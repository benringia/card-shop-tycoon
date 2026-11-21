--!strict
-- The Recycler (owner 2026-11-21: "we also neeed a way to get rid of thousands of other copies of other rarities. we
-- already have commons", then "can we have add a recycler. that can make extra cards turn into upgrade materials. make
-- sure the costs are fair"; layout A of artifact UjbnCvUyswFQ7d1vQSrW7R): a shop machine (Config/Shelves `SHELF`,
-- kind "Recycler") that turns the binder's extra Rares, Very Rares, Epics and Legendaries into upgrade materials.
-- Each rarity always makes the same material, `per` extras to one. Extras (Util/RecycleRules.piles): a card's plain
-- copies (never foils) of the `GRADES` past what it still needs for its missing stars and grades plus `SPARE`, so
-- recycling never slows your own upgrades. Commons stay with the Bulk Bin.
--
-- Fair costs (tests/RecycleRules): a pile gives back about a tenth of what its cards are worth, counted at Turts' own
-- value for the material (Config/Turts `value`: its cost in farming time). 5,000 packs ($10,000) of extras with every
-- card maxed make about 51 Wild Ore, 10 XP Tonics and 9 Star Shards (some 23 Star Shards' worth), where the same 80
-- minutes of late boss fights drop about 17 Star Shards and their seals: recycling tops playing up and never beats it.
-- A Legendary gives most of its worth, since a spare one only exists once that card has every star and Grade S.
-- No Grading Seals or Gold Seals (the Grade S chase keeps its price). Materials can't be sold: no money loop.
-- Plain data (no Color3) so Lune can load it.
return {
	SHELF = "Recycler",
	ORDER = { "Rare", "Very Rare", "Epic", "Legendary" }, -- the window's rows, top to bottom
	RECIPES = {
		Rare = { per = 80, item = "wildOre" },
		["Very Rare"] = { per = 60, item = "xpTonic" },
		Epic = { per = 60, item = "starShard" },
		Legendary = { per = 1, item = "starShard" },
	} :: { [string]: { per: number, item: string } },
	-- Coins instead (owner 2026-11-21: "on recycler add. convert to coins. for players who just need coins"): every
	-- extra card of a rarity for this much cash, no leftovers. About an eighth of a card's worth, like the materials;
	-- this pay has no pace of its own (no customer, no case slot), so a pack's cards never recycle for half its price
	-- (a pack's at the most $0.64 of $2, a Deck Box's $1.68 of $6: tests/RecycleRules)
	COINS = { Rare = 0.2, ["Very Rare"] = 0.5, Epic = 1.5, Legendary = 15 } :: { [string]: number },
	MODES = { "materials", "coins" }, -- the window's switch
	MODE_WORDS = { materials = "Upgrade stuff", coins = "Coins" } :: { [string]: string },
	-- Every conversion takes time (owner 2026-11-21: "then add timers for every conversion"): the machine is a timed
	-- station like the Condenser (UpgradeJobService "recycler": one job at a time, what it makes given when the time is
	-- up, also while away; Finish now works on it). Seconds for each material made, and for each dollar of coins,
	-- between MIN_SECONDS and MAX_SECONDS: 5 Wild Ore 1:40, $87.60 1:28, a whole binge an hour at the most
	SECONDS = { wildOre = 20, xpTonic = 40, starShard = 60 } :: { [string]: number },
	SECONDS_PER_DOLLAR = 1,
	MIN_SECONDS = 10,
	MAX_SECONDS = 3600,
	SPARE = 2, -- copies a card keeps past what its stars and grades still need
	GRADES = { C = true, B = true }, -- only these are ever recycled (an A or S stays in your binder)
	GRADE_ORDER = { "S", "A", "B", "C" }, -- best first: the copies a card keeps are its best ones

	ACTION_COOLDOWN = 0.5, -- seconds between recycle requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, the window closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the buttons stay locked waiting for the server (client)

	-- The window's words
	PLURALS = { Rare = { "Rare", "Rares" }, ["Very Rare"] = { "Very Rare", "Very Rares" }, Epic = { "Epic", "Epics" }, Legendary = { "Legendary", "Legendaries" } } :: { [string]: { string } },
	ITEM_WORDS = { wildOre = { "Wild Ore", "Wild Ore" }, xpTonic = { "XP Tonic", "XP Tonics" }, starShard = { "Star Shard", "Star Shards" } } :: { [string]: { string } },
	EXPLAIN = "Turn extra cards into upgrade stuff!",
	EXPLAIN_COINS = "Turn extra cards into coins!",
	SAFE = "Cards you still need stay safe. So do foils and Grade A and S.", -- one line under the big button

	-- The machine's code-built look (Util/Props buildRecycler), bottom centre at the origin, front -Z: a dark plinth
	-- with a green rim, a white body with a RECYCLER strip and a green band, and an open hopper on top with a heap of
	-- cards in the rarities' colours
	LOOK = {
		SHELL = { 244, 246, 250 },
		DARK = { 36, 44, 52 },
		GLOW = { 80, 220, 130 },
		-- the cards heaped in the hopper, in the four rarities' colours (Config/Rarities) in turn
		CARD_COLORS = { { 70, 140, 255 }, { 40, 210, 200 }, { 170, 80, 255 }, { 255, 200, 40 } },
		BASE_RADIUS = 2.6,
		PLINTH_HEIGHT = 0.5,
		BODY_RADIUS = 2.25,
		BODY_HEIGHT = 3.1, -- plinth and body together
		HOPPER_RADIUS = 1.7,
		HOPPER_HEIGHT = 1.1,
		HOPPER_WALL = 0.18,
		CARD_SIZE = { 0.72, 0.05, 1.0 }, -- a card lying in the hopper
		CARDS = 7, -- cards heaped in it
		SCREEN_TEXT = "RECYCLER",
	},
}
