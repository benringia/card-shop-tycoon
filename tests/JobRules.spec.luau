--!strict
local JobRules = require("../src/shared/Util/JobRules")
local config = require("../src/shared/Config/Jobs")
local expect = require("./lib/expect")

return {
	["speed factor: rarity spread, clamped"] = function()
		expect.near(JobRules.getSpeedFactor(config, 14), 1, 1e-9, "Very Rare SPD is base speed")
		expect.near(JobRules.getSpeedFactor(config, 10), (10 / 14) ^ 1.5, 1e-9, "Common C is slow (~0.60)")
		expect.near(JobRules.getSpeedFactor(config, 20), (20 / 14) ^ 1.5, 1e-9, "Legendary C is fast (~1.71)")
		expect.near(JobRules.getSpeedFactor(config, 100), 2.5, 1e-9, "max")
		expect.near(JobRules.getSpeedFactor(config, 1), 0.4, 1e-9, "min")
		expect.near(JobRules.getSpeedFactor(config, 0 / 0), 1, 1e-9, "NaN -> base")
	end,
	["durations: a Common C scans much slower than a Legendary"] = function()
		local common = JobRules.getDuration(config, 1.2, 10)
		local legendary = JobRules.getDuration(config, 1.2, 20)
		expect.near(common, 1.2 / (10 / 14) ^ 1.5, 1e-9, "common")
		assert(common > legendary * 2.5, `common {common} vs legendary {legendary}`)
		expect.near(JobRules.getDuration(config, 2, 14), 2, 1e-9, "base")
	end,
	["mistake chance falls with power"] = function()
		expect.near(JobRules.getMistakeChance(config, 100), 0.20, 1e-9, "weak")
		expect.near(JobRules.getMistakeChance(config, 170), 0.20, 1e-9, "low end")
		expect.near(JobRules.getMistakeChance(config, 485), 0.03, 1e-9, "high end")
		expect.near(JobRules.getMistakeChance(config, 900), 0.03, 1e-9, "strong")
		expect.near(JobRules.getMistakeChance(config, 327.5), 0.115, 1e-9, "middle")
	end,
	["slots by level and pass"] = function()
		expect.equal(JobRules.getSlotCount(config, 9, true), 0, "locked below Lv 10")
		expect.equal(JobRules.getSlotCount(config, 10, false), 1, "free slot")
		expect.equal(JobRules.getSlotCount(config, 12, true), 2, "with pass")
	end,
}
