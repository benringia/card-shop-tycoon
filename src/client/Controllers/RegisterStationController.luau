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
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Payment = require(Config:WaitForChild("Payment"))
local RegisterConfig = require(Config:WaitForChild("Register"))
local RegisterStation = require(Config:WaitForChild("RegisterStation"))
local Town = require(Config:WaitForChild("Town"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local PaymentRules = require(Shared:WaitForChild("Util"):WaitForChild("PaymentRules"))
local RegisterStationRules = require(Shared:WaitForChild("Util"):WaitForChild("RegisterStationRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local RegisterScreen = require(ClientUtil:WaitForChild("RegisterScreen"))
local RegisterSpot = require(ClientUtil:WaitForChild("RegisterSpot"))
local SaleOrigin = require(ClientUtil:WaitForChild("SaleOrigin"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))
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
local GIVEN_PER_ROW = GIVEN.perRow
-- a Top-face picture is drawn with its top edge along the part's -X: plates are turned a quarter to read upright from
-- the cashier's side (as the drawer's, server Util/RegisterBuild)
local QUARTER = CFrame.Angles(0, math.rad(-90), 0)
local CHECK_SECONDS = 0.25
local ERROR_SECONDS = 2.5
local FIRST_SALE_STEP = "ringUp" -- Pish's first sale: the helper glow shows at once

local player = Players.LocalPlayer

local RegisterStationController = {}

local manned = false
local manAsk = 0 -- each step onto the register, so an old ask's wait for the server's yes gives way to a new one
local checkoutOpen = false
local remaining = 0
local scannedTotal = 0 -- the checkout's running total in dollars (CheckoutUpdate)
local lines: { RegisterScreen.Line } = {}
local offerOpen = false
local request: Request? = nil
local typed = ""
local pieces: { number } = {}
local givenParts: { BasePart } = {}
-- a note or coin on the counter (or in flight): its body, the clear plate with its picture, and where it lies
type Piece = { part: Part, plate: Part?, coin: boolean, thickness: number, rest: CFrame }
local givenPieces: { Piece } = {}
local GIVE_FX = RegisterStation.GIVE_FX
local pile: Model? = nil -- the money on the counter, one model so the exact change can glow together
local hover: Highlight -- the drawer stack under the mouse
local exactGlow: Highlight
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
local keypadSleep: Frame -- the card machine's sleeping face, over its keys while nobody pays by card
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
			if not RegisterStationRules.keypadOn(situation()) then
				return -- asleep: no card payment to type
			end
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
		if not now or not RegisterStationRules.keypadOn(situation()) then
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

	-- Its sleeping face (owner 2026-11-19: "make the card machine unusable when it's not supposed to be used"): over the
	-- keys whenever nobody pays by card, taking their taps
	keypadSleep = Instance.new("Frame")
	keypadSleep.Name = "Asleep"
	keypadSleep.Active = true
	keypadSleep.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	keypadSleep.Size = UDim2.fromScale(1, 1)
	keypadSleep.ZIndex = 5
	keypadSleep.Parent = keypadGui
	local face = Instance.new("TextLabel")
	face.BackgroundTransparency = 1
	face.Position = UDim2.fromScale(0.1, 0.22)
	face.Size = UDim2.fromScale(0.8, 0.3)
	face.Font = Enum.Font.FredokaOne
	face.TextScaled = true
	face.TextColor3 = rgb(C.soft)
	face.Text = WORDS.keypadOff
	face.ZIndex = 6
	face.Parent = keypadSleep
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0.08, 0.56)
	hint.Size = UDim2.fromScale(0.84, 0.2)
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextWrapped = true
	hint.TextColor3 = rgb(C.off)
	hint.Text = WORDS.keypadOffHint
	hint.ZIndex = 6
	hint.Parent = keypadSleep
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
	-- a holder in the soft cotton candy look (its buttons baby colours with a white rim, like the windows' and the
	-- party dock's), growing on a desktop with the rest of the HUD
	local holder = Instance.new("Frame")
	holder.Name = "LeaveHolder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(look.x, look.y)
	holder.Size = UDim2.fromOffset(look.width, look.height)
	holder:SetAttribute("SoftButtons", true)
	holder.Parent = UIController.GetScreenGui()
	Hud.scaleWith(holder, 1, true) -- grows on a desktop; never shrinks (a short phone's 0.7 made it 36 px tall)
	leaveButton = UIKit.iconButton(holder, RegisterStation.LEAVE, look.icon, UIKit.Colors.Danger)
	leaveButton.Name = "LeaveRegister"
	leaveButton.Size = UDim2.fromScale(1, 1)
	leaveButton.Font = Enum.Font.FredokaOne
	leaveButton.TextSize = 20
	leaveButton.Visible = false
	for _, child in leaveButton:GetChildren() do
		if child.Name == "Icon" and child:IsA("GuiObject") then
			child.Rotation = 180 -- the arrow points out, to the left
		end
	end
	-- its key as a square keyboard key inside the button, after the word (keyboards only): a white cap with a darker
	-- lip under it. A white circle on the corner with an X in it read as a close button (owner 2026-11-21)
	local cap = look.cap
	local lip = Instance.new("Frame")
	lip.Name = "Key"
	lip.AnchorPoint = Vector2.new(1, 0.5)
	-- the button's padding (below) moves its children: out past the padded edge, 12 px inside the button's own
	lip.Position = UDim2.new(1, if UserInputService.KeyboardEnabled then cap + 2 else -12, 0.5, 2)
	lip.Size = UDim2.fromOffset(cap, cap)
	lip.BackgroundColor3 = HudLayout.KEY_CHIP
	lip.BackgroundTransparency = 0.45
	lip.ZIndex = leaveButton.ZIndex + 2
	lip.Visible = UserInputService.KeyboardEnabled
	lip.Parent = leaveButton
	UIKit.corner(lip, 7)
	local key = Instance.new("TextLabel")
	key.Name = "Cap"
	key.Position = UDim2.fromOffset(0, -3)
	key.Size = UDim2.fromScale(1, 1)
	key.BackgroundColor3 = Color3.new(1, 1, 1)
	key.Font = Enum.Font.FredokaOne
	key.Text = look.key
	key.TextSize = 16
	key.TextColor3 = HudLayout.KEY_CHIP
	key.ZIndex = lip.ZIndex + 1
	key.Parent = lip
	UIKit.corner(key, 7)
	-- room for the key: the icon and the word sit left of it
	local pad = leaveButton:FindFirstChildOfClass("UIPadding")
	if pad and lip.Visible then
		pad.PaddingRight = UDim.new(0, cap + 14)
	end
	-- the phone's thumbstick and jump button hide while you're on the register (you don't walk there)
	UIKit.hideTouchControlsWhileVisible(leaveButton)
	leaveButton.Activated:Connect(function()
		RegisterStationController.Leave()
	end)
end

-- Money on the counter ---------------------------------------------------------------------------------------------

-- A piece lying flat at `flat` (a coin is a cylinder on its side; its picture's plate sits on top)
local function placePiece(piece: Piece, flat: CFrame)
	piece.part.CFrame = if piece.coin then flat * CFrame.Angles(0, 0, math.rad(90)) else flat
	local plate = piece.plate
	if plate then
		plate.CFrame = flat * CFrame.new(0, piece.thickness / 2 + 0.003, 0) * QUARTER
	end
end

local function moneyPile(): Model
	local model = pile
	if not model or not model.Parent then
		model = Instance.new("Model")
		model.Name = "GivenMoneyPile"
		model.Parent = workspace
		pile = model
	end
	return model :: Model
end

-- One of the drawer's own notes or coins (owner 2026-11-19: "add money model on the cashier for moneys at the
-- table"): its body in its colour and its picture on top
local function buildPiece(cents: number, flat: CFrame): Piece
	local bill = cents >= 100
	local size = if bill then GIVEN.billSize else GIVEN.coinSize
	local part = Instance.new("Part")
	part.Name = "GivenMoney"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = rgb(RegisterStation.MONEY_COLORS[cents])
	part.Size = Vector3.new(size[1], size[2], size[3])
	local faceSize: Vector3
	if bill then
		part.Material = Enum.Material.SmoothPlastic
		faceSize = Vector3.new(size[3], 0.004, size[1])
	else
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Metal
		faceSize = Vector3.new(size[2], 0.004, size[3])
	end
	local piece: Piece = { part = part, plate = nil, coin = not bill, thickness = if bill then size[2] else size[1], rest = flat }
	local image = RegisterStation.MONEY_IMAGES[cents]
	if image then
		local plate = Instance.new("Part")
		plate.Name = "GivenMoneyFace"
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanTouch = false
		plate.CanQuery = false
		plate.CastShadow = false
		plate.Transparency = 1
		plate.Size = faceSize
		plate.Parent = part
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 400
		gui.LightInfluence = 0.4
		gui.Parent = plate
		local face = Instance.new("ImageLabel")
		face.BackgroundTransparency = 1
		face.Size = UDim2.fromScale(1, 1)
		face.Image = image
		face.Parent = gui
		piece.plate = plate
	end
	placePiece(piece, flat)
	part.Parent = moneyPile()
	return piece
end

-- Where the nth piece lies on the counter: its row spot, a touch askew like money laid down by hand
local function restOf(top: CFrame, index: number, cents: number): CFrame
	local spot = RegisterStationRules.givenSpot(GIVEN, index, GIVEN_PER_ROW)
	local size = if cents >= 100 then GIVEN.billSize else GIVEN.coinSize
	local thickness = if cents >= 100 then size[2] else size[1]
	return top * CFrame.new(spot.x, thickness / 2 + 0.01, spot.z) * CFrame.Angles(0, math.rad(((index * 37) % 9) - 4), 0)
end

local function layOutGiven()
	for _, part in givenParts do
		part:Destroy()
	end
	table.clear(givenParts)
	table.clear(givenPieces)
	local top = counterTop()
	if not top then
		return
	end
	for index, cents in pieces do
		local piece = buildPiece(cents, restOf(top, index, cents))
		piece.part:SetAttribute("GivenIndex", index)
		table.insert(givenParts, piece.part)
		table.insert(givenPieces, piece)
	end
end

-- Tapping money (owner 2026-11-20: "make clicking on moneys on the cashier more immersive") ----------------------------

-- A piece flies from `from` to `to` in a low arc over `seconds`: a coin flipping, a note tilting; then `done`. A piece
-- taken away mid-flight (the row laid out again by the next tap) just stops
local function flyPiece(piece: Piece, from: Vector3, to: CFrame, seconds: number, done: (() -> ())?)
	local started = os.clock()
	local turn = to - to.Position
	placePiece(piece, CFrame.new(from) * turn) -- at its start now: never a frame lying at its place first
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not piece.part.Parent then
			connection:Disconnect()
			return
		end
		local u = math.clamp((os.clock() - started) / seconds, 0, 1)
		local eased = 1 - (1 - u) ^ 2
		local at = from:Lerp(to.Position, eased) + Vector3.new(0, RegisterStationRules.arcLift(u, GIVE_FX.arc), 0)
		local spin = if piece.coin then CFrame.Angles((1 - eased) * GIVE_FX.flips * math.pi * 2, 0, 0) else CFrame.Angles(math.rad(GIVE_FX.tilt) * (1 - eased), 0, 0)
		placePiece(piece, CFrame.new(at) * turn * spin)
		if u >= 1 then
			connection:Disconnect()
			placePiece(piece, to)
			if done then
				done()
			end
		end
	end)
end

-- A note's flick or a coin's clink: a short cut of its clip at `pitch`
local function moneySound(cents: number, pitch: number)
	local spec = if cents >= 100 then GIVE_FX.sounds.note else GIVE_FX.sounds.coin
	local sound = SoundBank.make(spec.id)
	sound.Volume = spec.volume
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	sound:Play()
	task.delay(spec.cut, function()
		TweenService:Create(sound, TweenInfo.new(0.08), { Volume = 0 }):Play()
	end)
	Debris:AddItem(sound, spec.cut + 0.3)
end

-- Its value popping up over where it landed ("+$1"), rising and fading
local function valuePop(cents: number, at: Vector3, sign: string)
	local look = GIVE_FX.pop
	local anchor = Instance.new("Attachment")
	anchor.Position = at
	anchor.Parent = workspace.Terrain -- Terrain sits at the origin, so this is the world position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(look.width, look.height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.25, 0)
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(if sign == "+" then C.go else C.soft)
	label.TextStrokeColor3 = Color3.fromRGB(18, 22, 30)
	label.TextStrokeTransparency = 0.2
	label.Text = sign .. PaymentRules.pieceText(cents)
	label.Parent = gui
	local tween = TweenInfo.new(look.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, tween, { StudsOffsetWorldSpace = Vector3.new(0, 0.25 + look.rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(look.seconds * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, look.seconds * 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, look.seconds + 0.1)
end

-- The top of a value's stack in the open drawer (where a piece flies from and back to)
local function drawerStack(cents: number): BasePart?
	local model = unit()
	local drawer = if model then model:FindFirstChild("CashDrawer") else nil
	local found: BasePart? = nil
	if drawer then
		for _, part in drawer:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("Money") == cents and (not found or part.Position.Y > found.Position.Y) then
				found = part
			end
		end
	end
	return found
end

-- The exact change glows mint for a beat before it gives itself
local function flashExact()
	local look = GIVE_FX.exact
	exactGlow.Adornee = moneyPile()
	exactGlow.FillTransparency = look.fill
	exactGlow.OutlineTransparency = 0
	exactGlow.Enabled = true
	TweenService:Create(exactGlow, TweenInfo.new(look.seconds), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
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
	-- asleep unless someone pays by card: its keys covered, whatever was typed gone
	local awake = RegisterStationRules.keypadOn(now)
	keypadSleep.Visible = not awake
	if not awake and typed ~= "" then
		typed = ""
		keypadScreen.Text = "$0.00"
	end
	-- exact change gives itself after a beat ("Exact!" on the screen first)
	if now == "cash" and paying and giving() == change and change > 0 then
		if not autoGiveAt then
			flashExact()
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

-- `from`: where in the drawer it was tapped; it flies from there onto the counter
local function givePiece(cents: number, from: Vector3?)
	if #pieces >= Payment.MAX_PIECES then
		return
	end
	table.insert(pieces, cents)
	table.sort(pieces, function(a: number, b: number): boolean
		return a > b
	end)
	lastProgressAt = os.clock()
	layOutGiven()
	moneySound(cents, RegisterStationRules.givePitch(#pieces, GIVE_FX))
	local index = RegisterStationRules.addedIndex(pieces, cents)
	local piece = if index then givenPieces[index] else nil
	if piece and from then
		local rest = piece.rest
		flyPiece(piece, from, rest, GIVE_FX.fly, function()
			valuePop(cents, rest.Position, "+")
		end)
	end
end

-- A piece tapped on the counter goes back: the row closes up at once and a copy of it flies home to its drawer stack
local function takeBack(index: number)
	local cents = pieces[index]
	local lying = givenPieces[index]
	if not cents then
		return
	end
	local from = if lying then lying.rest else nil
	table.remove(pieces, index)
	lastProgressAt = os.clock()
	layOutGiven()
	moneySound(cents, GIVE_FX.sounds.backPitch)
	local home = drawerStack(cents)
	if from and home then
		valuePop(cents, from.Position, "-")
		local flying = buildPiece(cents, from)
		flying.part.CanQuery = false -- it can't be tapped on its way home
		flyPiece(flying, from.Position, (from - from.Position) + home.Position + Vector3.new(0, 0.05, 0), GIVE_FX.back, function()
			flying.part:Destroy()
		end)
		Debris:AddItem(flying.part, GIVE_FX.back + 0.5)
	end
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
	-- the register's own screen instead of the HUD; the party dock (the shop bar) and your cash stay, a sale's coins and
	-- XP flying into them (owner 2026-11-16: "money should be visible while I'm using cash register")
	Hud.keepOnly("register", { "party", "cash" })
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
	-- The server's yes is ManningRegister; without it in time (it said no: its toast says why) you step off again, not
	-- left on a register whose scans it refuses (Config/Register MAN_CONFIRM)
	manAsk += 1
	local mine, asked = manAsk, os.clock()
	task.spawn(function()
		while manned and manAsk == mine and player:GetAttribute("ManningRegister") ~= true and os.clock() - asked < RegisterConfig.MAN_CONFIRM do
			task.wait(0.1)
		end
		if manned and manAsk == mine and player:GetAttribute("ManningRegister") ~= true then
			RegisterStationController.Leave()
		end
	end)
	-- a sale's coins and XP sparks start from the register's screen while you man it; while the camera looks down at the
	-- drawer or the card machine (paying), from the middle of the view, where it looks
	SaleOrigin.set(function(): Vector2?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local glass = piece("RegisterScreen")
		if glass then
			local seen, onScreen = camera:WorldToViewportPoint(glass.Position)
			if onScreen then
				return Vector2.new(seen.X, seen.Y)
			end
		end
		return camera.ViewportSize / 2
	end)
	refresh()
end

function RegisterStationController.Leave()
	if not manned then
		return
	end
	manned = false
	Remotes.ManRegister:FireServer(false)
	SaleOrigin.set(nil)
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
	-- Leave's key (Config/RegisterStation LEAVE_PILL.key)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local typing = processed or UserInputService:GetFocusedTextBox() ~= nil
		if RegisterStationRules.leaveKey(input.KeyCode.Name, RegisterStation.LEAVE_PILL, manned, typing) then
			RegisterStationController.Leave()
		end
		return
	end
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
		takeBack(index)
		refresh()
		return
	end
	local cents = hit.Instance:GetAttribute("Money")
	if typeof(cents) == "number" and situation() == "cash" then
		local stack = drawerStack(cents)
		givePiece(cents, if stack then stack.Position + Vector3.new(0, 0.05, 0) else hit.Position)
		refresh()
	end
end

-- The drawer stack under the mouse glows while you count change, so it reads as something to tap
local function onHover(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local camera = workspace.CurrentCamera
	local model = unit()
	local drawer = if model then model:FindFirstChild("CashDrawer") else nil
	if not manned or not camera or not drawer or situation() ~= "cash" then
		hover.Enabled = false
		return
	end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { drawer }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 30, params)
	local cents = if hit then hit.Instance:GetAttribute("Money") else nil
	local stack = if typeof(cents) == "number" then drawerStack(cents) else nil
	hover.Adornee = stack
	hover.Enabled = stack ~= nil
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

-- A sale while you man the register (owner 2026-11-16, mockup approved; Config/RegisterStation SALE_FX): the screen
-- flashes "SOLD! +$12.50", coins burst out of it into your cash pill, which counts up as they land (the shop XP sparks
-- start from the register too: Util/SaleOrigin)
local function saleMoment(amount: number)
	local fx = RegisterStation.SALE_FX
	screen.sold(string.format(fx.soldWords, PaymentRules.money(math.round(amount * 100))))
	local from = SaleOrigin.get()
	local pill = UIController.GetCashPill()
	if not from or not pill or amount <= 0 then
		return
	end
	local count = RegisterStationRules.saleCoins(amount, fx)
	UIController.HoldCash(CoinBurst.duration(count), fx.rollSeconds, amount)
	CoinBurst.fly(UIController.GetScreenGui(), from, pill, count)
end

function RegisterStationController.Start()
	screen = RegisterScreen.build(player:WaitForChild("PlayerGui"), function()
		Remotes.Charge:FireServer()
	end, giveChange)
	buildKeypad()
	buildLeave()
	-- each sale raises this visit's takings (RegisterService); the change is the sale's amount
	local lastTaken = tonumber(player:GetAttribute("RegisterTaken")) or 0
	player:GetAttributeChangedSignal("RegisterTaken"):Connect(function()
		local taken = tonumber(player:GetAttribute("RegisterTaken")) or 0
		local amount = taken - lastTaken
		lastTaken = taken
		if manned and amount > 0 then
			saleMoment(amount)
		end
	end)
	helper = Instance.new("Highlight")
	helper.Name = "RegisterHelper"
	helper.FillColor = rgb(RegisterStation.HELPER_COLOR)
	helper.OutlineColor = rgb(RegisterStation.HELPER_COLOR)
	helper.FillTransparency = 0.45
	helper.DepthMode = Enum.HighlightDepthMode.Occluded
	helper.Enabled = false
	helper.Parent = player:WaitForChild("PlayerGui")
	hover = Instance.new("Highlight")
	hover.Name = "RegisterHover"
	hover.FillColor = rgb(GIVE_FX.hover.color)
	hover.OutlineColor = rgb(GIVE_FX.hover.color)
	hover.FillTransparency = GIVE_FX.hover.fill
	hover.DepthMode = Enum.HighlightDepthMode.Occluded
	hover.Enabled = false
	hover.Parent = player:WaitForChild("PlayerGui")
	exactGlow = Instance.new("Highlight")
	exactGlow.Name = "RegisterExact"
	exactGlow.FillColor = rgb(GIVE_FX.exact.color)
	exactGlow.OutlineColor = rgb(GIVE_FX.exact.color)
	exactGlow.DepthMode = Enum.HighlightDepthMode.Occluded
	exactGlow.Enabled = false
	exactGlow.Parent = player:WaitForChild("PlayerGui")

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
	UserInputService.InputChanged:Connect(onHover)
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
