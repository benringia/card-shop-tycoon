--!strict
local WeaponRules = require("../src/shared/Util/WeaponRules")
local W = require("../src/shared/Config/Weapons")
local Combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

return {
	-- The quick switch (spec 2026-11-07-weapons-round2-design 6): switching in a fight is allowed (the server's swap lock
	-- makes it cost 1 s), only the first sword's shop level blocks
	["equipping: refused before your first sword, with the reason to show; allowed in a fight"] = function()
		expect.equal(WeaponRules.equipBlock(3, 4), "Your first sword comes at shop level 4.")
		expect.equal(WeaponRules.equipBlock(4, 4), nil)
		expect.equal(WeaponRules.equipBlock(10, 4), nil)
		expect.equal((WeaponRules.equipBlock :: any)(10, 4, true), nil, "a fight no longer blocks (the old third argument)")
	end,

	["a Grade S weapon can't be reforged (the roll can never beat it); any lower grade can"] = function()
		expect.equal(WeaponRules.canReforge({ grade = "S", level = 3 }), false)
		expect.equal(WeaponRules.canReforge({ grade = "A", level = 0 }), true)
		expect.equal(WeaponRules.canReforge({ grade = "C", level = 10 }), true)
	end,

	["shown Power: the Prism Blade's counts its always-on strong hit and bond; the others are their Power"] = function()
		expect.near(WeaponRules.shownPower(W, Combat, "prismBlade", "C", 0), 1 * Combat.STRONG * W.BOND.damage, 1e-9)
		expect.near(WeaponRules.shownPower(W, Combat, "prismBlade", "S", 10), 1.15 * 1.3 * Combat.STRONG * W.BOND.damage, 1e-9)
		assert(WeaponRules.shownPower(W, Combat, "prismBlade", "C", 0) > WeaponRules.shownPower(W, Combat, "sunforgedBlade", "C", 0), "the Legendary reads strongest")
		expect.equal(WeaponRules.shownPower(W, Combat, "verdantBlade", "A", 3), WeaponRules.power(W, "verdantBlade", "A", 3))
		expect.equal(WeaponRules.shownPower(W, Combat, "starterSword", "C", 0), 1)
	end,

	["a dropped Epic or Legendary is told to the server only when it's new (a duplicate became its material)"] = function()
		expect.equal(WeaponRules.announces(W, "prismBlade", 0), true)
		expect.equal(WeaponRules.announces(W, "prismBlade", 10), false, "already owned")
		expect.equal(WeaponRules.announces(W, "verdantBlade", 0), false, "a Rare")
		expect.equal(WeaponRules.announces(W, "nope", 0), false)
	end,

	["Power: rarity x grade x levels; the Steel Sword stays 1"] = function()
		expect.equal(WeaponRules.power(W, "starterSword", "C", 0), 1)
		expect.near(WeaponRules.power(W, "verdantBlade", "C", 0), 1.25, 1e-9)
		expect.near(WeaponRules.power(W, "sunforgedBlade", "S", 10), 1.6 * 1.15 * 1.3, 1e-9)
		expect.near(WeaponRules.power(W, "forgeSword_Volt", "B", 4), 1.15 * 1.05 * 1.12, 1e-9)
		expect.equal(WeaponRules.power(W, "nope", "S", 3), 1, "an unknown weapon hits like the Steel Sword")
	end,

	["the Prism Blade's own base replaces its rarity's (always strong and bonded is its edge)"] = function()
		expect.near(WeaponRules.power(W, "prismBlade", "C", 0), 1, 1e-9)
		expect.near(WeaponRules.power(W, "prismBlade", "S", 10), 1.15 * 1.3, 1e-9)
	end,

	["a hit's weapon info is the weapon it's given (a skill's caster weapon), not whatever is equipped by then"] = function()
		local halberd = WeaponRules.hitInfo(W, "magmaHalberd", "S", "Ember")
		expect.equal(halberd.element, "Ember", "its element")
		expect.equal(halberd.prism, false)
		expect.equal(halberd.bond, W.BOND.damage, "bonded with an Ember creature")
		expect.equal((halberd.perk :: any).kind, "erupt", "its perk")
		local lance = WeaponRules.hitInfo(W, "titansLance", "C", "Ember")
		expect.equal(lance.element, "Bloom")
		expect.equal(lance.bond, 1, "not bonded with an Ember creature")
		expect.equal((lance.perk :: any).kind, "heal")
		local prism = WeaponRules.hitInfo(W, "prismBlade", "C", nil)
		expect.equal(prism.element, nil, "the sim picks the Prism Blade's element per foe")
		expect.equal(prism.prism, true)
		local steel = WeaponRules.hitInfo(W, W.STARTER, "C", "Bloom")
		expect.equal(steel.element, nil)
		expect.equal(steel.perk, nil)
		expect.equal(steel.bond, 1)
	end,

	["bond: same element x1.15 damage and x1.5 meter; prism bonds with any; Steel never"] = function()
		local d, m = WeaponRules.bond(W, "forgeSword_Ember", "Ember")
		expect.equal(d, 1.15)
		expect.equal(m, 1.5)
		d, m = WeaponRules.bond(W, "forgeSword_Ember", "Tide")
		expect.equal(d, 1)
		expect.equal(m, 1)
		d = WeaponRules.bond(W, "prismBlade", "Shade")
		expect.equal(d, 1.15)
		d = WeaponRules.bond(W, "starterSword", "Ember")
		expect.equal(d, 1)
		d = WeaponRules.bond(W, "prismBlade", nil)
		expect.equal(d, 1, "no creature out: no bond")
	end,

	["perks: a Grade S weapon's perk is 1.2x stronger; the Steel Sword has none"] = function()
		local plain = WeaponRules.perk(W, "verdantBlade", "A")
		assert(plain, "the Verdant Blade heals")
		expect.equal(plain.kind, "heal")
		expect.equal(plain.every, 4)
		expect.near(plain.share :: number, 0.02, 1e-9)
		local s = WeaponRules.perk(W, "verdantBlade", "S")
		assert(s, "Grade S")
		expect.near(s.share :: number, 0.024, 1e-9)
		expect.near((W.ById.verdantBlade.perk :: any).share, 0.02, 1e-9, "the config isn't changed")
		local prism = WeaponRules.perk(W, "prismBlade", "S")
		assert(prism, "the prism perk")
		expect.equal(prism.kind, "prism")
		expect.isNil(WeaponRules.perk(W, "starterSword", "S"))
	end,

	["the element strong against each one (nil for none)"] = function()
		expect.equal(WeaponRules.strongAgainst(Combat, "Bloom"), "Ember")
		expect.equal(WeaponRules.strongAgainst(Combat, "Shade"), "Volt")
		expect.isNil(WeaponRules.strongAgainst(Combat, "None"))
		expect.isNil(WeaponRules.strongAgainst(Combat, nil))
	end,

	["the Prism Blade is always strong against the foe's element"] = function()
		expect.equal(WeaponRules.hitElement(W, "prismBlade", "Tide", Combat), "Bloom")
		expect.equal(WeaponRules.hitElement(W, "prismBlade", "Volt", Combat), "Shade")
		expect.equal(WeaponRules.hitElement(W, "verdantBlade", "Tide", Combat), "Bloom")
		expect.isNil(WeaponRules.hitElement(W, "starterSword", "Tide", Combat))
		expect.isNil(WeaponRules.hitElement(W, "prismBlade", nil, Combat), "a foe with no element: no wheel")
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 4): Grade S makes the Trident's chill stronger; the Titan's
	-- Lance recipe (checked on a copy with the Lance built, as it isn't until its model is in)
	["the spears: a Grade S chill, the Titan's Lance recipe"] = function()
		local chill = WeaponRules.perk(W, "tidalTrident", "S")
		assert(chill, "the Trident has a perk")
		expect.equal(chill.kind, "chill")
		expect.near(chill.share :: number, 0.12, 1e-9)
		local built = table.clone(W)
		built.ById = table.clone(W.ById)
		built.ById.titansLance = table.clone(W.ById.titansLance)
		built.ById.titansLance.ready = true
		local cost = WeaponRules.makeCost(built, "titansLance")
		assert(cost, "the Lance has a recipe")
		expect.equal(cost.cash, 60000)
		expect.equal(cost.items.material_meadowWarden, 30)
		expect.equal(cost.items.material_frostTyrant, 20)
		expect.equal(cost.items.material_stormSovereign, 20)
		expect.equal(cost.items.starShard, 10)
	end,

	["costs: boss weapons by rarity, the masterwork's recipe, reforge half rounded up"] = function()
		local rare = WeaponRules.makeCost(W, "verdantBlade")
		assert(rare, "the Verdant Blade has a cost")
		expect.equal(rare.cash, 2000)
		expect.equal(rare.items.material_meadowWarden, 15)
		local sun = WeaponRules.makeCost(W, "sunforgedBlade")
		assert(sun, "the Sunforged Blade has a cost")
		expect.equal(sun.items.material_emberColossus, 20)
		expect.equal(sun.items.starShard, 5)
		expect.equal(sun.cash, 25000)
		local forge = WeaponRules.makeCost(W, "forgeSword_Volt")
		assert(forge, "a Forge Sword has a cost")
		expect.equal(forge.cash, 1500)
		expect.equal(forge.items.wildOre, 20)
		local reforge = WeaponRules.reforgeCost(W, "verdantBlade")
		assert(reforge, "the Verdant Blade can be reforged")
		expect.equal(reforge.items.material_meadowWarden, 8)
		expect.equal(reforge.cash, 1000)
		expect.isNil(WeaponRules.makeCost(W, "starterSword"))
		expect.isNil(WeaponRules.makeCost(W, "riftReaper"))
		expect.isNil(WeaponRules.reforgeCost(W, "starterSword"))
	end,

	["upgrades: +5 and +10 need Star Shards; none past +10; Forge weapons pay in Wild Ore"] = function()
		local five = WeaponRules.upgradeCost(W, "verdantBlade", 5)
		assert(five, "+5")
		expect.equal(five.items.starShard, 1)
		expect.equal(five.items.material_meadowWarden, 4)
		expect.equal(five.cash, 4000 * 0.8)
		local ten = WeaponRules.upgradeCost(W, "verdantBlade", 10)
		assert(ten, "+10")
		expect.equal(ten.items.starShard, 3)
		expect.isNil(WeaponRules.upgradeCost(W, "verdantBlade", 11))
		expect.isNil(WeaponRules.upgradeCost(W, "verdantBlade", 0))
		local tide = WeaponRules.upgradeCost(W, "forgeSword_Tide", 1)
		assert(tide, "a Forge Sword upgrades")
		expect.equal(tide.items.wildOre, 2)
		expect.isNil(tide.items.starShard)
		expect.isNil(WeaponRules.upgradeCost(W, "starterSword", 1))
		local sun = WeaponRules.upgradeCost(W, "sunforgedBlade", 1)
		assert(sun, "the Sunforged Blade upgrades")
		expect.equal(sun.items.material_emberColossus, 2, "a masterwork pays in its recipe's main material")
	end,

	["each weapon's material: its boss's, Wild Ore for the Forge, a masterwork's main one; none for the Steel Sword"] = function()
		expect.equal(WeaponRules.material(W, "verdantBlade"), "material_meadowWarden")
		expect.equal(WeaponRules.material(W, "forgeSword_Shade"), "wildOre")
		expect.equal(WeaponRules.material(W, "sunforgedBlade"), "material_emberColossus")
		expect.isNil(WeaponRules.material(W, "starterSword"))
		expect.isNil(WeaponRules.material(W, "nope"))
	end,

	["a material's goal: making its weapon first, then its next upgrade (the loot toast's progress)"] = function()
		local id, need = WeaponRules.materialGoal(W, "material_meadowWarden", {})
		expect.equal(id, "verdantBlade")
		expect.equal(need, 15)
		id, need = WeaponRules.materialGoal(W, "material_meadowWarden", { verdantBlade = { grade = "A", level = 4 } })
		expect.equal(id, "verdantBlade")
		expect.equal(need, 4, "its +5 needs 4")
		id, need = WeaponRules.materialGoal(W, "material_emberColossus", {})
		expect.equal(id, "sunforgedBlade", "the masterwork's recipe (the Magma Halberd isn't built)")
		expect.equal(need, 20)
		id, need = WeaponRules.materialGoal(W, "wildOre", {})
		expect.equal(id, "forgeSword_Ember", "the first Forge Sword")
		expect.equal(need, 20)
		id, need = WeaponRules.materialGoal(W, "wildOre", { forgeSword_Ember = { grade = "C", level = 0 } })
		expect.equal(id, "forgeSword_Ember", "once owned: its next upgrade")
		expect.equal(need, 2)
		id, need = WeaponRules.materialGoal(W, "material_frostTyrant", {})
		expect.equal(id, "tidalTrident", "the Frost Tyrant's own weapon (weapons round 2)")
		expect.equal(need, 40)
		id, need = WeaponRules.materialGoal(W, "material_meadowWarden", { verdantBlade = { grade = "S", level = 10 } })
		expect.equal(id, "sunforgedBlade", "the Verdant Blade maxed: the masterwork takes Heartwood too")
		expect.equal(need, 10)
		-- the Titan's Lance takes Heartwood too (weapons round 2): maxed as well, nothing is left
		local done = { verdantBlade = { grade = "S", level = 10 }, sunforgedBlade = { grade = "C", level = 0 }, titansLance = { grade = "S", level = 10 } }
		expect.isNil((WeaponRules.materialGoal(W, "material_meadowWarden", done)), "nothing left needs it")
	end,

	["forge progress: the weapon's main material, have over need (capped)"] = function()
		local have, need = WeaponRules.makeProgress(W, "verdantBlade", { material_meadowWarden = 9 })
		expect.equal(have, 9)
		expect.equal(need, 15)
		have, need = WeaponRules.makeProgress(W, "forgeSword_Volt", { wildOre = 33 })
		expect.equal(have, 20, "capped at the need")
		expect.equal(need, 20)
		have, need = WeaponRules.makeProgress(W, "sunforgedBlade", {})
		expect.equal(have, 0)
		expect.equal(need, 20, "its main material (Colossus Core)")
		expect.isNil((WeaponRules.makeProgress(W, "starterSword", {})))
		expect.isNil((WeaponRules.makeProgress(W, "riftReaper", {})), "not built yet")
	end,

	["paying is all or nothing"] = function()
		local cost = { cash = 100, items = { a = 2, b = 1 } }
		local ok, why = WeaponRules.pay(cost, 100, { a = 2 })
		expect.equal(ok, false)
		expect.equal(why, "b")
		ok, why = WeaponRules.pay(cost, 99, { a = 2, b = 1 })
		expect.equal(ok, false)
		expect.equal(why, "cash")
		expect.equal((WeaponRules.pay(cost, 100, { a = 2, b = 1 })), true)
	end,

	["a drop you already own becomes 10 material; a reforge keeps the better grade and the level"] = function()
		local owned = { verdantBlade = { grade = "S", level = 4 } }
		local rec, refund = WeaponRules.give(owned, "verdantBlade", "C", "drop", W)
		expect.isNil(rec)
		expect.equal(refund, 10)
		rec = WeaponRules.give(owned, "verdantBlade", "B", "reforge", W)
		expect.isNil(rec)
		rec = WeaponRules.give({ verdantBlade = { grade = "B", level = 4 } }, "verdantBlade", "S", "reforge", W)
		assert(rec, "a better reforge")
		expect.equal(rec.grade, "S")
		expect.equal(rec.level, 4)
		local fresh, none = WeaponRules.give({}, "verdantBlade", "A", "drop", W)
		assert(fresh, "a new drop")
		expect.equal(fresh.grade, "A")
		expect.equal(fresh.level, 0)
		expect.equal(none, 0)
	end,

	["drop chance by rarity (owner 2026-11-06): a Rare 1% plus 0.5% a kill without one, a Legendary about 2 weeks"] = function()
		expect.near(WeaponRules.dropChance(W, "verdantBlade", 0), 0.01, 1e-9)
		expect.near(WeaponRules.dropChance(W, "verdantBlade", 10), 0.06, 1e-9)
		expect.equal(WeaponRules.dropChance(W, "verdantBlade", 500), 1)
		expect.near(WeaponRules.dropChance(W, "prismBlade", 0), 0.001, 1e-9)
		expect.near(WeaponRules.dropChance(W, "prismBlade", 10), 0.003, 1e-9)
		expect.equal(WeaponRules.dropChance(W, "nope", 0), 0)
		-- Median full-loot kills to a drop (6 a day at the daily soft cap): Rare ~15 (2.5 days), Legendary ~79 (13 days)
		local function median(rarity: string): number
			local odds = W.DROP[rarity]
			local miss, kills = 1, 0
			repeat
				kills += 1
				miss *= 1 - math.min(1, odds.base + odds.step * (kills - 1))
			until miss <= 0.5
			return kills
		end
		expect.equal(median("Rare"), 15)
		expect.equal(median("Legendary"), 79)
		assert(median("Rare") < median("Very Rare") and median("Very Rare") < median("Epic") and median("Epic") < median("Legendary"), "rarer is slower")
	end,

	["loading: unknown weapons dropped and named, levels clamped, a missing equip falls back to the Steel Sword"] = function()
		local owned, equipped, dropped = WeaponRules.read(
			W,
			{ verdantBlade = { grade = "Z", level = 99 }, gone = { grade = "S", level = 1 } },
			"riftReaper"
		)
		expect.equal(owned.verdantBlade.grade, "C")
		expect.equal(owned.verdantBlade.level, 10)
		expect.isNil(owned.gone)
		expect.equal(dropped[1], "gone")
		expect.equal(equipped, "starterSword")
		local _, kept = WeaponRules.read(W, { verdantBlade = { grade = "A", level = 2 } }, "verdantBlade")
		expect.equal(kept, "verdantBlade")
		local empty, starter = WeaponRules.read(W, "junk", nil)
		expect.equal(next(empty), nil)
		expect.equal(starter, "starterSword")
		local bad = WeaponRules.read(W, { verdantBlade = { grade = "A", level = -3.7 } }, nil)
		expect.equal(bad.verdantBlade.level, 0)
	end,

	["the Forge opens at shop level 6; boss weapons don't wait for it"] = function()
		expect.equal(WeaponRules.unlocked(W, "forgeSword_Ember", 5), false)
		expect.equal(WeaponRules.unlocked(W, "forgeSword_Ember", 6), true)
		expect.equal(WeaponRules.unlocked(W, "verdantBlade", 1), true)
		expect.equal(WeaponRules.unlocked(W, "riftReaper", 50), false, "not built yet")
	end,
}
