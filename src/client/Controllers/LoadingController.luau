--!strict
-- Drives the loading screen (ReplicatedFirst/LoadingScreen, Config/LoadingScreen): tracks the character, the save (the
-- server's DataLoaded attribute) and your own cards' paintings (downloaded here, so the binder opens with every face
-- drawn), the summoned creature (CreatureController's CreatureReady, or no creature summoned)
-- and the fight gear (Util/CombatAssets, downloaded now), and writes the step to LocalPlayer attributes the screen
-- follows (LoadingText, LoadingShare, LoadingNote, LoadingDone). Also hands TeleportService a copy of the screen, so
-- teleports to and from the Frontier and the Dungeon show it too.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardArt = require(Config:WaitForChild("CardArt"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Cards = require(Config:WaitForChild("Cards"))
local LoadingScreen = require(Config:WaitForChild("LoadingScreen"))
local LoadingRules = require(Shared:WaitForChild("Util"):WaitForChild("LoadingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CombatAssets = require(ClientUtil:WaitForChild("CombatAssets"))

local player = Players.LocalPlayer
local started = os.clock()

local LoadingController = {}

local gearReady = false
local artReady = false
local artStarted = false
local nothingSummoned = false -- the party says no creature is summoned: nothing to wait for

-- Your cards' small paintings (the binder, shelves and cases draw them) and the face backdrops, downloaded once the
-- server first sends the collection
local function preloadArt(payload: any)
	if artStarted then
		return
	end
	artStarted = true
	task.spawn(function()
		local images = { CardDesign.IMAGES.GLOW }
		for _, id in CardDesign.SCENES do
			table.insert(images, id)
		end
		for _, cardId in LoadingRules.ownedCardIds(payload) do
			local card = Cards.ById[cardId]
			local art = if card then CardArt.SMALL[card.name] or CardArt.FULL[card.name] else nil
			if art and art ~= "" then
				table.insert(images, art)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, images)
		artReady = true
	end)
end

-- A copy of the screen at its first step for teleports (the next place's loading screen carries it on)
local function setTeleportScreen()
	local folder = ReplicatedFirst:FindFirstChild("LoadingScreen")
	local builder = folder and folder:FindFirstChild("LoadingGui")
	if not builder or not builder:IsA("ModuleScript") then
		return
	end
	local LoadingGui = require(builder) :: any
	local images = {}
	for _, name in LoadingScreen.FAN_CARDS do
		table.insert(images, CardArt.SMALL[name] or CardArt.FULL[name] or "")
	end
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(LoadingGui.build(LoadingScreen, images, LoadingScreen.STEPS[1]))
	end)
	if not ok then
		warn("[LoadingController] no teleport screen:", err)
	end
end

function LoadingController.Start()
	setTeleportScreen()
	if player:GetAttribute("LoadingDone") == true then
		return -- already shown this session
	end
	Remotes.CollectionChanged.OnClientEvent:Connect(preloadArt)
	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			nothingSummoned = payload.summoned == nil
		end
	end)
	task.spawn(function()
		CombatAssets.preload()
		gearReady = true
	end)
	task.spawn(function()
		local kind = workspace:GetAttribute("PlaceKind")
		local placeKind = if typeof(kind) == "string" then kind else "Main"
		while true do
			local status: LoadingRules.Status = {
				character = game:IsLoaded() and player.Character ~= nil,
				data = player:GetAttribute("DataLoaded") == true,
				art = artReady,
				creature = player:GetAttribute("CreatureReady") == true or nothingSummoned,
				gear = gearReady,
			}
			local step, share, done, slow = LoadingRules.progress(status, os.clock() - started, LoadingScreen)
			player:SetAttribute("LoadingText", LoadingRules.stepText(step, placeKind, LoadingScreen))
			player:SetAttribute("LoadingShare", share)
			player:SetAttribute("LoadingNote", if slow then LoadingScreen.SLOW_NOTE else "")
			if done then
				player:SetAttribute("LoadingDone", true)
				return
			end
			task.wait(0.1)
		end
	end)
end

return LoadingController
