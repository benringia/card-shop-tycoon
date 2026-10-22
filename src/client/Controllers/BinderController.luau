--!strict
-- Binder: a full-screen book per set (set tabs on its edge). Spread 1 is the set's cover and page 1; later
-- spreads are two pages of pockets, owned cards in colour with counts, missing ones as "?" slots. Turn pages
-- with the arrows or Q/E (A/D: first/last); Filters (F) narrow and sort the pages while the book shrinks aside.
-- Hovering a pocket with a mouse shows a tooltip.
-- Only the pockets on the open spread are drawn, so a big collection stays cheap.
-- Tap an owned card to see it large. Cards earn money only from a showcase, so the binder just
-- shows what you have; cards on display in your cases count towards completion.
-- The server sends the binder whenever it changes; displayed cards are read from your plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Party = require(Config:WaitForChild("Party"))
local Items = require(Config:WaitForChild("Items"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Collection = require(Config:WaitForChild("Collection"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BinderSpreads = require(Shared:WaitForChild("Util"):WaitForChild("BinderSpreads"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local PocketLayout = require(ClientUtil:WaitForChild("PocketLayout"))
local UIController = require(Controllers:WaitForChild("UIController"))
local RarityGuideController = require(Controllers:WaitForChild("RarityGuideController"))

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

-- A pocket is the card plus a chip row under it (copies owned, best grade and level)
local CARD_ASPECT = 0.7
local CHIP_ROW = 22 -- pixels
-- The card view: a big card on the left, the copies list and buttons right of it
local DETAIL_CARD = Vector2.new(220, 314)
local DETAIL_X = 16 + DETAIL_CARD.X + 14
-- 3 x 3 pockets like a real binder; short screens get fewer, bigger pockets (3 a page at least, so the
-- card text stays readable)
local POCKET_OPTIONS: PocketLayout.Options = {
	aspect = 0.63, -- pocket width / height: a 0.7 card plus the chip row
	gap = 6,
	preferredColumns = 3,
	preferredRows = 3,
	minWidth = 110,
	maxColumns = 5,
	maxRows = 3,
	minPockets = 3,
}
local TITLE_VALUE_ROOM = 96 -- right side of a row title kept free for the price
local TOOLTIP_WIDTH = 230
local ALL_FILTER, OWNED_FILTER, MISSING_FILTER = "All", "Owned", "Missing"
local PAGE_KEYS = { [Enum.KeyCode.Q] = -1, [Enum.KeyCode.E] = 1 }
local BINDER_KEY = Enum.KeyCode.B
local BAG_KEY = Enum.KeyCode.I -- inventory: the binder's Bag tab
local BAG_PRIORITY_MARGIN = 100 -- above every built-in binding (the camera's I zoom included)
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
local partied: { [string]: boolean } = {} -- beastId -> in the party
local hintToast: number? = nil -- toast from BinderController.Open, hidden once a card is tapped
local partySlots: { [number]: string } = {} -- party slot -> beastId
local assignButton: TextButton
local jobChooser: Frame
local assignTarget: (string | { cardId: string, foil: boolean, grade: string })? = nil
local partyButton: TextButton
local partyChooser: Frame
local partySlotButtons: { TextButton } = {}
local partyTarget: (string | { cardId: string, foil: boolean, grade: string })? = nil
local displayed: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local currentSet = Collection.SETS[1]
local book: Frame
local bookHolder: Frame
local bookScale: UIScale
local coverPage: Frame
local coverTitle: TextLabel
local coverProgress: TextLabel
local coverEmblem: TextLabel
local setTabs: { [string]: TextButton } = {}
local progressName: TextLabel
local progressCount: TextLabel
local progressValue: TextLabel
local progressFill: Frame
local filtersPanel: Frame
local setFiltersOpen: (open: boolean) -> ()
local rarityGuideButton: TextButton
local showButtons: { [string]: TextButton } = {}
local sortButtons: { [string]: TextButton } = {}
local rarityChips: { [string]: TextButton } = {}
local rarityPicks: { [string]: boolean } = {} -- none picked = every rarity
local showFilter = ALL_FILTER -- All, Owned or Missing
local sortBy = "Set" -- Set (card number), Value, Copies or Rarity
local bagOverlay: Frame -- the Bag tab (built in buildBag); the card tooltip stays off while it shows
local pages: { Frame } = {} -- left and right page
local pageLabel: TextLabel
local spreadIndex = 1
local pocketsPerPage = POCKET_OPTIONS.preferredColumns * POCKET_OPTIONS.preferredRows
local pageGrids: { UIGridLayout } = {}
local visibleTiles: { Tile } = {} -- tiles that pass the search and filter, in card order
local searchText = ""
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
	local status = if job then ` · Working: {job}` elseif partied[beast.id] then " · In party" else ""
	local title = `{if beast.foil then "FOIL · " else ""}{BeastRules.describeGrade(beast.grade)} · {growth}{status}`
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

-- "Add to party" for the selected copy, or why it can't join
local function refreshPartyButton(selected: Entry?)
	partyChooser.Visible = false
	local beast = if selected then selected.beast else nil
	local text, ready
	if not selected then
		text, ready = "Add to party", false
	elseif beast and partied[beast.id] then
		text, ready = "In party", false
	elseif beast and working[beast.id] then
		text, ready = "Working", false
	else
		text, ready = "Add to party", true
	end
	partyButton.Text = text
	partyButton.BackgroundColor3 = if ready then UIKit.Colors.Accent else UIKit.Colors.Locked
	partyButton.AutoButtonColor = ready
	partyTarget = if not ready or not selected
		then nil
		elseif beast then beast.id
		else { cardId = (detailCard :: Card).id, foil = selected.foil, grade = selected.grade }
end

-- Slot buttons say which card each party slot holds now
local function refreshPartyChooser()
	for slot, button in partySlotButtons do
		local beast = beasts[partySlots[slot] or ""]
		local card = if beast then Cards.ById[beast.cardId] else nil
		button.Text = if card then `Slot {slot}\n{card.name}` else `Slot {slot}\nempty`
	end
end

-- "Assign to job" for the selected copy, or why it can't be assigned
refreshAssignButton = function(selected: Entry?)
	refreshPartyButton(selected)
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
	elseif beast and partied[beast.id] then
		text, ready = "In party", false
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
	-- The tile shows the stats of the best copy: the strongest levelled one, else a plain one of the best grade
	local bestGrade = getBestGrade(cardId)
	local strongest = raised[1]
	local growth = if strongest
		then { level = strongest.level, stars = strongest.stars, grade = strongest.grade }
		else { level = 1, stars = BeastRules.START_STARS, grade = bestGrade or BeastRules.DEFAULT_GRADE }
	CardFace.render(tile.inner, tile.stroke, tile.card, inBinder.foil + shown.foil > 0 or hasFoilBeast, false, growth)
	-- Total copies in the binder; the chip shows the best grade and best levelled one (details in the card view)
	tile.countLabel.Visible = true
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
	for _, beast in raised do
		if partied[beast.id] then
			table.insert(parts, "Party")
			break
		end
	end
	tile.levelLabel.Text = table.concat(parts, " · ")
	tile.levelLabel.Visible = #parts > 0
	-- With chips the count shrinks to the left part of the row
	local short = #parts > 0
	tile.countLabel.Size = UDim2.new(if short then 0.36 else 1, 0, 0, CHIP_ROW - 3)
	tile.countLabel.Text = if owned == 0 then "shown" elseif short then `x{owned}` else `Owned {owned}`
end

local function passesFilter(card: Card): boolean
	if card.set ~= currentSet then
		return false
	end
	if searchText ~= "" then
		local query = string.lower(searchText)
		local number = tonumber((string.gsub(query, "#", "")))
		local nameMatch = string.find(string.lower(card.name), query, 1, true) ~= nil
		if not nameMatch and number ~= card.number then
			return false
		end
	end
	if showFilter == OWNED_FILTER and not isCollected(card.id) then
		return false
	elseif showFilter == MISSING_FILTER and isCollected(card.id) then
		return false
	end
	if next(rarityPicks) ~= nil and not rarityPicks[card.rarity] then
		return false
	end
	return true
end

-- Best value among your copies of a card (0 if you have none)
local function getBestValue(card: Card): number
	local best = 0
	for _, entry in getEntries(card) do
		best = math.max(best, entry.value)
	end
	return best
end

local function sortTiles(list: { Tile })
	local keys: { [Tile]: number } = {}
	for _, tile in list do
		local card = tile.card
		if sortBy == "Value" then
			keys[tile] = -getBestValue(card)
		elseif sortBy == "Copies" then
			local owned, onDisplay = getOwnedCounts(card.id)
			keys[tile] = -(owned + onDisplay)
		elseif sortBy == "Rarity" then
			local tier = Rarities.Tiers[card.rarity]
			keys[tile] = -(if tier then tier.order else 0)
		else
			keys[tile] = 0
		end
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then
			return keys[a] < keys[b]
		end
		return a.card.number < b.card.number
	end)
end

local function getSpreadCount(): number
	return BinderSpreads.count(#visibleTiles, pocketsPerPage)
end

-- Puts the tiles of the current spread into the pages and draws them; the rest wait off-screen.
-- Spread 1 is the set's cover (left page) and page 1 (right page).
local function showSpread(index: number)
	spreadIndex = math.clamp(index, 1, getSpreadCount())
	local first, last = BinderSpreads.cards(spreadIndex, #visibleTiles, pocketsPerPage)
	local shownSet: { [Tile]: boolean } = {}
	for position = first, last do
		local tile = visibleTiles[position]
		local offset = position - first
		shownSet[tile] = true
		tile.button.LayoutOrder = offset
		if spreadIndex == 1 then
			tile.button.Parent = pages[2]
		else
			tile.button.Parent = pages[if offset < pocketsPerPage then 1 else 2]
		end
		renderTile(tile)
	end
	for _, tile in tiles do
		if not shownSet[tile] then
			tile.button.Parent = nil
		end
	end
	coverPage.Visible = spreadIndex == 1
	pageLabel.Text = BinderSpreads.label(spreadIndex, BinderSpreads.pages(#visibleTiles, pocketsPerPage))
end

-- Lights up the Filters panel's choices
local function refreshFilterButtons()
	for value, button in showButtons do
		button.BackgroundColor3 = if value == showFilter then UIKit.Colors.Accent else UIKit.Colors.Row
	end
	for value, button in sortButtons do
		button.BackgroundColor3 = if value == sortBy then UIKit.Colors.Accent else UIKit.Colors.Row
	end
	for rarity, chip in rarityChips do
		local tier = Rarities.Tiers[rarity]
		local color = if tier then tier.color else UIKit.Colors.Accent
		chip.BackgroundColor3 = if rarityPicks[rarity] then color else UIKit.Colors.Row
	end
end

-- Re-applies search, filters and sort, then redraws the open spread (keeping the page when possible)
local function applyFilter()
	visibleTiles = {}
	for _, tile in tiles do
		if passesFilter(tile.card) then
			table.insert(visibleTiles, tile)
		end
	end
	sortTiles(visibleTiles)
	refreshFilterButtons()
	showSpread(spreadIndex)
end

-- The current set's cover page, set tabs and the progress card
local function refreshSet()
	local owned, total, value = 0, 0, 0
	for _, card in Cards.BySet[currentSet] or {} do
		total += 1
		if isCollected(card.id) then
			owned += 1
		end
		for _, entry in getEntries(card) do
			value += entry.value * entry.count
		end
	end
	local color = Collection.SET_COLORS[currentSet] or UIKit.Colors.Accent
	coverPage.BackgroundColor3 = color
	coverTitle.Text = string.upper(currentSet)
	coverProgress.Text = `{owned} / {total}`
	coverEmblem.Text = Collection.SET_EMBLEMS[currentSet] or "✨"
	progressName.Text = currentSet
	progressCount.Text = `📖 {owned} / {total}`
	progressValue.Text = string.format("$%.2f", value)
	progressFill.Size = UDim2.fromScale(if total > 0 then owned / total else 0, 1)
	progressFill.BackgroundColor3 = color
	for set, tab in setTabs do
		local active = set == currentSet
		tab.BackgroundColor3 = if active then (Collection.SET_COLORS[set] or UIKit.Colors.Accent) else UIKit.Colors.Row
		tab.Size = UDim2.fromOffset(if active then 76 else 64, 70)
	end
end

local function refresh()
	displayed = readDisplayedCards()
	refreshSet()
	applyFilter()
	refreshDetail()
end

local function openSet(set: string)
	if not Cards.BySet[set] then
		return
	end
	currentSet = set
	spreadIndex = 1
	refresh()
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
	if not UserInputService.MouseEnabled or not tile.button.Parent or detail.Visible or bagOverlay.Visible then
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
	if detail.Visible and hintToast then
		UIController.Dismiss(hintToast) -- "Tap a card, then ..." is done once a card is open
		hintToast = nil
	end
end

local function buildTile(card: Card, parent: Instance): Tile
	local button = Instance.new("TextButton")
	button.Name = card.id
	button.LayoutOrder = card.number
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = parent

	-- The card on top, keeping its shape; the chips sit in the row under it, clear of the card's text
	local holder = Instance.new("Frame")
	holder.Name = "CardHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, -CHIP_ROW)
	holder.Parent = button
	local inner, stroke = addCardFrame(holder)
	inner.AnchorPoint = Vector2.new(0.5, 0)
	inner.Position = UDim2.fromScale(0.5, 0)
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = CARD_ASPECT
	shape.Parent = inner

	local countLabel = UIKit.label(button, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(0, 1)
	countLabel.Position = UDim2.fromScale(0, 1)
	countLabel.Size = UDim2.new(1, 0, 0, CHIP_ROW - 3)
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.BackgroundColor3 = UIKit.Colors.Panel
	countLabel.BackgroundTransparency = 0.2
	countLabel.ZIndex = 3
	UIKit.corner(countLabel, 6)

	local levelLabel = UIKit.label(button, "", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	levelLabel.Name = "Level"
	levelLabel.AnchorPoint = Vector2.new(1, 1)
	levelLabel.Position = UDim2.fromScale(1, 1)
	levelLabel.Size = UDim2.new(0.62, 0, 0, CHIP_ROW - 3)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.BackgroundColor3 = UIKit.Colors.Accent
	levelLabel.BackgroundTransparency = 0.1
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
	cardHolder.Size = UDim2.fromOffset(DETAIL_CARD.X, DETAIL_CARD.Y)
	cardHolder.BackgroundTransparency = 1
	cardHolder.ZIndex = 11
	cardHolder.Parent = detail
	detailInner, detailStroke = addCardFrame(cardHolder)

	detailName = UIKit.label(detail, "", Enum.Font.FredokaOne, 22, UIKit.Colors.Text)
	detailName.Position = UDim2.fromOffset(DETAIL_X, 12)
	detailName.Size = UDim2.new(1, -(DETAIL_X + 12), 0, 26)
	detailName.ZIndex = 11

	detailSubtitle = UIKit.label(detail, "", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	detailSubtitle.Position = UDim2.fromOffset(DETAIL_X, 38)
	detailSubtitle.Size = UDim2.new(1, -(DETAIL_X + 12), 0, 16)
	detailSubtitle.ZIndex = 11

	detailSummary = UIKit.label(detail, "", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	detailSummary.Position = UDim2.fromOffset(DETAIL_X, 56)
	detailSummary.Size = UDim2.new(1, -(DETAIL_X + 12), 0, 28)
	detailSummary.TextYAlignment = Enum.TextYAlignment.Top
	detailSummary.ZIndex = 11

	-- Levelled cards and plain copies; scrolls when there are many, ends above the Back button
	raisedList = Instance.new("ScrollingFrame")
	raisedList.Position = UDim2.fromOffset(DETAIL_X, 88)
	raisedList.Size = UDim2.new(1, -(DETAIL_X + 4), 1, -150)
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

	-- Bottom row, in thirds of the space right of the card: Assign to job, Add to party, Back
	local function placeBottom(button: TextButton, third: number)
		button.Position = UDim2.new(third / 3, DETAIL_X - third * (DETAIL_X / 3 + 1), 1, -56)
		button.Size = UDim2.new(1 / 3, -(DETAIL_X / 3 + 9), 0, 48)
		button.TextSize = 14
		button.ZIndex = 12
	end
	assignButton = UIKit.button(detail, "Assign to job", UIKit.Colors.Locked)
	placeBottom(assignButton, 0)
	assignButton.Activated:Connect(function()
		if assignTarget then
			partyChooser.Visible = false
			jobChooser.Visible = true
		end
	end)

	partyButton = UIKit.button(detail, "Add to party", UIKit.Colors.Locked)
	placeBottom(partyButton, 1)
	partyButton.Activated:Connect(function()
		if partyTarget then
			jobChooser.Visible = false
			refreshPartyChooser()
			partyChooser.Visible = true
		end
	end)

	partyChooser = Instance.new("Frame")
	partyChooser.Name = "PartyChooser"
	partyChooser.AnchorPoint = Vector2.new(0.5, 1)
	partyChooser.Position = UDim2.new(0.5, 0, 1, -62)
	partyChooser.Size = UDim2.fromOffset(330, 142)
	partyChooser.BackgroundColor3 = UIKit.Colors.Panel
	partyChooser.Visible = false
	partyChooser.ZIndex = 20
	partyChooser.Parent = detail
	UIKit.corner(partyChooser, 12)
	local partyStroke = Instance.new("UIStroke")
	partyStroke.Color = UIKit.Colors.Accent
	partyStroke.Parent = partyChooser
	local partyTitle = UIKit.label(partyChooser, "Which party slot? A card there goes back to your binder.", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	partyTitle.Position = UDim2.fromOffset(12, 8)
	partyTitle.Size = UDim2.new(1, -24, 0, 22)
	partyTitle.TextTruncate = Enum.TextTruncate.AtEnd
	partyTitle.ZIndex = 21
	for slot = 1, Party.PARTY_SIZE do
		local choice = UIKit.button(partyChooser, `Slot {slot}`, UIKit.Colors.Accent)
		choice.Position = UDim2.new((slot - 1) / Party.PARTY_SIZE, if slot == 1 then 12 else 4, 0, 36)
		choice.Size = UDim2.new(1 / Party.PARTY_SIZE, -16, 0, 56)
		choice.TextSize = 13
		choice.TextWrapped = true
		choice.ZIndex = 21
		choice.Activated:Connect(function()
			partyChooser.Visible = false
			if partyTarget then
				Remotes.SetPartySlot:FireServer(slot, partyTarget)
			end
		end)
		partySlotButtons[slot] = choice
	end
	local partyCancel = UIKit.button(partyChooser, "Cancel", UIKit.Colors.Row)
	partyCancel.Position = UDim2.new(0, 12, 0, 98)
	partyCancel.Size = UDim2.new(1, -24, 0, 36)
	partyCancel.TextSize = 14
	partyCancel.ZIndex = 21
	partyCancel.Activated:Connect(function()
		partyChooser.Visible = false
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
	placeBottom(back, 2)
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
		local firstCard = BinderSpreads.cards(spreadIndex, #visibleTiles, pocketsPerPage)
		pocketsPerPage = perPage
		local spread = 1
		while spread < BinderSpreads.count(#visibleTiles, pocketsPerPage) do
			local _, last = BinderSpreads.cards(spread, #visibleTiles, pocketsPerPage)
			if last >= firstCard then
				break
			end
			spread += 1
		end
		spreadIndex = spread
		if coverPage then
			showSpread(spreadIndex)
		end
	end
end

-- Bag: the item inventory (Config/Items), the binder's second tab. Item tiles on the left, the chosen item's
-- details (what it does, where to get it, how to use it) on the right.
local bagGrid: ScrollingFrame
local bagDetail: Frame
local bagItems: { [string]: number } = {}
local selectedItem: string? = nil
local cardsTab: TextButton
local bagTab: TextButton

local BAG_TILE = Vector2.new(108, 124)

local function bagLabel(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, y: number, height: number): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 33
	return label
end

local function ownedItemIds(): { string }
	local ids = {}
	for id in Items.ITEMS do
		if (bagItems[id] or 0) > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function renderBagDetail()
	for _, child in bagDetail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local info = if selectedItem then Items.ITEMS[selectedItem] else nil
	if not info or not selectedItem then
		bagLabel(bagDetail, "Tap an item to see what it does.", Enum.Font.GothamBold, 14, UIKit.Colors.Subtext, 16, 40)
		return
	end
	local icon = bagLabel(bagDetail, info.icon, Enum.Font.GothamBold, 56, UIKit.Colors.Text, 10, 64)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local name = bagLabel(bagDetail, `{info.name} · x{bagItems[selectedItem] or 0}`, Enum.Font.FredokaOne, 20, UIKit.Colors.Text, 78, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	bagLabel(bagDetail, info.description, Enum.Font.Gotham, 14, UIKit.Colors.Text, 112, 40)
	if info.source then
		bagLabel(bagDetail, "Where to get it", Enum.Font.GothamBold, 13, UIKit.Colors.Accent, 160, 18)
		bagLabel(bagDetail, info.source, Enum.Font.Gotham, 13, UIKit.Colors.Subtext, 178, 36)
	end
	if info.use then
		bagLabel(bagDetail, "How to use it", Enum.Font.GothamBold, 13, UIKit.Colors.Accent, 220, 18)
		bagLabel(bagDetail, info.use, Enum.Font.Gotham, 13, UIKit.Colors.Subtext, 238, 36)
	end
end

local function renderBag()
	for _, child in bagGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ids = ownedItemIds()
	if selectedItem and not table.find(ids, selectedItem) then
		selectedItem = nil
	end
	selectedItem = selectedItem or ids[1]
	if #ids == 0 then
		local empty = UIKit.label(bagGrid, "🎒 Your bag is empty.\nItems drop in the Frontier: take its portal in the plaza.", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		empty.Size = UDim2.new(1, -8, 0, 80)
		empty.TextWrapped = true
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.ZIndex = 33
	end
	for order, id in ids do
		local info = Items.ITEMS[id]
		local tile = Instance.new("TextButton")
		tile.Text = ""
		tile.LayoutOrder = order
		tile.AutoButtonColor = true
		tile.BackgroundColor3 = UIKit.Colors.Row
		tile.ZIndex = 32
		tile.Parent = bagGrid
		UIKit.corner(tile, 12)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if id == selectedItem then UIKit.Colors.Accent else Color3.fromRGB(80, 80, 100)
		stroke.Thickness = if id == selectedItem then 3 else 1
		stroke.Parent = tile
		local icon = UIKit.label(tile, info.icon, Enum.Font.GothamBold, 44, UIKit.Colors.Text)
		icon.Position = UDim2.fromOffset(0, 10)
		icon.Size = UDim2.new(1, 0, 0, 56)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.ZIndex = 33
		local name = UIKit.label(tile, info.name, Enum.Font.GothamBold, 13, UIKit.Colors.Text)
		name.Position = UDim2.fromOffset(4, 70)
		name.Size = UDim2.new(1, -8, 0, 18)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 33
		local badge = UIKit.label(tile, `x{bagItems[id]}`, Enum.Font.FredokaOne, 16, UIKit.Colors.Accent)
		badge.Position = UDim2.fromOffset(4, 92)
		badge.Size = UDim2.new(1, -8, 0, 22)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.ZIndex = 33
		tile.Activated:Connect(function()
			selectedItem = id
			renderBag()
		end)
	end
	renderBagDetail()
end

local function showTab(bag: boolean)
	if bag then
		hideTooltip()
	end
	bagOverlay.Visible = bag
	cardsTab.BackgroundColor3 = if bag then UIKit.Colors.Row else UIKit.Colors.Accent
	bagTab.BackgroundColor3 = if bag then UIKit.Colors.Accent else UIKit.Colors.Row
	if bag then
		renderBag()
	end
end

local function buildBag(parent: Frame)
	-- Two tabs in the header, next to the title
	local function tab(text: string, x: number): TextButton
		local button = UIKit.button(parent, text, UIKit.Colors.Row)
		button.Position = UDim2.fromOffset(x, 10)
		button.Size = UDim2.fromOffset(116, 48)
		button.TextSize = 15
		button.ZIndex = 12
		return button
	end
	cardsTab = tab("📖 Cards", 150)
	bagTab = tab("🎒 Bag", 272)
	-- The card view covers the whole binder, title row included: hide the tabs while it's open
	detail:GetPropertyChangedSignal("Visible"):Connect(function()
		cardsTab.Visible = not detail.Visible
		bagTab.Visible = not detail.Visible
	end)

	bagOverlay = Instance.new("Frame")
	bagOverlay.Name = "Bag"
	bagOverlay.Position = UDim2.fromOffset(12, 64)
	bagOverlay.Size = UDim2.new(1, -24, 1, -76)
	bagOverlay.BackgroundColor3 = UIKit.Colors.Panel
	bagOverlay.Visible = false
	bagOverlay.ZIndex = 30
	bagOverlay.Parent = parent
	UIKit.corner(bagOverlay, 12)

	bagGrid = Instance.new("ScrollingFrame")
	bagGrid.Position = UDim2.fromOffset(8, 8)
	bagGrid.Size = UDim2.new(0.58, -12, 1, -16)
	bagGrid.BackgroundTransparency = 1
	bagGrid.BorderSizePixel = 0
	bagGrid.ScrollBarThickness = 4
	bagGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bagGrid.CanvasSize = UDim2.new()
	bagGrid.ZIndex = 31
	bagGrid.Parent = bagOverlay
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(BAG_TILE.X, BAG_TILE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bagGrid

	bagDetail = Instance.new("Frame")
	bagDetail.AnchorPoint = Vector2.new(1, 0)
	bagDetail.Position = UDim2.new(1, -8, 0, 8)
	bagDetail.Size = UDim2.new(0.42, -4, 1, -16)
	bagDetail.BackgroundColor3 = UIKit.Colors.Row
	bagDetail.ZIndex = 32
	bagDetail.Parent = bagOverlay
	UIKit.corner(bagDetail, 12)

	cardsTab.Activated:Connect(function()
		showTab(false)
	end)
	bagTab.Activated:Connect(function()
		showTab(true)
	end)
	parent:GetPropertyChangedSignal("Visible"):Connect(function()
		if not parent.Visible then
			showTab(false)
		end
	end)
	showTab(false)
end

-- A small dark key hint on a button's corner ("Q", "E")
local function addKeyChip(button: GuiObject, key: string)
	local chip = Instance.new("TextLabel")
	chip.Name = "Key"
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.new(1, 10, 1, 10)
	chip.Size = UDim2.fromOffset(24, 24)
	chip.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	chip.Font = Enum.Font.FredokaOne
	chip.Text = key
	chip.TextSize = 14
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.ZIndex = button.ZIndex + 2
	chip.Parent = button
	UIKit.corner(chip, 6)
	UIKit.outline(chip, Color3.new(1, 1, 1), 1.5)
end

local function choiceRow(parent: Instance, order: number, values: { string }, onPick: (string) -> ()): { [string]: TextButton }
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local buttons: { [string]: TextButton } = {}
	for index, value in values do
		local button = UIKit.button(row, value, UIKit.Colors.Row)
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #values, -6, 1, 0)
		button.TextSize = 15
		button.Activated:Connect(function()
			onPick(value)
		end)
		buttons[value] = button
	end
	return buttons
end

local function sectionLabel(parent: Instance, order: number, text: string)
	local label = UIKit.label(parent, text, Enum.Font.FredokaOne, 18, UIKit.Colors.Text)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 24)
end

-- The Filters panel on the right: search, Show, Sort by, rarity chips. The book shrinks aside while it's open.
local function buildFilters(parent: Frame)
	filtersPanel = Instance.new("Frame")
	filtersPanel.Name = "Filters"
	-- Between the close / Filters buttons (top right) and the set progress card (bottom right)
	filtersPanel.AnchorPoint = Vector2.new(1, 0)
	filtersPanel.Position = UDim2.new(1, -16, 0, 84)
	filtersPanel.Size = UDim2.new(0, Collection.FILTERS_WIDTH, 1, -(84 + 100))
	filtersPanel.BackgroundColor3 = UIKit.Colors.Panel
	filtersPanel.Visible = false
	filtersPanel.ZIndex = 6
	filtersPanel.Parent = parent
	UIKit.corner(filtersPanel, 16)
	UIKit.outline(filtersPanel, Color3.new(1, 1, 1), 3)
	UIKit.header(filtersPanel, "Filters")
	local close = UIKit.closeButton(filtersPanel)
	close.Activated:Connect(function()
		setFiltersOpen(false)
	end)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(14, UIKit.HEADER_HEIGHT + 10)
	body.Size = UDim2.new(1, -28, 1, -(UIKit.HEADER_HEIGHT + 20))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = filtersPanel.ZIndex
	body.Parent = filtersPanel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.LayoutOrder = 1
	search.Size = UDim2.new(1, 0, 0, 44)
	search.BackgroundColor3 = UIKit.Colors.Row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "🔍 Search name or #"
	search.Text = ""
	search.Font = Enum.Font.GothamBold
	search.TextSize = 15
	search.TextColor3 = UIKit.Colors.Ink
	search.PlaceholderColor3 = UIKit.Colors.InkSoft
	search.Parent = body
	UIKit.corner(search, 12)
	UIKit.outline(search)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		spreadIndex = 1
		applyFilter()
	end)

	sectionLabel(body, 2, "Show")
	showButtons = choiceRow(body, 3, { ALL_FILTER, OWNED_FILTER, MISSING_FILTER }, function(value)
		showFilter = value
		spreadIndex = 1
		applyFilter()
	end)
	sectionLabel(body, 4, "Sort by")
	sortButtons = choiceRow(body, 5, { "Set", "Value", "Copies", "Rarity" }, function(value)
		sortBy = value
		spreadIndex = 1
		applyFilter()
	end)
	sectionLabel(body, 6, "Rarity")
	local chips = Instance.new("Frame")
	chips.LayoutOrder = 7
	chips.Size = UDim2.new(1, 0, 0, 0)
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.BackgroundTransparency = 1
	chips.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 40)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chips
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	for index, rarity in rarities do
		local chip = UIKit.button(chips, rarity, UIKit.Colors.Row)
		chip.LayoutOrder = index
		chip.TextSize = 15
		chip.Activated:Connect(function()
			rarityPicks[rarity] = if rarityPicks[rarity] then nil else true
			spreadIndex = 1
			applyFilter()
		end)
		rarityChips[rarity] = chip
	end
end

-- Opens or closes the Filters panel; the book shrinks and slides left to make room
function setFiltersOpen(open: boolean)
	local info = TweenInfo.new(Collection.BOOK.SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bookScale, info, { Scale = if open then Collection.BOOK.FILTER_SCALE else 1 }):Play()
	TweenService:Create(bookHolder, info, {
		Position = UDim2.fromScale(if open then Collection.BOOK.FILTER_X else 0.5, Collection.BOOK.CENTRE_Y),
	}):Play()
	if open then
		filtersPanel.Visible = true
		Motion.popIn(filtersPanel)
	else
		Motion.popOut(filtersPanel, function()
			filtersPanel.Visible = false
		end)
	end
end

local function makePage(book: Frame, isLeft: boolean): Frame
	local page = Instance.new("Frame")
	page.Name = if isLeft then "LeftPage" else "RightPage"
	page.Position = if isLeft then UDim2.new(0, 14, 0, 14) else UDim2.new(0.5, 10, 0, 14)
	page.Size = UDim2.new(0.5, -24, 1, -28)
	page.BackgroundColor3 = Collection.BOOK.PAGE_COLOR
	page.Parent = book
	UIKit.corner(page, 10)

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

-- The set's cover over spread 1's left page: its colour, name, progress and emblem. It sits on the book,
-- not in the page (the page's grid would size it like a pocket).
local function buildCover(page: Frame)
	coverPage = Instance.new("Frame")
	coverPage.Name = "Cover"
	coverPage.Position = page.Position
	coverPage.Size = page.Size
	coverPage.BackgroundColor3 = UIKit.Colors.Accent
	coverPage.ZIndex = page.ZIndex + 1
	coverPage.Parent = page.Parent
	UIKit.corner(coverPage, 10)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	gradient.Parent = coverPage
	local border = Instance.new("Frame")
	border.Position = UDim2.fromScale(0.06, 0.05)
	border.Size = UDim2.fromScale(0.88, 0.9)
	border.BackgroundTransparency = 1
	border.ZIndex = coverPage.ZIndex
	border.Parent = coverPage
	UIKit.corner(border, 12)
	UIKit.outline(border, Color3.new(1, 1, 1), 2).Transparency = 0.5
	local band = Instance.new("Frame")
	band.Position = UDim2.fromScale(0.06, 0.16)
	band.Size = UDim2.fromScale(0.88, 0.22)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 0.75
	band.BorderSizePixel = 0
	band.ZIndex = coverPage.ZIndex
	band.Parent = coverPage
	coverTitle = UIKit.label(band, "", Enum.Font.FredokaOne, 40, Color3.new(1, 1, 1))
	coverTitle.Position = UDim2.fromScale(0.05, 0.05)
	coverTitle.Size = UDim2.fromScale(0.9, 0.55)
	coverTitle.TextScaled = true
	coverTitle.TextXAlignment = Enum.TextXAlignment.Center
	coverTitle.ZIndex = band.ZIndex + 1
	coverProgress = UIKit.label(band, "", Enum.Font.FredokaOne, 24, Color3.new(1, 1, 1))
	coverProgress.Position = UDim2.fromScale(0.05, 0.6)
	coverProgress.Size = UDim2.fromScale(0.9, 0.32)
	coverProgress.TextScaled = true
	coverProgress.TextXAlignment = Enum.TextXAlignment.Center
	coverProgress.ZIndex = band.ZIndex + 1
	coverEmblem = UIKit.label(coverPage, "", Enum.Font.FredokaOne, 80, Color3.new(1, 1, 1))
	coverEmblem.AnchorPoint = Vector2.new(0.5, 0.5)
	coverEmblem.Position = UDim2.fromScale(0.5, 0.66)
	coverEmblem.Size = UDim2.fromScale(0.5, 0.36)
	coverEmblem.TextScaled = true
	coverEmblem.TextXAlignment = Enum.TextXAlignment.Center
	coverEmblem.TextTransparency = 0.15
	coverEmblem.ZIndex = coverPage.ZIndex + 1
end

-- A round arrow button beside the book, with its key chip
local function arrowButton(parent: Instance, text: string, key: string, big: boolean, onClick: () -> ()): TextButton
	local button = UIKit.button(parent, text, if big then UIKit.Colors.Accent else UIKit.Colors.Row)
	button.Size = UDim2.fromOffset(if big then 64 else 52, if big then 64 else 52)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = if big then 30 else 24
	addKeyChip(button, key)
	button.Activated:Connect(onClick)
	return button
end

local function buildPanel(parent: Instance)
	local list: ScrollingFrame
	panel, list = UIKit.panel(parent, "Binder", "Binder")
	list:Destroy() -- the binder uses pages instead of a scrolling list
	-- Full screen, the world dimmed behind; no header (the book is the screen)
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.45
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit:Destroy()
	end
	for _, name in { "Header", "Title" } do
		local item = panel:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	local edge = panel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge:Destroy()
	end
	local corner = panel:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	local close = panel:FindFirstChild("Close") :: GuiObject?
	if close then
		close.Position = UDim2.new(1, -16, 0, 16)
	end

	-- The book: holder keeps the shape and position (it slides when Filters open), the scale shrinks it
	bookHolder = Instance.new("Frame")
	bookHolder.Name = "BookHolder"
	bookHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	bookHolder.Position = UDim2.fromScale(0.5, Collection.BOOK.CENTRE_Y)
	bookHolder.Size = UDim2.fromScale(Collection.BOOK.WIDTH, Collection.BOOK.HEIGHT)
	bookHolder.BackgroundTransparency = 1
	bookHolder.ZIndex = panel.ZIndex
	bookHolder.Parent = panel
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = Collection.BOOK.ASPECT
	shape.Parent = bookHolder
	bookScale = Instance.new("UIScale")
	bookScale.Parent = bookHolder

	book = Instance.new("Frame")
	book.Name = "Book"
	book.Size = UDim2.fromScale(1, 1)
	book.BackgroundColor3 = Collection.BOOK.COLOR
	book.ZIndex = panel.ZIndex
	book.Parent = bookHolder
	UIKit.corner(book, 18)
	UIKit.outline(book, Collection.BOOK.STITCH, 2).Transparency = 0.4
	pages = { makePage(book, true), makePage(book, false) }
	buildCover(pages[1])

	-- Rings down the middle
	for index = 1, 3 do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, index / 4)
		ring.Size = UDim2.fromOffset(46, 14)
		ring.BackgroundColor3 = Color3.fromRGB(225, 228, 238)
		ring.ZIndex = book.ZIndex + 3
		ring.Parent = book
		UIKit.corner(ring, 7)
		UIKit.outline(ring, Color3.fromRGB(120, 125, 145), 2)
	end

	-- Set tabs on the book's left edge
	for index, set in Collection.SETS do
		if Cards.BySet[set] then
			local tab = UIKit.button(bookHolder, string.upper(set), UIKit.Colors.Row)
			tab.Name = "SetTab" .. string.gsub(set, " ", "")
			tab.AnchorPoint = Vector2.new(1, 0)
			tab.Position = UDim2.new(0, 10, 0, 24 + (index - 1) * 80)
			tab.Size = UDim2.fromOffset(64, 70)
			tab.Font = Enum.Font.FredokaOne
			tab.TextScaled = true
			tab.TextWrapped = true
			local tabPadding = tab:FindFirstChildOfClass("UIPadding")
			if tabPadding then
				tabPadding.PaddingLeft = UDim.new(0, 6)
				tabPadding.PaddingRight = UDim.new(0, 8)
				tabPadding.PaddingTop = UDim.new(0, 6)
				tabPadding.PaddingBottom = UDim.new(0, 10)
			end
			tab.ZIndex = book.ZIndex - 1
			tab.Activated:Connect(function()
				openSet(set)
			end)
			setTabs[set] = tab
		end
	end

	-- Page counter under the book, arrows either side (Q/E one spread, A/D first/last)
	local counter = Instance.new("Frame")
	counter.Name = "Counter"
	counter.AnchorPoint = Vector2.new(0.5, 0)
	counter.Position = UDim2.new(0.5, 0, 1, 10)
	counter.Size = UDim2.fromOffset(140, 40)
	counter.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	counter.ZIndex = book.ZIndex
	counter.Parent = bookHolder
	UIKit.corner(counter, 20)
	pageLabel = UIKit.label(counter, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	pageLabel.Size = UDim2.fromScale(1, 1)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center

	local leftArrows = Instance.new("Frame")
	leftArrows.AnchorPoint = Vector2.new(1, 0.5)
	leftArrows.Position = UDim2.new(0, -96, 0.5, 0) -- clear of the set tabs
	leftArrows.Size = UDim2.fromOffset(64, 140)
	leftArrows.BackgroundTransparency = 1
	leftArrows.Parent = bookHolder
	local leftList = Instance.new("UIListLayout")
	leftList.Padding = UDim.new(0, 16)
	leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftList.Parent = leftArrows
	arrowButton(leftArrows, "<", "Q", true, function()
		showSpread(spreadIndex - 1)
	end).LayoutOrder = 1
	arrowButton(leftArrows, "<<", "A", false, function()
		showSpread(1)
	end).LayoutOrder = 2

	local rightArrows = leftArrows:Clone()
	for _, child in rightArrows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rightArrows.AnchorPoint = Vector2.new(0, 0.5)
	rightArrows.Position = UDim2.new(1, 18, 0.5, 0)
	rightArrows.Parent = bookHolder
	arrowButton(rightArrows, ">", "E", true, function()
		showSpread(spreadIndex + 1)
	end).LayoutOrder = 1
	arrowButton(rightArrows, ">>", "D", false, function()
		showSpread(getSpreadCount())
	end).LayoutOrder = 2

	-- Filters (F), top right next to the close button
	local filterButton = UIKit.button(panel, "🔍", UIKit.Colors.Row)
	filterButton.Name = "FilterButton"
	filterButton.AnchorPoint = Vector2.new(1, 0)
	filterButton.Position = UDim2.new(1, -84, 0, 16)
	filterButton.Size = UDim2.fromOffset(52, 52)
	filterButton.TextSize = 24
	addKeyChip(filterButton, "F")
	filterButton.Activated:Connect(function()
		setFiltersOpen(not filtersPanel.Visible)
	end)
	buildFilters(panel)

	-- Set progress, bottom right
	local progress = Instance.new("Frame")
	progress.Name = "SetProgress"
	progress.AnchorPoint = Vector2.new(1, 1)
	progress.Position = UDim2.new(1, -16, 1, -16)
	progress.Size = UDim2.fromOffset(300, 74)
	progress.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	progress.ZIndex = panel.ZIndex + 1
	progress.Parent = panel
	UIKit.corner(progress, 14)
	UIKit.outline(progress, Color3.fromRGB(60, 80, 140), 2)
	progressName = UIKit.label(progress, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	progressName.Position = UDim2.fromOffset(14, 6)
	progressName.Size = UDim2.new(1, -110, 0, 30)
	progressValue = UIKit.label(progress, "", Enum.Font.FredokaOne, 20, VALUE_COLOR)
	progressValue.AnchorPoint = Vector2.new(1, 0)
	progressValue.Position = UDim2.new(1, -14, 0, 6)
	progressValue.Size = UDim2.fromOffset(100, 30)
	progressValue.TextXAlignment = Enum.TextXAlignment.Right
	progressCount = UIKit.label(progress, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	progressCount.Position = UDim2.fromOffset(14, 40)
	progressCount.Size = UDim2.fromOffset(110, 26)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 130, 0, 50)
	track.Size = UDim2.new(1, -144, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(60, 70, 110)
	track.Parent = progress
	UIKit.corner(track, 4)
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.Parent = track
	UIKit.corner(progressFill, 4)

	-- Rarity guide, bottom left
	rarityGuideButton = UIKit.button(panel, "ℹ️ Rarity guide", UIKit.Colors.Row)
	rarityGuideButton.Name = "RarityGuide"
	rarityGuideButton.AnchorPoint = Vector2.new(0, 1)
	rarityGuideButton.Position = UDim2.new(0, 16, 1, -16)
	rarityGuideButton.Size = UDim2.fromOffset(190, 52)
	rarityGuideButton.TextSize = 17
	rarityGuideButton.Activated:Connect(RarityGuideController.Open)

	tooltip = Instance.new("Frame")
	tooltip.Name = "BinderTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Row
	tooltip.ZIndex = 50
	tooltip.Visible = false
	tooltip.Parent = parent
	UIKit.corner(tooltip, 10)
	UIKit.outline(tooltip, UIKit.Colors.Accent, 2)
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
	fitPockets()
	refreshSet()
	applyFilter()

	buildDetail(panel)
	buildBag(panel)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		hideTooltip()
		Hud.setHidden("Binder", panel.Visible)
		if not panel.Visible and filtersPanel.Visible then
			filtersPanel.Visible = false
			bookScale.Scale = 1
			bookHolder.Position = UDim2.fromScale(0.5, Collection.BOOK.CENTRE_Y)
		end
	end)
end

local function onCollectionChanged(payload: { stacks: Stacks, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	graded = if typeof(payload.stacks) == "table" then payload.stacks else {}
	collection = sumGrades(graded)
	beasts = if typeof(payload.beasts) == "table" then payload.beasts else {}
	working = if typeof((payload :: any).working) == "table" then (payload :: any).working else {}
	partied = if typeof((payload :: any).partied) == "table" then (payload :: any).partied else {}
	refresh()
end

-- Typing in a text box or the chat bar (the chat bar isn't a TextBox the game can see)
local function isTyping(): boolean
	if UserInputService:GetFocusedTextBox() then
		return true
	end
	local chatBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	return chatBar ~= nil and chatBar.IsFocused
end

local function toggle()
	detail.Visible = false
	detailCard = nil
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh() -- displayed cards may have sold since last time
	end
end

-- Inventory: open the binder on the Bag tab, or close it if the Bag is already showing
local function toggleBag()
	if panel.Visible and bagOverlay.Visible then
		toggle()
	else
		if not panel.Visible then
			toggle()
		end
		showTab(true)
	end
end

-- Bottom-centre tiles: Cards (the binder) and Bag
local function buildButtons()
	Hud.tile({ id = "Cards", icon = "📖", label = "Cards", key = "B", group = "Bottom", order = 1, onClick = toggle })
	Hud.tile({ id = "Bag", icon = "🎒", label = "Bag", key = "I", group = "Bottom", order = 2, onClick = toggleBag })
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

-- Opens the binder on its pages (from the Jobs or Party panel), with a hint saying what to do next
function BinderController.Open(hint: string?)
	if not panel.Visible then
		toggle()
	end
	if hint then
		hintToast = UIController.Notify(hint, false, 4)
	end
end

-- Cards in the party: beastId -> true
function BinderController.GetPartied(): { [string]: boolean }
	return partied
end

function BinderController.GetBeasts(): { [string]: Beast }
	return beasts
end

function BinderController.Start()
	local screenGui = UIController.GetScreenGui()
	buildPanel(screenGui)
	buildButtons()
	refresh()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == BINDER_KEY then
			toggle()
			return
		end
		if not panel.Visible or bagOverlay.Visible or detail.Visible or isTyping() then
			return
		end
		local step = PAGE_KEYS[input.KeyCode]
		if step then
			showSpread(spreadIndex + step)
		elseif input.KeyCode == Enum.KeyCode.A then
			showSpread(1)
		elseif input.KeyCode == Enum.KeyCode.D then
			showSpread(getSpreadCount())
		elseif input.KeyCode == Enum.KeyCode.F then
			setFiltersOpen(not filtersPanel.Visible)
		end
	end)
	-- I opens the Bag. Roblox's camera binds I (zoom) through ContextActionService and swallows it before
	-- InputBegan sees it, so the Bag binds there too, above the camera's priority. Bound actions never fire
	-- while the player types (chat, text boxes).
	ContextActionService:BindActionAtPriority("OpenBag", function(_, state)
		if state ~= Enum.UserInputState.Begin or isTyping() then
			return Enum.ContextActionResult.Pass
		end
		toggleBag()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + BAG_PRIORITY_MARGIN, BAG_KEY)

	Remotes.CollectionChanged.OnClientEvent:Connect(onCollectionChanged)
	-- Job slots opening or filling up change the card view's Assign button
	for _, name in { "JobSlots", "JobsUsed" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if detail.Visible then
				refreshDetail()
			end
		end)
	end
	-- Party slot names in the "Which party slot?" chooser
	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		partySlots = {}
		for _, entry in payload.slots do
			if typeof(entry) == "table" and typeof(entry.slot) == "number" and typeof(entry.beastId) == "string" then
				partySlots[entry.slot] = entry.beastId
			end
		end
		refreshPartyChooser()
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		bagItems = if typeof(items) == "table" then items else {}
		if bagOverlay.Visible then
			renderBag()
		end
	end)
	Remotes.RequestCollection:FireServer()
	Remotes.RequestParty:FireServer()
	Remotes.RequestItems:FireServer()
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	task.spawn(watchOwnPlot)
end

return BinderController
