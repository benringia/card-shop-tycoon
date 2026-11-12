--!strict
local AmbienceRules = require("../src/shared/Util/AmbienceRules")
local expect = require("./lib/expect")

return {
	["nextAt: inside its range from now"] = function()
		expect.equal(AmbienceRules.nextAt(100, { 50, 80 }, 0), 150, "low end")
		expect.equal(AmbienceRules.nextAt(100, { 50, 80 }, 1), 180, "high end")
	end,

	["roarVolume: grows room by room"] = function()
		expect.equal(AmbienceRules.roarVolume(0, 6, { 0.15, 0.5 }), 0.15, "start")
		expect.equal(AmbienceRules.roarVolume(6, 6, { 0.15, 0.5 }), 0.5, "the end")
		expect.equal(AmbienceRules.roarVolume(3, 6, { 0.15, 0.5 }) > 0.15, true, "louder midway")
		expect.equal(AmbienceRules.roarVolume(9, 6, { 0.15, 0.5 }), 0.5, "capped")
	end,

	["heartbeat: silent early, full at the chamber"] = function()
		expect.equal(AmbienceRules.heartbeat(2, 4, 6), 0, "early")
		expect.equal(AmbienceRules.heartbeat(6, 4, 6), 1, "at the chamber")
		local mid = AmbienceRules.heartbeat(5, 4, 6)
		expect.equal(mid > 0 and mid < 1, true, "rising")
	end,

	["heartbeat: heard already at the `from` step (the lock), full after it"] = function()
		expect.equal(AmbienceRules.heartbeat(4, 5, 6), 0, "before the lock")
		expect.equal(AmbienceRules.heartbeat(5, 5, 6), 0.5, "at the lock")
		expect.equal(AmbienceRules.heartbeat(6, 5, 6), 1, "the chamber")
	end,
}
