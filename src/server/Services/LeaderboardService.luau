--!strict
-- The plaza leaderboard (Config/Leaderboard; owner 2026-11-13): most packs opened, all time across every server and in
-- this server. Every place sends its players' lifetime totals (DataService stats.packsOpened) to a shared
-- OrderedDataStore when they change (at most every WRITE_EVERY seconds, and as they leave; never from Studio); the main
-- game draws the lists on the plaza's two giant cards (Config/Plaza FAN, Server/Util/LeaderboardBoard), reads the
-- all-time top every READ_EVERY seconds and shows it with the players here counted live (LeaderboardRules.merge), next
-- to this server's list. No remotes: the cards are drawn on the server and replicate.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Leaderboard = require(Shared:WaitForChild("Config"):WaitForChild("Leaderboard"))
local Data = require(Shared:WaitForChild("Config"):WaitForChild("Data"))
local LeaderboardRules = require(Shared:WaitForChild("Util"):WaitForChild("LeaderboardRules"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LeaderboardBoard = require((script.Parent.Parent :: Instance):WaitForChild("Util"):WaitForChild("LeaderboardBoard"))

local LeaderboardService = {}

local STAT = "packsOpened"

local store: OrderedDataStore? = nil
-- The total last sent to the store, by player (weak: a player who left by teleport never got the leave hook)
local written: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local names: { [number]: string } = {} -- display names of the all-time list's players, by user id

local function getStore(): OrderedDataStore?
	if not store then
		local ok, made = pcall(function()
			return DataStoreService:GetOrderedDataStore(Leaderboard.storeName(Data.STORE_NAME))
		end)
		if ok then
			store = made
		else
			warn("[LeaderboardService] no store:", made)
		end
	end
	return store
end

-- Sends a player's total if it changed (Studio's test packs never count)
local function write(player: Player)
	if RunService:IsStudio() then
		return
	end
	local count = DataService.GetStat(player, STAT)
	if not LeaderboardRules.shouldWrite(count, written[player]) then
		return
	end
	local target = getStore()
	if not target then
		return
	end
	local ok, err = pcall(function()
		target:SetAsync(tostring(player.UserId), count)
	end)
	if ok then
		written[player] = count
	else
		warn("[LeaderboardService] write failed:", err)
	end
end

local function startWrites()
	DataService.OnBeforeLeave(function(player)
		task.spawn(write, player)
	end)
	task.spawn(function()
		while true do
			task.wait(Leaderboard.WRITE_EVERY)
			for _, player in Players:GetPlayers() do
				task.spawn(write, player)
			end
		end
	end)
end

-- Display names for these user ids (cached; "Player" when Roblox can't say)
local function resolveNames(ids: { number })
	local missing: { number } = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos :: { any } do
			if typeof(info.Id) == "number" then
				names[info.Id] = if typeof(info.DisplayName) == "string" and info.DisplayName ~= "" then info.DisplayName else info.Username
			end
		end
	end
	for _, id in missing do
		if not names[id] then
			local found, name = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			names[id] = if found and typeof(name) == "string" then name else "Player"
		end
	end
end

-- The all-time top from the store; nil when it couldn't be read
local function readTop(): { LeaderboardRules.Entry }?
	local target = getStore()
	if not target then
		return nil
	end
	local ok, page = pcall(function()
		return target:GetSortedAsync(false, Leaderboard.TOP):GetCurrentPage()
	end)
	if not ok then
		warn("[LeaderboardService] read failed:", page)
		return nil
	end
	local ids: { number } = {}
	local raw: { { userId: number, count: number } } = {}
	for _, item in page :: { any } do
		local id = tonumber(item.key)
		if id and typeof(item.value) == "number" then
			table.insert(ids, id)
			table.insert(raw, { userId = id, count = item.value })
		end
	end
	resolveNames(ids)
	local entries: { LeaderboardRules.Entry } = {}
	for _, item in raw do
		table.insert(entries, { userId = item.userId, name = names[item.userId] or "Player", count = item.count })
	end
	return entries
end

-- Everyone here now with their total
local function liveEntries(): { LeaderboardRules.Entry }
	local entries: { LeaderboardRules.Entry } = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, { userId = player.UserId, name = player.DisplayName, count = DataService.GetStat(player, STAT) })
	end
	return entries
end

-- A list as text, to skip redrawing an unchanged board
local function signature(list: { LeaderboardRules.Entry }): string
	local parts = {}
	for _, entry in list do
		table.insert(parts, `{entry.userId}:{entry.name}:{entry.count}`)
	end
	return table.concat(parts, "|")
end

-- The plaza's list cards by list (PlazaBuild marks them; the scenery is built before this service starts)
local function findCards(): { [string]: BasePart }
	local cards: { [string]: BasePart } = {}
	local scenery = workspace:FindFirstChild("Scenery")
	for _, item in (if scenery then scenery else workspace):GetDescendants() do
		local list = item:GetAttribute("LeaderboardList")
		if item:IsA("BasePart") and typeof(list) == "string" then
			cards[list] = item
		end
	end
	return cards
end

local function startBoard()
	local cards = findCards()
	if not cards.allTime or not cards.server then
		warn("[LeaderboardService] the plaza's leaderboard cards are missing")
		return
	end
	local allTimeList = LeaderboardBoard.attach(cards.allTime, "allTime")
	local serverList = LeaderboardBoard.attach(cards.server, "server")
	local face = Leaderboard.FACE
	local stored: { LeaderboardRules.Entry } = {}
	local loaded = false
	task.spawn(function()
		while true do
			local top = readTop()
			if top then
				stored = top
			end
			loaded = true
			task.wait(Leaderboard.READ_EVERY)
		end
	end)
	local shown = ""
	task.spawn(function()
		while true do
			local live = liveEntries()
			local allTime = LeaderboardRules.merge(stored, live, Leaderboard.TOP)
			local server = LeaderboardRules.rank(live, Leaderboard.TOP, true)
			local now = `{loaded}#{signature(allTime)}#{signature(server)}`
			if now ~= shown then
				shown = now
				LeaderboardBoard.fill(allTimeList, allTime, if loaded or #allTime > 0 then face.empty else face.loading)
				LeaderboardBoard.fill(serverList, server, face.empty)
			end
			task.wait(Leaderboard.SERVER_EVERY)
		end
	end)
end

-- The Frontier and the Dungeon: totals go to the store (Bag packs open there too), no board
function LeaderboardService.StartWrites()
	startWrites()
end

-- The main game: totals go to the store and the plaza's two giant cards show the lists
function LeaderboardService.Start()
	startWrites()
	startBoard()
end

return LeaderboardService
