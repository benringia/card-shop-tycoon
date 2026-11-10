--!strict
-- Drives the loading screen (ReplicatedFirst/LoadingScreen, Config/LoadingScreen): tracks the character, the save (the
-- server's DataLoaded attribute) and your own cards' paintings (kept drawn here, tiny, so binder pages show every face
-- the moment they turn), the summoned creature (CreatureController's CreatureReady, or no creature summoned) and your
-- own cards' and the town animals' models (CreatureVisuals' TownCreaturesReady), the fight gear (Util/CombatAssets,
-- downloaded now), plus the
-- town's first pictures and models (round 4, and owner 2026-11-09 "same with in town. make sure models and weapon
-- effects are ready": the product, prop and place-prop models with their maps, Util/TownPreload's pictures; a failed
-- one counts as done), and writes the step to LocalPlayer attributes the screen
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
local ProductPictures = require(Config:WaitForChild("ProductPictures"))
local PackFx = require(Config:WaitForChild("PackFx"))
local Town = require(Config:WaitForChild("Town"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local TownPreload = require(Shared:WaitForChild("Util"):WaitForChild("TownPreload"))
local LoadingRules = require(Shared:WaitForChild("Util"):WaitForChild("LoadingRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CombatAssets = require(ClientUtil:WaitForChild("CombatAssets"))

local player = Players.LocalPlayer
local started = os.clock()

local LoadingController = {}

local gearReady = false
local shopReady = false
local townReady = false
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

-- The town's first pictures and models: the pack, deck box and display box models (meshes and every look's maps: the
-- shelves and the opening stage draw them), the weapon models, the shop props' and place props' models (plots and
-- placement ghosts), and Util/TownPreload's pictures (every UI icon, the pack fronts, the menus' product pictures, the
-- mascot stickers, the binder covers, the level-up textures, the pack opening's effects, the portals' textures, the
-- weapons' portraits). Images are kept drawn (a picture is only ready once something draws it); PreloadAsync reports
-- each fetch, and a failed or timed-out one counts as done (LoadingRules.settled).
local function preloadShop()
	local items: { any } = {}
	-- Whole folders: their meshes and every look's SurfaceAppearance (game scripts can't read a SurfaceAppearance's maps,
	-- but preloading the instance fetches them). The weapons' colours and glow maps are SurfaceAppearances too, so a
	-- freshly cloned sword (on the back, the drop and forge reveals) would show untextured until they're fetched
	for _, name in { "PackModels", "WeaponModels", "PropModels", "PlaceProps" } do
		local folder = ReplicatedStorage:FindFirstChild(name)
		if folder then
			table.insert(items, folder)
		end
	end
	local images = TownPreload.images({
		uiIcons = UIIcons,
		packs = Packs,
		hudMascot = HudMascot,
		binderCovers = BinderCovers,
		levelUpFx = LevelUpFx,
		productPictures = ProductPictures,
		packFx = PackFx,
		town = Town,
		weaponLooks = WeaponLooks,
	})
	for _, image in images do
		table.insert(items, keepDrawn(image))
	end
	-- The level-up sounds (round 5), so the first level-up isn't silent while they fetch: as Sound instances (an asset id
	-- given as a string reports Failure and fetches nothing)
	for _, set in LevelUpFx.SOUNDS.sets do
		for _, part in { set.sound, set.sting } do
			local sound = Instance.new("Sound")
			sound.SoundId = part.id
			table.insert(items, sound)
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
end

-- The town round you (Config/LoadingScreen TOWN_FOLDERS; owner 2026-11-09: "in town. some models still load some time
-- after the loading screen"): Roblox fetches a mesh only once it's drawn up close, so scenery popped in as you walked.
-- The area round your character is streamed in, then every town folder's meshes, textures and looks are fetched
local function preloadTown()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", LoadingScreen.STREAM_TIMEOUT)
	if root and root:IsA("BasePart") then
		pcall(player.RequestStreamAroundAsync, player, root.Position, LoadingScreen.STREAM_TIMEOUT)
	end
	local folders: { Instance } = {}
	for _, name in LoadingScreen.TOWN_FOLDERS do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(folders, folder)
		end
	end
	ContentProvider:PreloadAsync(folders)
end

-- Anything that streams in later (the far side of town, a plot's new props, customers, the Wild): its meshes, textures
-- and looks fetched as it arrives, a batch every WARM_GAP seconds, not when the camera first comes close
local WARM_GAP = 0.5
local function warmStreamed()
	local queue: { Instance } = {}
	workspace.DescendantAdded:Connect(function(item)
		if item:IsA("MeshPart") or item:IsA("SurfaceAppearance") or item:IsA("Decal") or item:IsA("SpecialMesh") then
			table.insert(queue, item)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WARM_GAP)
			if #queue > 0 then
				local batch = queue
				queue = {}
				pcall(ContentProvider.PreloadAsync, ContentProvider, batch)
			end
		end
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
	-- the look of where this place's teleports go (the main game's: the Frontier's)
	local here = if Place.isFrontier() then "Frontier" elseif Place.isDungeon() then "Dungeon" else "Main"
	local screen = LoadingRules.look(LoadingScreen, LoadingRules.teleportLook(here) or "Main")
	local images = {}
	for _, name in screen.FAN_CARDS do
		table.insert(images, CardArt.SMALL[name] or CardArt.FULL[name] or "")
	end
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(LoadingGui.build(screen, images, screen.STEPS[1]))
	end)
	if not ok then
		warn("[LoadingController] no teleport screen:", err)
	end
end

function LoadingController.Start()
	setTeleportScreen()
	warmStreamed()
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
		local ok, err = pcall(preloadTown)
		if not ok then
			warn("[LoadingController] town:", err)
		end
		townReady = true
	end)
	task.spawn(function()
		local placeKind = if Place.isFrontier() then "Frontier" elseif Place.isDungeon() then "Dungeon" else "Main"
		local screen = LoadingRules.look(LoadingScreen, placeKind)
		-- The Frontier's valley round you (spec 2026-11-10-frontier-valley-design): its terrain filled and its scenery in
		local valley = if placeKind == "Frontier" then Place.getValley() else nil
		local function valleyReady(): boolean?
			if not valley then
				return nil
			end
			return workspace:GetAttribute(valley.TERRAIN_READY_ATTRIBUTE) == true and workspace:FindFirstChild("Scenery") ~= nil
		end
		while true do
			local status: LoadingRules.Status = {
				character = game:IsLoaded() and player.Character ~= nil,
				data = player:GetAttribute("DataLoaded") == true,
				art = artReady,
				shop = shopReady and townReady,
				creature = (player:GetAttribute("CreatureReady") == true or nothingSummoned)
					and player:GetAttribute("TownCreaturesReady") == true,
				gear = gearReady,
				valley = valleyReady(),
			}
			local step, share, done, slow = LoadingRules.progress(status, os.clock() - started, screen)
			player:SetAttribute("LoadingText", LoadingRules.stepText(step, placeKind, screen))
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
