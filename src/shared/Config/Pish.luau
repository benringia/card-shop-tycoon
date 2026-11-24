--!strict
-- Pish, the tutorial's guide puppy (spec docs/superpowers/specs/2026-11-09-tutorial-pish-design.md): the owner's dog leads
-- a new player's first visit without words, comes back to teach each unlock, wanders the town (Town Pish, everyone
-- sees him) and gives luck when petted. Plain data (Lune-tested: tests/TutorialRules, LuckRules, LessonRules).
-- His model: ReplicatedStorage.NpcModels.Pish; his clips: ReplicatedStorage.MonsterAnimations.Pish.
return {
	-- The first visit, in order: each completes when the game sees the player do it (TutorialService)
	-- (owner 2026-11-17: "When the player opens their first card. Pish will then ask the player to summon them. then the
	-- party UI and everything else should be displayed": summonPal right after his present, the calm HUD only up to it)
	STEPS = { "giftPack", "summonPal", "buildRack", "orderStock", "stockRack", "customer", "ringUp", "gift", "bye" },
	-- The calm HUD (every piece hidden) runs up to this step and stops after it; KEEP: pieces a calm step still shows
	-- (TutorialRules.pishFocus)
	CALM_UNTIL = "summonPal",
	KEEP = { summonPal = { "party" } } :: { [string]: { string } },
	-- The picture over Pish's head for each step (Config/UIIcons names)
	STEP_ICONS = {
		giftPack = "PishPresent",
		summonPal = "Party",
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
	-- His pacing (owner 2026-11-18: "make it helpful but not annoying. do not popup when the player is currently doing
	-- something. like manning the cashier"; Util/LessonRules.mayStart, whileBusy): a lesson or a nudge starts once the
	-- player has been free `free` seconds (not on the register, carrying boxes, placing, in a window, a fight, a show or
	-- a popup: client Util/PlayerBusy) and `gap` seconds after his last visit; one under way steps back while they're
	-- busy (his time stopped) and leaves after `wait` seconds of it, its lesson kept for a better moment
	-- `gap` was 45 until the final tutorial check (owner 2026-11-19: "make sure the tutorial are not annoying"): shop
	-- levels 2 to 4 come within minutes and queue six lessons plus the prices one, so he was back within a minute each
	-- time; 90 gives a real breather (a lesson whose thing the player finds first is never taught: LessonRules.used)
	PACE = { free = 4, gap = 90, wait = 12 },
	LESSON_SECONDS = 20, -- a lesson visit that points leaves after this long (or when the new thing is used)
	-- ...one with an introduction for inside its window (PishTalk.AFTER: jobs, prices) waits this long for the tap
	-- (owner 2026-11-21: Pish introduces jobs; 20 s was gone before a new player found the Phone)
	INTRO_SECONDS = 45,
	TEACH_QUIET_SECONDS = 30, -- a lesson that teaches leaves after this long with no step taken (each step starts it again)
	-- What Pish teaches after his first visit, once per player. Until 2026-11-19 every town and shop unlock brought a
	-- visit at its level (owner 2026-11-10); levels 2 to 4 come within minutes, so he came again and again while the
	-- player was busiest (owner 2026-11-19: "so we should adjust the tutorial to not based on levels? whats the best
	-- move here", then "A and B now"). Now he teaches at first use, and only what needs words:
	--   `on = "placed"`: a machine or a card case, explained beside it the first time it's placed (PishTalk.AFTER;
	--     LessonRules.onPlaced). Its `level` only orders the waiting lessons. The main quest strip is what tells the
	--     player it can be built.
	--   `level` alone: what can't be placed, taught when it's handed over or opens: the sword, jobs.
	--   `trigger`: an event (the first trophy, the first title, the end of his first visit: prices).
	-- Plain shelves, racks, decor and new stock have no lesson: the main quest strip and the NEW tag on their tile
	-- (LevelRules.isNew) carry them. Combat is Chikin's.
	LESSONS = {
		{ id = "showcase", level = 2, icon = "Cases", shelf = "GlassShowcase", on = "placed" },
		{ id = "collectorCase", level = 3, icon = "Cases", shelf = "CollectorCase", on = "placed" },
		{ id = "sword", level = 4, icon = "Sword" },
		{ id = "condenser", level = 5, icon = "Condenser", shelf = "Condenser", on = "placed" },
		-- Storage racks (spec 2026-11-24-storage-racks-design): explained beside the first one placed, so a save already
		-- past level 5 gets it then too (no `late` needed)
		{ id = "storageRack", level = 5, icon = "Box", shelf = "StorageRack", on = "placed" },
		{ id = "forge", level = 6, icon = "Forge", shelf = "Forge", on = "placed" },
		-- `rush` (owner 2026-11-21: "The moment player unlock jobs. pish will introduce it to them"): first in line
		-- and no breather after his last visit (PACE.gap); he still waits for a free moment (LessonRules.rushFirst,
		-- mayStart). He points at Jobs on the Phone, then says what jobs are inside the window (PishTalk.AFTER.jobs)
		{ id = "jobs", level = 8, icon = "Jobs", rush = true },
		{ id = "bulkBin", level = 10, icon = "Copies", shelf = "BulkBin", on = "placed" },
		-- The Recycler came after launch (owner 2026-11-21: "when recycler is in game, pish will introduce it to old
		-- players and add it to tutorial for new players"): a level lesson that walks you to it in the Shop (no `on`),
		-- so a new player gets it on reaching Lv 12; `late`: a save already past its level gets it at its next join,
		-- once (LessonRules.late, TutorialService)
		{ id = "recycler", level = 12, icon = "Copies", shelf = "Recycler", late = true },
		-- The shop rooms came after launch too (spec 2026-11-23-shop-rooms-design): at a room's level his paws lead to its
		-- locked door (TutorialController POINT_AT); `late` brings it once to saves already past the level; opening the
		-- room first marks it seen (RoomService). Levels match Config/ShopRooms (tests/ShopRooms)
		{ id = "backRoom", level = 15, icon = "Shop", late = true },
		{ id = "gallery", level = 30, icon = "Shop", late = true },
		{ id = "grading", level = 14, icon = "GradingSeal", shelf = "GradingStation", on = "placed" },
		{ id = "trophy", icon = "Trophy", trigger = "trophy" },
		{ id = "titles", icon = "Trophy", trigger = "title" }, -- the first title earned: how to equip it (owner 2026-11-13)
		-- right after his first visit: setting your own prices (owner 2026-11-16: "let pish teach players how to set prices
		-- through shelves or the prices tile")
		{ id = "prices", icon = "Prices", trigger = "tourDone" },
		-- a creature's first faint (owner 2026-11-21, launch day: "if a player pet dies for the first time, chikin or
		-- pish should appear and talk to them about the healing spring. with an option to skip it ofcourse"): one line,
		-- his paws to the spring, Got it! to send him off (BattleService.OnFainted, CombatTutorialService)
		{ id = "spring", icon = "Heart", trigger = "faint" },
		-- "Customers love choice" (spec 2026-11-24-shop-variety-design): the first time a customer misses a product the
		-- shop could stock (from Config/Customers VARIETY.lessonLevel, CustomerService.OnMissed), his paws at the order
		-- computer; `talk`: he goes straight to his lines (PishTalk.AFTER.variety, "{product}" the one they missed)
		{ id = "variety", icon = "Order", trigger = "missing", talk = true },
	} :: { { id: string, level: number?, icon: string, shelf: string?, product: string?, trigger: string?, on: string?, rush: boolean?, late: boolean?, talk: boolean? } },
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
		homeChance = 0.15, -- of his other walks: home to the dog house in the plaza, in front of his bed (owner 2026-11-20)
		homeNap = 0.5, -- there he naps this often, else sits
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
		-- the ground under his run is looked for no higher than this over the player's feet (a step or a curb), on
		-- things you can't walk through: from 6 studs up he ran over the player's creature (found 2026-11-17)
		stepUp = 2,
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
