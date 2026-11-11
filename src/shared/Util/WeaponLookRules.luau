--!strict
-- The weapon glow (owner 2026-11-06: an aura like the reference picture; hybrid for performance): what a weapon shows
-- at its rarity, upgrade level and grade, in hand or on the back, and which swords on screen get the full aura (your
-- own and the nearest few) while the rest show the cheap creature-style glow. Pure: `looks` is Config/WeaponLooks
-- (passed in so Lune can test it); client Util/WeaponLook draws it.

export type Layers = {
	edge: number, -- 0-1: the inner glow (the painted runes, gems, crystal) and its light's strength
	aura: number, -- 0-1: the aura's density (0: none; 1: the full blaze)
	auraSize: number, -- its flames' size (1 in hand; smaller on the back, so the blade shows)
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
		-- On the back less aura and no light, except an Awakened weapon: it shows off (owner, 2026-11-06), a little
		-- thinner; smaller flames there either way (owner 2026-11-11)
		aura = if place ~= "back" then aura elseif awakened then aura * looks.BACK.awakenedShare else aura * looks.BACK.auraShare,
		auraSize = if place == "back" then looks.BACK.sizeShare else 1,
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

local HIT_ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

-- The element a sword hit's particles come from (Config/SwordFx ELEMENT_HIT, owner 2026-11-08): the weapon's own; the
-- Prism Blade's any of the five (`roll` 1-5, picked at random by the caller); nil for a weapon without one
function WeaponLookRules.hitElement(element: string?, prism: boolean?, roll: number): string?
	if element then
		return element
	end
	if prism then
		return HIT_ELEMENTS[math.clamp(math.floor(roll), 1, #HIT_ELEMENTS)]
	end
	return nil
end

-- A new drop's light column (spec 4.4): seen by everyone within range of the winner, who has the cinematic instead
function WeaponLookRules.seesBeacon(distance: number, range: number, mine: boolean): boolean
	return not mine and distance <= range
end

-- Which swords get the full aura: your own always, then the nearest `nearest` others within `range` studs (set of keys)
-- A pack aura layer's ZOffset: its own (`base`, from Config/WeaponLooks ELEMENT_AURA) while its part is in view,
-- BEHIND_BODY.shift studs nearer the camera while the wearer's body hides the part
function WeaponLookRules.packZOffset(looks: any, base: number, hidden: boolean): number
	return if hidden then base + looks.BEHIND_BODY.shift else base
end

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

-- The weapon window's family icon (Config/WeaponLooks ICONS; a Config/UIIcons name)
function WeaponLookRules.familyIcon(looks: any, family: string): string
	return looks.ICONS.family[family] or looks.ICONS.unknownFamily
end

-- A perk's icon: a venom burn by its look, else by its kind
function WeaponLookRules.perkIcon(looks: any, perk: { kind: string, look: string? }): string
	local icons = looks.ICONS.perk
	return (if perk.look then icons[perk.look] else nil) or icons[perk.kind] or looks.ICONS.unknownPerk
end

return WeaponLookRules
