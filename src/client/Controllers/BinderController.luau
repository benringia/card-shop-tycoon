--!strict
-- Binder: a two-page spread like a real binder, 9 card pockets per page, owned cards in colour with
-- counts, missing ones greyed out. Turn pages with the arrows; search and filter chips narrow the pages
-- (built for card lists far bigger than Set 1). Hovering a pocket with a mouse shows a tooltip.
-- Only the pockets on the open spread are drawn, so a big collection stays cheap.
-- Tap an owned card to see it large. Cards earn money only from a showcase, so the binder just
-- shows what you have; cards on display in your cases count towards completion.
-- The server sends the binder whenever it changes; displayed cards are read from your plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local PocketLayout = require(ClientUtil:WaitForChild("PocketLayout"))
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

-- 3 x 3 pockets like a real binder; short screens (landscape phones) get fewer, bigger pockets
local POCKET_OPTIONS: PocketLayout.Options = {
	aspect = 0.7, -- card width / height
	gap = 6,
	preferredColumns = 3,
	preferredRows = 3,
	minWidth = 70,
	maxColumns = 5,
	maxRows = 3,
	minPockets = 4,
}
local BINDER_MAX_SIZE = Vector2.new(920, 600)
local COVER_COLOR = Color3.fromRGB(70, 40, 30) -- binder cover and spine
local PAGE_COLOR = Color3.fromRGB(40, 40, 54)
local TITLE_VALUE_ROOM = 96 -- right side of a row title kept free for the price
local TOOLTIP_WIDTH = 230
local FILTER_CHIP_WIDTH = 84
local ALL_FILTER, OWNED_FILTER, MISSING_FILTER = "All", "Owned", "Missing"
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
local working: { [string]: string } = {} -- beastId -> job, for cards working in the shop
local assignButton: TextButton
local jobChooser: Frame
local assignTarget: (string | { cardId: string, foil: boolean, grade: string })? = nil
local displayed: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local completionLabel: TextLabel
local pages: { Frame } = {} -- left and right page
local pageLabel: TextLabel
local spreadIndex = 1
local pocketsPerPage = POCKET_OPTIONS.preferredColumns * POCKET_OPTIONS.preferredRows
local pageGrids: { UIGridLayout } = {}
local visibleTiles: { Tile } = {} -- tiles that pass the search and filter, in card order
local binderFilter = ALL_FILTER -- All, Owned, Missing or a rarity name
local searchText = ""
local filterButtons: { [string]: TextButton } = {}
local tooltip: Frame
local tooltipText: TextLabel

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
local refreshAssignButton: (selected: Entry?) -> ()

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
	local job = working[beast.id]
	local title = `{if beast.foil then "FOIL · " else ""}{BeastRules.describeGrade(beast.grade)} · {growth}{if job then ` · Working: {job}` else ""}`
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

-- "Assign to job" for the selected copy, or why it can't be assigned
refreshAssignButton = function(selected: Entry?)
	jobChooser.Visible = false
	local slots = player:GetAttribute("JobSlots")
	local used = player:GetAttribute("JobsUsed")
	local slotCount = if typeof(slots) == "number" then slots else 0
	local usedCount = if typeof(used) == "number" then used else 0
	local beast = if selected then selected.beast else nil
	local job = if beast then working[beast.id] else nil
	local text, ready
	if not selected then
		text, ready = "Assign to job", false
	elseif job then
		text, ready = `Working: {job}`, false
	elseif slotCount == 0 then
		text, ready = `Jobs at shop Lv {Jobs.UNLOCK_LEVEL}`, false
	elseif usedCount >= slotCount then
		text, ready = "Job slots full", false
	else
		text, ready = "Assign to job", true
	end
	assignButton.Text = text
	assignButton.BackgroundColor3 = if ready then UIKit.Colors.Accent else UIKit.Colors.Locked
	assignButton.AutoButtonColor = ready
	assignTarget = if not ready or not selected
		then nil
		elseif beast then beast.id
		else { cardId = (detailCard :: Card).id, foil = selected.foil, grade = selected.grade }
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
	refreshAssignButton(selected)

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

-- Copies of this card the player has: in the binder (plain + levelled) and on display
local function getOwnedCounts(cardId: string): (number, number)
	local inBinder = getCount(collection, cardId)
	local shown = getCount(displayed, cardId)
	return inBinder.normal + inBinder.foil + #getRaised(cardId), shown.normal + shown.foil
end

local function isCollected(cardId: string): boolean
	local owned, onDisplay = getOwnedCounts(cardId)
	return owned + onDisplay > 0
end

-- Draws one pocket (only called for pockets on the open spread)
local function renderTile(tile: Tile)
	local cardId = tile.card.id
	local inBinder = getCount(collection, cardId)
	local shown = getCount(displayed, cardId)
	local owned, onDisplay = getOwnedCounts(cardId)
	if owned + onDisplay == 0 then
		CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
		tile.countLabel.Visible = false
		tile.levelLabel.Visible = false
		return
	end
	local raised = getRaised(cardId)
	local hasFoilBeast = false
	for _, beast in raised do
		hasFoilBeast = hasFoilBeast or beast.foil
	end
	CardFace.render(tile.inner, tile.stroke, tile.card, inBinder.foil + shown.foil > 0 or hasFoilBeast, false)
	-- Total copies in the binder; the chip shows the best grade and best levelled one (details in the card view)
	tile.countLabel.Text = if owned > 0 then `Owned {owned}` else "on display"
	tile.countLabel.Visible = true
	local bestGrade = getBestGrade(cardId)
	local parts = {}
	if bestGrade then
		table.insert(parts, bestGrade)
	end
	if raised[1] then
		table.insert(parts, `Lv {raised[1].level}`)
	end
	for _, beast in raised do
		if working[beast.id] then
			table.insert(parts, "Job")
			break
		end
	end
	tile.levelLabel.Text = table.concat(parts, " · ")
	tile.levelLabel.Visible = #parts > 0
end

local function passesFilter(card: Card): boolean
	if searchText ~= "" then
		local query = string.lower(searchText)
		local number = tonumber((string.gsub(query, "#", "")))
		local nameMatch = string.find(string.lower(card.name), query, 1, true) ~= nil
		if not nameMatch and number ~= card.number then
			return false
		end
	end
	if binderFilter == OWNED_FILTER then
		return isCollected(card.id)
	elseif binderFilter == MISSING_FILTER then
		return not isCollected(card.id)
	elseif binderFilter ~= ALL_FILTER then
		return card.rarity == binderFilter
	end
	return true
end

local function getSpreadCount(): number
	return math.max(1, math.ceil(#visibleTiles / (pocketsPerPage * 2)))
end

-- Puts the tiles of the current spread into the two pages and draws them; the rest wait off-screen
local function showSpread(index: number)
	spreadIndex = math.clamp(index, 1, getSpreadCount())
	local first = (spreadIndex - 1) * pocketsPerPage * 2 + 1
	local shownSet: { [Tile]: boolean } = {}
	for position, tile in visibleTiles do
		local offset = position - first
		if offset >= 0 and offset < pocketsPerPage * 2 then
			shownSet[tile] = true
			tile.button.LayoutOrder = offset
			tile.button.Parent = pages[if offset < pocketsPerPage then 1 else 2]
			renderTile(tile)
		end
	end
	for _, tile in tiles do
		if not shownSet[tile] then
			tile.button.Parent = nil
		end
	end
	if #visibleTiles == 0 then
		pageLabel.Text = "No cards match"
		return
	end
	local leftPage = spreadIndex * 2 - 1
	local cardWord = if #visibleTiles == 1 then "card" else "cards"
	pageLabel.Text = `Pages {leftPage}-{leftPage + 1} of {getSpreadCount() * 2} · {#visibleTiles} {cardWord}`
end

local function refreshFilterButtons()
	for filter, button in filterButtons do
		button.BackgroundColor3 = if filter == binderFilter then UIKit.Colors.Accent else UIKit.Colors.Row
	end
end

-- Re-applies search and filter, then redraws the open spread (keeping the page when possible)
local function applyFilter()
	visibleTiles = {}
	for _, tile in tiles do
		if passesFilter(tile.card) then
			table.insert(visibleTiles, tile)
		end
	end
	refreshFilterButtons()
	showSpread(spreadIndex)
end

local function refresh()
	displayed = readDisplayedCards()
	local collected = 0
	for _, card in Cards.List do
		if isCollected(card.id) then
			collected += 1
		end
	end
	local percent = math.floor(collected / #Cards.List * 100)
	completionLabel.Text = `{collected}/{#Cards.List} cards · {percent}%`
	applyFilter()
	refreshDetail()
end

-- Tooltip (mouse only) -------------------------------------------------------------------------------

local function describeTooltip(card: Card): string
	local lines = { card.name, `{card.rarity} · {card.element} · #{card.number}` }
	local owned, onDisplay = getOwnedCounts(card.id)
	if owned + onDisplay == 0 then
		table.insert(lines, "Not collected yet")
		return table.concat(lines, "\n")
	end
	table.insert(lines, `Owned {owned}{if onDisplay > 0 then ` · {onDisplay} on display` else ""}`)
	local entries = getEntries(card)
	local bestGrade = getBestGrade(card.id)
	if bestGrade then
		table.insert(lines, `Best grade {bestGrade}`)
	end
	local raised = getRaised(card.id)
	if raised[1] then
		table.insert(lines, `Best level Lv {raised[1].level}`)
	end
	if entries[1] then
		local low, high = math.huge, 0
		for _, entry in entries do
			low = math.min(low, entry.value)
			high = math.max(high, entry.value)
		end
		table.insert(lines, `Strongest: Power {entries[1].power}`)
		table.insert(lines, if low == high then string.format("Worth $%.2f", high) else string.format("Worth $%.2f - $%.2f", low, high))
	end
	table.insert(lines, "Tap for details")
	return table.concat(lines, "\n")
end

local function showTooltip(tile: Tile)
	-- Pockets under the open card view still get mouse events; no tooltip through it
	if not UserInputService.MouseEnabled or not tile.button.Parent or detail.Visible then
		return
	end
	tooltipText.Text = describeTooltip(tile.card)
	-- Beside the pocket, kept on screen
	local screen = tooltip.Parent :: any
	local origin: Vector2 = screen.AbsolutePosition
	local screenSize: Vector2 = screen.AbsoluteSize
	local button = tile.button
	local x = button.AbsolutePosition.X - origin.X + button.AbsoluteSize.X + 8
	if x + TOOLTIP_WIDTH > screenSize.X then
		x = button.AbsolutePosition.X - origin.X - TOOLTIP_WIDTH - 8
	end
	local y = button.AbsolutePosition.Y - origin.Y
	tooltip.Position = UDim2.fromOffset(math.max(0, x), math.clamp(y, 0, math.max(0, screenSize.Y - tooltip.AbsoluteSize.Y)))
	tooltip.Visible = true
end

local function hideTooltip()
	tooltip.Visible = false
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
		hideTooltip()
		openDetail(card)
	end)
	button.MouseEnter:Connect(function()
		showTooltip(tile)
	end)
	button.MouseLeave:Connect(hideTooltip)
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

	-- Assign the selected copy to a shop job (left half), Back (right half)
	assignButton = UIKit.button(detail, "Assign to job", UIKit.Colors.Locked)
	assignButton.Position = UDim2.new(0, 180, 1, -56)
	assignButton.Size = UDim2.new(0.5, -98, 0, 48)
	assignButton.TextSize = 15
	assignButton.ZIndex = 12
	assignButton.Activated:Connect(function()
		if assignTarget then
			jobChooser.Visible = true
		end
	end)

	jobChooser = Instance.new("Frame")
	jobChooser.Name = "JobChooser"
	jobChooser.AnchorPoint = Vector2.new(0.5, 1)
	jobChooser.Position = UDim2.new(0.5, 0, 1, -62)
	jobChooser.Size = UDim2.fromOffset(300, 132)
	jobChooser.BackgroundColor3 = UIKit.Colors.Panel
	jobChooser.Visible = false
	jobChooser.ZIndex = 20
	jobChooser.Parent = detail
	UIKit.corner(jobChooser, 12)
	local chooserStroke = Instance.new("UIStroke")
	chooserStroke.Color = UIKit.Colors.Accent
	chooserStroke.Parent = jobChooser
	local chooserTitle = UIKit.label(jobChooser, "Which job?", Enum.Font.GothamBold, 16, UIKit.Colors.Text)
	chooserTitle.Position = UDim2.fromOffset(12, 8)
	chooserTitle.Size = UDim2.new(1, -24, 0, 22)
	chooserTitle.ZIndex = 21
	for index, job in Jobs.JOBS do
		local choice = UIKit.button(jobChooser, job, UIKit.Colors.Accent)
		choice.Position = UDim2.new((index - 1) / #Jobs.JOBS, if index == 1 then 12 else 4, 0, 36)
		choice.Size = UDim2.new(1 / #Jobs.JOBS, -16, 0, 48)
		choice.TextSize = 15
		choice.ZIndex = 21
		choice.Activated:Connect(function()
			jobChooser.Visible = false
			if assignTarget then
				Remotes.AssignJob:FireServer(assignTarget, job)
			end
		end)
	end
	local cancel = UIKit.button(jobChooser, "Cancel", UIKit.Colors.Row)
	cancel.Position = UDim2.new(0, 12, 0, 90)
	cancel.Size = UDim2.new(1, -24, 0, 34)
	cancel.TextSize = 14
	cancel.ZIndex = 21
	cancel.Activated:Connect(function()
		jobChooser.Visible = false
	end)

	local back = UIKit.button(detail, "Back", UIKit.Colors.Row)
	back.Position = UDim2.new(0.5, 88, 1, -56)
	back.Size = UDim2.new(0.5, -100, 0, 48)
	back.TextSize = 16
	back.ZIndex = 12
	back.Activated:Connect(function()
		detail.Visible = false
		detailCard = nil
	end)
end

-- Sizes the pockets for the pages' size on screen; a layout change re-pages the binder
local function fitPockets()
	local page = pages[1]
	if not page then
		return
	end
	local layout = PocketLayout.choose(page.AbsoluteSize.X, page.AbsoluteSize.Y, POCKET_OPTIONS)
	for _, grid in pageGrids do
		grid.CellSize = UDim2.fromOffset(layout.width, layout.height)
		grid.FillDirectionMaxCells = layout.columns
	end
	local perPage = layout.columns * layout.rows
	if perPage ~= pocketsPerPage then
		-- Keep the first card of the current spread in view
		local firstCard = (spreadIndex - 1) * pocketsPerPage * 2 + 1
		pocketsPerPage = perPage
		spreadIndex = math.floor((firstCard - 1) / (pocketsPerPage * 2)) + 1
		if #visibleTiles > 0 then
			showSpread(spreadIndex)
		end
	end
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
	grid.CellPadding = UDim2.fromOffset(POCKET_OPTIONS.gap, POCKET_OPTIONS.gap)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = POCKET_OPTIONS.preferredColumns
	grid.Parent = page
	table.insert(pageGrids, grid)
	page:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPockets)
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

	completionLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
	completionLabel.Position = UDim2.fromOffset(16, 56)
	completionLabel.Size = UDim2.fromOffset(170, 32)

	-- Search by name or number, then filter chips (they scroll sideways on narrow screens)
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(190, 56)
	search.Size = UDim2.fromOffset(180, 32)
	search.BackgroundColor3 = UIKit.Colors.Row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.Gotham
	search.TextSize = 14
	search.TextColor3 = UIKit.Colors.Text
	search.Parent = panel
	UIKit.corner(search, 8)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		spreadIndex = 1
		applyFilter()
	end)

	local chips = Instance.new("ScrollingFrame")
	chips.Name = "Filters"
	chips.Position = UDim2.fromOffset(380, 54)
	chips.Size = UDim2.new(1, -392, 0, 38)
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.ScrollBarThickness = 3
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.CanvasSize = UDim2.new()
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.Parent = panel
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 6)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chips
	local filters = { ALL_FILTER, OWNED_FILTER, MISSING_FILTER }
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	for _, name in rarities do
		table.insert(filters, name)
	end
	for index, filter in filters do
		local chip = UIKit.button(chips, filter, UIKit.Colors.Row)
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(FILTER_CHIP_WIDTH, 32)
		chip.TextSize = 13
		local tier = Rarities.Tiers[filter]
		if tier then
			chip.TextColor3 = tier.color
		end
		chip.Activated:Connect(function()
			binderFilter = filter
			spreadIndex = 1
			applyFilter()
		end)
		filterButtons[filter] = chip
	end

	-- The open binder: cover with a spine down the middle and a page either side
	local spread = Instance.new("Frame")
	spread.Name = "Spread"
	spread.Position = UDim2.fromOffset(12, 96)
	spread.Size = UDim2.new(1, -24, 1, -156)
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
	fitPockets()

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

	tooltip = Instance.new("Frame")
	tooltip.Name = "BinderTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Panel
	tooltip.ZIndex = 50
	tooltip.Visible = false
	tooltip.Parent = parent
	UIKit.corner(tooltip, 8)
	local tooltipStroke = Instance.new("UIStroke")
	tooltipStroke.Color = UIKit.Colors.Accent
	tooltipStroke.Parent = tooltip
	local tooltipPadding = Instance.new("UIPadding")
	tooltipPadding.PaddingTop = UDim.new(0, 8)
	tooltipPadding.PaddingBottom = UDim.new(0, 8)
	tooltipPadding.PaddingLeft = UDim.new(0, 10)
	tooltipPadding.PaddingRight = UDim.new(0, 10)
	tooltipPadding.Parent = tooltip
	tooltipText = UIKit.label(tooltip, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	tooltipText.Size = UDim2.fromScale(1, 0)
	tooltipText.AutomaticSize = Enum.AutomaticSize.Y
	tooltipText.ZIndex = 51

	for _, card in Cards.List do
		table.insert(tiles, buildTile(card, panel))
	end
	applyFilter()

	buildDetail(panel)
	panel:GetPropertyChangedSignal("Visible"):Connect(hideTooltip)
end

local function onCollectionChanged(payload: { stacks: Stacks, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	graded = if typeof(payload.stacks) == "table" then payload.stacks else {}
	collection = sumGrades(graded)
	beasts = if typeof(payload.beasts) == "table" then payload.beasts else {}
	working = if typeof((payload :: any).working) == "table" then (payload :: any).working else {}
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
-- Cards working a shop job: beastId -> job
function BinderController.GetWorking(): { [string]: string }
	return working
end

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
	-- Job slots opening or filling up change the card view's Assign button
	for _, name in { "JobSlots", "JobsUsed" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if detail.Visible then
				refreshDetail()
			end
		end)
	end
	Remotes.RequestCollection:FireServer()
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	task.spawn(watchOwnPlot)
end

return BinderController
