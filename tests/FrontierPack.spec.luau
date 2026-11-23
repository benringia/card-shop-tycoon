--!strict
-- The Frontier Pack (owner 2026-11-23: Frontier cards "take ages to find it and upgrade it", pick B: their own pack,
-- stocked once the Frost Tyrant is beaten): what it rolls, what it costs, and the lock on ordering it
local PackOdds = require("../src/shared/Config/PackOdds")
local CardList = require("../src/shared/Config/CardList")
local Products = require("../src/shared/Config/Products")
local Items = require("../src/shared/Config/Items")
local Bosses = require("../src/shared/Config/Bosses")
local OrderRules = require("../src/shared/Util/OrderRules")
local expect = require("./lib/expect")

local PACK = Products.ById.FrontierPack
local FIRST_SPARK = Products.ById.FirstSparkPack

local function chance(slots: { { { rarity: string, weight: number } } }, rarity: string): number
	-- the chance a pack holds at least one of `rarity`
	local none = 1
	for _, slot in slots do
		local total, hit = 0, 0
		for _, option in slot do
			total += option.weight
			if option.rarity == rarity then
				hit += option.weight
			end
		end
		none *= 1 - hit / total
	end
	return 1 - none
end

return {
	["every slot rolls only rarities the Frontier set has, so no slot can come up empty"] = function()
		local has: { [string]: boolean } = {}
		for _, row in CardList.FRONTIER do
			has[row[3]] = true
		end
		local slots = PackOdds.SLOTS.FrontierPack
		expect.equal(#slots, 5, "5 cards, as the pack's art says")
		for index, slot in slots do
			for _, option in slot do
				assert(has[option.rarity], `slot {index}: no Frontier {option.rarity}`)
			end
		end
	end,

	["about one Epic in two packs, a Legendary one in twenty"] = function()
		local slots = PackOdds.SLOTS.FrontierPack
		local epic = chance(slots, "Epic")
		assert(epic > 0.4 and epic < 0.6, `an Epic in {epic}`)
		expect.near(chance(slots, "Legendary"), 0.05, 0.001)
	end,

	["a Legendary per dollar like a First Spark pack's"] = function()
		local frontier = chance(PackOdds.SLOTS.FrontierPack, "Legendary") / PACK.marketPrice
		local firstSpark = chance(PackOdds.SLOTS.FirstSparkPack, "Legendary") / FIRST_SPARK.marketPrice
		expect.near(frontier, firstSpark, firstSpark * 0.05)
	end,

	["stocking it pays the same share as a First Spark pack"] = function()
		expect.near(PACK.boxCost / (PACK.unitsPerBox * PACK.marketPrice), FIRST_SPARK.boxCost / (FIRST_SPARK.unitsPerBox * FIRST_SPARK.marketPrice), 0.001)
		assert(OrderRules.profit(PACK) > 0, "a box makes money")
	end,

	["it opens with the Frost Tyrant, a boss that exists, not a shop level"] = function()
		local boss = PACK.unlockBoss
		assert(boss, "a boss to beat")
		assert(Bosses.BOSSES[boss.id], `{boss.id} is a boss`)
		expect.equal(Bosses.BOSSES[boss.id].name, boss.name)
		expect.equal(PACK.unlockLevel, 1, "no level line (Util/LevelRules leaves it out)")
	end,

	["ordering: locked until the boss is beaten, with the reason"] = function()
		local byId = Products.ById
		local cart = {}
		local locked = OrderRules.addLook(PACK, 40, 10000, cart, byId, 12, false, OrderRules.clearedSet("meadowWarden"))
		expect.equal(locked.state, "locked")
		expect.equal(locked.text, "Beat the Frost Tyrant first")
		expect.equal(locked.why, "Beat the Frost Tyrant to stock Frontier Booster Packs.")
		expect.equal(OrderRules.addLook(PACK, 40, 10000, cart, byId, 12, true, {}).text, "Beat Frost Tyrant", "a phone's short words")
		expect.equal(OrderRules.addLook(PACK, 40, 10000, cart, byId, 12, false, OrderRules.clearedSet("caveBroodQueen,frostTyrant")).state, "ready")
		expect.equal(OrderRules.addLook(FIRST_SPARK, 40, 10000, cart, byId, 12, false, nil).state, "ready", "other products don't care")
	end,

	["the beaten bosses read from the BossesCleared attribute"] = function()
		local set = OrderRules.clearedSet("frostTyrant,meadowWarden")
		expect.equal(set.frostTyrant, true)
		expect.equal(set.meadowWarden, true)
		expect.isNil(set.stormSovereign)
		expect.isNil(next(OrderRules.clearedSet(nil)), "nothing beaten yet")
		expect.isNil(next(OrderRules.clearedSet("")), "an empty list")
		expect.equal(OrderRules.isOpen(PACK, 1, OrderRules.clearedSet("frostTyrant")), true)
		expect.equal(OrderRules.isOpen(PACK, 99, {}), false)
	end,

	["its packs go in the Bag and open from there"] = function()
		local item = Items.ITEMS.frontierPack
		assert(item, "a Bag item")
		expect.equal(item.open, "FrontierPack")
		expect.equal(item.stock, "FrontierPack")
	end,
}
