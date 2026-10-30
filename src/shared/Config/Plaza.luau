--!strict
-- The Card Festival Square plaza (the user's pick C, 2026-10-30), built at server start by Server/Util/PlazaBuild:
-- a cream gazebo with a teal tiled dome over the healing fountain (the Elemental Bloom lotus, round 2's pick B, built
-- by Server/Util/BloomFountain), a fan of five giant cards (real card art, gold rims), three market stalls with striped
-- awnings, six cafe tables with townsfolk sitting at three, string lights from the gazebo to eight lamp posts, four
-- planters of bushes and flowers along the edge holding the lamps and the trees. Places are polar round the spring:
-- angle in degrees (0 = +X, 90 = +Z: x = cos, z = sin), r in studs. The lanes (to the two shop doors and along the
-- street) stay clear (Lune-tested, Util/PlazaLayout). Plain data, read by Lune tests. Colours { r, g, b }.
return {
	FOUNTAIN_HEIGHT = 11, -- the healing fountain's height, floating card included (the gazebo is built round it)
	FOUNTAIN_RADIUS = 5.5, -- its base step
	LANE_HALF = 4.5, -- studs kept clear either side of each lane's middle
	BENCH_REACH = 2, -- a bench's footprint (TownLayout places them at Town.LAYOUT.BENCH_RADIUS)
	SPAWN = { x = -17, z = 0 }, -- the place's spawn pad: where new players appear

	-- The Elemental Bloom: a white stone lotus on a round step. Five outer petals, one per card element, each with a
	-- glowing gem at its tip spraying an arc of its colour into the pool in the flower's heart; five smaller petals
	-- between them rise from the water; a golden card-shaped crystal floats and turns over a stem in the middle.
	-- Petals lean out `lean` degrees from upright from a ring `r` studs out at height `y`; studs from the ground.
	FOUNTAIN = {
		step = { radius = 5.5, height = 0.6 },
		bowl = { radius = 3.6, height = 1.8 }, -- on the step, under the petals
		pool = { radius = 2.6, y = 2.45 }, -- the water's top
		petal = { r = 2.2, y = 1.6, length = 4, width = 3.4, thickness = 1.4, lean = 40 },
		inner = { r = 1.5, y = 1.9, length = 3, width = 1.6, thickness = 0.5, lean = 26 },
		tint = 0.42, -- how far each outer petal's stone leans toward its element's colour
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
	},

	GAZEBO = {
		radius = 9.5, -- the columns' circle
		posts = 8,
		postSize = 1.1,
		postHeight = 16, -- above the platform
		platform = { radius = 11.5, height = 0.5 },
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
		{ angle = 315, r = 19.5, color = { 255, 143, 179 } },
		{ angle = 45, r = 19.5, color = { 110, 190, 255 } },
		{ angle = 135, r = 19.5, color = { 130, 220, 130 } },
	},
	STALL = {
		width = 5.4,
		depth = 2.2,
		counter = 2.8,
		postHeight = 6.8,
		stripes = 6,
		slope = 20, -- degrees the awning tips toward the front
		wood = { 168, 116, 63 },
		stripe = { 255, 250, 244 },
		reach = 3.1,
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
