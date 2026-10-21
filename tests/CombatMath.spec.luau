--!strict
local CombatMath = require("../src/shared/Util/CombatMath")
local combat = require("../src/shared/Config/Combat")
local wild = require("../src/shared/Config/Wild")
local expect = require("./lib/expect")

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

return {
	["element wheel: strong, weak and neutral for all 25 pairs"] = function()
		local strong = { Ember = "Bloom", Bloom = "Tide", Tide = "Ember", Volt = "Shade", Shade = "Volt" }
		for _, a in ELEMENTS do
			for _, d in ELEMENTS do
				local mult, kind = CombatMath.getElementMultiplier(combat, a, d)
				if strong[a] == d then
					expect.equal(mult, combat.STRONG, `{a}>{d}`)
					expect.equal(kind, "strong", `{a}>{d} kind`)
				elseif strong[d] == a then
					expect.equal(mult, combat.WEAK, `{a}<{d}`)
					expect.equal(kind, "weak", `{a}<{d} kind`)
				else
					expect.equal(mult, 1, `{a}={d}`)
					expect.isNil(kind, `{a}={d} kind`)
				end
			end
		end
	end,

	["attack interval: faster with SPD, clamped"] = function()
		expect.near(CombatMath.getAttackInterval(combat, 10), 2, 1e-9, "Common SPD 10")
		expect.near(CombatMath.getAttackInterval(combat, 20), 1, 1e-9, "Legendary SPD 20")
		expect.equal(CombatMath.getAttackInterval(combat, 1000), combat.ATTACK_MIN, "min")
		expect.equal(CombatMath.getAttackInterval(combat, 1), combat.ATTACK_MAX, "max")
		expect.equal(CombatMath.getAttackInterval(combat, 0), combat.ATTACK_MAX, "zero SPD")
	end,

	["damage: spread around ATK x multiplier, at least 1"] = function()
		expect.equal(CombatMath.getDamage(combat, 20, 1, 0.5), 20, "middle roll")
		expect.equal(CombatMath.getDamage(combat, 20, 1, 0), 18, "low roll -10%")
		assert(CombatMath.getDamage(combat, 20, 1.5, 0.999) <= 33, "high roll +10%")
		expect.equal(CombatMath.getDamage(combat, 0.1, 0.75, 0), 1, "at least 1")
	end,

	["run chance: SPD moves it, clamped, elite penalty"] = function()
		expect.near(CombatMath.getRunChance(combat, 10, 10, false), 0.5, 1e-9, "even")
		expect.near(CombatMath.getRunChance(combat, 14, 10, false), 0.62, 1e-9, "+4 SPD")
		expect.equal(CombatMath.getRunChance(combat, 100, 1, false), combat.RUN_MAX, "max")
		expect.equal(CombatMath.getRunChance(combat, 1, 100, false), combat.RUN_MIN, "min")
		expect.near(CombatMath.getRunChance(combat, 14, 10, true), 0.47, 1e-9, "elite")
		expect.equal(CombatMath.getRunChance(combat, 1, 100, true), combat.RUN_MIN, "elite floor")
	end,

	["xp split: floor, at least 1, never more than the total"] = function()
		expect.equal(CombatMath.splitXp(30, 3), 10, "even")
		expect.equal(CombatMath.splitXp(31, 3), 10, "floor")
		expect.equal(CombatMath.splitXp(1, 3), 1, "at least 1")
		expect.equal(CombatMath.splitXp(0, 3), 0, "nothing to split")
		expect.equal(CombatMath.splitXp(30, 0), 0, "no cards")
	end,

	["monster stats grow with level; elites stronger; unknown species nil"] = function()
		local low = CombatMath.getMonsterStats(wild, "Mossling", 1, false) :: any
		local high = CombatMath.getMonsterStats(wild, "Mossling", 5, false) :: any
		local elite = CombatMath.getMonsterStats(wild, "Mossling", 1, true) :: any
		assert(high.hp > low.hp and high.atk > low.atk, "grows")
		expect.equal(elite.hp, math.round(low.hp * wild.ELITE_STAT_MULTIPLIER), "elite hp")
		expect.isNil(CombatMath.getMonsterStats(wild, "Nope", 1, false), "unknown")
	end,

	["rewards scale with level and elite"] = function()
		local r1 = CombatMath.getRewards(wild, 1, false)
		local r10 = CombatMath.getRewards(wild, 10, false)
		local e1 = CombatMath.getRewards(wild, 1, true)
		assert(r10.xp > r1.xp and r10.cash > r1.cash, "level")
		expect.equal(e1.xp, r1.xp * wild.ELITE_REWARD_MULTIPLIER, "elite xp")
		expect.equal(r1.dropChance, wild.DROP_CHANCE, "normal drop")
		expect.equal(e1.dropChance, wild.ELITE_DROP_CHANCE, "elite drop")
	end,

	["every zone species exists and every species has a valid element"] = function()
		for _, zone in wild.ZONES do
			for _, species in zone.species do
				assert(wild.SPECIES[species], `{zone.name}: unknown species {species}`)
			end
		end
		for name, species in wild.SPECIES do
			assert(table.find(ELEMENTS, species.element), `{name}: element {species.element}`)
		end
	end,
}
