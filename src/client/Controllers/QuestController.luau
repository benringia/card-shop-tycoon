--!strict
-- Daily quests on screen (owner 2026-11-17; the always-on tracker, mockup pick B): the strip at the top right with
-- today's three quests and their bars (Util/QuestStrip: its look and animations; a chip by the cash on a phone), a
-- toast as one is done, and tapping it opens the Quests window: each quest's words, bar and pay with Claim, the Quest
-- Chest once all three are claimed, and the time until new ones. Coins fly from a claimed quest into the cash pill.
-- QuestService decides everything; this shows it and asks (Remotes.QuestState, Remotes.QuestClaim). The strip hides with
-- the HUD (fights, full-screen views, Pish's and Chikin's calm HUD) and, on a phone, while a window is open; there it's
-- a small chip beside the cash pill (owner 2026-11-17: "mobile version screen now too crowded", "go A").
-- The week's quests (owner 2026-11-17: "what players do after daily quests?", look A) come with the day's (the view's
-- `week`): in the window under the day's, with the Weekly Chest (its win moment: Util/GiftWin "questWeek"), and in the
-- strip once today's chest is opened. A small piece can ride under the strip (QuestController.Below: Turts' chip).
-- The main quest (owner 2026-11-18, look A; Util/MainQuest picks it): a row at the strip's bottom with Build! once paid
-- for, the window's first section, and a first build's moment (Remotes.MainQuestDone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Quests = require(Config:WaitForChild("Quests"))
local MainQuests = require(Config:WaitForChild("MainQuests"))
local Placement = require(Config:WaitForChild("Placement"))
local Shelves = require(Config:WaitForChild("Shelves"))
local Teams = require(Config:WaitForChild("Teams"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local QuestRules = require(Shared:WaitForChild("Util"):WaitForChild("QuestRules"))
local GiftRules = require(Shared:WaitForChild("Util"):WaitForChild("GiftRules"))
local MainQuestRules = require(Shared:WaitForChild("Util"):WaitForChild("MainQuestRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local QuestStrip = require(ClientUtil:WaitForChild("QuestStrip"))
local GiftWin = require(ClientUtil:WaitForChild("GiftWin"))
local MainQuest = require(ClientUtil:WaitForChild("MainQuest"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BlockedController = require(Controllers:WaitForChild("BlockedController"))

local QuestController = {}

type QuestView = QuestRules.QuestView
type View = QuestRules.View
type Chest = { name: string, order: number, title: string, items: { { item: string, count: number } }, ready: boolean, opened: boolean, waiting: string, which: string, tint: { light: Color3, deep: Color3 } }

-- belowGap: the strip's outline (3 px, 4.5 glowing) and the chip's rim (3 px) are drawn outside them, so 12 shows about
-- 6 (owner 2026-11-17: "add small gap between them"); cashGap: a phone's quest chip to the cash pill
local TRACKER = { margin = 16, phoneGap = 8, desktopTop = Teams.STRIP.top, belowGap = 12, cashGap = 8 }
local WINDOW = Quests.WINDOW
local WEEK_ORDER = 20 -- the week's rows come after the day's and their chest in the window
local MAIN_ORDER = -10 -- the main quest comes first in the window

local DesktopHudConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DesktopHud"))
local DesktopHud = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("DesktopHud"))
local PhoneNotice = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("PhoneNotice"))

local player = Players.LocalPlayer

local view: View? = nil
local screen: ScreenGui
local holder: Frame
local tracker: TextButton
local panel: Frame
local list: ScrollingFrame
local dayLabel: TextLabel? = nil -- "New quests in 1h 46m" in today's heading (ticks while the window is open)
local weekLabel: TextLabel? = nil
local belowSlot: Frame? = nil -- pieces riding under the strip (QuestController.Below)
local belowPieces: { GuiObject } = {}
local windowOpen = false -- any UIKit window (a phone's tracker steps aside)
-- a boss fight is on: the strip and what rides under it step aside (owner 2026-11-18: they sat under the fight's sword
-- chip and soft lock button)
local bossFight = false
local lastClaimAt: Vector2? = nil -- where the last Claim press was (the coins fly from there)

-- "New quests in 9h 12m": to the next UTC midnight (QuestService's day, GiftRules.dayOf)
local function resetText(): string
	local left = 86400 - os.time() % 86400
	local hours, minutes = left // 3600, (left % 3600) // 60
	return if hours > 0 then `New quests in {hours}h {minutes}m` else `New quests in {math.max(1, minutes)}m`
end

-- "4 days left": to Monday 00:00 UTC, when QuestService rolls the week's quests
local function weekText(): string
	return QuestRules.weekLeftText(os.time())
end

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The bottom of the top-right column's last piece on a phone (its frame keeps room for a taller dock: going by the frame
-- put the strip on the jump button, owner 2026-11-17)
local function columnBottom(column: GuiObject): number
	local bottom = column.AbsolutePosition.Y
	for _, child in column:GetChildren() do
		if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.Y > 0 then
			bottom = math.max(bottom, child.AbsolutePosition.Y + child.AbsoluteSize.Y)
		end
	end
	return bottom
end

-- The tracker's place. A computer: under the team strip (or where it would be), what rides under it right under the
-- strip. A phone (owner 2026-11-17, "go A" of artifact GtT4bM87otu1aayFVANr7z): the quests' chip beside the cash pill,
-- its middle on the pill's; what rides under it under the top-right column's last piece (and the team strip), beside the
-- jump button if it would reach it
local function place()
	local origin = screen.AbsolutePosition
	local teamBottom: number? = nil
	local column = screen:FindFirstChild("TeamColumn", true)
	if column and column:IsA("GuiObject") and column.Visible and column.AbsoluteSize.Y > 4 then
		teamBottom = column.AbsolutePosition.Y + column.AbsoluteSize.Y - origin.Y
	end
	local slot = belowSlot
	if UIController.IsCompact() then
		local cash = UIController.GetCashPill()
		local chip = tracker.AbsoluteSize
		local top = cash.AbsolutePosition.Y - origin.Y + (cash.AbsoluteSize.Y - chip.Y) / 2
		tracker.Position = UDim2.new(1, -(screen.AbsoluteSize.X - (cash.AbsolutePosition.X - origin.X) + TRACKER.cashGap), 0, top)
		if slot then
			local size = screen.AbsoluteSize
			local below = math.max(columnBottom(UIController.GetStatusRow()) - origin.Y, if teamBottom then teamBottom + 2 else 0)
			local own = slot.AbsoluteSize
			local slotTop, slotRight = CompactHud.questSpot(below, { w = own.X, h = own.Y }, { w = size.X, h = size.Y }, CompactHud.jumpRect(size.X, size.Y), TRACKER.margin, TRACKER.phoneGap)
			slot.Position = UDim2.new(1, -slotRight, 0, slotTop)
		end
		return
	end
	-- under your row at the top right in a computer's column layout, and under the team strip
	local start = UIController.GetColumnStart(TRACKER.desktopTop)
	local top = if teamBottom then math.max(start, teamBottom + 10) else start
	tracker.Position = UDim2.new(1, -TRACKER.margin, 0, top)
	if slot then
		local slotTop = if tracker.Visible then top + tracker.AbsoluteSize.Y + TRACKER.belowGap else top
		slot.Position = UDim2.new(1, -TRACKER.margin, 0, slotTop)
	end
end

-- On a computer the quests are a Phone app (owner 2026-11-21; Config/DesktopHud QUESTS): no strip on the HUD
local function inPhone(): boolean
	return DesktopHud.questsInPhone(DesktopHud.layout(UIController.IsCompact(), DesktopHudConfig), DesktopHudConfig)
end

-- The Quests app's red count (what waits: Util/PhoneNotice.quests) and the Phone tile's ping or nudge when it rises or
-- the quests moved on (`changed`)
local phoneWaiting = 0
local function tellPhone(changed: boolean)
	if not inPhone() then
		return
	end
	local goal = MainQuest.current()
	-- quiet through a guide's tour that hides the quests (the calm HUD): no count, no ping
	local hidden = Hud.hides("quests")
	local count = PhoneNotice.quests(view :: any, goal ~= nil and goal.kind == "build" and goal.ready, hidden)
	Hud.setBadge("Quests", count)
	Hud.notice(if hidden then nil else PhoneNotice.kind(phoneWaiting, count, changed))
	phoneWaiting = count
end

local function renderTracker()
	local current = view
	local aside = (UIController.IsCompact() and windowOpen) or bossFight
	QuestStrip.setInPhone(inPhone())
	tracker.Visible = current ~= nil and #current.quests > 0 and not aside and not inPhone()
	if belowSlot then
		belowSlot.Visible = not aside
	end
	QuestStrip.render(current, UIController.IsCompact(), resetText(), weekText())
	place()
end

local function claim(which: number | string, button: GuiObject)
	lastClaimAt = button.AbsolutePosition + button.AbsoluteSize / 2
	Remotes.QuestClaim:FireServer(which)
end

-- A section's heading in the window: its picture and name on the left, how it's going on the right (returned, so a
-- countdown can keep ticking in it)
local function sectionHead(name: string, order: number, icon: string, title: string, right: string, palette: UIKit.Palette): TextLabel
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = list
	local picture = Icon.make(row, icon, UDim2.fromOffset(26, 26))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.new(0, 6, 0.5, 0)
	local words = UIKit.label(row, title, Enum.Font.FredokaOne, 20, UIStyle.BABY.lilac.deep)
	words.Position = UDim2.fromOffset(40, 0)
	words.Size = UDim2.new(0.5, -40, 1, 0)
	words.TextWrapped = false
	local side = UIKit.label(row, right, Enum.Font.GothamBold, 14, palette.hint)
	side.Name = "Side"
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.new(1, -6, 0, 0)
	side.Size = UDim2.new(0.5, 0, 1, 0)
	side.TextXAlignment = Enum.TextXAlignment.Right
	side.TextWrapped = false
	return side
end

-- A pay chip: a small picture and a few words in a soft pill ("$75", "75 XP", "Weekly Chest")
local function payChip(parent: GuiObject, order: number, icon: string, text: string, palette: UIKit.Palette)
	local chip = Instance.new("Frame")
	chip.Name = "Pay"
	chip.LayoutOrder = order
	chip.BackgroundColor3 = palette.slotEmpty
	chip.Size = UDim2.fromOffset(0, 20)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Parent = parent
	UIKit.corner(chip, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = chip
	local line = Instance.new("UIListLayout")
	line.FillDirection = Enum.FillDirection.Horizontal
	line.VerticalAlignment = Enum.VerticalAlignment.Center
	line.Padding = UDim.new(0, 3)
	line.SortOrder = Enum.SortOrder.LayoutOrder
	line.Parent = chip
	Icon.make(chip, icon, UDim2.fromOffset(16, 16)).LayoutOrder = 1
	local words = UIKit.label(chip, text, Enum.Font.GothamBold, 13, palette.ink)
	words.LayoutOrder = 2
	words.Size = UDim2.fromOffset(0, 20)
	words.AutomaticSize = Enum.AutomaticSize.X
	words.TextWrapped = false
end

-- A row's card in the window (Config/Quests WINDOW, QuestRules.rowBox; owner 2026-11-20, relaid out): its picture on
-- a soft tile, and where its middle column and its action column go. Returns the card and its columns' places
local function card(name: string, order: number, look: any, fill: Color3, edge: Color3, icon: string, tileFill: Color3): (Frame, QuestRules.RowBox)
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, look.height)
	row.BackgroundColor3 = fill
	row.Parent = list
	UIKit.corner(row, 14)
	UIKit.outline(row, edge, 2)
	local box = QuestRules.rowBox(0, look) -- from the card's own edges: middleW is what the middle gives up
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, box.iconX, 0.5, 0)
	tile.Size = UDim2.fromOffset(look.icon, look.icon)
	tile.BackgroundColor3 = tileFill
	tile.Parent = row
	UIKit.corner(tile, 12)
	local picture = Icon.make(tile, icon, UDim2.fromScale(0.78, 0.78))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	return row, box
end

-- A card's middle column: its title, a thick bar under it and a line of pay chips (returned, to fill)
local function middle(row: Frame, box: QuestRules.RowBox, look: any, title: string, share: number, barColor: Color3, palette: UIKit.Palette): Frame
	local top = (look.height - (look.title + 6 + 8 + look.bar + 8 + 20)) / 2
	local words = UIKit.label(row, title, Enum.Font.FredokaOne, look.title, palette.ink)
	words.Name = "Words"
	words.Position = UDim2.fromOffset(box.middleX, top)
	words.Size = UDim2.new(1, box.middleW, 0, look.title + 6)
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.TextWrapped = false
	local track = UIKit.bar(row, share, barColor)
	track.Position = UDim2.fromOffset(box.middleX, top + look.title + 6 + 6)
	track.Size = UDim2.new(1, box.middleW, 0, look.bar)
	local pays = Instance.new("Frame")
	pays.Name = "Pays"
	pays.BackgroundTransparency = 1
	pays.Position = UDim2.fromOffset(box.middleX, top + look.title + 6 + 6 + look.bar + 8)
	pays.Size = UDim2.new(1, box.middleW, 0, 20)
	pays.Parent = row
	local payLine = Instance.new("UIListLayout")
	payLine.FillDirection = Enum.FillDirection.Horizontal
	payLine.VerticalAlignment = Enum.VerticalAlignment.Center
	payLine.Padding = UDim.new(0, 6)
	payLine.SortOrder = Enum.SortOrder.LayoutOrder
	payLine.Parent = pays
	return pays
end

-- Puts a card's action (a button, or words) in its action column, centred
local function seat(action: GuiObject, look: any)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -look.pad, 0.5, 0)
	action.Size = UDim2.fromOffset(look.action, look.button)
	if action:IsA("TextLabel") then
		action.TextXAlignment = Enum.TextXAlignment.Center
		action.TextWrapped = true
	end
end

-- One quest's row (owner 2026-11-21: "easily understandable/immersive"; relaid out 2026-11-20): its picture on a tile,
-- its words over a thick bar and its pay as chips, and in the action column Claim (the whole card turns mint: its pay
-- waits), else how far it is, big ("3 / 8"), or a word once it's claimed or done (QuestRules.actionWords)
local function questRow(index: number, quest: QuestView, palette: UIKit.Palette, weekly: boolean)
	local state = QuestRules.rowState(quest :: any, weekly)
	local baby = UIStyle.BABY
	local look = WINDOW.ROW
	local waiting = state == "claim"
	local finished = state == "claimed" or state == "done"
	local row, box = card(
		if weekly then `Week{index}` else `Quest{index}`,
		if weekly then WEEK_ORDER + index else index,
		look,
		if waiting then baby.mint.light else palette.row,
		if waiting then baby.mint.deep else palette.rowEdge,
		quest.icon,
		if waiting then Color3.new(1, 1, 1) else palette.slotEmpty
	)
	local pays = middle(row, box, look, quest.text, quest.progress / math.max(1, quest.goal), if quest.done then baby.mint.fill else baby.sky.fill, palette)
	for order, pay in QuestRules.pay(quest :: any, weekly) do
		payChip(pays, order, pay.icon, pay.text, palette)
	end
	local words = QuestRules.actionWords(quest :: any, weekly)
	if words then
		local label = UIKit.label(row, if finished then `{words} ✅` else words, Enum.Font.FredokaOne, if finished then 16 else 22, if finished then baby.mint.deep else palette.inkSoft)
		label.Name = "Count"
		seat(label, look)
	else
		local button = UIKit.button(row, "Claim", UIKit.Colors.Success)
		button.Name = "Claim"
		button.Activated:Connect(function()
			claim(index, button)
		end)
		seat(button, look)
	end
end

-- "Epic Pack + XP Tonic x2"
local function itemNames(items: { { item: string, count: number } }): string
	local names = {}
	for _, entry in items do
		local info = Items.ITEMS[entry.item]
		local name = if info then info.name else entry.item
		table.insert(names, if entry.count > 1 then `{name} x{entry.count}` else name)
	end
	return table.concat(names, " + ")
end

-- A chest's row (the Quest Chest: all three claimed; the Weekly Chest: all three done): what's in it and Open
local function chestRow(chest: Chest, palette: UIKit.Palette)
	local look = WINDOW.ROW
	local row, box = card(chest.name, chest.order, look, chest.tint.light, chest.tint.deep, "Gift", Color3.new(1, 1, 1))
	local title = UIKit.label(row, chest.title, Enum.Font.FredokaOne, look.title, palette.ink)
	title.Position = UDim2.fromOffset(box.middleX, 14)
	title.Size = UDim2.new(1, box.middleW, 0, look.title + 6)
	title.TextWrapped = false
	local inside = UIKit.label(row, itemNames(chest.items), Enum.Font.GothamBold, 13, palette.inkSoft)
	inside.Position = UDim2.fromOffset(box.middleX, 14 + look.title + 8)
	inside.Size = UDim2.new(1, box.middleW, 0, 32)
	inside.TextYAlignment = Enum.TextYAlignment.Top
	local action: GuiObject
	if chest.opened then
		action = UIKit.label(row, "Opened ✅", Enum.Font.FredokaOne, 16, UIStyle.BABY.mint.deep)
	elseif chest.ready then
		local button = UIKit.button(row, "Open", UIKit.Colors.Accent)
		button.Name = if chest.which == "week" then "OpenWeekChest" else "OpenChest"
		button.Activated:Connect(function()
			claim(chest.which, button)
		end)
		action = button
	else
		action = UIKit.label(row, chest.waiting, Enum.Font.FredokaOne, 15, palette.hint)
	end
	seat(action, look)
end

-- Standing by your shop (the server refuses placements from further: PlacementService)
local function nearShop(): boolean
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	local floor = if plot then plot:FindFirstChild("Floor") else nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not floor or not floor:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - floor.Position).Magnitude <= Placement.MAX_EDIT_DISTANCE
end

-- The main quest's Build: that item's placement (the Build menu's own checks), or why it can't be built here
local function buildMain(goal: MainQuestRules.Goal)
	if goal.kind ~= "build" then
		return
	end
	if Place.isFrontier() or Place.isDungeon() then
		BlockedController.Show(`Build the {goal.name} in your shop, back in town.`)
		return
	end
	if not nearShop() then
		BlockedController.Show(`Go back to your shop to build the {goal.name}.`)
		return
	end
	if panel.Visible then
		UIKit.closePanel(panel)
	end
	local BuildController = require(Controllers:WaitForChild("BuildController")) :: any
	BuildController.Buy(goal.id)
end

-- The window's first section (owner 2026-11-18, look A): "Main Quest", what to build (or the level to reach) with its
-- bar and Build once paid for, then the other items still to build
local function mainSection(palette: UIKit.Palette)
	local goal = MainQuest.current()
	if not goal then
		return
	end
	local baby = UIStyle.BABY
	local look = WINDOW.MAIN
	sectionHead("MainHead", MAIN_ORDER, "👑", "Main Quest", if goal.kind == "build" then "Grow your shop" else "Level up your shop", palette)
	-- the hero card: a bigger picture and title, what it pays as a chip with how far it is ("$250 / $300") at that
	-- line's right end (beside the title it cut "Build the Accessory Shelf" short), and Build (or what's missing) in
	-- the action column
	local row, box = card("MainQuest", MAIN_ORDER + 1, look, baby.lilac.light, if goal.ready then baby.mint.deep else baby.lilac.deep, goal.icon, Color3.new(1, 1, 1))
	local barColor = if goal.ready then baby.mint.fill elseif goal.kind == "level" then baby.lilac.fill else baby.butter.fill
	local pays = middle(row, box, look, goal.text, goal.progress, barColor, palette)
	local count = UIKit.label(row, goal.amount, Enum.Font.FredokaOne, 15, if goal.ready then baby.mint.deep else palette.inkSoft)
	count.Name = "Count"
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -(look.pad + look.action + look.gap), 0, pays.Position.Y.Offset)
	count.Size = UDim2.fromOffset(130, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextWrapped = false
	if goal.kind == "build" then
		payChip(pays, 1, "Level", `{MainQuestRules.reward(MainQuests, goal.cost)} XP when built`, palette)
	else
		payChip(pays, 1, "Level", "Opens new things to build", palette)
	end
	local action: GuiObject
	if goal.ready then
		local button = UIKit.button(row, "Build", UIKit.Colors.Success)
		button.Name = "Build"
		button.TextSize = 20
		button.Activated:Connect(function()
			buildMain(goal)
		end)
		action = button
	elseif goal.kind == "build" then
		local cash = player:GetAttribute("Cash")
		local short = goal.cost - (if typeof(cash) == "number" then cash else 0)
		action = UIKit.label(row, `{MainQuestRules.money(short)} to go`, Enum.Font.FredokaOne, 17, palette.hint)
	else
		action = UIKit.label(row, "Keep going!", Enum.Font.FredokaOne, 16, palette.hint)
	end
	seat(action, look)
	-- what's next to build: a small heading and up to three cells side by side (picture, name, price)
	local nextLook = WINDOW.THEN
	local others = MainQuest.others()
	local shown = math.min(#others, nextLook.max)
	if shown > 0 then
		local strip = Instance.new("Frame")
		strip.Name = "MainThen"
		strip.LayoutOrder = MAIN_ORDER + 2
		strip.BackgroundTransparency = 1
		strip.Size = UDim2.new(1, 0, 0, 18 + nextLook.height)
		strip.Parent = list
		local caption = UIKit.label(strip, nextLook.caption, Enum.Font.GothamBold, 12, palette.hint)
		caption.Position = UDim2.fromOffset(6, 0)
		caption.Size = UDim2.new(1, -12, 0, 16)
		caption.TextWrapped = false
		local cells = Instance.new("Frame")
		cells.BackgroundTransparency = 1
		cells.Position = UDim2.fromOffset(0, 18)
		cells.Size = UDim2.new(1, 0, 0, nextLook.height)
		cells.Parent = strip
		local line = Instance.new("UIListLayout")
		line.FillDirection = Enum.FillDirection.Horizontal
		line.SortOrder = Enum.SortOrder.LayoutOrder
		line.Padding = UDim.new(0, nextLook.gap)
		line.Parent = cells
		for index = 1, shown do
			local item = others[index]
			local cell = Instance.new("Frame")
			cell.Name = `Then{index}`
			cell.LayoutOrder = index
			-- equal shares of the row, the gaps taken out of each
			cell.Size = UDim2.new(1 / shown, -nextLook.gap * (shown - 1) / shown, 1, 0)
			cell.BackgroundColor3 = palette.row
			cell.Parent = cells
			UIKit.corner(cell, 12)
			UIKit.outline(cell, palette.rowEdge, 1.5)
			local small = Icon.make(cell, item.icon, UDim2.fromOffset(28, 28))
			small.AnchorPoint = Vector2.new(0, 0.5)
			small.Position = UDim2.new(0, 8, 0.5, 0)
			local name = UIKit.label(cell, item.name, Enum.Font.FredokaOne, 14, palette.ink)
			name.Position = UDim2.fromOffset(44, 6)
			name.Size = UDim2.new(1, -50, 0, 18)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.TextWrapped = false
			local price = UIKit.label(cell, MainQuestRules.money(item.cost), Enum.Font.GothamBold, 13, palette.inkSoft)
			price.Position = UDim2.fromOffset(44, 24)
			price.Size = UDim2.new(1, -50, 0, 16)
			price.TextWrapped = false
		end
	end
end

local function renderPanel()
	local current = view
	if not panel.Visible or not current then
		return
	end
	clearChildren(list)
	weekLabel = nil
	dayLabel = nil
	local palette = UIKit.colorsFor(panel)
	mainSection(palette)
	-- today's quests under their own heading: how many are done on the left, when new ones come on the right (the
	-- window's footer line moved here, beside what it's about)
	dayLabel = sectionHead("DayHead", 0, "📜", `Today · {QuestRules.sectionLine(current :: any)}`, resetText(), palette)
	for index, quest in current.quests do
		questRow(index, quest, palette, false)
	end
	chestRow({
		name = "Bonus",
		order = 10,
		title = "Quest Chest",
		items = Quests.BONUS,
		ready = current.bonusReady,
		opened = current.bonusClaimed,
		waiting = QuestRules.chestWaiting(QuestRules.chestLeft(current :: any, false)),
		which = "bonus",
		tint = UIStyle.BABY.butter,
	}, palette)
	local week = current.week
	if week and #week.quests > 0 then
		weekLabel = sectionHead("WeekHead", WEEK_ORDER, "⭐", `This week · {QuestRules.sectionLine(week :: any)}`, weekText(), palette)
		for index, quest in week.quests do
			questRow(index, quest, palette, true)
		end
		chestRow({
			name = "WeekChest",
			order = WEEK_ORDER + 10,
			title = "Weekly Chest",
			items = Quests.WEEKLY.CHEST,
			ready = week.bonusReady,
			opened = week.bonusClaimed,
			waiting = QuestRules.chestWaiting(QuestRules.chestLeft(week :: any, true)),
			which = "week",
			tint = UIStyle.BABY.sky,
		}, palette)
	end
end

local function buildTracker()
	holder = Instance.new("Frame")
	holder.Name = "QuestHud"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = screen
	Hud.hideWith(holder) -- fights and full-screen views
	Hud.calmPiece(holder, "quests") -- Pish's and Chikin's calm HUD
	tracker = QuestStrip.build(holder)
	-- bigger on a desktop (owner 2026-11-21: "increase font size. its small on the laptops"): the strip and the chips
	-- under it grow with the screen (Util/Hud.scaleWith grow, Config/HudGrow); a phone's chip keeps its size
	Hud.scaleWith(tracker, 1, true)
	tracker.Activated:Connect(function()
		panel.Visible = true
	end)
	local slot = Instance.new("Frame")
	slot.Name = "QuestBelow"
	slot.BackgroundTransparency = 1
	slot.AnchorPoint = Vector2.new(1, 0)
	slot.AutomaticSize = Enum.AutomaticSize.XY
	slot.Size = UDim2.fromOffset(0, 0)
	slot.Parent = holder
	local stack = Instance.new("UIListLayout")
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, TRACKER.belowGap)
	stack.Parent = slot
	for _, piece in belowPieces do
		piece.Parent = slot
	end
	Hud.scaleWith(slot, 1, true)
	belowSlot = slot
end

local function buildPanel()
	panel, list = UIKit.panel(screen, "Quests", "Quests", "Quests")
	Icon.header(panel, "📜", UIKit.HEADER_HEIGHT)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(WINDOW.width, WINDOW.height)
	end
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, WINDOW.list.gap)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	-- room inside the list: a row's outline isn't cut by the list's edge, and rows stop short of the scroll bar
	-- (owner 2026-11-20: "borders cutoff")
	local room = Instance.new("UIPadding")
	room.PaddingLeft = UDim.new(0, WINDOW.list.left)
	room.PaddingRight = UDim.new(0, WINDOW.list.right)
	room.PaddingTop = UDim.new(0, WINDOW.list.top)
	room.PaddingBottom = UDim.new(0, WINDOW.list.bottom)
	room.Parent = list
	list.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + 22)) -- no footer line: each section's heading has its own
	panel:GetPropertyChangedSignal("Visible"):Connect(renderPanel)
end

-- A claim's moment: coins from the button into the cash pill and a toast; the chest's items in the Bag; the Weekly
-- Chest's the gifts' win moment (a pack in it can be opened right there)
local function onClaimed(which: unknown, cash: unknown, xp: unknown, items: unknown)
	if which == "week" and typeof(items) == "table" then
		if panel.Visible then
			UIKit.closePanel(panel)
		end
		local lines = GiftRules.lines({ items = items :: any }, Items, nil)
		task.spawn(function()
			local pack = GiftWin.play("questWeek", 0, lines)
			if pack then
				Remotes.OpenBagPack:FireServer(pack)
			end
		end)
		return
	end
	if which == "bonus" and typeof(items) == "table" then
		local names = {}
		for _, entry in items :: { any } do
			local info = Items.ITEMS[entry.item]
			table.insert(names, if info then info.name else tostring(entry.item))
		end
		UIController.Notify(`Quest Chest opened! {table.concat(names, " and ")} went in your Bag.`, false, nil, "Gift")
		return
	end
	if typeof(cash) ~= "number" or typeof(xp) ~= "number" then
		return
	end
	local from = lastClaimAt or screen.AbsoluteSize / 2
	CoinBurst.fly(screen, from, UIController.GetCashPill(), 6)
	UIController.Notify(`Quest claimed! +${cash} and +{xp} shop XP`, false, nil, "Cash")
end

local function onState(payload: unknown, finished: unknown, weekFinished: unknown)
	local before = view
	view = if typeof(payload) == "table" then payload :: View else nil
	renderTracker()
	renderPanel()
	tellPhone(PhoneNotice.questsChanged(before :: any, view :: any))
	local current = view
	if current and typeof(finished) == "number" then
		local quest = current.quests[finished]
		if quest then
			local where = if inPhone() then "Claim it on your Phone." else "Tap Quests to claim."
			UIController.Notify(`Quest done: {quest.text}! {where}`, false, nil, quest.icon)
		end
	end
	local week = if current then current.week else nil
	if week and typeof(weekFinished) == "number" then
		local quest = week.quests[weekFinished]
		if quest then
			UIController.Notify(`Weekly quest done: {quest.text}!`, false, nil, quest.icon)
		end
	end
end

-- A small piece riding under the strip (Turts' restock chip, owner 2026-11-17, look A): right under it, its right edge
-- on the strip's; on a phone under the top-right column (the strip is a chip by the cash there), off the jump button and
-- hidden while a window is open, like the strip; the piece shows and hides itself otherwise (town only, say)
function QuestController.Below(piece: GuiObject)
	table.insert(belowPieces, piece)
	local slot = belowSlot
	if slot then
		piece.Parent = slot
		place()
	end
end

-- The quests as the window draws them (Util/QuestRules.View; nil before the server's first word): the What now? tips
-- read them (HintController)
function QuestController.QuestView(): any?
	return view
end

-- Where a What now? tip about quests points: on a computer the Phone's tile (its Quests app once the Phone is open), on
-- a phone the quest strip
function QuestController.HintTarget(): GuiObject?
	if inPhone() then
		return if Hud.isTrayOpen() then Hud.find("Quests") else Hud.find("Manage")
	end
	return tracker
end

function QuestController.Start()
	screen = UIController.GetScreenGui()
	buildTracker()
	buildPanel()
	UIKit.onPanelsChanged(function(open: boolean)
		windowOpen = open
		renderTracker()
	end)
	UIController.OnCompact(function()
		renderTracker()
	end)
	Remotes.QuestState.OnClientEvent:Connect(onState)
	Remotes.QuestClaim.OnClientEvent:Connect(onClaimed)
	-- The main quest: its row and the window follow the goal; a first build plays its moment and a toast
	QuestStrip.onBuild(buildMain)
	MainQuest.onChanged(function(goal)
		QuestStrip.setMain(goal)
		renderPanel()
		tellPhone(false) -- a build you can now pay for waits in the Quests app
	end)
	-- A computer's Quests app, first on the Phone (owner 2026-11-21: "put the quests inside phone"); it opens the
	-- Quests window, away from town too (a wild fight counts for a quest)
	if inPhone() then
		Hud.fanButton({
			id = "Quests",
			icon = "📜",
			label = "Quests",
			order = 0,
			everywhere = true,
			onClick = function()
				panel.Visible = true
			end,
		})
		tellPhone(false)
		Hud.onCalm(function()
			tellPhone(false) -- a tour began or ended: the count goes or comes back
		end)
	end
	QuestStrip.setMain(MainQuest.current())
	Remotes.BattleStarted.OnClientEvent:Connect(function(payload: unknown)
		QuestStrip.setFighting(true)
		bossFight = typeof(payload) == "table" and typeof((payload :: any).boss) == "string"
		renderTracker()
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function()
		QuestStrip.setFighting(false)
		bossFight = false
		renderTracker()
	end)
	Remotes.MainQuestDone.OnClientEvent:Connect(function(shelfId: unknown, xp: unknown)
		if typeof(shelfId) ~= "string" or typeof(xp) ~= "number" then
			return
		end
		local def = Shelves.ById[shelfId]
		local name = if def then def.name else shelfId
		QuestStrip.mainDone(name, xp)
		UIController.Notify(`Main quest done: {name} built! +{xp} shop XP`, false, nil, "Level")
	end)
	Remotes.QuestState:FireServer() -- today's quests, whatever order the controllers started in
	tracker:GetPropertyChangedSignal("AbsoluteSize"):Connect(place) -- a fold moves what rides under it at once
	UIController.GetCashPill():GetPropertyChangedSignal("AbsoluteSize"):Connect(place) -- a phone's chip beside the cash
	-- The tracker follows the cash row and the team strip; the window's countdown ticks while it's open
	task.spawn(function()
		while true do
			task.wait(0.5)
			if tracker.Visible or (belowSlot and belowSlot.Visible) then
				place()
			end
			if tracker.Visible then
				QuestStrip.tick(resetText(), weekText())
			end
			if panel.Visible then
				local day = dayLabel
				if day then
					day.Text = resetText()
				end
				local label = weekLabel
				if label then
					label.Text = weekText()
				end
			end
		end
	end)
end

return QuestController
