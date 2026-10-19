--!strict
-- Opens packs. Rolls happen here on the server only; the client just animates the result it's sent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local StockService = require(Services:WaitForChild("StockService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Pack = typeof(Packs.ById[""])
type Weighted = typeof(Packs.ById[""].slots[1][1])

export type PullResult = { cardId: string, foil: boolean }

local PackService = {}

local rng = Random.new()
local allowRip = RateLimiter.new(Packs.RIP_COOLDOWN)

local function rollRarity(slot: { Weighted }): string
	local total = 0
	for _, option in slot do
		total += option.weight
	end
	local roll = rng:NextNumber() * total
	for _, option in slot do
		roll -= option.weight
		if roll <= 0 then
			return option.rarity
		end
	end
	return slot[#slot].rarity
end

local function rollPack(pack: Pack): { PullResult }
	local results: { PullResult } = {}
	for _, slot in pack.slots do
		local pool = Cards.ByRarity[rollRarity(slot)]
		local card = pool[rng:NextInteger(1, #pool)]
		table.insert(results, { cardId = card.id, foil = rng:NextNumber() < Rarities.FOIL_CHANCE })
	end
	return results
end

local function onRip(player: Player)
	if not allowRip(player) then
		return
	end
	local productId = StockService.GetCarriedProductId(player)
	local pack = if productId then Packs.ById[productId] else nil
	if not productId or not pack then
		Remotes.Notify:FireClient(player, "Carry a box of packs to open one.", true)
		return
	end
	if StockService.TakeCarriedUnits(player, 1) < 1 then
		return
	end

	local results = rollPack(pack)
	for _, result in results do
		CardService.AddCard(player, result.cardId, result.foil)
	end
	Remotes.PackOpened:FireClient(player, productId, results)
end

-- Studio testing only (called by DevService): a normal roll with a foil legendary in the hit slot
function PackService.OpenTestPack(player: Player)
	local productId = "FirstSparkPack"
	local results = rollPack(Packs.ById[productId])
	local legendaries = Cards.ByRarity.Legendary
	results[#results] = { cardId = legendaries[rng:NextInteger(1, #legendaries)].id, foil = true }
	for _, result in results do
		CardService.AddCard(player, result.cardId, result.foil)
	end
	Remotes.PackOpened:FireClient(player, productId, results)
end

function PackService.Start()
	Remotes.RipPack.OnServerEvent:Connect(onRip)
end

return PackService
