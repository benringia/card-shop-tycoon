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
		Bench = { height = 3, collide = true, yaw = 180 }, -- the bench model's seat faces its +Z: turned, the plaza benches face the spring
		Fence = { height = 4, collide = true },
		Portal = { height = 14, collide = false }, -- today's frame: stands in at a portal until its own model is saved
		-- The portals grown from their worlds (PORTAL_LOOKS; Blender models, docs/props.md)
		PortalWild = { height = 28, collide = false },
		PortalFrontier = { height = 28, collide = false },
		PortalArena = { height = 28, collide = false },
		Terminal = { height = 0, collide = false }, -- the POS terminal on the checkout (fits COUNTER.REGISTER)
		CounterDecor = { height = 1.2, collide = false },
		-- fixtures: drawn on their part (which becomes an invisible hitbox) only when the model file exists
		-- built = the code-built look is the real one: model files are ignored, placement ghosts use it too
		Computer = { height = 0, collide = false, built = true }, -- the order computer: a modern workstation
		Condenser = { height = 0, collide = false, built = true }, -- the Card Condenser (CONDENSER_LOOK)
		GradingStation = { height = 0, collide = false, built = true }, -- the Grading Station (GRADING_LOOK)
		Trophy = { height = 0, collide = false, built = true }, -- a boss trophy (TROPHY_LOOK; its Gem in the boss's colour)
		-- each product shelf's look (Config/Shelves prop): code-built modern shelving (Util/ShelfLooks, SHELF_LOOK)
		Shelf = { height = 0, collide = false, built = true }, -- Small Pack Rack: a one-sided gondola
		WallShelf = { height = 0, collide = false, built = true },
		HookRack = { height = 0, collide = false, built = true }, -- Accessory Hook: a pegboard with hooks
		DisplayRack = { height = 0, collide = false, built = true }, -- Big Display Rack: double-sided
		-- stretch = fill the box on every axis (plain straight parts only); roll stands a model up (degrees about Z)
		CardCase = { height = 0, collide = false, built = true }, -- Glass Showcase / Collector Case: a tall glass case (CASE_LOOK)
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
		BENCH_RADIUS = 13.5, -- around the spring, just outside the plaza gazebo (Config/Plaza)
		BENCH_ANGLES = { 45, 135, 225, 315 },
		EDGE_FENCE_INSET = 2, -- the fence round the island stands this far inside the bounds
		FENCE_SECTION = 6.5, -- one Fence prop per section (the Fence model is 6.5 long at its 4-stud height)
		STREET_HALF_LENGTH = 110, -- the street runs x -110..110
		PLAZA_RADIUS = 26, -- round stone pad around the spring; open room for event NPCs and stalls
		SIDEWALK = 8, -- the paved strip along each shop row's front
		PLOT_MARGIN = 1, -- decor stays this far outside every plot footprint (walls sit in it)
	},
	PORTAL_CLEARANCE = 10, -- nothing but the portal frame this close to a portal
	-- Butterflies (ButterflyController, client only): a flock round the healing spring and more at Forest Falls and the
	-- east trails' start; each spot's flock loops round its centre between its radii. Studs; colours as { r, g, b }.
	BUTTERFLIES = {
		SPOTS = {
			{ x = 0, z = 0, count = 10, minRadius = 6.5, maxRadius = 8.5 }, -- under the plaza gazebo's dome, round the fountain
			{ x = 190, z = -120, count = 5, minRadius = 6, maxRadius = 18 },
			{ x = 136, z = 0, count = 3, minRadius = 3, maxRadius = 10 },
		},
		SIZE = 0.55, -- one wing's width
		SPEED = 3, -- studs a second along their loop
		FLAP_SPEED = 14,
		MIN_HEIGHT = 2.5,
		MAX_HEIGHT = 8,
		COLORS = { { 255, 150, 210 }, { 140, 210, 255 }, { 255, 230, 120 }, { 190, 150, 255 }, { 150, 240, 190 } },
	},

	-- The island inside the hedge (the Baseplate is cut to this size); the invisible walls follow WALK_EDGE
	BOUNDS = { HALF_X = 130, HALF_Z = 110, WALL_HEIGHT = 60 },
	-- Portal Worlds (spec 2026-10-30-town-portal-worlds-design): each portal stands in its own area at the end of a
	-- trail from the street's end (Util/PortalTrails). Order matches TownService's portals (Wild, Frontier, Arena);
	-- each trail's last point is that portal's spot (Wild.PLAZA_PORTAL, Places.FRONTIER_PORTAL, Pvp.ARENA_PORTAL).
	-- surface: the trail's terrain material. sign: the signpost board's words. A trail point's y is the ground's height there.
	PORTAL_AREAS = {
		{
			key = "Wild",
			name = "Forest Falls",
			effect = "Wild",
			sign = "THE WILD",
			surface = "Ground",
			trail = { { x = 110, z = -20 }, { x = 130, z = -26 }, { x = 148, z = -55 }, { x = 165, z = -95 }, { x = 185, z = -118 } },
		},
		{
			key = "Frontier",
			name = "Frostpeak",
			effect = "Frontier",
			sign = "FRONTIER",
			surface = "Snow",
			-- climbs onto Frostpeak's snowy rise (y: the ground's height at a point, 0 when left out)
			trail = { { x = 110, z = 20 }, { x = 130, z = 26 }, { x = 148, z = 58 }, { x = 166, z = 100, y = 10 }, { x = 182, z = 128, y = 10 } },
		},
		{
			key = "Arena",
			name = "Ember Canyon",
			effect = "Arena",
			sign = "PVP ARENA",
			surface = "Sand",
			trail = { { x = -110, z = 0 }, { x = -130, z = 0 }, { x = -205, z = 0 } },
		},
	},
	-- Where players can walk: the island plus the three trails and clearings (the invisible walls run along it)
	WALK_EDGE = {
		{ x = -130, z = -110 }, { x = 130, z = -110 }, { x = 130, z = -45 }, { x = 140, z = -60 }, { x = 150, z = -90 },
		{ x = 150, z = -165 }, { x = 230, z = -165 }, { x = 230, z = -85 }, { x = 178, z = -80 }, { x = 158, z = -45 },
		{ x = 140, z = -15 }, { x = 140, z = 15 }, { x = 160, z = 48 }, { x = 180, z = 85 }, { x = 235, z = 90 },
		{ x = 235, z = 170 }, { x = 150, z = 170 }, { x = 150, z = 98 }, { x = 140, z = 62 }, { x = 130, z = 45 },
		{ x = 130, z = 110 }, { x = -130, z = 110 }, { x = -130, z = 24 }, { x = -225, z = 24 }, { x = -225, z = -24 },
		{ x = -130, z = -24 },
	},
	-- Trails: width, the hedge gap round each exit, walk lengths the user chose (studs; 16 studs/s walking)
	TRAIL = { WIDTH = 12, HEDGE_GAP = 8, WALK_SPEED = 16, EAST_LENGTH = { 125, 140 }, ARENA_LENGTH = { 85, 100 } },
	-- "This way" signposts: arms name PORTAL_AREAS keys and point at that trail's start
	SIGNPOSTS = {
		{ x = 30, z = 0, arms = { "Wild", "Frontier", "Arena" } },
		{ x = 112, z = 0, arms = { "Wild", "Frontier" } },
		{ x = -112, z = 12, arms = { "Arena" } },
	},
	PORTAL_REACH = 16, -- studs: travel remotes only work this close to their portal
	SIGN_DISTANCE = 120, -- studs: signpost and arch words stop drawing beyond this
	SIGN_SUBTEXT = "This way", -- under each name on a signpost arm
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
	-- The delivery spot (PlotService, StockService): outside on the sidewalk beside the doors, a concrete platform
	-- level with the shop floor, a charcoal mat with a yellow safety border, a "DELIVERIES" sign on its street face and
	-- two bollards at its street corners. Delivered boxes stand on the mat. X = plot-local offset of its centre
	-- (negative = the register's side); GAP = from the shop front wall out to the pad. Studs; colours { r, g, b }.
	DELIVERY = {
		X = -12.7,
		GAP = 0.6,
		SIZE = { 6, 0.2, 6 }, -- the spot boxes stand on (width, height, depth)
		PLATFORM = { 178, 181, 188 },
		MAT = { 44, 47, 54 },
		BORDER = { 245, 200, 40 },
		BORDER_WIDTH = 0.3,
		BOLLARD = { 28, 30, 36 },
		BOLLARD_SIZE = 0.5,
		BOLLARD_HEIGHT = 2.4,
		TEXT = "📦 DELIVERIES",
	},
	-- The portals grown from their worlds (spec 2026-10-30-town-portals-design, the user's pick A), keyed like
	-- PORTAL_AREAS' effect. Each model's parts (Util/PortalLooks.parts): Frame, Opening (the vortex fills it) and the
	-- spots its effects use; glow: parts drawn as glowing colour. vortex: the swirl's colours (start, end), its spin
	-- (degrees a second, client side near the camera) and transparency. effects: beams between two parts (from, to;
	-- a scrolling texture) or emitters on a part (fields as PORTAL_EFFECTS' emitters). Server/Util/PortalBuild.
	PORTAL_LOOKS = {
		Wild = {
			slot = "PortalWild",
			vortex = { colors = { { 60, 200, 60 }, { 250, 185, 40 } }, spin = 30, transparency = 0.05 },
			light = { color = { 170, 240, 140 }, brightness = 1, range = 16 },
			glow = { Pool = { 90, 220, 210 }, Flowers = { 255, 215, 90 } },
			effects = {
				{ kind = "beam", from = "Fx_Trickle", to = "Fx_Pool", texture = "rbxassetid://139671283074387", width = 0.9, speed = 1.5, color = { 120, 220, 255 } },
				{ kind = "emitter", at = "Fx_Pool", texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 8, lifetime = { 0.6, 1 }, speed = { 1, 2 }, size = { 0.6, 0 }, rise = -6, spin = 90, colors = { { 170, 235, 255 }, { 255, 255, 255 } } },
				{ kind = "emitter", at = "Opening", texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 16, lifetime = { 2, 3 }, speed = { 1.5, 3 }, size = { 0.9, 0 }, rise = 1, spin = 60, colors = { { 140, 235, 110 }, { 245, 215, 90 } } },
			},
		},
		Frontier = {
			slot = "PortalFrontier",
			vortex = { colors = { { 30, 130, 255 }, { 110, 210, 255 } }, spin = 25, transparency = 0.05 },
			light = { color = { 130, 205, 255 }, brightness = 1, range = 16 },
			glow = {},
			effects = {
				{ kind = "emitter", at = "Fx_Base", texture = "rbxasset://textures/particles/smoke_main.dds", rate = 3, lifetime = { 3, 4 }, speed = { 0.2, 0.6 }, size = { 4, 7 }, rise = 0.2, spin = 20, transparency = { 0.8, 1 }, colors = { { 200, 240, 255 } } },
				{ kind = "emitter", at = "Opening", texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 14, lifetime = { 3, 4 }, speed = { 0.4, 1 }, size = { 0.7, 0.4 }, rise = -0.8, spin = 30, colors = { { 215, 245, 255 }, { 160, 205, 255 } } },
			},
		},
		Arena = {
			slot = "PortalArena",
			vortex = { colors = { { 255, 50, 20 }, { 255, 150, 30 } }, spin = 35, transparency = 0.05 },
			light = { color = { 255, 140, 70 }, brightness = 1, range = 16 },
			glow = { Lava = { 255, 110, 30 } },
			effects = {
				{ kind = "beam", from = "Fx_DripA", to = "Fx_Pool", texture = "rbxassetid://139671283074387", width = 0.6, speed = 0.8, color = { 255, 120, 30 } },
				{ kind = "beam", from = "Fx_DripB", to = "Fx_Pool", texture = "rbxassetid://139671283074387", width = 0.6, speed = 0.8, color = { 255, 120, 30 } },
				{ kind = "emitter", at = "Fx_Pool", texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 20, lifetime = { 1.2, 1.8 }, speed = { 3, 5 }, size = { 0.6, 0 }, rise = 3, spin = 90, colors = { { 255, 205, 90 }, { 255, 90, 40 } } },
			},
		},
	},
	-- MAX_EFFECTS: beams and emitters per portal, the vortex included (one light on top, apart from the area's own cap);
	-- SPIN_RANGE: studs from the camera the vortex turns within; LABEL_GAP: the name floats this far over the model;
	-- VORTEX_TEXTURE: assets/ui/fx/portal-vortex.png (Figma, white with alpha so the beam's colour tints it);
	-- VORTEX_LIGHT: the vortex beam's LightEmission (part glow: readable against bright daylight scenery)
	PORTAL_FX = { MAX_EFFECTS = 4, SPIN_RANGE = 150, LABEL_GAP = 3, VORTEX_TEXTURE = "rbxassetid://81210648824476", VORTEX_LIGHT = 0.25 },
	PORTAL_GLOW = { BRIGHTNESS = 2, RANGE = 18 },
	PORTAL_PANEL_TRANSPARENCY = 0.65, -- the frame's see-through glow panels, so the particles show through
	PORTAL_RING_CENTRE = 5, -- height of the ring centre above the ground (WildService and ArenaService rings)
	PORTAL_LABEL_DISTANCE = 40, -- shown only this close, so far labels don't pile up

	-- The checkout counter (front = customer side), built in code to match the shop shell (PlotService): a white
	-- body on a charcoal plinth, a dark stone top overhanging the front, an LED strip in the shop's accent colour
	-- under it, and pendant lights hanging over it. The POS terminal takes the left end, full depth; scan items
	-- lie along the front edge to its right; the decor sits in a strip along the back. Props are fitted into
	-- these boxes; x = offset from the counter centre. Studs; colours as { r, g, b }.
	COUNTER = {
		PROP_DEPTH = 0.6, -- the back strip (decor)
		REGISTER = { x = -1.8, width = 2.4, height = 2.2, depth = 2 }, -- the POS terminal's box
		DECOR = { x = 2.4, width = 0.8, height = 1.2 },
		ITEM_GAP = 0.15, -- between the terminal and the first scan item
		STAFF_BEHIND = 1.6, -- the cashier (owner or pet) stands this far behind the counter
		-- A low step behind the counter the cashier stands on, so a small pet still shows over the counter
		STEP = { width = 5, depth = 2.6, height = 1 },
		TOP = { 58, 62, 72 }, -- dark quartz
		TOP_THICKNESS = 0.2,
		TOP_OVERHANG = 0.3, -- past the body's front, over the customers' side
		PLINTH_HEIGHT = 0.3, -- the charcoal kick along the foot
		LED_HEIGHT = 0.12,
		-- Pendant lights over the counter: a thin cord from the ceiling to a black cone shade with a warm bulb.
		-- BOTTOM is the shade's bottom above the floor; SPREAD the distance between the two.
		PENDANT = {
			COUNT = 2,
			SPREAD = 3.2,
			BOTTOM = 7.5,
			SHADE_WIDTH = 1.3,
			SHADE_HEIGHT = 0.9,
			CORD = 0.06,
			BULB = { 255, 228, 180 },
			BRIGHTNESS = 0.7,
			RANGE = 12,
		},
	},

	-- Stock boxes on Products shelves (ShelfStock): levels match the Store Shelf's plates
	SHELF_STOCK = {
		LEVELS = { 0.1, 0.37, 0.62 },
		PER_LEVEL = 4,
		BOX_HEIGHT = 1.25,
		WIDTH_FILL = 0.76,
		DEPTH_FILL = 0.66,
		-- Pack products: each box's place holds an open display box (Util/PackModels) showing up to PACKS_SHOWN packs,
		-- emptying as the shelf sells (ShelfStock.boxFill). The box sizes above let it stand at MIN_SCALE or more of its
		-- full size (TRAY: the model's width, height with the lid back, depth) on every pack rack (the user's "Bigger").
		DISPLAY = { PACKS_SHOWN = 6, TRAY = { 0.79, 1.31, 1.38 }, MIN_SCALE = 0.95 },
		-- Card sleeves (Products stockLook "Sleeves"): retail packets in each box's place, leaning back: a white
		-- backing card with a header tab and hang hole, a clear window showing the sleeves, a strip in the product's
		-- colour. Each stock slot gets the next sleeve colour, so a shelf reads as an assortment.
		-- Deck boxes (Products stockLook "Deck"): the 3D deck box (Util/PackModels) fitted to WIDTH x HEIGHT x DEPTH,
		-- PER_STACK front to back, leaning back a little
		DECKS = { PER_STACK = 2, WIDTH = 0.55, HEIGHT = 0.8, DEPTH = 0.4, LEAN = 4 },
		-- Booster boxes (Products stockLook "Booster"): sealed booster boxes printed like the delivery case
		-- (Util/BrandBox), PER_STACK stacked in each place
		BOOSTERS = { PER_STACK = 2, WIDTH = 0.74, HEIGHT = 0.55, DEPTH = 0.95, PIXELS_PER_STUD = 300 },
		SLEEVES = {
			PER_STACK = 2,
			WIDTH = 0.62,
			HEIGHT = 0.74,
			TAB = 0.14,
			THICKNESS = 0.1,
			LEAN = 8,
			CARD = { 242, 242, 246 },
			WINDOW_TRANSPARENCY = 0.6,
			COLORS = { { 220, 60, 70 }, { 60, 120, 230 }, { 40, 170, 110 }, { 150, 90, 210 }, { 32, 34, 40 }, { 240, 170, 40 } },
		},
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

	-- The Glass Showcase / Collector Case (Util/CaseLook, code-built; UI project 3): a dark base with the bed on top,
	-- corner posts and top rails, tall glass sides and lid, and a light strip along the top front edge. Part names
	-- Support, Carpet, Frame, Glass, Strip (Shelves propColors recolour them). The bed sits at CaseLayout.UPRIGHT
	-- bedHeight. Studs; colours { r, g, b }.
	CASE_LOOK = {
		SUPPORT = { 40, 44, 58 }, -- charcoal base
		CARPET = { 70, 40, 110 }, -- violet bed
		FRAME = { 205, 210, 220 }, -- chrome posts and rails
		GLASS = { 210, 235, 255 },
		GLASS_TRANSPARENCY = 0.85,
		GLASS_REFLECTANCE = 0.15,
		STRIP = { 70, 230, 255 }, -- cyan light strip
		POST = 0.12, -- corner post and rail thickness
		BED = 0.06, -- bed thickness
		STRIP_HEIGHT = 0.1,
	},

	-- The Card Condenser (Props, code-built), restyled to match the Grading Station's scan pod (2026-10-30): a dark
	-- plinth with a violet rim, a white body with a light band, a card slot and a CONDENSER strip; a see-through
	-- chamber with a glowing floor where a crystal floats ringed by three cards, with two more rings of small cards
	-- circling the other way below it and above it; a white cap with a violet ring. The rings are Rotors that
	-- CondenserFxController spins and bobs on each client (each ring its own speed and direction). No lights.
	-- Studs; colours { r, g, b }.
	CONDENSER_LOOK = {
		BASE_RADIUS = 2.6,
		PLINTH_HEIGHT = 0.5,
		BASE_HEIGHT = 1.6, -- plinth and body together
		BODY_RADIUS = 2.25,
		CHAMBER_RADIUS = 1.9,
		CHAMBER_HEIGHT = 3.6,
		CAP_HEIGHT = 0.5,
		CORE_RADIUS = 1.05, -- the floating cards' circle round the crystal
		RING_RADIUS = 1.45, -- the outer card rings' circle
		RING_RISE = 1.05, -- each outer ring this far below / above the crystal
		RING_CARD = { 0.36, 0.5 }, -- an outer ring card: width, height
		RING_CARDS = 5, -- cards in each outer ring
		RING_SPIN = -0.7, -- the outer rings turn this fast against the crystal's (1 = the same)
		SHELL = { 236, 240, 247 }, -- glossy white
		DARK = { 28, 32, 46 },
		GLOW = { 170, 110, 255 }, -- violet
		GLASS = { 225, 215, 255 },
		GLASS_TRANSPARENCY = 0.8, -- see-through plastic, not Glass (Glass hides what's behind it)
		FLOOR_TRANSPARENCY = 0.6, -- the chamber's glowing floor, softened (0.35 drowned the cards in violet)
		CARD = { 255, 214, 110 },
		SCREEN_TEXT = "✨ CONDENSER",
		SPIN_SPEED = 40, -- degrees a second (every Rotor, the Grading Station's too)
		BOB = 0.15, -- studs up and down
		BOB_SECONDS = 2.4,
		FX_DISTANCE = 80, -- only spun this close to the camera
	},

	-- The Grading Station (Props, code-built): a futuristic scan pod (the user's pick, 2026-10-30, then made bigger).
	-- A dark plinth with a glowing rim, a round white body with a light band, a slot and a GRADING strip at the front;
	-- on top an emitter under a see-through column where a gold card floats in a beam of light, two rings of small
	-- cards circle it the other way below and above it, and a cap with the grade hologram above it. The card, the
	-- hologram and the rings are Rotors (CondenserFxController spins and bobs them). No lights. Studs; colours
	-- { r, g, b }.
	GRADING_LOOK = {
		PLINTH_RADIUS = 2.85,
		PLINTH_HEIGHT = 0.7,
		BODY_RADIUS = 2.4,
		BODY_HEIGHT = 2.3,
		EMITTER_RADIUS = 1.1,
		COLUMN_RADIUS = 1.35,
		COLUMN_HEIGHT = 3.5,
		BEAM_RADIUS = 0.42,
		CAP_RADIUS = 1.5,
		CAP_HEIGHT = 0.3,
		CARD_SIZE = { 0.75, 1.05 }, -- the floating card: width, height
		ORBIT_RADIUS = 0.95, -- the small cards' circle round the beam
		ORBIT_RISE = 1.0, -- each ring this far below / above the middle card
		ORBIT_CARD = { 0.34, 0.48 },
		ORBIT_CARDS = 4, -- cards in each ring
		ORBIT_SPIN = -0.8, -- the rings turn this fast against the middle card (1 = the same)
		HOLO_SIZE = 2, -- the grade hologram over the cap (a ring with the letter), studs across
		SHELL = { 236, 240, 247 }, -- glossy white
		DARK = { 28, 32, 46 }, -- plinth, emitter, slot and strip
		GLOW = { 70, 230, 255 }, -- cyan light
		CARD = { 255, 205, 90 },
		GLASS = { 200, 230, 255 },
		GLASS_TRANSPARENCY = 0.78, -- see-through plastic, not Glass (Glass hides what's behind it)
		BEAM_TRANSPARENCY = 0.62,
		SCREEN_TEXT = "GRADING",
		HOLO_TEXT = "S", -- the top grade
	},

	-- A boss trophy (Props, code-built): a dark stone plinth with a gold band and a gem in the boss's element colour
	-- (Config/Shelves propColors Gem), a gold cup with handles on top. No lights. Studs; colours { r, g, b }.
	TROPHY_LOOK = {
		PLINTH_WIDTH = 2.6,
		PLINTH_HEIGHT = 2.2,
		STONE = { 52, 54, 64 },
		GOLD = { 232, 186, 70 },
		GEM = { 255, 255, 255 }, -- recoloured per boss
	},

	-- Code-built product shelves (Util/ShelfLayout places the parts, Util/ShelfLooks draws them): charcoal posts and
	-- base, light grey plates with dark price rails, an oak slat back (a pegboard on the Accessory Hook) and a
	-- charcoal header sign. No lights of their own. Studs; colours as { r, g, b }.
	SHELF_LOOK = {
		POST = 0.2,
		PLATE = 0.1,
		RAIL = 0.22,
		BACK = 0.15,
		BASE = 0.35,
		HEADER = 0.7,
		HOOK = 0.6, -- how far a pegboard hook reaches out
		FRAME = { 38, 41, 48 },
		PLATE_COLOR = { 214, 217, 222 },
		RAIL_COLOR = { 70, 74, 84 },
		BACK_COLOR = { 196, 160, 118 }, -- light oak, like the floor
		SLAT_GAP = { 160, 126, 90 },
		PEGBOARD = { 92, 97, 108 },
		CHROME = { 190, 195, 202 },
		HEADER_TEXT = { 255, 255, 255 },
		-- Words on the header sign, per prop slot
		HEADERS = { Shelf = "TRADING CARDS", WallShelf = "TRADING CARDS", DisplayRack = "TRADING CARDS", HookRack = "ACCESSORIES" },
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
		PLANTER_OFFSET = 2.2, -- a planter each side of the doorway, this far past the door's edge
		PLANTER_SIZE = 1.8,
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
		TRAIL_LINE_TOP = 0.05, -- off the street, the line lies just above the trail's ground (terrain tops out at y 0)
		GLOW_TRANSPARENCY = 0.15,
	},

	-- The town's lighting is the day cycle now (Config/DayCycle; its afternoon is the old look)
}
