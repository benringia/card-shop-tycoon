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
		end
	end,

	["every header band has a top and a bottom colour"] = function()
		for _, name in { "Bag", "Cards", "Bosses", "Party", "Shop", "Prices", "Jobs", "Default" } do
			local band = CreamTheme.headers[name]
			expect.equal(#band.top == 3 and #band.bottom == 3, true, name)
		end
	end,
}
