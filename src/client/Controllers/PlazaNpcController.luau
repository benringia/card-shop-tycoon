--!strict
-- The plaza's sitting townsfolk on this client (Config/Plaza SITTER, rigs built by Server/Util/PlazaBuild): each plays
-- Roblox's sit animation and now and then lifts its cup to sip (right shoulder and elbow turned up, held, then back)
-- while the camera is near and the extras are on (Util/Extras). Scenery only: nothing goes to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plaza = require(Shared:WaitForChild("Config"):WaitForChild("Plaza"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

type Joint = { motor: Motor6D, rest: CFrame, angle: number }
type Sitter = { rig: Model, joints: { Joint }, nextSip: number }

local PlazaNpcController = {}

local sitters: { [Model]: Sitter } = {}
local random = Random.new()

local function nextSipAt(): number
	local every = Plaza.SITTER.sip.every
	return os.clock() + random:NextNumber(every[1], every[2])
end

local function setUp(rig: Model)
	if not rig:IsA("Model") or sitters[rig] then
		return
	end
	local humanoid = rig:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = Plaza.SITTER.animation
	animator:LoadAnimation(animation):Play()
	local sip = Plaza.SITTER.sip
	local joints = {}
	for _, spec in { { "RightUpperArm", "RightShoulder", sip.shoulder }, { "RightLowerArm", "RightElbow", sip.elbow } } do
		local limb = rig:FindFirstChild(spec[1])
		local motor = limb and limb:FindFirstChild(spec[2])
		if motor and motor:IsA("Motor6D") then
			table.insert(joints, { motor = motor, rest = motor.C0, angle = spec[3] })
		end
	end
	sitters[rig] = { rig = rig, joints = joints, nextSip = nextSipAt() }
end

local function sipFrom(sitter: Sitter)
	local sip = Plaza.SITTER.sip
	local lift = TweenInfo.new(sip.raise, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, joint in sitter.joints do
		TweenService:Create(joint.motor, lift, { C0 = joint.rest * CFrame.Angles(math.rad(joint.angle), 0, 0) }):Play()
	end
	task.delay(sip.raise + sip.hold, function()
		for _, joint in sitter.joints do
			if joint.motor.Parent then
				TweenService:Create(joint.motor, lift, { C0 = joint.rest }):Play()
			end
		end
	end)
end

function PlazaNpcController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	task.spawn(function()
		local townsfolk = workspace:WaitForChild("Scenery"):WaitForChild("FestivalSquare"):WaitForChild("Townsfolk")
		for _, rig in townsfolk:GetChildren() do
			task.spawn(setUp, rig :: Model)
		end
		townsfolk.ChildAdded:Connect(function(rig)
			setUp(rig :: Model)
		end)
		townsfolk.ChildRemoved:Connect(function(rig)
			sitters[rig :: Model] = nil
		end)
		while true do
			task.wait(0.5)
			local camera = workspace.CurrentCamera.CFrame.Position
			local now = os.clock()
			for _, sitter in sitters do
				if now >= sitter.nextSip then
					sitter.nextSip = nextSipAt()
					local root = sitter.rig.PrimaryPart
					if Extras.enabled() and root and (root.Position - camera).Magnitude <= Plaza.SITTER.sip.range then
						sipFrom(sitter)
					end
				end
			end
		end
	end)
end

return PlazaNpcController
