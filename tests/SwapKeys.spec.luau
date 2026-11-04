--!strict
local SwapKeys = require("../src/shared/Util/SwapKeys")
local expect = require("./lib/expect")

local FIGHTERS = { { id = "a:b1", fainted = false }, { id = "a:b2", fainted = true } }

return {
	["a key brings in its own party slot's card, whatever order the reserves are in"] = function()
		local action, id = SwapKeys.pick("b3", { "a:b4", "a:b3" }, FIGHTERS, true, 0)
		expect.equal(action, "swap")
		expect.equal(id, "a:b3")
	end,

	["a key while swaps cool down says how long is left"] = function()
		local action, left = SwapKeys.pick("b3", { "a:b3" }, FIGHTERS, true, 4.2)
		expect.equal(action, "cooling")
		expect.near(left :: number, 4.2, 1e-9)
		expect.equal(SwapKeys.pick("b3", { "a:b3" }, FIGHTERS, true, 0.01), "swap", "ready within a frame")
		expect.equal(SwapKeys.pick("b3", { "a:b3" }, FIGHTERS, false, 4.2), "swap", "a wild call-in has no cooldown")
	end,

	["the card already fighting, a resting one, an empty slot"] = function()
		expect.equal(SwapKeys.pick("b1", { "a:b3" }, FIGHTERS, true, 0), "active")
		expect.equal(SwapKeys.pick("b2", { "a:b3" }, FIGHTERS, true, 0), "resting", "fainted in this fight")
		expect.equal(SwapKeys.pick("b9", { "a:b3" }, FIGHTERS, true, 0), "resting", "not in the fight: resting from before")
		expect.equal(SwapKeys.pick(nil, { "a:b3" }, FIGHTERS, true, 0), "none")
	end,
}
