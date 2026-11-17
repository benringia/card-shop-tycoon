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
	-- what the welcome-back card calls each product's units ("18 packs")
	PLURALS = { FirstSparkPack = "packs", CardSleeves = "sleeves", DeckBox = "deck boxes", FirstSparkBox = "booster boxes" },
}
