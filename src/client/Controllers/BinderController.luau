--!strict
-- Binder: a two-page spread like a real binder, 9 card pockets per page, owned cards in colour with
-- counts, missing ones greyed out. Turn pages with the arrows.
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
type Stacks = { [string]: { [string]: Owned } } -- cardId -> grade -> counts
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One row in the card view: a stack of plain copies (one grade, foil or not) or a levelled card
type Entry = { key: string, power: number, value: number, beast: Beast?, grade: string, foil: boolean, count: number }

type Tile = {
	card: Card,
	button: TextButton,
	inner: Frame,
	stroke: UIStroke,
	countLabel: TextLabel,
	levelLabel: TextLabel, -- best grade and best levelled copy, e.g. "S · Lv 12"
}

local PAGE_COLUMNS = 3
local PAGE_ROWS = 3
local CARDS_PER_PAGE = PAGE_COLUMNS * PAGE_ROWS
local CARD_ASPECT = 0.7 -- width / height of a card pocket
local POCKET_GAP = 6
local BINDER_MAX_SIZE = Vector2.new(920, 600)
local COVER_COLOR = Color3.fromRGB(70, 40, 30) -- binder cover and spine
local PAGE_COLOR = Color3.fromRGB(40, 40, 54)
local TITLE_VALUE_ROOM = 96 -- right side of a row title kept free for the price
local BINDER_KEY = Enum.KeyCode.B
local HOW_TO_SELL = "To sell, put it in a Glass Showcase (customers) or Collector Case (players): walk up, press F, then Cards."
local BEAST_ROW_HEIGHT = 100
local STACK_ROW_HEIGHT = 80
local VALUE_COLOR = Color3.fromRGB(120, 230, 120)
local XP_BAR_COLOR = Color3.fromRGB(90, 160, 255)
local XP_TRACK_COLOR = Color3.fromRGB(25, 25, 35)

local player = Players.LocalPlayer

local BinderController = {}

local graded: Stacks = {}
local collection: { [string]: Owned } = {} -- graded, summed per card
local beasts: { [string]: Beast } = {}
local displayed: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local completionLabel: TextLabel
local pages: { Frame } = {} -- left and right page
local pageLabel: TextLabel
local spreadIndex = 1

local detail: Frame
local detailInner: Frame
local detailStroke: UIStroke
local detailName: TextLabel
local detailSubtitle: TextLabel
local detailSummary: TextLabel
local raisedList: ScrollingFrame
local detailCard: Card? = nil
local selectedKey: string? = nil -- the row shown on the big card (Entry.key)
local plotConnections: { RBXScriptConnection } = {}
local refreshQueued = false

local function getCount(source: { [string]: Owned }, cardId: string): Owned
	return source[cardId] or { normal = 0, foil = 0 }
end

-- This card's levelled cards in the binder, strongest (Power) first
local function getRaised(cardId: string): { Beast }
	local list: { Beast } = {}
	for _, beast in beasts do
		if beast.cardId == cardId then
			table.insert(list, beast)
		end
	end
	local card = Cards.ById[cardId]
	table.sort(list, function(a, b)
		return BeastRules.getPower(card, a.foil, a.level, a.stars, a.grade) > BeastRules.getPower(card, b.foil, b.level, b.stars, b.grade)
	end)
	return list
end

local function sumGrades(stacks: Stacks): { [string]: Owned }
	local summed: { [string]: Owned } = {}
	for cardId, byGrade in stacks do
		local total = { normal = 0, foil = 0 }
		for _, owned in byGrade do
			total.normal += owned.normal
			total.foil += owned.foil
		end
		summed[cardId] = total
	end
	return summed
end

-- Every row for this card: plain stacks per grade and foil, plus levelled cards, strongest first
local function getEntries(card: Card): { Entry }
	local entries: { Entry } = {}
	for grade, owned in graded[card.id] or {} do
		for _, foil in { true, false } do
			local count = if foil then owned.foil else owned.normal
			if count > 0 then
				table.insert(entries, {
					key = `stack:{grade}:{foil}`,
					power = BeastRules.getPower(card, foil, 1, BeastRules.START_STARS, grade),
					value = BeastRules.getValue(card, foil, 1, BeastRules.START_STARS, grade),
					grade = grade,
					foil = foil,
					count = count,
				})
			end
		end
	end
	for _, beast in getRaised(card.id) do
		table.insert(entries, {
			key = beast.id,
			power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
			value = BeastRules.getValue(card, beast.foil, beast.level, beast.stars, beast.grade),
			beast = beast,
			grade = beast.grade,
			foil = beast.foil,
			count = 1,
		})
	end
	table.sort(entries, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.value > b.value
	end)
	return entries
end

-- Best grade owned of this card (plain or levelled), or nil
local function getBestGrade(cardId: string): string?
	local best: string? = nil
	local function consider(grade: string)
		if not best or BeastRules.getGradeRank(grade) > BeastRules.getGradeRank(best) then
			best = grade
		end
	end
	for grade, owned in graded[cardId] or {} do
		if owned.normal + owned.foil > 0 then
			consider(grade)
		end
	end
	for _, beast in getRaised(cardId) do
		consider(beast.grade)
	end
	return best
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

local function selectEntry(key: string)
	selectedKey = key
	refreshDetail()
end

local function addValueText(row: GuiObject, value: number)
	local label = addRowText(row, string.format("$%.2f", value), 6, 20, Enum.Font.FredokaOne, 17, VALUE_COLOR)
	label.TextXAlignment = Enum.TextXAlignment.Right
end

local function describeStats(card: Card, entry: Entry, level: number, stars: number): string
	local stats = BeastRules.getStats(card, entry.foil, level, stars, entry.grade)
	return `Power {entry.power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`
end

-- One levelled card: grade, growth and value / stats / XP bar / what it needs for the next star
local function addBeastRow(card: Card, entry: Entry, beast: Beast, order: number)
	local row = makeRow(order, BEAST_ROW_HEIGHT, entry.key == selectedKey, function()
		selectEntry(entry.key)
	end)

	local growth = BeastRules.describeGrowth(beast.level, beast.stars)
	local title = `{if beast.foil then "FOIL · " else ""}{BeastRules.describeGrade(beast.grade)} · {growth}`
	local titleLabel = addRowText(row, title, 6, 20, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	titleLabel.Size = UDim2.new(1, -(TITLE_VALUE_ROOM + 10), 0, 20)
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	addValueText(row, entry.value)
	addRowText(row, describeStats(card, entry, beast.level, beast.stars), 28, 18, Enum.Font.GothamBold, 13, UIKit.Colors.Text)

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

	addRowText(row, BeastRules.describeStarProgress(beast.stars), 72, 24, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
end

-- Plain copies of one grade (level 1, 0 stars): how many, how strong and what they're worth
local function addStackRow(card: Card, entry: Entry, order: number)
	local row = makeRow(order, STACK_ROW_HEIGHT, entry.key == selectedKey, function()
		selectEntry(entry.key)
	end)
	local growth = BeastRules.describeGrowth(1, BeastRules.START_STARS)
	local title = `{if entry.foil then "FOIL · " else ""}{BeastRules.describeGrade(entry.grade)} · Owned {entry.count} · {growth}`
	local titleLabel = addRowText(row, title, 6, 20, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	titleLabel.Size = UDim2.new(1, -(TITLE_VALUE_ROOM + 10), 0, 20)
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	addValueText(row, entry.value)
	addRowText(row, describeStats(card, entry, 1, BeastRules.START_STARS), 28, 18, Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	addRowText(row, BeastRules.describeStarProgress(BeastRules.START_STARS), 48, 28, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
end

refreshDetail = function()
	local card = detailCard
	if not card then
		return
	end
	local shown = getCount(displayed, card.id)
	local entries = getEntries(card)
	local onDisplay = shown.normal + shown.foil
	if #entries + onDisplay == 0 then
		detail.Visible = false
		detailCard = nil
		return
	end

	-- Keep the selection valid: if that copy left the binder, show the strongest one
	local selected: Entry? = nil
	for _, entry in entries do
		if entry.key == selectedKey then
			selected = entry
		end
	end
	selected = selected or entries[1]
	selectedKey = if selected then selected.key else nil

	if selected then
		local beast = selected.beast
		local growth = {
			level = if beast then beast.level else 1,
			stars = if beast then beast.stars else BeastRules.START_STARS,
			grade = selected.grade,
		}
		CardFace.render(detailInner, detailStroke, card, selected.foil, true, growth)
	else
		CardFace.render(detailInner, detailStroke, card, shown.foil > 0)
	end

	local owned = 0
	for _, entry in entries do
		owned += entry.count
	end
	detailName.Text = card.name
	detailSubtitle.Text = string.format("#%02d · %s · %s", card.number, card.element, card.rarity)
	detailSummary.Text = string.format(
		"Owned %d%s%s",
		owned,
		if onDisplay > 0 then ` · {onDisplay} on display` else "",
		if #entries > 1 then " · strongest first, tap one to view it" else ""
	)

	clearRows()
	for index, entry in entries do
		local beast = entry.beast
		if beast then
			addBeastRow(card, entry, beast, index)
		else
			addStackRow(card, entry, index)
		end
	end
	local footer = UIKit.label(raisedList, HOW_TO_SELL, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	footer.LayoutOrder = #entries + 1
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
			-- Total copies in the binder; the level chip shows the best levelled one (details in the card view)
			local owned = binderTotal + raised
			tile.countLabel.Text = if owned > 0 then `Owned {owned}` else "on display"
			tile.countLabel.Visible = true
			-- Chip: best grade owned, plus the best levelled copy's level
			local bestGrade = getBestGrade(tile.card.id)
			local best = getRaised(tile.card.id)[1]
			local parts = {}
			if bestGrade then
				table.insert(parts, bestGrade)
			end
			if best then
				table.insert(parts, `Lv {best.level}`)
			end
			tile.levelLabel.Text = table.concat(parts, " · ")
			tile.levelLabel.Visible = #parts > 0
		else
			CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
			tile.countLabel.Visible = false
			tile.levelLabel.Visible = false
		end
	end

	local percent = math.floor(ownedKinds / #Cards.List * 100)
	completionLabel.Text = `{ownedKinds}/{#Cards.List} cards · {percent}%`
	refreshDetail()
end

local function openDetail(card: Card)
	detailCard = card
	local strongest = getEntries(card)[1] -- open on the strongest copy
	selectedKey = if strongest then strongest.key else nil
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

	local levelLabel = UIKit.label(button, "", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	levelLabel.Name = "Level"
	levelLabel.AnchorPoint = Vector2.new(0.5, 0)
	levelLabel.Position = UDim2.fromScale(0.5, 0.55) -- the empty band under the element letter
	levelLabel.Size = UDim2.fromOffset(60, 16)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.BackgroundColor3 = UIKit.Colors.Accent
	levelLabel.Visible = false
	levelLabel.ZIndex = 3
	UIKit.corner(levelLabel, 6)

	local tile: Tile = { card = card, button = button, inner = inner, stroke = stroke, countLabel = countLabel, levelLabel = levelLabel }
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

	-- Levelled cards and plain copies; scrolls when there are many, ends above the Back button
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

local function getSpreadCount(): number
	return math.max(1, math.ceil(#tiles / (CARDS_PER_PAGE * 2)))
end

-- Puts the tiles of the current spread into the two pages; the rest wait off-screen
local function showSpread(index: number)
	spreadIndex = math.clamp(index, 1, getSpreadCount())
	local first = (spreadIndex - 1) * CARDS_PER_PAGE * 2 + 1
	for position, tile in tiles do
		local offset = position - first
		if offset >= 0 and offset < CARDS_PER_PAGE * 2 then
			tile.button.LayoutOrder = offset
			tile.button.Parent = pages[if offset < CARDS_PER_PAGE then 1 else 2]
		else
			tile.button.Parent = nil
		end
	end
	local leftPage = spreadIndex * 2 - 1
	pageLabel.Text = `Pages {leftPage}-{leftPage + 1} of {getSpreadCount() * 2}`
end

-- Pockets fill each page 3 x 3 at card proportions, whatever the screen size
local function fitPockets(page: Frame, grid: UIGridLayout)
	local size = page.AbsoluteSize
	local height = (size.Y - POCKET_GAP * (PAGE_ROWS + 1)) / PAGE_ROWS
	local width = math.min(height * CARD_ASPECT, (size.X - POCKET_GAP * (PAGE_COLUMNS + 1)) / PAGE_COLUMNS)
	width = math.max(width, 1)
	grid.CellSize = UDim2.fromOffset(math.floor(width), math.floor(width / CARD_ASPECT))
end

local function buildPage(spread: Frame, isLeft: boolean): Frame
	local page = Instance.new("Frame")
	page.Name = if isLeft then "LeftPage" else "RightPage"
	page.Position = if isLeft then UDim2.fromOffset(8, 8) else UDim2.new(0.5, 6, 0, 8)
	page.Size = UDim2.new(0.5, -14, 1, -16)
	page.BackgroundColor3 = PAGE_COLOR
	page.Parent = spread
	UIKit.corner(page, 8)

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(POCKET_GAP, POCKET_GAP)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = PAGE_COLUMNS -- 3 pockets per row, so each page is 3 x 3
	grid.Parent = page
	page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitPockets(page, grid)
	end)
	fitPockets(page, grid)
	return page
end

local function buildPanel(parent: Instance)
	local list: ScrollingFrame
	panel, list = UIKit.panel(parent, "Binder", "Binder")
	list:Destroy() -- the binder uses pages instead of a scrolling list
	-- Bigger than other panels: it's the main way to look at your collection
	panel.Size = UDim2.fromScale(0.96, 0.9)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = BINDER_MAX_SIZE
	end

	completionLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
	completionLabel.Position = UDim2.fromOffset(16, 56)
	completionLabel.Size = UDim2.new(1, -32, 0, 24)

	-- The open binder: cover with a spine down the middle and a page either side
	local spread = Instance.new("Frame")
	spread.Name = "Spread"
	spread.Position = UDim2.fromOffset(12, 84)
	spread.Size = UDim2.new(1, -24, 1, -144)
	spread.BackgroundColor3 = COVER_COLOR
	spread.Parent = panel
	UIKit.corner(spread, 12)
	local spine = Instance.new("Frame")
	spine.Name = "Spine"
	spine.AnchorPoint = Vector2.new(0.5, 0)
	spine.Position = UDim2.fromScale(0.5, 0)
	spine.Size = UDim2.new(0, 4, 1, 0)
	spine.BackgroundColor3 = Color3.new(0, 0, 0)
	spine.BackgroundTransparency = 0.5
	spine.BorderSizePixel = 0
	spine.Parent = spread
	pages = { buildPage(spread, true), buildPage(spread, false) }

	-- Page turning
	local previous = UIKit.button(panel, "<", UIKit.Colors.Row)
	previous.Position = UDim2.new(0, 12, 1, -54)
	previous.Size = UDim2.fromOffset(64, 46)
	previous.Activated:Connect(function()
		showSpread(spreadIndex - 1)
	end)
	local nextButton = UIKit.button(panel, ">", UIKit.Colors.Row)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.new(1, -12, 1, -54)
	nextButton.Size = UDim2.fromOffset(64, 46)
	nextButton.Activated:Connect(function()
		showSpread(spreadIndex + 1)
	end)
	pageLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
	pageLabel.Position = UDim2.new(0, 84, 1, -54)
	pageLabel.Size = UDim2.new(1, -168, 0, 46)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center

	for _, card in Cards.List do
		table.insert(tiles, buildTile(card, panel))
	end
	showSpread(1)

	buildDetail(panel)
end

local function onCollectionChanged(payload: { stacks: Stacks, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	graded = if typeof(payload.stacks) == "table" then payload.stacks else {}
	collection = sumGrades(graded)
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

-- The cards in the player's binder (not counting ones on display), summed over grades
function BinderController.GetCollection(): { [string]: Owned }
	return collection
end

-- The plain copies in the binder by card, then grade
function BinderController.GetGradedStacks(): Stacks
	return graded
end

-- The player's levelled cards (not counting ones on display)
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
