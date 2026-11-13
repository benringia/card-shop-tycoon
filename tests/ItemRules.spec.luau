--!strict
local ItemRules = require("../src/shared/Util/ItemRules")
local config = require("../src/shared/Config/Items")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

return {
	["only pack items open"] = function()
		expect.equal(ItemRules.openablePack(config, "sparkPack"), "FirstSparkPack", "the level-up pack")
		for _, bad in { "xpTonic", "nope", 42, nil } do
			expect.isNil(ItemRules.openablePack(config, bad), `not openable: {tostring(bad)}`)
		end
		expect.isNil(ItemRules.openablePack(config, nil), "nil")
	end,

	-- Turts' rug shop (spec 2026-11-13-turts-shop-design): his packs open from the Bag with their floors; the Legendary
	-- Pack's Legendary rolls the stingy pity grades, so it can't skip the long Grade S chase
	["Turts' packs open from the Bag with their floors; the Legendary Pack's grade is the stingy one"] = function()
		local product, floor, stingy = ItemRules.openablePack(config, "legendaryPack")
		expect.equal(product, "FirstSparkPack")
		expect.equal(floor, "Legendary")
		expect.equal(stingy, true)
		local _, epicFloor, epicStingy = ItemRules.openablePack(config, "epicPack")
		expect.equal(epicFloor, "Epic")
		expect.equal(epicStingy, false)
		local _, vrFloor, vrStingy = ItemRules.openablePack(config, "vrPack")
		expect.equal(vrFloor, "Very Rare")
		expect.equal(vrStingy, false)
		local _, giftFloor, giftStingy = ItemRules.openablePack(config, "pishGift")
		expect.equal(giftFloor, "Very Rare")
		expect.equal(giftStingy, false, "Pish's gift rolls its grade as usual")
		-- every item Turts sells exists
		local Turts = require("../src/shared/Config/Turts")
		for id, offer in Turts.OFFERS do
			assert(config.ITEMS[offer.item], `{id} sells {offer.item}, which isn't an item`)
		end
	end,

	-- Pish's end gift (spec 2026-11-09-tutorial-pish-design 5): a First Spark pack whose hit card is Very Rare or better
	["openablePack: the gift opens a First Spark pack with a Very Rare floor"] = function()
		local product, floor = ItemRules.openablePack(config, "pishGift")
		expect.equal(product, "FirstSparkPack")
		expect.equal(floor, "Very Rare")
		local plain, none = ItemRules.openablePack(config, "sparkPack")
		expect.equal(plain, "FirstSparkPack")
		expect.isNil(none, "the level-up pack has no floor")
	end,

	-- Round 3 (owner 2026-11-10: "we need an icon for pish's gift. that will make players excited"): his present at the
	-- start is its own item with his picture, his gift at the end too
	["Pish's present is its own item: a First Spark pack, no floor, his pictures on both gifts"] = function()
		local Pish = require("../src/shared/Config/Pish")
		local UIIcons = require("../src/shared/Config/UIIcons")
		expect.equal(Pish.FIRST_ITEM, "pishPresent")
		local product, floor = ItemRules.openablePack(config, Pish.FIRST_ITEM)
		expect.equal(product, "FirstSparkPack")
		expect.isNil(floor, "a plain pack")
		expect.equal(config.ITEMS.pishPresent.icon, "PishPresent")
		expect.equal(config.ITEMS.pishGift.icon, "PishGift")
		assert(UIIcons.PishPresent and UIIcons.PishGift, "both pictures uploaded")
	end,

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
	["bossOf: fragments and trophies name their ladder step"] = function()
		local ladder = { "meadowWarden", "caveBroodQueen", "emberColossus" }
		local index, kind = ItemRules.bossOf("fragment_caveBroodQueen", ladder)
		expect.equal(index, 2, "opens boss 2")
		expect.equal(kind, "fragment", "a fragment")
		index, kind = ItemRules.bossOf("trophy_meadowWarden", ladder)
		expect.equal(index, 1, "boss 1's trophy")
		expect.equal(kind, "trophy", "a trophy")
		expect.isNil((ItemRules.bossOf("xpTonic", ladder)), "not a boss item")
		expect.isNil((ItemRules.bossOf("fragment_unknownBoss", ladder)), "unknown boss")
	end,
}
