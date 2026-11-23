--!strict
-- A teleport's loading screen the moment it starts (owner 2026-11-23: "when teleporting to frontier, there is a few
-- seconds delay before the loading screen to frontier appears which caused the player confusions"). The server says a
-- teleport is starting (Remotes.Departing, naming the place it goes to) before the save's hand-off and the teleport
-- itself, which take a few seconds before Roblox shows its own copy of the screen. The same binder goes up here at once,
-- and that place's look is handed to TeleportService too, so the copy Roblox shows and the next place carries on are
-- the same screen (from the Frontier: the Dungeon's look for the Dungeon, the shops' for home). nil takes it down (the
-- teleport failed, or Studio, which can't teleport), and so does a teleport that never comes (Places.DEPARTURE).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local LoadingScreen = require(Config:WaitForChild("LoadingScreen"))
local Places = require(Config:WaitForChild("Places"))
local LoadingRules = require(Shared:WaitForChild("Util"):WaitForChild("LoadingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LoadingGui = require(ReplicatedFirst:WaitForChild("LoadingScreen"):WaitForChild("LoadingGui")) :: any

local Controllers = script.Parent :: Instance
local UIController = require(Controllers:WaitForChild("UIController"))

local DepartureController = {}

local KINDS = { Main = true, Frontier = true, Dungeon = true }
local player = Players.LocalPlayer
local shown: { gui: ScreenGui, stop: () -> () }? = nil

local function takeDown()
	local current = shown
	if not current then
		return
	end
	shown = nil
	current.stop()
	LoadingGui.fadeOut(current.gui, LoadingScreen.FADE_SECONDS)
end

local function depart(kind: unknown)
	takeDown()
	if typeof(kind) ~= "string" or not KINDS[kind] then
		return
	end
	local look = LoadingRules.look(LoadingScreen, kind)
	local first = LoadingRules.stepText(1, kind, look)
	-- the copy Roblox shows once the teleport starts: where this one goes, not this place's usual destination
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(LoadingGui.build(look, first))
	end)
	if not ok then
		warn("[DepartureController] no teleport screen:", err)
	end
	local gui = LoadingGui.build(look, first)
	gui.Name = "Departure"
	gui.Parent = player:WaitForChild("PlayerGui")
	local mine = { gui = gui, stop = LoadingGui.animate(gui, look) }
	shown = mine
	task.delay(Places.DEPARTURE.MAX_SECONDS, function()
		if shown == mine then
			takeDown()
			UIController.Notify(Places.DEPARTURE.FAILED, true, 3)
		end
	end)
end

function DepartureController.Start()
	Remotes.Departing.OnClientEvent:Connect(depart)
end

return DepartureController
