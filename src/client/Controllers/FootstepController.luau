--!strict
-- Footsteps (the owner 2026-11-11: "lets just add a footsteps sound effect on whatever the character is stepping on";
-- Config/Footsteps, Util/FootstepRules): every player's character within RANGE studs of the camera (the nearest
-- MAX_OTHERS besides your own) takes a step each STRIDE studs it walks on the ground, sounding like the floor under it
-- (your own from Humanoid.FloorMaterial; other players' from a short ray down, since theirs isn't replicated), a
-- different sound each step at a random pitch, from its feet. Roblox's own running loop (RbxCharacterSounds' "Running"
-- on the root) is muted so the two never play together. Every place.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Footsteps = require(Shared:WaitForChild("Config"):WaitForChild("Footsteps"))
local FootstepRules = require(Shared:WaitForChild("Util"):WaitForChild("FootstepRules"))

local FootstepController = {}

local RAY_DOWN = 5 -- studs below the root a floor is looked for (other players)
local SOUND_LIFE = 1.5 -- seconds a step's sound is kept

type Walker = { carry: number, last: number? }

local player = Players.LocalPlayer
local walkers: { [Model]: Walker } = setmetatable({}, { __mode = "k" }) :: any
local templates: { [string]: Sound } = {}
local muted: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function templateFor(id: string): Sound
	local made = templates[id]
	if not made then
		local folder = SoundService:FindFirstChild("Footsteps") or Instance.new("Folder")
		folder.Name = "Footsteps"
		folder.Parent = SoundService
		made = Instance.new("Sound")
		made.SoundId = id
		made.Parent = folder
		templates[id] = made
	end
	return made :: Sound
end

-- Roblox's own running loop on this character, muted (once; it can arrive after the character)
local function muteRunning(character: Model, root: BasePart)
	if muted[character] then
		return
	end
	muted[character] = true
	local function mute(child: Instance)
		if child:IsA("Sound") and child.Name == "Running" then
			child.Volume = 0
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

-- The floor's material under another player's character (a short ray down), nil in the air
local function floorBelow(character: Model, root: BasePart): string?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -RAY_DOWN, 0), params)
	return if hit then hit.Material.Name else nil
end

local function step(walker: Walker, root: BasePart, surfaceName: string, own: boolean)
	local surface = Footsteps.SURFACES[surfaceName]
	if not surface then
		return
	end
	local index = FootstepRules.pick(#surface.ids, math.random(), walker.last)
	walker.last = index
	local sound = templateFor(surface.ids[index]):Clone()
	sound.Volume = surface.volume * (if own then 1 else Footsteps.OTHERS)
	sound.PlaybackSpeed = Footsteps.PITCH[1] + math.random() * (Footsteps.PITCH[2] - Footsteps.PITCH[1])
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = Footsteps.ROLL_OFF
	local region = (surface :: any).region
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(0, region)
	end
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFE)
end

-- One character this frame: its next step, if it walked far enough on a floor
local function walk(character: Model, own: boolean, dt: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	muteRunning(character, root)
	local walker = walkers[character]
	if not walker then
		walker = { carry = 0, last = nil }
		walkers[character] = walker
	end
	local material = if own then humanoid.FloorMaterial.Name else floorBelow(character, root)
	local surfaceName = if material then FootstepRules.surface(material, Footsteps) else nil
	if not surfaceName then
		walker.carry = 0
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local carry, stepped = FootstepRules.advance(walker.carry, speed, dt, Footsteps.STRIDE, Footsteps.MIN_SPEED)
	walker.carry = carry
	if stepped then
		step(walker, root, surfaceName, own)
	end
end

function FootstepController.Start()
	for _, surface in Footsteps.SURFACES do
		for _, id in surface.ids do
			templateFor(id)
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		local others: { { character: Model, distance: number } } = {}
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if not character then
				continue
			end
			if other == player then
				walk(character, true, dt)
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			local distance = if root and root:IsA("BasePart") then (root.Position - origin).Magnitude else math.huge
			if distance <= Footsteps.RANGE then
				table.insert(others, { character = character, distance = distance })
			end
		end
		table.sort(others, function(a, b)
			return a.distance < b.distance
		end)
		for index = 1, math.min(#others, Footsteps.MAX_OTHERS) do
			walk(others[index].character, false, dt)
		end
	end)
end

return FootstepController
