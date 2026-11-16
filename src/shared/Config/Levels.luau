--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8, DESIGN.md 7.2): the total XP to reach level n is
-- BASE_XP x (n - 1) ^ POWER, rounded to ROUND_TO. Lv 20, where shop jobs open, needs about 6,000 XP: 6x sooner
-- than round 4's 36,000 (owner 2026-11-16: "it takes too long to level up", 2.7x; then 2026-11-17: "I just want the
-- fast level to be the retention mechanism make the players feel progress always ... make it like 4", and the same
-- day "is it not game breaking upping it to 6x?"; the real grind is upgrading and maxing cards and weapons), the
-- unlocks staying at their levels. XP keeps counting past MAX_LEVEL; the level doesn't.
-- What each level unlocks comes from the unlockLevel fields in Products and Shelves (and Jobs, Swords, Bosses).
-- Plain numbers only so Lune unit tests can load this file.
return {
	BASE_XP = 40 / 6, -- round 4's 40, 6x faster (15 at 2.7x, 10 at 4x)
	POWER = 2.31,
	ROUND_TO = 10,
	MAX_LEVEL = 100,
	-- Level-up rewards (EconomyService pays the cash; LevelUpService gives the gifts; the middle card shows them,
	-- Util/LevelUpCard). Owner 2026-11-16: "small cash every level. only give gift every 5 levels (wild ores and etc)
	-- make sure its not economy breaking": all 100 levels give 30 Wild Ore, 10 XP Tonics, 10 packs and 4 Gold Seals
	-- (tests/LevelUpRules)
	REWARD_CASH_PER_LEVEL = 2, -- $2 x the new level: $4 at Lv 2, $200 at Lv 100 (cash per hour about as before: $10 x at round 4's pace)
	-- Shop XP from fights (owner 2026-11-17: "can we add a small exp to the shop from killing monsters. combat exp for
	-- pets stays the same"): a won fight gives this much shop XP per $1 it paid (a sale gives 1 per $1), at least 1:
	-- a Meadow monster 1, a Rift one 7-10 (elites 3x), the Meadow Warden 18, the Prism Hydra 200 (LevelMath.fightXp)
	FIGHT_XP_PER_CASH = 0.5,
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
