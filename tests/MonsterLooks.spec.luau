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
		local world = table.clone(frontier) :: any
		world.SPECIES = { Nameless = { element = "Tide", hp = 1, atk = 1, spd = 1, shape = "slime" } }
		expect.near(MonsterLooks.height(world, "Nameless", false), frontier.MONSTER_HEIGHT, 1e-9, "a species with no height")
	end,

	-- The Frontier valley (spec 2026-11-10-frontier-valley-design): its Meshy monsters are 30% over their Wild
	-- counterparts' heights
	["each Frontier species stands 30% over its Wild counterpart"] = function()
		local pairs = { ["Frost Wisp"] = "Mossling", ["Shade Lynx"] = "Ash Wolf", ["Storm Hawk"] = "Cave Bat", ["Rift Horror"] = "Spark Beetle", ["Prism Crab"] = "Puddle Crab", ["Lava Brute"] = "Magma Golem" }
		for species, counterpart in pairs do
			local ratio = MonsterLooks.height(frontier, species, false) / MonsterLooks.height(wild, counterpart, false)
			assert(ratio >= 1.25 and ratio <= 1.35, `{species}: {ratio}x {counterpart}`)
		end
	end,

	["a boss is sized by its scale as before"] = function()
		expect.near(MonsterLooks.height(wild, "Mossling", false, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "boss")
		expect.near(MonsterLooks.height(wild, "Mossling", true, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "elite flag ignored")
	end,

	["the Wild bosses are huge (size B), the final boss still the biggest"] = function()
		local bosses = require("../src/shared/Config/Bosses").BOSSES
		local expected = { meadowWarden = 17, caveBroodQueen = 16, emberColossus = 17 }
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

	-- On the lava field's dark basalt the Colossus's dark plates blended in (the user): its lava glows brighter than its
	-- saved mask's 2.5 (set once, steady) and a warm light on it lights the ground round it
	["the Colossus stands out of the dark lava field"] = function()
		local colossus = (require("../src/shared/Config/Bosses").BOSSES :: any).emberColossus
		assert(colossus.glow and colossus.glow.strength > 2.5, "its lava glows no brighter than its saved mask")
		for key in colossus.glow do
			assert(key == "strength", "glows don't animate: " .. key)
		end
		local light = colossus.light
		assert(light and light.brightness > 0 and light.range >= 20 and #light.color == 3, "no light on it")
	end,

	["bosses without a height keep their scale"] = function()
		local bosses = require("../src/shared/Config/Bosses").BOSSES
		for id, boss in bosses :: any do
			if boss.height == nil then
				expect.near(MonsterLooks.height(frontier, boss.name, false, boss.scale, nil), frontier.MONSTER_HEIGHT * boss.scale, 1e-9, id)
			end
		end
	end,

	["the Frontier bosses stand as tall as the Wild's (their Meshy models)"] = function()
		local bosses = require("../src/shared/Config/Bosses").BOSSES :: any
		for _, id in { "frostTyrant", "stormSovereign", "riftDevourer" } do
			assert(bosses[id].height >= 15 and bosses[id].height <= 20, `{id}: {bosses[id].height} studs`)
			assert(bosses[id].ringRadius >= 15, `{id}: fighters stand clear of its body`)
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

	-- A boss's model downloaded only when its fight began (its mesh alone took about 8 s in Studio, its textures after
	-- that), so its intro showed an empty ring: a place's boss and monster models download in the background, bosses
	-- first in ladder order
	["a place preloads its bosses' models first, then its monsters'"] = function()
		local bosses = require("../src/shared/Config/Bosses")
		local order = MonsterLooks.preloadOrder(wild, bosses, "Wild")
		expect.equal(order[1], "meadowWarden", "the first boss")
		expect.equal(order[2], "caveBroodQueen", "the second")
		expect.equal(order[3], "emberColossus", "the third")
		local seen = {}
		for _, name in order do
			assert(not seen[name], name .. " twice")
			seen[name] = true
		end
		for species in wild.SPECIES do
			assert(seen[species], species .. " is not preloaded")
		end
		expect.equal(seen.frostTyrant, nil, "the Frontier's bosses load in the Frontier")
		local there = MonsterLooks.preloadOrder(frontier, bosses, "Frontier")
		expect.equal(there[1], "frostTyrant", "the Frontier's first boss")
		expect.equal(table.find(there, "meadowWarden"), nil, "no Wild boss there")
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

	-- The Wild bosses (spec 2026-11-01-wild-bosses-arenas-design): styled by boss id; only the Warden has a random
	-- signature (the Brood Queen's flare and the Colossus's vents come from the fight)
	["the Wild bosses move in their own styles, only the Warden slams at random"] = function()
		local known = {}
		for _, list in { party.PET_ANIM.FIDGETS, party.PET_ANIM.BODY_FIDGETS, party.PET_ANIM.TITAN_FIDGETS } do
			for _, kind in list do
				known[kind] = true
			end
		end
		for _, id in { "meadowWarden", "caveBroodQueen", "emberColossus" } do
			local style = (party.CREATURE_STYLE :: any)[id]
			assert(style and style.fidgets, id .. " has no style")
			for _, kind in style.fidgets do
				assert(known[kind], id .. ": unknown fidget " .. kind)
			end
		end
		expect.equal((party.SIGNATURE :: any).meadowWarden.fidget, "rootslam", "the Warden slams its roots")
		expect.equal((party.SIGNATURE :: any).caveBroodQueen, nil, "a random flare would read as a heal")
		expect.equal((party.SIGNATURE :: any).emberColossus, nil, "its vents come with the enrage")
		-- Its stubby legs join a low belly: the rig holds clean up to about 17 degrees of swing (LEG_SWING 28 x 0.6)
		local colossus = (party.CREATURE_STYLE :: any).emberColossus
		assert(colossus.legSwing and colossus.legSwing <= 0.6, "the Colossus plods with short swings")
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
