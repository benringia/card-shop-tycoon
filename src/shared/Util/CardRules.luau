--!strict
-- Card value and price maths shared by the server (validation, customers) and the UI (showing prices).
-- Value comes from BeastRules, so a raised beast's level and stars raise its market value and price limits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Showcase = require(Config:WaitForChild("Showcase"))
local BeastRules = require((script.Parent :: Instance):WaitForChild("BeastRules"))

type Card = typeof(Cards.List[1])

local CardRules = {}

local function roundCents(value: number): number
	return math.round(value * 100) / 100
end

-- Market value of a plain copy (level 1, 0 stars) or a levelled card, with its grade
function CardRules.getMarketValue(card: Card, foil: boolean, level: number?, stars: number?, grade: string?): number
	return BeastRules.getValue(card, foil, level or 1, stars or BeastRules.START_STARS, grade or BeastRules.DEFAULT_GRADE)
end

-- Showcase price: rounded to cents, between MIN_PRICE and MAX_MARKUP × market value
function CardRules.clampPrice(price: number, card: Card, foil: boolean, level: number?, stars: number?, grade: string?): number
	local market = CardRules.getMarketValue(card, foil, level, stars, grade)
	return math.clamp(roundCents(price), Showcase.MIN_PRICE, roundCents(market * Showcase.MAX_MARKUP))
end

-- One +/- tap in the showcase UI, scaled to the card's value so commons and legendaries both feel right
function CardRules.getPriceStep(card: Card, foil: boolean, level: number?, stars: number?, grade: string?): number
	local step = roundCents(CardRules.getMarketValue(card, foil, level, stars, grade) * Showcase.PRICE_STEP_RATIO)
	return math.max(Showcase.MIN_PRICE_STEP, step)
end

-- Whether pulling this card gets a server-wide chat announcement
function CardRules.shouldAnnounce(card: Card, foil: boolean): boolean
	local rule = Announcements.RULES[card.rarity]
	return rule == "always" or (rule == "foil" and foil)
end

return CardRules
