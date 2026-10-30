--!strict
-- The Wild as one valley with three moods (spec 2026-10-31-wild-valley-design, the user's pick A): the main game's Wild
-- (Config/Wild: zones in a row along +z from ORIGIN, boss arenas off their +x side) dressed as a sunny meadow, a rocky
-- gorge with a crystal cave and a volcanic ridge. World coordinates (the Wild sits at z 1100-1560); zone centres
-- (0, 1200), (0, 1340), (0, 1480). Plain data, Lune-tested with Util/WildValley: scenery stays clear of the trail, every
-- monster's wander circle, the arenas and their paths, the stream and the arrival; EDGE closes the map. Main game only:
-- the Frontier builds its own Wild without this.
return {
	MAX_CELLS = 40000, -- the valley's terrain (estimated 4-stud cells), inside Scenery.MAX_CELLS with the town's
	TRAIL_WIDTH = 10, -- studs: the dirt trail from the arrival down the valley's middle (x 0)
	MARKER_SPACING = 12, -- studs between the trail's small glowing stones
	-- Nothing stands here: the arrival pad and the return portal behind it
	ARRIVAL_CLEAR = { minX = -20, maxX = 20, minZ = 1106, maxZ = 1146 },
	-- The walkable edge (invisible walls along it): the zones, the arenas off their +x side, the arrival
	EDGE = { { x = -72, z = 1104 }, { x = 158, z = 1104 }, { x = 158, z = 1556 }, { x = -72, z = 1556 } },
	-- The meadow's stream: from the -x cliff down to a pond by the arrival, the trail crossing it on a bridge
	STREAM = { from = { x = -72, z = 1170 }, to = { x = 40, z = 1128 }, width = 6, pond = { x = 42, z = 1126, radius = 8 } },
	-- The wooden footbridge where the trail crosses the stream (code-built: deck planks, rails and posts)
	BRIDGE = { x = 0, z = 1143, length = 16, width = 9, rise = 1.2, wood = { 138, 96, 60 }, dark = { 96, 66, 42 } },
	-- The trail's markers: small glowing stones along its edges, alternating sides
	MARKER = { size = 1.3, color = { 170, 255, 190 } },

	-- The valley's terrain (SceneryService fills it after the town's; shapes as Config/Scenery's). The ground draws at
	-- y 0 (filled to y -2) under the zone floors monsters stand on; the stream lies level with it; cliffs and hills close
	-- the view outside the edge walls: grassy round the meadow, warm grey limestone round the gorge (tallest on its -x side, where
	-- the cave mouth is), basalt round the ridge.
	TERRAIN = {
		{ shape = "Block", x = 43, y = -5, z = 1330, size = { x = 240, y = 6, z = 464 }, material = "Grass" }, -- the valley floor
		{ shape = "Block", x = 43, y = -5, z = 1340, size = { x = 240, y = 6, z = 144 }, material = "Limestone" }, -- the gorge's rock floor
		{ shape = "Block", x = 43, y = -5, z = 1486, size = { x = 240, y = 6, z = 148 }, material = "CrackedLava" }, -- the ridge's dark ground
		{ shape = "Block", x = 0, y = -5, z = 1266, size = { x = 10, y = 6, z = 292 }, material = "Ground" }, -- the dirt trail
		{ shape = "Block", x = 0, y = -5, z = 1446, size = { x = 10, y = 6, z = 68 }, material = "Basalt" }, -- the trail on the ridge
		-- The stream and its pond: water only fills empty space, so the channel is carved first (Air), then filled, then
		-- floored below so nobody sinks out of the world (Forest Falls' pool)
		{ shape = "Block", x = -16, y = -4, z = 1149, yaw = 20.56, size = { x = 120, y = 8, z = 6 }, material = "Air" },
		{ shape = "Block", x = 42, y = -4, z = 1126, yaw = 45, size = { x = 16, y = 8, z = 16 }, material = "Air" },
		{ shape = "Block", x = -16, y = -5, z = 1149, yaw = 20.56, size = { x = 120, y = 6, z = 6 }, material = "Water" }, -- the stream
		{ shape = "Block", x = 42, y = -5, z = 1126, yaw = 45, size = { x = 16, y = 6, z = 16 }, material = "Water" }, -- its pond
		{ shape = "Block", x = -16, y = -10, z = 1149, yaw = 20.56, size = { x = 124, y = 4, z = 10 }, material = "Ground" }, -- the stream's bed
		{ shape = "Block", x = 42, y = -10, z = 1126, yaw = 45, size = { x = 20, y = 4, z = 20 }, material = "Ground" }, -- the pond's bed
		-- Cliffs and hills beyond the edge walls
		{ shape = "Block", x = 43, y = 6, z = 1090, size = { x = 300, y = 28, z = 24 }, material = "Grass" }, -- behind the arrival
		{ shape = "Block", x = -86, y = 6, z = 1186, size = { x = 24, y = 28, z = 164 }, material = "Grass" }, -- the meadow's west hills
		{ shape = "Block", x = 170, y = 5, z = 1186, size = { x = 24, y = 26, z = 164 }, material = "Grass" }, -- the meadow's east hills
		{ shape = "Block", x = -88, y = 12, z = 1340, size = { x = 28, y = 44, z = 144 }, material = "Limestone" }, -- the gorge's tall west cliff
		{ shape = "Block", x = 170, y = 9, z = 1340, size = { x = 24, y = 38, z = 144 }, material = "Limestone" }, -- the gorge's east cliff
		{ shape = "Ball", x = -82, y = 8, z = 1340, radius = 13, material = "Limestone" }, -- the rock the cave mouth is set in
		{ shape = "Block", x = -86, y = 10, z = 1484, size = { x = 24, y = 36, z = 144 }, material = "Basalt" }, -- the ridge's west wall
		{ shape = "Block", x = 170, y = 10, z = 1484, size = { x = 24, y = 36, z = 144 }, material = "Basalt" }, -- the ridge's east wall
		{ shape = "Block", x = 43, y = 13, z = 1570, size = { x = 300, y = 42, z = 24 }, material = "Basalt" }, -- the ridge's far wall
		-- Jagged basalt rims on the ridge walls (turned blocks, like the caldera's)
		{ shape = "Block", x = -82, y = 30, z = 1440, yaw = 25, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -84, y = 31, z = 1520, yaw = -35, size = { x = 16, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 166, y = 30, z = 1460, yaw = 40, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 20, y = 36, z = 1566, yaw = -20, size = { x = 18, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 90, y = 35, z = 1568, yaw = 30, size = { x = 18, y = 14, z = 12 }, material = "Basalt" },
		-- Rocky relief on the gorge's cliffs (turned blocks standing out of the faces), a brow over the cave
		{ shape = "Block", x = -72, y = 12, z = 1300, yaw = 20, size = { x = 10, y = 20, z = 14 }, material = "Limestone" },
		{ shape = "Block", x = -72, y = 14, z = 1384, yaw = -25, size = { x = 10, y = 24, z = 16 }, material = "Limestone" },
		{ shape = "Block", x = -75, y = 26, z = 1316, yaw = 35, size = { x = 12, y = 16, z = 12 }, material = "Limestone" },
		{ shape = "Block", x = -75, y = 28, z = 1366, yaw = -30, size = { x = 12, y = 16, z = 12 }, material = "Limestone" },
		{ shape = "Ball", x = -75, y = 25, z = 1340, radius = 8, material = "Limestone" },
		{ shape = "Block", x = 159, y = 18, z = 1310, yaw = 25, size = { x = 12, y = 18, z = 14 }, material = "Limestone" },
		{ shape = "Block", x = 159, y = 20, z = 1372, yaw = -20, size = { x = 12, y = 18, z = 14 }, material = "Limestone" },
		-- The cave mouth carved into the gorge's west rock (applied last; CAVE dresses it)
		{ shape = "Block", x = -74, y = 9, z = 1340, size = { x = 16, y = 18, z = 22 }, material = "Air" },
	},
	-- The crystal cave's mouth (the carved opening above): a dark wall on its back face (found by a ray westward from x,
	-- once the terrain is filled), blue light inside
	CAVE = { x = -60, z = 1340, width = 22, height = 18, inside = { 16, 18, 30 }, light = { 110, 190, 255 } },
	-- The gorge's crystals: clusters of three (a tall one and two leaning), glowing blue
	CRYSTAL_LOOK = { color = { 90, 180, 255 }, tip = { 190, 235, 255 }, transparency = 0.12 },
	-- The ridge's floor cracks (Util/LavaCracks.floor: off the trail), and its vents' look
	RIDGE_CRACKS = { SEED = 47, FLOOR = { centre = { x = 0, z = 1480 }, size = { x = 116, z = 116 }, count = 14 } },
	VENT_LOOK = { rock = { 40, 34, 40 }, glow = { 255, 120, 30 }, radius = 3 },

	-- Town prop models (PropModels), scaled to `height` on the drawn ground. zone: which mood they dress.
	PROPS = {
		-- Meadow (zone 1)
		{ model = "TreeA", x = -48, z = 1248, height = 22, yaw = 20 },
		{ model = "TreeB", x = 48, z = 1248, height = 20, yaw = 140 },
		{ model = "TreeC", x = -50, z = 1228, height = 18, yaw = 250 },
		{ model = "TreeD", x = -28, z = 1250, height = 20, yaw = 75 },
		{ model = "PineA", x = 50, z = 1228, height = 19, yaw = 10 },
		{ model = "TreeB", x = -66, z = 1150, height = 21, yaw = 300 },
		{ model = "TreeC", x = -66, z = 1190, height = 19, yaw = 30 },
		{ model = "TreeA", x = -66, z = 1230, height = 23, yaw = 200 },
		{ model = "TreeD", x = -40, z = 1270, height = 20, yaw = 120 },
		{ model = "Bush", x = 28, z = 1250, height = 3, yaw = 0 },
		{ model = "BushA", x = 50, z = 1172, height = 3, yaw = 90 },
		{ model = "BushB", x = -60, z = 1262, height = 2.6, yaw = 180 },
		{ model = "FlowerPink", x = 48, z = 1152, height = 2.4, yaw = 30 },
		{ model = "FlowerYellow", x = -50, z = 1172, height = 2.4, yaw = 80 },
		{ model = "FlowerBlue", x = 28, z = 1150, height = 2.4, yaw = 140 },
		{ model = "FlowerWhite", x = -48, z = 1152, height = 2.4, yaw = 200 },
		{ model = "RockC", x = 40, z = 1270, height = 3, yaw = 60 },
		-- Gorge (zone 2)
		{ model = "RockA", x = -48, z = 1292, height = 5, yaw = 20 },
		{ model = "RockB", x = 48, z = 1292, height = 4, yaw = 110 },
		{ model = "RockC", x = -50, z = 1312, height = 6, yaw = 200 },
		{ model = "RockD", x = 50, z = 1312, height = 4, yaw = 290 },
		{ model = "Rock", x = -48, z = 1388, height = 6, yaw = 40 },
		{ model = "RockA", x = 48, z = 1388, height = 5, yaw = 160 },
		{ model = "RockB", x = -28, z = 1390, height = 4, yaw = 250 },
		{ model = "RockC", x = 28, z = 1390, height = 4, yaw = 330 },
		{ model = "RockD", x = -40, z = 1410, height = 5, yaw = 70 },
	},
	-- Blue crystal clusters in the gorge (code-built like Frostpeak's ice crystals), and at the cave's lip
	CRYSTALS = {
		{ x = -50, z = 1368, height = 5, yaw = 20 },
		{ x = -28, z = 1290, height = 4, yaw = 80 },
		{ x = 28, z = 1290, height = 4, yaw = 150 },
		{ x = 50, z = 1368, height = 4, yaw = 230 },
		{ x = -68, z = 1328, height = 6, yaw = 300 },
		{ x = -68, z = 1352, height = 5, yaw = 10 },
	},
	-- The ridge: the caldera's charred trees and obsidian shards (Blender props), and two smoking vents
	CHARRED = {
		{ model = "CharredTree", x = -48, z = 1432, height = 11, yaw = 20 },
		{ model = "CharredTree", x = 48, z = 1432, height = 10, yaw = 140 },
		{ model = "CharredTree", x = -50, z = 1508, height = 12, yaw = 250 },
		{ model = "CharredTree", x = 50, z = 1508, height = 10, yaw = 75 },
		{ model = "CharredTree", x = -28, z = 1530, height = 9, yaw = 300 },
		{ model = "CharredTree", x = 28, z = 1530, height = 10, yaw = 190 },
		{ model = "CharredTree", x = -66, z = 1450, height = 11, yaw = 30 },
		{ model = "CharredTree", x = -66, z = 1500, height = 10, yaw = 210 },
	},
	SHARDS = {
		{ model = "ObsidianShards", x = -50, z = 1452, height = 4, yaw = 0 },
		{ model = "ObsidianShards", x = 50, z = 1452, height = 4, yaw = 120 },
		{ model = "ObsidianShards", x = -28, z = 1430, height = 3.5, yaw = 240 },
		{ model = "ObsidianShards", x = 28, z = 1430, height = 4, yaw = 60 },
		{ model = "ObsidianShards", x = -48, z = 1528, height = 4.5, yaw = 300 },
		{ model = "ObsidianShards", x = 48, z = 1528, height = 3.5, yaw = 170 },
	},
	VENTS = {
		{ x = -56, z = 1500, height = 4 },
		{ x = 56, z = 1456, height = 3.5 },
	},
}
