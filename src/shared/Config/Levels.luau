--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8, DESIGN.md 7.2): the total XP to reach level n is
-- BASE_XP x (n - 1) ^ POWER, rounded to ROUND_TO. POWER puts Lv 20 at about 36,000 XP, where shop jobs open (the old
-- Lv 10), so every unlock keeps about the XP it needed before. XP keeps counting past MAX_LEVEL; the level doesn't.
-- What each level unlocks comes from the unlockLevel fields in Products and Shelves (and Jobs, Swords, Bosses).
-- Plain numbers only so Lune unit tests can load this file.
return {
	BASE_XP = 40, -- Lv 2
	POWER = 2.31,
	ROUND_TO = 10,
	MAX_LEVEL = 100,
	-- Level-up rewards (EconomyService pays the cash; LevelUpService gives the pack)
	REWARD_CASH_PER_LEVEL = 10, -- $10 x the new level: $20 at Lv 2, $1,000 at Lv 100
	PACK_EVERY = 10, -- a pack on every 10th level
	PACK_ITEM = "sparkPack", -- the Bag item it gives (Config/Items)
	PACK_OPEN_COOLDOWN = 1, -- seconds between opening Bag packs (the server's rate limit)
}
