--!strict
-- Manning the register (owner 2026-11-16: "when I go to a cash register, I want the option like 'Man the cashier'. I
-- will then switch to first person with the UI of an actual cash register ... when I get off the cash register, I will
-- then switch back to third person"; like TCG Card Shop Simulator; Config/RegisterStation, Util/RegisterStationRules).
-- A "Man the register" prompt at your own register puts you behind it in first person: you tap the customer's items on
-- the counter to scan them, Charge on the register's screen (Util/RegisterScreen: the three steps, one big line of
-- what to do), then type the total on the card machine or count the change out of the cash drawer (money you give
-- lands on the counter, a tap takes it back; after a few seconds stuck the next note or coin to give glows). The camera
-- leans in to the card machine or over the drawer. Leave (top left) puts you back in third person. The server checks
-- every step (RegisterService); the unit is built there (Util/RegisterBuild)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Payment = require(Config:WaitForChild("Payment"))
local RegisterStation = require(Config:WaitForChild("RegisterStation"))
local Town = require(Config:WaitForChild("Town"))
local PaymentRules = require(Shared:WaitForChild("Util"):WaitForChild("PaymentRules"))
local RegisterStationRules = require(Shared:WaitForChild("Util"):WaitForChild("RegisterStationRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local RegisterScreen = require(ClientUtil:WaitForChild("RegisterScreen"))
local RegisterSpot = require(ClientUtil:WaitForChild("RegisterSpot"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Request = { method: string, total: number, given: number }
type Pose = { eye: { number }, look: { number } }

local LINES = Payment.LINES
local WORDS = RegisterStation.SCREEN
local C = RegisterStation.SCREEN_COLORS
local CAMERA = RegisterStation.CAMERA
local GIVEN = RegisterStation.GIVEN
-- 4 across and 3 down: each key taller, so it's a thumb's size on a phone (owner 2026-11-16: "buttons are too small
-- for phone")
local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "del" }
local GIVEN_PER_ROW = 5
local CHECK_SECONDS = 0.25
local ERROR_SECONDS = 2.5
local FIRST_SALE_STEP = "ringUp" -- Pish's first sale: the helper glow shows at once

local player = Players.LocalPlayer

local RegisterStationController = {}

local manned = false
local checkoutOpen = false
local remaining = 0
local scannedTotal = 0 -- the checkout's running total in dollars (CheckoutUpdate)
local lines: { RegisterScreen.Line } = {}
local offerOpen = false
local request: Request? = nil
local typed = ""
local pieces: { number } = {}
local givenParts: { BasePart } = {}
local errorUntil = 0
local errorLine = ""
local lastProgressAt = 0 -- your last tap while paying cash (the helper glow waits for a stall)
local shownPose = ""
local drawerOpen = false
local drawerClosed: CFrame? = nil
local saved: { walk: number, jumpPower: number, jumpHeight: number, autoRotate: boolean }? = nil
local hideConnection: RBXScriptConnection? = nil

local prompt: ProximityPrompt? = nil
local screen: RegisterScreen.Screen
local keypadGui: SurfaceGui
local keypadScreen: TextLabel
local keypadLabel: TextLabel
local leaveButton: TextButton
local autoGiveAt: number? = nil -- exact change gives itself then (AUTO_GIVE_SECONDS)
local helper: Highlight

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The register's pieces --------------------------------------------------------------------------------------------

local function unit(): Model?
	local register = RegisterSpot.register(player)
	local found = if register and register.Parent then register.Parent:FindFirstChild("RegisterUnit") else nil
	return if found and found:IsA("Model") then found else nil
end

local function piece(name: string): BasePart?
	local model = unit()
	local found = if model then model:FindFirstChild(name, true) else nil
	return if found and found:IsA("BasePart") then found else nil
end

-- The counter top's centre, +Z toward the cashier (as Config/RegisterStation measures)
local function counterTop(): CFrame?
	local register = RegisterSpot.register(player)
	return if register then register.CFrame * CFrame.new(0, register.Size.Y / 2, 0) else nil
end

local function situation(): RegisterStationRules.Situation
	return RegisterStationRules.situation({
		manned = manned,
		checkoutOpen = checkoutOpen,
		remaining = remaining,
		offerOpen = offerOpen,
		paying = if request then request.method else nil,
	})
end

local function giving(): number
	local sum = 0
	for _, cents in pieces do
		sum += cents
	end
	return sum
end

local function showError(line: string)
	errorLine = line
	errorUntil = os.clock() + ERROR_SECONDS
end

-- The card machine's face ------------------------------------------------------------------------------------------

local function buildKeypad()
	keypadGui = Instance.new("SurfaceGui")
	keypadGui.Name = "CardKeypadGui"
	keypadGui.Face = Enum.NormalId.Top
	keypadGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	keypadGui.PixelsPerStud = RegisterStation.SCREEN_PIXELS
	keypadGui.LightInfluence = 0
	keypadGui.ResetOnSpawn = false
	keypadGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	keypadGui.Enabled = false
	keypadGui.Parent = player:WaitForChild("PlayerGui")

	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(44, 47, 62)
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = keypadGui
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(padding :: any)[side] = UDim.new(0, 10)
	end
	padding.Parent = back

	-- its label: the amount to type while a card payment waits, so a phone zoomed in on the keys still sees it
	keypadLabel = Instance.new("TextLabel")
	keypadLabel.BackgroundTransparency = 1
	keypadLabel.Size = UDim2.fromScale(1, 0.08)
	keypadLabel.Font = Enum.Font.FredokaOne
	keypadLabel.TextScaled = true
	keypadLabel.TextColor3 = rgb(C.soft)
	keypadLabel.Text = WORDS.keypadLabel
	keypadLabel.Parent = back

	keypadScreen = Instance.new("TextLabel")
	keypadScreen.Name = "Typed"
	keypadScreen.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	keypadScreen.Position = UDim2.fromScale(0, 0.09)
	keypadScreen.Size = UDim2.fromScale(1, 0.13)
	keypadScreen.Font = Enum.Font.FredokaOne
	keypadScreen.TextScaled = true
	keypadScreen.TextColor3 = rgb(C.doneInk)
	keypadScreen.TextXAlignment = Enum.TextXAlignment.Right
	keypadScreen.Text = "$0.00"
	keypadScreen.Parent = back
	UIKit.corner(keypadScreen, 8)
	local inner = Instance.new("UIPadding")
	inner.PaddingRight = UDim.new(0, 8)
	inner.PaddingTop = UDim.new(0, 3)
	inner.PaddingBottom = UDim.new(0, 3)
	inner.Parent = keypadScreen

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromScale(0, 0.25)
	grid.Size = UDim2.fromScale(1, 0.58)
	grid.Parent = back
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.CellSize = UDim2.new(1 / 4, -5, 1 / 3, -5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index, key in KEYS do
		local button = Instance.new("TextButton")
		button.Name = "Key_" .. key
		button.LayoutOrder = index
		button.AutoButtonColor = true
		button.BackgroundColor3 = if key == "del" then Color3.fromRGB(255, 143, 184) else Color3.fromRGB(74, 80, 112)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = if key == "del" then Color3.fromRGB(58, 16, 32) else Color3.new(1, 1, 1)
		button.Text = if key == "del" then "Del" else key
		button.Parent = grid
		UIKit.corner(button, 12)
		button.Activated:Connect(function()
			typed = PaymentRules.typeKey(typed, key, Payment.MAX_TYPED)
			keypadScreen.Text = if typed == "" then "$0.00" else "$" .. typed
		end)
	end

	local ok = Instance.new("TextButton")
	ok.Name = "CardOk"
	ok.AutoButtonColor = true
	ok.BackgroundColor3 = rgb(C.go)
	ok.Position = UDim2.fromScale(0, 0.85)
	ok.Size = UDim2.fromScale(1, 0.15)
	ok.Font = Enum.Font.FredokaOne
	ok.TextScaled = true
	ok.TextColor3 = rgb(C.goInk)
	ok.Text = "OK"
	ok.Parent = back
	UIKit.corner(ok, 12)
	ok.Activated:Connect(function()
		local now = request
		if not now then
			return
		end
		-- a wrong total says so at once; a right one goes to the server, which checks it again
		local cents = PaymentRules.typedCents(typed)
		if cents and PaymentRules.cardRight(cents, now.total) then
			Remotes.PayAnswer:FireServer(cents)
		else
			showError(LINES.wrongCard)
		end
	end)
end

local function giveChange()
	local now = request
	if not now then
		return
	end
	local result = PaymentRules.checkChange(Payment, pieces, now.given - now.total)
	if result == "ok" then
		Remotes.PayAnswer:FireServer(table.clone(pieces))
	else
		showError(if result == "over" then LINES.over else LINES.short)
	end
end

-- Leave: a pill in the top-left corner, clear of the drawer and the card machine (owner 2026-11-16)
local function buildLeave()
	local look = RegisterStation.LEAVE_PILL
	leaveButton = UIKit.button(UIController.GetScreenGui(), "⬅ " .. RegisterStation.LEAVE, UIKit.Colors.Danger)
	leaveButton.Name = "LeaveRegister"
	leaveButton.Position = UDim2.fromOffset(look.x, look.y)
	leaveButton.Size = UDim2.fromOffset(look.width, look.height)
	leaveButton.TextSize = 20
	leaveButton.Visible = false
	-- the phone's thumbstick and jump button hide while you're on the register (you don't walk there)
	UIKit.hideTouchControlsWhileVisible(leaveButton)
	leaveButton.Activated:Connect(function()
		RegisterStationController.Leave()
	end)
end

-- Money on the counter ---------------------------------------------------------------------------------------------

local function layOutGiven()
	for _, part in givenParts do
		part:Destroy()
	end
	table.clear(givenParts)
	local top = counterTop()
	if not top then
		return
	end
	for index, cents in pieces do
		local spot = RegisterStationRules.givenSpot(GIVEN, index, GIVEN_PER_ROW)
		local bill = cents >= 100
		local size = if bill then GIVEN.billSize else GIVEN.coinSize
		local part = Instance.new("Part")
		part.Name = "GivenMoney"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = Vector3.new(size[1], size[2], size[3])
		part.Color = rgb(RegisterStation.MONEY_COLORS[cents])
		if bill then
			part.CFrame = top * CFrame.new(spot.x, size[2] / 2 + 0.01, spot.z)
		else
			part.Shape = Enum.PartType.Cylinder
			part.Material = Enum.Material.Metal
			part.CFrame = top * CFrame.new(spot.x, size[1] / 2 + 0.01, spot.z) * CFrame.Angles(0, 0, math.rad(90))
		end
		part:SetAttribute("GivenIndex", index)
		part.Parent = workspace
		table.insert(givenParts, part)
	end
end

-- The drawer -------------------------------------------------------------------------------------------------------

local function setDrawer(open: boolean)
	if open == drawerOpen then
		return
	end
	local model = unit()
	local drawer = if model then model:FindFirstChild("CashDrawer") else nil
	if not drawer or not drawer:IsA("Model") then
		return
	end
	drawerOpen = open
	local closed = drawerClosed or drawer:GetPivot()
	drawerClosed = closed
	local look = RegisterStation.UNIT.drawer
	local goal = if open then closed * CFrame.new(0, 0, look.openZ - look.closedZ) else closed
	local value = Instance.new("CFrameValue")
	value.Value = drawer:GetPivot()
	value.Changed:Connect(function(at: CFrame)
		drawer:PivotTo(at)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(look.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = goal })
	-- the opening it leaves in the base's front (the body's own drawer face shows while it's in)
	local cavity = model and model:FindFirstChild("DrawerCavity")
	if cavity and cavity:IsA("BasePart") and open then
		cavity.LocalTransparencyModifier = 0
		cavity.Transparency = 0
	end
	tween.Completed:Once(function()
		value:Destroy()
		if cavity and cavity:IsA("BasePart") and not drawerOpen then
			cavity.Transparency = 1
		end
	end)
	tween:Play()
end

-- The helper glow: after a stall (or on Pish's first sale) the next note or coin to give glows gold
local function updateHelper(now: RegisterStationRules.Situation)
	local paying = request
	local stalled = os.clock() - lastProgressAt >= RegisterStation.HELPER_SECONDS or player:GetAttribute("TutorialStep") == FIRST_SALE_STEP
	local nextCents = if paying and now == "cash" and stalled then RegisterStationRules.nextPiece(Payment.DRAWER, paying.given - paying.total - giving()) else nil
	local target: BasePart? = nil
	local model = unit()
	local drawer = if model then model:FindFirstChild("CashDrawer") else nil
	if nextCents and drawer then
		-- the top of its stack (its cup for a coin)
		for _, part in drawer:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("Money") == nextCents and (not target or part.Position.Y > target.Position.Y) then
				target = part
			end
		end
	end
	helper.Adornee = target
	helper.Enabled = target ~= nil
end

-- Camera and refresh -----------------------------------------------------------------------------------------------

local function moveCamera(name: string)
	local top = counterTop()
	local camera = workspace.CurrentCamera
	-- a phone leans in closer (Config/RegisterStation CAMERA phonePoses)
	local poses = if UIKit.isPhone() then CAMERA.phonePoses else CAMERA.poses
	local key = name .. (if poses == CAMERA.phonePoses then ":phone" else "")
	if not top or not camera or key == shownPose then
		return
	end
	shownPose = key
	local pose: Pose = poses[name] or poses.default
	local eye = top * Vector3.new(pose.eye[1], pose.eye[2], pose.eye[3])
	local look = top * Vector3.new(pose.look[1], pose.look[2], pose.look[3])
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA.fov
	TweenService:Create(camera, TweenInfo.new(CAMERA.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(eye, look) }):Play()
end

local function refresh()
	local now = situation()
	screen.gui.Enabled = manned
	keypadGui.Enabled = manned
	leaveButton.Visible = manned
	if not manned then
		helper.Enabled = false
		return
	end
	local paying = request
	local change = if paying then paying.given - paying.total else 0
	local problem = if os.clock() < errorUntil then errorLine else ""
	if now == "cash" and giving() > change then
		problem = LINES.over -- too much in your hand says so at once
	end
	screen.set({
		situation = now,
		clock = RegisterStationRules.clock(Lighting.ClockTime),
		sales = tonumber(player:GetAttribute("RegisterSales")) or 0,
		taken = tonumber(player:GetAttribute("RegisterTaken")) or 0,
		lines = lines,
		total = math.round(scannedTotal * 100),
		remaining = remaining,
		payTotal = if paying then paying.total else 0,
		given = if paying then paying.given else 0,
		giving = giving(),
		error = problem,
	})
	-- the card machine says what to type
	keypadLabel.Text = if now == "card" and paying then string.format(WORDS.keypadType, PaymentRules.money(paying.total)) else WORDS.keypadLabel
	keypadLabel.TextColor3 = rgb(if now == "card" then C.now else C.soft)
	-- exact change gives itself after a beat ("Exact!" on the screen first)
	if now == "cash" and paying and giving() == change and change > 0 then
		if not autoGiveAt then
			autoGiveAt = os.clock() + RegisterStation.AUTO_GIVE_SECONDS
			task.delay(RegisterStation.AUTO_GIVE_SECONDS + 0.05, function()
				local still = request
				if autoGiveAt and os.clock() >= autoGiveAt and still and situation() == "cash" and giving() == still.given - still.total then
					autoGiveAt = nil
					giveChange()
				end
			end)
		end
	else
		autoGiveAt = nil
	end
	setDrawer(now == "cash")
	updateHelper(now)
	moveCamera(if now == "card" or now == "cash" or now == "charge" then now else "default")
end

local function givePiece(cents: number)
	if #pieces >= Payment.MAX_PIECES then
		return
	end
	table.insert(pieces, cents)
	table.sort(pieces, function(a: number, b: number): boolean
		return a > b
	end)
	lastProgressAt = os.clock()
	layOutGiven()
end

-- Manning ----------------------------------------------------------------------------------------------------------

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function RegisterStationController.Man()
	local register = RegisterSpot.register(player)
	local character = player.Character
	local human = humanoid()
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if manned or not register or not unit() or not character or not human or human.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	manned = true
	-- On the cashier's step behind the counter, facing the customers (Town.COUNTER STEP, STAFF_BEHIND)
	local look = Town.COUNTER
	local floorY = register.Position.Y - register.Size.Y / 2
	local behind = register.CFrame * CFrame.new(CAMERA.poses.default.eye[1], 0, register.Size.Z / 2 + look.STAFF_BEHIND)
	local standAt = Vector3.new(behind.Position.X, floorY + look.STEP.height + human.HipHeight + root.Size.Y / 2, behind.Position.Z)
	local facing = register.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1))
	character:PivotTo(CFrame.lookAt(standAt, standAt + facing))
	saved = { walk = human.WalkSpeed, jumpPower = human.JumpPower, jumpHeight = human.JumpHeight, autoRotate = human.AutoRotate }
	human.WalkSpeed = 0
	human.JumpPower = 0
	human.JumpHeight = 0
	human.AutoRotate = false
	-- the register's own screen instead of the HUD; the party dock stays, so a sale's XP still flies to the shop bar
	Hud.keepOnly("register", { "party" })
	-- First person: your own body hidden from you
	hideConnection = RunService.RenderStepped:Connect(function()
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 1
			end
		end
	end)
	shownPose = ""
	lastProgressAt = os.clock()
	if prompt then
		prompt.Enabled = false
	end
	Remotes.ManRegister:FireServer(true)
	refresh()
end

function RegisterStationController.Leave()
	if not manned then
		return
	end
	manned = false
	Remotes.ManRegister:FireServer(false)
	Hud.keepOnly("register", nil)
	if hideConnection then
		hideConnection:Disconnect()
		hideConnection = nil
	end
	local character = player.Character
	if character then
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
	local human = humanoid()
	local before = saved
	if human and before then
		human.WalkSpeed = before.walk
		human.JumpPower = before.jumpPower
		human.JumpHeight = before.jumpHeight
		human.AutoRotate = before.autoRotate
	end
	saved = nil
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = human
		camera.FieldOfView = 70
	end
	shownPose = ""
	setDrawer(false)
	pieces = {}
	layOutGiven()
	if prompt then
		prompt.Enabled = true
	end
	refresh()
end

function RegisterStationController.IsManned(): boolean
	return manned
end

-- What the register shows now ("off" when you're not on it), for Pish's first sale (TutorialController)
function RegisterStationController.Situation(): RegisterStationRules.Situation
	return situation()
end

-- The prompt on your own register's base (client-made, so only you see it)
local function ensurePrompt()
	local housing = piece("RegisterHousing")
	if not housing or (prompt and prompt.Parent == housing) then
		return
	end
	if prompt then
		prompt:Destroy()
	end
	local look = RegisterStation.PROMPT
	local made = Instance.new("ProximityPrompt")
	made.Name = "ManRegister"
	made.ActionText = look.action
	made.ObjectText = look.object
	made.HoldDuration = look.hold
	made.MaxActivationDistance = look.distance
	made.RequiresLineOfSight = false
	made.Enabled = not manned
	made.Triggered:Connect(function()
		RegisterStationController.Man()
	end)
	made.Parent = housing
	prompt = made
end

-- Taps on the drawer's money and on the money given (the screen's and keypad's buttons are GUI, handled there)
local function onInput(input: InputObject, processed: boolean)
	if not manned or processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local camera = workspace.CurrentCamera
	local model = unit()
	if not camera or not model then
		return
	end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local targets: { Instance } = { model }
	for _, part in givenParts do
		table.insert(targets, part)
	end
	params.FilterDescendantsInstances = targets
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 30, params)
	if not hit then
		return
	end
	local index = hit.Instance:GetAttribute("GivenIndex")
	if typeof(index) == "number" then
		table.remove(pieces, index)
		lastProgressAt = os.clock()
		layOutGiven()
		refresh()
		return
	end
	local cents = hit.Instance:GetAttribute("Money")
	if typeof(cents) == "number" and situation() == "cash" then
		givePiece(cents)
		refresh()
	end
end

-- The scan list from the server: { name, price, done } per counter item
local function readLines(raw: unknown): { RegisterScreen.Line }
	local read: { RegisterScreen.Line } = {}
	if typeof(raw) ~= "table" then
		return read
	end
	for _, line in raw :: { any } do
		if typeof(line) == "table" and typeof(line.name) == "string" and typeof(line.price) == "number" then
			table.insert(read, {
				name = line.name,
				price = line.price,
				done = line.done == true,
				product = if typeof(line.product) == "string" then line.product else nil,
				card = if typeof(line.card) == "string" then line.card else nil,
			})
		end
	end
	return read
end

function RegisterStationController.Start()
	screen = RegisterScreen.build(player:WaitForChild("PlayerGui"), function()
		Remotes.Charge:FireServer()
	end, giveChange)
	buildKeypad()
	buildLeave()
	helper = Instance.new("Highlight")
	helper.Name = "RegisterHelper"
	helper.FillColor = rgb(RegisterStation.HELPER_COLOR)
	helper.OutlineColor = rgb(RegisterStation.HELPER_COLOR)
	helper.FillTransparency = 0.45
	helper.DepthMode = Enum.HighlightDepthMode.Occluded
	helper.Enabled = false
	helper.Parent = player:WaitForChild("PlayerGui")

	Remotes.CheckoutUpdate.OnClientEvent:Connect(function(newTotal: unknown, left: unknown, rawLines: unknown)
		checkoutOpen = typeof(newTotal) == "number"
		scannedTotal = if typeof(newTotal) == "number" then newTotal else 0
		remaining = if typeof(left) == "number" then left else 0
		lines = readLines(rawLines)
		if not checkoutOpen then
			request = nil
			typed = ""
			keypadScreen.Text = "$0.00"
			pieces = {}
			layOutGiven()
		end
		refresh()
	end)
	Remotes.PaymentStart.OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) ~= "table" then
			request = nil
			refresh()
			return
		end
		local data = payload :: any
		if (data.method ~= "card" and data.method ~= "cash") or typeof(data.total) ~= "number" or typeof(data.given) ~= "number" then
			return
		end
		local fresh = request == nil or request.total ~= data.total or request.method ~= data.method
		request = { method = data.method, total = data.total, given = data.given }
		if fresh then
			typed = ""
			keypadScreen.Text = "$0.00"
			pieces = {}
			lastProgressAt = os.clock()
			layOutGiven()
		end
		refresh()
	end)
	Remotes.PaymentResult.OnClientEvent:Connect(function(result: unknown)
		showError(if result == "over" then LINES.over elseif result == "short" then LINES.short else LINES.wrongCard)
		refresh()
	end)
	Remotes.OfferUpdate.OnClientEvent:Connect(function(offer: unknown)
		offerOpen = offer ~= nil
		refresh()
	end)
	UserInputService.InputBegan:Connect(onInput)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			ensurePrompt()
			screen.gui.Adornee = piece("RegisterScreen")
			keypadGui.Adornee = piece("CardKeypad")
			if manned then
				-- off the register once you're away from it, or knocked out
				local human = humanoid()
				if not human or human.Health <= 0 or not RegisterSpot.at(player) then
					RegisterStationController.Leave()
				else
					refresh()
				end
			end
		end
	end)
end

return RegisterStationController
