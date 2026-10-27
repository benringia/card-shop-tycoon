--!strict
local BeastFxRules = require("../src/shared/Util/BeastFxRules")
local BeastFx = require("../src/shared/Config/BeastFx")
local expect = require("./lib/expect")

local function counter(): () -> number
	local values = { 0, 1, 0.5, 0.25, 0.75 }
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
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

	["an arc runs exactly from one bone to the other"] = function()
		local from, to = { 0, 0, 0 }, { 10, 0, 0 }
		local path = BeastFxRules.arc(from, to, 6, 0.2, counter())
		expect.equal(#path, 7, "segments + 1 corners")
		expect.equal(path[1], from, "starts at the first bone")
		expect.equal(path[#path], to, "ends at the second bone")
	end,

	["an arc's corners stay within its jitter"] = function()
		local path = BeastFxRules.arc({ 0, 0, 0 }, { 10, 0, 0 }, 5, 0.2, counter())
		for index = 2, #path - 1 do
			local t = (index - 1) / 5
			local point = path[index]
			assert(math.abs(point[1] - 10 * t) <= 2 + 1e-9, `x at {index}`)
			assert(math.abs(point[2]) <= 2 + 1e-9 and math.abs(point[3]) <= 2 + 1e-9, `off the line at {index}`)
		end
	end,

	["every element has fire, ground flames, a light and lightning"] = function()
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local look = BeastFx.ELEMENTS[element]
			assert(look, `{element} has a look`)
			assert(#look.flames > 0 and #look.ground > 0, `{element} burns`)
			assert(look.arcs.every[1] > 0 and look.arcs.every[1] <= look.arcs.every[2], `{element} arc timing`)
			for _, flame in look.flames do
				assert(flame.lifetime[1] <= flame.lifetime[2], `{element} flame lifetime`)
			end
		end
	end,

	["grade S and A auras are lighter than a Legendary's, and A lighter than S"] = function()
		local legendary, s, a = BeastFx.TIERS.Legendary, BeastFx.TIERS.S, BeastFx.TIERS.A
		assert(legendary and s and a, "every tier is there")
		for _, field in { "bones", "rate", "size", "light" } do
			assert(legendary[field] > s[field], `S {field} isn't below Legendary`)
			assert(s[field] > a[field], `A {field} isn't below S`)
		end
		assert(legendary.ground and legendary.arcs and legendary.dust, "the Legendary aura is complete")
		assert(not s.ground and not a.ground and not a.arcs, "S and A keep it small")
	end,

	["a grade S Legendary's Divine aura is more than a Legendary's, with the extras"] = function()
		local divine, legendary = BeastFx.TIERS.Divine, BeastFx.TIERS.Legendary
		assert(divine, "the Divine tier is there")
		for _, field in { "bones", "rate", "size", "light" } do
			assert(divine[field] > legendary[field], `Divine {field} isn't above Legendary`)
		end
		assert(divine.arcSlow < legendary.arcSlow, "more lightning")
		assert(divine.ground and divine.arcs and divine.dust and divine.divine, "the whole aura plus the extras")
		assert(not legendary.divine, "plain Legendaries don't get the extras")
		local cfg = BeastFx.DIVINE
		assert(cfg.HALO.count >= 3 and cfg.ORBS.count >= 1 and cfg.EMBERS.max >= 1, "something to show")
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
