--!strict
-- The scenery round the town and in the three portal areas (Portal Worlds spec): terrain shapes Util/TownTerrain turns
-- into fills (SceneryService builds them at server start, main game only). Plain data, read by Lune tests.
-- Shapes: Block (x, y, z centre; size; yaw in degrees, TownLayout's convention), Ball (centre, radius), Wedge (like
-- Block). Materials are Enum.Material names. Roblox draws terrain 2 studs above a fill's top (TownTerrain.SURFACE_LIFT),
-- so ground at y 0 is filled to y -2; inside the island (x -130..130, z -110..110) nothing is filled higher.
return {
	-- The ground everywhere round the town, drawn at y 0 (applied first; everything else overrides it)
	GROUND = {
		{ shape = "Block", x = 0, y = -5, z = 0, size = { x = 560, y = 6, z = 480 }, material = "Grass" },
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
	},
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
