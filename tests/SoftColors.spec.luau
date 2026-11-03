--!strict
local BabyColors = require("../src/shared/Config/BabyColors")
local ContrastRules = require("../src/shared/Util/ContrastRules")
local SoftColors = require("../src/shared/Util/SoftColors")
local expect = require("./lib/expect")

local WHITE = { 255, 255, 255 }
local BRIGHT = { "pink", "sky", "mint", "lilac", "peach" }

return {
	["every baby colour's deep shade reads white labels at 3:1"] = function()
		for name, colour in BabyColors.COLORS do
			if name ~= "white" then
				local ratio = ContrastRules.ratio(colour.deep, WHITE)
				expect.equal(ratio >= 3, true, `{name}'s deep shade is {string.format("%.2f", ratio)}:1 against white`)
			end
		end
	end,

	["light buttons get plum text, bright ones white"] = function()
		local colors = BabyColors.COLORS
		expect.equal(SoftColors.textOn(colors.butter.fill, BabyColors.LIGHT_LUMA), "ink")
		expect.equal(SoftColors.textOn(colors.white.fill, BabyColors.LIGHT_LUMA), "ink")
		for _, name in BRIGHT do
			expect.equal(SoftColors.textOn(colors[name].fill, BabyColors.LIGHT_LUMA), "white", name)
		end
		expect.equal(ContrastRules.ratio(BabyColors.INK, colors.butter.fill) >= 4.5, true, "plum on butter")
		expect.equal(ContrastRules.ratio(BabyColors.INK, colors.white.fill) >= 4.5, true, "plum on white")
	end,

	["the kit's roles and the five elements map to baby colours"] = function()
		for role, name in BabyColors.ROLES do
			expect.equal(BabyColors.COLORS[name] ~= nil, true, `{role} -> {name}`)
		end
		local count = 0
		for element, name in BabyColors.ELEMENTS do
			count += 1
			expect.equal(BabyColors.COLORS[name] ~= nil, true, `{element} -> {name}`)
		end
		expect.equal(count, 5)
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			expect.equal(BabyColors.ELEMENTS[element] ~= nil, true, element)
		end
	end,

	["deepOf gives a named colour's deep shade, else the fill darkened by 35%"] = function()
		local sky = BabyColors.COLORS.sky
		local deep = SoftColors.deepOf(sky.fill, BabyColors.COLORS)
		expect.equal(deep[1] == sky.deep[1] and deep[2] == sky.deep[2] and deep[3] == sky.deep[3], true, "named")
		local other = SoftColors.deepOf({ 200, 100, 50 }, BabyColors.COLORS)
		expect.near(other[1], 130, 1)
		expect.near(other[2], 65, 1)
		expect.near(other[3], 32.5, 1)
	end,
}
