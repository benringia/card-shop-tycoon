--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8): total XP = BASE_XP x (level - 1) ^ POWER, rounded.
local LevelMath = require("../src/shared/Util/LevelMath")
local config = require("../src/shared/Config/Levels")
local expect = require("./lib/expect")

local function required(level: number): number
	return LevelMath.getRequiredXp(config, level)
end

return {
	-- Shop XP: a sale's total rounded, at least `minXp`; ripping a pack from your stock gives what selling it would (its
	-- market price; owner 2026-11-16: "pish should encourage players to rip packs for faster exp")
	["a sale or a rip gives its price in shop XP, at least the minimum"] = function()
		expect.equal(LevelMath.saleXp(12.6, 1), 13)
		expect.equal(LevelMath.saleXp(2.4, 1), 2)
		expect.equal(LevelMath.saleXp(0.2, 1), 1, "a tiny sale still counts")
		expect.equal(LevelMath.saleXp(0 / 0, 1), 1, "junk: the minimum")
	end,

	["Lv 1 is free and the first levels come quickly"] = function()
		expect.equal(required(1), 0, "Lv 1")
		expect.equal(required(2), 10, "Lv 2")
		expect.equal(required(3), 50, "Lv 3")
		local five = required(5)
		assert(five >= 230 and five <= 270, `Lv 5 needs {five}, want about 250`)
	end,

	-- Owner 2026-11-16: "maybe adjust the shop leveling. I think it takes too long to level up" (2.7x faster), then
	-- 2026-11-17: "I just want the fast level to be the retention mechanism make the players feel progress always ...
	-- make it like 4": every level needs 10 / 40 of round 4's XP (Lv 20, where shop jobs open, was about 36,000)
	["Lv 20 (shop jobs) about 4x sooner than round 4"] = function()
		local xp = required(20)
		assert(math.abs(xp - 9000) <= 90, `Lv 20 needs {xp}, want about 9,000`)
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
		assert(top >= 400000 and top <= 415000, `Lv 100 needs {top}, want about 407,000`)
	end,

	["level for xp"] = function()
		expect.equal(LevelMath.getLevelForXp(config, 0), 1, "start")
		expect.equal(LevelMath.getLevelForXp(config, required(2) - 1), 1, "just under Lv 2")
		expect.equal(LevelMath.getLevelForXp(config, required(2)), 2, "Lv 2")
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
