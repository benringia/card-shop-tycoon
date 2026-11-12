--!strict
-- A fall into the Crystal Abyss's chasm (spec 2026-11-12-dungeon-world), on this player's screen: once they drop
-- ABYSS.FALL_FX_ABOVE studs above the kill height, a yell and the rush of air, and the screen fades to black. The
-- server decides the fall (DungeonService sets them back on the ledge and marks them out of the run); the black lifts
-- once they're back above it. Never during the Hydra's welcome.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeon = require(Shared:WaitForChild("Config"):WaitForChild("Dungeon"))

local DungeonFallController = {}

local ABYSS = Dungeon.ABYSS
local FADE_IN = 0.8
local FADE_OUT = 1.2
local SOUND_TIMEOUT = 10

local player = Players.LocalPlayer
local falling = false
local cover: Frame

local function playOnce(key: string)
	local spec = (Dungeon.SOUNDS :: any)[key]
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.PlaybackSpeed = spec.pitch or 1
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(SOUND_TIMEOUT, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	sound:Play()
end

local function check()
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local low = root.Position.Y < ABYSS.KILL_Y + ABYSS.FALL_FX_ABOVE
	if low and not falling and player:GetAttribute("DungeonIntroPlaying") ~= true then
		falling = true
		playOnce("fall")
		playOnce("fallWind")
		TweenService:Create(cover, TweenInfo.new(FADE_IN), { BackgroundTransparency = 0 }):Play()
	elseif not low and falling then
		falling = false -- set back down (the ledge): the black lifts
		TweenService:Create(cover, TweenInfo.new(FADE_OUT), { BackgroundTransparency = 1 }):Play()
	end
end

function DungeonFallController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DungeonFall"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60 -- over the HUD and the welcome's overlay
	gui.ResetOnSpawn = false
	cover = Instance.new("Frame")
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.Active = false
	cover.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	RunService.Heartbeat:Connect(check)
end

return DungeonFallController
