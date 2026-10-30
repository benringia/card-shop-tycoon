--!strict
-- The Wild as one valley with three moods (spec 2026-10-31-wild-valley-design, the user's pick A): the valley's layout
-- (Config/WildValley) and its rules (Util/WildValley). Zones, spawn points, arenas and travel are unchanged, so the
-- scenery has to keep out of their way: clear of the trail, of every monster's wander circle, of the arenas and their
-- paths and of the arrival; the edge walls close round everything players can reach.
local wild = require("../src/shared/Config/Wild")
local bosses = require("../src/shared/Config/Bosses")
local valley = require("../src/shared/Config/WildValley")
local WildValley = require("../src/shared/Util/WildValley")
local expect = require("./lib/expect")

local function allProps(): { any }
	local list = {}
	for _, name in { "PROPS", "CRYSTALS", "CHARRED", "SHARDS", "VENTS" } do
		for _, prop in valley[name] do
			table.insert(list, prop)
		end
	end
	return list
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

	["props stay clear of spawn spots and their wander"] = function()
		for _, prop in allProps() do
			for index in wild.ZONES do
				for _, spot in WildValley.spawnSpots(wild, index) do
					local d = math.sqrt((prop.x - spot.x) ^ 2 + (prop.z - spot.z) ^ 2)
					assert(d >= wild.WANDER_RADIUS + 2, `{prop.model or "prop"} at {prop.x}, {prop.z} is {d} from a spawn spot`)
				end
			end
		end
	end,

	["props stay off the trail, the stream, the arenas and the arrival"] = function()
		for _, prop in allProps() do
			local ok, why = WildValley.clearOf(prop, valley, wild, bosses)
			assert(ok, `{prop.model or "prop"} at {prop.x}, {prop.z}: {why}`)
		end
		-- the rule itself: on the trail, in a ring, on an arena path and in the arrival are all refused
		local centre = WildValley.zoneCenter(wild, 1)
		local arena = WildValley.arenaCenter(wild, bosses, 1)
		expect.equal((WildValley.clearOf({ x = centre.x, z = centre.z - 20 }, valley, wild, bosses)), false, "on the trail")
		expect.equal((WildValley.clearOf({ x = arena.x, z = arena.z }, valley, wild, bosses)), false, "in a boss ring")
		expect.equal((WildValley.clearOf({ x = wild.ZONE_SIZE / 2 + 4, z = centre.z }, valley, wild, bosses)), false, "on an arena path")
		local arrival = valley.ARRIVAL_CLEAR
		expect.equal((WildValley.clearOf({ x = arrival.minX + 1, z = arrival.minZ + 1 }, valley, wild, bosses)), false, "in the arrival")
	end,

	["the edge closes round the zones, paths, arenas and arrival"] = function()
		local half = wild.ZONE_SIZE / 2
		for index in wild.ZONES do
			local c = WildValley.zoneCenter(wild, index)
			for _, corner in { { -half, -half }, { half, -half }, { -half, half }, { half, half } } do
				local p = { x = c.x + corner[1], z = c.z + corner[2] }
				assert(WildValley.inside(valley.EDGE, p), `zone {index} corner {p.x}, {p.z} is outside the edge`)
			end
			local arena = WildValley.arenaCenter(wild, bosses, index)
			local far = { x = arena.x + bosses.ARENA_RADIUS + 1, z = arena.z }
			assert(WildValley.inside(valley.EDGE, far), `arena {index}'s far side is outside the edge`)
		end
		local arrival = valley.ARRIVAL_CLEAR
		for _, p in { { x = arrival.minX, z = arrival.minZ }, { x = arrival.maxX, z = arrival.maxZ } } do
			assert(WildValley.inside(valley.EDGE, p), `the arrival corner {p.x}, {p.z} is outside the edge`)
		end
		expect.equal(WildValley.inside(valley.EDGE, { x = 0, z = -100 }), false, "the town is outside")
	end,

	["the valley's terrain fits the budget and draws the zones at y 0"] = function()
		local scenery = require("../src/shared/Config/Scenery")
		local town = require("../src/shared/Config/Town")
		local TownLayout = require("../src/shared/Util/TownLayout")
		local TownTerrain = require("../src/shared/Util/TownTerrain")
		local cells = TownTerrain.estimatedCells(valley.TERRAIN)
		assert(cells <= valley.MAX_CELLS, `the valley's terrain is {cells} cells (budget {valley.MAX_CELLS})`)
		local plots = TownLayout.plotRects({ plotCount = 6, perRow = 3, plotWidth = 40, plotDepth = 40, gap = 24, streetWidth = 96 } :: any)
		local townCells = TownTerrain.estimatedCells(TownTerrain.ops(scenery, town, plots))
		assert(townCells + cells <= scenery.MAX_CELLS, `town {townCells} + valley {cells} cells over {scenery.MAX_CELLS}`)
		-- monsters stand on the zone floors at y 0: the terrain under every spawn spot and zone corner draws there too
		local half = wild.ZONE_SIZE / 2 - 2
		for index in wild.ZONES do
			local c = WildValley.zoneCenter(wild, index)
			for _, p in { c, { x = c.x - half, z = c.z - half }, { x = c.x + half, z = c.z + half }, table.unpack(WildValley.spawnSpots(wild, index)) } do
				local ground = TownTerrain.groundAt(valley.TERRAIN, p.x, p.z)
				assert(ground and math.abs(ground) < 0.01, `zone {index}: ground at {p.x}, {p.z} draws at {ground}`)
			end
		end
		-- the walkable edge has ground all the way to it (no void to fall into)
		for _, p in { { x = -70, z = 1110 }, { x = 156, z = 1110 }, { x = 156, z = 1550 }, { x = -70, z = 1550 } } do
			assert(TownTerrain.groundAt(valley.TERRAIN, p.x, p.z) ~= nil, `no ground at the edge corner {p.x}, {p.z}`)
		end
		-- the stream keeps clear of every monster's wander circle
		local stream = valley.STREAM
		for index in wild.ZONES do
			for _, spot in WildValley.spawnSpots(wild, index) do
				local dx, dz = stream.to.x - stream.from.x, stream.to.z - stream.from.z
				local t = math.clamp(((spot.x - stream.from.x) * dx + (spot.z - stream.from.z) * dz) / (dx * dx + dz * dz), 0, 1)
				local d = math.sqrt((spot.x - (stream.from.x + dx * t)) ^ 2 + (spot.z - (stream.from.z + dz * t)) ^ 2)
				assert(d >= wild.WANDER_RADIUS + stream.width / 2, `the stream runs {d} from a spawn spot`)
			end
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
		local trail = WildValley.trail(wild)
		local markers = WildValley.markers(trail, valley.MARKER_SPACING)
		assert(#markers >= 3, "markers")
		local first, last = trail[1], trail[#trail]
		local function dist(a, b): number
			return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		end
		assert(dist(markers[1], first) <= valley.MARKER_SPACING, "the first marker is by the arrival")
		assert(dist(markers[#markers], last) <= valley.MARKER_SPACING, "the last marker is by the ridge's middle")
		for index = 2, #markers do
			assert(dist(markers[index], markers[index - 1]) <= valley.MARKER_SPACING + 1e-9, "a gap in the markers")
		end
		expect.near(last.z, WildValley.zoneCenter(wild, #wild.ZONES).z, 1e-9, "the trail ends at the last zone's middle")
	end,
}
