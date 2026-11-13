--!strict
-- The loading screen from the first frame: the binder (Config/LoadingScreen, LoadingGui). A teleport's screen covers the
-- gap while the configs arrive, then a fresh one in this place's look takes over (the copy carried another place's
-- painting and colours). Controllers/LoadingController sets the LocalPlayer attributes LoadingText, LoadingPockets,
-- LoadingNote and LoadingDone as things load; this follows them, shows "Ready!" a moment once the last card is in,
-- and fades out. If the client never says so, it fades after MAX_SECONDS anyway.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LoadingGui = require(script.Parent:WaitForChild("LoadingGui"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()

-- A teleport's screen, shown at once while this place's configs arrive
local arriving = TeleportService:GetArrivingTeleportGui()
if arriving and arriving:IsA("ScreenGui") then
	arriving.Parent = playerGui
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end

-- Roblox's own screen (or the teleport's) stays until the configs arrive (a moment): ours needs their words and pictures
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
local config = shared and shared:WaitForChild("Config", 10)
local cfgModule = config and config:WaitForChild("LoadingScreen", 10)
local util = shared and shared:WaitForChild("Util", 10)
local rulesModule = util and util:WaitForChild("LoadingRules", 10)
if not cfgModule or not cfgModule:IsA("ModuleScript") or not rulesModule or not rulesModule:IsA("ModuleScript") then
	return
end
local cfg = require(cfgModule) :: any
local rules = require(rulesModule) :: any

-- This place's look. Workspace's PlaceKind attribute hasn't replicated this early, so the place id says first
-- (Config/Places), the attribute after
local placesModule = config and config:WaitForChild("Places", 10)
local places = if placesModule and placesModule:IsA("ModuleScript") then require(placesModule) :: any else {}
local kindValue = workspace:GetAttribute("PlaceKind")
local kind = if game.PlaceId ~= 0 and game.PlaceId == places.FRONTIER_PLACE_ID then "Frontier"
	elseif game.PlaceId ~= 0 and game.PlaceId == places.DUNGEON_PLACE_ID then "Dungeon"
	elseif typeof(kindValue) == "string" then kindValue
	else "Main"
local look = rules.look(cfg, kind)

local gui = LoadingGui.build(look, rules.stepText(1, kind, look))
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
if arriving and arriving:IsA("ScreenGui") then
	arriving:Destroy() -- only once the fresh one covers the screen
end
-- The screen's own pictures (the world's painting, the nine cards) fetched first; never waited on
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { gui })
end)
local stop = LoadingGui.animate(gui, look)

local function refresh()
	local text = player:GetAttribute("LoadingText")
	local pockets = player:GetAttribute("LoadingPockets")
	local note = player:GetAttribute("LoadingNote")
	if typeof(text) == "string" and typeof(pockets) == "number" then
		LoadingGui.set(gui, text, pockets, if typeof(note) == "string" then note else "")
	end
end
local changed = player.AttributeChanged:Connect(function(name)
	if name == "LoadingText" or name == "LoadingPockets" or name == "LoadingNote" then
		refresh()
	end
end)
refresh()

while player:GetAttribute("LoadingDone") ~= true and os.clock() - started < cfg.MAX_SECONDS do
	task.wait(0.1)
end
changed:Disconnect()
if player:GetAttribute("LoadingDone") ~= true then
	LoadingGui.set(gui, cfg.READY, cfg.POCKETS, "") -- out of time: in with what's loaded
else
	refresh()
end
-- the last cards land, "Ready!" a moment, then away
task.wait(LoadingGui.settleSeconds(gui) + cfg.READY_HOLD)
stop()
LoadingGui.fadeOut(gui, cfg.FADE_SECONDS)
