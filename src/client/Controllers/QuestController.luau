--!strict
-- Daily quests on screen (owner 2026-11-17; the always-on tracker, mockup pick B): a small card at the top right with
-- today's three quests and their bars (one line on a phone: "Quests 1/3"), a toast as one is done, and tapping it opens
-- the Quests window: each quest's words, bar and pay with Claim, the Quest Chest once all three are claimed, and the
-- time until new ones. Coins fly from a claimed quest into the cash pill. QuestService decides everything; this shows
-- it and asks (Remotes.QuestState, Remotes.QuestClaim). The tracker hides with the HUD (fights, full-screen views,
-- Pish's and Chikin's calm HUD) and, on a phone, while a window is open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Quests = require(Config:WaitForChild("Quests"))
local Teams = require(Config:WaitForChild("Teams"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local UIController = require(Controllers:WaitForChild("UIController"))

local QuestController = {}

type QuestView = { id: string, text: string, icon: string, goal: number, progress: number, done: boolean, claimed: boolean, cash: number, xp: number }
type View = { quests: { QuestView }, bonusReady: boolean, bonusClaimed: boolean, claimable: number }

local TRACKER = { width = 230, phoneWidth = 150, pad = 8, gap = 4, margin = 16, desktopTop = Teams.STRIP.top }
local ROW_HEIGHT = 76

local view: View? = nil
local screen: ScreenGui
local holder: Frame
local tracker: TextButton
local trackerTitle: TextLabel
local trackerClaim: TextLabel
local trackerRows: Frame
local panel: Frame
local list: ScrollingFrame
local resetLabel: TextLabel
local windowOpen = false -- any UIKit window (a phone's tracker steps aside)
local lastClaimAt: Vector2? = nil -- where the last Claim press was (the coins fly from there)

local function doneCount(current: View): number
	local done = 0
	for _, quest in current.quests do
		if quest.done then
			done += 1
		end
	end
	return done
end

-- "New quests in 9h 12m": to the next UTC midnight (QuestService's day, GiftRules.dayOf)
local function resetText(): string
	local left = 86400 - os.time() % 86400
	local hours, minutes = left // 3600, (left % 3600) // 60
	return if hours > 0 then `New quests in {hours}h {minutes}m` else `New quests in {math.max(1, minutes)}m`
end

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The tracker's place: under the team strip on a computer (or where it would be), under the cash row (and the strip) on a
-- phone
local function place()
	local top = TRACKER.desktopTop
	local compact = UIController.IsCompact()
	if compact then
		local status = UIController.GetStatusRow()
		top = status.AbsolutePosition.Y + status.AbsoluteSize.Y + 8
	end
	local column = screen:FindFirstChild("TeamColumn", true)
	if column and column:IsA("GuiObject") and column.Visible and column.AbsoluteSize.Y > 4 then
		top = math.max(top, column.AbsolutePosition.Y + column.AbsoluteSize.Y + 10)
	end
	tracker.Position = UDim2.new(1, -TRACKER.margin, 0, top - screen.AbsolutePosition.Y)
	tracker.Size = UDim2.fromOffset(if compact then TRACKER.phoneWidth else TRACKER.width, 0)
	trackerRows.Visible = not compact
end

local function renderTracker()
	local current = view
	tracker.Visible = current ~= nil and #current.quests > 0 and not (UIController.IsCompact() and windowOpen)
	if not current then
		return
	end
	trackerTitle.Text = `📜 Quests {doneCount(current)}/{#current.quests}`
	trackerClaim.Visible = current.claimable > 0
	clearChildren(trackerRows)
	if current.bonusClaimed then
		-- all claimed and the chest opened: one line until tomorrow's (the loop below keeps its countdown)
		trackerTitle.Text = "📜 Quests done!"
		local soon = UIKit.label(trackerRows, resetText(), Enum.Font.GothamBold, 12, UIStyle.CREAM.HINT)
		soon.Name = "Reset"
		soon.Size = UDim2.new(1, 0, 0, 16)
		place()
		return
	end
	for index, quest in current.quests do
		local row = Instance.new("Frame")
		row.Name = `Quest{index}`
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 30)
		row.Parent = trackerRows
		local color = if quest.claimed then UIStyle.CREAM.HINT elseif quest.done then UIStyle.CREAM.GOOD else UIStyle.CREAM.INK
		local words = UIKit.label(row, if quest.done then `✅ {quest.text}` else quest.text, Enum.Font.GothamBold, 12, color)
		words.Size = UDim2.new(1, -36, 0, 16)
		words.TextTruncate = Enum.TextTruncate.AtEnd
		words.TextWrapped = false
		local count = UIKit.label(row, `{quest.progress}/{quest.goal}`, Enum.Font.FredokaOne, 12, color)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, 0, 0, 0)
		count.Size = UDim2.fromOffset(34, 16)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local track = UIKit.bar(row, quest.progress / math.max(1, quest.goal), if quest.done then UIStyle.BABY.mint.fill else UIStyle.BABY.sky.fill)
		track.Position = UDim2.fromOffset(0, 19)
		track.Size = UDim2.new(1, 0, 0, 7)
		track.BackgroundColor3 = UIStyle.CREAM.TRACK -- the cream track (the card isn't a window, so the kit would pick the dark one)
	end
	place()
end

local function claim(which: number | string, button: GuiObject)
	lastClaimAt = button.AbsolutePosition + button.AbsoluteSize / 2
	Remotes.QuestClaim:FireServer(which)
end

-- One quest's row in the window: its picture, words, bar, pay and Claim (or how far it is, or claimed)
local function questRow(index: number, quest: QuestView, palette: UIKit.Palette)
	local row = Instance.new("Frame")
	row.Name = `Quest{index}`
	row.LayoutOrder = index
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Parent = list
	UIKit.corner(row, 12)
	UIKit.outline(row, if quest.done and not quest.claimed then UIStyle.BABY.mint.deep else palette.rowEdge, 2)
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
	local pay = UIKit.label(row, `{quest.progress}/{quest.goal} · +${quest.cash} · +{quest.xp} shop XP`, Enum.Font.GothamBold, 13, palette.inkSoft)
	pay.Position = UDim2.fromOffset(66, 50)
	pay.Size = UDim2.new(1, -66 - 130, 0, 18)
	local action: GuiObject
	if quest.claimed then
		action = UIKit.label(row, "Claimed ✅", Enum.Font.FredokaOne, 16, palette.hint)
		action.Size = UDim2.fromOffset(116, 48)
	elseif quest.done then
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

-- The Quest Chest: what's in it and Open once all three are claimed
local function bonusRow(current: View, palette: UIKit.Palette)
	local row = Instance.new("Frame")
	row.Name = "Bonus"
	row.LayoutOrder = 10
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIStyle.BABY.butter.light
	row.Parent = list
	UIKit.corner(row, 12)
	UIKit.outline(row, UIStyle.BABY.butter.deep, 2)
	local icon = Icon.make(row, "Gift", UDim2.fromOffset(44, 44))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	local names = {}
	for _, entry in Quests.BONUS do
		local info = Items.ITEMS[entry.item]
		table.insert(names, if info then info.name else entry.item)
	end
	local title = UIKit.label(row, "Quest Chest", Enum.Font.FredokaOne, 17, palette.ink)
	title.Position = UDim2.fromOffset(66, 10)
	title.Size = UDim2.new(1, -66 - 130, 0, 22)
	local inside = UIKit.label(row, table.concat(names, " + "), Enum.Font.GothamBold, 13, palette.inkSoft)
	inside.Position = UDim2.fromOffset(66, 36)
	inside.Size = UDim2.new(1, -66 - 130, 0, 30)
	local action: GuiObject
	if current.bonusClaimed then
		action = UIKit.label(row, "Opened ✅", Enum.Font.FredokaOne, 16, palette.hint)
	elseif current.bonusReady then
		local button = UIKit.button(row, "Open", UIKit.Colors.Accent)
		button.Name = "OpenChest"
		button.Activated:Connect(function()
			claim("bonus", button)
		end)
		action = button
	else
		action = UIKit.label(row, "Claim all 3", Enum.Font.FredokaOne, 15, palette.hint)
	end
	action.Size = UDim2.fromOffset(116, 48)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -10, 0.5, 0)
	if action:IsA("TextLabel") then
		action.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function renderPanel()
	local current = view
	if not panel.Visible or not current then
		return
	end
	clearChildren(list)
	local palette = UIKit.colorsFor(panel)
	for index, quest in current.quests do
		questRow(index, quest, palette)
	end
	bonusRow(current, palette)
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
	tracker = Instance.new("TextButton")
	tracker.Name = "QuestTracker"
	tracker.Text = ""
	tracker.AutoButtonColor = false
	tracker.AnchorPoint = Vector2.new(1, 0)
	tracker.AutomaticSize = Enum.AutomaticSize.Y
	tracker.BackgroundColor3 = UIStyle.CREAM.ROW
	tracker.BackgroundTransparency = 0.06
	tracker.Visible = false
	tracker.Parent = holder
	UIKit.corner(tracker, 12)
	UIKit.outline(tracker, UIStyle.CREAM.ROW_EDGE, 2)
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(pad :: any)[side] = UDim.new(0, TRACKER.pad)
	end
	pad.Parent = tracker
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, TRACKER.gap)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = tracker
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.LayoutOrder = 0
	top.Size = UDim2.new(1, 0, 0, 22)
	top.Parent = tracker
	trackerTitle = UIKit.label(top, "📜 Quests", Enum.Font.FredokaOne, 16, UIStyle.CREAM.INK)
	trackerTitle.Size = UDim2.fromScale(1, 1)
	trackerTitle.TextWrapped = false
	trackerClaim = UIKit.pill(top, "Claim!", UIStyle.BABY.mint.fill)
	trackerClaim.AnchorPoint = Vector2.new(1, 0.5)
	trackerClaim.Position = UDim2.new(1, 0, 0.5, 0)
	trackerClaim.Size = UDim2.fromOffset(0, 20)
	trackerClaim.TextSize = 13
	trackerClaim.Visible = false
	trackerRows = Instance.new("Frame")
	trackerRows.Name = "Rows"
	trackerRows.BackgroundTransparency = 1
	trackerRows.LayoutOrder = 1
	trackerRows.AutomaticSize = Enum.AutomaticSize.Y
	trackerRows.Size = UDim2.new(1, 0, 0, 0)
	trackerRows.Parent = tracker
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 2)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = trackerRows
	tracker.Activated:Connect(function()
		panel.Visible = true
	end)
end

local function buildPanel()
	panel, list = UIKit.panel(screen, "Quests", "Daily Quests", "Quests")
	Icon.header(panel, "📜", UIKit.HEADER_HEIGHT)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(560, 460)
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

-- A claim's moment: coins from the button into the cash pill and a toast; the chest's items in the Bag
local function onClaimed(which: unknown, cash: unknown, xp: unknown, items: unknown)
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

local function onState(payload: unknown, finished: unknown)
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
	-- The tracker follows the cash row and the team strip; the window's countdown ticks while it's open
	task.spawn(function()
		while true do
			task.wait(0.5)
			if tracker.Visible then
				place()
				local reset = trackerRows:FindFirstChild("Reset")
				if reset and reset:IsA("TextLabel") then
					reset.Text = resetText()
				end
			end
			if panel.Visible then
				resetLabel.Text = resetText()
			end
		end
	end)
end

return QuestController
