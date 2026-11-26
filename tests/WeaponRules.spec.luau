--!strict
local WeaponRules = require("../src/shared/Util/WeaponRules")
local W = require("../src/shared/Config/Weapons")
local Combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

-- The catalogue with one weapon not built yet (every weapon is built since weapons round 3; the rule still matters for
-- the next round's)
local function unbuiltCopy(cfg: any, id: string): any
	local copy = table.clone(cfg)
	copy.ById = table.clone(cfg.ById)
	copy.WEAPONS = {}
	for _, weapon in cfg.WEAPONS do
		local entry = weapon
		if weapon.id == id then
			entry = table.clone(weapon)
			entry.ready = false
			copy.ById[id] = entry
		end
		table.insert(copy.WEAPONS, entry)
	end
	return copy
end
local UNBUILT = unbuiltCopy(W, "riftReaper")

return {
	-- The quick switch (spec 2026-11-07-weapons-round2-design 6): switching in a fight is allowed (the server's swap lock
	-- makes it cost 1 s), only the first sword's shop level blocks
	["equipping: refused before your first sword, with the reason to show; allowed in a fight"] = function()
		expect.equal(WeaponRules.equipBlock(3, 4, false), "Chikin gives you your first sword after your first fight.")
		expect.equal(WeaponRules.equipBlock(4, 4, false), nil)
		expect.equal(WeaponRules.equipBlock(10, 4, false), nil)
		expect.equal(WeaponRules.equipBlock(1, 4, true), nil, "Chikin gave it")
	end,

	-- Owner 2026-11-16: "chikin should give the player a sword before leaving the player on wild": the sword comes when
	-- Chikin's first fight is over (or at shop level 4 for anyone who never had his tour)
	["the first sword: from Chikin after the first fight, or at shop level 4"] = function()
		expect.equal(WeaponRules.swordReady(1, 4, false), false)
		expect.equal(WeaponRules.swordReady(1, 4, true), true)
		expect.equal(WeaponRules.swordReady(4, 4, false), true)
	end,

	["a Grade S weapon can't be reforged (the roll can never beat it); any lower grade can"] = function()
		expect.equal(WeaponRules.canReforge({ grade = "S", level = 3 }), false)
		expect.equal(WeaponRules.canReforge({ grade = "A", level = 0 }), true)
		expect.equal(WeaponRules.canReforge({ grade = "C", level = 10 }), true)
	end,

	-- Weapons round 4 (owner 2026-11-25, the future-proof rule): the Prism Blade keeps only "always strong", no bond
	["shown Power: the Prism Blade's counts its always-on strong hit; the others are their Power"] = function()
		expect.near(WeaponRules.shownPower(W, Combat, "prismBlade", "C", 0), 1.0 * Combat.STRONG, 1e-9)
		expect.near(WeaponRules.shownPower(W, Combat, "prismBlade", "S", 10), 1.0 * 1.15 * 1.5 * Combat.STRONG, 1e-9)
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
		-- the bases and the 5% a level since 2026-11-21 (1.25 / 1.6 / 1.15 and 3% before)
		expect.near(WeaponRules.power(W, "verdantBlade", "C", 0), 1.1, 1e-9)
		expect.near(WeaponRules.power(W, "sunforgedBlade", "S", 10), 1.39 * 1.15 * 1.5, 1e-9)
		expect.near(WeaponRules.power(W, "forgeSword_Volt", "B", 4), 1.05 * 1.05 * 1.2, 1e-9)
		expect.equal(WeaponRules.power(W, "nope", "S", 3), 1, "an unknown weapon hits like the Steel Sword")
	end,

	["the Prism Blade's own base replaces its rarity's (always strong is its edge; 1.0 keeps its hits as they were bonded)"] = function()
		expect.near(WeaponRules.power(W, "prismBlade", "C", 0), 1.0, 1e-9)
		expect.near(WeaponRules.power(W, "prismBlade", "S", 10), 1.0 * 1.15 * 1.5, 1e-9)
		-- its sword hits at +0: 0.87 x 1.5 x 1.15 bonded before, 1.0 x 1.5 now
		expect.near(WeaponRules.power(W, "prismBlade", "C", 0) * Combat.STRONG, 0.87 * Combat.STRONG * 1.15, 0.01)
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

	["bond: same element x1.15 damage and x1.5 meter; the Prism and the Steel Sword never"] = function()
		local d, m = WeaponRules.bond(W, "forgeSword_Ember", "Ember")
		expect.equal(d, 1.15)
		expect.equal(m, 1.5)
		d, m = WeaponRules.bond(W, "forgeSword_Ember", "Tide")
		expect.equal(d, 1)
		expect.equal(m, 1)
		d, m = WeaponRules.bond(W, "prismBlade", "Shade")
		expect.equal(d, 1, "no weapon bonds with every creature")
		expect.equal(m, 1)
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
		expect.equal(cost.cash, 36000) -- $60,000 until 2026-11-20 (the owner: "60k in our current economy takes too long")
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
		expect.equal(sun.cash, 15000) -- $25,000 until 2026-11-20
		-- the Forge's top costs came down 40% that day (the owner's pick of three); Rare and Very Rare stayed
		expect.equal(W.BOSS_COST.Rare.cash, 2000)
		expect.equal(W.BOSS_COST["Very Rare"].cash, 5000)
		expect.equal(W.BOSS_COST.Epic.cash, 8000)
		expect.equal(W.BOSS_COST.Legendary.cash, 18000)
		expect.equal(W.BOSS_COST.Epic.material, 40, "materials as before")
		expect.equal(W.BOSS_COST.Legendary.material, 60)
		local forge = WeaponRules.makeCost(W, "forgeSword_Volt")
		assert(forge, "a Forge Sword has a cost")
		expect.equal(forge.cash, 1500)
		expect.equal(forge.items.wildOre, 20)
		local reforge = WeaponRules.reforgeCost(W, "verdantBlade")
		assert(reforge, "the Verdant Blade can be reforged")
		expect.equal(reforge.items.material_meadowWarden, 8)
		expect.equal(reforge.cash, 1000)
		expect.isNil(WeaponRules.makeCost(W, "starterSword"))
		expect.isNil(WeaponRules.makeCost(UNBUILT, "riftReaper"), "not built yet")
		expect.isNil(WeaponRules.reforgeCost(W, "starterSword"))
	end,

	-- The owner 2026-11-19 ("do all", the pre-launch QA's fifth finding): supers need a weapon of the creature's
	-- element, and a first one at $1,500 and 20 Wild Ore was about an hour and a half in, so an early Epic's super
	-- stayed locked that long. Your first Forge weapon costs FIRST_FORGE; every one after it the full price.
	["your first Forge weapon is cheap; the next ones, and every reforge, cost the full price"] = function()
		local starter = { starterSword = { grade = "C", level = 0 } }
		local first = WeaponRules.makeCost(W, "forgeSword_Ember", starter)
		assert(first, "a cost")
		expect.equal(first.cash, 500)
		expect.equal(first.items.wildOre, 8)
		expect.equal(first.unlockLevel, 6, "still from the Forge's shop level")
		expect.equal(WeaponRules.firstForge(W, starter), true)
		expect.equal(WeaponRules.firstForge(W, {}), true)
		-- a boss's weapon dropping first doesn't use the offer up: it may be another element
		local dropped = { starterSword = { grade = "C", level = 0 }, verdantBlade = { grade = "B", level = 0 } }
		expect.equal(WeaponRules.firstForge(W, dropped), true)
		local spear = WeaponRules.makeCost(W, "forgeSpear_Tide", dropped)
		assert(spear, "a cost")
		expect.equal(spear.cash, 500, "any Forge weapon, any family")
		-- once one is forged: the full price
		local forged = { starterSword = { grade = "C", level = 0 }, forgeSword_Ember = { grade = "C", level = 0 } }
		expect.equal(WeaponRules.firstForge(W, forged), false)
		local second = WeaponRules.makeCost(W, "forgeSword_Volt", forged)
		assert(second, "a cost")
		expect.equal(second.cash, 1500)
		expect.equal(second.items.wildOre, 20)
		-- boss weapons and masterworks never take it; nor does a reforge; nor a caller that doesn't say what's owned
		local rare = WeaponRules.makeCost(W, "verdantBlade", starter)
		assert(rare, "a cost")
		expect.equal(rare.cash, 2000)
		local reforge = WeaponRules.reforgeCost(W, "forgeSword_Ember")
		assert(reforge, "a cost")
		expect.equal(reforge.cash, 750, "half the full price")
		local plain = WeaponRules.makeCost(W, "forgeSword_Ember")
		assert(plain, "a cost")
		expect.equal(plain.cash, 1500)
		assert(W.FIRST_FORGE.cash < 1500 and W.FIRST_FORGE.items.wildOre < 20, "cheaper than the full price")
		assert(typeof(W.FIRST_FORGE.line) == "string" and W.FIRST_FORGE.line ~= "", "its words")
	end,

	["upgrades: +5 and +10 need Star Shards; none past +10; Forge weapons pay in Wild Ore"] = function()
		local five = WeaponRules.upgradeCost(W, "verdantBlade", 5)
		assert(five, "+5")
		expect.equal(five.items.starShard, 1)
		expect.equal(five.items.material_meadowWarden, 8) -- 4 until 2026-11-21 (upgrades take twice the materials)
		expect.equal(five.cash, 4000 * 0.8)
		local ten = WeaponRules.upgradeCost(W, "verdantBlade", 10)
		assert(ten, "+10")
		expect.equal(ten.items.starShard, 3)
		expect.isNil(WeaponRules.upgradeCost(W, "verdantBlade", 11))
		expect.isNil(WeaponRules.upgradeCost(W, "verdantBlade", 0))
		local tide = WeaponRules.upgradeCost(W, "forgeSword_Tide", 1)
		assert(tide, "a Forge Sword upgrades")
		expect.equal(tide.items.wildOre, 4)
		expect.isNil(tide.items.starShard)
		expect.isNil(WeaponRules.upgradeCost(W, "starterSword", 1))
		local sun = WeaponRules.upgradeCost(W, "sunforgedBlade", 1)
		assert(sun, "the Sunforged Blade upgrades")
		expect.equal(sun.items.material_emberColossus, 4, "a masterwork pays in its recipe's main material")
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
		expect.equal(need, 8, "its +5 needs 8")
		id, need = WeaponRules.materialGoal(W, "material_emberColossus", {})
		expect.equal(id, "sunforgedBlade", "the masterwork's recipe (the Magma Halberd isn't built)")
		expect.equal(need, 20)
		id, need = WeaponRules.materialGoal(W, "wildOre", {})
		expect.equal(id, "forgeSword_Ember", "the first Forge Sword")
		expect.equal(need, 8, "your first Forge weapon's special price (Weapons.FIRST_FORGE)")
		id, need = WeaponRules.materialGoal(W, "wildOre", { forgeSword_Ember = { grade = "C", level = 0 } })
		expect.equal(id, "forgeSword_Ember", "once owned: its next upgrade")
		expect.equal(need, 4)
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
		expect.isNil((WeaponRules.makeProgress(UNBUILT, "riftReaper", {})), "not built yet")
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

	-- Weapons round 4 part 2 (owner 2026-11-25): a drop you already own is a mutation roll (the caller's: BossService
	-- and WeaponService.Offer), so it gives nothing by itself; the 10 material it gave before would flood the upgrades
	-- now that boss weapons drop almost every win
	["a drop you already own gives nothing by itself; a reforge keeps the better grade, the level and the mutation"] = function()
		local owned = { verdantBlade = { grade = "S", level = 4 } }
		local rec, refund = WeaponRules.give(owned, "verdantBlade", "C", "drop", W)
		expect.isNil(rec)
		expect.equal(refund, 0, "its mutation roll instead of material")
		expect.isNil((W :: any).DUPLICATE_MATERIAL, "no duplicate material any more")
		rec = WeaponRules.give(owned, "verdantBlade", "B", "reforge", W)
		expect.isNil(rec)
		local sharp = { id = "sharp", rarity = "Epic" }
		local guard = { id = "guard", rarity = "Rare" }
		rec = WeaponRules.give({ verdantBlade = { grade = "B", level = 4, mutation = sharp, pending = guard } }, "verdantBlade", "S", "reforge", W)
		assert(rec, "a better reforge")
		expect.equal(rec.grade, "S")
		expect.equal(rec.level, 4)
		expect.equal(rec.mutation and rec.mutation.id, "sharp", "a reforge keeps the mutation")
		expect.equal(rec.pending and rec.pending.id, "guard", "and the one waiting")
		local fresh, none = WeaponRules.give({}, "verdantBlade", "A", "drop", W)
		assert(fresh, "a new drop")
		expect.equal(fresh.grade, "A")
		expect.equal(fresh.level, 0)
		expect.isNil(fresh.mutation, "a new weapon comes plain (the owner's mockup: today's reveal)")
		expect.equal(none, 0)
	end,

	["loading keeps a known mutation and a waiting one, and drops unknown ones"] = function()
		local MutationRules = require("../src/shared/Util/MutationRules")
		local Mutations = require("../src/shared/Config/Mutations")
		local function readMutation(value: unknown)
			return MutationRules.read(Mutations, value)
		end
		local owned = WeaponRules.read(W, {
			verdantBlade = { grade = "A", level = 2, mutation = { id = "sharp", rarity = "Epic" }, pending = { id = "guard", rarity = "Rare" } },
			sunforgedBlade = { grade = "B", level = 0, mutation = { id = "nope", rarity = "Epic" }, pending = "junk" },
		}, nil, readMutation)
		local verdant = owned.verdantBlade
		expect.equal(verdant.mutation and verdant.mutation.id, "sharp")
		expect.equal(verdant.mutation and verdant.mutation.rarity, "Epic")
		expect.equal(verdant.pending and verdant.pending.id, "guard")
		expect.equal(owned.sunforgedBlade.grade, "B", "the weapon itself stays")
		expect.isNil(owned.sunforgedBlade.mutation, "an unknown mutation is dropped")
		expect.isNil(owned.sunforgedBlade.pending, "and junk")
		local plain = WeaponRules.read(W, { verdantBlade = { grade = "A", level = 2, mutation = { id = "sharp", rarity = "Epic" } } }, nil)
		expect.isNil(plain.verdantBlade.mutation, "no reader given: no mutation read")
	end,

	-- owner 2026-11-26 (Essence only from drops): a Forge roll's waiting choice is saved with `forge = true`, so it
	-- still gives none after a rejoin; anything else there is read as a drop's
	["loading keeps a Forge roll's mark on its waiting mutation"] = function()
		local MutationRules = require("../src/shared/Util/MutationRules")
		local Mutations = require("../src/shared/Config/Mutations")
		local function readMutation(value: unknown)
			return MutationRules.read(Mutations, value)
		end
		local owned = WeaponRules.read(W, {
			verdantBlade = { grade = "A", level = 2, pending = { id = "guard", rarity = "Rare", forge = true } },
			sunforgedBlade = { grade = "B", level = 0, pending = { id = "sharp", rarity = "Epic", forge = "yes" } },
			tidalTrident = { grade = "C", level = 0, mutation = { id = "sharp", rarity = "Epic", forge = true } },
		}, nil, readMutation)
		local verdant = owned.verdantBlade.pending
		expect.equal(verdant and verdant.id, "guard")
		expect.equal(verdant and verdant.forge, true, "a Forge roll's choice stays one")
		local sunforged = owned.sunforgedBlade.pending
		expect.equal(sunforged and sunforged.id, "sharp", "the mutation itself kept")
		expect.isNil(sunforged and sunforged.forge, "only true marks it")
		local trident = owned.tidalTrident.mutation
		expect.isNil(trident and (trident :: any).forge, "a kept mutation never carries the mark")
	end,

	-- Weapons round 4 part 2 (owner 2026-11-25: "increase the weapons droprate to almost always drop on bosses. then
	-- every weapon should have a chance for a mutation"): 95 / 92 / 88 / 85% by rarity, sure by the second loot win; a
	-- drop of one you have is its mutation roll. (A Rare 20% plus 2.5% and a Legendary 6% plus 0.08% until then.)
	["drops come almost every loot win, rarer a little less: 95 / 92 / 88 / 85%, sure by the second"] = function()
		expect.equal(WeaponRules.dropChance(W, "verdantBlade", 0), 1, "a Wild boss's Rare: 95% x 1.3, capped")
		expect.near(WeaponRules.dropChance(W, "prismBlade", 0), 0.85, 1e-9)
		expect.equal(WeaponRules.dropChance(W, "prismBlade", 1), 1, "sure on the second")
		expect.equal(WeaponRules.dropChance(W, "nope", 0), 0)
		expect.near(W.DROP.Rare.base, 0.95, 1e-9)
		expect.near(W.DROP["Very Rare"].base, 0.92, 1e-9)
		expect.near(W.DROP.Epic.base, 0.88, 1e-9)
		expect.near(W.DROP.Legendary.base, 0.85, 1e-9)
		for _, rarity in { "Rare", "Very Rare", "Epic", "Legendary" } do
			local odds = W.DROP[rarity]
			expect.equal(math.min(1, odds.base + odds.step), 1, `{rarity}: sure by the second loot win`)
		end
		assert(W.DROP.Rare.base > W.DROP["Very Rare"].base and W.DROP["Very Rare"].base > W.DROP.Epic.base and W.DROP.Epic.base > W.DROP.Legendary.base, "rarer a little less likely")
	end,

	-- The material comes every loot win (ChestRules.mine): the weights' 1-3 plus this by the weapon's rarity, so the
	-- upgrades take about as long as when a duplicate gave 10 (an owner's old average a loot win: Rare 3.5, Very Rare
	-- 2.8, Epic 2.4, Legendary 1.8; now 3.2, 3.2, 2.2, 2.2)
	["the material every loot win by the weapon's rarity"] = function()
		expect.equal(WeaponRules.materialEveryWin(W, "verdantBlade"), 2, "Rare")
		expect.equal(WeaponRules.materialEveryWin(W, "tidalTrident"), 1, "Epic")
		expect.equal(WeaponRules.materialEveryWin(W, "sunforgedBlade"), 0, "a masterwork: no boss drops it")
		expect.equal(WeaponRules.materialEveryWin(W, "prismBlade"), 1, "Legendary")
		expect.equal(WeaponRules.materialEveryWin(W, "forgeSword_Ember"), 0, "not a boss's weapon")
		expect.equal(WeaponRules.materialEveryWin(W, "nope"), 0)
		expect.equal(W.MATERIAL_EVERY_WIN["Very Rare"], 2)
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
		expect.equal(WeaponRules.unlocked(UNBUILT, "riftReaper", 50), false, "not built yet")
		expect.equal(WeaponRules.unlocked(W, "riftReaper", 1), true, "built: a boss weapon, no shop level")
	end,

	-- Weapons round 3 (spec 4): the scythes' perks at Grade S (every share x PERK_S, the thresholds kept)
	["the scythes' perks scale at Grade S, their thresholds kept"] = function()
		local chain = WeaponRules.perk(W, "stormReaper", "S") :: any
		expect.near(chain.share, 0.4 * W.PERK_S, 1e-9)
		expect.near(chain.spread, 0.3 * W.PERK_S, 1e-9)
		expect.equal(chain.every, 4)
		local reap = WeaponRules.perk(W, "riftReaper", "S") :: any
		expect.near(reap.share, 0.3 * W.PERK_S, 1e-9)
		expect.equal(reap.below, 0.3, "the threshold stays")
		local venom = WeaponRules.perk(W, "widowsReaper", "C") :: any
		expect.equal(venom.look, "venom")
		expect.near(venom.share, 0.025, 1e-9)
		expect.near((WeaponRules.perk(W, "widowsReaper", "S") :: any).share, 0.025 * W.PERK_S, 1e-9)
	end,

	-- Owner 2026-11-19: Epic and Legendary supers stay locked until you hold a weapon of your creature's element (the
	-- Prism Blade unlocks every one); a sword, a spear or a scythe all count
	["supers: unlocked by a weapon of the creature's element, or the Prism Blade"] = function()
		expect.equal(WeaponRules.superUnlocked(W, "forgeSword_Ember", "Ember"), true)
		expect.equal(WeaponRules.superUnlocked(W, "magmaHalberd", "Ember"), true, "a spear counts")
		expect.equal(WeaponRules.superUnlocked(W, "riftReaper", "Shade"), true, "a scythe counts")
		expect.equal(WeaponRules.superUnlocked(W, "prismBlade", "Volt"), false, "the Prism Blade unlocks none: a super needs its element's weapon")
		expect.equal(WeaponRules.superUnlocked(W, "prismBlade", "Bloom"), false)
		expect.equal(WeaponRules.superUnlocked(W, "forgeSword_Ember", "Tide"), false, "another element")
		expect.equal(WeaponRules.superUnlocked(W, "starterSword", "Ember"), false, "the Steel Sword has no element")
		expect.equal(WeaponRules.superUnlocked(W, nil, "Ember"), false, "no sword yet")
		expect.equal(WeaponRules.superUnlocked(W, "noSuchWeapon", "Ember"), false)
		expect.equal(WeaponRules.superUnlocked(W, "forgeSword_Ember", nil), false)
	end,

	-- Owner 2026-11-19 ("weapon strength: OK"): the weapon that unlocks a super powers it, SUPER.share of the way from
	-- the Steel Sword's Power to its own
	["supers: a stronger weapon fires a stronger super"] = function()
		local common = WeaponRules.superScale(W, "forgeSword_Ember", "C", 0)
		expect.near(common, 1 + W.SUPER.share * (WeaponRules.power(W, "forgeSword_Ember", "C", 0) - 1), 1e-9)
		local upgraded = WeaponRules.superScale(W, "forgeSword_Ember", "S", 10)
		local legendary = WeaponRules.superScale(W, "riftReaper", "S", 10)
		expect.equal(common > 1, true, "even a new Forge weapon adds a little")
		expect.equal(upgraded > common, true, "upgrades and grade add more")
		expect.equal(legendary > upgraded, true, "a Legendary weapon most")
		expect.near(WeaponRules.superScale(W, "starterSword", "C", 0), 1, 1e-9, "the Steel Sword: no change")
	end,

	-- owner 2026-11-20: "slightly increase weapon droprate on wild bosses only"
	["the Wild's bosses drop their weapons a little more often; the Frontier's and the Dungeon's as before"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		assert(W.DROP_WILD > 1 and W.DROP_WILD <= 1.5, "slightly")
		local wild, other = 0, 0
		for _, weapon in W.WEAPONS do
			local source = weapon.source
			if source.kind == "boss" then
				local boss = Bosses.BOSSES[source.boss]
				local odds = W.DROP[weapon.rarity]
				for _, pity in { 0, 7, 40 } do
					local plain = math.min(1, odds.base + odds.step * pity)
					local expected = if boss.place == "Wild" then math.min(1, plain * W.DROP_WILD) else plain
					expect.near(WeaponRules.dropChance(W, weapon.id, pity), expected, 1e-9, `{weapon.id} at pity {pity}`)
				end
				if boss.place == "Wild" then
					wild += 1
					expect.equal(W.WILD_BOSSES[source.boss], true, `{source.boss} is a Wild boss`)
				else
					other += 1
					expect.isNil(W.WILD_BOSSES[source.boss], `{source.boss} is not`)
				end
			end
		end
		assert(wild >= 3 and other >= 3, "both kinds checked")
	end,

	-- owner 2026-11-21: "should we up the weapons drop rate overall? to make it easier for the players to get their
	-- hands on one but. increase the grind to upgrade it", option B, then "epic/legendary weapons should still be hard
	-- to get": a weapon is weaker when it drops and gains 5% a level, so +10 is about what it was; Rare and Very Rare
	-- drop much sooner; upgrades take twice the materials
	["weapons: easier to get, their Power in the upgrades"] = function()
		local function at(id: string, level: number): number
			return WeaponRules.power(W, id, "C", level)
		end
		-- a fresh one is weaker than it was (1.15 / 1.25 / 1.4 / 1.6 / 1.8), never under the Steel Sword
		expect.near(at("forgeSword_Ember", 0), 1.05, 1e-9)
		expect.near(at("verdantBlade", 0), 1.1, 1e-9)
		expect.near(at("magmaHalberd", 0), 1.22, 1e-9)
		expect.near(at("sunforgedBlade", 0), 1.39, 1e-9)
		expect.near(at("riftReaper", 0), 1.21, 1e-9)
		expect.near(at("titansLance", 0), 1.04, 1e-9)
		for _, weapon in W.WEAPONS do
			if weapon.ready and not weapon.prism then
				assert(at(weapon.id, 0) >= W.STARTER_POWER, `{weapon.id} at +0 under the Steel Sword`)
			end
		end
		-- every level adds 5%: +10 is where it was (the old base x 1.3), within 6%
		expect.equal(W.UPGRADE_STEP, 0.05)
		-- (the Prism Blade left this list in weapons round 4: its Power took in its old bond, its hits pinned by "the
		-- Prism Blade's own base replaces its rarity's")
		local before = { forgeSword_Ember = 1.15, verdantBlade = 1.25, magmaHalberd = 1.4, sunforgedBlade = 1.6, riftReaper = 1.4, titansLance = 1.2 }
		for id, base in before do
			local was, now = base * 1.3, at(id, 10)
			assert(math.abs(now / was - 1) <= 0.06, `{id} at +10: {now}, {was} before`)
			assert(at(id, 0) < base, `{id} drops weaker than before`)
		end
		-- the wins it takes (median, with the pity; a Wild boss's a little sooner)
		local function median(rarity: string): number
			local odds = W.DROP[rarity]
			local left, wins = 1, 0
			while left > 0.5 do
				left *= 1 - math.min(1, odds.base + odds.step * wins)
				wins += 1
			end
			return wins
		end
		-- "epic/legendary weapons should still be hard to get" kept them at 50 and 79 wins for a few hours; then the owner
		-- on the Tidal Trident's 0.20%: "weapon drop chance for some weapons like this is too low. it's almoost imposible
		-- to get make it more forgiving" (22 and 37); then, the same evening, "increase epic weapon drop rate to 12% then
		-- legendaries to 6. if thats fair" (3 / 4 / 6 / 11). Since weapons round 4 part 2 (2026-11-25: "almost always
		-- drop on bosses") the first loot win, a duplicate being a mutation roll. A weapon is quick to get; the grind is
		-- its upgrade
		expect.near(W.DROP.Rare.base, 0.95, 1e-9)
		expect.near(W.DROP.Legendary.base, 0.85, 1e-9)
		for _, rarity in { "Rare", "Very Rare", "Epic", "Legendary" } do
			expect.equal(median(rarity), 1, `{rarity}: the first loot win, most times`)
		end
		-- the boss board's "Drop chance now" goes down with rarity, on the first try and after any number of misses
		for _, misses in { 0, 5, 20 } do
			local function at(rarity: string): number
				return W.DROP[rarity].base + W.DROP[rarity].step * misses
			end
			assert(at("Rare") > at("Very Rare") and at("Very Rare") > at("Epic") and at("Epic") > at("Legendary"), `rarer is slower after {misses} misses`)
		end
		-- upgrades: twice the materials (50 before), the same cash
		local total = 0
		for _, count in W.UPGRADE.material do
			total += count
		end
		expect.equal(total, 100)
		expect.equal(W.UPGRADE.cash[10], 22000)
	end,
}
