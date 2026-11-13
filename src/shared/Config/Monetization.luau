--!strict
-- Game pass and developer product IDs. Create them on Creator Hub (your experience -> Monetization ->
-- Passes), then paste the ID here. 0 means "not created yet": the game treats it as not owned and the UI
-- shows "Coming soon".
return {
	PASSES = {
		ExtraJobSlot = 0, -- +1 shop job slot (DESIGN 8)
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
		TurtsRestock = 0,
	},
	PURCHASE_MEMORY = 100, -- receipts remembered in a save, so a retried one is never granted twice
}
