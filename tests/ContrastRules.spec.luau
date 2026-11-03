--!strict
local ContrastRules = require("../src/shared/Util/ContrastRules")
local CreamTheme = require("../src/shared/Config/CreamTheme")
local expect = require("./lib/expect")

return {
	["contrast of black on white is 21, a colour on itself 1"] = function()
		expect.near(ContrastRules.ratio({ 0, 0, 0 }, { 255, 255, 255 }), 21, 1e-6)
		expect.near(ContrastRules.ratio({ 120, 40, 200 }, { 120, 40, 200 }), 1, 1e-9)
		expect.near(ContrastRules.ratio({ 255, 255, 255 }, { 0, 0, 0 }), 21, 1e-6, "order doesn't matter")
	end,

	["the cream theme's text reads on its surfaces"] = function()
		local t = CreamTheme
		for _, surface in { t.bodyTop, t.bodyBottom, t.row, t.slotEmpty } do
			expect.equal(ContrastRules.ratio(t.ink, surface) >= 4.5, true, "body text")
			expect.equal(ContrastRules.ratio(t.inkSoft, surface) >= 4.5, true, "secondary text")
			expect.equal(ContrastRules.ratio(t.hint, surface) >= 4.5, true, "hints")
			expect.equal(ContrastRules.ratio(t.good, surface) >= 4.5, true, "good news (fast, ready)")
			expect.equal(ContrastRules.ratio(t.bad, surface) >= 4.5, true, "bad news (resting, mistakes)")
			expect.equal(ContrastRules.ratio(t.power, surface) >= 4.5, true, "Power numbers")
			expect.equal(ContrastRules.ratio(t.fair, surface) >= 4.5, true, "fair prices")
		end
	end,

	["hue is the colour wheel angle: red 0, yellow 60, green 120, blue 240"] = function()
		expect.near(ContrastRules.hue({ 255, 0, 0 }), 0, 1e-9)
		expect.near(ContrastRules.hue({ 255, 255, 0 }), 60, 1e-9)
		expect.near(ContrastRules.hue({ 0, 128, 0 }), 120, 1e-9)
		expect.near(ContrastRules.hue({ 0, 0, 255 }), 240, 1e-9)
		expect.near(ContrastRules.hue({ 255, 0, 128 }), 360 - 30.1176, 1e-3, "magenta-red wraps below 360")
	end,

	["the price bands differ at a glance: good, fair, pricey, bad at least 20 degrees apart in hue"] = function()
		local t = CreamTheme
		local bands = { good = t.good, fair = t.fair, pricey = t.power, bad = t.bad }
		for nameA, a in bands do
			for nameB, b in bands do
				if nameA < nameB then
					local apart = math.abs(ContrastRules.hue(a) - ContrastRules.hue(b))
					apart = math.min(apart, 360 - apart)
					expect.equal(apart >= 20, true, `{nameA} and {nameB} are {math.floor(apart)} degrees apart`)
				end
			end
		end
	end,

	["every header band has a top and a bottom colour"] = function()
		for _, name in { "Bag", "Cards", "Bosses", "Party", "Shop", "Prices", "Jobs", "Default" } do
			local band = CreamTheme.headers[name]
			expect.equal(#band.top == 3 and #band.bottom == 3, true, name)
		end
	end,
}
