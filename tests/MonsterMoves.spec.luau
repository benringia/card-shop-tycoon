--!strict
local MonsterMoves = require("../src/shared/Util/MonsterMoves")
local expect = require("./lib/expect")

local CFG = { CHARGE_GRACE = 0.3, HIT_GRACE = 0.15 }
local BOSS = { windup = 0.6, strike = 0.5, specialWindup = 1.4, specialRelease = 0.8 }

local function play(state: MonsterMoves.State, event: any, now: number, lengths: any?): MonsterMoves.Play?
	return MonsterMoves.decide(state, event, now, lengths or BOSS, CFG)
end

return {
	["a charge winds up over its lead and holds for the strike"] = function()
		local move = play(MonsterMoves.new(), { type = "charge", seconds = 0.6 }, 0)
		assert(move, "a wind-up")
		expect.equal(move.clip, "windup")
		expect.near(move.speed, 1, 1e-9)
		expect.near(move.hold, 0.3, 1e-9)
	end,

	["an attack chains the strike onto the wind-up"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "charge", seconds = 0.6 }, 0)
		local move = play(state, { type = "attack" }, 0.6)
		assert(move, "a strike")
		expect.equal(move.clip, "strike")
		expect.equal(move.speed, 1)
		expect.equal(move.hold, 0)
	end,

	["one strike at a time"] = function()
		local state = MonsterMoves.new()
		assert(play(state, { type = "attack" }, 0), "the first hit strikes")
		expect.equal(play(state, { type = "attack" }, 0), nil, "a second target hit the same moment")
		expect.equal(play(state, { type = "attack" }, 0.3), nil, "mid strike")
		local later = play(state, { type = "attack" }, 0.55)
		assert(later, "once the strike is over")
		expect.equal(later.clip, "strike")
	end,

	["a wind-up doesn't restart while one is showing"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "charge", seconds = 0.6 }, 0)
		expect.equal(play(state, { type = "telegraph", kind = "quick", seconds = 0.5 }, 0.2), nil)
	end,

	["a quick hit's warning winds up and its hit strikes, dodged or not"] = function()
		local state = MonsterMoves.new()
		local windup = play(state, { type = "telegraph", kind = "quick", seconds = 0.5 }, 0)
		assert(windup, "a wind-up")
		expect.equal(windup.clip, "windup")
		expect.near(windup.speed, 1.2, 1e-9, "the 0.6 s wind-up over the 0.5 s warning")
		expect.near(windup.hold, 0.45, 1e-9, "waits through the hit grace too")
		local strike = play(state, { type = "attack", kind = "Quick", dodged = true }, 0.65)
		assert(strike, "a strike")
		expect.equal(strike.clip, "strike")
	end,

	["a ring plays the special wind-up over its warning"] = function()
		local move = play(MonsterMoves.new(), { type = "ring", kind = "slam", seconds = 1.4 }, 0)
		assert(move, "a special wind-up")
		expect.equal(move.clip, "specialWindup")
		expect.near(move.speed, 1, 1e-9)
		expect.near(move.hold, 0.45, 1e-9)
		local fast = play(MonsterMoves.new(), { type = "ring", kind = "slam", seconds = 0.7 }, 0)
		assert(fast, "a special wind-up")
		expect.near(fast.speed, 2, 1e-9)
	end,

	["a ring cuts in over a wind-up or a strike"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "attack" }, 0)
		local move = play(state, { type = "ring", kind = "slam", seconds = 1.4 }, 0.1)
		assert(move, "the special wins")
		expect.equal(move.clip, "specialWindup")
	end,

	["nothing interrupts the special"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "ring", kind = "slam", seconds = 1.4 }, 0)
		expect.equal(play(state, { type = "charge", seconds = 0.6 }, 0.5), nil)
		expect.equal(play(state, { type = "attack" }, 0.6), nil, "a creature hit lands, the body stays in its wind-up")
		expect.equal(play(state, { type = "telegraph", kind = "quick", seconds = 0.5 }, 0.7), nil)
		expect.equal(play(state, { type = "ring", kind = "slam", seconds = 1.4 }, 0), nil, "a second ring in the same burst")
	end,

	["the ring's hit releases once"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "ring", kind = "slam", seconds = 1.4 }, 0)
		local release = play(state, { type = "attack", kind = "Slam" }, 1.55)
		assert(release, "a release")
		expect.equal(release.clip, "specialRelease")
		expect.equal(release.speed, 1)
		expect.equal(play(state, { type = "attack", kind = "Slam", dodged = true }, 1.55), nil, "the other player's ring")
		expect.equal(play(state, { type = "attack" }, 1.9), nil, "mid release")
		assert(play(state, { type = "attack" }, 2.4), "after it")
	end,

	["a swipe ring releases the same way"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "ring", kind = "swipe", seconds = 1.3 }, 0)
		local release = play(state, { type = "attack", kind = "Swipe" }, 1.45)
		assert(release, "a release")
		expect.equal(release.clip, "specialRelease")
	end,

	["the Frost Tyrant's ice spikes release the same way"] = function()
		local state = MonsterMoves.new()
		play(state, { type = "ring", kind = "spikes", seconds = 1.1 }, 0)
		local release = play(state, { type = "attack", kind = "Spikes" }, 1.25)
		assert(release, "a release")
		expect.equal(release.clip, "specialRelease")
	end,

	["a body without a clip plays nothing for it"] = function()
		local wild = { windup = 0.6, strike = 0.5 }
		expect.equal(play(MonsterMoves.new(), { type = "ring", kind = "slam", seconds = 1.4 }, 0, wild), nil)
		expect.equal(play(MonsterMoves.new(), { type = "attack", kind = "Slam" }, 0, wild), nil)
		expect.equal(play(MonsterMoves.new(), { type = "charge", seconds = 0.6 }, 0, {}), nil)
		expect.equal(play(MonsterMoves.new(), { type = "attack" }, 0, {}), nil)
		assert(play(MonsterMoves.new(), { type = "attack" }, 0, wild), "a wild monster strikes")
	end,

	["speeds stay sensible for odd warnings"] = function()
		local zero = play(MonsterMoves.new(), { type = "ring", kind = "slam", seconds = 0 }, 0)
		assert(zero, "a special wind-up")
		expect.equal(zero.speed, 4)
		local slow = play(MonsterMoves.new(), { type = "charge", seconds = 10 }, 0)
		assert(slow, "a wind-up")
		expect.equal(slow.speed, 0.25)
		local missing = play(MonsterMoves.new(), { type = "charge" }, 0)
		assert(missing, "a wind-up")
		expect.equal(missing.speed, 4)
	end,
}
