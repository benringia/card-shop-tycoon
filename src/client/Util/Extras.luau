--!strict
-- Whether this client runs the town's moving extras (tree sway, animals, butterflies): the frame watchdog
-- (Util/FrameWatchdog) is happy and the player hasn't set a low graphics level (Config/Ambient WATCHDOG). Also whether
-- this player is in a boss fight (BattleController sets it): other players' auras and supers are drawn lighter then
-- (Config/BeastFx BUDGET, Config/WeaponLooks BUDGET, Config/SuperFx OTHERS_GRADE).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambient = require(Shared:WaitForChild("Config"):WaitForChild("Ambient"))
local FrameWatchdog = require(Shared:WaitForChild("Util"):WaitForChild("FrameWatchdog"))

local Extras = {}

local QUALITY_EVERY = 1 -- seconds between reads of the graphics level (auras ask every frame)

local watchdog = FrameWatchdog.new(Ambient.WATCHDOG)
RunService.Heartbeat:Connect(function(dt)
	watchdog:push(dt)
end)

local lowCached, lowReadAt = false, -math.huge
local inBossFight = false

local function lowGraphics(): boolean
	local now = os.clock()
	if now - lowReadAt < QUALITY_EVERY then
		return lowCached
	end
	lowReadAt = now
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	lowCached = ok and level ~= Enum.SavedQualitySetting.Automatic
		and (level :: Enum.SavedQualitySetting).Value <= Ambient.WATCHDOG.LOW_QUALITY
	return lowCached
end

function Extras.enabled(): boolean
	return watchdog.on and not lowGraphics()
end

-- Whether the player picked a low graphics level (not the watchdog): for cheap motion that should keep going through
-- the hitches of arriving somewhere new (the portals' swirls)
function Extras.lowGraphics(): boolean
	return lowGraphics()
end

-- This player's boss fight started or ended (BattleController)
function Extras.setBossFight(on: boolean)
	inBossFight = on
end

function Extras.bossFight(): boolean
	return inBossFight
end

return Extras
