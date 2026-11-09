--!strict
-- The first visit with Pish on this client (spec 2026-11-09-tutorial-pish-design 4, 5, 6): while the server says a step
-- is on (player attribute TutorialStep, Server/Services/TutorialService), this player's own Pish (a marker only this
-- client has, drawn by Util/PishVisual) leads them: he runs to the step's place and points, a paw trail leads there, a
-- bouncing paw marks the button or thing to use, a picture bubble over him says what, the paw row and his gift box sit
-- at the top (Util/TutorialCues). Town Pish is hidden for this player meanwhile. Skip needs holding; then a card with
-- the gift crossed out and a sad Pish asks again. A Pish button in the Manage tray replays it later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))

local TutorialController = {}

local STEPS = Pish.STEPS
local FOLLOW_RANGE = 40 -- studs: further from the step's place than this, Pish comes back to the player
local BESIDE = 3.5 -- studs he stands from the player or the place
local TRAIL_REFRESH = 8 -- studs the player moves before the trail is redrawn from where they are
local BUTTON = 56 -- px: the skip button (tap targets 48 px or more)
local GREEN = Color3.fromRGB(80, 205, 130)
local GREY = Color3.fromRGB(190, 195, 205)

-- Where each step points: a HUD button (in the Manage tray: `tray`), or a part of the player's shop
local TARGETS: { [string]: { hud: string?, tray: boolean?, part: string? } } = {
	giftPack = { hud = "Bag" },
	buildRack = { hud = "Build", tray = true },
	orderStock = { part = "OrderComputer" },
	stockRack = { part = "DeliverySpot" },
	customer = { part = "Register" },
	ringUp = { part = "Register" },
	gift = { hud = "Bag" },
	bye = {},
}

local player = Players.LocalPlayer
local marker: Part? = nil
local visual: PishVisual.Visual? = nil
local step = ""
local cues: { () -> () } = {}
local trailRemover: (() -> ())? = nil
local trailFrom: Vector3? = nil
local trailTo: Vector3? = nil
local pointedAt = "" -- the step he last ran to and pointed for
local shownKey = "" -- what the paw points at now (redrawn when it changes)
local skipButton: TextButton? = nil
local skipCard: Frame? = nil
local replayButton: TextButton? = nil
local leaving = false

local function root(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
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

-- The step's place in the player's shop (stocking: the pad, or the rack once a box is carried)
local function targetPart(stepId: string): BasePart?
	local plot = ownPlot()
	local spec = TARGETS[stepId]
	if not plot or not spec or not spec.part then
		return nil
	end
	if stepId == "stockRack" and (player:GetAttribute("CarryCount") or 0) > 0 then
		for _, item in plot:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("ShelfId") == Pish.RACK then
				return item
			end
		end
	end
	local found = plot:FindFirstChild(spec.part, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- The HUD button the step points at (the Manage tile while the tray it's in is shut)
local function targetButton(stepId: string): GuiObject?
	local spec = TARGETS[stepId]
	if not spec or not spec.hud then
		return nil
	end
	if spec.tray and not Hud.isTrayOpen() then
		return Hud.find("Manage")
	end
	return Hud.find(spec.hud)
end

local function clearCues()
	for _, remove in cues do
		remove()
	end
	cues = {}
	if trailRemover then
		trailRemover()
		trailRemover = nil
	end
	trailFrom, trailTo = nil, nil
end

local function play(clip: string, onDone: (() -> ())?)
	if visual then
		PishVisual.play(visual, clip, onDone)
	elseif onDone then
		task.delay(1, onDone)
	end
end

local function ensurePish()
	if marker then
		return
	end
	local at = root()
	local made = Instance.new("Part")
	made.Name = "TutorialPish"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.Transparency = 1
	made.Size = Vector3.new(2, 2, 2)
	local start = if at then at.Position + at.CFrame.RightVector * BESIDE else Vector3.zero
	made.CFrame = CFrame.new(Vector3.new(start.X, (if at then at.Position.Y - 3 else 0), start.Z))
	made.Parent = workspace
	marker = made
	visual = PishVisual.new(made)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Pish.LUCK.petRange
	prompt.Parent = made
	prompt.Triggered:Connect(function()
		play("petted")
		if visual then
			PishVisual.hearts(visual)
		end
		Remotes.PetPish:FireServer()
	end)
	TownPishController.SetHidden(true)
end

local function removePish()
	if visual then
		PishVisual.destroy(visual)
		visual = nil
	end
	if marker then
		marker:Destroy()
		marker = nil
	end
	TownPishController.SetHidden(false)
end

-- The paw over the step's button or place (redrawn when the tray opens or a box is picked up)
local function pointPaw()
	local button = targetButton(step)
	local part = targetPart(step)
	local key = if button then button:GetFullName() elseif part then part:GetFullName() else ""
	if key == shownKey then
		return
	end
	shownKey = key
	for _, remove in cues do
		remove()
	end
	cues = {}
	if button then
		table.insert(cues, TutorialCues.pawOn(button))
	elseif part then
		table.insert(cues, TutorialCues.pawOn(part))
	end
	local adornee = if visual then visual.body.root elseif marker then marker else nil
	local icon = Pish.STEP_ICONS[step]
	if adornee and icon then
		table.insert(cues, TutorialCues.bubble(adornee, icon, Pish.HEIGHT + 1.5))
	end
end

-- The paw trail from the player to the step's place, redrawn as they walk
local function updateTrail()
	local part = targetPart(step)
	local at = root()
	if not part or not at then
		if trailRemover then
			trailRemover()
			trailRemover = nil
		end
		return
	end
	local from = at.Position - Vector3.new(0, 3, 0)
	local moved = if trailFrom then (from - trailFrom).Magnitude else math.huge
	local retarget = trailTo == nil or (part.Position - trailTo).Magnitude > 1
	if moved < TRAIL_REFRESH and not retarget then
		return
	end
	if trailRemover then
		trailRemover()
	end
	trailFrom, trailTo = from, part.Position
	local ground = Vector3.new(part.Position.X, from.Y, part.Position.Z)
	trailRemover = TutorialCues.trail(from, ground)
end

-- Where Pish heads: beside the step's place, or beside the player when they've wandered off (or there's no place)
local function goal(): Vector3?
	local at = root()
	if not at then
		return nil
	end
	local feet = at.Position - Vector3.new(0, 3, 0)
	local part = targetPart(step)
	if part and (part.Position - feet).Magnitude <= FOLLOW_RANGE then
		local toward = Vector3.new(feet.X - part.Position.X, 0, feet.Z - part.Position.Z)
		local side = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(1, 0, 0)
		local spot = part.Position + side * (part.Size.Magnitude / 2 + BESIDE)
		return Vector3.new(spot.X, feet.Y, spot.Z)
	end
	local beside = feet + at.CFrame.RightVector * BESIDE
	return beside
end

local function moveTowardGoal(dt: number)
	local current = marker
	local target = goal()
	if not current or not target or leaving then
		return
	end
	local at = current.Position
	local flat = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	local distance = flat.Magnitude
	if distance > 0.3 then
		local stepLength = math.min(distance, Pish.TOWN.trotSpeed * dt)
		local nextAt = Vector3.new(at.X, target.Y, at.Z) + flat.Unit * stepLength
		current.CFrame = CFrame.lookAt(nextAt, nextAt + flat.Unit)
		return
	end
	-- Arrived: face the player, and point once per step at its place
	local me = root()
	if me then
		local look = Vector3.new(me.Position.X, at.Y, me.Position.Z)
		if (look - at).Magnitude > 0.1 then
			current.CFrame = CFrame.lookAt(at, look)
		end
	end
	if pointedAt ~= step and targetPart(step) then
		pointedAt = step
		play("point")
	end
end

-- The "really skip?" card: the gift crossed out, a sad Pish; a big green paw keeps going, a small grey skip skips
local function showSkipCard()
	if skipCard then
		return
	end
	TutorialCues.giftBox(true, true)
	if visual then
		PishVisual.sound(visual, "whimper")
		PishVisual.play(visual, "headTilt")
	end
	local card = Instance.new("Frame")
	card.Name = "SkipCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(300, 200)
	card.BackgroundColor3 = Color3.fromRGB(255, 248, 240)
	card.ZIndex = 40
	card.Parent = TutorialCues.screen()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Thickness = 4
	edge.Color = Color3.fromRGB(255, 255, 255)
	edge.Parent = card
	local giftIcon = Icon.make(card, "Gift", UDim2.fromOffset(84, 84))
	giftIcon.AnchorPoint = Vector2.new(0.5, 0)
	giftIcon.Position = UDim2.new(0.5, 0, 0, 14)
	local cross = Instance.new("TextLabel")
	cross.BackgroundTransparency = 1
	cross.AnchorPoint = Vector2.new(0.5, 0)
	cross.Position = UDim2.new(0.5, 0, 0, 14)
	cross.Size = UDim2.fromOffset(84, 84)
	cross.Text = "❌"
	cross.TextScaled = true
	cross.ZIndex = 42
	cross.Parent = card
	local keep = Instance.new("TextButton")
	keep.Name = "Keep"
	keep.Text = ""
	keep.AnchorPoint = Vector2.new(0, 1)
	keep.Position = UDim2.new(0, 18, 1, -16)
	keep.Size = UDim2.fromOffset(170, 64)
	keep.BackgroundColor3 = GREEN
	keep.ZIndex = 41
	keep.Parent = card
	local keepCorner = Instance.new("UICorner")
	keepCorner.CornerRadius = UDim.new(0, 18)
	keepCorner.Parent = keep
	local paw = Icon.make(keep, "Paw", UDim2.fromOffset(44, 44))
	paw.AnchorPoint = Vector2.new(0.5, 0.5)
	paw.Position = UDim2.fromScale(0.5, 0.5)
	local skip = Instance.new("TextButton")
	skip.Name = "ReallySkip"
	skip.Text = ""
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -18, 1, -20)
	skip.Size = UDim2.fromOffset(56, 52)
	skip.BackgroundColor3 = GREY
	skip.ZIndex = 41
	skip.Parent = card
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 14)
	skipCorner.Parent = skip
	local next = Icon.make(skip, "Next", UDim2.fromOffset(30, 30))
	next.AnchorPoint = Vector2.new(0.5, 0.5)
	next.Position = UDim2.fromScale(0.5, 0.5)
	local function close()
		card:Destroy()
		skipCard = nil
		TutorialCues.giftBox(step ~= "", false)
	end
	keep.Activated:Connect(close)
	skip.Activated:Connect(function()
		close()
		Remotes.TutorialAction:FireServer("skip")
	end)
	skipCard = card
end

-- The skip button: held for SKIP_HOLD seconds (its fill grows), a tap does nothing
local function makeSkipButton(): TextButton
	local button = Instance.new("TextButton")
	button.Name = "TutorialSkip"
	button.Text = ""
	-- Top left beside Pish's gift box, above the Manage tray: the right side is the HUD's (cash, weapon switch)
	button.Position = UDim2.fromOffset(TutorialCues.GIFT_RIGHT + 8, 4)
	button.Size = UDim2.fromOffset(BUTTON, BUTTON)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.ClipsDescendants = true
	button.ZIndex = 30
	button.Parent = TutorialCues.screen()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 70)
	fill.BorderSizePixel = 0
	fill.ZIndex = 30
	fill.Parent = button
	local next = Icon.make(button, "Next", UDim2.fromOffset(30, 30))
	next.AnchorPoint = Vector2.new(0.5, 0.5)
	next.Position = UDim2.fromScale(0.5, 0.5)
	next.ZIndex = 31
	local held: number? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held = os.clock()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held = nil
			TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 0) }):Play()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local since = held
		if not since then
			return
		end
		local share = math.clamp((os.clock() - since) / Pish.SKIP_HOLD, 0, 1)
		fill.Size = UDim2.fromScale(1, share)
		if share >= 1 then
			held = nil
			fill.Size = UDim2.fromScale(1, 0)
			showSkipCard()
		end
	end)
	return button
end

local function finishVisit()
	leaving = true
	clearCues()
	shownKey = ""
	TutorialCues.pawRow(0, 0)
	TutorialCues.giftBox(false, false)
	if skipButton then
		skipButton.Visible = false
	end
	if skipCard then
		skipCard:Destroy()
		skipCard = nil
	end
	local current = marker
	if not current then
		leaving = false
		return
	end
	-- He runs off and is gone; Town Pish comes back
	local away = current.Position + current.CFrame.LookVector * -20
	local tween = TweenService:Create(current, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.lookAt(away, away + (away - current.Position)),
	})
	tween:Play()
	tween.Completed:Wait()
	removePish()
	leaving = false
end

local function onStep()
	local value = player:GetAttribute("TutorialStep")
	local nextStep = if typeof(value) == "string" then value else ""
	if nextStep == step then
		return
	end
	local before = step
	step = nextStep
	shownKey = ""
	clearCues()
	if replayButton then
		replayButton.Visible = step == "" and player:GetAttribute("TutorialDone") == true
	end
	if step == "" then
		if before ~= "" then
			task.spawn(finishVisit)
		end
		return
	end
	ensurePish()
	if not skipButton then
		skipButton = makeSkipButton()
	end
	(skipButton :: TextButton).Visible = step ~= "bye"
	local index = table.find(STEPS, step) or 1
	TutorialCues.pawRow(index - 1, #STEPS)
	TutorialCues.giftBox(true, false)
	if before ~= "" and marker then
		TutorialCues.sparkle(marker.Position + Vector3.new(0, Pish.HEIGHT, 0))
		play("happyHop")
	end
	if step == "bye" then
		play("celebrate", function()
			Remotes.TutorialAction:FireServer("bye")
		end)
	end
	pointPaw()
end

function TutorialController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return
	end
	replayButton = Hud.fanButton({
		id = "Pish",
		icon = "Paw",
		label = "Pish",
		order = 6,
		onClick = function()
			Remotes.TutorialAction:FireServer("replay")
		end,
	})
	;(replayButton :: TextButton).Visible = player:GetAttribute("TutorialDone") == true
	player:GetAttributeChangedSignal("TutorialStep"):Connect(onStep)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		if replayButton then
			replayButton.Visible = step == "" and player:GetAttribute("TutorialDone") == true
		end
	end)
	local tick = 0
	RunService.RenderStepped:Connect(function(dt)
		if step == "" then
			if visual then
				PishVisual.step(visual, dt)
			end
			return
		end
		moveTowardGoal(dt)
		if visual then
			PishVisual.step(visual, dt)
		end
		tick += dt
		if tick >= 0.3 then
			tick = 0
			pointPaw()
			updateTrail()
		end
	end)
	onStep()
end

return TutorialController
