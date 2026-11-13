--!strict
local BeastFxRules = require("../src/shared/Util/BeastFxRules")
local BeastFx = require("../src/shared/Config/BeastFx")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

-- A layer's particles a second at full strength, summed over its layers with this texture
local function rateOf(layers: { any }, texture: string, color: { number }?): number
	local total = 0
	for _, layer in layers do
		local sameColor = color == nil or (typeof(layer.color) == "table" and layer.color[1] == color[1] and layer.color[2] == color[2] and layer.color[3] == color[3])
		if layer.texture == texture and sameColor then
			total += layer.rate
		end
	end
	return total
end

return {
	["spread picks the far ends of the body before the middle"] = function()
		local points = { { 0, 0, 0 }, { 10, 0, 0 }, { -10, 0, 0 }, { 0.5, 0, 0 }, { 0, 6, 0 } }
		local picked = BeastFxRules.spread(points, 3)
		expect.equal(#picked, 3, "three picked")
		local chosen: { [number]: boolean } = {}
		for _, index in picked do
			chosen[index] = true
		end
		assert(chosen[2] and chosen[3] and chosen[5], "the three ends")
	end,

	["spread never picks a point twice or more than there are"] = function()
		local points = { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 } }
		local picked = BeastFxRules.spread(points, 9)
		expect.equal(#picked, 3, "capped at the points there are")
		local seen: { [number]: boolean } = {}
		for _, index in picked do
			assert(not seen[index], `picked {index} twice`)
			seen[index] = true
		end
		expect.equal(#BeastFxRules.spread({}, 4), 0, "no points, none picked")
	end,

	["side bones burn in pairs: a picked ear brings the other ear"] = function()
		expect.equal(BeastFxRules.mirrorName("Ear_Left_0"), "Ear_Right_0", "left to right")
		expect.equal(BeastFxRules.mirrorName("1_Right_Limb_2"), "1_Left_Limb_2", "right to left")
		expect.equal(BeastFxRules.mirrorName("Tail_2"), nil, "middle bones have no mirror")
		local names = { "Head_0", "Ear_Left_0", "Ear_Right_0", "Tail_1", "0_Left_Limb_2" }
		local out = BeastFxRules.withMirrors(names, { 2, 4, 3, 5 })
		local has: { [number]: boolean } = {}
		for _, index in out do
			assert(not has[index], "an index twice")
			has[index] = true
		end
		assert(has[2] and has[3], "both ears")
		assert(has[4], "the tail")
		assert(has[5] and #out == 4, "a side bone without a mirror stays alone")
	end,

	-- Owner 2026-11-13 ("finalize all" the pet glows and auras): the store packs' effects on the bones, like the weapons'
	-- (Config/WeaponLooks ELEMENT_AURA): no Roblox built-in fire, no drawn lightning
	["every element wears the store packs: body, ground, halo and orb layers, and a light"] = function()
		for _, element in ELEMENTS do
			local look = BeastFx.ELEMENTS[element]
			assert(look, `{element} has a look`)
			assert(#look.layers > 0 and #look.ground > 0 and #look.halo > 0 and #look.orb > 0, `{element} has every layer`)
			for _, group in { look.layers, look.ground, look.halo, look.orb } do
				for _, layer in group do
					assert((AttackFx.TEXTURES :: any)[layer.texture], `{element}: {layer.texture} is a pack texture`)
					assert(layer.rate > 0, `{element}: {layer.texture} emits`)
					assert(layer.lifetime[1] <= layer.lifetime[2], `{element}: {layer.texture} lifetime`)
				end
			end
			assert(look.light.brightness > 0 and look.light.range > 0, `{element} glows`)
			expect.equal((look :: any).arcs, nil, `{element}: no drawn lightning`)
		end
	end,

	["Ember burns thin, Volt reads bright with crackling bolts, Shade keeps its dark smoke"] = function()
		local ember, tide = BeastFx.ELEMENTS.Ember, BeastFx.ELEMENTS.Tide
		assert(rateOf(ember.layers, "fireAura") > 0 and rateOf(tide.layers, "waterAura") > 0, "Euphoric fire and water")
		-- the first test drowned Solarion in fire: small flames, no more of them than the weapon blade's own aura
		assert(rateOf(ember.layers, "fireAura") <= 60, "Ember's fire is thin")
		for _, layer in ember.layers do
			if layer.texture == "fireAura" then
				assert(layer.size[1][2] <= 0.7, "Ember's flames are small")
			end
		end
		local volt = BeastFx.ELEMENTS.Volt
		assert(rateOf(volt.layers, "lightningGrow") > 0, "Volt crackles with the pack's bolts")
		expect.equal(rateOf(volt.layers, "auraSmoke", { 0, 0, 0 }), 0, "no dark smoke swallowing Volt's yellow")
		assert(rateOf(volt.layers, "auraSmoke") > 0, "Volt's bright smoke")
		assert(rateOf(BeastFx.ELEMENTS.Shade.layers, "auraSmoke", { 0, 0, 0 }) > 0, "Shade's dark smoke")
		assert(rateOf(BeastFx.ELEMENTS.Bloom.layers, "auraSmoke") > 0, "Bloom's green smoke")
	end,

	["grade S and A auras are lighter than a Legendary's, and A lighter than S"] = function()
		local legendary, s, a = BeastFx.TIERS.Legendary, BeastFx.TIERS.S, BeastFx.TIERS.A
		assert(legendary and s and a, "every tier is there")
		for _, field in { "bones", "rate", "size", "light" } do
			assert(legendary[field] > s[field], `S {field} isn't below Legendary`)
			assert(s[field] > a[field], `A {field} isn't below S`)
		end
		assert(legendary.ground and legendary.dust, "the Legendary aura is complete")
		assert(not s.ground and not a.ground, "S and A keep it small")
	end,

	["a grade S Legendary's Divine aura is more than a Legendary's, with the extras"] = function()
		local divine, legendary = BeastFx.TIERS.Divine, BeastFx.TIERS.Legendary
		assert(divine, "the Divine tier is there")
		for _, field in { "bones", "rate", "size", "light" } do
			assert(divine[field] > legendary[field], `Divine {field} isn't above Legendary`)
		end
		assert(divine.ground and divine.dust and divine.divine, "the whole aura plus the extras")
		assert(not legendary.divine, "plain Legendaries don't get the extras")
		local cfg = BeastFx.DIVINE
		assert(cfg.HALO.count >= 3 and cfg.ORBS.count >= 1 and cfg.EMBERS.max >= 1, "something to show")
	end,

	-- Owner 2026-11-13: "pets that glows alot on boss battles specially on full party I think will be heavy", picked
	-- "Light touch" for other players' effects in boss fights, "make the performance better without affecting flexing
	-- too much"
	["your own creature's aura is always whole; another's is whole outside a boss fight"] = function()
		local legendary = BeastFx.TIERS.Legendary
		for _, shown in { BeastFxRules.budget(legendary, BeastFx.BUDGET, true, true, false), BeastFxRules.budget(legendary, BeastFx.BUDGET, false, false, false) } do
			expect.equal(shown.rate, 1)
			expect.equal(shown.ground, true)
			expect.equal(shown.light, true)
			expect.equal(shown.dust, true)
		end
		local s = BeastFxRules.budget(BeastFx.TIERS.S, BeastFx.BUDGET, true, false, false)
		expect.equal(s.ground, false, "a tier without ground flames gets none")
		expect.equal(s.dust, false)
		expect.equal(s.embers, false, "no embers without the Divine tier")
		expect.equal(BeastFxRules.budget(BeastFx.TIERS.Divine, BeastFx.BUDGET, true, false, false).embers, true)
	end,

	["another player's creature in a boss fight: a light touch that still shows off"] = function()
		local divine = BeastFxRules.budget(BeastFx.TIERS.Divine, BeastFx.BUDGET, false, true, false)
		assert(divine.rate > 0.2 and divine.rate < 1, "fewer particles, never none (flex kept)")
		expect.equal(divine.ground, false, "no ground flames")
		expect.equal(divine.light, false, "no light of its own")
		expect.equal(divine.dust, false)
		expect.equal(divine.embers, false, "no embers left on the ground")
		expect.equal(divine.halo, true, "a grade S Legendary keeps its halo and orbs")
	end,

	["low graphics or a struggling frame rate steps every aura down, yours too"] = function()
		local mine = BeastFxRules.budget(BeastFx.TIERS.Legendary, BeastFx.BUDGET, true, false, true)
		assert(mine.rate > 0 and mine.rate < 1, "thinner")
		expect.equal(mine.ground, false)
		expect.equal(mine.dust, false)
		expect.equal(mine.light, true, "your own keeps its light")
		local both = BeastFxRules.budget(BeastFx.TIERS.Legendary, BeastFx.BUDGET, false, true, true)
		expect.near(both.rate, BeastFx.BUDGET.others.rate * BeastFx.BUDGET.low.rate, 1e-9, "both cuts")
		expect.equal(BeastFxRules.budget(BeastFx.TIERS.Divine, BeastFx.BUDGET, true, false, true).halo, true, "the halo stays")
	end,

	-- Owner 2026-11-13: "add them only for grade S commons and rares. grade A/S very rares too"
	["which copies glow: Commons and Rares at S, Very Rares and Epics at A and S, every Legendary"] = function()
		for _, rarity in { "Common", "Rare" } do
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "S"), "S", `{rarity} S`)
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "A"), nil, `{rarity} A stays plain`)
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "B"), nil)
		end
		for _, rarity in { "Very Rare", "Epic" } do
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "S"), "S", `{rarity} S`)
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "A"), "A", `{rarity} A`)
			expect.equal(BeastFxRules.tier(BeastFx, rarity, "C"), nil)
		end
		expect.equal(BeastFxRules.tier(BeastFx, "Legendary", "S"), "Divine")
		expect.equal(BeastFxRules.tier(BeastFx, "Legendary", "C"), "Legendary")
		expect.equal(BeastFxRules.tier(BeastFx, "Legendary", nil), "Legendary", "no grade yet: still a Legendary")
		expect.equal(BeastFxRules.tier(BeastFx, "Common", nil), nil)
		expect.equal(BeastFxRules.tier(BeastFx, "Mythic", "S"), nil, "an unknown rarity")
	end,

	-- A grade S Common (about 2 studs tall) drew its aura so small it barely showed (Studio 2026-11-13)
	["small creatures' auras are drawn no smaller than MIN_SCALE"] = function()
		local s = BeastFx.TIERS.S
		expect.near(BeastFxRules.scale(BeastFx, 0.7, s), BeastFx.MIN_SCALE * s.size, 1e-9, "a Common is lifted")
		expect.near(BeastFxRules.scale(BeastFx, 3, s), 3 * s.size, 1e-9, "a big creature keeps its own size")
		assert(BeastFx.MIN_SCALE >= 0.8 and BeastFx.MIN_SCALE <= 1, "the floor")
	end,

	["ring spaces its points evenly round the circle"] = function()
		local points = BeastFxRules.ring(4, 2, 0)
		expect.equal(#points, 4, "four points")
		for _, point in points do
			expect.near(math.sqrt(point[1] ^ 2 + point[2] ^ 2), 2, 1e-9, "on the circle")
		end
		expect.near(points[1][1], 2, 1e-9, "starts at the angle")
		expect.near(points[2][2], 2, 1e-9, "a quarter turn on")
		local turned = BeastFxRules.ring(4, 2, math.pi / 2)
		expect.near(turned[1][2], 2, 1e-9, "turning the angle turns the ring")
	end,

	["orbit keeps orbs apart and brings each round in one lap"] = function()
		local a = BeastFxRules.orbit(1, 3, 0, 6, 5, 2, 0)
		local b = BeastFxRules.orbit(2, 3, 0, 6, 5, 2, 0)
		expect.near(math.sqrt(a[1] ^ 2 + a[3] ^ 2), 5, 1e-9, "on the circle")
		expect.near(a[2], 2, 1e-9, "at its height without a bob")
		local apart = math.sqrt((a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2)
		expect.near(apart, 5 * math.sqrt(3), 1e-9, "a third of a turn apart")
		local lap = BeastFxRules.orbit(1, 3, 6, 6, 5, 2, 0)
		expect.near(lap[1], a[1], 1e-9, "back after one lap")
		expect.near(lap[3], a[3], 1e-9, "back after one lap")
		for time = 0, 6, 0.5 do
			local bobbing = BeastFxRules.orbit(1, 3, time, 6, 5, 2, 0.3)
			assert(math.abs(bobbing[2] - 2) <= 0.3 + 1e-9, "bobs within its range")
		end
	end,
}
