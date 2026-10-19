--!strict
-- Rarity config for Set 1. Numbers come from DESIGN.md section 5.
local Rarities = {
	Common = { order = 1, color = Color3.fromRGB(160, 160, 160), minValue = 0.10, maxValue = 0.50 },
	Rare = { order = 2, color = Color3.fromRGB(70, 140, 255), minValue = 1, maxValue = 3 },
	Epic = { order = 3, color = Color3.fromRGB(170, 80, 255), minValue = 5, maxValue = 20 },
	Legendary = { order = 4, color = Color3.fromRGB(255, 200, 40), minValue = 40, maxValue = 150 },
}

-- Chance any card rolls foil, and how much foil multiplies value
local FOIL_CHANCE = 0.04
local FOIL_MULTIPLIER = 3

return {
	Tiers = Rarities,
	FOIL_CHANCE = FOIL_CHANCE,
	FOIL_MULTIPLIER = FOIL_MULTIPLIER,
}
