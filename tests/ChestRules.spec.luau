--!strict
-- The boss chests (spec 2026-11-11-boss-chests-design; the owner: "after each boss 3 or 4 chest appear ... we make the
-- player choose 1 chest to open"): the material count, what the other two chests show, where yours goes, and the
-- checks on a pick (Util/ChestRules, Config/BossChests)
local ChestRules = require("../src/shared/Util/ChestRules")
local BossChests = require("../src/shared/Config/BossChests")
local expect = require("./lib/expect")

local WEIGHTS = BossChests.MATERIAL

local function kinds(list: { ChestRules.Content }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, content in list do
		counts[content.kind] = (counts[content.kind] or 0) + 1
	end
	return counts
end

return {
	["three chests, 20 s to pick"] = function()
		expect.equal(BossChests.COUNT, 3)
		expect.equal(BossChests.PICK_SECONDS, 20)
	end,

	["material: 1, 2 or 3 by the weights, averaging today's 1.2 (80% x 1-2)"] = function()
		expect.equal(ChestRules.materialCount(0, WEIGHTS), 1)
		expect.equal(ChestRules.materialCount(0.849, WEIGHTS), 1)
		expect.equal(ChestRules.materialCount(0.85, WEIGHTS), 2)
		expect.equal(ChestRules.materialCount(0.949, WEIGHTS), 2)
		expect.equal(ChestRules.materialCount(0.95, WEIGHTS), 3)
		expect.equal(ChestRules.materialCount(0.9999, WEIGHTS), 3)
		local total, average = 0, 0
		for _, entry in WEIGHTS do
			total += entry.weight
			average += entry.count * entry.weight
		end
		expect.near(total, 1, 1e-9, "the weights add up")
		expect.near(average, 1.2, 1e-9, "the same material as today")
	end,

	-- The owner 2026-11-11: "the ? should only show if you dont have the sword"
	["the ? shows only when the weapon didn't drop and you don't have it yet"] = function()
		expect.equal(ChestRules.showsMystery(false, false), true, "a miss, not owned")
		expect.equal(ChestRules.showsMystery(false, true), false, "a miss, already yours")
		expect.equal(ChestRules.showsMystery(true, false), false, "it dropped")
		expect.equal(ChestRules.showsMystery(true, true), false)
	end,

	["with the ?: one chest shows the weapon with a ?, one some material"] = function()
		local first = ChestRules.others(true, "verdantBlade", "material_meadowWarden", { 0.5, 0.97, 0.2 }, WEIGHTS)
		expect.equal(#first, 2)
		expect.equal(first[1].kind, "mystery", "a low order roll puts the ? first")
		expect.equal(first[1].weaponId, "verdantBlade")
		expect.equal(first[2].kind, "material")
		expect.equal(first[2].item, "material_meadowWarden")
		expect.equal(first[2].count, 1, "the first count roll (0.5)")
		local second = ChestRules.others(true, "verdantBlade", "material_meadowWarden", { 0.97, 0.1, 0.8 }, WEIGHTS)
		expect.equal(second[1].kind, "material")
		expect.equal(second[1].count, 3)
		expect.equal(second[2].kind, "mystery", "a high order roll puts it second")
	end,

	["without the ? (a drop, or a weapon you have): the other two show material only"] = function()
		local list = ChestRules.others(false, "verdantBlade", "material_meadowWarden", { 0.9, 0.1, 0.3 }, WEIGHTS)
		expect.equal(#list, 2)
		local counts = kinds(list)
		expect.equal(counts.material, 2)
		expect.isNil(counts.mystery)
		expect.isNil(counts.weapon)
		expect.equal(list[1].count, 2)
		expect.equal(list[2].count, 1)
	end,

	["your chest's contents go where you tapped, the others round it in order"] = function()
		local mine: ChestRules.Content = { kind = "weapon", weaponId = "verdantBlade" }
		local a: ChestRules.Content = { kind = "material", item = "m", count = 1 }
		local b: ChestRules.Content = { kind = "mystery", weaponId = "verdantBlade" }
		for index = 1, 3 do
			local layout = ChestRules.layout(index, mine, { a, b })
			expect.equal(#layout, 3)
			expect.equal(layout[index], mine, `mine at {index}`)
		end
		local middle = ChestRules.layout(2, mine, { a, b })
		expect.equal(middle[1], a)
		expect.equal(middle[3], b)
		local last = ChestRules.layout(3, mine, { a, b })
		expect.equal(last[1], a)
		expect.equal(last[2], b)
	end,

	["a pick: only a whole chest number 1-3"] = function()
		expect.equal(ChestRules.validIndex(1, 3), 1)
		expect.equal(ChestRules.validIndex(2, 3), 2)
		expect.equal(ChestRules.validIndex(3, 3), 3)
		for _, bad in { 0, 4, 1.5, -1, "2", 0 / 0, math.huge } :: { any } do
			expect.isNil(ChestRules.validIndex(bad, 3), `refused {bad}`)
		end
		expect.isNil(ChestRules.validIndex(nil, 3))
	end,

	["opening: only your own set, by its id, once"] = function()
		local set: ChestRules.Set = {
			id = "abc",
			bossId = "meadowWarden",
			weaponId = "verdantBlade",
			mine = { kind = "material", item = "m", count = 1 },
			others = {},
			opened = false,
		}
		expect.equal(ChestRules.canOpen(nil, "abc"), false, "no set")
		expect.equal(ChestRules.canOpen(set, "xyz"), false, "another id")
		expect.equal(ChestRules.canOpen(set, 5), false, "not a string")
		expect.equal(ChestRules.canOpen(set, "abc"), true)
		set.opened = true
		expect.equal(ChestRules.canOpen(set, "abc"), false, "already opened")
	end,

	-- The owner 2026-11-11: "I defeated a boss and no chests appeared" (an over-powered win); picked "chests every win":
	-- a reduced win still shows the chests, the weapon can't drop (as before) and the material keeps its reduced chance
	["your chest: the weapon when it dropped, else the material, at a reduced win's chance or empty"] = function()
		local weapon = ChestRules.mine("verdantBlade", true, "m", 1, 0.99, 0.5, WEIGHTS, nil)
		expect.equal(weapon.kind, "weapon")
		expect.equal(weapon.weaponId, "verdantBlade")
		local full = ChestRules.mine("verdantBlade", false, "m", 1, 0.99, 0.97, WEIGHTS, nil)
		expect.equal(full.kind, "material", "full loot: always material")
		expect.equal(full.count, 3)
		local lucky = ChestRules.mine("verdantBlade", false, "m", 0.35, 0.34, 0.5, WEIGHTS, "strong")
		expect.equal(lucky.kind, "material", "a reduced win under its chance")
		expect.equal(lucky.count, 1)
		local empty = ChestRules.mine("verdantBlade", false, "m", 0.35, 0.35, 0.5, WEIGHTS, "strong")
		expect.equal(empty.kind, "empty", "a reduced win past its chance")
		expect.equal(empty.reason, "strong")
	end,

	["why a win was reduced: too strong for the boss first, then the day's soft cap"] = function()
		expect.isNil(ChestRules.reason(1, 1))
		expect.equal(ChestRules.reason(1, 0.35), "strong")
		expect.equal(ChestRules.reason(0.75, 0.35), "strong")
		expect.equal(ChestRules.reason(0.75, 1), "tired")
	end,

	["not picked in time: the server opens one of the three"] = function()
		expect.equal(ChestRules.autoIndex(0, 3), 1)
		expect.equal(ChestRules.autoIndex(0.5, 3), 2)
		expect.equal(ChestRules.autoIndex(0.999, 3), 3)
	end,
}
