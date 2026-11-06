--!strict
-- Client-only stages (binder, card view, pack opening) go right above the player, so the camera never leaves the light
-- Roblox keeps round it (a far stage left the shop lit like the open air for ~20 s after it closed)
local StageRules = require("../src/shared/Util/StageRules")
local Stages = require("../src/shared/Config/Stages")
local expect = require("./lib/expect")

local BASE = { x = 10, y = 4, z = -20 }
local FAR = { x = 0, y = 3200, z = 0 }

return {
	["the stage goes at the first clear height above the player"] = function()
		local spot, near = StageRules.pick(BASE, { 120, 160, 200 }, function()
			return true
		end, FAR)
		expect.equal(near, true)
		expect.equal(spot.x, BASE.x)
		expect.equal(spot.y, BASE.y + 120)
		expect.equal(spot.z, BASE.z)
	end,

	["a blocked height is skipped"] = function()
		local spot, near = StageRules.pick(BASE, { 120, 160, 200 }, function(at)
			return at.y > BASE.y + 150
		end, FAR)
		expect.equal(near, true)
		expect.equal(spot.y, BASE.y + 160)
	end,

	["with every height blocked it falls back to the far stage"] = function()
		local spot, near = StageRules.pick(BASE, { 120, 160 }, function()
			return false
		end, FAR)
		expect.equal(near, false)
		expect.equal(spot.y, FAR.y)
		local none = StageRules.pick(BASE, {}, function()
			return true
		end, FAR)
		expect.equal(none.y, FAR.y, "no heights to try")
	end,

	["every height stays inside the light Roblox keeps round the camera"] = function()
		assert(#Stages.LIFTS > 0, "some heights to try")
		local last = 0
		for _, lift in Stages.LIFTS do
			assert(lift > last, "lowest first")
			-- measured 2026-11-06: 220 studs up for 15 s kept the shop's light, 400 lost it
			assert(lift <= Stages.KEEPS_LIGHT, `{lift} studs is past {Stages.KEEPS_LIGHT}`)
			last = lift
		end
		assert(Stages.LIFTS[1] >= Stages.CLEAR_OF_TOWN, "clear of the town's tallest pieces")
	end,
}
