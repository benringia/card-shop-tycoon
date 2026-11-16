--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8, DESIGN.md 7.2): the total XP to reach level n is
-- BASE_XP x (n - 1) ^ POWER, rounded to ROUND_TO. Lv 20, where shop jobs open, needs about 13,500 XP: 2.7x sooner
-- than round 4's 36,000 (owner 2026-11-16: "maybe adjust the shop leveling. I think it takes too long to level up";
-- picked 2.7x faster), the unlocks staying at their levels. XP keeps counting past MAX_LEVEL; the level doesn't.
-- What each level unlocks comes from the unlockLevel fields in Products and Shelves (and Jobs, Swords, Bosses).
-- Plain numbers only so Lune unit tests can load this file.
return {
	BASE_XP = 15, -- Lv 2 (round 4: 40)
	POWER = 2.31,
	ROUND_TO = 10,
	MAX_LEVEL = 100,
	-- Level-up rewards (EconomyService pays the cash; LevelUpService gives the gifts; the middle card shows them,
	-- Util/LevelUpCard). Owner 2026-11-16: "small cash every level. only give gift every 5 levels (wild ores and etc)
	-- make sure its not economy breaking": all 100 levels give 30 Wild Ore, 10 XP Tonics, 10 packs and 4 Gold Seals
	-- (tests/LevelUpRules)
	REWARD_CASH_PER_LEVEL = 4, -- $4 x the new level: $8 at Lv 2, $400 at Lv 100 (was $10 x before levels came 2.7x faster)
	MILESTONE_EVERY = 10, -- the rainbow pillar (Config/LevelUpFx)
	GIFT_EVERY = 5, -- a gift on every 5th level: by the level's last digit (Config/Items ids, Bag items)
	GIFTS = {
		[5] = { { item = "wildOre", count = 3 }, { item = "xpTonic", count = 1 } },
		[0] = { { item = "sparkPack", count = 1 } },
	},
	EXTRA_EVERY = 25, -- and this on every 25th
	EXTRA = { item = "goldSeal", count = 1 },
	PACK_OPEN_COOLDOWN = 1, -- seconds between opening Bag packs (the server's rate limit)
}
