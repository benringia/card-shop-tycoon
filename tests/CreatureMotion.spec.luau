--!strict
local CreatureMotion = require("../src/shared/Util/CreatureMotion")
local config = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

local motion = config.MOTION

return {
	["idle: breathing within 3%, no hop"] = function()
		for _, t in { 0, 0.4, 0.75, 1.5, 2.25, 2.9 } do
			local pose = CreatureMotion.getPose(motion, t, 0, 0, false)
			expect.equal(pose.offsetY, 0, `no hop at {t}`)
			assert(math.abs(pose.scaleY - 1) <= motion.BREATH_AMOUNT + 1e-9, `breath at {t}: {pose.scaleY}`)
		end
		local inhale = CreatureMotion.getPose(motion, motion.BREATH_SECONDS / 4, 0, 0, false)
		expect.near(inhale.scaleY, 1 + motion.BREATH_AMOUNT, 1e-9, "full breath in")
	end,

	["breathing keeps volume"] = function()
		local pose = CreatureMotion.getPose(motion, motion.BREATH_SECONDS / 4, 0, 0, false)
		expect.near(pose.scaleX * pose.scaleX * pose.scaleY, 1, 1e-9, "volume")
	end,

	["walking: hops between 0 and HOP_HEIGHT"] = function()
		for walked = 0, 10, 0.37 do
			local pose = CreatureMotion.getPose(motion, 1, 8, walked, false)
			assert(pose.offsetY >= 0 and pose.offsetY <= motion.HOP_HEIGHT + 1e-9, `hop {pose.offsetY} at {walked}`)
		end
		local mid = CreatureMotion.getPose(motion, 1, 8, motion.STEP_LENGTH / 2, false)
		expect.near(mid.offsetY, motion.HOP_HEIGHT, 1e-9, "top of the hop mid-step")
	end,

	["walking: waddle swaps side each step"] = function()
		local first = CreatureMotion.getPose(motion, 1, 8, motion.STEP_LENGTH * 0.5, false)
		local second = CreatureMotion.getPose(motion, 1, 8, motion.STEP_LENGTH * 1.5, false)
		assert(first.roll > 0 and second.roll < 0, `rolls {first.roll} then {second.roll}`)
	end,

	["walking: leans more with speed, capped"] = function()
		local slow = CreatureMotion.getPose(motion, 1, 3, 1, false)
		local fast = CreatureMotion.getPose(motion, 1, 100, 1, false)
		assert(slow.pitch > 0 and fast.pitch > slow.pitch, "leans forward more when faster")
		expect.near(fast.pitch, math.rad(motion.LEAN_DEGREES), 1e-9, "capped")
	end,

	["flyers hover and bob instead of hopping"] = function()
		local idle = CreatureMotion.getPose(motion, 0, 0, 0, true)
		expect.near(idle.offsetY, motion.HOVER_HEIGHT, 1e-9, "hover height")
		local moving = CreatureMotion.getPose(motion, 0.5, 8, 3, true)
		assert(math.abs(moving.offsetY - motion.HOVER_HEIGHT) <= motion.HOVER_BOB + 1e-9, "bob around hover height")
	end,
}
