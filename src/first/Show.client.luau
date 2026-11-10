--!strict
-- The loading screen from the first frame (Config/LoadingScreen): a teleport's screen carries on as it arrived, else
-- a fresh one replaces Roblox's. Controllers/LoadingController sets the LocalPlayer attributes LoadingText,
-- LoadingShare, LoadingNote and LoadingDone as things load; this follows them and fades out when done. If the client
-- never says so, it fades after MAX_SECONDS anyway.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LoadingGui = require(script.Parent:WaitForChild("LoadingGui"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()

-- Roblox's own screen stays until the configs arrive (a moment): ours needs their words and pictures
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
local config = shared and shared:WaitForChild("Config", 10)
local cfgModule = config and config:WaitForChild("LoadingScreen", 10)
local artModule = config and config:WaitForChild("CardArt", 10)
if not cfgModule or not artModule or not cfgModule:IsA("ModuleScript") or not artModule:IsA("ModuleScript") then
	return
end
local cfg = require(cfgModule) :: any
local art = require(artModule) :: any

-- This place's look (Util/LoadingRules.look: the Frontier's own title, colours, picture and tips). Workspace's
-- PlaceKind attribute hasn't replicated this early, so the place id says first (Config/Places), the attribute after
local placesModule = config and config:WaitForChild("Places", 10)
local places = if placesModule and placesModule:IsA("ModuleScript") then require(placesModule) :: any else {}
local kindValue = workspace:GetAttribute("PlaceKind")
local kind = if game.PlaceId ~= 0 and game.PlaceId == places.FRONTIER_PLACE_ID then "Frontier"
	elseif game.PlaceId ~= 0 and game.PlaceId == places.DUNGEON_PLACE_ID then "Dungeon"
	elseif typeof(kindValue) == "string" then kindValue
	else "Main"
local util = shared and shared:WaitForChild("Util", 10)
local rulesModule = util and util:WaitForChild("LoadingRules", 10)
local look = if rulesModule and rulesModule:IsA("ModuleScript") then (require(rulesModule) :: any).look(cfg, kind) else cfg

local arriving = TeleportService:GetArrivingTeleportGui()
local gui: ScreenGui
if arriving and arriving:IsA("ScreenGui") then
	gui = arriving
else
	local images = {}
	for _, name in look.FAN_CARDS do
		table.insert(images, art.SMALL[name] or art.FULL[name] or "")
	end
	gui = LoadingGui.build(look, images, look.FIRST_STEP[kind] or look.STEPS[1])
end
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
local stop = LoadingGui.animate(gui, look)

local function refresh()
	local text = player:GetAttribute("LoadingText")
	local share = player:GetAttribute("LoadingShare")
	local note = player:GetAttribute("LoadingNote")
	if typeof(text) == "string" and typeof(share) == "number" then
		LoadingGui.set(gui, text, share, if typeof(note) == "string" then note else "")
	end
end
local changed = player.AttributeChanged:Connect(function(name)
	if name == "LoadingText" or name == "LoadingShare" or name == "LoadingNote" then
		refresh()
	end
end)
refresh()

while player:GetAttribute("LoadingDone") ~= true and os.clock() - started < cfg.MAX_SECONDS do
	task.wait(0.1)
end
changed:Disconnect()
stop()
LoadingGui.fadeOut(gui, cfg.FADE_SECONDS)
