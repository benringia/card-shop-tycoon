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
local BabyColors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BabyColors"))
local SoftColors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("SoftColors"))
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

-- Cream windows (spec 2026-11-03-cream-windows-design): UIKit.panel builds them by default and marks the frame's
-- Theme attribute; the pieces built inside (header, rows, buttons, pills, bars, outlines, auto text) read it
local CREAM = UIStyle.CREAM

export type Palette = {
	panel: Color3, -- the window body
	row: Color3, -- rows, slots, stat cards
	rowEdge: Color3, -- their outline
	slotEmpty: Color3,
	ink: Color3, -- text on the window
	inkSoft: Color3, -- secondary text
	hint: Color3, -- hints and small headings
	good: Color3, -- fast, ready, better
	bad: Color3, -- resting, mistakes, not enough
	power: Color3, -- Power numbers; the "pricey" price band
	fair: Color3, -- the "fair" price band, between good and pricey
	track: Color3, -- bar tracks
	outline: Color3, -- buttons', pills' and chips' outlines
	outlineThickness: number,
}

local DARK_PALETTE: Palette = {
	panel = UIKit.Colors.Panel,
	row = UIKit.Colors.Row,
	rowEdge = UIStyle.EDGE,
	slotEmpty = UIKit.Colors.Row,
	ink = UIKit.Colors.Text,
	inkSoft = UIKit.Colors.Subtext,
	hint = UIStyle.HINT,
	good = UIStyle.GOOD,
	bad = UIStyle.BAD,
	power = UIStyle.POWER,
	fair = UIStyle.HINT,
	track = UIStyle.EDGE,
	outline = UIStyle.EDGE,
	outlineThickness = 2,
}

local CREAM_PALETTE: Palette = {
	panel = CREAM.BODY_BOTTOM,
	row = CREAM.ROW,
	rowEdge = CREAM.ROW_EDGE,
	slotEmpty = CREAM.SLOT_EMPTY,
	ink = CREAM.INK,
	inkSoft = CREAM.INK_SOFT,
	hint = CREAM.HINT,
	good = CREAM.GOOD,
	bad = CREAM.BAD,
	power = CREAM.POWER,
	fair = CREAM.FAIR,
	track = CREAM.TRACK,
	outline = CREAM.OUTLINE,
	outlineThickness = CREAM.BUTTON_OUTLINE,
}

-- The look of the window `instance` sits in: "cream" (UIKit.panel's default) or "dark" (the binder, the fight screens,
-- anything outside a window)
function UIKit.themeOf(instance: Instance): "cream" | "dark"
	local current: Instance? = instance
	while current do
		local theme = current:GetAttribute("Theme")
		if theme == "cream" or theme == "dark" then
			return theme
		end
		if current:IsA("LayerCollector") then
			break
		end
		current = current.Parent
	end
	return "dark"
end

-- The colours for things built inside `instance`'s window (dark windows get today's tokens, unchanged)
function UIKit.colorsFor(instance: Instance): Palette
	return if UIKit.themeOf(instance) == "cream" then CREAM_PALETTE else DARK_PALETTE
end

-- The cotton candy buttons (spec 2026-11-03-cotton-candy-ui-design): soft inside a themed ("cream") window or under
-- anything marked SoftButtons (the binder's screen); everything else (fights, the pack opening) keeps the candy lip
function UIKit.isSoft(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current:GetAttribute("SoftButtons") == true then
			return true
		end
		local theme = current:GetAttribute("Theme")
		if theme == "cream" then
			return true
		elseif theme == "dark" then
			return false
		end
		if current:IsA("LayerCollector") then
			break
		end
		current = current.Parent
	end
	return false
end

local function toRgb(color: Color3): { number }
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local function fromRgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A named kit colour (Colors.Accent, Secondary, Danger, Success, Locked, Row, Panel) to its baby fill
-- (Config/BabyColors ROLES); any other colour is kept
function UIKit.softFill(color: Color3): Color3
	for role, name in BabyColors.ROLES do
		local token = (UIKit.Colors :: any)[role]
		if token == color then
			return UIStyle.BABY[name].fill
		end
	end
	if color == CREAM.ROW or color == CREAM.SLOT_EMPTY then
		return UIStyle.BABY[BabyColors.ROLES.Neutral].fill -- the window's white row or pale slot passed as a fill
	end
	return color
end

-- The soft glow (Config/BabyColors GLOW) round `parent`, whose corners are `corner` px round: `color`, dropped `drop` px,
-- `transparency` see-through. Drawn over the parent, but its middle is clear, so only the glow outside shows.
function UIKit.glow(parent: GuiObject, color: Color3, corner: number, drop: number, transparency: number): ImageLabel
	local look = BabyColors.GLOW
	local scale = math.max(corner, 1) / look.corner
	local spread = look.margin * scale
	local inset = look.margin + look.corner
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = look.image
	glow.ImageColor3 = color
	glow.ImageTransparency = transparency
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(inset, inset, look.size - inset, look.size - inset)
	glow.SliceScale = scale
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0.5, drop)
	glow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
	glow.ZIndex = 0
	glow:SetAttribute("Drop", drop)
	glow.Parent = parent
	return glow
end

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
-- A panel with a view inside it (the binder's card view): its X closes that view first. Returns true if it did.
local backSteps: { [Frame]: () -> boolean } = {}

function UIKit.setBackStep(frame: Frame, step: () -> boolean)
	backSteps[frame] = step
end

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
		if UIKit.themeOf(instance) == "cream" then
			return if soft then CREAM.INK_SOFT else CREAM.INK
		end
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
	stroke.Color = color or UIKit.colorsFor(parent).rowEdge -- dark windows: Colors.Outline; cream: the soft cream edge
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
-- A label drawn on a soft button's colour (a tab's name) takes the same text as the button would: plum on light fills,
-- white with a soft deep outline on bright ones. The outline is the label's "SoftEdge" stroke, made the first time.
function UIKit.softText(label: TextLabel, fill: Color3)
	local look = BabyColors.SOFT_BUTTON.textOutline
	local rgb = toRgb(UIKit.softFill(fill))
	local edge = label:FindFirstChild("SoftEdge") :: UIStroke?
	if not edge then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "SoftEdge"
		stroke.Thickness = look.thickness
		stroke.Transparency = look.transparency
		stroke.Parent = label
		edge = stroke
	end
	local light = SoftColors.textOn(rgb, BabyColors.LIGHT_LUMA) == "ink"
	label.TextColor3 = if light then UIStyle.BABY_INK else Color3.new(1, 1, 1)
	local stroke = edge :: UIStroke
	stroke.Color = fromRgb(SoftColors.deepOf(rgb, BabyColors.COLORS))
	stroke.Enabled = not light
end

-- No grey hover in the soft look (owner 2026-11-03): Roblox's automatic darkening stays off, even when a controller
-- turns it back on to show a button can be used, and a mouse makes the button grow a little instead
local function noGreyHover(button: GuiButton, hoverScale: number)
	if button:GetAttribute("SoftHover") then
		return
	end
	button:SetAttribute("SoftHover", true)
	button.AutoButtonColor = false
	button:GetPropertyChangedSignal("AutoButtonColor"):Connect(function()
		if button.AutoButtonColor then
			button.AutoButtonColor = false
		end
	end)
	Motion.hover(button, hoverScale)
end

-- The cotton candy look on a new button (spec 2026-11-03-cotton-candy-ui-design): a flat baby colour (a named kit
-- colour becomes its baby fill, now and whenever a controller sets one later), a white outline, a soft glow in its own
-- colour, a faint lighter band along the top, plum text on light fills and white text outlined in the deep shade on
-- bright ones (a text colour a controller set itself is kept), and a squishy press. No dark lip.
local function softButton(button: TextButton): TextButton
	local look = BabyColors.SOFT_BUTTON
	noGreyHover(button, look.hoverScale)
	Motion.press(button, true)
	local round = button:FindFirstChildOfClass("UICorner")
	if round then
		round.CornerRadius = UDim.new(0, look.corner)
	end
	UIKit.outline(button, CREAM.OUTLINE, look.outline)
	-- Callers pad the text (iconButton makes room for its picture), like on the candy buttons
	local padding = Instance.new("UIPadding")
	padding.Parent = button
	UIKit.glow(button, button.BackgroundColor3, look.corner, look.glowDrop, look.glowTransparency)
	-- The padding moves children too: keep the glow on the whole button whatever it is
	local function refit()
		local left, right = padding.PaddingLeft.Offset, padding.PaddingRight.Offset
		local top, bottom = padding.PaddingTop.Offset, padding.PaddingBottom.Offset
		local glow = button:FindFirstChild("Glow")
		if glow and glow:IsA("ImageLabel") then
			local spread = BabyColors.GLOW.margin * glow.SliceScale
			local drop = glow:GetAttribute("Drop")
			glow.Size = UDim2.new(1, spread * 2 + left + right, 1, spread * 2 + top + bottom)
			glow.Position = UDim2.new(0.5, (right - left) / 2, 0.5, (if typeof(drop) == "number" then drop else 0) + (bottom - top) / 2)
		end
	end
	refit()
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		padding:GetPropertyChangedSignal(side):Connect(refit)
	end
	button.ChildAdded:Connect(function(child)
		if child.Name == "Glow" then
			task.defer(refit) -- a new glow (the round close button's) fits the padding too
		end
	end)
	local textEdge = UIKit.outlined(button, look.textOutline.thickness)
	textEdge.Transparency = look.textOutline.transparency -- a soft outline, like the mockup's light text shadow
	local autoText: Color3? = nil -- the text colour this button last picked for itself
	local function restyle()
		local fill = UIKit.softFill(button.BackgroundColor3)
		if fill ~= button.BackgroundColor3 then
			-- A named kit colour becomes its baby fill. Carry on: on the first call the change listener isn't connected
			-- yet (returning here left the text in Roblox's default navy); later calls run again harmlessly.
			button.BackgroundColor3 = fill
		end
		local rgb = toRgb(fill)
		local glow = button:FindFirstChild("Glow")
		if glow and glow:IsA("ImageLabel") then
			glow.ImageColor3 = fill
		end
		textEdge.Color = fromRgb(SoftColors.deepOf(rgb, BabyColors.COLORS))
		local pick = if SoftColors.textOn(rgb, BabyColors.LIGHT_LUMA) == "ink" then UIStyle.BABY_INK else Color3.new(1, 1, 1)
		if autoText == nil or button.TextColor3 == autoText then
			button.TextColor3 = pick
		end
		autoText = pick
	end
	local function outlineText()
		textEdge.Enabled = UIKit.isLight(button.TextColor3) -- white text gets the deep outline; plum text none
	end
	restyle()
	outlineText()
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(restyle)
	button:GetPropertyChangedSignal("TextColor3"):Connect(outlineText)
	return button
end

function UIKit.button(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.Text = text
	button.Parent = parent
	UIKit.corner(button, 12)
	if UIKit.isSoft(parent) then
		return softButton(button)
	end
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

	local cream = UIKit.themeOf(parent) == "cream"
	UIKit.outline(button, if cream then CREAM.OUTLINE else UIStyle.EDGE, if cream then CREAM.BUTTON_OUTLINE else UIStyle.EDGE_THICKNESS)
	local textEdge = UIKit.outlined(button)
	if cream then
		textEdge.Transparency = 0.35 -- a softer text outline in cream windows
	end
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
	if UIKit.isSoft(parent) then
		local round = close:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(0.5, 0) -- a pink circle with a white outline
		end
		-- Its glow follows the circle, not a button's rounded square
		local old = close:FindFirstChild("Glow")
		if old then
			old:Destroy()
		end
		local look = BabyColors.SOFT_BUTTON
		UIKit.glow(close, close.BackgroundColor3, 26, look.glowDrop, look.glowTransparency)
	end
	return close
end

-- The coloured band across the top of a panel (Config/UIStyle HEADERS: Party, Cards, Bosses, Bag, Default), with
-- the outlined title in it and a dark line under it
function UIKit.header(parent: GuiObject, title: string, band: string?): (Frame, TextLabel)
	local cream = UIKit.themeOf(parent) == "cream"
	local bands = if cream then CREAM.HEADERS else UIStyle.HEADERS
	local colors = bands[band or "Default"] or bands.Default
	local corner = if cream then CREAM.CORNER else PANEL_CORNER
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, UIKit.HEADER_HEIGHT)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = parent.ZIndex
	header.Parent = parent
	UIKit.corner(header, corner - 2)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(colors.top, colors.bottom)
	gradient.Parent = header
	-- Square off the header's bottom corners where it meets the body
	local squareBottom = Instance.new("Frame")
	squareBottom.Name = "SquareBottom"
	squareBottom.AnchorPoint = Vector2.new(0, 1)
	squareBottom.Position = UDim2.fromScale(0, 1)
	squareBottom.Size = UDim2.new(1, 0, 0, corner)
	squareBottom.BackgroundColor3 = Color3.new(1, 1, 1)
	squareBottom.BorderSizePixel = 0
	squareBottom.ZIndex = header.ZIndex
	squareBottom.Parent = header
	local bottomGradient = gradient:Clone()
	bottomGradient.Color = ColorSequence.new(colors.bottom)
	bottomGradient.Parent = squareBottom
	-- A line where the band meets the body: dark, or white in a cream window
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	rule.Size = UDim2.new(1, 0, 0, UIStyle.EDGE_THICKNESS)
	rule.BackgroundColor3 = if cream then CREAM.OUTLINE else UIStyle.EDGE
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

-- Paints `frame` as a cream window (spec 2026-11-03-cream-windows-design) and marks it Theme "cream" so the pieces
-- built inside it take the look: a cream gradient face (the "Face" child, under every other child), a thick white
-- outline and a soft shadow peeking out under it instead of the dark drop lip. UIKit.panel's windows use it, and the
-- windows built their own way (the Bag, the card detail). Returns the face and the outline.
function UIKit.creamWindow(frame: Frame): (Frame, UIStroke)
	frame:SetAttribute("Theme", "cream")
	-- Rows, slots and other buttons built in the window lose Roblox's grey hover and grow a little instead
	local function soften(child: Instance)
		if child:IsA("GuiButton") then
			noGreyHover(child, BabyColors.SOFT_BUTTON.rowHoverScale)
		end
	end
	for _, child in frame:GetDescendants() do
		soften(child)
	end
	frame.DescendantAdded:Connect(soften)
	frame.BackgroundColor3 = CREAM.BODY_BOTTOM
	UIKit.corner(frame, CREAM.CORNER)
	local edge = UIKit.outline(frame, CREAM.OUTLINE, CREAM.OUTLINE_THICKNESS)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 0 -- under every other child (Sibling ZIndexBehavior)
	face.Parent = frame
	UIKit.corner(face, CREAM.CORNER)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(CREAM.BODY_TOP, CREAM.BODY_BOTTOM)
	fill.Parent = face
	-- A soft lilac glow round the window instead of a dark shadow (spec 2026-11-03-cotton-candy-ui-design)
	local look = BabyColors.WINDOW_GLOW
	local glow = UIKit.glow(frame, UIStyle.BABY[look.color].fill, CREAM.CORNER, look.drop, look.transparency)
	glow.ZIndex = -1
	return face, edge
end

-- Centred modal panel: a coloured header band (`band`: a Config/UIStyle HEADERS name) with the title, red close
-- button and a scrolling list. `theme` "cream" (the default; spec 2026-11-03-cream-windows-design): a cream body with a
-- thick white outline and a soft shadow under it, the band in the window's HUD button colour (UIStyle.CREAM). "dark"
-- (the binder): the frame is the dark edge colour and a "Body" child paints the slate face LIP pixels short of the
-- bottom, so the edge shows there as a drop lip under a thick outline. The frame's Theme attribute tells the pieces
-- built inside which look to take. Starts hidden. The title label is named "Title" for callers that change it.
function UIKit.panel(
	parent: Instance,
	name: string,
	title: string,
	band: string?,
	theme: ("cream" | "dark")?,
	softButtons: boolean? -- a dark panel whose buttons still take the cotton candy look (the binder's screen)
): (Frame, ScrollingFrame)
	local look = theme or "cream"
	local cream = look == "cream"
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.7)
	frame.Visible = false
	frame.ZIndex = UIKit.PANEL_Z_INDEX -- over the HUD buttons, which stay at the default 1
	frame:SetAttribute("Theme", look)
	if softButtons then
		frame:SetAttribute("SoftButtons", true)
	end
	frame.Parent = parent
	local body: Frame, edge: UIStroke
	if cream then
		body, edge = UIKit.creamWindow(frame)
	else
		frame.BackgroundColor3 = UIStyle.EDGE
		UIKit.corner(frame, PANEL_CORNER)
		edge = UIKit.outline(frame, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
		body = Instance.new("Frame")
		body.Name = "Body"
		body.Size = UDim2.new(1, 0, 1, -UIStyle.LIP)
		body.BackgroundColor3 = UIKit.Colors.Panel
		body.BorderSizePixel = 0
		body.ZIndex = 0 -- under every other child (Sibling ZIndexBehavior)
		body.Parent = frame
		UIKit.corner(body, PANEL_CORNER)
	end
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
		local step = backSteps[frame]
		if step and step() then
			return
		end
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
		backSteps[frame] = nil
	end)
	trackPanel(frame)
	return frame, list
end

-- List row: a white card with a title and detail line, plus an action button on the right
function UIKit.row(parent: Instance, order: number, title: string, detail: string): (Frame, TextButton, TextLabel)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 76)
	frame.BackgroundColor3 = UIKit.colorsFor(parent).row
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

-- A segmented switch (round 3, the binder's Filters): one pale pill holding `values` side by side, the chosen one
-- butter with a white edge, the rest plum on the pale pill. `onPick` runs on a tap; the returned function shows a value
-- as chosen (so the caller's own state stays the truth). Built for a cream window.
function UIKit.segmented(parent: Instance, values: { string }, onPick: (string) -> ()): (Frame, (string) -> ())
	local look = BabyColors.SEGMENTED
	local palette = UIKit.colorsFor(parent)
	local bar = Instance.new("Frame")
	bar.Name = "Segmented"
	bar.Size = UDim2.new(1, 0, 0, look.height)
	bar.BackgroundColor3 = palette.slotEmpty
	bar.Parent = parent
	UIKit.corner(bar, look.height / 2)
	UIKit.outline(bar, palette.rowEdge, 2)
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(padding :: any)[side] = UDim.new(0, look.padding)
	end
	padding.Parent = bar
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, look.padding)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = bar
	local parts: { [string]: TextButton } = {}
	for index, value in values do
		local part = Instance.new("TextButton")
		part.Name = value
		part.LayoutOrder = index
		part.Size = UDim2.new(1 / #values, -look.padding * (#values - 1) / #values, 1, 0)
		part.AutoButtonColor = false
		part.BackgroundColor3 = UIStyle.BABY.butter.fill
		part.BackgroundTransparency = 1
		part.Font = Enum.Font.FredokaOne
		part.TextSize = look.textSize
		part.Text = value
		part.TextColor3 = palette.inkSoft
		part.Parent = bar
		UIKit.corner(part, (look.height - look.padding * 2) / 2)
		local edge = UIKit.outline(part, Color3.new(1, 1, 1), 2)
		edge.Enabled = false
		part.Activated:Connect(function()
			onPick(value)
		end)
		parts[value] = part
	end
	local function choose(chosen: string)
		for value, part in parts do
			local on = value == chosen
			part.BackgroundTransparency = if on then 0 else 1
			part.TextColor3 = if on then UIStyle.BABY_INK else palette.inkSoft
			local edge = part:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Enabled = on
			end
		end
	end
	return bar, choose
end

-- A small white tag with a coloured dot before its text (round 3, the Filters' rarity picks); the returned function
-- fills it with its colour (white text) when on. Built for a cream window.
function UIKit.dotTag(parent: Instance, text: string, color: Color3): (TextButton, (boolean) -> ())
	local look = BabyColors.DOT_TAG
	local palette = UIKit.colorsFor(parent)
	local tag = Instance.new("TextButton")
	tag.Name = text
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, look.height)
	tag.AutoButtonColor = false
	tag.BackgroundColor3 = palette.row
	tag.Font = Enum.Font.FredokaOne
	tag.TextSize = look.textSize
	tag.Text = text
	tag.TextColor3 = palette.ink
	tag.Parent = parent
	UIKit.corner(tag, look.height / 2)
	local edge = UIKit.outline(tag, palette.rowEdge, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, look.dot + 14)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = tag
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, -(look.dot + 6), 0.5, 0)
	dot.Size = UDim2.fromOffset(look.dot, look.dot)
	dot.BackgroundColor3 = color
	dot.Parent = tag
	UIKit.corner(dot, look.dot / 2)
	local ring = UIKit.outline(dot, Color3.new(1, 1, 1), 2)
	local textEdge = UIKit.outlined(tag, 1)
	textEdge.Transparency = 0.5
	local function set(on: boolean)
		tag.BackgroundColor3 = if on then color else palette.row
		tag.TextColor3 = if on then Color3.new(1, 1, 1) else palette.ink
		textEdge.Enabled = on
		edge.Color = if on then Color3.new(1, 1, 1) else palette.rowEdge
		edge.Thickness = if on then 3 else 2
		dot.BackgroundColor3 = if on then Color3.new(1, 1, 1) else color
		ring.Color = if on then color else Color3.new(1, 1, 1)
	end
	set(false)
	return tag, set
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
	UIKit.outline(pill, UIKit.colorsFor(parent).outline, 2)
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
	local palette = UIKit.colorsFor(parent)
	track.BackgroundColor3 = palette.track
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	UIKit.corner(track, 999)
	UIKit.outline(track, palette.rowEdge, 2)
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
