--!strict
-- The Wild bosses' moments (spec 2026-11-01-wild-bosses-arenas-design): a roar at the fight's intro, the Brood Queen's
-- egg sac flaring on each heal, the Colossus's vents on its enrage. Late arrivals see the state, never a replay.
local BossMoments = require("../src/shared/Util/BossMoments")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

-- The bosses with a model of their own: the Wild's three and the Frontier's (spec 2026-11-10-frontier-valley-design)
local MODELLED = { meadowWarden = true, caveBroodQueen = true, emberColossus = true, frostTyrant = true, stormSovereign = true, riftDevourer = true }

return {
	["the intro roar comes once, at its moment"] = function()
		expect.near(BossMoments.roarIn(100, 100, 1) :: number, 1, 1e-9, "just spawned")
		expect.near(BossMoments.roarIn(100, 100.4, 1) :: number, 0.6, 1e-9, "streamed in early")
		expect.equal(BossMoments.roarIn(100, 103, 1), nil, "joined after the roar")
		expect.equal(BossMoments.roarIn(nil, 100, 1), nil, "no spawn time")
	end,

	["a heal flares when the count rises, never on first sight"] = function()
		expect.equal(BossMoments.flares(nil, 2), false, "first sight mid-fight")
		expect.equal(BossMoments.flares(2, 2), false, "no change")
		expect.equal(BossMoments.flares(2, 3), true, "healed")
		expect.equal(BossMoments.flares(0, nil), false, "attribute cleared")
	end,

	["moment effects need their bones"] = function()
		local moment = { bones = { "Fx_Vent_0", "Fx_Vent_1" } }
		expect.equal(BossMoments.anchors(moment, { Fx_Vent_0 = true }), nil, "a bone missing")
		expect.equal(#(BossMoments.anchors(moment, { Fx_Vent_0 = true, Fx_Vent_1 = true }) :: { string }), 2, "all there")
		expect.equal(BossMoments.anchors(nil, {}), nil, "no moment")
	end,

	["only the modelled bosses have moments, each with a roar and known effects"] = function()
		for id, boss in Bosses.BOSSES do
			local moments = (boss :: any).moments
			expect.equal(moments ~= nil, MODELLED[id] == true, id)
			if moments then
				assert(string.match(moments.roar, "^rbxassetid://%d+$"), id .. " has no roar sound")
				for _, kind in { moments.heal and moments.heal.fx, moments.enrage and moments.enrage.burst, moments.enrage and moments.enrage.lasting } do
					assert(kind == nil or (Bosses :: any).MOMENT_FX[kind], id .. ": unknown effect " .. tostring(kind))
				end
			end
		end
		local queen = (Bosses.BOSSES.caveBroodQueen :: any).moments
		local colossus = (Bosses.BOSSES.emberColossus :: any).moments
		expect.equal(queen.heal.bones[1], "Fx_Sac", "the flare comes from the egg sac")
		expect.equal(#colossus.enrage.bones, 3, "three vents")
		assert((Bosses :: any).ROAR_VOLUME > 0, "the roar is heard")
	end,

	-- Her screech (a hiss and screech sound) came out far louder than the other roars at the same volume (the user)
	["the Brood Queen's screech plays quieter than the other roars"] = function()
		local queen = (Bosses.BOSSES.caveBroodQueen :: any).moments
		assert(queen.roarVolume and queen.roarVolume < (Bosses :: any).ROAR_VOLUME, "her screech plays at the roars' volume")
		assert(queen.roarVolume > 0, "her screech is silent")
	end,

	-- Fx_Sac sits at the egg sac's centre and the sac is opaque, so the sparkles would fade before they leave it: they
	-- draw toward the camera by more than the sac's radius (0.31 of her height, rig_cavebroodqueen.py)
	["the Brood Queen's flare draws in front of her egg sac"] = function()
		local flare = (Bosses :: any).MOMENT_FX.broodFlare
		local queen = Bosses.BOSSES.caveBroodQueen :: any
		assert(flare.zOffset and flare.zOffset > 0.31 * queen.height, "the sac hides the flare")
	end,
}
