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

-- The First Spark Deck Box's slots (Config/Packs DeckBox): 5 cards opened at once, $9 against a pack's $3
local DECK_BOX = {
	slots = {
		COMMON,
		COMMON,
		{ { rarity = "Common", weight = 0.5 }, { rarity = "Rare", weight = 0.5 } },
		{ { rarity = "Rare", weight = 0.75 }, { rarity = "Very Rare", weight = 0.25 } },
		{ { rarity = "Rare", weight = 0.45 }, { rarity = "Very Rare", weight = 0.25 }, { rarity = "Epic", weight = 0.22 }, { rarity = "Legendary", weight = 0.08 } },
	},
}

return {
	["a deck box beats a pack: 5 cards, two guaranteed Rare or better, better hit odds"] = function()
		expect.equal(#DECK_BOX.slots, 5, "5 cards")
		local guaranteed = 0
		for _, slot in DECK_BOX.slots do
			local common = false
			for _, option in slot do
				common = common or option.rarity == "Common"
			end
			if not common then
				guaranteed += 1
			end
		end
		expect.equal(guaranteed, 2, "Rare-or-better slots")
		local deck, pack = OddsRules.perCard(DECK_BOX), OddsRules.perCard(FIRST_SPARK)
		for _, rarity in { "Very Rare", "Epic", "Legendary" } do
			assert(deck[rarity] > pack[rarity], `{rarity} odds are no better than a pack's`)
			assert(deck[rarity] < pack[rarity] * 4, `{rarity} odds are too generous for 3x a pack's price`)
		end
	end,

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

	["perPack adds up each slot's chance of a rarity"] = function()
		expect.near(OddsRules.perPack(FIRST_SPARK, "Legendary"), 0.03, 1e-9, "one hit slot at 3%")
		expect.near(OddsRules.perPack(FIRST_SPARK, "Rare"), 0.3 + 0.68, 1e-9, "two slots can be Rare")
		expect.near(OddsRules.perPack(FIRST_SPARK, "Common"), 3.7, 1e-9, "about 3.7 Commons a pack")
		expect.equal(OddsRules.perPack(FIRST_SPARK, "Mythic"), 0, "a rarity it never gives")
		expect.equal(OddsRules.perPack({ slots = {} }, "Legendary"), 0, "an empty pack")
	end,
}
