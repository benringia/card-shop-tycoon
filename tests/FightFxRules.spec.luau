--!strict
local FightFxRules = require("../src/shared/Util/FightFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
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
}
