--!strict
local FightFxRules = require("../src/shared/Util/FightFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local Wild = require("../src/shared/Config/Wild")
local SwordFx = require("../src/shared/Config/SwordFx")
local expect = require("./lib/expect")

return {
	["effects stay within their budget, smaller with extras off"] = function()
		expect.equal(AttackFx.MAX_ACTIVE, 12)
		expect.equal(AttackFx.MAX_ACTIVE_LOW, 4)
		expect.equal(FightFxRules.budget(11, true, AttackFx), true)
		expect.equal(FightFxRules.budget(12, true, AttackFx), false)
		expect.equal(FightFxRules.budget(3, false, AttackFx), true)
		expect.equal(FightFxRules.budget(4, false, AttackFx), false)
	end,

	["each element's attack kind comes from the config"] = function()
		for element, entry in AttackFx.ELEMENT do
			expect.equal(FightFxRules.kindFor(element, AttackFx), entry.kind, element)
		end
		expect.isNil(FightFxRules.kindFor("Plasma", AttackFx), "an unknown element has none")
	end,

	["projectile and bolt attackers fight from range, combo ones up close"] = function()
		expect.equal(FightFxRules.isRanged("Ember", AttackFx), true, "Ember throws fireballs")
		expect.equal(FightFxRules.isRanged("Tide", AttackFx), true, "Tide throws water")
		expect.equal(FightFxRules.isRanged("Volt", AttackFx), true, "Volt shoots a bolt")
		expect.equal(FightFxRules.isRanged("Bloom", AttackFx), false, "Bloom lashes up close")
		-- The owner (2026-11-05): "Remodel shade basic attack, change it to a ranged moon slash dark purple"
		expect.equal(FightFxRules.isRanged("Shade", AttackFx), true, "Shade flings a moon slash")
		expect.equal(FightFxRules.isRanged("Plasma", AttackFx), false, "an unknown element stands close")
		expect.equal(Combat.RANGED_BACK > 0, true, "ranged creatures stand further back")
	end,

	["every element attack has its sounds"] = function()
		for element in AttackFx.ELEMENT do
			local sounds = AttackFx.SOUNDS[element]
			expect.equal(sounds ~= nil and typeof(sounds.hit) == "string", true, element)
		end
		expect.equal(typeof(AttackFx.SOUNDS.charge), "string")
	end,

	["every Pet button move and super move has its effect"] = function()
		for element, ability in Combat.ABILITIES do
			expect.equal(FightFxRules.hasEffect(ability.kind, AttackFx), true, `{element} {ability.kind}`)
		end
		for name, signature in Combat.SIGNATURES do
			expect.equal(FightFxRules.hasEffect(signature.kind, AttackFx), true, `{name} {signature.kind}`)
		end
		expect.equal(FightFxRules.hasEffect("Nothing", AttackFx), false)
	end,

	["every boss move effect is a real boss's, with its looks and sounds"] = function()
		local styles = { strike = { leaves = true, fangs = true, embers = true }, release = { roots = true, web = true, lava = true } }
		for bossId, moves in AttackFx.BOSS do
			expect.equal(Bosses.BOSSES[bossId] ~= nil, true, bossId)
			expect.equal(styles.strike[moves.strike], true, `{bossId} strike`)
			expect.equal(styles.release[moves.release], true, `{bossId} release`)
			expect.equal(#moves.color, 3, bossId)
			expect.equal(string.match(moves.sounds.strike, "^rbxassetid://%d+$") ~= nil, true, `{bossId} strike sound`)
			expect.equal(string.match(moves.sounds.release, "^rbxassetid://%d+$") ~= nil, true, `{bossId} release sound`)
		end
		expect.equal(AttackFx.BOSS.prismHydra, nil, "no Hydra until its remodel")
	end,

	["every wild monster's attack look is a real species', with its sound"] = function()
		local styles = { bite = true, dive = true, embers = true, headbutt = true, snap = true, spark = true }
		local count = 0
		for species, moves in AttackFx.MONSTER do
			count += 1
			expect.equal(Wild.SPECIES[species] ~= nil, true, species)
			expect.equal(styles[moves.strike], true, `{species} strike`)
			expect.equal(#moves.color, 3, species)
			expect.equal(string.match(moves.sounds.strike, "^rbxassetid://%d+$") ~= nil, true, `{species} sound`)
		end
		local wild = 0
		for _ in Wild.SPECIES do
			wild += 1
		end
		expect.equal(count, wild, "every species has one")
	end,

	["a creature's grade sets how big its attack looks"] = function()
		local c, b, a, s = FightFxRules.tier("C", AttackFx), FightFxRules.tier("B", AttackFx), FightFxRules.tier("A", AttackFx), FightFxRules.tier("S", AttackFx)
		expect.equal(c.scale, 1)
		expect.equal(c.extra, 0)
		expect.near(b.scale, 1.25, 1e-9)
		expect.equal(b.extra, 0)
		expect.near(a.scale, 1.55, 1e-9)
		expect.equal(a.extra, 1)
		expect.near(s.scale, 2, 1e-9)
		expect.equal(s.extra, 2)
		expect.equal(c.sparks < b.sparks and b.sparks < a.sparks and a.sparks < s.sparks, true, "more sparks each grade")
		expect.equal(c.shake < b.shake and b.shake < a.shake and a.shake < s.shake, true, "more shake each grade")
		expect.equal(FightFxRules.tier(nil, AttackFx), c, "no grade: C")
		expect.equal(FightFxRules.tier("Z", AttackFx), c, "unknown: C")
	end,

	-- Owner 2026-11-09: creature hits get the sword hit's pack effects, "slashes on slash attacks and no slash on non
	-- slash attacks", the element's own particles on all
	["a creature's cut lands with the slash streaks, its other attacks without"] = function()
		expect.equal(FightFxRules.cuts("Bloom", AttackFx), true, "the Bloom combo")
		expect.equal(FightFxRules.cuts("Shade", AttackFx), true, "the moon slash")
		for _, element in { "Ember", "Tide", "Volt" } do
			expect.equal(FightFxRules.cuts(element, AttackFx), false, element)
		end
		expect.equal(FightFxRules.cuts("Plasma", AttackFx), false, "an unknown element")
	end,

	["a combo's earlier hits and the extra moon slashes land lighter than the hit with the damage"] = function()
		local light = AttackFx.LIGHT_HIT
		assert(light.size > 0 and light.size < 1, `size {light.size}`)
		assert(light.share > 0 and light.share < 1, `share {light.share}`)
	end,

	["a hit's pack emitters: the streaks and arc only on a cut, the sparks and the element's own always"] = function()
		local slashTextures = { slashStreak = true, slashArc = true }
		for element, own in SwordFx.ELEMENT_HIT do
			local cut = FightFxRules.hitSpecs(SwordFx, element, true)
			expect.equal(#cut, #SwordFx.IMPACT.emitters + #own, `{element} cut`)
			local plain = FightFxRules.hitSpecs(SwordFx, element, false)
			local textures: { [string]: boolean } = {}
			for _, spec in plain do
				assert(not slashTextures[spec.texture], `{element}: a {spec.texture} on a hit that isn't a cut`)
				textures[spec.texture] = true
			end
			assert(textures.sparkStreak, `{element}: the spark streaks stay`)
			for index, spec in own do
				assert(table.find(plain, spec) ~= nil, `{element}: its particle {index}`)
			end
		end
		expect.equal(#FightFxRules.hitSpecs(SwordFx, nil, true), #SwordFx.IMPACT.emitters, "no element: the cut alone")
	end,
}
