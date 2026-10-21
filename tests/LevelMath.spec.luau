--!strict
local LevelMath = require("../src/shared/Util/LevelMath")
local config = require("../src/shared/Config/Levels")
local expect = require("./lib/expect")

return {
	["table levels unchanged"] = function()
		expect.equal(LevelMath.getRequiredXp(config, 1), 0, "Lv 1")
		expect.equal(LevelMath.getRequiredXp(config, 2), 150, "Lv 2")
		expect.equal(LevelMath.getRequiredXp(config, 10), 36000, "Lv 10")
	end,

	["levels keep going past the table"] = function()
		-- last table step is 12000 (24000 -> 36000); each later step is 15% bigger
		expect.equal(LevelMath.getRequiredXp(config, 11), 36000 + 13800, "Lv 11")
		expect.equal(LevelMath.getRequiredXp(config, 12), 36000 + 13800 + 15870, "Lv 12")
	end,

	["level for xp, no cap"] = function()
		expect.equal(LevelMath.getLevelForXp(config, 0), 1, "start")
		expect.equal(LevelMath.getLevelForXp(config, 36000), 10, "Lv 10")
		expect.equal(LevelMath.getLevelForXp(config, 49799), 10, "just under 11")
		expect.equal(LevelMath.getLevelForXp(config, 49800), 11, "Lv 11")
		assert(LevelMath.getLevelForXp(config, 1e9) > 50, "huge xp keeps levelling")
	end,

	["progress always has a next level"] = function()
		local into, span = LevelMath.getProgress(config, 40000)
		expect.equal(into, 4000, "into Lv 10")
		expect.equal(span, 13800, "Lv 10 -> 11")
	end,

	["bad xp is level 1"] = function()
		expect.equal(LevelMath.getLevelForXp(config, 0 / 0), 1, "NaN")
		expect.equal(LevelMath.getLevelForXp(config, -5), 1, "negative")
	end,
}
