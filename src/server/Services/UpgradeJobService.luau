--!strict
-- Timed station upgrades (owner 2026-11-12: "forge, condenser, and grading station should have a waiting time on
-- upgrades, the higher the upgrade the longer wait time. also with an option to pay robux for instant upgrade"; spec
-- 2026-11-12-timed-upgrades-revive-design). Each station (Condenser, Grading Station, Forge) holds one job at a time:
-- the upgraded item waits inside (a levelled card lifted out of the collection, a plain copy taken off its stack, a
-- weapon locked in the Forge or not made yet) until its time is up, then comes back on its own with a toast, also for
-- time spent away (finished on the next load). "Finish now" (Robux SkipS / SkipM / SkipL, PurchaseService) ends the job
-- the player asked to skip, else the soonest one the tier covers, else becomes a token the next job uses at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Weapons = require(Config:WaitForChild("Weapons"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local CardService = require(Services:WaitForChild("CardService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type Job = UpgradeRules.Job
type PlayerData = DataService.PlayerData
type Tokens = { S: number, M: number, L: number }

local UpgradeJobService = {}

local STATIONS = { "condenser", "grading", "forge" }
local SKIP_INTENT_SECONDS = 120 -- how long a "Finish now" press keeps pointing at its station while the purchase runs

local jobs: { [Player]: { [string]: Job } } = {} -- loaded players only
local tokens: { [Player]: Tokens } = {}
local skipIntent: { [Player]: { station: string, at: number } } = {}
local allowSkip = RateLimiter.new(1)

local function isStation(value: unknown): boolean
	return typeof(value) == "string" and table.find(STATIONS, value) ~= nil
end

-- What's inside: its name, and what it's becoming (a reforge's grade stays a surprise till it's done)
local function describe(job: Job): (string, string)
	if job.beast then
		local card = Cards.ById[job.beast.cardId]
		local detail = if job.kind == "star" then BeastRules.describeGrowth(job.beast.level, job.beast.stars) else `Grade {job.beast.grade}`
		return if card then card.name else "A card", detail
	elseif job.plain then
		local card = Cards.ById[job.plain.cardId]
		return if card then card.name else "A card", `Grade {job.plain.grade}`
	end
	local weapon = if job.weaponId then Weapons.ById[job.weaponId] else nil
	local name = if weapon then weapon.name else "A weapon"
	if job.kind == "level" then
		return name, `+{job.level or 0}`
	elseif job.kind == "reforge" then
		return name, "A new grade"
	end
	return name, "Being made"
end

local function send(player: Player)
	local now = os.time()
	local view = {}
	for station, job in jobs[player] or {} do
		local name, detail = describe(job)
		view[station] = { kind = job.kind, left = math.max(0, job.finishAt - now), total = job.finishAt - job.startedAt, name = name, detail = detail }
	end
	Remotes.UpgradeJobs:FireClient(player, view)
end

-- Gives the (upgraded) item back; the toast's words (nil for a weapon: the Forge window tells it, ForgeController)
local function giveBack(player: Player, job: Job): string?
	local name, detail = describe(job)
	if job.beast then
		CardService.AddBeast(player, job.beast)
	elseif job.plain then
		CardService.GiveCard(player, job.plain.cardId, job.plain.foil, job.plain.grade)
	elseif job.weaponId and job.grade then
		WeaponService.SetLocked(player, job.weaponId, false)
		local result: { [string]: any }
		if job.kind == "level" then
			WeaponService.SetLevel(player, job.weaponId, job.level or 0)
			result = { action = "upgrade", weaponId = job.weaponId, grade = job.grade, level = job.level or 0, kept = false, owned = job.grade }
		else
			local action = if job.kind == "craft" then "forge" else "reforge"
			local record = WeaponService.Give(player, job.weaponId, job.grade, action)
			local now = WeaponService.GetOwned(player, job.weaponId)
			detail = if job.kind == "reforge" and not record and now
				then `rolled Grade {job.grade}, kept Grade {now.grade}`
				else `Grade {job.grade}`
			result = {
				action = action,
				weaponId = job.weaponId,
				grade = job.grade,
				level = if now then now.level else 0,
				kept = record == nil, -- a reforge that didn't beat the grade it had
				owned = if now then now.grade else job.grade,
			}
		end
		-- done: its reveal plays when the Forge is open, else a toast says so and the reveal waits for the Forge
		-- (owner 2026-11-12, ForgeController)
		result.finished = true
		Remotes.ForgeResult:FireClient(player, result)
		return nil
	end
	return `{name} is ready! {detail}`
end

-- A job done: out of the station, its item back, a toast
local function finish(player: Player, station: string)
	local mine = jobs[player]
	local job = if mine then mine[station] else nil
	if not mine or not job then
		return
	end
	mine[station] = nil
	local ok, message = pcall(giveBack, player, job)
	if ok and message then
		Remotes.Notify:FireClient(player, message, false)
	elseif not ok then
		warn(`[UpgradeJobService] giving back {player.Name}'s {station} job failed: {message}`)
	end
	send(player)
end

local function tierRank(tier: string): number
	for index, entry in Upgrades.TIERS do
		if entry.name == tier then
			return index
		end
	end
	return math.huge
end

-- Puts a job in a station (the caller has taken its cost and, for a card, lifted the item out); false when it's busy.
-- A skip token that covers it finishes it at once.
function UpgradeJobService.Begin(player: Player, station: string, job: Job): boolean
	local mine = jobs[player]
	if not mine or not isStation(station) or mine[station] then
		return false
	end
	mine[station] = job
	if job.weaponId and job.kind ~= "craft" then
		WeaponService.SetLocked(player, job.weaponId, true)
	end
	local owned = tokens[player]
	local token = if owned then UpgradeRules.tokenFor(owned :: any, UpgradeRules.tier(Upgrades, job.finishAt - os.time()), Upgrades) else nil
	if owned and token then
		(owned :: any)[token] -= 1
		Remotes.Notify:FireClient(player, "A Finish now you bought earlier finished it!", false)
		finish(player, station)
		return true
	end
	send(player)
	return true
end

-- Seconds left on a station's job, or nil when it's free
function UpgradeJobService.Left(player: Player, station: string): number?
	local mine = jobs[player]
	local job = if mine then mine[station] else nil
	return if job then math.max(0, job.finishAt - os.time()) else nil
end

UpgradeJobService.Finish = finish

-- A "Finish now" bought (a grant: always true, nothing bought is lost): the station the player pressed it on, else the
-- job with the least time left this tier covers, else a token for the next job
function UpgradeJobService.Skip(player: Player, tier: string): boolean
	local mine = jobs[player] or {}
	local rank = tierRank(tier)
	local function covered(station: string): boolean
		local left = UpgradeJobService.Left(player, station)
		return left ~= nil and tierRank(UpgradeRules.tier(Upgrades, left)) <= rank
	end
	local intent = skipIntent[player]
	skipIntent[player] = nil
	local target: string? = nil
	if intent and os.clock() - intent.at <= SKIP_INTENT_SECONDS and covered(intent.station) then
		target = intent.station
	else
		local least = math.huge
		for station in mine do
			local left = UpgradeJobService.Left(player, station)
			if left and covered(station) and left < least then
				target, least = station, left
			end
		end
	end
	if target then
		finish(player, target)
		return true
	end
	local owned = tokens[player]
	if owned then
		(owned :: any)[tier] = ((owned :: any)[tier] or 0) + 1
		Remotes.Notify:FireClient(player, "Saved: your next upgrade finishes at once.", false)
	end
	return true
end

-- A job that couldn't be read back: give back what can be found in it (never lose an item)
local function rescue(player: Player, raw: any)
	warn(`[UpgradeJobService] {player.Name}: an unreadable station job, giving its item back`)
	if typeof(raw) ~= "table" then
		return
	end
	local beast = raw.beast
	if typeof(beast) == "table" and typeof(beast.id) == "string" and typeof(beast.cardId) == "string" and Cards.ById[beast.cardId] then
		CardService.AddBeast(player, {
			id = beast.id,
			cardId = beast.cardId,
			foil = beast.foil == true,
			level = if typeof(beast.level) == "number" then beast.level else 1,
			xp = if typeof(beast.xp) == "number" then beast.xp else 0,
			stars = if typeof(beast.stars) == "number" then beast.stars else BeastRules.START_STARS,
			grade = if BeastRules.isGrade(beast.grade) then beast.grade else "C",
		})
	elseif typeof(raw.plain) == "table" and typeof(raw.plain.cardId) == "string" and Cards.ById[raw.plain.cardId] then
		CardService.GiveCard(player, raw.plain.cardId, raw.plain.foil == true, if BeastRules.isGrade(raw.plain.grade) then raw.plain.grade else "C")
	end
end

local function load(player: Player, data: PlayerData)
	local mine: { [string]: Job } = {}
	jobs[player] = mine
	local saved = if typeof(data.skipTokens) == "table" then data.skipTokens else {}
	local function count(tier: string): number
		local value = (saved :: any)[tier]
		return if typeof(value) == "number" and value >= 0 then math.floor(value) else 0
	end
	tokens[player] = { S = count("S"), M = count("M"), L = count("L") }
	local raw = if typeof(data.upgrades) == "table" then data.upgrades else {}
	for _, station in STATIONS do
		local entry = (raw :: any)[station]
		if entry ~= nil then
			local job = UpgradeRules.readJob(entry, Cards, Weapons)
			if job then
				mine[station] = job
				if job.weaponId and job.kind ~= "craft" then
					WeaponService.SetLocked(player, job.weaponId, true)
				end
			else
				rescue(player, entry)
			end
		end
	end
	-- finished while away: back now
	local now = os.time()
	for station, job in table.clone(mine) do
		if UpgradeRules.due(job, now) then
			finish(player, station)
		end
	end
	send(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their jobs
local function save(player: Player, data: PlayerData)
	local mine = jobs[player]
	if not mine then
		return
	end
	local copy = {}
	for station, job in mine do
		copy[station] = table.clone(job)
	end
	data.upgrades = copy
	local owned = tokens[player]
	if owned then
		data.skipTokens = { S = owned.S, M = owned.M, L = owned.L }
	end
end

local function unload(player: Player)
	jobs[player] = nil
	tokens[player] = nil
	skipIntent[player] = nil
end

function UpgradeJobService.Start()
	DataService.Register({ name = "UpgradeJobService", load = load, save = save, unload = unload })
	for _, tier in { "S", "M", "L" } do
		PurchaseService.OnProduct(`Skip{tier}`, function(player: Player): boolean
			return UpgradeJobService.Skip(player, tier)
		end)
	end
	Remotes.SkipUpgrade.OnServerEvent:Connect(function(player: Player, station: unknown)
		if allowSkip(player) and isStation(station) and jobs[player] then
			skipIntent[player] = { station = station :: string, at = os.clock() }
		end
	end)
	Remotes.UpgradeJobs.OnServerEvent:Connect(function(player: Player)
		if allowSkip(player) and jobs[player] then
			send(player) -- a client asking for the stations' jobs now (it started listening late)
		end
	end)
	-- once a second: jobs whose time is up come back
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				for station, job in table.clone(jobs[player] or {}) do
					if UpgradeRules.due(job, now) then
						finish(player, station)
					end
				end
			end
		end
	end)
end

return UpgradeJobService
