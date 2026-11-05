--!strict
-- Bargain hunters (spec 2026-11-06-customers-design): once everything is scanned they offer 10-25% under the total, and
-- pay your counter up to their own ceiling
local HaggleRules = require("../src/shared/Util/HaggleRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

return {
	["offers 10-25% under"] = function()
		expect.equal(HaggleRules.offer(Customers, 100, 0), 90)
		expect.equal(HaggleRules.offer(Customers, 100, 1), 75)
		expect.equal(HaggleRules.offer(Customers, 3.33, 0.5), 2.75, "rounded to cents")
	end,

	["counter range is between their offer and your total"] = function()
		local low, high = HaggleRules.counterRange(80, 100)
		expect.equal(low, 80)
		expect.equal(high, 100)
	end,

	["pays up to their ceiling"] = function()
		expect.equal(HaggleRules.ceiling(Customers, 80, 100, 0), 88)
		expect.equal(HaggleRules.ceiling(Customers, 80, 100, 1), 96)
		expect.equal(HaggleRules.accepts(88, 88), true)
		expect.equal(HaggleRules.accepts(88.01, 88), false)
	end,

	["cashier settles halfway"] = function()
		expect.equal(HaggleRules.cashierPrice(80, 100), 90)
		expect.equal(HaggleRules.cashierPrice(80, 100.02), 90.01, "rounded to cents")
	end,

	-- Lower is better for them: sure under the ceiling's band, maybe around it, no above
	["the face never gives the ceiling away exactly"] = function()
		local edges = HaggleRules.moodEdges(Customers, 88, 100)
		expect.equal(edges.sure, 83)
		expect.equal(edges.maybe, 93)
	end,
}
