--!strict
-- Your character acting in the prologue's act 3 and wake-up (owner 2026-11-15; Config/Prologue KNOCK, CRAWL, WAKE): held
-- by its root (anchored, moved by hand) to be thrown back by the Hydra's blow, lie face down and crawl
-- (PrologueRules.knock, .crawl), and lie on its back in town. The limbs are posed through their joints' Transform after
-- the animations each frame (PreSimulation): player joints are AnimationConstraints (Motor6Ds on older rigs; both have
-- Transform). R15 only (SwordService gives everyone the standard body); a missing joint is just left to its animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PrologueRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("PrologueRules"))

local PrologueBody = {}

export type Body = {
	root: BasePart,
	place: (cframe: CFrame) -> (),
	pose: (pose: PrologueRules.CrawlPose?) -> (),
	release: () -> (),
}

type Joint = Motor6D | AnimationConstraint

-- Each pose key's joint: { the part it moves, the joint's name }
local JOINTS: { [string]: { string } } = {
	rightShoulder = { "RightUpperArm", "RightShoulder" },
	leftShoulder = { "LeftUpperArm", "LeftShoulder" },
	rightElbow = { "RightLowerArm", "RightElbow" },
	leftElbow = { "LeftLowerArm", "LeftElbow" },
	neck = { "Head", "Neck" },
	rightHip = { "RightUpperLeg", "RightHip" },
	leftHip = { "LeftUpperLeg", "LeftHip" },
	rightKnee = { "RightLowerLeg", "RightKnee" },
	leftKnee = { "LeftLowerLeg", "LeftKnee" },
}
-- How each key's degrees turn its joint: shoulders raise the arm out to the side (about the joint's Z, the left the
-- other way), so lying face down the arms sweep along the floor; knees bend backwards; the rest turn about X
local function turn(key: string, degrees: number): CFrame
	local angle = math.rad(degrees)
	if key == "rightShoulder" then
		return CFrame.Angles(0, 0, angle)
	elseif key == "leftShoulder" then
		return CFrame.Angles(0, 0, -angle)
	elseif key == "rightKnee" or key == "leftKnee" then
		return CFrame.Angles(-angle, 0, 0)
	end
	return CFrame.Angles(angle, 0, 0)
end

-- Lying face down at `at` (your middle), your head toward `toward` (a flat direction)
function PrologueBody.faceDown(at: Vector3, toward: Vector3): CFrame
	local up = Vector3.new(toward.X, 0, toward.Z).Unit
	local back = Vector3.yAxis -- your back to the sky
	return CFrame.fromMatrix(at, up:Cross(back), up, back)
end

-- Lying on your back at `at`, your head toward `toward`
function PrologueBody.onBack(at: Vector3, toward: Vector3): CFrame
	local up = Vector3.new(toward.X, 0, toward.Z).Unit
	local back = -Vector3.yAxis -- your face to the sky
	return CFrame.fromMatrix(at, up:Cross(back), up, back)
end

-- Takes hold of `character` (nil without a root or humanoid)
function PrologueBody.grab(character: Model): Body?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	local joints: { [string]: Joint } = {}
	for key, where in JOINTS do
		local part = character:FindFirstChild(where[1])
		local joint = if part then part:FindFirstChild(where[2]) else nil
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[key] = joint :: any
		end
	end
	root.Anchored = true
	humanoid.PlatformStand = true
	local current: PrologueRules.CrawlPose? = nil
	local posing = RunService.PreSimulation:Connect(function()
		local pose = current
		if not pose then
			return
		end
		for key, joint in joints do
			if joint.Parent then
				joint.Transform = turn(key, (pose :: any)[key] :: number)
			end
		end
	end)
	local body: Body = {
		root = root,
		place = function(cframe: CFrame)
			if root.Parent then
				root.CFrame = cframe
			end
		end,
		pose = function(pose: PrologueRules.CrawlPose?)
			current = pose
		end,
		release = function()
			posing:Disconnect()
			current = nil
			if root.Parent then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
			end
			if humanoid.Parent then
				humanoid.PlatformStand = false
			end
		end,
	}
	return body
end

return PrologueBody
