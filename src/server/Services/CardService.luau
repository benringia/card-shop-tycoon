--!strict
-- Each player's binder: { [cardId] = { normal = n, foil = n } }. Cards on display in a showcase are
-- taken out of the binder while shown (PlacementService holds them) and come back when removed.
-- The whole collection is pushed to the client on every change (Set 1 is only 30 cards).
-- Saved through DataService. (DESIGN.md calls this CollectionService; renamed to avoid clashing
-- with Roblox's own service.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Collection = require(Config:WaitForChild("Collection"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

export type Owned = { normal: number, foil: number }
export type PullResult = { cardId: string, foil: boolean }

local CardService = {}

local collections: { [Player]: { [string]: Owned } } = {}
local allowRequest = RateLimiter.new(Collection.REQUEST_COOLDOWN)

local function sync(player: Player)
	local collection = collections[player]
	if collection then
		Remotes.CollectionChanged:FireClient(player, collection)
	end
end

local function getOwned(collection: { [string]: Owned }, cardId: string): Owned
	local owned = collection[cardId]
	if not owned then
		owned = { normal = 0, foil = 0 }
		collection[cardId] = owned
	end
	return owned
end

-- Adds a batch of cards (a pack, a purchase, or cards coming back off display) and syncs once
function CardService.AddCards(player: Player, results: { PullResult })
	local collection = collections[player]
	if not collection then
		return
	end
	for _, result in results do
		if Cards.ById[result.cardId] then
			local owned = getOwned(collection, result.cardId)
			if result.foil then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	sync(player)
end

-- Removes one copy from the binder (to put it on display). Returns false if the player has none.
function CardService.TakeCard(player: Player, cardId: string, foil: boolean): boolean
	local collection = collections[player]
	local owned = if collection then collection[cardId] else nil
	if not owned then
		return false
	end
	if foil then
		if owned.foil <= 0 then
			return false
		end
		owned.foil -= 1
	else
		if owned.normal <= 0 then
			return false
		end
		owned.normal -= 1
	end
	sync(player)
	return true
end

-- Whether the player's binder has loaded (they can receive cards)
function CardService.IsLoaded(player: Player): boolean
	return collections[player] ~= nil
end

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value > 0 then math.floor(value) else 0
end

-- Unknown card IDs and bad counts in saved data are dropped
local function load(player: Player, data: PlayerData)
	local collection: { [string]: Owned } = {}
	for cardId, saved in data.cards do
		if Cards.ById[cardId] and typeof(saved) == "table" then
			local owned = { normal = readCount(saved.normal), foil = readCount(saved.foil) }
			if owned.normal + owned.foil > 0 then
				collection[cardId] = owned
			end
		end
	end
	collections[player] = collection
	sync(player)
end

local function save(player: Player, data: PlayerData)
	local collection = collections[player]
	if not collection then
		return
	end
	local cards = {}
	for cardId, owned in collection do
		if owned.normal + owned.foil > 0 then
			cards[cardId] = { normal = owned.normal, foil = owned.foil }
		end
	end
	data.cards = cards
end

function CardService.Start()
	DataService.Register({
		name = "CardService",
		load = load,
		save = save,
		unload = function(player: Player)
			collections[player] = nil
		end,
	})

	Remotes.RequestCollection.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sync(player)
		end
	end)
end

return CardService
