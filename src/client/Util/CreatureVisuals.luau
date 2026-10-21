--!strict
-- Shared by CreatureController (summoned creatures) and MonsterController (wild monsters): turns a model
-- (imported, or a placeholder built from parts) into a client-only "body" that follows an invisible server
-- marker smoothly, with the motion kit (breathing, hop-and-waddle, hover) or the model's own Idle/Walk
-- animations. A marker with the attribute Fainted = true makes its body lie down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureMotion = require(Shared:WaitForChild("Util"):WaitForChild("CreatureMotion"))

local CreatureVisuals = {}

local SMOOTHING = 10 -- higher follows the marker more tightly
local NEAR_DISTANCE = 80 -- studs from the camera: breathing (rescaling) only this close
local TELEPORT_DISTANCE = 40 -- further than this and the body jumps to its marker
local FAINT_ROLL = math.rad(80)
local STRIPPED = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "Tool" }

export type Body = {
	marker: BasePart,
	model: Model,
	root: BasePart,
	baseScale: number,
	flying: boolean,
	rigged: boolean,
	cframe: CFrame,
	speed: number,
	walked: number,
	frame: number,
	tracks: { idle: AnimationTrack?, walk: AnimationTrack? },
}

function CreatureVisuals.countParts(model: Instance): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- A model from a ReplicatedStorage folder (CreatureModels, MonsterModels), or nil if missing or too big
function CreatureVisuals.getTemplate(folderName: string, name: string, maxParts: number): Model?
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	local template = if folder then folder:FindFirstChild(name) else nil
	if not template or not template:IsA("Model") or CreatureVisuals.countParts(template) > maxParts then
		return nil
	end
	return template
end

-- Free models can carry scripts and noise: none of it may run or play on this client
function CreatureVisuals.strip(model: Model)
	for _, descendant in model:GetDescendants() do
		for _, className in STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

-- For placeholder models: one smooth part
function CreatureVisuals.addPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function findRigRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

-- Rigged = an Animations folder with Idle and Walk, a root to hold it up, and something to play them on
local function getAnimator(model: Model): Animator?
	local animations = model:FindFirstChild("Animations")
	local idle = if animations then animations:FindFirstChild("Idle") else nil
	local walk = if animations then animations:FindFirstChild("Walk") else nil
	if not idle or not idle:IsA("Animation") or not walk or not walk:IsA("Animation") or not findRigRoot(model) then
		return nil -- no rig root to hold it up: treat it as a static model
	end
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = controller
		animator = created
	end
	return animator
end

-- Adds a root part at the bottom centre facing the model's front, then sizes the model to `height` studs
local function prepare(model: Model, height: number, rigged: boolean): (BasePart, number)
	local rigRoot = findRigRoot(model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local yaw = model:GetAttribute("YawOffset") -- degrees, for models that don't face -Z
	local root = Instance.new("Part")
	root.Name = "CreatureRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
		* CFrame.Angles(0, math.rad(if typeof(yaw) == "number" then yaw else 0), 0)
	root.Parent = model

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			-- Rigs: only the root is anchored so their joints can animate; static models: all of it
			descendant.Anchored = descendant == root or not rigged
		end
	end
	if rigged and rigRoot then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = rigRoot
		weld.Parent = root
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.PlatformStand = true
	end
	model.PrimaryPart = root

	local scale = model:GetScale() * height / math.max(boxSize.Y, 0.1)
	model:ScaleTo(scale)
	return root, scale
end

-- Sizes the model, places it on the marker and puts it in the world. Strip it first.
function CreatureVisuals.build(model: Model, marker: BasePart, height: number, flying: boolean): Body
	local animator = getAnimator(model)
	local root, scale = prepare(model, height, animator ~= nil)
	local body: Body = {
		marker = marker,
		model = model,
		root = root,
		baseScale = scale,
		flying = flying,
		rigged = animator ~= nil,
		cframe = marker.CFrame,
		speed = 0,
		walked = 0,
		frame = 0,
		tracks = {},
	}
	model:PivotTo(marker.CFrame)
	model.Parent = workspace
	-- Animators only load animations once they're in the game
	if animator then
		local animations = model:FindFirstChild("Animations") :: Instance
		local idle = animator:LoadAnimation(animations:FindFirstChild("Idle") :: Animation)
		local walk = animator:LoadAnimation(animations:FindFirstChild("Walk") :: Animation)
		idle.Looped = true
		walk.Looped = true
		idle:Play()
		body.tracks.idle, body.tracks.walk = idle, walk
	end
	return body
end

-- Name tag floating `above` studs over the body's feet
function CreatureVisuals.makeTag(root: BasePart, above: number, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, above + 1, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = root
	return label
end

-- One frame: follow the marker smoothly, then pose (motion kit or animations), or lie down when fainted
function CreatureVisuals.step(body: Body, dt: number, now: number, origin: Vector3, motion: any)
	local target = body.marker.CFrame
	local previous = body.cframe.Position
	if (target.Position - previous).Magnitude > TELEPORT_DISTANCE then
		body.cframe = target
	else
		body.cframe = body.cframe:Lerp(target, 1 - math.exp(-SMOOTHING * dt))
	end
	local moved = Vector3.new(body.cframe.X - previous.X, 0, body.cframe.Z - previous.Z).Magnitude
	if moved < TELEPORT_DISTANCE then
		body.walked += moved
		body.speed += (moved / math.max(dt, 1e-3) - body.speed) * math.min(1, dt * 8)
	end
	body.frame += 1

	if body.marker:GetAttribute("Fainted") == true then
		body.model:PivotTo(body.cframe * CFrame.Angles(0, 0, FAINT_ROLL))
		return
	end

	local near = (body.cframe.Position - origin).Magnitude <= NEAR_DISTANCE
	if body.rigged then
		-- Its own animations do the walking and breathing; the kit only lifts flyers
		local walking = body.speed >= motion.WALK_SPEED_MIN
		local idle, walk = body.tracks.idle :: AnimationTrack, body.tracks.walk :: AnimationTrack
		if walking and not walk.IsPlaying then
			walk:Play(0.2)
			idle:Stop(0.2)
		elseif not walking and not idle.IsPlaying then
			idle:Play(0.2)
			walk:Stop(0.2)
		end
		local hover = if body.flying then CreatureMotion.getPose(motion, now, body.speed, body.walked, true).offsetY else 0
		body.model:PivotTo(body.cframe * CFrame.new(0, hover, 0))
	else
		local pose = CreatureMotion.getPose(motion, now, body.speed, body.walked, body.flying)
		body.model:PivotTo(body.cframe * CFrame.new(0, pose.offsetY, 0) * CFrame.Angles(-pose.pitch, 0, pose.roll))
		-- Model:ScaleTo is uniform: breathing grows and shrinks a little, every other frame, only up close
		if near and body.frame % 2 == 0 then
			body.model:ScaleTo(body.baseScale * pose.scaleY)
		end
	end
end

return CreatureVisuals
