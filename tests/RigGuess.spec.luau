--!strict
local RigGuess = require("../src/shared/Util/RigGuess")
local expect = require("./lib/expect")

type Bone = RigGuess.Bone

local function bone(name: string, parent: number, x: number, y: number, z: number): Bone
	return { name = name, parent = parent, x = x, y = y, z = z }
end

-- A four-legged rig in the Ultra pack's style: a middle chain to the head, a tail, two-bone ears, three-bone legs

local function dog(): { Bone }
	return {
		bone("Root.M", 0, 0, 0.5, 0), -- 1
		bone("Root.M.001", 1, 0, 0.55, -0.2), -- 2
		bone("Root.M.002", 2, 0, 0.6, -0.4), -- 3
		bone("Root.M.003", 3, 0, 0.75, -0.5), -- 4
		bone("Root.M.004", 4, 0, 0.85, -0.6), -- 5
		bone("Root.M.005", 5, 0, 0.9, -0.75), -- 6
		bone("Root.M.006", 1, 0, 0.55, 0.3), -- 7
		bone("Root.M.007", 7, 0, 0.6, 0.5), -- 8
		bone("Leg.L", 3, -0.2, 0.45, -0.4), -- 9
		bone("Leg.L.001", 9, -0.2, 0.2, -0.4), -- 10
		bone("Leg.L.002", 10, -0.2, 0.02, -0.4), -- 11
		bone("Leg.R", 3, 0.2, 0.45, -0.4), -- 12
		bone("Leg.R.001", 12, 0.2, 0.2, -0.4), -- 13
		bone("Leg.R.002", 13, 0.2, 0.02, -0.4), -- 14
		bone("Leg.L.003", 1, -0.2, 0.45, 0.2), -- 15
		bone("Leg.L.004", 15, -0.2, 0.2, 0.2), -- 16
		bone("Leg.L.005", 16, -0.2, 0.02, 0.2), -- 17
		bone("Leg.R.003", 1, 0.2, 0.45, 0.2), -- 18
		bone("Leg.R.004", 18, 0.2, 0.2, 0.2), -- 19
		bone("Leg.R.005", 19, 0.2, 0.02, 0.2), -- 20
		bone("Root.L.010", 5, -0.1, 0.9, -0.6), -- 21
		bone("Root.L.011", 21, -0.12, 1, -0.6), -- 22
		bone("Root.R.010", 5, 0.1, 0.9, -0.6), -- 23
		bone("Root.R.011", 23, 0.12, 1, -0.6), -- 24
	}
end

return {
	["a four-legged rig gets front and hind legs, segment by segment"] = function()
		local names = RigGuess.guess(dog())
		expect.equal(names["Leg.L"], "0_Left_Limb_0", "front left hip")
		expect.equal(names["Leg.L.002"], "0_Left_Limb_2", "front left foot")
		expect.equal(names["Leg.R.001"], "0_Right_Limb_1", "front right knee")
		expect.equal(names["Leg.L.003"], "1_Left_Limb_0", "hind left hip")
		expect.equal(names["Leg.R.005"], "1_Right_Limb_2", "hind right foot")
		assert(RigGuess.hasLegs(names), "it walks")
	end,

	["the middle runs pelvis, spine, neck, head; the back of it is the tail"] = function()
		local names = RigGuess.guess(dog())
		expect.equal(names["Root.M"], "Pelvis", "pelvis")
		expect.equal(names["Root.M.001"], "Spine_0", "spine")
		expect.equal(names["Root.M.002"], "Spine_1", "spine")
		expect.equal(names["Root.M.003"], "Neck", "neck")
		expect.equal(names["Root.M.004"], "Head_0", "head")
		expect.equal(names["Root.M.005"], "Head_1", "head tip")
		expect.equal(names["Root.M.006"], "Tail_0", "tail base")
		expect.equal(names["Root.M.007"], "Tail_1", "tail tip")
	end,

	["limbs high on the head pointing up are ears"] = function()
		local names = RigGuess.guess(dog())
		expect.equal(names["Root.L.010"], "Ear_Left_0", "left ear")
		expect.equal(names["Root.R.011"], "Ear_Right_1", "right ear tip")
	end,

	["with IK feet, each leg is the limb ending nearest its foot, and the foot is named"] = function()
		local names = RigGuess.guess({
			bone("Root.M", 0, 0, 0.4, 0), -- 1
			bone("Root.M.001", 1, 0, 0.6, -0.5), -- 2
			bone("Leg.L.003", 2, -0.3, 0.3, -0.4), -- 3: a sprawled front leg, hardly dropping
			bone("Leg.L.004", 3, -0.6, 0.27, -0.6), -- 4
			bone("Root.L.006", 2, -0.1, 0.25, -1.3), -- 5: a whisker, low at the face
			bone("Root.L.007", 5, -0.5, 0.15, -1.4), -- 6
			bone("Leg.L.001-IKTarget.001", 0, -0.85, 0.1, -0.8), -- 7: the foot
			bone("Leg.L.009", 7, -0.9, 0.05, -0.9), -- 8: toes under it
		})
		expect.equal(names["Leg.L.003"], "0_Left_Limb_0", "the sprawled leg")
		expect.equal(names["Leg.L.004"], "0_Left_Limb_1", "its knee")
		expect.isNil(names["Root.L.006"], "not the whisker")
		expect.equal(names["Leg.L.001-IKTarget.001"], "Foot_0_Left", "the foot is named for its leg")
		expect.isNil(names["Leg.L.009"], "the toes move with the foot")
	end,

	["lowercase rigs: sides, IK and a bone named head"] = function()
		local names = RigGuess.guess({
			bone("goblal.control", 0, 0, 0.02, -0.7), -- 1
			bone("torso.1", 1, 0, 0.2, -0.7), -- 2
			bone("torso.2", 2, 0, 0.4, -0.72), -- 3
			bone("head", 3, 0, 0.6, -0.76), -- 4
			bone("hair", 4, 0, 0.85, -0.9), -- 5
			bone("leg.l", 3, -0.23, 0.33, -0.69), -- 6
			bone("leg.l.001", 6, -0.28, 0.18, -0.9), -- 7
			bone("ik.l", 1, -0.21, 0.13, -0.62), -- 8
			bone("feet.l", 8, -0.21, 0.13, -0.62), -- 9
		})
		expect.equal(names["leg.l"], "0_Left_Limb_0", "leg")
		expect.equal(names["ik.l"], "Foot_0_Left", "foot")
		expect.equal(names["head"], "Head_0", "the named head")
		expect.equal(names["torso.2"], "Neck", "below the head")
		expect.isNil(names["hair"], "not the hair")
	end,

	["a bird's two legs step as one pair"] = function()
		local names = RigGuess.guess({
			bone("Root.M", 0, 0, 0.5, 0),
			bone("Root.M.001", 1, 0, 0.8, -0.3),
			bone("Leg.L", 1, -0.15, 0.4, 0),
			bone("Leg.L.001", 3, -0.15, 0.05, 0),
			bone("Leg.R", 1, 0.15, 0.4, 0),
			bone("Leg.R.001", 5, 0.15, 0.05, 0),
		})
		expect.equal(names["Leg.L"], "0_Left_Limb_0", "left leg")
		expect.equal(names["Leg.R.001"], "0_Right_Limb_1", "right leg")
	end,

	["sideways limbs are arms, not legs"] = function()
		local names = RigGuess.guess({
			bone("Root.M", 0, 0, 0.45, 0),
			bone("Root.M.001", 1, 0, 0.7, 0),
			bone("Root.M.002", 2, 0, 0.95, -0.05),
			bone("Root.L", 2, -0.1, 0.7, 0),
			bone("Root.L.001", 4, -0.3, 0.7, 0),
			bone("Root.L.002", 5, -0.45, 0.7, 0),
			bone("Leg.L", 1, -0.1, 0.4, 0),
			bone("Leg.L.001", 7, -0.1, 0.03, 0),
			bone("Leg.R", 1, 0.1, 0.4, 0),
			bone("Leg.R.001", 9, 0.1, 0.03, 0),
		})
		expect.equal(names["Leg.L"], "0_Left_Limb_0", "the legs step as one pair")
		expect.equal(names["Root.L"], "Arm_Left_0", "the shoulder")
		expect.equal(names["Root.L.002"], "Arm_Left_2", "down to the hand")
	end,

	["every arm chain on a side moves (rigs with a second set of arm bones)"] = function()
		local names = RigGuess.guess({
			bone("Root.M", 0, 0, 0.45, 0), -- 1
			bone("Root.M.001", 1, 0, 0.7, 0), -- 2
			bone("Root.L.009", 2, -0.1, 0.53, 0), -- 3
			bone("Root.L.015", 3, -0.2, 0.52, 0), -- 4
			bone("Root.L.016", 4, -0.28, 0.51, 0), -- 5
			bone("Root.L.010", 2, -0.1, 0.54, 0), -- 6
			bone("Root.L.017", 6, -0.2, 0.53, 0), -- 7
			bone("Root.L.019", 7, -0.28, 0.52, 0), -- 8
			bone("Leg.L", 1, -0.1, 0.4, 0),
			bone("Leg.L.001", 9, -0.1, 0.03, 0),
		})
		expect.equal(names["Root.L.009"], "Arm_Left_0", "the first set")
		expect.equal(names["Root.L.010"], "Arm_Left_0", "the second set")
		expect.equal(names["Root.L.019"], "Arm_Left_2", "down its hand")
	end,

	["a rig without legs is not walked"] = function()
		local names = RigGuess.guess({
			bone("Root.M", 0, 0, 0.3, 0.4),
			bone("Root.M.001", 1, 0, 0.4, 0),
			bone("Root.M.002", 2, 0, 0.6, -0.4),
		})
		assert(not RigGuess.hasLegs(names), "no legs")
		expect.equal(#RigGuess.guess({}), 0, "no bones")
	end,
}
