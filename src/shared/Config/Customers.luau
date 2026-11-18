--!strict
-- NPC customer behaviour. See DESIGN.md section 4.5. Plain data (colours as { r, g, b }) so Lune tests can load it.

-- Roblox's free hair (creator Roblox, price 0), for grown-ups and kids alike (ADULT_LOOK, KID_LOOK)
-- Side Part, Short and Sleek, Top Knot, Sideswept Dreads, Surfer, Curly Afro, Brown Charmer, Cool Side Shave (not Brown
-- Hair 62234425: its texture is gone, tests/CustomerLook)
local SHORT_HAIR = { 9244021842, 7193386173, 9243992729, 9243987340, 9174354743, 9174355709, 9174353649, 9244038785, 7193450455, 376548738, 3814474927 }
-- Pony Tails, Wavy and Medium Middle Parts, Straight Bangs, Chestnut Bun, Lavender Updo, Long Red Hair, Colorful Braids
local LONG_HAIR = { 9244095135, 7193442167, 9244097555, 7193444640, 7193448258, 9244111257, 9244089488, 6993754725, 7193448988, 7193449810, 62724852, 451220849, 2956239660, 3814476174 }

return {
	MAX_PER_PLOT = 4,
	FIRST_SPAWN_DELAY = 5, -- seconds after a shop is claimed
	-- A new player's shop: none come until Pish sends his own customer (TutorialRules.holdsCustomers), then the shop's
	-- own wait this long, so his first sale has the counter to itself (owner 2026-11-16)
	AFTER_PISH_CUSTOMER = 40,
	SPAWN_INTERVAL_MIN = 8, -- seconds between customers; shop rating will shorten this later
	SPAWN_INTERVAL_MAX = 15,
	SPAWN_CHECK_INTERVAL = 1,

	-- A new shop's boost (owner 2026-11-19: "make them buy like 3 or 4 minimum. rarely just 1. specially if its market
	-- price. to speed up gold in early game", then "add your suggestions"; CustomerTypes.newShopShare): in full up to
	-- shop level `fullUntil`, fading to nothing by `goneAt` (the economy as before from there). While it's on, customers
	-- come `gap` times as far apart (about 1.4x as many), want LIST_SIZE's `new` sizes and kids KID.units' `new`, and at a
	-- shelf priced a band over market take one fewer, past that just one (CustomerTypes.unitsAt)
	NEW_SHOP = { fullUntil = 8, goneAt = 15, gap = 0.7 },
	-- How many things a customer wants (CustomerTypes.listSize): each size's share, a new shop's (`new`: usually 3 or 4,
	-- rarely 1) and from shop level NEW_SHOP.goneAt (`late`: 1 to 3 evenly, as before), blended in between
	LIST_SIZE = {
		{ count = 1, new = 0.05, late = 1 },
		{ count = 2, new = 0.15, late = 1 },
		{ count = 3, new = 0.45, late = 1 },
		{ count = 4, new = 0.35, late = 0 },
	},

	WALK_SPEED = 6, -- a normal walk, as the town walkers (owner 2026-11-06: 10 looked hurried)
	BROWSE_SECONDS = 1.5, -- time spent looking at a shelf
	SHELF_STAND_DISTANCE = 2.5, -- studs in front of a shelf's front face
	SEARCH_SHELVES = 2, -- more shelves a customer checks when something on their list isn't on the shelves
	-- Studs out on the street from the shop front: the shop's door, where customers become its customers and leave it.
	-- They walk there from somewhere random on the street (TownWalkerService, WALKERS.arriveAway) and walk off to the
	-- nearest street end after; only without the town walkers (or past WALKERS.crowdCap) do they appear and vanish here
	ENTRY_DISTANCE = 8,

	QUEUE_PATIENCE = 40, -- seconds in the register queue before giving up (Bigger Queue upgrade +50% later)
	CHECKOUT_PATIENCE = 60, -- once scanning starts, seconds after the latest scan before giving up
	QUEUE_SPACING = 3,
	QUEUE_CHECK_INTERVAL = 0.5,
	COUNTER_ARRIVE_DISTANCE = 1.5, -- close enough to a queue slot to count as standing there

	MAX_LIFETIME = 180, -- safety net: customers stuck outside the queue are removed after this many seconds
	LIFETIME_RECHECK = 10, -- queued customers have their own timers, so the safety net checks again later

	BUBBLE_SECONDS = 2.5,
	-- Config/UIIcons names (anything else shows as text)
	BUBBLE_ANNOYED = "Angry", -- price over the top band
	BUBBLE_NO_STOCK = "Thinking", -- nothing they wanted on the shelves
	BUBBLE_GAVE_UP = "⌛", -- waited too long in the queue
	BUBBLE_HAPPY = "Happy", -- paid at the register
	BUBBLE_DISAPPOINTED = "Thinking", -- a collector who didn't find their card at their price
	BUBBLE_REFUSE = "🙅", -- a kid turning down your counter
	OFFER_ACTION_COOLDOWN = 0.25, -- seconds between an owner's answers to an offer (OfferAction)
	OFFER_CHECK_INTERVAL = 0.5, -- seconds between checks for unanswered offers running out

	PATH_AGENT = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true, -- the plot floor is a 1-stud step up from the street
	},

	-- Roblox's default R15 animations: today's walk (the old 507777826 looked like a jog, owner 2026-11-06) and idle.
	-- The walk clip is made for WALK_CLIP_PACE studs a second (Roblox's Animate: "normalizedWalkSpeed 0.5"), so NPCs
	-- play it at their speed over that (Util/WalkStep.clipSpeed)
	WALK_ANIMATION = "rbxassetid://913402848",
	IDLE_ANIMATION = "rbxassetid://507766666",
	WALK_CLIP_PACE = 6.4,
	-- Following a path (Util/WalkStep, server Util/NpcMotion): a waypoint on the way counts as reached `lookahead` studs
	-- early so the next step goes out before the NPC stops; the walk's end within `finish`. Trying to walk but covering
	-- under stallStuds in stallSeconds is being stuck (it gives that walk up). A step may take twice its walk time plus
	-- `grace` s; position checked every `check` s; the idle clip waits idleDelay s after stopping (no flicker at turns)
	NPC_STEP = { lookahead = 1.25, finish = 0.6, stallSeconds = 1, stallStuds = 0.5, grace = 4, check = 0.05, idleDelay = 0.25 },

	SKIN_COLORS = {
		{ 255, 220, 185 },
		{ 234, 184, 146 },
		{ 198, 134, 94 },
		{ 141, 85, 54 },
		{ 95, 60, 40 },
	},
	-- Grown-up customers (owner 2026-11-16: "improve customer's look. add some adult"; picked look B from Studio renders):
	-- Roblox's own "Man" (bundle 238) and "Woman" (239) bodies with their animated faces, dressed from Roblox's free
	-- catalog (creator Roblox, price 0; the Classic v2 bundles' outfits too). Kids: KID_LOOK.
	-- Each type keeps its colours through its shirts; plain shoppers wear everything. Util/CustomerLook picks
	ADULT_LOOK = {
		bodies = {
			man = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078, Head = 10725826963, MoodAnimation = 10725833199 },
			woman = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793, Head = 10725626210, MoodAnimation = 10725638029 },
		},
		hair = { man = SHORT_HAIR, woman = LONG_HAIR },
		outfits = {
			plain = {
				shirts = { 607785314, 398633584, 3670737444, 398635081, 398634295, 144076358, 382538059, 4047884939, 4047884046, 4047886060, 144076436, 382537085, 382537702, 4637596615, 4637603462, 4637617396, 4637611578 },
				pants = { 398633812, 398634487, 398635338, 144076760, 382537950, 382538503, 382537569, 382537806, 4637601297, 4637605284, 4637618900, 4637612548 },
			},
			-- purples (Purple and Teal Top, Cindy's purple jacket, Pastel Starburst with Gray Jacket)
			collector = { shirts = { 4047886060, 4637611578, 398634295 }, pants = { 4637612548, 398634487, 4637605284 } },
			-- casual and warm (the Pizza shirts, Blue Plaid, Green Jersey), shorts
			bargain = { shirts = { 4047884939, 382537085, 398635081, 382538059 }, pants = { 382537950, 382537806, 398635338 } },
			-- dark jackets (ROBLOX Jacket, Motorcycle, Guitar Tee with Black Jacket), black jeans
			bigSpender = { shirts = { 607785314, 144076358, 4047884046 }, pants = { 382537569, 398633812, 382538503 } },
		},
	},
	-- Kids in the same style (owner 2026-11-16: "update the kids to be the same style as the adults"): Roblox's "ROBLOX
	-- Boy" (bundle 109) and "ROBLOX Girl" (108) bodies at the kid's scale with one of Roblox's free animated heads
	-- (Dylan, Devon, Check It, Silly Fun, Stevie), casual clothes and the same hair
	KID_LOOK = {
		bodies = {
			boy = { Torso = 376532000, LeftArm = 376530220, RightArm = 376531012, LeftLeg = 376531300, RightLeg = 376531703 },
			girl = { Torso = 376547767, LeftArm = 376547633, RightArm = 376547341, LeftLeg = 376546668, RightLeg = 376547092 },
		},
		heads = {
			{ Head = 10687288296, MoodAnimation = 10687293613 },
			{ Head = 10723855306, MoodAnimation = 10723858600 },
			{ Head = 11308945948, MoodAnimation = 11308935548 },
			{ Head = 15938951781, MoodAnimation = 15938951885 },
			{ Head = 10638267973, MoodAnimation = 10647852134 },
		},
		hair = { boy = SHORT_HAIR, girl = LONG_HAIR },
		-- the Pizza shirts, Green Jersey, Teal Shirt, Purple and Teal Top, Pastel Starburst, Denim Jacket with Hoodie
		outfits = {
			shirts = { 4047884939, 382537085, 382538059, 382537702, 4047886060, 398634295, 398633584 },
			pants = { 382537950, 382537806, 398635338, 398634487, 382537569 },
		},
	},
	CLOTHES_COLORS = {
		{ 200, 60, 60 },
		{ 60, 110, 200 },
		{ 70, 160, 90 },
		{ 230, 180, 50 },
		{ 130, 80, 170 },
		{ 50, 50, 60 },
		{ 220, 220, 225 },
	},

	-- Customer types (spec 2026-11-06-customers-design, owner's pick B: props plus an icon as they walk in). weight:
	-- their share of customers (Util/CustomerTypes, in TYPE_ORDER); needsShowcase: only shops with a Glass Showcase
	-- holding a card; minLevel: from that shop level; tolerance: price bands higher than a plain customer they still
	-- buy in; icon: over them as they come through the door (a UIIcons name or an emoji; the collector shows its card
	-- instead); scale: the rig's size; colors: their clothes (rgb, picked at random); props: parts welded to a body
	-- part, size and offset in studs (offset from the part's centre, -Z the front), plain colours
	TYPE_ORDER = { "plain", "kid", "collector", "bargain", "bigSpender" },
	-- A kid buys this many of the cheapest pack; a big spender the booster box when stocked (else this many packs) and
	-- tips `tip` of the total when every price is at or under market
	-- Kids buy the cheapest pack, a new shop's mostly 2 or 3, later 1 or 2 as before (CustomerTypes.kidUnits; NEW_SHOP),
	-- and rip one at the counter: everyone sees the reveal for revealSeconds before they leave or offer the card
	-- (OfferService)
	KID = {
		units = { { count = 1, new = 0.15, late = 1 }, { count = 2, new = 0.5, late = 1 }, { count = 3, new = 0.35, late = 0 } },
		revealSeconds = 3,
	},
	BIG_SPENDER = { box = "FirstSparkBox", packs = { 6, 12 }, tip = 0.1 },
	-- The shop bag a customer carries out after paying (owner 2026-11-16: "customers that bought something should carry
	-- a shopping bag on their way out. shopping bag should have pish and chikin design on them"; server Util/ShopBag).
	-- One part: `image` (tools/ui-art/make_shop_bag.py, assets/ui/bag; look A: kraft paper, the dogs' gold seal from the
	-- card back, the name) on both wide sides, `color` the paper on the rest; rope handles; held in `hand` (the right
	-- holds a kid's pack or a bargain hunter's coupon), turned so its pictures face sideways like a bag at your side.
	-- Studs at a grown-up's size (kids' scaled with them): size width, height, depth; handle above the bag's top;
	-- the bag's top `drop` below the hand
	BAG = {
		image = "rbxassetid://104259813346579",
		color = { 201, 154, 99 },
		handleColor = { 122, 85, 49 },
		hand = "LeftHand",
		turn = 25, -- degrees off sideways, so the picture also shows from behind
		size = { 0.9, 1.0, 0.42 },
		handle = { width = 0.42, height = 0.34, thick = 0.06 },
		drop = 0.3,
	},
	-- Collectors want one card: ownedShare of the time one you own, else any card weighted by rarity (per card);
	-- they pay up to premium x its worth
	COLLECTOR = {
		premium = 1.3,
		ownedShare = 0.5,
		wantWeights = { Common = 30, Rare = 25, ["Very Rare"] = 20, Epic = 15, Legendary = 10 },
		-- The thought bubble over a collector holding the wanted card's face (CustomerController), in pixels and studs
		thought = { cardWidth = 54, cardHeight = 76, padding = 5, offsetY = 3.4, maxDistance = 70 },
	},
	-- Kid offers (Util/OfferRules): a kid sells a Very Rare or better pull by rarity chance x grade factor, asks
	-- askLow-askHigh of its worth and takes lowestLow-lowestHigh; at most perHour offers an hour and one Legendary per
	-- legendaryGap seconds per shop; the counter moves in steps of `step` x worth (chips: under the worth), the face
	-- shows sure / maybe moodBand x worth around the lowest; retries counters before leaving; patience seconds to answer
	OFFER = {
		chance = { ["Very Rare"] = 0.4, Epic = 0.3, Legendary = 0.3 },
		gradeFactor = { C = 1.15, B = 1.0, A = 0.85, S = 0.7 },
		askLow = 0.90,
		askHigh = 1.0,
		lowestLow = 0.75,
		lowestHigh = 0.90,
		perHour = 4,
		legendaryGap = 10800,
		step = 0.05,
		chips = { -0.20, -0.15, -0.10, 0 },
		moodBand = 0.05,
		retries = 1,
		patience = 25,
	},
	-- Shop rating (Util/RatingRules, RatingService): parts scored 0-1 with these weights (decor: the shop's look and
	-- placed pieces, Util/DecorRules.score; about a tenth of the rating), over the last `history` visits for happiness, smoothed over smoothSeconds, worked out every `tick` s; the
	-- spawn gap is spawnAt1 x at 1 star and spawnAt5 x at 5 (3 stars: today's flow); display points per card shown,
	-- displayFull points = a full score; a tip is good from goodFrom
	RATING = {
		parts = { stocked = 0.35, prices = 0.25, displays = 0.15, happy = 0.25, decor = 0.10 },
		history = 20,
		smoothSeconds = 90,
		tick = 5,
		spawnAt1 = 1.4,
		spawnAt5 = 0.6,
		displayPoints = { Epic = 1, Legendary = 3, foil = 1 },
		displayFull = 6,
		goodFrom = 0.7,
		sendStep = 0.05,
		-- The stars on the shop's sign (PlotService.SetSignRating): a row along the sign's bottom, filled by quarters
		sign = { rowHeight = 0.32, nameHeight = 0.68, dim = 0.72, color = { 255, 205, 60 } },
		-- The HUD chip (RatingController): a white pill of stars and the number in a 48 px tap area
		chip = { height = 36, hit = 48, star = 18, text = 18 },
		tipsHeight = 250, -- the tips window's height in pixels
	},
	-- The tips window's lines per rating part: good when it scores RATING.goodFrom or more, else the fix
	RATING_TIPS = {
		stocked = { good = "Shelves stocked", fix = "Restock empty shelves" },
		prices = { good = "Fair prices", fix = "Lower the prices customers find too high" },
		displays = { good = "Great cards on display", fix = "Put a rare card in a Glass Showcase to draw collectors" },
		happy = { good = "Happy customers", fix = "Keep stock in and serve the queue quickly" },
		decor = { good = "A cosy shop", fix = "Decorate your shop" },
	},
	-- Town walkers (Util/WalkerRules, TownWalkerService): up to `max` in town, one more every spawnEvery s while a player
	-- is in town; they walk in from a street end and stroll the whole street for linger s (sitting on a free bench
	-- sitChance of the time), then pick an open shop weighted by rating^ratingPower (x wantedBonus for a collector's card
	-- on show) and become its customer; after lifetime s they walk off at the nearest street end.
	-- Stops (WalkerRules.townStops): window spots windowOffsets studs either side of each shop's door on its sidewalk,
	-- road spots at roadXs, roadZ out from the middle line, plaza spots plazaRadius out at plazaAngles (degrees, 0 = +X;
	-- 180 is the spawn pad) and the plaza benches. They appear and leave exitInset studs inside the street's ends.
	-- walkSpeed is a stroll (owner 2026-11-06: "walk slowly, not run"); the walk clip keeps pace (WALK_CLIP_PACE).
	-- Their paths never jump (they hopped onto the fountain) and keep off grass and water; a waypoint they can't reach
	-- in stuckSeconds past its walk time is given up. A collector keeps its card to itself until it's in a shop (no
	-- thought bubbles on the street). "In town" is within townRadius of the plaza centre.
	WALKERS = {
		max = 8,
		spawnEvery = 20,
		linger = { 40, 120 },
		sitChance = 0.3,
		ratingPower = 2,
		wantedBonus = 3,
		lifetime = 300,
		stopSeconds = { 4, 9 },
		walkSpeed = 6,
		stuckSeconds = 2,
		agent = {
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = false,
			Costs = { Water = math.huge, Grass = 6, LeafyGrass = 6, Mud = 6, Ground = 6 },
		},
		windowOffsets = { -11, 11 },
		roadXs = { -96, -64, -32, 32, 64, 96 },
		roadZ = 32,
		plazaRadius = 16,
		plazaAngles = { 0, 90, 270 },
		exitInset = 4,
		townRadius = 260,
		-- A shop's customers walk in from a random street stop or end at least arriveAway studs from the shop's door and
		-- every player (WalkerRules.spawnPoint), and walk off to the nearest end after. Past crowdCap town NPCs at once
		-- (strolling, arriving and leaving) they appear and vanish at the door instead (fewer rigs on screen).
		arriveAway = 40,
		crowdCap = 24,
		-- A walk that can't start (no path out of a tight spot, like the gap between a bench and the gazebo) counts as
		-- failed; after unstickAfter in a row the walker retraces the route it came in on, after giveUpAfter it's removed
		unstickAfter = 2,
		giveUpAfter = 5,
	},
	-- Reactions (Util/ReactionRules): passing within `reach` studs of a case holding an Epic, Legendary or foil card a
	-- customer stops `seconds` with a whoa (a Legendary holds `crowd` at once); within `petReach` of your summoned
	-- creature, petChance of them stop to pet it (once per visit)
	REACTIONS = { reach = 6, seconds = 1.5, crowd = 3, petChance = 0.35, petReach = 8, whoa = "😮", heart = "Heart", checkEvery = 0.25 },
	-- Bargain hunters (Util/HaggleRules): offer offLow-offHigh under the total, pay up to gapLow-gapHigh of the way back
	HAGGLE = { offLow = 0.10, offHigh = 0.25, gapLow = 0.4, gapHigh = 0.8 },
	-- The offer panel at the register (RegisterController), in pixels; buttons and chips at least 48 tall for phones
	-- On phones it sits below the cash row (phoneTop) and left of the jump button's column (phoneRight)
	PANEL = { width = 230, padding = 10, gap = 6, buttonHeight = 48, cardWidth = 54, cardHeight = 76, topOffset = -20, phoneTop = 44, phoneRight = 100 },
	-- The counter's face for the price you picked (from the server's edges, never the exact price they'd take)
	FACES = { sure = "😀 Sure!", maybe = "😐 Hmm, maybe", no = "😠 No way" },
	-- A kid's rip over the counter (CustomerController): the card grows in, holds, then shrinks away; Very Rare or
	-- better gets a cheer bubble and the pack opening's hit sound, a Legendary a light beam too
	REVEAL = {
		cardWidth = 64,
		cardHeight = 90,
		offsetY = 4.2,
		growSeconds = 0.35,
		holdSeconds = 2.5,
		maxDistance = 90,
		cheer = "🎉",
		cheerFrom = "Very Rare",
		beam = { height = 26, width = 2.2, transparency = 0.6, seconds = 2.8, color = { 255, 214, 92 } },
	},
	TYPES = {
		plain = { weight = 0.55, props = {} },
		kid = {
			weight = 0.20,
			icon = "🎒",
			scale = 0.82,
			colors = { torso = { { 79, 195, 255 }, { 255, 140, 66 }, { 110, 214, 92 } }, legs = { { 58, 123, 213 }, { 70, 70, 90 } } },
			props = {
				{ part = "Head", size = { 1.3, 0.35, 1.3 }, offset = { 0, 0.68, 0.05 }, color = { 255, 95, 143 }, shape = "Block" }, -- cap
				{ part = "Head", size = { 0.9, 0.12, 0.6 }, offset = { 0, 0.52, -0.8 }, color = { 255, 95, 143 }, shape = "Block" }, -- its peak
				{ part = "RightHand", size = { 0.5, 0.7, 0.1 }, offset = { 0, -0.35, -0.25 }, color = { 255, 122, 182 }, shape = "Block" }, -- a pack
			},
			-- dressed, their hair would poke through the cap: the pack alone
			dressedProps = {
				{ part = "RightHand", size = { 0.5, 0.7, 0.1 }, offset = { 0, -0.35, -0.25 }, color = { 255, 122, 182 }, shape = "Block" },
			},
		},
		collector = {
			weight = 0.10,
			needsShowcase = true,
			colors = { torso = { { 142, 111, 216 }, { 96, 84, 140 } }, legs = { { 75, 63, 107 }, { 50, 50, 60 } } },
			props = {
				{ part = "Head", size = { 1.0, 0.25, 0.1 }, offset = { 0, 0.1, -0.62 }, color = { 43, 37, 64 }, shape = "Block" }, -- glasses
				{ part = "UpperTorso", size = { 0.25, 1.1, 0.85 }, offset = { 1.15, -0.1, 0 }, color = { 124, 92, 255 }, shape = "Block" }, -- a binder under its arm
			},
		},
		bargain = {
			weight = 0.10,
			icon = "🏷️",
			tolerance = 1,
			colors = { torso = { { 242, 165, 65 }, { 200, 150, 90 } }, legs = { { 107, 90, 70 }, { 90, 80, 60 } } },
			props = {
				{ part = "Head", size = { 1.55, 0.45, 1.55 }, offset = { 0, 0.68, 0 }, color = { 124, 196, 107 }, shape = "Block" }, -- bucket hat
				{ part = "RightHand", size = { 0.6, 0.35, 0.05 }, offset = { 0, -0.35, -0.25 }, color = { 255, 243, 168 }, shape = "Block" }, -- a coupon
			},
			-- dressed, their hair would poke through the bucket hat: the coupon alone
			dressedProps = {
				{ part = "RightHand", size = { 0.6, 0.35, 0.05 }, offset = { 0, -0.35, -0.25 }, color = { 255, 243, 168 }, shape = "Block" },
			},
		},
		bigSpender = {
			weight = 0.05,
			icon = "💎",
			minLevel = 11, -- the booster box unlocks there
			tolerance = 1,
			colors = { torso = { { 43, 37, 64 }, { 30, 30, 40 } }, legs = { { 29, 24, 48 } } },
			props = {
				{ part = "Head", size = { 1.05, 0.22, 0.1 }, offset = { 0, 0.1, -0.62 }, color = { 20, 18, 30 }, shape = "Block" }, -- shades
				{ part = "UpperTorso", size = { 1.0, 0.12, 0.1 }, offset = { 0, 0.55, -0.52 }, color = { 245, 197, 66 }, shape = "Block" }, -- gold chain
				{ part = "UpperTorso", size = { 0.3, 0.3, 0.08 }, offset = { 0, 0.25, -0.53 }, color = { 245, 197, 66 }, shape = "Ball" }, -- its medallion
			},
		},
	},
}
