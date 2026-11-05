--!strict
-- The super moves' pure choices (spec 2026-11-05-super-moves-design, Config/SuperFx): which grade a look plays, the
-- caster's cinematic beats, and where its camera sits. Roblox-free (Lune-tested): positions are plain { x, y, z }.
local SuperFxRules = {}

export type Vec = { x: number, y: number, z: number }
export type Beats = { call: number, impact: number, back: number }

local VALID = { C = true, B = true, A = true, S = true }
local RANK = { C = 1, B = 2, A = 3, S = 4 }

-- The grade a look plays: C for none or an unknown one; with the extras switch off, no richer than LOW_GRAPHICS_GRADE
function SuperFxRules.grade(grade: string?, extrasOn: boolean, cfg: any): string
	local g = if grade and VALID[grade] then grade else "C"
	local cap = cfg.LOW_GRAPHICS_GRADE
	if not extrasOn and RANK[g] > RANK[cap] then
		return cap
	end
	return g
end

-- One look's numbers at the grade it plays
function SuperFxRules.look(cfg: any, lookId: string, grade: string?, extrasOn: boolean): any
	return cfg.LOOKS[lookId].grades[SuperFxRules.grade(grade, extrasOn, cfg)]
end

-- Seconds from the press: the call beat ends, the move lands (the wind-up's end), control comes back (`tail` later)
function SuperFxRules.beats(tier: string, tail: number, cfg: any): Beats
	local spec = cfg.TIERS[tier]
	return { call = spec.call, impact = spec.windup, back = spec.windup + tail }
end

local function add(a: Vec, b: Vec, k: number?): Vec
	local s = k or 1
	return { x = a.x + b.x * s, y = a.y + b.y * s, z = a.z + b.z * s }
end

local function flat(v: Vec): Vec
	local length = math.sqrt(v.x * v.x + v.z * v.z)
	if length < 1e-6 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = v.x / length, y = 0, z = v.z / length }
end

local UP: Vec = { x = 0, y = 1, z = 0 }

-- The camera's eye and focus for a beat: "call" and "charge" a low, close shot in front of the creature (`facing`, its
-- look direction); "impact" a wide shot from behind and beside it framing it and its target (no target: a wide shot
-- of the creature from the front). Distances in multiples of `height`.
function SuperFxRules.shot(beat: string, creature: Vec, height: number, facing: Vec, target: Vec?, cfg: any): (Vec, Vec)
	local cam = cfg.CAMERA
	local front = flat(facing)
	local chest = add(creature, UP, cam.focusHeight * height)
	if beat == "call" or beat == "charge" then
		local reach = (if beat == "call" then cam.callDistance else cam.chargeDistance) * height
		local eye = add(add(creature, front, reach), UP, cam.callHeight * height)
		return eye, chest
	end
	if not target then
		local eye = add(add(creature, front, cam.impactDistance * height), UP, cam.impactHeight * height)
		return eye, chest
	end
	local toward = flat({ x = target.x - creature.x, y = 0, z = target.z - creature.z })
	local apart = math.sqrt((target.x - creature.x) ^ 2 + (target.z - creature.z) ^ 2)
	local back = math.max(cam.impactDistance * height, apart * cam.impactReach)
	local side: Vec = { x = toward.z, y = 0, z = -toward.x } -- to its right
	local eye = add(add(add(creature, toward, -back), side, cam.impactSide * height), UP, cam.impactHeight * height)
	local focus = add({ x = (creature.x + target.x) / 2, y = (creature.y + target.y) / 2, z = (creature.z + target.z) / 2 }, UP, cam.focusHeight * height)
	return eye, focus
end

return SuperFxRules
