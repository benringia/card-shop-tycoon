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
		-- Frostpeak's clearing: a snowy rise drawn at y 10 (FROST_HEIGHT), the grass below it; the trail climbs onto it
		{ shape = "Block", x = 192.5, y = 0, z = 139, size = { x = 115, y = 16, z = 82 }, material = "Snow" },
		{ shape = "Block", x = -182, y = -5, z = 0, size = { x = 104, y = 6, z = 64 }, material = "CrackedLava" }, -- Ember Canyon's floor: dark cracked rock
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
		-- Ember Canyon, a caldera (caldera spec 2026-10-31): dark basalt walls stepping back as they rise, and an end wall
		{ shape = "Block", x = -185, y = 4, z = 50, size = { x = 110, y = 24, z = 40 }, material = "Basalt" },
		{ shape = "Block", x = -185, y = 20, z = 52, size = { x = 110, y = 8, z = 36 }, material = "Basalt" },
		{ shape = "Block", x = -185, y = 28, z = 54, size = { x = 110, y = 8, z = 32 }, material = "Basalt" },
		{ shape = "Block", x = -185, y = 4, z = -54, size = { x = 110, y = 24, z = 40 }, material = "Basalt" }, -- 4 back: the lava runs at its foot
		{ shape = "Block", x = -185, y = 20, z = -56, size = { x = 110, y = 8, z = 36 }, material = "Basalt" },
		{ shape = "Block", x = -185, y = 28, z = -58, size = { x = 110, y = 8, z = 32 }, material = "Basalt" },
		{ shape = "Block", x = -184, y = -5, z = -29, size = { x = 100, y = 6, z = 7 }, material = "CrackedLava" }, -- the lava river's banks
		{ shape = "Ball", x = -236, y = -6, z = 0, radius = 11, material = "CrackedLava" }, -- round the lava pool behind the portal
		{ shape = "Block", x = -246, y = 12, z = 0, size = { x = 24, y = 40, z = 140 }, material = "Basalt" },
		-- Forest Falls: a mossy cliff behind the pool, the pool, rocks round it, hills beyond
		{ shape = "Block", x = 190, y = 12, z = -186, size = { x = 100, y = 40, z = 40 }, material = "Rock" },
		{ shape = "Ball", x = 170, y = 30, z = -190, radius = 14, material = "Grass" },
		{ shape = "Ball", x = 210, y = 30, z = -190, radius = 14, material = "Grass" },
		{ shape = "Block", x = 185, y = -4, z = -152, size = { x = 24, y = 8, z = 16 }, material = "Air" },
		{ shape = "Block", x = 185, y = -5, z = -152, size = { x = 24, y = 6, z = 16 }, material = "Water" }, -- drawn level with the ground
		{ shape = "Block", x = 185, y = -10, z = -152, size = { x = 28, y = 4, z = 20 }, material = "Rock" }, -- the pool's floor: nobody sinks out of the world
		{ shape = "Ball", x = 170, y = -1, z = -151, radius = 4.5, material = "Rock" },
		{ shape = "Ball", x = 200, y = -1, z = -150, radius = 5, material = "Rock" },
		{ shape = "Ball", x = 172, y = 0, z = -160, radius = 5.5, material = "Rock" },
		{ shape = "Ball", x = 198, y = 0, z = -161, radius = 5, material = "Rock" },
		{ shape = "Ball", x = 178, y = -2, z = -143, radius = 3, material = "Rock" },
		{ shape = "Ball", x = 268, y = -14, z = -110, radius = 34, material = "Grass" },
		{ shape = "Ball", x = 262, y = -14, z = -50, radius = 30, material = "Grass" },
		-- Frostpeak: a cliff with a frozen waterfall and its frozen pool, snow on top, the peak beyond the walls
		{ shape = "Block", x = 196, y = 12, z = 190, size = { x = 90, y = 40, z = 40 }, material = "Slate" },
		{ shape = "Ball", x = 175, y = 30, z = 192, radius = 14, material = "Snow" },
		{ shape = "Ball", x = 220, y = 30, z = 192, radius = 14, material = "Snow" },
		{ shape = "Ball", x = 230, y = -10, z = 260, radius = 60, material = "Slate" },
		{ shape = "Ball", x = 228, y = 40, z = 258, radius = 40, material = "Slate" },
		{ shape = "Ball", x = 226, y = 70, z = 256, radius = 28, material = "Snow" },
		{ shape = "Ball", x = 225, y = 92, z = 255, radius = 16, material = "Snow" },
		{ shape = "Ball", x = 268, y = -16, z = 120, radius = 32, material = "Snow" },
		-- Soft snow banks along the rise's front and west edges, so it doesn't end in a hard slab
		{ shape = "Ball", x = 141, y = 4, z = 99, radius = 7, material = "Snow" },
		{ shape = "Ball", x = 190, y = 4, z = 97, radius = 7, material = "Snow" },
		{ shape = "Ball", x = 212, y = 4, z = 97, radius = 8, material = "Snow" },
		{ shape = "Ball", x = 234, y = 4, z = 98, radius = 7, material = "Snow" },
		{ shape = "Ball", x = 134, y = 4, z = 122, radius = 7, material = "Snow" },
		{ shape = "Ball", x = 134, y = 4, z = 148, radius = 8, material = "Snow" },
		{ shape = "Ball", x = 136, y = 4, z = 172, radius = 7, material = "Snow" },
		-- Rounding the cliffs and canyon rims so they read as rock, not boxes
		{ shape = "Ball", x = 150, y = 18, z = -176, radius = 11, material = "Rock" },
		{ shape = "Ball", x = 172, y = 24, z = -174, radius = 10, material = "Rock" },
		{ shape = "Ball", x = 205, y = 22, z = -175, radius = 11, material = "Rock" },
		{ shape = "Ball", x = 232, y = 16, z = -176, radius = 12, material = "Rock" },
		{ shape = "Ball", x = 190, y = 34, z = -192, radius = 13, material = "Grass" },
		{ shape = "Ball", x = 160, y = 20, z = 182, radius = 11, material = "Slate" },
		{ shape = "Ball", x = 232, y = 20, z = 182, radius = 11, material = "Slate" },
		-- The caldera's rims: turned basalt blocks, so they read jagged, not rounded
		{ shape = "Block", x = -145, y = 27, z = 44, yaw = 25, size = { x = 15, y = 12, z = 11 }, material = "Basalt" },
		{ shape = "Block", x = -175, y = 31, z = 46, yaw = -35, size = { x = 16, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -210, y = 29, z = 44, yaw = 50, size = { x = 14, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -160, y = 33, z = 64, yaw = -15, size = { x = 17, y = 14, z = 13 }, material = "Basalt" },
		{ shape = "Block", x = -200, y = 34, z = 62, yaw = 40, size = { x = 18, y = 15, z = 14 }, material = "Basalt" },
		{ shape = "Block", x = -145, y = 27, z = -48, yaw = -30, size = { x = 15, y = 12, z = 11 }, material = "Basalt" },
		{ shape = "Block", x = -178, y = 31, z = -50, yaw = 35, size = { x = 16, y = 14, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -212, y = 29, z = -48, yaw = -50, size = { x = 14, y = 12, z = 12 }, material = "Basalt" },
		{ shape = "Block", x = -158, y = 33, z = -68, yaw = 20, size = { x = 17, y = 14, z = 13 }, material = "Basalt" },
		{ shape = "Block", x = -198, y = 34, z = -66, yaw = -40, size = { x = 18, y = 15, z = 14 }, material = "Basalt" },
		{ shape = "Block", x = -240, y = 31, z = 0, yaw = 30, size = { x = 20, y = 16, z = 18 }, material = "Basalt" },
		{ shape = "Block", x = -240, y = 33, z = -30, yaw = -25, size = { x = 16, y = 14, z = 14 }, material = "Basalt" },
		{ shape = "Block", x = -240, y = 33, z = 30, yaw = 55, size = { x = 16, y = 14, z = 14 }, material = "Basalt" },
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
	FROST_HEIGHT = 10, -- studs: Frostpeak's rise (the Frontier trail's end and portal stand at this height)
	-- Frosted pines up on Frostpeak's rise (the town's pine models scaled; their leaves plain SNOW_TINT snow, since a
	-- SurfaceAppearance tint can only darken its texture). y: the ground they stand on.
	SNOW_PINES = {
		{ x = 142, z = 110, y = 10, model = "Pine", height = 30, yaw = 0 },
		{ x = 140, z = 140, y = 10, model = "PineA", height = 34, yaw = 90 },
		{ x = 144, z = 165, y = 10, model = "PineB", height = 28, yaw = 180 },
		{ x = 242, z = 104, y = 10, model = "PineA", height = 32, yaw = 45 },
		{ x = 246, z = 130, y = 10, model = "Pine", height = 36, yaw = 135 },
		{ x = 240, z = 160, y = 10, model = "PineB", height = 30, yaw = 225 },
		{ x = 220, z = 150, y = 10, model = "PineB", height = 26, yaw = 100 },
		{ x = 165, z = 155, y = 10, model = "Pine", height = 27, yaw = 200 },
		{ x = 152, z = 108, y = 10, model = "PineA", height = 25, yaw = 280 },
		{ x = 160, z = 120, y = 10, model = "Pine", height = 22, yaw = 30 },
		{ x = 200, z = 108, y = 10, model = "PineB", height = 24, yaw = 160 },
	},
	SNOW_TINT = { 225, 236, 248 },
	-- On the grass below the rise: pines with just a little snow, easing from the green into the snow
	DUSTED_PINES = {
		{ x = 200, z = 78, model = "Pine", height = 28, yaw = 315 },
		{ x = 225, z = 80, model = "PineA", height = 30, yaw = 20 },
		{ x = 135, z = 72, model = "PineB", height = 26, yaw = 60 },
		{ x = 170, z = 70, model = "Pine", height = 24, yaw = 150 },
		{ x = 186, z = 66, model = "PineA", height = 27, yaw = 240 },
		{ x = 246, z = 82, model = "PineB", height = 29, yaw = 330 },
	},
	DUSTED_TINT = { 170, 205, 178 }, -- green leaves frosted pale
	-- Ember Canyon (the caldera): the torch pillars beside the Arena portal, dark basalt (its obsidian arch stands on the
	-- ground: the round stone platform went with the portals remodel)
	TORCHES = {
		{ x = -203, z = 15, height = 7 }, -- just outside the obsidian arch's sides (Town.PORTAL_SCENERY_CLEAR), so they show
		{ x = -203, z = -15, height = 7 },
	},
	TORCH_FIRE = { COLOR = { 255, 150, 60 }, RATE = 18 },
	TORCH_STONE = { 52, 46, 56 }, -- dark basalt, like the caldera's walls
	-- The caldera's Blender props (assets/props; SceneryService places them, scaled to `height`, on the drawn ground): charred
	-- dead trees where the cacti stood and along the walls, black-purple obsidian shard clusters like the portal's, and the
	-- quiet volcano far behind the end wall (its foot sunk to y -4; its Lava glows, smoke rises from its Fx_Smoke)
	CHARRED_TREES = {
		{ model = "CharredTree", x = -150, z = 20, height = 11, yaw = 20 },
		{ model = "CharredTree", x = -168, z = -19, height = 10, yaw = 140 },
		{ model = "CharredTree", x = -190, z = 22, height = 12, yaw = 250 },
		{ model = "CharredTree", x = -222, z = 18, height = 10, yaw = 75 },
		{ model = "CharredTree", x = -140, z = -20, height = 9, yaw = 300 },
		{ model = "CharredTree", x = -176, z = 24, height = 9, yaw = 190 },
		{ model = "CharredTree", x = -212, z = -20, height = 11, yaw = 30 },
		{ model = "CharredTree", x = -228, z = -16, height = 9, yaw = 210 },
	},
	SHARDS = {
		{ model = "ObsidianShards", x = -160, z = 12, height = 4, yaw = 0 },
		{ model = "ObsidianShards", x = -185, z = -14, height = 5, yaw = 120 },
		{ model = "ObsidianShards", x = -198, z = 14, height = 3.5, yaw = 240 },
		{ model = "ObsidianShards", x = -215, z = -10, height = 4.5, yaw = 60 },
		{ model = "ObsidianShards", x = -135, z = 14, height = 3, yaw = 300 },
		{ model = "ObsidianShards", x = -230, z = 12, height = 4, yaw = 170 },
	},
	VOLCANO = { model = "Volcano", x = -335, z = 10, height = 120, yaw = 0, y = -4 },
	-- The caldera's glowing cracks (Util/LavaCracks lays them out, SceneryService snaps them onto the terrain as glowing
	-- strips): down the canyon's three inner cliff faces (each a line in plan view, from/to, the cracks between heights
	-- low and high) and across its floor (a box), clear of the trail and the portal. WIDTH: a strip's width range
	-- (studs); MAX_SEGMENTS: all strips together.
	CRACKS = {
		SEED = 31,
		WIDTH = { 0.35, 0.7 },
		COLOR = { 255, 110, 30 },
		MAX_SEGMENTS = 160,
		WALLS = {
			{ name = "North", from = { x = -136, z = 30 }, to = { x = -232, z = 30 }, low = 1, high = 22, count = 6 },
			{ name = "South", from = { x = -136, z = -32 }, to = { x = -232, z = -32 }, low = 1, high = 22, count = 6 },
			{ name = "End", from = { x = -234, z = -22 }, to = { x = -234, z = 22 }, low = 1, high = 22, count = 4 },
		},
		FLOOR = { centre = { x = -182, z = 0 }, size = { x = 96, z = 44 }, count = 10 },
	},
	-- Lava: a glowing river at the south wall's foot (just past the walkable floor) and a pool behind the portal
	LAVA = {
		RIVER = { from = { x = -136, z = -28.5 }, to = { x = -232, z = -28.5 }, width = 5.5 },
		POOL = { x = -236, z = 0, radius = 8 },
		COLOR = { 255, 120, 30 }, -- hotter for the caldera
		HOT = { 255, 210, 90 },
		GLOW = { BRIGHTNESS = 2, RANGE = 26 },
	},
	-- Forest Falls: scrolling sheets of water down the cliff face into the pool, mist and splash at the bottom
	FALLS = {
		-- the cliff's face draws at z -163.5 (terrain bulges ~2.5 studs past its fill on every side), its top at y 33
		TOP = { x = 185, y = 33, z = -162 },
		BOTTOM = { x = 185, y = 0.6, z = -156 },
		TEXTURE = "rbxassetid://139671283074387", -- assets/ui/fx/waterfall-streaks.png (Figma image generator)
		COLOR = { 205, 242, 255 },
		-- Layered streams: a wide body, a bright faster core and two thin side runs; each bulges out over the lip
		-- (curve, studs) and scrolls at its own speed, so the water reads as depth, not one flat sheet. offset: studs
		-- along x from the falls' middle.
		STREAMS = {
			{ offset = 0, width0 = 13, width1 = 16, speed = 1.4, length = 10, transparency = 0.05, curve = 3 },
			{ offset = 0.5, width0 = 7, width1 = 10, speed = 2.5, length = 6, transparency = 0.25, curve = 4 },
			{ offset = -7, width0 = 2.5, width1 = 4, speed = 1.9, length = 8, transparency = 0.15, curve = 2 },
			{ offset = 7, width0 = 3, width1 = 4.5, speed = 1.7, length = 9, transparency = 0.15, curve = 2.5 },
		},
		EMITTERS = {
			{ kind = "mist", x = 185, y = 1, z = -155, rate = 16 },
			{ kind = "splash", x = 185, y = 0.8, z = -155.5, rate = 55 },
			{ kind = "foam", x = 185, y = 0.3, z = -153, rate = 20 },
			{ kind = "lip", x = 185, y = 32.5, z = -161.5, rate = 10 },
		},
	},
	-- Frostpeak's frozen falls: ice crystals round its foot (the falls themselves are Glacier terrain)
	CRYSTALS = {
		{ x = 188, z = 163, y = 10, height = 4, yaw = 20 },
		{ x = 204, z = 162, y = 10, height = 5, yaw = 70 },
		{ x = 210, z = 158, y = 10, height = 3, yaw = 140 },
		{ x = 182, z = 160, y = 10, height = 3, yaw = 250 },
		{ x = 146, z = 140, y = 10, height = 4, yaw = 30 },
		{ x = 236, z = 152, y = 10, height = 3.5, yaw = 110 },
	},
	CRYSTAL_COLOR = { 180, 225, 255 },
	-- Frostpeak's frozen falls, built from ice: columns of frozen water hanging from the cliff's lip down to a bulging
	-- frozen mound, an icicle fringe along the lip, and a frozen pond at the foot (snowy rim, a few cracks). The same
	-- layout on every server (a fixed random seed).
	FROZEN_FALLS = {
		x = 196,
		FACE_Z = 167, -- the cliff's face draws here
		TOP = 33,
		BOTTOM = 10, -- the rise
		WIDTH = 15,
		COLUMNS = 11,
		RADIUS = { 0.9, 1.8 },
		SHORT_SHARE = 0.3, -- this share of the columns stop short, hanging like giant icicles
		MOUND = 7, -- frozen splash balls at the foot
		FRINGE = 12, -- icicles along the lip
		SEED = 7,
		ICE = { 205, 235, 255 },
		DEEP = { 150, 205, 245 },
		FROST = { 240, 250, 255 },
		POND = { x = 196, z = 156, radius = 9, RIM = 12, CRACKS = 4, color = { 190, 228, 250 } },
	},
	-- Icicles hanging from the frozen cliff's brow
	ICICLES = {
		{ x = 168, z = 167, y = 32, length = 4 },
		{ x = 176, z = 167, y = 33, length = 6 },
		{ x = 184, z = 167, y = 32, length = 3 },
		{ x = 210, z = 167, y = 33, length = 5 },
		{ x = 218, z = 167, y = 32, length = 7 },
		{ x = 226, z = 167, y = 31, length = 4 },
	},
	-- Small life from the town's own prop models (scaled copies): flowers, bushes, rocks and lily pads round the falls,
	-- a grove on the grass between the east trails, rocks and crystals on the snowy rise, rocks in the canyon. Clear of
	-- the trails (Lune-tested). y: the ground they stand on (left out: the drawn ground there, up hills too).
	AREA_PROPS = {
		{ model = "FlowerPink", x = 160, z = -120, height = 2.6, yaw = 10 },
		{ model = "FlowerYellow", x = 170, z = -128, height = 2.6, yaw = 80 },
		{ model = "FlowerBlue", x = 205, z = -138, height = 2.6, yaw = 140 },
		{ model = "FlowerWhite", x = 222, z = -112, height = 2.6, yaw = 200 },
		{ model = "FlowerPink", x = 200, z = -100, height = 2.6, yaw = 260 },
		{ model = "FlowerYellow", x = 158, z = -140, height = 2.6, yaw = 320 },
		{ model = "FlowerBlue", x = 226, z = -150, height = 2.6, yaw = 30 },
		{ model = "FlowerWhite", x = 158, z = -112, height = 2.6, yaw = 90 },
		{ model = "Bush", x = 155, z = -105, height = 4.5, yaw = 0 },
		{ model = "BushA", x = 225, z = -125, height = 4, yaw = 120 },
		{ model = "BushB", x = 168, z = -158, height = 5, yaw = 240 },
		{ model = "BushA", x = 205, z = -160, height = 4, yaw = 60 },
		{ model = "RockD", x = 164, z = -147, height = 7, yaw = 30 },
		{ model = "RockA", x = 206, z = -144, height = 6, yaw = 160 },
		{ model = "RockC", x = 212, z = -153, height = 5, yaw = 290 },
		{ model = "RockB", x = 194, z = -140, height = 3, yaw = 60 },
		{ model = "RootsLarge", x = 150, z = -130, height = 3, yaw = 45 },
		{ model = "Lilypad", x = 180, z = -150, y = 0.1, height = 0.3, yaw = 0 },
		{ model = "LilypadA", x = 190, z = -148, y = 0.1, height = 0.3, yaw = 90 },
		{ model = "Lilypad", x = 186, z = -154, y = 0.1, height = 0.3, yaw = 200 },
		{ model = "RockB", x = 230, z = 120, y = 10, height = 3, yaw = 10 },
		{ model = "RockA", x = 160, z = 130, y = 10, height = 2.5, yaw = 100 },
		-- The grove between the east trails (on and round the hill)
		{ model = "TreeD", x = 150, z = 0, height = 22, yaw = 10 },
		{ model = "TreeC", x = 165, z = -25, height = 20, yaw = 80 },
		{ model = "TreeD", x = 172, z = 20, height = 24, yaw = 150 },
		{ model = "TreeB", x = 185, z = 45, height = 26, yaw = 220 },
		{ model = "TreeC", x = 215, z = -35, height = 22, yaw = 290 },
		{ model = "Pine", x = 230, z = 10, height = 28, yaw = 30 },
		{ model = "TreeD", x = 240, z = 50, height = 24, yaw = 100 },
		{ model = "Pine", x = 160, z = 40, height = 26, yaw = 170 },
		{ model = "TreeA", x = 155, z = -40, height = 24, yaw = 240 },
		{ model = "PineB", x = 200, z = -20, height = 27, yaw = 310 },
		{ model = "BushA", x = 178, z = 0, height = 4, yaw = 0 },
		{ model = "BushB", x = 196, z = 25, height = 5, yaw = 90 },
		{ model = "Bush", x = 222, z = 28, height = 4.5, yaw = 180 },
		{ model = "BushA", x = 160, z = 18, height = 4, yaw = 270 },
		{ model = "RockD", x = 195, z = 10, height = 5, yaw = 45 },
		{ model = "RockA", x = 170, z = -8, height = 3, yaw = 135 },
		{ model = "FlowerYellow", x = 182, z = -12, height = 2.6, yaw = 20 },
		{ model = "FlowerPink", x = 210, z = 14, height = 2.6, yaw = 200 },
		{ model = "FlowerBlue", x = 168, z = 32, height = 2.6, yaw = 120 },
		-- The snowy rise's edge by the Frontier portal
		{ model = "RockD", x = 156, z = 112, y = 10, height = 4, yaw = 60 },
		{ model = "RockB", x = 205, z = 120, y = 10, height = 3, yaw = 140 },
		{ model = "RockA", x = 225, z = 140, y = 10, height = 3, yaw = 230 },
		{ model = "RockC", x = 150, z = 128, y = 10, height = 3.5, yaw = 320 },
		{ model = "RockC", x = -150, z = -18, height = 3, yaw = 70 },
		{ model = "RockD", x = -200, z = 19, height = 4, yaw = 160 },
	},
	-- Glowing mushrooms copied from the plaza garden's (their lights left off)
	MUSHROOMS = {
		{ x = 166, z = -150 },
		{ x = 218, z = -142 },
		{ x = 152, z = -116 },
		{ x = 230, z = -108 },
	},
	-- Area effects (at most 4 per area, Lune-tested): drifting snow and an aurora over Frostpeak, rising embers in the canyon
	EMITTERS = {
		{ area = "Frostpeak", kind = "snow", x = 192, y = 44, z = 128, size = { x = 90, z = 90 }, rate = 22 },
		{ area = "Frostpeak", kind = "snow", x = 200, y = 50, z = 200, size = { x = 90, z = 60 }, rate = 10 },
		{ area = "Frostpeak", kind = "aurora" }, -- AURORA's curtains (one effect)
		{ area = "Frostpeak", kind = "glints", x = 192, y = 11, z = 136, size = { x = 90, z = 70 }, rate = 8 },
		{ area = "EmberCanyon", kind = "embers", x = -178, y = 1, z = 0, size = { x = 90, z = 48 }, rate = 12 },
		{ area = "EmberCanyon", kind = "bubbles", x = -236, y = 0.5, z = 0, size = { x = 12, z = 12 }, rate = 6 },
		{ area = "EmberCanyon", kind = "flow", x = -184, y = 0.6, z = -28.5, size = { x = 96, z = 3 }, rate = 10 },
		{ area = "EmberCanyon", kind = "smoke", x = -335, y = 110, z = 10, size = { x = 10, z = 10 }, rate = 2 }, -- the volcano's crater (moved onto its Fx_Smoke when the model is there)
		{ area = "ForestFalls", kind = "fireflies", x = 190, y = 4, z = -125, size = { x = 75, z = 65 }, rate = 10 },
		{ area = "ForestFalls", kind = "leaves", x = 190, y = 34, z = -125, size = { x = 90, z = 70 }, rate = 5 },
	},
	-- The aurora over Frostpeak: hanging curtains (beams with upright attachments hang their width vertically), a
	-- curtain texture turned on its side so its glowing bottom edge runs along the beam's lower edge, waving and drifting
	AURORA = {
		TEXTURE = "rbxassetid://138568776053883", -- assets/ui/fx/aurora-curtain-beam.png (aurora-curtain.png turned 90 degrees)
		TEXTURE_LENGTH = 70,
		SPEED = 0.15,
		TRANSPARENCY = 0.2,
		CURTAINS = {
			{ from = { x = 125, y = 78, z = 228 }, to = { x = 255, y = 84, z = 205 }, width = 44, curve = { 30, -26 } },
			{ from = { x = 150, y = 92, z = 252 }, to = { x = 280, y = 96, z = 230 }, width = 40, curve = { -24, 30 } },
			{ from = { x = 110, y = 70, z = 205 }, to = { x = 215, y = 74, z = 190 }, width = 34, curve = { 22, 18 } },
		},
	},
	-- Ambient sounds, positioned and quiet (free Creator Store sounds; the user judges them by ear)
	SOUNDS = {
		{ name = "Falls", id = "rbxassetid://9116496316", x = 185, y = 6, z = -158, volume = 0.5, range = 90 }, -- Pro Sound Effects: Medium Size Waterfall 1
		{ name = "Wind", id = "rbxassetid://5799870105", x = 195, y = 20, z = 130, volume = 0.35, range = 100 }, -- Ambient wind (Mukar)
		{ name = "Embers", id = "rbxassetid://9112780462", x = -200, y = 4, z = 0, volume = 0.3, range = 70 }, -- Pro Sound Effects: Fireplace Constant Burning Flame 4
		{ name = "Birds", id = "rbxassetid://9112831666", x = 0, y = 18, z = 0, volume = 0.25, range = 170 }, -- Pro Sound Effects: Morning Birds 2 (loop)
	},
	SMALL_DECOR_SIZE = 4, -- studs: hand-placed decor parts smaller than this cast no shadow
	-- Terrain colours (Grass takes Town.GRASS_COLOR); Basalt and CrackedLava appear only in the canyon (the caldera)
	MATERIAL_COLORS = {
		Rock = { 98, 120, 92 }, -- mossy: the forest's cliff
		Slate = { 118, 128, 144 }, -- Frostpeak's cliff and peak
		CrackedLava = { 40, 30, 32 }, -- the caldera's floor and the lava's banks
		Basalt = { 46, 42, 50 }, -- the caldera's walls, rims and trail
		Snow = { 240, 246, 255 },
		Glacier = { 170, 215, 245 },
		Ground = { 120, 96, 70 },
	},
	WATER = { COLOR = { 60, 190, 200 }, TRANSPARENCY = 0.6, REFLECTANCE = 0.3, WAVE_SIZE = 0.05, WAVE_SPEED = 6 },
	PLOT_GROUND_MARGIN = 5, -- studs of plain ground round each shop, so no grass blades poke through its floor
	MAX_CELLS = 180000, -- estimated 4-stud cells (memory: the spike's oversized fill cost +80 MB)
}
