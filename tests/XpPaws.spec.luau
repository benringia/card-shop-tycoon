--!strict
local XpPaws = require("../src/shared/Util/XpPaws")
local expect = require("./lib/expect")

return {
	["paws fill left to right with progress"] = function()
		local f = XpPaws.fills(38, 100, 5)
		expect.equal(#f, 5)
		expect.equal(f[1], 1)
		expect.near(f[2], 0.9, 1e-9)
		expect.equal(f[3], 0)
		expect.equal(f[5], 0)
	end,

	["no progress, full progress"] = function()
		for _, v in XpPaws.fills(0, 100, 5) do
			expect.equal(v, 0)
		end
		for _, v in XpPaws.fills(100, 100, 5) do
			expect.equal(v, 1)
		end
		for _, v in XpPaws.fills(250, 100, 5) do
			expect.equal(v, 1, "over the span stays full")
		end
		for _, v in XpPaws.fills(-5, 100, 5) do
			expect.equal(v, 0, "below zero stays empty")
		end
	end,

	["numbers shorten to fit the pill"] = function()
		expect.equal(XpPaws.short(640), "640")
		expect.equal(XpPaws.short(9600), "9.6k")
		expect.equal(XpPaws.short(9000), "9k", "no .0")
		expect.equal(XpPaws.short(90000), "90k")
		expect.equal(XpPaws.short(225858), "226k")
		expect.equal(XpPaws.short(1500000), "1.5M")
		expect.equal(XpPaws.short(12400000), "12M")
		expect.equal(XpPaws.short(-3), "0", "never negative")
	end,

	["the XP line under the paws: progress through the level, MAX at the top"] = function()
		expect.equal(XpPaws.label(90000, 225858), "90k / 226k")
		expect.equal(XpPaws.label(0, 120), "0 / 120")
		expect.equal(XpPaws.label(5, 0), "MAX")
	end,

	["a zero or negative span fills every paw"] = function()
		for _, v in XpPaws.fills(0, 0, 5) do
			expect.equal(v, 1)
		end
		for _, v in XpPaws.fills(3, -1, 5) do
			expect.equal(v, 1)
		end
	end,
}
