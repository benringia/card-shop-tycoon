--!strict
local KeyframeTiming = require("../src/shared/Util/KeyframeTiming")
local expect = require("./lib/expect")

local TIMES = { 0, 0.5, 1, 1.5 }

return {
	["a time between two keyframes blends them"] = function()
		local a, b, alpha = KeyframeTiming.between(TIMES, 0.75, true)
		expect.equal(a, 2, "from")
		expect.equal(b, 3, "to")
		expect.near(alpha, 0.5, 1e-9, "halfway")
	end,

	["on a keyframe it holds that keyframe"] = function()
		local a, b, alpha = KeyframeTiming.between(TIMES, 1, true)
		expect.equal(a, 3, "from")
		expect.near(alpha, 0, 1e-9, "no blend")
		local _, _, _ = b, nil, nil
	end,

	["a looping animation wraps round"] = function()
		local a, b, alpha = KeyframeTiming.between(TIMES, 1.5 + 0.75, true)
		expect.equal(a, 2, "wrapped from")
		expect.equal(b, 3, "wrapped to")
		expect.near(alpha, 0.5, 1e-9, "wrapped blend")
	end,

	["a one-shot animation holds its last keyframe"] = function()
		local a, b, alpha = KeyframeTiming.between(TIMES, 9, false)
		expect.equal(a, 4, "last")
		expect.equal(b, 4, "last")
		expect.near(alpha, 0, 1e-9, "held")
	end,

	["a single keyframe always holds"] = function()
		local a, b, alpha = KeyframeTiming.between({ 0 }, 3, true)
		expect.equal(a, 1, "from")
		expect.equal(b, 1, "to")
		expect.near(alpha, 0, 1e-9, "held")
	end,

	["walk and run weights follow the speed and always add up to one"] = function()
		local cfg = { WALK_FROM = 0.5, RUN_FROM = 10, RUN_FULL = 16 }
		for _, speed in { 0, 0.4, 3, 9.9, 12, 16, 40 } do
			local idle, walk, run = KeyframeTiming.weights(cfg, speed)
			expect.near(idle + walk + run, 1, 1e-9, `sum at {speed}`)
		end
		local idle = KeyframeTiming.weights(cfg, 0)
		expect.near(idle, 1, 1e-9, "standing is all idle")
		local _, walk = KeyframeTiming.weights(cfg, 5)
		expect.near(walk, 1, 1e-9, "walking pace is all walk")
		local _, _, run = KeyframeTiming.weights(cfg, 20)
		expect.near(run, 1, 1e-9, "fast is all run")
	end,

	["a one-shot clip blends in, holds, then blends out"] = function()
		expect.equal(KeyframeTiming.oneShotWeight(0, 1, 0.15), 0)
		expect.near(KeyframeTiming.oneShotWeight(0.075, 1, 0.15), 0.5, 1e-9)
		expect.equal(KeyframeTiming.oneShotWeight(0.15, 1, 0.15), 1)
		expect.equal(KeyframeTiming.oneShotWeight(0.5, 1, 0.15), 1)
		expect.near(KeyframeTiming.oneShotWeight(0.925, 1, 0.15), 0.5, 1e-9)
		expect.equal(KeyframeTiming.oneShotWeight(1, 1, 0.15), 0)
		expect.equal(KeyframeTiming.oneShotWeight(2, 1, 0.15), 0, "over")
		expect.equal(KeyframeTiming.oneShotWeight(-1, 1, 0.15), 0, "not started")
		expect.near(KeyframeTiming.oneShotWeight(0.1, 0.2, 0.15), 1, 1e-9, "a clip shorter than two blends peaks at its middle")
	end,
}
