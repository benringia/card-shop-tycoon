--!strict
-- The main town (world pass 1 spec, docs/superpowers/specs/2026-10-25-main-town-design.md): prop slots,
-- decor layout, shop shell sizes, plot themes and lighting. Plain data only (colours are { r, g, b },
-- angles in degrees) so Lune tests can load this file. Prop models: docs/props.md.
return {
	-- Prop models with more parts than this use the code-built fallback
	MAX_PROP_PARTS = 150,

	-- Each slot is a file name in assets/props. A slot also uses its variants: files named after the slot plus a
	-- suffix that starts with a capital letter or digit (Tree, TreeA, TreeB ... ; Flower, FlowerBlue ...), taken in
	-- turn. height = bounding-box height after scaling (studs). Shelf fits the shelf's own size instead.
	-- yaw (degrees) turns a slot's models whose front isn't -Z; a model's own YawOffset attribute wins.
	SLOTS = {
		Tree = { height = 18, collide = true },
		Pine = { height = 20, collide = true },
		Bush = { height = 3, collide = false },
		Flower = { height = 1.5, collide = false },
		Clover = { height = 1, collide = false },
		Rock = { height = 3, collide = true },
		Crate = { height = 3, collide = true },
		Barrel = { height = 3.5, collide = true },
		Lamp = { height = 9, collide = true, yaw = 90 }, -- the lantern pole's arm points along the model's -X
		Bench = { height = 3, collide = true },
		Fence = { height = 4, collide = true },
		Portal = { height = 14, collide = false },
		PlazaDecor = { height = 2.5, collide = false },
		Register = { height = 1.5, collide = false, yaw = -90 }, -- the cash register's price display faces its +X
		CounterDecor = { height = 1.2, collide = false },
		-- the Store Shelf model faces -X; stretch = fill the shelf's box on every axis (plain straight parts only)
		Shelf = { height = 0, collide = false, yaw = 90, stretch = true },
	},
	TREE_SLOTS = { "Tree", "Pine" }, -- the tree lines alternate these

	-- Decor layout (TownLayout). Distances in studs.
	LAYOUT = {
		LAMP_INSET = 2, -- lamps stand this far into the street from the plot fronts
		ROW_END_LAMP_OFFSET = 4, -- past the outer edge of each row's end plots
		BENCH_RADIUS = 10, -- around the spring
		BENCH_ANGLES = { 45, 135, 225, 315 },
		FLOWER_ANGLE_OFFSET = 18, -- flower bed beside each bench
		PLAZA_DECOR_ANGLES = { 0, 180 }, -- on the plaza edge, between the benches
		PLAZA_DECOR_RADIUS = 13,
		GAP_CLOVER_DEPTHS = { 12, 28 }, -- clover patches this far back from the street in each gap
		GAP_CRATE_DEPTH = 3, -- crate and barrel this far back from the street, in the gaps between plots
		GAP_CRATE_SPREAD = 1.5, -- crate and barrel sit this far either side of the gap centre
		FENCE_OFFSET = 5, -- fence line behind the back of each row
		FENCE_HALF_LENGTH = 70,
		FENCE_SECTION = 8, -- one Fence prop per section
		TREE_OFFSET = 12, -- tree line behind the back of each row
		TREE_SPACING = 14,
		STREET_HALF_LENGTH = 90, -- the cobblestone street runs x -90..90
		STREET_END_TREE_X = 100,
		STREET_END_TREE_Z = 22,
		PORTAL_ROCK_BACK = 12, -- rocks behind each portal, away from the town
		PORTAL_ROCK_SIDE = 4,
		PLAZA_RADIUS = 14, -- round stone pad around the spring
		PLOT_MARGIN = 1, -- decor stays this far outside every plot footprint (walls sit in it)
	},
	PORTAL_CLEARANCE = 10, -- nothing but the portal frame this close to a portal
	PORTAL_LABEL_HEIGHT = 17, -- floating name above each plaza portal
	PORTAL_LABEL_DISTANCE = 150, -- shown up to this far away

	-- Register counter (front = customer side). The register takes the left end, full depth; scan items lie
	-- along the front edge to its right; the decor sits in a strip along the back. Props are fitted into these
	-- boxes; x = offset from the counter centre.
	COUNTER = {
		PROP_DEPTH = 0.6, -- the back strip (decor)
		REGISTER = { x = -1.8, width = 2.4, height = 2.2, depth = 2 },
		DECOR = { x = 2.4, width = 0.8, height = 1.2 },
		ITEM_GAP = 0.15, -- between the register and the first scan item
	},

	-- Stock boxes on Products shelves (ShelfStock): levels match the Store Shelf's plates
	SHELF_STOCK = {
		LEVELS = { 0.1, 0.37, 0.62 },
		PER_LEVEL = 4,
		BOX_HEIGHT = 0.9,
		WIDTH_FILL = 0.7,
		DEPTH_FILL = 0.5,
	},

	-- Shop shells (PlotService). Walls sit outside the floor edges.
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 1,
	TRIM_HEIGHT = 0.6,
	PILLAR_SIZE = 1.6,
	AWNING_DEPTH = 4, -- how far the awning reaches out over the street
	AWNING_DROP = 2.5, -- how far it slopes down over that distance
	AWNING_STRIPES = 8,
	ROOF_THICKNESS = 1,
	ROOF_CHECK_SECONDS = 0.2, -- client: how often it checks which shop you stand in

	-- One theme per plot id
	PLOT_THEMES = {
		{ name = "Mint", wall = { 198, 236, 214 }, trim = { 88, 160, 124 }, awning = { 110, 190, 150 }, roof = { 120, 170, 140 }, floor = { 225, 240, 228 } },
		{ name = "Peach", wall = { 255, 218, 193 }, trim = { 200, 120, 85 }, awning = { 240, 150, 110 }, roof = { 190, 120, 95 }, floor = { 250, 232, 218 } },
		{ name = "Lavender", wall = { 222, 208, 240 }, trim = { 130, 105, 175 }, awning = { 160, 130, 210 }, roof = { 125, 105, 160 }, floor = { 238, 230, 248 } },
		{ name = "Butter", wall = { 255, 240, 184 }, trim = { 195, 160, 60 }, awning = { 240, 200, 80 }, roof = { 180, 150, 80 }, floor = { 252, 246, 220 } },
		{ name = "Sky", wall = { 200, 226, 248 }, trim = { 80, 130, 190 }, awning = { 110, 165, 225 }, roof = { 95, 130, 175 }, floor = { 228, 240, 252 } },
		{ name = "Rose", wall = { 250, 208, 220 }, trim = { 190, 95, 125 }, awning = { 235, 125, 160 }, roof = { 175, 100, 125 }, floor = { 250, 230, 236 } },
	},
	STRIPE_COLOR = { 255, 255, 255 },

	GRASS_COLOR = { 120, 180, 95 },
	STREET_COLOR = { 190, 175, 155 },
	PLAZA_COLOR = { 215, 205, 190 },

	-- Main town only; the Frontier keeps its own lighting
	LIGHTING = {
		CLOCK_TIME = 14.5,
		AMBIENT = { 120, 110, 105 },
		OUTDOOR_AMBIENT = { 150, 140, 130 },
		ATMOSPHERE = { density = 0.25, offset = 0.1, haze = 1.2, glare = 0.2, color = { 225, 215, 200 }, decay = { 140, 160, 190 } },
		BLOOM = { intensity = 0.4, size = 24, threshold = 1.6 },
		SATURATION = 0.12,
	},
}
