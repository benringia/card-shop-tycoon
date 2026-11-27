--!strict
-- What now? hints (spec 2026-11-27-what-now-hints-design; owner 2026-11-27: "never let a player go idle", look 1): once
-- a player has stood still a while, or walked around with nothing earned, and is free, Pish's face and one short line
-- in a white bubble (Util/HintBubble) stand on the gold arrow (Util/TutorialCues) pointing at the one best next thing,
-- picked by Util/HintRules from what this client already knows for its HUD. One tip every 2 minutes at most, the same
-- one not for 5; never during Pish's or Chikin's tours or a lesson; its x mutes it for the session. The main game only.
-- Each tip shown, followed or closed is logged (Remotes.HintSeen, HintService). Dev: /hint <kind> (HintPreview).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SharedUtil = Shared:WaitForChild("Util")
local Bosses = require(Config:WaitForChild("Bosses"))
local Chikin = require(Config:WaitForChild("Chikin"))
local Hints = require(Config:WaitForChild("Hints"))
local Items = require(Config:WaitForChild("Items"))
local Music = require(Config:WaitForChild("Music"))
local Products = require(Config:WaitForChild("Products"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local HintRules = require(SharedUtil:WaitForChild("HintRules"))
local ItemRules = require(SharedUtil:WaitForChild("ItemRules"))
local LessonRules = require(SharedUtil:WaitForChild("LessonRules"))
local MusicRules = require(SharedUtil:WaitForChild("MusicRules"))
local QuestRemind = require(SharedUtil:WaitForChild("QuestRemind"))
local UpgradeRules = require(SharedUtil:WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local HintBubble = require(ClientUtil:WaitForChild("HintBubble"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local MainQuest = require(ClientUtil:WaitForChild("MainQuest"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local BossBoardController = require(Controllers:WaitForChild("BossBoardController"))
local QuestController = require(Controllers:WaitForChild("QuestController"))
local StockHintController = require(Controllers:WaitForChild("StockHintController"))
local TutorialController = require(Controllers:WaitForChild("TutorialController"))
local UIController = require(Controllers:WaitForChild("UIController"))

local HintController = {}

local player = Players.LocalPlayer
local PORTAL = Wild.PLAZA_PORTAL
-- The stations whose finished job waits to be taken out: their Config/Shelves id, the player's note and the job's key
local STATIONS = {
	{ id = "Condenser", done = "CondenserDone", job = "condenser" },
	{ id = "GradingStation", done = "GradingDone", job = "grading" },
}

-- What a tip points at: a button, a part of the shop, or a spot in the world to walk to
type Target = { gui: GuiObject?, part: BasePart?, spot: Vector3? }
type Shown = {
	kind: string,
	removers: { () -> () },
	pointer: () -> (),
	at: number,
	walk: boolean,
	inTown: boolean,
	gui: GuiObject?,
	preview: boolean,
}

local bag: { [string]: number } = {}
local current: Shown? = nil
local muted: { [string]: boolean } = {}
local shownAt: { [string]: number } = {}
local lastShownAt: number? = nil
local joinedAt = os.clock()
local idleSince: number? = nil
local quietSince = os.clock()
local anchor: Part? = nil

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function root(): BasePart?
	local character = player.Character
	local found = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if found and found:IsA("BasePart") then found else nil
end

local function myPlot(): Instance?
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in if plots then plots:GetChildren() else {} do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function myShelves(): Instance?
	local plot = myPlot()
	return if plot then plot:FindFirstChild("Shelves") else nil
end

local function inTown(): boolean
	local at = root()
	return at ~= nil and MusicRules.inTown(at.Position.X, at.Position.Z, Town.BOUNDS, Music.TOWN.margin)
end

-- A station placed in the shop with its finished job waiting (UpgradeRules.showsReady), or nil
local function readyStation(): string?
	local shelves = myShelves()
	for _, spec in STATIONS do
		if shelves and shelves:FindFirstChild(spec.id) and UpgradeRules.showsReady(StationJobs.get(spec.job) ~= nil, player:GetAttribute(spec.done)) then
			return spec.id
		end
	end
	return nil
end

local function facts(): HintRules.Facts
	local stocked = false
	local shelves = myShelves()
	for _, part in if shelves then shelves:GetChildren() else {} do
		local units = part:GetAttribute("Units")
		if typeof(units) == "number" and units > 0 then
			stocked = true
			break
		end
	end
	local view = QuestController.QuestView()
	local questsDone = 0
	local questText: string? = nil
	if view then
		local week = view.week
		questsDone = (tonumber(view.claimable) or 0) + (if typeof(week) == "table" then tonumber(week.claimable) or 0 else 0)
		local said = QuestRemind.words(view, nil)
		questText = if said and not said.strong then said.text else nil
	end
	local packs = 0
	for itemId, count in bag do
		if ItemRules.openablePack(Items, itemId) then
			packs += count
		end
	end
	local goal = MainQuest.current()
	return {
		registerWaiting = player:GetAttribute("RegisterWaiting") == true,
		questsDone = questsDone,
		boxWaiting = number("BoxesWaiting") > 0 or number("CarryCount") > 0,
		boxesComing = number("BoxesComing"),
		shelvesStocked = stocked,
		cash = number("Cash"),
		cheapestBox = LessonRules.cheapestBox(Products.List, math.max(1, number("Level"))),
		stationReady = readyStation(),
		buildName = if goal and goal.kind == "build" and goal.ready then goal.name else nil,
		packs = packs,
		boss = BossBoardController.Suggested(),
		questText = questText,
		inTown = inTown(),
	}
end

local function asPart(found: Instance?): BasePart?
	if found and found:IsA("BasePart") then
		return found
	end
	if found and found:IsA("Model") then
		return found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function plotPart(name: string): BasePart?
	local plot = myPlot()
	return asPart(if plot then plot:FindFirstChild(name, true) else nil)
end

-- A button that's on the screen now, or nil
local function onScreen(gui: GuiObject?): GuiObject?
	return if gui and gui.Parent and gui.Visible and gui.AbsoluteSize.X > 0 then gui else nil
end

-- A HUD button, or the Phone's tile while the Phone holding it is shut (as Pish points: TutorialController)
local function hudButton(id: string): GuiObject?
	if Hud.inPhone(id) and not Hud.isTrayOpen() then
		return onScreen(Hud.find("Manage"))
	end
	return onScreen(Hud.find(id))
end

local function nearest(parts: { BasePart }): BasePart?
	local at = root()
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		local distance = if at then (part.Position - at.Position).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

local function withPart(part: BasePart?): Target?
	return if part then { part = part } else nil
end

local function withGui(gui: GuiObject?): Target?
	return if gui then { gui = gui } else nil
end

-- What tip `kind` points at; nil when it isn't there (no station placed, the Phone hidden): that tip is skipped
local function targetFor(kind: string, f: HintRules.Facts): Target?
	if kind == "register" then
		return withPart(plotPart("RegisterHousing") or plotPart("Register"))
	elseif kind == "claim" or kind == "quest" then
		return withGui(onScreen(QuestController.HintTarget()))
	elseif kind == "stock" then
		return withPart(if number("CarryCount") > 0 then nearest(StockHintController.Glowing()) else plotPart("DeliverySpot"))
	elseif kind == "order" then
		return withPart(plotPart("OrderComputer"))
	elseif kind == "station" then
		local shelves = myShelves()
		local id = f.stationReady
		return withPart(asPart(if shelves and id then shelves:FindFirstChild(id) else nil))
	elseif kind == "build" then
		return withGui(hudButton("Build"))
	elseif kind == "packs" then
		return withGui(hudButton("Bag"))
	elseif kind == "boss" and not f.inTown then
		-- in the Wild valley: the boss's own portal (WildService's "BossPortal <name>")
		local boss = f.boss
		local portal = if boss then workspace:FindFirstChild(`BossPortal {boss.name}`, true) else nil
		return if portal and portal:IsA("Model") then { spot = portal:GetPivot().Position + Vector3.new(0, Hints.SPOT_HEIGHT, 0) } else nil
	elseif kind == "boss" or kind == "hunt" then
		return { spot = Vector3.new(PORTAL.x, PORTAL.y + Hints.SPOT_HEIGHT, PORTAL.z) }
	end
	return nil
end

-- An unseen part at a spot in the world, for the arrow to hang over
local function anchorAt(spot: Vector3): BasePart
	local made = anchor
	if not made or not made.Parent then
		local part = Instance.new("Part")
		part.Name = "HintAnchor"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Parent = workspace
		anchor = part
		made = part
	end
	local placed = made :: Part
	placed.Position = spot
	return placed
end

local function pointAt(target: Target): () -> ()
	local gui, part, spot = target.gui, target.part, target.spot
	if gui then
		return TutorialCues.pointAt(gui)
	elseif part then
		return TutorialCues.pointAt(part)
	end
	return TutorialCues.pointAt(anchorAt(spot :: Vector3))
end

local function hide(outcome: ("done" | "closed")?)
	local tip = current
	if not tip then
		return
	end
	current = nil
	tip.pointer()
	for _, remove in tip.removers do
		remove()
	end
	if outcome and not tip.preview then
		Remotes.HintSeen:FireServer(tip.kind, outcome)
	end
end

-- Show tip `kind` now on its target; false when its target isn't there
local function show(kind: string, f: HintRules.Facts, preview: boolean): boolean
	local target = targetFor(kind, f)
	if not target then
		return false
	end
	hide(nil)
	local now = os.clock()
	local removers: { () -> () } = {}
	local spot, at = target.spot, root()
	if spot and at then
		table.insert(removers, TutorialCues.trail(at.Position, spot)) -- arrows on the ground for a walk
	end
	local tip: Shown = {
		kind = kind,
		removers = removers,
		pointer = pointAt(target),
		at = now,
		walk = spot ~= nil,
		inTown = f.inTown,
		gui = target.gui,
		preview = preview,
	}
	table.insert(removers, HintBubble.show(HintRules.words(kind, f, Hints.WORDS), function()
		if current ~= tip then
			return
		end
		if not preview then
			muted[kind] = true -- its x: not again this session
		end
		hide("closed")
	end))
	current = tip
	if not preview then
		shownAt[kind] = now
		lastShownAt = now
		Remotes.HintSeen:FireServer(kind, "shown")
	end
	return true
end

-- Pish's tour, Chikin leading (not his quiet wait for shop level 4), a lesson visit or a tour's calm HUD: the guides
-- have the player
local function guidesAway(): boolean
	local combat = player:GetAttribute("CombatStep")
	local chikinAway = combat == nil or combat == "" or combat == Chikin.WAIT_STEP
	return player:GetAttribute("TutorialDone") ~= false and chikinAway and not TutorialController.IsVisiting() and not Hud.isCalm()
end

-- The tip on now: gone once done (its thing true no more, its walk out of town), its window opened, the player busy or
-- its time up; a button tip follows the Phone opening (onto the app inside) or shutting
local function keepShowing(tip: Shown, now: number, away: boolean, PlayerBusy: any)
	local f = facts()
	if UIKit.anyPanelOpen() then
		hide("done") -- a window opened right after the tip: taken as followed
		return
	end
	if not tip.preview and (not HintRules.holds(tip.kind, f) or (tip.walk and f.inTown ~= tip.inTown)) then
		hide("done")
		return
	end
	local free = (tip.preview or away) and PlayerBusy.reason({ carrying = true, window = true }) == nil
	if not free or now - tip.at >= (if tip.walk then Hints.WALK_SHOW else Hints.SHOW) then
		hide(nil)
		return
	end
	if tip.gui then
		local target = targetFor(tip.kind, f)
		local gui = if target then target.gui else nil
		if gui ~= tip.gui then
			tip.pointer()
			if not gui then
				tip.pointer = function() end
				hide(nil)
				return
			end
			tip.pointer = TutorialCues.pointAt(gui)
			tip.gui = gui
		end
	end
end

local function tick(PlayerBusy: any)
	local now = os.clock()
	local character = player.Character
	local human = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local moving = human ~= nil and human.MoveDirection.Magnitude > 0.05
	local away = guidesAway()
	local busy = PlayerBusy.reason({ carrying = true }) ~= nil
	if not away or busy then
		quietSince = now -- busy with something, or with a guide: not lost
	end
	if not away or busy or moving then
		idleSince = nil
	elseif idleSince == nil then
		idleSince = now
	end
	local tip = current
	if tip then
		keepShowing(tip, now, away, PlayerBusy)
		return
	end
	if not away or busy then
		return
	end
	if not HintRules.due(now, { joinedAt = joinedAt, idleSince = idleSince, quietSince = quietSince, lastShownAt = lastShownAt }, Hints) then
		return
	end
	local f = facts()
	local skip = HintRules.skip(now, shownAt, muted, Hints.REPEAT)
	for _ = 1, #Hints.ORDER do
		local kind = HintRules.pick(f, skip, Hints.ORDER)
		if not kind or show(kind, f, false) then
			return
		end
		skip[kind] = true -- nothing to point at here: the next one
	end
end

-- /hint <kind> (DevService sets HintPreview "<kind>:<clock>"): that tip on its target now, with sample words for what
-- isn't true, whatever the shop's state
local function preview(raw: unknown)
	local kind = if typeof(raw) == "string" then string.match(raw, "^(%a+):") else nil
	if not kind or not table.find(Hints.ORDER, kind) then
		return
	end
	local f = facts()
	f.questsDone = math.max(f.questsDone, 1)
	f.packs = math.max(f.packs, 1)
	f.buildName = f.buildName or "Bulk Bin"
	local shelves = myShelves()
	for _, spec in STATIONS do
		if not f.stationReady and shelves and shelves:FindFirstChild(spec.id) then
			f.stationReady = spec.id
		end
	end
	local first = Bosses.BOSSES[Bosses.LADDER[1]]
	f.boss = f.boss or { name = first.name, cleared = false }
	f.questText = f.questText or "Quest: Open 3 packs · 1/3"
	if not show(kind, f, true) then
		UIController.Notify(`Nothing to point at for {kind} here`, true)
	end
end

function HintController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return -- the shop, the town and the Wild valley are the main game's
	end
	UserInputService.InputBegan:Connect(function()
		idleSince = nil -- any key, click, tap or stick counts as doing something
	end)
	for _, name in { "Cash", "XP" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			quietSince = os.clock() -- something earned (or spent): not lost
		end)
	end
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items: unknown)
		if typeof(items) ~= "table" then
			return
		end
		local fresh: { [string]: number } = {}
		for itemId, count in items :: any do
			if typeof(itemId) == "string" and typeof(count) == "number" then
				fresh[itemId] = count
			end
		end
		bag = fresh
	end)
	Remotes.RequestItems:FireServer() -- the Bag now, in case it came before this listened
	player:GetAttributeChangedSignal("HintPreview"):Connect(function()
		preview(player:GetAttribute("HintPreview"))
	end)
	task.spawn(function()
		local PlayerBusy = require(ClientUtil:WaitForChild("PlayerBusy")) :: any -- here, not at load: it requires half the controllers
		while true do
			task.wait(Hints.TICK)
			tick(PlayerBusy)
		end
	end)
end

return HintController
