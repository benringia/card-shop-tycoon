--!strict
-- The Bulk Bin (owner 2026-11-17: "what happens when a really active player plays non stop and end up like 1000 common
-- cards. we need a way to get rid those right?", then option C of artifact XyGHP2ku71fRaYeuEkGZ6D, "lets do C"): a shop
-- fixture (Config/Shelves `SHELF`, a Products shelf that only takes `PRODUCT`) you fill with your extra Commons from
-- the binder, `PER` to a handful; customers buy handfuls like any product (the register, your price, offline sales).
-- Extras (Util/BulkRules.extras): copies of a `RARITIES` card past the `KEEP` best you always keep, never foils, only
-- the `GRADES` (an A or S stays in your binder). A customer of a kind in `CHANCE` adds a handful to their list at that
-- chance, only while one of your bins has some (they never ask for bulk a shop can't sell). Plain data (tests/BulkRules).
return {
	PRODUCT = "BulkCards",
	SHELF = "BulkBin",
	PER = 5,
	KEEP = 2,
	RARITIES = { Common = true },
	GRADES = { C = true, B = true },
	GRADE_ORDER = { "S", "A", "B", "C" }, -- best first: the copies you keep are your best ones
	CHANCE = { kid = 0.35, plain = 0.2, bargain = 0.4 },
	-- the bin's code-built look (Util/Props): a wooden crate with corner posts and a sign; the handfuls inside
	-- (Util/BulkHandful) are card backs printed with the shop's medallion
	LOOK = {
		WOOD = { 196, 140, 86 },
		DARK = { 120, 78, 42 },
		SIGN = { 255, 248, 232 },
		SIGN_TEXT = { 120, 78, 42 },
		WALL = 0.82, -- the crate's walls, as a share of its height
		THICK = 0.18, -- wall thickness, studs
		SIGN_TEXT_LINE = "BULK CARDS",
		CARD = { 0.52, 0.72 }, -- a card's width and height in a handful, studs
		CARD_BACK = { 52, 40, 110 },
	},
}
