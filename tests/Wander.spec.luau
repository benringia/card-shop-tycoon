--!strict
-- Ambient animals wandering round their homes (Portal Worlds spec): 3 in town, 2 in the plaza (one resting, one
-- circling the fountain), one in each portal area. Pure steps in Util/Wander, homes in Config/Ambient CRITTERS.
local ambient = require("../src/shared/Config/Ambient")
local Wander = require("../src/shared/Util/Wander")
local expect = require("./lib/expect")

-- A repeatable stand-in for Random
local function stubRandom(seed: number)
	local state = seed
	return {
		NextNumber = function(_, low: number, high: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return low + (high - low) * (state / 2147483648)
		end,
	}
end

return {
	["targets stay in the home area, clear of the middle"] = function()
		local bunny = { home = { x = 0, z = 0 }, radius = 18, avoid = 9 } -- a home round something to keep clear of
		local rng = stubRandom(42)
		for _ = 1, 1000 do
			local target = Wander.target(bunny.home, bunny.radius, bunny.avoid, rng)
			local d = math.sqrt((target.x - bunny.home.x) ^ 2 + (target.z - bunny.home.z) ^ 2)
			assert(d <= bunny.radius + 1e-9, `target {d} studs out`)
			assert(d >= bunny.avoid - 1e-9, `target {d} studs from the spring`)
		end
	end,

	["a step never overshoots"] = function()
		local pos, arrived = Wander.step({ x = 0, z = 0 }, { x = 1, z = 0 }, 10, 1)
		expect.equal(pos.x, 1, "lands on the target")
		expect.equal(pos.z, 0, "level")
		expect.equal(arrived, true, "arrived")
		pos, arrived = Wander.step({ x = 0, z = 0 }, { x = 10, z = 0 }, 4, 0.5)
		expect.near(pos.x, 2, 1e-9, "speed x time")
		expect.equal(arrived, false, "still going")
	end,

	["an animal running laps picks a turn up to maxArc, now and then the other way"] = function()
		local rng = stubRandom(7)
		local back = 0
		for _ = 1, 500 do
			local target = Wander.orbitTarget(90, 120, rng)
			local turn = target - 90
			assert(math.abs(turn) >= 30 - 1e-9 and math.abs(turn) <= 120 + 1e-9, `turned {turn} degrees`)
			if turn < 0 then
				back += 1
			end
		end
		assert(back > 50 and back < 250, `{back} of 500 turns went back`)
	end,

	["running laps follows the circle and stops on the target angle"] = function()
		local angle, arrived = Wander.orbitStep(0, 90, 10, 7, 0.5)
		expect.near(angle, math.deg(3.5 / 10), 1e-9, "moves speed x time along the circle")
		expect.equal(arrived, false, "still going")
		angle, arrived = Wander.orbitStep(80, 90, 10, 7, 1)
		expect.equal(angle, 90, "lands on the target, never past it")
		expect.equal(arrived, true, "arrived")
		angle = Wander.orbitStep(0, -90, 10, 7, 0.5)
		assert(angle < 0, "runs the other way for a negative turn")
		local p = Wander.circlePoint({ x = 2, z = 3 }, 10, 90)
		expect.near(p.x, 2, 1e-9, "x")
		expect.near(p.z, 13, 1e-9, "on the circle")
	end,

	["three animals in town, two in the plaza, one in each portal area"] = function()
		local town, areas = 0, {}
		for _, critter in ambient.CRITTERS do
			if critter.area == "town" then
				town += 1
			else
				areas[critter.area] = (areas[critter.area] or 0) + 1
			end
		end
		expect.equal(town, 3, "town animals")
		expect.equal(areas.plaza, 2, "plaza animals")
		for _, area in { "ForestFalls", "Frostpeak", "EmberCanyon" } do
			expect.equal(areas[area], 1, area)
		end
	end,
}
