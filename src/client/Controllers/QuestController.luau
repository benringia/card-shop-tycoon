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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Quests = require(Config:WaitForChild("Quests"))
local Teams = require(Config:WaitForChild("Teams"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local QuestRules = require(Shared:WaitForChild("Util"):WaitForChild("QuestRules"))
local GiftRules = require(Shared:WaitForChild("Util"):WaitForChild("GiftRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local QuestStrip = require(ClientUtil:WaitForChild("QuestStrip"))
local GiftWin = require(ClientUtil:WaitForChild("GiftWin"))
local UIController = require(Controllers:WaitForChild("UIController"))

local QuestController = {}

type QuestView = QuestRules.QuestView
type View = QuestRules.View
type Chest = { name: string, order: number, title: string, items: { { item: string, count: number } }, ready: boolean, opened: boolean, waiting: string, which: string, tint: { light: Color3, deep: Color3 } }

-- belowGap: the strip's outline (3 px, 4.5 glowing) and the chip's rim (3 px) are drawn outside them, so 12 shows about
-- 6 (owner 2026-11-17: "add small gap between them"); cashGap: a phone's quest chip to the cash pill
local TRACKER = { margin = 16, phoneGap = 8, desktopTop = Teams.STRIP.top, belowGap = 12, cashGap = 8 }
local ROW_HEIGHT = 76
local WEEK_ORDER = 20 -- the week's rows come after the day's and their chest in the window

local view: View? = nil
local screen: ScreenGui
local holder: Frame
local tracker: TextButton
local panel: Frame
local list: ScrollingFrame
local resetLabel: TextLabel
local weekLabel: TextLabel? = nil
local belowSlot: Frame? = nil -- pieces riding under the strip (QuestController.Below)
local belowPieces: { GuiObject } = {}
local windowOpen = false -- any UIKit window (a phone's tracker steps aside)
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
	local top = if teamBottom then math.max(TRACKER.desktopTop, teamBottom + 10) else TRACKER.desktopTop
	tracker.Position = UDim2.new(1, -TRACKER.margin, 0, top)
	if slot then
		local slotTop = if tracker.Visible then top + tracker.AbsoluteSize.Y + TRACKER.belowGap else top
		slot.Position = UDim2.new(1, -TRACKER.margin, 0, slotTop)
	end
end

local function renderTracker()
	local current = view
	local aside = UIController.IsCompact() and windowOpen
	tracker.Visible = current ~= nil and #current.quests > 0 and not aside
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

-- One quest's row in the window: its picture, words, bar, pay and Claim (or how far it is, or claimed); a `weekly` one
-- pays nothing itself (the Weekly Chest does) and says Done once done
local function questRow(index: number, quest: QuestView, palette: UIKit.Palette, weekly: boolean)
	local row = Instance.new("Frame")
	row.Name = if weekly then `Week{index}` else `Quest{index}`
	row.LayoutOrder = if weekly then WEEK_ORDER + index else index
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Parent = list
	UIKit.corner(row, 12)
	UIKit.outline(row, if quest.done and not quest.claimed and not weekly then UIStyle.BABY.mint.deep else palette.rowEdge, 2)
	local icon = Icon.make(row, quest.icon, UDim2.fromOffset(44, 44))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	local words = UIKit.label(row, quest.text, Enum.Font.FredokaOne, 17, palette.ink)
	words.Position = UDim2.fromOffset(66, 8)
	words.Size = UDim2.new(1, -66 - 130, 0, 22)
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.TextWrapped = false
	local track = UIKit.bar(row, quest.progress / math.max(1, quest.goal), if quest.done then UIStyle.BABY.mint.fill else UIStyle.BABY.sky.fill)
	track.Position = UDim2.fromOffset(66, 34)
	track.Size = UDim2.new(1, -66 - 130, 0, 10)
	local payText = if weekly then `{quest.progress}/{quest.goal} · for the Weekly Chest` else `{quest.progress}/{quest.goal} · +${quest.cash} · +{quest.xp} shop XP`
	local pay = UIKit.label(row, payText, Enum.Font.GothamBold, 13, palette.inkSoft)
	pay.Position = UDim2.fromOffset(66, 50)
	pay.Size = UDim2.new(1, -66 - 130, 0, 18)
	local action: GuiObject
	if weekly and quest.done then
		action = UIKit.label(row, "Done ✅", Enum.Font.FredokaOne, 16, UIStyle.BABY.mint.deep)
		action.Size = UDim2.fromOffset(116, 48)
	elseif quest.claimed then
		action = UIKit.label(row, "Claimed ✅", Enum.Font.FredokaOne, 16, palette.hint)
		action.Size = UDim2.fromOffset(116, 48)
	elseif quest.done and not weekly then
		local button = UIKit.button(row, "Claim", UIKit.Colors.Success)
		button.Name = "Claim"
		button.Size = UDim2.fromOffset(116, 48)
		button.Activated:Connect(function()
			claim(index, button)
		end)
		action = button
	else
		action = UIKit.label(row, "Keep going!", Enum.Font.FredokaOne, 15, palette.hint)
		action.Size = UDim2.fromOffset(116, 48)
	end
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -10, 0.5, 0)
	if action:IsA("TextLabel") then
		action.TextXAlignment = Enum.TextXAlignment.Center
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
	local row = Instance.new("Frame")
	row.Name = chest.name
	row.LayoutOrder = chest.order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = chest.tint.light
	row.Parent = list
	UIKit.corner(row, 12)
	UIKit.outline(row, chest.tint.deep, 2)
	local icon = Icon.make(row, "Gift", UDim2.fromOffset(44, 44))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	local title = UIKit.label(row, chest.title, Enum.Font.FredokaOne, 17, palette.ink)
	title.Position = UDim2.fromOffset(66, 10)
	title.Size = UDim2.new(1, -66 - 130, 0, 22)
	local inside = UIKit.label(row, itemNames(chest.items), Enum.Font.GothamBold, 13, palette.inkSoft)
	inside.Position = UDim2.fromOffset(66, 36)
	inside.Size = UDim2.new(1, -66 - 130, 0, 30)
	local action: GuiObject
	if chest.opened then
		action = UIKit.label(row, "Opened ✅", Enum.Font.FredokaOne, 16, palette.hint)
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
	action.Size = UDim2.fromOffset(116, 48)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -10, 0.5, 0)
	if action:IsA("TextLabel") then
		action.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- The week's heading in the window: "Weekly Quests" and the time left
local function weekHeading(palette: UIKit.Palette)
	local row = Instance.new("Frame")
	row.Name = "WeekHead"
	row.LayoutOrder = WEEK_ORDER
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -8, 0, 34)
	row.Parent = list
	local star = Icon.make(row, "⭐", UDim2.fromOffset(26, 26))
	star.AnchorPoint = Vector2.new(0, 0.5)
	star.Position = UDim2.new(0, 10, 0.5, 0)
	local words = UIKit.label(row, "Weekly Quests", Enum.Font.FredokaOne, 20, UIStyle.BABY.lilac.deep)
	words.Position = UDim2.fromOffset(44, 0)
	words.Size = UDim2.new(0.6, -44, 1, 0)
	words.TextWrapped = false
	local left = UIKit.label(row, weekText(), Enum.Font.GothamBold, 14, palette.hint)
	left.Name = "Left"
	left.AnchorPoint = Vector2.new(1, 0)
	left.Position = UDim2.new(1, -10, 0, 0)
	left.Size = UDim2.new(0.4, 0, 1, 0)
	left.TextXAlignment = Enum.TextXAlignment.Right
	weekLabel = left
end

local function renderPanel()
	local current = view
	if not panel.Visible or not current then
		return
	end
	clearChildren(list)
	weekLabel = nil
	local palette = UIKit.colorsFor(panel)
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
		waiting = "Claim all 3",
		which = "bonus",
		tint = UIStyle.BABY.butter,
	}, palette)
	local week = current.week
	if week and #week.quests > 0 then
		weekHeading(palette)
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
			waiting = "Finish all 3",
			which = "week",
			tint = UIStyle.BABY.sky,
		}, palette)
	end
	resetLabel.Text = resetText()
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
	belowSlot = slot
end

local function buildPanel()
	panel, list = UIKit.panel(screen, "Quests", "Quests", "Quests")
	Icon.header(panel, "📜", UIKit.HEADER_HEIGHT)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(560, 520)
	end
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	list.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + 52))
	resetLabel = UIKit.label(panel, "", Enum.Font.FredokaOne, 15, UIKit.colorsFor(panel).hint)
	resetLabel.Name = "Reset"
	resetLabel.AnchorPoint = Vector2.new(0.5, 1)
	resetLabel.Position = UDim2.new(0.5, 0, 1, -10)
	resetLabel.Size = UDim2.new(1, -24, 0, 22)
	resetLabel.TextXAlignment = Enum.TextXAlignment.Center
	resetLabel.ZIndex = panel.ZIndex + 2
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
	view = if typeof(payload) == "table" then payload :: View else nil
	renderTracker()
	renderPanel()
	local current = view
	if current and typeof(finished) == "number" then
		local quest = current.quests[finished]
		if quest then
			UIController.Notify(`Quest done: {quest.text}! Tap Quests to claim.`, false, nil, quest.icon)
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
				resetLabel.Text = resetText()
				local label = weekLabel
				if label then
					label.Text = weekText()
				end
			end
		end
	end)
end

return QuestController
