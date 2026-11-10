--!strict
-- The Frontier's effects (spec 2026-11-10-frontier-valley-design, plan Task 4): red eyes in the fog that fade as you
-- come close, lightning between its bounds, a tremor's shake. Nothing here hurts anyone.
local FrontierFxRules = require("../src/shared/Util/FrontierFxRules")
local valley = require("../src/shared/Config/FrontierValley")
local expect = require("./lib/expect")

local function lcg(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

return {
	["eyes vanish as you come close"] = function()
		local fade = { near = 30, far = 90 }
		expect.equal(FrontierFxRules.eyeAlpha(20, fade), 0, "close: gone")
		expect.equal(FrontierFxRules.eyeAlpha(30, fade), 0, "at near: gone")
		expect.near(FrontierFxRules.eyeAlpha(60, fade), 0.5, 1e-9, "halfway")
		expect.equal(FrontierFxRules.eyeAlpha(100, fade), 1, "far: seen")
	end,

	["lightning comes between its bounds"] = function()
		local rng = lcg(7)
		for _ = 1, 100 do
			local wait = FrontierFxRules.nextFlash(rng, { 8, 16 })
			assert(wait >= 8 and wait <= 16, `a flash after {wait} s`)
		end
	end,

	["a tremor's shake starts and ends still, never over its strength"] = function()
		expect.equal(FrontierFxRules.shake(0, 1.6, 0.35), 0, "at the start")
		expect.equal(FrontierFxRules.shake(1.6, 1.6, 0.35), 0, "at the end")
		expect.equal(FrontierFxRules.shake(3, 1.6, 0.35), 0, "after")
		for step = 1, 15 do
			local amount = FrontierFxRules.shake(step / 10, 1.6, 0.35)
			assert(amount > 0 and amount <= 0.35, `{amount} at {step / 10} s`)
		end
	end,

	["every Frontier effect stands in its area"] = function()
		local fx = (valley :: any).FX
		assert(fx, "FrontierValley.FX")
		expect.equal(fx.snow.zone, 1, "snow in Frostwood")
		expect.equal(fx.lightning.zone, 2, "lightning on Stormpeak")
		expect.equal(fx.tremor.zone, 3, "tremors in the Rift")
		expect.equal(fx.vortex.zone, 3, "the vortex over the Rift")
		assert(#fx.eyes >= 6, "a few pairs of eyes")
		for _, eye in fx.eyes do
			local WildValley = require("../src/shared/Util/WildValley")
			expect.equal(WildValley.zoneAt(valley, eye), 1, `eyes at {eye.x}, {eye.z} are in Frostwood`)
			local clear = WildValley.clearOf(eye, valley)
			assert(clear, `eyes at {eye.x}, {eye.z} sit on the trail, a portal or the camp`)
		end
		assert(fx.lightning.every[1] >= 4, "lightning isn't constant")
		assert(fx.tremor.shake <= 0.5, "a tremor is a small shake")
	end,
}
