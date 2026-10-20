--!strict
-- Small helpers for building the game's UI in code, so every panel looks the same.
-- Sizes follow mobile-first rules: tap targets at least 48px.
local GuiService = game:GetService("GuiService")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(30, 30, 42),
	Row = Color3.fromRGB(45, 45, 60),
	Accent = Color3.fromRGB(40, 160, 90),
	Danger = Color3.fromRGB(200, 60, 60),
	Locked = Color3.fromRGB(90, 90, 100),
	Text = Color3.fromRGB(255, 255, 255),
	Subtext = Color3.fromRGB(190, 190, 205),
}

UIKit.PANEL_Z_INDEX = 4 -- panels draw over the HUD; a panel opened from another one (card picker) goes higher

-- Roblox's on-screen thumbstick and jump button sit over panel buttons on phones (the binder's
-- page arrows, Back buttons), so they are hidden while any panel is open
local openPanels: { [Frame]: boolean } = {}

local function updateTouchControls()
	GuiService.TouchControlsEnabled = next(openPanels) == nil
end

local function trackPanel(frame: Frame)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		openPanels[frame] = if frame.Visible then true else nil
		updateTouchControls()
	end)
	frame.Destroying:Connect(function()
		openPanels[frame] = nil
		updateTouchControls()
	end)
end

function UIKit.corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function UIKit.label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

function UIKit.button(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.TextColor3 = UIKit.Colors.Text
	button.Text = text
	button.Parent = parent
	UIKit.corner(button, 10)
	return button
end

-- Centred modal panel with a title, close button and a scrolling list. Starts hidden.
function UIKit.panel(parent: Instance, name: string, title: string): (Frame, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.7)
	frame.BackgroundColor3 = UIKit.Colors.Panel
	frame.Visible = false
	frame.ZIndex = UIKit.PANEL_Z_INDEX -- over the HUD buttons, which stay at the default 1
	frame.Parent = parent
	UIKit.corner(frame, 14)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 520)
	sizeLimit.Parent = frame

	local titleLabel = UIKit.label(frame, title, Enum.Font.FredokaOne, 28, UIKit.Colors.Text)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(16, 10)
	titleLabel.Size = UDim2.new(1, -80, 0, 44)

	local close = UIKit.button(frame, "X", UIKit.Colors.Row)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(48, 48)
	close.TextSize = 22
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 68)
	list.Size = UDim2.new(1, -24, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	trackPanel(frame)
	return frame, list
end

-- List row with a title and detail line, plus an action button on the right
function UIKit.row(parent: Instance, order: number, title: string, detail: string): (Frame, TextButton, TextLabel)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 76)
	frame.BackgroundColor3 = UIKit.Colors.Row
	frame.Parent = parent
	UIKit.corner(frame, 10)

	local titleLabel = UIKit.label(frame, title, Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.Size = UDim2.new(1, -130, 0, 30)

	local detailLabel = UIKit.label(frame, detail, Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	detailLabel.Position = UDim2.fromOffset(12, 40)
	detailLabel.Size = UDim2.new(1, -130, 0, 28)

	local button = UIKit.button(frame, "", UIKit.Colors.Accent)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(104, 52)

	return frame, button, detailLabel
end

return UIKit
