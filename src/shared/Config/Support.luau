--!strict
-- "Support the dev" (owner 2026-11-12: "add a 'Support the dev' somewhere where the supporter will receive a
-- supporters aura and title"; picks: tap Pish to open it and he asks now and then, golden sparkles, the town dogs thank
-- you; three amounts on Creator Hub). Server/Services/SupportService (the gifts, the aura, the title), client
-- SupportController (the card, Pish's ask). Each tier is a Monetization PRODUCTS key; its title is a Config/Titles id.
-- Plain data.
return {
	TIERS = {
		{ product = "Support1", title = "supporter", name = "Supporter", icon = "💛", perk = "Title, golden sparkles and a glow" },
		{ product = "Support2", title = "superSupporter", name = "Superfan", icon = "💖", perk = "Title, more sparkles in pink and gold" },
		{ product = "Support3", title = "legendarySupporter", name = "Legend", icon = "🌟", perk = "Title, rainbow sparkles and a light" },
	},
	-- The aura round the best tier's character (SupportService, at its chest, seen by everyone): golden sparkles bursting
	-- out and drifting up (`rate` a second, `size` studs at their biggest) in a soft glow (`glow`: its colour and size);
	-- tier 2 pink-gold, tier 3 rainbow sparkles and a warm light
	AURA = {
		{ rate = 14, colors = { { 255, 196, 40 }, { 255, 226, 110 } }, size = 0.8, glow = { color = { 255, 205, 80 }, size = 5 } },
		{ rate = 20, colors = { { 255, 196, 40 }, { 255, 140, 200 } }, size = 0.9, glow = { color = { 255, 190, 150 }, size = 6 } },
		{ rate = 28, colors = { { 255, 110, 110 }, { 255, 210, 80 }, { 120, 220, 255 }, { 200, 140, 255 } }, size = 1, glow = { color = { 255, 220, 140 }, size = 7 }, light = { 255, 215, 140 } },
	},
	-- The same aura on the character window's stage (a ViewportFrame draws no particles: Util/StageAura draws it in 2D
	-- from shapes): the glow behind the character (`glow` of the stage's height, `glowGrow` more per tier, its `rings`
	-- stacked circles fainter outward in `glowColors[tier]`, breathing to `swell` over `breathe` seconds, centred
	-- `centre` down) and `rate[tier]` sparkles a second (SPARKLE, the 3D aura's own: owner 2026-11-13 "show the actual
	-- effects"; `sparkSize` px, rising `climb` px over `life` seconds from inside `spread` across and `rise` down) in the
	-- tier's AURA colours
	STAGE = {
		rate = { 5, 7, 10 },
		glow = 0.8,
		glowGrow = 0.08,
		glowColors = { { 255, 200, 70 }, { 255, 170, 190 }, { 255, 210, 110 } },
		rings = { { size = 1, fade = 0.9 }, { size = 0.78, fade = 0.85 }, { size = 0.58, fade = 0.8 }, { size = 0.4, fade = 0.75 } },
		swell = 1.07,
		breathe = 1.6,
		centre = 0.55,
		sparkSize = { 22, 40 },
		climb = { 40, 75 },
		life = { 1.2, 1.8 },
		spread = { 0.28, 0.72 },
		rise = { 0.35, 0.85 },
	},
	SPARKLE = "rbxasset://textures/particles/sparkles_main.dds", -- Roblox's own sparkle (bold enough to read in daylight)
	GLOW = "rbxassetid://111832033900052", -- Config/AttackFx TEXTURES.glow
	CARD = {
		title = "💛 Support the dev",
		-- Pish and Chikin holding a golden heart (owner 2026-11-13: the card back's medallion was hard to see; Figma
		-- generated, cut out by tools/ui-art/cutout.py: assets/ui/support/SupportDogs.png)
		picture = "rbxassetid://131467700155398",
		pictureHeight = 140,
		line = "Made by one dev and two dogs. Thank you for playing!",
		gifts = "You've supported %d time%s. Thank you!",
		yours = "Yours!",
		replay = "Replay a tour",
	},
	THANKS = "Thank you so much! You're a %s now! 💛", -- the toast after a gift (%s: the tier's name)
	THANKS_AGAIN = "Thank you again! 💛", -- a gift that doesn't raise the tier
	-- The thank-you after a gift (owner 2026-11-12: "both dogs running towards the player, then saying something like
	-- 'thank you, for your support, this is for you' and then a glow slowly coming out the players body"; client
	-- ThanksController): Pish and Chikin run in from `run.from` studs (the first clear way of their `pish` / `chikin`
	-- angles from the player's front, Util/ArrivalShot.pickRun) to `stop` studs in front, `side` apart, and say their
	-- `lines`; then a golden glow rises out of the player for `glow.seconds`; the server's aura and title appear at
	-- `reveal` (SupportService), as the glow ends; the dogs hop and vanish in stars. Seconds in `at` count from the start.
	-- Mid-fight, a tour or another cinematic: only the glow (Util/SupportRules.thanksMode).
	CINEMATIC = {
		reveal = 8.2,
		at = { talkPish = 2.4, talkChikin = 4.6, glow = 5.6, leave = 8.9, done = 9.9 },
		run = { from = 16, minRun = 6, wallGap = 1.5, stop = 3.5, side = 5, speed = 7, pish = { 35, 60, 15, 90, 120 }, chikin = { -35, -60, -15, -90, -120 } },
		camera = { back = 10, side = 1.5, up = 4.5, close = { back = 7.5, side = 1, up = 2.8 }, follow = 3 }, -- studs off the player: in front, to their right, up
		lines = { pish = "Thank you for your support, %s!", chikin = "This is for you! 💛" },
		bubbles = { pish = { up = 4.2, edge = { 150, 170, 255 } }, chikin = { up = 4.6, edge = { 255, 150, 110 } } },
		glow = { seconds = 2.6, color = { 255, 205, 80 }, sound = "rbxassetid://9116418035", volume = 0.6 }, -- Magic Tone Falling Shimmer
	},
	-- Pish asks after a good moment (a boss win, a big pull), `delay` seconds later (after its screens), once a session
	NUDGE = { delay = 10, text = "Enjoying the shop? Tap me to help Chikin and me! 💛" },
}
