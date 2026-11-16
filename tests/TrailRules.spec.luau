--!strict
-- The guides' paw trails (owner 2026-11-16: "chikin paws are passes through things. fix it and make the paws go
-- through the correct path"): paws spaced evenly along the walking route (pathfinding's waypoints), not a straight line
local TrailRules = require("../src/shared/Util/TrailRules")
local expect = require("./lib/expect")

local function p(x: number, z: number, y: number?): TrailRules.Point
	return { x = x, y = y or 0, z = z }
end

return {
	["paws every few studs along a bent route, each facing its own leg"] = function()
		-- an L: 10 east then 10 north
		local paws = TrailRules.along({ p(0, 0), p(10, 0), p(10, -10) }, 4, 50)
		expect.equal(#paws, 4, "at 4, 8, 12, 16 of the 20 studs")
		expect.near(paws[1].x, 4, 1e-6)
		expect.near(paws[2].x, 8, 1e-6)
		expect.near(paws[3].x, 10, 1e-6)
		expect.near(paws[3].z, -2, 1e-6, "round the corner")
		expect.near(paws[1].facing, 90, 1e-6, "east")
		expect.near(paws[3].facing, 0, 1e-6, "north (-Z)")
	end,

	["the paws follow the ground's height"] = function()
		local paws = TrailRules.along({ p(0, 0, 0), p(10, 0, 2) }, 5, 50)
		expect.near(paws[1].y, 1, 1e-6, "halfway up the step")
	end,

	["a long route spreads its paws out rather than passing the cap"] = function()
		local paws = TrailRules.along({ p(0, 0), p(300, 0) }, 3, 40)
		expect.equal(#paws, 40)
		expect.near(paws[40].x, 300 * 40 / 41, 1e-6, "evenly to just short of the end")
	end,

	["a route too short for a gap still gets one paw; no route none"] = function()
		local paws = TrailRules.along({ p(0, 0), p(2, 0) }, 3, 40)
		expect.equal(#paws, 1)
		expect.near(paws[1].x, 1, 1e-6)
		expect.equal(#TrailRules.along({ p(0, 0) }, 3, 40), 0)
		expect.equal(#TrailRules.along({}, 3, 40), 0)
	end,
}
