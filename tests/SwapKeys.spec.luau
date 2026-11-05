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
	-- The owner (2026-11-05, option A): the fight's party strip shows every slot's card and what tapping it does
	["the party strip: each filled slot in order, with what its key would do"] = function()
		local slots = { [1] = "b3", [2] = "b1", [3] = "b2" }
		local tiles = SwapKeys.party(slots, 3, { "a:b3" }, FIGHTERS, true, 0)
		expect.equal(#tiles, 3)
		expect.equal(tiles[1].slot, 1)
		expect.equal(tiles[1].beastId, "b3")
		expect.equal(tiles[1].state, "swap")
		expect.equal(tiles[1].simId, "a:b3")
		expect.equal(tiles[2].state, "active")
		expect.equal(tiles[2].simId, "a:b1")
		expect.equal(tiles[3].state, "fainted", "b2 fainted in this fight")
		local cooling = SwapKeys.party(slots, 3, { "a:b3" }, FIGHTERS, true, 2.5)
		expect.equal(cooling[1].state, "cooling")
		expect.near(cooling[1].seconds :: number, 2.5, 1e-9)
		expect.isNil(cooling[2].seconds, "only a cooling tile counts down")
	end,

	["the party strip skips empty slots"] = function()
		local tiles = SwapKeys.party({ [2] = "b1" }, 3, {}, FIGHTERS, true, 0)
		expect.equal(#tiles, 1)
		expect.equal(tiles[1].slot, 2)
		expect.equal(#SwapKeys.party({}, 3, {}, {}, true, 0), 0)
	end,
	-- The owner (2026-11-05, option C): a fainted card lies face down with dizzy stars, one resting since an earlier fight
	-- with a Zzz
	["the party strip tells a card that fainted in this fight from one resting since an earlier fight"] = function()
		local tiles = SwapKeys.party({ [1] = "b2", [2] = "b9" }, 3, {}, FIGHTERS, true, 0)
		expect.equal(tiles[1].state, "fainted")
		expect.equal(tiles[2].state, "resting")
		expect.equal(SwapKeys.pick("b2", {}, FIGHTERS, true, 0), "resting", "a key still says it's resting")
	end,
}
