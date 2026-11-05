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

-- Rift Step's rifts (owner 2026-11-05, "Blink Barrage"): `hits` spots `radius` studs round the boss at its height, one
-- a hit: the first behind it (away from the caster), then zig-zagging side to side round to the last in front
function SuperFxRules.riftSpots(caster: Vec, target: Vec, hits: number, radius: number): { Vec }
	local dx, dz = target.x - caster.x, target.z - caster.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		dx, dz, length = 0, -1, 1
	end
	dx, dz = dx / length, dz / length
	local spots = {}
	for index = 1, hits do
		local along = if hits > 1 then (index - 1) / (hits - 1) else 0
		local angle = along * math.pi * (if index % 2 == 0 then 1 else -1)
		local c, s = math.cos(angle), math.sin(angle)
		local x, z = dx * c - dz * s, dx * s + dz * c
		table.insert(spots, { x = target.x + x * radius, y = target.y, z = target.z + z * radius })
	end
	return spots
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

local function gap(a: Vec, b: Vec): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

-- A shot that must also show `sky` (a look bursting high over the boss): it aims halfway up to it and backs off
-- level (never down into the ground) until both fit in the frame, never closer than it was
local function withSky(eye: Vec, focus: Vec, sky: Vec, facing: Vec, cam: any): (Vec, Vec)
	local mid = { x = (focus.x + sky.x) / 2, y = (focus.y + sky.y) / 2, z = (focus.z + sky.z) / 2 }
	local want = math.max(gap(focus, sky) / 2 / math.tan(math.rad(cam.fov / 2) * 0.6), gap(eye, focus))
	if gap(eye, mid) >= want then
		return eye, mid
	end
	local dx, dz = eye.x - mid.x, eye.z - mid.z
	local level = math.sqrt(dx * dx + dz * dz)
	local away = if level > 1e-6 then { x = dx / level, y = 0, z = dz / level } else flat({ x = -facing.x, y = 0, z = -facing.z })
	local rise = eye.y - mid.y
	local reach = math.sqrt(math.max(0, want * want - rise * rise))
	return add(add(mid, away, reach), UP, rise), mid
end

-- The camera's eye and focus for a beat: "call" and "charge" a low, close shot in front of the creature (`facing`, its
-- look direction) and round to one side; "impact" a wide shot from behind and beside it framing it and its target (no target: a wide shot
-- of the creature from the front). Distances in multiples of `height`.
local function baseShot(beat: string, creature: Vec, height: number, facing: Vec, target: Vec?, cfg: any): (Vec, Vec)
	local cam = cfg.CAMERA
	local front = flat(facing)
	local chest = add(creature, UP, cam.focusHeight * height)
	if beat == "call" or beat == "charge" then
		-- Round to one side of straight ahead, so what it faces (its target) isn't between the camera and it
		local turn = math.rad(cam.callAngle)
		local aside: Vec = {
			x = front.x * math.cos(turn) + front.z * math.sin(turn),
			y = 0,
			z = front.z * math.cos(turn) - front.x * math.sin(turn),
		}
		local reach = (if beat == "call" then cam.callDistance else cam.chargeDistance) * height
		local eye = add(add(creature, aside, reach), UP, cam.callHeight * height)
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

-- The same with `sky`, a point high over the boss it must also show (Supernova's burst): the charge and impact shots
-- look up to it as well (the call's close-up stays as it is)
function SuperFxRules.shot(beat: string, creature: Vec, height: number, facing: Vec, target: Vec?, cfg: any, sky: Vec?): (Vec, Vec)
	local eye, focus = baseShot(beat, creature, height, facing, target, cfg)
	if sky and beat ~= "call" then
		return withSky(eye, focus, sky, facing, cfg.CAMERA)
	end
	return eye, focus
end

export type Decorations = { gone: string?, soaked: string?, dodged: string? }

-- What a fight event means for the supers' lasting looks, whoever sent it (a ward running out has no sender; a boss's
-- or monster's hit goes down its own path): `gone` the fighter whose ward broke or ran out (its bubble bursts), `soaked`
-- the fighter whose ward took the hit (its bubble ripples), `dodged` the fighter a hit passed through (Eclipse, Rift Step)
function SuperFxRules.decorations(event: any): Decorations
	local out: Decorations = {}
	if typeof(event) ~= "table" then
		return out
	end
	if event.type == "shieldGone" and typeof(event.to) == "string" then
		out.gone = event.to
	end
	if typeof(event.absorbed) == "number" and event.absorbed > 0 and typeof(event.to) == "string" then
		out.soaked = event.to
	end
	if event.dodged == true and typeof(event.to) == "string" then
		out.dodged = event.to
	end
	return out
end

return SuperFxRules
