--!strict
-- Pack opening presentation (client only). Timings in seconds, sizes in fractions of the screen's height.
-- See DESIGN.md section 5.7. Sound IDs are empty until you pick some: paste e.g. "rbxassetid://123" to enable.
return {
	TEAR_SECONDS = 0.45, -- the top flying off and the pack sliding away
	AUTO_TEAR_SECONDS = 0.35, -- the tear line running across by itself after a tap
	FLIP_SECONDS = 0.18, -- each half of the flip
	FLASH_SECONDS = 0.6, -- the white flash on big pulls (CardReveal flash = true)
	FOIL_SHIMMER_SECONDS = 1.6, -- one sweep of the foil shimmer
	RISE_SECONDS = 0.45, -- the cards rising out of the pack
	OUT_SECONDS = 0.25, -- a revealed card sliding off to the left
	SUMMARY_STAGGER = 0.06, -- between each card popping into the summary row

	-- The light stage behind everything
	STAGE = {
		-- Midnight & Gold, like the windows: deep navy at the top, near-black at the foot, a soft glow behind the pack
		TOP = Color3.fromRGB(30, 36, 56),
		BOTTOM = Color3.fromRGB(10, 12, 20),
		GLOW_TRANSPARENCY = 0.78, -- the soft glow in the middle
		DIM = 0.55, -- how dark the stage gets at a tease's full dim (CardReveal dim = 1)
	},
	-- The premium backdrop (Util/PackStage): slow light rays behind the pack in its colour, bokeh sparkles drifting
	-- up, a glowing pedestal under the pack and a soft vignette. Sizes of the screen's height; speeds in pixels a second.
	AMBIENT = {
		RAY_COUNT = 16,
		RAY_RADIUS = 0.95,
		RAY_WIDTH = 0.16,
		RAY_TRANSPARENCY = 0.55, -- at the centre; they fade out to nothing
		RAY_TURN_SECONDS = 60,
		TINT_SOFTEN = 0.55, -- how much the pack's colour is mixed with white for the rays and pedestal
		BOKEH_COUNT = 24,
		BOKEH_SIZE = { 4, 16 }, -- pixels
		BOKEH_SPEED = { 14, 40 },
		BOKEH_TRANSPARENCY = { 0.45, 0.85 },
		PEDESTAL_WIDTH = 0.75,
		PEDESTAL_HEIGHT = 0.16,
		PEDESTAL_GAP = 0.01, -- under the pack's foot
		PEDESTAL_TRANSPARENCY = 0.25,
		PEDESTAL_PULSE_SECONDS = 1.8,
		VIGNETTE_COLOR = Color3.fromRGB(0, 0, 0),
		VIGNETTE_SIZE = 0.28,
		VIGNETTE_TRANSPARENCY = 0.7, -- at the very edge
	},
	-- Pixels: the top row (hint pill, Odds) sits below Roblox's top bar (36 on phones); the bottom pill this far up
	TOP = 44,
	EDGE = 12,
	PILL_HEIGHT = 46,
	PACK = {
		Y = 0.6, -- centre height
		HEIGHT = 0.6,
		ASPECT = 0.65, -- width / height
		CAP = 0.1, -- the strip above the tear line, of the pack's height
		TEETH = 16, -- crimp teeth across the pack
		BOB_PIXELS = 8, -- the pack floats up and down this much
		BOB_SECONDS = 1.6,
		TEAR_DONE = 0.8, -- dragged across this much of the pack's width = torn open
		TAP_PIXELS = 12, -- a press that moves less than this is a tap (the pack tears by itself)
		SWAY = 2.5, -- degrees it rocks either way while it floats
		SWAY_SECONDS = 2.2,
		SHINE_SECONDS = 0.9, -- a foil shine sweeping across it
		SHINE_EVERY = 1.8, -- seconds between sweeps
		ENTER_SECONDS = 0.5, -- popping in when the screen opens
	},
	-- A deck box (Config/Packs kind "Deck"): boxier than a pack, a deeper lid, a darker side face for depth
	DECK = { ASPECT = 0.8, LID = 0.17, SIDE = 0.07 },
	CARD_Y = 0.53, -- the card being revealed: centre height
	CARD_HEIGHT = 0.56,
	BANNER = { SCALE = 0.2, MIN = 36, MAX = 64 }, -- the RARE! banner's height: of the card's height, in pixels
	SUMMARY_Y = 0.5, -- the results row: centre height (below the pills, with room for the NEW ribbons)
	SUMMARY_HEIGHT = 0.42, -- each card in the results row

	-- Border thickness by rarity, so better pulls feel heavier
	STROKE_THICKNESS = { Common = 2, Rare = 3, ["Very Rare"] = 3.5, Epic = 4, Legendary = 6 },

	TEAR_SOUND_ID = "",
	FLIP_SOUND_ID = "",
	HIT_SOUND_IDS = { Rare = "", ["Very Rare"] = "", Epic = "", Legendary = "" },

	-- ===== The 3D opening (UI project 3, spec section 4; the approved preview's timings). Studs and seconds. =====
	-- A client-only stage far above the world, a Scriptable camera looking along +Z at its middle
	STAGE_POSITION = Vector3.new(0, 3600, 0), -- apart from the card view's (2500) and the binder's (3200)
	FIELD_OF_VIEW = 40,
	CAMERA_DISTANCE = 8, -- the camera's distance from the stage's middle
	LETTERBOX = 0.11, -- each cinematic bar, share of the screen height
	BACKDROP = {
		MIDDLE = Color3.fromRGB(75, 47, 176), -- a violet glow behind the pack
		EDGE = Color3.fromRGB(13, 8, 38), -- near-black at the edges
		BEHIND = 7, -- how far behind the stage's middle
		SIZE = 70,
	},
	LIGHTS = {
		KEY = { COLOR = Color3.fromRGB(255, 240, 220), BRIGHTNESS = 2.2, RANGE = 16, AT = Vector3.new(-3, 4, -6) },
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
		SHOWN_SCALE = 1.18, -- a Common lands this much bigger
		TEASED_SCALE = 1.28, -- a teased card lands this much bigger
		RISE = 0.5, -- a teased card rises this much while it glows
		SHINE_SECONDS = 0.42,
		BURST_SIZE = 4.5,
		BIG_BURST_SIZE = 6.2, -- Legendary and Frontier
		SPOTLIGHT_LOCK = 0.6, -- taps are ignored this long after a spotlight flip (CardReveal spotlight)
		BANNER_SECONDS = 0.38,
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
	-- Sounds (spec 5b): Creator Store ids, filled in by UI project 3 Task 11; "" plays nothing
	SOUNDS = {
		crinkle = "", snap = "", stack = "", flip = "", tease = "",
		hitRare = "", hitEpic = "", hitLegendary = "", shimmer = "", land = "", chime = "",
	},
	VOLUMES = {
		crinkle = 0.5, snap = 0.6, stack = 0.35, flip = 0.45, tease = 0.5,
		hitRare = 0.55, hitEpic = 0.65, hitLegendary = 0.75, shimmer = 0.3, land = 0.35, chime = 0.5,
	},
}
