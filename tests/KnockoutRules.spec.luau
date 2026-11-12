--!strict
-- Knocked out in the Wild (owner 2026-11-12: "when I die, can we have a 20 second timer and add an option to be revived
-- at the exact same spot for robux"; spec 2026-11-12-timed-upgrades-revive-design): the countdown, paused while the
-- purchase prompt is open (Util/KnockoutRules, KnockoutService)
local KnockoutRules = require("../src/shared/Util/KnockoutRules")
local expect = require("./lib/expect")

return {
	["the countdown runs down, waits while the purchase prompt is open, a minute at most"] = function()
		expect.equal(KnockoutRules.left(0, 0, 5, 20), 15)
		expect.equal(KnockoutRules.left(0, 10, 15, 20), 15, "ten seconds paused don't count")
		expect.equal(KnockoutRules.left(0, 0, 30, 20), 0, "never below zero")
		expect.equal(KnockoutRules.pausedFor(10, 0, 100, 60), 60, "a pause counts a minute at most")
		expect.equal(KnockoutRules.pausedFor(nil, 7, 100, 60), 7, "not paused now: what was paused before")
		expect.equal(KnockoutRules.pausedFor(90, 5, 100, 60), 15, "paused ten seconds on top of five")
	end,
}
