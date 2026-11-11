--!strict
-- The welcome cinematic's flight (Portal Worlds spec): the camera keys (Config/Welcome plus the player's own shop at the
-- end), a smooth curve through them, and how far the time-lapse has got. Pure, Lune-tested; WelcomeController flies it.
export type Vec = { x: number, y: number, z: number }
export type Key = { t: number, pos: Vec, look: Vec }

local WelcomePath = {}

-- The config's keys plus the shop's: `back` studs out along `outward` from the door, `up` above it, looking at the sign
function WelcomePath.keys(cfg: any, door: Vec, outward: { x: number, z: number }): { Key }
	local keys: { Key } = {}
	for _, key in cfg.KEYS do
		table.insert(keys, key)
	end
	local view = cfg.SHOP_VIEW
	table.insert(keys, {
		t = 1,
		pos = { x = door.x + outward.x * view.back, y = door.y + view.up, z = door.z + outward.z * view.back },
		look = { x = door.x, y = door.y + view.lookUp, z = door.z },
	})
	return keys
end

-- Catmull-Rom through p1..p2 (p0 and p3 shape the curve)
local function spline(p0: Vec, p1: Vec, p2: Vec, p3: Vec, u: number): Vec
	local u2, u3 = u * u, u * u * u
	local function axis(a: number, b: number, c: number, d: number): number
		return 0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u2 + (3 * b - a - 3 * c + d) * u3)
	end
	return { x = axis(p0.x, p1.x, p2.x, p3.x), y = axis(p0.y, p1.y, p2.y, p3.y), z = axis(p0.z, p1.z, p2.z, p3.z) }
end

-- The camera's position and target `t` (0..1) along the flight
function WelcomePath.sample(keys: { Key }, t: number): (Vec, Vec)
	local clamped = math.clamp(t, 0, 1)
	local index = 1
	while index < #keys - 1 and clamped > keys[index + 1].t do
		index += 1
	end
	local a, b = keys[index], keys[index + 1]
	local before, after = keys[math.max(index - 1, 1)], keys[math.min(index + 2, #keys)]
	local u = if b.t > a.t then (clamped - a.t) / (b.t - a.t) else 1
	return spline(before.pos, a.pos, b.pos, after.pos, u), spline(before.look, a.look, b.look, after.look, u)
end

local POP_FROM = 0.5 -- a card starts at half its size...
local FADE_IN_SHARE = 0.6 -- ...shows fully this far into its pop...
local FADE_OUT = 0.35 -- ...and fades over its last this many seconds (your shop's card holds to the end)

-- An ease out that overshoots a little and settles: a bounce
local function backOut(u: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

-- The place card showing `seconds` into the flight (Config/Welcome CARDS: from, to): its index, its size (bouncing in
-- over `pop` seconds) and how visible it is (0-1); nil between cards
function WelcomePath.cardAt(cards: { any }, seconds: number, pop: number): (number?, number, number)
	for index, card in cards do
		if seconds >= card.from and seconds < card.to then
			local age = seconds - card.from
			local u = math.clamp(age / pop, 0, 1)
			local scale = if u >= 1 then 1 else POP_FROM + (1 - POP_FROM) * backOut(u)
			local fadeIn = math.clamp(age / (pop * FADE_IN_SHARE), 0, 1)
			local fadeOut = if card.finale then 1 else math.clamp((card.to - seconds) / FADE_OUT, 0, 1)
			return index, scale, math.min(fadeIn, fadeOut)
		end
	end
	return nil, 0, 0
end

-- The cues (Config/Welcome CUES: at) the flight passed between `before` and `now` (seconds), in order: each fires once
function WelcomePath.crossed(cues: { any }, before: number, now: number): { any }
	local out = {}
	for _, cue in cues do
		if cue.at > before and cue.at <= now then
			table.insert(out, cue)
		end
	end
	table.sort(out, function(a, b)
		return a.at < b.at
	end)
	return out
end

-- The camera's field of view for its `speed` (studs a second) and its roll in degrees for its `turn` (its look turning,
-- degrees a second; positive to the left), within Config/Welcome LENS's limits. The roll is the camera's own
-- (CFrame.Angles' z: positive banks it left), so it leans into the turn
function WelcomePath.lens(speed: number, turn: number, cfg: any): (number, number)
	local fov = cfg.fov + math.min(cfg.maxExtra, math.max(0, speed) * cfg.fovPerSpeed)
	local roll = math.clamp(turn * cfg.rollPerTurn, -cfg.maxRoll, cfg.maxRoll)
	return fov, roll
end

-- How far the time-lapse has got (0 = morning, 1 = sunset): sunset is reached at 1 - SUNSET_SHARE and held
function WelcomePath.dayProgress(cfg: any, t: number): number
	return math.min(1, math.max(0, t) / (1 - cfg.SUNSET_SHARE))
end

return WelcomePath
