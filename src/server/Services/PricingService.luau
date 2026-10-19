--!strict
-- Holds each player's sell price per product. Prices are mirrored to player attributes
-- ("Price_<productId>") so the client UI can show them. No saving yet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local PricingConfig = require(Config:WaitForChild("Pricing"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PriceChangedCallback = (player: Player, productId: string, price: number) -> ()

local PricingService = {}

local prices: { [Player]: { [string]: number } } = {}
local changedCallbacks: { PriceChangedCallback } = {}
local allowSet = RateLimiter.new(PricingConfig.SET_COOLDOWN)

local function attributeName(productId: string): string
	return "Price_" .. productId
end

local function setup(player: Player)
	if prices[player] then
		return
	end
	prices[player] = {}
	for _, product in Products.List do
		player:SetAttribute(attributeName(product.id), PriceRules.getDefault(product.marketPrice))
	end
end

-- Expects { [productId] = price } with at most one entry per product
local function onSetPrices(player: Player, changes: unknown)
	if not allowSet(player) or typeof(changes) ~= "table" then
		return
	end
	local playerPrices = prices[player]
	if not playerPrices then
		return
	end

	local seen = 0
	for productId, price in changes :: { [unknown]: unknown } do
		seen += 1
		if seen > #Products.List then
			break
		end
		if typeof(productId) ~= "string" or typeof(price) ~= "number" or price ~= price then
			continue
		end
		local product = Products.ById[productId]
		if not product then
			continue
		end

		local clamped = PriceRules.clamp(price, product.marketPrice)
		playerPrices[productId] = clamped
		player:SetAttribute(attributeName(productId), clamped)
		for _, callback in changedCallbacks do
			task.spawn(callback, player, productId, clamped)
		end
	end
end

function PricingService.GetPrice(player: Player, productId: string): number
	local product = Products.ById[productId]
	if not product then
		return 0
	end
	local playerPrices = prices[player]
	local price = if playerPrices then playerPrices[productId] else nil
	return price or PriceRules.getDefault(product.marketPrice)
end

function PricingService.OnPriceChanged(callback: PriceChangedCallback)
	table.insert(changedCallbacks, callback)
end

function PricingService.Start()
	Remotes.SetPrices.OnServerEvent:Connect(onSetPrices)
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		prices[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return PricingService
