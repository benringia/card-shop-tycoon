--!strict
-- A card's skills as the card view shows them (the owner 2026-11-05: "Add Creature Skill to the creature card", option A)
local SkillText = require("../src/shared/Util/SkillText")
local Combat = require("../src/shared/Config/Combat")
local CombatHud = require("../src/shared/Config/CombatHud")
local Swords = require("../src/shared/Config/Swords")
local UIIcons = require("../src/shared/Config/UIIcons")
local expect = require("./lib/expect")

return {
	-- The skill button per sword (owner's picks 2026-11-07): its own icon, name and tooltip, plus the dodge rule
	["each round 1 sword's skill button has its own icon, name and tooltip"] = function()
		local seen = {}
		local Weapons = require("../src/shared/Config/Weapons")
		local swordMovesets = {} -- the swords' (the spear's button: weapons round 2, its own test)
		for _, weapon in Weapons.WEAPONS do
			if weapon.family == "sword" and weapon.moveset then
				swordMovesets[weapon.moveset] = true
			end
		end
		for moveset in Swords.SWORDS do
			if moveset ~= Swords.STARTER and swordMovesets[moveset] then
				local button = SkillText.swordSkill(CombatHud, moveset)
				expect.equal(UIIcons[button.icon] ~= nil, true, `{moveset}'s icon is uploaded`)
				expect.equal(button.name ~= CombatHud.BUTTONS.skill.name, true, `{moveset} has its own name`)
				expect.equal(#button.tip <= 140, true, `{moveset}'s tooltip fits the tooltip box`)
				expect.isNil(seen[button.icon], `{moveset}'s icon is its own`)
				seen[button.icon] = true
			end
		end
		expect.equal(SkillText.swordSkill(CombatHud, "sunforgedBlade").name, "Sunfall Cleave")
		expect.equal(SkillText.swordSkill(CombatHud, "prismBlade").icon, "PrismJudgment")
	end,

	-- Weapons round 2: every spear's skill button is Piercing Rush's (the owner's pick C, 2026-11-07: a spear with its
	-- afterimages)
	["the spear's skill button: Piercing Rush, its afterimage icon and the dodge rule"] = function()
		local button = SkillText.swordSkill(CombatHud, "spear")
		expect.equal(button.icon, "PiercingRush")
		expect.equal(UIIcons[button.icon] ~= nil, true, "its icon is uploaded")
		expect.equal(button.name, "Piercing Rush")
		expect.equal(#button.tip <= 140, true, "its tooltip fits the tooltip box")
		local ending = CombatHud.SKILL_DODGE_TIP
		expect.equal(string.sub(button.tip, -#ending), ending, "ends with the dodge rule")
	end,

	-- Weapons round 2.5: the Titan's Lance's own skill button (owner 2026-11-08: the LanceLeaves glyph)
	["the Titan's Lance's skill button: Titan's Wrath, its lance-in-vines icon and the dodge rule"] = function()
		local button = SkillText.swordSkill(CombatHud, "titansLance")
		expect.equal(button.icon, "LanceLeaves")
		expect.equal(UIIcons[button.icon] ~= nil, true, "its icon is uploaded")
		expect.equal(button.name, "Titan's Wrath")
		expect.equal(#button.tip <= 140, true, "its tooltip fits the tooltip box")
		local ending = CombatHud.SKILL_DODGE_TIP
		expect.equal(string.sub(button.tip, -#ending), ending, "ends with the dodge rule")
	end,

	-- Weapons round 3: every scythe's Reaping Cyclone button (a spare glyph: a crescent flung out with sparks)
	["the scythe's skill button: Reaping Cyclone, its crescent icon and the dodge rule"] = function()
		local button = SkillText.swordSkill(CombatHud, "scythe")
		expect.equal(button.icon, "CrescentSparks")
		expect.equal(UIIcons[button.icon] ~= nil, true, "its icon is uploaded")
		expect.equal(button.name, "Reaping Cyclone")
		expect.equal(#button.tip <= 140, true, "its tooltip fits the tooltip box")
		local ending = CombatHud.SKILL_DODGE_TIP
		expect.equal(string.sub(button.tip, -#ending), ending, "ends with the dodge rule")
	end,

	-- The Rift Reaper's own skill button (spec 5.4: the Skull glyph, the summoned Grim Reaper)
	["the Rift Reaper's skill button: Thousand Cuts, the skull icon and the dodge rule"] = function()
		local button = SkillText.swordSkill(CombatHud, "riftReaper")
		expect.equal(button.icon, "Skull")
		expect.equal(UIIcons[button.icon] ~= nil, true, "its icon is uploaded")
		expect.equal(button.name, "Thousand Cuts")
		expect.equal(#button.tip <= 140, true, "its tooltip fits the tooltip box")
		local ending = CombatHud.SKILL_DODGE_TIP
		expect.equal(string.sub(button.tip, -#ending), ending, "ends with the dodge rule")
	end,

	-- Weapons round 2.5 part 2: the Halberd's and the Trident's own skill buttons (spare glyphs, spec 5)
	["the Halberd's and the Trident's skill buttons: Magma Cleave and Torrent Strike, their icons and the dodge rule"] = function()
		for moveset, want in { magmaHalberd = { "Magma Cleave", "HalberdFlames" }, tidalTrident = { "Torrent Strike", "TridentWave" } } do
			local button = SkillText.swordSkill(CombatHud, moveset)
			expect.equal(button.name, want[1], moveset)
			expect.equal(button.icon, want[2], moveset)
			expect.equal(UIIcons[button.icon] ~= nil, true, `{moveset}: its icon is uploaded`)
			expect.equal(#button.tip <= 140, true, `{moveset}: its tooltip fits the tooltip box`)
			local ending = CombatHud.SKILL_DODGE_TIP
			expect.equal(string.sub(button.tip, -#ending), ending, `{moveset}: ends with the dodge rule`)
		end
	end,

	["the Steel Sword and anything unknown keep the dash slash's button"] = function()
		for _, moveset in { Swords.STARTER, "noSuchSword", nil :: string? } do
			local button = SkillText.swordSkill(CombatHud, moveset)
			expect.equal(button.icon, CombatHud.BUTTONS.skill.icon)
			expect.equal(button.name, CombatHud.BUTTONS.skill.name)
		end
	end,

	["every skill's tooltip says a dodge before it lands cancels it"] = function()
		for _, moveset in { Swords.STARTER, "verdantBlade", "forgeSword" } do
			local tip = SkillText.swordSkill(CombatHud, moveset).tip
			expect.equal(string.find(tip, CombatHud.SKILL_DODGE_TIP, 1, true) ~= nil, true, moveset)
		end
	end,

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
