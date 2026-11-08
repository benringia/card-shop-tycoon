--!strict
-- The weapon glow (owner 2026-11-06: an aura like the reference picture, hybrid for performance): the inner glow, the
-- aura's density by upgrade, the +10 ribbons, the cheap creature-style sparkles, and which swords get the full aura
local WeaponLookRules = require("../src/shared/Util/WeaponLookRules")
local Looks = require("../src/shared/Config/WeaponLooks")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

return {
	["+0: the rarity's resting inner glow, no aura"] = function()
		local layers = WeaponLookRules.layers(Looks, "Common", 0, "C", "hand")
		expect.near(layers.edge, Looks.REST.Common, 1e-9)
		expect.equal(layers.aura, 0)
		expect.equal(layers.ribbons, false)
		expect.equal(layers.trailScale, 1)
		expect.equal(layers.burst, false)
		expect.equal(layers.twinkle, false)
	end,

	["the inner glow brightens with upgrades up to full at +10, never dimmer than the rarity's rest"] = function()
		local last = -1
		for level = 0, 10 do
			local edge = WeaponLookRules.layers(Looks, "Rare", level, "C", "hand").edge
			assert(edge >= last, `+{level} never dims`)
			last = edge
		end
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 10, "C", "hand").edge, 1)
		expect.near(WeaponLookRules.layers(Looks, "Legendary", 1, "C", "hand").edge, Looks.REST.Legendary, 1e-9, "its rest is above +1's step")
	end,

	["the aura starts at +4 (Epic and Legendary at +2) and is full from +7"] = function()
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 3, "C", "hand").aura, 0)
		local four = WeaponLookRules.layers(Looks, "Rare", 4, "C", "hand").aura
		assert(four > 0 and four < 1, "+4 starts thin")
		assert(WeaponLookRules.layers(Looks, "Rare", 6, "C", "hand").aura > four, "thicker each level")
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 7, "C", "hand").aura, 1)
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 10, "C", "hand").aura, 1)
		assert(WeaponLookRules.layers(Looks, "Epic", 2, "C", "hand").aura > 0, "an Epic's starts at +2")
		assert(WeaponLookRules.layers(Looks, "Legendary", 2, "C", "hand").aura > 0, "a Legendary's starts at +2")
		expect.equal(WeaponLookRules.layers(Looks, "Common", 2, "C", "hand").aura, 0)
		assert(
			WeaponLookRules.layers(Looks, "Epic", 5, "C", "hand").aura > WeaponLookRules.layers(Looks, "Rare", 5, "C", "hand").aura,
			"at the same level an Epic blazes more"
		)
	end,

	["+7 to +9: a bigger trail and a burst on hits; +10 Awakened adds the streaming ribbons"] = function()
		local seven = WeaponLookRules.layers(Looks, "Epic", 7, "C", "hand")
		expect.near(seven.trailScale, 1.2, 1e-9)
		expect.equal(seven.burst, true)
		expect.equal(seven.ribbons, false)
		expect.near(WeaponLookRules.layers(Looks, "Epic", 9, "C", "hand").trailScale, 1.5, 1e-9)
		local ten = WeaponLookRules.layers(Looks, "Epic", 10, "C", "hand")
		expect.equal(ten.ribbons, true)
		expect.equal(ten.awakened, true)
	end,

	["the cheap glow: sparkles by rarity, more with upgrades and Grade S (like the creatures')"] = function()
		local common = WeaponLookRules.layers(Looks, "Common", 0, "C", "hand").sparkles
		local legendary = WeaponLookRules.layers(Looks, "Legendary", 0, "C", "hand").sparkles
		assert(common > 0 and legendary > common, "rarer sparkles more")
		assert(WeaponLookRules.layers(Looks, "Common", 10, "C", "hand").sparkles > common, "upgrades add some")
		expect.equal(WeaponLookRules.layers(Looks, "Common", 0, "S", "hand").sparkles, common + Looks.SPARKLES.gradeS)
		expect.equal(WeaponLookRules.layers(Looks, "Common", 0, "S", "hand").twinkle, true)
	end,

	["on the back: half the aura and no light, except an Awakened weapon, which keeps both"] = function()
		local hand = WeaponLookRules.layers(Looks, "Legendary", 6, "C", "hand")
		local back = WeaponLookRules.layers(Looks, "Legendary", 6, "C", "back")
		expect.equal(hand.light, true, "a Legendary lights up in hand")
		expect.equal(back.light, false)
		expect.near(back.aura, hand.aura * Looks.BACK.auraShare, 1e-9)
		local awakened = WeaponLookRules.layers(Looks, "Epic", 10, "S", "back")
		expect.equal(awakened.aura, 1)
		expect.equal(awakened.light, true)
		expect.equal(WeaponLookRules.layers(Looks, "Rare", 10, "S", "back").light, false, "lights are Epic and Legendary only")
	end,

	["odd input: clamped levels, an unknown rarity rests dark"] = function()
		expect.equal(WeaponLookRules.layers(Looks, "Common", 99, "C", "hand").ribbons, true)
		expect.equal(WeaponLookRules.layers(Looks, "Common", -3, "C", "hand").aura, 0)
		expect.equal(WeaponLookRules.layers(Looks, "Nope", 0, "C", "hand").edge, 0)
	end,

	["the full aura goes on your own sword and the nearest few in range; the rest get the cheap glow"] = function()
		local full = WeaponLookRules.fullAuras({
			{ key = "me", distance = 500, mine = true },
			{ key = "near", distance = 10, mine = false },
			{ key = "mid", distance = 30, mine = false },
			{ key = "close", distance = 5, mine = false },
			{ key = "four", distance = 40, mine = false },
			{ key = "far", distance = 900, mine = false },
		}, 3, 60)
		expect.equal(full.me, true, "your own always blazes, however far the camera is")
		expect.equal(full.close, true)
		expect.equal(full.near, true)
		expect.equal(full.mid, true)
		expect.equal(full.four, nil, "only the nearest 3")
		expect.equal(full.far, nil, "out of range")
		local none = WeaponLookRules.fullAuras({}, 3, 60)
		expect.equal(next(none), nil)
	end,

	["a new drop's light column: everyone near the winner sees it, the winner has the cinematic instead"] = function()
		expect.equal(WeaponLookRules.seesBeacon(40, Looks.BEACON.range, false), true)
		expect.equal(WeaponLookRules.seesBeacon(Looks.BEACON.range + 1, Looks.BEACON.range, false), false, "too far")
		expect.equal(WeaponLookRules.seesBeacon(0, Looks.BEACON.range, true), false, "the winner")
		assert(Looks.BEACON.height > 10 and Looks.BEACON.seconds > Looks.BEACON.fadeIn + Looks.BEACON.fadeOut)
	end,

	["the budget's numbers are set"] = function()
		assert(Looks.BUDGET.nearest >= 1 and Looks.BUDGET.range > 0 and Looks.BUDGET.every > 0)
	end,

	-- Owner 2026-11-08 (free VFX packs, picked in game): Ember weapons blaze with the Euphoric pack's fire, Tide weapons
	-- with its water, Bloom weapons glow with the Yona pack's aura in green ("apply this glow to all green weapons");
	-- Volt, Shade and the Prism Blade keep our flames
	["Ember, Tide and Bloom weapons wear the pack auras; the rest keep our flames"] = function()
		expect.equal(WeaponLookRules.auraStyle(Looks, "Ember", false), "Ember")
		expect.equal(WeaponLookRules.auraStyle(Looks, "Tide", false), "Tide")
		expect.equal(WeaponLookRules.auraStyle(Looks, "Bloom", false), "Bloom")
		for _, element in { "Volt", "Shade" } do
			expect.equal(WeaponLookRules.auraStyle(Looks, element, false), nil, element)
		end
		expect.equal(WeaponLookRules.auraStyle(Looks, nil, false), nil, "the Steel Sword")
		expect.equal(WeaponLookRules.auraStyle(Looks, nil, true), nil, "the Prism Blade")
	end,

	["the element auras' textures are effect textures and they burn"] = function()
		for element, aura in Looks.ELEMENT_AURA do
			assert(#aura.emitters >= 1, element)
			for index, spec in aura.emitters do
				local id = (AttackFx.TEXTURES :: any)[spec.texture]
				expect.equal(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{element} {index}: {spec.texture}`)
				assert(spec.rate > 0 and spec.lifetime[1] > 0 and #spec.size >= 2, `{element} {index}`)
			end
		end
	end,

	-- Owner 2026-11-08: "tone it down for low grades, then gradually to its max glow" (the green glow; on top of the
	-- upgrade ladder's thickening)
	["a Bloom weapon's glow is toned down at low grades and full at Grade S"] = function()
		local c = WeaponLookRules.auraGrade(Looks, "Bloom", "C")
		local b = WeaponLookRules.auraGrade(Looks, "Bloom", "B")
		local a = WeaponLookRules.auraGrade(Looks, "Bloom", "A")
		assert(c > 0 and c < b and b < a and a < 1, `C {c} < B {b} < A {a} < S`)
		expect.equal(WeaponLookRules.auraGrade(Looks, "Bloom", "S"), 1)
		expect.equal(WeaponLookRules.auraGrade(Looks, "Ember", "C"), 1, "the fire isn't graded")
		expect.equal(WeaponLookRules.auraGrade(Looks, nil, "C"), 1, "our flames aren't graded")
	end,
}
