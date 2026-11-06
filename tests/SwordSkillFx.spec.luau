--!strict
-- The round 1 swords' effects (sword skills round, spec 2026-11-06-sword-skills-design 4): every look a moveset names
-- exists with its kind and real textures, every Forge Sword element has its colours, the scale and others' budget rules
local SwordSkillFx = require("../src/shared/Config/SwordSkillFx")
local SwordSkillFxRules = require("../src/shared/Util/SwordSkillFxRules")
local Swords = require("../src/shared/Config/Swords")
local Weapons = require("../src/shared/Config/Weapons")
local WeaponLooks = require("../src/shared/Config/WeaponLooks")
local AttackFx = require("../src/shared/Config/AttackFx")
local MoveFx = require("../src/shared/Config/MoveFx")
local SuperFx = require("../src/shared/Config/SuperFx")
local SwordFx = require("../src/shared/Config/SwordFx")
local AdminPanel = require("../src/shared/Config/AdminPanel")
local expect = require("./lib/expect")

local TEXTURE_TABLES = { AttackFx.TEXTURES, MoveFx.TEXTURES, SuperFx.TEXTURES, SwordFx.TEXTURES }

local function textureExists(key: string): boolean
	for _, list in TEXTURE_TABLES do
		if (list :: any)[key] ~= nil then
			return true
		end
	end
	return false
end

return {
	["every look a moveset names exists with the right kind and real textures"] = function()
		local named = 0
		for id, sword in Swords.SWORDS do
			if sword.fx then
				for kind, look in sword.fx :: any do
					named += 1
					local spec = SwordSkillFx.LOOKS[look]
					assert(spec, `{id} {kind}: no look {look}`)
					expect.equal(spec.kind, kind, `{look} is a {kind}`)
					expect.equal(#spec.textures > 0, true, `{look} has textures`)
					for _, texture in spec.textures do
						expect.equal(textureExists(texture), true, `{look}: texture {texture}`)
					end
				end
			end
		end
		expect.equal(named, 12, "four swords x slash, finisher, skill")
	end,

	["every element has its look colours, so each Forge Sword is coloured (Review Focus 5)"] = function()
		for _, weapon in Weapons.WEAPONS do
			if weapon.element and weapon.ready then
				local look = WeaponLooks.BY_ELEMENT[weapon.element]
				assert(look, `{weapon.id}: {weapon.element} has no look`)
				expect.equal(#look.glow, 3, `{weapon.element} glow`)
				expect.equal(#look.deep, 3, `{weapon.element} deep`)
				local own = WeaponLooks.WEAPONS[weapon.id]
				assert(own and own.glow and own.deep, `{weapon.id} has its own glow and deep`)
			end
		end
	end,

	["effects keep their size below +7, then grow with the trail's scale"] = function()
		expect.equal(SwordSkillFxRules.scale(1), 1)
		expect.equal(SwordSkillFxRules.scale(1.5), 1.5)
		expect.equal(SwordSkillFxRules.scale(0), 1, "no trail yet: full size")
	end,

	["others' effects: full nearby until a few are drawn, then light, none far away (Review Focus 4)"] = function()
		local others = SwordSkillFx.OTHERS
		expect.equal(others.range, 90)
		expect.equal(others.full, 3)
		expect.equal(SwordSkillFxRules.drawsOthers(30, 0, others), "full")
		expect.equal(SwordSkillFxRules.drawsOthers(30, 3, others), "light")
		expect.equal(SwordSkillFxRules.drawsOthers(200, 0, others), "none")
		expect.equal(SwordSkillFxRules.drawsOthers(90, 0, others), "full", "at the edge of range")
	end,

	["/skillfx names a round 1 weapon with effects for each sword and element"] = function()
		for name, weaponId in SwordSkillFx.PREVIEW do
			local weapon = Weapons.ById[weaponId]
			assert(weapon and weapon.moveset, `{name}: {weaponId} is a weapon with a moveset`)
			expect.equal(Swords.SWORDS[weapon.moveset].fx ~= nil, true, `{name}: its moveset has effects`)
		end
		for _, name in { "sunforged", "verdant", "prism", "forge", "ember", "tide", "bloom", "volt", "shade" } do
			expect.equal(SwordSkillFx.PREVIEW[name] ~= nil, true, name)
		end
	end,

	["the admin panel has a Sword skills section of /skillfx buttons"] = function()
		local found = false
		for _, section in AdminPanel.SECTIONS do
			if section.title == "Sword skills" then
				found = true
				expect.equal(#section.buttons >= 8, true, "four swords x finisher and skill")
				for _, button in section.buttons do
					expect.equal(string.sub(button.command, 1, 8), "/skillfx", button.label)
				end
			end
		end
		expect.equal(found, true, "a Sword skills section")
	end,
}
