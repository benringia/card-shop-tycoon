--!strict
-- A town dog's walk from one point to the next (spec 2026-11-09-tutorial-pish-design 4): straight, unless something
-- solid is in the way (the plaza fountain; since 2026-11-20 the dog house, the carts, the tables: `routeRound`), then by
-- points pushed out round it. Pure, Lune-tested; Server/Util/TownDog walks the points.
export type Point = { x: number, z: number }
export type Circle = { x: number, z: number, radius: number }

local PishPath = {}

local PUSH = 1.25 -- a detour point sits this many radii from the centre
local MAX_DEPTH = 5

-- The point on segment a-b closest to c, how far it is from c, and how far along the segment it is (0 to 1)
local function closest(a: Point, b: Point, c: Point): (Point, number, number)
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((c.x - a.x) * dx + (c.z - a.z) * dz) / lengthSq, 0, 1) else 0
	local point = { x = a.x + dx * t, z = a.z + dz * t }
	local ox, oz = point.x - c.x, point.z - c.z
	return point, math.sqrt(ox * ox + oz * oz), t
end

local function walk(from: Point, to: Point, circles: { Circle }, depth: number, out: { Point })
	-- the first thing this leg cuts through (nearest along the way); one that holds `to` is walked into straight
	local centre: Circle? = nil
	local point: Point = to
	local first = math.huge
	if depth < MAX_DEPTH then
		for _, circle in circles do
			local tx, tz = to.x - circle.x, to.z - circle.z
			if tx * tx + tz * tz >= circle.radius * circle.radius then
				local near, distance, along = closest(from, to, circle)
				if distance < circle.radius and along < first then
					centre, point, first = circle, near, along
				end
			end
		end
	end
	if not centre then
		table.insert(out, to)
		return
	end
	local radius = centre.radius
	local ox, oz = point.x - centre.x, point.z - centre.z
	local length = math.sqrt(ox * ox + oz * oz)
	if length < 1e-6 then
		-- Straight through the middle: go round on the left of the way
		ox, oz = -(to.z - from.z), to.x - from.x
		length = math.sqrt(ox * ox + oz * oz)
	end
	local detour = { x = centre.x + ox / length * radius * PUSH, z = centre.z + oz / length * radius * PUSH }
	walk(from, detour, circles, depth + 1, out)
	walk(detour, to, circles, depth + 1, out)
end

-- The points to walk through after `from`, the last one `to`, going round every circle in `circles` the way cuts
-- through (owner 2026-11-20: the dogs were "phashing through the dog house"). A `to` inside one is walked to straight.
function PishPath.routeRound(from: Point, to: Point, circles: { Circle }): { Point }
	local out = {}
	walk(from, to, circles, 0, out)
	return out
end

-- The same round one circle (the fountain)
function PishPath.route(from: Point, to: Point, centre: Point, radius: number): { Point }
	return PishPath.routeRound(from, to, { { x = centre.x, z = centre.z, radius = radius } })
end

-- A town dog's next stop (Town Chikin's, Config/Chikin TOWN.stops): its index, picked by `roll` (0-1) by weight, never
-- `current` (the stop it stands at) while there's another; nil with no stops
-- Where a shop visit comes in from and leaves by (owner 2026-11-12: "pish is phasing through items": the delivery pad
-- beside its doors): straight out from the doorway past what stands on the sidewalk (`reach` studs out from the shop
-- front) by `clearance`. `outward`: the shop's facing, a unit vector toward the street.
function PishPath.shopApproach(doorway: Point, outward: Point, reach: number, clearance: number): Point
	local out = reach + clearance
	return { x = doorway.x + outward.x * out, z = doorway.z + outward.z * out }
end

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
