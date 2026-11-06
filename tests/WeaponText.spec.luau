--!strict
local WeaponText = require("../src/shared/Util/WeaponText")
local Weapons = require("../src/shared/Config/Weapons")
local Items = require("../src/shared/Config/Items")
local Combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

local function valueOf(rows: { { label: string, value: string } }, label: string): string?
	for _, row in rows do
		if row.label == label then
			return row.value
		end
	end
	return nil
end

return {
	["stats: Power to 2 decimals, the element and its bond, the perk in words"] = function()
		local rows = WeaponText.stats(Weapons, "verdantBlade", nil, Combat)
		expect.equal(valueOf(rows, "Power"), "x1.25")
		expect.equal(valueOf(rows, "Element"), "Bloom · bonds with Bloom creatures")
		expect.equal(valueOf(rows, "Perk"), "Every 4th hit heals your creature 2%")
		expect.equal(valueOf(rows, "Grade"), nil, "not owned: no grade or level")
		local owned = WeaponText.stats(Weapons, "verdantBlade", { grade = "S", level = 4 }, Combat)
		expect.equal(valueOf(owned, "Power"), "x1.61") -- 1.25 x 1.15 x 1.12
		expect.equal(valueOf(owned, "Perk"), "Every 4th hit heals your creature 2.4%", "Grade S perks are stronger")
		expect.equal(valueOf(owned, "Grade"), "S")
		expect.equal(valueOf(owned, "Level"), "+4")
	end,

	["stats: the burn, the prism and the plain Steel Sword"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "sunforgedBlade", nil, Combat), "Perk"), "Sets the foe burning for 3 s")
		local prism = WeaponText.stats(Weapons, "prismBlade", nil, Combat)
		expect.equal(valueOf(prism, "Power"), "x1.72", "always strong and bonded (1.725)")
		expect.equal(valueOf(prism, "Perk"), "Always strong against the foe's element")
		expect.equal(valueOf(prism, "Element"), "Every element · bonds with every creature")
		local steel = WeaponText.stats(Weapons, "starterSword", nil, Combat)
		expect.equal(valueOf(steel, "Power"), "x1.00")
		expect.equal(valueOf(steel, "Element"), "None")
		expect.equal(valueOf(steel, "Perk"), nil)
		expect.equal(#WeaponText.stats(Weapons, "nope", nil, Combat), 0)
	end,

	["where a weapon comes from, in words (the Armory's locked cards)"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		expect.equal(WeaponText.source(Weapons, Bosses, "verdantBlade"), "Drops from the Meadow Warden")
		expect.equal(WeaponText.source(Weapons, Bosses, "prismBlade"), "Drops from the Prism Hydra")
		expect.equal(WeaponText.source(Weapons, Bosses, "forgeSword_Tide"), "Forge: Wild Ore")
		expect.equal(WeaponText.source(Weapons, Bosses, "sunforgedBlade"), "Masterwork: 3 bosses' materials + Star Shards")
		expect.equal(WeaponText.source(Weapons, Bosses, "starterSword"), "Everyone's first sword")
		expect.equal(WeaponText.source(Weapons, Bosses, "tidalTrident"), "Drops from the Frost Tyrant")
		expect.equal(WeaponText.source(Weapons, Bosses, "titansLance"), "Masterwork", "no recipe yet")
	end,

	["a material's pickup line shows its progress toward what it's for"] = function()
		expect.equal(WeaponText.pickup("Warden Heartwood", 2, 9, 15), "Warden Heartwood +2 (9/15)")
		expect.equal(WeaponText.pickup("Wild Ore", 1, 3, nil), "Wild Ore +1")
	end,

	["the Forge's one button says what it does, or what's missing"] = function()
		local cost = { cash = 2000, items = { material_meadowWarden = 15 } }
		local text, ready = WeaponText.button("forge", cost, { material_meadowWarden = 9 }, 5000, Items, {})
		expect.equal(text, "Need 6 more Warden Heartwood")
		expect.equal(ready, false)
		text, ready = WeaponText.button("forge", cost, { material_meadowWarden = 15 }, 1500, Items, {})
		expect.equal(text, "Need $500 more")
		expect.equal(ready, false)
		text, ready = WeaponText.button("forge", cost, { material_meadowWarden = 20 }, 2000, Items, {})
		expect.equal(text, "Forge · $2,000")
		expect.equal(ready, true)
		expect.equal((WeaponText.button("upgrade", { cash = 1200, items = {} }, {}, 9000, Items, { level = 4 })), "Upgrade to +4 · $1,200")
		expect.equal((WeaponText.button("reforge", { cash = 1000, items = {} }, {}, 9000, Items, {})), "Reforge · $1,000")
		expect.equal((WeaponText.button("upgrade", nil, {}, 9000, Items, {})), "Maxed at +10")
		text, ready = WeaponText.button("forge", { cash = 1500, items = {} }, {}, 9000, Items, { unlockLevel = 6, shopLevel = 5 })
		expect.equal(text, "Opens at shop level 6")
		expect.equal(ready, false)
	end,

	["what each upgrade adds to the glow (the forge reveal's line)"] = function()
		local Looks = require("../src/shared/Config/WeaponLooks")
		expect.equal(WeaponText.ladderStep(Looks, 1), "Its edges glow brighter")
		expect.equal(WeaponText.ladderStep(Looks, 3), "Its edges glow brighter")
		expect.equal(WeaponText.ladderStep(Looks, 4), "Its aura appears!")
		expect.equal(WeaponText.ladderStep(Looks, 6), "A stronger aura")
		expect.equal(WeaponText.ladderStep(Looks, 7), "A bigger trail and a burst on every hit!")
		expect.equal(WeaponText.ladderStep(Looks, 9), "A bigger trail")
		expect.equal(WeaponText.ladderStep(Looks, 10), "AWAKENED!")
	end,

	["cost lines: cash first, then each item with have/need and whether it's enough"] = function()
		local cost = { cash = 2000, items = { material_meadowWarden = 15, starShard = 1 } }
		local lines = WeaponText.cost(cost, { material_meadowWarden = 9, starShard = 3 }, 2500, Items)
		expect.equal(#lines, 3)
		expect.equal(lines[1].text, "$2,000")
		expect.equal(lines[1].enough, true)
		expect.equal(lines[2].text, "Warden Heartwood 9/15")
		expect.equal(lines[2].enough, false)
		expect.equal(lines[3].text, "Star Shard 3/1")
		expect.equal(lines[3].enough, true)
		local poor = WeaponText.cost({ cash = 25000, items = {} }, {}, 900, Items)
		expect.equal(poor[1].text, "$25,000")
		expect.equal(poor[1].enough, false)
		local unknown = WeaponText.cost({ cash = 0, items = { mystery = 2 } }, {}, 0, Items)
		expect.equal(#unknown, 1, "no cash line for a free cost")
		expect.equal(unknown[1].text, "mystery 0/2")
	end,
}
