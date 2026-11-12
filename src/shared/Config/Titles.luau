--!strict
-- Titles over a player's name (owner 2026-11-12: "add TITLES tab on the character menu, I'm planning to add titles
-- system"; 2026-11-13: "add more titles that is obtainable in game"): one list, so new titles only add rows. `check`
-- (Util/TitleRules): "bossClear" (that boss cleared), "bosses" (every one of them cleared), "secret" (the Dungeon's
-- secret chest found), "supporter" (a "Support the dev" gift of that tier or higher, Config/Support), "level" (shop
-- level), "stat" (a lifetime counter: packsOpened, customersServed, totalEarned), "cards" (different cards owned),
-- "set" (every card of a set: its id prefix, `count` cards), "rarity" (cards of a rarity owned), "pvp" (duels won).
-- Once earned a title stays earned (TitleService saves it). The player picks one in the character window (saved
-- data.title; "" = automatic: the first earned in ORDER, so the rarest come first).
-- Names plain ASCII and short (owner 2026-11-12: "lets do gradient, and shorter", after other games' one- or two-word
-- titles); over the head (TitleController) `icon` (an emoji) then the name, small, in its `gradient` (left to right),
-- `shimmer`: a slow light sweep (supporter titles). `color`: the title's one colour in lists.
local WILD = { "meadowWarden", "caveBroodQueen", "emberColossus" }
local FRONTIER = { "frostTyrant", "stormSovereign", "riftDevourer" }

return {
	ORDER = {
		"legendarySupporter", "superSupporter", "supporter",
		"dungeonConqueror", "champion", "cardMogul", "millionaire", "setMaster", "trailblazer",
		"tycoon", "shopStar", "wildHunter", "luckyStar", "duelist", "crystalSeeker",
		"collector", "packRipper", "shopkeeper",
	},
	ById = {
		dungeonConqueror = {
			name = "Hydra Slayer",
			color = { 255, 200, 70 },
			gradient = { { 255, 225, 110 }, { 255, 160, 50 } },
			icon = "🐉",
			how = "Beat the Prism Hydra",
			check = { kind = "bossClear", boss = "prismHydra" },
		},
		crystalSeeker = {
			name = "Seeker",
			color = { 170, 140, 255 },
			gradient = { { 150, 225, 255 }, { 185, 140, 255 } },
			icon = "💎",
			how = "Find the Dungeon's secret chest",
			check = { kind = "secret" },
		},
		supporter = {
			name = "Supporter",
			color = { 255, 205, 80 },
			gradient = { { 255, 230, 120 }, { 255, 175, 60 } },
			shimmer = true,
			icon = "💛",
			how = "Support the dev (tap Pish)",
			check = { kind = "supporter", tier = 1 },
		},
		superSupporter = {
			name = "Superfan",
			color = { 255, 140, 195 },
			gradient = { { 255, 215, 110 }, { 255, 130, 190 } },
			shimmer = true,
			icon = "💖",
			how = "Give a Superfan gift (tap Pish)",
			check = { kind = "supporter", tier = 2 },
		},
		legendarySupporter = {
			name = "Legend",
			color = { 255, 185, 60 },
			gradient = { { 255, 140, 120 }, { 130, 200, 255 } },
			shimmer = true,
			icon = "🌟",
			how = "Give a Legend gift (tap Pish)",
			check = { kind = "supporter", tier = 3 },
		},
		shopkeeper = {
			name = "Shopkeeper",
			color = { 255, 180, 110 },
			gradient = { { 255, 210, 140 }, { 255, 150, 90 } },
			icon = "🛒",
			how = "Reach shop level 10",
			check = { kind = "level", min = 10 },
		},
		tycoon = {
			name = "Tycoon",
			color = { 255, 170, 80 },
			gradient = { { 255, 220, 120 }, { 255, 120, 80 } },
			icon = "🏪",
			how = "Reach shop level 30",
			check = { kind = "level", min = 30 },
		},
		cardMogul = {
			name = "Card Mogul",
			color = { 220, 160, 255 },
			gradient = { { 255, 220, 90 }, { 190, 120, 255 } },
			icon = "👑",
			how = "Reach shop level 50",
			check = { kind = "level", min = 50 },
		},
		millionaire = {
			name = "Millionaire",
			color = { 130, 220, 110 },
			gradient = { { 180, 240, 120 }, { 255, 210, 70 } },
			icon = "💰",
			how = "Earn $1,000,000 from sales",
			check = { kind = "stat", stat = "totalEarned", min = 1000000 },
		},
		shopStar = {
			name = "Shop Star",
			color = { 255, 150, 170 },
			gradient = { { 255, 200, 120 }, { 255, 120, 170 } },
			icon = "🎉",
			how = "Serve 1,000 customers",
			check = { kind = "stat", stat = "customersServed", min = 1000 },
		},
		packRipper = {
			name = "Pack Ripper",
			color = { 255, 160, 100 },
			gradient = { { 255, 200, 120 }, { 255, 130, 80 } },
			icon = "📦",
			how = "Open 100 packs",
			check = { kind = "stat", stat = "packsOpened", min = 100 },
		},
		luckyStar = {
			name = "Lucky Star",
			color = { 140, 220, 120 },
			gradient = { { 140, 240, 140 }, { 255, 230, 90 } },
			icon = "🍀",
			how = "Pull a Legendary card",
			check = { kind = "rarity", rarity = "Legendary", min = 1 },
		},
		collector = {
			name = "Collector",
			color = { 200, 160, 255 },
			gradient = { { 255, 160, 200 }, { 150, 170, 255 } },
			icon = "🃏",
			how = "Own 20 different cards",
			check = { kind = "cards", min = 20 },
		},
		setMaster = {
			name = "Set Master",
			color = { 130, 170, 255 },
			gradient = { { 120, 200, 255 }, { 160, 120, 255 } },
			icon = "📖",
			how = "Own every First Spark card",
			check = { kind = "set", set = "FS", count = 35 },
		},
		wildHunter = {
			name = "Wild Hunter",
			color = { 110, 200, 110 },
			gradient = { { 150, 235, 120 }, { 60, 180, 90 } },
			icon = "🌿",
			how = "Beat all three Wild bosses",
			check = { kind = "bosses", bosses = WILD },
		},
		trailblazer = {
			name = "Trailblazer",
			color = { 130, 170, 255 },
			gradient = { { 150, 225, 255 }, { 120, 140, 255 } },
			icon = "🧭",
			how = "Beat all three Frontier bosses",
			check = { kind = "bosses", bosses = FRONTIER },
		},
		duelist = {
			name = "Duelist",
			color = { 240, 120, 110 },
			gradient = { { 255, 170, 120 }, { 230, 90, 90 } },
			icon = "🥊",
			how = "Win 10 duels in the Arena",
			check = { kind = "pvp", min = 10 },
		},
		champion = {
			name = "Champion",
			color = { 255, 160, 80 },
			gradient = { { 255, 215, 80 }, { 255, 90, 90 } },
			icon = "🏅",
			how = "Win 50 duels in the Arena",
			check = { kind = "pvp", min = 50 },
		},
	},
	MAX_SAVED = 40, -- a saved title id longer than this is junk (automatic)
	EQUIP_COOLDOWN = 0.5, -- seconds between equips (the remote's rate limit)
	CHECK_SECONDS = 5, -- how often TitleService looks for newly earned titles (counters change all the time)
}
