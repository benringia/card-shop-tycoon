--!strict
-- The first visit with Pish on this client (spec 2026-11-09-tutorial-pish-design 4, 5, 6): while the server says a step
-- is on (player attribute TutorialStep, Server/Services/TutorialService), this player's own Pish (a marker only this
-- client has, drawn by Util/PishVisual) leads them: he runs to the step's place and points, a paw trail leads there, a
-- bouncing paw marks the button or thing to use, a picture bubble over him says what, the paw row and his gift box sit
-- at the top (Util/TutorialCues). Town Pish is hidden for this player meanwhile. Skip needs holding; then a card with
-- the gift crossed out and a sad Pish asks again. A Pish button in the Manage tray replays it later.
-- Later he comes back the same way (spec 8, 16): a lesson visit for each unlock the server says is waiting (run in,
-- bark, say what's new; a shelf, machine, trophy or new stock he then teaches step by step, like the first visit, until
-- the server sees it placed or ordered; the first sword and jobs he points at; he leaves after LESSON_SECONDS with
-- nothing done; only when the player is free and in town), and the stuck helper's nudge (the order computer or a box).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Game = require(Config:WaitForChild("Game"))
local Music = require(Config:WaitForChild("Music"))
local Pish = require(Config:WaitForChild("Pish"))
local PishTalk = require(Config:WaitForChild("PishTalk"))
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local ArrivalShot = require(Shared:WaitForChild("Util"):WaitForChild("ArrivalShot"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local TalkRules = require(Shared:WaitForChild("Util"):WaitForChild("TalkRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local HudMascotView = require(ClientUtil:WaitForChild("HudMascotView"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local TutorialTalk = require(ClientUtil:WaitForChild("TutorialTalk"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

local TutorialController = {}

local STEPS = Pish.STEPS
local FOLLOW_RANGE = 40 -- studs: further from the step's place than this, Pish comes back to the player
local BESIDE = 3.5 -- studs he stands from the player or the place
local RUN_IN = 16 -- studs away a visiting Pish appears, to run in
local TRAIL_REFRESH = 8 -- studs the player moves before the trail is redrawn from where they are
local FREE_SECONDS = 3 -- a visit starts once the player has been free this long (the first-sword popup comes first)
local NUDGE_RANGE = 60 -- studs: a nudge shows only when the player is this near the thing to use
local PORTAL_REACH = 14 -- studs from the Wild portal that count as having gone to it
local SPOT_HEIGHT = 9 -- studs above the ground the paw over a place in town (the portal) hangs
local ARRIVAL = Pish.ARRIVAL -- his arrival's numbers and shot (Util/ArrivalShot)
local BYE_IDLE_SECONDS = 20 -- the goodbye's last line left this long: the first visit ends by itself

-- Where Pish points: a HUD button (in the Manage tray: `tray`), a button inside a window (`gui`), a part of the
-- player's shop (the Pack Rack instead while a box is carried: `carryRack`), or a spot in town
-- `placed`: a shelf the player has placed (its Config/Shelves id; "trophy": any trophy), the nearest one
type Target = {
	hud: string?,
	tray: boolean?,
	part: string?,
	carryRack: boolean?,
	spot: Vector3?,
	gui: GuiObject?,
	placed: string?,
}

-- Each lesson (Config/Pish LESSONS) by id. One with a shelf, a product or the trophy is taught step by step
-- (lessonSituation); the others point at one place: the first sword's way is the Wild portal, jobs their tile
type Lesson = { id: string, level: number?, icon: string, shelf: string?, product: string?, trigger: string? }
local PORTAL = Wild.PLAZA_PORTAL
local LESSONS: { [string]: Lesson } = {}
for _, lesson in Pish.LESSONS do
	LESSONS[lesson.id] = lesson
end
local POINT_AT: { [string]: Target } = {
	sword = { spot = Vector3.new(PORTAL.x, PORTAL.y + SPOT_HEIGHT, PORTAL.z) },
	jobs = { hud = "Jobs", tray = true },
}
-- The stuck helper's two nudges (Util/LessonRules.nudge)
local NUDGES: { [string]: { target: Target, icon: string } } = {
	order = { target = { part = "OrderComputer" }, icon = "Order" },
	stock = { target = { part = "DeliverySpot", carryRack = true }, icon = "Box" },
}

-- `started`: when it began, or the player's last step in a lesson that teaches; `firstKey`: where they were when it
-- began (a step away from it ends his first line); `lastKey`: where they were at the last tick; `introDone`: his first
-- line is over
type Visit = {
	kind: "lesson" | "nudge",
	id: string,
	started: number,
	firstKey: string?,
	lastKey: string?,
	introDone: boolean?,
	after: number?, -- it's placed or ordered: the PishTalk.AFTER line he's on (past the last: the visit ends)
}

local player = Players.LocalPlayer
local marker: Part? = nil
local visual: PishVisual.Visual? = nil
local step = ""
local introIndex = 1 -- Pish's intro line on now (Config/PishTalk), from 1 at each step
local byeSent = false
local lastLineAt = 0 -- os.clock() the goodbye's last line showed
local arriving = false -- his arrival is playing (the camera and his run are its own)
local arrivedOnce = false
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
local shownTarget: Instance? = nil -- the button or part the paw is on
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
	["lesson:build"] = { BuildMenu = true },
	["lesson:order"] = { OrderMenu = true },
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

local function teaches(lesson: Lesson): boolean
	return lesson.shelf ~= nil or lesson.product ~= nil or lesson.trigger == "trophy"
end

-- The trophy the player holds, to place (the trophy lesson's tile)
local function heldTrophy(): string?
	for _, def in Shelves.List do
		if def.kind == "Trophy" and def.requiresItem and BuildController.ItemCount(def.requiresItem) > 0 then
			return def.id
		end
	end
	return nil
end

-- Where the player is in a lesson that teaches its new thing (Config/PishTalk TEACH) and where Pish points, plus the
-- name his line says: Manage, Shop, its tab, its tile, placing it; or the computer, then its Order button
local function lessonSituation(lesson: Lesson): (string, Target, string)
	if lesson.product then
		local inTheWay = windowInTheWay("lesson:order")
		if inTheWay then
			return "closeWindow", { gui = inTheWay }, ""
		end
		local product = Products.ById[lesson.product]
		local name = if product then product.name else lesson.product
		local order = inMainGui("OrderMenu")
		if order then
			local row = order:FindFirstChild(lesson.product, true)
			return "orderOpen", { gui = if row and row:IsA("GuiObject") then inside(row, "Order") else nil }, name
		end
		return "computer", { part = "OrderComputer" }, name
	end
	local inTheWay = windowInTheWay("lesson:build")
	if inTheWay then
		return "closeWindow", { gui = inTheWay }, ""
	end
	if PlacementController.IsActive() then
		return "placing", {}, ""
	end
	local shelfId = lesson.shelf or heldTrophy()
	local def = if shelfId then Shelves.ById[shelfId] else nil
	local shop = inMainGui("BuildMenu")
	if shop then
		local tile = if shelfId then inside(shop, shelfId) else nil
		if tile and def then
			return "tile", { gui = tile }, def.name
		end
		local category = if def then def.category else "Trophies"
		return "tab", { gui = inside(shop, "Tab" .. category) }, category
	end
	if Hud.isTrayOpen() then
		return "trayOpen", { hud = "Build" }, ""
	end
	return "default", { hud = "Build", tray = true }, ""
end

-- What Pish is on now, worked out once a tick (refreshFocus): its key (a change redraws the cues), target, picture,
-- the step's situation and whether he's still on his intro lines (no pointing yet); in a lesson, the name its line says
local focusKey, focusTarget, focusIcon, focusSituation = "", nil :: Target?, nil :: string?, "default"
local focusName = ""
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
			-- "Tap me on your party bar": the peeking Pish there is the Pish button (round 5)
			local mascot = HudMascotView.tapArea()
			focusTarget = if mascot then { gui = mascot } else nil
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
		local lesson = LESSONS[now.id]
		if lesson and teaches(lesson) and now.after then
			-- Placed or ordered: he stands by it (the box's pad for new stock) and says what it's for
			local placed = if lesson.trigger == "trophy" then "trophy" else lesson.shelf
			focusKey, focusIcon, focusSituation = "lesson:" .. now.id .. ":after", lesson.icon, "after"
			focusTarget = if placed then { placed = placed } else { part = "DeliverySpot" }
		elseif lesson and teaches(lesson) then
			local situation, target, name = lessonSituation(lesson)
			focusKey, focusTarget, focusIcon = "lesson:" .. now.id .. ":" .. situation, target, lesson.icon
			focusSituation, focusName = situation, name
		else
			focusKey, focusTarget = "lesson:" .. now.id, POINT_AT[now.id]
			focusIcon = if lesson then lesson.icon else nil
		end
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
	local placed = spec.placed
	if plot and placed then
		local at = root()
		local nearest: BasePart? = nil
		for _, item in plot:GetDescendants() do
			local id = item:GetAttribute("ShelfId")
			local match = typeof(id) == "string" and (id == placed or (placed == "trophy" and string.sub(id, 1, 7) == "trophy_"))
			if match and item:IsA("BasePart") then
				local closer = not nearest or not at or (item.Position - at.Position).Magnitude < (nearest.Position - at.Position).Magnitude
				if closer then
					nearest = item
				end
			end
		end
		return nearest
	end
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

-- A thing in the shop or town to point at; none while a window is open (the paw and the trail are drawn over the
-- screen, so they'd sit on top of the window)
local function targetPart(): BasePart?
	if UIKit.anyPanelOpen() then
		return nil
	end
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
	local target: Instance? = button or part
	local drawn = key .. "|" .. (if target then target:GetFullName() else "")
	-- The same place by name is not enough: a window that rebuilds its buttons (the Bag after a tap) makes new ones
	-- under the same names, and the paw on the old one would vanish (final review I2)
	if drawn == shownKey and target == shownTarget then
		return
	end
	shownKey = drawn
	shownTarget = target
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
	-- The tour card has the middle of the screen: Pish's card waits under it (no overlap)
	if TutorialCues.isTourCardOpen() then
		TutorialTalk.hide()
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

-- Skip tapped (round 3: "if they click it. the progress and discouragement element shows up"): a sad Pish and the
-- tour card (Util/TutorialCues.tourCard): how far they are, his gift at the end, Keep going or Skip tour
local function openTourCard()
	if visual then
		PishVisual.sound(visual, "whimper")
		PishVisual.play(visual, "headTilt")
	end
	local index = table.find(STEPS, step) or 1
	TutorialCues.tourCard(index - 1, #STEPS, function()
		updateTalk()
	end, function()
		Remotes.TutorialAction:FireServer("skip")
	end)
	updateTalk()
end

local function finishVisit()
	leaving = true
	clearCues()
	shownKey = ""
	TutorialTalk.hide()
	TutorialCues.skipButton(false, openTourCard)
	TutorialCues.closeTourCard()
	TutorialCues.spotlight(nil)
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

local function teaching(now: Visit?): Lesson?
	local lesson = if now and now.kind == "lesson" then LESSONS[now.id] else nil
	return if lesson and teaches(lesson) then lesson else nil
end

-- A lesson that teaches: his line about the new thing with Next (until they tap it or take a step), then the line for
-- where they are (Config/PishTalk TEACH)
local function updateLessonTalk()
	local now = visit
	if not now or not teaching(now) then
		return
	end
	local afterIndex = now.after
	if afterIndex then
		local lines = PishTalk.AFTER[now.id] or {}
		local last = afterIndex >= #lines
		TutorialTalk.say(lines[afterIndex] or "", focusIcon, if last then PishTalk.BYE else PishTalk.NEXT, function()
			now.after = afterIndex + 1 -- past the last line updateVisit ends the visit
			now.started = os.clock()
			updateLessonTalk()
		end)
		return
	end
	if not now.introDone and focusKey ~= now.firstKey then
		now.introDone = true -- they're already on their way
	end
	if not now.introDone then
		TutorialTalk.say(TalkRules.fill(PishTalk.LESSONS[now.id] or "", Game.NAME), focusIcon, PishTalk.NEXT, function()
			now.introDone = true
			now.started = os.clock() -- Next is a step too: the quiet time starts again
			updateLessonTalk()
		end)
		return
	end
	local line = PishTalk.TEACH[focusSituation] or PishTalk.TEACH.default
	TutorialTalk.say(string.format(line, focusName), focusIcon, nil, nil)
end

local function startVisit(kind: "lesson" | "nudge", id: string)
	visit = { kind = kind, id = id, started = os.clock() }
	pointedAt = ""
	shownKey = ""
	clearCues()
	ensurePish(RUN_IN)
	refreshFocus()
	local now = visit :: Visit
	now.firstKey = focusKey
	if teaching(now) then
		updateLessonTalk()
	else
		local line = if kind == "lesson" then PishTalk.LESSONS[id] else PishTalk.NUDGES[id]
		if line then
			TutorialTalk.say(TalkRules.fill(line, Game.NAME), focusIcon, nil, nil)
		end
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
		if teaching(now) then
			local afterIndex = now.after
			if afterIndex then
				-- Saying what it's for: over after his last line, or left alone a while
				local lines = PishTalk.AFTER[now.id] or {}
				if afterIndex > #lines or os.clock() - now.started >= Pish.TEACH_QUIET_SECONDS then
					endVisit(true)
				end
				return
			end
			-- Done when the server sees it placed or ordered (onState); each step the player takes gives him more time
			if focusKey ~= now.firstKey and focusKey ~= now.lastKey then
				now.lastKey = focusKey
				now.started = os.clock()
			end
			if os.clock() - now.started >= Pish.TEACH_QUIET_SECONDS then
				endVisit(false)
			end
			return
		end
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
			if typeof(id) == "string" and LESSONS[id] then
				table.insert(queue, id)
			end
		end
		lessonQueue = queue
		-- The lesson being taught is no longer waiting: the server saw it placed or ordered. A happy hop, then he says
		-- what it's for (PishTalk.AFTER) before he goes
		local now = visit
		if now and now.kind == "lesson" and not now.after and not table.find(queue, now.id) then
			if marker then
				TutorialCues.sparkle(marker.Position + Vector3.new(0, Pish.HEIGHT, 0))
				play("happyHop")
			end
			if teaching(now) and PishTalk.AFTER[now.id] then
				now.after = 1
				now.started = os.clock()
				refreshFocus()
				updateLessonTalk()
			else
				endVisit(true)
			end
		end
	end
	local nudge = (payload :: any).nudge
	if typeof(nudge) == "string" and NUDGES[nudge] and step == "" and not visit then
		pendingNudge = nudge
	end
end

-- Pish arrives (round 3; the shot round 5, owner 2026-11-10): after the welcome flight a bark, then the camera rides
-- low beside him on his paws as he runs in from the street, slowly pans up to his face, and zooms out to the two of you
-- as he stops in front of the player and barks (Util/ArrivalShot, Config/Pish ARRIVAL); then the camera goes back
-- behind the player and he starts talking. Once per first visit (a replay starts without it); a tap skips it
local function arrive()
	arriving = true
	arrivedOnce = true
	TutorialTalk.hide()
	TutorialCues.skipButton(false, openTourCard)
	-- A player back mid-tour joins straight into it: he waits for the loading screen to go
	local waited = 0
	while player:GetAttribute("LoadingDone") ~= true and waited < ARRIVAL.waitLimit do
		waited += task.wait(0.2)
	end
	if waited > 0 then
		task.wait(ARRIVAL.afterLoading) -- the loading screen's fade, so the first shot isn't under it
	end
	local at = root()
	if not at or step ~= STEPS[1] then
		arriving = false
		if step ~= "" then
			ensurePish()
			TutorialCues.skipButton(step ~= "bye", openTourCard)
			updateTalk()
		end
		return
	end
	local up = Vector3.yAxis
	local look = Vector3.new(at.CFrame.LookVector.X, 0, at.CFrame.LookVector.Z).Unit
	local feet = at.Position - Vector3.new(0, 3, 0)
	ensurePish()
	local dog = marker :: Part
	local blockers = RaycastParams.new()
	blockers.FilterType = Enum.RaycastFilterType.Exclude
	blockers.FilterDescendantsInstances = { player.Character :: Instance, dog, if visual then visual.body.model else dog }
	local function freeFor(from: Vector3, way: Vector3, length: number): number
		local hit = workspace:Raycast(from, way * length, blockers)
		return if hit then hit.Distance else length
	end
	-- His run: in front of the player if it's clear, else the first clear way fanning out left and right, else the
	-- longest (Util/ArrivalShot.pickRun): he never runs through a shelf or a wall
	local ways, clearance = {}, {}
	for _, degrees in { 0, 30, -30, 60, -60, 90, -90, 135, -135, 180 } do
		local way = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(look)
		table.insert(ways, way)
		table.insert(clearance, freeFor(feet + up * 1.2, way, ARRIVAL.from + ARRIVAL.wallGap))
	end
	local index, runFrom = ArrivalShot.pickRun(clearance, ARRIVAL)
	local outward = ways[index]
	local across = Vector3.new(-outward.Z, 0, outward.X) -- to the side of his way in
	local stop = feet + outward * ARRIVAL.stop + across * ARRIVAL.stopSide
	local start = feet + outward * runFrom + across * math.min(ARRIVAL.startSide, runFrom * 0.15)
	local run = Vector3.new(stop.X - start.X, 0, stop.Z - start.Z)
	local runLength = run.Magnitude
	local runWay = run.Unit
	-- The camera rides on the side of his run with fewer things in the way (Util/ArrivalShot.pickSide)
	local side = Vector3.new(runWay.Z, 0, -runWay.X)
	local blocked = { 0, 0 }
	for sample = 0, 5 do
		local point = start + run * (sample / 5) + up * 1
		for which, sign in { 1, -1 } do
			if freeFor(point, side * sign, ARRIVAL.wide.side) < ARRIVAL.wide.side then
				blocked[which] += 1
			end
		end
	end
	side *= ArrivalShot.pickSide(blocked[1], blocked[2])
	-- The wide shot of the two of you: the first angle with a clear view (Util/ArrivalShot.pickWide)
	local middle = (feet + stop) / 2
	local wideTarget = middle + up * ARRIVAL.wide.lookUp
	local widePlaces, wideFree = {}, {}
	for _, angle in ARRIVAL.wideAngles do
		local place = middle + side * angle.side + outward * angle.out + up * angle.up
		local reach = (place - wideTarget).Magnitude
		table.insert(widePlaces, place)
		table.insert(wideFree, freeFor(wideTarget, (place - wideTarget).Unit, reach) / reach)
	end
	local widePlace = widePlaces[ArrivalShot.pickWide(wideFree, ARRIVAL)]
	dog.CFrame = CFrame.lookAt(start, Vector3.new(stop.X, start.Y, stop.Z))
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- Never through a wall or a shelf: the camera stops short of anything between it and what it looks at
	local function clear(from: Vector3, to: Vector3): Vector3
		local hit = workspace:Raycast(from, to - from, blockers)
		return if hit then hit.Position + (from - to).Unit * 0.5 else to
	end
	local function shot(): CFrame
		local here = dog.Position
		local covered = Vector3.new(here.X - start.X, 0, here.Z - start.Z).Magnitude
		local frame = ArrivalShot.at(if runLength > 0 then covered / runLength else 1, ARRIVAL)
		local target = here + up * frame.lookUp
		local close = CFrame.lookAt(clear(target, here + side * frame.side + runWay * frame.ahead + up * frame.up), target)
		if frame.wide <= 0 then
			return close
		end
		local wide = CFrame.lookAt(clear(wideTarget, widePlace), wideTarget)
		return close:Lerp(wide, frame.wide)
	end
	camera.CFrame = shot() -- a cut to his paws
	local skipped = false
	local tap = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			skipped = true
		end
	end)
	local follow = RunService.RenderStepped:Connect(function(dt)
		camera.CFrame = camera.CFrame:Lerp(shot(), math.min(1, dt * ARRIVAL.follow))
	end)
	task.spawn(function()
		local function hold(seconds: number)
			local from = os.clock()
			while os.clock() - from < seconds and not skipped do
				task.wait()
			end
		end
		hold(ARRIVAL.delay)
		if visual and not skipped then
			PishVisual.sound(visual, "bark")
		end
		while not skipped and dog.Parent do
			local now = dog.Position
			local flat = Vector3.new(stop.X - now.X, 0, stop.Z - now.Z)
			if flat.Magnitude < 0.3 then
				break
			end
			local dt = task.wait()
			local nextAt = now + flat.Unit * math.min(flat.Magnitude, ARRIVAL.speed * dt)
			dog.CFrame = CFrame.lookAt(nextAt, nextAt + flat.Unit)
		end
		local facing = Vector3.new(at.Position.X, stop.Y, at.Position.Z)
		if dog.Parent then
			dog.CFrame = CFrame.lookAt(stop, facing)
		end
		if not skipped then
			play("bark")
			hold(if visual then math.max(PishVisual.length(visual, "bark"), 1) else 1)
		end
		follow:Disconnect()
		tap:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		arriving = false
		refreshFocus()
		TutorialCues.skipButton(step ~= "" and step ~= "bye", openTourCard)
		updateTalk()
	end)
end

-- The Pish button (the peeking Pish over the party bar) offers his tour again after the first visit, and at its goodbye
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
	-- The calm HUD through the first visit (round 3, pick A); back for the goodbye, which points at the peeking Pish
	Hud.setCalm(step ~= "" and step ~= "bye")
	clearCues()
	if step ~= "" then
		visit = nil -- a replay takes over a visit; its lesson stays waiting
	end
	refreshFocus()
	if step == "" then
		if before ~= "" then
			task.spawn(finishVisit)
		end
		return
	end
	-- His arrival the first time the first visit starts (not a replay: the visit was done before it started again)
	if before == "" and step == STEPS[1] and not arrivedOnce and player:GetAttribute("TutorialDone") ~= true then
		task.spawn(arrive)
		return
	end
	ensurePish()
	TutorialCues.skipButton(step ~= "bye", openTourCard)
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
	-- The peeking Pish over the party bar is the Pish button (owner 2026-11-10): at his goodbye a tap ends it; once
	-- the first visit is done (no visit on) a tap offers his tour again
	HudMascotView.onTap(function()
		if step == "bye" then
			if not byeSent then
				byeSent = true
				Remotes.TutorialAction:FireServer("bye")
			end
		elseif replayShown() and not visit then
			TutorialCues.askReplay(function()
				Remotes.TutorialAction:FireServer("replay")
			end)
		end
	end)
	player:GetAttributeChangedSignal("TutorialStep"):Connect(onStep)
	Remotes.TutorialState.OnClientEvent:Connect(onState)
	local tick = 0
	RunService.RenderStepped:Connect(function(dt)
		if arriving then
			if visual then
				PishVisual.step(visual, dt) -- his run in plays on its own (arrive)
			end
			return
		end
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
		TutorialTalk.keepClear(if focusTarget then targetButton() else nil)
		if step ~= "" then
			updateTalk()
			byeIdle()
		elseif visit then
			updateLessonTalk()
		end
		if leading then
			pointPaw()
			updateTrail()
		end
		-- The calm HUD only in town: in the Wild a player mid-tour needs the party bar and the weapon switch
		Hud.setCalm(step ~= "" and step ~= "bye" and inTown())
		-- The first visit's spotlight on the button Pish points at (nothing dims for a thing in the shop)
		TutorialCues.spotlight(if step ~= "" and focusTarget then targetButton() else nil)
		if step == "" then
			updateVisit()
		end
	end)
	onStep()
end

return TutorialController
