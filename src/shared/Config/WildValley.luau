--!strict
-- The Wild valley (round 2, spec 2026-10-31-wild-valley-v2-design, the user's layout A "Winding valley"): the main
-- game's Wild as one S-shaped trail through three biomes at three heights: the meadow (ground y 0), a right turn and a
-- climb into the limestone gorge (y 15), a left turn and a climb onto the Ember Ridge (y 35), round a central mass that
-- hides each biome from the last. World coordinates (the valley sits at x -470..124, z 1080..1824). Plain data,
-- Lune-tested with Util/WildValley (the ground modelled by TownTerrain.groundAt over WildValley.terrainOps). Main game
-- only: the Frontier builds its own Wild without this.
return {
	MAX_CELLS = 105000, -- the valley's terrain with the boss arena clearings (estimated 4-stud cells; 90k -> 95k for the wider hollow and lava field clearings, measured 2026-11-02: terrain memory unchanged, 60 fps; 95k -> 105k for round 2's skylines, about 100.5k after trimming the walls' hidden backs, measured 2026-11-05 in the valley: terrain graphics 48.0 -> 46.3 MB, voxels 5.9 -> 6.4 MB)
	SURFACE_LIFT = 2, -- TownTerrain.SURFACE_LIFT: terrain draws this far above a fill's top (Lune-tested equal)
	TRAIL_WIDTH = 10,
	MARKER_SPACING = 12, -- studs between the trail's small glowing stones
	MAX_STEP = 1.5, -- studs a monster may climb or drop in one step (0.1 s at chase speed 11 moves 1.1 studs)
	PORTAL_CLEAR = 30, -- studs round a boss portal kept free of scenery and spawn spots
	BOARD_CLEAR = 6, -- studs round a trailhead board
	-- Monsters per biome (Util/WildPopulation): QUIET while few play there, PER_PLAYER more for each player in it past
	-- FREE_PLAYERS, up to MAX; respawn seconds { min, max } while quiet and while busy (wanting more than QUIET); checked
	-- every CHECK_SECONDS
	POPULATION = { QUIET = 8, PER_PLAYER = 2, FREE_PLAYERS = 3, MAX = 24, RESPAWN_QUIET = { 20, 40 }, RESPAWN_BUSY = { 10, 20 }, CHECK_SECONDS = 2 },
	-- Spawn spots (Util/WildValley.zoneSpots): a grid this far apart, kept this far from a biome's edges and from props
	SPOT_SPACING = 18,
	SPOT_MARGIN = 20,
	SPOT_PROP_CLEAR = 6,
	-- Nothing stands here: the arrival pad and the return portal behind it
	ARRIVAL_CLEAR = { minX = -20, maxX = 20, minZ = 1106, maxZ = 1146 },
	-- The biomes, indexed like Config/Wild ZONES: middle, ground height, walkable outline, the boss portal (facing
	-- `faces`, by the trail) and the trailhead board where the trail comes in
	BIOMES = {
		{ centre = { x = -50, z = 1212 }, ground = 0, -- the meadow
			outline = { { x = -190, z = 1104 }, { x = 90, z = 1104 }, { x = 100, z = 1160 }, { x = 95, z = 1290 }, { x = 40, z = 1322 }, { x = -120, z = 1322 }, { x = -205, z = 1290 }, { x = -205, z = 1160 } },
			portal = { x = -150, z = 1300, faces = { x = -165, z = 1262 } }, board = { x = 12, z = 1152 } },
		{ centre = { x = -330, z = 1420 }, ground = 15, -- the gorge
			outline = { { x = -250, z = 1300 }, { x = -330, z = 1290 }, { x = -430, z = 1310 }, { x = -445, z = 1400 }, { x = -440, z = 1500 }, { x = -400, z = 1548 }, { x = -290, z = 1552 }, { x = -220, z = 1530 }, { x = -215, z = 1420 }, { x = -225, z = 1330 } },
			portal = { x = -365, z = 1520, faces = { x = -310, z = 1505 } }, board = { x = -232, z = 1334 } },
		{ centre = { x = -55, z = 1680 }, ground = 35, -- the ridge
			outline = { { x = -215, z = 1575 }, { x = -120, z = 1560 }, { x = 40, z = 1562 }, { x = 100, z = 1600 }, { x = 100, z = 1760 }, { x = 40, z = 1800 }, { x = -140, z = 1800 }, { x = -200, z = 1760 }, { x = -215, z = 1650 } },
			portal = { x = 0, z = 1725, faces = { x = -40, z = 1690 } }, board = { x = -190, z = 1625 } },
	},
	-- The trail: x, z and the ground's height (y) at each point. The meadow, a right turn and a climb, the gorge, a left
	-- turn and a climb, the ridge
	TRAIL = {
		{ x = 0, z = 1130, y = 0 }, { x = 0, z = 1185, y = 0 }, { x = -60, z = 1235, y = 0 }, { x = -140, z = 1255, y = 0 },
		{ x = -190, z = 1275, y = 0 }, { x = -240, z = 1320, y = 15 }, { x = -310, z = 1390, y = 15 }, { x = -320, z = 1480, y = 15 },
		{ x = -290, z = 1545, y = 15 }, { x = -195, z = 1605, y = 35 }, { x = -120, z = 1650, y = 35 }, { x = -40, z = 1690, y = 35 },
	},
	TRAIL_MATERIAL = { "Ground", "Ground", "Basalt" }, -- a dirt trail through the meadow and the gorge, basalt on the ridge
	BIOME_FLOOR = { "Grass", "Limestone", "CrackedLava" },
	BIOME_CLIFF = { "Grass", "Limestone", "Basalt" },
	-- Where the trail climbs (WildValley.terrainOps): a ramp `width` wide and `depth` deep in the upper biome's floor,
	-- and a wall `wall` thick on each side rising `wallHeight` above the upper ground
	PASS = { width = 44, depth = 24, wall = 12, wallHeight = 12 },
	-- Low grass patches on the Caves' floor (the owner 2026-11-05: "short grass patches too ... not as much as the
	-- meadow"): terrain Grass, where Roblox draws its grass blades, as flat domes standing GRASS_PATCH_RISE above the
	-- floor, two or three overlapping per patch; about a tenth of the floor (Lune-tested)
	GRASS_PATCH_RISE = 1.2, -- terrain cells are 4 studs: a lower dome only greens their middles
	GRASS_PATCHES = {
		{ x = -300, z = 1345, radius = 7 },
		{ x = -306, z = 1353, radius = 5 },
		{ x = -372, z = 1330, radius = 8 },
		{ x = -381, z = 1322, radius = 6 },
		{ x = -262, z = 1460, radius = 7 },
		{ x = -254, z = 1470, radius = 5 },
		{ x = -352, z = 1452, radius = 8 },
		{ x = -344, z = 1461, radius = 6 },
		{ x = -400, z = 1500, radius = 7 },
		{ x = -410, z = 1492, radius = 5 },
		{ x = -240, z = 1410, radius = 6 },
		{ x = -403, z = 1388, radius = 7 },
		{ x = -330, z = 1510, radius = 6 },
		{ x = -285, z = 1500, radius = 6 },
		{ x = -395, z = 1445, radius = 6 },
		-- more, in mixed sizes (the owner: "add more. in different patch sizes"): small tufts to wide carpets
		{ x = -266, z = 1378, radius = 8 },
		{ x = -263, z = 1371, radius = 5 },
		{ x = -276, z = 1334, radius = 3 },
		{ x = -427, z = 1436, radius = 9 },
		{ x = -434, z = 1431, radius = 5 },
		{ x = -268, z = 1429, radius = 11 },
		{ x = -263, z = 1436, radius = 7 },
		{ x = -293, z = 1362, radius = 3 },
		{ x = -380, z = 1375, radius = 3 },
		{ x = -415, z = 1309, radius = 11 },
		{ x = -410, z = 1317, radius = 7 },
		{ x = -352, z = 1360, radius = 4 },
		{ x = -398, z = 1520, radius = 7 },
		{ x = -400, z = 1526, radius = 4 },
	},
	-- Gentle mounds: buried balls whose tops stand `height` above their biome's ground
	HILLS = {
		{ x = 60, z = 1200, radius = 16, height = 4, material = "Grass" },
		{ x = 55, z = 1285, radius = 16, height = 4, material = "Grass" },
		{ x = -95, z = 1165, radius = 16, height = 4, material = "Grass" },
		{ x = -165, z = 1195, radius = 16, height = 4, material = "Grass" },
		{ x = -40, z = 1300, radius = 16, height = 4, material = "Grass" },
		{ x = -130, z = 1195, radius = 30, height = 6, material = "Grass" }, -- round 2: the ruin hill under the stone circle
		{ x = -120, z = 1725, radius = 16, height = 4, material = "CrackedLava" },
		{ x = 45, z = 1660, radius = 16, height = 4, material = "CrackedLava" },
		{ x = -20, z = 1775, radius = 16, height = 4, material = "CrackedLava" },
		{ x = 60, z = 1760, radius = 16, height = 4, material = "CrackedLava" },
	},
	-- The walkable edge (invisible walls along it, from y EDGE_WALL.bottom to top: under the meadow, well above the
	-- ridge): the three biomes, the two climbing passes along the trail, and a notch into the gorge's cave mouth
	-- (players walk in up to its dark back wall)
	EDGE_WALL = { bottom = -10, top = 80 },
	EDGE = {
		{ x = 94, z = 1100 }, { x = 104, z = 1160 }, { x = 99, z = 1292 }, { x = 42, z = 1326 }, { x = -120, z = 1326 },
		{ x = -185, z = 1298 }, { x = -222, z = 1333 }, { x = -212, z = 1420 }, { x = -218, z = 1532 }, { x = -257, z = 1542 },
		{ x = -207, z = 1572 }, { x = -120, z = 1557 }, { x = 40, z = 1559 }, { x = 103, z = 1598 }, { x = 103, z = 1762 },
		{ x = 41, z = 1803 }, { x = -141, z = 1803 }, { x = -203, z = 1762 }, { x = -218, z = 1650 }, { x = -218, z = 1614 },
		{ x = -311, z = 1555 }, { x = -401, z = 1551 }, { x = -443, z = 1501 }, { x = -446.5, z = 1431 }, { x = -454, z = 1431 },
		{ x = -454, z = 1409 }, { x = -447, z = 1409 }, { x = -448, z = 1400 }, { x = -433, z = 1307 }, { x = -330, z = 1287 },
		{ x = -245, z = 1298 }, { x = -208, z = 1264 }, { x = -208, z = 1160 }, { x = -192, z = 1100 },
	},
	-- The valley's ground is terrain filled in the background at start (SceneryService): travel to the Wild waits up to
	-- TERRAIN_WAIT seconds for this Workspace attribute, so nobody lands before there's ground to stand on
	TERRAIN_READY_ATTRIBUTE = "WildTerrainReady",
	TERRAIN_WAIT = 20,
	-- The Frontier's plain name boards (WildService's sign)
	SIGN_WIDTH = 14,
	-- The valley's wooden signs (Server/Util/TrailProps, like the town's), each turned to face the trail: "The Wild"
	-- trailhead by the arrival, clear of the root arch's legs (each biome's board is in BIOMES), and an arrow post at each
	-- bend naming the way on (a zone: its name and colour) and the way back to the portal home
	RETURN_SIGN = { x = 18, z = 1134 },
	BOARD_FACE_BACK = 25, -- studs back along the trail (toward the arrival) a board turns to face (WildValley.backAlongTrail)
	ARROWS = {
		{ x = -165, z = 1245, arms = { { zone = 2, toward = { x = -240, z = 1320 } }, { text = "SHOP", toward = { x = 0, z = 1130 } } } },
		{ x = -310, z = 1535, arms = { { zone = 3, toward = { x = -195, z = 1605 } }, { text = "SHOP", toward = { x = -320, z = 1480 } } } },
	},
	-- The meadow's stream: out of the east hills, across the trail under a bridge, into a pond west of it
	STREAM = { from = { x = 98, z = 1185 }, to = { x = -60, z = 1148 }, width = 6, pond = { x = -60, z = 1148, radius = 13 } }, -- round 2: a bigger pond
	-- The wooden footbridge where the trail crosses the stream (code-built: deck planks, rails and posts)
	BRIDGE = { x = 0, z = 1162, length = 16, width = 9, rise = 1.2, wood = { 138, 96, 60 }, dark = { 96, 66, 42 } },
	-- The trail's markers: small glowing stones along its edges, alternating sides
	MARKER = { size = 1.3, color = { 170, 255, 190 } },

	-- The valley's terrain (shapes as Config/Scenery's; WildValley.terrainOps adds the hills, the passes, the trail and
	-- CARVES). Each floor is filled to its ground - 2 (it draws at its ground); the gorge's and the ridge's floors are
	-- turned so they start exactly where their pass's ramp tops out. Hills and cliffs close every side; a hollow central
	-- mass (three walls and a roof, topping out at y 47) stands between the meadow, the gorge and the ridge.
	TERRAIN = {
		{ shape = "Block", x = -55.5, y = -4, z = 1212.5, size = { x = 319, y = 4, z = 235 }, material = "Grass" }, -- the meadow's floor
		{ shape = "Block", x = -45.5, y = 8, z = 1097, size = { x = 339, y = 28, z = 14 }, material = "Grass" }, -- the hills behind the arrival (round 2: 10 trimmed off the hidden back)
		{ shape = "Block", x = -214, y = 8, z = 1183, size = { x = 18, y = 28, z = 158 }, material = "Grass" }, -- the meadow's west hills (12 trimmed)
		{ shape = "Block", x = 107, y = 8, z = 1213, size = { x = 14, y = 28, z = 218 }, material = "Grass" }, -- the meadow's east hills (10 trimmed)
		{ shape = "Ball", x = 60, y = 8, z = 1094, radius = 12, material = "Grass" },
		{ shape = "Ball", x = -120, y = 10, z = 1095, radius = 14, material = "Grass" },
		{ shape = "Ball", x = -222, y = 12, z = 1150, radius = 12, material = "Grass" },
		{ shape = "Ball", x = 115, y = 10, z = 1250, radius = 12, material = "Grass" },
		-- The central mass: grassy toward the meadow, limestone toward the gorge, basalt toward the ridge; its roof mossy
		-- on the meadow's half and basalt on the ridge's (seen over the walls from each)
		{ shape = "Block", x = -52.5, y = 20.5, z = 1328, size = { x = 305, y = 53, z = 12 }, material = "Grass" }, -- (8 trimmed off its hollow side)
		{ shape = "Block", x = -209, y = 28, z = 1440, size = { x = 12, y = 38, z = 196 }, material = "Limestone" }, -- (8 trimmed off its hollow side)
		{ shape = "Block", x = -57.5, y = 37, z = 1552, size = { x = 315, y = 20, z = 12 }, material = "Basalt" }, -- (8 trimmed off its hollow side)
		{ shape = "Block", x = -57.5, y = 45, z = 1381, size = { x = 315, y = 4, z = 118 }, material = "Rock" },
		{ shape = "Block", x = -57.5, y = 45, z = 1499, size = { x = 315, y = 4, z = 118 }, material = "Basalt" },
		{ shape = "Ball", x = -150, y = 30, z = 1330, radius = 12, material = "Grass" },
		{ shape = "Ball", x = 20, y = 28, z = 1328, radius = 14, material = "Grass" },
		{ shape = "Ball", x = -212, y = 32, z = 1400, radius = 10, material = "Limestone" },
		{ shape = "Ball", x = -213, y = 34, z = 1490, radius = 12, material = "Limestone" },
		{ shape = "Ball", x = -100, y = 46, z = 1557, radius = 12, material = "Basalt" },
		{ shape = "Ball", x = 40, y = 46, z = 1556, radius = 10, material = "Basalt" },
		{ shape = "Ball", x = -50, y = 44, z = 1440, radius = 14, material = "Rock" },
		{ shape = "Ball", x = -140, y = 43, z = 1390, radius = 10, material = "Rock" },
		{ shape = "Ball", x = 40, y = 43, z = 1480, radius = 11, material = "Basalt" },
		-- The gorge: its floor (turned along the first pass), tall limestone cliffs west and north, a hill south, low shelves
		{ shape = "Block", x = -346.85, y = 11, z = 1432.99, yaw = 131.99, size = { x = 325, y = 4, z = 310 }, material = "Limestone" },
		{ shape = "Block", x = -457.5, y = 30.5, z = 1420, size = { x = 25, y = 43, z = 280 }, material = "Limestone" },
		{ shape = "Block", x = -389, y = 30.5, z = 1560, size = { x = 162, y = 43, z = 14 }, material = "Limestone" }, -- (10 trimmed)
		{ shape = "Block", x = -364, y = 13, z = 1281, size = { x = 212, y = 38, z = 18 }, material = "Limestone" }, -- (8 trimmed)
		{ shape = "Block", x = -233.7, y = 28, z = 1540.6, yaw = 17.46, size = { x = 41, y = 38, z = 12 }, material = "Limestone" }, -- closes the north-east corner up to the second pass's wall
		{ shape = "Block", x = -435, y = 12.5, z = 1360, size = { x = 20, y = 7, z = 60 }, material = "Limestone" },
		{ shape = "Block", x = -436, y = 13, z = 1470, size = { x = 18, y = 8, z = 44 }, material = "Limestone" },
		{ shape = "Block", x = -350, y = 12.5, z = 1545, size = { x = 60, y = 7, z = 16 }, material = "Limestone" },
		{ shape = "Ball", x = -450, y = 40, z = 1330, radius = 12, material = "Limestone" },
		{ shape = "Ball", x = -448, y = 44, z = 1500, radius = 10, material = "Limestone" },
		{ shape = "Ball", x = -420, y = 45, z = 1562, radius = 12, material = "Limestone" },
		{ shape = "Ball", x = -300, y = 30, z = 1275, radius = 12, material = "Limestone" },
		-- the rock shelf jutting from the west cliff over the cave mouth and the biggest mushrooms (an overhang: drawn,
		-- but nothing stands on it, so the ground under it stays the gorge's floor)
		{ shape = "Block", x = -437.5, y = 45, z = 1420, size = { x = 35, y = 6, z = 70 }, material = "Limestone", overhang = true },
		-- round 2 (Caves pick A: the crystal cave in a mossy rock face): moss over the shelf and two mossy clumps either side
		-- of the mouth, above head height (the mouth and its carve unchanged)
		{ shape = "Block", x = -437.5, y = 48.5, z = 1420, size = { x = 35, y = 1.5, z = 70 }, material = "LeafyGrass", overhang = true },
		{ shape = "Ball", x = -452, y = 34, z = 1398, radius = 6, material = "LeafyGrass" },
		{ shape = "Ball", x = -452, y = 34, z = 1442, radius = 6, material = "LeafyGrass" },
		-- The ridge: its cracked-lava floor (turned along the second pass), basalt cliffs all round, jagged rims
		{ shape = "Block", x = -43.31, y = 31, z = 1683.07, yaw = -122.28, size = { x = 310, y = 4, z = 340 }, material = "CrackedLava" },
		{ shape = "Block", x = -58, y = 45.5, z = 1807, size = { x = 364, y = 33, z = 14 }, material = "Basalt" }, -- (10 trimmed)
		{ shape = "Block", x = 107, y = 44.5, z = 1679, size = { x = 14, y = 31, z = 242 }, material = "Basalt" }, -- (10 trimmed)
		{ shape = "Block", x = -223.5, y = 34.5, z = 1720, size = { x = 17, y = 51, z = 160 }, material = "Basalt" }, -- (8 trimmed)
		{ shape = "Block", x = -176.7, y = 44.5, z = 1790, yaw = -33.7, size = { x = 76, y = 31, z = 24 }, material = "Basalt" },
		{ shape = "Block", x = -100, y = 64, z = 1810, yaw = 25, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 60, y = 63, z = 1812, yaw = -35, size = { x = 18, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 112, y = 62, z = 1640, yaw = 40, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -228, y = 62, z = 1700, yaw = -20, size = { x = 16, y = 14, z = 12 }, material = "Basalt" },
	},
	-- Round 2 (spec 2026-11-05-valley-natural-design, the owner: "it looks like its inside a box"): each wall's top gets
	-- a natural skyline of terrain lumps (WildValley.skylineOps) along a line on the wall, outside the walkable edge and
	-- off the passes: `top` is the wall's fill top, lumps rise `rise` above it
	SKYLINES = {
		-- the Meadow: grassy hills on its south, west, east walls and the central mass's meadow side
		{ material = "Grass", top = 22, seed = 11, points = { { x = -200, z = 1097 }, { x = 110, z = 1097 } }, spacing = 20, radius = { 8, 16 }, rise = { 4, 12 }, drift = 2 },
		{ material = "Grass", top = 22, seed = 12, points = { { x = -214, z = 1112 }, { x = -214, z = 1250 } }, spacing = 20, radius = { 8, 16 }, rise = { 4, 12 }, drift = 2 },
		{ material = "Grass", top = 22, seed = 13, points = { { x = 109, z = 1112 }, { x = 109, z = 1290 } }, spacing = 20, radius = { 8, 16 }, rise = { 4, 12 }, drift = 2 },
		{ material = "Grass", top = 47, seed = 14, points = { { x = -165, z = 1330 }, { x = 90, z = 1330 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		-- the Caves: limestone on the west and north cliffs, the south wall and the central mass's gorge side
		{ material = "Limestone", top = 52, seed = 21, points = { { x = -460, z = 1300 }, { x = -460, z = 1545 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Limestone", top = 52, seed = 22, points = { { x = -450, z = 1561 }, { x = -318, z = 1561 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Limestone", top = 32, seed = 23, points = { { x = -455, z = 1278 }, { x = -268, z = 1278 } }, spacing = 20, radius = { 9, 14 }, rise = { 10, 16 }, drift = 2 }, -- a low wall: lumps kept out of jump reach
		{ material = "Limestone", top = 47, seed = 24, points = { { x = -208, z = 1352 }, { x = -208, z = 1525 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		-- Ember Ridge: basalt on its north, east, west and north-west walls and the central mass's ridge side
		{ material = "Basalt", top = 62, seed = 31, points = { { x = -135, z = 1808 }, { x = 110, z = 1808 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Basalt", top = 60, seed = 32, points = { { x = 109, z = 1575 }, { x = 109, z = 1792 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Basalt", top = 60, seed = 33, points = { { x = -227, z = 1655 }, { x = -227, z = 1785 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Basalt", top = 60, seed = 34, points = { { x = -200, z = 1774 }, { x = -152, z = 1806 } }, spacing = 20, radius = { 9, 18 }, rise = { 5, 14 }, drift = 2 },
		{ material = "Basalt", top = 47, seed = 35, points = { { x = -110, z = 1550 }, { x = 90, z = 1550 } }, spacing = 20, radius = { 9, 14 }, rise = { 12, 16 }, drift = 2 }, -- a low wall: lumps kept out of jump reach
	},
	-- Cut and filled after the trail: the meadow's stream and pond (water only fills empty space, so the channel is
	-- carved first, then filled, then floored below so nobody sinks out of the world) and the gorge's cave mouth
	CARVES = {
		{ shape = "Block", x = 19, y = -4, z = 1166.5, yaw = -13.18, size = { x = 162, y = 8, z = 6 }, material = "Air" },
		{ shape = "Block", x = -60, y = -4, z = 1148, yaw = 45, size = { x = 26, y = 8, z = 26 }, material = "Air" },
		{ shape = "Block", x = 19, y = -5, z = 1166.5, yaw = -13.18, size = { x = 162, y = 6, z = 6 }, material = "Water" }, -- the stream
		{ shape = "Block", x = -60, y = -5, z = 1148, yaw = 45, size = { x = 26, y = 6, z = 26 }, material = "Water" }, -- its pond
		{ shape = "Block", x = 19, y = -10, z = 1166.5, yaw = -13.18, size = { x = 166, y = 4, z = 10 }, material = "Ground" },
		{ shape = "Block", x = -60, y = -10, z = 1148, yaw = 45, size = { x = 30, y = 4, z = 30 }, material = "Ground" },
		{ shape = "Block", x = -454, y = 22, z = 1420, size = { x = 18, y = 18, z = 22 }, material = "Air" }, -- the cave mouth (from just under the gorge's floor, so it walks in level)
	},
	-- The crystal cave's mouth in the gorge's west cliff (the carved opening above, its floor at y): a dark wall on its
	-- back face (found by a ray westward from x, once the terrain is filled), blue light inside
	CAVE = { x = -436, y = 15, z = 1420, width = 22, height = 18, inside = { 16, 18, 30 }, light = { 110, 190, 255 } },
	-- The gorge's crystals: clusters of three (a tall one and two leaning), glowing blue
	CRYSTAL_LOOK = { color = { 90, 180, 255 }, tip = { 190, 235, 255 }, transparency = 0.12 },
	-- The ridge's floor cracks (Util/LavaCracks.floor: off the trail), and its vents' look
	RIDGE_CRACKS = { SEED = 47, FLOOR = { centre = { x = -55, z = 1680 }, size = { x = 250, z = 200 }, count = 26 } },
	VENT_LOOK = { rock = { 40, 34, 40 }, glow = { 255, 120, 30 }, radius = 3 },
	-- The boss portals (WildService.BuildBossArenas; each at its biome's `portal`): the obsidian arch HEIGHT tall with
	-- the purple Boss look (Config/Town PORTAL_LOOKS), a trailhead board with the boss's name beside it. Each fight
	-- goes to its own copy of the boss's arena (Config/Bosses ARENA_COPIES), far from the valley: copy c of zone z's
	-- boss at ARENA_FIELD x + (c - 1) * spacing, z + (z - 1) * spacing, on a terrain clearing `size[zone]` wide in the zone's
	-- material (Slate terrain is Frostpeak's ice blue map-wide, so the gorge's is Limestone), dressed by ARENA_DRESSING
	-- with its way home (ARENA_HOME) inside its walls. Under it a flat part `ground` wide (top `sink` under the terrain's,
	-- `thickness` thick; a part, as terrain that wide is about 86k more cells) runs on past the walls, so a camera
	-- looking straight down from full zoom sees ground fading into the haze, not the clearing's edge (Util/WildValley
	-- .arenaApron); the play area stays the clearing.
	-- ARENA_COPIES_FOR_TERRAIN mirrors Bosses.ARENA_COPIES for WildValley.terrainOps (Lune-tested equal).
	BOSS_PORTAL = { model = "PortalArena", height = 20 },
	ARENA_FIELD = { x = 1600, z = 1200, y = 0, spacing = 1200 },
	ARENA_CLEARING = {
		size = { 124, 164, 164 }, -- the hollow and the lava field wider: the user found them tight with walls at 56-57
		ground = 360,
		sink = 0.5,
		thickness = 2,
		materials = { "Grass", "Limestone", "Basalt" },
		-- the ground part's colours, matched by eye to each clearing's terrain under its arena's light (2026-11-02)
		apronColors = { { 78, 150, 66 }, { 115, 109, 86 }, { 75, 74, 74 } },
	},
	ARENA_COPIES_FOR_TERRAIN = 4,
	-- Studs from a copy's middle a fighter still holds it (BossRules.stillInCopy): out to its clearing's corners,
	-- which invisible walls close (WildValley.arenaEdge)
	ARENA_HOLD = 120,
	-- The invisible walls round each arena copy (WildValley.arenaEdge): a ring of ARENA_EDGE_SIDES walls this far inside
	-- its innermost wall row, so nobody walks out between the pieces (the hollow's roof doesn't collide)
	ARENA_EDGE_INSET = 4,
	ARENA_EDGE_SIDES = 24,
	-- Each zone's boss arena dressed in its mood (WildService.BuildBossArenas; rings and barriers as before): the
	-- floor disc and path (lifted LIFT studs over the terrain so they don't flicker against it) and the fence posts, every
	-- other one capped with a glowing tip; the ridge's floor also gets glowing cracks (Util/LavaCracks.floor in a box `size`
	-- wide round the ring's middle, clear of the gate)
	ARENA_LIFT = 0.15,
	ARENA_LOOKS = {
		{ floor = { 96, 150, 70 }, floorMaterial = "Grass", path = { 128, 100, 70 }, pathMaterial = "Ground", post = { 110, 78, 50 }, postMaterial = "Wood", postSize = 1.2, postHeight = 5 },
		{ floor = { 112, 104, 100 }, floorMaterial = "Slate", path = { 128, 120, 116 }, pathMaterial = "Slate", post = { 100, 96, 100 }, postMaterial = "Slate", postSize = 1.6, postHeight = 6, tip = { 110, 200, 255 } },
		{ floor = { 46, 42, 50 }, floorMaterial = "Basalt", path = { 60, 54, 62 }, pathMaterial = "Basalt", post = { 52, 46, 56 }, postMaterial = "Basalt", postSize = 1.6, postHeight = 6, tip = { 255, 120, 30 }, cracks = { seed = 53, count = 12, size = 46, width = { 0.4, 0.8 } } },
	},
	-- Each Wild boss's arena as a place of its own (spec 2026-11-01-wild-bosses-arenas-design; Util/WildValley.arenaDressing
	-- lays it out from a seed, offsets from the copy's centre): rows of wall pieces all round (`radius`, `count`, its
	-- models, `height` { min, max } studs) that close it in, groups of inner pieces scattered between the fence and the
	-- walls (clear of the fight, the path and the way home; `y` lifts a hung one off the ground), a roof or a backdrop
	-- model, code-built crystals, the area effects round it (Scenery's effect kinds, a box `size` wide at `y`), and its
	-- looping ambient sound at the centre (heard out to `range`). Model names are PropModels (assets/props).
	ARENA_DRESSING = {
		{ -- the Warden's grove: mossy standing stones, then giant old trees, flowers and roots, fireflies and leaves
			walls = {
				{ radius = 53, count = 26, models = { "StandingStone" }, height = { 14, 20 } },
				{ radius = 58, count = 27, models = { "TreeA", "TreeB", "TreeC" }, height = { 36, 46 } },
			},
			inner = {
				{ models = { "FlowerPink", "FlowerWhite", "FlowerYellow" }, count = 24, radius = { 40, 50 }, height = { 1.5, 2.5 } },
				{ models = { "Bush", "BushA", "RootsLarge" }, count = 10, radius = { 42, 50 }, height = { 3, 5 } },
			},
			effects = { { kind = "fireflies", rate = 8, y = 6, size = 100 }, { kind = "leaves", rate = 3, y = 30, size = 110 } },
			sound = { id = "rbxassetid://9112806424", volume = 0.4, range = 90 }, -- Pro Sound Effects: Jungle Dawn 1 (loop)
		},
		{ -- the Broodmother's hollow: a rock dome over stalagmites, webs, hanging cocoons, bones and violet-blue crystals
			walls = {
				{ radius = 74, count = 34, models = { "Stalagmite", "RockA", "RockB" }, height = { 16, 28 } },
			},
			inner = {
				{ models = { "Bones" }, count = 8, radius = { 42, 68 }, height = { 4, 7 } },
				{ models = { "Web" }, count = 8, radius = { 50, 70 }, height = { 8, 12 } },
				{ models = { "Cocoon" }, count = 10, radius = { 42, 68 }, height = { 4, 6 }, hang = true }, -- from the ceiling
			},
			-- about 170 across, past the walls, its rim `sink` under the floor. `profile` is the dome's shape in Blender units
			-- (build_arena_props.py cave_dome: an ellipsoid `radius` wide and `rise` tall round z `base`, cut at `rim`; the
			-- saved model's top at `top`), its random dents allowed for by `squeeze` and `sag` (WildValley.ceilingAt)
			roof = {
				model = "CaveDome",
				height = 64,
				sink = 2,
				profile = { radius = 66, rise = 50, base = -4, rim = -6, top = 45, squeeze = 0.95, sag = 0.95 },
			},
			crystals = { count = 10, radius = { 44, 70 }, height = { 4, 7 } },
			effects = { { kind = "glints", rate = 5, y = 4, size = 140 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9120505297", volume = 0.5, range = 90 }, -- Pro Sound Effects: Water Cave Trickle Thin Into Small Puddles 5
		},
		{ -- the Behemoth's lava field: basalt cliffs all round, charred trees and obsidian shards, the volcano behind
			walls = {
				{ radius = 74, count = 34, models = { "LavaCliff" }, height = { 30, 40 } },
			},
			inner = {
				{ models = { "CharredTree" }, count = 10, radius = { 44, 68 }, height = { 12, 18 } },
				{ models = { "ObsidianShards" }, count = 11, radius = { 42, 70 }, height = { 4, 8 } },
			},
			backdrop = { model = "Volcano", distance = 180, height = 130 },
			effects = { { kind = "embers", rate = 12, y = 4, size = 140 }, { kind = "ash", rate = 8, y = 40, size = 160 } },
			sound = { id = "rbxassetid://9112780462", volume = 0.45, range = 90 }, -- Pro Sound Effects: Fireplace Constant Burning Flame 4
		},
	},
	-- Mirrors Bosses.ARENA_RADIUS (the fence round the fight; Lune-tested equal) for Util/WildValley.arenaSpots
	ARENA_FENCE = 36,
	-- Each arena's way home on its -X side, `distance` studs from the centre (inside its walls), in its zone's look: the
	-- meadow's root arch, the ice-blue crystal ring for the caves, the obsidian arch with the canyon's lava for the ridge
	ARENA_HOME = {
		distance = 46,
		{ model = "PortalWild", look = "Wild" },
		{ model = "PortalFrontier", look = "Frontier" },
		{ model = "PortalArena", look = "Arena" },
	},

	-- The valley's scenery lists (Util/WildValley.scenery, spec 2026-11-04-valley-scenery-design): every spot in them is
	-- kept off the trail and the rest (WildValley.clearOf) and away from monster spawn spots (SPOT_PROP_CLEAR, or a spot's
	-- own `clear` for a big piece). A spot: `model` (PropModels; none for code-built ones), x, z, `height`, `yaw`, and
	-- for glowing pieces `glow` (a GLOW colour)
	PROP_LISTS = { "PROPS", "CRYSTALS", "CHARRED", "SHARDS", "VENTS", "MUSHROOMS", "TUFTS", "RUINS", "MOSS_ROCKS", "EMBER_TREES", "EMBER_CRYSTALS", "SKELETON", "GIANT_TREES" },
	-- The Caves' glow mushroom hollow (owner's pick C): glowing mushrooms (the four biggest under the rock shelf by the
	-- cave mouth are the landmark; `clear` keeps spawn spots off them), glowing plant and flower tufts in patches along the
	-- trail, mossy rocks (today's rocks, same places)
	MUSHROOMS = {
		-- the landmark: the four biggest by the cave mouth, under the rock shelf (kept below its drawn underside, y 40)
		{ model = "GlowMushroomTall", x = -428, z = 1386, height = 21, yaw = 20, glow = "teal", clear = 11 },
		{ model = "GlowMushroomTall", x = -427, z = 1458, height = 20, yaw = 200, glow = "purple", clear = 10 },
		{ model = "GlowMushroomTall", x = -412, z = 1374, height = 22, yaw = 80, glow = "purple", clear = 11 },
		{ model = "GlowMushroomTall", x = -410, z = 1470, height = 21, yaw = 290, glow = "teal", clear = 10 },
		-- more giants along the cliffs
		{ model = "GlowMushroomTall", x = -270, z = 1535, height = 20, yaw = 130, glow = "teal", clear = 10 },
		{ model = "GlowMushroomTall", x = -432, z = 1345, height = 20, yaw = 310, glow = "purple", clear = 10 },
		{ model = "GlowMushroomTall", x = -430, z = 1500, height = 18, yaw = 50, glow = "teal", clear = 9 },
		{ model = "GlowMushroomTall", x = -250, z = 1505, height = 16, yaw = 240, glow = "purple", clear = 8 },
		-- clusters round the gorge
		{ model = "GlowMushroomCluster", x = -300, z = 1335, height = 12, yaw = 40, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -372, z = 1318, height = 13, yaw = 120, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -262, z = 1468, height = 11, yaw = 250, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -398, z = 1530, height = 10, yaw = 330, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -238, z = 1405, height = 10, yaw = 160, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -352, z = 1440, height = 9, yaw = 60, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -232, z = 1440, height = 11, yaw = 10, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -330, z = 1305, height = 10, yaw = 200, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -285, z = 1300, height = 9, yaw = 280, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -350, z = 1360, height = 9, yaw = 100, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -385, z = 1430, height = 8, yaw = 170, glow = "teal" },
		-- small ones near the trail and the clusters
		{ model = "GlowMushroomSmall", x = -290, z = 1352, height = 4.5, yaw = 10, glow = "teal" },
		{ model = "GlowMushroomSmall", x = -333, z = 1420, height = 4.5, yaw = 140, glow = "purple" },
		{ model = "GlowMushroomSmall", x = -300, z = 1470, height = 4, yaw = 220, glow = "teal" },
		{ model = "GlowMushroomSmall", x = -280, z = 1520, height = 4.5, yaw = 300, glow = "purple" },
		{ model = "GlowMushroomSmall", x = -415, z = 1342, height = 5, yaw = 70, glow = "teal" },
		{ model = "GlowMushroomSmall", x = -386, z = 1488, height = 4.5, yaw = 190, glow = "purple" },
		{ model = "GlowMushroomSmall", x = -255, z = 1376, height = 4, yaw = 250, glow = "teal" },
		{ model = "GlowMushroomSmall", x = -436, z = 1470, height = 4.5, yaw = 30, glow = "teal" },
	},
	TUFTS = {
		{ model = "GlowTuft", x = -251.1, z = 1348.2, height = 3.1, yaw = 300, glow = "blue" },
		{ model = "GlowFlowers", x = -255.1, z = 1350.6, height = 2.9, yaw = 320, glow = "blue" },
		{ model = "GlowTuft", x = -254.6, z = 1347.4, height = 3.4, yaw = 0, glow = "blue" },
		{ model = "GlowFlowers", x = -291.3, z = 1357.5, height = 2.4, yaw = 140, glow = "teal" },
		{ model = "GlowTuft", x = -294.9, z = 1359.1, height = 2.8, yaw = 260, glow = "teal" },
		{ model = "GlowFlowers", x = -293.8, z = 1356.6, height = 2.7, yaw = 310, glow = "teal" },
		{ model = "GlowTuft", x = -298.5, z = 1405.0, height = 3.5, yaw = 10, glow = "purple" },
		{ model = "GlowFlowers", x = -301.1, z = 1407.0, height = 2.4, yaw = 10, glow = "purple" },
		{ model = "GlowTuft", x = -301.6, z = 1403.0, height = 2.7, yaw = 310, glow = "purple" },
		{ model = "GlowFlowers", x = -322.9, z = 1424.2, height = 2.9, yaw = 150, glow = "blue" },
		{ model = "GlowTuft", x = -325.2, z = 1426.2, height = 3.2, yaw = 40, glow = "blue" },
		{ model = "GlowFlowers", x = -326.3, z = 1423.5, height = 3.4, yaw = 120, glow = "blue" },
		{ model = "GlowTuft", x = -303.9, z = 1446.8, height = 2.9, yaw = 180, glow = "teal" },
		{ model = "GlowFlowers", x = -306.0, z = 1448.7, height = 2.8, yaw = 310, glow = "teal" },
		{ model = "GlowTuft", x = -306.0, z = 1446.0, height = 2.4, yaw = 310, glow = "teal" },
		{ model = "GlowFlowers", x = -328.2, z = 1464.8, height = 3.1, yaw = 330, glow = "purple" },
		{ model = "GlowTuft", x = -330.0, z = 1467.2, height = 3.1, yaw = 70, glow = "purple" },
		{ model = "GlowFlowers", x = -330.4, z = 1464.3, height = 2.7, yaw = 210, glow = "purple" },
		{ model = "GlowTuft", x = -299.0, z = 1494.6, height = 2.7, yaw = 60, glow = "blue" },
		{ model = "GlowFlowers", x = -301.6, z = 1497.3, height = 2.5, yaw = 270, glow = "blue" },
		{ model = "GlowTuft", x = -302.3, z = 1493.1, height = 3.2, yaw = 150, glow = "blue" },
		{ model = "GlowFlowers", x = -309.4, z = 1523.4, height = 3.6, yaw = 0, glow = "teal" },
		{ model = "GlowTuft", x = -313.4, z = 1524.9, height = 2.8, yaw = 150, glow = "teal" },
		{ model = "GlowFlowers", x = -312.3, z = 1522.1, height = 3.1, yaw = 280, glow = "teal" },
		{ model = "GlowTuft", x = -293.0, z = 1391.3, height = 2.9, yaw = 180, glow = "purple" },
		{ model = "GlowFlowers", x = -295.5, z = 1392.3, height = 2.7, yaw = 260, glow = "purple" },
		{ model = "GlowTuft", x = -296.4, z = 1389.5, height = 3.5, yaw = 90, glow = "purple" },
		{ model = "GlowFlowers", x = -328.7, z = 1477.8, height = 2.9, yaw = 160, glow = "blue" },
		{ model = "GlowTuft", x = -331.2, z = 1479.0, height = 3.5, yaw = 300, glow = "blue" },
		{ model = "GlowFlowers", x = -331.9, z = 1476.1, height = 3.4, yaw = 90, glow = "blue" },
	},
	MOSS_ROCKS = {
		{ model = "MossRockA", x = -280, z = 1330, height = 5, yaw = 20 },
		{ model = "MossRockB", x = -380, z = 1340, height = 4, yaw = 110 },
		{ model = "MossRockA", x = -405, z = 1365, height = 6, yaw = 200 },
		{ model = "MossRockB", x = -260, z = 1420, height = 4, yaw = 290 },
		{ model = "MossRockA", x = -380, z = 1460, height = 6, yaw = 40 },
		{ model = "MossRockB", x = -270, z = 1480, height = 5, yaw = 160 },
		{ model = "MossRockA", x = -410, z = 1515, height = 4, yaw = 250 },
		{ model = "MossRockB", x = -345, z = 1310, height = 4, yaw = 330 },
		{ model = "MossRockA", x = -250, z = 1390, height = 5, yaw = 70 },
		{ model = "MossRockB", x = -430, z = 1460, height = 5, yaw = 120 },
	},
	-- The Meadow's ancient ruins (owner's pick B): arches, pillars, walls; a circle of standing stones as its landmark
	-- (WildValley.ring: `count` stones round x, z) and red-and-white mushroom rings
	RUINS = {
		-- round 2 (the owner: "it has random stuffs on it"): every piece gathered round the stone circle on its hill, one old
		-- site; the path from the trail (PATHS) comes up through the north arch
		{ model = "RuinArch", x = -128, z = 1222, height = 13, yaw = 0, clear = 9 },
		{ model = "RuinArch", x = -158, z = 1190, height = 12, yaw = 80, clear = 9 },
		-- pillars round the circle: two whole, two broken off, two fallen
		{ model = "RuinPillar", x = -108, z = 1180, height = 12, yaw = 30 },
		{ model = "RuinPillar", x = -150, z = 1215, height = 13, yaw = 260 },
		{ model = "RuinPillarBroken", x = -110, z = 1212, height = 9, yaw = 150 },
		{ model = "RuinPillarBroken", x = -148, z = 1172, height = 8, yaw = 90 },
		{ model = "RuinPillarFallen", x = -102, z = 1198, height = 2, yaw = 20 },
		{ model = "RuinPillarFallen", x = -134, z = 1167, height = 2, yaw = 100 },
		-- broken lines of low wall round the site
		{ model = "RuinWall", x = -155, z = 1205, height = 3, yaw = 90 },
		{ model = "RuinWall", x = -152, z = 1178, height = 2.8, yaw = 70 },
		{ model = "RuinWall", x = -118, z = 1168, height = 3, yaw = 20 },
		{ model = "RuinWall", x = -142, z = 1222, height = 2.6, yaw = 0 },
		{ model = "RuinWall", x = -103, z = 1188, height = 2.8, yaw = 100 },
	},
	-- Round 2: giant ancient trees framing the trail (GiantTreeA/B/C, Blender; the owner's pick "framed by giant trees"),
	-- solid at their trunks (COLLIDERS), spawn spots kept off their canopies (`clear`)
	GIANT_TREES = {
		{ model = "GiantTreeA", x = 30, z = 1192, height = 38, yaw = 30, clear = 12 },
		{ model = "GiantTreeC", x = -95, z = 1225, height = 34, yaw = 200, clear = 12 }, -- with GiantTreeB, a gate the trail passes through
		{ model = "GiantTreeB", x = -80, z = 1285, height = 40, yaw = 110, clear = 12 },
	},
	-- Round 2: footpaths off the trail (drawn like the trail, after it): up to the ruin hill through its north arch
	PATHS = {
		{ from = { x = -120, z = 1250, y = 0 }, to = { x = -129, z = 1212, y = 0 }, width = 5, material = "Ground" }, -- flat: the hill covers its last stretch
	},
	STONE_CIRCLE = { x = -130, z = 1195, radius = 13, count = 9, model = "StandingStone", height = 11 },
	MUSHROOM_RINGS = {
		{ x = -60, z = 1190, radius = 3, count = 8, model = "Toadstool", height = 1.4 },
		{ x = -5, z = 1300, radius = 3, count = 8, model = "Toadstool", height = 1.4 },
	},
	-- Ember Ridge's ember forest (owner's pick B): ember-crowned trees, red and orange crystal clusters, a dragon skeleton
	EMBER_TREES = {
		-- three groves: south of the trail as you come onto the ridge, by the north-east hill, by the east hill
		{ model = "EmberTree", x = -100, z = 1600, height = 18, yaw = 20, glow = "ember" },
		{ model = "EmberTree", x = -85, z = 1612, height = 16, yaw = 140, glow = "ember" },
		{ model = "EmberTree", x = -110, z = 1590, height = 15, yaw = 250, glow = "ember" },
		{ model = "EmberTree", x = -75, z = 1598, height = 14, yaw = 310, glow = "ember" },
		{ model = "EmberTree", x = 30, z = 1765, height = 19, yaw = 60, glow = "ember" },
		{ model = "EmberTree", x = 50, z = 1750, height = 17, yaw = 180, glow = "ember" },
		{ model = "EmberTree", x = 60, z = 1772, height = 15, yaw = 290, glow = "ember" },
		{ model = "EmberTree", x = 15, z = 1752, height = 14, yaw = 100, glow = "ember" },
		{ model = "EmberTree", x = 55, z = 1625, height = 20, yaw = 220, glow = "ember" },
		{ model = "EmberTree", x = 72, z = 1645, height = 16, yaw = 340, glow = "ember" },
		{ model = "EmberTree", x = 48, z = 1655, height = 15, yaw = 90, glow = "ember" },
		{ model = "EmberTree", x = 80, z = 1620, height = 14, yaw = 160, glow = "ember" },
	},
	EMBER_CRYSTALS = {
		{ x = -130, z = 1700, height = 4, yaw = 30 },
		{ x = -30, z = 1640, height = 5, yaw = 120 },
		{ x = 10, z = 1680, height = 4, yaw = 200 },
		{ x = -60, z = 1760, height = 5, yaw = 300 },
		{ x = -120, z = 1765, height = 4, yaw = 60 },
		{ x = 85, z = 1700, height = 3, yaw = 150 },
		{ x = -200, z = 1660, height = 4, yaw = 240 },
		{ x = -75, z = 1715, height = 6, yaw = 330 },
		{ x = 20, z = 1790, height = 4, yaw = 90 },
		{ x = -165, z = 1770, height = 5, yaw = 180 },
	},
	-- the landmark: half buried in the ash west of the middle, seen across the ridge from the second pass's top; about
	-- 50 long at this height (`clear` keeps spawn spots off it)
	SKELETON = {
		{ model = "DragonSkeleton", x = -150, z = 1735, height = 14, yaw = 200, glow = "ember", clear = 26 },
	},
	-- The glowing parts' colours (a model's `Glow` part turns Neon in its spot's `glow`; teal when it names none)
	GLOW = {
		teal = { 80, 235, 215 },
		purple = { 190, 120, 255 },
		blue = { 110, 190, 255 },
		ember = { 255, 100, 25 }, -- redder than it looks: Neon and bloom push it toward yellow
	},
	-- The ridge's crystal clusters (code-built like the Caves' CRYSTAL_LOOK ones), red with orange tips
	-- (not `solid`: they neither block players nor catch the camera, like the round's other small pieces)
	EMBER_CRYSTAL_LOOK = { color = { 255, 70, 40 }, tip = { 255, 170, 70 }, transparency = 0.12, solid = false },
	-- Invisible upright cylinders that stop players at a big piece (shares of the spot's height: `radius`, `height`; one
	-- in the middle, or one at each `spread` offset along the piece's own X, so an arch's legs block and its gap doesn't)
	COLLIDERS = {
		GlowMushroomTall = { radius = 0.08, height = 0.6 },
		GlowMushroomCluster = { radius = 0.18, height = 0.5 },
		MossRockA = { radius = 0.45, height = 0.8 },
		MossRockB = { radius = 0.45, height = 0.8 },
		RuinArch = { radius = 0.12, height = 1, spread = { -0.38, 0.38 } },
		RuinPillar = { radius = 0.12, height = 1 },
		RuinPillarBroken = { radius = 0.18, height = 0.8 },
		StandingStone = { radius = 0.2, height = 1 }, -- the Meadow's stone circle (solid in the arenas too)
		GiantTreeA = { radius = 0.08, height = 0.5 },
		GiantTreeB = { radius = 0.08, height = 0.5 },
		GiantTreeC = { radius = 0.08, height = 0.5 },
		RuinWall = { radius = 0.4, height = 1, spread = { -0.9, 0, 0.9 } },
		EmberTree = { radius = 0.06, height = 0.7 },
		DragonSkeleton = { radius = 0.3, height = 0.5, spread = { -1, 0, 1 } },
	},
	-- Town prop models (PropModels), scaled to `height` on the drawn ground (y: a ground height of its own)
	PROPS = {
		-- The meadow (biome 1): trees round its edges and in clumps, bushes, flowers and rocks
		{ model = "TreeA", x = -60, z = 1120, height = 22, yaw = 20 },
		{ model = "TreeB", x = 60, z = 1125, height = 20, yaw = 140 },
		{ model = "TreeC", x = -120, z = 1130, height = 19, yaw = 250 },
		{ model = "PineA", x = 85, z = 1150, height = 19, yaw = 10 },
		{ model = "TreeD", x = -180, z = 1135, height = 20, yaw = 75 },
		{ model = "TreeA", x = -185, z = 1225, height = 23, yaw = 200 },
		{ model = "TreeB", x = -188, z = 1118, height = 21, yaw = 300 }, -- moved off the stone circle's view (was -110, 1210)
		{ model = "TreeC", x = -30, z = 1270, height = 18, yaw = 30 },
		{ model = "TreeD", x = 30, z = 1295, height = 20, yaw = 120 },
		{ model = "PineB", x = 80, z = 1260, height = 21, yaw = 60 },
		{ model = "TreeA", x = -80, z = 1300, height = 22, yaw = 160 },
		{ model = "PineA", x = -195, z = 1170, height = 20, yaw = 220 },
		{ model = "TreeB", x = 40, z = 1230, height = 20, yaw = 90 },
		{ model = "Bush", x = -30, z = 1195, height = 3, yaw = 0 },
		{ model = "BushA", x = 40, z = 1150, height = 3, yaw = 90 },
		{ model = "BushB", x = 25, z = 1210, height = 2.6, yaw = 180 },
		{ model = "Bush", x = -150, z = 1240, height = 3, yaw = 45 },
		{ model = "BushA", x = -100, z = 1290, height = 3, yaw = 270 },
		{ model = "FlowerPink", x = -20, z = 1225, height = 2.4, yaw = 30 },
		{ model = "FlowerYellow", x = 30, z = 1180, height = 2.4, yaw = 80 },
		{ model = "FlowerWhite", x = 70, z = 1140, height = 2.4, yaw = 200 },
		{ model = "FlowerPink", x = -160, z = 1150, height = 2.4, yaw = 260 },
		{ model = "RockC", x = -90, z = 1125, height = 3, yaw = 60 },
		{ model = "RockB", x = 75, z = 1245, height = 3.5, yaw = 200 },
		-- the ruins round (spec 2026-11-04-valley-scenery-design): wildflower drifts, five of one colour each
		{ model = "FlowerYellow", x = -123.8, z = 1149.5, height = 2.2, yaw = 20 },
		{ model = "FlowerYellow", x = -124.3, z = 1151.1, height = 2.1, yaw = 80 },
		{ model = "FlowerYellow", x = -126.7, z = 1152.3, height = 2.4, yaw = 80 },
		{ model = "FlowerYellow", x = -127.6, z = 1148.9, height = 2.3, yaw = 130 },
		{ model = "FlowerYellow", x = -124.2, z = 1149.1, height = 2.0, yaw = 250 },
		{ model = "FlowerPink", x = -73.5, z = 1211.8, height = 2.2, yaw = 150 },
		{ model = "FlowerPink", x = -74.2, z = 1213.3, height = 2.4, yaw = 350 },
		{ model = "FlowerPink", x = -75.6, z = 1212.9, height = 2.1, yaw = 80 },
		{ model = "FlowerPink", x = -77.9, z = 1210.8, height = 2.6, yaw = 10 },
		{ model = "FlowerPink", x = -75.0, z = 1209.7, height = 2.3, yaw = 130 },
		{ model = "FlowerWhite", x = 22.0, z = 1254.5, height = 2.2, yaw = 210 },
		{ model = "FlowerWhite", x = 20.3, z = 1256.5, height = 2.0, yaw = 210 },
		{ model = "FlowerWhite", x = 18.3, z = 1256.7, height = 2.3, yaw = 200 },
		{ model = "FlowerWhite", x = 18.1, z = 1252.1, height = 2.6, yaw = 190 },
		{ model = "FlowerWhite", x = 21.4, z = 1253.1, height = 2.6, yaw = 180 },
		{ model = "FlowerBlue", x = 56.4, z = 1214.5, height = 2.6, yaw = 230 },
		{ model = "FlowerBlue", x = 55.2, z = 1216.2, height = 2.2, yaw = 190 },
		{ model = "FlowerBlue", x = 52.0, z = 1216.7, height = 2.1, yaw = 290 },
		{ model = "FlowerBlue", x = 53.3, z = 1214.3, height = 2.2, yaw = 30 },
		{ model = "FlowerBlue", x = 55.5, z = 1213.8, height = 2.1, yaw = 70 },
		{ model = "FlowerPink", x = -183.6, z = 1185.5, height = 2.1, yaw = 90 },
		{ model = "FlowerPink", x = -184.3, z = 1187.1, height = 2.5, yaw = 170 },
		{ model = "FlowerPink", x = -188.3, z = 1186.2, height = 2.3, yaw = 20 },
		{ model = "FlowerPink", x = -186.4, z = 1183.2, height = 2.5, yaw = 310 },
		{ model = "FlowerPink", x = -183.1, z = 1182.8, height = 2.2, yaw = 300 },
		{ model = "FlowerYellow", x = 16.0, z = 1204.9, height = 2.2, yaw = 180 },
		{ model = "FlowerYellow", x = 16.2, z = 1208.3, height = 2.1, yaw = 30 },
		{ model = "FlowerYellow", x = 11.9, z = 1205.9, height = 2.5, yaw = 190 },
		{ model = "FlowerYellow", x = 13.3, z = 1203.3, height = 2.3, yaw = 320 },
		{ model = "FlowerYellow", x = 16.0, z = 1202.0, height = 2.2, yaw = 330 },
		-- more trees in clumps on the edges
		{ model = "TreeA", x = 70, z = 1295, height = 22, yaw = 40 },
		{ model = "TreeC", x = 55, z = 1308, height = 19, yaw = 170 },
		{ model = "TreeB", x = -193, z = 1205, height = 21, yaw = 300 }, -- clear of the west wall's skyline lumps
		{ model = "TreeD", x = -200, z = 1248, height = 20, yaw = 80 },
		{ model = "TreeC", x = -150, z = 1112, height = 20, yaw = 210 },
		{ model = "PineB", x = -100, z = 1115, height = 21, yaw = 20 }, -- clear of the south wall's skyline lumps
		{ model = "TreeD", x = 90, z = 1225, height = 20, yaw = 140 },
		{ model = "TreeA", x = -170, z = 1118, height = 18, yaw = 260 },
	},
	-- Past the ridge's far cliff: the caldera's volcano (dressed like the canyon's: anchored, its lava glowing), its foot
	-- hidden behind the cliff, its lava streaks (its -Z side) toward the ridge
	VOLCANO = { model = "Volcano", x = -55, z = 1935, y = 20, height = 140, yaw = 0 }, -- round 2: bigger and further back (concept A: the volcano dominates), its foot still behind the north wall
	-- Settling (the owner 2026-11-05: "floating trees/mushrooms", a giant tree's roots in the air over a rounded wall top):
	-- a piece first stands at the drawn ground under its centre, then SceneryService measures its lowest surfaces (its
	-- bottom `band` of height) against the terrain under them by rays, on a `grid` x `grid` square over its box, and drops
	-- it by WildValley.settleDrop (the widest gap plus `sink`, never more than `cap` of its height); `perYield` pieces
	-- between waits
	SETTLE = { band = 0.04, grid = 15, sink = 0.4, cap = 0.2, perYield = 10 },
	-- How far each wide-footed backdrop piece's roots or stems spread from its centre, as a share of its height (measured
	-- in Studio 2026-11-05): each stands back from its wall's front so the foot on the side you see rests on the wall top
	-- (Lune-tested; the side behind may reach out over the wall's hidden back)
	FEET = { GiantTreeA = 0.28, GiantTreeB = 0.28, GiantTreeC = 0.28, GlowMushroomTall = 0.2, GlowMushroomCluster = 0.32, EmberTree = 0.18, CharredTree = 0.18 },
	-- Round 2 (spec 2026-11-05-valley-natural-design): what stands past the walls, never reachable. BACKDROP: pieces on
	-- the skylines and beyond (giant trees, scaled-up glow mushrooms, ember trees; `glow` for glowing ones), standing on
	-- the drawn ground, no colliders, streamed as whole models. MOUNTAINS: far range pieces at their own `y` (sunk so no
	-- base shows), always loaded so they never pop in, at least 150 studs out from the valley
	BACKDROP = {
		-- the Meadow (pick B): giant trees on the hills all round, big town trees between them
		{ model = "GiantTreeA", x = -156, z = 1093, height = 46, yaw = 20 },
		{ model = "GiantTreeB", x = -38, z = 1093, height = 50, yaw = 140 },
		{ model = "GiantTreeC", x = 70, z = 1090, height = 44, yaw = 260 },
		{ model = "GiantTreeB", x = -221, z = 1145, height = 48, yaw = 80 },
		{ model = "GiantTreeA", x = -222, z = 1232, height = 52, yaw = 200 },
		{ model = "GiantTreeC", x = 115, z = 1150, height = 46, yaw = 300 },
		{ model = "GiantTreeA", x = 116, z = 1262, height = 50, yaw = 30 },
		{ model = "GiantTreeB", x = -117, z = 1338, height = 48, yaw = 170 },
		{ model = "GiantTreeA", x = -12, z = 1332, height = 52, yaw = 60 },
		{ model = "GiantTreeC", x = 75, z = 1335, height = 44, yaw = 230 },
		{ model = "TreeA", x = -95, z = 1097, height = 34, yaw = 50 },
		{ model = "TreeD", x = 15, z = 1097, height = 32, yaw = 210 },
		{ model = "PineB", x = 100, z = 1100, height = 36, yaw = 0 },
		{ model = "TreeB", x = -214, z = 1188, height = 36, yaw = 120 },
		{ model = "TreeC", x = 109, z = 1205, height = 34, yaw = 250 },
		{ model = "TreeD", x = -60, z = 1330, height = 38, yaw = 330 },
		{ model = "TreeA", x = 35, z = 1330, height = 34, yaw = 90 },
		-- the Caves (pick A): tree-sized glowing mushrooms on every wall, fading into the fog
		{ model = "GlowMushroomTall", x = -460, z = 1310, height = 48, yaw = 10, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -462, z = 1349, height = 30, yaw = 120, glow = "purple" },
		{ model = "GlowMushroomTall", x = -460, z = 1385, height = 44, yaw = 230, glow = "purple" },
		{ model = "GlowMushroomTall", x = -460, z = 1460, height = 50, yaw = 60, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -460, z = 1504, height = 28, yaw = 300, glow = "purple" },
		{ model = "GlowMushroomTall", x = -460, z = 1535, height = 42, yaw = 150, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -440, z = 1565, height = 30, yaw = 20, glow = "teal" },
		{ model = "GlowMushroomTall", x = -399, z = 1565, height = 46, yaw = 200, glow = "purple" },
		{ model = "GlowMushroomTall", x = -360, z = 1561, height = 40, yaw = 80, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -326, z = 1564, height = 28, yaw = 260, glow = "purple" },
		{ model = "GlowMushroomTall", x = -438, z = 1275, height = 40, yaw = 140, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -401, z = 1278, height = 26, yaw = 40, glow = "teal" },
		{ model = "GlowMushroomTall", x = -356, z = 1276, height = 44, yaw = 310, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -300, z = 1274, height = 28, yaw = 190, glow = "purple" },
		{ model = "GlowMushroomTall", x = -207, z = 1371, height = 30, yaw = 100, glow = "teal" },
		{ model = "GlowMushroomCluster", x = -208, z = 1420, height = 24, yaw = 220, glow = "purple" },
		{ model = "GlowMushroomTall", x = -206, z = 1470, height = 32, yaw = 340, glow = "purple" },
		{ model = "GlowMushroomCluster", x = -207, z = 1515, height = 22, yaw = 70, glow = "teal" },
		-- Ember Ridge (pick A): ember trees and charred trees on its hills, rising toward the volcano
		{ model = "EmberTree", x = -110, z = 1808, height = 28, yaw = 30, glow = "ember" },
		{ model = "EmberTree", x = -50, z = 1808, height = 30, yaw = 150, glow = "ember" },
		{ model = "EmberTree", x = 10, z = 1808, height = 26, yaw = 270, glow = "ember" },
		{ model = "EmberTree", x = 70, z = 1808, height = 28, yaw = 90, glow = "ember" },
		{ model = "CharredTree", x = -82, z = 1809, height = 18, yaw = 210 },
		{ model = "CharredTree", x = 40, z = 1809, height = 16, yaw = 330 },
		{ model = "EmberTree", x = 109, z = 1600, height = 26, yaw = 40, glow = "ember" },
		{ model = "EmberTree", x = 109, z = 1660, height = 28, yaw = 160, glow = "ember" },
		{ model = "EmberTree", x = 109, z = 1720, height = 24, yaw = 280, glow = "ember" },
		{ model = "EmberTree", x = 109, z = 1780, height = 30, yaw = 20, glow = "ember" },
		{ model = "EmberTree", x = -227, z = 1673, height = 26, yaw = 120, glow = "ember" },
		{ model = "EmberTree", x = -228, z = 1732, height = 28, yaw = 240, glow = "ember" },
		{ model = "EmberTree", x = -227, z = 1780, height = 24, yaw = 0, glow = "ember" },
		{ model = "EmberTree", x = -186, z = 1784, height = 26, yaw = 200, glow = "ember" },
		{ model = "CharredTree", x = -165, z = 1797, height = 18, yaw = 60 },
		{ model = "CharredTree", x = -80, z = 1549, height = 16, yaw = 110 },
		{ model = "EmberTree", x = 0, z = 1550, height = 24, yaw = 230, glow = "ember" },
		{ model = "CharredTree", x = 61, z = 1548, height = 18, yaw = 350 },
	},
	MOUNTAINS = {
		-- snowy ranges south of the Meadow, west of the Caves and east of the Meadow
		{ model = "MountainSnow", x = -180, z = 820, y = -20, height = 130, yaw = 0 },
		{ model = "MountainSnow", x = 150, z = 860, y = -20, height = 110, yaw = 15 },
		{ model = "MountainSnow", x = -470, z = 900, y = -20, height = 120, yaw = -30 },
		{ model = "MountainSnow", x = -720, z = 1250, y = -10, height = 140, yaw = 90 },
		{ model = "MountainSnow", x = -700, z = 1560, y = -10, height = 120, yaw = 80 },
		{ model = "MountainSnow", x = 330, z = 1180, y = -20, height = 110, yaw = 95 },
		-- dark jagged ranges round Ember Ridge, the volcano among them
		{ model = "MountainDark", x = 320, z = 1650, y = 10, height = 120, yaw = 90 },
		{ model = "MountainDark", x = -200, z = 2050, y = 10, height = 130, yaw = 10 },
		{ model = "MountainDark", x = 150, z = 2020, y = 10, height = 110, yaw = -15 },
		{ model = "MountainDark", x = -430, z = 1900, y = 10, height = 120, yaw = -45 },
	},
	-- Round 2 (the owner's pick "burnt hills to the volcano"): glowing lava streams down the volcano's ridge-facing side
	-- (WildValley.lavaRays cast onto its surface, joined by strips `width` wide), from near the crater to where the
	-- ridge's far wall hides it
	VOLCANO_LAVA = {
		steps = 8,
		reach = 1,
		width = 3.5,
		streams = {
			{ angle = -55, wobble = 6, from = 0.86, to = 0.5 },
			{ angle = -25, wobble = 5, from = 0.9, to = 0.45 },
			{ angle = 12, wobble = 7, from = 0.88, to = 0.42 },
			{ angle = 38, wobble = 5, from = 0.85, to = 0.5 },
			{ angle = 66, wobble = 6, from = 0.82, to = 0.55 },
		},
	},
	-- Blue crystal clusters in the gorge (code-built like Frostpeak's ice crystals), two at the cave's lip
	CRYSTALS = {
		{ x = -440, z = 1405, height = 6, yaw = 300 },
		{ x = -440, z = 1436, height = 5, yaw = 10 },
		{ x = -280, z = 1440, height = 5, yaw = 20 },
		{ x = -360, z = 1380, height = 4, yaw = 80 },
		{ x = -395, z = 1480, height = 5, yaw = 150 },
		{ x = -250, z = 1350, height = 4, yaw = 230 },
		{ x = -320, z = 1530, height = 4, yaw = 100 },
		{ x = -410, z = 1330, height = 4, yaw = 190 },
	},
	-- The ridge (biome 3): the caldera's charred trees and obsidian shards (Blender props), and three smoking vents
	CHARRED = {
		{ model = "CharredTree", x = -60, z = 1620, height = 10, yaw = 140 },
		{ model = "CharredTree", x = 70, z = 1700, height = 10, yaw = 75 },
		{ model = "CharredTree", x = -100, z = 1780, height = 9, yaw = 300 },
		{ model = "CharredTree", x = 90, z = 1630, height = 10, yaw = 210 },
	},
	SHARDS = {
		{ model = "ObsidianShards", x = -90, z = 1700, height = 4, yaw = 0 },
		{ model = "ObsidianShards", x = 10, z = 1650, height = 4, yaw = 120 },
		{ model = "ObsidianShards", x = -160, z = 1770, height = 3.5, yaw = 240 },
		{ model = "ObsidianShards", x = 50, z = 1720, height = 4, yaw = 60 },
		{ model = "ObsidianShards", x = -200, z = 1690, height = 4.5, yaw = 300 },
		{ model = "ObsidianShards", x = -70, z = 1760, height = 3.5, yaw = 170 },
		{ model = "ObsidianShards", x = 80, z = 1590, height = 4, yaw = 90 },
	},
	VENTS = {
		{ x = -110, z = 1690, height = 4 },
		{ x = 40, z = 1610, height = 3.5 },
		{ x = -30, z = 1740, height = 4 },
	},
}
