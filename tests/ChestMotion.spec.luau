--!strict
-- The boss chests' motion (the owner 2026-11-11: "make the chest/chest opening more immersive", the storyboard's beats):
-- the chests dropping in one after another, a waiting chest's rattle, and the picked chest shaking harder and harder
-- before it bursts open (Util/ChestMotion, Config/BossChests BEATS)
local ChestMotion = require("../src/shared/Util/ChestMotion")
local BossChests = require("../src/shared/Config/BossChests")
local expect = require("./lib/expect")

local BEATS = BossChests.BEATS

return {
	["arrival: each chest falls from above in turn and lands to stay"] = function()
		local drop = BEATS.drop
		expect.equal(ChestMotion.dropHeight(0, 1, drop), drop.height, "the first starts high")
		expect.equal(ChestMotion.dropHeight(0, 2, drop), drop.height, "the second waits up there")
		local half = ChestMotion.dropHeight(drop.seconds / 2, 1, drop)
		assert(half > 0 and half < drop.height, "falling")
		assert(half > drop.height / 2, "slow at first, speeding up (it falls)")
		expect.equal(ChestMotion.dropHeight(drop.seconds, 1, drop), 0, "landed")
		expect.equal(ChestMotion.dropHeight(10, 3, drop), 0, "stays down")
		expect.equal(ChestMotion.landsAt(1, drop), drop.seconds)
		assert(ChestMotion.landsAt(2, drop) > ChestMotion.landsAt(1, drop), "one after another")
		assert(ChestMotion.landsAt(3, drop) < 1.5, "all down within the beat")
	end,

	["waiting: a rattle cracks the lid open and back, nothing between rattles"] = function()
		local rattle = BEATS.rattle
		expect.equal(ChestMotion.rattle(4, 5, rattle), 0, "before it")
		expect.equal(ChestMotion.rattle(5 + rattle.seconds + 0.01, 5, rattle), 0, "after it")
		local peak = ChestMotion.rattle(5 + rattle.seconds / 2, 5, rattle)
		assert(peak > 0.5 and peak <= 1, `a crack at its middle ({peak})`)
		assert(rattle.every[1] < rattle.every[2], "rattles come every few seconds, at random")
	end,

	["the pick: the chest shakes harder and faster until it bursts"] = function()
		local tension = BEATS.tension
		local function biggest(from: number, to: number): number
			local most = 0
			for i = 0, 200 do
				local t = from + (to - from) * i / 200
				most = math.max(most, math.abs(ChestMotion.tension(t, tension)))
			end
			return most
		end
		local early, late = biggest(0, tension.seconds * 0.25), biggest(tension.seconds * 0.75, tension.seconds)
		assert(early <= tension.shakeFrom * 1.5, `a little at first ({early})`)
		assert(late > early * 2, `much harder at the end ({early} -> {late})`)
		assert(late <= tension.shakeTo + 1e-9, "never past its limit")
		expect.equal(ChestMotion.tension(tension.seconds + 1, tension), 0, "still once it has burst")
	end,
}
