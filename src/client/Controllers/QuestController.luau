--!strict
-- Daily quests on screen (owner 2026-11-17; the always-on tracker, mockup pick B): the strip at the top right with
-- today's three quests and their bars (Util/QuestStrip: its look and animations; one line on a phone), a toast as one is
-- done, and tapping it opens the Quests window: each quest's words, bar and pay with Claim, the Quest Chest once all
-- three are claimed, and the time until new ones. Coins fly from a claimed quest into the cash pill. QuestService
-- decides everything; this shows it and asks (Remotes.QuestState, Remotes.QuestClaim). The strip hides with the HUD
-- (fights, full-screen views, Pish's and Chikin's calm HUD) and, on a phone, while a window is open; there it sits
-- under the top-right column, clear of the jump button (CompactHud.questSpot).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Quests = require(Config:WaitForChild("Quests"))
local Teams = require(Config:WaitForChild("Teams"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local QuestStrip = require(ClientUtil:WaitForChild("QuestStrip"))
local UIController = require(Controllers:WaitForChild("UIController"))

local QuestController = {}

type QuestView = { id: string, kind: string, text: string, icon: string, goal: number, progress: number, done: boolean, claimed: boolean, cash: number, xp: number }
type View = { quests: { QuestView }, bonusReady: boolean, bonusClaimed: boolean, claimable: number }

local TRACKER = { margin = 16, phoneGap = 8, desktopTop = Teams.STRIP.top }
local ROW_HEIGHT = 76

local view: View? = nil
local screen: ScreenGui
local holder: Frame
local tracker: TextButton
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

-- The tracker's place: under the team strip on a computer (or where it would be); on a phone under the top-right column
-- (and the team strip), beside the jump button if it would reach it
local function place()
	local top = TRACKER.desktopTop
	local right = TRACKER.margin
	local compact = UIController.IsCompact()
	local below = if compact then columnBottom(UIController.GetStatusRow()) - screen.AbsolutePosition.Y else 0
	local column = screen:FindFirstChild("TeamColumn", true)
	if column and column:IsA("GuiObject") and column.Visible and column.AbsoluteSize.Y > 4 then
		local teamBottom = column.AbsolutePosition.Y + column.AbsoluteSize.Y - screen.AbsolutePosition.Y
		top = math.max(top, teamBottom + 10)
		below = math.max(below, teamBottom + 2)
	end
	if compact then
		local size = screen.AbsoluteSize
		local jump = CompactHud.jumpRect(size.X, size.Y)
		local own = tracker.AbsoluteSize
		top, right = CompactHud.questSpot(below, { w = own.X, h = own.Y }, { w = size.X, h = size.Y }, jump, TRACKER.margin, TRACKER.phoneGap)
	end
	tracker.Position = UDim2.new(1, -right, 0, top)
end

local function renderTracker()
	local current = view
	tracker.Visible = current ~= nil and #current.quests > 0 and not (UIController.IsCompact() and windowOpen)
	QuestStrip.render(current, UIController.IsCompact(), resetText())
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
	tracker = QuestStrip.build(holder)
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
				QuestStrip.tick(resetText())
			end
			if panel.Visible then
				resetLabel.Text = resetText()
			end
		end
	end)
end

return QuestController
