--!strict
local ElementFx = require("../src/shared/Config/ElementFx")
local ElementFxRules = require("../src/shared/Util/ElementFxRules")
local expect = require("./lib/expect")

local INTENSITY = ElementFx.INTENSITY

return {
	["a plain grade C copy with no stars gets the base intensity"] = function()
		expect.equal(ElementFxRules.intensity(INTENSITY, "C", 0), INTENSITY.BASE, "base")
	end,

	["a grade S copy with every star is at full intensity"] = function()
		expect.equal(ElementFxRules.intensity(INTENSITY, "S", 5), 1, "full")
	end,

	["better grades and more stars are stronger"] = function()
		local c = ElementFxRules.intensity(INTENSITY, "C", 2)
		local b = ElementFxRules.intensity(INTENSITY, "B", 2)
		local a = ElementFxRules.intensity(INTENSITY, "A", 2)
		local s = ElementFxRules.intensity(INTENSITY, "S", 2)
		assert(c < b and b < a and a < s, "grades in order")
		assert(ElementFxRules.intensity(INTENSITY, "A", 3) > a, "a star adds")
	end,

	["intensity never goes past 0..1, and an unknown grade counts as C"] = function()
		expect.equal(ElementFxRules.intensity(INTENSITY, "S", 99), 1, "clamped high")
		expect.equal(ElementFxRules.intensity(INTENSITY, "Z", -4), INTENSITY.BASE + INTENSITY.PER_STAR * 0, "unknown grade, negative stars")
	end,

	["at blends a range by intensity"] = function()
		expect.equal(ElementFxRules.at({ 2, 10 }, 0), 2, "low end")
		expect.equal(ElementFxRules.at({ 2, 10 }, 1), 10, "high end")
		expect.equal(ElementFxRules.at({ 2, 10 }, 0.5), 6, "middle")
	end,

	["every element has at least one emitter and a light"] = function()
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local fx = ElementFx.ELEMENTS[element]
			assert(fx, `{element} missing`)
			assert(#fx.emitters > 0, `{element} has no emitters`)
			assert(fx.light, `{element} has no light`)
		end
	end,
}
