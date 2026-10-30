--!strict
-- The caldera's glowing cracks (caldera spec 2026-10-31): lays out branching cracks down the canyon's cliff faces and
-- across its floor from Config/Scenery CRACKS. Pure and Lune-tested; SceneryService snaps the segments onto the terrain
-- as glowing strips. `rng` returns 0..1 (Random.new(SEED):NextNumber in game), so the cracks are the same every start.
local LavaCracks = {}

export type WallPoint = { along: number, y: number }
export type Segment = { a: WallPoint, b: WallPoint, width: number }
export type FloorPoint = { x: number, z: number }
export type FloorSegment = { a: FloorPoint, b: FloorPoint, width: number }

local function between(rng: () -> number, low: number, high: number): number
	return low + (high - low) * rng()
end

local function wallLength(wall: any): number
	return math.sqrt((wall.to.x - wall.from.x) ^ 2 + (wall.to.z - wall.from.z) ^ 2)
end

-- One crack down a wall: starts near the top, walks down with sideways jitter in 4-7 steps, branching once by chance
function LavaCracks.wall(wall: any, widths: { number }, rng: () -> number): { Segment }
	local length = wallLength(wall)
	local segments: { Segment } = {}
	local function walk(start: WallPoint, steps: number, width: number)
		local point = start
		local stepDown = (wall.high - wall.low) / 7
		for _ = 1, steps do
			local nextPoint = {
				along = math.clamp(point.along + between(rng, -2.5, 2.5) / length, 0, 1),
				y = math.max(wall.low, point.y - stepDown * between(rng, 0.7, 1.3)),
			}
			table.insert(segments, { a = point, b = nextPoint, width = width })
			point = nextPoint
			if point.y <= wall.low then
				break
			end
		end
		return point
	end
	local width = between(rng, widths[1], widths[2])
	local start = { along = between(rng, 0.04, 0.96), y = between(rng, wall.high - 3, wall.high) }
	local steps = 4 + math.floor(rng() * 4)
	local before = #segments
	walk(start, steps, width)
	if rng() < 0.5 and #segments > before + 1 then
		-- a thinner branch off the crack's second joint
		walk(segments[before + 2].a, 2 + math.floor(rng() * 2), widths[1])
	end
	return segments
end

local function trailDistance(point: FloorPoint, trail: { FloorPoint }): number
	local best = math.huge
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		local dx, dz = b.x - a.x, b.z - a.z
		local t = math.clamp(((point.x - a.x) * dx + (point.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
		best = math.min(best, math.sqrt((point.x - (a.x + dx * t)) ^ 2 + (point.z - (a.z + dz * t)) ^ 2))
	end
	return best
end

-- Meandering branching cracks across the floor box, every point clear of the trail and the portal
function LavaCracks.floor(floor: any, widths: { number }, trail: { FloorPoint }, portal: FloorPoint, clearTrail: number, clearPortal: number, rng: () -> number): { FloorSegment }
	local halfX, halfZ = floor.size.x / 2, floor.size.z / 2
	local function ok(point: FloorPoint): boolean
		return math.abs(point.x - floor.centre.x) <= halfX
			and math.abs(point.z - floor.centre.z) <= halfZ
			and trailDistance(point, trail) >= clearTrail
			and math.sqrt((point.x - portal.x) ^ 2 + (point.z - portal.z) ^ 2) >= clearPortal
	end
	local segments: { FloorSegment } = {}
	local tries = 0
	local made = 0
	while made < floor.count and tries < floor.count * 20 do
		tries += 1
		local start = { x = floor.centre.x + between(rng, -halfX, halfX), z = floor.centre.z + between(rng, -halfZ, halfZ) }
		if ok(start) then
			made += 1
			local width = between(rng, widths[1], widths[2])
			local heading = between(rng, 0, math.pi * 2)
			local point = start
			for step = 1, 3 + math.floor(rng() * 3) do
				heading += between(rng, -0.7, 0.7)
				local stride = between(rng, 2.5, 4.5)
				local nextPoint = { x = point.x + math.cos(heading) * stride, z = point.z + math.sin(heading) * stride }
				if not ok(nextPoint) then
					break
				end
				table.insert(segments, { a = point, b = nextPoint, width = if step == 1 then width else width * 0.85 })
				point = nextPoint
			end
		end
	end
	return segments
end

-- Every wall's cracks (by the wall's name) and the floor's, at most CRACKS.MAX_SEGMENTS together
function LavaCracks.all(cracks: any, town: any, rng: () -> number): ({ [string]: { Segment } }, { FloorSegment })
	local trail
	for _, area in town.PORTAL_AREAS do
		if area.key == "Arena" then
			trail = area.trail
		end
	end
	local budget = cracks.MAX_SEGMENTS
	local walls: { [string]: { Segment } } = {}
	for _, wall in cracks.WALLS do
		local list: { Segment } = {}
		for _ = 1, wall.count do
			for _, segment in LavaCracks.wall(wall, cracks.WIDTH, rng) do
				if budget > 0 then
					table.insert(list, segment)
					budget -= 1
				end
			end
		end
		walls[wall.name] = list
	end
	local floor: { FloorSegment } = {}
	if trail then
		for _, segment in LavaCracks.floor(cracks.FLOOR, cracks.WIDTH, trail, trail[#trail], town.TRAIL.WIDTH / 2 + 2, town.PORTAL_SCENERY_CLEAR, rng) do
			if budget > 0 then
				table.insert(floor, segment)
				budget -= 1
			end
		end
	end
	return walls, floor
end

return LavaCracks
