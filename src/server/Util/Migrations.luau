--!strict
-- Save data migrations. MIGRATIONS[n] upgrades a profile from version n to n + 1.
-- Pure (no requires, no Roblox APIs) so tests/ can run it in Lune. DataService calls run().
local Migrations = {}

-- Copies rolled one by one when stacks get grades (v5); anything beyond this (corrupt data) becomes
-- the lowest grade so loading never stalls
local MAX_ROLLED_COPIES = 10000
local LOWEST_GRADE = "C" -- matches Config/Beasts DEFAULT_GRADE; this module has no requires

type Counts = { normal: number, foil: number }

local function readCount(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

local function isOldStack(entry: any): boolean
	return typeof(entry) == "table" and (entry.normal ~= nil or entry.foil ~= nil)
end

local function gradeStack(old: any, rollGrade: () -> string): { [string]: Counts }
	local graded: { [string]: Counts } = {}
	local function add(grade: string, side: string, amount: number)
		local counts = graded[grade] or { normal = 0, foil = 0 }
		graded[grade] = counts
		if side == "foil" then
			counts.foil += amount
		else
			counts.normal += amount
		end
	end
	for _, side in { "normal", "foil" } do
		local count = readCount(old[side])
		local rolled = math.min(count, MAX_ROLLED_COPIES)
		for _ = 1, rolled do
			add(rollGrade(), side, 1)
		end
		if count > rolled then
			add(LOWEST_GRADE, side, count - rolled)
		end
	end
	return graded
end

local function lowerStars(entry: any)
	if typeof(entry) == "table" and typeof(entry.stars) == "number" then
		entry.stars = math.max(0, entry.stars - 1)
	end
end

local MIGRATIONS: { [number]: (data: any, rollGrade: () -> string) -> () } = {
	-- v2: displayed cards live on each saved shelf; the old top-level showcase list was never used
	[1] = function(data)
		data.showcase = nil
	end,
	-- v3: levelled cards live in their own table; existing cards are plain stacks already
	[2] = function(data)
		data.beasts = data.beasts or {}
	end,
	-- v4: stars now run 0-5 instead of 1-5, so every saved star count drops by one
	[3] = function(data)
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				lowerStars(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						lowerStars(card)
					end
				end
			end
		end
	end,
	-- v5: every copy has a grade; plain stacks become cardId -> grade -> { normal, foil }
	[4] = function(data, rollGrade)
		if typeof(data.cards) == "table" then
			for cardId, entry in data.cards do
				if isOldStack(entry) then
					data.cards[cardId] = gradeStack(entry, rollGrade)
				end
			end
		end
		local function giveGrade(entry: any)
			if typeof(entry) == "table" and typeof(entry.cardId) == "string" and typeof(entry.grade) ~= "string" then
				entry.grade = rollGrade()
			end
		end
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				giveGrade(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						giveGrade(card)
					end
				end
			end
		end
	end,
	-- v6: shop jobs; cards assigned to job slots
	[5] = function(data)
		data.jobs = data.jobs or {}
	end,
	-- v7: party of 3 cards (slot keys "1".."3") and which slot is summoned
	[6] = function(data)
		if typeof(data.party) ~= "table" then
			data.party = { slots = {} }
		elseif typeof(data.party.slots) ~= "table" then
			data.party.slots = {}
		end
	end,
	-- v8: fainted cards resting until a Unix time (battles)
	[7] = function(data)
		if typeof(data.resting) ~= "table" then
			data.resting = {}
		end
	end,
	-- v9: PvP record (battles part 2)
	[8] = function(data)
		if typeof(data.pvp) ~= "table" then
			data.pvp = { wins = 0, losses = 0, draws = 0 }
		end
	end,
	-- v10: item inventory (Star Shards first)
	[9] = function(data)
		if typeof(data.items) ~= "table" then
			data.items = {}
		end
	end,
	-- v11: pack pity counts (packs since the last Legendary, and since the last Epic or better), from zero
	[10] = function(data)
		if typeof(data.pity) ~= "table" then
			data.pity = { legendary = 0, epic = 0, firstDone = false }
		end
	end,
}

local function lowestGrade(): string
	return LOWEST_GRADE
end

-- rollGrade gives each copy its grade in v5 (the server passes a random roll; tests pass a fixed one)
function Migrations.run(data: any, targetVersion: number, rollGrade: (() -> string)?)
	local version = if typeof(data.version) == "number" then data.version else 1
	-- A save written by newer code (e.g. an old server still running during an update) keeps its
	-- version, so the newer code never runs the same migration on it twice
	if version >= targetVersion then
		return
	end
	while version < targetVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data, rollGrade or lowestGrade)
		end
		version += 1
	end
	data.version = targetVersion
end

return Migrations
