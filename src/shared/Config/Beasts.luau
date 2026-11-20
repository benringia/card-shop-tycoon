--!strict
-- Glimmerbeast growth, stats and value. See DESIGN.md section 5.8 and the beast cards spec.
-- Plain numbers only (no Roblox types) so Lune unit tests can load this file.
return {
	MAX_LEVEL = 30,
	START_STARS = 0, -- every card starts with no stars
	MAX_STARS = 5,

	-- Base stats by rarity, before element, level, stars, grade and foil. Spaced so rarity always beats
	-- grade at equal level and stars (tests/BeastMath.spec checks it).
	BASE_STATS = {
		Common = { hp = 60, atk = 12, spd = 10 },
		Rare = { hp = 80, atk = 16, spd = 12 },
		["Very Rare"] = { hp = 100, atk = 21, spd = 14 },
		Epic = { hp = 135, atk = 27, spd = 17 },
		Legendary = { hp = 180, atk = 36, spd = 20 },
	},
	ELEMENT_MULTIPLIERS = {
		Ember = { hp = 1, atk = 1.2, spd = 1 },
		Tide = { hp = 1.2, atk = 1, spd = 1 },
		Bloom = { hp = 1.1, atk = 1.1, spd = 1 },
		Volt = { hp = 1, atk = 1, spd = 1.25 },
		Shade = { hp = 1, atk = 1.1, spd = 1.1 },
	},
	LEVEL_STAT_GROWTH = 0.06, -- +6% per level above 1
	STAR_STAT_GROWTH = 0.15, -- +15% stats per star
	FOIL_STAT_MULTIPLIER = 1.05,

	-- +3% value per level above 1 (Lv 30: 1.87x). It was +10% (3.9x): levels come from free XP (fights, XP Tonics), so
	-- a levelled card sold to a customer printed money, and with its stars a maxed card sold for far more than the
	-- cards inside it (owner 2026-11-20, from a tester; tests/BeastMath)
	LEVEL_VALUE_GROWTH = 0.03,
	-- Value multiplier by stars 0-5 (index = stars + 1). Always less than the cards that went into it (1, 5, 13, 25,
	-- 41, 65; with Star Shards filling half of each star 1, 3, 7, 13, 21, 33): owner 2026-11-20, from a tester, "you
	-- can easily earn money fast by upgrading stars of the cards then selling it. make sure this doesnt get abused".
	-- It was { 1, 6, 15, 30, 50, 80 }: a star added value out of nothing (double with shards), and one sale to one
	-- customer carried all of it. Stars are for power now; selling the copies one by one always pays more
	-- (tests/BeastMath).
	STAR_VALUE = { 1, 2.5, 6, 11, 18, 28 },
	-- Duplicates condensed for the next star: 0->1, 1->2, 2->3, 3->4, 4->5 (64 total)
	STAR_COSTS = { 4, 8, 12, 16, 24 },
	MAX_SHARD_SHARE = 0.5, -- Star Shards can cover at most this share of a star's duplicates

	-- XP to go from level L to L + 1 = round(XP_BASE * L ^ XP_EXPONENT)
	XP_BASE = 50,
	XP_EXPONENT = 1.5,


	-- Grades, weakest first. Rolled once when a card is pulled; boost stats and value.
	GRADES = { "C", "B", "A", "S" },
	GRADE_CHANCES = { C = 0.55, B = 0.3, A = 0.13, S = 0.02 },
	-- Rarer cards are less likely to be Grade S (the chase); the difference goes to C. Rarities not listed use
	-- GRADE_CHANCES. A Grade S Legendary also comes from the Grading Station (Config/Grading).
	GRADE_CHANCES_BY_RARITY = {
		Epic = { C = 0.555, B = 0.3, A = 0.13, S = 0.015 },
		Legendary = { C = 0.56, B = 0.3, A = 0.13, S = 0.01 },
	} :: { [string]: { [string]: number } },
	GRADE_BONUS = { C = 0, B = 0.03, A = 0.06, S = 0.10 },
	DEFAULT_GRADE = "C",

	-- Power = HP + ATK * weight + SPD * weight: one number to compare cards
	POWER_ATK_WEIGHT = 5,
	POWER_SPD_WEIGHT = 5,
}
