--!strict
local SparkPath = require("../src/shared/Util/SparkPath")
local expect = require("./lib/expect")

return {
	["a spark starts at the monster and lands on the portrait"] = function()
		local x0, y0 = SparkPath.point(100, 400, 900, 500, 120, 0)
		expect.near(x0, 100, 1e-9)
		expect.near(y0, 400, 1e-9)
		local x1, y1 = SparkPath.point(100, 400, 900, 500, 120, 1)
		expect.near(x1, 900, 1e-9)
		expect.near(y1, 500, 1e-9)
	end,

	["it bows up on the way, lift / 2 above the straight line at the middle"] = function()
		local x, y = SparkPath.point(100, 400, 900, 500, 120, 0.5)
		expect.near(x, 500, 1e-9)
		expect.near(y, 450 - 60, 1e-9, "screen y grows downwards, so up is smaller")
	end,

	["more XP, more sparks, within the limits"] = function()
		expect.equal(SparkPath.count(0, 3, 6), 3)
		expect.equal(SparkPath.count(50, 3, 6) >= 3, true)
		expect.equal(SparkPath.count(1e9, 3, 6), 6)
		expect.equal(SparkPath.count(5000, 3, 6) >= SparkPath.count(50, 3, 6), true)
	end,
}
