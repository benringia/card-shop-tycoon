--!strict
-- The scenery round the town and in the three portal areas (Portal Worlds spec): terrain shapes Util/TownTerrain turns
-- into fills (SceneryService builds them at server start, main game only). Plain data, read by Lune tests.
-- Shapes: Block (x, y, z centre; size; yaw in degrees, TownLayout's convention), Ball (centre, radius), Wedge (like
-- Block). Materials are Enum.Material names. Roblox draws terrain 2 studs above a fill's top (TownTerrain.SURFACE_LIFT),
-- so ground at y 0 is filled to y -2; inside the island (x -130..130, z -110..110) nothing is filled higher.
return {
	-- The ground everywhere round the town, drawn at y 0 (applied first; everything else overrides it)
	GROUND = {
		{ shape = "Block", x = 0, y = -5, z = 0, size = { x = 700, y = 6, z = 620 }, material = "Grass" }, -- wide enough that its edge hides in the haze
	},
	-- Walkable floors in the areas (after the island, before the trails)
	FLOORS = {
		{ shape = "Block", x = 192, y = -5, z = 130, size = { x = 96, y = 6, z = 96 }, material = "Snow" }, -- Frostpeak's clearing
		{ shape = "Block", x = -182, y = -5, z = 0, size = { x = 104, y = 6, z = 64 }, material = "Sand" }, -- Ember Canyon's floor
	},
	-- Hills, cliffs, the falls' pool, the peak and the canyon walls (applied last)
	TERRAIN = {
		-- Soft hills behind the shop rows
		{ shape = "Ball", x = -150, y = -18, z = 165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = -75, y = -18, z = 165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = 0, y = -18, z = 165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = 75, y = -18, z = 165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = -150, y = -18, z = -165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = -75, y = -18, z = -165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = 0, y = -18, z = -165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = 75, y = -18, z = -165, radius = 40, material = "Grass" },
		{ shape = "Ball", x = -200, y = -18, z = 95, radius = 40, material = "Grass" },
		{ shape = "Ball", x = -200, y = -18, z = -95, radius = 40, material = "Grass" },
		{ shape = "Ball", x = 208, y = -20, z = 0, radius = 36, material = "Grass" }, -- between the two east areas
		-- Ember Canyon: striped walls (Sandstone and Limestone layers, stepping back as they rise) and an end wall
		{ shape = "Block", x = -185, y = 4, z = 50, size = { x = 110, y = 24, z = 40 }, material = "Sandstone" },
		{ shape = "Block", x = -185, y = 20, z = 52, size = { x = 110, y = 8, z = 36 }, material = "Limestone" },
		{ shape = "Block", x = -185, y = 28, z = 54, size = { x = 110, y = 8, z = 32 }, material = "Sandstone" },
		{ shape = "Block", x = -185, y = 4, z = -50, size = { x = 110, y = 24, z = 40 }, material = "Sandstone" },
		{ shape = "Block", x = -185, y = 20, z = -52, size = { x = 110, y = 8, z = 36 }, material = "Limestone" },
		{ shape = "Block", x = -185, y = 28, z = -54, size = { x = 110, y = 8, z = 32 }, material = "Sandstone" },
		{ shape = "Block", x = -246, y = 12, z = 0, size = { x = 24, y = 40, z = 140 }, material = "Sandstone" },
		-- Forest Falls: a mossy cliff behind the pool, the pool, rocks round it, hills beyond
		{ shape = "Block", x = 190, y = 12, z = -186, size = { x = 100, y = 40, z = 40 }, material = "Rock" },
		{ shape = "Ball", x = 170, y = 30, z = -190, radius = 14, material = "Grass" },
		{ shape = "Ball", x = 210, y = 30, z = -190, radius = 14, material = "Grass" },
		{ shape = "Block", x = 185, y = -4, z = -152, size = { x = 24, y = 8, z = 16 }, material = "Air" },
		{ shape = "Block", x = 185, y = -5, z = -152, size = { x = 24, y = 6, z = 16 }, material = "Water" }, -- drawn level with the ground
		{ shape = "Ball", x = 171, y = -1, z = -152, radius = 2.5, material = "Rock" },
		{ shape = "Ball", x = 199, y = -1, z = -152, radius = 2.5, material = "Rock" },
		{ shape = "Ball", x = 268, y = -14, z = -110, radius = 34, material = "Grass" },
		{ shape = "Ball", x = 262, y = -14, z = -50, radius = 30, material = "Grass" },
		-- Frostpeak: a cliff with a frozen waterfall and its frozen pool, snow on top, the peak beyond the walls
		{ shape = "Block", x = 196, y = 12, z = 190, size = { x = 90, y = 40, z = 40 }, material = "Rock" },
		{ shape = "Block", x = 196, y = 12, z = 168, size = { x = 14, y = 40, z = 4 }, material = "Glacier" },
		{ shape = "Block", x = 196, y = -5, z = 160, size = { x = 20, y = 6, z = 10 }, material = "Glacier" },
		{ shape = "Ball", x = 175, y = 30, z = 192, radius = 14, material = "Snow" },
		{ shape = "Ball", x = 220, y = 30, z = 192, radius = 14, material = "Snow" },
		{ shape = "Ball", x = 230, y = -10, z = 260, radius = 60, material = "Rock" },
		{ shape = "Ball", x = 228, y = 40, z = 258, radius = 40, material = "Rock" },
		{ shape = "Ball", x = 226, y = 70, z = 256, radius = 28, material = "Snow" },
		{ shape = "Ball", x = 225, y = 92, z = 255, radius = 16, material = "Snow" },
		{ shape = "Ball", x = 268, y = -16, z = 120, radius = 32, material = "Snow" },
		-- Rounding the cliffs and canyon rims so they read as rock, not boxes
		{ shape = "Ball", x = 150, y = 18, z = -176, radius = 11, material = "Rock" },
		{ shape = "Ball", x = 172, y = 24, z = -174, radius = 10, material = "Rock" },
		{ shape = "Ball", x = 205, y = 22, z = -175, radius = 11, material = "Rock" },
		{ shape = "Ball", x = 232, y = 16, z = -176, radius = 12, material = "Rock" },
		{ shape = "Ball", x = 190, y = 34, z = -192, radius = 13, material = "Grass" },
		{ shape = "Ball", x = 160, y = 20, z = 182, radius = 11, material = "Rock" },
		{ shape = "Ball", x = 232, y = 20, z = 182, radius = 11, material = "Rock" },
		{ shape = "Ball", x = -145, y = 26, z = 44, radius = 8, material = "Sandstone" },
		{ shape = "Ball", x = -175, y = 30, z = 46, radius = 9, material = "Sandstone" },
		{ shape = "Ball", x = -210, y = 28, z = 44, radius = 8, material = "Sandstone" },
		{ shape = "Ball", x = -160, y = 32, z = 64, radius = 9, material = "Sandstone" },
		{ shape = "Ball", x = -200, y = 33, z = 62, radius = 10, material = "Sandstone" },
		{ shape = "Ball", x = -145, y = 26, z = -44, radius = 8, material = "Sandstone" },
		{ shape = "Ball", x = -178, y = 30, z = -46, radius = 9, material = "Sandstone" },
		{ shape = "Ball", x = -212, y = 28, z = -44, radius = 8, material = "Sandstone" },
		{ shape = "Ball", x = -158, y = 32, z = -64, radius = 9, material = "Sandstone" },
		{ shape = "Ball", x = -198, y = 33, z = -62, radius = 10, material = "Sandstone" },
		{ shape = "Ball", x = -240, y = 30, z = 0, radius = 12, material = "Sandstone" },
	},
	-- Giant trees: copies of the town's tree models (ReplicatedStorage.PropModels) scaled up, so they batch together.
	-- height in studs; yaw in degrees. Outside the island, clear of the trails (Lune-tested).
	GIANT_TREES = {
		{ x = 140, z = -100, model = "TreeA", height = 52, yaw = 20 },
		{ x = 138, z = -135, model = "TreeB", height = 58, yaw = 110 },
		{ x = 143, z = -160, model = "TreeA", height = 48, yaw = 200 },
		{ x = 240, z = -100, model = "TreeB", height = 55, yaw = 300 },
		{ x = 245, z = -135, model = "TreeA", height = 60, yaw = 40 },
		{ x = 238, z = -160, model = "TreeB", height = 50, yaw = 160 },
		{ x = 215, z = -130, model = "TreeA", height = 46, yaw = 80 },
		{ x = 160, z = -150, model = "TreeB", height = 44, yaw = 250 },
		{ x = 195, z = -55, model = "TreeA", height = 50, yaw = 130 },
		{ x = 220, z = -65, model = "TreeB", height = 54, yaw = 10 },
		{ x = -145, z = -125, model = "TreeA", height = 50, yaw = 70 },
		{ x = -145, z = 125, model = "TreeB", height = 52, yaw = 190 },
	},
	-- Frosted pines round Frostpeak (the town's pine models scaled; their leaves plain SNOW_TINT snow, since a
	-- SurfaceAppearance tint can only darken its texture)
	SNOW_PINES = {
		{ x = 142, z = 110, model = "Pine", height = 30, yaw = 0 },
		{ x = 140, z = 140, model = "PineA", height = 34, yaw = 90 },
		{ x = 144, z = 165, model = "PineB", height = 28, yaw = 180 },
		{ x = 242, z = 100, model = "PineA", height = 32, yaw = 45 },
		{ x = 246, z = 130, model = "Pine", height = 36, yaw = 135 },
		{ x = 240, z = 160, model = "PineB", height = 30, yaw = 225 },
		{ x = 200, z = 78, model = "Pine", height = 28, yaw = 315 },
		{ x = 225, z = 80, model = "PineA", height = 30, yaw = 20 },
		{ x = 220, z = 150, model = "PineB", height = 26, yaw = 100 },
		{ x = 165, z = 155, model = "Pine", height = 27, yaw = 200 },
	},
	SNOW_TINT = { 225, 236, 248 },
	-- Ember Canyon: cacti along the walls, the Arena portal's stone platform and the torch pillars beside it
	CACTI = {
		{ x = -150, z = 24, height = 7 },
		{ x = -170, z = -25, height = 6 },
		{ x = -190, z = 26, height = 8 },
		{ x = -210, z = -24, height = 6 },
		{ x = -222, z = 22, height = 7 },
		{ x = -160, z = -24, height = 5 },
	},
	PLATFORM = { x = -205, z = 0, radius = 7, height = 0.8, color = { 150, 120, 105 } },
	TORCHES = {
		{ x = -203, z = 11, height = 7 }, -- just outside the portal frame's sides, so they show
		{ x = -203, z = -11, height = 7 },
	},
	TORCH_FIRE = { COLOR = { 255, 150, 60 }, RATE = 18 },
	-- Forest Falls: scrolling sheets of water down the cliff face into the pool, mist and splash at the bottom
	FALLS = {
		-- the cliff's face draws at z -163.5 (terrain bulges ~2.5 studs past its fill on every side), its top at y 33
		TOP = { x = 185, y = 33, z = -162 },
		BOTTOM = { x = 185, y = 0.6, z = -156 },
		TEXTURE = "rbxassetid://139671283074387", -- assets/ui/fx/waterfall-streaks.png (Figma image generator)
		TEXTURE_LENGTH = 10,
		COLOR = { 205, 242, 255 },
		BEAMS = {
			{ width0 = 12, width1 = 15, speed = 1.4, transparency = 0.05 },
			{ width0 = 9, width1 = 12, speed = 2.3, transparency = 0.3 },
		},
		EMITTERS = {
			{ kind = "mist", x = 185, y = 1, z = -155, rate = 16 },
			{ kind = "splash", x = 185, y = 1, z = -155.5, rate = 28 },
		},
	},
	-- Frostpeak's frozen falls: ice crystals round its foot (the falls themselves are Glacier terrain)
	CRYSTALS = {
		{ x = 188, z = 163, height = 4, yaw = 20 },
		{ x = 204, z = 162, height = 5, yaw = 70 },
		{ x = 210, z = 158, height = 3, yaw = 140 },
		{ x = 182, z = 160, height = 3, yaw = 250 },
	},
	CRYSTAL_COLOR = { 180, 225, 255 },
	-- Area effects (at most 4 per area, Lune-tested): drifting snow and an aurora over Frostpeak, rising embers in the canyon
	EMITTERS = {
		{ area = "Frostpeak", kind = "snow", x = 192, y = 34, z = 128, size = { x = 90, z = 90 }, rate = 22 },
		{ area = "Frostpeak", kind = "snow", x = 200, y = 40, z = 200, size = { x = 90, z = 60 }, rate = 10 },
		{ area = "Frostpeak", kind = "aurora", x = 150, y = 95, z = 215, toX = 255, toY = 105, toZ = 185, width = 34 },
		{ area = "EmberCanyon", kind = "embers", x = -178, y = 1, z = 0, size = { x = 90, z = 50 }, rate = 12 },
		{ area = "EmberCanyon", kind = "embers", x = -230, y = 4, z = 0, size = { x = 16, z = 40 }, rate = 6 },
	},
	-- Ambient sounds, positioned and quiet (free Creator Store sounds; the user judges them by ear)
	SOUNDS = {
		{ name = "Falls", id = "rbxassetid://9116496316", x = 185, y = 6, z = -158, volume = 0.5, range = 90 }, -- Pro Sound Effects: Medium Size Waterfall 1
		{ name = "Wind", id = "rbxassetid://5799870105", x = 195, y = 10, z = 130, volume = 0.35, range = 100 }, -- Ambient wind (Mukar)
		{ name = "Embers", id = "rbxassetid://9112780462", x = -200, y = 4, z = 0, volume = 0.3, range = 70 }, -- Pro Sound Effects: Fireplace Constant Burning Flame 4
		{ name = "Birds", id = "rbxassetid://9112831666", x = 0, y = 18, z = 0, volume = 0.25, range = 170 }, -- Pro Sound Effects: Morning Birds 2 (loop)
	},
	SMALL_DECOR_SIZE = 4, -- studs: hand-placed decor parts smaller than this cast no shadow
	-- Terrain colours (Grass takes Town.GRASS_COLOR); Sandstone and Limestone appear only in the canyon
	MATERIAL_COLORS = {
		Sandstone = { 196, 96, 62 },
		Limestone = { 226, 146, 96 },
		Snow = { 240, 246, 255 },
		Glacier = { 170, 215, 245 },
		Sand = { 222, 170, 120 },
		Ground = { 120, 96, 70 },
	},
	WATER = { COLOR = { 60, 190, 200 }, TRANSPARENCY = 0.6, REFLECTANCE = 0.3, WAVE_SIZE = 0.05, WAVE_SPEED = 6 },
	MAX_CELLS = 180000, -- estimated 4-stud cells (memory: the spike's oversized fill cost +80 MB)
}
