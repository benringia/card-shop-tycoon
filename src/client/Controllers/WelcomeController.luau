--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): once the player's shop is theirs and their data says they
-- haven't seen it (player attribute SeenWelcome, WelcomeService), the camera flies past Forest Falls, Frostpeak, over
-- the plaza and past Ember Canyon to their shop, while the sky runs a time-lapse from morning to sunset and holds
-- sunset. Cinema bars and a title; the rest of the UI is off and the player stands still; a Skip button from the first frame. It
-- ends (finished, skipped, or the character dying) by putting everything back and telling the server.
-- Livelier since the owner 2026-11-11 ("more epic/jolly/welcoming"): its own music (the local WelcomePlaying attribute
-- tells MusicController), a bouncing card with a chime for each place it passes, whooshes on the fast stretches, the
-- title popping in with a sparkle, a camera that widens as it speeds and banks into turns (Util/WelcomePath), and
-- confetti cannons and a star burst at your shop as it arrives (Util/WelcomeFx; Config/Welcome CARDS, CUES, LENS, FINALE).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cycle = require(Config:WaitForChild("DayCycle"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Welcome = require(Config:WaitForChild("Welcome"))
local SharedUtil = Shared:WaitForChild("Util")
local DayCycle = require(SharedUtil:WaitForChild("DayCycle"))
local Place = require(SharedUtil:WaitForChild("Place"))
local SkyLook = require(SharedUtil:WaitForChild("SkyLook"))
local WelcomePath = require(SharedUtil:WaitForChild("WelcomePath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local WelcomeFx = require(ClientUtil:WaitForChild("WelcomeFx"))

local WelcomeController = {}

local player = Players.LocalPlayer
local playing = false

type Card = { frame: Frame, title: TextLabel, sub: TextLabel, stroke: UIStroke, scale: UIScale }
-- The ribbon title's pieces, each popping in on its own beat (Config/Welcome TITLE)
type Title = {
	root: Frame,
	top: TextLabel,
	topStroke: UIStroke,
	topScale: UIScale,
	ribbon: CanvasGroup,
	ribbonScale: UIScale,
	dogs: ImageLabel,
	dogsScale: UIScale,
	stars: { { image: ImageLabel, scale: UIScale, phase: number } },
}

local TITLE = Welcome.TITLE
local TITLE_COLORS = TITLE.colors

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function ownPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function vec(v: WelcomePath.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

-- The player stands still while it plays (and the phone's thumbstick hides); returns how to put it back
local function freeze(): () -> ()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local walk, jump, jumpHeight = 16, 50, 7.2
	if humanoid then
		walk, jump, jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	GuiService.TouchControlsEnabled = false
	return function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = walk
			humanoid.JumpPower = jump
			humanoid.JumpHeight = jumpHeight
		end
		GuiService.TouchControlsEnabled = not UIKit.anyPanelOpen()
	end
end

-- The place card at the bottom, over the cinema bar: a white pill, the place's icon and name in its colour and what you
-- do there under it, both centred (the owner 2026-11-11: "center the texts")
local function buildCard(screen: ScreenGui): Card
	local frame = Instance.new("Frame")
	frame.Name = "PlaceCard"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1 - Welcome.BAR_SHARE, -14)
	frame.Size = UDim2.new(0.9, 0, 0, 88)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 88)
	limit.Parent = frame
	UIKit.corner(frame, 26)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local title = UIKit.label(frame, "", Enum.Font.FredokaOne, 32, Color3.new(1, 1, 1))
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 42)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = UIKit.label(frame, "", Enum.Font.GothamBold, 18, Color3.fromRGB(95, 80, 110))
	sub.Position = UDim2.fromOffset(12, 50)
	sub.Size = UDim2.new(1, -24, 0, 26)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	return { frame = frame, title = title, sub = sub, stroke = stroke, scale = scale }
end

local function scaler(parent: Instance): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = parent
	return scale
end

local function rounded(parent: GuiObject, share: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(share, 0)
	corner.Parent = parent
end

local function titleText(parent: GuiObject, text: string, color: Color3): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(TITLE_COLORS.outline)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label, stroke
end

-- The title (owner 2026-11-16, mockup A): "WELCOME TO" in white over a lilac ribbon (a darker underside, notched tails)
-- holding the game's name in gold with a plum outline and drop, the dogs' sticker on the ribbon's top right corner,
-- stars twinkling round it. Sized as a share of the screen's width; outlines follow its height.
local function buildTitle(screen: ScreenGui): Title
	local box = TITLE.box
	local root = Instance.new("Frame")
	root.Name = "Title"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, Welcome.BAR_SHARE + box.top)
	root.Size = UDim2.fromScale(box.width, 1)
	root.Visible = false
	root.Parent = screen
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = box.aspect
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = root

	local top, topStroke = titleText(root, string.upper(TITLE.top), Color3.new(1, 1, 1))
	top.Position = UDim2.fromScale(0.5, 0.12)
	top.Size = UDim2.fromScale(0.5, 0.18)
	top.ZIndex = 3

	local ribbon = Instance.new("CanvasGroup")
	ribbon.Name = "Ribbon"
	ribbon.BackgroundTransparency = 1
	ribbon.AnchorPoint = Vector2.new(0.5, 0)
	ribbon.Position = UDim2.fromScale(0.5, 0.24)
	ribbon.Size = UDim2.fromScale(1, 0.56)
	ribbon.ZIndex = 2
	ribbon.Parent = root
	for _, left in { true, false } do
		local tail = Instance.new("ImageLabel")
		tail.BackgroundTransparency = 1
		tail.Image = TITLE.ribbonTail
		tail.ImageColor3 = rgb(TITLE_COLORS.tail)
		tail.AnchorPoint = Vector2.new(0.5, 0)
		tail.Position = UDim2.fromScale(if left then 0.09 else 0.91, 0.3)
		tail.Size = UDim2.fromScale(0.11, 0.62)
		tail.Rotation = if left then 0 else 180
		tail.ZIndex = 1
		tail.Parent = ribbon
	end
	local under = Instance.new("Frame")
	under.BackgroundColor3 = rgb(TITLE_COLORS.ribbonUnder)
	under.BorderSizePixel = 0
	under.AnchorPoint = Vector2.new(0.5, 0)
	under.Position = UDim2.fromScale(0.5, 0.13)
	under.Size = UDim2.fromScale(0.78, 0.74)
	under.ZIndex = 2
	under.Parent = ribbon
	rounded(under, 0.22)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0)
	band.Position = UDim2.fromScale(0.5, 0.05)
	band.Size = UDim2.fromScale(0.78, 0.74)
	band.ZIndex = 3
	band.Parent = ribbon
	rounded(band, 0.22)
	local bandGradient = Instance.new("UIGradient")
	bandGradient.Rotation = 90
	bandGradient.Color = ColorSequence.new(rgb(TITLE_COLORS.ribbonTop), rgb(TITLE_COLORS.ribbonBottom))
	bandGradient.Parent = band
	local drop, dropStroke = titleText(band, TITLE.name, rgb(TITLE_COLORS.outline))
	drop.Position = UDim2.fromScale(0.5, 0.56)
	drop.Size = UDim2.fromScale(0.9, 0.78)
	drop.ZIndex = 4
	local name, nameStroke = titleText(band, TITLE.name, Color3.new(1, 1, 1))
	name.Position = UDim2.fromScale(0.5, 0.5)
	name.Size = UDim2.fromScale(0.9, 0.78)
	name.ZIndex = 5
	local gold = Instance.new("UIGradient")
	gold.Rotation = 90
	gold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(TITLE_COLORS.goldTop)),
		ColorSequenceKeypoint.new(0.55, rgb(TITLE_COLORS.goldMid)),
		ColorSequenceKeypoint.new(1, rgb(TITLE_COLORS.goldBottom)),
	})
	gold.Parent = name

	local dogs = Instance.new("ImageLabel")
	dogs.Name = "Dogs"
	dogs.BackgroundTransparency = 1
	dogs.Image = TITLE.dogs
	dogs.ScaleType = Enum.ScaleType.Fit
	dogs.AnchorPoint = Vector2.new(0.5, 0.78)
	dogs.Position = UDim2.fromScale(0.86, 0.33)
	dogs.Size = UDim2.fromScale(0.26, 1)
	dogs.Rotation = 8
	dogs.ImageTransparency = 1
	dogs.ZIndex = 6
	dogs.Parent = root
	local dogsAspect = Instance.new("UIAspectRatioConstraint")
	dogsAspect.AspectRatio = TITLE.dogsAspect
	dogsAspect.DominantAxis = Enum.DominantAxis.Width
	dogsAspect.Parent = dogs

	local stars = {}
	for _, spot in TITLE.stars do
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = TITLE.star
		star.ImageColor3 = rgb(TITLE_COLORS.star)
		star.ImageTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.x, spot.y)
		star.Size = UDim2.fromScale(spot.size, 1)
		star.ZIndex = 7
		star.Parent = root
		local square = Instance.new("UIAspectRatioConstraint")
		square.DominantAxis = Enum.DominantAxis.Width
		square.Parent = star
		table.insert(stars, { image = star, scale = scaler(star), phase = spot.phase })
	end

	-- Outlines in pixels follow the title's height (a phone's is about half a monitor's)
	local function outlines()
		local height = root.AbsoluteSize.Y
		topStroke.Thickness = math.max(1.5, height * 0.016)
		nameStroke.Thickness = math.max(2, height * 0.024)
		dropStroke.Thickness = nameStroke.Thickness
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(outlines)
	outlines()

	return {
		root = root,
		top = top,
		topStroke = topStroke,
		topScale = scaler(top),
		ribbon = ribbon,
		ribbonScale = scaler(ribbon),
		dogs = dogs,
		dogsScale = scaler(dogs),
		stars = stars,
	}
end

-- Each piece of the title pops in `delay` after it starts and they all fade out together
local function showTitle(title: Title, seconds: number)
	local function piece(delay: number): (boolean, number, number)
		local shown, size, alpha = WelcomePath.cardAt({ { from = TITLE.seconds[1] + delay, to = TITLE.seconds[2] } }, seconds, Welcome.CARD_POP)
		return shown ~= nil, if shown then size else 1, alpha
	end
	local topShown, topSize, topAlpha = piece(TITLE.delays.top)
	local ribbonShown, ribbonSize, ribbonAlpha = piece(TITLE.delays.ribbon)
	local dogsShown, dogsSize, dogsAlpha = piece(TITLE.delays.dogs)
	title.root.Visible = topShown or ribbonShown or dogsShown
	title.top.TextTransparency = 1 - topAlpha
	title.topStroke.Transparency = 1 - topAlpha
	title.topScale.Scale = topSize
	title.ribbon.GroupTransparency = 1 - ribbonAlpha
	title.ribbonScale.Scale = ribbonSize
	title.dogs.ImageTransparency = 1 - dogsAlpha
	title.dogsScale.Scale = dogsSize
	for _, star in title.stars do
		local twinkle = 0.5 + 0.5 * math.sin((seconds + star.phase) * 4)
		star.image.ImageTransparency = 1 - ribbonAlpha * (0.3 + 0.7 * twinkle)
		star.image.Rotation = (seconds + star.phase) * 60
		star.scale.Scale = 0.5 + 0.6 * twinkle
	end
end

local function buildOverlay(): (ScreenGui, TextButton, Title)
	local screen = Instance.new("ScreenGui")
	screen.Name = "Welcome"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 50
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, Welcome.BAR_SHARE)
		bar.Parent = screen
	end
	local title = buildTitle(screen)
	-- Top right, under the cinema bar: clear of the phone's jump button (bottom right)
	local skip = UIKit.button(screen, "Skip", Color3.fromRGB(40, 44, 58))
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -16, Welcome.BAR_SHARE, 12)
	skip.Size = UDim2.fromOffset(Welcome.SKIP_SIZE[1], Welcome.SKIP_SIZE[2])
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Font = Enum.Font.FredokaOne
	skip.TextSize = 24
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen, skip, title
end

local function play(plot: Model)
	if playing then
		return
	end
	playing = true
	ScreenClear.wait() -- a purchase dialog or the Roblox menu first (owner 2026-11-13)
	local floor = plot:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		playing = false
		return
	end
	-- The shop's door: the middle of its street side (the floor faces the street)
	local outward = Vector3.new(floor.CFrame.LookVector.X, 0, floor.CFrame.LookVector.Z).Unit
	local door = floor.Position + outward * PlotConfig.DEPTH / 2
	local keys = WelcomePath.keys(Welcome, { x = door.X, y = 0, z = door.Z }, { x = outward.X, z = outward.Z })
	-- Ask for the scenery along the flight all at once, waiting STREAM_TIMEOUT at most
	local pending = #keys
	for _, key in keys do
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(vec(key.pos), Welcome.STREAM_TIMEOUT)
			end)
			pending -= 1
		end)
	end
	local waitUntil = os.clock() + Welcome.STREAM_TIMEOUT
	while pending > 0 and os.clock() < waitUntil do
		task.wait()
	end

	WelcomeFx.preload() -- the finale's confetti and stars, ready by the time the flight reaches the shop
	local screen, skip, title = buildOverlay()
	local card = buildCard(screen)
	local sounds: { [string]: Sound } = {}
	for name, id in Welcome.SOUNDS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = screen
		sounds[name] = sound
	end
	local function playSound(name: string, volume: number)
		local sound = sounds[name]
		if sound then
			sound.Volume = volume
			sound.TimePosition = 0
			sound:Play()
		end
	end
	player:SetAttribute("WelcomePlaying", true) -- MusicController plays the flight's music (a local attribute)
	-- Everything else off while it plays
	local hidden: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui ~= screen and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	local unfreeze = freeze()
	SkyLook.hold(true)
	local camera = workspace.CurrentCamera
	local previousType = camera.CameraType
	local previousFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	local started = os.clock()
	local finished = false
	local connections: { RBXScriptConnection } = {}
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		screen:Destroy()
		for _, gui in hidden do
			gui.Enabled = true
		end
		unfreeze()
		SkyLook.hold(false)
		player:SetAttribute("WelcomePlaying", nil)
		camera.FieldOfView = previousFov
		camera.CameraType = if previousType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else previousType
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
		playing = false
		Remotes.WelcomeSeen:FireServer()
	end
	table.insert(connections, skip.Activated:Connect(finish))
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(finish))
	end
	local lens = Welcome.LENS
	local lastSeconds = 0
	local lastPos: Vector3? = nil
	local lastYaw: number? = nil
	local fov, roll = lens.fov, 0
	local shownCard: number? = nil
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local seconds = os.clock() - started
		local t = seconds / Welcome.SECONDS
		if t >= 1 then
			finish()
			return
		end
		-- Ease in and out, so the flight starts gently and settles on the shop
		local eased = t * t * (3 - 2 * t)
		local pos, look = WelcomePath.sample(keys, eased)
		local at, target = vec(pos), vec(look)
		-- Wider as it speeds up, banking into its turns (eased so it never snaps)
		local facing = target - at
		local yaw = math.deg(math.atan2(-facing.X, -facing.Z))
		local speed = if lastPos and dt > 0 then (at - lastPos).Magnitude / dt else 0
		local turn = 0
		if lastYaw and dt > 0 then
			turn = ((yaw - lastYaw + 540) % 360 - 180) / dt
		end
		lastPos, lastYaw = at, yaw
		local wantFov, wantRoll = WelcomePath.lens(speed, turn, lens)
		local ease = 1 - math.exp(-lens.smoothing * dt)
		fov += (wantFov - fov) * ease
		roll += (wantRoll - roll) * ease
		camera.FieldOfView = fov
		camera.CFrame = CFrame.lookAt(at, target) * CFrame.Angles(0, 0, math.rad(roll))
		SkyLook.apply(DayCycle.timelapse(Cycle, WelcomePath.dayProgress(Welcome, eased)))
		-- The title's pieces bounce in with its sparkle and fade out together
		showTitle(title, seconds)
		-- The place card under the flight, a chime as each pops in; confetti with your shop's
		local index, size, alpha = WelcomePath.cardAt(Welcome.CARDS, seconds, Welcome.CARD_POP)
		if index ~= shownCard then
			shownCard = index
			local place = if index then Welcome.CARDS[index] else nil
			if place then
				local color = rgb(place.color)
				card.title.Text = `{place.icon} {place.title}`
				card.title.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.2)
				card.sub.Text = place.sub
				card.stroke.Color = color
				playSound("chime", Welcome.CHIME_VOLUME)
				if place.finale then
					WelcomeFx.finale(door, outward)
				end
			end
		end
		card.frame.Visible = index ~= nil
		card.scale.Scale = size
		card.frame.BackgroundTransparency = 1 - alpha
		card.stroke.Transparency = 1 - alpha
		for _, label in { card.title, card.sub } do
			label.TextTransparency = 1 - alpha
		end
		-- Whooshes on the fast stretches, the title's sparkle, the finale
		for _, cue in WelcomePath.crossed(Welcome.CUES, lastSeconds, seconds) do
			playSound(cue.sound, cue.volume)
		end
		lastSeconds = seconds
	end))
end

local function check()
	if player:GetAttribute("SeenWelcome") ~= false or playing or player:GetAttribute("LoadingDone") ~= true then
		return -- seen, playing, or the loading screen still up (it starts when that fades)
	end
	if player:GetAttribute("SeenPrologue") ~= true then
		return -- the prologue plays first (PrologueController; WelcomeService sets it seen when it's over)
	end
	local plot = ownPlot()
	if plot and player.Character then
		task.spawn(play, plot)
	end
end

function WelcomeController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	player:GetAttributeChangedSignal("SeenWelcome"):Connect(check)
	player:GetAttributeChangedSignal("SeenPrologue"):Connect(check)
	player:GetAttributeChangedSignal("LoadingDone"):Connect(check)
	player.CharacterAdded:Connect(function()
		task.delay(1, check)
	end)
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(check)
	end
	plots.ChildAdded:Connect(function(plot)
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(check)
	end)
	check()
end

return WelcomeController
