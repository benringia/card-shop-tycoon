--!strict
-- Beast stats, value and XP for game code (server and client): looks up the card's rarity,
-- element and base value, then defers to the pure BeastMath with the game's config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastMath = require((script.Parent :: Instance):WaitForChild("BeastMath"))

type Card = typeof(Cards.List[1])

local BeastRules = {}

BeastRules.MAX_LEVEL = Beasts.MAX_LEVEL
BeastRules.MAX_STARS = Beasts.MAX_STARS

local function isKnownCard(cardId: string): boolean
	return Cards.ById[cardId] ~= nil
end

function BeastRules.getStats(card: Card, foil: boolean, level: number, stars: number): BeastMath.Stats
	return BeastMath.getStats(Beasts, card.rarity, card.element, foil, level, stars)
end

function BeastRules.getValue(card: Card, foil: boolean, level: number, stars: number): number
	return BeastMath.getValue(Beasts, card.value, Rarities.FOIL_MULTIPLIER, foil, level, stars)
end

function BeastRules.getXpToNext(level: number): number
	return BeastMath.getXpToNext(Beasts, level)
end

function BeastRules.applyXp(level: number, xp: number, amount: number): (number, number)
	return BeastMath.applyXp(Beasts, level, xp, amount)
end

function BeastRules.sanitize(raw: unknown): BeastMath.BeastData?
	return BeastMath.sanitize(Beasts, raw, isKnownCard)
end

-- "Lv 6 · 2-star" (text, because Roblox's built-in fonts can't draw a star symbol)
function BeastRules.describeGrowth(level: number, stars: number): string
	return `Lv {level} · {stars}-star`
end

return BeastRules
