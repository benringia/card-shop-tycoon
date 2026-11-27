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

	-- Owner 2026-11-27 (picks B and 1; spec 2026-11-27-tutorial-arrows-design): arrows on the ground for the next
	-- stretch only. Seen in the 11-27 recording: the whole route's paws piled into a gold smear at the horizon
	["each arrow knows how far along the route it lies"] = function()
		local paws = TrailRules.along({ p(0, 0), p(10, 0), p(10, -10) }, 4, 50)
		for index, distance in { 4, 8, 12, 16 } do
			expect.near(paws[index].distance, distance, 1e-6, `arrow {index}`)
		end
		local spread = TrailRules.along({ p(0, 0), p(300, 0) }, 3, 40)
		expect.near(spread[40].distance, 300 * 40 / 41, 1e-6, "a long route's spread arrows too")
	end,

	["how far along the route the player is: the nearest point on it"] = function()
		local route = { p(0, 0), p(10, 0), p(10, -10) }
		expect.near(TrailRules.progress(route, p(0, 0)), 0, 1e-6, "at the start")
		expect.near(TrailRules.progress(route, p(10, 0)), 10, 1e-6, "at the corner")
		expect.near(TrailRules.progress(route, p(12, -4)), 14, 1e-6, "beside the second leg, 4 studs in")
		expect.near(TrailRules.progress(route, p(4, 3, 2)), 4, 1e-6, "off to the side and higher up: only where along it counts")
		expect.near(TrailRules.progress(route, p(10, -15)), 20, 1e-6, "past the end")
		expect.near(TrailRules.progress(route, p(-5, 0)), 0, 1e-6, "before the start")
		expect.equal(TrailRules.progress({ p(3, 3) }, p(0, 0)), 0, "no route")
	end,

	["only the next few arrows ahead of the player show"] = function()
		local paws = TrailRules.along({ p(0, 0), p(10, 0), p(10, -10) }, 4, 50) -- at 4, 8, 12, 16
		local first, last = TrailRules.ahead(paws, 0, 3)
		expect.equal(first, 1)
		expect.equal(last, 3, "three from the start")
		first, last = TrailRules.ahead(paws, 9, 3)
		expect.equal(first, 3, "the first one past the player (12 > 9)")
		expect.equal(last, 4, "never past the route's end")
		first, last = TrailRules.ahead(paws, 16, 3)
		assert(first > last, "past the last arrow: none (the goal's own arrow shows)")
		first, last = TrailRules.ahead({}, 0, 3)
		assert(first > last, "no arrows: none")
		local short = TrailRules.along({ p(0, 0), p(2, 0) }, 3, 40)
		first, last = TrailRules.ahead(short, 0, 12)
		expect.equal(first, 1)
		expect.equal(last, 1, "a route shorter than a gap: its one arrow")
	end,

	["a route too short for a gap still gets one paw; no route none"] = function()
		local paws = TrailRules.along({ p(0, 0), p(2, 0) }, 3, 40)
		expect.equal(#paws, 1)
		expect.near(paws[1].x, 1, 1e-6)
		expect.equal(#TrailRules.along({ p(0, 0) }, 3, 40), 0)
		expect.equal(#TrailRules.along({}, 3, 40), 0)
	end,
}
