--!strict
-- Hit feel (spec 2026-11-25-hit-feel-design; owner: "the hits feel weak and monsters just stand there", then felt a
-- test: "strong feels good", "stepping feels good now"): a monster's reaction to a hit, its curve, the clip freeze, a
-- wild monster's lunge and steps, and the cap on how far it drifts from its server spot
local HitFeel = require("../src/shared/Util/HitFeel")
local Config = require("../src/shared/Config/HitFeel")
local expect = require("./lib/expect")

local function near(a: number, b: number, message: string?)
	assert(math.abs(a - b) < 1e-6, `{message or "value"}: expected {b}, got {a}`)
end

local REACT = Config.REACT

return {
	["the felt numbers"] = function()
		near(REACT.knock, 1.1)
		near(REACT.bigKnock, 2.6)
		near(REACT.tilt, 15)
		near(REACT.bigTilt, 1.4)
		near(REACT.pop, 1.08)
		near(REACT.flash, 0.05)
		near(REACT.flashSeconds, 0.2)
		near(REACT.out, 0.05)
		near(REACT.back, 0.32)
		near(REACT.bigBack, 1.6)
		near(REACT.stop, 0.07)
		near(REACT.bigStop, 1.5)
		near(REACT.bossShare, 0.35)
		near(Config.STEP.gap[1], 1.6)
		near(Config.STEP.gap[2], 3.2)
		near(Config.STEP.radius, 2.2)
		near(Config.STEP.speed, 4)
		near(Config.STEP.turn, 0.3)
		near(Config.LUNGE.studs, 2.6)
		near(Config.MAX_DRIFT, 3)
	end,

	["a hit pushes the monster away from the hitter"] = function()
		local r = HitFeel.reaction(10, 0, 0, -5, 0, false, false, REACT)
		near(r.dx, 1, "away along +x")
		near(r.dz, 0)
		near(r.at, 10)
		near(r.knock, 1.1)
		near(r.tilt, math.rad(15))
		near(r.pop, 1.08)
		near(r.back, 0.32)
		near(r.stop, 0.07)
	end,

	["straight back when the hitter stands on it"] = function()
		local r = HitFeel.reaction(0, 3, 3, 3, 3, false, false, REACT)
		near(r.dx, 0)
		near(r.dz, 1)
		assert(r.dx == r.dx and r.dz == r.dz, "never NaN")
	end,

	["a big hit knocks further, leans more, comes back slower and freezes longer"] = function()
		local r = HitFeel.reaction(0, 0, 0, 0, -4, true, false, REACT)
		near(r.knock, 2.6)
		near(r.tilt, math.rad(15 * 1.4))
		near(r.back, 0.32 * 1.6)
		near(r.stop, 0.07 * 1.5)
		near(r.dz, 1)
	end,

	["a boss takes a share of the jolt and never pops, big hit or not"] = function()
		local r = HitFeel.reaction(0, 0, 0, -4, 0, true, true, REACT)
		near(r.knock, 2.6 * 0.35)
		near(r.tilt, math.rad(15 * 1.4) * 0.35)
		near(r.pop, 1, "no pop")
		local small = HitFeel.reaction(0, 0, 0, -4, 0, false, true, REACT)
		near(small.knock, 1.1 * 0.35)
		near(small.pop, 1)
	end,

	["the reaction's curve: out fast, back over its time, then gone"] = function()
		local r = HitFeel.reaction(100, 0, 0, -1, 0, false, false, REACT)
		near(HitFeel.amount(r, 100) :: number, 0, "at the hit")
		near(HitFeel.amount(r, 100 + REACT.out) :: number, 1, "full at out")
		local midway = HitFeel.amount(r, 100 + REACT.out + REACT.back / 2) :: number
		assert(midway > 0 and midway < 1, "on its way back")
		expect.equal(HitFeel.amount(r, 100 + REACT.out + REACT.back + 0.01), nil, "over")
	end,

	["a new hit replaces the reaction"] = function()
		local first = HitFeel.reaction(0, 0, 0, -1, 0, true, false, REACT)
		local second = HitFeel.reaction(0.1, 0, 0, -1, 0, false, false, REACT)
		near(HitFeel.amount(second, 0.1 + REACT.out) :: number, 1, "the new one at full")
		near(second.knock, 1.1, "its own size, not added to the first")
		assert(first.knock > second.knock)
	end,

	["its own clip freezes a moment"] = function()
		local r = HitFeel.reaction(5, 0, 0, -1, 0, false, false, REACT)
		expect.equal(HitFeel.frozen(r, 5.03), true)
		expect.equal(HitFeel.frozen(r, 5 + REACT.stop + 0.01), false)
	end,

	["the lunge into a strike: out, held, back, then over"] = function()
		local L = Config.LUNGE
		near(HitFeel.lunge(0, 1, L) :: number, 0, "starts at its spot")
		near(HitFeel.lunge(L.rise, 1, L) :: number, 1, "all the way out")
		near(HitFeel.lunge((L.rise + L.hold) / 2, 1, L) :: number, 1, "held")
		local back = HitFeel.lunge((L.hold + 1) / 2, 1, L) :: number
		assert(back > 0 and back < 1, "on its way back")
		expect.equal(HitFeel.lunge(1, 1, L), nil, "over at the clip's end")
		expect.equal(HitFeel.lunge(0.5, 0, L), nil, "no clip, no lunge")
	end,

	["the drift cap leaves small offsets and pulls big ones back"] = function()
		local x, z = HitFeel.clampDrift(1, 1, 3)
		near(x, 1)
		near(z, 1)
		x, z = HitFeel.clampDrift(0, -4.6, 3) -- a step 2 in front plus a 2.6-stud lunge
		near(x, 0)
		near(z, -3)
		x, z = HitFeel.clampDrift(3, 4, 3)
		near(math.sqrt(x * x + z * z), 3)
		near(x / z, 3 / 4, "same direction")
	end,

	["a wild monster's steps: calm, small, mostly facing the fight"] = function()
		local base = { gap = { 0.5, 1.4 }, after = 0.25, weights = { wander = 0.8, roar = 0.1, stomp = 0.1 }, wander = { radius = 5, front = 2, back = 1, speed = 9 }, roarVolume = 0.15, stompShake = 0.1 }
		local steps = HitFeel.stepIdle(base, Config.STEP)
		near(steps.gap[1], 1.6)
		near(steps.gap[2], 3.2)
		near(steps.wander.radius, 2.2)
		near(steps.wander.front, 2.2 * 0.4)
		near(steps.wander.back, 0.5)
		near(steps.wander.speed, 4)
		near(steps.weights.wander, 1)
		near(steps.weights.roar, 0)
		near(steps.after, 0.25, "the rest kept")
		near(base.wander.radius, 5, "the packs' own left alone")
	end,
}
