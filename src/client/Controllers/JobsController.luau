--!strict
-- Shop Jobs panel (option B of the 2026-10-29 mockups): three chips explain the rules once (a faster card works
-- quicker, a stronger one makes fewer mistakes, XP a minute), then one row per job slot. A working card: its art
-- (hover, or hold a finger on it, for its stats), name, grade, level and job chip, a live status, an XP bar with
-- "Lv 18 in 9 min", Speed and Mistakes in kid words with the number under, and Switch job / Stop working. A free
-- slot offers Pick a card (the binder); a locked one says when it opens or offers the Extra Job Slot pass.
-- Cards are assigned from the binder card view. The server sends JobsChanged on every change.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Party = require(Config:WaitForChild("Party"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local JobRules = require(Shared:WaitForChild("Util"):WaitForChild("JobRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type SlotInfo = { slot: number, beastId: string, job: string, status: string }
type JobsState = {
	slotCount: number,
	maxSlots: number,
	unlockLevel: number,
	hasPass: boolean,
	passId: number,
	slots: { SlotInfo },
}

local WHITE = Color3.new(1, 1, 1)
local MAX_SIZE = Vector2.new(760, 560)
local ROW_HEIGHT = 120
local FREE_ROW_HEIGHT = 80
local ART = Vector2.new(74, 104)
local PHONE_ART = Vector2.new(60, 84)
local TILE_WIDTH = 176
local PHONE_TILE_WIDTH = 128
local BUTTON = UIStyle.MIN_TAP
local TIP_WIDTH = 250
local TIP_GAP = 10
local TONES = { good = UIStyle.GOOD, ok = WHITE, bad = UIStyle.BAD }
local STATUS_OK = { fill = Color3.fromRGB(16, 48, 31), text = UIStyle.GOOD }
local STATUS_WAIT = { fill = Color3.fromRGB(58, 44, 14), text = UIStyle.HINT }
local STATUS_OOPS = { fill = Color3.fromRGB(64, 20, 24), text = UIStyle.BAD }
local PICK_HINT = "Tap a card, then Give a job."

local player = Players.LocalPlayer

local JobsController = {}

local panel: Frame
local list: ScrollingFrame
local tip: Frame -- the card tooltip
local state: JobsState? = nil
local drawn = "" -- what the rows show (slots, cards, jobs); a payload that only changes statuses keeps the rows
local statusLines: { [number]: Frame } = {} -- slot -> the line its status pill sits in

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = UIKit.label(parent, value, if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold, size, color)
	label.TextWrapped = false
	label.Size = UDim2.fromOffset(0, size + 4)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	if bold then
		UIKit.outlined(label, 2)
	end
	return label
end

-- A transparent horizontal strip, children side by side and centred vertically
local function strip(parent: Instance, order: number, height: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = (parent :: GuiObject).ZIndex
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function makeRow(order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, height)
	row.BackgroundColor3 = UIStyle.ROW
	row.ZIndex = list.ZIndex + 1
	row.Parent = list
	UIKit.corner(row, 12)
	return row
end

-- The rules once, at the top: what makes a good worker, and the XP it earns
local function buildRules()
	local rules = strip(list, 0, 30, 8)
	rules.AutomaticSize = Enum.AutomaticSize.Y
	local layout = rules:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.Wraps = true
	for index, rule in {
		{ "Spd", "Faster cards work quicker" },
		{ "Power", "Stronger cards make fewer mistakes" },
		{ "Xp", `+{Jobs.XP_PER_MINUTE} XP a minute while you play` },
	} do
		local chip = UIKit.pill(rules, rule[2], UIStyle.PANEL, nil, rule[1])
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(0, 30)
		chip.ZIndex = rules.ZIndex + 1
	end
end

-- The card tooltip beside the card's art (kept on screen), with the perk it would give when summoned
local function showTip(art: GuiObject, card: Card, beast: { foil: boolean, grade: string, level: number, stars: number })
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
	CardTips.copy(tip, {
		card = card,
		foil = beast.foil,
		grade = beast.grade,
		level = beast.level,
		stars = beast.stars,
		power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
		stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade),
		reference = CardTips.reference(),
		perk = if perk then PartyRules.describe(perk) else nil,
	})
	tip.Visible = true
	local screen = tip.Parent :: GuiObject
	local origin = screen.AbsolutePosition
	local spot = UiLayout.beside(
		{ x = art.AbsolutePosition.X - origin.X, y = art.AbsolutePosition.Y - origin.Y, w = art.AbsoluteSize.X, h = art.AbsoluteSize.Y },
		{ w = tip.AbsoluteSize.X, h = tip.AbsoluteSize.Y },
		{ w = screen.AbsoluteSize.X, h = screen.AbsoluteSize.Y },
		TIP_GAP
	)
	tip.Position = UDim2.fromOffset(spot.x, spot.y)
end

local function hideTip()
	tip.Visible = false
end

-- Hover the art (mouse), or hold a finger on it, for the card's stats
local function hookTip(art: GuiObject, card: Card, beast: { foil: boolean, grade: string, level: number, stars: number })
	art.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			showTip(art, card, beast)
		end
	end)
	art.MouseLeave:Connect(hideTip)
	local pressed = 0
	art.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		pressed += 1
		local press = pressed
		task.delay(UIStyle.LONG_PRESS, function()
			if pressed == press and art.Parent then
				showTip(art, card, beast)
			end
		end)
	end)
	art.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			pressed += 1
			hideTip()
		end
	end)
end

-- A tile: icon, the kid word in its tone's colour, the number under it (phones: the word only)
local function statTile(parent: Instance, order: number, icon: string, word: string, tone: string, detail: string, phone: boolean): Frame
	local tile = Instance.new("Frame")
	tile.LayoutOrder = order
	tile.Size = UDim2.new(1, 0, 0.5, -3)
	tile.BackgroundColor3 = UIStyle.PANEL
	tile.ZIndex = (parent :: GuiObject).ZIndex + 1
	tile.Parent = parent
	UIKit.corner(tile, 10)
	UIKit.outline(tile, UIStyle.EDGE, 2)
	local picture = Icon.make(tile, icon, UDim2.fromOffset(22, 22))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.new(0, 7, 0.5, 0)
	picture.ZIndex = tile.ZIndex + 1
	local wordLabel = text(tile, word, UIKit.textSize("small"), TONES[tone] or WHITE, true)
	wordLabel.AutomaticSize = Enum.AutomaticSize.None
	wordLabel.TextTruncate = Enum.TextTruncate.AtEnd
	wordLabel.Position = UDim2.new(0, 34, 0, if phone then 0 else 4)
	wordLabel.Size = UDim2.new(1, -38, if phone then 1 else 0, if phone then 0 else UIKit.textSize("small") + 4)
	if not phone then
		local detailLabel = text(tile, detail, UIKit.textSize("small") - 1, UIKit.Colors.Subtext)
		detailLabel.AnchorPoint = Vector2.new(0, 1)
		detailLabel.Position = UDim2.new(0, 34, 1, -4)
	end
	return tile
end

-- The live status: a dot and the words, green while working, amber while waiting, red on a slip
local function statusPill(parent: Instance, order: number, status: string): Frame
	local old = parent:FindFirstChild("Status")
	if old then
		old:Destroy()
	end
	local look = if string.find(status, "^Idle") or string.find(status, "^Waiting") or status == "Starting" then STATUS_WAIT
		elseif string.find(status, "Dropped") or string.find(status, "Mis%-scan") then STATUS_OOPS
		else STATUS_OK
	local pill = Instance.new("Frame")
	pill.Name = "Status"
	pill.LayoutOrder = order
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 24)
	pill.BackgroundColor3 = look.fill
	pill.ZIndex = (parent :: GuiObject).ZIndex + 1
	pill.Parent = parent
	UIKit.corner(pill, 10)
	UIKit.outline(pill, UIStyle.EDGE, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = pill
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = look.text
	dot.ZIndex = pill.ZIndex + 1
	dot.Parent = pill
	UIKit.corner(dot, 4)
	text(pill, status, UIKit.textSize("small"), look.text).LayoutOrder = 2
	return pill
end

local function buildWorkerRow(slot: number, info: SlotInfo)
	local phone = UIKit.isPhone()
	local row = makeRow(slot, ROW_HEIGHT)
	UIKit.outline(row, UIStyle.EDGE, 2)
	local beast = BinderController.GetBeasts()[info.beastId]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		local loading = text(row, `Slot {slot} · {info.job}`, UIKit.textSize("body"), WHITE, true)
		loading.Position = UDim2.fromOffset(14, 12)
		return
	end

	-- The card, with its tooltip
	local artSize = if phone then PHONE_ART else ART
	local art = CardTips.art(row, card, beast.foil, artSize)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 10, 0.5, 0)
	hookTip(art, card, beast)

	-- Switch job over Stop working, on the right
	local buttons = Instance.new("Frame")
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -10, 0.5, 0)
	buttons.Size = UDim2.fromOffset(BUTTON, 2 * BUTTON + 6)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = row.ZIndex
	buttons.Parent = row
	local nextJob = JobRules.nextJob(Jobs.JOBS, info.job)
	local switch = UIKit.iconButton(buttons, "", "Next", UIKit.Colors.Secondary)
	switch.Size = UDim2.fromOffset(BUTTON, BUTTON)
	switch.ZIndex = buttons.ZIndex + 1
	Tooltip.attach(switch, if nextJob then `Switch job: {card.name} becomes a {nextJob}` else "Switch job")
	switch.Activated:Connect(function()
		Remotes.SwitchJob:FireServer(slot)
	end)
	local stop = UIKit.iconButton(buttons, "", "Remove", UIKit.Colors.Danger)
	stop.AnchorPoint = Vector2.new(0, 1)
	stop.Position = UDim2.fromScale(0, 1)
	stop.Size = UDim2.fromOffset(BUTTON, BUTTON)
	stop.ZIndex = buttons.ZIndex + 1
	Tooltip.attach(stop, "Stop working")
	stop.Activated:Connect(function()
		Remotes.UnassignJob:FireServer(slot)
	end)

	-- Speed and Mistakes in words
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	local power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade)
	local speed = JobRules.getSpeedFactor(Jobs, stats.spd)
	local mistakes = JobRules.getMistakeChance(Jobs, power)
	local tileWidth = if phone then PHONE_TILE_WIDTH else TILE_WIDTH
	local tiles = Instance.new("Frame")
	tiles.AnchorPoint = Vector2.new(1, 0.5)
	tiles.Position = UDim2.new(1, -(BUTTON + 20), 0.5, 0)
	tiles.Size = UDim2.fromOffset(tileWidth, 2 * BUTTON + 6)
	tiles.BackgroundTransparency = 1
	tiles.ZIndex = row.ZIndex
	tiles.Parent = row
	local tileList = Instance.new("UIListLayout")
	tileList.Padding = UDim.new(0, 6)
	tileList.SortOrder = Enum.SortOrder.LayoutOrder
	tileList.Parent = tiles
	local speedWord, speedTone = JobRules.speedWord(Jobs, speed)
	Tooltip.attach(statTile(tiles, 1, "Spd", speedWord, speedTone, string.format("x%.2f work speed", speed), phone), "Work speed: from its Attack Speed")
	local mistakeWord, mistakeTone = JobRules.mistakeWord(Jobs, mistakes)
	Tooltip.attach(statTile(tiles, 2, "Power", mistakeWord, mistakeTone, `{math.round(mistakes * 100)}% of the time`, phone), "Mistakes: stronger cards make fewer")

	-- Name, grade, level and job; the live status; XP to the next level
	local left = 10 + artSize.X + 12
	local middle = Instance.new("Frame")
	middle.Position = UDim2.fromOffset(left, 10)
	middle.Size = UDim2.new(1, -(left + tileWidth + BUTTON + 34), 1, -20)
	middle.BackgroundTransparency = 1
	middle.ZIndex = row.ZIndex
	middle.Parent = row
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, if phone then 4 else 8)
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = middle

	local title = strip(middle, 1, 26, 6)
	local name = text(title, card.name, UIKit.textSize(if phone then "body" else "name"), WHITE, true)
	name.LayoutOrder = 1
	local grade = UIKit.pill(title, beast.grade, UIStyle.GRADES[beast.grade] or UIStyle.GRADES.C)
	grade.LayoutOrder = 2
	grade.Size = UDim2.fromOffset(0, 20)
	Tooltip.attach(grade, CardTips.gradeText(beast.grade))
	text(title, `Lv {beast.level}`, UIKit.textSize("small"), WHITE, true).LayoutOrder = 3

	local jobLine = strip(middle, 2, 26, 6)
	local jobInfo = Jobs.JOB_INFO[info.job]
	local jobChip = UIKit.pill(jobLine, info.job, UIStyle.PANEL, nil, if jobInfo then jobInfo.icon else "Jobs")
	jobChip.LayoutOrder = 1
	jobChip.Size = UDim2.fromOffset(0, 24)
	if jobInfo then
		Tooltip.attach(jobChip, `{info.job}: {jobInfo.text}`)
	end
	statusPill(jobLine, 2, info.status)
	statusLines[slot] = jobLine

	local xpLine = Instance.new("Frame")
	xpLine.LayoutOrder = 3
	xpLine.Size = UDim2.new(1, 0, 0, 20)
	xpLine.BackgroundTransparency = 1
	xpLine.ZIndex = middle.ZIndex
	xpLine.Parent = middle
	local xpIcon = Icon.make(xpLine, "Xp", UDim2.fromOffset(20, 20))
	xpIcon.ZIndex = xpLine.ZIndex + 1
	Tooltip.icon(xpIcon, "Xp")
	local toNext = BeastRules.getXpToNext(beast.level)
	local minutes = JobRules.minutesToNext(beast.xp, toNext, Jobs.XP_PER_MINUTE)
	local track = UIKit.bar(xpLine, if toNext > 0 then beast.xp / toNext else 1, if toNext > 0 then UIStyle.XP else UIStyle.GOLD)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 26, 0.5, 0)
	track.Size = UDim2.new(1, -(26 + (if phone then 92 else 118)), 0, track.Size.Y.Offset)
	local xpText = text(xpLine, if minutes then `Lv {beast.level + 1} in {minutes} min` else "MAX LEVEL", UIKit.textSize("small"), if minutes then WHITE else UIStyle.HINT)
	xpText.AnchorPoint = Vector2.new(1, 0.5)
	xpText.Position = UDim2.fromScale(1, 0.5)
end

-- A free slot: a "+" box, what to do, and Pick a card (opens the binder)
local function buildFreeRow(slot: number)
	local row = makeRow(slot, FREE_ROW_HEIGHT)
	local edge = UIKit.outline(row, UIKit.Colors.Subtext, 3)
	edge.Transparency = 0.5
	local plus = text(row, "+", 34, UIKit.Colors.Subtext, true)
	plus.AutomaticSize = Enum.AutomaticSize.None
	plus.AnchorPoint = Vector2.new(0, 0.5)
	plus.Position = UDim2.new(0, 12, 0.5, 0)
	plus.Size = UDim2.fromOffset(60, 56)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	plus.BackgroundColor3 = UIStyle.PANEL
	plus.BackgroundTransparency = 0
	UIKit.corner(plus, 10)
	local title = text(row, `Slot {slot} is free`, UIKit.textSize("body") + 2, WHITE, true)
	title.Position = UDim2.fromOffset(86, 14)
	local hint = text(row, "Pick a card from your binder to work here", UIKit.textSize("small"), UIKit.Colors.Subtext)
	hint.Position = UDim2.fromOffset(86, 42)
	local pick = UIKit.iconButton(row, "Pick a card", "Cards", UIKit.Colors.Accent)
	pick.AnchorPoint = Vector2.new(1, 0.5)
	pick.Position = UDim2.new(1, -12, 0.5, 0)
	pick.Size = UDim2.fromOffset(160, BUTTON)
	pick.TextSize = UIKit.textSize("body")
	pick.ZIndex = row.ZIndex + 1
	pick.Activated:Connect(function()
		panel.Visible = false
		BinderController.Open(PICK_HINT)
	end)
end

-- A slot you can't use yet: before the unlock level, or the pass slot
local function buildLockedRow(slot: number, current: JobsState)
	local row = makeRow(slot, FREE_ROW_HEIGHT)
	UIKit.outline(row, UIStyle.EDGE, 2)
	row.BackgroundColor3 = UIStyle.PANEL
	local lock = Icon.make(row, "Lock", UDim2.fromOffset(40, 40))
	lock.AnchorPoint = Vector2.new(0, 0.5)
	lock.Position = UDim2.new(0, 22, 0.5, 0)
	lock.ZIndex = row.ZIndex + 1
	local needsPass = slot > Jobs.FREE_SLOTS
	local level = player:GetAttribute("Level")
	local early = not needsPass or (typeof(level) == "number" and level < current.unlockLevel)
	local title = text(row, `Slot {slot}`, UIKit.textSize("body") + 2, WHITE, true)
	title.Position = UDim2.fromOffset(86, 14)
	local detail = text(row, if early then `Opens at shop level {current.unlockLevel}` else "Extra Job Slot pass: one more card working in your shop", UIKit.textSize("small"), UIKit.Colors.Subtext)
	detail.Position = UDim2.fromOffset(86, 42)
	if needsPass and not current.hasPass then
		local available = current.passId ~= 0
		local buy = UIKit.iconButton(row, if available then "Get the pass" else "Coming soon", "Cash", if available then UIKit.Colors.Accent else UIKit.Colors.Locked)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -12, 0.5, 0)
		buy.Size = UDim2.fromOffset(170, BUTTON)
		buy.TextSize = UIKit.textSize("body")
		buy.AutoButtonColor = available
		buy.ZIndex = row.ZIndex + 1
		buy.Activated:Connect(function()
			if available then
				MarketplaceService:PromptGamePassPurchase(player, current.passId)
			end
		end)
	end
end

-- The rows' shape: which slots are open, which card works where at which job (not statuses)
local function shapeOf(current: JobsState?): string
	if not current then
		return ""
	end
	local parts = { `{current.slotCount}/{current.maxSlots}/{current.hasPass}` }
	for _, info in current.slots do
		table.insert(parts, `{info.slot}:{info.beastId}:{info.job}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function render()
	if not panel.Visible then
		return
	end
	hideTip()
	clear(list)
	statusLines = {}
	buildRules()
	local current = state
	drawn = shapeOf(current)
	if not current then
		local wait = text(list, "Loading...", UIKit.textSize("body"), UIKit.Colors.Subtext)
		wait.LayoutOrder = 1
		return
	end
	local bySlot: { [number]: SlotInfo } = {}
	for _, info in current.slots do
		bySlot[info.slot] = info
	end
	for slot = 1, current.maxSlots do
		local info = bySlot[slot]
		if slot > current.slotCount then
			buildLockedRow(slot, current)
		elseif info then
			buildWorkerRow(slot, info)
		else
			buildFreeRow(slot)
		end
	end
end

-- Wide on desktops (up to MAX_SIZE), nearly the whole screen on phones; only as tall as its rows need
local function layout()
	local phone = UIKit.isPhone()
	local rows = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local camera = workspace.CurrentCamera
	local screenHeight = if camera then camera.ViewportSize.Y else MAX_SIZE.Y
	local needed = UIKit.HEADER_HEIGHT + 24 + rows.AbsoluteContentSize.Y + UIStyle.LIP
	local height = math.min(needed, screenHeight * (if phone then 0.96 else 0.85))
	panel.Size = UDim2.new(if phone then 0.97 else 0.9, 0, 0, height)
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		layout()
		Remotes.RequestJobs:FireServer()
		render()
	end
end

function JobsController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Jobs", "Shop Jobs")
	Icon.header(panel, "Jobs", UIKit.HEADER_HEIGHT)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	local rows = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	rows:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(layout)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			hideTip()
		end
	end)

	tip = Instance.new("Frame")
	tip.Name = "JobsCardTip"
	tip.Size = UDim2.fromOffset(TIP_WIDTH, 0)
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.BackgroundColor3 = UIStyle.PANEL
	tip.ZIndex = 50
	tip.Visible = false
	tip.Parent = screenGui
	UIKit.corner(tip, 12)
	UIKit.outline(tip, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local tipPadding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(tipPadding :: any)[side] = UDim.new(0, 10)
	end
	tipPadding.Parent = tip

	Hud.fanButton({ id = "Jobs", icon = "Jobs", label = "Jobs", order = 3, onClick = toggle })

	Remotes.JobsChanged.OnClientEvent:Connect(function(payload: JobsState)
		if typeof(payload) ~= "table" then
			return
		end
		state = payload
		if panel.Visible and shapeOf(payload) == drawn then
			-- Only what the workers are doing changed: update the pills, keep the rows (and any tooltip)
			for _, info in payload.slots do
				local line = statusLines[info.slot]
				if line and typeof(info.status) == "string" then
					statusPill(line, 2, info.status)
				end
			end
			return
		end
		render()
	end)
	-- Levels and XP change as cards work; redraw with the new binder
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
end

return JobsController
