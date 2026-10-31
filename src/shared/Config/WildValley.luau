--!strict
-- The Wild valley (round 2, spec 2026-10-31-wild-valley-v2-design, the user's layout A "Winding valley"): the main
-- game's Wild as one S-shaped trail through three biomes at three heights: the meadow (ground y 0), a right turn and a
-- climb into the limestone gorge (y 15), a left turn and a climb onto the Ember Ridge (y 35), round a central mass that
-- hides each biome from the last. World coordinates (the valley sits at x -470..124, z 1080..1824). Plain data,
-- Lune-tested with Util/WildValley (the ground modelled by TownTerrain.groundAt over WildValley.terrainOps). Main game
-- only: the Frontier builds its own Wild without this.
return {
	MAX_CELLS = 90000, -- the valley's terrain with the boss arena clearings (estimated 4-stud cells)
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
	-- Gentle mounds: buried balls whose tops stand `height` above their biome's ground
	HILLS = {
		{ x = 60, z = 1200, radius = 16, height = 4, material = "Grass" },
		{ x = 55, z = 1285, radius = 16, height = 4, material = "Grass" },
		{ x = -95, z = 1165, radius = 16, height = 4, material = "Grass" },
		{ x = -165, z = 1195, radius = 16, height = 4, material = "Grass" },
		{ x = -40, z = 1300, radius = 16, height = 4, material = "Grass" },
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
	STREAM = { from = { x = 98, z = 1185 }, to = { x = -60, z = 1148 }, width = 6, pond = { x = -60, z = 1148, radius = 8 } },
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
		{ shape = "Block", x = -45.5, y = 8, z = 1092, size = { x = 339, y = 28, z = 24 }, material = "Grass" }, -- the hills behind the arrival
		{ shape = "Block", x = -220, y = 8, z = 1183, size = { x = 30, y = 28, z = 158 }, material = "Grass" }, -- the meadow's west hills
		{ shape = "Block", x = 112, y = 8, z = 1213, size = { x = 24, y = 28, z = 218 }, material = "Grass" }, -- the meadow's east hills
		{ shape = "Ball", x = 60, y = 8, z = 1094, radius = 12, material = "Grass" },
		{ shape = "Ball", x = -120, y = 10, z = 1095, radius = 14, material = "Grass" },
		{ shape = "Ball", x = -222, y = 12, z = 1150, radius = 12, material = "Grass" },
		{ shape = "Ball", x = 115, y = 10, z = 1250, radius = 12, material = "Grass" },
		-- The central mass: grassy toward the meadow, limestone toward the gorge, basalt toward the ridge; its roof mossy
		-- on the meadow's half and basalt on the ridge's (seen over the walls from each)
		{ shape = "Block", x = -52.5, y = 20.5, z = 1332, size = { x = 305, y = 53, z = 20 }, material = "Grass" },
		{ shape = "Block", x = -205, y = 28, z = 1440, size = { x = 20, y = 38, z = 196 }, material = "Limestone" },
		{ shape = "Block", x = -57.5, y = 37, z = 1548, size = { x = 315, y = 20, z = 20 }, material = "Basalt" },
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
		{ shape = "Block", x = -389, y = 30.5, z = 1565, size = { x = 162, y = 43, z = 24 }, material = "Limestone" },
		{ shape = "Block", x = -364, y = 13, z = 1277, size = { x = 212, y = 38, z = 26 }, material = "Limestone" },
		{ shape = "Block", x = -233.7, y = 28, z = 1540.6, yaw = 17.46, size = { x = 41, y = 38, z = 12 }, material = "Limestone" }, -- closes the north-east corner up to the second pass's wall
		{ shape = "Block", x = -435, y = 12.5, z = 1360, size = { x = 20, y = 7, z = 60 }, material = "Limestone" },
		{ shape = "Block", x = -436, y = 13, z = 1470, size = { x = 18, y = 8, z = 44 }, material = "Limestone" },
		{ shape = "Block", x = -350, y = 12.5, z = 1545, size = { x = 60, y = 7, z = 16 }, material = "Limestone" },
		{ shape = "Ball", x = -450, y = 40, z = 1330, radius = 12, material = "Limestone" },
		{ shape = "Ball", x = -448, y = 44, z = 1500, radius = 10, material = "Limestone" },
		{ shape = "Ball", x = -420, y = 45, z = 1562, radius = 12, material = "Limestone" },
		{ shape = "Ball", x = -300, y = 30, z = 1275, radius = 12, material = "Limestone" },
		-- The ridge: its cracked-lava floor (turned along the second pass), basalt cliffs all round, jagged rims
		{ shape = "Block", x = -43.31, y = 31, z = 1683.07, yaw = -122.28, size = { x = 310, y = 4, z = 340 }, material = "CrackedLava" },
		{ shape = "Block", x = -58, y = 45.5, z = 1812, size = { x = 364, y = 33, z = 24 }, material = "Basalt" },
		{ shape = "Block", x = 112, y = 44.5, z = 1679, size = { x = 24, y = 31, z = 242 }, material = "Basalt" },
		{ shape = "Block", x = -227.5, y = 34.5, z = 1720, size = { x = 25, y = 51, z = 160 }, material = "Basalt" },
		{ shape = "Block", x = -176.7, y = 44.5, z = 1790, yaw = -33.7, size = { x = 76, y = 31, z = 24 }, material = "Basalt" },
		{ shape = "Block", x = -100, y = 64, z = 1810, yaw = 25, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 60, y = 63, z = 1812, yaw = -35, size = { x = 18, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = 112, y = 62, z = 1640, yaw = 40, size = { x = 16, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -228, y = 62, z = 1700, yaw = -20, size = { x = 16, y = 14, z = 12 }, material = "Basalt" },
	},
	-- Cut and filled after the trail: the meadow's stream and pond (water only fills empty space, so the channel is
	-- carved first, then filled, then floored below so nobody sinks out of the world) and the gorge's cave mouth
	CARVES = {
		{ shape = "Block", x = 19, y = -4, z = 1166.5, yaw = -13.18, size = { x = 162, y = 8, z = 6 }, material = "Air" },
		{ shape = "Block", x = -60, y = -4, z = 1148, yaw = 45, size = { x = 16, y = 8, z = 16 }, material = "Air" },
		{ shape = "Block", x = 19, y = -5, z = 1166.5, yaw = -13.18, size = { x = 162, y = 6, z = 6 }, material = "Water" }, -- the stream
		{ shape = "Block", x = -60, y = -5, z = 1148, yaw = 45, size = { x = 16, y = 6, z = 16 }, material = "Water" }, -- its pond
		{ shape = "Block", x = 19, y = -10, z = 1166.5, yaw = -13.18, size = { x = 166, y = 4, z = 10 }, material = "Ground" },
		{ shape = "Block", x = -60, y = -10, z = 1148, yaw = 45, size = { x = 20, y = 4, z = 20 }, material = "Ground" },
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
	-- boss at ARENA_FIELD x + (c - 1) * spacing, z + (z - 1) * spacing, on a terrain clearing `size` wide in the zone's
	-- material (Slate terrain is Frostpeak's ice blue map-wide, so the gorge's is Limestone) with `count` of its props
	-- round it `ring` studs out, `height` { min, max } tall, and a root-arch portal home outside its gate.
	-- ARENA_COPIES_FOR_TERRAIN mirrors Bosses.ARENA_COPIES for WildValley.terrainOps (Lune-tested equal).
	BOSS_PORTAL = { model = "PortalArena", height = 20 },
	ARENA_FIELD = { x = 1600, z = 1200, y = 0, spacing = 1200 },
	ARENA_CLEARING = { size = 124, ring = 62, materials = { "Grass", "Limestone", "Basalt" }, props = { { "TreeA", "TreeB", "PineA" }, { "RockA", "RockB", "RockD" }, { "CharredTree" } }, count = 12, height = { 16, 22 } },
	ARENA_COPIES_FOR_TERRAIN = 4,
	-- Studs from a copy's middle a fighter still holds it (BossRules.stillInCopy): out to its clearing's corners,
	-- which invisible walls close (WildValley.arenaEdge)
	ARENA_HOLD = 90,
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

	-- Town prop models (PropModels), scaled to `height` on the drawn ground (y: a ground height of its own)
	PROPS = {
		-- The meadow (biome 1): trees round its edges and in clumps, bushes, flowers and rocks
		{ model = "TreeA", x = -60, z = 1120, height = 22, yaw = 20 },
		{ model = "TreeB", x = 60, z = 1125, height = 20, yaw = 140 },
		{ model = "TreeC", x = -120, z = 1130, height = 19, yaw = 250 },
		{ model = "PineA", x = 85, z = 1150, height = 19, yaw = 10 },
		{ model = "TreeD", x = -180, z = 1135, height = 20, yaw = 75 },
		{ model = "TreeA", x = -185, z = 1225, height = 23, yaw = 200 },
		{ model = "TreeB", x = -110, z = 1210, height = 21, yaw = 300 },
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
		{ model = "FlowerBlue", x = -130, z = 1180, height = 2.4, yaw = 140 },
		{ model = "FlowerWhite", x = 70, z = 1140, height = 2.4, yaw = 200 },
		{ model = "FlowerPink", x = -160, z = 1150, height = 2.4, yaw = 260 },
		{ model = "RockC", x = -90, z = 1125, height = 3, yaw = 60 },
		{ model = "RockB", x = 75, z = 1245, height = 3.5, yaw = 200 },
		-- The gorge (biome 2): rocks over its limestone floor
		{ model = "RockA", x = -280, z = 1330, height = 5, yaw = 20 },
		{ model = "RockB", x = -380, z = 1340, height = 4, yaw = 110 },
		{ model = "RockC", x = -405, z = 1365, height = 6, yaw = 200 },
		{ model = "RockD", x = -260, z = 1420, height = 4, yaw = 290 },
		{ model = "Rock", x = -380, z = 1460, height = 6, yaw = 40 },
		{ model = "RockA", x = -270, z = 1480, height = 5, yaw = 160 },
		{ model = "RockB", x = -410, z = 1515, height = 4, yaw = 250 },
		{ model = "RockC", x = -345, z = 1310, height = 4, yaw = 330 },
		{ model = "RockD", x = -250, z = 1390, height = 5, yaw = 70 },
		{ model = "Rock", x = -430, z = 1460, height = 5, yaw = 120 },
	},
	-- Past the ridge's far cliff: the caldera's volcano (dressed like the canyon's: anchored, its lava glowing), its foot
	-- hidden behind the cliff, its lava streaks (its -Z side) toward the ridge
	VOLCANO = { model = "Volcano", x = -55, z = 1890, y = 20, height = 90, yaw = 0 },
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
		{ model = "CharredTree", x = -150, z = 1700, height = 11, yaw = 20 },
		{ model = "CharredTree", x = -60, z = 1620, height = 10, yaw = 140 },
		{ model = "CharredTree", x = 20, z = 1610, height = 12, yaw = 250 },
		{ model = "CharredTree", x = 70, z = 1700, height = 10, yaw = 75 },
		{ model = "CharredTree", x = -100, z = 1780, height = 9, yaw = 300 },
		{ model = "CharredTree", x = -180, z = 1740, height = 10, yaw = 190 },
		{ model = "CharredTree", x = -40, z = 1600, height = 11, yaw = 30 },
		{ model = "CharredTree", x = 90, z = 1630, height = 10, yaw = 210 },
		{ model = "CharredTree", x = 30, z = 1785, height = 11, yaw = 110 },
		{ model = "CharredTree", x = -140, z = 1610, height = 9, yaw = 330 },
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
