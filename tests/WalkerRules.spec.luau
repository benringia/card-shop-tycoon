--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2): customers who stroll the plaza, sit on benches, then pick an
-- open shop by its rating and what they want
local WalkerRules = require("../src/shared/Util/WalkerRules")
local Customers = require("../src/shared/Config/Customers")
local Plaza = require("../src/shared/Config/Plaza")
local Town = require("../src/shared/Config/Town")
local Wild = require("../src/shared/Config/Wild")
local expect = require("./lib/expect")

-- Plot numbers copied from Config/Plots (it holds Color3 and Vector3 values, so Lune can't load it)
local WORLD: WalkerRules.World = {
	perRow = 3,
	plotWidth = 40,
	plotDepth = 40,
	gap = 24,
	streetWidth = 96,
	spring = { x = Wild.SPRING.x, z = Wild.SPRING.z },
}

local function plotCentres(): { { x: number, z: number } }
	local centres = {}
	for _, side in { -1, 1 } do
		for col = 0, WORLD.perRow - 1 do
			local x = (col - (WORLD.perRow - 1) / 2) * (WORLD.plotWidth + WORLD.gap)
			table.insert(centres, { x = x, z = side * (WORLD.streetWidth + WORLD.plotDepth) / 2 })
		end
	end
	return centres
end

local function fromSpring(point: { x: number, z: number }): number
	return math.sqrt((point.x - WORLD.spring.x) ^ 2 + (point.z - WORLD.spring.z) ^ 2)
end

local function counts(shops, rolls: number): { [number]: number }
	local result: { [number]: number } = {}
	for step = 0, rolls - 1 do
		local id = WalkerRules.chooseShop(Customers, shops, (step + 0.5) / rolls)
		if id then
			result[id] = (result[id] or 0) + 1
		end
	end
	return result
end

return {
	["walkers only go to open shops"] = function()
		local closed = { { id = 1, rating = 5, open = false, hasWanted = false }, { id = 2, rating = 3, open = false, hasWanted = false } }
		expect.equal(WalkerRules.chooseShop(Customers, closed, 0.5), nil)
		local oneOpen = { { id = 1, rating = 5, open = false, hasWanted = true }, { id = 2, rating = 1, open = true, hasWanted = false } }
		for _, roll in { 0, 0.5, 0.99 } do
			expect.equal(WalkerRules.chooseShop(Customers, oneOpen, roll), 2)
		end
	end,

	["better rated shops draw more walkers"] = function()
		local result = counts({ { id = 1, rating = 5, open = true, hasWanted = false }, { id = 2, rating = 3, open = true, hasWanted = false } }, 1000)
		local ratio = (result[1] or 0) / math.max(1, result[2] or 0)
		assert(ratio > 2.4 and ratio < 3.2, `about (5/3)^2 = 2.78, got {ratio}`)
	end,

	["a collector heads for the shop showing its card"] = function()
		local result = counts({ { id = 1, rating = 3, open = true, hasWanted = true }, { id = 2, rating = 3, open = true, hasWanted = false } }, 1000)
		local ratio = (result[1] or 0) / math.max(1, result[2] or 0)
		assert(ratio > 2.6 and ratio < 3.4, `wantedBonus 3, got {ratio}`)
	end,

	["they sit on free benches only"] = function()
		local stops = { { kind = "bench", free = false }, { kind = "fountain", free = true } }
		expect.equal(WalkerRules.nextStop(Customers, stops, 0.1), 2, "the bench is taken")
		expect.equal(WalkerRules.nextStop(Customers, { { kind = "bench", free = false } }, 0.5), nil, "nowhere free")
		local free = { { kind = "bench", free = true }, { kind = "spot", free = true } }
		expect.equal(WalkerRules.nextStop(Customers, free, 0.1), 1, "under sitChance: the bench")
		expect.equal(WalkerRules.nextStop(Customers, free, 0.9), 2, "over it: a spot")
		expect.equal(WalkerRules.nextStop(Customers, { { kind = "bench", free = true } }, 0.9), 1, "only a bench free: sit anyway")
	end,

	["walkers stroll the whole street, not just the plaza"] = function()
		local stops = WalkerRules.townStops(Customers, Town, WORLD)
		for _, side in { -1, 1 } do
			local west, east = false, false
			for _, stop in stops do
				if stop.z * side > 0 then
					west = west or stop.x < -60
					east = east or stop.x > 60
				end
			end
			assert(west and east, `stops reach both ends of the {if side < 0 then "north" else "south"} side`)
		end
		for _, stop in stops do
			assert(math.abs(stop.x) <= Town.LAYOUT.STREET_HALF_LENGTH, `stop at x {stop.x} is past the street's end`)
			assert(math.abs(stop.z) <= WORLD.streetWidth / 2, `stop at z {stop.z} is inside a shop row`)
		end
	end,

	["every shop has window spots on its sidewalk, facing it"] = function()
		local stops = WalkerRules.townStops(Customers, Town, WORLD)
		local front = WORLD.streetWidth / 2
		for _, plot in plotCentres() do
			local side = if plot.z > 0 then 1 else -1
			local found = 0
			for _, stop in stops do
				if stop.kind == "window" and math.abs(stop.x - plot.x) <= WORLD.plotWidth / 2 and stop.z * side > 0 then
					local z = math.abs(stop.z)
					assert(z >= front - Town.LAYOUT.SIDEWALK and z <= front, "on the sidewalk")
					assert((stop.faceZ - stop.z) * side > 0, "facing the shop")
					found += 1
				end
			end
			assert(found >= 2, `the shop at x {plot.x} has {found} window spots`)
		end
	end,

	["no stop crowds the fountain or the gazebo"] = function()
		local clear = Plaza.GAZEBO.platform.radius + Customers.PATH_AGENT.AgentRadius
		for _, stop in WalkerRules.townStops(Customers, Town, WORLD) do
			if stop.kind ~= "bench" then
				assert(fromSpring(stop) >= clear, `a {stop.kind} stop {fromSpring(stop)} studs from the spring`)
			end
		end
	end,

	["they arrive and leave at the street's ends"] = function()
		local exits = WalkerRules.exits(Customers, Town)
		expect.equal(#exits, 2)
		for _, exit in exits do
			assert(math.abs(exit.x) > WORLD.plotWidth * 2, "past the shops")
			assert(math.abs(exit.x) <= Town.LAYOUT.STREET_HALF_LENGTH, "on the street")
		end
		local west = if exits[1].x < exits[2].x then 1 else 2
		expect.equal(WalkerRules.nearestExit(exits, -50, 30), west, "the west end is nearer")
		expect.equal(WalkerRules.nearestExit(exits, 50, -30), 3 - west, "the east end is nearer")
	end,

	["walkers walk, never run or jump"] = function()
		local walkers = Customers.WALKERS
		assert(walkers.walkSpeed < Customers.WALK_SPEED, "slower than shoppers")
		assert(walkers.walkSpeed <= walkers.walkClipPace, "no faster than the walk clip's own pace")
		expect.equal(walkers.agent.AgentCanJump, false, "the path never jumps")
	end,
}
