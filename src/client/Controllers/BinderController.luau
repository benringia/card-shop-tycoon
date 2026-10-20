--!strict
-- Binder: every Set 1 card in a grid, owned ones in colour with counts, missing ones greyed out.
-- Tap an owned card to see it large. Cards earn money only from a showcase, so the binder just
-- shows what you have; cards on display in your cases count towards completion.
-- The server sends the binder whenever it changes; displayed cards are read from your plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])
type Owned = { normal: number, foil: number }
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number }

type Tile = {
	card: Card,
	inner: Frame,
	stroke: UIStroke,
	countLabel: TextLabel,
}

local TILE_SIZE = Vector2.new(78, 112)
local BINDER_KEY = Enum.KeyCode.B
local HOW_TO_SELL = "To sell, put it in a Glass Showcase (customers) or Collector Case (players): walk up, press F, then Cards."
local BEAST_ROW_HEIGHT = 100
local FRESH_ROW_HEIGHT = 64
local VALUE_COLOR = Color3.fromRGB(120, 230, 120)
local XP_BAR_COLOR = Color3.fromRGB(90, 160, 255)
local XP_TRACK_COLOR = Color3.fromRGB(25, 25, 35)

local player = Players.LocalPlayer

local BinderController = {}

local collection: { [string]: Owned } = {}
local beasts: { [string]: Beast } = {}
local displayed: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local completionLabel: TextLabel

local detail: Frame
local detailInner: Frame
local detailStroke: UIStroke
local detailName: TextLabel
local detailSubtitle: TextLabel
local detailSummary: TextLabel
local raisedList: ScrollingFrame
local detailCard: Card? = nil
local selectedBeastId: string? = nil -- the beast shown on the big card; nil shows a fresh copy
local plotConnections: { RBXScriptConnection } = {}
local refreshQueued = false

local function getCount(source: { [string]: Owned }, cardId: string): Owned
	return source[cardId] or { normal = 0, foil = 0 }
end

-- This card's raised beasts in the binder, strongest (highest value) first
local function getRaised(cardId: string): { Beast }
	local list: { Beast } = {}
	for _, beast in beasts do
		if beast.cardId == cardId then
			table.insert(list, beast)
		end
	end
	local card = Cards.ById[cardId]
	table.sort(list, function(a, b)
		return BeastRules.getValue(card, a.foil, a.level, a.stars) > BeastRules.getValue(card, b.foil, b.level, b.stars)
	end)
	return list
end

-- Cards currently in this player's own cases, read from the card parts on their plot
local function readDisplayedCards(): { [string]: Owned }
	local counts: { [string]: Owned } = {}
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	if not plot then
		return counts
	end
	for _, part in plot:GetDescendants() do
		local cardId = part:GetAttribute("CardId")
		if typeof(cardId) == "string" and part:GetAttribute("OwnerUserId") == player.UserId then
			local owned = counts[cardId] or { normal = 0, foil = 0 }
			counts[cardId] = owned
			if part:GetAttribute("Foil") == true then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	return counts
end

local function addCardFrame(parent: Instance): (Frame, UIStroke)
	local inner = Instance.new("Frame")
	inner.Name = "Face"
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = parent
	UIKit.corner(inner, 8)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner
	return inner, stroke
end

local function clearRows()
	for _, child in raisedList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addRowText(row: GuiObject, text: string, y: number, height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, size, color)
	label.Position = UDim2.fromOffset(10, y)
	label.Size = UDim2.new(1, -20, 0, height)
	label.ZIndex = 13
	return label
end

local function makeRow(order: number, height: number, selected: boolean, onTap: () -> ()): TextButton
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, height)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Text = ""
	row.ZIndex = 12
	row.Parent = raisedList
	UIKit.corner(row, 8)
	if selected then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = row
	end
	row.Activated:Connect(onTap)
	return row
end

local refreshDetail: () -> ()

local function selectBeast(beastId: string?)
	selectedBeastId = beastId
	refreshDetail()
end

-- One raised beast: growth and value / stats / XP bar / what it needs for the next star
local function addBeastRow(card: Card, beast: Beast, order: number)
	local row = makeRow(order, BEAST_ROW_HEIGHT, beast.id == selectedBeastId, function()
		selectBeast(beast.id)
	end)

	local title = `{if beast.foil then "FOIL · " else ""}{BeastRules.describeGrowth(beast.level, beast.stars)}`
	addRowText(row, title, 6, 20, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	local valueText = string.format("$%.2f", BeastRules.getValue(card, beast.foil, beast.level, beast.stars))
	local value = addRowText(row, valueText, 6, 20, Enum.Font.FredokaOne, 17, VALUE_COLOR)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars)
	addRowText(row, `HP {stats.hp}   ATK {stats.atk}   SPD {stats.spd}`, 28, 18, Enum.Font.GothamBold, 13, UIKit.Colors.Text)

	-- XP bar with the numbers on it
	local toNext = BeastRules.getXpToNext(beast.level)
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(10, 50)
	track.Size = UDim2.new(1, -20, 0, 18)
	track.BackgroundColor3 = XP_TRACK_COLOR
	track.ZIndex = 13
	track.Parent = row
	UIKit.corner(track, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(if toNext > 0 then math.clamp(beast.xp / toNext, 0, 1) else 1, 1)
	fill.BackgroundColor3 = if toNext > 0 then XP_BAR_COLOR else UIKit.Colors.Accent
	fill.ZIndex = 14
	fill.Parent = track
	UIKit.corner(fill, 6)
	local xpText = UIKit.label(track, if toNext > 0 then `XP {beast.xp} / {toNext}` else "MAX LEVEL", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	xpText.Size = UDim2.fromScale(1, 1)
	xpText.TextXAlignment = Enum.TextXAlignment.Center
	xpText.TextStrokeTransparency = 0.6
	xpText.ZIndex = 15

	addRowText(row, BeastRules.describeStarProgress(beast.level, beast.stars), 72, 24, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
end

-- Untouched copies: how many and what they're worth
local function addFreshRow(card: Card, inBinder: Owned, order: number)
	local row = makeRow(order, FRESH_ROW_HEIGHT, selectedBeastId == nil, function()
		selectBeast(nil)
	end)
	local count = if inBinder.foil == 0
		then `x{inBinder.normal}`
		elseif inBinder.normal == 0 then `x{inBinder.foil} foil`
		else `x{inBinder.normal} + {inBinder.foil} foil`
	addRowText(row, `Fresh copies {count} · Lv 1`, 6, 20, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	local valueText = string.format("$%.2f", CardRules.getMarketValue(card, inBinder.foil > 0))
	local value = addRowText(row, valueText, 6, 20, Enum.Font.FredokaOne, 17, VALUE_COLOR)
	value.TextXAlignment = Enum.TextXAlignment.Right
	addRowText(row, "Give a copy XP and it becomes a beast that levels up.", 30, 28, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
end

refreshDetail = function()
	local card = detailCard
	if not card then
		return
	end
	local inBinder = getCount(collection, card.id)
	local shown = getCount(displayed, card.id)
	local raised = getRaised(card.id)
	local freshCount = inBinder.normal + inBinder.foil
	if freshCount + shown.normal + shown.foil + #raised == 0 then
		detail.Visible = false
		detailCard = nil
		return
	end

	-- Keep the selection valid: if that beast left the binder, show the fresh copies (or the best beast)
	local selected: Beast? = nil
	for _, beast in raised do
		if beast.id == selectedBeastId then
			selected = beast
		end
	end
	if not selected and freshCount == 0 then
		selected = raised[1]
	end
	selectedBeastId = if selected then selected.id else nil

	if selected then
		CardFace.render(detailInner, detailStroke, card, selected.foil, true, { level = selected.level, stars = selected.stars })
	else
		-- Show the foil version when the player has one, it's the one they'll want to look at
		CardFace.render(detailInner, detailStroke, card, inBinder.foil + shown.foil > 0)
	end

	detailName.Text = card.name
	detailSubtitle.Text = string.format("#%02d · %s · %s", card.number, card.element, card.rarity)
	local onDisplay = shown.normal + shown.foil
	detailSummary.Text = string.format(
		"%d raised · %d fresh%s%s",
		#raised,
		freshCount,
		if onDisplay > 0 then ` · {onDisplay} on display` else "",
		if #raised + (if freshCount > 0 then 1 else 0) > 1 then " · tap a row to view it" else ""
	)

	clearRows()
	for index, beast in raised do
		addBeastRow(card, beast, index)
	end
	if freshCount > 0 then
		addFreshRow(card, inBinder, #raised + 1)
	end
	local footer = UIKit.label(raisedList, HOW_TO_SELL, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	footer.LayoutOrder = #raised + 2
	footer.Size = UDim2.new(1, -8, 0, 44)
	footer.ZIndex = 12
end

local function refresh()
	displayed = readDisplayedCards()
	local ownedKinds = 0
	for _, tile in tiles do
		local inBinder = getCount(collection, tile.card.id)
		local shown = getCount(displayed, tile.card.id)
		local binderTotal = inBinder.normal + inBinder.foil
		local raised = #getRaised(tile.card.id)
		if binderTotal + shown.normal + shown.foil + raised > 0 then
			ownedKinds += 1
			local hasFoilBeast = false
			for _, beast in getRaised(tile.card.id) do
				hasFoilBeast = hasFoilBeast or beast.foil
			end
			CardFace.render(tile.inner, tile.stroke, tile.card, inBinder.foil + shown.foil > 0 or hasFoilBeast, false)
			local freshText = if binderTotal == 0
				then (if raised > 0 then "" else "on display")
				elseif inBinder.foil == 0 then `x{inBinder.normal}`
				elseif inBinder.normal == 0 then `{inBinder.foil} foil`
				else `x{inBinder.normal} · {inBinder.foil} foil`
			tile.countLabel.Text = if raised > 0
				then (if freshText == "" then `{raised} raised` else `{freshText} · {raised} raised`)
				else freshText
			tile.countLabel.Visible = true
		else
			CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
			tile.countLabel.Visible = false
		end
	end

	local percent = math.floor(ownedKinds / #Cards.List * 100)
	completionLabel.Text = `{ownedKinds}/{#Cards.List} cards · {percent}%`
	refreshDetail()
end

local function openDetail(card: Card)
	detailCard = card
	local best = getRaised(card.id)[1] -- open on the strongest beast, the most interesting one
	selectedBeastId = if best then best.id else nil
	refreshDetail()
	detail.Visible = detailCard ~= nil
end

local function buildTile(card: Card, parent: Instance): Tile
	local button = Instance.new("TextButton")
	button.Name = card.id
	button.LayoutOrder = card.number
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = parent

	local inner, stroke = addCardFrame(button)

	local countLabel = UIKit.label(button, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(0.5, 1)
	countLabel.Position = UDim2.new(0.5, 0, 1, -3)
	countLabel.Size = UDim2.new(1, -6, 0, 18)
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.BackgroundColor3 = UIKit.Colors.Panel
	countLabel.BackgroundTransparency = 0.2
	countLabel.ZIndex = 3
	UIKit.corner(countLabel, 6)

	local tile: Tile = { card = card, inner = inner, stroke = stroke, countLabel = countLabel }
	button.Activated:Connect(function()
		openDetail(card)
	end)
	return tile
end

-- Card shown large over the grid with its counts and value
local function buildDetail(parent: Frame)
	detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.Size = UDim2.fromScale(1, 1)
	detail.BackgroundColor3 = UIKit.Colors.Panel
	detail.ZIndex = 10
	detail.Visible = false
	detail.Active = true
	detail.Parent = parent
	UIKit.corner(detail, 14)

	-- Card on the left, info on the right: fits short landscape phone screens
	local cardHolder = Instance.new("Frame")
	cardHolder.Position = UDim2.fromOffset(16, 16)
	cardHolder.Size = UDim2.fromOffset(150, 214)
	cardHolder.BackgroundTransparency = 1
	cardHolder.ZIndex = 11
	cardHolder.Parent = detail
	detailInner, detailStroke = addCardFrame(cardHolder)

	detailName = UIKit.label(detail, "", Enum.Font.FredokaOne, 22, UIKit.Colors.Text)
	detailName.Position = UDim2.fromOffset(180, 12)
	detailName.Size = UDim2.new(1, -192, 0, 26)
	detailName.ZIndex = 11

	detailSubtitle = UIKit.label(detail, "", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	detailSubtitle.Position = UDim2.fromOffset(180, 38)
	detailSubtitle.Size = UDim2.new(1, -192, 0, 16)
	detailSubtitle.ZIndex = 11

	detailSummary = UIKit.label(detail, "", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	detailSummary.Position = UDim2.fromOffset(180, 56)
	detailSummary.Size = UDim2.new(1, -192, 0, 28)
	detailSummary.TextYAlignment = Enum.TextYAlignment.Top
	detailSummary.ZIndex = 11

	-- Beasts and fresh copies; scrolls when there are many, ends above the Back button
	raisedList = Instance.new("ScrollingFrame")
	raisedList.Position = UDim2.fromOffset(180, 88)
	raisedList.Size = UDim2.new(1, -184, 1, -150)
	raisedList.BackgroundTransparency = 1
	raisedList.BorderSizePixel = 0
	raisedList.ScrollBarThickness = 4
	raisedList.CanvasSize = UDim2.new()
	raisedList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	raisedList.ZIndex = 11
	raisedList.Parent = detail
	local raisedLayout = Instance.new("UIListLayout")
	raisedLayout.Padding = UDim.new(0, 6)
	raisedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	raisedLayout.Parent = raisedList

	local back = UIKit.button(detail, "Back", UIKit.Colors.Row)
	back.Position = UDim2.new(0, 180, 1, -56)
	back.Size = UDim2.new(1, -192, 0, 48)
	back.TextSize = 16
	back.ZIndex = 12
	back.Activated:Connect(function()
		detail.Visible = false
		detailCard = nil
	end)
end

local function buildPanel(parent: Instance)
	local list: ScrollingFrame
	panel, list = UIKit.panel(parent, "Binder", "Binder")

	-- Room for the completion line above the grid
	list.Position = UDim2.fromOffset(12, 100)
	list.Size = UDim2.new(1, -24, 1, -112)
	local listLayout = list:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	completionLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
	completionLabel.Position = UDim2.fromOffset(16, 62)
	completionLabel.Size = UDim2.new(1, -32, 0, 32)

	for _, card in Cards.List do
		table.insert(tiles, buildTile(card, list))
	end

	buildDetail(panel)
end

local function onCollectionChanged(payload: { stacks: { [string]: Owned }, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	collection = if typeof(payload.stacks) == "table" then payload.stacks else {}
	beasts = if typeof(payload.beasts) == "table" then payload.beasts else {}
	refresh()
end

local function toggle()
	detail.Visible = false
	detailCard = nil
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh() -- displayed cards may have sold since last time
	end
end

local function buildButton(parent: Instance)
	local button = UIKit.button(parent, "Binder (B)", UIKit.Colors.Row)
	button.Name = "BinderButton"
	-- Above the Build button on the middle-left
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, -66)
	button.Size = UDim2.fromOffset(96, 56)
	button.TextSize = 17
	button.Activated:Connect(toggle)
end

-- Batches bursts of card parts appearing or leaving into one refresh
local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refresh()
	end)
end

-- Refreshes when a card goes on display, sells or comes off, so "on display" counts stay right
local function watchOwnPlot()
	for _, connection in plotConnections do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return
	end
	local shelves = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotId):WaitForChild("Shelves")
	local function onChanged(instance: Instance)
		if instance:GetAttribute("CardId") ~= nil then
			queueRefresh()
		end
	end
	table.insert(plotConnections, shelves.DescendantAdded:Connect(onChanged))
	table.insert(plotConnections, shelves.DescendantRemoving:Connect(onChanged))
	queueRefresh()
end

-- The cards in the player's binder (not counting ones on display)
function BinderController.GetCollection(): { [string]: Owned }
	return collection
end

-- The player's raised beasts (not counting ones on display)
function BinderController.GetBeasts(): { [string]: Beast }
	return beasts
end

function BinderController.Start()
	local screenGui = UIController.GetScreenGui()
	buildPanel(screenGui)
	buildButton(screenGui)
	refresh()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == BINDER_KEY then
			toggle()
		end
	end)

	Remotes.CollectionChanged.OnClientEvent:Connect(onCollectionChanged)
	Remotes.RequestCollection:FireServer()
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	task.spawn(watchOwnPlot)
end

return BinderController
