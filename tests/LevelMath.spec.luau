--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8): total XP = BASE_XP x (level - 1) ^ POWER, rounded.
local LevelMath = require("../src/shared/Util/LevelMath")
local config = require("../src/shared/Config/Levels")
local expect = require("./lib/expect")

local function required(level: number): number
	return LevelMath.getRequiredXp(config, level)
end

return {
	["Lv 1 is free and Lv 2 is 40"] = function()
		expect.equal(required(1), 0, "Lv 1")
		expect.equal(required(2), 40, "Lv 2")
		expect.equal(required(3), 200, "Lv 3")
	end,

	["Lv 20 keeps today's jobs XP"] = function()
		local xp = required(20)
		assert(math.abs(xp - 36000) <= 360, `Lv 20 needs {xp}, want about 36,000`)
	end,

	["every step is bigger than the last"] = function()
		for level = 2, 99 do
			local step = required(level + 1) - required(level)
			local before = required(level) - required(level - 1)
			assert(step > before, `Lv {level} -> {level + 1} step {step} is not bigger than {before}`)
		end
	end,

	["Lv 100 is the cap"] = function()
		expect.equal(config.MAX_LEVEL, 100, "MAX_LEVEL")
		expect.equal(LevelMath.getLevelForXp(config, required(100)), 100, "exactly Lv 100")
		expect.equal(LevelMath.getLevelForXp(config, 1e12), 100, "huge xp stops at 100")
		local top = required(100)
		assert(top >= 1600000 and top <= 1660000, `Lv 100 needs {top}, want about 1.63M`)
	end,

	["level for xp"] = function()
		expect.equal(LevelMath.getLevelForXp(config, 0), 1, "start")
		expect.equal(LevelMath.getLevelForXp(config, 39), 1, "just under Lv 2")
		expect.equal(LevelMath.getLevelForXp(config, 40), 2, "Lv 2")
		expect.equal(LevelMath.getLevelForXp(config, required(20) - 1), 19, "just under Lv 20")
	end,

	["progress at the cap has no span"] = function()
		local _, span = LevelMath.getProgress(config, 1e9)
		expect.equal(span, 0, "span at Lv 100")
	end,

	["progress mid-level"] = function()
		local into, span = LevelMath.getProgress(config, required(5) + 10)
		expect.equal(into, 10, "into Lv 5")
		expect.equal(span, required(6) - required(5), "Lv 5 -> 6")
	end,

	["bad xp is level 1"] = function()
		expect.equal(LevelMath.getLevelForXp(config, 0 / 0), 1, "NaN")
		expect.equal(LevelMath.getLevelForXp(config, -5), 1, "negative")
	end,
}
