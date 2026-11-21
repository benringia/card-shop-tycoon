--!strict
-- The plaza leaderboard (Config/Leaderboard; owner 2026-11-13): most packs opened and (since 2026-11-21) most boss
-- kills, all time across every server and in this server. Every place sends its players' lifetime totals (DataService
-- stats, one counter and one shared OrderedDataStore for each ranking in Leaderboard.BOARDS) when they change (at most
-- every WRITE_EVERY seconds, and as they leave; never from Studio); the main game draws the lists on the plaza's two
-- giant cards (Config/Plaza FAN, Server/Util/LeaderboardBoard), which show one ranking at a time, each for FLIP_EVERY
-- seconds. It reads each all-time top every READ_EVERY seconds and shows it with the players here counted live
-- (LeaderboardRules.merge), next to this server's list. No remotes: the cards are drawn on the server and replicate.
-- The game's owner is on neither list (Config/Leaderboard HIDE_OWNER).
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

type Board = typeof(Leaderboard.BOARDS[1])

local stores: { [string]: OrderedDataStore } = {} -- by a ranking's store name
-- The total last sent to each ranking's store, by player (weak: a player who left by teleport never got the leave hook)
local written: { [string]: { [Player]: number } } = {}
for _, board in Leaderboard.BOARDS do
	written[board.store] = setmetatable({}, { __mode = "k" }) :: any
end
local names: { [number]: string } = {} -- display names of the all-time list's players, by user id
-- Left off both lists and never sent to the store: the game's owner (Config/Leaderboard HIDE_OWNER)
local hidden = LeaderboardRules.hidden(game.CreatorId, game.CreatorType.Name, Leaderboard.HIDE_OWNER)

local function getStore(board: Board): OrderedDataStore?
	if not stores[board.store] then
		local ok, made = pcall(function()
			return DataStoreService:GetOrderedDataStore(Leaderboard.storeName(Data.STORE_NAME, board.store))
		end)
		if ok then
			stores[board.store] = made
		else
			warn("[LeaderboardService] no store:", made)
		end
	end
	return stores[board.store]
end

-- Sends a player's totals that changed, one ranking at a time (Studio's test packs and fights never count, nor the
-- owner's test save: SaveSlotService)
local function write(player: Player)
	if RunService:IsStudio() or DataService.IsTestSlot(player) then
		return
	end
	for _, board in Leaderboard.BOARDS do
		local count = DataService.GetStat(player, board.stat)
		local target = if LeaderboardRules.shouldWrite(count, written[board.store][player], hidden[player.UserId] == true) then getStore(board) else nil
		if target then
			local ok, err = pcall(function()
				target:SetAsync(tostring(player.UserId), count)
			end)
			if ok then
				written[board.store][player] = count
			else
				warn("[LeaderboardService] write failed:", err)
			end
		end
	end
end

-- A hidden player's entry from before they were hidden comes out of the store (once a server; never from Studio, like
-- the writes)
local function forgetHidden()
	if RunService:IsStudio() then
		return
	end
	for _, board in Leaderboard.BOARDS do
		local target = getStore(board)
		if target then
			for userId in hidden do
				local ok, err = pcall(function()
					target:RemoveAsync(tostring(userId))
				end)
				if not ok then
					warn("[LeaderboardService] couldn't take a hidden entry out:", err)
				end
			end
		end
	end
end

local function startWrites()
	task.spawn(forgetHidden)
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

-- A ranking's all-time top from its store; nil when it couldn't be read
local function readTop(board: Board): { LeaderboardRules.Entry }?
	local target = getStore(board)
	if not target then
		return nil
	end
	local ok, page = pcall(function()
		return target:GetSortedAsync(false, LeaderboardRules.readSize(Leaderboard.TOP, hidden)):GetCurrentPage()
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
	return LeaderboardRules.without(entries, hidden)
end

-- Everyone here now with their total in a ranking
local function liveEntries(board: Board): { LeaderboardRules.Entry }
	local entries: { LeaderboardRules.Entry } = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, { userId = player.UserId, name = player.DisplayName, count = DataService.GetStat(player, board.stat) })
	end
	return LeaderboardRules.without(entries, hidden)
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
	-- each ranking's all-time top as last read, and whether it was read at all
	local stored: { [string]: { LeaderboardRules.Entry } } = {}
	local loaded: { [string]: boolean } = {}
	task.spawn(function()
		while true do
			for _, board in Leaderboard.BOARDS do
				local top = readTop(board)
				if top then
					stored[board.store] = top
				end
				loaded[board.store] = true
			end
			task.wait(Leaderboard.READ_EVERY)
		end
	end)
	local shown = ""
	task.spawn(function()
		while true do
			-- the rankings take turns on the two cards (LeaderboardRules.shownBoard)
			local board = Leaderboard.BOARDS[LeaderboardRules.shownBoard(os.clock(), Leaderboard.FLIP_EVERY, #Leaderboard.BOARDS)]
			local live = liveEntries(board)
			local allTime = LeaderboardRules.merge(stored[board.store] or {}, live, Leaderboard.TOP)
			local server = LeaderboardRules.rank(live, Leaderboard.TOP, true)
			local ready = loaded[board.store] == true
			local now = `{board.store}#{ready}#{signature(allTime)}#{signature(server)}`
			if now ~= shown then
				shown = now
				LeaderboardBoard.fill(allTimeList, allTime, if ready or #allTime > 0 then board.empty else face.loading, board.subtitle)
				LeaderboardBoard.fill(serverList, server, board.empty, board.subtitle)
			end
			task.wait(Leaderboard.SERVER_EVERY)
		end
	end)
end

-- The Frontier and the Dungeon: totals go to the stores (Bag packs open there too, and their bosses are fought there), no board
function LeaderboardService.StartWrites()
	startWrites()
end

-- The main game: totals go to the store and the plaza's two giant cards show the lists
function LeaderboardService.Start()
	startWrites()
	startBoard()
end

return LeaderboardService
