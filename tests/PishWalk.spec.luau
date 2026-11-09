--!strict
-- Pish's walk (spec 2026-11-09-tutorial-pish-design 14; owner 2026-11-10: "he look like he's shaking so fast while
-- walking"): a small dog's quick but unhurried steps, about 2 leg cycles a second strolling. The procedural walk
-- (Util/PetAnimator) takes one leg cycle per stride, PET_ANIM.STRIDE x his size x his style's stride.
local Party = require("../src/shared/Config/Party")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

local function cyclesPerSecond(speed: number): number
	local size = Pish.HEIGHT / Party.CREATURE_HEIGHT
	local style = Party.CREATURE_STYLE.Pish
	local stride = Party.PET_ANIM.STRIDE * size * (style.stride or 1)
	return speed / stride
end

return {
	["strolling, about two leg cycles a second"] = function()
		local walk = cyclesPerSecond(Pish.TOWN.speed)
		assert(walk >= 1.5 and walk <= 2.2, `strolling: {walk} leg cycles a second (want 1.5-2.2)`)
	end,

	["trotting after you, quick but never a blur"] = function()
		local trot = cyclesPerSecond(Pish.TOWN.trotSpeed)
		assert(trot <= 3.5, `trotting: {trot} leg cycles a second (want at most 3.5)`)
		assert(Pish.TOWN.trotSpeed > Pish.TOWN.speed, "the trot is faster than the stroll")
	end,

	["a soft bob, not a shake"] = function()
		local bounce = Party.CREATURE_STYLE.Pish.bounce
		expect.equal(bounce <= 0.4, true, `bounce {bounce} (at most 0.4)`)
	end,
}
