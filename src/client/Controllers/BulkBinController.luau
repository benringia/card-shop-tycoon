--!strict
-- The Bulk Bin's window (owner 2026-11-26: "Bulkbin: Currently with one click all your commons are gone. make the
-- player use it display a window. so that they will know what they putting on it", pick B of the mockups in artifact
-- 72BD8xZJT75xL5ityfY621; words and rules in Util/BulkRules and Config/Bulk, look in Config/StationLook): your bin's
-- Add extras prompt opens it. Every card with extra Commons shows as a tile with how many go in ("x6"); a tap keeps that
-- card out (the tile fades, its edge dashed, "Kept") and a second tap puts it back. The footer says what goes in ("25
-- cards = 5 handfuls", "2 kept out · customers buy them 5 at a time") over Not now and "Put 25 in", or why nothing can
-- (the bin full, no extras yet, all kept out, less than a handful). Put in sends the cards kept out
-- (Remotes.FillBulkBin); BulkService works the extras out again from the binder and puts the rest in. The cards kept
-- out stay kept out the next time the window opens this session. Closes when you walk away or the bin goes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bulk = require(Config:WaitForChild("Bulk"))
local Cards = require(Config:WaitForChild("Cards"))
local Shelves = require(Config:WaitForChild("Shelves"))
local StockConfig = require(Config:WaitForChild("Stock"))
local StationLook = require(Config:WaitForChild("StationLook"))
local BulkRules = require(Shared:WaitForChild("Util"):WaitForChild("BulkRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local StationPick = require(ClientUtil:WaitForChild("StationPick"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

local PANEL_MAX_SIZE = Vector2.new(820, 540)
local DISTANCE_CHECK_SECONDS = 0.5
local EDGE = 20
local FOOTER = 84 -- a computer's footer (a phone's: PHONE_FOOTER)
local PHONE_FOOTER = 64
local SAY = "These extra Commons go in. Tap a card to keep it out."
local SAY_SUB = `You keep {Bulk.KEEP} of each card. Foils and Grade A or S never go in.`

local player = Players.LocalPlayer

local BulkBinController = {}

local panel: Frame
local palette: UIKit.Palette
local say: TextLabel
local sub: TextLabel
local grid: ScrollingFrame
local footer: Frame
local footerTitle: TextLabel
local footerLine: TextLabel
local buttons: Frame
local bin: BasePart? = nil
local keptOut: { [string]: boolean } = {} -- the cards kept out (this session)

local function rarityOf(cardId: string): string?
	local card = Cards.ById[cardId]
	return if card then card.rarity else nil
end

-- How many handfuls the bin still has room for
local function roomIn(part: BasePart): number
	local def = Shelves.ById[part.Name]
	local units = part:GetAttribute("Units")
	return math.max(0, (if def then def.capacity else 0) - (if typeof(units) == "number" then units else 0))
end

local render: () -> ()

-- One card's tile: its picture and name, "x6" while it goes in, or faded with a dashed edge and "Kept"
local function tile(order: number, cardId: string, count: number)
	local card = Cards.ById[cardId]
	if not card then
		return
	end
	local kept = keptOut[cardId] == true
	local phone = UIKit.isShort()
	local size = if phone then StationLook.BULK_TILE.phone else StationLook.BULK_TILE.desktop
	local look = StationLook.KEPT
	local button = Instance.new("TextButton")
	button.Name = "Card_" .. cardId
	button.LayoutOrder = order
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = palette.row
	button.BackgroundTransparency = if kept then look.fade else 0
	button.Parent = grid
	UIKit.corner(button, 12)
	if kept then
		StationPick.dashed(button, Vector2.new(size[1], size[2]), StationPick.rgb(look.dash), 12)
	else
		UIKit.outline(button, StationPick.rgb(StationLook.USE_ON.edge), 2)
	end
	local artTall = math.floor(size[2] * StationLook.BULK_TILE.art)
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundColor3 = CardFace.getRarityColor(card.rarity)
	art.BackgroundTransparency = if kept then look.fade else 0
	art.Position = UDim2.fromOffset(6, 6)
	art.Size = UDim2.new(1, -12, 0, artTall)
	art.ScaleType = Enum.ScaleType.Crop
	art.Image = CardFace.artImage(card)
	art.ImageTransparency = if kept then look.fade else 0
	art.Parent = button
	UIKit.corner(art, 8)
	local name = UIKit.label(button, card.name, Enum.Font.FredokaOne, if phone then 12 else 13, palette.ink)
	name.Name = "CardName"
	name.Position = UDim2.fromOffset(4, artTall + 10)
	name.Size = UDim2.new(1, -8, 0, 16)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextTransparency = if kept then look.fade else 0
	local badgeLook = if kept then { fill = look.badge, ink = look.ink } else StationLook.COUNT
	local badge = UIKit.pill(button, if kept then "Kept" else `x{count}`, StationPick.rgb(badgeLook.fill), StationPick.rgb(badgeLook.ink))
	badge.Name = "Count"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -2, 0, 2)
	badge.Size = UDim2.fromOffset(0, 22)
	badge.TextSize = 13
	button.Activated:Connect(function()
		keptOut[cardId] = if kept then nil else true
		render()
	end)
end

local function close()
	panel.Visible = false
	bin = nil
end

render = function()
	local part = bin
	if not panel.Visible or not part then
		return
	end
	StationPick.clear(grid)
	StationPick.clear(buttons)
	local phone = UIKit.isShort()
	-- every extra, kept out or not, so a kept card still shows as a tile to tap back in
	local takes = BulkRules.extras(BinderController.GetGradedStacks(), rarityOf, Bulk)
	local tiles = BulkRules.byCard(takes)
	local extras, kept = 0, 0
	for order, entry in tiles do
		tile(order, entry.cardId, entry.count)
		if keptOut[entry.cardId] then
			kept += 1
		else
			extras += entry.count
		end
	end
	local words = BulkRules.words({ extras = extras, kept = kept, room = roomIn(part), per = Bulk.PER, keep = Bulk.KEEP })
	footerTitle.Text = words.title
	footerLine.Text = words.line

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons
	local notNow = UIKit.button(buttons, "Not now", UIKit.Colors.Secondary)
	notNow.Name = "NotNow"
	notNow.LayoutOrder = 1
	notNow.Font = Enum.Font.FredokaOne
	notNow.TextSize = if phone then 15 else 18
	notNow.Size = UDim2.fromOffset(if phone then 110 else 132, StationLook.BUTTON + (if phone then 0 else 4))
	notNow.Activated:Connect(close)
	local put = UIKit.button(buttons, words.button, if words.ready then UIKit.Colors.Accent else UIKit.Colors.Locked)
	put.Name = "PutIn"
	put.LayoutOrder = 2
	put.Font = Enum.Font.FredokaOne
	put.TextSize = if phone then 17 else 21
	put.Size = UDim2.fromOffset(if phone then 150 else 180, StationLook.BUTTON + (if phone then 0 else 8))
	put.AutoButtonColor = words.ready
	put.Activated:Connect(function()
		local uid = part:GetAttribute("ShelfUid")
		if not words.ready or typeof(uid) ~= "string" then
			return
		end
		local list: { string } = {}
		for _, entry in tiles do
			if keptOut[entry.cardId] then
				table.insert(list, entry.cardId)
			end
		end
		Remotes.FillBulkBin:FireServer(uid, list) -- BulkService: the rest go in, or the locked card says why not
		close()
	end)
end

-- Places the pieces for this screen: a phone's smaller words, tiles and footer
local function layout()
	local phone = UIKit.isShort()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local edge = if phone then 10 else EDGE
	local top = UIKit.HEADER_HEIGHT + (if phone then 6 else 14)
	say.TextSize = if phone then 15 else 21
	say.Position = UDim2.fromOffset(edge, top)
	say.Size = UDim2.new(1, -2 * edge, 0, if phone then 20 else 28)
	sub.TextSize = if phone then 11 else 13
	sub.Position = UDim2.fromOffset(edge, top + (if phone then 20 else 30))
	sub.Size = UDim2.new(1, -2 * edge, 0, 16)
	local gridTop = top + (if phone then 40 else 56)
	local foot = if phone then PHONE_FOOTER else FOOTER
	grid.Position = UDim2.fromOffset(edge - 6, gridTop)
	grid.Size = UDim2.new(1, -2 * (edge - 6), 1, -(gridTop + foot))
	local cell = if phone then StationLook.BULK_TILE.phone else StationLook.BULK_TILE.desktop
	local gridLayout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	gridLayout.CellSize = UDim2.fromOffset(cell[1], cell[2])
	gridLayout.CellPadding = UDim2.fromOffset(StationLook.BULK_TILE.gap, StationLook.BULK_TILE.gap)
	footer.Position = UDim2.new(0, edge, 1, -foot)
	footer.Size = UDim2.new(1, -2 * edge, 0, foot)
	footerTitle.TextSize = if phone then 15 else 18
end

-- Opens the window for your own Bulk Bin (its Add extras prompt)
function BulkBinController.Open(part: BasePart)
	bin = part
	layout()
	panel.Visible = true
	grid.CanvasPosition = Vector2.zero
	render()
end

-- Closes once the owner walks away or the bin is moved or sold
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local part = bin
		if part and panel.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > StockConfig.INTERACT_DISTANCE then
				close()
			end
		end
	end
end

function BulkBinController.Start()
	local screenGui = UIController.GetScreenGui()
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "BulkBinWindow", "Bulk Bin", "BulkBin")
	list.Visible = false
	palette = UIKit.colorsFor(panel)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	say = UIKit.label(panel, SAY, Enum.Font.FredokaOne, 21, palette.ink)
	say.Name = "Say"
	say.TextTruncate = Enum.TextTruncate.AtEnd
	sub = UIKit.label(panel, SAY_SUB, Enum.Font.GothamBold, 13, palette.inkSoft)
	sub.Name = "Sub"
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Extras"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = UIKit.Colors.Accent
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel
	local padding = Instance.new("UIPadding") -- room for the tiles' outlines
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Parent = panel
	local rule = Instance.new("Frame") -- the line over the footer
	rule.Name = "Rule"
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = palette.rowEdge
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.Parent = footer
	-- what goes in over the footer's middle, the small line under it
	footerTitle = UIKit.label(footer, "", Enum.Font.FredokaOne, 18, palette.ink)
	footerTitle.Name = "Title"
	footerTitle.AnchorPoint = Vector2.new(0, 1)
	footerTitle.Position = UDim2.new(0, 0, 0.5, 3)
	footerTitle.Size = UDim2.new(1, -320, 0, 24)
	footerTitle.TextTruncate = Enum.TextTruncate.AtEnd
	footerTitle.TextWrapped = false
	footerLine = UIKit.label(footer, "", Enum.Font.GothamBold, 12, palette.inkSoft)
	footerLine.Name = "Line"
	footerLine.Position = UDim2.new(0, 0, 0.5, 6)
	footerLine.Size = UDim2.new(1, -320, 0, 30)
	footerLine.TextYAlignment = Enum.TextYAlignment.Top
	buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, 0, 0.5, 2)
	buttons.Size = UDim2.new(0, 320, 1, -8)
	buttons.Parent = footer

	-- the binder changing (a pack opened, the bin filled) or the bin's stock: the tiles and the footer follow
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render) -- after BinderController has stored the new binder
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			bin = nil
		end
	end)
	task.spawn(watchDistance)
end

return BulkBinController
