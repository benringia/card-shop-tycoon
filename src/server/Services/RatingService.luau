--!strict
-- Shop rating (spec 2026-11-06-customers-design, Util/RatingRules, Config/Customers RATING): every few seconds each
-- open shop is scored on its parts (product shelves stocked, fair prices on what's stocked, Epic / Legendary / foil
-- cards on display, happy customers over the last visits, decor at weight 0 until the Decor system), mapped to 1-5
-- stars and smoothed. The stars show on the shop's sign (PlotService.SetSignRating), the owner gets RatingUpdate for
-- the tips chip, and the gap between customers scales with it (CustomerService.UseSpawnScale). Not saved: worked out
-- live, a fresh join starts from what's on the shelves with happiness neutral.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Pricing = require(Config:WaitForChild("Pricing"))
local Products = require(Config:WaitForChild("Products"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local RatingRules = require(Shared:WaitForChild("Util"):WaitForChild("RatingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local CustomerService = require(Services:WaitForChild("CustomerService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PricingService = require(Services:WaitForChild("PricingService"))

type State = {
	rating: number?, -- nil until the first tick (then it starts at the shop's score, not at 3)
	history: { string }, -- the last visits' outcomes, newest last
	parts: { [string]: number },
	lastSent: number?,
}

local RatingService = {}

local states: { [Player]: State } = {}

local function stateOf(owner: Player): State
	local state = states[owner]
	if not state then
		state = { history = {}, parts = {} }
		states[owner] = state
	end
	return state
end

-- Each part's 0-1 score for this owner's shop right now
local function partsFor(owner: Player, state: State): { [string]: number }
	local productShelves, stocked = 0, 0
	local stockedProducts: { [string]: boolean } = {}
	local shown: { { rarity: string, foil: boolean } } = {}
	for _, shelf in PlacementService.GetShelves(owner) do
		if shelf.def.kind == "Products" then
			productShelves += 1
			local productId = shelf.productId
			if shelf.units > 0 and productId then
				stocked += 1
				stockedProducts[productId] = true
			end
		elseif PlacementService.IsCardCase(shelf) then
			for _, displayed in shelf.cards do
				local card = Cards.ById[displayed.cardId]
				if card then
					table.insert(shown, { rarity = card.rarity, foil = displayed.foil })
				end
			end
		end
	end
	local chances: { number } = {}
	for productId in stockedProducts do
		local product = Products.ById[productId]
		if product then
			local band = PriceRules.getBand(PricingService.GetPrice(owner, productId), product.marketPrice)
			table.insert(chances, if band then band.chance else 0)
		end
	end
	return {
		stocked = RatingRules.stocked(stocked, productShelves),
		prices = RatingRules.prices(chances, Pricing.BUY_BANDS[1].chance),
		displays = RatingRules.displays(CustomerConfig, shown),
		happy = RatingRules.happy(state.history),
		decor = 0, -- the Decor system's score goes here (its weight is 0 until then)
	}
end

local function send(owner: Player, state: State)
	local weights = CustomerConfig.RATING.parts
	local parts: { { name: string, score: number, weight: number } } = {}
	for _, tip in RatingRules.tips(state.parts, weights, CustomerConfig.RATING.goodFrom) do
		table.insert(parts, { name = tip.name, score = state.parts[tip.name] or 0, weight = weights[tip.name] })
	end
	Remotes.RatingUpdate:FireClient(owner, { rating = state.rating, parts = parts })
end

local function tick()
	local cfg = CustomerConfig.RATING
	for _, plot in PlotService.GetPlots() do
		local owner = plot.owner
		if not owner then
			continue
		end
		local state = stateOf(owner)
		state.parts = partsFor(owner, state)
		local target = RatingRules.score(state.parts, cfg.parts)
		local current = state.rating
		local rating = if current then RatingRules.smooth(current, target, cfg.tick, cfg.smoothSeconds) else target
		state.rating = rating
		PlotService.SetSignRating(plot, rating)
		local sent = state.lastSent
		if not sent or math.abs(rating - sent) >= cfg.sendStep then
			state.lastSent = rating
			send(owner, state)
		end
	end
end

-- The owner's rating (1-5); 3 before their shop has been scored
function RatingService.Get(owner: Player): number
	local state = states[owner]
	return if state and state.rating then state.rating else 3
end

-- The gap between customers at this owner's shop: shorter for a well-rated shop, longer for a poor one
function RatingService.SpawnScale(owner: Player): number
	return RatingRules.spawnScale(CustomerConfig, RatingService.Get(owner))
end

function RatingService.Start()
	CustomerService.UseSpawnScale(RatingService.SpawnScale)
	CustomerService.OnOutcome(function(owner, outcome)
		if not owner.Parent then
			return
		end
		local history = stateOf(owner).history
		table.insert(history, outcome)
		while #history > CustomerConfig.RATING.history do
			table.remove(history, 1)
		end
	end)
	PlotService.OnReleased(function(player, plot)
		states[player] = nil
		PlotService.SetSignRating(plot, nil)
	end)
	task.spawn(function()
		while true do
			task.wait(CustomerConfig.RATING.tick)
			tick()
		end
	end)
end

return RatingService
