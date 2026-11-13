--!strict
-- Pish, the tutorial's guide puppy (spec docs/superpowers/specs/2026-11-09-tutorial-pish-design.md): the owner's dog leads
-- a new player's first visit without words, comes back to teach each unlock, wanders the town (Town Pish, everyone
-- sees him) and gives luck when petted. Plain data (Lune-tested: tests/TutorialRules, LuckRules, LessonRules).
-- His model: ReplicatedStorage.NpcModels.Pish; his clips: ReplicatedStorage.MonsterAnimations.Pish.
return {
	-- The first visit, in order: each completes when the game sees the player do it (TutorialService)
	STEPS = { "giftPack", "buildRack", "orderStock", "stockRack", "customer", "ringUp", "gift", "bye" },
	-- The picture over Pish's head for each step (Config/UIIcons names)
	STEP_ICONS = {
		giftPack = "PishPresent",
		buildRack = "Build",
		orderStock = "Order",
		stockRack = "Box",
		customer = "Customer",
		ringUp = "Register",
		gift = "PishGift",
		bye = "Paw",
	} :: { [string]: string },
	FIRST_ITEM = "pishPresent", -- his present at the start: a First Spark pack with his picture (Config/Items)
	GIFT_ITEM = "pishGift", -- his gift at the end: a pack whose hit card is Very Rare or better
	RACK = "SmallPackRack", -- the rack the first visit builds (Config/Shelves)
	ORDER_PRODUCT = "FirstSparkPack", -- the stock it orders (Config/Products)

	-- Petting Town Pish: luck for `seconds`, at most once per `cooldown` (seconds) per player, raising the hit slot's
	-- `fromRarity`-and-up weights by `boost` (the slot's lowest rarity gives up the difference; Util/LuckRules), for a
	-- player within `petRange` studs of him
	LUCK = { seconds = 180, cooldown = 900, boost = 0.25, fromRarity = "Very Rare", petRange = 12 },

	SKIP_HOLD = 2, -- seconds the skip button is held before the "really skip?" card
	LESSON_SECONDS = 20, -- a lesson visit that points leaves after this long (or when the new thing is used)
	TEACH_QUIET_SECONDS = 30, -- a lesson that teaches leaves after this long with no step taken (each step starts it again)
	-- One visit per town or shop unlock, once per player (owner 2026-11-10: "when a player unlocks something for the
	-- first time, pish will visit and teach them"; tests/LessonRules checks every Products / Shelves unlock has one).
	-- `shelf`: he walks them through Build to place it, `product`: through the order computer to order it (done when
	-- they do, Util/LessonRules.forShelf / forProduct); `trigger`: an event instead of a level (the first trophy).
	-- The two cases unlock at 1 and are taught once his first visit has given you cards. Combat is Chikin's.
	LESSONS = {
		{ id = "showcase", level = 2, icon = "Cases", shelf = "GlassShowcase" },
		-- shop decor: one lesson for the whole Decor tab (looks and pieces), on its first piece (spec 2026-11-14-shop-decor)
		{ id = "decor", level = 2, icon = "Decor", shelf = "PottedPlant" },
		{ id = "sleeves", level = 3, icon = "Sleeves", product = "CardSleeves" },
		{ id = "collectorCase", level = 3, icon = "Cases", shelf = "CollectorCase" },
		{ id = "sword", level = 4, icon = "Sword" },
		{ id = "wallShelf", level = 4, icon = "Shelves", shelf = "WallShelf" },
		{ id = "condenser", level = 5, icon = "Condenser", shelf = "Condenser" },
		{ id = "forge", level = 6, icon = "Forge", shelf = "Forge" },
		{ id = "expand", level = 7, icon = "DeckBox", product = "DeckBox" },
		{ id = "accessoryHook", level = 7, icon = "Shelves", shelf = "AccessoryHook" },
		{ id = "bigRack", level = 9, icon = "Shelves", shelf = "BigDisplayRack" },
		{ id = "boosterBox", level = 11, icon = "BoosterBox", product = "FirstSparkBox" },
		{ id = "grading", level = 14, icon = "GradingSeal", shelf = "GradingStation" },
		{ id = "jobs", level = 20, icon = "Jobs" },
		{ id = "trophy", icon = "Trophy", trigger = "trophy" },
		{ id = "titles", icon = "Trophy", trigger = "title" }, -- the first title earned: how to equip it (owner 2026-11-13)
	} :: { { id: string, level: number?, icon: string, shelf: string?, product: string?, trigger: string? } },
	-- The stuck helper: in a player's first `firstSeconds` of play, after `quiet` seconds without progress, at most
	-- once per `gap` seconds
	STUCK = { firstSeconds = 3600, quiet = 60, gap = 120 },

	-- Town Pish's day: walking at `speed` (studs a second; `trotSpeed` running to a player), now and then to an open
	-- shop's door (`shopChance`) where he stays `visitSeconds`, a random idle clip every `idleEvery` seconds (never the
	-- same twice running), a nap now and then
	TOWN = {
		speed = 4.5, -- a small dog's stroll (was 7: his legs blurred)
		trotSpeed = 8,
		visitSeconds = { 6, 12 },
		idleEvery = { 5, 10 },
		napChance = 0.1,
		shopChance = 0.5,
		petHoldMax = 8, -- seconds petting can hold him in one place (Util/PishPath.holdEnd): pets every 2 s can't keep him
		idleClips = { "sit", "sniff", "bark", "roll", "dig", "shake", "playBow", "headTilt", "yawnStretch", "tailChase", "happyHop", "scratch" },
		-- He greets a player who comes near, like Town Chikin (owner 2026-11-12: "npc pish should also greet people like
		-- chikin"; Util/GreetRules, Server/Util/TownDog.greet): the nearest within `range` studs he hasn't greeted in
		-- `cooldown` seconds; he stops `hold` seconds, faces them, plays one of `clips` and barks, and a bubble over him
		-- says one of PishTalk.GREETS with their name. Not a player his tutorial self is leading.
		greet = { range = 16, cooldown = 30, every = 0.5, hold = 2.5, joinGrace = 15, clips = { "happyHop", "headTilt", "bark" } },
	},
	HEIGHT = 2.6, -- studs: a small dog beside a 5-stud player
	-- His arrival after the welcome flight (Util/ArrivalShot; owner 2026-11-10: the camera close on his paws as he runs,
	-- slowly up to his face, then out to the two of you when he's near; longer). Studs and seconds; `feet` / `face`: the
	-- close camera beside him (up, to his side, ahead of him) and the height it looks at; `panFrom` / `panTo` /
	-- `wideFrom`: shares of his run; `wide`: the shot of you both from the side
	ARRIVAL = {
		from = 30, -- studs from the player he starts (in front, else the first clear way; Util/ArrivalShot.pickRun), `startSide` to their left
		minRun = 10, -- the shortest run when every way is blocked
		wallGap = 1.5, -- studs he starts short of a wall or a shelf
		startSide = 5,
		stop = 4, -- studs in front of the player he stops, `stopSide` to their left
		stopSide = 2,
		speed = 6.5, -- studs a second (about 4.6 s of running)
		feet = { up = 0.55, side = 2.6, ahead = 1.6, lookUp = 0.35 },
		face = { up = 1.75, side = 3, ahead = 2.2, lookUp = 1.8 },
		panFrom = 0.25,
		panTo = 0.7,
		wideFrom = 0.78,
		wide = { side = 10, lookUp = 1.6 }, -- `side`: how far the camera's side of his run is checked; the height it looks at
		-- The wide shot's angles to try, from the middle of the two of you (studs: to the camera's side of his run, out
		-- along his way in, up): from the side, the other side, behind him looking at you, behind you looking at him;
		-- the first with `wideClear` of its view free of walls (Util/ArrivalShot.pickWide)
		wideAngles = {
			{ side = 10, out = 0, up = 4.5 },
			{ side = -10, out = 0, up = 4.5 },
			{ side = 2.5, out = 9, up = 3.5 },
			{ side = 2.5, out = -8, up = 4.5 },
		},
		wideClear = 0.85,
		-- His magical entrance first (the owner 2026-11-11: "change the pish and chicken entrance cinematic. not the same
		-- as this but still epic/magical/welcoming"; Util/DogMagic, ArrivalShot.magic; Chikin's too): the camera looks
		-- out from beside you as a golden magic circle on the ground calls him for `call` seconds (motes pulling in,
		-- a twinkling), then a pop of stars and light and he hops out of it (`hop` seconds, his happyHop) as his name
		-- card pops up with a cheerful sting; then he runs in trailing sparkles (the shot below) and arrives in hearts
		-- and stars. `circle` studs; the pop's emitters as Util/PackEmitter reads them (the Euphoric pack's, as the
		-- welcome finale's). Pro Sound Effects and an APM sting.
		MAGIC = {
			call = 1.6,
			hop = 1.0,
			circle = { radius = 3.4, spin = 90, lift = 0.15, light = 16 },
			camera = { back = 3, side = 3.5, up = 4.5, lookUp = 1.5, hero = { ahead = 7, side = 2.5, up = 2, lookUp = 1.6 }, push = 2.5 },
			banner = { seconds = 2.6, pop = 0.45 },
			trail = { rate = 30, lifetime = { 0.5, 0.9 }, size = 0.45, color = { 255, 220, 120 } },
			sounds = {
				call = "rbxassetid://9116379771", -- Magical Wing Flutter, Rapid, Pitched-Up Chimes (the circle calling)
				poof = "rbxassetid://9125644321", -- Magic Twirling Small High Pitch Spinning Chime (he pops out)
				pop = "rbxassetid://9117841516", -- Pop Airy 2
				ding = "rbxassetid://9126073960", -- Synth Sparkle Tone Ding (his name card)
				sting = "rbxassetid://9039712094", -- APM "Family Friendly Tag - Sting 1" (5 s)
				arrive = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits 1 (hearts as he arrives)
			},
			volumes = { call = 0.6, poof = 0.7, pop = 0.5, ding = 0.5, sting = 0.25, arrive = 0.55 },
			stars = {
				count = 10,
				emitter = { texture = "goldStars", lifetime = { 0.8, 1.2 }, speed = { 3, 7 }, spread = { 180, 180 }, rotation = { -360, 360 }, size = { { 0, 1.2 }, { 1, 1.2 } }, transparency = { { 0, 1 }, { 0.4, 0 }, { 1, 1 } }, color = { 255, 212, 57 }, emission = 2, brightness = 4, zOffset = 1 },
			},
			burst = {
				count = 18,
				emitter = { texture = "starStreak", lifetime = { 0.35, 0.55 }, speed = { 60, 110 }, spread = { 360, 360 }, drag = 12, size = { { 0, 0.6 }, { 0.5, 1.6 }, { 1, 0 } }, transparency = { { 0, 0.25 }, { 1, 0 } }, color = { 255, 214, 110 }, emission = 1, brightness = 4, facing = "parallel", zOffset = 2 },
			},
			glow = {
				count = 1,
				emitter = { texture = "auraLight", lifetime = { 0.8, 0.8 }, size = { { 0, 9 }, { 1, 9 } }, transparency = { { 0, 1 }, { 0.3, 0.5 }, { 1, 1 } }, color = { 255, 220, 140 }, emission = 1, brightness = 3 },
			},
		},
		follow = 9, -- how quickly the camera follows its shot (per second)
		waitLimit = 30, -- seconds he waits for the loading screen at most
		afterLoading = 0.8, -- and then its fade (Config/LoadingScreen FADE_SECONDS 0.6) before the first shot
	},
	-- Licensed sounds (Roblox's Pro Sound Effects catalogue, which has no house dogs: coyote barks pitched up small, a
	-- coyote cub's whimper, dirt thrown from a shovel; no canine yawn, so the yawn stays silent), measured in
	-- Config/SoundLevels. Each Bark marker plays the whole bark, so it must stay short.
	SOUNDS = {
		bark = "rbxassetid://9113955093", -- Coyotes Gruff Barking 6, 0.5 s
		whimper = "rbxassetid://9113951583", -- Coyote Cub Whimpering Yelping Crying 3, 2 s
		yawn = "",
		yip = "rbxassetid://9113955748", -- Coyotes Gruff Barking 12, 0.5 s
		dig = "rbxassetid://9114083746", -- Dirt Dig Dirt Throws From Shovel 12, 0.8 s
	} :: { [string]: string },
	SOUND_PITCH = { bark = 1.35, whimper = 1.1, yip = 1.7 } :: { [string]: number }, -- PlaybackSpeed (higher: a smaller dog)
	SOUND_VOLUME = 1, -- times each sound's level (Util/SoundLevel); all four are quiet (measured 11-76 of 120)
}
