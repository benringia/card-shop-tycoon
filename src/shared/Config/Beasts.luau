--!strict
-- Glimmerbeast growth, stats and value. See DESIGN.md section 5.8 and the beast cards spec.
-- Plain numbers only (no Roblox types) so Lune unit tests can load this file.
return {
	MAX_LEVEL = 30,
	MAX_STARS = 5,

	-- Base stats by rarity, before element, level, stars and foil
	BASE_STATS = {
		Common = { hp = 60, atk = 12, spd = 10 },
		Rare = { hp = 80, atk = 16, spd = 12 },
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
	STAR_STAT_GROWTH = 0.15, -- +15% per star above 1
	FOIL_STAT_MULTIPLIER = 1.05,

	LEVEL_VALUE_GROWTH = 0.10, -- +10% value per level above 1
	STAR_VALUE = { 1, 1.5, 2.25, 3.5, 5 }, -- value multiplier by star count

	-- XP to go from level L to L + 1 = round(XP_BASE * L ^ XP_EXPONENT)
	XP_BASE = 50,
	XP_EXPONENT = 1.5,

	-- A beast must reach this level before it can gain a star (star upgrades arrive with star merging)
	STAR_UPGRADE_LEVEL = 30,
}
