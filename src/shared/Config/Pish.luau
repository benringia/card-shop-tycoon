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
		giftPack = "BoosterPack",
		buildRack = "Build",
		orderStock = "Order",
		stockRack = "Box",
		customer = "Customer",
		ringUp = "Register",
		gift = "Gift",
		bye = "Paw",
	} :: { [string]: string },
	FIRST_ITEM = "sparkPack", -- the pack Pish drops at the start (Config/Items)
	GIFT_ITEM = "pishGift", -- his gift at the end: a pack whose hit card is Very Rare or better
	RACK = "SmallPackRack", -- the rack the first visit builds (Config/Shelves)
	ORDER_PRODUCT = "FirstSparkPack", -- the stock it orders (Config/Products)

	-- Petting Town Pish: luck for `seconds`, at most once per `cooldown` (seconds) per player, raising the hit slot's
	-- `fromRarity`-and-up weights by `boost` (the slot's lowest rarity gives up the difference; Util/LuckRules), for a
	-- player within `petRange` studs of him
	LUCK = { seconds = 180, cooldown = 900, boost = 0.25, fromRarity = "Very Rare", petRange = 12 },

	SKIP_HOLD = 2, -- seconds the skip button is held before the "really skip?" card
	LESSON_SECONDS = 20, -- a lesson visit leaves after this (or when the new thing is used)
	-- One visit per unlock (owner's levels, Config/Levels), once per player
	LESSONS = {
		{ id = "sleeves", level = 3, icon = "Sleeves" },
		{ id = "sword", level = 4, icon = "Sword" },
		{ id = "condenser", level = 5, icon = "Condenser" },
		{ id = "forge", level = 6, icon = "Forge" },
		{ id = "expand", level = 7, icon = "DeckBox" },
		{ id = "boosterBox", level = 11, icon = "BoosterBox" },
		{ id = "grading", level = 14, icon = "GradingSeal" },
		{ id = "jobs", level = 20, icon = "Jobs" },
	} :: { { id: string, level: number, icon: string } },
	-- The stuck helper: in a player's first `firstSeconds` of play, after `quiet` seconds without progress, at most
	-- once per `gap` seconds
	STUCK = { firstSeconds = 3600, quiet = 60, gap = 120 },

	-- Town Pish's day: walking at `speed` (studs a second; `trotSpeed` running to a player), now and then to an open
	-- shop's door (`shopChance`) where he stays `visitSeconds`, a random idle clip every `idleEvery` seconds (never the
	-- same twice running), a nap now and then
	TOWN = {
		speed = 7,
		trotSpeed = 11,
		visitSeconds = { 6, 12 },
		idleEvery = { 5, 10 },
		napChance = 0.1,
		shopChance = 0.5,
		idleClips = { "sit", "sniff", "bark", "roll", "dig", "shake", "playBow", "headTilt", "yawnStretch", "tailChase", "happyHop", "scratch" },
	},
	HEIGHT = 2.6, -- studs: a small dog beside a 5-stud player
	-- Licensed sounds (Roblox's PSE catalogue), measured in Config/SoundLevels
	SOUNDS = { bark = "", whimper = "", yawn = "", yip = "", dig = "" } :: { [string]: string },
}
