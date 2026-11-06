--!strict
local WeaponLookRules = require("../src/shared/Util/WeaponLookRules")
local Looks = require("../src/shared/Config/WeaponLooks")
local expect = require("./lib/expect")

return {
	["+0: the rarity's resting glow and no aura"] = function()
		local layers = WeaponLookRules.layers(Looks, "Common", 0, "C", "hand")
		expect.near(layers.edge, Looks.REST.Common, 1e-9)
		expect.equal(layers.aura, 0)
		expect.equal(layers.trailScale, 1)
		expect.equal(layers.burst, false)
		expect.equal(layers.awakened, false)
		expect.equal(layers.twinkle, false)
	end,

	["+1 to +3: brighter edges, never dimmer than the rarity's rest"] = function()
		expect.near(WeaponLookRules.layers(Looks, "Common", 3, "C", "hand").edge, Looks.LADDER.edge[3], 1e-9)
		expect.near(WeaponLookRules.layers(Looks, "Rare", 1, "C", "hand").edge, Looks.LADDER.edge[1], 1e-9)
		expect.near(WeaponLookRules.layers(Looks, "Legendary", 1, "C", "hand").edge, Looks.REST.Legendary, 1e-9)
		expect.near(WeaponLookRules.layers(Looks, "Common", 9, "C", "hand").edge, Looks.LADDER.edge[3], 1e-9, "kept after +3")
	end,

	["+4 to +6: the aura, the last rate kept after"] = function()
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 3, "C", "hand").aura, 0)
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 4, "C", "hand").aura, Looks.LADDER.auraRate[1])
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 6, "C", "hand").aura, Looks.LADDER.auraRate[3])
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 10, "C", "hand").aura, Looks.LADDER.auraRate[3])
	end,

	["+7 to +9: a bigger trail and a burst on hits; +10 Awakened"] = function()
		local seven = WeaponLookRules.layers(Looks, "Epic", 7, "C", "hand")
		expect.near(seven.trailScale, 1.2, 1e-9)
		expect.equal(seven.burst, true)
		expect.equal(seven.awakened, false)
		expect.near(WeaponLookRules.layers(Looks, "Epic", 9, "C", "hand").trailScale, 1.5, 1e-9)
		local ten = WeaponLookRules.layers(Looks, "Epic", 10, "C", "hand")
		expect.equal(ten.awakened, true)
		expect.near(ten.trailScale, 1.5, 1e-9)
	end,

	["Grade S twinkles"] = function()
		expect.equal(WeaponLookRules.layers(Looks, "Common", 0, "S", "hand").twinkle, true)
		expect.equal(WeaponLookRules.layers(Looks, "Common", 0, "A", "hand").twinkle, false)
	end,

	["on the back: fewer aura particles and no light"] = function()
		local hand = WeaponLookRules.layers(Looks, "Legendary", 6, "C", "hand")
		local back = WeaponLookRules.layers(Looks, "Legendary", 6, "C", "back")
		expect.equal(hand.light, true, "a Legendary lights up in hand")
		expect.equal(back.light, false)
		expect.near(back.aura, hand.aura * Looks.BACK.auraShare, 1e-9)
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 6, "C", "hand").light, false, "lights are Epic and Legendary only")
	end,

	["edges never glow past full, odd levels are clamped"] = function()
		local looks = table.clone(Looks) :: any
		looks.REST = { Common = 1.4 }
		expect.equal(WeaponLookRules.layers(looks, "Common", 0, "C", "hand").edge, 1)
		expect.equal(WeaponLookRules.layers(Looks, "Common", 99, "C", "hand").awakened, true)
		expect.equal(WeaponLookRules.layers(Looks, "Common", -3, "C", "hand").aura, 0)
		expect.equal(WeaponLookRules.layers(Looks, "Nope", 0, "C", "hand").edge, 0, "an unknown rarity rests dark")
	end,
}
