--!strict
-- Shared NPC helpers for customers and shop workers: building an R15 rig, walk/idle animations,
-- collision groups (players walk through NPCs), and walking along a path.
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local NpcMotion = {}

NpcMotion.NPC_GROUP = "Customers" -- every NPC (customers and workers); kept for existing collision setups
NpcMotion.PLAYER_GROUP = "Players"

local groupsReady = false

function NpcMotion.setupCollisionGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	PhysicsService:RegisterCollisionGroup(NpcMotion.NPC_GROUP)
	PhysicsService:RegisterCollisionGroup(NpcMotion.PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(NpcMotion.NPC_GROUP, NpcMotion.NPC_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(NpcMotion.NPC_GROUP, NpcMotion.PLAYER_GROUP, false)
end

function NpcMotion.setGroup(instance: Instance, group: string)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = group
	end
end

-- An R15 rig from a description, in the NPC collision group, standing at spawnCFrame
function NpcMotion.createRig(description: HumanoidDescription, name: string, spawnCFrame: CFrame): Model
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	for _, descendant in model:GetDescendants() do
		NpcMotion.setGroup(descendant, NpcMotion.NPC_GROUP)
	end
	model:PivotTo(spawnCFrame + Vector3.new(0, 3, 0))
	return model
end

function NpcMotion.setupAnimations(humanoid: Humanoid, walkAnimationId: string, idleAnimationId: string)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local walkAnimation = Instance.new("Animation")
	walkAnimation.AnimationId = walkAnimationId
	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = idleAnimationId

	local walk = animator:LoadAnimation(walkAnimation)
	local idle = animator:LoadAnimation(idleAnimation)
	idle:Play()

	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				idle:Stop()
				walk:Play()
			end
		elseif not idle.IsPlaying then
			walk:Stop()
			idle:Play()
		end
	end)
end

local function moveDirect(humanoid: Humanoid, target: Vector3): boolean
	humanoid:MoveTo(target)
	-- MoveToFinished fires false on its own after 8 seconds if the target isn't reached
	return humanoid.MoveToFinished:Wait()
end

-- Walks along a computed path; falls back to a straight line if no path is found.
-- isAlive lets the caller stop the walk early (NPC removed).
function NpcMotion.walkTo(humanoid: Humanoid, root: BasePart, target: Vector3, agentParams: { [string]: any }, isAlive: () -> boolean): boolean
	local path = PathfindingService:CreatePath(agentParams)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	if not isAlive() then
		return false
	end
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return moveDirect(humanoid, target)
	end

	for _, waypoint in path:GetWaypoints() do
		if not isAlive() then
			return false
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		if not moveDirect(humanoid, waypoint.Position) then
			return false
		end
	end
	return true
end

return NpcMotion
