--!strict
-- Glimmerbeast growth, stats and value. See DESIGN.md section 5.8 and the beast cards spec.
-- Plain numbers only (no Roblox types) so Lune unit tests can load this file.
return {
	MAX_LEVEL = 30,
	START_STARS = 0, -- every card starts with no stars
	MAX_STARS = 5,

	-- Base stats by rarity, before element, level, stars and foil
	BASE_STATS = {
		Common = { hp = 60, atk = 12, spd = 10 },
		Rare = { hp = 80, atk = 16, spd = 12 },
		["Very Rare"] = { hp = 95, atk = 19, spd = 13 },
		Epic = { hp = 110, atk = 22, spd = 14 },
		Legendary = { hp = 150, atk = 30, spd = 16 },
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

	-- XP to go from level L to L + 1 = round(XP_BASE * L ^ XP_EXPONENT)
	XP_BASE = 50,
	XP_EXPONENT = 1.5,

}
