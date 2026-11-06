--!strict
-- Shared NPC helpers for customers and shop workers: building an R15 rig, walk/idle animations,
-- collision groups (players walk through NPCs), and walking along a path.
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomerConfig = require(Shared:WaitForChild("Config"):WaitForChild("Customers"))
local WalkStep = require(Shared:WaitForChild("Util"):WaitForChild("WalkStep"))

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

-- The walk clip plays at the feet's pace (Util/WalkStep.clipSpeed over Customers.WALK_CLIP_PACE), and the idle clip
-- only once the NPC has stood still a moment (NPC_STEP.idleDelay), so a turn on the path doesn't flicker to idle
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

	local stopping: {}? = nil -- the stop that will switch to idle unless the NPC moves again first
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			stopping = nil
			local rate = WalkStep.clipSpeed(speed, CustomerConfig.WALK_CLIP_PACE)
			if walk.IsPlaying then
				walk:AdjustSpeed(rate)
			else
				idle:Stop(0.2)
				walk:Play(0.2, 1, rate)
			end
			return
		end
		if not walk.IsPlaying or stopping then
			return
		end
		local stop = {}
		stopping = stop
		task.delay(CustomerConfig.NPC_STEP.idleDelay, function()
			if stopping == stop then
				stopping = nil
				walk:Stop(0.25)
				idle:Play(0.25)
			end
		end)
	end)
end

-- One step toward `point`: true once it's there (WalkStep.reached: a waypoint on the way a little early, so the next
-- step goes out before the NPC stops), false when it's stuck (walking without getting anywhere) or past its time
-- (twice the walk time plus graceSeconds, NPC_STEP.grace when nil)
local function step(humanoid: Humanoid, root: BasePart, point: Vector3, isLast: boolean, graceSeconds: number?): boolean
	local look = CustomerConfig.NPC_STEP
	local function flatTo(): number
		local here = root.Position
		return Vector2.new(point.X - here.X, point.Z - here.Z).Magnitude
	end
	local limit = WalkStep.limit(flatTo(), humanoid.WalkSpeed, graceSeconds or look.grace)
	local started = os.clock()
	local askedAt, checkedAt, checkedFrom = started, started, root.Position
	humanoid:MoveTo(point)
	while not WalkStep.reached(flatTo(), isLast, look) do
		task.wait(look.check)
		if not root.Parent then
			return false
		end
		local now = os.clock()
		if now - started > limit then
			return false
		end
		if now - checkedAt >= look.stallSeconds then
			local moved = (root.Position - checkedFrom).Magnitude
			if WalkStep.stalled(moved, now - checkedAt, look) then
				return false
			end
			checkedAt, checkedFrom = now, root.Position
		end
		-- Roblox's MoveTo gives up after 8 s of walking: ask again before that on a long step
		if now - askedAt > 6 then
			humanoid:MoveTo(point)
			askedAt = now
		end
	end
	return true
end

-- Walks along a computed path; falls back to a straight line if no path is found, unless straightLine is false (then
-- it gives up: false). isAlive (asked before each waypoint) lets the caller stop the walk early (NPC removed).
-- graceSeconds: see step.
function NpcMotion.walkTo(
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3,
	agentParams: { [string]: any },
	isAlive: () -> boolean,
	graceSeconds: number?,
	straightLine: boolean?
): (boolean, { Vector3 }?)
	local path = PathfindingService:CreatePath(agentParams)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	if not isAlive() then
		return false
	end
	if not ok or path.Status ~= Enum.PathStatus.Success then
		if straightLine == false then
			return false
		end
		return step(humanoid, root, target, true, graceSeconds)
	end

	local waypoints = path:GetWaypoints()
	local route: { Vector3 } = {}
	for index, waypoint in waypoints do
		if not isAlive() then
			return false
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		table.insert(route, waypoint.Position)
		if not step(humanoid, root, waypoint.Position, index == #waypoints, graceSeconds) then
			return false
		end
	end
	-- (the second result: the route walked, so a caller stuck at its end can retrace it)
	return true, route
end

-- Walks straight through `points` in order (no path search), as smoothly as a path; false when it gets stuck. Used
-- to retrace a route walked before, out of a tight spot no path can start from
function NpcMotion.walkRoute(humanoid: Humanoid, root: BasePart, points: { Vector3 }, isAlive: () -> boolean, graceSeconds: number?): boolean
	for index, point in points do
		if not isAlive() then
			return false
		end
		if not step(humanoid, root, point, index == #points, graceSeconds) then
			return false
		end
	end
	return true
end

return NpcMotion
