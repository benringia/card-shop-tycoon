--!strict
-- How NPCs (customers, town walkers, shop workers) follow a path smoothly (owner 2026-11-06: "they are stuttering
-- while walking", "walking in place")
local WalkStep = require("../src/shared/Util/WalkStep")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local STEP = Customers.NPC_STEP

return {
	["a waypoint on the way counts as reached a little early, so the walk never stops between"] = function()
		expect.equal(WalkStep.reached(STEP.lookahead - 0.1, false, STEP), true)
		expect.equal(WalkStep.reached(STEP.lookahead + 0.1, false, STEP), false)
		assert(STEP.lookahead >= 1, "early enough to send the next step before it stops")
	end,

	["the walk's end is reached closely"] = function()
		expect.equal(WalkStep.reached(STEP.lookahead - 0.1, true, STEP), false, "not early at the end")
		expect.equal(WalkStep.reached(STEP.finish - 0.05, true, STEP), true)
	end,

	["trying to walk without getting anywhere is being stuck"] = function()
		expect.equal(WalkStep.stalled(0.1, STEP.stallSeconds, STEP), true, "walking in place")
		expect.equal(WalkStep.stalled(3, STEP.stallSeconds, STEP), false, "moving")
		expect.equal(WalkStep.stalled(0.1, STEP.stallSeconds * 0.5, STEP), false, "not long enough to tell")
		assert(STEP.stallSeconds <= 1.5, "a stuck walker gives up quickly")
	end,

	["a step may take twice its walk time plus some grace"] = function()
		expect.near(WalkStep.limit(12, 6, 2), 6, 1e-9)
		expect.near(WalkStep.limit(12, 0, 2), 26, 1e-9, "no speed: as if 1 stud a second")
	end,

	["the walk clip keeps pace with the feet"] = function()
		expect.near(WalkStep.clipSpeed(Customers.WALK_CLIP_PACE, Customers.WALK_CLIP_PACE), 1, 1e-9)
		expect.near(WalkStep.clipSpeed(Customers.WALKERS.walkSpeed, Customers.WALK_CLIP_PACE), 6 / 6.4, 1e-9)
		expect.equal(WalkStep.clipSpeed(100, Customers.WALK_CLIP_PACE), 2, "never a sprint")
		expect.equal(WalkStep.clipSpeed(0.1, Customers.WALK_CLIP_PACE), 0.5, "never a crawl")
	end,

	["NPCs use Roblox's own walk, not the old brisk one"] = function()
		expect.equal(Customers.WALK_ANIMATION, "rbxassetid://913402848")
	end,
}
