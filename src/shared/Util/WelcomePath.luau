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

-- How far the time-lapse has got (0 = morning, 1 = sunset): sunset is reached at 1 - SUNSET_SHARE and held
function WelcomePath.dayProgress(cfg: any, t: number): number
	return math.min(1, math.max(0, t) / (1 - cfg.SUNSET_SHARE))
end

return WelcomePath
