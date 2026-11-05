--!strict
-- Kid offers (spec 2026-11-06-customers-design): a kid who pulled Very Rare or better may offer it to you, asks about
-- what it's worth, and takes your counter from their own lowest price
local OfferRules = require("../src/shared/Util/OfferRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

return {
	["only some kids sell: rarity chance times grade"] = function()
		expect.equal(OfferRules.wantsToSell(Customers, "Very Rare", "C", 0.45), true, "0.4 x 1.15 = 0.46")
		expect.equal(OfferRules.wantsToSell(Customers, "Very Rare", "C", 0.47), false)
		expect.equal(OfferRules.wantsToSell(Customers, "Legendary", "S", 0.20), true, "0.3 x 0.7 = 0.21")
		expect.equal(OfferRules.wantsToSell(Customers, "Legendary", "S", 0.22), false)
		expect.equal(OfferRules.wantsToSell(Customers, "Rare", "C", 0), false, "Rare never")
		expect.equal(OfferRules.wantsToSell(Customers, "Common", "C", 0), false, "Common never")
	end,

	["asks about what it's worth, accepts from its lowest"] = function()
		expect.equal(OfferRules.asking(Customers, 100, 0), 90)
		expect.equal(OfferRules.asking(Customers, 100, 1), 100)
		expect.equal(OfferRules.lowest(Customers, 100, 0.5), 82.5)
		expect.equal(OfferRules.accepts(82.5, 82.5), true)
		expect.equal(OfferRules.accepts(82.49, 82.5), false)
		expect.equal(OfferRules.asking(Customers, 3.33, 0.5), 3.16, "rounded to cents")
	end,

	["ceilings: 4 an hour, never two Legendaries within 3 hours"] = function()
		local now = 20000
		expect.equal(OfferRules.allowed(Customers, { offers = { now - 100, now - 900, now - 2000, now - 3500 } }, now, "Epic"), false, "4 in the last hour")
		expect.equal(OfferRules.allowed(Customers, { offers = { now - 100, now - 900, now - 2000 } }, now, "Epic"), true, "3 in the last hour")
		expect.equal(OfferRules.allowed(Customers, { offers = { now - 100, now - 900, now - 2000, now - 3700 } }, now, "Epic"), true, "an older one doesn't count")
		expect.equal(OfferRules.allowed(Customers, { offers = {}, lastLegendary = now - 10000 }, now, "Legendary"), false)
		expect.equal(OfferRules.allowed(Customers, { offers = {}, lastLegendary = now - 10000 }, now, "Epic"), true)
		expect.equal(OfferRules.allowed(Customers, { offers = {}, lastLegendary = now - 10801 }, now, "Legendary"), true)
	end,

	["counter range and steps"] = function()
		local low, high = OfferRules.counterRange(40, 38)
		expect.equal(low, 20)
		expect.equal(high, 38)
		expect.equal(OfferRules.step(Customers, 40), 2)
		expect.equal(OfferRules.step(Customers, 0.1), 0.01, "never under a cent")
	end,

	["the face never gives the price away exactly"] = function()
		local edges = OfferRules.moodEdges(Customers, 80, 100)
		expect.equal(edges.sure, 85)
		expect.equal(edges.maybe, 75)
		expect.equal(OfferRules.mood(Customers, 80, 80, 100), "maybe", "at their lowest: maybe")
		expect.equal(OfferRules.mood(Customers, 85, 80, 100), "sure")
		expect.equal(OfferRules.mood(Customers, 74.99, 80, 100), "no")
	end,

	["offer expires"] = function()
		expect.equal(OfferRules.expired(Customers, 0, 25), true)
		expect.equal(OfferRules.expired(Customers, 0, 24.9), false)
	end,

	["can't pay, can't buy"] = function()
		expect.equal(OfferRules.canPay(10, 10.01), false)
		expect.equal(OfferRules.canPay(10, 10), true)
	end,
}
