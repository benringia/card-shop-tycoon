--!strict
-- Footsteps (the owner 2026-11-11: "lets just add a footsteps sound effect on whatever the character is stepping on"):
-- which surface a floor material sounds like, when a walking character takes its next step, and which of a surface's
-- sounds plays (Util/FootstepRules on Config/Footsteps; FootstepController plays them)
local Footsteps = require("../src/shared/Config/Footsteps")
local FootstepRules = require("../src/shared/Util/FootstepRules")
local expect = require("./lib/expect")

return {
	["each floor material sounds like its surface; anything else like the default"] = function()
		expect.equal(FootstepRules.surface("Grass", Footsteps), "grass")
		expect.equal(FootstepRules.surface("LeafyGrass", Footsteps), "grass")
		expect.equal(FootstepRules.surface("Snow", Footsteps), "snow")
		expect.equal(FootstepRules.surface("Sand", Footsteps), "sand")
		expect.equal(FootstepRules.surface("WoodPlanks", Footsteps), "wood")
		expect.equal(FootstepRules.surface("Cobblestone", Footsteps), "stone")
		expect.equal(FootstepRules.surface("SmoothPlastic", Footsteps), Footsteps.DEFAULT, "a plain part: the default")
		expect.equal(FootstepRules.surface("Air", Footsteps), nil, "in the air: no step")
		expect.equal(FootstepRules.surface("Water", Footsteps), nil, "swimming: no step")
	end,

	["every surface has sounds, ids and a sensible volume"] = function()
		for name, surface in Footsteps.SURFACES do
			assert(#surface.ids >= 2, `{name}: a few sounds so steps vary`)
			for _, id in surface.ids do
				assert(string.match(id, "^rbxassetid://%d+$"), `{name}: {id}`)
			end
			assert(surface.volume > 0 and surface.volume <= 1, `{name}: volume`)
		end
		for material, surface in Footsteps.MATERIALS do
			assert(Footsteps.SURFACES[surface], `{material} -> {surface}: a surface that exists`)
		end
		assert(Footsteps.SURFACES[Footsteps.DEFAULT], "the default exists")
	end,

	["a step every stride of ground covered, none standing still"] = function()
		local stride = Footsteps.STRIDE
		local carry, stepped = FootstepRules.advance(0, 0, 1, stride, Footsteps.MIN_SPEED)
		expect.equal(stepped, false, "standing still: no step")
		expect.equal(carry, 0)
		local steps, held = 0, 0
		for _ = 1, 60 do -- one second at 16 studs a second
			local took
			held, took = FootstepRules.advance(held, 16, 1 / 60, stride, Footsteps.MIN_SPEED)
			steps += if took then 1 else 0
		end
		expect.equal(steps, math.floor(16 / stride), "a walk's steps a second")
		local _, slow = FootstepRules.advance(stride - 0.01, Footsteps.MIN_SPEED * 0.5, 1, stride, Footsteps.MIN_SPEED)
		expect.equal(slow, false, "shuffling below the walking speed: no step")
	end,

	["the next sound is never the last one again"] = function()
		expect.equal(FootstepRules.pick(3, 0, nil), 1)
		expect.equal(FootstepRules.pick(3, 0, 1), 2, "not the one just played")
		expect.equal(FootstepRules.pick(3, 0.99, 3), 2)
		expect.equal(FootstepRules.pick(1, 0.5, 1), 1, "only one: that one")
	end,
}
