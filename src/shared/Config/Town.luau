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
		Lamp = { height = 9, collide = true, yaw = 90 }, -- the lantern pole's arm points along the model's -X
		Bench = { height = 3, collide = true },
		Fence = { height = 4, collide = true },
		Portal = { height = 14, collide = false },
		Register = { height = 1.5, collide = false, yaw = -90 }, -- the cash register's price display faces its +X
		CounterDecor = { height = 1.2, collide = false },
		-- the Store Shelf model faces -X; stretch = fill the shelf's box on every axis (plain straight parts only)
		Shelf = { height = 0, collide = false, yaw = 90, stretch = true },
		-- fixtures: drawn on their part (which becomes an invisible hitbox) only when the model file exists
		Computer = { height = 0, collide = false, yaw = 90 }, -- the order computer (a desk set; its monitor faces -X)
		Condenser = { height = 0, collide = false }, -- the Card Condenser
		Counter = { height = 0, collide = false }, -- the register counter: a market stall drawn over it (COUNTER.STALL)
		-- each shelf type's look (Config/Shelves prop); roll stands a model up (degrees about its Z, before yaw)
		WallShelf = { height = 0, collide = false },
		HookRack = { height = 0, collide = false, roll = 90 }, -- a landscape pegboard, stood upright
		DisplayRack = { height = 0, collide = false, yaw = 90, stretch = true }, -- double-sided, long side on its Z
		Showcase = { height = 0, collide = false, yaw = 90, stretch = true }, -- glass counter, long side on its Z
		DeliveryPad = { height = 0, collide = false, stretch = true }, -- a wooden pallet
		-- delivery boxes, one per product (Products boxProp); welded to the box part, so they travel when carried
		BoxPacks = { height = 0, collide = false },
		BoxSleeves = { height = 0, collide = false },
		BoxDecks = { height = 0, collide = false },
		BoxBooster = { height = 0, collide = false },
		-- shop front awning, repeated across the front; parts named "COLOUR ME" take the plot's awning colour
		Awning = { height = 0, collide = false },
	},
	-- Decor layout (TownLayout). Distances in studs.
	LAYOUT = {
		LAMP_INSET = 2, -- lamps stand this far into the street from the plot fronts
		ROW_END_LAMP_OFFSET = 4, -- past the outer edge of each row's end plots
		BENCH_RADIUS = 11, -- around the spring
		BENCH_ANGLES = { 45, 135, 225, 315 },
		EDGE_FENCE_INSET = 2, -- the fence round the island stands this far inside the bounds
		FENCE_SECTION = 6.5, -- one Fence prop per section (the Fence model is 6.5 long at its 4-stud height)
		STREET_HALF_LENGTH = 110, -- the cobblestone street runs x -110..110
		PLAZA_RADIUS = 22, -- round stone pad around the spring; open room for event NPCs and stalls
		PLOT_MARGIN = 1, -- decor stays this far outside every plot footprint (walls sit in it)
	},
	PORTAL_CLEARANCE = 10, -- nothing but the portal frame this close to a portal

	-- The playable area: the Baseplate is cut to this size and ringed with invisible walls
	BOUNDS = { HALF_X = 130, HALF_Z = 90, WALL_HEIGHT = 60 },
	-- Each plaza portal's look: ring and glow-part colour, particle colours, and 1-3 emitters (phones).
	-- Emitters sit on a box filling the ring. speed/lifetime/size are { min, max } or { start, end };
	-- rise = upward pull (negative falls); colors on an emitter override the portal's.
	PORTAL_EFFECTS = {
		Wild = {
			ring = { 110, 210, 90 },
			colors = { { 140, 235, 110 }, { 245, 215, 90 } },
			emitters = {
				{ texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 16, lifetime = { 2, 3 }, speed = { 1.5, 3 }, size = { 0.9, 0 }, rise = 1, spin = 60 },
				{ texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 6, lifetime = { 1.5, 2 }, speed = { 0.3, 0.6 }, size = { 1.2, 0.2 }, rise = 0, spin = 180 },
			},
		},
		Frontier = {
			ring = { 70, 150, 255 },
			colors = { { 215, 245, 255 }, { 160, 205, 255 } },
			emitters = {
				{ texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 14, lifetime = { 3, 4 }, speed = { 0.4, 1 }, size = { 0.7, 0.4 }, rise = -0.8, spin = 30 },
				{ texture = "rbxasset://textures/particles/smoke_main.dds", rate = 3, lifetime = { 2.5, 3.5 }, speed = { 0.2, 0.5 }, size = { 3, 5 }, rise = 0.3, spin = 20, transparency = { 0.82, 1 }, colors = { { 120, 255, 200 }, { 140, 170, 255 }, { 210, 140, 255 } } },
			},
		},
		Arena = {
			ring = { 230, 60, 45 },
			colors = { { 255, 205, 90 }, { 255, 90, 40 } },
			emitters = {
				{ texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 20, lifetime = { 1.2, 1.8 }, speed = { 3, 5 }, size = { 0.6, 0 }, rise = 3, spin = 90 },
				{ texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 5, lifetime = { 1, 1.5 }, speed = { 0.3, 0.6 }, size = { 1.4, 0.3 }, rise = 0, spin = 200 },
			},
		},
	},
	DELIVERY_PALLET = { height = 1 }, -- the DeliveryPad model's height; delivered boxes stand on top of it
	PORTAL_GLOW = { BRIGHTNESS = 2, RANGE = 18 },
	PORTAL_PANEL_TRANSPARENCY = 0.65, -- the frame's see-through glow panels, so the particles show through
	PORTAL_RING_CENTRE = 5, -- height of the ring centre above the ground (WildService and ArenaService rings)
	PORTAL_LABEL_HEIGHT = 17, -- floating name above each plaza portal
	PORTAL_LABEL_DISTANCE = 40, -- shown only this close, so far labels don't pile up

	-- Register counter (front = customer side). The register takes the left end, full depth; scan items lie
	-- along the front edge to its right; the decor sits in a strip along the back. Props are fitted into these
	-- boxes; x = offset from the counter centre.
	COUNTER = {
		PROP_DEPTH = 0.6, -- the back strip (decor)
		REGISTER = { x = -1.8, width = 2.4, height = 2.2, depth = 2 },
		DECOR = { x = 2.4, width = 0.8, height = 1.2 },
		ITEM_GAP = 0.15, -- between the register and the first scan item
		-- The Counter prop is a market stall: its front lines up with the counter's, it reaches back over the
		-- cashier, and its canopy starts at canopyFrom x height
		STALL = { width = 6.6, height = 7.2, depth = 4.2, canopyFrom = 0.79 },
		STAFF_BEHIND = 1.6, -- the cashier (owner or pet) stands this far behind the counter, inside the stall
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
	WALL_HEIGHT = 18, -- room for the camera under the ceiling
	AWNING_HEIGHT = 12, -- the awning's top edge above the floor; a front wall above it carries the sign
	WALL_THICKNESS = 1,
	TRIM_HEIGHT = 0.6,
	PILLAR_SIZE = 1.6,
	AWNING_DEPTH = 5, -- how far the awning reaches out over the street
	AWNING_DROP = 2.5, -- how far it slopes down over that distance
	AWNING_STRIPES = 8,
	ROOF_THICKNESS = 1, -- the flat ceiling and the gable panels
	GABLE = { RISE = 8, OVERHANG = 1.5 }, -- roof ridge runs side to side, this high above the ceiling
	CEILING_LIGHTS = { XS = { -12, 0, 12 }, SIZE = 3, RANGE = 26, BRIGHTNESS = 0.8, COLOR = { 255, 225, 180 } },

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
		CLOCK_TIME = 15.5, -- mid-afternoon, a slightly lower sun
		BRIGHTNESS = 1.6, -- sunlight (Roblox default 2)
		EXPOSURE = -0.25, -- whole-scene exposure: a softer, dimmer look
		AMBIENT = { 95, 88, 85 },
		OUTDOOR_AMBIENT = { 120, 112, 105 },
		ATMOSPHERE = { density = 0.25, offset = 0.1, haze = 1.2, glare = 0.2, color = { 225, 215, 200 }, decay = { 140, 160, 190 } },
		BLOOM = { intensity = 0.4, size = 24, threshold = 1.6 },
		SATURATION = 0.12,
	},
}
