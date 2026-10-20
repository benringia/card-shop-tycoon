--!strict
-- Single cards on display. Owners move cards (fresh copies or raised beasts) from their binder into
-- card cases and price them:
--   Glass Showcase (CustomerCards): NPC customers may take a card and pay at the register.
--   Collector Case (PlayerCards):  other players buy directly, after confirming the price.
-- A raised beast moves as itself (level, XP and stars intact). PlacementService holds what's in each
-- slot and saves it; this service runs the actions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlacedShelf = typeof(PlacementService.GetShelves((nil :: any))[1])
type DisplayedCard = PlacementService.DisplayedCard

local PRICE_TOLERANCE = 0.001 -- floating point slack when comparing the price a buyer saw

local ShowcaseService = {}

local allowAction = RateLimiter.new(ShowcaseConfig.ACTION_COOLDOWN)
local allowBuy = RateLimiter.new(ShowcaseConfig.BUY_COOLDOWN)
local rng = Random.new()

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function isSlot(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= 64
end

local function getGrowth(displayed: DisplayedCard): (number, number)
	local beast = displayed.beast
	return if beast then beast.level else 1, if beast then beast.stars else BeastRules.START_STARS
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function isNear(player: Player, part: BasePart): boolean
	local root = getRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= ShowcaseConfig.BUY_DISTANCE
end

-- The owner's own card case, if they're close enough to manage it
local function getOwnCase(player: Player, shelfUid: unknown): PlacedShelf?
	if typeof(shelfUid) ~= "string" then
		return nil
	end
	local shelf = PlacementService.GetShelf(player, shelfUid)
	if not shelf or not PlacementService.IsCardCase(shelf) then
		return nil
	end
	local plot = PlotService.GetPlot(player)
	local root = getRoot(player)
	if not plot or not root or (root.Position - plot.floor.Position).Magnitude > ShowcaseConfig.BUY_DISTANCE * 3 then
		notify(player, "Go back to your shop to do that.", true)
		return nil
	end
	return shelf
end

local function describe(displayed: DisplayedCard): string
	local card = Cards.ById[displayed.cardId]
	local name = `{if displayed.foil then "foil " else ""}{card.name}`
	local beast = displayed.beast
	return if beast then `{name} ({BeastRules.describeGrowth(beast.level, beast.stars)})` else name
end

-- beastId set: that specific raised beast; nil: a fresh copy
local function onDisplayCard(player: Player, shelfUid: unknown, slot: unknown, cardId: unknown, foil: unknown, beastId: unknown)
	if not allowAction(player) or not isSlot(slot) or typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" then
		return
	end
	local card = Cards.ById[cardId]
	local shelf = getOwnCase(player, shelfUid)
	if not card or not shelf then
		return
	end
	local slotNumber = slot :: number
	if slotNumber > shelf.def.capacity or shelf.cards[slotNumber] then
		return
	end

	local beast: CardService.Beast? = nil
	if typeof(beastId) == "string" then
		local owned = CardService.GetBeast(player, beastId)
		if not owned or owned.cardId ~= cardId or owned.foil ~= foil then
			notify(player, "You don't have that beast in your binder.", true)
			return
		end
		beast = CardService.TakeBeast(player, beastId)
	elseif not CardService.TakeFresh(player, cardId, foil) then
		notify(player, "You don't have that card in your binder.", true)
		return
	end

	local level = if beast then beast.level else 1
	local stars = if beast then beast.stars else BeastRules.START_STARS
	PlacementService.SetDisplayedCard(shelf, slotNumber, {
		cardId = cardId,
		foil = foil,
		price = CardRules.clampPrice(CardRules.getMarketValue(card, foil, level, stars), card, foil, level, stars),
		beast = beast,
	})
end

local function onRemoveCard(player: Player, shelfUid: unknown, slot: unknown)
	if not allowAction(player) or not isSlot(slot) then
		return
	end
	local shelf = getOwnCase(player, shelfUid)
	local displayed = if shelf then shelf.cards[slot :: number] else nil
	if not shelf or not displayed then
		return
	end
	PlacementService.SetDisplayedCard(shelf, slot :: number, nil)
	CardService.GiveCard(player, displayed.cardId, displayed.foil, displayed.beast)
end

-- Batched so several quick +/- taps across slots arrive as one request
local function onSetPrices(player: Player, shelfUid: unknown, changes: unknown)
	if not allowAction(player) or typeof(changes) ~= "table" then
		return
	end
	local shelf = getOwnCase(player, shelfUid)
	if not shelf then
		return
	end
	for index, change in changes :: { [unknown]: unknown } do
		if typeof(index) ~= "number" or index > shelf.def.capacity or typeof(change) ~= "table" then
			break
		end
		local entry = change :: { [string]: unknown }
		local slot, price = entry.slot, entry.price
		if not isSlot(slot) or typeof(price) ~= "number" or price ~= price then
			continue
		end
		local displayed = shelf.cards[slot :: number]
		if displayed then
			local card = Cards.ById[displayed.cardId]
			local level, stars = getGrowth(displayed)
			PlacementService.SetDisplayedCard(shelf, slot :: number, {
				cardId = displayed.cardId,
				foil = displayed.foil,
				price = CardRules.clampPrice(price, card, displayed.foil, level, stars),
				beast = displayed.beast,
			})
		end
	end
end

-- Player-to-player: only from a Collector Case, only for the exact card (and beast) and price the
-- buyer confirmed
local function onBuyCard(
	buyer: Player,
	ownerUserId: unknown,
	shelfUid: unknown,
	slot: unknown,
	cardId: unknown,
	foil: unknown,
	expectedPrice: unknown,
	expectedBeastId: unknown
)
	if not allowBuy(buyer) then
		return
	end
	if typeof(ownerUserId) ~= "number" or typeof(shelfUid) ~= "string" or not isSlot(slot) then
		return
	end
	if typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" or typeof(expectedPrice) ~= "number" then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner or owner == buyer then
		return
	end
	local shelf = PlacementService.GetShelf(owner, shelfUid)
	if not shelf or shelf.def.kind ~= "PlayerCards" then
		return
	end
	local slotNumber = slot :: number
	local displayed = shelf.cards[slotNumber]
	local cardPart = shelf.cardParts[slotNumber]
	if not displayed or not cardPart or displayed.cardId ~= cardId or displayed.foil ~= foil then
		notify(buyer, "That card is no longer for sale.", true)
		return
	end
	-- The owner may have swapped in a different beast of the same card after the buyer looked
	local actualBeastId = if displayed.beast then displayed.beast.id else nil
	local wantedBeastId = if typeof(expectedBeastId) == "string" then expectedBeastId else nil
	if actualBeastId ~= wantedBeastId then
		notify(buyer, "That card is no longer for sale.", true)
		return
	end
	if math.abs(displayed.price - expectedPrice) > PRICE_TOLERANCE then
		notify(buyer, string.format("The price changed to $%.2f. Check it and try again.", displayed.price), true)
		return
	end
	if not isNear(buyer, cardPart) then
		notify(buyer, "Get closer to the case.", true)
		return
	end
	if not CardService.IsLoaded(buyer) then
		return
	end
	if not EconomyService.TrySpend(buyer, displayed.price) then
		notify(buyer, "Not enough cash.", true)
		return
	end

	PlacementService.SetDisplayedCard(shelf, slotNumber, nil)
	EconomyService.AddCash(owner, displayed.price)
	CardService.GiveCard(buyer, displayed.cardId, displayed.foil, displayed.beast)
	local priceText = string.format("$%.2f", displayed.price)
	notify(buyer, `Bought {describe(displayed)} for {priceText}!`, false)
	notify(owner, `{buyer.DisplayName} bought your {describe(displayed)} for {priceText}!`, false)
end

-- A random card from the owner's Glass Showcases, for a customer to consider
function ShowcaseService.PickCardForCustomer(owner: Player): (PlacedShelf?, number?)
	local options: { { shelf: PlacedShelf, slot: number } } = {}
	for _, shelf in PlacementService.GetShelves(owner) do
		if shelf.def.kind == "CustomerCards" then
			for slot in shelf.cards do
				table.insert(options, { shelf = shelf, slot = slot })
			end
		end
	end
	if #options == 0 then
		return nil, nil
	end
	local pick = options[rng:NextInteger(1, #options)]
	return pick.shelf, pick.slot
end

-- Customer picks the card up to pay for it. Returns nil if it's gone (someone else took it).
function ShowcaseService.TakeForCustomer(shelf: PlacedShelf, slot: number): DisplayedCard?
	local displayed = shelf.cards[slot]
	if displayed then
		PlacementService.SetDisplayedCard(shelf, slot, nil)
	end
	return displayed
end

-- Customer gave up: back in its slot, another free slot, or the owner's binder
function ShowcaseService.ReturnFromCustomer(owner: Player, shelfUid: string, slot: number, displayed: DisplayedCard)
	local shelf = PlacementService.GetShelf(owner, shelfUid)
	if shelf then
		local freeSlot = if shelf.cards[slot] then PlacementService.GetFreeSlot(shelf) else slot
		if freeSlot then
			PlacementService.SetDisplayedCard(shelf, freeSlot, displayed)
			return
		end
	end
	CardService.GiveCard(owner, displayed.cardId, displayed.foil, displayed.beast)
end

function ShowcaseService.Start()
	Remotes.DisplayCard.OnServerEvent:Connect(onDisplayCard)
	Remotes.RemoveDisplayedCard.OnServerEvent:Connect(onRemoveCard)
	Remotes.SetCardPrice.OnServerEvent:Connect(onSetPrices)
	Remotes.BuyDisplayedCard.OnServerEvent:Connect(onBuyCard)
end

return ShowcaseService
