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
