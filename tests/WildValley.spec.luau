--!strict
-- The Wild valley (round 2, spec 2026-10-31-wild-valley-v2-design, the user's layout A "Winding valley"): one S-shaped
-- trail through three biomes at three heights (Config/WildValley), its rules in Util/WildValley, the ground modelled by
-- TownTerrain.groundAt over the valley's fills. The Frontier keeps today's zone grid (its spawn ring is pinned here too).
local wild = require("../src/shared/Config/Wild")
local bosses = require("../src/shared/Config/Bosses")
local valley = require("../src/shared/Config/WildValley")
local WildValley = require("../src/shared/Util/WildValley")
local TownTerrain = require("../src/shared/Util/TownTerrain")
local town = require("../src/shared/Config/Town")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

-- A seeded 0..1 random (Lune has no Random): the game passes Random.new(seed):NextNumber
local function lcg(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- The Wild boss whose arena is at the end of this zone
local function bossOf(zone: number): any
	for _, boss in bosses.BOSSES do
		if (boss :: any).place == "Wild" and boss.zone == zone then
			return boss
		end
	end
	error(`no Wild boss in zone {zone}`)
end

-- An inner piece's rules (spec 2026-11-01-wild-bosses-arenas-design): clear of the fight, the path and the way home
local function checkClear(x: number, z: number, ringRadius: number, label: string)
	local distance = math.sqrt(x * x + z * z)
	assert(distance > ringRadius + 4 and distance > bosses.ARENA_RADIUS + 2, label .. " stands in the fight")
	assert(not (x < -bosses.ARENA_RADIUS and math.abs(z) < 8), label .. " blocks the path home")
	local home = valley.ARENA_HOME.distance
	assert(math.sqrt((x + home) ^ 2 + z * z) >= 8, label .. " crowds the way home")
end

local OPS = WildValley.terrainOps(valley, TownTerrain.trailSegment)

local function allProps(): { any }
	return WildValley.scenery(valley)
end

local function distanceToSegment(p: any, a: any, b: any): number
	local dx, dz = b.x - a.x, b.z - a.z
	local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
end

return {
	["spawn spots match today's ring"] = function()
		local spots = WildValley.spawnSpots(wild, 1)
		expect.equal(#spots, wild.MONSTERS_PER_ZONE, "one per monster")
		local centre = WildValley.zoneCenter(wild, 1)
		local angle = 1 / wild.MONSTERS_PER_ZONE * math.pi * 2
		expect.near(spots[1].x, centre.x + math.cos(angle) * wild.ZONE_SIZE * 0.18, 1e-9, "spot 1 x (odd: the inner ring)")
		expect.near(spots[1].z, centre.z + math.sin(angle) * wild.ZONE_SIZE * 0.18, 1e-9, "spot 1 z")
		expect.near(spots[2].x, centre.x + math.cos(angle * 2) * wild.ZONE_SIZE * 0.32, 1e-9, "spot 2 x (even: the outer ring)")
		expect.near(WildValley.zoneCenter(wild, 2).z - centre.z, wild.ZONE_SIZE + wild.ZONE_GAP, 1e-9, "zones in a row along z")
	end,

	["each biome is at least 200 studs across and stands at its height"] = function()
		local heights = { 0, 15, 35 }
		for index, biome in valley.BIOMES do
			expect.equal(biome.ground, heights[index], `biome {index} height`)
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in biome.outline do
				minX, maxX, minZ, maxZ = math.min(minX, p.x), math.max(maxX, p.x), math.min(minZ, p.z), math.max(maxZ, p.z)
			end
			assert(math.max(maxX - minX, maxZ - minZ) >= 200, `biome {index} is {maxX - minX} x {maxZ - minZ}`)
			local ground = TownTerrain.groundAt(OPS, biome.centre.x, biome.centre.z)
			assert(ground and math.abs(ground - biome.ground) <= 1, `biome {index} centre draws at {ground}`)
			expect.equal(WildValley.zoneAt(valley, biome.centre), index, `biome {index} centre`)
		end
		expect.equal(WildValley.zoneAt(valley, { x = 0, z = 0 }), nil, "the town is no biome")
	end,

	["the trail turns right into the gorge, then left onto the ridge"] = function()
		-- facing +z, right is -x: in (x, z) a right turn has a positive cross product
		local function turn(a: any, b: any): (number, number)
			local cross = a.x * b.z - a.z * b.x
			local cos = (a.x * b.x + a.z * b.z) / (math.sqrt(a.x ^ 2 + a.z ^ 2) * math.sqrt(b.x ^ 2 + b.z ^ 2))
			return cross, math.deg(math.acos(cos))
		end
		local m, g, r = valley.BIOMES[1].centre, valley.BIOMES[2].centre, valley.BIOMES[3].centre
		local cross1, angle1 = turn({ x = 0, z = 1 }, { x = g.x - m.x, z = g.z - m.z })
		assert(cross1 > 0 and angle1 >= 45, `into the gorge: cross {cross1}, {angle1} degrees`)
		local cross2, angle2 = turn({ x = g.x - m.x, z = g.z - m.z }, { x = r.x - g.x, z = r.z - g.z })
		assert(cross2 < 0 and angle2 >= 45, `onto the ridge: cross {cross2}, {angle2} degrees`)
	end,

	["the ridge can't be seen from the arrival"] = function()
		local from = valley.TRAIL[1]
		local to = valley.BIOMES[3].centre
		local blocked = false
		for step = 1, 99 do
			local t = step / 100
			local x, z = from.x + (to.x - from.x) * t, from.z + (to.z - from.z) * t
			local sight = (from.y + 5) + ((valley.BIOMES[3].ground + 5) - (from.y + 5)) * t
			local top = TownTerrain.topAt(OPS, x, z)
			blocked = blocked or (top ~= nil and top > sight)
		end
		assert(blocked, "a straight look from the arrival reaches the ridge")
	end,

	["the trail climbs gently, with no step, and stays inside the edge"] = function()
		local trail = WildValley.trail(valley)
		for index = 2, #trail do
			local a, b = trail[index - 1], trail[index]
			local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			local last = TownTerrain.groundAt(OPS, a.x, a.z) :: number
			for step = 1, math.floor(length / 2) do
				local t = step * 2 / length
				local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
				local ground = TownTerrain.groundAt(OPS, x, z) :: number
				assert(math.abs(ground - last) <= 2 * math.tan(math.rad(25)), `a step at {x}, {z}: {last} to {ground}`)
				assert(WildValley.inside(valley.EDGE, { x = x, z = z }), `the trail leaves the edge at {x}, {z}`)
				last = ground
			end
		end
	end,

	["monsters refuse a step up or down past the limit"] = function()
		expect.equal(WildValley.canStep(0, 1.5, valley.MAX_STEP), true, "a gentle rise")
		expect.equal(WildValley.canStep(15, 0, valley.MAX_STEP), false, "off a shelf")
		expect.equal(WildValley.canStep(0, -5, valley.MAX_STEP), false, "into the stream bed (water is ignored)")
		expect.equal(WildValley.canStep(0, nil, valley.MAX_STEP), false, "no ground found (a drop or inside a cliff)")
	end,

	["each arena copy is walled in round its clearing, its ring and its way home inside"] = function()
		local clearing = valley.ARENA_CLEARING
		for zone = 1, 3 do
			local half = clearing.size[zone] / 2
			assert(valley.ARENA_HOLD >= half * math.sqrt(2), `zone {zone}: a player in a clearing's corner still holds the copy`)
			for copy = 1, bosses.ARENA_COPIES do
				local c = WildValley.arenaCopyCenter(valley, zone, copy)
				local edge = WildValley.arenaEdge(valley, zone, copy)
				expect.equal(WildValley.inside(edge, c), true, `copy {zone}/{copy}'s middle`)
				local home = { x = c.x - valley.ARENA_HOME.distance, z = c.z }
				expect.equal(WildValley.inside(edge, home), true, `copy {zone}/{copy}'s way home`)
				for _, p in edge do
					assert(math.abs(p.x - c.x) <= half and math.abs(p.z - c.z) <= half, "the wall stands on the clearing")
					assert(math.sqrt((p.x - c.x) ^ 2 + (p.z - c.z) ^ 2) <= valley.ARENA_HOLD, "the walls keep players where they hold the copy")
				end
			end
		end
	end,

	-- Looked at straight down from the camera's full zoom (128 studs), a copy's ground must not end in empty sky: a flat
	-- part runs on past the walls into the haze (a part: terrain that wide is about 86k more cells), just under the
	-- clearing's terrain, while the invisible walls stay round the clearing
	["an arena copy's ground runs on past its walls, its play area stays the clearing"] = function()
		local clearing = valley.ARENA_CLEARING
		for zone = 1, 3 do
			local c = WildValley.arenaCopyCenter(valley, zone, 1)
			local apron = WildValley.arenaApron(valley, zone, 1)
			assert(apron.size >= 360 and apron.size > clearing.size[zone] + 150, `zone {zone}: its ground ends in view from above`)
			assert(apron.size < valley.ARENA_FIELD.spacing, `zone {zone}: copies' grounds would overlap`)
			expect.equal(apron.x, c.x, `zone {zone}: centred on its copy`)
			expect.equal(apron.material, clearing.materials[zone], `zone {zone}: in its clearing's material`)
			-- a part's material draws lighter or duller than terrain's, so each zone's colour is matched by eye
			assert(type(apron.color) == "table" and #apron.color == 3, `zone {zone}: no colour matched to its terrain`)
			-- just under the drawn ground (terrain draws SURFACE_LIFT above its fill), so no step shows at the clearing's edge
			local ground = TownTerrain.groundAt(OPS, c.x, c.z) :: number
			local apronTop = apron.y + apron.thickness / 2
			assert(apronTop < ground and apronTop >= ground - 1, `zone {zone}: its top at {apronTop}, the drawn ground at {ground}`)
		end
	end,

	-- The walls are separate pieces with gaps, and the hollow's roof doesn't collide: a square of invisible walls round
	-- the clearing let a player walk out between two stalagmites into the open sky past the dome. The invisible walls
	-- ring each arena just inside its innermost wall row instead, its fight and its way home inside
	["the invisible walls ring each arena inside its wall row"] = function()
		for zone = 1, 3 do
			local inner = math.huge
			for _, row in valley.ARENA_DRESSING[zone].walls do
				inner = math.min(inner, row.radius)
			end
			for copy = 1, bosses.ARENA_COPIES do
				local c = WildValley.arenaCopyCenter(valley, zone, copy)
				local edge = WildValley.arenaEdge(valley, zone, copy)
				assert(#edge >= 16, `zone {zone}: {#edge} sides`)
				for _, p in edge do
					expect.near(math.sqrt((p.x - c.x) ^ 2 + (p.z - c.z) ^ 2), inner - valley.ARENA_EDGE_INSET, 1e-6, `zone {zone}: off the ring`)
				end
				local home = valley.ARENA_HOME.distance
				expect.equal(WildValley.inside(edge, { x = c.x - home - 2, z = c.z }), true, `zone {zone}: its way home outside`)
				expect.equal(WildValley.inside(edge, { x = c.x, z = c.z + bosses.ARENA_RADIUS + 2 }), true, `zone {zone}: its fence outside`)
				expect.equal(WildValley.inside(edge, { x = c.x + inner, z = c.z }), false, `zone {zone}: reaches its walls`)
			end
		end
	end,

	-- The hollow's roof is a dome (rig of build_arena_props.py cave_dome): a hung piece's top meets the ceiling over it,
	-- never inside the rock or above the roof
	["the hollow's cocoons hang from its ceiling"] = function()
		local hung = 0
		for seed = 1, 4 do
			for _, piece in WildValley.arenaDressing(valley, bossOf(2).ringRadius, 2, lcg(seed)) do
				if piece.model == "Cocoon" then
					hung += 1
					local r = math.sqrt(piece.x ^ 2 + piece.z ^ 2)
					local ceiling = WildValley.ceilingAt(valley, 2, r) :: number
					local top = (piece.y or 0) + piece.height
					assert(top <= ceiling + 1e-9 and top >= ceiling - 1.5, `a cocoon at r {r}: top {top}, ceiling {ceiling}`)
					assert((piece.y or 0) >= 8, `a cocoon at r {r} hangs at head height`)
				end
			end
		end
		assert(hung > 0, "no cocoons")
		expect.equal(WildValley.ceilingAt(valley, 1, 10), nil, "the grove has no roof")
	end,

	["the edge closes round the biomes, the trail and the arrival; the town is outside"] = function()
		for index, biome in valley.BIOMES do
			for _, p in biome.outline do
				local dx, dz = biome.centre.x - p.x, biome.centre.z - p.z
				local length = math.sqrt(dx * dx + dz * dz)
				local inset = { x = p.x + dx / length * 3, z = p.z + dz / length * 3 }
				expect.equal(WildValley.inside(valley.EDGE, inset), true, `biome {index}'s corner {p.x}, {p.z}`)
			end
		end
		for _, p in valley.TRAIL do
			expect.equal(WildValley.inside(valley.EDGE, p), true, `trail point {p.x}, {p.z}`)
		end
		expect.equal(WildValley.inside(valley.EDGE, valley.TRAIL[1]), true, "the arrival")
		expect.equal(WildValley.inside(valley.EDGE, { x = 0, z = 0 }), false, "the town is outside")
		expect.equal(WildValley.inside(valley.EDGE, { x = 0, z = 1000 }), false, "the town's side of the valley is outside")
	end,

	["the invisible walls rise well above every biome's ground"] = function()
		local lowest, highest = math.huge, -math.huge
		for _, biome in valley.BIOMES do
			lowest, highest = math.min(lowest, biome.ground), math.max(highest, biome.ground)
		end
		assert(valley.EDGE_WALL.bottom <= lowest - 5, "the walls reach under the lowest floor")
		assert(valley.EDGE_WALL.top >= highest + 30, `the walls stand only {valley.EDGE_WALL.top - highest} studs above the ridge`)
	end,

	["the valley's terrain fits its budget"] = function()
		expect.equal(valley.SURFACE_LIFT, TownTerrain.SURFACE_LIFT, "the valley's ramps use the terrain's surface lift")
		local cells = TownTerrain.estimatedCells(OPS)
		assert(cells <= valley.MAX_CELLS, `{cells} cells (budget {valley.MAX_CELLS})`)
	end,

	["props stay off the trail, the stream, the portals, the boards and the arrival, in their own biome"] = function()
		for _, prop in allProps() do
			local ok, why = WildValley.clearOf(prop, valley)
			assert(ok, `{prop.model or "prop"} at {prop.x}, {prop.z}: {why}`)
		end
		local lists = {
			{ valley.CRYSTALS, 2 }, { valley.MUSHROOMS, 2 }, { valley.TUFTS, 2 }, { valley.MOSS_ROCKS, 2 },
			{ valley.RUINS, 1 },
			{ valley.CHARRED, 3 }, { valley.SHARDS, 3 }, { valley.VENTS, 3 }, { valley.EMBER_TREES, 3 }, { valley.EMBER_CRYSTALS, 3 }, { valley.SKELETON, 3 },
		}
		local circle = valley.STONE_CIRCLE
		table.insert(lists, { WildValley.ring(circle, circle.radius, circle.count, circle), 1 })
		for _, ring in valley.MUSHROOM_RINGS do
			table.insert(lists, { WildValley.ring(ring, ring.radius, ring.count, ring), 1 })
		end
		for _, list in lists do
			for _, prop in list[1] do
				expect.equal(WildValley.zoneAt(valley, prop), list[2], `{prop.x}, {prop.z} dresses biome {list[2]}`)
			end
		end
	end,

	["a ring spreads its pieces evenly round its centre, each facing in"] = function()
		local spots = WildValley.ring({ x = 0, z = 0 }, 10, 4, { model = "Toadstool", height = 1 })
		expect.equal(#spots, 4)
		for index, spot in spots do
			expect.near(math.sqrt(spot.x ^ 2 + spot.z ^ 2), 10, 1e-6, `spot {index} on the circle`)
			expect.equal(spot.model, "Toadstool")
			expect.equal(spot.height, 1)
			local nextSpot = spots[index % 4 + 1]
			expect.near(spot.x * nextSpot.x + spot.z * nextSpot.z, 0, 1e-6, `spots {index} and {index % 4 + 1} are 90 degrees apart`)
			-- facing in: the spot's front (-Z turned by yaw, as Roblox props face) points at the centre
			local yaw = math.rad(spot.yaw)
			local frontX, frontZ = -math.sin(yaw), -math.cos(yaw)
			expect.near(frontX * -spot.x / 10 + frontZ * -spot.z / 10, 1, 1e-6, `spot {index} faces the centre`)
		end
	end,

	["the valley's scenery is every list plus the circle and the rings"] = function()
		local total = valley.STONE_CIRCLE.count
		for _, name in valley.PROP_LISTS do
			total += #valley[name]
		end
		for _, ring in valley.MUSHROOM_RINGS do
			total += ring.count
		end
		expect.equal(#WildValley.scenery(valley), total)
	end,

	["big pieces keep spawn spots their own distance away"] = function()
		for _, prop in WildValley.scenery(valley) do
			if prop.clear then
				local zone = WildValley.zoneAt(valley, prop)
				for _, spot in WildValley.zoneSpots(valley, zone :: number) do
					local d = math.sqrt((spot.x - prop.x) ^ 2 + (spot.z - prop.z) ^ 2)
					assert(d >= prop.clear, `spawn spot {spot.x}, {spot.z} is {d} from {prop.model} (needs {prop.clear})`)
				end
			end
		end
	end,

	["every glowing piece names a known glow colour"] = function()
		local function rgb(color: any, label: string)
			expect.equal(type(color) == "table" and #color == 3, true, `{label} is three numbers`)
			for _, value in color do
				expect.equal(value >= 0 and value <= 255, true, `{label} channel {value}`)
			end
		end
		for _, name in { "teal", "purple", "blue", "ember" } do
			rgb(valley.GLOW[name], `glow {name}`)
		end
		for _, prop in WildValley.scenery(valley) do
			if prop.glow then
				rgb(valley.GLOW[prop.glow], `{prop.model or "piece"} at {prop.x}, {prop.z} glows {prop.glow}`)
			end
		end
		rgb(valley.EMBER_CRYSTAL_LOOK.color, "ember crystal")
		rgb(valley.EMBER_CRYSTAL_LOOK.tip, "ember crystal tip")
	end,

	["colliders are thin shares of a piece"] = function()
		for _, name in { "GlowMushroomTall", "GlowMushroomCluster", "MossRockA", "MossRockB", "RuinArch", "RuinPillar", "RuinPillarBroken", "RuinWall", "StandingStone", "EmberTree", "DragonSkeleton" } do
			local share = valley.COLLIDERS[name]
			expect.equal(share ~= nil, true, `{name} has a collider`)
			expect.equal(share.radius > 0 and share.radius <= 0.5, true, `{name} collider radius share`)
			expect.equal(share.height > 0 and share.height <= 1, true, `{name} collider height share`)
		end
	end,

	-- The scenery round's final review: tall pieces block players (the Meadow's landmark stones were walk-through)
	["every tall dressed piece blocks players"] = function()
		local dressed = {}
		for _, name in { "MUSHROOMS", "TUFTS", "MOSS_ROCKS", "RUINS", "EMBER_TREES", "SKELETON" } do
			for _, spot in valley[name] do
				table.insert(dressed, spot)
			end
		end
		local circle = valley.STONE_CIRCLE
		for _, spot in WildValley.ring(circle, circle.radius, circle.count, circle) do
			table.insert(dressed, spot)
		end
		for _, spot in dressed do
			if spot.height >= 6 then
				assert(valley.COLLIDERS[spot.model] ~= nil, `{spot.model} at {spot.x}, {spot.z} ({spot.height} tall) has no collider`)
			end
		end
	end,

	-- ... and the ridge's crystals neither block nor catch the camera (the gorge's old blue ones stay as they were)
	["the ridge's crystals neither block nor catch the camera"] = function()
		expect.equal(valley.EMBER_CRYSTAL_LOOK.solid, false)
	end,

	-- ... and nothing pokes into an overhang (its drawn underside sits SURFACE_LIFT below the fill's bottom); a piece's
	-- reach is about 0.45 of its height (a giant mushroom's cap)
	["pieces under an overhang stay below its drawn underside"] = function()
		for _, op in valley.TERRAIN do
			if op.overhang then
				local size = op.size :: any
				local underside = op.y - size.y / 2 - valley.SURFACE_LIFT
				for _, spot in WildValley.scenery(valley) do
					local reach = spot.height * 0.45
					local overX = math.abs(spot.x - op.x) <= size.x / 2 + reach
					local overZ = math.abs(spot.z - op.z) <= size.z / 2 + reach
					if overX and overZ then
						local top = (TownTerrain.groundAt(OPS, spot.x, spot.z) :: number) + spot.height
						assert(top <= underside, `{spot.model or "piece"} at {spot.x}, {spot.z} reaches {top}, the overhang's underside draws at {underside}`)
					end
				end
			end
		end
	end,

	-- Round 2 (spec 2026-11-05-valley-natural-design): the walls get a natural skyline of terrain lumps
	["a skyline's lumps are steady and rise above its wall"] = function()
		local first, again = WildValley.skylineOps(valley), WildValley.skylineOps(valley)
		expect.equal(#first > 0, true, "the walls have lumps")
		expect.equal(#first, #again, "the same lumps every run")
		local index = 0
		for _, line in valley.SKYLINES do
			local points = line.points
			local function nearLine(op: any): number
				local best = math.huge
				for i = 2, #points do
					best = math.min(best, distanceToSegment(op, points[i - 1], points[i]))
				end
				return best
			end
			local count = 0
			for i = 2, #points do
				local length = math.sqrt((points[i].x - points[i - 1].x) ^ 2 + (points[i].z - points[i - 1].z) ^ 2)
				count += math.floor(length / line.spacing) + 1
			end
			for _ = 1, count do
				index += 1
				local op, same = first[index], again[index]
				expect.equal(op.shape, "Ball")
				expect.equal(op.material, line.material)
				expect.equal(op.x == same.x and op.y == same.y and op.z == same.z and op.radius == same.radius, true, "steady")
				expect.equal(op.radius >= line.radius[1] and op.radius <= line.radius[2], true, `radius {op.radius}`)
				local rise = op.y + op.radius - line.top
				expect.equal(rise >= line.rise[1] - 1e-9 and rise <= line.rise[2] + 1e-9, true, `rise {rise}`)
				assert(nearLine(op) <= line.drift + 0.01, `lump at {op.x}, {op.z} strays {nearLine(op)} from its line`)
			end
		end
		expect.equal(index, #first, "one run of lumps per line")
	end,

	["skyline lumps stand outside the walkable edge"] = function()
		for _, op in WildValley.skylineOps(valley) do
			expect.equal(WildValley.inside(valley.EDGE, op), false, `lump at {op.x}, {op.z}`)
		end
	end,

	["the bridge carries the trail over the stream"] = function()
		local s, b = valley.STREAM, valley.BRIDGE
		assert(distanceToSegment(b, valley.TRAIL[1], valley.TRAIL[2]) <= 0.5, "the bridge's middle is off the trail")
		assert(distanceToSegment(b, s.from, s.to) <= s.width / 2, "the bridge's middle isn't over the stream")
	end,

	["the edge lets players into the cave mouth but not past its carve"] = function()
		local cave = valley.CAVE
		assert(WildValley.inside(valley.EDGE, { x = cave.x - 13, z = cave.z }), "an invisible wall stands across the cave mouth")
		local carve
		for _, op in valley.CARVES do
			if op.material == "Air" and op.z == cave.z then
				carve = op
			end
		end
		assert(carve, "the cave's carve")
		local back, sides = carve.x - carve.size.x / 2, carve.size.z / 2
		local deepest = math.huge
		for _, p in valley.EDGE do
			if math.abs(p.z - cave.z) <= sides then
				deepest = math.min(deepest, p.x)
			end
		end
		-- the edge wall (2 thick) stays inside the carve, in front of the cave's dark back wall
		assert(deepest - 1 > back, `the edge reaches x {deepest}, past the cave's back at {back}`)
		expect.equal(WildValley.zoneAt(valley, cave), 2, "the cave is in the gorge")
		expect.equal(cave.y, valley.BIOMES[2].ground, "the cave mouth opens at the gorge's floor")
	end,

	["the valley's effects stand in their biomes, at most 4 a biome"] = function()
		local scenery = require("../src/shared/Config/Scenery")
		local count = {}
		for _, e in scenery.EMITTERS do
			local biome = ({ WildMeadow = 1, WildGorge = 2, WildRidge = 3 })[e.area]
			if biome then
				count[biome] = (count[biome] or 0) + 1
				expect.equal(WildValley.zoneAt(valley, e), biome, `{e.kind} at {e.x}, {e.z}`)
				assert(math.abs(e.y - valley.BIOMES[biome].ground) <= 30, `{e.kind} floats at {e.y}`)
			end
		end
		for biome, n in count do
			assert(n <= 4, `biome {biome} has {n} effects`)
		end
	end,

	["every biome has 24 spawn spots well inside it, clear, on gentle ground"] = function()
		for index, biome in valley.BIOMES do
			local spots = WildValley.zoneSpots(valley, index)
			expect.equal(#spots, valley.POPULATION.MAX, `biome {index} spots`)
			for _, p in spots do
				expect.equal(WildValley.zoneAt(valley, p), index, `{p.x}, {p.z} in biome {index}`)
				assert(WildValley.clearOf(p, valley), `{p.x}, {p.z} isn't clear`)
				local here = TownTerrain.groundAt(OPS, p.x, p.z) :: number
				assert(math.abs(here - biome.ground) <= 6, `{p.x}, {p.z} draws at {here}`)
				for _, d in { { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
					local there = TownTerrain.groundAt(OPS, p.x + d[1], p.z + d[2]) :: number
					assert(math.abs(there - here) <= 2, `steep ground at {p.x}, {p.z}`)
				end
			end
		end
	end,

	["the boards and arrow posts stand beside the trail, not on it, inside the edge"] = function()
		local spots = { valley.RETURN_SIGN }
		for _, biome in valley.BIOMES do
			table.insert(spots, biome.board)
		end
		for _, post in valley.ARROWS do
			table.insert(spots, post)
			assert(#post.arms >= 2, "an arrow post names the way on and the way back")
		end
		for _, s in spots do
			local nearest = math.huge
			local trail = WildValley.trail(valley)
			for i = 2, #trail do
				nearest = math.min(nearest, distanceToSegment(s, trail[i - 1], trail[i]))
			end
			assert(nearest >= valley.TRAIL_WIDTH / 2 + 2 and nearest <= 20, `{s.x}, {s.z} is {nearest} from the trail`)
			assert(WildValley.inside(valley.EDGE, s), `{s.x}, {s.z} is outside the edge`)
			assert(distanceToSegment(s, valley.STREAM.from, valley.STREAM.to) >= valley.STREAM.width / 2 + 3, `{s.x}, {s.z} stands in the stream`)
		end
	end,

	["a board turns toward the trail where players come from"] = function()
		local t5, t6 = valley.TRAIL[5], valley.TRAIL[6]
		local back = WildValley.backAlongTrail(valley, { x = t6.x, z = t6.z }, 10)
		local length = math.sqrt((t6.x - t5.x) ^ 2 + (t6.z - t5.z) ^ 2)
		expect.near(back.x, t6.x + (t5.x - t6.x) * 10 / length, 1e-6, "10 studs back down the first pass (x)")
		expect.near(back.z, t6.z + (t5.z - t6.z) * 10 / length, 1e-6, "10 studs back down the first pass (z)")
		local start = WildValley.backAlongTrail(valley, { x = 10, z = 1135 }, valley.BOARD_FACE_BACK)
		expect.near(start.x, valley.TRAIL[1].x, 1e-6, "never past the arrival (x)")
		expect.near(start.z, valley.TRAIL[1].z, 1e-6, "never past the arrival (z)")
	end,

	["arena copies stand apart, far from the valley, each on its clearing"] = function()
		expect.equal(valley.ARENA_COPIES_FOR_TERRAIN, bosses.ARENA_COPIES, "terrain and Bosses agree")
		local centres = {}
		for zone = 1, 3 do
			for copy = 1, bosses.ARENA_COPIES do
				local c = WildValley.arenaCopyCenter(valley, zone, copy)
				for _, other in centres do
					assert(math.sqrt((c.x - other.x) ^ 2 + (c.z - other.z) ^ 2) >= valley.ARENA_FIELD.spacing, "two copies too close")
				end
				assert(not WildValley.inside(valley.EDGE, c) and c.x - 100 >= 1000, `copy {zone}/{copy} near the valley`)
				local ground = TownTerrain.groundAt(OPS, c.x, c.z)
				assert(ground and math.abs(ground - valley.ARENA_FIELD.y) <= 0.01, `copy {zone}/{copy} has no ground`)
				table.insert(centres, c)
			end
		end
	end,

	["each boss portal stands beside its biome's trail on gentle ground, its gate spot inside the edge"] = function()
		for index, biome in valley.BIOMES do
			local p = biome.portal
			expect.equal(WildValley.zoneAt(valley, p), index, `portal {index} in its biome`)
			local here = TownTerrain.groundAt(OPS, p.x, p.z) :: number
			assert(math.abs(here - biome.ground) <= 3, `portal {index} draws at {here}`)
			local dx, dz = p.faces.x - p.x, p.faces.z - p.z
			local length = math.sqrt(dx * dx + dz * dz)
			local gate = { x = p.x + dx / length * 8, z = p.z + dz / length * 8 }
			assert(WildValley.inside(valley.EDGE, gate), `portal {index}'s gate spot is outside the edge`)
			local there = TownTerrain.groundAt(OPS, gate.x, gate.z) :: number
			assert(math.abs(there - here) <= 1.5, `portal {index}'s gate spot draws at {there}, the portal at {here}`)
		end
	end,

	["town and valley terrain fit the measured budget"] = function()
		local scenery = require("../src/shared/Config/Scenery")
		local town = require("../src/shared/Config/Town")
		local TownLayout = require("../src/shared/Util/TownLayout")
		local plots = TownLayout.plotRects({ plotCount = 6, perRow = 3, plotWidth = 40, plotDepth = 40, gap = 24, streetWidth = 96 } :: any)
		local townCells = TownTerrain.estimatedCells(TownTerrain.ops(scenery, town, plots))
		local cells = TownTerrain.estimatedCells(OPS)
		assert(townCells + cells <= scenery.MAX_CELLS, `town {townCells} + valley {cells} cells over {scenery.MAX_CELLS}`)
	end,

	["each zone's arena has a look and the ridge's cracks stay inside its ring"] = function()
		expect.equal(#valley.ARENA_LOOKS, #wild.ZONES, "one arena look per zone")
		for index, look in valley.ARENA_LOOKS do
			assert(look.floorMaterial and look.pathMaterial and look.postMaterial, `zone {index}'s arena look is missing a material`)
		end
		assert(valley.ARENA_LIFT > 0 and valley.ARENA_LIFT < 0.5, "the arena floor sits just above the terrain")
		local cracks = valley.ARENA_LOOKS[3].cracks
		assert(cracks and cracks.count > 0, "the ridge arena has lava cracks")
		-- the crack box's corners stay inside the fence posts (posts at ARENA_RADIUS - 0.6)
		assert(cracks.size / 2 * math.sqrt(2) < bosses.ARENA_RADIUS - 1, "the ridge arena's cracks run past its fence")
	end,

	["markers run the whole trail"] = function()
		local trail = WildValley.trail(valley)
		local markers = WildValley.markers(trail, valley.MARKER_SPACING)
		assert(#markers >= 3, "markers")
		local first, last = trail[1], trail[#trail]
		local function dist(a, b): number
			return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		end
		assert(dist(markers[1], first) <= valley.MARKER_SPACING, "the first marker is by the arrival")
		assert(dist(markers[#markers], last) <= valley.MARKER_SPACING, "the last marker is by the trail's end")
		for index = 2, #markers do
			assert(dist(markers[index], markers[index - 1]) <= valley.MARKER_SPACING + 1e-9, "a gap in the markers")
		end
		expect.equal(WildValley.zoneAt(valley, last), #valley.BIOMES, "the trail ends on the ridge")
	end,

	-- Each arena shows its own sky while you're in one of its copies (spec 2026-11-01-wild-bosses-arenas-design)
	["an arena copy knows its zone, nowhere else is an arena"] = function()
		for zone = 1, #valley.BIOMES do
			for copy = 1, bosses.ARENA_COPIES do
				local centre = WildValley.arenaCopyCenter(valley, zone, copy)
				expect.equal(WildValley.arenaZoneAt(valley, bosses.ARENA_COPIES, centre.x, centre.z), zone, `zone {zone} copy {copy}`)
				expect.equal(WildValley.arenaZoneAt(valley, bosses.ARENA_COPIES, centre.x + 60, centre.z - 60), zone, "near its corner")
				expect.equal(WildValley.arenaZoneAt(valley, bosses.ARENA_COPIES, centre.x + valley.ARENA_HOLD + 10, centre.z), nil, "past it")
			end
		end
		expect.equal(WildValley.arenaZoneAt(valley, bosses.ARENA_COPIES, 0, 1130), nil, "the valley's arrival")
		expect.equal(WildValley.arenaZoneAt(valley, bosses.ARENA_COPIES, 0, 0), nil, "the town's plaza")
	end,

	["each arena is walled all round, its pieces clear of the fight, the path and the way home"] = function()
		for zone = 1, #valley.BIOMES do
			local dressing = valley.ARENA_DRESSING[zone]
			local ringRadius = bossOf(zone).ringRadius
			local walls, inner = 0, 0
			for _, row in dressing.walls do
				assert(2 * math.pi * row.radius / row.count <= 14, `zone {zone}: a gap in its walls`)
				assert(row.radius + 4 <= valley.ARENA_CLEARING.size[zone] / 2, `zone {zone}: a wall off its ground`)
				walls += row.count
			end
			for _, group in dressing.inner do
				inner += group.count
			end
			for seed = 1, 4 do
				local pieces = WildValley.arenaDressing(valley, ringRadius, zone, lcg(seed))
				local again = WildValley.arenaDressing(valley, ringRadius, zone, lcg(seed))
				expect.equal(#pieces, walls + inner, `zone {zone}: every piece placed`)
				expect.equal(pieces[#pieces].x, again[#again].x, "the same seed, the same layout")
				for index, piece in pieces do
					assert(type(piece.model) == "string" and piece.height > 0, "a piece without a model or size")
					if not piece.wall then
						checkClear(piece.x, piece.z, ringRadius, `zone {zone} piece {index}`)
					end
				end
			end
			for _, spot in WildValley.arenaSpots(valley, ringRadius, 10, { 40, 54 }, lcg(7)) do
				checkClear(spot.x, spot.z, ringRadius, `zone {zone} spot`)
			end
			expect.equal(dressing.roof ~= nil, zone == 2, `zone {zone}: only the hollow has a roof`)
			expect.equal(dressing.backdrop ~= nil, zone == 3, `zone {zone}: only the lava field has a backdrop`)
			assert(string.match(dressing.sound.id, "^rbxassetid://%d+$"), `zone {zone} has no ambient sound`)
			assert(dressing.sound.range > 0 and dressing.sound.range < valley.ARENA_FIELD.spacing / 2, `zone {zone}'s sound reaches the next copy`)
		end
	end,

	-- The user found the hollow and the lava field too tight with their walls 56-57 studs out: they stand well back now
	["the hollow and the lava field stand their walls well back from the fight"] = function()
		for _, zone in { 2, 3 } do
			for _, row in valley.ARENA_DRESSING[zone].walls do
				assert(row.radius >= 72, `zone {zone}: walls {row.radius} studs out`)
			end
		end
	end,

	["the arenas' fence radius agrees with Bosses"] = function()
		expect.equal(valley.ARENA_FENCE, bosses.ARENA_RADIUS, "WildValley and Bosses agree")
	end,

	["each arena's way home is in its zone's look, inside its walls"] = function()
		local home = valley.ARENA_HOME
		expect.equal(#home, 3, "one per Wild zone")
		for zone = 1, #home do
			local spot = home[zone]
			assert(fs.isFile(`assets/props/{spot.model}.rbxm`), `zone {zone}: no {spot.model} model`)
			assert((town.PORTAL_LOOKS :: any)[spot.look], `zone {zone}: no {spot.look} portal look`)
			local innerWall = math.huge
			for _, row in valley.ARENA_DRESSING[zone].walls do
				innerWall = math.min(innerWall, row.radius)
			end
			assert(home.distance >= bosses.ARENA_RADIUS + 6 and home.distance <= innerWall - 4, `zone {zone}: the way home is outside its walls`)
		end
	end,

	["every model an arena is built from is a saved prop"] = function()
		for zone, dressing in valley.ARENA_DRESSING do
			local names = {}
			for _, group in { dressing.walls, dressing.inner } do
				for _, row in group do
					for _, name in row.models do
						table.insert(names, name)
					end
				end
			end
			for _, extra in { dressing.roof, dressing.backdrop } do
				table.insert(names, extra.model)
			end
			for _, name in names do
				assert(fs.isFile(`assets/props/{name}.rbxm`), `zone {zone}: no assets/props/{name}.rbxm`)
			end
		end
	end,
}
