--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): a 10-12 s flight past Forest Falls, Frostpeak, the plaza and
-- Ember Canyon to the player's own shop, as a time-lapse from morning to sunset that holds sunset for the last half.
local welcome = require("../src/shared/Config/Welcome")
local WelcomePath = require("../src/shared/Util/WelcomePath")
local expect = require("./lib/expect")

local DOOR = { x = -64, y = 0, z = -48 }
local OUT = { x = 0, z = 1 }

return {
	["the flight lasts 10-12 seconds"] = function()
		assert(welcome.SECONDS >= 10 and welcome.SECONDS <= 12, `{welcome.SECONDS} s`)
	end,

	["it ends at the player's own shop"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local pos, look = WelcomePath.sample(keys, 1)
		expect.near(pos.z, DOOR.z + welcome.SHOP_VIEW.back, 1e-6, "in front of the door")
		expect.near(pos.y, DOOR.y + welcome.SHOP_VIEW.up, 1e-6, "a little above it")
		expect.near(look.x, DOOR.x, 1e-6, "looking at it")
		expect.near(look.z, DOOR.z, 1e-6, "looking at it")
	end,

	["it starts at the first key"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local pos = WelcomePath.sample(keys, 0)
		expect.near(pos.x, welcome.KEYS[1].pos.x, 1e-6, "x")
		expect.near(pos.z, welcome.KEYS[1].pos.z, 1e-6, "z")
	end,

	["sunset holds for the last half"] = function()
		expect.equal(WelcomePath.dayProgress(welcome, 0), 0, "morning at the start")
		expect.equal(WelcomePath.dayProgress(welcome, 0.5), 1, "sunset by halfway")
		expect.equal(WelcomePath.dayProgress(welcome, 0.9), 1, "still sunset")
		local quarter = WelcomePath.dayProgress(welcome, 0.25)
		assert(quarter > 0 and quarter < 1, "a time-lapse in between")
	end,

	["keys run in order through the three areas and the plaza"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		expect.equal(keys[1].t, 0, "starts at 0")
		expect.equal(keys[#keys].t, 1, "ends at 1")
		for index = 2, #keys do
			assert(keys[index].t > keys[index - 1].t, `key {index} is out of order`)
		end
		expect.equal(#keys, #welcome.KEYS + 1, "every config key plus the shop")
	end,

	["the flight moves smoothly (no jumps between frames)"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local last = WelcomePath.sample(keys, 0)
		local steps = welcome.SECONDS * 60
		for step = 1, steps do
			local pos = WelcomePath.sample(keys, step / steps)
			local jump = math.sqrt((pos.x - last.x) ^ 2 + (pos.y - last.y) ^ 2 + (pos.z - last.z) ^ 2)
			assert(jump < 8, `a {jump}-stud jump at frame {step}`)
			last = pos
		end
	end,
}
