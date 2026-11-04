--!strict
local SummonMotion = require("../src/shared/Util/SummonMotion")
local expect = require("./lib/expect")

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
