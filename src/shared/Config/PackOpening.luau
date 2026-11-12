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
	-- While shown the stage moves right above the player (Config/Stages, Util/StageSpot); this box (its middle
	-- STAGE_BOX_OFFSET from the stage's middle) must be clear of the world there: the camera, the row of cards and the
	-- view out to the backdrop
	STAGE_BOX = Vector3.new(80, 50, 60),
	STAGE_BOX_OFFSET = Vector3.new(0, 0, 18),
	FIELD_OF_VIEW = 40,
	CAMERA_DISTANCE = 8, -- the camera's distance from the stage's middle
	LETTERBOX = 0.11, -- each cinematic bar, share of the screen height
	BACKDROP = {
		EDGE = Color3.fromRGB(13, 8, 38), -- near-black past the painting's sides (wide phone screens)
		BEHIND = 45, -- how far behind the stage's middle (past the row's far-away cards)
		SIZE = 160,
		-- Owner's pick A (2026-11-10, "connect every element to our core loop"): Pish and Chikin's card shop at night,
		-- the two of them peeking over the counter (assets/ui/opening, Figma-generated, uploaded; Pish repainted a little
		-- grumpy with his underbite, owner 2026-11-10)
		IMAGE = "rbxassetid://89947475330742",
		IMAGE_SIZE = Vector2.new(75, 42), -- studs: the view's height at BEHIND (about 39) and a little more
		IMAGE_TINT = Color3.fromRGB(185, 175, 200), -- a little darker, so the cards stand out
		FADE = 0.08, -- share of its width fading into EDGE at each side
		-- Darker behind the cards in the middle (the glow picture, tinted)
		SHADE = { COLOR = Color3.fromRGB(13, 8, 38), SIZE = 0.62, TRANSPARENCY = 0.45 },
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
		-- "Charged and ready to rip" (the user's pick for the waiting pack): it turns toward the pointer, crackles with
		-- energy over a soft glow, and a glowing dashed tear line with a gliding dot shows the swipe
		TILT_YAW = 22, -- degrees it turns toward a pointer at the screen's side
		TILT_PITCH = 12, -- degrees it tips toward a pointer at the top or bottom
		TILT_SPEED = 6, -- how fast it follows (per second)
		STRAIGHTEN_SECONDS = 0.2, -- it turns back square as the tear starts
		CHARGE = {
			COLOR = Color3.fromRGB(150, 205, 255), -- blue-white energy
			RATE = 7, -- sparks a second along each side (scaled by graphics level)
			SPARK_SIZE = 0.32,
			GLOW_SIZE = 6, -- studs, the glow behind the pack
			GLOW_TRANSPARENCY = 0.4, -- at its brightest
			GLOW_PULSE_SECONDS = 1.1,
		},
		GUIDE = {
			DASHES = 9,
			DASH = 0.1, -- studs long
			THICKNESS = 0.035,
			COLOR = Color3.fromRGB(255, 246, 225),
			IN_FRONT = 0.16, -- studs in front of the pack's middle (clear of the foil)
			DOT = 0.16, -- the gliding dot's size
			SWIPE_SECONDS = 1.3, -- the dot crosses this fast
			PAUSE_SECONDS = 0.6, -- then waits this long before the next pass
			PULSE_SECONDS = 1.2, -- the dashes breathe this often
		},
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
		PACK_DOWN = 2.4, -- the pack moves down this far first, its top just under the stack (1.3 left them overlapping)
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
		-- The lineup: its own sounds, not the boss victory's tiles and chime (owner 2026-11-10: "similar to the sound
		-- after killing a boss")
		land = "rbxassetid://105273485659548", -- cardswipe (as the pile's stack): each lineup card landing
		chime = "rbxassetid://9126073001", -- Synth Sparkle Tone High Pitch Bell Tone Ding 4 (Pro Sound Effects): lineup done
		-- The Forge's reveal on the same stage (Config/WeaponLooks REVEAL.forge), all Pro Sound Effects but the boom
		forgeFire = "rbxassetid://9114446277", -- Fire Whoosh 6: the forge flares up as the build-up starts
		forgeStrike = "rbxassetid://9125361455", -- Anvil Hits Ringing Metal Clinks Blacksmith 1: each hammer strike
		forgeClank = "rbxassetid://9113132724", -- Anvil Hit Sharp Metallic Clanks Bouncing 4: the hit
		forgeBurst = "rbxassetid://9117985933", -- Pyro Fire Ball Burst 7: sparks and flame (A and S)
		forgeBoom = "rbxassetid://94978851787238", -- Deep Impact Boom (Daily Sounds): a Grade S or +10
		forgeRing = "rbxassetid://9119742466", -- Sword Draw Clang Unsheathing Two Sabers 1: the banner
		-- A boss weapon's drop cinematic (Config/WeaponLooks REVEAL.drop), Pro Sound Effects but the boom
		dropRise = "rbxassetid://9120732821", -- Whoosh Rising Swish Airy Various Pitches 3: the light column opens
		dropBurst = "rbxassetid://9116385087", -- Magic Burst 5: the weapon flashes into view
		dropRing = "rbxassetid://9119747485", -- Sword Long Metallic Ring Decay 3: its blade rings on (faded at the end)
		dropSting = "rbxassetid://9114023753", -- Cymbal Sting 1: an Epic or Legendary's swell
		dropBoom = "rbxassetid://94978851787238", -- Deep Impact Boom (Daily Sounds): a Legendary's weight
		dropFlip = "rbxassetid://3456145589", -- card_flip (the opening's flip, quieter here): its card turns over
		-- The boss chests (Config/BossChests)
		chestCreak = "rbxassetid://9120881682", -- Wood Groan Creak Opening Wood Chest Coffin 5 (Pro Sound Effects)
		chestThud = "rbxassetid://9120798134", -- Wood Bench Hits 2 (Pro Sound Effects): a chest landing
		chestCoins = "rbxassetid://9113849492", -- Coins Or Keys Jingle 6 (Pro Sound Effects): coins out of the chest
		chestPoof = "rbxassetid://9114156934", -- Doppler Whooshes Crackly Airy Bursts 1 (Pro Sound Effects): an empty chest
	},
	VOLUMES = {
		-- The rip at about half (owner 2026-11-10: lower the ripping sound)
		crinkle = 0.3, snap = 0.3, stack = 0.35, flip = 0.45, tease = 0.5,
		hitRare = 0.55, hitEpic = 0.65, hitLegendary = 0.75, shimmer = 0.3, land = 0.3, chime = 0.4,
		-- The Forge's: half their first levels (owner 2026-11-06: good, but loud)
		forgeFire = 0.22, forgeStrike = 0.25, forgeClank = 0.32, forgeBurst = 0.25, forgeBoom = 0.3, forgeRing = 0.2,
		-- The drop cinematic's: half again (owner 2026-11-06: good, but loud)
		dropRise = 0.12, dropBurst = 0.15, dropRing = 0.08, dropSting = 0.11, dropBoom = 0.12, dropFlip = 0.2,
		chestCreak = 0.35, chestThud = 0.35, chestCoins = 0.3, chestPoof = 0.25,
	},
	TEASE_FADE_SECONDS = 0.12, -- the tease's rise fades out this fast when the hit lands
}
