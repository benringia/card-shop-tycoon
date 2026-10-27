--!strict
local ItemRules = require("../src/shared/Util/ItemRules")
local config = require("../src/shared/Config/Items")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

return {
	["sanitize: unknown ids, bad counts dropped; whole numbers; capped"] = function()
		local items = ItemRules.sanitize(config, { starShard = 4.9, mystery = 3, [5] = 1 })
		expect.equal(items.starShard, 4, "floored")
		expect.isNil(items.mystery, "unknown id dropped")
		for _, bad in { -1, 0 / 0, "7", math.huge } do
			expect.isNil(ItemRules.sanitize(config, { starShard = bad }).starShard, `bad {tostring(bad)}`)
		end
		expect.equal(ItemRules.sanitize(config, { starShard = 123456 }).starShard, config.MAX_STACK, "capped")
		expect.equal(next(ItemRules.sanitize(config, "junk")), nil, "junk -> empty")
	end,

	["add: capped at the stack limit, reports what was added"] = function()
		local items, added = ItemRules.add(config, { starShard = 9998 }, "starShard", 5)
		expect.equal(items.starShard, config.MAX_STACK, "capped")
		expect.equal(added, 1, "only 1 fit")
		local fresh, one = ItemRules.add(config, {}, "starShard", 1)
		expect.equal(fresh.starShard, 1, "first shard")
		expect.equal(one, 1, "added 1")
		local _, none = ItemRules.add(config, {}, "nope", 3)
		expect.equal(none, 0, "unknown id adds nothing")
	end,

	["take: nil when short, new table when enough"] = function()
		local items = { starShard = 3 }
		expect.isNil(ItemRules.take(items, "starShard", 4), "short")
		local after = ItemRules.take(items, "starShard", 3) :: any
		expect.isNil(after.starShard, "used up -> removed")
		expect.equal(items.starShard, 3, "input untouched")
		expect.isNil(ItemRules.take(items, "starShard", -1), "negative refused")
	end,
	["every boss drop, unlock and first-clear item exists in Config/Items"] = function()
		local function check(item: string, where: string)
			assert(config.ITEMS[item], `{where} gives {item}, which isn't in Config/Items`)
		end
		for id, boss in Bosses.BOSSES do
			for _, drop in boss.drops do
				check(drop.item, `{id} drops`)
			end
			for _, grant in boss.firstClear do
				check(grant.item, `{id} first clear`)
			end
			for _, grant in boss.dailyBonus do
				check(grant.item, `{id} daily bonus`)
			end
			if boss.unlock then
				check(boss.unlock.item, `{id} unlock`)
			end
		end
		assert(typeof(config.ITEMS.xpTonic and config.ITEMS.xpTonic.xp) == "number", "the XP Tonic says how much XP it gives")
	end,
}
