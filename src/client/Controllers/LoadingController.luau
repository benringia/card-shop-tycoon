--!strict
-- Drives the loading screen (ReplicatedFirst/LoadingScreen, Config/LoadingScreen): tracks the character, the save (the
-- server's DataLoaded attribute) and your own cards' paintings (kept drawn here, tiny, so binder pages show every face
-- the moment they turn), the summoned creature (CreatureController's CreatureReady, or no creature summoned)
-- and the fight gear (Util/CombatAssets, downloaded now), plus the shop's first pictures (round 4: the product models
-- with their maps, every UI icon, pack fronts, the mascot stickers, binder covers and level-up textures; a failed one
-- counts as done), and writes the step to LocalPlayer attributes the screen
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
local UIIcons = require(Config:WaitForChild("UIIcons"))
local Packs = require(Config:WaitForChild("Packs"))
local HudMascot = require(Config:WaitForChild("HudMascot"))
local BinderCovers = require(Config:WaitForChild("BinderCovers"))
local LevelUpFx = require(Config:WaitForChild("LevelUpFx"))
local LoadingRules = require(Shared:WaitForChild("Util"):WaitForChild("LoadingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CombatAssets = require(ClientUtil:WaitForChild("CombatAssets"))
local ProductPicture = require(ClientUtil:WaitForChild("ProductPicture"))

local player = Players.LocalPlayer
local started = os.clock()

local LoadingController = {}

local gearReady = false
local shopReady = false
local artReady = false
local artStarted = false
local artCache: ScreenGui? = nil
local artLabels: { [string]: ImageLabel } = {}
local nothingSummoned = false -- the party says no creature is summoned: nothing to wait for

-- One picture kept drawn for the session, tiny and nearly invisible in a corner (like Util/Icon): Roblox only gets an
-- image ready once something draws it (preloading it by id isn't enough), and a face turned onto a page then shows it
-- at once
local function keepDrawn(image: string): ImageLabel
	local existing = artLabels[image]
	if existing then
		return existing
	end
	if not artCache then
		local cache = Instance.new("ScreenGui")
		cache.Name = "CardArtCache"
		cache.ResetOnSpawn = false
		cache.DisplayOrder = -10
		cache.Parent = player:WaitForChild("PlayerGui")
		artCache = cache
	end
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(2, 2)
	label.Image = image
	label.ImageTransparency = 0.98
	label.Parent = artCache
	artLabels[image] = label
	return label
end

-- Your cards' small paintings (the binder, shelves and cases draw them) and the face backdrops, kept drawn from the
-- first collection the server sends (and any card you get later); the loading screen waits until they're ready
local function preloadArt(payload: any)
	local labels = { keepDrawn(CardDesign.IMAGES.GLOW) }
	for _, id in CardDesign.SCENES do
		table.insert(labels, keepDrawn(id))
	end
	for _, cardId in LoadingRules.ownedCardIds(payload) do
		local card = Cards.ById[cardId]
		local art = if card then CardArt.SMALL[card.name] or CardArt.FULL[card.name] else nil
		if art and art ~= "" then
			table.insert(labels, keepDrawn(art))
		end
	end
	if artStarted then
		return
	end
	artStarted = true
	task.spawn(function()
		while os.clock() - started < LoadingScreen.MAX_SECONDS do
			local pending = false
			for _, label in labels do
				if not label.IsLoaded then
					pending = true
					break
				end
			end
			if not pending then
				break
			end
			task.wait(0.1)
		end
		artReady = true
	end)
end

-- The shop's first pictures: the pack, deck box and display box models (meshes and every look's maps), every UI icon,
-- the pack fronts, the mascot stickers, the binder covers and the level-up textures. Images are kept drawn (a picture
-- is only ready once something draws it); PreloadAsync reports each fetch, and a failed or timed-out one counts as
-- done (LoadingRules.settled). Then every product picture redraws.
local function preloadShop()
	local items: { any } = {}
	-- The whole folder: its meshes and every look's SurfaceAppearance (game scripts can't read a SurfaceAppearance's
	-- maps, but preloading the instance fetches them)
	local packModels = ReplicatedStorage:FindFirstChild("PackModels")
	if packModels then
		table.insert(items, packModels)
	end
	local images: { string } = {}
	for _, id in UIIcons do
		table.insert(images, id)
	end
	for _, pack in Packs.ById do
		if pack.art then
			table.insert(images, pack.art)
		end
	end
	for _, id in HudMascot.images do
		table.insert(images, id)
	end
	for _, cover in BinderCovers.SETS do
		table.insert(images, cover.art)
	end
	for _, id in LevelUpFx.IMAGES do
		table.insert(images, id)
	end
	for _, image in images do
		if typeof(image) == "string" and string.sub(image, 1, 13) == "rbxassetid://" then
			table.insert(items, keepDrawn(image))
		end
	end
	local statuses: { [string]: string } = {}
	ContentProvider:PreloadAsync(items, function(content: string, status: Enum.AssetFetchStatus)
		statuses[content] = status.Name
	end)
	-- PreloadAsync returns once each fetch has finished; wait out any that hasn't (to MAX_SECONDS)
	while os.clock() - started < LoadingScreen.MAX_SECONDS do
		local list: { string } = {}
		for _, status in statuses do
			table.insert(list, status)
		end
		if LoadingRules.settled(list) then
			break
		end
		task.wait(0.1)
	end
	shopReady = true
	ProductPicture.redrawAll()
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
		-- Whatever goes wrong, the step finishes: nothing may hold the screen for MAX_SECONDS
		local ok, err = pcall(preloadShop)
		if not ok then
			warn("[LoadingController] shop pictures:", err)
		end
		shopReady = true
	end)
	task.spawn(function()
		local kind = workspace:GetAttribute("PlaceKind")
		local placeKind = if typeof(kind) == "string" then kind else "Main"
		while true do
			local status: LoadingRules.Status = {
				character = game:IsLoaded() and player.Character ~= nil,
				data = player:GetAttribute("DataLoaded") == true,
				art = artReady,
				shop = shopReady,
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
