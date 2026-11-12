--!strict
-- The Crystal Abyss's regions on this client (spec 2026-11-12-abyss-regions; Config/Dungeon REGIONS): as you walk into a
-- region (Util/AbyssLayout.regionAt: the nearest island's) the cave's haze blends to that region's colours, and Volt's
-- lights (tagged DungeonFlicker by DungeonBuilder) flicker like a storm. Stands aside while a welcome or cinematic
-- plays (they darken the haze themselves). Dungeon place only.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeon = require(Shared:WaitForChild("Config"):WaitForChild("Dungeon"))
local AbyssLayout = require(Shared:WaitForChild("Util"):WaitForChild("AbyssLayout"))

local DungeonRegionController = {}

local CHECK_EVERY = 0.5
local BLEND = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local FLICKER = { every = 0.08, low = 0.3, high = 2.2, chance = 0.25 }
local TORCH = Dungeon.TORCH.flicker -- the braziers' gentle flicker (DungeonTorch)
local FADE = Dungeon.CAMERA_FADE -- gate seals and pillars see-through near the camera (DungeonCameraFade)

local player = Players.LocalPlayer
local islands = AbyssLayout.islands(Dungeon)
local current: string? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function check()
	if player:GetAttribute("DungeonIntroPlaying") == true then
		current = nil -- blend again once it ends
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if not root or not root:IsA("BasePart") or not air then
		return
	end
	local name = AbyssLayout.regionAt(islands, { x = root.Position.X, z = root.Position.Z })
	if name == current then
		return
	end
	current = name
	local haze = (Dungeon.REGIONS :: any)[name].haze
	TweenService:Create(air, BLEND, { Color = rgb(haze.color), Decay = rgb(haze.decay) }):Play()
end

function DungeonRegionController.Start()
	local since, flickerSince, torchSince, fadeSince = 0, 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		flickerSince += dt
		torchSince += dt
		fadeSince += dt
		if fadeSince >= FADE.every then
			fadeSince = 0
			local camera = workspace.CurrentCamera
			local eye = if camera then camera.CFrame.Position else Vector3.zero
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local me = if root and root:IsA("BasePart") then root.Position else eye
			for _, model in CollectionService:GetTagged("DungeonCameraFade") do
				if model:IsA("Model") then
					-- while you're inside its arena (every such gate is on its ring's -X side) and the camera is near it,
					-- whichever side the camera is on; walking up from the way in it shows shut
					local at = model:GetPivot().Position
					local near = me.X > at.X + 1 and (at - eye).Magnitude < FADE.within
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = if near then FADE.amount else 0
						end
					end
				end
			end
		end
		if torchSince >= TORCH.every then
			torchSince = 0
			for _, light in CollectionService:GetTagged("DungeonTorch") do
				if light:IsA("Light") and light.Enabled then
					light.Brightness = TORCH.low + math.random() * (TORCH.high - TORCH.low)
				end
			end
		end
		if since >= CHECK_EVERY then
			since = 0
			check()
		end
		if flickerSince >= FLICKER.every then
			flickerSince = 0
			for _, light in CollectionService:GetTagged("DungeonFlicker") do
				if light:IsA("Light") and math.random() < FLICKER.chance then
					light.Brightness = if math.random() < 0.5 then FLICKER.low else FLICKER.high
				end
			end
		end
	end)
end

return DungeonRegionController
