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

	LEVEL_VALUE_GROWTH = 0.10, -- +10% value per level above 1
	-- Value multiplier by stars 0-5 (index = stars + 1). Roughly the duplicates condensed plus a bonus.
	STAR_VALUE = { 1, 6, 15, 30, 50, 80 },
	-- Duplicates condensed for the next star: 0->1, 1->2, 2->3, 3->4, 4->5 (64 total)
	STAR_COSTS = { 4, 8, 12, 16, 24 },
	MAX_SHARD_SHARE = 0.5, -- Star Shards can cover at most this share of a star's duplicates

	-- XP to go from level L to L + 1 = round(XP_BASE * L ^ XP_EXPONENT)
	XP_BASE = 50,
	XP_EXPONENT = 1.5,


	-- Grades, weakest first. Rolled once when a card is pulled; boost stats and value.
	GRADES = { "C", "B", "A", "S" },
	GRADE_CHANCES = { C = 0.55, B = 0.3, A = 0.13, S = 0.02 },
	GRADE_BONUS = { C = 0, B = 0.03, A = 0.06, S = 0.10 },
	DEFAULT_GRADE = "C",

	-- Power = HP + ATK * weight + SPD * weight: one number to compare cards
	POWER_ATK_WEIGHT = 5,
	POWER_SPD_WEIGHT = 5,
}
