--!strict
local JobRules = require("../src/shared/Util/JobRules")
local config = require("../src/shared/Config/Jobs")
local expect = require("./lib/expect")

return {
	["speed factor clamps"] = function()
		expect.near(JobRules.getSpeedFactor(config, 12), 1, 1e-9, "reference")
		expect.near(JobRules.getSpeedFactor(config, 24), 2, 1e-9, "double")
		expect.near(JobRules.getSpeedFactor(config, 100), 2, 1e-9, "max")
		expect.near(JobRules.getSpeedFactor(config, 1), 0.6, 1e-9, "min")
		expect.near(JobRules.getSpeedFactor(config, 0 / 0), 1, 1e-9, "NaN -> base")
	end,
	["durations shrink with speed"] = function()
		expect.near(JobRules.getDuration(config, 2, 24), 1, 1e-9, "fast")
		expect.near(JobRules.getDuration(config, 2, 12), 2, 1e-9, "base")
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
