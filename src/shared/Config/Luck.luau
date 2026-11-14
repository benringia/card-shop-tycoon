--!strict
-- Luck bought with Robux (owner 2026-11-14: "LUCK BOOSTER for ROBUX", the products made on Creator Hub, ids in
-- Config/Monetization PRODUCTS; Util/BoughtLuck, Server/Services/LuckService, the Phone's Store app). It raises your own
-- packs' last card from Very Rare up, like Pish's Luck (which still adds on top): each purchase adds time to its
-- strength, the strongest runs first and only it runs down, and only while you play (saved, every place). Plain data.
return {
	-- Each product: the strength it adds time to and how many seconds. Prices live on Creator Hub (managed pricing on,
	-- so the Store reads them live: 2026-11-14 R$ 29 / 49 / 139)
	-- badge: a tag on its Store tile (true ones only: the 30 min is the cheaper per minute; nothing like "most
	-- popular" without sales to back it)
	PRODUCTS = {
		Luck15 = { strength = "x2", seconds = 15 * 60 },
		Luck30 = { strength = "x2", seconds = 30 * 60, badge = "BEST VALUE" },
		SuperLuck30 = { strength = "x3", seconds = 30 * 60, badge = "BEST LUCK" },
	},
	STORE = { "Luck15", "Luck30", "SuperLuck30" }, -- the Store's rows, in order
	-- boost: added to the Very Rare, Epic and Legendary weights of the last card (Util/LuckRules.boost; 1 doubles them)
	STRENGTHS = {
		x2 = { boost = 1, name = "2x Luck", icon = "🍀" },
		x3 = { boost = 2, name = "3x Super Luck", icon = "🌈" },
	},
	ORDER = { "x3", "x2" }, -- the strongest first
	FROM_RARITY = "Very Rare",
	MAX_SECONDS = 6 * 3600, -- most time a strength can hold
	TICK = 1, -- seconds between the server's countdown steps
	-- The win card the moment a purchase goes through (owner 2026-11-14 "make it feel like a WIN"; client
	-- StoreWinController): light rays, the picture spinning in, the title big, the line ({minutes}: the time bought),
	-- the Support gift's shimmer, clovers bursting round you
	WIN = {
		x2 = { title = "2x LUCK!", text = "{minutes} minutes of luckier packs!", colors = { { 70, 225, 130 }, { 15, 140, 80 } } },
		x3 = { title = "SUPER LUCK!", text = "{minutes} minutes of super lucky packs!", colors = { { 190, 120, 255 }, { 90, 60, 200 } }, rainbow = true },
		jobslot = { title = "+1 WORKER!", text = "A second card can work in your shop!", colors = { { 255, 210, 90 }, { 220, 140, 20 } } },
		SECONDS = 2.6,
		SOUND = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer (Config/Support)
		RAYS = "rbxassetid://139701534930046", -- Config/PackFx rays
	},
	-- The lucky aura while bought luck runs (owner 2026-11-14: "there should be a lucky aura around the character while
	-- the lucky buff that is bought from the store is active"): built by the server on the character so everyone sees
	-- it (LuckService), the running strength's look: four-leaf clovers (CLOVER, white, tinted with `clovers` over
	-- their life; tools/textures/make_luck_clover.py) floating out of the body and up, `rate` a second, golden glints
	-- (`glints`, GLINT_RATE) and a soft glow (`glow`). 3x Super Luck's clovers run through the rainbow.
	AURA = {
		CLOVER = "rbxassetid://95135931686221",
		SPARKLE = "rbxasset://textures/particles/sparkles_main.dds",
		GLOW = "rbxassetid://111832033900052", -- Config/AttackFx TEXTURES.glow, as the supporter aura's
		CLOVER_SIZE = 0.6,
		GLINT_RATE = 6,
		x2 = { rate = 9, clovers = { { 70, 200, 95 }, { 150, 240, 120 } }, glints = { 255, 225, 110 }, glow = { 120, 235, 135 } },
		x3 = {
			rate = 13,
			clovers = { { 255, 110, 120 }, { 255, 205, 80 }, { 110, 220, 120 }, { 110, 190, 255 }, { 200, 140, 255 } },
			glints = { 255, 240, 170 },
			glow = { 255, 225, 150 },
		},
	},
}
