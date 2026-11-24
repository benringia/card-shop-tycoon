--!strict
-- Welcome-back earnings (owner 2026-11-17: "yes do the three now"; Util/OfflineRules, OfflineService,
-- WelcomeBackController): while you're away your shop keeps selling the stock on its shelves, at your prices and their
-- buy chances (Config/Pricing BUY_BANDS), UNITS_PER_MINUTE customers' worth a minute (about a fifth of a busy shop's
-- pace), for up to MAX_MINUTES; under MIN_AWAY_MINUTES nothing. Sales pay cash and shop XP (XP_PER_CASH a dollar, as a
-- sale at the register). Plain data (tests/OfflineRules).
return {
	MIN_AWAY_MINUTES = 10,
	MAX_MINUTES = 120,
	UNITS_PER_MINUTE = 2,
	XP_PER_CASH = 1,
	-- what the welcome-back card calls each product's units ("18 packs"); customers and reviews name a missed product
	-- with it too ("No sleeves? Aww.", spec 2026-11-24-shop-variety-design)
	PLURALS = { FirstSparkPack = "packs", CardSleeves = "sleeves", DeckBox = "deck boxes", FirstSparkBox = "booster boxes", BulkCards = "bulk handfuls", FrontierPack = "Frontier packs" },
	-- Storage racks keep it going (owner 2026-11-24, pick 2; spec 2026-11-24-shop-variety-design): while a card works as
	-- Restocker, it refills the shelves from the racks' boxes, and each rack holding boxes adds RACK_MINUTES (at most
	-- MAX_EXTRA_MINUTES) of selling only what's still in the racks (OfflineRules.split, planRacks)
	RACK_MINUTES = 30,
	MAX_EXTRA_MINUTES = 120,
	-- The Welcome back card's Restocker report (WelcomeBackController; %d h: the longest away selling, in hours)
	REPORT = {
		title = "%s kept your shelves full",
		boxes = "%d boxes from your storage racks",
		box = "1 box from your storage racks",
		shelves = "%s from shelves",
		storage = "+%s from storage",
		more = "More racks of boxes: up to %d h of selling while you're away.",
		needs = "Give a card the Restocker job: your racks keep your shop selling up to %d h while you're away.",
	},
}
