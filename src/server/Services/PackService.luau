--!strict
-- Opens packs. Rolls happen here on the server only; the client just animates the result it's sent.
-- Also announces big pulls to the server once the puller has revealed them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local NewPulls = require(Shared:WaitForChild("Util"):WaitForChild("NewPulls"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local StockService = require(Services:WaitForChild("StockService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Pack = typeof(Packs.ById[""])
type Weighted = typeof(Packs.ById[""].slots[1][1])

export type PullResult = { cardId: string, foil: boolean, grade: string }

local PackService = {}

local rng = Random.new()
local allowRip = RateLimiter.new(Packs.RIP_COOLDOWN)
local pendingAnnouncements: { [Player]: { PullResult } } = {}

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
		table.insert(results, { cardId = card.id, foil = rng:NextNumber() < Rarities.FOIL_CHANCE, grade = BeastRules.rollGrade(rng:NextNumber()) })
	end
	return results
end

-- Tells every other player; the puller shows their own message locally when they flip
local function announce(player: Player, pull: { cardId: string, foil: boolean })
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.PullAnnouncement:FireClient(other, player.DisplayName, pull.cardId, pull.foil)
		end
	end
end

-- Removes one matching pending pull; returns whether there was one to release
local function takePending(player: Player, cardId: string, foil: boolean): boolean
	local list = pendingAnnouncements[player]
	if not list then
		return false
	end
	for index, pull in list do
		if pull.cardId == cardId and pull.foil == foil then
			table.remove(list, index)
			return true
		end
	end
	return false
end

-- Big pulls wait for the puller to flip them so chat never announces a card before it's revealed.
-- The client can only release pulls the server actually rolled; a timeout covers players who never flip.
local function queueAnnouncements(player: Player, results: { PullResult })
	for _, result in results do
		local card = Cards.ById[result.cardId]
		if card and CardRules.shouldAnnounce(card, result.foil) then
			local list = pendingAnnouncements[player] or {}
			pendingAnnouncements[player] = list
			table.insert(list, result)
			task.delay(Announcements.REVEAL_TIMEOUT, function()
				if player.Parent and takePending(player, result.cardId, result.foil) then
					announce(player, result)
				end
			end)
		end
	end
end

local function onPullRevealed(player: Player, cardId: unknown, foil: unknown)
	if typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" then
		return
	end
	if takePending(player, cardId, foil) then
		announce(player, { cardId = cardId, foil = foil })
	end
end

-- Gives the cards, queues any big-pull announcements, and sends the result for the reveal animation
-- Cards the player has now: binder, beasts and cards on display in their cases
local function getOwnedCardIds(player: Player): { [string]: boolean }
	local owned = CardService.GetOwnedCardIds(player)
	for _, shelf in PlacementService.GetShelves(player) do
		for _, displayed in shelf.cards do
			owned[displayed.cardId] = true
		end
	end
	return owned
end

local function deliverPack(player: Player, productId: string, results: { PullResult })
	-- Checked before the cards are added, so the results screen can mark first-ever copies NEW
	local newFlags = NewPulls.flag(results, getOwnedCardIds(player))
	CardService.AddFresh(player, results)
	queueAnnouncements(player, results)
	Remotes.PackOpened:FireClient(player, productId, results, newFlags)
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

	DataService.AddStat(player, "packsOpened", 1)
	deliverPack(player, productId, rollPack(pack))
end

-- Studio testing only (called by DevService): a normal roll with a foil legendary in the hit slot
function PackService.OpenTestPack(player: Player)
	local productId = "FirstSparkPack"
	local results = rollPack(Packs.ById[productId])
	local legendaries = Cards.ByRarity.Legendary
	results[#results] = { cardId = legendaries[rng:NextInteger(1, #legendaries)].id, foil = true, grade = BeastRules.rollGrade(rng:NextNumber()) }
	deliverPack(player, productId, results)
end

-- Studio only (DevService /raritypack): one card of each rarity, rarest last, to see every reveal at once
function PackService.OpenRarityPack(player: Player, foil: boolean)
	local productId = "FirstSparkPack"
	local tiers = {}
	for name, tier in Rarities.Tiers do
		if Cards.ByRarity[name] then
			table.insert(tiers, { name = name, order = tier.order })
		end
	end
	table.sort(tiers, function(a, b)
		return a.order < b.order
	end)
	local results = {}
	for _, tier in tiers do
		local pool = Cards.ByRarity[tier.name]
		table.insert(results, { cardId = pool[rng:NextInteger(1, #pool)].id, foil = foil, grade = BeastRules.rollGrade(rng:NextNumber()) })
	end
	deliverPack(player, productId, results)
end

function PackService.Start()
	Remotes.RipPack.OnServerEvent:Connect(onRip)
	Remotes.PullRevealed.OnServerEvent:Connect(onPullRevealed)
	Players.PlayerRemoving:Connect(function(player)
		pendingAnnouncements[player] = nil
	end)
end

return PackService
