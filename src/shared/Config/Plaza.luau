--!strict
-- The Card Festival Square plaza (the user's pick C, 2026-10-30), built at server start by Server/Util/PlazaBuild:
-- a white gazebo with a turquoise dome over the healing fountain, a fan of five giant cards (real card art, gold
-- rims), three market stalls with striped awnings, six cafe tables, string lights from the gazebo to eight lamp
-- posts, four potted trees. Places are polar round the spring: angle in degrees (0 = +X, 90 = +Z: x = cos, z = sin),
-- r in studs. The lanes (to the two shop doors and along the street) stay clear (Lune-tested, Util/PlazaLayout).
-- Plain data, read by Lune tests. Colours { r, g, b }.
return {
	FOUNTAIN_HEIGHT = 11, -- the healing fountain's height (Town.SLOTS.HealingSpring), so the gem clears the dome
	FOUNTAIN_RADIUS = 5.5, -- its basin at that height
	GEM_RISE = 4.9, -- the floating gem's top above the fountain at its highest (2.2 over it, bobbing 0.5, half-diagonal 1.9)
	LANE_HALF = 4.5, -- studs kept clear either side of each lane's middle
	BENCH_REACH = 2, -- a bench's footprint (TownLayout places them at Town.LAYOUT.BENCH_RADIUS)
	SPAWN = { x = -17, z = 0 }, -- the place's spawn pad: where new players appear

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
		white = { 246, 244, 238 },
		trim = { 222, 214, 196 },
		roof = { 64, 196, 200 },
		roofDark = { 40, 160, 168 },
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
	TABLE = {
		top = { radius = 1.4, height = 2.6 },
		chairs = 3,
		chairRadius = 2.1,
		white = { 248, 248, 246 },
		wood = { 168, 116, 63 },
		metal = { 52, 54, 62 },
		reach = 2.7,
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

	TREES = {
		{ angle = 45, r = 24.4, model = "TreeC", height = 9 },
		{ angle = 135, r = 24.4, model = "TreeC", height = 9 },
		{ angle = 238, r = 24.4, model = "TreeD", height = 9.5 }, -- off the diagonal: the card fan stands there
		{ angle = 315, r = 24.4, model = "TreeD", height = 9.5 },
	},
	PLANTER = { radius = 1.6, height = 1.6, color = { 92, 96, 108 } },
}
