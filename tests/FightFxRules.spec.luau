--!strict
local FightFxRules = require("../src/shared/Util/FightFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
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
}
