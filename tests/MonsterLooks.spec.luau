--!strict
-- The Wild monster models (spec 2026-11-01-wild-monster-models-design): each species drawn at its own height (elites
-- ELITE_SIZE times that), its bones moved by its own style once it has a model, a steady glow and effects near the
-- camera.
local wild = require("../src/shared/Config/Wild")
local frontier = require("../src/shared/Config/Frontier")
local party = require("../src/shared/Config/Party")
local MonsterLooks = require("../src/shared/Util/MonsterLooks")
local expect = require("./lib/expect")

return {
	["each wild species has its own height, elites 1.35x"] = function()
		local heights = { Mossling = 3.5, ["Puddle Crab"] = 3, ["Cave Bat"] = 3, ["Spark Beetle"] = 2.5, ["Ash Wolf"] = 4, ["Magma Golem"] = 6.5 }
		for species, height in heights do
			expect.near(MonsterLooks.height(wild, species, false), height, 1e-9, species)
			expect.near(MonsterLooks.height(wild, species, true), height * wild.ELITE_SIZE, 1e-9, species .. " elite")
		end
	end,

	["a species without a height keeps the world's monster height"] = function()
		expect.near(MonsterLooks.height(frontier, "Frost Wisp", false), frontier.MONSTER_HEIGHT, 1e-9, "Frontier species")
	end,

	["a boss is sized by its scale as before"] = function()
		expect.near(MonsterLooks.height(wild, "Mossling", false, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "boss")
		expect.near(MonsterLooks.height(wild, "Mossling", true, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "elite flag ignored")
	end,

	["the Wild bosses are huge (size B), the final boss still the biggest"] = function()
		local bosses = require("../src/shared/Config/Bosses").BOSSES
		local expected = { meadowWarden = 17, caveBroodQueen = 12, emberColossus = 17 }
		for id, height in expected do
			local boss = (bosses :: any)[id]
			expect.near(MonsterLooks.height(wild, boss.name, false, boss.scale, boss.height), height, 1e-9, id)
		end
		local hydra = (bosses :: any).prismHydra
		local hydraHeight = MonsterLooks.height(frontier, hydra.name, false, hydra.scale, hydra.height)
		expect.near(hydraHeight, frontier.MONSTER_HEIGHT * 7, 1e-9, "the Hydra as before")
		for id, height in expected do
			assert(height < hydraHeight, id .. " outgrows the final boss")
		end
	end,

	["bosses without a height keep their scale (Frontier bosses unchanged)"] = function()
		local bosses = require("../src/shared/Config/Bosses").BOSSES
		for _, id in { "frostTyrant", "stormSovereign", "riftDevourer" } do
			local boss = (bosses :: any)[id]
			expect.equal(boss.height, nil, id)
			expect.near(MonsterLooks.height(frontier, boss.name, false, boss.scale, nil), frontier.MONSTER_HEIGHT * boss.scale, 1e-9, id)
		end
	end,

	["fighters stand clear of the big bosses and inside the fence"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		for _, id in { "meadowWarden", "caveBroodQueen", "emberColossus" } do
			local boss = (Bosses.BOSSES :: any)[id]
			assert(boss.ringRadius and boss.ringRadius > Bosses.RING_RADIUS, id .. " needs more room than the default ring")
			assert(boss.ringRadius <= Bosses.ARENA_RADIUS - 8, id .. "'s fighters would stand at the fence")
			assert(boss.introShot and boss.introShot.back > Bosses.INTRO_SHOT.back, id .. " needs a wider intro shot")
		end
	end,

	["bones move by species, bosses by their id, nothing without a model"] = function()
		expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, true), "Ash Wolf", "monster")
		expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, false), nil, "placeholder")
		expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", true), "meadowWarden", "boss")
		expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", false), nil, "boss placeholder")
	end,

	-- The extras go off on a struggling device (Util/Extras, the frame watchdog): no sparks or smoke then
	["effects run only near the camera with the extras on"] = function()
		expect.equal(MonsterLooks.effectsOn(30, 60, true), true, "near")
		expect.equal(MonsterLooks.effectsOn(60, 60, true), true, "at the edge")
		expect.equal(MonsterLooks.effectsOn(61, 60, true), false, "far")
		expect.equal(MonsterLooks.effectsOn(30, 60, false), false, "extras off")
	end,

	-- A SurfaceAppearance whose EmissiveStrength keeps changing costs about 6.6 ms of render CPU a frame, even one golem
	-- near the camera (measured 2026-11-01), so glows hold one strength
	["every wild species has a height and a steady glow"] = function()
		for species, info in wild.SPECIES do
			local entry = info :: any
			assert(type(entry.height) == "number" and entry.height > 0, species .. " has no height")
			assert(entry.glow and entry.glow.strength > 0, species .. " has no glow")
			for key in entry.glow do
				assert(key == "strength", species .. "'s glow has " .. key .. ": glows don't animate")
			end
		end
	end,

	["every wild species moves in its own style with known fidgets"] = function()
		local known = {}
		for _, list in { party.PET_ANIM.FIDGETS, party.PET_ANIM.BODY_FIDGETS, party.PET_ANIM.TITAN_FIDGETS } do
			for _, kind in list do
				known[kind] = true
			end
		end
		for species in wild.SPECIES do
			local style = (party.CREATURE_STYLE :: any)[species]
			assert(style and style.fidgets, species .. " has no style")
			for _, kind in style.fidgets do
				assert(known[kind], species .. ": unknown fidget " .. kind)
			end
		end
		expect.equal((party.SIGNATURE :: any)["Ash Wolf"].fidget, "wildroar", "the wolf roars")
		expect.equal((party.SIGNATURE :: any)["Magma Golem"].fidget, "stomp", "the golem stomps")
	end,

	["the beetle sparks at its pincers and the wolf smokes at its tail"] = function()
		local beetle = (wild.SPECIES["Spark Beetle"] :: any).fx
		local wolf = (wild.SPECIES["Ash Wolf"] :: any).fx
		expect.equal(beetle.kind, "sparks", "beetle")
		expect.equal(#beetle.bones, 2, "both pincers")
		expect.equal(wolf.kind, "smoke", "wolf")
		assert(wild.FX_RANGE > 0, "effects have a range")
		for _, kind in { "sparks", "smoke" } do
			local look = (wild :: any).FX[kind]
			assert(look and look.rate > 0 and look.lifetime[1] > 0, kind .. " has no emitter numbers")
		end
	end,
}
