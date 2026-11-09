--!strict
-- Town Pish's walk between two points (spec 2026-11-09-tutorial-pish-design 4): straight, unless the plaza fountain is
-- in the way, then round it
local PishPath = require("../src/shared/Util/PishPath")
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
}
