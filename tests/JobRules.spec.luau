--!strict
local JobRules = require("../src/shared/Util/JobRules")
local config = require("../src/shared/Config/Jobs")
local expect = require("./lib/expect")

return {
	["saved job locks: valid entries only, one job per card"] = function()
		local locks = JobRules.getSavedLocks(config, {
			{ slot = 1, beastId = "a", job = "Cashier" },
			{ slot = 2, beastId = "b", job = "Restocker" },
			{ slot = 3, beastId = "a", job = "Restocker" }, -- same card twice: first wins
			{ slot = 4, beastId = "c", job = "Juggler" }, -- not a job
			{ slot = 5, beastId = 7, job = "Cashier" }, -- bad id
			"junk",
		})
		expect.equal(locks.a, "Cashier", "a")
		expect.equal(locks.b, "Restocker", "b")
		expect.isNil(locks.c, "unknown job")
		local count = 0
		for _ in locks do
			count += 1
		end
		expect.equal(count, 2, "two locks")
		expect.equal(next(JobRules.getSavedLocks(config, "nope")), nil, "junk -> none")
	end,

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
	["nextJob: the other job, wrapping round"] = function()
		expect.equal(JobRules.nextJob({ "Restocker", "Cashier" }, "Restocker"), "Cashier", "next")
		expect.equal(JobRules.nextJob({ "Restocker", "Cashier" }, "Cashier"), "Restocker", "wraps")
		expect.isNil(JobRules.nextJob({ "Restocker", "Cashier" }, "Juggler"), "not a job")
	end,
	["speedWord: kid words and a tone for the work speed"] = function()
		expect.equal((JobRules.speedWord(config, 1.7)), "Very fast", "very fast")
		expect.equal((JobRules.speedWord(config, 1.05)), "Normal speed", "normal")
		local word, tone = JobRules.speedWord(config, 0.45)
		expect.equal(word, "Very slow", "very slow")
		expect.equal(tone, "bad", "red")
	end,
	["mistakeWord: kid words and a tone for the mistake chance"] = function()
		local word, tone = JobRules.mistakeWord(config, 0.03)
		expect.equal(word, "Almost no mistakes", "strong card")
		expect.equal(tone, "good", "green")
		expect.equal((JobRules.mistakeWord(config, 0.11)), "Some mistakes", "middling")
		expect.equal((JobRules.mistakeWord(config, 0.2)), "Lots of mistakes", "weak card")
	end,
	["minutesToNext: whole minutes of work to the next level"] = function()
		expect.equal(JobRules.minutesToNext(31, 50, 2), 10, "9.5 rounds up")
		expect.equal(JobRules.minutesToNext(49, 50, 2), 1, "almost there")
		expect.isNil(JobRules.minutesToNext(0, 0, 2), "max level")
	end,
}
