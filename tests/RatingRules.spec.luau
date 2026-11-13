--!strict
-- Shop rating (spec 2026-11-06-customers-design): a weighted list of 0-1 parts mapped to 1-5 stars, smoothed, speeding up
-- or slowing down customers; decor (spec 2026-11-14-shop-decor-design) is about a tenth of it
local RatingRules = require("../src/shared/Util/RatingRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local WEIGHTS = Customers.RATING.parts

local function near(actual: number, expected: number, label: string?)
	assert(math.abs(actual - expected) < 1e-6, `{label or ""}: expected {expected}, got {actual}`)
end

return {
	["a well-run, decorated shop rates about 4.5"] = function()
		near(RatingRules.score({ stocked = 1, prices = 1, displays = 0.5, happy = 0.8, decor = 1 }, WEIGHTS), 1 + 4 * 0.975 / 1.1)
		near(RatingRules.score({ stocked = 0, prices = 0, displays = 0, happy = 0 }, WEIGHTS), 1, "nothing: 1 star")
		near(RatingRules.score({ stocked = 1, prices = 1, displays = 1, happy = 1, decor = 1 }, WEIGHTS), 5, "everything: 5 stars")
	end,

	["decor is about a tenth: a perfect shop with no decor is about 4.6 stars"] = function()
		near(RatingRules.score({ stocked = 1, prices = 1, displays = 1, happy = 1, decor = 0 }, WEIGHTS), 1 + 4 / 1.1)
		near(RatingRules.score({ stocked = 1, prices = 1, displays = 1, happy = 1, decor = 1 }, WEIGHTS), 5, "decorated too: 5 stars")
	end,

	["three stars is today's customer flow"] = function()
		near(RatingRules.spawnScale(Customers, 3), 1.0)
		near(RatingRules.spawnScale(Customers, 1), 1.4)
		near(RatingRules.spawnScale(Customers, 5), 0.6)
		near(RatingRules.spawnScale(Customers, 4), 0.8)
	end,

	["a fresh join starts neutral on happiness"] = function()
		expect.equal(RatingRules.happy({}), 0.5)
		expect.equal(RatingRules.happy({ "paid", "happyMoment", "annoyed", "noStock" }), 0.5)
		expect.equal(RatingRules.happy({ "paid", "paid", "paid", "gaveUp" }), 0.75)
	end,

	["smoothing takes its time"] = function()
		local next = RatingRules.smooth(3, 5, 5, 90)
		assert(next > 3 and next < 3.3, `one tick moves it a little: {next}`)
		near(RatingRules.smooth(4, 4, 5, 90), 4, "already there")
	end,

	["the parts' scores"] = function()
		near(RatingRules.stocked(3, 4), 0.75)
		near(RatingRules.stocked(0, 0), 0, "no product shelves")
		near(RatingRules.prices({ 0.95, 0.5 }, 0.95), (1 + 0.5 / 0.95) / 2)
		near(RatingRules.prices({ 0 }, 0.95), 0, "over the last band")
		near(RatingRules.prices({}, 0.95), 0.5, "nothing stocked: neutral")
		near(RatingRules.displays(Customers, { { rarity = "Legendary", foil = false }, { rarity = "Epic", foil = true } }), 5 / 6)
		near(RatingRules.displays(Customers, { { rarity = "Legendary", foil = true }, { rarity = "Legendary", foil = true } }), 1, "capped at full")
		near(RatingRules.displays(Customers, { { rarity = "Rare", foil = false } }), 0)
	end,

	["tips list each part that counts"] = function()
		local tips = RatingRules.tips({ stocked = 1, prices = 0.4, displays = 0.7, happy = 0.69, decor = 0 }, WEIGHTS)
		local byName = {}
		for _, tip in tips do
			byName[tip.name] = tip.good
		end
		expect.equal(byName.decor, false, "decor counts: an undecorated shop is asked to decorate")
		expect.equal(byName.stocked, true)
		expect.equal(byName.prices, false)
		expect.equal(byName.displays, true, "0.7 counts as good")
		expect.equal(byName.happy, false)
		expect.equal(tips[1].name, "stocked", "heaviest part first")
	end,
}
