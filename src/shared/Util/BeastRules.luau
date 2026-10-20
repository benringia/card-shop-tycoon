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
BeastRules.START_STARS = Beasts.START_STARS
BeastRules.GRADES = Beasts.GRADES
BeastRules.DEFAULT_GRADE = Beasts.DEFAULT_GRADE

local function isKnownCard(cardId: string): boolean
	return Cards.ById[cardId] ~= nil
end

-- grade: missing reads as no bonus
function BeastRules.getStats(card: Card, foil: boolean, level: number, stars: number, grade: string?): BeastMath.Stats
	return BeastMath.getStats(Beasts, card.rarity, card.element, foil, level, stars, grade or Beasts.DEFAULT_GRADE)
end

function BeastRules.getPower(card: Card, foil: boolean, level: number, stars: number, grade: string?): number
	return BeastMath.getPower(Beasts, BeastRules.getStats(card, foil, level, stars, grade))
end

function BeastRules.getValue(card: Card, foil: boolean, level: number, stars: number, grade: string?): number
	return BeastMath.getValue(Beasts, card.value, Rarities.FOIL_MULTIPLIER, foil, level, stars, grade or Beasts.DEFAULT_GRADE)
end

function BeastRules.isGrade(grade: unknown): boolean
	return BeastMath.isGrade(Beasts, grade)
end

-- 1 = weakest grade; 0 for an unknown one
function BeastRules.getGradeRank(grade: string): number
	return BeastMath.getGradeRank(Beasts, grade)
end

-- roll: a uniform random number in [0, 1)
function BeastRules.rollGrade(roll: number): string
	return BeastMath.rollGrade(Beasts, roll)
end

function BeastRules.describeGrade(grade: string): string
	return `Grade {grade}`
end

function BeastRules.getXpToNext(level: number): number
	return BeastMath.getXpToNext(Beasts, level)
end

function BeastRules.getCondenseCost(stars: number): number?
	return BeastMath.getCondenseCost(Beasts, stars)
end

function BeastRules.applyXp(level: number, xp: number, amount: number): (number, number)
	return BeastMath.applyXp(Beasts, level, xp, amount)
end

function BeastRules.sanitize(raw: unknown): BeastMath.BeastData?
	return BeastMath.sanitize(Beasts, raw, isKnownCard)
end

-- "Lv 6 · 2 stars" (text, because Roblox's built-in fonts can't draw a star symbol)
function BeastRules.describeGrowth(level: number, stars: number): string
	return `Lv {level} · {stars} {if stars == 1 then "star" else "stars"}`
end

-- What the player needs to do for the next star
function BeastRules.describeStarProgress(stars: number): string
	local progress = `Stars {stars}/{Beasts.MAX_STARS}`
	local cost = BeastMath.getCondenseCost(Beasts, stars)
	if not cost then
		return `{progress} · max stars`
	end
	return `{progress} · condense {cost} duplicates for the next star`
end

return BeastRules
