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

	-- Owner 2026-11-21: a tester opened 5,000 packs with Open 10 for the shop XP (15,000 for $10,000, with no limit on
	-- how fast: ten times the shop's own pace). "lets just do 2 exp after level 30": from shop Lv 30 an opened pack pays
	-- two thirds of its price in XP; selling it still pays all of it
	["an opened pack pays 3 shop XP, 2 from shop Lv 30"] = function()
		expect.equal(config.OPEN_XP.from, 30)
		expect.equal(LevelMath.openXp(3, 1, 1, config), 3, "a new shop")
		expect.equal(LevelMath.openXp(3, 1, 29, config), 3)
		expect.equal(LevelMath.openXp(3, 1, 30, config), 2)
		expect.equal(LevelMath.openXp(3, 1, 100, config), 2)
		expect.equal(LevelMath.openXp(9, 1, 29, config), 9, "a Deck Box")
		expect.equal(LevelMath.openXp(9, 1, 30, config), 6, "a Deck Box: the same share")
		expect.equal(LevelMath.openXp(0.2, 1, 50, config), 1, "never under the minimum")
		expect.equal(LevelMath.openXp(0 / 0, 1, 50, config), 1, "junk: the minimum")
		-- 5,000 packs from Lv 30 on: 10,000 XP, not 15,000
		expect.equal(LevelMath.openXp(3, 1, 40, config) * 5000, 10000)
	end,

	-- Owner 2026-11-17: "can we add a small exp to the shop from killing monsters. combat exp for pets stays the same":
	-- a won fight gives half the cash it paid in shop XP (a sale gives all of it), at least 1
	["a won fight gives half its cash in shop XP, at least 1"] = function()
		expect.equal(config.FIGHT_XP_PER_CASH, 0.5)
		expect.equal(LevelMath.fightXp(0.4, config), 1, "a Lv 1 Meadow monster ($0.40): the minimum")
		expect.equal(LevelMath.fightXp(4, config), 2, "a Lv 10 monster ($4)")
		expect.equal(LevelMath.fightXp(20, config), 10, "a Lv 50 Rift monster ($20)")
		expect.equal(LevelMath.fightXp(60, config), 30, "its elite (3x cash)")
		expect.equal(LevelMath.fightXp(36, config), 18, "the Meadow Warden ($36)")
		expect.equal(LevelMath.fightXp(400, config), 200, "the Prism Hydra ($400)")
		expect.equal(LevelMath.fightXp(0 / 0, config), 1, "junk: the minimum")
	end,

	["Lv 1 is free and the first levels come quickly"] = function()
		expect.equal(required(1), 0, "Lv 1")
		expect.equal(required(2), 10, "Lv 2")
		expect.equal(required(3), 30, "Lv 3")
		local five = required(5)
		assert(five >= 150 and five <= 180, `Lv 5 needs {five}, want about 160`)
	end,

	-- Owner 2026-11-16: "maybe adjust the shop leveling. I think it takes too long to level up" (2.7x faster), then
	-- 2026-11-17: "I just want the fast level to be the retention mechanism make the players feel progress always ...
	-- make it like 4", and the same day "is it not game breaking upping it to 6x?": every level needs 1/6 of round 4's
	-- XP (Lv 20, where shop jobs open, was about 36,000)
	["Lv 20 (shop jobs) about 6x sooner than round 4"] = function()
		local xp = required(20)
		assert(math.abs(xp - 6000) <= 60, `Lv 20 needs {xp}, want about 6,000`)
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
	end,

	-- owner 2026-11-20: "Also after level 20. make the leveling up more difficult". Up to Lv 20 nothing changes; past it
	-- each level costs the old curve's step times a factor that climbs to LATE.times by LATE.full and stays there
	["up to Lv 20 the levels cost what they did"] = function()
		local late = config.LATE
		expect.equal(late.from, 20)
		for level = 1, late.from do
			local plain = math.round(config.BASE_XP * math.max(0, level - 1) ^ config.POWER / config.ROUND_TO) * config.ROUND_TO
			expect.equal(required(level), plain, `Lv {level}`)
		end
	end,

	["past Lv 20 every level costs more than it did, with no cliff, up to three times"] = function()
		local late = config.LATE
		local function plain(level: number): number
			return config.BASE_XP * (level - 1) ^ config.POWER
		end
		assert(late.times >= 2, "clearly harder")
		assert(late.full > late.from + 3, "it climbs over several levels")
		for level = late.from + 1, 100 do
			local step = required(level) - required(level - 1)
			local before = plain(level) - plain(level - 1)
			assert(step > before * 1.05, `Lv {level} costs {step}, more than the {before} it did`)
			assert(step <= before * late.times + config.ROUND_TO, `Lv {level}: never more than {late.times}x`)
		end
		local first = (required(late.from + 1) - required(late.from)) / (required(late.from) - required(late.from - 1))
		assert(first < 1.5, `Lv 21 is {first}x Lv 20's step: no wall`)
		local full = (required(late.full + 5) - required(late.full + 4)) / (plain(late.full + 5) - plain(late.full + 4))
		assert(math.abs(full - late.times) < 0.05, `from Lv {late.full} on, {late.times}x (got {full})`)
		local top = required(100)
		assert(top > 271500 * 2 and top < 271500 * late.times, `Lv 100 needs {top}`)
	end,

	["with no LATE the curve is the plain one (older saves' maths, the migration)"] = function()
		local plainConfig = { BASE_XP = config.BASE_XP, POWER = config.POWER, ROUND_TO = config.ROUND_TO, MAX_LEVEL = config.MAX_LEVEL }
		local top = LevelMath.getRequiredXp(plainConfig, 100)
		assert(top >= 265000 and top <= 278000, `Lv 100 needed {top}, about 271,500`)
		expect.equal(LevelMath.getRequiredXp(plainConfig, 20), required(20))
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
