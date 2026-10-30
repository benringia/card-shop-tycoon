--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): once the player's shop is theirs and their data says they
-- haven't seen it (player attribute SeenWelcome, WelcomeService), the camera flies past Forest Falls, Frostpeak, over
-- the plaza and past Ember Canyon to their shop, while the sky runs a time-lapse from morning to sunset and holds
-- sunset. Cinema bars and a title; the rest of the UI is off and the player stands still; a Skip button from the first frame. It
-- ends (finished, skipped, or the character dying) by putting everything back and telling the server.
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

local WelcomeController = {}

local player = Players.LocalPlayer
local playing = false

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

local function buildOverlay(): (ScreenGui, TextButton, TextLabel)
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
	local title = UIKit.label(screen, Welcome.TITLE, Enum.Font.FredokaOne, 40, Color3.new(1, 1, 1))
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, Welcome.BAR_SHARE + 0.06)
	title.Size = UDim2.new(0.9, 0, 0, 56)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextTransparency = 1
	UIKit.outlined(title, 2)
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

	local screen, skip, title = buildOverlay()
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
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / Welcome.SECONDS
		if t >= 1 then
			finish()
			return
		end
		-- Ease in and out, so the flight starts gently and settles on the shop
		local eased = t * t * (3 - 2 * t)
		local pos, look = WelcomePath.sample(keys, eased)
		camera.CFrame = CFrame.lookAt(vec(pos), vec(look))
		SkyLook.apply(DayCycle.timelapse(Cycle, WelcomePath.dayProgress(Welcome, eased)))
		local seconds = os.clock() - started
		local window = Welcome.TITLE_SECONDS
		local fade = math.clamp(math.min(seconds - window[1], window[2] - seconds) / 0.5, 0, 1)
		title.TextTransparency = 1 - fade
		local stroke = title:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1 - fade
		end
	end))
end

local function check()
	if player:GetAttribute("SeenWelcome") ~= false or playing then
		return
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
