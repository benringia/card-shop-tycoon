--!strict
local RingRules = require("../src/shared/Util/RingRules")
local expect = require("./lib/expect")

return {
	["a slam hits inside its circle"] = function()
		expect.equal(RingRules.inSlam(0, 0, 7, 0, 6.9), true)
		expect.equal(RingRules.inSlam(0, 0, 7, 0, 7.1), false)
		expect.equal(RingRules.inSlam(10, 10, 7, 14, 14), true)
	end,

	["a swipe hits inside its cone"] = function()
		expect.equal(RingRules.inSwipe(0, 0, 0, -1, 20, 35, 0, -10), true)
		expect.equal(RingRules.inSwipe(0, 0, 0, -1, 20, 35, 5, -10), true, "26.6 degrees")
		expect.equal(RingRules.inSwipe(0, 0, 0, -1, 20, 35, 8, -10), false, "38.7 degrees")
		expect.equal(RingRules.inSwipe(0, 0, 0, -1, 20, 35, 0, -21), false, "past its length")
		expect.equal(RingRules.inSwipe(0, 0, 0, -1, 20, 35, 0, 5), false, "behind it")
		expect.equal(RingRules.inSwipe(0, 0, 0, -2, 20, 35, 0, -10), true, "any direction length")
	end,

	["the closing ring shrinks from 1.9 to the edge"] = function()
		expect.equal(RingRules.closingScale(0, 1.2), 1.9)
		expect.near(RingRules.closingScale(0.6, 1.2), 1.45, 1e-9)
		expect.equal(RingRules.closingScale(2, 1.2), 1)
		expect.equal(RingRules.closingScale(-1, 1.2), 1.9)
	end,
}
