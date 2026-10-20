--!strict
-- Each player's card collection: { [cardId] = { normal = n, foil = n } }, plus quick sell.
-- The whole collection is pushed to the client on every change (Set 1 is only 30 cards).
-- Saved through DataService. (DESIGN.md calls this CollectionService; renamed to avoid clashing
-- with Roblox's own service.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Collection = require(Config:WaitForChild("Collection"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

export type Owned = { normal: number, foil: number }
export type PullResult = { cardId: string, foil: boolean }

local CardService = {}

local collections: { [Player]: { [string]: Owned } } = {}
local allowSell = RateLimiter.new(Collection.SELL_COOLDOWN)
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

-- Adds a batch of pulls (one pack) and syncs once
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

function CardService.GetCollection(player: Player): { [string]: Owned }
	return collections[player] or {}
end

local function onQuickSell(player: Player, cardId: unknown, foil: unknown)
	if not allowSell(player) or typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" then
		return
	end
	local card = Cards.ById[cardId]
	local collection = collections[player]
	local owned = if collection then collection[cardId] else nil
	if not card or not owned then
		return
	end
	local count = if foil then owned.foil else owned.normal
	if count <= 0 then
		return
	end

	if foil then
		owned.foil -= 1
	else
		owned.normal -= 1
	end
	local payout = CardRules.getQuickSellValue(card, foil)
	EconomyService.AddCash(player, payout)
	sync(player)
	Remotes.Notify:FireClient(player, string.format("Sold %s%s for $%.2f", if foil then "foil " else "", card.name, payout), false)
end

-- Keeps one normal and one foil of each card, sells the rest
local function onSellDuplicates(player: Player)
	if not allowSell(player) then
		return
	end
	local collection = collections[player]
	if not collection then
		return
	end

	local total = 0
	local sold = 0
	for cardId, owned in collection do
		local card = Cards.ById[cardId]
		if not card then
			continue
		end
		local extraNormal = math.max(0, owned.normal - 1)
		local extraFoil = math.max(0, owned.foil - 1)
		total += extraNormal * CardRules.getQuickSellValue(card, false) + extraFoil * CardRules.getQuickSellValue(card, true)
		sold += extraNormal + extraFoil
		owned.normal -= extraNormal
		owned.foil -= extraFoil
	end
	if sold == 0 then
		Remotes.Notify:FireClient(player, "No duplicates to sell.", true)
		return
	end

	total = math.round(total * 100) / 100
	EconomyService.AddCash(player, total)
	sync(player)
	Remotes.Notify:FireClient(player, string.format("Sold %d duplicates for $%.2f", sold, total), false)
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
	Remotes.QuickSell.OnServerEvent:Connect(onQuickSell)
	Remotes.SellDuplicates.OnServerEvent:Connect(onSellDuplicates)
end

return CardService
