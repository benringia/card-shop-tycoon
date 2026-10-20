--!strict
-- Card value and price maths shared by the server (validation, customers) and the UI (showing prices).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Showcase = require(Config:WaitForChild("Showcase"))

type Card = typeof(Cards.List[1])

local CardRules = {}

function CardRules.getMarketValue(card: Card, foil: boolean): number
	return card.value * (if foil then Rarities.FOIL_MULTIPLIER else 1)
end

local function roundCents(value: number): number
	return math.round(value * 100) / 100
end

-- Showcase price: rounded to cents, between MIN_PRICE and MAX_MARKUP × market value
function CardRules.clampPrice(price: number, card: Card, foil: boolean): number
	local market = CardRules.getMarketValue(card, foil)
	return math.clamp(roundCents(price), Showcase.MIN_PRICE, roundCents(market * Showcase.MAX_MARKUP))
end

-- One +/- tap in the showcase UI, scaled to the card's value so commons and legendaries both feel right
function CardRules.getPriceStep(card: Card, foil: boolean): number
	local step = roundCents(CardRules.getMarketValue(card, foil) * Showcase.PRICE_STEP_RATIO)
	return math.max(Showcase.MIN_PRICE_STEP, step)
end

-- Whether pulling this card gets a server-wide chat announcement
function CardRules.shouldAnnounce(card: Card, foil: boolean): boolean
	local rule = Announcements.RULES[card.rarity]
	return rule == "always" or (rule == "foil" and foil)
end

return CardRules
