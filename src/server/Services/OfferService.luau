--!strict
-- Kid offers and bargain hunters' haggles at the register (spec 2026-11-06-customers-design). One open offer per shop,
-- answered by the owner from behind the register through OfferAction; the client only sees the asking price, the
-- counter's range and steps and the face's edges (OfferUpdate), never the kid's lowest or the bargain hunter's ceiling.
--   Kid: after paying they rip one pack at the counter (model attribute Pulled, everyone's reveal: CustomerController).
--        A Very Rare or better pull may be offered (Util/OfferRules: rarity chance x grade, under the ceilings) while
--        the owner is behind the register and no cashier rang the sale up. Accept pays the asking price, a counter at or
--        over their lowest buys it, a lower one costs a try; out of tries, declined or expired, they leave with it.
--   Bargain hunter: RegisterService opens the haggle once everything is scanned (Util/HaggleRules). Deal pays their
--        offer, a counter up to their ceiling is paid, anything else (or no answer) and they put it all back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Packs = require(Config:WaitForChild("Packs"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local HaggleRules = require(Shared:WaitForChild("Util"):WaitForChild("HaggleRules"))
local OfferRules = require(Shared:WaitForChild("Util"):WaitForChild("OfferRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PackService = require(Services:WaitForChild("PackService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Customer = CustomerService.Customer
type Plot = typeof(PlotService.GetPlots()[1])
type Pull = PackService.PullResult

type Offer = {
	id: number,
	kind: "kid" | "haggle",
	customer: Customer,
	owner: Player,
	plot: Plot,
	startedAt: number, -- when the owner first sees it (a kid's comes after the rip reveal)
	triesLeft: number,
	low: number, -- the counter's range
	high: number,
	step: number,
	edges: OfferRules.Edges,
	-- kid
	card: Pull?,
	worth: number?,
	asking: number?,
	lowest: number?,
	-- bargain hunter
	offer: number?,
	total: number?,
	ceiling: number?,
}

local OfferService = {}

local offers: { [Plot]: Offer } = {}
local histories: { [Player]: OfferRules.History } = {} -- this session's kid offers per owner (the ceilings)
local forcedRips: { [Player]: string } = {} -- Studio's /customer kid <rarity>: the next kid pulls that rarity and offers
local nextId = 0
local rng = Random.new()
local allowAction = RateLimiter.new(CustomerConfig.OFFER_ACTION_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function send(offer: Offer)
	local card = offer.card
	Remotes.OfferUpdate:FireClient(offer.owner, {
		id = offer.id,
		kind = offer.kind,
		card = if card then { cardId = card.cardId, foil = card.foil, grade = card.grade } else nil,
		asking = offer.asking,
		worth = offer.worth,
		offer = offer.offer,
		total = offer.total,
		range = { offer.low, offer.high },
		step = offer.step,
		edges = offer.edges,
		triesLeft = offer.triesLeft,
	})
end

local function close(offer: Offer)
	if offers[offer.plot] ~= offer then
		return
	end
	offers[offer.plot] = nil
	if offer.owner.Parent then
		Remotes.OfferUpdate:FireClient(offer.owner, nil)
	end
	if offer.kind == "kid" then
		CustomerService.ReleaseFromCounter(offer.customer)
	end
end

local function open(offer: Offer)
	local existing = offers[offer.plot]
	if existing then
		close(existing)
	end
	offers[offer.plot] = offer
end

local function newId(): number
	nextId += 1
	return nextId
end

local function getHistory(owner: Player): OfferRules.History
	local history = histories[owner]
	if not history then
		history = { offers = {} }
		histories[owner] = history
	end
	-- Only the last hour counts toward the ceiling
	local now = os.clock()
	for index = #history.offers, 1, -1 do
		if now - history.offers[index] >= 3600 then
			table.remove(history.offers, index)
		end
	end
	return history
end

local function rarityOrder(pull: Pull): number
	local tier = Rarities.Tiers[Cards.ById[pull.cardId].rarity]
	return if tier then tier.order else 0
end

-- The best card of the rip: rarest, then most valuable
local function bestPull(pulls: { Pull }): Pull?
	local best: Pull? = nil
	for _, pull in pulls do
		if not best or rarityOrder(pull) > rarityOrder(best) or (rarityOrder(pull) == rarityOrder(best) and Cards.ById[pull.cardId].value > Cards.ById[best.cardId].value) then
			best = pull
		end
	end
	return best
end

local function worthOf(pull: Pull): number
	return CardRules.getMarketValue(Cards.ById[pull.cardId], pull.foil, 1, BeastRules.START_STARS, pull.grade)
end

-- Kid -----------------------------------------------------------------------------------------------------------

local function buyFromKid(offer: Offer, price: number)
	local card = offer.card :: Pull
	local owner = offer.owner
	if not CardService.IsLoaded(owner) then
		return
	end
	if not EconomyService.TrySpend(owner, price) then
		notify(owner, "Not enough cash.", true)
		return
	end
	CardService.GiveCard(owner, card.cardId, card.foil, card.grade)
	local name = `{if card.foil then "foil " else ""}{Cards.ById[card.cardId].name}`
	notify(owner, string.format("You bought %s (%s) for $%.2f!", name, BeastRules.describeGrade(card.grade), price), false)
	CustomerService.ShowBubble(offer.customer, CustomerConfig.BUBBLE_HAPPY)
	close(offer)
end

local function onKidSale(customer: Customer, bought: { [string]: number }, byWorker: boolean)
	local packId: string? = nil
	for productId in bought do
		if Packs.ById[productId] then
			packId = productId
			break
		end
	end
	if not packId or not customer.alive then
		return
	end
	local owner = customer.owner
	local pulls = PackService.RollForCustomer(packId)
	local forced = forcedRips[owner]
	if forced then
		forcedRips[owner] = nil
		local pool = Cards.ByRarity[forced]
		local card = pool[rng:NextInteger(1, #pool)]
		pulls[#pulls] = { cardId = card.id, foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), card.rarity) }
	end
	local pull = bestPull(pulls)
	if not pull then
		return
	end
	-- Everyone nearby sees the rip (CustomerController)
	customer.model:SetAttribute("Pulled", `{pull.cardId}|{pull.grade}|{if pull.foil then 1 else 0}`)

	local plot = customer.plot
	if byWorker or offers[plot] or not RegisterService.IsOwnerAtRegister(owner, plot) then
		return
	end
	local rarity = Cards.ById[pull.cardId].rarity
	local history = getHistory(owner)
	local now = os.clock()
	-- A forced Studio rip skips the chance and the ceilings, not the rarity: kids only offer Very Rare or better
	local roll = if forced then -1 else rng:NextNumber()
	if not OfferRules.wantsToSell(CustomerConfig, rarity, pull.grade, roll) then
		return
	end
	if not forced and not OfferRules.allowed(CustomerConfig, history, now, rarity) then
		return
	end
	table.insert(history.offers, now)
	if rarity == "Legendary" then
		history.lastLegendary = now
	end

	local worth = worthOf(pull)
	local asking = OfferRules.asking(CustomerConfig, worth, rng:NextNumber())
	local low, high = OfferRules.counterRange(worth, asking)
	local lowest = OfferRules.lowest(CustomerConfig, worth, rng:NextNumber())
	local reveal = CustomerConfig.KID.revealSeconds
	-- Their asking price always gets the happy face
	local edges = OfferRules.moodEdges(CustomerConfig, lowest, worth)
	edges.sure = math.min(edges.sure, asking)
	local offer: Offer = {
		id = newId(),
		kind = "kid",
		customer = customer,
		owner = owner,
		plot = plot,
		startedAt = now + reveal,
		triesLeft = CustomerConfig.OFFER.retries + 1,
		low = low,
		high = high,
		step = OfferRules.step(CustomerConfig, worth),
		edges = edges,
		card = pull,
		worth = worth,
		asking = asking,
		lowest = lowest,
	}
	open(offer)
	-- The kid stays at the counter through the reveal and the offer
	CustomerService.HoldAtCounter(customer, reveal + CustomerConfig.OFFER.patience + 1)
	task.delay(reveal, function()
		if offers[plot] == offer then
			send(offer)
		end
	end)
end

local function answerKid(offer: Offer, action: string, price: number?)
	if action == "decline" then
		close(offer)
	elseif action == "accept" then
		buyFromKid(offer, offer.asking :: number)
	elseif price then
		if OfferRules.accepts(price, offer.lowest :: number) then
			buyFromKid(offer, price)
			return
		end
		offer.triesLeft -= 1
		CustomerService.ShowBubble(offer.customer, CustomerConfig.BUBBLE_REFUSE)
		if offer.triesLeft <= 0 then
			close(offer)
		else
			send(offer)
		end
	end
end

-- Bargain hunter ------------------------------------------------------------------------------------------------

local function onHaggle(plot: Plot, customer: Customer, offerPrice: number, total: number)
	if not customer.alive then
		return
	end
	local ceiling = HaggleRules.ceiling(CustomerConfig, offerPrice, total, rng:NextNumber())
	local low, high = HaggleRules.counterRange(offerPrice, total)
	-- Their own offer always gets the happy face
	local edges = HaggleRules.moodEdges(CustomerConfig, ceiling, total)
	edges.sure = math.max(edges.sure, offerPrice)
	local offer: Offer = {
		id = newId(),
		kind = "haggle",
		customer = customer,
		owner = customer.owner,
		plot = plot,
		startedAt = os.clock(),
		triesLeft = 1,
		low = low,
		high = high,
		step = OfferRules.step(CustomerConfig, total),
		edges = edges,
		offer = offerPrice,
		total = total,
		ceiling = ceiling,
	}
	open(offer)
	send(offer)
end

local function answerHaggle(offer: Offer, action: string, price: number?)
	local agreed: number? = nil
	if action == "accept" then
		agreed = offer.offer
	elseif action == "counter" and price and HaggleRules.accepts(price, offer.ceiling :: number) then
		agreed = price
	end
	close(offer)
	RegisterService.SettleHaggle(offer.plot, agreed)
end

-- The owner's answer ----------------------------------------------------------------------------------------------

local function onOfferAction(player: Player, id: unknown, action: unknown, price: unknown)
	if not allowAction(player) or typeof(id) ~= "number" then
		return
	end
	if action ~= "accept" and action ~= "counter" and action ~= "decline" then
		return
	end
	local plot = PlotService.GetPlot(player)
	local offer = if plot then offers[plot] else nil
	-- A stale id (the offer closed or changed) is ignored
	if not plot or not offer or offer.id ~= id or offer.owner ~= player or os.clock() < offer.startedAt then
		return
	end
	if not RegisterService.IsOwnerAtRegister(player, plot) then
		notify(player, "Stand behind the register to answer.", true)
		return
	end
	local counter: number? = nil
	if action == "counter" then
		-- Only inside the range worked out here; never a price the client made up
		if typeof(price) ~= "number" or price ~= price or price < offer.low - 1e-9 or price > offer.high + 1e-9 then
			return
		end
		counter = math.round(price * 100) / 100
	end
	if offer.kind == "kid" then
		answerKid(offer, action :: string, counter)
	else
		answerHaggle(offer, action :: string, counter)
	end
end

-- An offer left unanswered: the kid leaves with their card, the bargain hunter puts it all back
local function expireOffers()
	local now = os.clock()
	for _, offer in table.clone(offers) do
		if now >= offer.startedAt and OfferRules.expired(CustomerConfig, offer.startedAt, now) then
			if offer.kind == "kid" then
				CustomerService.ShowBubble(offer.customer, CustomerConfig.BUBBLE_GAVE_UP)
				close(offer)
			else
				close(offer)
				RegisterService.SettleHaggle(offer.plot, nil)
			end
		end
	end
end

-- Studio's /customer kid <rarity>: the next kid this owner sells to pulls at least that rarity and offers it
function OfferService.ForceNextKidRip(owner: Player, rarity: string): boolean
	if not Cards.ByRarity[rarity] then
		return false
	end
	forcedRips[owner] = rarity
	return true
end

function OfferService.Start()
	RegisterService.OnSaleCompleted(function(customer, bought, byWorker)
		if customer.kind == "kid" then
			onKidSale(customer, bought, byWorker)
		end
	end)
	RegisterService.OnHaggle(onHaggle)
	-- The customer left the counter for any reason (paid, gave up, removed): their offer goes with them
	CustomerService.OnLeftQueue(function(customer)
		for _, offer in table.clone(offers) do
			if offer.customer == customer then
				close(offer)
			end
		end
	end)
	Remotes.OfferAction.OnServerEvent:Connect(onOfferAction)
	Players.PlayerRemoving:Connect(function(player)
		histories[player] = nil
		forcedRips[player] = nil
		for _, offer in table.clone(offers) do
			if offer.owner == player then
				offers[offer.plot] = nil
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CustomerConfig.OFFER_CHECK_INTERVAL)
			expireOffers()
		end
	end)
end

return OfferService
