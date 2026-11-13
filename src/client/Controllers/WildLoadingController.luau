--!strict
-- The Wild's loading screen (owner 2026-11-05: "when entering wilds can we do a loading screen that make sure
-- everything is loaded before player can walk in"; Config/WildLoading, Util/WildLoadingRules). Since 2026-11-13 it's
-- the binder like every loading screen (ReplicatedFirst/LoadingScreen/LoadingGui, Config/LoadingScreen LOOKS.Wild, or
-- LOOKS.Frontier inside the Frontier): up the moment WildService sends you (WildTravel "loading"), a card into a
-- pocket for each thing loaded. Once you've arrived ("wild") it holds you still (your root anchored on your device)
-- until the ground under you, the valley's scenery round you, the monsters' models and the area's music are in, shows
-- the last card and "Here we go!", then fades and lets you walk. "stay" (the trip didn't happen) or "home" closes it.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local WildLoading = require(Config:WaitForChild("WildLoading"))
local LoadingScreen = require(Config:WaitForChild("LoadingScreen"))
local Music = require(Config:WaitForChild("Music"))
local WildLoadingRules = require(Util:WaitForChild("WildLoadingRules"))
local LoadingRules = require(Util:WaitForChild("LoadingRules"))
local Place = require(Util:WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LoadingGui = require(ReplicatedFirst:WaitForChild("LoadingScreen"):WaitForChild("LoadingGui")) :: any

local player = Players.LocalPlayer
local WildValley = Place.getValley() -- the place's valley config
local LOOK = LoadingRules.look(LoadingScreen, if Place.isFrontier() then "Frontier" else "Wild")

local WildLoadingController = {}

type Screen = { gui: ScreenGui, stop: () -> () }

local RELEASE_SECONDS = 6 -- the area's music stays loaded this long after the screen closes (its player starts it)

local screen: Screen? = nil
local shownAt = 0
local arrivedAt: number? = nil
local status: WildLoadingRules.Status = { ground = false, scenery = false, monsters = false, sounds = false }
local trip = 0 -- a new trip (or a close) stops the last one's loads writing into this one
local anchored: BasePart? = nil
local held: { Sound } = {}
local monstersLoaded = false -- once a session: the models stay fetched
local ticker: RBXScriptConnection? = nil
local finishing = false -- the last card is in: "Here we go!" a moment, then it closes

local function build(): Screen
	local gui = LoadingGui.build(LOOK, WildLoading.STEPS[1])
	gui.Name = "WildLoading"
	gui.DisplayOrder = 900 -- over every screen but the join loading screen
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, stop = LoadingGui.animate(gui, LOOK) }
end

-- Lets you walk again (only the root this screen anchored, if it's still yours)
local function release()
	local root = anchored
	anchored = nil
	if root and root.Parent then
		root.Anchored = false
	end
end

local function close()
	local current = screen
	if not current then
		return
	end
	screen = nil
	finishing = false
	trip += 1
	if ticker then
		ticker:Disconnect()
		ticker = nil
	end
	release()
	local keep = held
	held = {}
	task.delay(RELEASE_SECONDS, function()
		for _, sound in keep do
			sound:Destroy()
		end
	end)
	current.stop()
	LoadingGui.fadeOut(current.gui, WildLoading.FADE_SECONDS)
end

local function animate(now: number)
	local current = screen
	if not current or finishing then
		return
	end
	local arrivedFor = if arrivedAt then now - arrivedAt else nil
	local step, share, finished = WildLoadingRules.progress(status, arrivedFor, now - shownAt, WildLoading)
	local text = WildLoading.STEPS[step] or WildLoading.READY
	LoadingGui.set(current.gui, text, LoadingRules.pockets(share, finished, LOOK.POCKETS), "")
	if finished then
		-- the last cards land and "Here we go!" shows a moment, then it closes (unless a close came first)
		finishing = true
		local mine = trip
		task.delay(LoadingGui.settleSeconds(current.gui) + LOOK.READY_HOLD, function()
			if trip == mine then
				close()
			end
		end)
	end
end

local function show()
	if screen then
		return
	end
	screen = build()
	shownAt = os.clock()
	arrivedAt = nil
	finishing = false
	status = { ground = false, scenery = false, monsters = false, sounds = false }
	trip += 1
	ticker = RunService.RenderStepped:Connect(function()
		animate(os.clock())
	end)
end

-- Each load writes its flag only while its trip is still the current one
local function load(mine: number, key: string, work: () -> ())
	task.spawn(function()
		local ok, err = pcall(work)
		if not ok then
			warn(`[WildLoadingController] {key}:`, err)
		end
		if trip == mine then
			(status :: any)[key] = true -- a failed load counts as done: one bad asset can't hold you to MAX_SECONDS
		end
	end)
end

-- Ground under you, within GROUND_DEPTH studs (the server streamed the spot in before moving you; this waits for it on
-- your device)
local function groundUnder(mine: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	while trip == mine do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			params.FilterDescendantsInstances = { character }
			if workspace:Raycast(root.Position, Vector3.new(0, -WildLoading.GROUND_DEPTH, 0), params) then
				return
			end
		end
		task.wait(0.1)
	end
end

-- The arrival area's music and ambience and every boss arena's battle music and ambience (WildLoadingRules.sounds),
-- kept loaded until a while after the screen closes, so they start at once
local function areaSounds()
	local list: { Sound } = {}
	for _, id in WildLoadingRules.sounds(Music, WildValley) do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = SoundService
		table.insert(list, sound)
		table.insert(held, sound)
	end
	ContentProvider:PreloadAsync(list)
end

local function arrive()
	show()
	arrivedAt = os.clock()
	local mine = trip
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and not root.Anchored then
		root.Anchored = true -- held still until it's all in (on your device, which moves your character)
		anchored = root
	end
	load(mine, "ground", function()
		groundUnder(mine)
	end)
	load(mine, "scenery", function()
		local folders: { Instance } = {}
		for _, name in { "WildValley", "WildBackdrop", "Wild" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				table.insert(folders, folder)
			end
		end
		ContentProvider:PreloadAsync(folders)
	end)
	load(mine, "monsters", function()
		local models = ReplicatedStorage:FindFirstChild("MonsterModels")
		if models and not monstersLoaded then
			ContentProvider:PreloadAsync({ models })
			monstersLoaded = true
		end
	end)
	load(mine, "sounds", areaSounds)
end

-- The screen's pictures (the world's painting and the nine cards), kept drawn tiny and nearly invisible from the start
-- (Roblox only finishes loading an image once something draws it), so the first trip's screen is whole at once
local function keepPictures()
	local cache = Instance.new("ScreenGui")
	cache.Name = "WildLoadingCache"
	cache.ResetOnSpawn = false
	cache.DisplayOrder = -10
	local images = { LOOK.BACKDROP }
	for _, card in LOOK.DOG_CARDS do
		table.insert(images, card.image)
	end
	for _, id in images do
		local keep = Instance.new("ImageLabel")
		keep.BackgroundTransparency = 1
		keep.Size = UDim2.fromOffset(2, 2)
		keep.Image = id
		keep.ImageTransparency = 0.98
		keep.Parent = cache
	end
	cache.Parent = player:WaitForChild("PlayerGui")
end

function WildLoadingController.Start()
	keepPictures()
	Remotes.WildTravel.OnClientEvent:Connect(function(where)
		if where == "loading" then
			show()
		elseif where == "wild" then
			arrive()
		elseif where == "stay" or where == "home" then
			close()
		end
	end)
	player.CharacterRemoving:Connect(close)
end

return WildLoadingController
