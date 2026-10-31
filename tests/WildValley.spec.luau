--!strict
-- The Wild valley (round 2, spec 2026-10-31-wild-valley-v2-design, the user's layout A "Winding valley"): one S-shaped
-- trail through three biomes at three heights (Config/WildValley), its rules in Util/WildValley, the ground modelled by
-- TownTerrain.groundAt over the valley's fills. The Frontier keeps today's zone grid (its spawn ring is pinned here too).
local wild = require("../src/shared/Config/Wild")
local bosses = require("../src/shared/Config/Bosses")
local valley = require("../src/shared/Config/WildValley")
local WildValley = require("../src/shared/Util/WildValley")
local TownTerrain = require("../src/shared/Util/TownTerrain")
local expect = require("./lib/expect")

local OPS = WildValley.terrainOps(valley, TownTerrain.trailSegment)

local function allProps(): { any }
	local list = {}
	for _, name in { "PROPS", "CRYSTALS", "CHARRED", "SHARDS", "VENTS" } do
		for _, prop in valley[name] do
			table.insert(list, prop)
		end
	end
	return list
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
		for _, list in { { valley.CRYSTALS, 2 }, { valley.CHARRED, 3 }, { valley.SHARDS, 3 }, { valley.VENTS, 3 } } do
			for _, prop in list[1] do
				expect.equal(WildValley.zoneAt(valley, prop), list[2], `{prop.x}, {prop.z} dresses biome {list[2]}`)
			end
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
}
