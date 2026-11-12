--!strict
-- Town Pish's walk between two points (spec 2026-11-09-tutorial-pish-design 4): straight, unless the plaza fountain is
-- in the way, then round it
local PishPath = require("../src/shared/Util/PishPath")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

type Point = { x: number, z: number }

-- The closest the segment a-b comes to c
local function clearance(a: Point, b: Point, c: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((c.x - a.x) * dx + (c.z - a.z) * dz) / lengthSq, 0, 1) else 0
	local px, pz = a.x + dx * t - c.x, a.z + dz * t - c.z
	return math.sqrt(px * px + pz * pz)
end

local CENTRE = { x = 0, z = 0 }

local function clear(from: Point, points: { Point }, radius: number)
	local last = from
	for i, point in points do
		assert(clearance(last, point, CENTRE) >= radius * 0.99, `leg {i} keeps clear of the fountain`)
		last = point
	end
end

return {
	-- Town Chikin (the owner 2026-11-11): his stops on the portal side, the trailheads more often than the far Arena
	-- owner 2026-11-12: "pish is phasing through items" (the delivery pad beside a shop's doors): he comes and goes by a
	-- spot out past the pad, straight in from there
	["a shop visit comes in from past the delivery pad's outer edge, square to the door"] = function()
		local doorway = { x = 10, z = 0 }
		local outward = { x = 0, z = 1 } -- the street is +z
		local spot = PishPath.shopApproach(doorway, outward, 6.6, 2)
		expect.near(spot.x, 10, 1e-9, "straight out from the door")
		expect.near(spot.z, 8.6, 1e-9, "past the pad (6.6 studs out) by the clearance")
		local turned = PishPath.shopApproach({ x = 0, z = 0 }, { x = 1, z = 0 }, 6.6, 2)
		expect.near(turned.x, 8.6, 1e-9, "any way the shop faces")
	end,

	["a town dog's next stop: by weight, never the one it's at"] = function()
		local stops = { { x = 0, z = 0, weight = 3 }, { x = 10, z = 0, weight = 1 } }
		expect.equal(PishPath.pickStop(stops, 0, nil), 1, "low roll: the first")
		expect.equal(PishPath.pickStop(stops, 0.74, nil), 1, "three quarters of the weight")
		expect.equal(PishPath.pickStop(stops, 0.76, nil), 2)
		expect.equal(PishPath.pickStop(stops, 0, 1), 2, "never the stop it's at")
		expect.equal(PishPath.pickStop(stops, 0.99, 2), 1)
		expect.equal(PishPath.pickStop({ { x = 0, z = 0, weight = 1 } }, 0.5, 1), 1, "one stop: that one")
		expect.equal(PishPath.pickStop({}, 0.5, nil), nil, "none: nil")
	end,

	["a clear way is one straight leg"] = function()
		local points = PishPath.route({ x = -30, z = 20 }, { x = 30, z = 20 }, CENTRE, 9)
		expect.equal(#points, 1)
		expect.equal(points[1].x, 30)
		expect.equal(points[1].z, 20)
	end,

	["straight across the fountain: round it, ending where it was going"] = function()
		local to = { x = 30, z = 0 }
		local points = PishPath.route({ x = -30, z = 0 }, to, CENTRE, 9)
		assert(#points >= 2, "a way round")
		expect.equal(points[#points].x, 30)
		expect.equal(points[#points].z, 0)
		clear({ x = -30, z = 0 }, points, 9)
	end,

	["a short hop past the fountain's edge keeps clear too"] = function()
		local from = { x = -12, z = 1 }
		local points = PishPath.route(from, { x = 12, z = -1 }, CENTRE, 9)
		clear(from, points, 9)
	end,

	["a point inside the circle is reached straight (nothing to go round)"] = function()
		local points = PishPath.route({ x = 20, z = 0 }, { x = 5, z = 0 }, CENTRE, 9)
		expect.equal(#points, 1)
	end,
	["petting holds him still, but never longer than petHoldMax in one place (final review: one owner kept him at their door)"] = function()
		local max = Pish.TOWN.petHoldMax
		assert(max and max >= 3 and max <= 15, "a few seconds")
		expect.equal(PishPath.holdEnd(12, 10, max), 12, "one pet: he holds 2 s")
		expect.equal(PishPath.holdEnd(10 + max + 50, 10, max), 10 + max, "petted again and again: he moves on after petHoldMax")
		expect.equal(PishPath.holdEnd(5, 10, max), 5, "not petted now: no hold")
	end,
}
