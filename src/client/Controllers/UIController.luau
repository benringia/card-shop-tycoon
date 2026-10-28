--!strict
-- Owns the main ScreenGui: the status corner (party bar, buff, cash, level / XP) and toast messages. Star Shards
-- show in the Bag, not here.
-- Other controllers add their panels to UIController.GetScreenGui(), and status items to GetStatusFrame().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local UIStyle = require(Shared:WaitForChild("Config"):WaitForChild("UIStyle"))

local TOAST_SECONDS = 2.5
local LEVEL_UP_TOAST_SECONDS = 5
local XP_FILL_COLOR = Color3.fromRGB(90, 160, 255)
local PILL_COLOR = Color3.fromRGB(22, 26, 38)
local PILL_HEIGHT = 42
local PILL_GAP = 8
local ICON_SIZE = 48 -- the icon pokes out a little past the pill's top and bottom
local XP_BAR_WIDTH = 140
-- Status sits in the bottom-right corner (the top corners hold Roblox's menu, chat and the player list). The
-- column, bottom up: level + XP (in line with the party bar), cash, then the buff badge; money toasts pop
-- in just above it. Touch screens: see TOUCH_TOP.
local STATUS_MARGIN = 12
-- Fixed sizes, not AutomaticSize: an auto-sized frame anchored to the right edge can lay out past the screen edge
local STATUS_WIDTH = 250
local STATUS_HEIGHT = 48 + 2 * 42 + 2 * 8 -- buff badge + two pills (cash, level) + gaps
local STATUS_ROW_WIDTH = 500 -- party bar + gap + status column; spare width is empty and lets clicks through
-- Everything in the corner shrinks with the screen's height (Hud.scaleWith, HudLayout.SCALE). On touch screens
-- (landscape phones are short, the jump button takes the bottom right) it is one column down the right edge from
-- the top: buff, cash, level, then the party bar, then the money toasts; it ends around the middle.
local TOUCH_TOP = 8
local TOUCH_PARTY_HEIGHT = 84 -- room for the party bar under the column
-- Money toasts (sales): stacked above the status corner, newest at the bottom
local SIDE_TOAST_SECONDS = 3.5
local SIDE_TOAST_MAX = 4
local SIDE_TOAST_MAX_TOUCH = 2 -- landscape phones are short
local SIDE_TOAST_HEIGHT = 38
local SIDE_TOAST_LIGHT = Color3.fromRGB(80, 210, 110)
local SIDE_TOAST_DARK = Color3.fromRGB(25, 130, 60)
local SIDE_TOAST_OUTLINE = Color3.fromRGB(10, 60, 25) -- dark text outline so white text reads on green
local SIDE_POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SIDE_SETTLE = TweenInfo.new(0.6)
local SIDE_FADE = TweenInfo.new(0.3)

local player = Players.LocalPlayer

local UIController = {}

local screenGui: ScreenGui
local statusRow: Frame
local statusFrame: Frame
local sideToasts: Frame
local sideToastOrder = 0
local cashLabel: TextLabel
local levelLabel: TextLabel
local xpLabel: TextLabel
local xpFill: Frame
local cashPill: Frame
local levelBadge: Frame
local toastLabel: TextLabel
local toastToken = 0

local function getNumber(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	-- No Cash yet = the save is still loading (can take a while in Studio): say so, so it never looks like a reset
	local loaded = typeof(cash) == "number"
	local text = if loaded then string.format("$%.2f", cash) else "Loading..."
	if cashLabel.Text ~= text and cashLabel.Text ~= "" then
		Motion.bump(cashPill)
	end
	cashLabel.Text = text
end

local function updateXp()
	if typeof(player:GetAttribute("XP")) ~= "number" then
		levelLabel.Text = ""
		xpLabel.Text = "Loading your shop..."
		xpFill.Size = UDim2.fromScale(0, 1)
		return
	end
	local xp = getNumber("XP", 0)
	local level = tostring(getNumber("Level", 1))
	if levelLabel.Text ~= level and levelLabel.Text ~= "" then
		Motion.bump(levelBadge)
	end
	levelLabel.Text = level
	local into, span = LevelRules.getProgress(xp)
	xpLabel.Text = `XP {into} / {span}`
	xpFill.Size = UDim2.fromScale(math.clamp(into / span, 0, 1), 1)
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

-- Bottom-right column: items stack upwards, right-aligned. Buff 1, cash 2, level 4 (bottom).
function UIController.GetStatusFrame(): Frame
	return statusFrame
end

-- The whole bottom-right corner, laid out left to right; the status column (GetStatusFrame) is LayoutOrder 10
function UIController.GetStatusRow(): Frame
	return statusRow
end


-- Returns a token for UIController.Dismiss
function UIController.Notify(message: string, isError: boolean?, duration: number?): number
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.BackgroundColor3 = if isError then UIKit.Colors.Danger else UIKit.Colors.Accent
	toastLabel.TextColor3 = if isError then UIKit.Colors.Text else UIKit.Colors.Ink -- dark on gold
	toastLabel.Visible = true

	task.delay(duration or TOAST_SECONDS, function()
		-- A newer toast replaced this one, leave it showing
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
	return token
end

-- Money toast above the buff badge in the bottom-right corner (sales and other money coming in): a green
-- pill that pops in with a white flash, then fades. Newest sits at the bottom, nearest the cash.
function UIController.NotifySide(message: string)
	sideToastOrder += 1
	-- The pill carries the gradient; the text sits in its own label (a UIGradient would tint the text too)
	local pill = Instance.new("Frame")
	pill.Name = "MoneyToast"
	pill.LayoutOrder = sideToastOrder
	pill.Size = UDim2.fromOffset(0, SIDE_TOAST_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1) -- coloured by the gradient
	pill.Parent = sideToasts
	UIKit.corner(pill, SIDE_TOAST_HEIGHT / 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = pill
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(SIDE_TOAST_LIGHT, SIDE_TOAST_DARK)
	gradient.Rotation = 90
	gradient.Parent = pill
	local label = UIKit.label(pill, `💰 {message}`, Enum.Font.FredokaOne, 19, Color3.new(1, 1, 1))
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.TextStrokeColor3 = SIDE_TOAST_OUTLINE
	label.TextStrokeTransparency = 0
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = pill
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = pill
	-- Pop in, and the bright outline settles to a thin one
	TweenService:Create(scale, SIDE_POP, { Scale = 1 }):Play()
	TweenService:Create(stroke, SIDE_SETTLE, { Thickness = 1.5, Transparency = 0.3 }):Play()

	-- Too many at once: drop the oldest
	local shown = {}
	for _, child in sideToasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local max = if UserInputService.TouchEnabled then SIDE_TOAST_MAX_TOUCH else SIDE_TOAST_MAX
	for index = 1, #shown - max do
		shown[index]:Destroy()
	end

	task.delay(SIDE_TOAST_SECONDS, function()
		if not pill.Parent then
			return
		end
		TweenService:Create(pill, SIDE_FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, SIDE_FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(stroke, SIDE_FADE, { Transparency = 1 }):Play()
		TweenService:Create(scale, SIDE_FADE, { Scale = 0.8 }):Play()
		task.delay(SIDE_FADE.Time, function()
			pill:Destroy()
		end)
	end)
end

-- Hides a toast early (e.g. a hint once it's been followed); does nothing if a newer toast replaced it
function UIController.Dismiss(token: number)
	if toastToken == token then
		toastLabel.Visible = false
	end
end

-- Several level-ups can arrive at once; show them one after another instead of overwriting
local levelUpQueue: { number } = {}
local showingLevelUps = false

local function showLevelUps()
	showingLevelUps = true
	while #levelUpQueue > 0 do
		local level = table.remove(levelUpQueue, 1) :: number
		local unlocks = LevelRules.getUnlocks(level)
		local message = if #unlocks > 0
			then `Level {level}! Unlocked: {table.concat(unlocks, ", ")}`
			else `Level {level}!`
		UIController.Notify(message, false, LEVEL_UP_TOAST_SECONDS)
		task.wait(LEVEL_UP_TOAST_SECONDS)
	end
	showingLevelUps = false
end

local function queueLevelUp(level: number)
	table.insert(levelUpQueue, level)
	if not showingLevelUps then
		task.spawn(showLevelUps)
	end
end

-- A dark rounded pill whose icon (Config/UIIcons) sits over its left end, a little bigger than the pill.
-- Its contents go in a row after the icon's space; returns the pill and that row.
local function makePill(parent: Instance, order: number, icon: string): (Frame, Frame)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = PILL_COLOR
	pill.BackgroundTransparency = 0.1
	pill.Parent = parent
	UIKit.corner(pill, PILL_HEIGHT / 2)
	UIKit.outline(pill, UIKit.Colors.Outline, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, ICON_SIZE - 4)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	-- The icon lives in a zero-size anchor so the row ignores it, then sits over the pill's left end
	local anchor = Instance.new("Frame")
	anchor.Name = "IconAnchor"
	anchor.LayoutOrder = 0
	anchor.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	anchor.BackgroundTransparency = 1
	anchor.Parent = pill
	local holder = Icon.make(anchor, icon, UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, -(ICON_SIZE + 2), 0.5, 0)
	return pill, anchor
end

local function addValue(pill: Frame, color: Color3): TextLabel
	local value = UIKit.label(pill, "", Enum.Font.FredokaOne, 22, color)
	value.LayoutOrder = 2
	value.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.TextWrapped = false
	return value
end

-- The status pills in the corner column: cash (a green candy pill with outlined white text) and the level (its
-- number on the star icon, the XP bar inside the pill) at the bottom, in line with the party bar
local function buildStatusPills()
	local column = statusFrame

	cashPill = makePill(column, 2, "Cash")
	cashPill.Name = "Cash"
	cashPill.BackgroundColor3 = UIStyle.GREEN
	cashPill.BackgroundTransparency = 0
	local edge = cashPill:FindFirstChildOfClass("UIStroke") :: UIStroke
	edge.Color = UIStyle.EDGE
	edge.Thickness = UIStyle.EDGE_THICKNESS
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shade.Parent = cashPill
	cashLabel = addValue(cashPill, Color3.new(1, 1, 1))
	UIKit.outlined(cashLabel, 2)

	-- The level number sits on the star icon; the XP bar fills the pill
	local levelAnchor
	levelBadge, levelAnchor = makePill(column, 4, "Level")
	levelBadge.Name = "Level"
	levelLabel = UIKit.label(levelAnchor:FindFirstChild("Icon") :: Frame, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	levelLabel.Size = UDim2.fromScale(1, 0.9)
	levelLabel.Position = UDim2.fromScale(0, 0.08)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.ZIndex = 3
	local levelEdge = Instance.new("UIStroke")
	levelEdge.Color = Color3.fromRGB(120, 70, 0)
	levelEdge.Thickness = 2
	levelEdge.Parent = levelLabel
	local xpBar = Instance.new("Frame")
	xpBar.Name = "XP"
	xpBar.LayoutOrder = 2
	xpBar.Size = UDim2.fromOffset(XP_BAR_WIDTH, 22)
	xpBar.BackgroundColor3 = Color3.fromRGB(42, 48, 66)
	xpBar.ClipsDescendants = true
	xpBar.Parent = levelBadge
	UIKit.corner(xpBar, 11)
	xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.BackgroundColor3 = XP_FILL_COLOR
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpBar
	UIKit.corner(xpFill, 11)
	xpLabel = UIKit.label(xpBar, "", Enum.Font.FredokaOne, 13, Color3.new(1, 1, 1))
	xpLabel.Position = UDim2.fromScale(0.05, 0.12)
	xpLabel.Size = UDim2.fromScale(0.9, 0.76)
	xpLabel.TextScaled = true
	xpLabel.TextXAlignment = Enum.TextXAlignment.Center
	xpLabel.ZIndex = 2
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 14
	fit.Parent = xpLabel
end

-- The bottom-right corner (PC). On a narrow window the party bar would reach over the bottom-centre tiles (Cards,
-- Bag ...): then the corner lifts above the tile row. The money toasts stay just above it. On touch screens the
-- corner is a column from the top right instead, the toasts under it.
local function placeStatusRow(rowLayout: UIListLayout)
	if UserInputService.TouchEnabled then
		statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 0, TOUCH_TOP)
		if sideToasts then
			sideToasts.Position = UDim2.new(1, -STATUS_MARGIN, 0, TOUCH_TOP + rowLayout.AbsoluteContentSize.Y + 6)
		end
		return
	end
	local bottom = STATUS_MARGIN
	local width = screenGui.AbsoluteSize.X
	local tiles = screenGui:FindFirstChild("HudBottom")
	local tilesRight = width / 2 + (if tiles and tiles:IsA("GuiObject") then tiles.AbsoluteSize.X / 2 else 0)
	local rowLeft = width - STATUS_MARGIN - rowLayout.AbsoluteContentSize.X
	local scale = Hud.scaleFor()
	if rowLeft < tilesRight + STATUS_MARGIN then
		bottom = math.max(bottom, HudLayout.BOTTOM_MARGIN + HudLayout.TILE_SIZE.Y * scale + PILL_GAP)
	end
	statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 1, -bottom)
	if sideToasts then
		sideToasts.Position = UDim2.new(1, -STATUS_MARGIN, 1, -(bottom + STATUS_HEIGHT * scale + 6)) -- just above the buff badge
	end
end

function UIController.Start()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainGui"
	screenGui.ResetOnSpawn = false
	-- Children always draw above their parent; ZIndex only orders panels against each other.
	-- (The code default is Global, where a raised panel would cover its own contents.)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
	Hud.mount(screenGui)

	-- A row (party bar, then the column of buff, cash and XP) so the corner stays short on landscape phones
	statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.AnchorPoint = Vector2.new(1, 1)
	statusRow.Size = UDim2.fromOffset(STATUS_ROW_WIDTH, STATUS_HEIGHT)
	statusRow.BackgroundTransparency = 1
	statusRow.Parent = screenGui
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = statusRow
	local touch = UserInputService.TouchEnabled
	if touch then
		-- One column down the right edge from the top (placeStatusRow)
		statusRow.AnchorPoint = Vector2.new(1, 0)
		statusRow.Size = UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT + 8 + TOUCH_PARTY_HEIGHT)
		rowLayout.FillDirection = Enum.FillDirection.Vertical
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	Hud.scaleWith(statusRow)
	local function place()
		placeStatusRow(rowLayout)
	end
	place()
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(place)
	local tiles = screenGui:FindFirstChild("HudBottom")
	if tiles and tiles:IsA("GuiObject") then
		tiles:GetPropertyChangedSignal("AbsoluteSize"):Connect(place) -- context tiles (Drop, Rip) widen the row
	end

	statusFrame = Instance.new("Frame")
	statusFrame.Name = "Status"
	statusFrame.LayoutOrder = if touch then -1 else 10 -- above the party bar on touch screens, right of it on PC
	statusFrame.Size = if touch then UDim2.fromOffset(STATUS_WIDTH, 0) else UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT)
	statusFrame.AutomaticSize = if touch then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = statusRow
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.Padding = UDim.new(0, PILL_GAP)
	statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statusLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.Parent = statusFrame

	buildStatusPills()

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	-- Above the bottom HUD row
	toastLabel.Position = UDim2.new(0.5, 0, 1, -(HudLayout.BOTTOM_MARGIN + HudLayout.TILE_SIZE.Y + 16))
	toastLabel.Size = UDim2.new(0.9, 0, 0, 52)
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.TextSize = 20
	toastLabel.TextWrapped = true
	toastLabel.Visible = false
	toastLabel.ZIndex = 10
	toastLabel.Parent = screenGui
	UIKit.corner(toastLabel, 12)

	sideToasts = Instance.new("Frame")
	sideToasts.Name = "SideToasts"
	sideToasts.AnchorPoint = if UserInputService.TouchEnabled then Vector2.new(1, 0) else Vector2.new(1, 1)
	sideToasts.Size = UDim2.fromOffset(320, SIDE_TOAST_MAX * (SIDE_TOAST_HEIGHT + 6))
	Hud.scaleWith(sideToasts)
	sideToasts.BackgroundTransparency = 1
	sideToasts.Parent = screenGui
	place()
	-- Full-screen views (the binder) cover this corner with their own panels
	Hud.hideWith(statusRow)
	Hud.hideWith(sideToasts)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	sideLayout.VerticalAlignment = if UserInputService.TouchEnabled then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sideToasts

	local toastSize = Instance.new("UISizeConstraint")
	toastSize.MaxSize = Vector2.new(480, math.huge)
	toastSize.Parent = toastLabel

	updateCash()
	updateXp()
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	player:GetAttributeChangedSignal("XP"):Connect(updateXp)
	player:GetAttributeChangedSignal("Level"):Connect(updateXp)
	Remotes.Notify.OnClientEvent:Connect(function(message: string, isError: boolean?, style: string?)
		if typeof(message) ~= "string" then
			return
		end
		if style == "side" then
			UIController.NotifySide(message)
		else
			UIController.Notify(message, isError == true)
		end
	end)
	Remotes.LevelUp.OnClientEvent:Connect(queueLevelUp)
end

return UIController
