--!strict
-- Whether this client runs the town's moving extras (tree sway, animals, butterflies): the frame watchdog
-- (Util/FrameWatchdog) is happy and the player hasn't set a low graphics level (Config/Ambient WATCHDOG).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambient = require(Shared:WaitForChild("Config"):WaitForChild("Ambient"))
local FrameWatchdog = require(Shared:WaitForChild("Util"):WaitForChild("FrameWatchdog"))

local Extras = {}

local watchdog = FrameWatchdog.new(Ambient.WATCHDOG)
RunService.Heartbeat:Connect(function(dt)
	watchdog:push(dt)
end)

local function lowGraphics(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return false
	end
	return (level :: Enum.SavedQualitySetting).Value <= Ambient.WATCHDOG.LOW_QUALITY
end

function Extras.enabled(): boolean
	return watchdog.on and not lowGraphics()
end

return Extras
