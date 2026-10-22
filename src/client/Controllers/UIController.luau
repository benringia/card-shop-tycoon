--!strict
-- Owns the main ScreenGui: the status corner (cash, shop level / XP bar, buffs) and short toast messages.
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
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))

local TOAST_SECONDS = 2.5
local LEVEL_UP_TOAST_SECONDS = 5
local XP_FILL_COLOR = Color3.fromRGB(90, 160, 255)
local TOP_PILL_COLOR = Color3.fromRGB(20, 28, 60)
local TOP_PILL_HEIGHT = 44
local CASH_COLOR = Color3.fromRGB(130, 235, 140)
local SHARD_COLOR = Color3.fromRGB(205, 175, 255)
local XP_PILL_WIDTH = 200
-- Status sits in the bottom-right corner (the top corners hold Roblox's menu and the player list).
-- On touch screens it sits above the jump button.
local STATUS_MARGIN = 12
local TOUCH_JUMP_CLEARANCE = 130
-- Fixed sizes, not AutomaticSize: an auto-sized frame anchored to the right edge can lay out past the screen edge
local STATUS_WIDTH = 180
local STATUS_HEIGHT = 130 -- buff badge 48 + cash 44 + XP 26 + gaps
local STATUS_ROW_WIDTH = 420 -- party bar + gap + status column; spare width is empty and lets clicks through
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
local shardsLabel: TextLabel
local cashPill: Frame
local levelBadge: Frame
local shardsPill: Frame
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

-- Bottom-right column: items stack upwards, right-aligned. Cash is LayoutOrder 2, XP 3; lower orders go above.
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

-- A dark rounded pill with an icon and a value (the top bar's cash and shards)
local function makePill(parent: Instance, order: number, icon: string, color: Color3): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(0, TOP_PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = TOP_PILL_COLOR
	pill.BackgroundTransparency = 0.1
	pill.Parent = parent
	UIKit.corner(pill, TOP_PILL_HEIGHT / 2)
	UIKit.outline(pill, Color3.fromRGB(60, 80, 140), 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	local iconLabel = UIKit.label(pill, icon, Enum.Font.FredokaOne, 24, Color3.new(1, 1, 1))
	iconLabel.LayoutOrder = 1
	iconLabel.Size = UDim2.fromOffset(28, TOP_PILL_HEIGHT)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	local value = UIKit.label(pill, "", Enum.Font.FredokaOne, 22, color)
	value.LayoutOrder = 2
	value.Size = UDim2.fromOffset(0, TOP_PILL_HEIGHT)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.TextWrapped = false
	return pill, value
end

-- Top centre: cash pill, level badge, Star Shards pill; the XP pill under them
local function buildTopBar()
	local top = Hud.getTop()
	local bar = Instance.new("Frame")
	bar.Name = "Pills"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(0, TOP_PILL_HEIGHT + 8)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.Parent = top
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = bar
	local column = Instance.new("UIListLayout")
	column.HorizontalAlignment = Enum.HorizontalAlignment.Center
	column.Padding = UDim.new(0, 4)
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.Parent = top

	cashPill, cashLabel = makePill(bar, 1, "💵", CASH_COLOR)
	cashPill.Name = "Cash"

	levelBadge = Instance.new("Frame")
	levelBadge.Name = "Level"
	levelBadge.LayoutOrder = 2
	levelBadge.Size = UDim2.fromOffset(TOP_PILL_HEIGHT + 8, TOP_PILL_HEIGHT + 8)
	levelBadge.BackgroundColor3 = HudLayout.TILE
	levelBadge.Parent = bar
	UIKit.corner(levelBadge, (TOP_PILL_HEIGHT + 8) / 2)
	UIKit.outline(levelBadge, Color3.new(1, 1, 1), 3)
	levelLabel = UIKit.label(levelBadge, "", Enum.Font.FredokaOne, 22, Color3.new(1, 1, 1))
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center

	shardsPill, shardsLabel = makePill(bar, 3, "✨", SHARD_COLOR)
	shardsPill.Name = "Shards"
	shardsLabel.Text = "0"

	-- XP to the next level, small, under the pills
	local xpPill = Instance.new("Frame")
	xpPill.Name = "XP"
	xpPill.LayoutOrder = 2
	xpPill.Size = UDim2.fromOffset(XP_PILL_WIDTH, 24)
	xpPill.BackgroundColor3 = TOP_PILL_COLOR
	xpPill.BackgroundTransparency = 0.1
	xpPill.ClipsDescendants = true
	xpPill.Parent = top
	UIKit.corner(xpPill, 12)
	xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.BackgroundColor3 = XP_FILL_COLOR
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpPill
	UIKit.corner(xpFill, 12)
	xpLabel = UIKit.label(xpPill, "", Enum.Font.GothamBold, 13, Color3.new(1, 1, 1))
	xpLabel.Size = UDim2.fromScale(1, 1)
	xpLabel.TextXAlignment = Enum.TextXAlignment.Center
	xpLabel.ZIndex = 2
end

local function updateShards(items: unknown)
	local count = if typeof(items) == "table" then (items :: { [string]: any }).starShard else nil
	local text = tostring(if typeof(count) == "number" then count else 0)
	if shardsLabel.Text ~= text then
		Motion.bump(shardsPill)
	end
	shardsLabel.Text = text
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
	local bottom = STATUS_MARGIN + (if UserInputService.TouchEnabled then TOUCH_JUMP_CLEARANCE else 0)
	statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 1, -bottom)
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

	statusFrame = Instance.new("Frame")
	statusFrame.Name = "Status"
	statusFrame.LayoutOrder = 10
	statusFrame.Size = UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT)
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = statusRow
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.Padding = UDim.new(0, 4)
	statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statusLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.Parent = statusFrame

	buildTopBar()

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
	sideToasts.AnchorPoint = Vector2.new(1, 1)
	sideToasts.Position = UDim2.new(1, -STATUS_MARGIN, 1, -(bottom + STATUS_HEIGHT + 6)) -- just above the buff badge
	sideToasts.Size = UDim2.fromOffset(320, SIDE_TOAST_MAX * (SIDE_TOAST_HEIGHT + 6))
	sideToasts.BackgroundTransparency = 1
	sideToasts.Parent = screenGui
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	sideLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
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
	Remotes.ItemsChanged.OnClientEvent:Connect(updateShards)
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
