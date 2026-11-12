--!strict
-- How far this player can zoom out (Config/CameraLimits; owner 2026-11-12): MAX_ZOOM studs, BOSS_MAX_ZOOM while a boss
-- fight runs (Remotes.BattleStarted's boss; back at BattleEnded). Skill and boss cameras take the camera over on their
-- own and aren't limited by it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraLimits = require(Shared:WaitForChild("Config"):WaitForChild("CameraLimits"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CameraLimitController = {}

local player = Players.LocalPlayer

local function limit(studs: number)
	player.CameraMaxZoomDistance = math.max(studs, player.CameraMinZoomDistance)
end

function CameraLimitController.Start()
	limit(CameraLimits.MAX_ZOOM)
	Remotes.BattleStarted.OnClientEvent:Connect(function(payload: unknown)
		local boss = typeof(payload) == "table" and (payload :: any).boss ~= nil
		limit(if boss then CameraLimits.BOSS_MAX_ZOOM else CameraLimits.MAX_ZOOM)
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function()
		limit(CameraLimits.MAX_ZOOM)
	end)
end

return CameraLimitController
