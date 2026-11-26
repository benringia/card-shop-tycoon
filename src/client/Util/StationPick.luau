--!strict
-- The put-a-card-in windows (owner 2026-11-26, the redesign mockups of artifact 72BD8xZJT75xL5ityfY621; Config/
-- StationLook): the Card Condenser and the Grading Station share one shape, built here. Under the band two tabs: the
-- machine's own ("Condense", "Upgrade") and Ready with a gold count. The first tab holds a card slot on the left ("Put
-- a card in", or the card in it with Change card) and the recipe box on the right, its big button pinned at its
-- bottom. A tap on the slot opens the card picker over the window ("Pick a card to condense", Back in the band); the
-- Ready tab shows the cards ready now as the same tiles. A phone's window puts the tabs in the band beside the title.
-- Pixels are before the window's own scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationLook = require(Shared:WaitForChild("Config"):WaitForChild("StationLook"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local Recipe = require(ClientUtil:WaitForChild("Recipe"))

local StationPick = {}

local LOOK = StationLook
local PHONE_TITLE_ROOM = 250 -- a phone's band: the title on the left, then the tabs, then the close button
local PHONE_CLOSE_ROOM = 66
local BACK_SIZE = 44
local LINE = 22 -- the small line over a grid
local CARD_SHAPE = 137 / 96 -- a card face's height for its width

function StationPick.rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end
local rgb = StationPick.rgb

export type Colors = { tabOn: Color3, tabEdge: Color3, tabInk: Color3, slot: Color3, plus: Color3, dash: Color3 }
export type Words = {
	TABS: { string },
	SLOT: string,
	SLOT_SUB: string,
	CHANGE: string,
	EMPTY_SAY: string,
	EMPTY_SUB: string,
	EMPTY_BUTTON: string,
	PICK_TITLE: string,
	PICK_SUB: string,
	PICK_NONE: string,
	READY_SUB: string,
	READY_NONE: string,
}
export type Window = {
	panel: Frame,
	palette: UIKit.Palette,
	colors: Colors,
	words: Words,
	title: TextLabel,
	titleText: string,
	titleX: number, -- where the title sits with the band's icon (or none)
	icon: GuiObject?,
	back: TextButton,
	tabs: Frame,
	setTabs: (chosen: string, count: number?) -> (),
	body: Frame, -- the first tab: the slot box and the recipe box
	slotBox: Frame,
	rightBox: Frame,
	pane: ScrollingFrame,
	actionBar: Frame,
	readyView: Frame,
	readyGrid: ScrollingFrame,
	picker: Frame,
	pickerLine: TextLabel,
	pickerGrid: ScrollingFrame,
}
export type Tile = { card: any, tag: string?, gold: boolean, onTap: () -> () }
-- One copy of a card in the picker's second step (owner 2026-11-21's copy picker, since 2026-11-26 a step of the
-- picker: "when I click on a card, it then should let me pick which copy of that card would I want to use")
export type CopyTile = {
	key: string,
	grade: string, -- "Grade A"
	gradeColor: Color3,
	foil: boolean, -- a gold Foil tag on its picture
	label: string, -- "You have 2", "Lv 12"
	stars: number,
	maxStars: number,
	tag: string?, -- "Ready!", "3 more"
	gold: boolean, -- its tag is the gold Ready!
	chosen: boolean, -- the one in the slot now: ringed and lit
	draw: (holder: Frame) -> (), -- draws its card's face into `holder`
	onTap: () -> (),
}

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end
StationPick.clear = clear

-- The window's own scale (Util/Motion's pop and a desktop's bigger windows), to read sizes in its pixels
local function scaleOf(panel: Frame): number
	local scaler = panel:FindFirstChildOfClass("UIScale")
	return if scaler and scaler.Scale > 0 then scaler.Scale else 1
end

-- A gui's width in the window's own pixels
function StationPick.width(window: Window, gui: GuiObject): number
	return gui.AbsoluteSize.X / scaleOf(window.panel)
end

-- ...and its height (a pane not laid out yet: a computer's usual box)
function StationPick.height(window: Window, gui: GuiObject): number
	local tall = gui.AbsoluteSize.Y / scaleOf(window.panel)
	return if tall < 100 then 300 else tall
end

-- How tall `text` wraps to in `wide` px (a sentence over the recipe: one line or two)
function StationPick.textTall(text: string, size: number, font: Enum.Font, wide: number): number
	return TextService:GetTextSize(text, size, font, Vector2.new(math.max(1, wide), 1000)).Y
end

-- A dashed edge round a box `size` px big: short strokes along each side, the corners (`corner` px) left open
function StationPick.dashed(parent: GuiObject, size: Vector2, color: Color3, corner: number?): Frame
	local look = LOOK.DASH
	local holder = Instance.new("Frame")
	holder.Name = "Dashes"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = parent.ZIndex + 1
	holder.Parent = parent
	local round = corner or 10
	local function side(x0: number, y0: number, length: number, across: boolean)
		local count = math.max(1, math.floor((length + look.gap) / (look.length + look.gap)))
		local used = count * look.length + (count - 1) * look.gap
		local start = (length - used) / 2
		for index = 0, count - 1 do
			local along = start + index * (look.length + look.gap)
			local stroke = Instance.new("Frame")
			stroke.BorderSizePixel = 0
			stroke.BackgroundColor3 = color
			stroke.Position = if across then UDim2.fromOffset(x0 + along, y0) else UDim2.fromOffset(x0, y0 + along)
			stroke.Size = if across then UDim2.fromOffset(look.length, look.thick) else UDim2.fromOffset(look.thick, look.length)
			stroke.ZIndex = holder.ZIndex
			stroke.Parent = holder
			UIKit.corner(stroke, look.thick / 2)
		end
	end
	side(round, 0, size.X - 2 * round, true)
	side(round, size.Y - look.thick, size.X - 2 * round, true)
	side(0, round, size.Y - 2 * round, false)
	side(size.X - look.thick, round, size.Y - 2 * round, false)
	return holder
end

-- A soft rounded box (the slot box, the recipe box)
local function box(parent: Instance, name: string, fill: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = fill
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIKit.corner(frame, 18)
	UIKit.outline(frame, rgb(LOOK.BOX), 2)
	return frame
end

-- A small line over a grid and the grid's scrolling frame under it
local function gridArea(parent: Frame, name: string, palette: UIKit.Palette): (TextLabel, ScrollingFrame)
	local line = UIKit.label(parent, "", Enum.Font.GothamBold, 13, palette.inkSoft)
	line.Name = "Line"
	line.Position = UDim2.fromOffset(4, 0)
	line.Size = UDim2.new(1, -8, 0, LINE - 4)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local grid = Instance.new("ScrollingFrame")
	grid.Name = name
	grid.Position = UDim2.fromOffset(0, LINE)
	grid.Size = UDim2.new(1, 0, 1, -LINE)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = UIKit.Colors.Accent
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = parent
	local padding = Instance.new("UIPadding") -- room for the tiles' outlines and their hover grow
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = grid
	return line, grid
end

-- One tab: its words and, on the Ready tab, a gold count
local function makeTab(parent: Instance, value: string, order: number, palette: UIKit.Palette): (TextButton, TextLabel, TextLabel)
	local look = LOOK.TAB
	local tab = Instance.new("TextButton")
	tab.Name = value
	tab.LayoutOrder = order
	tab.Text = ""
	tab.AutoButtonColor = false
	tab.AutomaticSize = Enum.AutomaticSize.X
	tab.Size = UDim2.fromOffset(0, look.hit)
	tab.BackgroundColor3 = palette.row
	tab.Parent = parent
	UIKit.corner(tab, look.hit / 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, look.pad)
	padding.PaddingRight = UDim.new(0, look.pad)
	padding.Parent = tab
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tab
	local label = UIKit.label(tab, value, Enum.Font.FredokaOne, look.textSize, palette.inkSoft)
	label.Name = "Words"
	label.LayoutOrder = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, look.hit)
	local badge = Instance.new("TextLabel")
	badge.Name = "Count"
	badge.LayoutOrder = 2
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Size = UDim2.fromOffset(0, look.badge)
	badge.BackgroundColor3 = rgb(LOOK.BADGE.fill)
	badge.TextColor3 = rgb(LOOK.BADGE.ink)
	badge.Font = Enum.Font.FredokaOne
	badge.TextSize = 14
	badge.Text = ""
	badge.Visible = false
	badge.Parent = tab
	UIKit.corner(badge, look.badge / 2)
	local badgePad = Instance.new("UIPadding")
	badgePad.PaddingLeft = UDim.new(0, 8)
	badgePad.PaddingRight = UDim.new(0, 8)
	badgePad.Parent = badge
	return tab, label, badge
end

-- The window's pieces inside `panel` (a UIKit.panel; its own list is not used): the tabs (`onTab` on a tap), the first
-- tab's slot box and recipe box, the Ready tab's grid, the card picker and its Back (`onBack`). `icon`: the band's icon
-- (Icon.header), hidden while the picker shows
function StationPick.build(panel: Frame, list: ScrollingFrame, look: { [string]: any }, words: Words, onTab: (string) -> (), onBack: () -> (), icon: GuiObject?): Window
	list.Visible = false
	local palette = UIKit.colorsFor(panel)
	local colors: Colors = {
		tabOn = rgb(look.tabOn),
		tabEdge = rgb(look.tabEdge),
		tabInk = rgb(look.tabInk),
		slot = rgb(look.slot),
		plus = rgb(look.plus),
		dash = rgb(look.dash),
	}
	local title = panel:FindFirstChild("Title") :: TextLabel

	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.Text = ""
	back.AutoButtonColor = false
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT / 2)
	back.Size = UDim2.fromOffset(BACK_SIZE, BACK_SIZE)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BackgroundTransparency = 0.35
	back.ZIndex = title.ZIndex + 1
	back.Visible = false
	back.Parent = panel
	UIKit.corner(back, BACK_SIZE / 2)
	UIKit.outline(back, Color3.new(1, 1, 1), 2)
	local arrow = Icon.make(back, "Next", UDim2.fromOffset(24, 24))
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Rotation = 180 -- the Next arrow, turned round
	arrow.ZIndex = back.ZIndex + 1
	back.Activated:Connect(onBack)

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = panel.ZIndex + 3 -- over the band and its title on a phone
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Padding = UDim.new(0, LOOK.TAB.gap)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	local parts: { [string]: { tab: TextButton, label: TextLabel, badge: TextLabel, edge: UIStroke } } = {}
	for order, value in words.TABS do
		local tab, label, badge = makeTab(tabs, value, order, palette)
		parts[value] = { tab = tab, label = label, badge = badge, edge = UIKit.outline(tab, palette.rowEdge, 2) }
		tab.Activated:Connect(function()
			onTab(value)
		end)
	end
	local readyTab = words.TABS[2]
	-- the chosen tab lit in the machine's colour; the Ready tab's gold count (nil or 0: none)
	local function setTabs(chosen: string, count: number?)
		for value, part in parts do
			local on = value == chosen
			part.tab.BackgroundColor3 = if on then colors.tabOn else palette.row
			part.edge.Color = if on then colors.tabEdge else palette.rowEdge
			part.label.TextColor3 = if on then colors.tabInk else palette.inkSoft
		end
		local ready = parts[readyTab]
		if ready then
			ready.badge.Visible = count ~= nil and count > 0
			ready.badge.Text = if count then tostring(count) else ""
		end
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Parent = panel
	local slotBox = box(body, "Slot", palette.row)
	local rightBox = box(body, "RecipeBox", rgb(LOOK.RECIPE_FILL))
	local pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.BackgroundTransparency = 1
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = rightBox
	local actionBar = Instance.new("Frame")
	actionBar.Name = "Action"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Position = UDim2.fromScale(0, 1)
	actionBar.Parent = rightBox

	local readyView = Instance.new("Frame")
	readyView.Name = "Ready"
	readyView.BackgroundTransparency = 1
	readyView.Visible = false
	readyView.Parent = panel
	local readyLine, readyGrid = gridArea(readyView, "ReadyCards", palette)
	readyLine.Text = words.READY_SUB

	local picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.BackgroundTransparency = 1
	picker.Visible = false
	picker.Parent = panel
	local pickerLine, pickerGrid = gridArea(picker, "Cards", palette)
	pickerLine.Text = words.PICK_SUB

	return {
		panel = panel,
		palette = palette,
		colors = colors,
		words = words,
		title = title,
		titleText = title.Text,
		titleX = title.Position.X.Offset,
		icon = icon,
		back = back,
		tabs = tabs,
		setTabs = setTabs,
		body = body,
		slotBox = slotBox,
		rightBox = rightBox,
		pane = pane,
		actionBar = actionBar,
		readyView = readyView,
		readyGrid = readyGrid,
		picker = picker,
		pickerLine = pickerLine,
		pickerGrid = pickerGrid,
	}
end

-- The big button's height and its bar's (a phone's slimmer: its window is short)
local function buttonTall(): number
	return if UIKit.isShort() then LOOK.BUTTON else Recipe.LOOK.button
end
local function barTall(): number
	return buttonTall() + (if UIKit.isShort() then 12 else 20)
end

-- Places the pieces for this screen: a computer's tabs under the band, or a phone's in the band beside the title
function StationPick.layout(window: Window)
	local phone = UIKit.isShort()
	local panel = window.panel
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local edge = if phone then 8 else LOOK.EDGE
	local hit = LOOK.TAB.hit
	if phone then
		window.tabs.Position = UDim2.fromOffset(PHONE_TITLE_ROOM, (UIKit.HEADER_HEIGHT - hit) / 2)
		window.tabs.Size = UDim2.new(1, -(PHONE_TITLE_ROOM + PHONE_CLOSE_ROOM), 0, hit)
	else
		window.tabs.Position = UDim2.fromOffset(edge + 4, UIKit.HEADER_HEIGHT + 12)
		window.tabs.Size = UDim2.new(1, -2 * (edge + 4), 0, hit)
	end
	local top = if phone then UIKit.HEADER_HEIGHT + 8 else UIKit.HEADER_HEIGHT + 12 + hit + LOOK.BODY_GAP
	for _, area in { window.body, window.readyView } do
		area.Position = UDim2.fromOffset(edge, top)
		area.Size = UDim2.new(1, -2 * edge, 1, -(top + edge))
	end
	local pickTop = UIKit.HEADER_HEIGHT + (if phone then 8 else 12)
	window.picker.Position = UDim2.fromOffset(edge, pickTop)
	window.picker.Size = UDim2.new(1, -2 * edge, 1, -(pickTop + edge))
	local slotWide = if phone then LOOK.SLOT_BOX.phone else LOOK.SLOT_BOX.desktop
	local gap = if phone then 10 else LOOK.BODY_GAP
	window.slotBox.Position = UDim2.fromOffset(0, 0)
	window.slotBox.Size = UDim2.new(0, slotWide, 1, 0)
	window.rightBox.Position = UDim2.fromOffset(slotWide + gap, 0)
	window.rightBox.Size = UDim2.new(1, -(slotWide + gap), 1, 0)
	window.pane.Position = UDim2.fromOffset(0, 4)
	window.pane.Size = UDim2.new(1, 0, 1, -(barTall() + 4))
	window.actionBar.Size = UDim2.new(1, 0, 0, barTall())
end

-- A grid's cells: `size` px each (a card tile's or a copy tile's), LOOK.TILE.gap apart
local function cells(grid: ScrollingFrame, size: { number })
	local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	layout.CellSize = UDim2.fromOffset(size[1], size[2])
	layout.CellPadding = UDim2.fromOffset(LOOK.TILE.gap, LOOK.TILE.gap)
end

-- Which part shows: "tab" (the slot and the recipe), "ready" (the Ready tab's cards), "picking" (the card picker, its
-- words in the band with Back) or "copies" (the picker's second step: one card's copies, `title` in the band and
-- `line` over them)
function StationPick.show(window: Window, view: "tab" | "ready" | "picking" | "copies", title: string?, line: string?)
	local picking = view == "picking" or view == "copies"
	window.picker.Visible = picking
	window.tabs.Visible = not picking
	window.body.Visible = view == "tab"
	window.readyView.Visible = view == "ready"
	window.back.Visible = picking
	if window.icon then
		window.icon.Visible = not picking
	end
	window.title.Text = if view == "copies" then title or "" elseif picking then window.words.PICK_TITLE else window.titleText
	window.pickerLine.Text = if view == "copies" then line or "" else window.words.PICK_SUB
	window.title.Position = UDim2.new(0, if picking then 12 + BACK_SIZE + 10 else window.titleX, window.title.Position.Y.Scale, window.title.Position.Y.Offset)
end

-- The slot on the left. `draw` nil: the empty dashed slot ("Put a card in", "Tap to pick one"); else the card in it
-- (drawn into the holder it's given) and Change card. Both open the picker (`onPick`)
function StationPick.slot(window: Window, draw: ((holder: Frame) -> ())?, onPick: () -> ())
	local slotBox, palette, colors, words = window.slotBox, window.palette, window.colors, window.words
	clear(slotBox)
	local phone = UIKit.isShort()
	local size = if phone then LOOK.SLOT.phone else LOOK.SLOT.desktop
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = slotBox
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, if phone then 8 else 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	if not draw then
		local slot = Instance.new("TextButton")
		slot.Name = "PutIn"
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.LayoutOrder = 1
		slot.Size = UDim2.fromOffset(size[1], size[2])
		slot.BackgroundColor3 = colors.slot
		slot.Parent = holder
		UIKit.corner(slot, 14)
		StationPick.dashed(slot, Vector2.new(size[1], size[2]), colors.dash, 14)
		-- a + drawn as two bars in a circle (a font's + is small and thin)
		local plusSize = if phone then 40 else 56
		local plus = Instance.new("Frame")
		plus.Name = "Plus"
		plus.AnchorPoint = Vector2.new(0.5, 0.5)
		plus.Position = UDim2.new(0.5, 0, 0.5, if phone then -30 else -42)
		plus.Size = UDim2.fromOffset(plusSize, plusSize)
		plus.BackgroundColor3 = colors.plus
		plus.Parent = slot
		UIKit.corner(plus, plusSize / 2)
		local bar, thick = math.floor(plusSize * 0.46), if phone then 5 else 6
		for _, across in { true, false } do
			local stroke = Instance.new("Frame")
			stroke.BorderSizePixel = 0
			stroke.AnchorPoint = Vector2.new(0.5, 0.5)
			stroke.Position = UDim2.fromScale(0.5, 0.5)
			stroke.Size = if across then UDim2.fromOffset(bar, thick) else UDim2.fromOffset(thick, bar)
			stroke.BackgroundColor3 = colors.tabInk
			stroke.Parent = plus
			UIKit.corner(stroke, thick / 2)
		end
		local put = UIKit.label(slot, words.SLOT, Enum.Font.FredokaOne, if phone then 15 else 20, palette.ink)
		put.Name = "Words"
		put.AnchorPoint = Vector2.new(0.5, 0)
		put.Position = UDim2.new(0.5, 0, 0.5, if phone then 0 else 4)
		put.Size = UDim2.new(1, -12, 0, if phone then 20 else 26)
		put.TextXAlignment = Enum.TextXAlignment.Center
		put.TextWrapped = true
		local sub = UIKit.label(slot, words.SLOT_SUB, Enum.Font.GothamBold, if phone then 11 else 12, palette.inkSoft)
		sub.Name = "Sub"
		sub.AnchorPoint = Vector2.new(0.5, 0)
		sub.Position = UDim2.new(0.5, 0, 0.5, if phone then 22 else 34)
		sub.Size = UDim2.new(1, -12, 0, 16)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		slot.Activated:Connect(onPick)
		return
	end
	-- the card, as big as the slot is wide, then Change card
	local faceWide = size[1] - 4
	local face = Instance.new("TextButton")
	face.Name = "Card"
	face.Text = ""
	face.AutoButtonColor = false
	face.BackgroundTransparency = 1
	face.LayoutOrder = 1
	face.Size = UDim2.fromOffset(faceWide, math.floor(faceWide * CARD_SHAPE))
	face.Parent = holder
	local inside = Instance.new("Frame")
	inside.BackgroundTransparency = 1
	inside.Size = UDim2.fromScale(1, 1)
	inside.Parent = face
	draw(inside)
	face.Activated:Connect(onPick)
	local change = UIKit.button(holder, words.CHANGE, UIKit.Colors.Secondary)
	change.Name = "Change"
	change.LayoutOrder = 2
	change.Font = Enum.Font.FredokaOne
	change.TextSize = if phone then 14 else 16
	change.Size = UDim2.fromOffset(if phone then size[1] else 160, if phone then 40 else LOOK.BUTTON)
	change.Activated:Connect(onPick)
end

-- The picker's or the Ready tab's cards as tiles: each card's picture, its name and its tag (a gold "Ready!", "3
-- more"...); `none`: what an empty grid says
function StationPick.tiles(window: Window, grid: ScrollingFrame, tiles: { Tile }, none: string)
	local palette = window.palette
	clear(grid)
	local area = grid.Parent :: Instance
	local old = area:FindFirstChild("None")
	if old then
		old:Destroy()
	end
	local phone = UIKit.isShort()
	local size = if phone then LOOK.TILE.phone else LOOK.TILE.desktop
	cells(grid, size)
	if #tiles == 0 then
		-- the words alone, over the empty grid (a grid cell would squeeze them)
		local empty = UIKit.label(area, none, Enum.Font.GothamBold, 15, palette.inkSoft)
		empty.Name = "None"
		empty.Position = UDim2.fromOffset(6, LINE + 10)
		empty.Size = UDim2.new(1, -12, 0, 60)
		empty.TextWrapped = true
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	local artTall = math.floor(size[2] * LOOK.TILE.art)
	for order, tile in tiles do
		local card = tile.card
		local button = Instance.new("TextButton")
		button.Name = "Card_" .. tostring(card.id)
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = palette.row
		button.Parent = grid
		UIKit.corner(button, 14)
		UIKit.outline(button, rgb(LOOK.BOX), 2)
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundColor3 = CardFace.getRarityColor(card.rarity)
		art.Position = UDim2.fromOffset(6, 6)
		art.Size = UDim2.new(1, -12, 0, artTall)
		art.ScaleType = Enum.ScaleType.Crop
		art.Image = CardFace.artImage(card)
		art.Parent = button
		UIKit.corner(art, 8)
		local name = UIKit.label(button, card.name, Enum.Font.FredokaOne, if phone then 12 else 15, palette.ink)
		name.Name = "CardName"
		name.Position = UDim2.fromOffset(4, artTall + 9)
		name.Size = UDim2.new(1, -8, 0, if phone then 15 else 19)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		if tile.tag then
			local fill = if tile.gold then rgb(LOOK.BADGE.fill) else palette.track
			local tag = UIKit.pill(button, tile.tag, fill, if tile.gold then rgb(LOOK.BADGE.ink) else palette.inkSoft)
			tag.Name = "Tag"
			tag.AnchorPoint = Vector2.new(0.5, 1)
			tag.Position = UDim2.new(0.5, 0, 1, if phone then -5 else -8)
			tag.Size = UDim2.fromOffset(0, if phone then 18 else 22)
			tag.TextSize = if phone then 11 else 13
		end
		button.Activated:Connect(tile.onTap)
	end
end

-- The picker's second step: a card's copies as tiles in its grid (each copy's face with its level, stars and grade, a
-- gold Foil tag, its grade in the grade's colour, its stars, "You have 2" or "Lv 12", and a tag); the one in the slot
-- ringed and lit; a tap picks it
function StationPick.copyTiles(window: Window, tiles: { CopyTile })
	local palette, grid = window.palette, window.pickerGrid
	clear(grid)
	local old = window.picker:FindFirstChild("None")
	if old then
		old:Destroy()
	end
	local phone = UIKit.isShort()
	cells(grid, if phone then LOOK.COPY_TILE.phone else LOOK.COPY_TILE.desktop)
	local face = if phone then LOOK.COPY_TILE.face.phone else LOOK.COPY_TILE.face.desktop
	local small = if phone then 10 else 12
	for order, tile in tiles do
		local button = Instance.new("TextButton")
		button.Name = "Copy_" .. tile.key
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = if tile.chosen then rgb(LOOK.USE_ON.fill) else palette.row
		button.Parent = grid
		UIKit.corner(button, 12)
		UIKit.outline(button, if tile.chosen then rgb(LOOK.USE_ON.edge) else rgb(LOOK.BOX), if tile.chosen then 3 else 2)
		local holder = Instance.new("Frame")
		holder.Name = "Face"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 5)
		holder.Size = UDim2.fromOffset(face[1], face[2])
		holder.Parent = button
		tile.draw(holder)
		if tile.foil then
			local foil = UIKit.pill(button, "Foil", rgb(LOOK.BADGE.fill), rgb(LOOK.BADGE.ink))
			foil.Name = "Foil"
			foil.Position = UDim2.fromOffset(2, math.floor(face[2] * 0.22)) -- on the picture, clear of the card's name
			foil.Size = UDim2.fromOffset(0, 18)
			foil.TextSize = 11
			foil.ZIndex = holder.ZIndex + 10
		end
		local y = face[2] + 9
		local grade = UIKit.pill(button, tile.grade, tile.gradeColor, Color3.new(1, 1, 1))
		grade.Name = "Grade"
		grade.AnchorPoint = Vector2.new(0.5, 0)
		grade.Position = UDim2.new(0.5, 0, 0, y)
		grade.Size = UDim2.fromOffset(0, if phone then 18 else 20)
		grade.TextSize = small
		y += if phone then 21 else 24
		local starSize = if phone then 9 else 11
		local stars = Instance.new("Frame")
		stars.Name = "Stars"
		stars.BackgroundTransparency = 1
		stars.AnchorPoint = Vector2.new(0.5, 0)
		stars.Position = UDim2.new(0.5, 0, 0, y)
		stars.Size = UDim2.fromOffset(tile.maxStars * (starSize + 2) - 2, starSize)
		stars.Parent = button
		for index = 1, tile.maxStars do
			local icon = Icon.make(stars, "Star", UDim2.fromOffset(starSize, starSize))
			icon.Position = UDim2.fromOffset((index - 1) * (starSize + 2), 0)
			Icon.set(icon, "Star")
			local glyph = icon:FindFirstChild("Glyph")
			if glyph and glyph:IsA("ImageLabel") then
				glyph.ImageTransparency = if index <= tile.stars then 0 else 0.8
			end
		end
		y += starSize + 4
		local has = UIKit.label(button, tile.label, Enum.Font.GothamBold, small - 1, palette.inkSoft)
		has.Name = "Has"
		has.Position = UDim2.fromOffset(2, y)
		has.Size = UDim2.new(1, -4, 0, 14)
		has.TextXAlignment = Enum.TextXAlignment.Center
		if tile.tag then
			local fill = if tile.gold then rgb(LOOK.BADGE.fill) else palette.track
			local tag = UIKit.pill(button, tile.tag, fill, if tile.gold then rgb(LOOK.BADGE.ink) else palette.inkSoft)
			tag.Name = "Tag"
			tag.AnchorPoint = Vector2.new(0.5, 1)
			tag.Position = UDim2.new(0.5, 0, 1, -6)
			tag.Size = UDim2.fromOffset(0, if phone then 18 else 20)
			tag.TextSize = small - 1
		end
		button.Activated:Connect(tile.onTap)
	end
end

-- The big button pinned at the recipe box's bottom: its words, the small line under them, gold when it works
function StationPick.bigButton(window: Window, text: string, sub: string?, enabled: boolean): TextButton
	clear(window.actionBar)
	local button = UIKit.button(window.actionBar, text, if enabled then UIKit.Colors.Accent else UIKit.Colors.Locked)
	button.Name = "Go"
	button.AnchorPoint = Vector2.new(0.5, 0) -- grows evenly under the mouse
	button.Position = UDim2.new(0.5, 0, 0, if UIKit.isShort() then 4 else 8)
	button.Size = UDim2.new(1, -24, 0, buttonTall())
	button.AutoButtonColor = enabled
	Recipe.words(button, text, sub)
	return button
end

-- The recipe box with no card in: a sentence, a small line, the recipe drawn as dashed outlines (`spots` copies, an
-- arrow, the card) and the big button, locked
function StationPick.emptyPane(window: Window, spots: number)
	local pane, palette, words = window.pane, window.palette, window.words
	clear(pane)
	local phone = UIKit.isShort()
	local say = UIKit.label(pane, words.EMPTY_SAY, Enum.Font.FredokaOne, if phone then 15 else 20, palette.ink)
	say.Name = "Say"
	say.Position = UDim2.fromOffset(12, if phone then 6 else 14)
	say.Size = UDim2.new(1, -24, 0, if phone then 20 else 28)
	say.TextWrapped = true
	say.TextXAlignment = Enum.TextXAlignment.Center
	local sub = UIKit.label(pane, words.EMPTY_SUB, Enum.Font.GothamBold, if phone then 11 else 13, palette.inkSoft)
	sub.Name = "Sub"
	sub.Position = UDim2.fromOffset(12, if phone then 28 else 46)
	sub.Size = UDim2.new(1, -24, 0, if phone then 28 else 34)
	sub.TextWrapped = true
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.TextYAlignment = Enum.TextYAlignment.Top
	-- the ghost recipe, as big as the box has room for over the button (none in a tiny box)
	StationPick.bigButton(window, words.EMPTY_BUTTON, nil, false)
	local ghost = rgb(LOOK.GHOST)
	local rowTop = if phone then 62 else 96
	local fit = math.min(1, (StationPick.height(window, pane) - rowTop - 6) / 128)
	if fit < 0.4 then
		return
	end
	local spot = Vector2.new(math.floor(56 * fit), math.floor(78 * fit))
	local card = Vector2.new(math.floor(92 * fit), math.floor(128 * fit))
	local gap, room = math.floor(10 * fit), Recipe.LOOK.arrow
	local wide = spots * spot.X + (spots - 1) * gap + room + card.X
	local row = Instance.new("Frame")
	row.Name = "Ghost"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, rowTop)
	row.Size = UDim2.fromOffset(wide, card.Y)
	row.Parent = pane
	for index = 1, spots do
		local cell = Instance.new("Frame")
		cell.Name = "Spot"
		cell.BackgroundTransparency = 1
		cell.Position = UDim2.fromOffset((index - 1) * (spot.X + gap), (card.Y - spot.Y) / 2)
		cell.Size = UDim2.fromOffset(spot.X, spot.Y)
		cell.Parent = row
		StationPick.dashed(cell, spot, ghost, 6)
	end
	-- the arrow in the middle of its room, between the spots and the card
	Recipe.arrow(row, spots * spot.X + (spots - 1) * gap + room / 2, card.Y / 2, ghost)
	local after = Instance.new("Frame")
	after.Name = "Card"
	after.BackgroundTransparency = 1
	after.Position = UDim2.fromOffset(wide - card.X, 0)
	after.Size = UDim2.fromOffset(card.X, card.Y)
	after.Parent = row
	StationPick.dashed(after, card, ghost, 8)
end

return StationPick
