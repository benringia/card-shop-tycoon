--!strict
-- The phone's creature and weapon pair (owner 2026-11-17: "make the party swipeable. move the party down beside the
-- weapon and add a swipe up/down o both. when a player long presses. it should display her pets/weapons at the top and
-- bottom so that player can choose", placement 2 of artifact GtT4bM87otu1aayFVANr7z: "yes placemen2")
local PairRules = require("../src/shared/Util/PairRules")
local CompactHud = require("../src/shared/Util/CompactHud")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

return {
	["a hold needs a still finger: anything that moves is a swipe on its way, so a slow swipe up is still the next"] = function()
		local PAIR = Party.BAR.PAIR
		assert(PAIR.still < PAIR.swipe, "a hold's wobble room is less than a swipe")
		assert(PAIR.hold > 0.2 and PAIR.hold < 0.6, "a hold is a moment, not a wait")
		assert(PAIR.visible % 2 == 1, "the column is the same height above and below")
	end,

	["a swipe: up for the next one, down for the one before, nothing when short or sideways"] = function()
		expect.equal(PairRules.swipeStep(0, -40, 24), 1, "up: the next")
		expect.equal(PairRules.swipeStep(3, 30, 24), -1, "down: the one before")
		expect.equal(PairRules.swipeStep(0, 10, 24), 0, "too short: a tap")
		expect.equal(PairRules.swipeStep(60, -30, 24), 0, "more sideways than up")
	end,

	["the next party creature: the filled slots in order, wrapping round"] = function()
		local slots = { [1] = "a", [3] = "c" }
		expect.equal(PairRules.cycle(slots, 1, 1, 3), 3, "slot 2 is empty: on to 3")
		expect.equal(PairRules.cycle(slots, 3, 1, 3), 1, "round to the first")
		expect.equal(PairRules.cycle(slots, 1, -1, 3), 3, "back round to the last")
		expect.equal(PairRules.cycle(slots, 2, 1, 3), 1, "from an empty slot: the first filled")
		expect.equal(PairRules.cycle({}, 1, 1, 3), nil, "an empty party: nothing")
		expect.equal(PairRules.cycle({ [2] = "b" }, 2, 1, 3), 2, "one creature: itself")
	end,

	["the count on its corner: which of how many, nothing with one or none"] = function()
		local slots = { [1] = "a", [3] = "c" }
		expect.equal(PairRules.count(slots, 3, 3), "2/2")
		expect.equal(PairRules.count({ [1] = "a", [2] = "b", [3] = "c" }, 1, 3), "1/3")
		expect.equal(PairRules.count({ [2] = "b" }, 2, 3), "", "one: no count")
		expect.equal(PairRules.count({}, 1, 3), "", "none: no count")
	end,

	["the pair sits on the right edge just above Roblox's jump button"] = function()
		local screen = { w = 750, h = 323 } -- an iPhone 17 Pro's HUD space
		local jump = CompactHud.jumpRect(screen.w, screen.h)
		local top, right = PairRules.spot(jump, 54, 16, 12)
		expect.equal(top, jump.y - 12 - 54, "12 px over the jump button")
		expect.equal(right, 16, "on the right margin")
		assert(top + 54 <= jump.y, "never on the jump button")
	end,

	["the hold column: the current in the middle, the rest above and below, five at most, wrapping round"] = function()
		local function rows(count: number, current: number): string
			local parts = {}
			for _, row in PairRules.wheel(count, current, 5) do
				table.insert(parts, `{row.offset}:{row.index}`)
			end
			return table.concat(parts, " ")
		end
		expect.equal(rows(3, 2), "-1:1 0:2 1:3", "a party of three: one above, one below")
		expect.equal(rows(3, 1), "-1:3 0:1 1:2", "wrapping round: the last above the first")
		expect.equal(rows(2, 1), "0:1 1:2", "two: the other below")
		expect.equal(rows(4, 1), "-1:4 0:1 1:2 2:3", "four: one above, two below")
		expect.equal(rows(8, 1), "-2:7 -1:8 0:1 1:2 2:3", "many: two above and two below, the rest a swipe away")
		expect.equal(rows(1, 1), "0:1", "one: just itself")
	end,

	["a finger on the column: the row under it, and whether it's past an end"] = function()
		expect.equal((PairRules.rowAt(0, 62, 2, 2)), 0, "on the button: the current")
		expect.equal((PairRules.rowAt(-70, 62, 2, 2)), -1, "a row up")
		expect.equal((PairRules.rowAt(120, 62, 2, 2)), 2, "two rows down")
		local row, beyond = PairRules.rowAt(-200, 62, 2, 2)
		expect.equal(row, -2, "held at the top row")
		expect.equal(beyond, -1, "past the top: it rolls on")
		row, beyond = PairRules.rowAt(40, 62, 1, 1)
		expect.equal(row, 1, "rounds to the nearest row")
		expect.equal(beyond, 0, "inside the column")
	end,
}
