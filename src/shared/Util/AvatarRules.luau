--!strict
-- Avatar cosmetics and our sword (owner 2026-11-18, pick A: "Player models that has sword cosmetics on their back
-- should be removed? so that it will not overlap with our weapon?"): a weapon worn on the back goes, since the game's
-- sword sits there; wings, capes and backpacks stay (a boss fight still hides every back accessory, SwordService
-- SetBackHidden). Names are matched by whole words, CamelCase split ("BackSword"), plurals too, so "Swordfish" or
-- "Rainbow Wings" never match. Server SwordService. Pure, Lune-tested.
local AvatarRules = {}

local WEAPON_WORDS = {
	"sword", "greatsword", "longsword", "broadsword", "katana", "blade", "scythe", "spear", "lance", "trident",
	"halberd", "glaive", "axe", "hammer", "mace", "bow", "crossbow", "gun", "rifle", "blaster", "bazooka", "launcher",
	"saber", "sabre", "dagger", "knife", "knives", "staff", "claymore", "sheath", "scabbard", "weapon",
}

-- Whether an accessory's name says it's a weapon
function AvatarRules.looksLikeWeapon(name: string): boolean
	local words = string.lower((string.gsub(name, "(%l)(%u)", "%1 %2")))
	for _, word in WEAPON_WORDS do
		if string.find(words, "%f[%a]" .. word .. "s?%f[%A]") then
			return true
		end
	end
	return false
end

-- Whether an accessory (its AccessoryType's name, its name) goes: a weapon worn on the back
function AvatarRules.hidesOnBack(accessoryType: string, name: string): boolean
	return accessoryType == "Back" and AvatarRules.looksLikeWeapon(name)
end

return AvatarRules
