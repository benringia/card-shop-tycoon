--!strict
-- The town at night on this client (the owner 2026-11-11: "make it more immersive"; Config/Ambient NIGHT_LIGHTS): as
-- the day cycle's clock goes into the night (Util/SoundscapeRules.nightShare on Config/Soundscape NIGHT) the street
-- lights' and lamps' lights glow brighter and reach further, back down by morning, and fireflies drift
-- over the town's grassy corners (only while the extras run, Util/Extras). Main game only; nothing replicates.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Ambient = require(Config:WaitForChild("Ambient"))
local Soundscape = require(Config:WaitForChild("Soundscape"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local SoundscapeRules = require(SharedUtil:WaitForChild("SoundscapeRules"))

local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local TownNightController = {}

local LOOK = Ambient.NIGHT_LIGHTS
local CHECK_EVERY = 0.5 -- seconds between updates
local ROOT_WAIT = 60 -- seconds to wait for each folder the lights are in
local FIREFLY = Color3.fromRGB(210, 255, 120)

local lamps: { [Light]: { brightness: number, range: number } } = {} -- each light and its own brightness and range
local fireflies: { ParticleEmitter } = {}
local lastShare = -1

-- A street light's or lamp's light, with its own brightness and range (a new one takes the night at the next update)
local function consider(item: Instance)
	if not (item:IsA("PointLight") or item:IsA("SpotLight")) or lamps[item :: any] then
		return
	end
	local model = item:FindFirstAncestorOfClass("Model")
	if model and table.find(LOOK.models, model.Name) then
		local light: any = item
		lamps[light] = { brightness = light.Brightness, range = light.Range }
		lastShare = -1
	end
end

-- The lights in a folder now and as they stream in and out
local function watch(root: Instance)
	for _, item in root:GetDescendants() do
		consider(item)
	end
	root.DescendantAdded:Connect(consider)
	root.DescendantRemoving:Connect(function(item)
		lamps[item :: any] = nil
	end)
end

-- A firefly box over the ground at a spot (the terrain or the town's own ground parts, found by a ray; none: no
-- fireflies there)
local function swarm(folder: Folder, spot: any): ParticleEmitter?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("Town") or workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(spot.x, 120, spot.z), Vector3.new(0, -240, 0), params)
	if not hit then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "Fireflies"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(spot.size.x, 3, spot.size.z)
	part.Position = hit.Position + Vector3.new(0, LOOK.fireflies.height, 0)
	part.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Color = ColorSequence.new(FIREFLY)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = 0
	emitter.Parent = part
	return emitter
end

local function update()
	local night = SoundscapeRules.nightShare(Lighting.ClockTime, Soundscape.NIGHT)
	if math.abs(night - lastShare) > 0.01 then
		lastShare = night
		local lamp = LOOK.lamp
		local brightness = lamp.brightness[1] + (lamp.brightness[2] - lamp.brightness[1]) * night
		local range = lamp.range[1] + (lamp.range[2] - lamp.range[1]) * night
		for light, own in lamps do
			if light.Parent then
				local reach: any = light -- a PointLight or a SpotLight: both have a Range
				light.Brightness = own.brightness * brightness
				reach.Range = own.range * range
			end
		end
	end
	local rate = if Extras.enabled() then LOOK.fireflies.rate * night else 0
	for _, emitter in fireflies do
		emitter.Rate = rate
	end
end

function TownNightController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	task.spawn(function()
		-- The terrain is filled after the server starts: wait for the town's ground before placing the fireflies
		local ready = (Place.getValley() :: any).TERRAIN_READY_ATTRIBUTE
		while ready and workspace:GetAttribute(ready) ~= true do
			task.wait(1)
		end
		local folder = Instance.new("Folder")
		folder.Name = "TownNight"
		folder.Parent = workspace
		for _, spot in LOOK.fireflies.spots do
			local emitter = swarm(folder, spot)
			if emitter then
				table.insert(fireflies, emitter)
			end
		end
		for _, rootName in LOOK.roots do
			task.spawn(function()
				local root = workspace:WaitForChild(rootName, ROOT_WAIT)
				if root then
					watch(root)
				end
			end)
		end
		local sinceCheck = 0
		RunService.Heartbeat:Connect(function(dt)
			sinceCheck += dt
			if sinceCheck >= CHECK_EVERY then
				sinceCheck = 0
				update()
			end
		end)
	end)
end

return TownNightController
