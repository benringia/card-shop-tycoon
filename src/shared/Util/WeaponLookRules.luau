--!strict
-- The glow ladder (spec 2026-11-06-weapons-round1-design 5.1): what a weapon shows at its rarity, upgrade level and
-- grade, in hand or on the back. Pure: `looks` is Config/WeaponLooks (passed in so Lune can test it); client
-- Util/WeaponLook draws it.

export type Layers = {
	edge: number, -- 0-1: how strongly the edges glow
	aura: number, -- aura particles a second (0: none)
	trailScale: number, -- the swing trail's width (1: today's)
	burst: boolean, -- an element burst on every hit
	awakened: boolean, -- the +10 effect
	twinkle: boolean, -- Grade S
	light: boolean, -- a PointLight (in hand, Epic and Legendary)
}

local WeaponLookRules = {}

-- The ladder's step for this level: 0 below `from`, then 1, 2... capped at the list's length
local function step(level: number, from: number, count: number): number
	if level < from then
		return 0
	end
	return math.min(level - from + 1, count)
end

function WeaponLookRules.layers(looks: any, rarity: string, level: number, grade: string, place: "hand" | "back"): Layers
	local ladder = looks.LADDER
	local whole = math.max(0, math.floor(level))
	local edge = looks.REST[rarity] or 0
	local edgeStep = math.min(whole, 3)
	if edgeStep > 0 then
		edge = math.max(edge, ladder.edge[edgeStep])
	end
	local auraStep = step(whole, ladder.auraFrom, #ladder.auraRate)
	local aura = if auraStep > 0 then ladder.auraRate[auraStep] else 0
	local trailStep = step(whole, ladder.trailFrom, #ladder.trailScale)
	return {
		edge = math.min(edge, 1),
		-- On the back fewer particles and no light, except an Awakened weapon: it shows off (owner, 2026-11-06)
		aura = if place == "back" and whole < ladder.awakenedAt then aura * looks.BACK.auraShare else aura,
		trailScale = if trailStep > 0 then ladder.trailScale[trailStep] else 1,
		burst = whole >= ladder.trailFrom,
		awakened = whole >= ladder.awakenedAt,
		twinkle = grade == "S",
		light = looks.LIGHT[rarity] == true and (place == "hand" or whole >= ladder.awakenedAt),
	}
end

return WeaponLookRules
