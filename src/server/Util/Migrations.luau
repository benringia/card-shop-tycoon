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
	-- v12: boss ladder progress, per boss (BossService)
	[11] = function(data)
		if typeof(data.bosses) ~= "table" then
			data.bosses = {}
		end
	end,
	-- v13: the first-visit welcome cinematic (WelcomeService). Everyone who played before it has seen the town, so it
	-- doesn't play for them; set even if Reconcile already added false
	[12] = function(data)
		data.seenWelcome = true
	end,
	-- v14: the first-sword popup (SwordService). Everyone, old players too, sees it once; a bad value starts over
	[13] = function(data)
		if typeof(data.seenSword) ~= "boolean" then
			data.seenSword = false
		end
	end,
	-- v15: boss fights fought with the sword HUD (SwordService), so its buttons show their names for the first few.
	-- Everyone starts at 0; a saved whole count stays, anything else starts over
	[14] = function(data)
		local count = data.swordFights
		local whole = typeof(count) == "number" and count >= 0 and count < math.huge and count == math.floor(count)
		if not whole then
			data.swordFights = 0
		end
	end,
	-- v16: weapons (WeaponService): an empty Armory and the Steel Sword equipped; anything else starts over
	[15] = function(data)
		if typeof(data.weapons) ~= "table" then
			data.weapons = {}
		end
		if typeof(data.equippedWeapon) ~= "string" then
			data.equippedWeapon = "starterSword"
		end
	end,
	-- v17: the tutorial with Pish (TutorialService): shops from before it never go through the first visit (their
	-- first pack counts as given), Pish's gift still comes if they replay it, no lessons seen yet
	[16] = function(data)
		data.tutorial = {
			firstVisit = "done",
			step = 1,
			early = {},
			firstGiven = true,
			giftClaimed = false,
			customerSent = true, -- their shop already has customers: a replay brings none for free
			lessons = {},
			pishLuckAt = 0,
		}
	end,
	-- v18: Chikin's combat tutorial (CombatTutorialService), the same table as Pish's: shops past Pish's first visit
	-- already fight, so it's done for them; a new player still on Pish's tour gets Chikin after it
	[17] = function(data)
		local pish = if typeof(data.tutorial) == "table" then data.tutorial.firstVisit else nil
		data.combat = {
			firstVisit = if pish == "todo" then "todo" else "done",
			step = 1,
			early = {},
			firstGiven = false,
			giftClaimed = false,
			customerSent = false,
			lessons = {},
			pishLuckAt = 0,
		}
	end,
	-- v19: the Dungeon's secret chest (spec 2026-11-11-dungeon-puzzles): whether this player ever found it (its first
	-- find gives the title Crystal Seeker; BossService) and whether they saw the Hydra's full welcome (2026-11-12)
	[18] = function(data)
		local saved = if typeof(data.dungeon) == "table" then data.dungeon else nil
		data.dungeon = { secretFound = saved ~= nil and saved.secretFound == true, seenIntro = saved ~= nil and saved.seenIntro == true }
	end,
	-- v20 (2026-11-12): the title the player picked to show over their name ("" = automatic; TitleService, Config/Titles)
	[19] = function(data)
		data.title = if typeof(data.title) == "string" then data.title else ""
	end,
	-- v21 (spec 2026-11-12-timed-upgrades-revive-design): station jobs (UpgradeJobService), unused "Finish now" skips and
	-- the last receipts granted (PurchaseService); a good skip count kept, junk replaced
	[20] = function(data)
		data.upgrades = if typeof(data.upgrades) == "table" then data.upgrades else {}
		local tokens = if typeof(data.skipTokens) == "table" then data.skipTokens else {}
		local clean = {}
		for _, tier in { "S", "M", "L" } do
			local count = tokens[tier]
			clean[tier] = if typeof(count) == "number" and count >= 0 then math.floor(count) else 0
		end
		data.skipTokens = clean
		data.purchases = if typeof(data.purchases) == "table" then data.purchases else {}
	end,
	-- "Support the dev" (owner 2026-11-12): gifts given and the best tier (SupportService)
	[21] = function(data)
		local support = if typeof(data.support) == "table" then data.support else {}
		local function count(value: any): number
			return if typeof(value) == "number" and value >= 0 then math.floor(value) else 0
		end
		data.support = { gifts = count(support.gifts), best = count(support.best) }
	end,
	-- Titles stay earned once earned (owner 2026-11-13: more titles, told when earned; TitleService): `known` ever
	-- earned and told, `fresh` not seen in the Titles tab yet; `seeded` once the first load counted what's earned already
	[22] = function(data)
		local titles = if typeof(data.titles) == "table" then data.titles else {}
		local function names(list: any): { string }
			local clean = {}
			if typeof(list) == "table" then
				for _, id in list do
					if typeof(id) == "string" then
						table.insert(clean, id)
					end
				end
			end
			return clean
		end
		data.titles = { known = names(titles.known), fresh = names(titles.fresh), seeded = titles.seeded == true }
	end,
	-- Turts' rug shop (spec 2026-11-13-turts-shop-design): the restock a player last saw, the offers they bought in it,
	-- and a "restock now" roll (TurtsService; Util/TurtsRules.State)
	[23] = function(data)
		local turts = if typeof(data.turts) == "table" then data.turts else {}
		local function ids(list: any): { string }
			local clean = {}
			if typeof(list) == "table" then
				for _, id in list do
					if typeof(id) == "string" then
						table.insert(clean, id)
					end
				end
			end
			return clean
		end
		local personal = turts.personal
		local keep = typeof(personal) == "table" and typeof(personal.index) == "number" and typeof(personal.offers) == "table"
		data.turts = {
			index = if typeof(turts.index) == "number" then turts.index else 0,
			bought = ids(turts.bought),
			personal = if keep then { index = personal.index, offers = ids(personal.offers) } else nil,
		}
	end,
	-- Shop decor (spec 2026-11-14-shop-decor-design): the look in use and the looks bought; ids are checked against
	-- Config/Decor on load (DecorRules.clean)
	[24] = function(data)
		local decor = if typeof(data.decor) == "table" then data.decor else {}
		local owned = {}
		if typeof(decor.owned) == "table" then
			for _, id in decor.owned do
				if typeof(id) == "string" then
					table.insert(owned, id)
				end
			end
		end
		data.decor = { look = if typeof(decor.look) == "string" then decor.look else "CozyWood", owned = owned }
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
