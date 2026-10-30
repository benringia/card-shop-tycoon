--!strict
-- The town's day cycle on this client (Portal Worlds spec): from the server's start time (workspace attribute
-- DayCycleStart, set by TownService in the main game only), the blended look for now (Util/DayCycle), applied a few
-- times a second. Outside the town (the Wild, the Arena, the boss arenas) the fixed afternoon look shows at once.
-- Nothing is replicated: every client works the same time out from the server clock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cycle = require(Shared:WaitForChild("Config"):WaitForChild("DayCycle"))
local SharedUtil = Shared:WaitForChild("Util")
local DayCycle = require(SharedUtil:WaitForChild("DayCycle"))
local SkyLook = require(SharedUtil:WaitForChild("SkyLook"))

local DayCycleController = {}

function DayCycleController.Start()
	local elapsed = math.huge
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / Cycle.UPDATE_HZ then
			return
		end
		elapsed = 0
		local start = workspace:GetAttribute("DayCycleStart")
		if typeof(start) ~= "number" or SkyLook.isHeld() then
			return
		end
		-- Where the player is (the camera's focus while they have no character)
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local at = if root and root:IsA("BasePart") then root.Position else workspace.CurrentCamera.Focus.Position
		if DayCycle.inTown(Cycle, at.X, at.Z) then
			SkyLook.apply(DayCycle.lookAt(Cycle, workspace:GetServerTimeNow() - start))
		else
			SkyLook.apply(DayCycle.fixedLook(Cycle))
		end
	end)
end

return DayCycleController
