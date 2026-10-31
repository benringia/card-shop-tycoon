--!strict
-- The Wild valley's rules (round 2, spec 2026-10-31-wild-valley-v2-design): the trail, which biome a spot is in,
-- whether a spot is clear for scenery (off the trail, the stream, the arrival, the boss portals and boards), the
-- valley's terrain fills (Config/WildValley's plus the hills, the climbing passes and the trail) and how far a monster
-- may step. Also the Frontier's zone grid (zones in a row, their monster rings), which keeps today's map. Pure,
-- Lune-tested; configs (and TownTerrain's trail builder) passed in.
local WildValley = {}

export type Point = { x: number, z: number, y: number? }

function WildValley.zoneCenter(wild: any, index: number): Point
	return { x = wild.ORIGIN.x, z = wild.ORIGIN.z + (index - 1) * (wild.ZONE_SIZE + wild.ZONE_GAP) }
end

-- The Frontier's monster spawn spots: MONSTERS_PER_ZONE round a zone's middle, odd ones on the inner ring, even on the outer
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

-- The valley's trail: from the arrival through the three biomes (x, z and the ground's height y at each point)
function WildValley.trail(valley: any): { Point }
	return valley.TRAIL
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

-- The biome whose outline holds the point (nil: none)
function WildValley.zoneAt(valley: any, point: Point): number?
	for index, biome in valley.BIOMES do
		if WildValley.inside(biome.outline, point) then
			return index
		end
	end
	return nil
end

local function segmentDistance(p: Point, a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / lengthSq, 0, 1) else 0
	return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
end

-- The trail point `distance` studs back toward the arrival from the trail point nearest a spot (never past the
-- arrival): what a board beside the trail turns to face, so players walking up read it head on
function WildValley.backAlongTrail(valley: any, point: Point, distance: number): Point
	local trail = WildValley.trail(valley)
	local nearestIndex, nearestT, bestDistance = 2, 0, math.huge
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		local dx, dz = b.x - a.x, b.z - a.z
		local t = math.clamp(((point.x - a.x) * dx + (point.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
		local d = math.sqrt((point.x - (a.x + dx * t)) ^ 2 + (point.z - (a.z + dz * t)) ^ 2)
		if d < bestDistance then
			nearestIndex, nearestT, bestDistance = index, t, d
		end
	end
	local index, t, left = nearestIndex, nearestT, distance
	while true do
		local a, b = trail[index - 1], trail[index]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local available = t * length
		if left <= available or index == 2 then
			local along = math.max(0, available - left) / length
			return { x = a.x + (b.x - a.x) * along, z = a.z + (b.z - a.z) * along }
		end
		left -= available
		index -= 1
		t = 1
	end
end

-- Whether scenery may stand at a spot; false and why when not
function WildValley.clearOf(point: Point, valley: any): (boolean, string?)
	local trail = WildValley.trail(valley)
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
	local arrival = valley.ARRIVAL_CLEAR
	if point.x >= arrival.minX and point.x <= arrival.maxX and point.z >= arrival.minZ and point.z <= arrival.maxZ then
		return false, "in the arrival"
	end
	for _, biome in valley.BIOMES do
		if math.sqrt((point.x - biome.portal.x) ^ 2 + (point.z - biome.portal.z) ^ 2) < valley.PORTAL_CLEAR then
			return false, "by a boss portal"
		end
		if math.sqrt((point.x - biome.board.x) ^ 2 + (point.z - biome.board.z) ^ 2) < valley.BOARD_CLEAR then
			return false, "by a board"
		end
	end
	return true, nil
end

-- A biome's monster spawn spots (POPULATION.MAX of them): a grid SPOT_SPACING apart over its outline, kept SPOT_MARGIN
-- from the outline's edges, clear of the trail, stream, arrival, portals and boards, SPOT_PROP_CLEAR from every prop and
-- off the hills (so a monster's home is on gentle ground), then picked evenly from what's left
function WildValley.zoneSpots(valley: any, index: number): { Point }
	local outline = valley.BIOMES[index].outline
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in outline do
		minX, maxX, minZ, maxZ = math.min(minX, p.x), math.max(maxX, p.x), math.min(minZ, p.z), math.max(maxZ, p.z)
	end
	local props: { any } = {}
	for _, name in { "PROPS", "CRYSTALS", "CHARRED", "SHARDS", "VENTS" } do
		for _, prop in valley[name] do
			table.insert(props, prop)
		end
	end
	local function suits(p: Point): boolean
		if not WildValley.inside(outline, p) or not WildValley.clearOf(p, valley) then
			return false
		end
		for i = 1, #outline do
			if segmentDistance(p, outline[i], outline[i % #outline + 1]) < valley.SPOT_MARGIN then
				return false
			end
		end
		for _, prop in props do
			if math.sqrt((p.x - prop.x) ^ 2 + (p.z - prop.z) ^ 2) < valley.SPOT_PROP_CLEAR then
				return false
			end
		end
		for _, hill in valley.HILLS do
			if math.sqrt((p.x - hill.x) ^ 2 + (p.z - hill.z) ^ 2) < hill.radius + 2 then
				return false
			end
		end
		return true
	end
	local candidates: { Point } = {}
	local z = minZ
	while z <= maxZ do
		local x = minX
		while x <= maxX do
			local p = { x = x, z = z }
			if suits(p) then
				table.insert(candidates, p)
			end
			x += valley.SPOT_SPACING
		end
		z += valley.SPOT_SPACING
	end
	local count = valley.POPULATION.MAX
	local spots: { Point } = {}
	for k = 1, math.min(count, #candidates) do
		table.insert(spots, candidates[math.floor((k - 1) * #candidates / count) + 1])
	end
	return spots
end

-- Whether a monster may take a step from ground at fromY to ground at toY (no climbing cliffs or dropping off shelves)
function WildValley.canStep(fromY: number, toY: number, maxStep: number): boolean
	return math.abs(toY - fromY) <= maxStep
end

-- A slab tilted from a's ground to b's, exactly as long as the run: no overhang past either end, so no step where it
-- meets the floor above (the trail builder's slabs reach half their width past each end)
local function ramp(a: Point, b: Point, width: number, depth: number, lift: number, material: string): { [string]: any }
	local dx, dz = b.x - a.x, b.z - a.z
	local run = math.sqrt(dx * dx + dz * dz)
	local rise = (b.y :: number) - (a.y :: number)
	local pitch = math.atan2(rise, run)
	return {
		shape = "Block",
		x = (a.x + b.x) / 2,
		y = ((a.y :: number) + (b.y :: number)) / 2 - lift - depth / 2 / math.cos(pitch),
		z = (a.z + b.z) / 2,
		size = { x = width, y = depth, z = math.sqrt(run * run + rise * rise) },
		yaw = math.deg(math.atan2(-dx, -dz)),
		pitch = math.deg(pitch),
		material = material,
	}
end

-- A wall along each side of a climbing pass, from the lower floor's bottom to above the upper ground. It starts where
-- it leaves the lower biome (inside it, it would stand free like a pillar) and reaches its own thickness past its ends
-- otherwise, so it meets the cliffs round the biomes it joins
local function passWalls(ops: { any }, a: Point, b: Point, valley: any, material: string, lowerZone: number)
	local pass = valley.PASS
	local dx, dz = b.x - a.x, b.z - a.z
	local run = math.sqrt(dx * dx + dz * dz)
	local yaw = math.atan2(-dx, -dz)
	local acrossX, acrossZ = math.cos(yaw), -math.sin(yaw) -- the slab's own +X, square to the trail
	local bottom = math.min(a.y :: number, b.y :: number) - valley.SURFACE_LIFT - 4
	local top = math.max(a.y :: number, b.y :: number) + pass.wallHeight
	local offset = pass.width / 2 + pass.wall / 2
	local lower = valley.BIOMES[lowerZone].outline
	for _, side in { -1, 1 } do
		local startT = 0
		while startT < 1 and WildValley.inside(lower, { x = a.x + dx * startT + acrossX * offset * side, z = a.z + dz * startT + acrossZ * offset * side }) do
			startT += 1 / 64
		end
		local from = startT * run - (if startT == 0 then pass.wall else 0)
		local to = run + pass.wall
		local middle = (from + to) / 2 / run
		table.insert(ops, {
			shape = "Block",
			x = a.x + dx * middle + acrossX * offset * side,
			y = (bottom + top) / 2,
			z = a.z + dz * middle + acrossZ * offset * side,
			size = { x = pass.wall, y = top - bottom, z = to - from },
			yaw = math.deg(yaw),
			material = material,
		})
	end
end

-- A point `distance` studs from a toward b, at a's height
local function toward(a: Point, b: Point, distance: number): Point
	local dx, dz = b.x - a.x, b.z - a.z
	local length = math.sqrt(dx * dx + dz * dz)
	return { x = a.x + dx / length * distance, z = a.z + dz / length * distance, y = a.y }
end

-- The valley's terrain fills in order: Config/WildValley's TERRAIN, the hills, the trail (a pass where it climbs: a
-- wide ramp in the upper biome's floor, walls each side and the trail on it; elsewhere `segment`, TownTerrain's trail
-- slab, started and ended half its width short of a climb so it never pokes up beside the ramp), then CARVES
function WildValley.terrainOps(valley: any, segment: (a: any, b: any, width: number, material: string) -> any): { any }
	local ops: { any } = {}
	for _, op in valley.TERRAIN do
		table.insert(ops, op)
	end
	for _, hill in valley.HILLS do
		local ground = valley.BIOMES[WildValley.zoneAt(valley, hill) or 1].ground
		table.insert(ops, { shape = "Ball", x = hill.x, y = ground - valley.SURFACE_LIFT + hill.height - hill.radius, z = hill.z, radius = hill.radius, material = hill.material })
	end
	local trail = valley.TRAIL
	local width = valley.TRAIL_WIDTH
	local function climbs(index: number): boolean
		local a, b = trail[index - 1], trail[index]
		return a ~= nil and b ~= nil and a.y ~= b.y
	end
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		if climbs(index) then
			local upper = WildValley.zoneAt(valley, if b.y > a.y then b else a) or 1
			local lower = WildValley.zoneAt(valley, if b.y > a.y then a else b) or 1
			table.insert(ops, ramp(a, b, valley.PASS.width, valley.PASS.depth, valley.SURFACE_LIFT, valley.BIOME_FLOOR[upper]))
			passWalls(ops, a, b, valley, valley.BIOME_CLIFF[upper], lower)
			table.insert(ops, ramp(a, b, width, 4, valley.SURFACE_LIFT, valley.TRAIL_MATERIAL[upper]))
		else
			local zone = WildValley.zoneAt(valley, { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2 }) or WildValley.zoneAt(valley, b) or 1
			local from = if climbs(index - 1) then toward(a, b, width / 2) else a
			local to = if climbs(index + 1) then toward(b, a, width / 2) else b
			table.insert(ops, segment(from, to, width, valley.TRAIL_MATERIAL[zone]))
		end
	end
	for _, op in valley.CARVES do
		table.insert(ops, op)
	end
	return ops
end

return WildValley
