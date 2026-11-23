--!strict
-- Carrying a box, drawn on every client (owner 2026-11-23: "a better animation for player for holding boxes";
-- Config/CarryPose): any player whose CarryCount is over 0 (StockService) eases their arms round the box held in front
-- of them, hands on its sides, and leans back a touch; it all eases back when the box goes. The box itself is welded to
-- the UpperTorso on the server, so it sways with the walk and the hands stay on it. Posed through the joints' Transform
-- after the animations each frame (PreSimulation), blended from whatever the walk or idle plays: player joints are
-- AnimationConstraints (BinderPoseController's way). R15 bodies only (SwordService gives everyone the standard one).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryPose = require(Shared:WaitForChild("Config"):WaitForChild("CarryPose"))
local BinderPoseRules = require(Shared:WaitForChild("Util"):WaitForChild("BinderPoseRules"))

local CarryPoseController = {}

type Joint = Motor6D | AnimationConstraint
type Carrier = {
	carrying: boolean,
	since: number, -- when the ease in or out started (os.clock)
	character: Model?,
	joints: { [string]: Joint },
}

local ATTRIBUTE = "CarryCount"
local POSE = CarryPose.POSE
local JOINTS = {
	rightShoulder = { "RightUpperArm", "RightShoulder" },
	leftShoulder = { "LeftUpperArm", "LeftShoulder" },
	rightElbow = { "RightLowerArm", "RightElbow" },
	leftElbow = { "LeftLowerArm", "LeftElbow" },
	waist = { "UpperTorso", "Waist" },
}
-- The arms' pose at full weight, in each joint's own frame: shoulders forward and a little inward, elbows bent
local FORWARD, INWARD, ELBOW = math.rad(POSE.shoulder), math.rad(POSE.inward), math.rad(POSE.elbow)
local ARM_POSE: { [string]: CFrame } = {
	rightShoulder = CFrame.Angles(0, INWARD, 0) * CFrame.Angles(FORWARD, 0, 0),
	leftShoulder = CFrame.Angles(0, -INWARD, 0) * CFrame.Angles(FORWARD, 0, 0),
	rightElbow = CFrame.Angles(ELBOW, 0, 0),
	leftElbow = CFrame.Angles(ELBOW, 0, 0),
}
local LEAN = math.rad(POSE.lean) -- about X: the chest's top back

local carriers: { [Player]: Carrier } = {}

local function jointsOf(character: Model): { [string]: Joint }
	local joints: { [string]: Joint } = {}
	for key, path in JOINTS do
		local limb = character:FindFirstChild(path[1])
		local joint = if limb then limb:FindFirstChild(path[2]) else nil
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[key] = joint
		end
	end
	return joints
end

local function carrierOf(player: Player): Carrier
	local carrier = carriers[player]
	if not carrier then
		carrier = { carrying = false, since = -math.huge, character = nil, joints = {} }
		carriers[player] = carrier
	end
	return carrier
end

local function onAttribute(player: Player)
	local carrier = carrierOf(player)
	local count = player:GetAttribute(ATTRIBUTE)
	local carrying = typeof(count) == "number" and count > 0
	if carrying == carrier.carrying then
		return
	end
	-- carry on from where the ease was, so a quick put-down and pick-up never snaps
	local now = os.clock()
	local weight = BinderPoseRules.weight(carrier.since, now, CarryPose.EASE, carrier.carrying)
	carrier.carrying = carrying
	local done = if carrying then weight else 1 - weight
	carrier.since = now - done * CarryPose.EASE
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		onAttribute(player)
	end)
	onAttribute(player)
end

-- One carrier's frame, after the animations: the arms blended from the walk or idle into holding the box
local function pose(player: Player, carrier: Carrier, now: number)
	local weight = BinderPoseRules.weight(carrier.since, now, CarryPose.EASE, carrier.carrying)
	local character = player.Character
	if weight <= 0 or not character then
		return
	end
	if carrier.character ~= character or not next(carrier.joints) then
		carrier.character = character
		carrier.joints = jointsOf(character)
	end
	for key, target in ARM_POSE do
		local joint = carrier.joints[key]
		if joint and joint.Parent then
			joint.Transform = joint.Transform:Lerp(target, weight)
		end
	end
	local waist = carrier.joints.waist
	if waist and waist.Parent then
		waist.Transform = waist.Transform * CFrame.Angles(LEAN * weight, 0, 0)
	end
end

function CarryPoseController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		carriers[player] = nil
	end)
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for player, carrier in carriers do
			pose(player, carrier, now)
		end
	end)
end

return CarryPoseController
