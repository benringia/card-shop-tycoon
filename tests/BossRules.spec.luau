--!strict
local BossRules = require("../src/shared/Util/BossRules")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

local function record(fields: { [string]: any }): BossRules.Record
	local base = BossRules.read(nil, false)
	for key, value in fields do
		(base :: any)[key] = value
	end
	return base
end

return {
	["read: bad saves become safe defaults"] = function()
		expect.equal(BossRules.read(nil, true).unlocked, true, "an open boss starts unlocked")
		local bad = BossRules.read({ lootAt = -5, rewardedToday = 0 / 0 }, false)
		expect.equal(bad.lootAt, 0, "negative lootAt")
		expect.equal(bad.rewardedToday, 0, "NaN kills")
		expect.equal(bad.unlocked, false, "locked")
		expect.equal(bad.cleared, false, "not cleared")
		expect.equal(BossRules.read({ unlocked = true, cleared = true }, false).cleared, true, "kept")
	end,

	["canStart: open bosses start, locked ones need the fragments"] = function()
		local unlock = { item = "fragment_caveBroodQueen", count = 3 }
		expect.equal((BossRules.canStart(record({ unlocked = true }), unlock, 0)), true, "already unlocked")
		local ok, reason = BossRules.canStart(record({ unlocked = false }), unlock, 2)
		expect.equal(ok, false, "two of three")
		expect.equal(reason, "locked:2:3", "reason")
		expect.equal((BossRules.canStart(record({ unlocked = false }), unlock, 3)), true, "enough fragments")
		expect.equal((BossRules.canStart(record({ unlocked = false }), nil, 0)), true, "no unlock cost")
	end,

	["lootEligible: once the saved cooldown has passed"] = function()
		local saved = record({ lootAt = 1000 })
		expect.equal(BossRules.lootEligible(saved, 999), false, "still cooling down")
		expect.equal(BossRules.lootEligible(saved, 1000), true, "ready")
	end,

	["dayCounts: a new UTC day resets today's kills"] = function()
		local newDay = BossRules.dayCounts(record({ day = 5, rewardedToday = 9 }), 6)
		expect.equal(newDay.rewardedToday, 0, "reset")
		expect.equal(newDay.day, 6, "today")
		local sameDay = BossRules.dayCounts(record({ day = 6, rewardedToday = 9 }), 6)
		expect.equal(sameDay.rewardedToday, 9, "same day kept")
		expect.equal(BossRules.dayNumber(86400 * 3 + 5), 3, "UTC day number")
	end,

	["softCapFactor: full for 6 kills, then x0.75 each, never under 0.2"] = function()
		for kills = 0, 5 do
			expect.equal(BossRules.softCapFactor(Bosses, kills), 1, `kill {kills}`)
		end
		expect.near(BossRules.softCapFactor(Bosses, 6), 0.75, 1e-9, "7th rewarded kill")
		expect.near(BossRules.softCapFactor(Bosses, 7), 0.5625, 1e-9, "8th")
		expect.equal(BossRules.softCapFactor(Bosses, 40), 0.2, "floor")
	end,

	["overPowerFactor: far above the recommended Power drops less"] = function()
		expect.equal(BossRules.overPowerFactor(Bosses, 500, 200), 1, "2.5x is fine")
		expect.equal(BossRules.overPowerFactor(Bosses, 501, 200), 0.35, "above 2.5x")
		expect.near(BossRules.dropFactor(Bosses, record({ rewardedToday = 6 }), 501, 200), 0.75 * 0.35, 1e-9, "both together")
	end,

	["config: every boss after the first unlocks with the fragment the one before drops"] = function()
		local first = Bosses.BOSSES[Bosses.LADDER[1]]
		expect.isNil(first.unlock, "boss 1 is open")
		for index = 2, #Bosses.LADDER do
			local boss = Bosses.BOSSES[Bosses.LADDER[index]]
			local before = Bosses.BOSSES[Bosses.LADDER[index - 1]]
			assert(boss.unlock, `{boss.name} has no unlock`)
			expect.equal(boss.unlock.item, before.fragment, `{boss.name} unlocks with what {before.name} drops`)
		end
		for id, boss in Bosses.BOSSES do
			for _, drop in boss.drops do
				assert(drop.chance >= 0 and drop.chance <= 1, `{id} drop chance out of range`)
				assert(drop.min >= 1 and drop.max >= drop.min, `{id} drop count`)
			end
			assert(boss.recommended > 0 and boss.hp > 0 and boss.minFightSeconds > 0, `{id} numbers`)
		end
	end,
}
