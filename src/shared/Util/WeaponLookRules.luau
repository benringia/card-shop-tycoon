--!strict
-- The weapon glow (owner 2026-11-06: an aura like the reference picture; hybrid for performance): what a weapon shows
-- at its rarity, upgrade level and grade, in hand or on the back, and which swords on screen get the full aura (your
-- own and the nearest few) while the rest show the cheap creature-style glow. Pure: `looks` is Config/WeaponLooks
-- (passed in so Lune can test it); client Util/WeaponLook draws it.

export type Layers = {
	edge: number, -- 0-1: the inner glow (the painted runes, gems, crystal) and its light's strength
	aura: number, -- 0-1: the aura's density (0: none; 1: the full blaze)
	ribbons: boolean, -- +10 Awakened: flame ribbons streaming off the blade
	awakened: boolean, -- +10
	sparkles: number, -- the cheap glow's sparkles a second (creature-style)
	trailScale: number, -- the swing trail's width (1: today's)
	burst: boolean, -- an element burst on every hit
	twinkle: boolean, -- Grade S
	light: boolean, -- a PointLight (in hand, Epic and Legendary; on the back too once Awakened)
}

export type Candidate = { key: string, distance: number, mine: boolean }

local WeaponLookRules = {}

-- The ladder's step for this level: 0 below `from`, then 1, 2... capped at the list's length
local function step(level: number, from: number, count: number): number
	if level < from then
		return 0
	end
	return math.min(level - from + 1, count)
end

-- The inner glow at this level: the highest step reached, never under the rarity's rest
local function edgeAt(looks: any, rarity: string, level: number): number
	local edge = looks.REST[rarity] or 0
	if looks.REST[rarity] == nil then
		return 0
	end
	for _, point in looks.LADDER.edge do
		if level >= point[1] then
			edge = math.max(edge, point[2])
		end
	end
	return math.min(edge, 1)
end

-- The aura's density: from its first level (earlier for the rarest) it thickens each level until full
local function auraAt(looks: any, rarity: string, level: number): number
	local ladder = looks.LADDER
	local from = ladder.auraFrom[rarity] or ladder.auraFrom.default
	if level < from then
		return 0
	end
	return math.min(1, (level - from + 1) / (ladder.auraFull - from + 1))
end

function WeaponLookRules.layers(looks: any, rarity: string, level: number, grade: string, place: "hand" | "back"): Layers
	local ladder = looks.LADDER
	local whole = math.max(0, math.floor(level))
	local awakened = whole >= ladder.awakenedAt
	local trailStep = step(whole, ladder.trailFrom, #ladder.trailScale)
	local aura = auraAt(looks, rarity, whole)
	local sparkles = (looks.SPARKLES.byRarity[rarity] or 0)
		+ math.floor(whole * looks.SPARKLES.perLevel)
		+ (if grade == "S" then looks.SPARKLES.gradeS else 0)
	return {
		edge = edgeAt(looks, rarity, whole),
		-- On the back half the aura and no light, except an Awakened weapon: it shows off (owner, 2026-11-06)
		aura = if place == "back" and not awakened then aura * looks.BACK.auraShare else aura,
		ribbons = awakened,
		awakened = awakened,
		sparkles = sparkles,
		trailScale = if trailStep > 0 then ladder.trailScale[trailStep] else 1,
		burst = whole >= ladder.trailFrom,
		twinkle = grade == "S",
		light = looks.LIGHT[rarity] == true and (place == "hand" or awakened),
	}
end

-- Which pack aura a weapon wears (looks.ELEMENT_AURA, owner 2026-11-08): its element's, when it has one; nil keeps our
-- flames (no element, an element without one, or the Prism Blade's every-element flames)
function WeaponLookRules.auraStyle(looks: any, element: string?, prism: boolean?): string?
	if prism or not element or not looks.ELEMENT_AURA[element] then
		return nil
	end
	return element
end

-- How much of its pack aura a weapon of `grade` shows (looks.ELEMENT_AURA[style].byGrade, owner 2026-11-08: the green
-- glow toned down at low grades, full at S); 1 for an aura without grades and for our flames (style nil)
function WeaponLookRules.auraGrade(looks: any, style: string?, grade: string): number
	local aura = if style then looks.ELEMENT_AURA[style] else nil
	if not aura or not aura.byGrade then
		return 1
	end
	return aura.byGrade[grade] or 1
end

-- A new drop's light column (spec 4.4): seen by everyone within range of the winner, who has the cinematic instead
function WeaponLookRules.seesBeacon(distance: number, range: number, mine: boolean): boolean
	return not mine and distance <= range
end

-- Which swords get the full aura: your own always, then the nearest `nearest` others within `range` studs (set of keys)
function WeaponLookRules.fullAuras(candidates: { Candidate }, nearest: number, range: number): { [string]: boolean }
	local full: { [string]: boolean } = {}
	local others: { Candidate } = {}
	for _, candidate in candidates do
		if candidate.mine then
			full[candidate.key] = true
		elseif candidate.distance <= range then
			table.insert(others, candidate)
		end
	end
	table.sort(others, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(nearest, #others) do
		full[others[index].key] = true
	end
	return full
end

return WeaponLookRules
