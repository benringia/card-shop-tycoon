--!strict
-- The Wild valley's layout rules (spec 2026-10-31-wild-valley-design): where the zones' monsters spawn (WildService
-- uses these spots), the trail and its markers, and whether a spot is clear for scenery (off the trail, the stream, the
-- boss rings and their paths, the arrival). Pure, Lune-tested; configs passed in (Config/Wild, Config/Bosses,
-- Config/WildValley).
local WildValley = {}

export type Point = { x: number, z: number }

function WildValley.zoneCenter(wild: any, index: number): Point
	return { x = wild.ORIGIN.x, z = wild.ORIGIN.z + (index - 1) * (wild.ZONE_SIZE + wild.ZONE_GAP) }
end

-- A zone's monster spawn spots: MONSTERS_PER_ZONE round its middle, odd ones on the inner ring, even on the outer
function WildValley.spawnSpots(wild: any, index: number): { Point }
	local centre = WildValley.zoneCenter(wild, index)
	local spots: { Point } = {}
	for spot = 1, wild.MONSTERS_PER_ZONE do
		local angle = (spot / wild.MONSTERS_PER_ZONE) * math.pi * 2
		local radius = wild.ZONE_SIZE * (if spot % 2 == 0 then 0.32 else 0.18)
		table.insert(spots, { x = centre.x + math.cos(angle) * radius, z = centre.z + math.sin(angle) * radius })
	end
	return spots
end

-- A zone's boss arena: off the zone's +x side, past the path from its edge
function WildValley.arenaCenter(wild: any, bosses: any, index: number): Point
	local centre = WildValley.zoneCenter(wild, index)
	return { x = centre.x + wild.ZONE_SIZE / 2 + bosses.ARENA_GAP + bosses.ARENA_RADIUS, z = centre.z }
end

-- A zone's name board: at x ZONE_SIGN_X, 4 studs in from the zone's near (-z) edge where players arrive
function WildValley.zoneSign(wild: any, valley: any, index: number): Point
	local centre = WildValley.zoneCenter(wild, index)
	return { x = centre.x + valley.ZONE_SIGN_X, z = centre.z - wild.ZONE_SIZE / 2 + 4 }
end

-- The trail: from the arrival down the valley's middle to the last zone's middle
function WildValley.trail(wild: any): { Point }
	local points: { Point } = { { x = wild.ORIGIN.x + wild.ENTRANCE_OFFSET.x, z = wild.ORIGIN.z + wild.ENTRANCE_OFFSET.z } }
	for index in wild.ZONES do
		table.insert(points, WildValley.zoneCenter(wild, index))
	end
	return points
end

-- Points along the trail every `spacing` studs, from one spacing in to the end
function WildValley.markers(trail: { Point }, spacing: number): { Point }
	local markers: { Point } = {}
	local carry = spacing / 2
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local along = carry
		while along <= length do
			local t = along / length
			table.insert(markers, { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t })
			along += spacing
		end
		carry = along - length
	end
	return markers
end

local function segmentDistance(p: Point, a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / lengthSq, 0, 1) else 0
	return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
end

-- Whether scenery may stand at a spot; false and why when not
function WildValley.clearOf(point: Point, valley: any, wild: any, bosses: any): (boolean, string?)
	local trail = WildValley.trail(wild)
	for index = 2, #trail do
		if segmentDistance(point, trail[index - 1], trail[index]) < valley.TRAIL_WIDTH / 2 + 2 then
			return false, "on the trail"
		end
	end
	local stream = valley.STREAM
	if segmentDistance(point, stream.from, stream.to) < stream.width / 2 + 2 then
		return false, "in the stream"
	end
	if math.sqrt((point.x - stream.pond.x) ^ 2 + (point.z - stream.pond.z) ^ 2) < stream.pond.radius + 2 then
		return false, "in the pond"
	end
	local half = wild.ZONE_SIZE / 2
	for index in wild.ZONES do
		local arena = WildValley.arenaCenter(wild, bosses, index)
		if math.sqrt((point.x - arena.x) ^ 2 + (point.z - arena.z) ^ 2) < bosses.ARENA_RADIUS + 2 then
			return false, "in a boss ring"
		end
		local centre = WildValley.zoneCenter(wild, index)
		local pathStart, pathEnd = centre.x + half - 2, arena.x - bosses.ARENA_RADIUS + 2
		if point.x >= pathStart and point.x <= pathEnd and math.abs(point.z - centre.z) <= 9 then
			return false, "on an arena path"
		end
	end
	local arrival = valley.ARRIVAL_CLEAR
	if point.x >= arrival.minX and point.x <= arrival.maxX and point.z >= arrival.minZ and point.z <= arrival.maxZ then
		return false, "in the arrival"
	end
	return true, nil
end

-- Whether a point is inside a polygon (even-odd rule)
function WildValley.inside(polygon: { Point }, point: Point): boolean
	local inside = false
	local j = #polygon
	for i = 1, #polygon do
		local a, b = polygon[i], polygon[j]
		if (a.z > point.z) ~= (b.z > point.z) and point.x < (b.x - a.x) * (point.z - a.z) / (b.z - a.z) + a.x then
			inside = not inside
		end
		j = i
	end
	return inside
end

return WildValley
