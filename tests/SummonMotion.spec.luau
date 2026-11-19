--!strict
local SummonMotion = require("../src/shared/Util/SummonMotion")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

local FX = Party.SUMMON_FX

return {
	["a summon pops in from nothing, overshoots a little, then settles at full size"] = function()
		expect.near(SummonMotion.popScale(0, 0.4), 0.05, 1e-9, "starts tiny (never zero: a model can't scale to 0)")
		expect.equal(SummonMotion.popScale(0.4, 0.4), 1, "full size at the end")
		expect.equal(SummonMotion.popScale(1, 0.4), 1, "stays there")
		local peak = 0
		for i = 1, 40 do
			peak = math.max(peak, SummonMotion.popScale(i * 0.01, 0.4))
		end
		expect.equal(peak > 1.04 and peak < 1.25, true, `overshoots a little (peak {peak})`)
	end,

	-- Owner 2026-11-20: "can we add a better/immersive summon and unsummon effects". Your card flies from you to the
	-- spot, a circle spins up under it, the card turns into a pillar of light and the creature bursts out of it
	["a summon's beats: the card lands, the circle winds up, then the creature bursts out; quick enough for a swap"] = function()
		local beats = SummonMotion.beats(FX)
		expect.equal(beats.land, FX.card.fly, "the card lands after its flight")
		expect.near(beats.burst, FX.card.fly + FX.windup, 1e-9, "the circle winds up, then the burst")
		expect.near(beats.done, beats.burst + FX.pop, 1e-9, "then the pop")
		assert(beats.land > 0 and beats.land < beats.burst and beats.burst < beats.done)
		assert(beats.done <= 1.1, "a swap in a fight can't wait long")
		assert(beats.done < FX.window, "over before a summon stops counting as fresh")
		-- the card is thrown: the creature appears a few steps in front of you, not on top of you
		assert(FX.ahead >= 4 and FX.ahead <= 8, "a few steps ahead")
		assert(FX.aside >= 0 and FX.aside < FX.ahead)
	end,

	["the creature stays a speck until the burst, then pops out of the light"] = function()
		local beats = SummonMotion.beats(FX)
		expect.near(SummonMotion.summonScale(0, FX), 0.05, 1e-9)
		expect.near(SummonMotion.summonScale(beats.burst - 0.01, FX), 0.05, 1e-9, "still hidden in the circle")
		assert(SummonMotion.summonScale(beats.burst + FX.pop * 0.5, FX) > 0.5, "popping")
		expect.equal(SummonMotion.summonScale(beats.done, FX), 1)
		expect.equal(SummonMotion.summonScale(beats.done + 3, FX), 1)
	end,

	["the card flies in an arc: on the line at both ends, highest in the middle"] = function()
		expect.equal(SummonMotion.arcLift(0, 3), 0)
		expect.equal(SummonMotion.arcLift(1, 3), 0)
		expect.equal(SummonMotion.arcLift(0.5, 3), 3)
		assert(SummonMotion.arcLift(0.25, 3) > 0 and SummonMotion.arcLift(0.25, 3) < 3)
		expect.equal(SummonMotion.arcLift(-1, 3), 0, "never under the line")
		expect.equal(SummonMotion.arcLift(2, 3), 0)
	end,

	["a rarer card's summon is bigger: taller light, more rings, a shake from Epic, a sky beam for a Legendary"] = function()
		local order = { "Common", "Rare", "Very Rare", "Epic", "Legendary" } -- Config/Rarities, lowest first
		local last
		for _, rarity in order do
			local tier = SummonMotion.tier(FX, rarity)
			assert(FX.BY_RARITY[rarity], `{rarity} has its own summon`)
			if last then
				assert(tier.scale >= last.scale and tier.pillar >= last.pillar and tier.rings >= last.rings, `{rarity}: never smaller than the rarity before`)
			end
			last = tier
		end
		local common, epic, legendary = SummonMotion.tier(FX, "Common"), SummonMotion.tier(FX, "Epic"), SummonMotion.tier(FX, "Legendary")
		expect.equal(common.shake, 0, "a Common's is gentle")
		expect.equal(common.beam, false)
		assert(epic.shake > 0 and epic.beam == false, "an Epic's shakes the ground a little")
		assert(legendary.shake > epic.shake and legendary.beam == true, "a Legendary's tears the sky")
		assert(legendary.scale > common.scale * 1.4, "and is clearly bigger")
		assert(legendary.shake <= 0.4, "but never a boss's slam")
		expect.equal(SummonMotion.tier(FX, nil), common, "no rarity: a Common's")
		expect.equal(SummonMotion.tier(FX, "Mythic"), common)
	end,

	-- ...and back: the creature turns to light and shrinks, becomes its card and flies back into you
	["an unsummon's beats: its card leaves before the creature is gone, and it's all quick"] = function()
		local leave = SummonMotion.leaveBeats(FX)
		expect.equal(leave.done, FX.unsummon, "the server keeps the marker this long (PartyService.Dismiss)")
		assert(leave.card > 0 and leave.card < leave.done, "the card forms while the creature is still shrinking")
		assert(leave.done <= 0.8, "never slow")
		assert(FX.leave.fly > 0 and FX.leave.fly <= 0.5)
	end,

	["an unsummon shrinks away to almost nothing"] = function()
		expect.equal(SummonMotion.shrinkScale(0, 0.45), 1)
		expect.near(SummonMotion.shrinkScale(0.45, 0.45), 0.05, 1e-9)
		expect.equal(SummonMotion.shrinkScale(0.2, 0.45) < 1, true)
	end,

	["only a fresh summon shows its effect (not one streaming in later)"] = function()
		expect.equal(SummonMotion.fresh(100, 100.8, 1.5), true)
		expect.equal(SummonMotion.fresh(100, 102, 1.5), false, "streamed in later")
		expect.equal(SummonMotion.fresh(nil, 100, 1.5), false, "no stamp")
		expect.equal(SummonMotion.fresh(100, 99.5, 1.5), true, "a clock a little behind the server's still counts")
	end,

	["a faint tips the creature over, all the way after the tip time"] = function()
		expect.equal(SummonMotion.faintRoll(0, 0.3, 1.4), 0)
		expect.near(SummonMotion.faintRoll(0.3, 0.3, 1.4), 1.4, 1e-9)
		expect.near(SummonMotion.faintRoll(5, 0.3, 1.4), 1.4, 1e-9)
		local half = SummonMotion.faintRoll(0.15, 0.3, 1.4)
		expect.equal(half > 0 and half < 1.4, true)
	end,
}
