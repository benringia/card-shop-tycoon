--!strict
-- Daily quests (owner 2026-11-17: "yes do the three now"; Util/QuestRules, QuestService, QuestController): each UTC day
-- one quest of each KIND, picked from POOL among those unlocked at the shop's level, its goal from the last `goals` band
-- at or under the level; each pays REWARD (cash and shop XP, more for a bigger shop) and all three claimed open BONUS.
-- `event`: what counts toward it (QuestService hears it from the game: EVENTS). `{n}` in `text` is the goal. `icon`:
-- a Config/UIIcons name. Quests start once Pish's first visit is over, like the gifts. Plain data (tests/QuestRules).
return {
	KINDS = { "shop", "cards", "adventure" },
	EVENTS = { "serve", "earn", "stock", "rip", "levelCreature", "winWild", "winBoss" },
	POOL = {
		-- shop
		{ id = "serve", kind = "shop", event = "serve", icon = "Customer", text = "Serve {n} customers",
			goals = { { level = 1, goal = 3 }, { level = 6, goal = 6 }, { level = 15, goal = 10 }, { level = 30, goal = 15 } } },
		{ id = "earn", kind = "shop", event = "earn", icon = "Cash", text = "Earn ${n} from sales",
			goals = { { level = 1, goal = 25 }, { level = 6, goal = 80 }, { level = 15, goal = 250 }, { level = 30, goal = 600 } } },
		{ id = "stock", kind = "shop", event = "stock", icon = "Box", text = "Put {n} boxes on shelves",
			goals = { { level = 1, goal = 2 }, { level = 8, goal = 4 }, { level = 20, goal = 6 } } },
		-- cards
		{ id = "rip", kind = "cards", event = "rip", icon = "Pack", text = "Rip {n} packs",
			goals = { { level = 1, goal = 3 }, { level = 6, goal = 5 }, { level = 15, goal = 8 }, { level = 30, goal = 12 } } },
		{ id = "levelCreature", kind = "cards", event = "levelCreature", icon = "Level", text = "Level up creatures {n} times",
			minLevel = 3, goals = { { level = 3, goal = 2 }, { level = 12, goal = 3 }, { level = 30, goal = 5 } } },
		-- adventure
		{ id = "wild", kind = "adventure", event = "winWild", icon = "Sword", text = "Win {n} wild fights",
			goals = { { level = 1, goal = 2 }, { level = 6, goal = 4 }, { level = 15, goal = 6 }, { level = 30, goal = 10 } } },
		{ id = "boss", kind = "adventure", event = "winBoss", icon = "Trophy", text = "Beat a boss {n} times",
			minLevel = 4, goals = { { level = 4, goal = 1 }, { level = 26, goal = 2 } } },
	},
	-- each quest: cash and shop XP of `cash` + `cashPerLevel` x the shop level ($18 at Lv 1, $105 at Lv 30)
	REWARD = { cash = 15, cashPerLevel = 3, xp = 15, xpPerLevel = 3 },
	-- all three claimed: the Quest Chest (Config/Items ids)
	BONUS = { { item = "sparkPack", count = 1 }, { item = "xpTonic", count = 1 } },
	TICK = 30, -- seconds between the server's checks for a new UTC day
	-- The strip at the top right (client Util/QuestStrip, owner 2026-11-17: "add design/immersive animations on the quest
	-- strip", look A of artifact XyGHP2ku71fRaYeuEkGZ6D): pixels and seconds. `bubbles`: each quest's icon bubble in
	-- its kind's baby colour; the band's shine passes every `shineEvery` s, the scroll wiggles every `wiggleEvery` s, each
	-- bar's shine every `barShineEvery` s; the bubbles float `float` px up and down over `floatSeconds`. Its chevron
	-- (owner 2026-11-17: "can we make the quest window minimizable/hideable?") folds it to the band, and on a phone to
	-- `phoneFolded` px (the scroll and the chip), for the session (a new day's quests show it open again).
	STRIP = {
		width = 250, phoneWidth = 176, phoneFolded = 112, band = 28, phoneBand = 34, rowHeight = 32, rowGap = 5, pad = 8,
		bubbles = { shop = "mint", cards = "sky", adventure = "peach" },
		shineEvery = 5, wiggleEvery = 4, barShineEvery = 3.5,
		float = 2, floatSeconds = 1.5,
		fillSeconds = 0.6, confetti = 7,
	},
}
