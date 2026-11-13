--!strict
-- Reading your binder in the world (owner 2026-11-13: "Opening the binder should also show the character opening a
-- binder, so that other players know you are opening a binder", "like reading a book"; pose and binder only)
local BinderPoseRules = require("../src/shared/Util/BinderPoseRules")
local BinderPose = require("../src/shared/Config/BinderPose")
local expect = require("./lib/expect")

return {
	["the pose eases in as the binder opens and out as it closes"] = function()
		expect.equal(BinderPoseRules.weight(10, 10, 0.3, true), 0, "just opened")
		expect.equal(BinderPoseRules.weight(10, 10.3, 0.3, true), 1, "fully up")
		local half = BinderPoseRules.weight(10, 10.15, 0.3, true)
		assert(half > 0.3 and half < 0.7, `halfway: {half}`)
		expect.equal(BinderPoseRules.weight(10, 10, 0.3, false), 1, "just closed: still holding it")
		expect.equal(BinderPoseRules.weight(10, 11, 0.3, false), 0, "put away")
		expect.equal(BinderPoseRules.weight(10, 9, 0.3, true), 0, "a clock behind: never below 0")
	end,

	["the arms come forward to hold it and the head tips down, all scaled by the weight"] = function()
		local full = BinderPoseRules.angles(BinderPose.POSE, 1)
		expect.equal(full.shoulder, BinderPose.POSE.shoulder)
		expect.equal(full.elbow, BinderPose.POSE.elbow)
		expect.equal(full.neck, BinderPose.POSE.neck)
		local none = BinderPoseRules.angles(BinderPose.POSE, 0)
		expect.equal(none.shoulder, 0)
		expect.equal(none.inward, 0)
		local half = BinderPoseRules.angles(BinderPose.POSE, 0.5)
		expect.near(half.shoulder, BinderPose.POSE.shoulder / 2, 1e-9)
		expect.equal(BinderPoseRules.angles(BinderPose.POSE, 3).shoulder, BinderPose.POSE.shoulder, "clamped")
		local pose = BinderPose.POSE
		assert(pose.shoulder >= 15 and pose.shoulder <= 60, "upper arms a little forward, not up")
		local forearm = pose.shoulder + pose.elbow
		assert(forearm >= 80 and forearm <= 120, `forearms about level, holding it at the chest: {forearm}`)
		assert(BinderPose.POSE.neck > 0 and BinderPose.POSE.neck <= 25, "looking down a little")
	end,

	["you can show the binder in the world only outside a fight; putting it away always works"] = function()
		expect.equal(BinderPoseRules.canShow(true, false), true)
		expect.equal(BinderPoseRules.canShow(true, true), false, "not mid-fight")
		expect.equal(BinderPoseRules.canShow(false, true), true, "closing always goes through")
		expect.equal(BinderPoseRules.canShow("yes" :: any, false), false, "a bad message")
	end,

	["pages flip now and then, near the camera only"] = function()
		local flip = BinderPose.FLIP
		assert(flip.every[1] > 0 and flip.every[1] < flip.every[2], "a range of seconds between flips")
		assert(flip.seconds > 0 and flip.seconds < flip.every[1], "a flip ends before the next")
		assert(BinderPose.RANGE >= 40, "seen from across a shop")
		expect.near(BinderPoseRules.nextFlip(0, flip.every), flip.every[1], 1e-9)
		expect.near(BinderPoseRules.nextFlip(1, flip.every), flip.every[2], 1e-9)
	end,
}
