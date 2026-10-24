--!strict
-- Small helpers for building the game's UI in code, so every panel looks the same.
-- Style: bright and clean (light-blue panels, white cards, a blue gradient header, chunky buttons with a
-- darker bottom lip, a red close button). Colours live in UIKit.Colors.
-- Text colour picks itself: buttons get white text on dark colours and navy on light ones, and labels
-- made with Colors.Text / Colors.Subtext turn navy when the surface behind them is light.
-- Sizes follow mobile-first rules: tap targets at least 48px.
local GuiService = game:GetService("GuiService")

local Motion = require((script.Parent :: Instance):WaitForChild("Motion"))

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(212, 225, 248), -- panel body (light blue)
	Row = Color3.fromRGB(255, 255, 255), -- cards and rows on a panel; secondary buttons
	Accent = Color3.fromRGB(88, 101, 242), -- primary buttons, selected tabs (blue-violet)
	Success = Color3.fromRGB(46, 180, 95),
	Danger = Color3.fromRGB(232, 64, 76),
	Locked = Color3.fromRGB(160, 170, 192),
	Text = Color3.fromRGB(255, 255, 255), -- text on dark or coloured surfaces (navy on light ones, see label)
	Subtext = Color3.fromRGB(205, 210, 230),
	Ink = Color3.fromRGB(28, 38, 82), -- text on light surfaces
	InkSoft = Color3.fromRGB(88, 102, 145),
	Outline = Color3.fromRGB(176, 196, 236), -- thin borders on light cards
	HeaderTop = Color3.fromRGB(70, 140, 255),
	HeaderBottom = Color3.fromRGB(28, 78, 232),
}

UIKit.PANEL_Z_INDEX = 4 -- panels draw over the HUD; a panel opened from another one (card picker) goes higher
UIKit.HEADER_HEIGHT = 60

local LIGHT_LUMINANCE = 0.62 -- surfaces brighter than this get navy text
local LIP_SHADE = 0.68 -- the bottom lip of a button, this much of its colour
local LIP_START = 0.84 -- where the lip begins, from the top of the button

-- Roblox's on-screen thumbstick and jump button sit over panel buttons on phones (the binder's
-- page arrows, Back buttons), so they are hidden while any panel is open
local openPanels: { [Frame]: boolean } = {}

local function updateTouchControls()
	GuiService.TouchControlsEnabled = next(openPanels) == nil
end

-- Main windows (UIKit.panel) open one at a time: showing one closes the others, so they never pile up.
-- A panel with the "Overlay" attribute opens over another (the Rarity guide over the binder) and closes nothing.
local mainPanels: { [Frame]: boolean } = {}

local function closeOthers(frame: Frame)
	if frame:GetAttribute("Overlay") then
		return
	end
	for other in mainPanels do
		if other ~= frame and other.Visible and not other:GetAttribute("Overlay") then
			other.Visible = false
		end
	end
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

-- Hides the thumbstick and jump button while this frame is visible (the fight bar uses it too)
UIKit.hideTouchControlsWhileVisible = trackPanel

local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

function UIKit.isLight(color: Color3): boolean
	return luminance(color) > LIGHT_LUMINANCE
end

-- The first ancestor that actually paints a background (or nil over the 3D world)
local function surfaceBehind(instance: Instance): GuiObject?
	local current: Instance? = instance
	while current do
		if current:IsA("GuiObject") and current.BackgroundTransparency < 0.5 then
			return current
		end
		if current:IsA("LayerCollector") then
			return nil
		end
		current = current.Parent
	end
	return nil
end

-- White or navy, whichever reads on what's behind this instance
function UIKit.textColorFor(instance: Instance, soft: boolean?): Color3
	local surface = surfaceBehind(instance)
	if surface and UIKit.isLight(surface.BackgroundColor3) then
		return if soft then UIKit.Colors.InkSoft else UIKit.Colors.Ink
	end
	return if soft then UIKit.Colors.Subtext else UIKit.Colors.Text
end

function UIKit.corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function UIKit.outline(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or UIKit.Colors.Outline
	stroke.Thickness = thickness or 2
	stroke.Parent = parent
	return stroke
end

-- Colors.Text / Colors.Subtext turn navy on a light surface; any other colour is kept as given
function UIKit.label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	local auto = color == UIKit.Colors.Text or color == UIKit.Colors.Subtext
	if not auto then
		label.TextColor3 = color
		return label
	end
	-- Re-picked when the label moves (tiles built on a panel, then placed on a page) or its own background
	-- changes, unless the caller has set a colour of their own
	local soft = color == UIKit.Colors.Subtext
	local picked: Color3? = nil
	local function pick()
		if picked ~= nil and label.TextColor3 ~= picked then
			return
		end
		picked = UIKit.textColorFor(label, soft)
		label.TextColor3 = picked
	end
	pick()
	label.AncestryChanged:Connect(pick)
	label:GetPropertyChangedSignal("BackgroundColor3"):Connect(pick)
	label:GetPropertyChangedSignal("BackgroundTransparency"):Connect(pick)
	return label
end

-- A chunky button: its colour with a darker lip along the bottom (a gradient, so it follows colour changes),
-- and white or navy text to suit the colour. Text set by hand stays as set.
function UIKit.button(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.Text = text
	button.Parent = parent
	UIKit.corner(button, 12)
	Motion.press(button)

	local lip = Instance.new("UIGradient")
	lip.Name = "Lip"
	lip.Rotation = 90
	lip.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(LIP_START, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(LIP_START + 0.001, Color3.new(LIP_SHADE, LIP_SHADE, LIP_SHADE)),
		ColorSequenceKeypoint.new(1, Color3.new(LIP_SHADE, LIP_SHADE, LIP_SHADE)),
	})
	lip.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 4) -- keep the text on the face, above the lip
	padding.Parent = button

	local edge = UIKit.outline(button, nil, 1.5)
	local autoText: Color3? = nil -- the text colour this button last picked for itself
	local function restyle()
		local light = UIKit.isLight(button.BackgroundColor3)
		edge.Color = if light then UIKit.Colors.Outline else button.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.35)
		local pick = if light then UIKit.Colors.Ink else UIKit.Colors.Text
		if autoText == nil or button.TextColor3 == autoText then
			button.TextColor3 = pick
		end
		autoText = pick
	end
	restyle()
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(restyle)
	return button
end

-- The red close button that sits on a panel's top-right corner
function UIKit.closeButton(parent: GuiObject): TextButton
	local close = UIKit.button(parent, "X", UIKit.Colors.Danger)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 8, 0, -8)
	close.Size = UDim2.fromOffset(52, 52)
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 26
	close.ZIndex = parent.ZIndex + 3
	local ring = close:FindFirstChildWhichIsA("UIStroke")
	if ring then
		ring.Color = Color3.new(1, 1, 1)
		ring.Thickness = 3
	end
	return close
end

-- The blue gradient strip across the top of a panel, with the title in it
function UIKit.header(parent: GuiObject, title: string): (Frame, TextLabel)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, UIKit.HEADER_HEIGHT)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = parent.ZIndex
	header.Parent = parent
	UIKit.corner(header, 14)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(UIKit.Colors.HeaderTop, UIKit.Colors.HeaderBottom)
	gradient.Parent = header
	-- Square off the header's bottom corners where it meets the body
	local squareBottom = Instance.new("Frame")
	squareBottom.Name = "SquareBottom"
	squareBottom.AnchorPoint = Vector2.new(0, 1)
	squareBottom.Position = UDim2.fromScale(0, 1)
	squareBottom.Size = UDim2.new(1, 0, 0, 14)
	squareBottom.BackgroundColor3 = Color3.new(1, 1, 1)
	squareBottom.BorderSizePixel = 0
	squareBottom.ZIndex = header.ZIndex
	squareBottom.Parent = header
	local bottomGradient = gradient:Clone()
	bottomGradient.Color = ColorSequence.new(UIKit.Colors.HeaderBottom)
	bottomGradient.Parent = squareBottom

	local titleLabel = UIKit.label(header, title, Enum.Font.FredokaOne, 28, UIKit.Colors.Text)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(18, 0)
	titleLabel.Size = UDim2.new(1, -90, 1, 0)
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.75
	titleLabel.ZIndex = header.ZIndex + 1
	return header, titleLabel
end

-- Closes a panel with a quick shrink (a panel shown again meanwhile stays open)
function UIKit.closePanel(frame: GuiObject)
	if not frame.Visible then
		return
	end
	Motion.popOut(frame, function()
		frame.Visible = false
	end)
end

-- Centred modal panel: blue header with the title, red close button, light body with a scrolling list.
-- Starts hidden. The title label is named "Title" (inside the header) for callers that change it.
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
	UIKit.corner(frame, 16)
	UIKit.outline(frame, Color3.new(1, 1, 1), 3)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 520)
	sizeLimit.Parent = frame

	local _, titleLabel = UIKit.header(frame, title)
	titleLabel.Parent = frame -- callers find it as frame.Title; it still sits over the header
	titleLabel.Position = UDim2.fromOffset(18, 0)
	titleLabel.Size = UDim2.new(1, -90, 0, UIKit.HEADER_HEIGHT)
	titleLabel.ZIndex = frame.ZIndex + 2

	local close = UIKit.closeButton(frame)
	close.Activated:Connect(function()
		UIKit.closePanel(frame)
	end)
	-- Pops in whenever it's shown; hidden straight away (by code) it just resets
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			Motion.popIn(frame)
		else
			Motion.reset(frame)
		end
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + 12)
	list.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + 24))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UIKit.Colors.Accent
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	mainPanels[frame] = true
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			closeOthers(frame)
		end
	end)
	frame.Destroying:Connect(function()
		mainPanels[frame] = nil
	end)
	trackPanel(frame)
	return frame, list
end

-- List row: a white card with a title and detail line, plus an action button on the right
function UIKit.row(parent: Instance, order: number, title: string, detail: string): (Frame, TextButton, TextLabel)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 76)
	frame.BackgroundColor3 = UIKit.Colors.Row
	frame.Parent = parent
	UIKit.corner(frame, 12)
	UIKit.outline(frame)

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
