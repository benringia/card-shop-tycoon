--!strict
local FanLayout = require("../src/shared/Util/FanLayout")
local expect = require("./lib/expect")

return {
	["three buttons spread evenly from the first angle to the last"] = function()
		local p = FanLayout.positions(3, 100, 90, -90)
		expect.near(p[1].x, 0, 1e-6, "top x")
		expect.near(p[1].y, -100, 1e-6, "top y")
		expect.near(p[2].x, 100, 1e-6, "middle x")
		expect.near(p[2].y, 0, 1e-6, "middle y")
		expect.near(p[3].y, 100, 1e-6, "bottom y")
	end,

	["one button sits at the middle angle"] = function()
		local p = FanLayout.positions(1, 50, 90, -90)
		expect.near(p[1].x, 50, 1e-6, "x")
		expect.near(p[1].y, 0, 1e-6, "y")
	end,

	["no buttons gives an empty list"] = function()
		expect.equal(#FanLayout.positions(0, 50, 0, 90), 0, "empty")
	end,
}
