--!strict
-- The Card Festival Square plaza (the user's pick C, 2026-10-30), built at server start by Server/Util/PlazaBuild:
-- a cream gazebo with a teal tiled dome over the healing fountain (the Elemental Bloom lotus, round 2's pick B, built
-- by Server/Util/BloomFountain), a fan of five giant cards (real card art, gold rims), three festival carts with
-- striped canopies, six cafe tables with townsfolk sitting at three, string lights from the gazebo to eight lamp
-- posts, planters of bushes and flowers along the edge holding the lamps and the trees. Places are polar round the spring:
-- angle in degrees (0 = +X, 90 = +Z: x = cos, z = sin), r in studs. The lanes (to the two shop doors and along the
-- street) stay clear (Lune-tested, Util/PlazaLayout). Plain data, read by Lune tests. Colours { r, g, b }.
return {
	FOUNTAIN_HEIGHT = 12.6, -- the healing fountain's height, floating card at its highest included (the gazebo is built round it)
	FOUNTAIN_RADIUS = 7, -- its base step
	LANE_HALF = 4.5, -- studs kept clear either side of each lane's middle
	BENCH_REACH = 2, -- a bench's footprint (TownLayout places them at Town.LAYOUT.BENCH_RADIUS)
	SPAWN = { x = -17, z = 0 }, -- the place's spawn pad: where new players appear

	-- The Elemental Bloom: a lotus on a deep teal two-step base. Five outer petals, one per card element, each with a
	-- glowing gem at its tip spraying an arc of its colour into the pool in the flower's heart; magenta petals between
	-- them; a golden card-shaped crystal floats and turns over a gold cup in the middle. The model is built in Blender
	-- (tools/blender/build_bloom_fountain.py) and lives in ReplicatedStorage.PropModels as `model` (parts Body, Water,
	-- Crystal, Gem_<Element>), scaled so its base is FOUNTAIN_RADIUS round; `size` is its height then, card included.
	-- Until it's there a part-built stand-in is drawn from the numbers below: petals lean out `lean` degrees from
	-- upright from a ring `r` studs out at height `y`; studs from the ground.
	FOUNTAIN = {
		model = "BloomFountain",
		size = { height = 12.1 },
		step = { radius = 5.5, height = 0.6 },
		bowl = { radius = 3.6, height = 1.8 }, -- on the step, under the petals
		pool = { radius = 2.6, y = 2.45 }, -- the water's top
		petal = { r = 2.2, y = 1.6, length = 4, width = 3.4, thickness = 1.4, lean = 40 },
		inner = { r = 1.5, y = 1.9, length = 3, width = 1.6, thickness = 0.5, lean = 26 },
		tint = 0.75, -- how far each stand-in outer petal's stone leans toward its element's colour
		elements = {
			{ name = "Ember", color = { 255, 112, 72 } },
			{ name = "Tide", color = { 80, 170, 255 } },
			{ name = "Bloom", color = { 110, 220, 110 } },
			{ name = "Volt", color = { 255, 214, 70 } },
			{ name = "Shade", color = { 172, 112, 240 } },
		},
		gem = 0.8, -- each petal tip's crystal
		jet = { land = 0.9, rise = 2.4, drop = 1.4, width = 0.5, speed = 1.2, texture = "rbxassetid://139671283074387" },
		stem = { radius = 0.45, top = 5, cup = 0.95 },
		card = { width = 1.9, height = 2.6, thickness = 0.16, y = 7.6, bob = 0.5 },
		stone = { 222, 210, 198 }, -- warm, not white: white glares in the sun
		blush = { 236, 196, 206 }, -- the inner petals
		trim = { 176, 164, 148 },
		water = { 96, 224, 232 },
		gold = { 255, 204, 92 },
		-- The magic, on the server for everyone: sparkles off each gem in its colour, motes in every element's colour
		-- rising from the pool
		gemSparkles = { rate = 4, size = 0.35, lifetime = { 0.8, 1.4 } },
		motes = { rate = 14, speed = { 3, 5 }, lifetime = { 2.5, 3.5 }, size = 0.45, spread = 22 },
		-- and on each client (FountainFxController, near the camera, with the extras on): a slowly turning rune circle
		-- on the floor round the fountain, a column of light rising from the pool, one glowing orb per element circling
		-- the card with a trail; the column and the pool's light shift through the element colours
		fx = {
			range = 170, -- studs from the camera
			cycle = 5, -- seconds on each element's colour
			rune = { texture = "rbxassetid://131308578602059", radius = 8.8, lift = 0.06, spin = 6, transparency = 0.1 }, -- spin: degrees a second
			pillar = { height = 15.6, width = { 3.4, 1.2 }, transparency = { 0.5, 1 }, speed = 0.8 },
			orbs = { radius = 3.6, size = 0.6, speed = 40, bob = 0.6, rise = 0, trail = 0.7 }, -- rise: above the card's middle
		},
	},

	GAZEBO = {
		radius = 9.5, -- the columns' circle
		posts = 8,
		postSize = 1.1,
		postHeight = 16, -- above the platform
		platform = { radius = 11.5, height = 0.5 },
		inlay = { radius = 9.2, color = { 26, 74, 92 } }, -- dark stone set in the floor, so the fountain's glowing rune circle shows
		ring = 0.9, -- the beam round the column tops
		-- the dome: stepped discs, widest first (radius, height), then a lantern and a finial
		dome = { { 11, 1 }, { 9.8, 1.3 }, { 8.2, 1.3 }, { 6.2, 1.2 }, { 3.8, 1 } },
		lantern = 1.8,
		-- Matte, mid-toned colours: white plastic and a shiny roof glared in the sun and mirrored the sky
		stone = { 190, 164, 128 }, -- columns and the beam
		platformStone = { 204, 184, 152 },
		trim = { 150, 122, 92 },
		roof = { 40, 140, 146 },
		roofDark = { 24, 104, 112 },
		columnMaterial = "Plaster",
		roofMaterial = "RoofShingles",
		gold = { 242, 193, 78 },
		light = { color = { 255, 214, 160 }, brightness = 1.2, range = 16 },
		-- motes in the element colours rising off the finial, so the fountain's magic shows over the roof from the street
		beacon = { rate = 5, speed = { 4, 7 }, lifetime = { 3, 4.5 }, size = 0.6, spread = 15 },
	},

	FAN = {
		angle = 225,
		r = 19,
		face = { x = -10, z = 0 }, -- turned toward the plaza, with the spawn in front (and the street beyond)
		base = { height = 1.2, depth = 3, color = { 214, 206, 190 } }, -- the long stone plinth they stand on
		step = 3.4, -- studs between the cards' middles
		lean = 9, -- degrees each card leans out per step from the middle
		tilt = 6, -- degrees every card leans back
		depthStep = 0.5, -- each step out stands this much further back, so faces never fight
		cards = {
			{ card = "Cindercub", rarity = "Common", height = 5 },
			{ card = "Boltlynx", rarity = "Rare", height = 5.6 },
			{ card = "Solarion", rarity = "Legendary", height = 7 },
			{ card = "Thunderhorn", rarity = "Epic", height = 6 },
			{ card = "Tidecaller", rarity = "Very Rare", height = 5.4 },
		},
		gold = { 242, 193, 78 },
		back = { 70, 110, 245 },
		pixelsPerStud = 40,
		distance = 180, -- studs: the card faces draw this far (a landmark; only five screens)
	},

	STALLS = {
		{ angle = 315, r = 19.5, color = { 255, 120, 168 }, sign = "PACKS" },
		{ angle = 45, r = 19.5, color = { 80, 170, 255 }, sign = "CARDS" },
		{ angle = 135, r = 19.5, color = { 96, 200, 110 }, sign = "SNACKS" },
	},
	-- A festival cart (the user's pick A of three stall designs, 2026-10-30), its counter facing the gazebo: a wooden
	-- box with a slatted front in its colour and white, two big spoked wheels at one end, a handle with a prop leg at
	-- the other, turned posts holding a rounded striped canopy with a scalloped fringe and gold balls on its corners, a
	-- lantern hanging at one front corner, card packs and boxes on the counter, a chalkboard sign beside it. Studs.
	STALL = {
		body = { width = 5, depth = 2.4, bottom = 1.2, height = 1.6 },
		top = { overhang = 0.25, thickness = 0.25 },
		slats = 8,
		wheel = { radius = 1.25, tire = 0.28, thickness = 0.3, spokes = 6, segments = 12, x = 1.1 }, -- x: along the cart from its middle
		handle = { length = 1, height = 1.9, spread = 0.5 },
		post = { height = 3.3, radius = 0.16 },
		canopy = { rise = 1, segments = 7, overhang = 0.35, thickness = 0.14 },
		fringe = { count = 11, radius = 0.3 },
		lantern = { size = 0.5, drop = 0.9, color = { 255, 196, 110 }, brightness = 0.8, range = 9 },
		packs = { { 255, 92, 92 }, { 255, 196, 40 }, { 80, 170, 255 }, { 150, 90, 230 }, { 70, 200, 110 }, { 255, 140, 200 }, { 255, 150, 50 } },
		easel = { width = 1, height = 1.3, x = -2.2, z = -2 }, -- x, z: from the cart's middle (-z toward the gazebo)
		wood = { 168, 116, 63 },
		woodDark = { 110, 72, 40 },
		stripe = { 255, 250, 244 },
		gold = { 242, 193, 78 },
		slate = { 44, 52, 56 },
		reach = 3.6,
	},

	TABLES = { angles = { 24, 66, 114, 156, 204, 336 }, r = 18.4 },
	-- A round wooden cafe table with a cloth just under its top and a little vase, bistro chairs round it (a round
	-- seat on four thin dark legs, a round back on two posts), facing it
	TABLE = {
		top = { radius = 1.4, height = 2.6, thickness = 0.22 },
		cloth = { overhang = 0.14, drop = 0.4 },
		vase = { radius = 0.18, height = 0.5 },
		chairs = 3,
		chairRadius = 2.1,
		chairSize = 1.3,
		seat = { radius = 0.62, height = 1.55, thickness = 0.18 },
		back = { radius = 0.58, y = 2.75, lean = 8 },
		leg = 0.12,
		-- townsfolk sitting at every other table (the customers' look), sipping now and then (PlazaNpcController)
		sitters = {
			{ table = 1, chair = 1 },
			{ table = 3, chair = 2 },
			{ table = 5, chair = 3 },
		},
		wood = { 160, 108, 64 },
		clothColor = { 248, 244, 236 },
		metal = { 52, 54, 62 },
		flowers = { { 255, 128, 170 }, { 255, 214, 90 }, { 150, 190, 255 } },
		reach = 2.8,
	},
	SITTER = {
		rootHeight = 1.05, -- the sitting rig's root above the seat's top
		back = 0.1, -- studs toward the chair's back
		animation = "rbxassetid://2506281703", -- Roblox's default R15 sit
		sip = { every = { 6, 11 }, raise = 1.1, hold = 1.4, range = 90, shoulder = 70, elbow = 60 }, -- seconds, seconds, seconds, studs, degrees, degrees
		cup = { 255, 250, 240 },
	},

	LAMPS = { angles = { 22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5 }, r = 25, height = 9, reach = 0.6 },
	LIGHTS = {
		from = { r = 11, y = 16.5 }, -- the strings start at the gazebo's rim
		sag = 2.2,
		spacing = 1.7,
		bulb = 0.38,
		color = { 255, 214, 140 },
		wire = { 46, 40, 36 },
	},

	-- Low curved stone planters along the edge, one per quarter between the lanes (arcs in degrees), the lamps and
	-- trees standing in them; the card fan's quarter is split where the plinth's far end reaches the edge. Bushes and
	-- flowers every `step` studs along the middle, none within `clear` of a lamp or tree; `pattern` repeats.
	PLANTERS = {
		arcs = { { 14, 76 }, { 104, 166 }, { 194, 204 }, { 222, 256 }, { 284, 346 } },
		r = 25,
		width = 2,
		height = 0.9,
		piece = 4, -- degrees each stone piece of the curve covers
		step = 1.9,
		clear = 1.7,
		pattern = { "flower", "bush", "flower" },
		bushes = { "Bush", "BushA", "BushB" },
		flowers = { "FlowerPink", "FlowerYellow", "FlowerWhite", "FlowerBlue" },
		bushHeight = 2.2,
		flowerHeight = 1.1,
		stone = { 176, 160, 138 },
		soil = { 92, 140, 70 },
	},

	TREES = {
		{ angle = 45, r = 25, model = "TreeC", height = 9 },
		{ angle = 135, r = 25, model = "TreeC", height = 9 },
		{ angle = 238, r = 25, model = "TreeD", height = 9.5 }, -- off the diagonal: the card fan stands there
		{ angle = 315, r = 25, model = "TreeD", height = 9.5 },
	},
	TREE_REACH = 1, -- a tree's trunk, for the clearance tests (its leaves hang over the planter)
}
