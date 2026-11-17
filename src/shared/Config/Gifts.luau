--!strict
-- Daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design; owner: "go, can we also have weekly and
-- monthly. design must feel like a WIN. yes 10 min timer should start when they actually start playing"; layout A).
-- One daily gift per UTC day after PLAY_SECONDS of play that day (counted once the first visit is done), a 7-day round
-- that carries on where you left off (a missed day resets nothing); every daily gift claimed also fills the week's and
-- the month's bars, and their chests wait once earned. Util/GiftRules, GiftService (server), GiftController and
-- Util/GiftWin (client). Plain data: tests/GiftRules.
export type Grant = { item: string, count: number }
export type Reward = { cash: number?, items: { Grant }?, luck: { strength: string, seconds: number }? }

return {
	PLAY_SECONDS = 10 * 60, -- play a day before its gift (owner 2026-11-09: "shown only after 10-15 min of play")
	TICK = 1, -- seconds between the server's play-time counts (it tells the client the moment a gift is ready)
	-- The 7-day round (Config/Items ids; luck: a Config/Luck strength, as if bought)
	DAILY = {
		{ cash = 300, items = { { item = "sparkPack", count = 1 } } },
		{ items = { { item = "xpTonic", count = 1 } } },
		{ items = { { item = "vrPack", count = 1 } } },
		{ items = { { item = "wildOre", count = 10 } } },
		{ items = { { item = "gradingSeal", count = 1 } } },
		{ items = { { item = "starShard", count = 1 } } },
		{ items = { { item = "epicPack", count = 1 } }, luck = { strength = "x2", seconds = 15 * 60 } },
	} :: { Reward },
	-- Earned on the `days`th daily gift claimed in a week (weeks start Monday, UTC)
	WEEKLY = {
		days = 5,
		reward = { cash = 1000, items = { { item = "epicPack", count = 1 }, { item = "starShard", count = 1 } } } :: Reward,
	},
	-- Earned on the `days`th daily gift claimed in a month (UTC); `overrides`: other targets by month (year * 100 +
	-- month): the launch month has 11 days left after 2026-11-20
	MONTHLY = {
		days = 20,
		overrides = { [202611] = 8 } :: { [number]: number },
		reward = { cash = 5000, items = { { item = "legendaryPack", count = 1 } }, luck = { strength = "x3", seconds = 30 * 60 } } :: Reward,
		announce = "{name} opened the Monthly Chest!", -- a toast to everyone in the server
	},
	-- The win moment (client Util/GiftWin): its title, colours (RGB; rainbow: the title runs through the rainbow), the
	-- picture that rattles (a Config/UIIcons name) or the boss chest tinted `chest`
	WIN = {
		daily = { title = "DAY {day}!", picture = "PishGift", colors = { { 255, 163, 205 }, { 255, 110, 175 } } },
		big = { title = "BIG GIFT!", picture = "PishGift", colors = { { 255, 214, 90 }, { 255, 150, 30 } }, rainbow = true },
		weekly = { title = "WEEKLY CHEST!", chest = { 150, 100, 255 }, colors = { { 191, 160, 255 }, { 130, 80, 245 } } },
		monthly = { title = "MONTHLY CHEST!", chest = { 255, 196, 60 }, colors = { { 255, 220, 110 }, { 255, 150, 30 } }, rainbow = true },
		RAYS = "rbxassetid://139701534930046", -- Config/PackFx rays (the Store's win card)
		DIM = 0.55, -- the screen behind
		DROP = 0.45, -- seconds the gift drops in
		RATTLES = { 0.5, 0.42, 0.36 }, -- seconds before each rattle, each one harder
		RATTLE_ANGLE = { 8, 13, 19 }, -- degrees
		BURST = 0.35, -- the burst's flash
		CARD_EVERY = 0.35, -- seconds between the gift cards flipping in
		CONFETTI = 60, -- pieces
		-- Config/PackOpening and Config/Victory sounds, all Roblox-licensed
		SOUNDS = {
			drop = "rbxassetid://9120798134", -- Wood Bench Hits 2 (the chests' thud)
			rattle = "rbxassetid://9120881682", -- Wood Groan Creak Opening Wood Chest Coffin 5
			rise = "rbxassetid://9120732821", -- Whoosh Rising Swish Airy Various Pitches 3
			burst = "rbxassetid://9116385087", -- Magic Burst 5
			sting = "rbxassetid://9114023753", -- Cymbal Sting 1 (the chests and the big gift)
			fanfare = "rbxassetid://1836473422", -- Victory Fanfare Sting (the monthly chest)
			card = "rbxassetid://3456145589", -- card_flip (f4ngy, Freesound, CC BY)
			coins = "rbxassetid://9113849492", -- Coins Or Keys Jingle 6
			shimmer = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer
		},
		VOLUMES = { drop = 0.3, rattle = 0.22, rise = 0.18, burst = 0.25, sting = 0.15, fanfare = 0.12, card = 0.3, coins = 0.22, shimmer = 0.2 },
	},
	-- The window's life (client Util/GiftMotion; owner 2026-11-15: "it's a bit flat. add animation that kids/player will
	-- get excited to"): seconds and px. The tiles pop in `every` s apart from `from` size, tipped up to `tilt` degrees;
	-- today's gift bobs (rattles once ready: a `hop` and `angles`), sparkles twinkle round it and the big gift, a shine
	-- sweeps the big gift and the bars, the bars fill from empty, an earned chest rattles; the HUD tile wiggles when ready
	MOTION = {
		pop = { from = 0.4, seconds = 0.45, tilt = 10, every = 0.06 },
		breathe = 0.7,
		bob = 0.9,
		bobPx = 5,
		rock = 1.4,
		rockAngle = 6,
		rattle = { hop = 6, angles = { -12, 12, -9, 9, -5, 0 }, every = 1.6 },
		sparkle = { icon = "Star", seconds = 1.1, rest = 0.5, size = { 16, 26 }, ring = { 0.55, 0.75 }, today = 3, big = 3, chest = 2 },
		shine = { seconds = 0.9, brightest = 0.45, every = 2.6 },
		fill = 0.9,
		tileWiggle = 2.4, -- the HUD tile's rattle once something's ready
	},
	-- The HUD tile (Util/Hud side, under the Phone; on a phone screen in the column under it)
	-- phoneBottom: on a phone the tile sits in the bottom-centre row (third in the side column it covered the
	-- thumbstick's resting spot; owner 2026-11-17 "make sure nothing is cutoff/overlapping on all devices")
	TILE = { icon = "PishPresent", label = "Gift", order = 5, phoneBottom = true, ready = "Open!" },
}
