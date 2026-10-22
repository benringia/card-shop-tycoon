--!strict
local OddsRules = require("../src/shared/Util/OddsRules")
local expect = require("./lib/expect")

-- The First Spark pack's slots (Config/Packs), as plain data
local COMMON = { { rarity = "Common", weight = 1 } }
local FIRST_SPARK = {
	slots = {
		COMMON,
		COMMON,
		COMMON,
		{ { rarity = "Common", weight = 0.7 }, { rarity = "Rare", weight = 0.3 } },
		{ { rarity = "Rare", weight = 0.68 }, { rarity = "Very Rare", weight = 0.15 }, { rarity = "Epic", weight = 0.14 }, { rarity = "Legendary", weight = 0.03 } },
	},
}

return {
	["per-card odds average the pack's slots"] = function()
		local odds = OddsRules.perCard(FIRST_SPARK)
		expect.near(odds.Common, 0.74, 1e-9, "Common")
		expect.near(odds.Rare, 0.196, 1e-9, "Rare")
		expect.near(odds["Very Rare"], 0.03, 1e-9, "Very Rare")
		expect.near(odds.Epic, 0.028, 1e-9, "Epic")
		expect.near(odds.Legendary, 0.006, 1e-9, "Legendary")
	end,

	["the odds add up to one"] = function()
		local total = 0
		for _, chance in OddsRules.perCard(FIRST_SPARK) do
			total += chance
		end
		expect.near(total, 1, 1e-9, "total")
	end,

	["a slot whose weights don't add to one is scaled"] = function()
		local odds = OddsRules.perCard({ slots = { { { rarity = "Common", weight = 3 }, { rarity = "Rare", weight = 1 } } } })
		expect.near(odds.Common, 0.75, 1e-9, "Common")
		expect.near(odds.Rare, 0.25, 1e-9, "Rare")
	end,

	["about one in N rounds to the nearest whole card"] = function()
		expect.equal(OddsRules.oneIn(0.006), 167, "legendary")
		expect.equal(OddsRules.oneIn(0.5), 2, "half")
		expect.equal(OddsRules.oneIn(0), math.huge, "never")
	end,
}
