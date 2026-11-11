--!strict
-- Town Pish's walk from one point to the next (spec 2026-11-09-tutorial-pish-design 4): straight, unless a circle (the
-- plaza fountain) is in the way, then by points pushed out round it. Pure, Lune-tested; PishService walks the points.
export type Point = { x: number, z: number }

local PishPath = {}

local PUSH = 1.25 -- a detour point sits this many radii from the centre
local MAX_DEPTH = 5

-- The point on segment a-b closest to c, and how far it is from c
local function closest(a: Point, b: Point, c: Point): (Point, number)
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((c.x - a.x) * dx + (c.z - a.z) * dz) / lengthSq, 0, 1) else 0
	local point = { x = a.x + dx * t, z = a.z + dz * t }
	local ox, oz = point.x - c.x, point.z - c.z
	return point, math.sqrt(ox * ox + oz * oz)
end

local function walk(from: Point, to: Point, centre: Point, radius: number, depth: number, out: { Point })
	local tx, tz = to.x - centre.x, to.z - centre.z
	local point, distance = closest(from, to, centre)
	if distance >= radius or depth >= MAX_DEPTH or tx * tx + tz * tz < radius * radius then
		table.insert(out, to)
		return
	end
	local ox, oz = point.x - centre.x, point.z - centre.z
	local length = math.sqrt(ox * ox + oz * oz)
	if length < 1e-6 then
		-- Straight through the middle: go round on the left of the way
		ox, oz = -(to.z - from.z), to.x - from.x
		length = math.sqrt(ox * ox + oz * oz)
	end
	local detour = { x = centre.x + ox / length * radius * PUSH, z = centre.z + oz / length * radius * PUSH }
	walk(from, detour, centre, radius, depth + 1, out)
	walk(detour, to, centre, radius, depth + 1, out)
end

-- The points to walk through after `from`, the last one `to`. A `to` inside the circle is walked to straight.
function PishPath.route(from: Point, to: Point, centre: Point, radius: number): { Point }
	local out = {}
	walk(from, to, centre, radius, 0, out)
	return out
end

-- A town dog's next stop (Town Chikin's, Config/Chikin TOWN.stops): its index, picked by `roll` (0-1) by weight, never
-- `current` (the stop it stands at) while there's another; nil with no stops
function PishPath.pickStop(stops: { { weight: number } }, roll: number, current: number?): number?
	if #stops == 0 then
		return nil
	end
	local total = 0
	for index, stop in stops do
		if index ~= current or #stops == 1 then
			total += stop.weight
		end
	end
	local left = math.clamp(roll, 0, 0.999999) * total
	local last = nil
	for index, stop in stops do
		if index ~= current or #stops == 1 then
			last = index
			left -= stop.weight
			if left < 0 then
				return index
			end
		end
	end
	return last
end

-- When he moves on after being petted: when the last pet's hold ends (`pettedUntil`), but at most `maxHold` seconds
-- after this hold began (`holdStarted`), so one player petting him again and again can't keep him at their door
function PishPath.holdEnd(pettedUntil: number, holdStarted: number, maxHold: number): number
	return math.min(pettedUntil, holdStarted + maxHold)
end

return PishPath
