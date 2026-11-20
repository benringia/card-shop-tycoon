--!strict
local SwapKeys = require("../src/shared/Util/SwapKeys")
local expect = require("./lib/expect")

local FIGHTERS = { { id = "a:b1", fainted = false }, { id = "a:b2", fainted = true } }

return {
	-- owner 2026-11-12: "It still wouldn't let me unsummon my pet while in combat"
	["in a wild fight the card fighting unsummons, once the swap's cooldown is over"] = function()
		local action, id = SwapKeys.pick("b1", {}, FIGHTERS, true, 0, true)
		expect.equal(action, "unsummon")
		expect.equal(id, "a:b1")
		local cooling, seconds = SwapKeys.pick("b1", {}, FIGHTERS, true, 3, true)
		expect.equal(cooling, "cooling")
		expect.equal(seconds, 3)
		expect.equal(SwapKeys.pick("b1", {}, FIGHTERS, true, 0), "active", "a boss fight: it's fighting, nothing more")
	end,

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
	-- owner 2026-11-20: "in fights, should 1 and 3 mean left and right creature (matching the new carousel), retiring 2:
	-- YES". The creature fighting sits in the middle of the strip; 1 brings in the one on its left, 3 the one on its right
	["1 and 3 reach the creature left and right of the one fighting, round the party"] = function()
		local slots = { [1] = "b1", [2] = "b2", [3] = "b3" }
		expect.equal(SwapKeys.sideSlot(slots, 1, "left", 3), 3, "left of slot 1 wraps round to slot 3")
		expect.equal(SwapKeys.sideSlot(slots, 1, "right", 3), 2)
		expect.equal(SwapKeys.sideSlot(slots, 2, "left", 3), 1)
		expect.equal(SwapKeys.sideSlot(slots, 2, "right", 3), 3)
		expect.equal(SwapKeys.sideSlot(slots, 3, "right", 3), 1)
	end,

	["with two creatures both keys reach the other one; a lone creature answers either key"] = function()
		local two = { [1] = "b1", [3] = "b3" }
		expect.equal(SwapKeys.sideSlot(two, 1, "left", 3), 3)
		expect.equal(SwapKeys.sideSlot(two, 1, "right", 3), 3, "the empty slot is skipped")
		expect.equal(SwapKeys.sideSlot({ [2] = "b2" }, 2, "left", 3), 2, "unsummoned in a wild fight: it can come back")
		expect.equal(SwapKeys.sideSlot({ [2] = "b2" }, 2, "right", 3), 2)
		expect.isNil(SwapKeys.sideSlot({}, 1, "left", 3), "no cards")
	end,

	["the strip in carousel order: left, the one fighting, right, with the key that reaches each"] = function()
		local slots = { [1] = "b3", [2] = "b1", [3] = "b2" }
		local tiles = SwapKeys.party(slots, 3, { "a:b3" }, FIGHTERS, true, 0, 2)
		expect.equal(#tiles, 3)
		expect.equal(tiles[1].slot, 1, "left of the middle")
		expect.equal(tiles[1].key, "1")
		expect.equal(tiles[2].slot, 2, "the one fighting in the middle")
		expect.isNil(tiles[2].key, "no key: it's out")
		expect.equal(tiles[3].slot, 3)
		expect.equal(tiles[3].key, "3")
		local turned = SwapKeys.party(slots, 3, { "a:b3" }, FIGHTERS, true, 0, 1)
		expect.equal(turned[1].slot, 3, "the middle moved: slot 3 is on its left now")
		expect.equal(turned[2].slot, 1)
		expect.equal(turned[3].slot, 2)
	end,

	["the strip with two creatures or one: the key on the side it sits"] = function()
		local two = SwapKeys.party({ [1] = "b1", [3] = "b3" }, 3, { "a:b3" }, FIGHTERS, true, 0, 1)
		expect.equal(#two, 2)
		expect.equal(two[1].slot, 3, "slot 3 sits left of slot 1")
		expect.equal(two[1].key, "1")
		expect.isNil(two[2].key)
		local right = SwapKeys.party({ [1] = "b1", [2] = "b3" }, 3, { "a:b3" }, FIGHTERS, true, 0, 1)
		expect.equal(right[2].slot, 2)
		expect.equal(right[2].key, "3")
		local lone = SwapKeys.party({ [2] = "b1" }, 3, {}, FIGHTERS, true, 0, 2)
		expect.equal(lone[1].key, "1", "alone: either key, shown as 1")
		local old = SwapKeys.party({ [1] = "b1", [2] = "b2" }, 3, {}, FIGHTERS, true, 0)
		expect.equal(old[1].slot, 1, "no middle given: the party's own order")
		expect.isNil(old[1].key)
	end,

	-- The middle of the strip: the creature fighting, else the one last there, else the party's first card
	["the strip's middle: who fights, else who was last there, else the first card"] = function()
		local slots = { [1] = "b1", [2] = "b2", [3] = "b3" }
		expect.equal(SwapKeys.center(slots, 3, "a:b2", 1), 2, "the one fighting")
		expect.equal(SwapKeys.center(slots, 3, nil, 3), 3, "nobody out: where the middle was")
		expect.equal(SwapKeys.center(slots, 3, "a:b9", nil), 1, "not in the party: the first card")
		expect.equal(SwapKeys.center({ [2] = "b2" }, 3, nil, 1), 2, "the remembered slot is empty now")
		expect.equal(SwapKeys.center({}, 3, nil, nil), 1)
	end,
}
