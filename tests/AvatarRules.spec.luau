--!strict
-- Avatar cosmetics and our sword (owner 2026-11-18, pick A: "Player models that has sword cosmetics on their back
-- should be removed? so that it will not overlap with our weapon?"): a weapon worn on the back goes, wings, capes and
-- backpacks stay
local AvatarRules = require("../src/shared/Util/AvatarRules")
local expect = require("./lib/expect")

return {
	["a weapon worn on the back goes: it would cross the sword the game puts there"] = function()
		for _, name in {
			"Dual Katanas",
			"Sword Pack",
			"BackSword",
			"Classic Sword on Back",
			"Scythe of Doom",
			"Spear",
			"Battle Axe",
			"Bow and Arrow",
			"Crossbow",
			"Sniper Rifle",
			"Sheathed Blade",
			"Golden Greatsword",
			"Katana_01",
			"Trident",
			"Wizard Staff",
			"Throwing Knives",
		} do
			expect.equal(AvatarRules.hidesOnBack("Back", name), true, name)
		end
	end,

	["wings, capes, backpacks and look-alike words stay"] = function()
		for _, name in { "Rainbow Wings", "Red Cape", "Bunny Backpack", "Swordfish Plush", "Bowtie Bear", "Axolotl Backpack", "Angel Wings", "Bladesmith Apron" } do
			expect.equal(AvatarRules.hidesOnBack("Back", name), false, name)
		end
	end,

	["only the back: a sword on the waist or a hat never crosses ours"] = function()
		expect.equal(AvatarRules.hidesOnBack("Waist", "Katana"), false, "the waist")
		expect.equal(AvatarRules.hidesOnBack("Hat", "Sword Hat"), false, "a hat")
		expect.equal(AvatarRules.hidesOnBack("Unknown", "Sword"), false, "an old accessory not on the back")
	end,
}
