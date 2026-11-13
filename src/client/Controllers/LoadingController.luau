--!strict
-- Drives the loading screen (ReplicatedFirst/LoadingScreen, Config/LoadingScreen): tracks the character, the save (the
-- server's DataLoaded attribute) and your own cards' paintings (kept drawn here, tiny, so binder pages show every face
-- the moment they turn), the summoned creature (CreatureController's CreatureReady, or no creature summoned) and your
-- own cards' and the town animals' models (CreatureVisuals' TownCreaturesReady), the fight gear (Util/CombatAssets,
-- downloaded now), plus the
-- town's first pictures and models (round 4, and owner 2026-11-09 "same with in town. make sure models and weapon
-- effects are ready": the product, prop and place-prop models with their maps, Util/TownPreload's pictures; a failed
-- one counts as done), the Frontier's valley and the Dungeon's cavern, and writes the step to LocalPlayer attributes
-- the screen follows (LoadingText, LoadingShare, LoadingPockets, LoadingNote, LoadingDone). Holds your character still
-- until it's done (spec 2026-11-13-loading-screen-binder-design). Also hands TeleportService a copy of the screen, so
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
local WildLoading = require(Config:WaitForChild("WildLoading"))
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
local held: { BasePart } = {} -- the roots this held still while loading

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

-- The Frontier's valley round you (spec 2026-11-10-frontier-valley-design; final review): once the server has filled
-- its terrain and built its scenery, the area round your character is streamed in and the scenery's meshes, textures
-- and looks fetched, so the camp's tents, rocks and portals don't pop in after the screen lifts
local function preloadValley(valley: any)
	local ready = valley.TERRAIN_READY_ATTRIBUTE
	local deadline = os.clock() + LoadingScreen.MAX_SECONDS
	while not (workspace:GetAttribute(ready) == true and workspace:FindFirstChild("Scenery")) and os.clock() < deadline do
		task.wait(0.25)
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", LoadingScreen.STREAM_TIMEOUT)
	if root and root:IsA("BasePart") then
		pcall(player.RequestStreamAroundAsync, player, root.Position, LoadingScreen.STREAM_TIMEOUT)
	end
	local scenery = workspace:FindFirstChild("Scenery")
	if scenery then
		ContentProvider:PreloadAsync({ scenery })
	end
end

-- The Dungeon's cavern (Config/LoadingScreen CAVERN): once the server has built its world, the area round your
-- character streamed in, ground found under you and the world's meshes, textures and looks fetched, so the islands,
-- bridges and crystals don't pop in after the screen lifts
local function preloadCavern()
	local cavern = LoadingScreen.CAVERN
	local deadline = os.clock() + LoadingScreen.MAX_SECONDS
	local world = workspace:FindFirstChild(cavern.FOLDER)
	while not world and os.clock() < deadline do
		task.wait(0.25)
		world = workspace:FindFirstChild(cavern.FOLDER)
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", LoadingScreen.STREAM_TIMEOUT)
	if root and root:IsA("BasePart") then
		pcall(player.RequestStreamAroundAsync, player, root.Position, LoadingScreen.STREAM_TIMEOUT)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		while not workspace:Raycast(root.Position, Vector3.new(0, -cavern.GROUND_DEPTH, 0), params) and os.clock() < deadline do
			task.wait(0.1)
		end
	end
	if world then
		ContentProvider:PreloadAsync({ world })
	end
end

-- Held still while the screen is up (your root anchored on your device, which moves your character), so nobody walks
-- off under it; a character that respawns meanwhile is held too
local function hold(character: Model)
	if player:GetAttribute("LoadingDone") == true then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", LoadingScreen.STREAM_TIMEOUT)
	if root and root:IsA("BasePart") and not root.Anchored and player:GetAttribute("LoadingDone") ~= true then
		root.Anchored = true
		table.insert(held, root)
	end
end

-- Lets you walk: only the roots this held, if they're still there
local function release()
	for _, root in held do
		if root.Parent then
			root.Anchored = false
		end
	end
	table.clear(held)
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

-- The binder's builder (ReplicatedFirst/LoadingScreen/LoadingGui)
local function loadingGui(): any?
	local folder = ReplicatedFirst:FindFirstChild("LoadingScreen")
	local builder = folder and folder:FindFirstChild("LoadingGui")
	return if builder and builder:IsA("ModuleScript") then require(builder) :: any else nil
end

-- A copy of the screen at its first step for teleports (the next place's loading screen carries it on)
local function setTeleportScreen()
	local LoadingGui = loadingGui()
	if not LoadingGui then
		return
	end
	-- the look of where this place's teleports go (the main game's: the Frontier's)
	local here = if Place.isFrontier() then "Frontier" elseif Place.isDungeon() then "Dungeon" else "Main"
	local there = LoadingRules.teleportLook(here) or "Main"
	local screen = LoadingRules.look(LoadingScreen, there)
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(LoadingGui.build(screen, LoadingRules.stepText(1, there, screen)))
	end)
	if not ok then
		warn("[LoadingController] no teleport screen:", err)
	end
end

-- Studio's "/loading <main|wild|frontier|dungeon>" (DevService sets LoadingPreview): that place's loading screen,
-- a step a second with nothing loading, then "Ready!" and away, to judge each look without travelling
local PREVIEW_KINDS = { main = "Main", wild = "Wild", frontier = "Frontier", dungeon = "Dungeon" }
local function preview()
	local value = player:GetAttribute("LoadingPreview")
	local kind = if typeof(value) == "string" then PREVIEW_KINDS[string.match(value, "^(%a+)") or ""] else nil
	local LoadingGui = loadingGui()
	if not kind or not LoadingGui then
		return
	end
	local look = LoadingRules.look(LoadingScreen, kind)
	local wild = kind == "Wild"
	local steps = if wild then WildLoading.STEPS else look.STEPS
	local ready = if wild then WildLoading.READY else look.READY
	local first = if wild then steps[1] else LoadingRules.stepText(1, kind, look)
	local gui = LoadingGui.build(look, first)
	gui.Name = "LoadingPreview"
	gui.Parent = player:WaitForChild("PlayerGui")
	local stop = LoadingGui.animate(gui, look)
	for step = 1, #steps + 1 do
		local done = step > #steps
		local text = if done then ready elseif step == 1 then first else steps[step]
		LoadingGui.set(gui, text, LoadingRules.pockets((step - 1) / #steps, done, look.POCKETS), "")
		task.wait(1)
	end
	task.wait(LoadingGui.settleSeconds(gui) + look.READY_HOLD)
	stop()
	LoadingGui.fadeOut(gui, look.FADE_SECONDS)
end

function LoadingController.Start()
	player:GetAttributeChangedSignal("LoadingPreview"):Connect(function()
		task.spawn(preview)
	end)
	setTeleportScreen()
	warmStreamed()
	if player:GetAttribute("LoadingDone") == true then
		return -- already shown this session
	end
	if player.Character then
		task.spawn(hold, player.Character)
	end
	player.CharacterAdded:Connect(hold)
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
		-- The Frontier's valley round you: its terrain filled, the area round you streamed and its scenery fetched
		local valley = if placeKind == "Frontier" then Place.getValley() else nil
		local valleyLoaded = false
		if valley then
			task.spawn(function()
				-- whatever goes wrong, the step finishes (as the shop's and the town's)
				local ok, err = pcall(preloadValley, valley)
				if not ok then
					warn("[LoadingController] valley:", err)
				end
				valleyLoaded = true
			end)
		end
		local function valleyReady(): boolean?
			return if valley then valleyLoaded else nil
		end
		-- The Dungeon's cavern round you
		local cavernLoaded: boolean? = nil
		if placeKind == "Dungeon" then
			cavernLoaded = false
			task.spawn(function()
				local ok, err = pcall(preloadCavern)
				if not ok then
					warn("[LoadingController] cavern:", err)
				end
				cavernLoaded = true
			end)
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
				cavern = cavernLoaded,
			}
			local step, share, done, slow = LoadingRules.progress(status, os.clock() - started, screen)
			player:SetAttribute("LoadingText", LoadingRules.stepText(step, placeKind, screen))
			player:SetAttribute("LoadingShare", share)
			player:SetAttribute("LoadingPockets", LoadingRules.pockets(share, done, LoadingScreen.POCKETS))
			player:SetAttribute("LoadingNote", if slow then LoadingScreen.SLOW_NOTE else "")
			if done then
				release()
				player:SetAttribute("LoadingDone", true)
				return
			end
			task.wait(0.1)
		end
	end)
end

return LoadingController
