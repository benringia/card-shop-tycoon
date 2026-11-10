--!strict
-- Opens packs. Rolls happen here on the server only; the client just animates the result it's sent.
-- Also announces big pulls to the server once the puller has revealed them, and keeps each player's pity: packs since
-- their last Legendary and last Epic or better (saved; Util/PityRules raises a hit slot when one is due). What's left
-- until each guarantee is on the player as the PityLegendary and PityEpic attributes, for the pack screen.
-- Pish's Luck (SetLuck, from petting Town Pish) raises a player's own packs' hit slot from Very Rare up, and a Bag pack
-- with a floor (Pish's gift) keeps its hit card at that rarity or better (Util/LuckRules; spec
-- 2026-11-09-tutorial-pish-design 5, 7). OnOpened tells the tutorial a player opened one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local Pish = require(Config:WaitForChild("Pish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local NewPulls = require(Shared:WaitForChild("Util"):WaitForChild("NewPulls"))
local PityRules = require(Shared:WaitForChild("Util"):WaitForChild("PityRules"))
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
local pityStates: { [Player]: PityRules.State } = {} -- loaded players only
local luckUntil: { [Player]: number } = {} -- os.time Pish's Luck runs out
local openedHandlers: { (player: Player, productId: string, itemId: string?) -> () } = {}

local function publishPity(player: Player, state: PityRules.State)
	local legendary, epic = PityRules.remaining(Packs.PITY, state)
	player:SetAttribute("PityLegendary", legendary)
	player:SetAttribute("PityEpic", epic)
end

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

-- A player's own pack: the hit (last) slot floored (Pish's gift) and raised while they have Pish's Luck; a customer's
-- (no player) rolls the plain odds
local function rollPack(pack: Pack, player: Player?, floor: string?): { PullResult }
	local results: { PullResult } = {}
	local lucky = player ~= nil and LuckRules.left(luckUntil[player], os.time()) > 0
	for index, slot in pack.slots do
		local odds: { Weighted } = slot
		if index == #pack.slots then
			if floor then
				odds = LuckRules.atLeast(odds, Packs.RANK, floor) :: any
			end
			if lucky then
				odds = LuckRules.boost(odds, Packs.RANK, Pish.LUCK.fromRarity, Pish.LUCK.boost) :: any
			end
		end
		local pool = Cards.ByRarity[rollRarity(odds)]
		local card = pool[rng:NextInteger(1, #pool)]
		table.insert(results, { cardId = card.id, foil = rng:NextNumber() < Rarities.FOIL_CHANCE, grade = BeastRules.rollGrade(rng:NextNumber(), card.rarity) })
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

-- itemId: the Bag item it came from (nil: ripped from a carried box)
local function deliverPack(player: Player, productId: string, results: { PullResult }, itemId: string?)
	-- Checked before the cards are added, so the results screen can mark first-ever copies NEW
	local newFlags = NewPulls.flag(results, getOwnedCardIds(player))
	CardService.AddFresh(player, results)
	queueAnnouncements(player, results)
	Remotes.PackOpened:FireClient(player, productId, results, newFlags)
	for _, handler in openedHandlers do
		task.spawn(handler, player, productId, itemId)
	end
end

-- Counts this pack towards the player's pity and, when a guarantee is due, raises its hit slot: a pity Legendary
-- rolls its grade from the stingy PITY.LEGENDARY_GRADES, a pity Epic like any Epic
local function applyPity(player: Player, results: { PullResult })
	local state = pityStates[player]
	if not state or #results == 0 then
		return -- not loaded yet: no pity, and nothing counted that could be lost
	end
	local best, bestRank = "Common", 0
	for _, result in results do
		local card = Cards.ById[result.cardId]
		local rank = if card then Packs.RANK[card.rarity] or 0 else 0
		if rank > bestRank then
			best, bestRank = card.rarity, rank
		end
	end
	local forced, after = PityRules.open(Packs.PITY, Packs.RANK, state, best)
	pityStates[player] = after
	if forced then
		local pool = Cards.ByRarity[forced]
		local grade = if forced == "Legendary"
			then BeastRules.rollGradeFrom(rng:NextNumber(), Packs.PITY.LEGENDARY_GRADES)
			else BeastRules.rollGrade(rng:NextNumber(), forced)
		results[#results] = { cardId = pool[rng:NextInteger(1, #pool)].id, foil = rng:NextNumber() < Rarities.FOIL_CHANCE, grade = grade }
	end
	publishPity(player, after)
end

-- Whether a save holds any Legendary, plain or levelled (cards on display come back to the binder on load)
local function ownsLegendary(data: DataService.PlayerData): boolean
	for cardId in data.cards or {} do
		local card = Cards.ById[cardId]
		if card and card.rarity == "Legendary" then
			return true
		end
	end
	for _, beast in data.beasts or {} do
		local card = Cards.ById[beast.cardId]
		if card and card.rarity == "Legendary" then
			return true
		end
	end
	return false
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
	local results = rollPack(pack, player)
	applyPity(player, results)
	deliverPack(player, productId, results)
end

-- A pack from the Bag (LevelUpService, after it took the item): the same roll, pity and stat as ripping one from a
-- carried box; `floor` keeps its hit card at that rarity or better (Pish's gift). Returns false (nothing rolled) for a
-- product that isn't a pack.
function PackService.OpenItemPack(player: Player, productId: string, floor: string?, itemId: string?): boolean
	local pack = Packs.ById[productId]
	if not pack then
		return false
	end
	DataService.AddStat(player, "packsOpened", 1)
	local results = rollPack(pack, player, floor)
	applyPity(player, results)
	deliverPack(player, productId, results, itemId)
	return true
end

-- Pish's Luck until os.time `untilTime` (nil: none), from petting Town Pish (PishService)
function PackService.SetLuck(player: Player, untilTime: number?)
	luckUntil[player] = untilTime
end

-- Every pack a player opens (ripped or from the Bag): the tutorial's first steps listen
function PackService.OnOpened(callback: (player: Player, productId: string, itemId: string?) -> ())
	table.insert(openedHandlers, callback)
end

-- Studio testing only (called by DevService): a normal roll with a foil legendary in the hit slot
-- A pack a customer bought and rips at the counter: the same odds, no pity (it isn't a player's pack), nothing delivered
function PackService.RollForCustomer(productId: string): { PullResult }
	local pack = Packs.ById[productId]
	return if pack then rollPack(pack) else {}
end

function PackService.OpenTestPack(player: Player)
	local productId = "FirstSparkPack"
	local results = rollPack(Packs.ById[productId])
	local legendaries = Cards.ByRarity.Legendary
	results[#results] = { cardId = legendaries[rng:NextInteger(1, #legendaries)].id, foil = true, grade = BeastRules.rollGrade(rng:NextNumber(), "Legendary") }
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
		table.insert(results, { cardId = pool[rng:NextInteger(1, #pool)].id, foil = foil, grade = BeastRules.rollGrade(rng:NextNumber(), tier.name) })
	end
	deliverPack(player, productId, results)
end

function PackService.Start()
	DataService.Register({
		name = "PackService",
		load = function(player, data)
			local state = PityRules.read(data.pity)
			-- Saves from before the first-Legendary pity: anyone who already owns a Legendary is past their first
			state.firstDone = state.firstDone or ownsLegendary(data)
			pityStates[player] = state
			publishPity(player, state)
		end,
		save = function(player, data)
			local state = pityStates[player]
			if not state then
				return -- never loaded: keep what's saved
			end
			data.pity = { legendary = state.legendary, epic = state.epic, firstDone = state.firstDone }
		end,
		unload = function(player)
			pityStates[player] = nil
		end,
	})
	Remotes.RipPack.OnServerEvent:Connect(onRip)
	Remotes.PullRevealed.OnServerEvent:Connect(onPullRevealed)
	Players.PlayerRemoving:Connect(function(player)
		pendingAnnouncements[player] = nil
		luckUntil[player] = nil
	end)
end

return PackService
