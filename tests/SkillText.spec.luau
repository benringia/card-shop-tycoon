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
		expect.equal(SkillText.describe(Combat.SIGNATURES["Abyssal Koi"]), "Shields you and your party: 30% HP for 8 s")
		expect.equal(SkillText.describe(Combat.SIGNATURES["Tideborne Kirin"]), "Revives your fainted creatures at 35% once a fight, heals the rest 15%")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Thunderhorn), "A 2x hit and a 2 s stun")
		expect.equal(SkillText.describe(Combat.SIGNATURES["Eclipse Fox"]), "Dodges everything for 5 s")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Riftwalker), "4 hits of 0.8x ATK from every side")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Solarion), "A huge 4x hit")
		expect.equal(SkillText.describe(Combat.SIGNATURES.Voidmaw), "A 2x hit that heals it for half")
		for name, ability in Combat.SIGNATURES do
			local line = SkillText.describe(ability)
			assert(#line > 0 and not string.find(line, "[^\32-\126]"), `{name}: plain ASCII text`)
		end
	end,

	-- The owner (2026-11-05): the fight buttons' tooltips "explain what the skill does"
	["the Pet and Super buttons' tooltips say what the creature's moves do"] = function()
		expect.equal(SkillText.buttonTip(Combat, "pet", "Shade", nil), "Foe hits 30% weaker for 5 s")
		expect.equal(SkillText.buttonTip(Combat, "signature", "Tide", "Tidal Blessing"), SkillText.describe(Combat.SIGNATURES["Tideborne Kirin"]))
		expect.equal(SkillText.buttonTip(Combat, "signature", "Shade", "Rift Step"), "4 hits of 0.8x ATK from every side")
		expect.isNil(SkillText.buttonTip(Combat, "signature", "Tide", nil), "no super")
		expect.isNil(SkillText.buttonTip(Combat, "pet", "None", nil), "no element move")
		expect.isNil(SkillText.buttonTip(Combat, "dodge", "Tide", nil), "other buttons keep their own tip")
	end,

	-- The owner (2026-11-05): "weakness/strength" on the card view
	["an element's matchups: who it beats and who beats it, from the element wheel"] = function()
		local ember = SkillText.matchups(Combat, "Ember")
		expect.equal(table.concat(ember.strong, ","), "Bloom")
		expect.equal(table.concat(ember.weak, ","), "Tide")
		local volt = SkillText.matchups(Combat, "Volt")
		expect.equal(table.concat(volt.strong, ","), "Shade")
		expect.equal(table.concat(volt.weak, ","), "Shade")
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
