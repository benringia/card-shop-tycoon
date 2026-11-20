--!strict
-- Owner 2026-11-21: "can we put a filter so the colors are not too sharp/saturated?". One dial over every sky look
-- (town, the valleys, the arenas): the world's colours a little calmer, never grey. The UI's colours are its theme's
-- (Config/CreamTheme, BabyColors); a screen filter can't reach them.
local SoftFilter = require("../src/shared/Util/SoftFilter")
local Config = require("../src/shared/Config/SoftFilter")
local expect = require("./lib/expect")

return {
	["on: every look comes out calmer"] = function()
		local saturation, contrast = SoftFilter.grade(0.18, 0.05, Config)
		assert(saturation < 0.18, "less saturated")
		assert(contrast <= 0.05, "never sharper")
		expect.equal(Config.ON, true)
		assert(Config.saturation < 0 and Config.saturation >= -0.35, "calmer, not washed out")
		assert(Config.contrast <= 0 and Config.contrast >= -0.15)
	end,

	["off: the looks as they were"] = function()
		local saturation, contrast = SoftFilter.grade(0.18, 0.05, { ON = false, saturation = -0.2, contrast = -0.05, FLOOR = -0.3 })
		expect.equal(saturation, 0.18)
		expect.equal(contrast, 0.05)
	end,

	["never grey: a look that's already muted keeps its colour"] = function()
		local saturation = SoftFilter.grade(-0.15, 0.15, Config)
		assert(saturation >= Config.FLOOR, "not under the floor")
		local already = SoftFilter.grade(-0.6, 0, Config)
		expect.equal(already, -0.6, "a look under the floor on purpose stays as it is")
	end,
}
