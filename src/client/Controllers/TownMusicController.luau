--!strict
-- Gentle background music in the town (owner 2026-11-04; Config/Music TOWN, Util/MusicRules), playing along with the
-- scenery's birds, wind and waterfall: two soft underscores take turns with a little quiet between them, fading out
-- when you leave the town (the Wild valley, a boss arena) and back in when you return. Started in the main place only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Music = require(Shared:WaitForChild("Config"):WaitForChild("Music"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))

local TownMusicController = {}

local CFG = Music.TOWN

function TownMusicController.Start()
	local sound = Instance.new("Sound")
	sound.Name = "TownMusic"
	sound.Volume = 0
	sound.Parent = SoundService
	local track = 0
	local inTown = false
	local fade: Tween? = nil

	local function fadeTo(volume: number)
		if fade then
			fade:Cancel()
		end
		local tween = TweenService:Create(sound, TweenInfo.new(CFG.fade, Enum.EasingStyle.Sine), { Volume = volume })
		fade = tween
		tween:Play()
	end

	local function playNext()
		track = MusicRules.nextTrack(track, #CFG.tracks)
		sound.SoundId = CFG.tracks[track]
		sound.TimePosition = 0
		sound:Play()
	end

	sound.Ended:Connect(function()
		task.delay(CFG.gap, playNext)
	end)

	task.spawn(function()
		while true do
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local here = root ~= nil and root:IsA("BasePart")
				and MusicRules.inTown(root.Position.X, root.Position.Z, Town.BOUNDS, CFG.margin)
			if here ~= inTown then
				inTown = here
				fadeTo(if here then CFG.volume else 0)
			end
			task.wait(CFG.checkEvery)
		end
	end)
	playNext()
end

return TownMusicController
