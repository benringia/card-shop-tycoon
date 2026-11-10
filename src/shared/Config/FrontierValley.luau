--!strict
-- The Frontier valley (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md): the Frontier place's world on
-- the Wild valley's engine (Util/WildValley; Util/Place.getValley picks this config in the Frontier). One trail through
-- three areas at three heights: the camp and Frostwood (ground y 0) in the south, a climb east onto Stormpeak (y 30),
-- a drop north into the Rift's crater (y -12), the Dungeon gate at the trail's west end. A dead giant (a hollow terrain
-- mass with a rock roof) lies between the three, so none can be seen from the last. Same shape as Config/WildValley's
-- shared keys; the Wild's own pieces (stream, bridge, cave, volcano, vents) are left out. World coordinates in the
-- Frontier place (x -140..540, z -95..720). Plain data, Lune-tested (tests/FrontierValley.spec.luau).
return {
	MAX_CELLS = 140000, -- the main place runs its town and the Wild valley at 245k (Config/Scenery, measured 60 fps); the Frontier has no town (raised from 105k for the cliffs' outcrops, 2026-11-10)
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
		Mud = { 60, 56, 50 }, -- Stormpeak's swamps
	},
	PASS = { width = 44, depth = 20 },
	PASS_BANKS = {
		spacing = 9, out = 4, drift = 4, radius = { 10, 13 }, rise = { 6, 12 }, grassShare = 0.5, outcrop = 3, seed = 5151,
		props = {
			-- Frostwood up to Stormpeak: snowy pines and rocks
			{ every = 14, back = 6, trees = { "SnowPine" }, rocks = { "RockA", "RockB" }, height = { 16, 22 }, rockHeight = { 4, 6 },
				behind = { every = 11, back = 9, trees = { "SnowPine" }, height = { 22, 28 } } },
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
		{ x = 360, z = 20, radius = 14, height = 6, material = "Slate" },
		{ x = 500, z = 250, radius = 14, height = 6, material = "Rock" },
		{ x = 305, z = 205, radius = 12, height = 5, material = "Slate" },
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
	RETURN_SIGN = { x = -10, z = -20 }, -- clear of the spring (the owner 2026-11-10: they overlapped)
	HOME = { model = "PortalFrontier", look = "Frontier", title = "THE FRONTIER", name = "the Frontier" },
	BOARD_FACE_BACK = 25,
	ARROWS = {
		{ x = 160, z = 40, arms = { { zone = 2, toward = { x = 290, z = 60 } }, { text = "CAMP", toward = { x = 0, z = -40 } } } },
		{ x = 425, z = 300, arms = { { zone = 3, toward = { x = 400, z = 470 } }, { text = "CAMP", toward = { x = 290, z = 60 } } } },
	},
	MARKER = { size = 1.3, color = { 150, 205, 255 }, across = true }, -- icy blue trail stones, square to the trail
	-- Effects (Controllers/FrontierFxController, Util/FrontierFxRules; spec: darker and more dangerous than the Wild).
	-- Looks and sounds only: nothing hurts outside a fight. Snow falls round you in Frostwood; pairs of red eyes watch
	-- from its fog and fade as you come close (`eyeFade`), blinking now and then; lightning flashes over Stormpeak with
	-- thunder (`every` { min, max } seconds), a tornado turns far past its east cliffs; a violet vortex turns over the
	-- Rift, its floating rocks bob and the ground trembles now and then (a small camera shake and a rumble)
	FX = {
		snow = { zone = 1, rate = 40, height = 30, size = 120 },
		eyes = {
			{ x = -108, z = -10, y = 4 }, { x = -100, z = 112, y = 5 }, { x = -40, z = -60, y = 4 }, { x = 150, z = -60, y = 4 },
			{ x = 195, z = -28, y = 5 }, { x = 198, z = 108, y = 4 }, { x = 10, z = 136, y = 5 }, { x = 140, z = 136, y = 4 },
		},
		eyeFade = { near = 30, far = 90 },
		eyeColor = { 255, 40, 30 },
		eyeBlink = { 3, 8 },
		lightning = {
			zone = 2, arena = 2, every = { 8, 16 }, flash = 0.18, volume = 0.25, -- quieter (the owner 2026-11-10); also in the Storm Sovereign's arena
			sounds = { "rbxassetid://9120016021", "rbxassetid://9120016256", "rbxassetid://9120018172" }, -- Pro Sound Effects: Thunder Cracks Big Rumbling Blasts Booming 2, 3; Thunder Distant Boom 20
		},
		tornado = { x = 700, z = 160, height = 180, radius = 26, turn = 40, color = { 70, 74, 86 } },
		-- light rain round you on Stormpeak (the owner: "a bit of rain droplets not too much"; its sound is the area's
		-- ambient loop, Config/Music FRONTIER)
		-- a box `size` wide `height` over you; drops `drop` studs, stretched `length` along their fall (then: "I havent
		-- seen rain in this region make it rain a little": 50 a second over 110 studs was about none to see)
		rain = { zone = 2, rate = 400, height = 30, size = 70, speed = { 60, 75 }, length = 3, drop = 0.3, transparency = 0.3 },
		-- the storm's eye over each of the Storm Sovereign's arena copies (the spec: "a storm eye overhead")
		stormEye = { arena = 2, y = 150, size = 380, turn = 5, color = { 150, 170, 210 }, transparency = 0.4, image = "rbxassetid://82162011115712" },
		vortex = { zone = 3, x = 212, z = 582, y = 220, size = 520, turn = 3, color = { 150, 80, 255 }, transparency = 0.35, image = "rbxassetid://82162011115712" }, -- Config/WildLoading SWIRL
		floating = { bob = 0.8, speed = 0.5 },
		tremor = { zone = 3, every = { 20, 40 }, length = 1.6, shake = 0.35, sound = "rbxassetid://9113221477", volume = 0.4 }, -- Pro Sound Effects: Avalanche Rumble 3
	},
	-- Roblox's clouds over the Frontier (SceneryService.StartValley): heavy and grey
	CLOUDS = { cover = 0.78, density = 0.6, color = { 118, 122, 138 } },
	-- The Dungeon portal (Config/Frontier DUNGEON_PORTAL): a crystal arch at the trail's west end, the farthest walk
	DUNGEON_GATE = { x = -45, z = 622, faces = { x = -20, z = 620 }, model = "PortalArena", look = "Arena", height = 22 }, -- a real portal (the owner: "some portals dont have models")

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
		{ shape = "Block", x = 532, y = 41, z = 140, size = { x = 14, y = 30, z = 400 }, material = "Slate" },
		{ shape = "Block", x = 414.5, y = 41, z = -57, size = { x = 249, y = 30, z = 14 }, material = "Slate" },
		{ shape = "Block", x = 483.5, y = 41, z = 336, size = { x = 111, y = 30, z = 12 }, material = "Slate" },
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
		{ material = "Snow", top = 22, seed = 41, points = { { x = -135, z = -87 }, { x = 220, z = -87 } }, spacing = 26, radius = { 7, 13 }, rise = { 4, 10 }, drift = 2 },
		{ material = "Snow", top = 22, seed = 42, points = { { x = -132, z = -70 }, { x = -132, z = 145 } }, spacing = 26, radius = { 7, 13 }, rise = { 4, 10 }, drift = 2 },
		{ material = "Snow", top = 36, seed = 43, points = { { x = 256, z = -80 }, { x = 256, z = 22 } }, spacing = 26, radius = { 7, 13 }, rise = { 4, 8 }, drift = 2 },
		{ material = "Rock", top = 48, seed = 44, points = { { x = -120, z = 158 }, { x = 280, z = 158 } }, spacing = 26, radius = { 7, 13 }, rise = { 6, 14 }, drift = 2 },
		{ material = "Rock", top = 56, seed = 45, points = { { x = 286, z = 170 }, { x = 286, z = 325 } }, spacing = 26, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 56, seed = 46, points = { { x = 534, z = -50 }, { x = 534, z = 335 } }, spacing = 26, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 56, seed = 47, points = { { x = 300, z = -59 }, { x = 525, z = -59 } }, spacing = 26, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Slate", top = 56, seed = 48, points = { { x = 440, z = 338 }, { x = 525, z = 338 } }, spacing = 26, radius = { 7, 13 }, rise = { 5, 12 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 51, points = { { x = -90, z = 714 }, { x = 515, z = 714 } }, spacing = 26, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 52, points = { { x = -92, z = 470 }, { x = -92, z = 705 } }, spacing = 26, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 50, seed = 53, points = { { x = 516, z = 470 }, { x = 516, z = 705 } }, spacing = 26, radius = { 7, 13 }, rise = { 6, 16 }, drift = 2 },
		{ material = "Basalt", top = 52, seed = 54, points = { { x = -120, z = 450 }, { x = 360, z = 450 } }, spacing = 26, radius = { 7, 13 }, rise = { 6, 14 }, drift = 2 },
	},
	CARVES = {},
	-- Rocky outcrops along the cliffs' faces (WildValley.faceOps; the owner 2026-11-10: "minimize flat walls. make the
	-- terrain look natural"): each line runs along a wall's walkable face; `facing` points into the area; balls' centres
	-- at `height`, `rows` staggered rows. Not along the passes (their banks are natural already)
	FACES = {
		-- Frostwood: snowy hills south, west and east, the dead giant's rocky flank north
		{ material = "Snow", seed = 61, points = { { x = -118, z = -80 }, { x = 205, z = -80 } }, facing = { x = 0, z = 1 }, out = 1, drift = 2, spacing = 14, rows = 1, radius = { 6, 10 }, height = { 1, 12 } },
		{ material = "Snow", seed = 62, points = { { x = -125, z = -75 }, { x = -125, z = 145 } }, facing = { x = 1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 1, radius = { 6, 10 }, height = { 1, 12 } },
		{ material = "Snow", seed = 63, points = { { x = 215, z = -75 }, { x = 215, z = 22 } }, facing = { x = -1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 6, 10 }, height = { 1, 26 } },
		{ material = "Rock", seed = 64, points = { { x = 214, z = 94 }, { x = 214, z = 148 } }, facing = { x = -1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 6, 10 }, height = { 2, 30 } },
		{ material = "Rock", seed = 65, points = { { x = -120, z = 150 }, { x = 208, z = 150 } }, facing = { x = 0, z = -1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 12 }, height = { 2, 34 } },
		-- Stormpeak: slate crags all round
		{ material = "Slate", seed = 71, points = { { x = 525, z = -45 }, { x = 525, z = 325 } }, facing = { x = -1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 11 }, height = { 31, 50 } },
		{ material = "Slate", seed = 72, points = { { x = 295, z = -50 }, { x = 520, z = -50 } }, facing = { x = 0, z = 1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 11 }, height = { 31, 50 } },
		{ material = "Slate", seed = 73, points = { { x = 434, z = 330 }, { x = 520, z = 330 } }, facing = { x = 0, z = -1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 11 }, height = { 31, 50 } },
		{ material = "Rock", seed = 74, points = { { x = 294, z = 330 }, { x = 360, z = 330 } }, facing = { x = 0, z = -1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 11 }, height = { 31, 50 } },
		{ material = "Rock", seed = 75, points = { { x = 290, z = 166 }, { x = 290, z = 326 } }, facing = { x = 1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 7, 11 }, height = { 31, 50 } },
		{ material = "Slate", seed = 76, points = { { x = 290, z = -46 }, { x = 290, z = 26 } }, facing = { x = 1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 1, radius = { 6, 10 }, height = { 31, 36 } },
		-- The Rift: a jagged basalt crater rim
		{ material = "Basalt", seed = 81, points = { { x = -80, z = 705 }, { x = 505, z = 705 } }, facing = { x = 0, z = -1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 8, 13 }, height = { -10, 30 } },
		{ material = "Basalt", seed = 82, points = { { x = -83, z = 462 }, { x = -83, z = 700 } }, facing = { x = 1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 8, 13 }, height = { -10, 30 } },
		{ material = "Basalt", seed = 83, points = { { x = 507, z = 462 }, { x = 507, z = 700 } }, facing = { x = -1, z = 0 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 8, 13 }, height = { -10, 30 } },
		{ material = "Basalt", seed = 84, points = { { x = -80, z = 458 }, { x = 360, z = 458 } }, facing = { x = 0, z = 1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 8, 13 }, height = { -10, 30 } },
		{ material = "Basalt", seed = 85, points = { { x = 440, z = 458 }, { x = 505, z = 458 } }, facing = { x = 0, z = 1 }, out = 1, drift = 2, spacing = 14, rows = 2, radius = { 8, 13 }, height = { -10, 30 } },
	},

	-- The boss portals (WildService.BuildBossArenas) and each boss's arena copies far from the valley (as the Wild's)
	BOSS_PORTAL = { model = "PortalArena", height = 20 },
	ARENA_FIELD = { x = 1600, z = 1400, y = 0, spacing = 1200 },
	ARENA_CLEARING = {
		size = { 156, 156, 156 }, -- walls 72-76 out need ground to stand on
		ground = 360,
		sink = 0.5,
		thickness = 2,
		materials = { "Snow", "Slate", "Basalt" },
		apronColors = { { 222, 230, 240 }, { 82, 86, 98 }, { 28, 18, 42 } }, -- the Rift's island over a dark void
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
	-- Each Frontier boss's arena (WildValley.arenaDressing; the Wild's rules: rows of walls all round, inner pieces clear
	-- of the fight, the path and the way home). The Frontier's bosses are big, so the walls stand 72+ out
	ARENA_DRESSING = {
		{ -- the Frost Tyrant's frozen hall: ice pillars round it, snowy pines behind, his broken ice throne at the far end
			walls = {
				{ radius = 72, count = 34, models = { "IcePillar" }, height = { 18, 28 } },
				{ radius = 74, count = 36, models = { "SnowPine" }, height = { 34, 44 } },
			},
			inner = {
				{ models = { "RockA", "RockB" }, count = 8, radius = { 54, 68 }, height = { 3, 5 } },
				{ models = { "GiantSword" }, count = 4, radius = { 54, 66 }, height = { 10, 14 } },
			},
			backdrop = { model = "IceThrone", distance = 62, height = 26, yaw = 90, sink = 1 },
			effects = { { kind = "snow", rate = 24, y = 40, size = 150 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9114057104", volume = 0.35, range = 90 }, -- Pro Sound Effects: Desert Wind Whistley Light Gusts 1
		},
		{ -- the Storm Sovereign's summit: a ring of storm stones, rock spires behind, broken stones and bones
			walls = {
				{ radius = 72, count = 34, models = { "StormStone" }, height = { 14, 20 } },
				{ radius = 74, count = 34, models = { "RockSpire" }, height = { 26, 36 } },
			},
			inner = {
				{ models = { "RockA", "RockB", "RockC" }, count = 8, radius = { 54, 68 }, height = { 3, 6 } },
				{ models = { "Bones" }, count = 4, radius = { 54, 66 }, height = { 4, 6 } },
			},
			effects = { { kind = "ash", rate = 6, y = 40, size = 160 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9120018695", volume = 0.4, range = 90 }, -- Pro Sound Effects: Thunder Distant Rumble 2
		},
		{ -- the Rift Devourer's island: dark stalagmites round it, floating rocks over it, violet crystals, the void below
			walls = {
				{ radius = 72, count = 34, models = { "Stalagmite" }, height = { 22, 34 } },
			},
			inner = {
				{ models = { "FloatingRock" }, count = 6, radius = { 55, 68 }, height = { 6, 9 }, y = 14 },
				{ models = { "Bones" }, count = 4, radius = { 54, 68 }, height = { 4, 7 } },
			},
			crystals = { count = 10, radius = { 54, 70 }, height = { 4, 7 } },
			effects = { { kind = "glints", rate = 5, y = 4, size = 140 }, { kind = "mist", rate = 3, y = 2, size = 140 } },
			sound = { id = "rbxassetid://9112775624", volume = 0.4, range = 90 }, -- Pro Sound Effects: Eerie Presence 3
		},
	},
	ARENA_FENCE = 50, -- its bosses' arenaRadius (Config/Bosses; was 36 like the Wild's, the owner 2026-11-10: "make the arena wider")
	-- Each arena's way home: the Frontier's crystal ring
	ARENA_HOME = {
		distance = 58, -- past the fence (50), inside the walls (72)
		{ model = "PortalFrontier", look = "Frontier" },
		{ model = "PortalFrontier", look = "Frontier" },
		{ model = "PortalFrontier", look = "Frontier" },
	},

	-- The scenery lists (Util/WildValley.scenery): kept off the trail, the camp, the portals and boards. DRESSED_LISTS
	-- are anchored, given colliders and settled (SceneryService); PROPS are town props placed as they are; CRYSTALS are
	-- code-built in CRYSTAL_LOOK. The Titans' Graveyard props: tools/blender/build_frontier_props.py (docs/props.md)
	PROP_LISTS = { "PROPS", "RUINS", "BONES", "SPIRES", "CRYSTALS", "STORM_CRYSTALS", "SWAMPS" },
	DRESSED_LISTS = { "RUINS", "BONES", "SPIRES" },
	-- Frostwood: two ruined forts (west and north-east) with red banners, giant swords stuck in the snow
	RUINS = {
		{ model = "FortRuin", x = -92, z = 92, height = 16, yaw = 30, clear = 10 },
		{ model = "FortWall", x = -70, z = 62, height = 7, yaw = 0, clear = 10 },
		{ model = "FortWall", x = -105, z = 60, height = 6.5, yaw = 90, clear = 10 },
		{ model = "FortRuin", x = 115, z = 120, height = 14, yaw = 200, clear = 10 },
		{ model = "FortWall", x = 82, z = 118, height = 6.5, yaw = 10, clear = 10 },
		{ model = "GiantSword", x = -72, z = 8, height = 14, yaw = 30, clear = 5 },
		{ model = "GiantSword", x = 150, z = 10, height = 12, yaw = 200, clear = 5 },
		{ model = "GiantSword", x = 45, z = 105, height = 15, yaw = 120, clear = 5 },
		{ model = "GiantSword", x = -40, z = 120, height = 13, yaw = 80, clear = 5 },
	},
	-- Bones: by Frostwood's west hills, on Stormpeak, the dragon skeleton in the Rift
	BONES = {
		{ model = "Bones", x = -62, z = -45, height = 5, yaw = 40 },
		{ model = "Bones", x = 470, z = 250, height = 6, yaw = 120 },
		-- in and by Stormpeak's swamps
		{ model = "Bones", x = 416, z = 103, height = 5, yaw = 30 },
		{ model = "Bones", x = 396, z = 104, height = 4, yaw = 210 },
		{ model = "Bones", x = 386, z = 188, height = 4, yaw = 80 },
		{ model = "Bones", x = 377, z = 178, height = 5, yaw = 300 },
		{ model = "DragonSkeleton", x = 120, z = 655, height = 14, yaw = 160, glow = "violet", clear = 26 },
	},
	-- Stormpeak: rock spires, wrecked watchtowers, the giant horned skull, storm stones with glowing runes
	SPIRES = {
		{ model = "RockSpire", x = 330, z = 0, height = 22, yaw = 30, clear = 8 },
		{ model = "RockSpire", x = 480, z = -10, height = 26, yaw = 200, clear = 8 },
		{ model = "RockSpire", x = 500, z = 200, height = 24, yaw = 110, clear = 8 },
		{ model = "RockSpire", x = 330, z = 180, height = 20, yaw = 300, clear = 8 },
		{ model = "WreckedTower", x = 370, z = 20, height = 16, yaw = 20, clear = 9 },
		{ model = "WreckedTower", x = 462, z = 282, height = 14, yaw = 200, clear = 9 },
		{ model = "HornedSkull", x = 380, z = 250, height = 10, yaw = 210, glow = "storm", clear = 12 },
		{ model = "StormStone", x = 310, z = 140, height = 9, yaw = 80, glow = "storm" },
		{ model = "StormStone", x = 430, z = -20, height = 9, yaw = 0, glow = "storm" },
		{ model = "StormStone", x = 505, z = 120, height = 9, yaw = 270, glow = "storm" },
		{ model = "RockSpire", x = 470, z = 25, height = 20, yaw = 150, clear = 8 },
		{ model = "RockSpire", x = 320, z = 260, height = 24, yaw = 60, clear = 8 },
		{ model = "RockSpire", x = 362, z = 300, height = 18, yaw = 250, clear = 8 },
		{ model = "StormStone", x = 340, z = 150, height = 9, yaw = 120, glow = "storm" },
		{ model = "WreckedTower", x = 305, z = 300, height = 15, yaw = 300, clear = 9 },
		-- giant spires, a tall wrecked tower and storm stones from small to huge (the owner 2026-11-10: "add some storm
		-- related elements in various sizes")
		{ model = "RockSpire", x = 470, z = 320, height = 55, yaw = 40, clear = 12 },
		{ model = "RockSpire", x = 435, z = 75, height = 45, yaw = 170, clear = 10 },
		{ model = "RockSpire", x = 425, z = 300, height = 38, yaw = 280, clear = 9 },
		{ model = "WreckedTower", x = 430, z = 255, height = 22, yaw = 120, clear = 8 },
		{ model = "StormStone", x = 455, z = -40, height = 24, yaw = 10, glow = "storm", clear = 8 },
		{ model = "StormStone", x = 330, z = -35, height = 18, yaw = 200, glow = "storm", clear = 6 },
		{ model = "StormStone", x = 335, z = 320, height = 14, yaw = 140, glow = "storm", clear = 5 },
		{ model = "StormStone", x = 390, z = 315, height = 6, yaw = 60, glow = "storm" },
		{ model = "StormStone", x = 415, z = 155, height = 4, yaw = 300, glow = "storm" },
		-- the Rift's dark stalagmites (the owner 2026-11-10: "rift too empty")
		{ model = "Stalagmite", x = -50, z = 650, height = 14, yaw = 20, clear = 7 },
		{ model = "Stalagmite", x = 470, z = 640, height = 16, yaw = 130, clear = 7 },
		{ model = "Stalagmite", x = 230, z = 690, height = 12, yaw = 250, clear = 7 },
		{ model = "Stalagmite", x = 410, z = 520, height = 10, yaw = 300, clear = 6 },
		{ model = "Stalagmite", x = 40, z = 480, height = 11, yaw = 70, clear = 6 },
	},
	-- The Rift's violet crystal clusters (code-built, pointed: CRYSTAL_LOOK), small to oversized (the owner 2026-11-10:
	-- "add oversized crystals, these crystals are too small"); a big one's `clear` keeps monsters' spawns off its foot
	CRYSTALS = {
		{ x = 150, z = 650, height = 10, yaw = 10 },
		{ x = 240, z = 640, height = 11, yaw = 80 },
		{ x = 420, z = 560, height = 10, yaw = 150 },
		{ x = -20, z = 560, height = 8, yaw = 220 },
		{ x = 60, z = 520, height = 10, yaw = 300 },
		{ x = 330, z = 660, height = 11, yaw = 40 },
		{ x = 100, z = 680, height = 6, yaw = 60 },
		{ x = 280, z = 690, height = 18, yaw = 190 },
		{ x = 200, z = 520, height = 5, yaw = 15 },
		{ x = 440, z = 680, height = 8, yaw = 240 },
		{ x = 20, z = 680, height = 21, yaw = 120, clear = 6 },
		{ x = 360, z = 640, height = 6, yaw = 280 },
		{ x = -10, z = 500, height = 13, yaw = 45 },
		{ x = 480, z = 500, height = 14, yaw = 170 },
		{ x = 480, z = 590, height = 55, yaw = 200, clear = 14 },
		{ x = -55, z = 560, height = 48, yaw = 30, clear = 12 },
		{ x = 120, z = 700, height = 45, yaw = 330, clear = 12 },
		{ x = 330, z = 700, height = 40, yaw = 110, clear = 10 },
		{ x = 250, z = 470, height = 38, yaw = 260, clear = 10 },
		{ x = -45, z = 468, height = 34, yaw = 150, clear = 9 },
		{ x = 440, z = 700, height = 32, yaw = 70, clear = 8 },
	},
	-- glassy violet shells (Glass, `transparency`) round glowing cores (Neon, `core`); a tip `point` times a crystal's
	-- width tall; clusters from `lightFrom` studs light the ground round them
	CRYSTAL_LOOK = { color = { 150, 80, 255 }, tip = { 220, 180, 255 }, transparency = 0.25, core = 0.1, pointed = true, point = 1.1, lightFrom = 25, light = 1.5 },
	-- Stormpeak's storm crystals: charged by the storm, pointed like the Rift's in pale electric blue, small to oversized
	STORM_CRYSTALS = {
		{ x = 420, z = 30, height = 45, yaw = 15, clear = 12 },
		{ x = 320, z = 55, height = 38, yaw = 120, clear = 10 },
		{ x = 485, z = 155, height = 32, yaw = 250, clear = 8 },
		{ x = 460, z = 105, height = 30, yaw = 330, clear = 8 },
		{ x = 510, z = 5, height = 18, yaw = 70 },
		{ x = 370, z = 150, height = 15, yaw = 190 },
		{ x = 390, z = 285, height = 12, yaw = 40 },
		{ x = 350, z = 270, height = 8, yaw = 280 },
		{ x = 310, z = 95, height = 6, yaw = 160 },
		{ x = 395, z = 0, height = 5, yaw = 220 },
	},
	STORM_CRYSTAL_LOOK = { color = { 120, 190, 255 }, tip = { 225, 245, 255 }, transparency = 0.25, core = 0.05, pointed = true, point = 1.1, lightFrom = 25, light = 1.6 },
	-- Stormpeak's swamps (the owner 2026-11-10: "some ponds with bones or something a swamp"): mud in the terrain
	-- (WildValley.swampOps) round a dark pool `SWAMP_LOOK.pool` of the radius across, reeds round it; bones by and in
	-- it (BONES), a horned skull half sunk in the big one (LANDMARKS), dead trees on its edge (PROPS)
	SWAMPS = {
		{ x = 405, z = 115, radius = 18, yaw = 20, seed = 11, clear = 18 },
		{ x = 390, z = 185, radius = 15, yaw = 140, seed = 12, clear = 15 },
	},
	SWAMP_LOOK = { pool = 0.62, water = { 34, 46, 52 }, transparency = 0.12, reflectance = 0.35, rings = 6, reeds = 9, reedHeight = { 2, 4.5 }, reed = { 74, 82, 52 } },
	-- Puddles over Stormpeak, each with rain rings
	PUDDLES = {
		{ x = 400, z = 220, radius = 3.5 },
		{ x = 335, z = 290, radius = 4.5 },
		{ x = 310, z = 20, radius = 5.5 },
		{ x = 350, z = 65, radius = 2.5 },
		{ x = 355, z = 195, radius = 3.5 },
		{ x = 305, z = 165, radius = 4.5 },
		{ x = 430, z = 220, radius = 5.5 },
		{ x = 355, z = 125, radius = 2.5 },
		{ x = 480, z = 220, radius = 3.5 },
		{ x = 400, z = 75, radius = 4.5 },
		{ x = 355, z = 170, radius = 5.5 },
		{ x = 500, z = 170, radius = 2.5 },
		{ x = 300, z = 115, radius = 3.5 },
		{ x = 480, z = 125, radius = 4.5 },
	},
	PUDDLE_LOOK = { water = { 44, 56, 66 }, transparency = 0.2, reflectance = 0.3, rings = 0.5 },
	-- Pieces placed where scenery lists can't go (dressed like them, outside Util/WildValley.scenery's clearances): the
	-- ribcage the trail walks through (its feet off the trail), the Dungeon gate's crystal arch round the portal, the
	-- camp's tents, campfire and watchtower, and the Rift's floating rocks (at their own `y`, never settled)
	LANDMARKS = {
		{ model = "Ribcage", x = 95, z = 58, height = 22, yaw = 90 },
		{ model = "Tent", x = -26, z = -54, height = 5, yaw = 30 },
		{ model = "Tent", x = -27, z = -28, height = 5, yaw = 150 },
		{ model = "Campfire", x = -22, z = -41, height = 1.6, yaw = 0, glow = "fire" },
		{ model = "Watchtower", x = 38, z = -60, height = 16, yaw = 200 },
		{ model = "FloatingRock", x = 180, z = 640, y = 6, height = 7, yaw = 20, glow = "violet" },
		{ model = "FloatingRock", x = 380, z = 612, y = 10, height = 8, yaw = 140, glow = "violet" },
		{ model = "FloatingRock", x = 20, z = 540, y = 4, height = 6, yaw = 260, glow = "violet" },
		{ model = "FloatingRock", x = 300, z = 500, y = 8, height = 7, yaw = 80, glow = "violet" },
		-- small ones low, big ones high (the owner 2026-11-10: "different size of floating rocks")
		{ model = "FloatingRock", x = 460, z = 520, y = 4, height = 4, yaw = 30, glow = "violet" },
		{ model = "FloatingRock", x = 110, z = 560, y = 2, height = 3, yaw = 200, glow = "violet" },
		{ model = "FloatingRock", x = 250, z = 680, y = 0, height = 4, yaw = 310, glow = "violet" },
		{ model = "FloatingRock", x = 350, z = 690, y = 3, height = 5, yaw = 90, glow = "violet" },
		{ model = "FloatingRock", x = -60, z = 500, y = 6, height = 9, yaw = 150, glow = "violet" },
		{ model = "FloatingRock", x = 240, z = 520, y = 18, height = 10, yaw = 240, glow = "violet" },
		{ model = "FloatingRock", x = -40, z = 680, y = 14, height = 12, yaw = 60, glow = "violet" },
		{ model = "FloatingRock", x = 150, z = 480, y = 40, height = 14, yaw = 330, glow = "violet" },
		{ model = "FloatingRock", x = 450, z = 660, y = 22, height = 16, yaw = 110, glow = "violet" },
		{ model = "FloatingRock", x = 90, z = 690, y = 30, height = 20, yaw = 190, glow = "violet" },
		-- oversized, hung high over the crater (the owner 2026-11-10: "also oversized floating rocks")
		{ model = "FloatingRock", x = 200, z = 560, y = 45, height = 40, yaw = 20, glow = "violet" },
		{ model = "FloatingRock", x = 400, z = 690, y = 55, height = 50, yaw = 280, glow = "violet" },
		{ model = "FloatingRock", x = -30, z = 640, y = 40, height = 35, yaw = 130, glow = "violet" },
		{ model = "FloatingRock", x = 330, z = 480, y = 50, height = 30, yaw = 220, glow = "violet" },
		{ model = "FloatingRock", x = 60, z = 560, y = 60, height = 60, yaw = 70, glow = "violet" },
		-- a horned skull half sunk in Stormpeak's big swamp (its foot under the ground, so never settled)
		{ model = "HornedSkull", x = 410, z = 111, y = 26.5, height = 10, yaw = 200, glow = "storm" },
		-- a ruined crystal arch standing in the crater
		{ model = "CrystalArch", x = 445, z = 625, height = 18, yaw = 60, glow = "violet" },
	},
	GLOW = {
		teal = { 80, 235, 215 },
		blue = { 110, 190, 255 },
		violet = { 170, 90, 255 },
		ice = { 150, 215, 255 },
		storm = { 120, 200, 255 },
		fire = { 255, 120, 40 },
	},
	-- Invisible upright cylinders that stop players at a big piece (shares of its height; `spread` along its own X)
	COLLIDERS = {
		FortRuin = { radius = 0.25, height = 1 },
		FortWall = { radius = 0.15, height = 1, spread = { -1.1, -0.55, 0, 0.55, 1.1 } },
		GiantSword = { radius = 0.06, height = 0.6 },
		Tent = { radius = 0.45, height = 0.6 },
		Watchtower = { radius = 0.05, height = 0.6, spread = { -0.13, 0.13 } },
		WreckedTower = { radius = 0.18, height = 0.8 },
		RockSpire = { radius = 0.15, height = 0.9 },
		StormStone = { radius = 0.14, height = 1 },
		HornedSkull = { radius = 0.35, height = 0.5 },
		Ribcage = { radius = 0.05, height = 0.4, spread = { -0.6, 0.6 } },
		CrystalArch = { radius = 0.06, height = 0.6, spread = { -0.37, 0.37 } },
		DragonSkeleton = { radius = 0.3, height = 0.5, spread = { -1, 0, 1 } },
		Stalagmite = { radius = 0.18, height = 0.8 },
	},
	-- Town props placed as they are: snowy pines round Frostwood, rocks, dead trees on Stormpeak, obsidian in the Rift
	PROPS = {
		{ model = "SnowPine", x = -100, z = -50, height = 22, yaw = 20 },
		{ model = "SnowPine", x = -60, z = -62, height = 24, yaw = 140 },
		{ model = "SnowPine", x = 62, z = -60, height = 20, yaw = 250 },
		{ model = "SnowPine", x = 120, z = -56, height = 23, yaw = 10 },
		{ model = "SnowPine", x = 180, z = -40, height = 25, yaw = 75 },
		{ model = "SnowPine", x = 190, z = 20, height = 21, yaw = 200 },
		{ model = "SnowPine", x = -105, z = 20, height = 22, yaw = 300 },
		{ model = "SnowPine", x = -100, z = 128, height = 26, yaw = 160 },
		{ model = "SnowPine", x = 20, z = 132, height = 22, yaw = 30 },
		{ model = "SnowPine", x = 160, z = 130, height = 24, yaw = 120 },
		{ model = "SnowPine", x = 192, z = 128, height = 22, yaw = 60 },
		{ model = "RockB", x = 100, z = 10, height = 3, yaw = 60 },
		{ model = "RockC", x = -20, z = 100, height = 3.5, yaw = 200 },
		{ model = "CharredTree", x = 360, z = -20, height = 14, yaw = 30 },
		{ model = "CharredTree", x = 500, z = 100, height = 15, yaw = 140 },
		{ model = "CharredTree", x = 500, z = 290, height = 13, yaw = 260 },
		{ model = "RockC", x = 380, z = 60, height = 4, yaw = 90 },
		{ model = "CharredTree", x = 455, z = 225, height = 14, yaw = 80 },
		-- lightning-struck trees, small to giant, and dead ones on the swamps' edges
		{ model = "CharredTree", x = 365, z = 90, height = 24, yaw = 200 },
		{ model = "CharredTree", x = 435, z = 190, height = 20, yaw = 50 },
		{ model = "CharredTree", x = 450, z = 0, height = 9, yaw = 120 },
		{ model = "CharredTree", x = 420, z = 128, height = 12, yaw = 260 },
		{ model = "CharredTree", x = 398, z = 98, height = 10, yaw = 20 },
		{ model = "CharredTree", x = 376, z = 196, height = 11, yaw = 150 },
		{ model = "RockC", x = 300, z = -25, height = 4, yaw = 30 },
		{ model = "RockB", x = 395, z = -30, height = 5, yaw = 200 },
		{ model = "RockC", x = 505, z = 35, height = 4, yaw = 120 },
		{ model = "RockB", x = 470, z = 195, height = 5, yaw = 300 },
		{ model = "RockA", x = 330, z = 120, height = 4, yaw = 10 },
		{ model = "ObsidianShards", x = 400, z = 650, height = 6, yaw = 20 },
		{ model = "ObsidianShards", x = 0, z = 670, height = 5, yaw = 200 },
		{ model = "ObsidianShards", x = 150, z = 500, height = 7, yaw = 80 },
		{ model = "ObsidianShards", x = -30, z = 570, height = 6, yaw = 290 },
		{ model = "ObsidianShards", x = 260, z = 640, height = 8, yaw = 150 },
		{ model = "ObsidianShards", x = 480, z = 690, height = 5, yaw = 40 },
	},
	SETTLE = { band = 0.04, grid = 15, sink = 0.4, cap = 0.2, perYield = 10 },
	FEET = {},
	-- Past the walls: tall snowy pines over Frostwood's hills, the dead giant's skull and ribs on its body, crags over
	-- Stormpeak, stalagmites on the Rift's rim
	-- Each on the drawn rim (the owner 2026-11-10: "fix floating trees"; past the rims there's no terrain, so a piece
	-- stood there showed its crown over the rim with nothing under it)
	BACKDROP = {
		{ model = "SnowPine", x = -108, z = -86, height = 40, yaw = 20 },
		{ model = "SnowPine", x = 2, z = -86, height = 44, yaw = 140 },
		{ model = "SnowPine", x = 84, z = -88, height = 40, yaw = 250 },
		{ model = "SnowPine", x = 224, z = -80, height = 42, yaw = 80 },
		{ model = "SnowPine", x = -130, z = -16, height = 40, yaw = 300 },
		{ model = "SnowPine", x = -132, z = 118, height = 44, yaw = 30 },
		{ model = "TitanSkull", x = -70, z = 300, height = 28, yaw = 270 },
		{ model = "Ribcage", x = 90, z = 300, height = 30, yaw = 0 },
		{ model = "RockSpire", x = 536, z = 58, height = 34, yaw = 10 },
		{ model = "RockSpire", x = 536, z = 252, height = 38, yaw = 200 },
		{ model = "Stalagmite", x = -10, z = 716, height = 30, yaw = 0 },
		{ model = "Stalagmite", x = 174, z = 716, height = 36, yaw = 90 },
		{ model = "Stalagmite", x = 358, z = 714, height = 32, yaw = 180 },
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
