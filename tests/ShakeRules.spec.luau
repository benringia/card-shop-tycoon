--!strict
local ShakeRules = require("../src/shared/Util/ShakeRules")
local expect = require("./lib/expect")

return {
	["shakes add up to at most 1"] = function()
		expect.near(ShakeRules.add(0.3, 0.4), 0.7, 1e-9)
		expect.equal(ShakeRules.add(0.8, 0.6), 1)
		expect.equal(ShakeRules.add(0.5, -1), 0.5, "a negative shake adds nothing")
	end,

	["a shake dies down over time"] = function()
		expect.near(ShakeRules.decay(1, 0.25, 2), 0.5, 1e-9)
		expect.equal(ShakeRules.decay(0.2, 1, 2), 0, "never below 0")
	end,

	["the camera moves by the shake squared"] = function()
		expect.near(ShakeRules.offset(0.5, 2), 0.5, 1e-9)
		expect.near(ShakeRules.offset(1, 2), 2, 1e-9)
		expect.equal(ShakeRules.offset(0, 2), 0)
	end,

	["a far hit shakes less, a very far one not at all"] = function()
		expect.equal(ShakeRules.falloff(0.8, 5, 10, 60), 0.8, "inside near: full")
		expect.near(ShakeRules.falloff(0.8, 35, 10, 60), 0.4, 1e-9, "half way: half")
		expect.equal(ShakeRules.falloff(0.8, 80, 10, 60), 0, "past far: none")
	end,
}
