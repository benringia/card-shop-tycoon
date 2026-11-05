--!strict
-- The Wild's loading screen (owner 2026-11-05: "when entering wilds can we do a loading screen that make sure
-- everything is loaded before player can walk in", look A "Portal swirl"; Config/WildLoading, Util/WildLoadingRules).
-- Up the moment WildService sends you (WildTravel "loading"): the portal's greens swirling over a dimmed valley, the
-- title, a bar, the step and a tip. Once you've arrived ("wild") it holds you still (your root anchored on your
-- device) until the ground under you, the valley's scenery round you, the monsters' models and the area's music are
-- in, then fades and lets you walk. "stay" (the trip didn't happen) or "home" closes it.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local WildLoading = require(Config:WaitForChild("WildLoading"))
local Music = require(Config:WaitForChild("Music"))
local WildLoadingRules = require(Shared:WaitForChild("Util"):WaitForChild("WildLoadingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local WildLoadingController = {}

type Screen = {
	gui: ScreenGui,
	group: CanvasGroup,
	swirl: ImageLabel,
	swirlBack: ImageLabel,
	glow: ImageLabel,
	fill: Frame,
	step: TextLabel,
	tip: TextLabel,
}

local TIP_SECONDS = 4
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
local barShare = 0

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function text(parent: Instance, font: Enum.Font, size: number, rgb: { number }, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color(rgb)
	label.TextStrokeTransparency = 0.55
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.new(0.9, 0, 0, size + 8)
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function image(parent: Instance, id: string, size: number, rgb: { number }, transparency: number): ImageLabel
	local picture = Instance.new("ImageLabel")
	picture.BackgroundTransparency = 1
	picture.Image = id
	picture.ImageColor3 = color(rgb)
	picture.ImageTransparency = transparency
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.4)
	picture.Size = UDim2.fromScale(size, size)
	picture.SizeConstraint = Enum.SizeConstraint.RelativeYY
	picture.Parent = parent
	return picture
end

local function build(): Screen
	local colors = WildLoading.COLORS
	local gui = Instance.new("ScreenGui")
	gui.Name = "WildLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900 -- over every screen but the join loading screen
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = color(colors.back)
	group.Active = true -- taps don't reach the world under it
	group.Parent = gui
	local backdrop = Instance.new("ImageLabel")
	backdrop.BackgroundTransparency = 1
	backdrop.Image = WildLoading.BACKDROP
	backdrop.ScaleType = Enum.ScaleType.Crop
	local rect = WildLoading.BACKDROP_RECT
	backdrop.ImageRectOffset = Vector2.new(rect[1], rect[2])
	backdrop.ImageRectSize = Vector2.new(rect[3], rect[4])
	backdrop.ImageTransparency = 0.6
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = group
	local shade = Instance.new("Frame")
	shade.BackgroundColor3 = color(colors.back)
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = group
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.45, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	fade.Parent = shade
	local swirlBack = image(group, WildLoading.SWIRL, WildLoading.SWIRL_SIZE * 1.35, colors.swirlBack, 0.55)
	local swirl = image(group, WildLoading.SWIRL, WildLoading.SWIRL_SIZE, colors.swirl, 0)
	local glow = image(group, WildLoading.GLOW, WildLoading.SWIRL_SIZE * 0.45, colors.glow, 0.2)
	local phone = workspace.CurrentCamera.ViewportSize.Y < 500
	local title = text(group, Enum.Font.FredokaOne, if phone then 30 else 42, colors.text, 0.75)
	title.Text = WildLoading.TITLE
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.83)
	track.Size = UDim2.fromOffset(260, 10)
	track.BackgroundColor3 = color(colors.track)
	track.BackgroundTransparency = 0.82
	track.Parent = group
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local fillColor = Instance.new("UIGradient")
	fillColor.Color = ColorSequence.new(color(colors.bar), color(colors.barEnd))
	fillColor.Parent = fill
	local step = text(group, Enum.Font.GothamBold, if phone then 13 else 15, colors.text, 0.875)
	local tip = text(group, Enum.Font.Gotham, if phone then 12 else 14, colors.tip, 0.95)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, group = group, swirl = swirl, swirlBack = swirlBack, glow = glow, fill = fill, step = step, tip = tip }
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
	local fadeOut = TweenService:Create(current.group, TweenInfo.new(WildLoading.FADE_SECONDS), { GroupTransparency = 1 })
	fadeOut.Completed:Once(function()
		current.gui:Destroy()
	end)
	fadeOut:Play()
end

local function animate(now: number, dt: number)
	local current = screen
	if not current then
		return
	end
	current.swirl.Rotation = (now * WildLoading.SWIRL_TURN[1]) % 360
	current.swirlBack.Rotation = (now * WildLoading.SWIRL_TURN[2]) % 360
	current.glow.ImageTransparency = 0.25 + 0.15 * math.sin(now * 2.4)
	local arrivedFor = if arrivedAt then now - arrivedAt else nil
	local step, share, finished = WildLoadingRules.progress(status, arrivedFor, now - shownAt, WildLoading)
	barShare += (share - barShare) * math.min(1, dt * 6)
	current.fill.Size = UDim2.fromScale(barShare, 1)
	current.step.Text = WildLoading.STEPS[step] or WildLoading.READY
	local tips = WildLoading.TIPS
	current.tip.Text = tips[math.floor((now - shownAt) / TIP_SECONDS) % #tips + 1]
	if finished then
		close()
	end
end

local function show()
	if screen then
		return
	end
	screen = build()
	shownAt = os.clock()
	arrivedAt = nil
	barShare = 0
	status = { ground = false, scenery = false, monsters = false, sounds = false }
	trip += 1
	ticker = RunService.RenderStepped:Connect(function(dt)
		animate(os.clock(), dt)
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

-- The arrival area's music and ambience, kept loaded until a while after the screen closes, so they start at once
local function areaSounds()
	local area = Music.WILD.areas[1]
	local list: { Sound } = {}
	for _, id in { area.tracks[1], area.ambient and area.ambient.id } do
		if typeof(id) == "string" and id ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Parent = SoundService
			table.insert(list, sound)
			table.insert(held, sound)
		end
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

-- The screen's pictures, kept drawn tiny and nearly invisible from the start (Roblox only finishes loading an image
-- once something draws it), so the first trip's swirl is there at once
local function keepPictures()
	local cache = Instance.new("ScreenGui")
	cache.Name = "WildLoadingCache"
	cache.ResetOnSpawn = false
	cache.DisplayOrder = -10
	for _, id in { WildLoading.SWIRL, WildLoading.GLOW, WildLoading.BACKDROP } do
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
