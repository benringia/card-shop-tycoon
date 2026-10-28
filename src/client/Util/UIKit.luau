--!strict
-- Small helpers for building the game's UI in code, so every panel looks the same.
-- Style: look E, "bold hybrid" (Config/UIStyle): dark slate windows with a thick outline and a drop lip, a coloured
-- header band per window, outlined titles and big numbers, candy buttons (a gradient, a thick outline and a darker
-- bottom lip), chunky bars, pills and star rows. Colours live in UIKit.Colors and Config/UIStyle.
-- Text colour picks itself: buttons get white text on dark colours and navy on light ones, and labels
-- made with Colors.Text / Colors.Subtext turn navy when the surface behind them is light.
-- Sizes follow mobile-first rules: tap targets at least 48px.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIStyle"))
local UIIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIIcons"))
local Motion = require((script.Parent :: Instance):WaitForChild("Motion"))
local Icon = require((script.Parent :: Instance):WaitForChild("Icon"))

local UIKit = {}

-- Look E: dark slate windows, gold for the main action, blue for other choices, red for remove / leave
UIKit.Colors = {
	Panel = UIStyle.PANEL, -- panel body (dark slate)
	Row = UIStyle.ROW, -- cards and rows on a panel
	Accent = UIStyle.GOLD, -- primary buttons, selected tabs, highlights
	Secondary = UIStyle.BLUE, -- other choices
	Success = UIStyle.GREEN,
	Danger = UIStyle.RED,
	Locked = Color3.fromRGB(64, 70, 86),
	Text = Color3.fromRGB(244, 241, 233), -- text on dark or coloured surfaces (dark on light ones, see label)
	Subtext = Color3.fromRGB(150, 158, 178),
	Ink = Color3.fromRGB(34, 28, 16), -- text on light surfaces (gold buttons, white pills)
	InkSoft = Color3.fromRGB(110, 100, 80),
	Outline = UIStyle.EDGE, -- outlines on windows, buttons, rows and cards
	HeaderTop = Color3.fromRGB(38, 44, 66),
	HeaderBottom = Color3.fromRGB(26, 30, 46),
}

UIKit.PANEL_Z_INDEX = 4 -- panels draw over the HUD; a panel opened from another one (card picker) goes higher
UIKit.HEADER_HEIGHT = 60

local LIGHT_LUMINANCE = 0.62 -- surfaces brighter than this get navy text
local FACE_SHADE = 0.84 -- a candy button's face darkens to this much of its colour towards the lip
local LIP_SHADE = 0.6 -- the bottom lip of a button, this much of its colour
local LIP_START = 0.84 -- where the lip begins, from the top of the button
local PANEL_CORNER = 16
local ICON_SIZE = 24 -- an icon button's picture

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

-- Whether any UIKit.panel window (or the fight bar) is open
function UIKit.anyPanelOpen(): boolean
	return next(openPanels) ~= nil
end

-- World hovers and taps (shelf tooltips, price tags) stay off while a window is open or the pointer is over
-- visible UI. screen is a viewport point, like UserInputService:GetMouseLocation().
function UIKit.pointerBlocked(screen: Vector2): boolean
	if next(openPanels) ~= nil then
		return true
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local inset = GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(screen.X, screen.Y - inset.Y) do
		local drawn = object.BackgroundTransparency < 1
			or (object:IsA("ImageLabel") or object:IsA("ImageButton")) and object.ImageTransparency < 1 and object.Image ~= ""
			or object:IsA("TextButton")
		if drawn and object.Visible then
			return true
		end
	end
	return false
end

UIKit.PHONE_HEIGHT = 500 -- a screen this short (landscape phones) gets the compact layouts

-- A phone-sized screen: touch only, or a short screen (the Device emulator's phones too)
function UIKit.isPhone(): boolean
	local camera = workspace.CurrentCamera
	local short = camera ~= nil and camera.ViewportSize.Y < UIKit.PHONE_HEIGHT
	return short or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
end

-- Where a tooltip goes by the cursor (screen: a viewport point, like GetMouseLocation): below and right of it,
-- flipped to the left or above when it would leave the screen (small phones, the screen's edges). For a tooltip on
-- a ScreenGui that starts below Roblox's top bar.
local TIP_GAP = Vector2.new(16, 12)
function UIKit.cursorTipPosition(tip: GuiObject, screen: Vector2): UDim2
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(math.huge, math.huge)
	local inset = GuiService:GetGuiInset()
	local size = tip.AbsoluteSize
	local x = screen.X + TIP_GAP.X
	if x + size.X > view.X then
		x = screen.X - TIP_GAP.X - size.X
	end
	local y = screen.Y + TIP_GAP.Y
	if y + size.Y > view.Y then
		y = screen.Y - TIP_GAP.Y - size.Y
	end
	return UDim2.fromOffset(math.max(x, 0), math.max(y, inset.Y) - inset.Y)
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

-- Outlines text (a TextLabel's or a button's) in the kit's dark edge colour
function UIKit.outlined(text: TextLabel | TextButton, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = UIStyle.EDGE
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = text
	return stroke
end

-- A text size from Config/UIStyle (body, small, name, number, title), smaller on phones
function UIKit.textSize(kind: "body" | "small" | "name" | "number" | "title"): number
	local size = UIStyle.TEXT[kind]
	return if UIKit.isPhone() then math.floor(size * UIStyle.PHONE_TEXT_SCALE) else size
end

-- A candy button: its colour darkening down the face to a darker lip along the bottom (a gradient, so it follows
-- colour changes), a thick dark outline, and outlined white text (navy on light colours). Text set by hand stays as set.
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
		ColorSequenceKeypoint.new(LIP_START, Color3.new(FACE_SHADE, FACE_SHADE, FACE_SHADE)),
		ColorSequenceKeypoint.new(LIP_START + 0.001, Color3.new(LIP_SHADE, LIP_SHADE, LIP_SHADE)),
		ColorSequenceKeypoint.new(1, Color3.new(LIP_SHADE, LIP_SHADE, LIP_SHADE)),
	})
	lip.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 4) -- keep the text on the face, above the lip
	padding.Parent = button

	UIKit.outline(button, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local textEdge = UIKit.outlined(button)
	local autoText: Color3? = nil -- the text colour this button last picked for itself
	local function restyle()
		local light = UIKit.isLight(button.BackgroundColor3)
		local pick = if light then UIKit.Colors.Ink else Color3.new(1, 1, 1)
		if autoText == nil or button.TextColor3 == autoText then
			button.TextColor3 = pick
		end
		autoText = pick
	end
	-- Light text (white on a dark colour) gets the dark outline; navy text on a light colour doesn't
	local function outlineText()
		textEdge.Enabled = UIKit.isLight(button.TextColor3)
	end
	restyle()
	outlineText()
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(restyle)
	button:GetPropertyChangedSignal("TextColor3"):Connect(outlineText)
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
	return close
end

-- The coloured band across the top of a panel (Config/UIStyle HEADERS: Party, Cards, Bosses, Bag, Default), with
-- the outlined title in it and a dark line under it
function UIKit.header(parent: GuiObject, title: string, band: string?): (Frame, TextLabel)
	local colors = UIStyle.HEADERS[band or "Default"] or UIStyle.HEADERS.Default
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, UIKit.HEADER_HEIGHT)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = parent.ZIndex
	header.Parent = parent
	UIKit.corner(header, PANEL_CORNER - 2)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(colors.top, colors.bottom)
	gradient.Parent = header
	-- Square off the header's bottom corners where it meets the body
	local squareBottom = Instance.new("Frame")
	squareBottom.Name = "SquareBottom"
	squareBottom.AnchorPoint = Vector2.new(0, 1)
	squareBottom.Position = UDim2.fromScale(0, 1)
	squareBottom.Size = UDim2.new(1, 0, 0, PANEL_CORNER)
	squareBottom.BackgroundColor3 = Color3.new(1, 1, 1)
	squareBottom.BorderSizePixel = 0
	squareBottom.ZIndex = header.ZIndex
	squareBottom.Parent = header
	local bottomGradient = gradient:Clone()
	bottomGradient.Color = ColorSequence.new(colors.bottom)
	bottomGradient.Parent = squareBottom
	-- A dark line where the band meets the body
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	rule.Size = UDim2.new(1, 0, 0, UIStyle.EDGE_THICKNESS)
	rule.BackgroundColor3 = UIStyle.EDGE
	rule.BorderSizePixel = 0
	rule.ZIndex = header.ZIndex + 1
	rule.Parent = header

	local titleLabel = UIKit.label(header, title, Enum.Font.FredokaOne, UIKit.textSize("title"), UIKit.Colors.Text)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(18, 0)
	titleLabel.Size = UDim2.new(1, -90, 1, 0)
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	UIKit.outlined(titleLabel, 2.5)
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

-- Centred modal panel: a coloured header band (`band`: a Config/UIStyle HEADERS name) with the title, red close
-- button, dark body with a scrolling list. The frame itself is the dark edge colour and a "Body" child paints the
-- slate face LIP pixels short of the bottom, so the edge shows there as a drop lip under a thick outline.
-- Starts hidden. The title label is named "Title" (inside the header) for callers that change it.
function UIKit.panel(parent: Instance, name: string, title: string, band: string?): (Frame, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.7)
	frame.BackgroundColor3 = UIStyle.EDGE
	frame.Visible = false
	frame.ZIndex = UIKit.PANEL_Z_INDEX -- over the HUD buttons, which stay at the default 1
	frame.Parent = parent
	UIKit.corner(frame, PANEL_CORNER)
	local edge = UIKit.outline(frame, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -UIStyle.LIP)
	body.BackgroundColor3 = UIKit.Colors.Panel
	body.BorderSizePixel = 0
	body.ZIndex = 0 -- under every other child (Sibling ZIndexBehavior)
	body.Parent = frame
	UIKit.corner(body, PANEL_CORNER)
	-- A see-through panel (the binder: its book is its own screen) shows neither face nor edge
	frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		body.BackgroundTransparency = frame.BackgroundTransparency
		edge.Enabled = frame.BackgroundTransparency < 1
	end)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 520)
	sizeLimit.Parent = frame

	local _, titleLabel = UIKit.header(frame, title, band)
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

-- A candy button with an icon (Config/UIIcons name) before its text; with no text, just the icon, centred.
-- The picture is the "Icon" child (callers may resize it); .Text still works.
function UIKit.iconButton(parent: Instance, text: string, icon: string, color: Color3): TextButton
	local button = UIKit.button(parent, text, color)
	local picture = Icon.make(button, icon, UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.ZIndex = button.ZIndex + 1
	local padding = button:FindFirstChildOfClass("UIPadding") :: UIPadding
	local function place()
		if button.Text == "" then
			padding.PaddingLeft = UDim.new()
			picture.Position = UDim2.fromScale(0.5, 0.5)
		else
			padding.PaddingLeft = UDim.new(0, picture.AbsoluteSize.X + 10)
			picture.Position = UDim2.new(0, -picture.AbsoluteSize.X / 2 - 2, 0.5, 0)
		end
	end
	place()
	button:GetPropertyChangedSignal("Text"):Connect(place)
	picture:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	button:GetPropertyChangedSignal("ZIndex"):Connect(function()
		picture.ZIndex = button.ZIndex + 1
	end)
	return button
end

-- A rounded chip (rarity, grade, element, counts) that sizes to its text; an optional icon before the text.
-- Text is navy on light fills and outlined white on dark ones unless textColor is given.
function UIKit.pill(parent: Instance, text: string, fill: Color3, textColor: Color3?, icon: string?): TextLabel
	local pill = Instance.new("TextLabel")
	pill.Name = "Pill"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 24)
	pill.BackgroundColor3 = fill
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = UIKit.textSize("small")
	pill.Text = text
	pill.TextColor3 = textColor or (if UIKit.isLight(fill) then UIKit.Colors.Ink else Color3.new(1, 1, 1))
	pill.Parent = parent
	UIKit.corner(pill, 12)
	UIKit.outline(pill, UIStyle.EDGE, 2)
	if not textColor and not UIKit.isLight(fill) then
		UIKit.outlined(pill, 1.5)
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, if icon then 26 else 9)
	padding.PaddingRight = UDim.new(0, 9)
	padding.Parent = pill
	if icon then
		local picture = Icon.make(pill, icon, UDim2.fromOffset(18, 18))
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, -21, 0.5, 0)
		picture.ZIndex = pill.ZIndex + 1
	end
	return pill
end

-- A chunky bar: a dark outlined track with a fill `share` (0-1) of its width, the kit's green by default.
-- Returns the track (size and place it) and the fill (change its Size.X to update).
function UIKit.bar(parent: Instance, share: number, fill: Color3?): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.Size = UDim2.new(1, 0, 0, if UIKit.isPhone() then UIStyle.BAR.phoneHeight else UIStyle.BAR.height)
	track.BackgroundColor3 = UIStyle.EDGE
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	UIKit.corner(track, 999)
	UIKit.outline(track, UIStyle.EDGE, 2)
	local inside = Instance.new("Frame")
	inside.Name = "Fill"
	inside.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	inside.BackgroundColor3 = fill or Color3.new(1, 1, 1)
	inside.BorderSizePixel = 0
	inside.ZIndex = track.ZIndex
	inside.Parent = track
	UIKit.corner(inside, 999)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = if fill
		then ColorSequence.new(Color3.new(1, 1, 1), Color3.new(FACE_SHADE, FACE_SHADE, FACE_SHADE))
		else ColorSequence.new(UIStyle.BAR.fillTop, UIStyle.BAR.fillBottom)
	shade.Parent = inside
	return track, inside
end

-- One stat line: its icon, then a bar `share` full
function UIKit.statRow(parent: Instance, icon: string, share: number): Frame
	local row = Instance.new("Frame")
	row.Name = "StatRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Parent = parent
	local picture = Icon.make(row, icon, UDim2.fromOffset(20, 20))
	picture.ZIndex = row.ZIndex
	local track = UIKit.bar(row, share)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 26, 0.5, 0)
	track.Size = UDim2.new(1, -26, 0, track.Size.Y.Offset)
	return row
end

-- A row of star icons, `lit` of `total` bright, the rest dim
function UIKit.stars(parent: Instance, lit: number, total: number, size: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, size)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 1)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for index = 1, total do
		local star = Instance.new("ImageLabel")
		star.LayoutOrder = index
		star.BackgroundTransparency = 1
		star.Size = UDim2.fromOffset(size, size)
		star.Image = UIIcons.Star
		star.ImageTransparency = if index <= lit then 0 else 0.55
		star.ImageColor3 = if index <= lit then Color3.new(1, 1, 1) else Color3.fromRGB(90, 96, 120)
		star.ZIndex = row.ZIndex
		star.Parent = row
	end
	return row
end

return UIKit
