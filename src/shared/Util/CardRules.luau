--!strict
-- Card value maths shared by the server (paying out) and the binder UI (showing prices).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Collection = require(Config:WaitForChild("Collection"))
local Rarities = require(Config:WaitForChild("Rarities"))

type Card = typeof(Cards.List[1])

local CardRules = {}

function CardRules.getMarketValue(card: Card, foil: boolean): number
	return card.value * (if foil then Rarities.FOIL_MULTIPLIER else 1)
end

-- What quick sell pays for one copy, rounded down to the cent
function CardRules.getQuickSellValue(card: Card, foil: boolean): number
	local value = CardRules.getMarketValue(card, foil) * Collection.QUICK_SELL_RATE
	return math.max(Collection.MIN_SELL_PRICE, math.floor(value * 100 + 1e-6) / 100)
end

-- Whether pulling this card gets a server-wide chat announcement
function CardRules.shouldAnnounce(card: Card, foil: boolean): boolean
	local rule = Announcements.RULES[card.rarity]
	return rule == "always" or (rule == "foil" and foil)
end

return CardRules
