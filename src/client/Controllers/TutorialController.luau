--!strict
-- The first visit with Pish on this client (spec 2026-11-09-tutorial-pish-design 4, 5, 6): while the server says a step
-- is on (player attribute TutorialStep, Server/Services/TutorialService), this player's own Pish (a marker only this
-- client has, drawn by Util/PishVisual) leads them: he runs to the step's place and points, a paw trail leads there, a
-- bouncing paw marks the button or thing to use, a picture bubble over him says what, the paw row and his gift box sit
-- at the top (Util/TutorialCues). Town Pish is hidden for this player meanwhile. Skip needs holding; then a card with
-- the gift crossed out and a sad Pish asks again. A Pish button in the Manage tray replays it later.
-- Later he comes back the same way (spec 8): a lesson visit for each unlock the server says is waiting (run in, bark,
-- point at the new thing with its picture, leave after LESSON_SECONDS or once it's used; only when the player is free
-- and in town), and the stuck helper's nudge (point at the order computer or a waiting box).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Game = require(Config:WaitForChild("Game"))
local Music = require(Config:WaitForChild("Music"))
local Pish = require(Config:WaitForChild("Pish"))
local PishTalk = require(Config:WaitForChild("PishTalk"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local TalkRules = require(Shared:WaitForChild("Util"):WaitForChild("TalkRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local TutorialTalk = require(ClientUtil:WaitForChild("TutorialTalk"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

local TutorialController = {}

local STEPS = Pish.STEPS
local FOLLOW_RANGE = 40 -- studs: further from the step's place than this, Pish comes back to the player
local BESIDE = 3.5 -- studs he stands from the player or the place
local RUN_IN = 16 -- studs away a visiting Pish appears, to run in
local TRAIL_REFRESH = 8 -- studs the player moves before the trail is redrawn from where they are
local SKIP_BUTTON = Vector2.new(112, 48) -- px: the skip button on the tour bar (tap targets 48 px or more)
local SKIP_CARD = Vector2.new(360, 236) -- px: the "really skip?" card
local FREE_SECONDS = 3 -- a visit starts once the player has been free this long (the first-sword popup comes first)
local NUDGE_RANGE = 60 -- studs: a nudge shows only when the player is this near the thing to use
local PORTAL_REACH = 14 -- studs from the Wild portal that count as having gone to it
local SPOT_HEIGHT = 9 -- studs above the ground the paw over a place in town (the portal) hangs
local BYE_IDLE_SECONDS = 20 -- the goodbye's last line left this long: the first visit ends by itself
local GREY = Color3.fromRGB(190, 195, 205)

-- Where Pish points: a HUD button (in the Manage tray: `tray`), a button inside a window (`gui`), a part of the
-- player's shop (the Pack Rack instead while a box is carried: `carryRack`), or a spot in town
type Target = { hud: string?, tray: boolean?, part: string?, carryRack: boolean?, spot: Vector3?, gui: GuiObject? }

-- Each lesson's new thing: machines are bought in Build, new stock at the order computer, the first sword's way is the
-- Wild portal
local PORTAL = Wild.PLAZA_PORTAL
local LESSON_TARGETS: { [string]: Target } = {
	sleeves = { part = "OrderComputer" },
	sword = { spot = Vector3.new(PORTAL.x, PORTAL.y + SPOT_HEIGHT, PORTAL.z) },
	condenser = { hud = "Build", tray = true },
	forge = { hud = "Build", tray = true },
	expand = { part = "OrderComputer" },
	boosterBox = { part = "OrderComputer" },
	grading = { hud = "Build", tray = true },
	jobs = { hud = "Jobs", tray = true },
}
local LESSON_ICONS: { [string]: string } = {}
for _, lesson in Pish.LESSONS do
	LESSON_ICONS[lesson.id] = lesson.icon
end
-- The stuck helper's two nudges (Util/LessonRules.nudge)
local NUDGES: { [string]: { target: Target, icon: string } } = {
	order = { target = { part = "OrderComputer" }, icon = "Order" },
	stock = { target = { part = "DeliverySpot", carryRack = true }, icon = "Box" },
}

type Visit = { kind: "lesson" | "nudge", id: string, started: number }

local player = Players.LocalPlayer
local marker: Part? = nil
local visual: PishVisual.Visual? = nil
local step = ""
local introIndex = 1 -- Pish's intro line on now (Config/PishTalk), from 1 at each step
local byeSent = false
local lastLineAt = 0 -- os.clock() the goodbye's last line showed
local visit: Visit? = nil -- a lesson or nudge visit on now (never during the first visit)
local lessonQueue: { string } = {} -- lessons waiting to be shown, from the server
local pendingNudge: string? = nil
local freeSince: number? = nil
local spotAnchor: Part? = nil -- the paw's anchor at a spot in town
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

-- Shown on screen: it and every window it sits in are visible
local function shown(gui: Instance?): boolean
	local at = gui
	while at and at:IsA("GuiObject") do
		if not at.Visible then
			return false
		end
		at = at.Parent
	end
	return gui ~= nil
end

-- A window (or a thing in one) in the HUD's screen, by name, while it shows
local function inMainGui(name: string): GuiObject?
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("MainGui")
	local found = gui and gui:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") and shown(found) then found else nil
end

-- A button by name inside a window, while it shows
local function inside(window: GuiObject, name: string): GuiObject?
	local found = window:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") and shown(found) then found else nil
end

-- Pish's present or gift in the Bag: the Bag button, then its slot, then Open once it's the one showing
local function bagSituation(item: string): (string, Target)
	local bag = inMainGui("Bag")
	if not bag then
		return "default", { hud = "Bag" }
	end
	local details = bag:FindFirstChild("Details", true)
	if details and details:GetAttribute("ItemId") == item then
		local open = inside(bag, "Open")
		if open then
			return "picked", { gui = open }
		end
	end
	return "bagOpen", { gui = inside(bag, item) }
end

-- The windows each step works in; any other window open is in the way (Pish says to close it)
local STEP_WINDOWS: { [string]: { [string]: boolean } } = {
	giftPack = { Bag = true },
	gift = { Bag = true },
	buildRack = { BuildMenu = true },
	orderStock = { OrderMenu = true },
}

-- A window open that this step doesn't use, and its X
local function windowInTheWay(stepId: string): GuiObject?
	local allowed = STEP_WINDOWS[stepId] or {}
	for _, panel in UIKit.openPanelList() do
		if not allowed[panel.Name] and shown(panel) then
			local close = panel:FindFirstChild("Close", true)
			return if close and close:IsA("GuiObject") then close else panel
		end
	end
	return nil
end

-- What the player is at in this step (Config/PishTalk `now` lines) and where Pish points for it; first of all, a
-- window in the way to close
local function stepSituation(stepId: string): (string, Target)
	local inTheWay = windowInTheWay(stepId)
	if inTheWay then
		return "closeWindow", { gui = inTheWay }
	end
	if stepId == "giftPack" then
		return bagSituation(Pish.FIRST_ITEM)
	elseif stepId == "gift" then
		return bagSituation(Pish.GIFT_ITEM)
	elseif stepId == "buildRack" then
		if PlacementController.IsActive() then
			return "placing", {}
		end
		local shop = inMainGui("BuildMenu")
		if shop then
			return "shopOpen", { gui = inside(shop, Pish.RACK) }
		end
		if Hud.isTrayOpen() then
			return "trayOpen", { hud = "Build" }
		end
		return "default", { hud = "Manage" }
	elseif stepId == "orderStock" then
		local order = inMainGui("OrderMenu")
		local row = order and order:FindFirstChild(Pish.ORDER_PRODUCT, true)
		if order then
			return "orderOpen", { gui = if row then inside(row :: GuiObject, "Order") else nil }
		end
		return "default", { part = "OrderComputer" }
	elseif stepId == "stockRack" then
		local carrying = (player:GetAttribute("CarryCount") or 0) > 0
		return if carrying then "carrying" else "default", { part = "DeliverySpot", carryRack = true }
	elseif stepId == "customer" then
		return "default", { part = "Register" }
	elseif stepId == "ringUp" then
		local charge = inMainGui("Charge")
		if charge then
			return "charge", { gui = charge }
		end
		return "default", { part = "Register" }
	end
	return "default", {}
end

-- What Pish is on now, worked out once a tick (refreshFocus): its key (a change redraws the cues), target, picture,
-- the step's situation and whether he's still on his intro lines (no pointing yet)
local focusKey, focusTarget, focusIcon, focusSituation = "", nil :: Target?, nil :: string?, "default"
local talking = false

local function refreshFocus()
	if step ~= "" then
		local situation, target = stepSituation(step)
		local talk = PishTalk.STEPS[step]
		local line = if talk then TalkRules.show(talk, introIndex, situation) else nil
		talking = line ~= nil and line.next
		focusKey = step .. ":" .. (if talking then "intro" else situation)
		focusTarget = if talking then nil else target
		if step == "bye" then
			focusTarget = { hud = "Pish", tray = true } -- "Tap Manage, then Pish": where to find him later
		end
		focusIcon = Pish.STEP_ICONS[step]
		focusSituation = situation
		return
	end
	talking = false
	focusSituation = "default"
	local now = visit
	if not now then
		focusKey, focusTarget, focusIcon = "", nil, nil
	elseif now.kind == "lesson" then
		focusKey, focusTarget, focusIcon = "lesson:" .. now.id, LESSON_TARGETS[now.id], LESSON_ICONS[now.id]
	else
		local nudge = NUDGES[now.id]
		focusKey = "nudge:" .. now.id
		focusTarget = if nudge then nudge.target else nil
		focusIcon = if nudge then nudge.icon else nil
	end
end

local function focus(): (string, Target?, string?)
	return focusKey, focusTarget, focusIcon
end

-- An invisible anchor at a spot in town for the paw and the trail
local function anchorAt(at: Vector3): Part
	local made = spotAnchor
	if made and made.Parent and made.Position == at then
		return made
	end
	if made then
		made:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PishSpot"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = at
	anchor.Parent = workspace
	spotAnchor = anchor
	return anchor
end

-- The target's place: a spot in town, or a part of the player's shop (the rack once a box is carried)
local function partFor(spec: Target?): BasePart?
	if not spec then
		return nil
	end
	if spec.spot then
		return anchorAt(spec.spot)
	end
	local plot = ownPlot()
	if not plot or not spec.part then
		return nil
	end
	if spec.carryRack and (player:GetAttribute("CarryCount") or 0) > 0 then
		for _, item in plot:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("ShelfId") == Pish.RACK then
				return item
			end
		end
	end
	local found = plot:FindFirstChild(spec.part, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function targetPart(): BasePart?
	local _, spec = focus()
	return partFor(spec)
end

-- The button Pish points at: inside a window, or on the HUD (the Manage tile while the tray it's in is shut)
local function targetButton(): GuiObject?
	local _, spec = focus()
	if spec and spec.gui then
		return spec.gui
	end
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

-- His marker beside the player (`away` studs off for a visit, so he runs in)
local function ensurePish(away: number?)
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
	local start = if at then at.Position + at.CFrame.RightVector * (away or BESIDE) else Vector3.zero
	made.CFrame = CFrame.new(Vector3.new(start.X, (if at then at.Position.Y - 3 else 0), start.Z))
	made.Parent = workspace
	marker = made
	visual = PishVisual.new(made)
	if visual then
		PishVisual.nameTag(visual, nil) -- no petting while he's teaching (owner 2026-11-10)
	end
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

-- The paw over the button or place to use (redrawn when a window opens or a box is picked up)
local function pointPaw()
	local key, _ = focus()
	local button = targetButton()
	local part = if button then nil else targetPart()
	local drawn = key .. "|" .. (if button then button:GetFullName() elseif part then part:GetFullName() else "")
	if drawn == shownKey then
		return
	end
	shownKey = drawn
	for _, remove in cues do
		remove()
	end
	cues = {}
	if button then
		table.insert(cues, TutorialCues.pawOn(button))
	elseif part then
		table.insert(cues, TutorialCues.pawOn(part))
	end
end

-- Pish's line on the talk card for the step (Config/PishTalk, Util/TalkRules): his intro one line at a time with Next,
-- then the line for what to do now; the goodbye's last Next ends the first visit
local function updateTalk()
	local talk = PishTalk.STEPS[step]
	if step == "" or not talk then
		return
	end
	local line = TalkRules.show(talk, introIndex, focusSituation)
	local label = if not line.next then nil elseif line.finish then PishTalk.BYE else PishTalk.NEXT
	local text = if not line.next and focusSituation == "closeWindow" then PishTalk.LABELS.close else line.text
	TutorialTalk.say(TalkRules.fill(text, Game.NAME), focusIcon, label, function()
		if line.finish then
			if step == "bye" and not byeSent then
				byeSent = true
				Remotes.TutorialAction:FireServer("bye")
			end
			return
		end
		introIndex += 1
		refreshFocus()
		updateTalk()
	end)
end

-- The paw trail from the player to the place, redrawn as they walk
local function updateTrail()
	local part = targetPart()
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
	local part = targetPart()
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
	-- Arrived: face the player, and point once per step at its place (a visit barks first)
	local me = root()
	if me then
		local look = Vector3.new(me.Position.X, at.Y, me.Position.Z)
		if (look - at).Magnitude > 0.1 then
			current.CFrame = CFrame.lookAt(at, look)
		end
	end
	local key = focus()
	if pointedAt == key then
		return
	end
	local part = targetPart()
	if visit then
		pointedAt = key
		play("bark", if part then function()
			play("point")
		end else nil)
	elseif part then
		pointedAt = key
		play("point")
	end
end

-- The "really skip?" card (with words, owner 2026-11-10): "Skip Pish's tour?", his gift crossed out, a sad Pish; a big
-- green "Keep going" carries on, a small grey "Skip" skips
local function showSkipCard()
	if skipCard then
		return
	end
	local labels = PishTalk.LABELS
	if visual then
		PishVisual.sound(visual, "whimper")
		PishVisual.play(visual, "headTilt")
	end
	local card = Instance.new("Frame")
	card.Name = "SkipCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(SKIP_CARD.X, SKIP_CARD.Y)
	card.ZIndex = 40
	card.Parent = TutorialCues.screen()
	UIKit.creamWindow(card)
	local ink = UIKit.colorsFor(card).ink
	local title = UIKit.label(card, labels.skipTitle, Enum.Font.FredokaOne, 26, ink)
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local giftIcon = Icon.make(card, "Gift", UDim2.fromOffset(64, 64))
	giftIcon.AnchorPoint = Vector2.new(0.5, 0)
	giftIcon.Position = UDim2.new(0.5, 0, 0, 48)
	local cross = Instance.new("TextLabel")
	cross.BackgroundTransparency = 1
	cross.AnchorPoint = Vector2.new(0.5, 0)
	cross.Position = UDim2.new(0.5, 0, 0, 48)
	cross.Size = UDim2.fromOffset(64, 64)
	cross.Text = "❌"
	cross.TextScaled = true
	cross.ZIndex = 42
	cross.Parent = card
	local warning = UIKit.label(card, labels.skipWarning, Enum.Font.FredokaOne, 19, ink)
	warning.Position = UDim2.fromOffset(0, 116)
	warning.Size = UDim2.new(1, 0, 0, 24)
	warning.TextXAlignment = Enum.TextXAlignment.Center
	local keep = UIKit.button(card, labels.keepGoing, UIKit.Colors.Success)
	keep.Name = "Keep"
	keep.AnchorPoint = Vector2.new(0, 1)
	keep.Position = UDim2.new(0, 18, 1, -16)
	keep.Size = UDim2.fromOffset(190, 56)
	keep.Font = Enum.Font.FredokaOne
	keep.TextSize = 22
	local skip = UIKit.button(card, labels.skipYes, GREY)
	skip.Name = "ReallySkip"
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -18, 1, -20)
	skip.Size = UDim2.fromOffset(96, 48)
	skip.Font = Enum.Font.FredokaOne
	skip.TextSize = 18
	local function close()
		card:Destroy()
		skipCard = nil
	end
	keep.Activated:Connect(close)
	skip.Activated:Connect(function()
		close()
		Remotes.TutorialAction:FireServer("skip")
	end)
	skipCard = card
end

-- The skip button on the tour bar: "Skip tour", "hold to skip" under it; held for SKIP_HOLD seconds (its fill grows),
-- a tap does nothing
local function makeSkipButton(): TextButton
	local labels = PishTalk.LABELS
	local button = Instance.new("TextButton")
	button.Name = "TutorialSkip"
	button.Text = ""
	button.LayoutOrder = 4
	button.Size = UDim2.fromOffset(SKIP_BUTTON.X, SKIP_BUTTON.Y)
	button.BackgroundColor3 = Color3.fromRGB(238, 240, 246)
	button.AutoButtonColor = false
	button.ClipsDescendants = true
	button.ZIndex = 30
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	UIKit.outline(button, GREY, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 210, 160)
	fill.BorderSizePixel = 0
	fill.ZIndex = 30
	fill.Parent = button
	local words = UIKit.label(button, labels.skip, Enum.Font.FredokaOne, 18, Color3.fromRGB(80, 84, 104))
	words.Position = UDim2.fromOffset(0, 4)
	words.Size = UDim2.new(1, 0, 0, 22)
	words.TextXAlignment = Enum.TextXAlignment.Center
	words.ZIndex = 31
	local hint = UIKit.label(button, labels.skipHold, Enum.Font.GothamBold, 11, Color3.fromRGB(130, 136, 160))
	hint.Position = UDim2.fromOffset(0, 26)
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.ZIndex = 31
	local held: number? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held = os.clock()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held = nil
			TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 1) }):Play()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local since = held
		if not since then
			return
		end
		local share = math.clamp((os.clock() - since) / Pish.SKIP_HOLD, 0, 1)
		fill.Size = UDim2.fromScale(share, 1)
		if share >= 1 then
			held = nil
			fill.Size = UDim2.fromScale(0, 1)
			showSkipCard()
		end
	end)
	return button
end

local function finishVisit()
	leaving = true
	clearCues()
	shownKey = ""
	TutorialTalk.hide()
	TutorialCues.hideBar()
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
	if spotAnchor then
		spotAnchor:Destroy()
		spotAnchor = nil
	end
	leaving = false
end

local function inTown(): boolean
	local at = root()
	return at ~= nil and MusicRules.inTown(at.Position.X, at.Position.Z, Town.BOUNDS, Music.TOWN.margin)
end

-- Free for a visit: in town, no window, fight, pack opening or weapon reveal on
local function isFree(): boolean
	return inTown()
		and not UIKit.anyPanelOpen()
		and not OpeningStage.isShown()
		and not BattleController.IsFighting()
		and not WeaponRevealController.IsPlaying()
end

-- The visit's new thing was used: a window opened (the tile's, the order computer's), a box picked up for stocking,
-- or the player went to the spot (or through the portal, out of town)
local function visitUsed(spec: Target?): boolean
	if not spec then
		return false
	end
	if UIKit.anyPanelOpen() then
		return true
	end
	if spec.carryRack and (player:GetAttribute("CarryCount") or 0) > 0 then
		return true
	end
	local spot = spec.spot
	local at = root()
	if spot and at then
		local flat = Vector3.new(spot.X - at.Position.X, 0, spot.Z - at.Position.Z)
		return flat.Magnitude <= PORTAL_REACH or not inTown()
	end
	return false
end

local function startVisit(kind: "lesson" | "nudge", id: string)
	visit = { kind = kind, id = id, started = os.clock() }
	pointedAt = ""
	shownKey = ""
	clearCues()
	ensurePish(RUN_IN)
	refreshFocus()
	local line = if kind == "lesson" then PishTalk.LESSONS[id] else PishTalk.NUDGES[id]
	if line then
		TutorialTalk.say(TalkRules.fill(line, Game.NAME), focusIcon, nil, nil)
	end
	if kind == "lesson" then
		Remotes.TutorialAction:FireServer("lessonShown", id)
	end
end

-- The visit is over: a lesson is reported done (never shown again), and Pish runs off
local function endVisit(used: boolean)
	local ended = visit
	if not ended then
		return
	end
	visit = nil
	if ended.kind == "lesson" then
		local index = table.find(lessonQueue, ended.id)
		if index then
			table.remove(lessonQueue, index)
		end
		Remotes.TutorialAction:FireServer("lessonDone", ended.id, used)
	end
	task.spawn(finishVisit)
end

-- Every few frames outside the first visit: end the visit on now, or start the next one once the player is free
local function updateVisit()
	local now = visit
	if now then
		local _, spec = focus()
		if visitUsed(spec) then
			endVisit(true)
		elseif os.clock() - now.started >= Pish.LESSON_SECONDS then
			endVisit(false)
		end
		return
	end
	if leaving or marker then
		return
	end
	local free = isFree()
	freeSince = if free then (freeSince or os.clock()) else nil
	local nudge = pendingNudge
	if nudge then
		pendingNudge = nil
		local spec = NUDGES[nudge]
		local part = if spec then partFor(spec.target) else nil
		local at = root()
		if free and part and at and (part.Position - at.Position).Magnitude <= NUDGE_RANGE then
			startVisit("nudge", nudge)
		end
		return
	end
	if #lessonQueue > 0 and freeSince and os.clock() - freeSince >= FREE_SECONDS then
		startVisit("lesson", lessonQueue[1])
	end
end

-- The server's lesson queue, or a nudge from the stuck helper
local function onState(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local lessons = (payload :: any).lessons
	if typeof(lessons) == "table" then
		local queue = {}
		for _, id in lessons do
			if typeof(id) == "string" and LESSON_TARGETS[id] then
				table.insert(queue, id)
			end
		end
		lessonQueue = queue
	end
	local nudge = (payload :: any).nudge
	if typeof(nudge) == "string" and NUDGES[nudge] and step == "" and not visit then
		pendingNudge = nudge
	end
end

-- The Pish button in the Manage tray: after the first visit, and at its goodbye ("Tap Manage, then Pish")
local function replayShown(): boolean
	return step == "bye" or (step == "" and player:GetAttribute("TutorialDone") == true)
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
	introIndex = 1
	byeSent = false
	clearCues()
	if step ~= "" then
		visit = nil -- a replay takes over a visit; its lesson stays waiting
	end
	refreshFocus()
	if replayButton then
		replayButton.Visible = replayShown()
	end
	if step == "" then
		if before ~= "" then
			task.spawn(finishVisit)
		end
		return
	end
	ensurePish()
	local index = table.find(STEPS, step) or 1
	local bar = TutorialCues.topBar(index - 1, #STEPS)
	local skip = skipButton or makeSkipButton()
	skipButton = skip
	skip.Parent = bar
	skip.Visible = step ~= "bye"
	if before ~= "" and marker then
		TutorialCues.sparkle(marker.Position + Vector3.new(0, Pish.HEIGHT, 0))
		play("happyHop")
	end
	if step == "bye" then
		play("celebrate") -- his goodbye ends on its last line's button (updateTalk), or by itself (BYE_IDLE_SECONDS)
	end
	updateTalk()
	pointPaw()
end

-- The goodbye's last line left alone a while: the first visit ends by itself
local function byeIdle()
	if step ~= "bye" or byeSent then
		return
	end
	local talk = PishTalk.STEPS.bye
	if introIndex < #talk.intro then
		lastLineAt = 0
		return
	end
	if lastLineAt == 0 then
		lastLineAt = os.clock()
	elseif os.clock() - lastLineAt >= BYE_IDLE_SECONDS then
		byeSent = true
		Remotes.TutorialAction:FireServer("bye")
	end
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
	;(replayButton :: TextButton).Visible = replayShown()
	player:GetAttributeChangedSignal("TutorialStep"):Connect(onStep)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		if replayButton then
			replayButton.Visible = replayShown()
		end
	end)
	Remotes.TutorialState.OnClientEvent:Connect(onState)
	local tick = 0
	RunService.RenderStepped:Connect(function(dt)
		local leading = step ~= "" or visit ~= nil
		if leading then
			moveTowardGoal(dt)
		end
		if visual then
			PishVisual.step(visual, dt)
		end
		tick += dt
		if tick < 0.3 then
			return
		end
		tick = 0
		-- A pack opening, a fight or a weapon reveal has the screen: Pish waits quietly (his card, bar and paws hidden)
		local busy = OpeningStage.isShown() or BattleController.IsFighting() or WeaponRevealController.IsPlaying()
		TutorialCues.screen().Enabled = not busy
		if busy then
			if shownKey ~= "" then
				clearCues()
				shownKey = ""
			end
			if step == "" then
				updateVisit()
			end
			return
		end
		refreshFocus()
		TutorialTalk.keepClear(if focusTarget then focusTarget.gui else nil)
		if step ~= "" then
			updateTalk()
			byeIdle()
		end
		if leading then
			pointPaw()
			updateTrail()
		end
		if step == "" then
			updateVisit()
		end
	end)
	onStep()
end

return TutorialController
