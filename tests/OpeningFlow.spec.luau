--!strict
-- The 3D pack opening's reveal state machine (UI project 3 spec section 4)
local OpeningFlow = require("../src/shared/Util/OpeningFlow")
local expect = require("./lib/expect")

local equal = expect.equal

return {
	["taps do nothing while the tear, the stacking or a big flip's spotlight plays"] = function()
		local s, action = OpeningFlow.tap(OpeningFlow.new(5), 0)
		equal(action, "Tear", "first tap tears")
		local _, busy = OpeningFlow.tap(s, 0.1)
		expect.isNil(busy, "ignored while tearing")
		s = OpeningFlow.done(s, 1) -- the tear finished: the cards stack up
		local _, stacking = OpeningFlow.tap(s, 1.5)
		expect.isNil(stacking, "ignored while stacking")
		s = OpeningFlow.done(s, 2)
		equal(s.phase, "Stacked", "stacked")
		s, action = OpeningFlow.tap(s, 3)
		equal(action, "Flip", "flip the first")
		equal(s.index, 1, "card 1")
		local _, flipping = OpeningFlow.tap(s, 3.2)
		expect.isNil(flipping, "ignored mid-flip")
		s = OpeningFlow.done(s, 3.4, 0.6)
		local _, locked = OpeningFlow.tap(s, 3.5)
		expect.isNil(locked, "spotlight lock")
		local after, ok = OpeningFlow.tap(s, 4.1)
		equal(ok, "Next", "after the lock")
		equal(after.phase, "Stowing", "stowing card 1")
	end,

	["Next stows the shown card, then flips the next one"] = function()
		local s = { phase = "Shown", index = 2, count = 5, lockedUntil = 0 }
		local action
		s, action = OpeningFlow.tap(s, 1)
		equal(action, "Next", "next")
		s = OpeningFlow.done(s, 1.2) -- stowed
		equal(s.phase, "Flipping", "flipping")
		equal(s.index, 3, "the next card")
		s = OpeningFlow.done(s, 1.5)
		equal(s.phase, "Shown", "shown")
	end,

	["the last shown card goes to the results; skip jumps there"] = function()
		local s, action = OpeningFlow.tap({ phase = "Shown", index = 5, count = 5, lockedUntil = 0 }, 1)
		equal(action, "Results", "last")
		equal(s.phase, "Results", "results")
		local _, more = OpeningFlow.tap(s, 2)
		expect.isNil(more, "taps on the results do nothing (Continue closes)")
		equal(OpeningFlow.skip(OpeningFlow.new(5)).phase, "Results", "skip")
	end,

	["a pack with no cards goes straight to the results after the tear"] = function()
		local s = OpeningFlow.done(OpeningFlow.done(select(1, OpeningFlow.tap(OpeningFlow.new(0), 0)), 1), 2)
		equal(s.phase, "Results", "nothing to flip")
	end,
}
