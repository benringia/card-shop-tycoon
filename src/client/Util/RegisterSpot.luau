--!strict
-- Your own plot's register and whether you stand at it: the offer panel shows only there and manning the register
-- needs it (RegisterController, RegisterStationController)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegisterConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Register"))

local RegisterSpot = {}

function RegisterSpot.register(player: Player): BasePart?
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	local register = if plot then plot:FindFirstChild("Register", true) else nil
	return if register and register:IsA("BasePart") then register else nil
end

function RegisterSpot.at(player: Player): boolean
	local register = RegisterSpot.register(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return register ~= nil and root ~= nil and (root.Position - register.Position).Magnitude <= RegisterConfig.REACH
end

return RegisterSpot
