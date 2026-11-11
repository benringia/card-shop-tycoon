--!strict
-- The town's aurora (the owner 2026-11-11: "better aurora for town", from the Creator Store; then "visible at any
-- time"): TheRisingTides' Aurora Borealis (4556126742) in place of our three curtains (Config/Scenery AURORA;
-- SceneryService builds it, day and night)
local Scenery = require("../src/shared/Config/Scenery")
local expect = require("./lib/expect")

return {
	["the aurora: the pack's five beams across the northern sky, high over the town"] = function()
		local aurora = Scenery.AURORA
		expect.equal(#aurora.BEAMS, 5)
		for index, beam in aurora.BEAMS do
			assert(string.match(beam.texture, "^rbxassetid://%d+$"), `beam {index}: a texture`)
			assert(beam.width > 100, `beam {index}: sky-sized`)
			assert(#beam.colors >= 2 and #beam.transparency >= 3, `beam {index}: its colours and fade`)
			expect.equal(beam.transparency[1][2], 1, `beam {index}: fades in at its end`)
			expect.equal(beam.transparency[#beam.transparency][2], 1, `beam {index}: and out at the other`)
		end
		assert(aurora.at.y >= 200, "well over the town")
		assert(aurora.at.z > 200, "to the north, over Frostpeak's side")
		assert(aurora.strength >= 1 and aurora.strength <= 2, "at least as bold as the pack, never a solid wall")
	end,
}
