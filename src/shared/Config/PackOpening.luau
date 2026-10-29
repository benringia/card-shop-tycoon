--!strict
-- The pack opening (client only; UI project 3 spec section 4): the 3D stage, its cinematics and the screen over it.
-- Studs and seconds unless noted. See DESIGN.md section 5.7.
return {
	FOIL_SHIMMER_SECONDS = 1.6, -- one sweep of a foil card face's shimmer (Util/CardFace)
	-- Pixels: the screen's top row (hint, box count, Odds, the results pills) sits below Roblox's top bar (36 on phones)
	TOP = 44,
	EDGE = 12,
	PILL_HEIGHT = 46,
	-- Border thickness by rarity on card faces (Util/CardFace), so better pulls feel heavier
	STROKE_THICKNESS = { Common = 2, Rare = 3, ["Very Rare"] = 3.5, Epic = 4, Legendary = 6 },

	-- ===== The 3D opening (UI project 3, spec section 4; the approved preview's timings). Studs and seconds. =====
	-- A client-only stage far above the world, a Scriptable camera looking along +Z at its middle
	STAGE_POSITION = Vector3.new(0, 3600, 0), -- apart from the card view's (2500) and the binder's (3200)
	FIELD_OF_VIEW = 40,
	CAMERA_DISTANCE = 8, -- the camera's distance from the stage's middle
	LETTERBOX = 0.11, -- each cinematic bar, share of the screen height
	BACKDROP = {
		MIDDLE = Color3.fromRGB(75, 47, 176), -- a violet glow behind the pack
		EDGE = Color3.fromRGB(13, 8, 38), -- near-black at the edges
		BEHIND = 45, -- how far behind the stage's middle (past the row's far-away cards)
		SIZE = 160,
		GLOW = 0.35, -- the glow's size, share of the backdrop
	},
	LIGHTS = {
		-- Only the pack and deck box take these (card faces ignore light); too bright and the bloom glows round the pack
		KEY = { COLOR = Color3.fromRGB(255, 240, 220), BRIGHTNESS = 1.4, RANGE = 16, AT = Vector3.new(-3, 4, -6) },
		RIM = { COLOR = Color3.fromRGB(140, 190, 255), BRIGHTNESS = 1.6, RANGE = 14, AT = Vector3.new(4, 2, 3) },
	},
	POST = {
		BLOOM_INTENSITY = 0.5,
		BLOOM_SIZE = 24,
		BLOOM_THRESHOLD = 1.6,
		DIM_BRIGHTNESS = -0.18, -- the stage dims for a big pull (ColorCorrection at full dim)
		DIM_CONTRAST = 0.12,
		FOCUS_BLUR = 6, -- depth of field far blur during the push-in
	},
	SHAKE_SECONDS_STEP = 1 / 30, -- a camera shake picks a new offset this often
	-- The pack on the stage (Util/PackModels High)
	PACK_STAGE = {
		HEIGHT = 2.6, -- the pack's height on the stage
		SWAY = 1.5, -- degrees it rocks either way while it waits
		BOB = 0.12,
		BOB_SECONDS = 2.4,
		SHEEN_EVERY = 2.4, -- a light sweep over the foil this often while it waits
		SHEEN_BRIGHTNESS = 1.4, -- the sweeping light at its peak (4 washed the art out white under the bloom)
		SWIPE_PIXELS = 60, -- a drag across the pack's top this long tears it (a tap tears it too)
	},
	-- spec 4.2: bars in, push in on the tear, the strip parts while light leaks, then the snap
	TEAR = {
		PUSH_SCALE = 1.28,
		PUSH_SECONDS = 0.52,
		PART_SECONDS = 0.7,
		SNAP_SECONDS = 0.52,
		FLASH = 0.8,
		FLASH_SECONDS = 0.38,
		SHAKE = 0.12,
		SHAKE_SECONDS = 0.34,
		EASE_SECONDS = 0.46,
		SPILL = 6, -- shards spilling while the strip parts
		SHARDS = 26, -- shards on the snap
		BURST_SIZE = 6, -- the rip burst's size
		BURST_SECONDS = 0.7, -- the part of the rip burst that shows (its sheet runs on, empty, past frame 40 of 64)
	},
	-- spec 4.3: the cards stack up one at a time
	STACK = {
		PACK_DOWN = 1.3, -- the pack moves down this far first
		PACK_DOWN_SECONDS = 0.3,
		CARD_SECONDS = 0.19,
		TILT = 3, -- degrees either way each card lands at
		STEP = 0.02, -- each card sits this much in front of the one below
		PACK_AWAY_SECONDS = 0.28,
	},
	CARD_STAGE = { HEIGHT = 2.2, THICKNESS = 0.03, PIXELS_PER_STUD = 200 }, -- a card on the stage (width = height / 1.4)
	-- spec 4.4: each card's flip
	FLIP = {
		LIFT = 0.25,
		LIFT_SECONDS = 0.08,
		COMMON_SECONDS = 0.23,
		TEASE_SECONDS = 0.38,
		SHOWN_SCALE = 1.12, -- a Common lands this much bigger
		TEASED_SCALE = 1.24, -- a teased card lands this much bigger
		LANDING_UP = 0.35, -- a shown card sits this much above the middle (the banner goes under it)
		RISE = 0.5, -- a teased card rises this much while it glows
		SHINE_SECONDS = 0.42,
		BURST_SIZE = 4.5,
		BIG_BURST_SIZE = 6.2, -- Legendary and Frontier
		SPOTLIGHT_LOCK = 0.6, -- taps are ignored this long after a spotlight flip (CardReveal spotlight)
		BANNER_SECONDS = 0.38,
		BANNER_Y = 0.7, -- the RARE! banner's middle, share of the screen height (just under the shown card)
		BANNER_HEIGHT = 0.085, -- share of the screen height
		BANNER_ASPECT = 4.2, -- width over height
		GLOW_TRANSPARENCY = 0.88, -- the glow behind a teased (face-down) card
		GLOW_FADE_SECONDS = 0.25, -- it fades once the card is face up
		-- The rays and aura stand far behind the shown card (behind the row's far cards too), sized to look right there
		BACK_DEPTH = 32, -- studs from the camera
		RAYS_SIZE = 56,
		AURA_SIZE = 30,
	},
	-- spec 4.5: a shown Rare-or-better card floats, tilts and sparkles (rates in Config/CardReveal)
	ALIVE = {
		BOB = 0.12,
		SECONDS = 3.6, -- one float cycle
		BIG_SECONDS = 3.2, -- Legendary and Frontier
		HOLO_SECONDS = 2.4, -- one holo sweep
		BIG_HOLO_SECONDS = 1.8,
		AURA_SECONDS = 1.6, -- one breath of the aura
		RAYS_TURN_SECONDS = 26,
		BANNER_PULSE_SECONDS = 0.9,
	},
	STOW = { SECONDS = 0.22 }, -- a shown card zipping into the row
	-- spec 4.6: the row's cards fly to the lineup, snappy
	RESULTS = {
		FLIGHT_SECONDS = 0.22,
		STAGGER = 0.085, -- the next card leaves this long after the last
		ARC = 0.6, -- studs the flight rises in the middle
		SPIN = 8, -- degrees of spin on the way
		SHINE_SECONDS = 0.28,
		SPARKLES = { Common = 3, Rare = 6, ["Very Rare"] = 6, Epic = 8, Legendary = 10 }, -- glints round a landing card
		FLOAT = 0.1,
		FLOAT_SECONDS = 2.2,
		TWINKLE_EVERY = 0.42,
		PILL_SECONDS = 0.22,
		CONTINUE_DELAY = 0.12,
	},
	-- Sounds (spec 5b): free Creator Store sounds; "" plays nothing. Pro Sound Effects and APM are Roblox's licensed
	-- libraries, Daily Sounds made theirs from scratch; card_flip is f4ngy's on Freesound (CC BY, credited in DESIGN.md).
	SOUNDS = {
		crinkle = "rbxassetid://9113248978", -- Bag Grab Quick 6 (Pro Sound Effects): crinkling while the strip parts
		snap = "rbxassetid://9125724621", -- Paper Tear Fast Harsh Rip (Pro Sound Effects): the strip tears off
		stack = "rbxassetid://105273485659548", -- cardswipe: each card landing on the pile
		flip = "rbxassetid://3456145589", -- card_flip (f4ngy, Freesound)
		tease = "rbxassetid://9120747429", -- Whooshy Magic Sucks, a synthy rise (Pro Sound Effects); cut at the hit
		hitRare = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits 1 (Pro Sound Effects)
		hitEpic = "rbxassetid://94978851787238", -- Deep Impact Boom (Daily Sounds)
		hitLegendary = "rbxassetid://1844539433", -- Orchestral Hits (APM)
		shimmer = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer (Pro Sound Effects): a shown card comes alive
		land = "rbxassetid://106984966606682", -- Cartoon Pop (Daily Sounds): each lineup card landing
		chime = "rbxassetid://9116395089", -- Magic Glows Soft Clusters Of Chiming Hits 4 (Pro Sound Effects): lineup done
	},
	VOLUMES = {
		crinkle = 0.5, snap = 0.6, stack = 0.35, flip = 0.45, tease = 0.5,
		hitRare = 0.55, hitEpic = 0.65, hitLegendary = 0.75, shimmer = 0.3, land = 0.35, chime = 0.5,
	},
	TEASE_FADE_SECONDS = 0.12, -- the tease's rise fades out this fast when the hit lands
}
