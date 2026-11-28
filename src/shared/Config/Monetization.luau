--!strict
-- Game pass and developer product IDs. Create them on Creator Hub (your experience -> Monetization ->
-- Passes), then paste the ID here. 0 means "not created yet": the game treats it as not owned and the UI
-- shows "Coming soon".
return {
	PASSES = {
		ExtraJobSlot = 0, -- +1 shop job slot (DESIGN 8); sold as the developer product below (UNLOCKS) instead
		-- Robux round (spec 2026-11-28-robux-round-design; R$ 149 / 99 / 149 on Creator Hub, managed pricing on): VIP (a
		-- gold name with a crown, a [VIP] chat tag, the VIP Lounge look), Quick Open (Open 50 in the Bag), Night Shift
		-- (the welcome-back limits doubled)
		VIP = 0,
		QuickOpen = 0,
		NightShift = 0,
		StarterPack = 0, -- sold as the one-time developer product below (UNLOCKS); a pass key so every check counts it
	},
	-- Pass keys sold as one-time developer products and saved (owner 2026-11-14 made the Extra Job Slot a developer
	-- product): MonetizationService counts a bought one as owning the pass, never sells it twice (Util/UnlockRules)
	UNLOCKS = { "ExtraJobSlot", "StarterPack" },
	-- Unlocks holding something chance-based (the Starter Pack's 2x Luck): not shown or sold where Roblox restricts paid
	-- random items (Util/PaidRandomRules), like the luck boosts
	CHANCE = { StarterPack = true },
	-- The Store's "Forever" list, in order (Util/StoreRules, StoreController), the ones tagged NEW and until when
	-- (2027-01-01 00:00 UTC: true while they're new), and each one's words (icon, name, short line, its win chip)
	FOREVER = { "VIP", "QuickOpen", "NightShift", "ExtraJobSlot" },
	NEW = { VIP = true, QuickOpen = true, NightShift = true },
	NEW_UNTIL = 1798761600,
	STORE = {
		VIP = { icon = "👑", name = "VIP", line = "Shine in town", win = "Gold name + VIP look" },
		QuickOpen = { icon = "⚡", name = "Quick Open", line = "Open 50 at once", win = "Open 10 becomes Open 50" },
		NightShift = { icon = "🌙", name = "Night Shift", line = "Sell while away", win = "Away selling 2 h to 4 h" },
		ExtraJobSlot = { icon = "💼", name = "Extra Job Slot", line = "A second worker", win = "+1 worker, forever" },
		-- the banner on top of the Store while it's for sale (StoreRules.showStarter)
		StarterPack = {
			icon = "🎁",
			name = "Starter Pack",
			line = "One time only",
			chips = { "Sunny Shop look", '"Shop Starter" title', "2x Luck · 30 min" },
			tag = "ONE TIME",
		},
	},
	-- Each pass's and unlock's win card the moment it's granted (Config/Luck WIN, StoreWinController)
	WIN_KINDS = {
		ExtraJobSlot = "jobslot",
		StarterPack = "starter",
		VIP = "vip",
		QuickOpen = "quickopen",
		NightShift = "nightshift",
	},
	CHECK_RETRY_SECONDS = 60, -- after a failed ownership check, wait this long before asking Roblox again
	-- Developer products (spec 2026-11-12-timed-upgrades-revive-design; PurchaseService). Create each on Creator Hub (the
	-- experience -> Monetization -> Developer Products -> Create), set its price there and paste its ID here; 0 means
	-- "not created yet": its button says "Coming soon". Prices are set on Creator Hub (2026-11-12: Revive R$ 25, SkipS
	-- R$ 12, SkipM R$ 30, SkipL R$ 70; Support R$ 160 / 325 / 510, managed pricing off). A product nothing grants yet is answered NotProcessedYet, so
	-- Roblox asks again once a server can grant it.
	PRODUCTS = {
		Revive = 3730642737, -- stand up where you were knocked out, your cards rested (KnockoutService)
		SkipS = 3730643098, -- "Finish now" for a station job with up to 5 minutes left (UpgradeJobService)
		SkipM = 3730643201, -- up to 20 minutes
		SkipL = 3730643344, -- up to 1 hour
		-- "Support the dev" (Config/Support TIERS, SupportService): Donate 160 / 325 / 510 on Creator Hub
		Support1 = 3730645585,
		Support2 = 3730651831,
		Support3 = 3730651906,
		-- Turts' rug shop: "restock now", a fresh roll of offers for that player until the next restock (TurtsService);
		-- about 49 R$ on Creator Hub
		TurtsRestock = 3730861834,
		-- Luck for your packs (Config/Luck, LuckService, the Phone's Store; owner 2026-11-14): 2x Luck 15 / 30 min and
		-- 3x Super Luck 30 min, managed pricing on (R$ 29 / 49 / 139 when made), so the Store reads prices live
		Luck15 = 3731134842,
		Luck30 = 3731135110,
		SuperLuck30 = 3731135276,
		-- The Extra Job Slot, one time (UNLOCKS): R$ 160 when made, managed pricing on
		ExtraJobSlot = 3731134573,
		-- Every boss's loot timer ended at once (Bosses.RESET, BossService; owner 2026-11-19, pick A): R$ 20, managed
		-- pricing on (the Philippines R$ 8), so its buttons read the price live
		BossReset = 3733394373,
		-- The Starter Pack, one time (UNLOCKS; spec 2026-11-28-robux-round-design): the Sunny Shop look, the "Shop
		-- Starter" title and 30 minutes of 2x Luck; R$ 99, managed pricing on
		StarterPack = 0,
	},
	PURCHASE_MEMORY = 100, -- receipts remembered in a save, so a retried one is never granted twice
}
