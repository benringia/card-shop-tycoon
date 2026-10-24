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
		-- Modern high street (code-built stand-ins until models are added): black LED street lights along the
		-- sidewalks, trimmed hedges round the island's edge
		StreetLight = { height = 11, collide = true },
		Hedge = { height = 3, collide = true },
		Bench = { height = 3, collide = true },
		Fence = { height = 4, collide = true },
		Portal = { height = 14, collide = false },
		-- The plaza's healing fountain (WildService): parts named Water glow and breathe; a floating gem (the
		-- model's Crystal part, or one made above its top) turns over it. The model lives in PlaceProps (meshes).
		HealingSpring = { height = 14, collide = true },
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
	},
	-- Decor layout (TownLayout). Distances in studs.
	LAYOUT = {
		LAMP_INSET = 2, -- lamps stand this far into the street from the plot fronts
		ROW_END_LAMP_OFFSET = 4, -- past the outer edge of each row's end plots
		BENCH_RADIUS = 11, -- around the spring
		BENCH_ANGLES = { 45, 135, 225, 315 },
		EDGE_FENCE_INSET = 2, -- the fence round the island stands this far inside the bounds
		FENCE_SECTION = 6.5, -- one Fence prop per section (the Fence model is 6.5 long at its 4-stud height)
		STREET_HALF_LENGTH = 110, -- the street runs x -110..110
		PLAZA_RADIUS = 26, -- round stone pad around the spring; open room for event NPCs and stalls
		SIDEWALK = 8, -- the paved strip along each shop row's front
		PLOT_MARGIN = 1, -- decor stays this far outside every plot footprint (walls sit in it)
	},
	PORTAL_CLEARANCE = 10, -- nothing but the portal frame this close to a portal
	-- Butterflies round the healing spring (ButterflyController, client only). Studs; colours as { r, g, b }.
	BUTTERFLIES = {
		COUNT = 10,
		SIZE = 0.55, -- one wing's width
		SPEED = 3, -- studs a second along their loop
		FLAP_SPEED = 14,
		MIN_RADIUS = 6,
		MAX_RADIUS = 17,
		MIN_HEIGHT = 2.5,
		MAX_HEIGHT = 8,
		COLORS = { { 255, 150, 210 }, { 140, 210, 255 }, { 255, 230, 120 }, { 190, 150, 255 }, { 150, 240, 190 } },
	},

	-- The playable area: the Baseplate is cut to this size and ringed with invisible walls
	BOUNDS = { HALF_X = 130, HALF_Z = 110, WALL_HEIGHT = 60 },
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
		-- Pack products: each box's place holds a stack of thin packs with the pack art (Config/Packs art)
		PACKS = { PER_STACK = 5, HEIGHT = 1.05, ASPECT = 0.65, THICKNESS = 0.05, LEAN = 10 },
		-- The yellow price tag on the front edge of each stocked row, under its first stack
		TAG = {
			SIZE = { 0.95, 0.42, 0.05 }, -- studs: width, height, depth
			COLOR = { 255, 214, 50 },
			EDGE = { 220, 160, 10 },
			TEXT = { 45, 25, 10 },
			GAP = 0.08, -- in front of the boxes
			TILT = 6, -- degrees, hung a little crooked
		},
	},

	-- Shop shells (PlotService): one modern look for every shop. Walls sit outside the floor edges, so the
	-- placement grid is unchanged. Studs; colours as { r, g, b }.
	WALL_HEIGHT = 18, -- room for the camera under the ceiling
	AWNING_HEIGHT = 12, -- the top of the glass shop front; the dark sign band runs above it
	AWNING_DEPTH = 4, -- how far the flat canopy over the doors reaches out over the street
	WALL_THICKNESS = 1,
	ROOF_THICKNESS = 1,
	SHOP = {
		WALL = { 244, 245, 248 }, -- smooth white render
		CHARCOAL = { 38, 41, 48 }, -- base band, sign band, roof edge
		FRAME = { 24, 26, 30 }, -- black aluminium round the glass
		GLASS = { 190, 220, 235 },
		GLASS_TRANSPARENCY = 0.72,
		FLOOR = { 214, 186, 150 }, -- light oak (owned shops)
		FEATURE_WALL = { 222, 216, 206 }, -- the back wall inside: a warm greige, the same in every shop
		BASE_HEIGHT = 1.2, -- the charcoal band along the bottom of the outside walls
		PARAPET = 1.2, -- the roof edge rising above the walls
		MULLION = 0.35, -- frame bar thickness
		PANES = 3, -- glass panes each side of the doors
		DOOR_WIDTH = 12, -- the doorway (two sliding panels)
		DOOR_HEIGHT = 10,
		DOOR_OPEN_SECONDS = 0.45,
		DOOR_SENSE = 9, -- studs: anyone this close to the doorway (inside or out) opens it
		CANOPY = { 36, 39, 46 },
		CANOPY_LIGHT = { 255, 240, 215 },
		PLANTER = { 52, 56, 64 },
		LEAVES = { 70, 140, 85 },
		CEILING = { 250, 250, 252 },
		PANEL = { 255, 252, 245 }, -- LED ceiling panels
		PANEL_ROWS = { -12, 0, 12 },
		PANEL_COLS = { -13, 0, 13 },
		PANEL_SIZE = { 6, 3 },
		PANEL_RANGE = 20,
		PANEL_BRIGHTNESS = 0.45,
		ACCENT_STRIP = 0.4, -- the glowing strip under the sign band, in the shop's accent colour
	},

	-- One accent colour per plot id: the glowing strip under the sign
	PLOT_THEMES = {
		{ name = "Mint", accent = { 88, 190, 150 } },
		{ name = "Coral", accent = { 240, 125, 100 } },
		{ name = "Violet", accent = { 150, 115, 220 } },
		{ name = "Gold", accent = { 235, 185, 60 } },
		{ name = "Azure", accent = { 70, 150, 235 } },
		{ name = "Rose", accent = { 230, 110, 150 } },
	},

	GRASS_COLOR = { 120, 180, 95 },
	STREET_COLOR = { 62, 64, 72 }, -- charcoal asphalt
	PLAZA_COLOR = { 236, 231, 220 }, -- pale limestone
	SIDEWALK_COLOR = { 205, 207, 212 }, -- pale concrete paving
	-- Floor details (TownService; crosswalks and portal paths placed by TownLayout). Studs; colours as { r, g, b }.
	FLOOR = {
		SIDEWALK_TILE = 4, -- square paving slabs: a seam every this many studs
		SEAM_WIDTH = 0.15,
		SEAM_COLOR = { 170, 173, 180 },
		-- Zebra crossings in front of every shop door, sidewalk to sidewalk (skipping the plaza)
		CROSSWALK = { WIDTH = 7, STRIPE = 1.4, GAP = 1.4, COLOR = { 240, 240, 234 } },
		-- Glowing rings set into the plaza: one at the healing area's edge (Combat.SPRING_RADIUS) and one this far
		-- inside the plaza's rim
		RING_WIDTH = 0.35,
		RING_RIM_INSET = 2,
		RING_COLOR = { 120, 220, 255 },
		-- A glowing line from the plaza's edge to each portal, in that portal's ring colour (PORTAL_EFFECTS)
		PATH_WIDTH = 0.5,
		PATH_END_INSET = 6, -- stops this far short of the portal
		GLOW_TRANSPARENCY = 0.15,
	},

	-- Main town only; the Frontier keeps its own lighting
	LIGHTING = {
		CLOCK_TIME = 15.5, -- mid-afternoon, a slightly lower sun
		BRIGHTNESS = 1.6, -- sunlight (Roblox default 2)
		EXPOSURE = -0.25, -- whole-scene exposure: a softer, dimmer look
		AMBIENT = { 110, 102, 96 },
		OUTDOOR_AMBIENT = { 120, 112, 105 },
		ATMOSPHERE = { density = 0.25, offset = 0.1, haze = 1.2, glare = 0.2, color = { 225, 215, 200 }, decay = { 140, 160, 190 } },
		BLOOM = { intensity = 0.25, size = 24, threshold = 2 }, -- only the brightest spots glow
		SPECULAR = 0.35, -- how much walls and floors reflect the sky (Roblox default 1 makes bright patches)
		SATURATION = 0.12,
	},
}
