--!strict
-- Ambient animals wandering round their homes (Portal Worlds spec): 3 in town, one in each portal area. Pure steps in
-- Util/Wander, homes in Config/Ambient CRITTERS.
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

	["three animals in town and one in each portal area"] = function()
		local town, areas = 0, {}
		for _, critter in ambient.CRITTERS do
			if critter.area == "town" then
				town += 1
			else
				areas[critter.area] = (areas[critter.area] or 0) + 1
			end
		end
		expect.equal(town, 3, "town animals")
		for _, area in { "ForestFalls", "Frostpeak", "EmberCanyon" } do
			expect.equal(areas[area], 1, area)
		end
	end,
}
