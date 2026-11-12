--!strict
-- The character window's stage (owner 2026-11-12: "character windows must have their character model and the weapon
-- their using"): a ViewportFrame showing a copy of your own character as it is now (your equipped weapon included:
-- it's part of your character) on a soft glowing podium, breathing in your avatar's own idle animation (owner
-- 2026-11-12: "move rather than it look like an image only"); drag across it to turn it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Look = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CharacterWindow"))

local CharacterStage = {}

export type Stage = { frame: ViewportFrame, refresh: () -> (), destroy: () -> () }

local TURN_PER_PIXEL = 0.012 -- radians a pixel of drag turns it
-- facing the camera (a model looks down -Z, the camera looks at it from -Z), turned a little so the weapon hand (its
-- right) comes forward (owner 2026-11-12: 200 degrees showed its back)
local START_TURN = math.rad(20)
local FRAME_MARGIN = 1.12 -- room round the character in the stage

-- Your avatar's idle animation (its Animate script's first idle), or the default one
local function idleOf(character: Model): string
	local animate = character:FindFirstChild("Animate")
	local idle = if animate then animate:FindFirstChild("idle") else nil
	local first = if idle then idle:FindFirstChildWhichIsA("Animation") else nil
	return if first and first.AnimationId ~= "" then first.AnimationId else Look.IDLE_FALLBACK
end

-- A copy of the character to show: only its root anchored (its joints move it), no scripts, no sounds, no name tags
local function copyOf(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not copy then
		return nil
	end
	for _, piece in (copy :: Model):GetDescendants() do
		if piece:IsA("BaseScript") or piece:IsA("Sound") or piece:IsA("BillboardGui") or piece:IsA("ProximityPrompt") then
			piece:Destroy()
		elseif piece:IsA("BasePart") then
			piece.Anchored = piece.Name == "HumanoidRootPart"
			piece.CanCollide = false
		end
	end
	local humanoid = (copy :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return copy :: Model
end

function CharacterStage.new(parent: GuiObject): Stage
	local frame = Instance.new("ViewportFrame")
	frame.Name = "CharacterStage"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(200, 190, 220)
	frame.LightColor = Color3.fromRGB(255, 245, 255)
	frame.LightDirection = Vector3.new(-0.4, -1, -0.6)
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = frame
	frame.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = frame

	local model: Model? = nil
	local turn = START_TURN
	local centre = Vector3.zero
	local function place()
		if model then
			model:PivotTo(CFrame.new(centre) * CFrame.Angles(0, turn, 0))
		end
	end

	local function refresh()
		if model then
			model:Destroy()
			model = nil
		end
		local character = Players.LocalPlayer.Character
		local copy = if character then copyOf(character) else nil
		if not copy or not character then
			return
		end
		copy.Parent = world
		centre = Vector3.zero
		model = copy
		place()
		-- its idle, looping (a WorldModel animates on the client)
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = idleOf(character)
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Looped = true
				track:Play(0)
			end
		end
		-- its box as placed (the hat, the sword and the feet, not the root it pivots on)
		local box, size = copy:GetBoundingBox()
		local middle = box.Position
		-- the podium under its feet
		local podium = world:FindFirstChild("Podium") :: BasePart?
		if not podium then
			local made = Instance.new("Part")
			made.Name = "Podium"
			made.Shape = Enum.PartType.Cylinder
			made.Anchored = true
			made.Material = Enum.Material.Neon
			made.Color = Color3.fromRGB(235, 220, 255)
			made.Parent = world
			podium = made
		end
		local foot = middle.Y - size.Y / 2
		local across = math.max(size.X, size.Z) -- it turns: its widest side
		;(podium :: BasePart).Size = Vector3.new(0.4, across * 1.3, across * 1.3)
		;(podium :: BasePart).CFrame = CFrame.new(0, foot - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		-- the camera: the whole character in view (tall and wide: the stage is narrow), a little from above
		local half = math.tan(math.rad(camera.FieldOfView / 2))
		local aspect = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.X / frame.AbsoluteSize.Y else 1
		local distance = math.max(size.Y / (2 * half), across / (2 * half * aspect)) * FRAME_MARGIN + across / 2
		local aim = Vector3.new(0, middle.Y, 0)
		camera.CFrame = CFrame.lookAt(aim + Vector3.new(0, size.Y * 0.08, -distance), aim)
	end

	-- drag to turn it
	local dragging: InputObject? = nil
	local lastX = 0
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			lastX = input.Position.X
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging
		if moving then
			turn += (input.Position.X - lastX) * TURN_PER_PIXEL
			lastX = input.Position.X
			place()
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = nil
		end
	end))

	return {
		frame = frame,
		refresh = refresh,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			frame:Destroy()
		end,
	}
end

return CharacterStage
