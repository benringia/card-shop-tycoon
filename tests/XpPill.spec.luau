--!strict
local XpPill = require("../src/shared/Util/XpPill")
local expect = require("./lib/expect")

return {
	["the count-up starts on the old value, ends exactly on the new one, never past it"] = function()
		expect.equal(XpPill.countUp(100, 900, 0), 100)
		expect.equal(XpPill.countUp(100, 900, 1), 900)
		local last = 100
		for step = 1, 20 do
			local shown = XpPill.countUp(100, 900, step / 20)
			expect.equal(shown == math.floor(shown), true, "whole numbers")
			expect.equal(shown >= last and shown <= 900, true, "climbs, never past the new value")
			last = shown
		end
		expect.equal(XpPill.countUp(900, 100, 0.5) <= 900 and XpPill.countUp(900, 100, 0.5) >= 100, true, "counts down too")
		expect.equal(XpPill.countUp(100, 900, 2), 900, "t past 1 stays on the new value")
	end,
}
