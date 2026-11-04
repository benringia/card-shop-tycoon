--!strict
local XpPill = require("../src/shared/Util/XpPill")
local expect = require("./lib/expect")

return {
	["the XP into the level, big and exact, with commas"] = function()
		expect.equal(XpPill.amount(99800, 226000), "99,800 XP")
		expect.equal(XpPill.amount(1234567, 2000000), "1,234,567 XP")
		expect.equal(XpPill.amount(0, 100), "0 XP")
		expect.equal(XpPill.amount(640.7, 1000), "640 XP", "whole XP only")
		expect.equal(XpPill.amount(-5, 100), "0 XP", "never negative")
		expect.equal(XpPill.amount(500, 0), "MAX", "the top level (a span of 0)")
	end,

	["the level's total, small after it"] = function()
		expect.equal(XpPill.total(226000), "/ 226,000")
		expect.equal(XpPill.total(950), "/ 950")
		expect.equal(XpPill.total(0), "", "nothing at the top level")
	end,

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
