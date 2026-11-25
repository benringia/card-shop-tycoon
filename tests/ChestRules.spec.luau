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

	-- The owner 2026-11-11 ("chests every win"); since 2026-11-19 every loot win is full (no strength rule, no daily
	-- limit), so your chest always holds something: the weapon when it dropped, else its material
	["your chest: the weapon when it dropped, else its material, never empty"] = function()
		local weapon = ChestRules.mine("verdantBlade", true, "m", 0.5, WEIGHTS)
		expect.equal(weapon.kind, "weapon")
		expect.equal(weapon.weaponId, "verdantBlade")
		local material = ChestRules.mine("verdantBlade", false, "m", 0.97, WEIGHTS)
		expect.equal(material.kind, "material")
		expect.equal(material.item, "m")
		expect.equal(material.count, 3)
		local rules: any, chests: any = ChestRules, BossChests
		expect.isNil(rules.reason, "no reduced wins to explain")
		expect.isNil(chests.EMPTY, "no empty chest card")
	end,

	-- Weapons round 4 part 2 (owner 2026-11-25: weapons "almost always drop on bosses"): the material comes every loot
	-- win, the weapon's chest too, plus `everyWin` by the weapon's rarity (Config/Weapons MATERIAL_EVERY_WIN), so the
	-- upgrades' grind stays as it was once a duplicate stopped giving 10
	["your chest always holds the material, the weapon's too, plus every win's"] = function()
		local weapon = ChestRules.mine("verdantBlade", true, "m", 0.5, WEIGHTS, 0, 2)
		expect.equal(weapon.kind, "weapon")
		expect.equal(weapon.weaponId, "verdantBlade")
		expect.equal(weapon.item, "m")
		expect.equal(weapon.count, 3, "1 rolled + 2 every win")
		local material = ChestRules.mine("verdantBlade", false, "m", 0.97, WEIGHTS, 1, 2)
		expect.equal(material.kind, "material")
		expect.equal(material.count, 6, "3 rolled + 1 event + 2 every win")
		local others = ChestRules.others(false, "verdantBlade", "m", { 0.9, 0.1, 0.3 }, WEIGHTS, 0, 2)
		expect.equal(others[1].count, 4, "3 + 2: the others look alike")
		expect.equal(others[2].count, 3)
	end,

	-- Boss Rush (Config/Events, owner 2026-11-19): one more of the material in every chest, the two you didn't pick too
	-- (a weapon's chest holds its material too since weapons round 4 part 2)
	["an event's bonus: more material in every chest"] = function()
		local material = ChestRules.mine("verdantBlade", false, "m", 0.5, WEIGHTS, 1)
		expect.equal(material.count, 2, "1 rolled + 1")
		expect.equal(ChestRules.mine("verdantBlade", false, "m", 0.97, WEIGHTS, 1).count, 4, "3 rolled + 1")
		local weapon = ChestRules.mine("verdantBlade", true, "m", 0.5, WEIGHTS, 1)
		expect.equal(weapon.kind, "weapon")
		expect.equal(weapon.count, 2, "its material, 1 rolled + 1")
		local plain = ChestRules.others(false, "verdantBlade", "m", { 0.9, 0.1, 0.3 }, WEIGHTS, 1)
		expect.equal(plain[1].count, 3)
		expect.equal(plain[2].count, 2)
		local withMystery = ChestRules.others(true, "verdantBlade", "m", { 0.5, 0.97, 0.8 }, WEIGHTS, 1)
		expect.equal(withMystery[1].count, 2)
		expect.equal(withMystery[2].kind, "mystery")
		expect.equal(ChestRules.mine("verdantBlade", false, "m", 0.5, WEIGHTS, 0).count, 1, "no event")
	end,

	["not picked in time: the server opens one of the three"] = function()
		expect.equal(ChestRules.autoIndex(0, 3), 1)
		expect.equal(ChestRules.autoIndex(0.5, 3), 2)
		expect.equal(ChestRules.autoIndex(0.999, 3), 3)
	end,
}
