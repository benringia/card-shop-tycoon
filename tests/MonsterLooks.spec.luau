--!strict
-- The Wild monster models (spec 2026-11-01-wild-monster-models-design): each species drawn at its own height (elites
-- ELITE_SIZE times that), its bones moved by its own style once it has a model, and its glow (the golem's lava pulsing).
local wild = require("../src/shared/Config/Wild")
local frontier = require("../src/shared/Config/Frontier")
local party = require("../src/shared/Config/Party")
local MonsterLooks = require("../src/shared/Util/MonsterLooks")
local expect = require("./lib/expect")

return {
	["each wild species has its own height, elites 1.35x"] = function()
		local heights = { Mossling = 2.5, ["Puddle Crab"] = 2, ["Cave Bat"] = 3, ["Spark Beetle"] = 2.5, ["Ash Wolf"] = 4, ["Magma Golem"] = 6.5 }
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

	["bones move by species, bosses by their id, nothing without a model"] = function()
		expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, true), "Ash Wolf", "monster")
		expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, false), nil, "placeholder")
		expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", true), "meadowWarden", "boss")
		expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", false), nil, "boss placeholder")
	end,

	["glow: none, steady, or a pulse that stays in its range"] = function()
		expect.equal(MonsterLooks.glowStrength(nil, 3), nil, "no glow")
		expect.equal(MonsterLooks.glowStrength({ strength = 2 }, 3), 2, "steady")
		local pulse = { strength = 2, pulse = { low = 1.2, high = 3, seconds = 2.5 } }
		expect.near(MonsterLooks.glowStrength(pulse, 0) :: number, 1.2, 1e-9, "low at the start")
		expect.near(MonsterLooks.glowStrength(pulse, 1.25) :: number, 3, 1e-9, "high halfway")
		for step = 0, 50 do
			local value = MonsterLooks.glowStrength(pulse, step * 0.1) :: number
			assert(value >= 1.2 - 1e-9 and value <= 3 + 1e-9, "pulse out of range")
		end
	end,

	["every wild species has a height and the golem's lava pulses"] = function()
		for species, info in wild.SPECIES do
			local entry = info :: any
			assert(type(entry.height) == "number" and entry.height > 0, species .. " has no height")
			assert(entry.glow and entry.glow.strength > 0, species .. " has no glow")
		end
		assert((wild.SPECIES["Magma Golem"] :: any).glow.pulse, "the golem's lava doesn't pulse")
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
}
