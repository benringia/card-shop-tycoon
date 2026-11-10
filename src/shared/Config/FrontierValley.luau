--!strict
-- The Frontier valley (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md): the Frontier place's world on
-- the Wild valley's engine (Util/WildValley; Util/Place.getValley picks this config in the Frontier). One trail through
-- three areas at three heights: the camp and Frostwood (ground y 0) in the south, a climb east onto Stormpeak (y 30),
-- a drop north into the Rift's crater (y -12), the Dungeon gate at the trail's west end. A dead giant (a hollow terrain
-- mass with a rock roof) lies between the three, so none can be seen from the last. Same shape as Config/WildValley's
-- shared keys; the Wild's own pieces (stream, bridge, cave, volcano, vents) are left out. World coordinates in the
-- Frontier place (x -140..540, z -95..720). Plain data, Lune-tested (tests/FrontierValley.spec.luau).
return {
	MAX_CELLS = 105000, -- the Wild valley's budget (the Frontier place has no town)
	SURFACE_LIFT = 2, -- TownTerrain.SURFACE_LIFT
	TRAIL_WIDTH = 10,
	MARKER_SPACING = 12,
	MAX_STEP = 1.5,
	PORTAL_CLEAR = 30,
	BOARD_CLEAR = 6,
	POPULATION = { QUIET = 8, PER_PLAYER = 2, FREE_PLAYERS = 3, MAX = 24, RESPAWN_QUIET = { 20, 40 }, RESPAWN_BUSY = { 10, 20 }, CHECK_SECONDS = 2 },
	SPOT_SPACING = 18,
	SPOT_MARGIN = 20,
	SPOT_PROP_CLEAR = 6,
	-- The camp: the arrival pad (Config/Frontier ENTRANCE_OFFSET), the spring, the way home and the camp's tents; no
	-- monsters or scenery
	ARRIVAL_CLEAR = { minX = -32, maxX = 44, minZ = -66, maxZ = -16 },
	-- The biomes, indexed like Config/Frontier ZONES. Stormpeak's and the Rift's outlines reach out to their passes'
	-- ends (the trail's pass points are inside the area they lead to)
	BIOMES = {
		{ centre = { x = 45, z = 40 }, ground = 0, -- Frostwood
			outline = { { x = -110, z = -68 }, { x = 150, z = -70 }, { x = 205, z = -50 }, { x = 205, z = 140 }, { x = 60, z = 142 }, { x = -110, z = 138 }, { x = -117, z = 40 } },
			portal = { x = -30, z = 40, faces = { x = 0, z = 30 } }, board = { x = 12, z = -6 } },
		{ centre = { x = 405, z = 140 }, ground = 30, -- Stormpeak
			outline = { { x = 300, z = -38 }, { x = 470, z = -42 }, { x = 515, z = 0 }, { x = 515, z = 300 }, { x = 480, z = 322 }, { x = 416, z = 322 }, { x = 410, z = 334 }, { x = 390, z = 334 }, { x = 384, z = 322 }, { x = 300, z = 322 }, { x = 296, z = 150 }, { x = 296, z = 80 }, { x = 288, z = 74 }, { x = 288, z = 46 }, { x = 296, z = 40 } },
			portal = { x = 445, z = 145, faces = { x = 425, z = 165 } }, board = { x = 305, z = 90 } },
		{ centre = { x = 212, z = 582 }, ground = -12, -- the Rift
			outline = { { x = -72, z = 466 }, { x = 495, z = 466 }, { x = 497, z = 600 }, { x = 440, z = 698 }, { x = 100, z = 698 }, { x = -72, z = 690 } },
			portal = { x = 290, z = 600, faces = { x = 275, z = 565 } }, board = { x = 372, z = 482 } },
	},
	-- The trail: the camp, north and east through Frostwood, a straight climb east onto Stormpeak, north across it, a
	-- straight drop north into the Rift, then west to the Dungeon gate. Its passes run along an axis, so each upper floor
	-- starts square to the ramp's top
	TRAIL = {
		{ x = 0, z = -40, y = 0 }, { x = 0, z = 20, y = 0 }, { x = 60, z = 55, y = 0 }, { x = 130, z = 60, y = 0 },
		{ x = 190, z = 60, y = 0 }, { x = 290, z = 60, y = 30 }, { x = 350, z = 100, y = 30 }, { x = 420, z = 180, y = 30 },
		{ x = 400, z = 330, y = 30 }, { x = 400, z = 470, y = -12 }, { x = 330, z = 540, y = -12 }, { x = 200, z = 590, y = -12 },
		{ x = 60, z = 610, y = -12 }, { x = -20, z = 620, y = -12 },
	},
	TRAIL_MATERIAL = { "Ground", "Pavement", "CrackedLava" }, -- packed earth in the snow, flagstones, the Rift's violet cracks
	BIOME_FLOOR = { "Snow", "Slate", "Basalt" },
	BIOME_CLIFF = { "Rock", "Slate", "Basalt" },
	-- The Frontier's terrain colours (the Frontier place has no town to share them with)
	MATERIAL_COLORS = {
		Snow = { 222, 230, 240 },
		Glacier = { 160, 200, 230 },
		Ground = { 112, 98, 88 },
		Rock = { 104, 106, 116 },
		Slate = { 82, 86, 98 },
		Pavement = { 118, 116, 124 },
		Basalt = { 46, 38, 58 },
		CrackedLava = { 130, 70, 200 },
	},
	PASS = { width = 44, depth = 20 },
	PASS_BANKS = {
		spacing = 9, out = 4, drift = 4, radius = { 10, 13 }, rise = { 6, 12 }, grassShare = 0.5, outcrop = 3, seed = 5151,
		props = {
			-- Frostwood up to Stormpeak: snowy pines and rocks
			{ every = 14, back = 6, trees = { "PineA", "PineB", "Pine" }, rocks = { "RockA", "RockB" }, height = { 16, 22 }, rockHeight = { 4, 6 },
				behind = { every = 11, back = 9, trees = { "PineB", "Pine" }, height = { 22, 28 } } },
			-- Stormpeak down into the Rift: dead trees and obsidian
			{ every = 16, back = 6, trees = { "CharredTree" }, rocks = { "ObsidianShards" }, height = { 12, 17 }, rockHeight = { 4, 6 }, glow = "violet" },
		},
	},
	-- Mounds and frozen ponds (Glacier, barely raised): tops `height` over their biome's ground
	HILLS = {
		{ x = -70, z = -20, radius = 16, height = 4, material = "Snow" },
		{ x = 110, z = -30, radius = 16, height = 4, material = "Snow" },
		{ x = -65, z = 112, radius = 12, height = 0.8, material = "Glacier" }, -- a frozen pond by the fort ruins
		{ x = 150, z = 100, radius = 10, height = 0.8, material = "Glacier" },
		{ x = 480, z = 60, radius = 16, height = 5, material = "Rock" },
		{ x = 340, z = 230, radius = 18, height = 5, material = "Rock" },
		{ x = 60, z = 662, radius = 16, height = 4, material = "Basalt" },
	},
	-- The walkable edge (invisible walls along it): Frostwood, the climbing pass east, Stormpeak, the drop north, the Rift
	EDGE_WALL = { bottom = -20, top = 90 },
	EDGE = {
		{ x = -122, z = -76 }, { x = 212, z = -76 }, { x = 212, z = 41 }, { x = 292, z = 41 }, { x = 292, z = -46 },
		{ x = 521, z = -46 }, { x = 521, z = 326 }, { x = 419, z = 326 }, { x = 419, z = 461 }, { x = 503, z = 461 },
		{ x = 503, z = 701 }, { x = -79, z = 701 }, { x = -79, z = 461 }, { x = 381, z = 461 }, { x = 381, z = 326 },
		{ x = 292, z = 326 }, { x = 292, z = 79 }, { x = 212, z = 79 }, { x = 212, z = 146 }, { x = -122, z = 146 },
	},
	TERRAIN_READY_ATTRIBUTE = "FrontierTerrainReady",
	TERRAIN_WAIT = 20,
	-- The way home's board by the camp, and the camp's home portal (the Frontier's ice-blue crystal ring)
	RETURN_SIGN = { x = 20, z = -34 },
	HOME = { model = "PortalFrontier", look = "Frontier", title = "THE FRONTIER" },
	BOARD_FACE_BACK = 25,
	ARROWS = {
		{ x = 160, z = 40, arms = { { zone = 2, toward = { x = 290, z = 60 } }, { text = "CAMP", toward = { x = 0, z = -40 } } } },
		{ x = 425, z = 300, arms = { { zone = 3, toward = { x = 400, z = 470 } }, { text = "CAMP", toward = { x = 290, z = 60 } } } },
	},
	MARKER = { size = 1.3, color = { 150, 205, 255 }, across = true }, -- icy blue trail stones, square to the trail
	-- The Dungeon portal (Config/Frontier DUNGEON_PORTAL): a crystal arch at the trail's west end, the farthest walk
	DUNGEON_GATE = { x = -45, z = 622, faces = { x = -20, z = 620 } },

	-- The terrain (shapes as Config/Scenery's; WildValley.terrainOps adds the hills, passes, trail and arenas). Each floor
	-- is filled to its ground - 2; Stormpeak's floor starts at the climb's top (x 290) and ends at the drop's top (z 330)
	TERRAIN = {
		-- Frostwood: its floor, low snowy hills south and west, the snowy rise south of the climb and the giant's foot north
		-- of it (both hollow: walls and a roof, as the giant is)
		{ shape = "Block", x = 45, y = -4, z = 38, size = { x = 340, y = 4, z = 236 }, material = "Snow" },
		{ shape = "Block", x = 75.5, y = 8, z = -87, size = { x = 429, y = 28, z = 14 }, material = "Snow" },
		{ shape = "Block", x = -132, y = 8, z = 38, size = { x = 14, y = 28, z = 236 }, material = "Snow" },
		{ shape = "Block", x = 221, y = 15, z = -27, size = { x = 12, y = 42, z = 118 }, material = "Snow" },
		{ shape = "Block", x = 284, y = 15, z = -27, size = { x = 12, y = 42, z = 118 }, material = "Snow" },
		{ shape = "Block", x = 252.5, y = 15, z = 26, size = { x = 51, y = 42, z = 12 }, material = "Snow" },
		{ shape = "Block", x = 252.5, y = 34, z = -27, size = { x = 75, y = 4, z = 118 }, material = "Snow" },
		{ shape = "Block", x = 220, y = 19, z = 119, size = { x = 12, y = 50, z = 62 }, material = "Rock" },
		{ shape = "Block", x = 252, y = 19, z = 94, size = { x = 76, y = 50, z = 12 }, material = "Rock" },
		{ shape = "Block", x = 252, y = 42, z = 119, size = { x = 76, y = 4, z = 62 }, material = "Rock" },
		{ shape = "Block", x = 284, y = 35, z = 119, size = { x = 12, y = 18, z = 62 }, material = "Rock" },
		-- The dead giant: a hollow mass (walls and a roof) between all three areas, topping out at y 52-56
		{ shape = "Block", x = 75.5, y = 21, z = 156, size = { x = 429, y = 54, z = 12 }, material = "Rock" }, -- facing Frostwood
		{ shape = "Block", x = 284, y = 40, z = 246, size = { x = 12, y = 32, z = 168 }, material = "Rock" }, -- facing Stormpeak
		{ shape = "Block", x = 328, y = 42, z = 336, size = { x = 76, y = 28, z = 12 }, material = "Rock" }, -- Stormpeak's north, west of the drop
		{ shape = "Block", x = 366, y = 21, z = 388, size = { x = 12, y = 70, z = 116 }, material = "Basalt" }, -- the drop's west side
		{ shape = "Block", x = 120.5, y = 18, z = 454, size = { x = 491, y = 68, z = 8 }, material = "Basalt" }, -- facing the Rift
		{ shape = "Block", x = 82.5, y = 50, z = 304, size = { x = 415, y = 4, z = 308 }, material = "Rock" }, -- its roof
		{ shape = "Block", x = 328, y = 54, z = 394, size = { x = 76, y = 4, z = 128 }, material = "Basalt" },
		-- Stormpeak: its floor, slate cliffs east, south and north-east, the drop's east side
		{ shape = "Block", x = 407.5, y = 26, z = 140, size = { x = 235, y = 4, z = 380 }, material = "Slate" },
		{ shape = "Block", x = 532, y = 44, z = 140, size = { x = 14, y = 36, z = 400 }, material = "Slate" },
		{ shape = "Block", x = 414.5, y = 44, z = -57, size = { x = 249, y = 36, z = 14 }, material = "Slate" },
		{ shape = "Block", x = 483.5, y = 44, z = 336, size = { x = 111, y = 36, z = 12 }, material = "Slate" },
		{ shape = "Block", x = 434, y = 21, z = 394, size = { x = 12, y = 70, z = 104 }, material = "Basalt" },
		-- The Rift: its crater floor and a tall basalt rim all round
		{ shape = "Block", x = 212, y = -16, z = 581.5, size = { x = 590, y = 4, z = 247 }, material = "Basalt" },
		{ shape = "Block", x = 212, y = 15, z = 709, size = { x = 620, y = 62, z = 8 }, material = "Basalt" },
		{ shape = "Block", x = -87, y = 15, z = 581.5, size = { x = 8, y = 62, z = 261 }, material = "Basalt" },
		{ shape = "Block", x = 511, y = 15, z = 581.5, size = { x = 8, y = 62, z = 261 }, material = "Basalt" },
		{ shape = "Block", x = 467.5, y = 15, z = 454, size = { x = 83, y = 62, z = 8 }, material = "Basalt" },
	},
	-- Lumps along the walls' tops (WildValley.skylineOps): snowy hills round Frostwood, the giant's lumpy body, slate
	-- crags round Stormpeak, the Rift's jagged rim
	SKYLINES = {
		{ material = "Snow", top = 22, seed = 41, points = { { x = -135, z = -87 }, { x = 220, z = -87 } }, spacing = 22, radius = { 7, 13 }, rise = { 4, 10 }, drift = 2 },
		{ material = "Snow", top = 22, seed = 42, points = { { x = -132, z = -70 }, { x = -132, z = 145 } }, spacing = 22, radius = { 7, 13 }, rise = { 4, 10 }, drift = 2 },
		{ material = "Snow", top = 36, seed = 43, points = { { x = 256, z = -80 }, { x = 256, z = 22 } }, spacing = 22, radius = { 7, 13 }, rise = { 4, 8 }, drift = 2 },
		{ material = "Rock", top = 48, seed = 44, points = { { x = -120, z = 158 }, { x = 280, z = 158 } }, spacing = 22, radius = { 7, 13 }, rise = { 6, 14 }, drift = 2 },
		{ material = "Rock", top = 56, seed = 45, points = { { x = 286, z = 170 }, { x = 286, z = 325 } }, spacing = 22, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 62, seed = 46, points = { { x = 534, z = -50 }, { x = 534, z = 335 } }, spacing = 22, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 62, seed = 47, points = { { x = 300, z = -59 }, { x = 525, z = -59 } }, spacing = 22, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 62, seed = 48, points = { { x = 440, z = 338 }, { x = 525, z = 338 } }, spacing = 22, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 51, points = { { x = -90, z = 714 }, { x = 515, z = 714 } }, spacing = 22, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 52, points = { { x = -92, z = 470 }, { x = -92, z = 705 } }, spacing = 22, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 53, points = { { x = 516, z = 470 }, { x = 516, z = 705 } }, spacing = 22, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 52, seed = 54, points = { { x = -120, z = 450 }, { x = 360, z = 450 } }, spacing = 22, radius = { 7, 13 }, rise = { 6, 14 }, drift = 2 },
	},
	CARVES = {},

	-- The boss portals (WildService.BuildBossArenas) and each boss's arena copies far from the valley (as the Wild's)
	BOSS_PORTAL = { model = "PortalArena", height = 20 },
	ARENA_FIELD = { x = 1600, z = 1400, y = 0, spacing = 1200 },
	ARENA_CLEARING = {
		size = { 136, 148, 140 },
		ground = 360,
		sink = 0.5,
		thickness = 2,
		materials = { "Snow", "Slate", "Basalt" },
		apronColors = { { 222, 230, 240 }, { 82, 86, 98 }, { 46, 38, 58 } },
	},
	ARENA_COPIES_FOR_TERRAIN = 4,
	ARENA_HOLD = 120,
	ARENA_EDGE_INSET = 4,
	ARENA_EDGE_SIDES = 24,
	ARENA_LIFT = 0.15,
	ARENA_LOOKS = {
		{ floor = { 200, 216, 232 }, floorMaterial = "Ice", path = { 170, 192, 214 }, pathMaterial = "Ice", post = { 140, 172, 204 }, postMaterial = "Ice", postSize = 1.4, postHeight = 6, tip = { 150, 220, 255 } },
		{ floor = { 80, 84, 96 }, floorMaterial = "Slate", path = { 100, 104, 116 }, pathMaterial = "Slate", post = { 70, 72, 84 }, postMaterial = "Slate", postSize = 1.6, postHeight = 7, tip = { 255, 230, 80 } },
		{ floor = { 40, 30, 52 }, floorMaterial = "Basalt", path = { 58, 44, 70 }, pathMaterial = "Basalt", post = { 48, 36, 60 }, postMaterial = "Basalt", postSize = 1.6, postHeight = 6, tip = { 190, 110, 255 } },
	},
	-- Each Frontier boss's arena (stand-in pieces until the Frontier's props: Task 5 of the plan)
	ARENA_DRESSING = {
		{ -- the Frost Tyrant's frozen hall
			walls = {
				{ radius = 60, count = 30, models = { "PineA", "PineB", "Pine" }, height = { 30, 40 } },
			},
			inner = {
				{ models = { "RuinPillar", "RuinPillarBroken" }, count = 8, radius = { 44, 66 }, height = { 10, 16 } },
				{ models = { "RockA", "RockB" }, count = 10, radius = { 42, 68 }, height = { 4, 7 } },
			},
			effects = { { kind = "snow", rate = 20, y = 40, size = 150 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9120505297", volume = 0.3, range = 90 },
		},
		{ -- the Storm Sovereign's summit
			walls = {
				{ radius = 60, count = 24, models = { "StandingStone" }, height = { 18, 26 } },
				{ radius = 68, count = 30, models = { "RockA", "RockB", "RockC" }, height = { 16, 26 } },
			},
			inner = {
				{ models = { "RuinPillarBroken", "RuinPillarFallen" }, count = 8, radius = { 44, 64 }, height = { 4, 9 } },
			},
			effects = { { kind = "ash", rate = 6, y = 40, size = 160 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9120505297", volume = 0.3, range = 90 },
		},
		{ -- the Rift Devourer's island
			walls = {
				{ radius = 64, count = 30, models = { "Stalagmite", "LavaCliff" }, height = { 20, 34 } },
			},
			inner = {
				{ models = { "ObsidianShards" }, count = 11, radius = { 42, 70 }, height = { 4, 8 } },
				{ models = { "Bones" }, count = 6, radius = { 42, 68 }, height = { 4, 7 } },
			},
			crystals = { count = 10, radius = { 44, 70 }, height = { 4, 7 } },
			effects = { { kind = "glints", rate = 5, y = 4, size = 140 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9120505297", volume = 0.3, range = 90 },
		},
	},
	ARENA_FENCE = 36,
	-- Each arena's way home: the Frontier's crystal ring
	ARENA_HOME = {
		distance = 46,
		{ model = "PortalFrontier", look = "Frontier" },
		{ model = "PortalFrontier", look = "Frontier" },
		{ model = "PortalFrontier", look = "Frontier" },
	},

	-- The scenery lists (Util/WildValley.scenery): kept off the trail, the camp, the portals and boards. DRESSED_LISTS
	-- are anchored, given colliders and settled (SceneryService); PROPS are town props placed as they are; CRYSTALS are
	-- code-built in CRYSTAL_LOOK. Stand-in models until the Titans' Graveyard props (plan Task 3)
	PROP_LISTS = { "PROPS", "RUINS", "BONES", "SPIRES", "CRYSTALS" },
	DRESSED_LISTS = { "RUINS", "BONES", "SPIRES" },
	-- Frostwood's ruined forts: one west of the camp, one north-east
	RUINS = {
		{ model = "RuinArch", x = -85, z = 80, height = 13, yaw = 90, clear = 9 },
		{ model = "RuinWall", x = -95, z = 60, height = 3, yaw = 0 },
		{ model = "RuinWall", x = -72, z = 100, height = 3, yaw = 90 },
		{ model = "RuinPillar", x = -100, z = 98, height = 12, yaw = 30 },
		{ model = "RuinPillarBroken", x = -60, z = 75, height = 9, yaw = 150 },
		{ model = "RuinPillarFallen", x = -78, z = 52, height = 2, yaw = 20 },
		{ model = "RuinWall", x = 90, z = 112, height = 3, yaw = 20 },
		{ model = "RuinPillar", x = 120, z = 122, height = 12, yaw = 200 },
		{ model = "RuinPillarBroken", x = 62, z = 120, height = 8, yaw = 80 },
	},
	-- Bones: by Frostwood's west hills, on Stormpeak, the dragon skeleton in the Rift
	BONES = {
		{ model = "Bones", x = -62, z = -45, height = 5, yaw = 40 },
		{ model = "Bones", x = 470, z = 250, height = 6, yaw = 120 },
		{ model = "DragonSkeleton", x = 120, z = 655, height = 14, yaw = 160, glow = "violet", clear = 26 },
	},
	-- Stormpeak's rock spires
	SPIRES = {
		{ model = "RockA", x = 330, z = 0, height = 20, yaw = 30, clear = 8 },
		{ model = "RockB", x = 480, z = -10, height = 24, yaw = 200, clear = 8 },
		{ model = "RockA", x = 500, z = 200, height = 22, yaw = 110, clear = 8 },
		{ model = "RockB", x = 330, z = 180, height = 18, yaw = 300, clear = 8 },
	},
	-- The Rift's violet crystal clusters (code-built)
	CRYSTALS = {
		{ x = 150, z = 650, height = 6, yaw = 10 },
		{ x = 240, z = 640, height = 7, yaw = 80 },
		{ x = 420, z = 560, height = 6, yaw = 150 },
		{ x = -20, z = 560, height = 5, yaw = 220 },
		{ x = 60, z = 520, height = 6, yaw = 300 },
		{ x = 330, z = 660, height = 7, yaw = 40 },
	},
	CRYSTAL_LOOK = { color = { 150, 80, 255 }, tip = { 220, 180, 255 }, transparency = 0.12 },
	GLOW = {
		teal = { 80, 235, 215 },
		blue = { 110, 190, 255 },
		violet = { 170, 90, 255 },
		ice = { 150, 215, 255 },
	},
	COLLIDERS = {
		RuinArch = { radius = 0.12, height = 1, spread = { -0.38, 0.38 } },
		RuinPillar = { radius = 0.12, height = 1 },
		RuinPillarBroken = { radius = 0.18, height = 0.8 },
		RuinWall = { radius = 0.4, height = 1, spread = { -0.9, 0, 0.9 } },
		StandingStone = { radius = 0.2, height = 1 },
		DragonSkeleton = { radius = 0.3, height = 0.5, spread = { -1, 0, 1 } },
		RockA = { radius = 0.4, height = 0.8 },
		RockB = { radius = 0.4, height = 0.8 },
	},
	-- Town props placed as they are: pines round Frostwood, rocks, dead trees on Stormpeak, obsidian in the Rift
	PROPS = {
		{ model = "PineA", x = -100, z = -50, height = 22, yaw = 20 },
		{ model = "PineB", x = -60, z = -62, height = 24, yaw = 140 },
		{ model = "Pine", x = 62, z = -60, height = 20, yaw = 250 },
		{ model = "PineA", x = 120, z = -56, height = 23, yaw = 10 },
		{ model = "PineB", x = 180, z = -40, height = 25, yaw = 75 },
		{ model = "Pine", x = 190, z = 20, height = 21, yaw = 200 },
		{ model = "PineA", x = -105, z = 20, height = 22, yaw = 300 },
		{ model = "PineB", x = -100, z = 128, height = 26, yaw = 160 },
		{ model = "Pine", x = 20, z = 132, height = 22, yaw = 30 },
		{ model = "PineA", x = 160, z = 130, height = 24, yaw = 120 },
		{ model = "PineB", x = 192, z = 128, height = 22, yaw = 60 },
		{ model = "RockB", x = 100, z = 10, height = 3, yaw = 60 },
		{ model = "RockC", x = -20, z = 100, height = 3.5, yaw = 200 },
		{ model = "CharredTree", x = 360, z = -20, height = 14, yaw = 30 },
		{ model = "CharredTree", x = 500, z = 100, height = 15, yaw = 140 },
		{ model = "CharredTree", x = 470, z = 295, height = 13, yaw = 260 },
		{ model = "RockC", x = 380, z = 60, height = 4, yaw = 90 },
		{ model = "ObsidianShards", x = 400, z = 650, height = 6, yaw = 20 },
		{ model = "ObsidianShards", x = 0, z = 670, height = 5, yaw = 200 },
	},
	SETTLE = { band = 0.04, grid = 15, sink = 0.4, cap = 0.2, perYield = 10 },
	FEET = {},
	-- Past the walls: tall pines over Frostwood's hills, crags over Stormpeak, stalagmites on the Rift's rim
	BACKDROP = {
		{ model = "PineB", x = -100, z = -100, height = 40, yaw = 20 },
		{ model = "Pine", x = 0, z = -102, height = 44, yaw = 140 },
		{ model = "PineA", x = 100, z = -100, height = 40, yaw = 250 },
		{ model = "PineB", x = 200, z = -98, height = 42, yaw = 80 },
		{ model = "Pine", x = -150, z = 0, height = 40, yaw = 300 },
		{ model = "PineA", x = -150, z = 100, height = 44, yaw = 30 },
		{ model = "RockA", x = 548, z = 50, height = 30, yaw = 10 },
		{ model = "RockB", x = 548, z = 250, height = 34, yaw = 200 },
		{ model = "Stalagmite", x = 0, z = 728, height = 30, yaw = 0 },
		{ model = "Stalagmite", x = 200, z = 730, height = 36, yaw = 90 },
		{ model = "Stalagmite", x = 400, z = 728, height = 32, yaw = 180 },
	},
	-- Far ranges: snowy ones south and west, dark ones east and north
	MOUNTAINS = {
		{ model = "MountainSnow", x = -150, z = -330, y = -20, height = 130, yaw = 0 },
		{ model = "MountainSnow", x = 180, z = -360, y = -20, height = 120, yaw = 20 },
		{ model = "MountainSnow", x = -420, z = 100, y = -20, height = 140, yaw = 90 },
		{ model = "MountainDark", x = 800, z = 120, y = 10, height = 150, yaw = 90 },
		{ model = "MountainDark", x = 780, z = 520, y = 0, height = 140, yaw = 100 },
		{ model = "MountainDark", x = 0, z = 980, y = 0, height = 160, yaw = 10 },
		{ model = "MountainDark", x = 380, z = 1000, y = 0, height = 140, yaw = -15 },
		{ model = "MountainDark", x = -400, z = 640, y = 0, height = 150, yaw = 70 },
	},
}
