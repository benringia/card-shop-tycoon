--!strict
-- A card's skills as the card view shows them (the owner 2026-11-05: "Add Creature Skill to the creature card", option A)
local SkillText = require("../src/shared/Util/SkillText")
local Combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

return {
	["each Pet move says what it does, from the fight's numbers"] = function()
		expect.equal(SkillText.describe(Combat.ABILITIES.Ember), "A big hit: 2.5x ATK")
		expect.equal(SkillText.describe(Combat.ABILITIES.Tide), "Heals your creature 25% over 5 s")
		expect.equal(SkillText.describe(Combat.ABILITIES.Bloom), "Slows the foe 40% for 4 s")
		expect.equal(SkillText.describe(Combat.ABILITIES.Volt), "Next 3 attacks twice as fast")
		expect.equal(SkillText.describe(Combat.ABILITIES.Shade), "Foe hits 30% weaker for 5 s")
	end,

	["each super move says what it does"] = function()
		expect.equal(SkillText.describe(Combat.SIGNATURES.Infernox), "Burns the foe for 6 s")
		expect.equal(SkillText.describe(Combat.SIGNATURES["Abyssal Koi"]), "A shield worth 30% of its HP")
		expect.equal(SkillText.describe(Combat.SIGNATURES["Tideborne Kirin"]), "A shield worth 35% of its HP")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Thunderhorn), "A 2x hit and a 2 s stun")
		expect.equal(SkillText.describe(Combat.SIGNATURES["Eclipse Fox"]), "Dodges everything for 3 s")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Solarion), "A huge 4x hit")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Voidmaw), "A 2x hit that heals it for half")
		for name, ability in Combat.SIGNATURES do
			local line = SkillText.describe(ability)
			assert(#line > 0 and not string.find(line, "[^\32-\126]"), `{name}: plain ASCII text`)
		end
	end,

	["a card's skills: its element's Pet move, and a super move for the cards that have one"] = function()
		local plain = SkillText.forCard(Combat, "Tide", "Puffpuddle")
		expect.equal(plain.pet.name, "Healing Rain")
		expect.equal(plain.pet.kind, "Rain")
		expect.isNil(plain.super, "a Common has no super move")
		local legend = SkillText.forCard(Combat, "Ember", "Solarion")
		expect.equal(legend.pet.name, "Fireball")
		expect.equal(legend.super and legend.super.name, "Supernova")
		expect.equal(legend.super and legend.super.text, "A huge 4x hit")
	end,
}
