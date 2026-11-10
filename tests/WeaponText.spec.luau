--!strict
local WeaponText = require("../src/shared/Util/WeaponText")
local Weapons = require("../src/shared/Config/Weapons")
local Items = require("../src/shared/Config/Items")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local CombatHud = require("../src/shared/Config/CombatHud")
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
	["the spears' perks in words (weapons round 2)"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "magmaHalberd", nil, Combat), "Perk"), "Every 5th hit erupts for 60% more")
		expect.equal(valueOf(WeaponText.stats(Weapons, "tidalTrident", nil, Combat), "Perk"), "Hits slow the foe's attacks 10% for 3 s")
		expect.equal(valueOf(WeaponText.stats(Weapons, "titansLance", nil, Combat), "Perk"), "Every 4th hit heals your creature 1%")
	end,

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
		expect.equal(WeaponText.source(Weapons, Bosses, "titansLance"), "Masterwork: 3 bosses' materials + Star Shards")
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

	["what each upgrade adds to the glow (the forge reveal's line), by rarity"] = function()
		local Looks = require("../src/shared/Config/WeaponLooks")
		expect.equal(WeaponText.ladderStep(Looks, 1, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 3, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 4, "Rare"), "Its aura appears!")
		expect.equal(WeaponText.ladderStep(Looks, 2, "Epic"), "Its aura appears!", "Epic and Legendary start at +2")
		expect.equal(WeaponText.ladderStep(Looks, 2, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 6, "Rare"), "A stronger aura")
		expect.equal(WeaponText.ladderStep(Looks, 7, "Rare"), "The full blaze, a bigger trail and a burst on every hit!")
		expect.equal(WeaponText.ladderStep(Looks, 9, "Rare"), "A bigger trail")
		expect.equal(WeaponText.ladderStep(Looks, 10, "Legendary"), "AWAKENED! Flames stream off it")
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

	["the Forge window's tab lines say what each tab does (owner's pick A, 2026-11-08)"] = function()
		expect.equal(WeaponText.tabLine("Forge"), "Make a weapon you don't have yet. You pay its materials and cash; it comes out at a random grade, C to S (like a card).")
		expect.equal(WeaponText.tabLine("Upgrade"), "Level a weapon you own up, +0 to +10: more Power and a brighter glow each level. Never fails. +5 and +10 also need Star Shards.")
		expect.equal(WeaponText.tabLine("Reforge"), "Roll a new grade for half the making cost. You keep the better grade, so it never gets worse. Grade S can't be reforged.")
	end,

	["cost chips: cash first, then each item with its icon, need and what you have"] = function()
		local chips = WeaponText.costChips({ cash = 250, items = { wildOre = 2 } }, { wildOre = 11 }, 100, Items)
		expect.equal(#chips, 2)
		expect.equal(chips[1].icon, "Cash")
		expect.equal(chips[1].text, "$250")
		expect.equal(chips[1].enough, false, "$100 of $250")
		expect.equal(chips[2].icon, "WildOre")
		expect.equal(chips[2].text, "2 Wild Ore (you have 11)")
		expect.equal(chips[2].enough, true)
		local free = WeaponText.costChips({ cash = 0, items = { starShard = 1, mystery = 2 } }, {}, 0, Items)
		expect.equal(#free, 2, "no cash chip for a cost without cash")
		expect.equal(free[1].text, "2 mystery (you have 0)", "sorted by id; an unknown item shows its id")
		expect.equal(free[1].icon, "")
		expect.equal(free[2].text, "1 Star Shard (you have 0)")
		expect.equal(free[2].enough, false)
	end,

	-- Weapons round 3 (spec 4): the scythes' perks in words
	["the scythes' perks in words"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "widowsReaper", nil, Combat), "Perk"), "Poisons the foe for 3 s")
		expect.equal(valueOf(WeaponText.stats(Weapons, "stormReaper", nil, Combat), "Perk"), "Every 4th hit strikes for 40% more and arcs to other foes for 30%")
		expect.equal(valueOf(WeaponText.stats(Weapons, "riftReaper", nil, Combat), "Perk"), "Hits deal 30% more to foes under 30% HP")
	end,

	-- The weapon window (Armory UI, owner's pick A 2026-11-09): Power against what you hold, signed
	["versus: this weapon's Power against the equipped one's, signed, to 2 decimals"] = function()
		local maxed = { grade = "S", level = 10 }
		local better = WeaponText.versus(Weapons, Combat, "titansLance", maxed, "starterSword", nil)
		assert(better, "a known pair compares")
		expect.equal(better.text, "+0.79 vs Steel Sword")
		expect.equal(better.sign, 1)
		local worse = WeaponText.versus(Weapons, Combat, "starterSword", nil, "titansLance", maxed)
		assert(worse)
		expect.equal(worse.text, "-0.79 vs Titan's Lance")
		expect.equal(worse.sign, -1)
		local held = WeaponText.versus(Weapons, Combat, "titansLance", maxed, "titansLance", maxed)
		assert(held)
		expect.equal(held.text, "Equipped now")
		expect.equal(held.sign, 0)
		local even = WeaponText.versus(Weapons, Combat, "forgeSword_Ember", nil, "forgeSword_Tide", nil)
		assert(even)
		expect.equal(even.text, "Same Power as Tide Forge Sword")
		expect.equal(even.sign, 0)
		expect.equal(WeaponText.versus(Weapons, Combat, "titansLance", maxed, "nope", nil), nil, "an unknown weapon compares to nothing")
	end,

	["powerRange: Grade C at +0 to Grade S at the top level, one number when they match"] = function()
		expect.equal(WeaponText.powerRange(Weapons, Combat, "riftReaper"), "x1.40 to x2.09")
		expect.equal(WeaponText.powerRange(Weapons, Combat, "starterSword"), "x1.00")
		expect.equal(WeaponText.powerRange(Weapons, Combat, "nope"), "")
	end,

	["howToGet: the boss and where it lives, then how the forge makes it"] = function()
		local rift = WeaponText.howToGet(Weapons, Bosses, "riftReaper")
		expect.equal(rift.drop, "Beat the Rift Devourer in the Frontier: it can drop.")
		expect.equal(rift.forge, "Or forge it:")
		expect.equal(WeaponText.howToGet(Weapons, Bosses, "widowsReaper").drop, "Beat the Cave Brood Queen in the Wild: it can drop.")
		local forged = WeaponText.howToGet(Weapons, Bosses, "forgeScythe_Ember")
		expect.equal(forged.drop, nil)
		expect.equal(forged.forge, "Forge it at the Forge in your shop:")
		local masterwork = WeaponText.howToGet(Weapons, Bosses, "titansLance")
		expect.equal(masterwork.drop, nil)
		expect.equal(masterwork.forge, "A masterwork. Forge it at the Forge in your shop:")
		local steel = WeaponText.howToGet(Weapons, Bosses, "starterSword")
		expect.equal(steel.drop, nil, "everyone has the Steel Sword")
		expect.equal(steel.forge, nil)
	end,

	["howToGet: a Dungeon boss is at the end of the Dungeon run"] = function()
		local bosses = { BOSSES = { prismHydra = { name = "Prism Hydra", place = "Dungeon" } } }
		local cfg = { ById = { test = { id = "test", source = { kind = "boss", boss = "prismHydra" } } } }
		expect.equal(WeaponText.howToGet(cfg, bosses, "test").drop, "Beat the Prism Hydra at the end of the Dungeon: it can drop.")
	end,

	["progress: each material's have/need sorted by id, then the cash"] = function()
		local rows = WeaponText.progress({ cash = 30000, items = { material_riftDevourer = 60, starShard = 2 } }, { material_riftDevourer = 12 }, 40000, Items)
		expect.equal(#rows, 3)
		expect.equal(rows[1].icon, "RiftShard")
		expect.equal(rows[1].name, "Rift Shard")
		expect.equal(rows[1].have, 12)
		expect.equal(rows[1].need, 60)
		expect.equal(rows[1].text, "12/60")
		expect.equal(rows[2].name, "Star Shard")
		expect.equal(rows[2].text, "0/2", "none yet")
		expect.equal(rows[3].icon, "Cash")
		expect.equal(rows[3].name, "Cash")
		expect.equal(rows[3].text, "$30,000")
		expect.equal(rows[3].have, 40000)
		expect.equal(rows[3].need, 30000)
		expect.equal(#WeaponText.progress({ cash = 0, items = {} }, {}, 0, Items), 0, "a free cost has no rows")
	end,

	["skill: a weapon's own sword skill by its moveset, else the dash slash (named in words, not capitals)"] = function()
		local lance = WeaponText.skill(CombatHud, Weapons, "titansLance")
		expect.equal(lance.name, "Titan's Wrath")
		expect.equal(lance.icon, "LanceLeaves")
		expect.equal(lance.text, CombatHud.SKILLS.titansLance.tip)
		expect.equal(WeaponText.skill(CombatHud, Weapons, "widowsReaper").name, "Reaping Cyclone")
		expect.equal(WeaponText.skill(CombatHud, Weapons, "riftReaper").name, "Thousand Cuts")
		local steel = WeaponText.skill(CombatHud, Weapons, "starterSword")
		expect.equal(steel.name, "Dash")
		expect.equal(steel.icon, CombatHud.BUTTONS.skill.icon)
		for _, weapon in Weapons.WEAPONS do
			local skill = WeaponText.skill(CombatHud, Weapons, weapon.id)
			assert(skill.name ~= "" and skill.text ~= "", `{weapon.id} has a skill in words`)
		end
	end,

	["bond: what sharing its element with your creature gives, from Config/Weapons BOND"] = function()
		expect.equal(WeaponText.bond(Weapons, "titansLance"), "+15% hits and a 50% faster super with Bloom creatures")
		expect.equal(WeaponText.bond(Weapons, "prismBlade"), "+15% hits and a 50% faster super with every creature")
		expect.equal(WeaponText.bond(Weapons, "starterSword"), nil, "no element, no bond")
	end,
}
