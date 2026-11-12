--!strict
-- Robux developer products (spec 2026-11-12-timed-upgrades-revive-design): the game's one ProcessReceipt. Services
-- name what a product does (OnProduct: a skip finishes a station job, a revive stands you up); a receipt is granted
-- once, ever: its PurchaseId goes into the save with the grant (Util/ReceiptRules, the newest Monetization
-- PURCHASE_MEMORY) and the purchase is reported granted only once the DataStore holds that id (ProfileStore's own
-- developer product recipe: DataService.SaveNow returns what was saved). Anything else answers NotProcessedYet, so
-- Roblox asks again (the next join, or a place that can grant it).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local ReceiptRules = require(Shared:WaitForChild("Util"):WaitForChild("ReceiptRules"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))

type PlayerData = DataService.PlayerData

local PurchaseService = {}

local purchases: { [Player]: { string } } = {} -- receipts granted, by PurchaseId (loaded players only)
local grants: { [string]: (player: Player) -> boolean } = {}

-- The Monetization PRODUCTS name of a product id, or nil
local function keyOf(productId: number): string?
	for key, id in Monetization.PRODUCTS do
		if id ~= 0 and id == productId then
			return key
		end
	end
	return nil
end

-- Saves now and says whether the DataStore holds this receipt
local function savedWith(player: Player, purchaseId: string): boolean
	local saved = DataService.SaveNow(player)
	return saved ~= nil and typeof(saved.purchases) == "table" and table.find(saved.purchases, purchaseId) ~= nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local list = if player then purchases[player] else nil
	if not player or not list then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not here, or their save isn't loaded yet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not ReceiptRules.seen(list, purchaseId) then
		local key = keyOf(receipt.ProductId)
		local grant = if key then grants[key] else nil
		if not grant then
			warn(`[PurchaseService] nothing grants product {receipt.ProductId} here (receipt {purchaseId})`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(grant, player)
		if not ok or granted ~= true then
			if not ok then
				warn(`[PurchaseService] {key} for {player.Name} failed: {granted}`)
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		purchases[player] = ReceiptRules.record(list, purchaseId, Monetization.PURCHASE_MEMORY)
	end
	-- granted (now or on an earlier try): done once the DataStore holds the id, so it's never granted again
	if savedWith(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- What buying this product does (a Monetization PRODUCTS name): true once given. Looked up per receipt, so services
-- may register after Start.
function PurchaseService.OnProduct(key: string, grant: (player: Player) -> boolean)
	grants[key] = grant
end

-- A product's id, 0 when it isn't created yet (its button says "Coming soon")
function PurchaseService.ProductId(key: string): number
	local id = Monetization.PRODUCTS[key]
	return if typeof(id) == "number" then id else 0
end

local function load(player: Player, data: PlayerData)
	local list = {}
	if typeof(data.purchases) == "table" then
		for _, id in data.purchases do
			if typeof(id) == "string" then
				table.insert(list, id)
			end
		end
	end
	purchases[player] = list
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their receipts
local function save(player: Player, data: PlayerData)
	local list = purchases[player]
	if list then
		data.purchases = table.clone(list)
	end
end

local function unload(player: Player)
	purchases[player] = nil
end

function PurchaseService.Start()
	DataService.Register({ name = "PurchaseService", load = load, save = save, unload = unload })
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
