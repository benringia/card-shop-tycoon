--!strict
-- Owns each player's lifecycle and their saved data (ProfileStore, session-locked).
--   Join:  claim a plot → load the profile → every registered service loads its part.
--   Leave: every service saves its part → end the session → services unload → release the plot.
-- Services keep their own runtime state and register load/save/unload handlers here, so nothing
-- is torn down before it has been saved. ProfileStore also autosaves; OnSave collects first.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local DataConfig = require(Config:WaitForChild("Data"))
local EconomyConfig = require(Config:WaitForChild("Economy"))
local BeastRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("BeastRules"))
local ProfileStore = require(ServerStorage:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

local Services = script.Parent :: Instance
local PlotService = require(Services:WaitForChild("PlotService"))
local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))
local Migrations = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("Migrations"))

-- Shape of what's saved. Tables only hold plain data: no Instances, Vector3s or Color3s.
export type SavedCard = {
	slot: number,
	cardId: string,
	foil: boolean,
	price: number,
	-- Set when the displayed card is a levelled card (stars 0-5)
	beastId: string?,
	level: number?,
	xp: number?,
	stars: number?,
	grade: string?, -- C/B/A/S; a levelled card's grade is on the card too
}
export type SavedBeast = { cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string } -- stars 0-5
export type SavedOwned = { normal: number, foil: number }
export type SavedJob = { slot: number, beastId: string, job: string }
-- Party slots keyed "1".."3" so the saved table stays a plain dictionary; summoned is a slot number
export type SavedParty = { slots: { [string]: string }, summoned: number? }
export type SavedShelf = {
	shelfId: string,
	gridX: number,
	gridZ: number,
	rotation: number,
	productId: string?,
	units: number,
	paid: number,
	cards: { SavedCard }?, -- card cases only: what's on display
}
export type SavedBox = { productId: string, units: number }
export type SavedCell = { gridX: number, gridZ: number, rotation: number }

export type PlayerData = {
	version: number,
	cash: number,
	xp: number,
	level: number,
	shopName: string,
	upgrades: { [string]: boolean },
	prices: { [string]: number },
	layout: { SavedShelf },
	fixtures: { [string]: SavedCell },
	boxes: { SavedBox },
	cards: { [string]: { [string]: SavedOwned } }, -- cardId -> grade -> plain copies in the binder
	beasts: { [string]: SavedBeast }, -- levelled cards by ID
	jobs: { SavedJob }, -- cards working in the shop
	party: SavedParty, -- 3 party cards, one summoned
	resting: { [string]: number }, -- beastId -> Unix time it can fight again (fainted in battle)
	pvp: { wins: number, losses: number, draws: number }, -- PvP record
	items: { [string]: number }, -- itemId -> count (Config/Items)
	pity: { legendary: number, epic: number, firstDone: boolean }, -- packs since the last Legendary / Epic or better (PackService)
	bosses: { [string]: any }, -- bossId -> BossRules.Record (BossService)
	stats: { packsOpened: number, customersServed: number, totalEarned: number },
	purchases: { [string]: boolean },
}

export type Handler = {
	name: string,
	load: (player: Player, data: PlayerData) -> (),
	save: (player: Player, data: PlayerData) -> (),
	unload: (player: Player) -> (),
}

local TEMPLATE: PlayerData = {
	version = DataConfig.SCHEMA_VERSION,
	cash = EconomyConfig.STARTING_CASH,
	xp = 0,
	level = EconomyConfig.STARTING_LEVEL,
	shopName = "",
	upgrades = {},
	prices = {},
	layout = {},
	fixtures = {},
	boxes = {},
	cards = {},
	beasts = {},
	jobs = {},
	party = { slots = {} },
	resting = {},
	pvp = { wins = 0, losses = 0, draws = 0 },
	items = {},
	pity = { legendary = 0, epic = 0, firstDone = false },
	bosses = {},
	stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 },
	purchases = {},
}

local DataService = {}

-- Gives each existing copy a grade when an old save is upgraded (schema v5)
local gradeRng = Random.new()
local function rollGrade(): string
	return BeastRules.rollGrade(gradeRng:NextNumber())
end

local store = ProfileStore.New(DataConfig.STORE_NAME, TEMPLATE)
local handlers: { Handler } = {}
local beforeLeaveCallbacks: { (player: Player) -> () } = {}
local profiles: { [Player]: any } = {}

-- Runs one handler step; a bug in one service must not stop the others saving
local function runHandler(handler: Handler, step: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[DataService] {handler.name}.{step} failed: {err}`)
	end
end

local function collect(player: Player, data: PlayerData)
	for _, handler in handlers do
		runHandler(handler, "save", function()
			handler.save(player, data)
		end)
	end
end

local function unloadAll(player: Player)
	-- Reverse load order, so things that depend on others go first
	for index = #handlers, 1, -1 do
		local handler = handlers[index]
		runHandler(handler, "unload", function()
			handler.unload(player)
		end)
	end
end

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

local function onPlayerAdded(player: Player)
	-- Claim first so the player spawns in their shop while the profile loads
	if not Place.isFrontier() and not Place.isDungeon() then -- the Frontier and Dungeon places have no plots
		PlotService.Claim(player)
	end

	local profile = store:StartSessionAsync(DataConfig.KEY_PREFIX .. player.UserId, {
		Cancel = function()
			return not isInGame(player)
		end,
	})
	if not profile then
		if isInGame(player) then
			player:Kick(DataConfig.LOAD_FAILED_MESSAGE)
		end
		return
	end
	if not isInGame(player) then
		profile:EndSession()
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: links the data to this user for deletion requests
	Migrations.run(profile.Data, DataConfig.SCHEMA_VERSION, rollGrade)
	profile:Reconcile() -- fills in fields added to TEMPLATE since this profile was created

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if isInGame(player) then
			player:Kick(DataConfig.SESSION_ENDED_MESSAGE)
		end
	end)
	-- Autosaves and the final save copy live state into the profile first
	profile.OnSave:Connect(function()
		if profiles[player] == profile then
			collect(player, profile.Data)
		end
	end)

	profiles[player] = profile
	for _, handler in handlers do
		runHandler(handler, "load", function()
			handler.load(player, profile.Data)
		end)
	end
end

local function onPlayerRemoving(player: Player)
	-- e.g. customers put picked-up stock and cards back, so they're on shelves when we save
	for _, callback in beforeLeaveCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn(`[DataService] before-leave callback failed: {err}`)
		end
	end

	local profile = profiles[player]
	if profile then
		collect(player, profile.Data)
		profiles[player] = nil
		profile:EndSession()
	end
	unloadAll(player)
	if not Place.isFrontier() and not Place.isDungeon() then
		PlotService.Release(player)
	end
end

-- Services register in their Start(), before DataService.Start(). Load runs in registration order.
function DataService.Register(handler: Handler)
	table.insert(handlers, handler)
end

-- Runs when a player leaves, before their data is collected (not on autosaves)
function DataService.OnBeforeLeave(callback: (player: Player) -> ())
	table.insert(beforeLeaveCallbacks, callback)
end

-- Lifetime counters (DESIGN stats). Written straight into the profile.
function DataService.AddStat(player: Player, stat: "packsOpened" | "customersServed" | "totalEarned", amount: number)
	local profile = profiles[player]
	if not profile or amount ~= amount then
		return
	end
	local stats = profile.Data.stats
	stats[stat] = (stats[stat] or 0) + amount
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
