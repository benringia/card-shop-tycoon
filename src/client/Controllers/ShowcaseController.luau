--!strict
-- Managing your own card case (Glass Showcase or Collector Case), laid out like an MMO marketplace:
-- a listings table on the left, the selected card's details on the right (hover a row with a mouse for a
-- tooltip), a "Set price" editor that opens on demand, and a card picker (with rarity filters) for empty slots.
-- Opened from the case's Edit menu. The server checks every change; this reads the case's card parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Pricing = require(Config:WaitForChild("Pricing"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Shelves = require(Config:WaitForChild("Shelves"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
-- "All", "Foil", or a rarity name (exactly that rarity)
type PickerFilter = string

local ALL_FILTER = "All"
local FOIL_FILTER = "Foil"
local FILTER_CHIP_WIDTH = 96
local PICKER_TILE_SIZE = Vector2.new(92, 168) -- card face on top, grade/count and value underneath
local PICKER_FACE_HEIGHT = 118
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local PANEL_MAX_SIZE = Vector2.new(820, 520)
local LIST_WIDTH_SCALE = 0.55 -- listings table share of the panel width; details pane gets the rest
local LISTING_ROW_HEIGHT = 64
local DETAIL_FACE_SIZE = Vector2.new(120, 171)
local TOOLTIP_WIDTH = 240
local MARKET_COLORS = {
	Under = Color3.fromRGB(120, 230, 120), -- at or under market: sells easily
	Near = Color3.fromRGB(240, 200, 80), -- up to 1.5x market
	Over = Color3.fromRGB(240, 110, 100), -- above that
}
local NEAR_MARKET_RATIO = 1.5

local SEND_DELAY = 0.4 -- price taps are sent together once tapping stops
local KIND_DESCRIPTIONS = {
	CustomerCards = "Customers may buy these at your price.",
	PlayerCards = "Other players can buy these at your price.",
}

local ShowcaseController = {}

local panel: Frame
local list: ScrollingFrame
local detailPane: ScrollingFrame
local tooltip: Frame
local tooltipText: TextLabel
local selectedSlot: number? = nil -- listing shown in the details pane
local editingSlot: number? = nil -- listing whose price editor is open
local titleLabel: TextLabel
local subtitle: TextLabel
local picker: Frame
local pickerList: ScrollingFrame
local pickerTitle: TextLabel
local pickerPane: ScrollingFrame
local pickerSelectedKey: string? = nil
local filterButtons: { [PickerFilter]: TextButton } = {}
local pickerFilter: PickerFilter = ALL_FILTER

local casePart: BasePart? = nil
local caseConnections: { RBXScriptConnection } = {}
local pending: { [number]: number } = {} -- slot → price not sent yet
local sendToken = 0
local pickerSlot: number? = nil

local function clearChildren(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function getCardPart(slot: number): BasePart?
	local part = casePart
	if not part then
		return nil
	end
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Slot") == slot then
			return child
		end
	end
	return nil
end

-- A card face drawn into a new frame (the same look as the binder and pack reveal)
local function makeCardFace(parent: Instance, card: Card, foil: boolean, showValue: boolean, growth: CardFace.Growth?): Frame
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = parent
	UIKit.corner(face, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil, showValue, growth)
	return face
end

-- A displayed card's level, stars and grade (1, 0, C for a plain Grade C copy)
local function getGrowthFromPart(part: BasePart): (number, number, string)
	local level, stars, grade = part:GetAttribute("Level"), part:GetAttribute("Stars"), part:GetAttribute("Grade")
	return if typeof(level) == "number" then level else 1,
		if typeof(stars) == "number" then stars else BeastRules.START_STARS,
		if BeastRules.isGrade(grade) then grade :: string else BeastRules.DEFAULT_GRADE
end

-- All, every rarity from Common up (read from the config, so new tiers show up here), then Foil
local function getPickerFilters(): { PickerFilter }
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	local filters: { PickerFilter } = { ALL_FILTER }
	for _, name in rarities do
		table.insert(filters, name)
	end
	table.insert(filters, FOIL_FILTER)
	return filters
end

local function passesFilter(card: Card, foil: boolean): boolean
	if pickerFilter == ALL_FILTER then
		return true
	elseif pickerFilter == FOIL_FILTER then
		return foil
	end
	return card.rarity == pickerFilter
end

local STEP_BUTTON_WIDTH = 80
local PRICE_BOX_COLOR = Color3.fromRGB(20, 20, 30)
local PRICE_TEXT_COLOR = Color3.fromRGB(120, 230, 120)
local STEP_BUTTON_COLOR = Color3.fromRGB(70, 110, 190)

local function flush(token: number)
	local part = casePart
	if token ~= sendToken or not part or next(pending) == nil then
		return
	end
	local changes = {}
	for slot, price in pending do
		table.insert(changes, { slot = slot, price = price })
	end
	pending = {}
	Remotes.SetCardPrice:FireServer(part:GetAttribute("ShelfUid"), changes)
end

local render: () -> ()

local function queuePrice(slot: number, price: number)
	pending[slot] = price
	render()
	sendToken += 1
	local token = sendToken
	task.delay(SEND_DELAY, flush, token)
end

-- One copy's growth, so price maths use its real value
type CopyGrowth = { level: number, stars: number, grade: string }

local function nudge(slot: number, card: Card, foil: boolean, growth: CopyGrowth, current: number, direction: number)
	local step = CardRules.getPriceStep(card, foil, growth.level, growth.stars, growth.grade)
	queuePrice(slot, CardRules.clampPrice(current + direction * step, card, foil, growth.level, growth.stars, growth.grade))
end

-- Accepts "275", "$275.50" or "1,200"; anything else puts the current price back.
-- Clamped here for display; the server clamps again.
local function setTypedPrice(slot: number, card: Card, foil: boolean, growth: CopyGrowth, box: TextBox)
	local cleaned = string.gsub(box.Text, "[%$,%s]", "")
	local typed = tonumber(cleaned)
	if not typed or typed ~= typed then
		render()
		return
	end
	queuePrice(slot, CardRules.clampPrice(typed, card, foil, growth.level, growth.stars, growth.grade))
end

-- The middle of the price stepper, between the - and + buttons
local function placePriceBox(box: GuiObject)
	box.Position = UDim2.fromOffset(STEP_BUTTON_WIDTH + 6, 0)
	box.Size = UDim2.new(1, -2 * (STEP_BUTTON_WIDTH + 6), 1, 0)
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = PRICE_BOX_COLOR
	UIKit.corner(box, 8)
end

-- Everything about one listed card, read from its part
type Listing = {
	slot: number,
	card: Card,
	foil: boolean,
	growth: CopyGrowth,
	price: number,
	market: number,
	stats: { hp: number, atk: number, spd: number },
	power: number,
}

local function readListing(slot: number, cardPart: BasePart): Listing?
	local card = Cards.ById[cardPart:GetAttribute("CardId") :: string]
	if not card then
		return nil
	end
	local foil = cardPart:GetAttribute("Foil") == true
	local serverPrice = cardPart:GetAttribute("Price")
	local level, stars, grade = getGrowthFromPart(cardPart)
	return {
		slot = slot,
		card = card,
		foil = foil,
		growth = { level = level, stars = stars, grade = grade },
		price = pending[slot] or (if typeof(serverPrice) == "number" then serverPrice else 0),
		market = CardRules.getMarketValue(card, foil, level, stars, grade),
		stats = BeastRules.getStats(card, foil, level, stars, grade),
		power = BeastRules.getPower(card, foil, level, stars, grade),
	}
end

local function getMarketRatio(listing: Listing): number
	return if listing.market > 0 then listing.price / listing.market else math.huge
end

local function getMarketColor(listing: Listing): Color3
	local ratio = getMarketRatio(listing)
	return if ratio <= 1 + 1e-6
		then MARKET_COLORS.Under
		elseif ratio <= NEAR_MARKET_RATIO then MARKET_COLORS.Near
		else MARKET_COLORS.Over
end

local function describeGrowth(listing: Listing): string
	return `{BeastRules.describeGrade(listing.growth.grade)} · {BeastRules.describeGrowth(listing.growth.level, listing.growth.stars)}`
end

-- The full details, shared by the tooltip and the details pane
local function describeDetails(listing: Listing, kind: string): string
	local stats = listing.stats
	local lines = {
		`{listing.card.name}{if listing.foil then " (FOIL)" else ""}`,
		`{listing.card.rarity} · {listing.card.element} · #{listing.card.number}`,
		describeGrowth(listing),
		`Power {listing.power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`,
		string.format("Market $%.2f · asking %d%%", listing.market, math.round(getMarketRatio(listing) * 100)),
	}
	if kind == "CustomerCards" then
		local band = PriceRules.getBand(listing.price, listing.market)
		table.insert(lines, `Customers: {if band then band.label else Pricing.NEVER_LABEL}`)
	end
	return table.concat(lines, "\n")
end

-- Tooltip (mouse only) -------------------------------------------------------------------------------

local function showTooltip(row: GuiObject, listing: Listing, kind: string)
	-- Rows under the open card picker still get mouse events; no tooltip through it
	if not UserInputService.MouseEnabled or picker.Visible then
		return
	end
	tooltipText.Text = describeDetails(listing, kind)
	-- Just right of the row's card face, kept on screen
	local screen = (tooltip.Parent :: GuiObject?)
	local origin = if screen and screen:IsA("GuiBase2d") then (screen :: any).AbsolutePosition else Vector2.zero
	local screenSize = if screen and screen:IsA("GuiBase2d") then (screen :: any).AbsoluteSize else Vector2.new(1920, 1080)
	local x = row.AbsolutePosition.X - origin.X + THUMBNAIL_SIZE.X + 16
	local y = row.AbsolutePosition.Y - origin.Y + row.AbsoluteSize.Y
	tooltip.Position = UDim2.fromOffset(
		math.clamp(x, 0, math.max(0, screenSize.X - TOOLTIP_WIDTH)),
		math.clamp(y, 0, math.max(0, screenSize.Y - tooltip.AbsoluteSize.Y))
	)
	tooltip.Visible = true
end

local function hideTooltip()
	tooltip.Visible = false
end

-- Listings table ---------------------------------------------------------------------------------------

local openPicker: (slot: number) -> ()

local function makeListingRow(slot: number, selected: boolean): TextButton
	local row = Instance.new("TextButton")
	row.LayoutOrder = slot
	row.Size = UDim2.new(1, -6, 0, LISTING_ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 8)
	if selected then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = row
	end
	return row
end

local function addRowLabel(row: GuiObject, text: string, position: UDim2, size: UDim2, font: Enum.Font, textSize: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, textSize, color)
	label.Position = position
	label.Size = size
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- slot. name  / grade · level · stars        price / % of market
local function buildListingRow(listing: Listing, kind: string)
	local row = makeListingRow(listing.slot, listing.slot == selectedSlot)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(6, 4)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeCardFace(thumbnail, listing.card, listing.foil, false)

	local textX = THUMBNAIL_SIZE.X + 14
	local name = `{listing.slot}. {listing.card.name}{if listing.foil then " FOIL" else ""}`
	addRowLabel(row, name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + 104), 0, 20), Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	addRowLabel(row, describeGrowth(listing), UDim2.fromOffset(textX, 32), UDim2.new(1, -(textX + 104), 0, 18), Enum.Font.Gotham, 12, UIKit.Colors.Subtext)

	local price = addRowLabel(row, string.format("$%.2f", listing.price), UDim2.new(1, -100, 0, 6), UDim2.fromOffset(90, 24), Enum.Font.FredokaOne, 19, PRICE_TEXT_COLOR)
	price.TextXAlignment = Enum.TextXAlignment.Right
	local ratio = string.format("%d%% of market", math.round(getMarketRatio(listing) * 100))
	local tag = addRowLabel(row, ratio, UDim2.new(1, -100, 0, 34), UDim2.fromOffset(90, 18), Enum.Font.GothamBold, 12, getMarketColor(listing))
	tag.TextXAlignment = Enum.TextXAlignment.Right

	row.Activated:Connect(function()
		selectedSlot = listing.slot
		if editingSlot ~= listing.slot then
			editingSlot = nil
		end
		render()
	end)
	row.MouseEnter:Connect(function()
		showTooltip(row, listing, kind)
	end)
	row.MouseLeave:Connect(hideTooltip)
end

local function buildEmptyListing(slot: number)
	local row = makeListingRow(slot, false)
	row.AutoButtonColor = false
	row.BackgroundTransparency = 0.5
	addRowLabel(row, `{slot}. Empty slot`, UDim2.fromOffset(14, 0), UDim2.new(1, -140, 1, 0), Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
	local add = UIKit.button(row, "+ Add card", UIKit.Colors.Accent)
	add.AnchorPoint = Vector2.new(1, 0.5)
	add.Position = UDim2.new(1, -10, 0.5, 0)
	add.Size = UDim2.fromOffset(116, 44)
	add.TextSize = 15
	add.Activated:Connect(function()
		openPicker(slot)
	end)
end

-- Details pane -----------------------------------------------------------------------------------------

local function addPaneButton(text: string, color: Color3, y: number, onTap: () -> ()): TextButton
	local button = UIKit.button(detailPane, text, color)
	button.Position = UDim2.fromOffset(8, y)
	button.Size = UDim2.new(1, -16, 0, 48)
	button.TextSize = 17
	button.Activated:Connect(onTap)
	return button
end

-- The price editor: [- step] [ $price ] [+ step], typed prices on Collector Cases, then Done
local function buildPriceEditor(listing: Listing, kind: string, y: number): number
	local step = CardRules.getPriceStep(listing.card, listing.foil, listing.growth.level, listing.growth.stars, listing.growth.grade)
	local stepper = Instance.new("Frame")
	stepper.Position = UDim2.fromOffset(8, y)
	stepper.Size = UDim2.new(1, -16, 0, 48)
	stepper.BackgroundTransparency = 1
	stepper.Parent = detailPane

	local minus = UIKit.button(stepper, string.format("- $%.2f", step), STEP_BUTTON_COLOR)
	minus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	minus.TextSize = 14
	minus.Activated:Connect(function()
		nudge(listing.slot, listing.card, listing.foil, listing.growth, listing.price, -1)
	end)

	local priceText = string.format("$%.2f", listing.price)
	if kind == "PlayerCards" then
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Type a price"
		box.Text = priceText
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 22
		box.TextColor3 = PRICE_TEXT_COLOR
		box.FocusLost:Connect(function()
			setTypedPrice(listing.slot, listing.card, listing.foil, listing.growth, box)
		end)
		box.Parent = stepper
		placePriceBox(box)
	else
		local label = UIKit.label(stepper, priceText, Enum.Font.FredokaOne, 22, PRICE_TEXT_COLOR)
		label.TextXAlignment = Enum.TextXAlignment.Center
		placePriceBox(label)
	end

	local plus = UIKit.button(stepper, string.format("+ $%.2f", step), STEP_BUTTON_COLOR)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)
	plus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	plus.TextSize = 14
	plus.Activated:Connect(function()
		nudge(listing.slot, listing.card, listing.foil, listing.growth, listing.price, 1)
	end)
	y += 54

	if kind == "PlayerCards" then
		local hint = UIKit.label(detailPane, "Tap the price to type one.", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, y)
		hint.Size = UDim2.new(1, -20, 0, 16)
		y += 20
	end
	addPaneButton("Done", UIKit.Colors.Accent, y, function()
		editingSlot = nil
		render()
	end)
	return y + 54
end

local function renderDetailPane(listings: { [number]: Listing }, kind: string, isEmpty: boolean)
	clearChildren(detailPane)
	local listing = if selectedSlot then listings[selectedSlot] else nil
	if not listing then
		local message = if isEmpty
			then "This case is empty. Tap + Add card to list one from your binder."
			else "Select a card to see its details."
		local empty = UIKit.label(detailPane, message, Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		empty.Position = UDim2.fromOffset(10, 10)
		empty.Size = UDim2.new(1, -20, 0, 60)
		return
	end

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 8)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = detailPane
	makeCardFace(faceHolder, listing.card, listing.foil, true, listing.growth)

	local info = UIKit.label(detailPane, describeDetails(listing, kind), Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	info.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 16, 8)
	info.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 22), 0, DETAIL_FACE_SIZE.Y)
	info.TextYAlignment = Enum.TextYAlignment.Top

	local y = DETAIL_FACE_SIZE.Y + 16
	local priceLine = UIKit.label(detailPane, string.format("Your price  $%.2f", listing.price), Enum.Font.FredokaOne, 22, PRICE_TEXT_COLOR)
	priceLine.Position = UDim2.fromOffset(10, y)
	priceLine.Size = UDim2.new(1, -20, 0, 28)
	y += 34

	if editingSlot == listing.slot then
		buildPriceEditor(listing, kind, y)
		return
	end
	addPaneButton("Set price", STEP_BUTTON_COLOR, y, function()
		editingSlot = listing.slot
		render()
	end)
	addPaneButton("Remove", UIKit.Colors.Danger, y + 54, function()
		pending[listing.slot] = nil
		editingSlot = nil
		Remotes.RemoveDisplayedCard:FireServer(casePart and casePart:GetAttribute("ShelfUid"), listing.slot)
	end)
end

render = function()
	local part = casePart
	if not part then
		return
	end
	local def = Shelves.ById[part.Name]
	if not def then
		return
	end
	hideTooltip()
	clearChildren(list)
	local listings: { [number]: Listing } = {}
	local firstFilled: number? = nil
	for slot = 1, def.capacity do
		local cardPart = getCardPart(slot)
		local listing = if cardPart then readListing(slot, cardPart) else nil
		if listing then
			listings[slot] = listing
			firstFilled = firstFilled or slot
		end
	end
	-- Keep the selection on a listed card; a sold or removed one falls back to the first listing
	if not (selectedSlot and listings[selectedSlot]) then
		selectedSlot = firstFilled
	end
	if editingSlot and not listings[editingSlot] then
		editingSlot = nil
	end
	for slot = 1, def.capacity do
		local listing = listings[slot]
		if listing then
			buildListingRow(listing, def.kind)
		else
			buildEmptyListing(slot)
		end
	end
	renderDetailPane(listings, def.kind, firstFilled == nil)
end

local function refreshFilterButtons()
	for filter, button in filterButtons do
		button.BackgroundColor3 = if filter == pickerFilter then UIKit.Colors.Accent else UIKit.Colors.Row
	end
end

-- One choice in the picker: a stack of plain copies (card, grade, foil) or one levelled card
type PickerEntry = {
	key: string,
	card: Card,
	foil: boolean,
	growth: CopyGrowth,
	beastId: string?,
	count: number,
}

local function describeCopy(entry: PickerEntry): string
	local card, growth = entry.card, entry.growth
	local stats = BeastRules.getStats(card, entry.foil, growth.level, growth.stars, growth.grade)
	local power = BeastRules.getPower(card, entry.foil, growth.level, growth.stars, growth.grade)
	local market = CardRules.getMarketValue(card, entry.foil, growth.level, growth.stars, growth.grade)
	return table.concat({
		`{card.name}{if entry.foil then " (FOIL)" else ""}`,
		`{card.rarity} · {card.element} · #{card.number}`,
		`{BeastRules.describeGrade(growth.grade)} · {BeastRules.describeGrowth(growth.level, growth.stars)}`,
		`Power {power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`,
		string.format("Market $%.2f", market),
		if entry.beastId then "Levelled card" else `You have x{entry.count} of this copy`,
	}, "\n")
end

local function listEntry(entry: PickerEntry)
	local part, slot = casePart, pickerSlot
	picker.Visible = false
	if not part or not slot then
		return
	end
	if entry.beastId then
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, entry.beastId)
	else
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, nil, entry.growth.grade)
	end
end

-- Right side of the picker: the chosen card large, its details and the List button
local function renderPickerPane(entry: PickerEntry?)
	clearChildren(pickerPane)
	if not entry then
		local hint = UIKit.label(pickerPane, "Tap a card to see its details.", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, 10)
		hint.Size = UDim2.new(1, -20, 0, 40)
		return
	end
	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 8)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = pickerPane
	makeCardFace(faceHolder, entry.card, entry.foil, true, entry.growth)

	local info = UIKit.label(pickerPane, describeCopy(entry), Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	info.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 16, 8)
	info.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 22), 0, DETAIL_FACE_SIZE.Y)
	info.TextYAlignment = Enum.TextYAlignment.Top

	local listButton = UIKit.button(pickerPane, `List in slot {pickerSlot or 0}`, UIKit.Colors.Accent)
	listButton.Position = UDim2.fromOffset(8, DETAIL_FACE_SIZE.Y + 16)
	listButton.Size = UDim2.new(1, -16, 0, 48)
	listButton.TextSize = 17
	listButton.Activated:Connect(function()
		listEntry(entry)
	end)
end

local renderPicker: () -> ()

-- Card face with grade/count and value underneath, so the grid stays readable
local function buildPickerTile(entry: PickerEntry, order: number, selected: PickerEntry?, choose: (PickerEntry) -> ())
	local tile = Instance.new("TextButton")
	tile.Name = entry.key
	tile.LayoutOrder = order
	tile.BackgroundColor3 = UIKit.Colors.Row
	tile.Text = ""
	tile.Parent = pickerList
	UIKit.corner(tile, 8)
	if selected and selected.key == entry.key then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = tile
	end

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(4, 4)
	faceHolder.Size = UDim2.new(1, -8, 0, PICKER_FACE_HEIGHT)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = tile
	makeCardFace(faceHolder, entry.card, entry.foil, false)

	local growth = entry.growth
	local detail = if entry.beastId then `{growth.grade} · Lv {growth.level}` else `Grade {growth.grade} · x{entry.count}`
	local line = UIKit.label(tile, detail, Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	line.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 6)
	line.Size = UDim2.new(1, -4, 0, 16)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local market = CardRules.getMarketValue(entry.card, entry.foil, growth.level, growth.stars, growth.grade)
	local value = UIKit.label(tile, string.format("$%.2f", market), Enum.Font.FredokaOne, 15, PRICE_TEXT_COLOR)
	value.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 24)
	value.Size = UDim2.new(1, -4, 0, 18)
	value.TextXAlignment = Enum.TextXAlignment.Center

	tile.Activated:Connect(function()
		choose(entry)
	end)
	-- With a mouse, hovering selects, so the details (and List) always match the tile under the cursor
	tile.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not (selected and selected.key == entry.key) then
			choose(entry)
		end
	end)
end

-- Every copy the player can list: levelled cards (most valuable first), then plain stacks rarest first,
-- best grade and foil first
local function getPickerEntries(): { PickerEntry }
	local entries: { PickerEntry } = {}
	local raised = {}
	for _, beast in BinderController.GetBeasts() do
		table.insert(raised, beast)
	end
	table.sort(raised, function(a, b)
		local cardA, cardB = Cards.ById[a.cardId], Cards.ById[b.cardId]
		return BeastRules.getValue(cardA, a.foil, a.level, a.stars, a.grade) > BeastRules.getValue(cardB, b.foil, b.level, b.stars, b.grade)
	end)
	for _, beast in raised do
		local card = Cards.ById[beast.cardId]
		if card and passesFilter(card, beast.foil) then
			table.insert(entries, {
				key = beast.id,
				card = card,
				foil = beast.foil,
				growth = { level = beast.level, stars = beast.stars, grade = beast.grade },
				beastId = beast.id,
				count = 1,
			})
		end
	end
	local graded = BinderController.GetGradedStacks()
	for _, card in Cards.RarestFirst do
		local byGrade = graded[card.id] or {}
		for index = #BeastRules.GRADES, 1, -1 do
			local grade = BeastRules.GRADES[index]
			local owned = byGrade[grade]
			for _, foil in { true, false } do
				local count = if owned then (if foil then owned.foil else owned.normal) else 0
				if count > 0 and passesFilter(card, foil) then
					table.insert(entries, {
						key = `{card.id}:{grade}:{foil}`,
						card = card,
						foil = foil,
						growth = { level = 1, stars = BeastRules.START_STARS, grade = grade },
						count = count,
					})
				end
			end
		end
	end
	return entries
end

-- Grid of cards on the left, details and the List button on the right
renderPicker = function()
	clearChildren(pickerList)
	refreshFilterButtons()
	local entries = getPickerEntries()
	local selected: PickerEntry? = nil
	for _, entry in entries do
		if entry.key == pickerSelectedKey then
			selected = entry
		end
	end
	selected = selected or entries[1]
	pickerSelectedKey = if selected then selected.key else nil

	for order, entry in entries do
		buildPickerTile(entry, order, selected, function(chosen)
			pickerSelectedKey = chosen.key
			renderPicker()
		end)
	end
	if #entries == 0 then
		local binderEmpty = next(BinderController.GetCollection()) == nil and next(BinderController.GetBeasts()) == nil
		local message = if binderEmpty then "Your binder is empty. Rip some packs first." else "No cards match this filter."
		local empty = UIKit.label(pickerList, message, Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
		empty.Size = UDim2.fromOffset(300, 60)
	end
	renderPickerPane(selected)
end

openPicker = function(slot: number)
	pickerSlot = slot
	pickerSelectedKey = nil
	pickerTitle.Text = `Choose a card for slot {slot}`
	renderPicker()
	picker.Visible = true
end

local function buildPicker(parent: Instance)
	picker, pickerList = UIKit.panel(parent, "CardPicker", "Pick a card")
	picker.ZIndex = UIKit.PANEL_Z_INDEX + 1 -- over the case manager it opens from
	-- Same size as the case manager so it covers it completely
	picker.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = picker:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	pickerTitle = picker:FindFirstChild("Title") :: TextLabel
	pickerTitle.TextSize = 22

	-- Rarity filter chips; the row scrolls sideways when it's wider than the panel (phones)
	local chips = Instance.new("ScrollingFrame")
	chips.Position = UDim2.fromOffset(12, 62)
	chips.Size = UDim2.new(1, -24, 0, 44)
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.ScrollBarThickness = 3
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.CanvasSize = UDim2.new()
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.Parent = picker
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chips
	for index, filter in getPickerFilters() do
		local chip = UIKit.button(chips, filter, UIKit.Colors.Row)
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(FILTER_CHIP_WIDTH, 40)
		chip.TextSize = 15
		local tier = Rarities.Tiers[filter]
		if tier then
			chip.TextColor3 = tier.color
		end
		chip.Activated:Connect(function()
			pickerFilter = filter
			renderPicker()
		end)
		filterButtons[filter] = chip
	end

	-- Grid of card tiles on the left
	pickerList.Position = UDim2.fromOffset(12, 112)
	pickerList.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -124)
	local listLayout = pickerList:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(PICKER_TILE_SIZE.X, PICKER_TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = pickerList

	-- Details of the chosen card on the right
	pickerPane = Instance.new("ScrollingFrame")
	pickerPane.Name = "Details"
	pickerPane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 112)
	pickerPane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -124)
	pickerPane.BackgroundColor3 = UIKit.Colors.Row
	pickerPane.BackgroundTransparency = 0.4
	pickerPane.BorderSizePixel = 0
	pickerPane.ScrollBarThickness = 4
	pickerPane.CanvasSize = UDim2.new()
	pickerPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerPane.Parent = picker
	UIKit.corner(pickerPane, 10)
end

local function disconnectCase()
	for _, connection in caseConnections do
		connection:Disconnect()
	end
	table.clear(caseConnections)
end

-- Opens the manager for one of your own card cases
function ShowcaseController.Open(part: BasePart)
	local def = Shelves.ById[part.Name]
	if not def or (def.kind ~= "CustomerCards" and def.kind ~= "PlayerCards") then
		return
	end
	disconnectCase()
	casePart = part
	pending = {}
	selectedSlot = nil
	editingSlot = nil
	titleLabel.Text = def.name
	subtitle.Text = KIND_DESCRIPTIONS[def.kind] or ""

	-- Re-render whenever cards arrive, leave (sold or removed) or change price
	local function watchCard(child: Instance)
		if child:IsA("BasePart") then
			table.insert(caseConnections, child:GetAttributeChangedSignal("Price"):Connect(render))
		end
	end
	for _, child in part:GetChildren() do
		watchCard(child)
	end
	table.insert(caseConnections, part.ChildAdded:Connect(function(child)
		watchCard(child)
		render()
	end))
	table.insert(caseConnections, part.ChildRemoved:Connect(render))
	table.insert(caseConnections, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			panel.Visible = false
		end
	end))

	render()
	picker.Visible = false
	panel.Visible = true
end

function ShowcaseController.Start()
	local screenGui = UIController.GetScreenGui()

	panel, list = UIKit.panel(screenGui, "CardCase", "Cards")
	titleLabel = panel:FindFirstChild("Title") :: TextLabel
	subtitle = UIKit.label(panel, "", Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	-- Marketplace layout: listings on the left, details of the selected one on the right
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	list.Position = UDim2.fromOffset(12, 84)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -96)

	detailPane = Instance.new("ScrollingFrame")
	detailPane.Name = "Details"
	detailPane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 84)
	detailPane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -96)
	detailPane.BackgroundColor3 = UIKit.Colors.Row
	detailPane.BackgroundTransparency = 0.4
	detailPane.BorderSizePixel = 0
	detailPane.ScrollBarThickness = 4
	detailPane.CanvasSize = UDim2.new()
	detailPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailPane.Parent = panel
	UIKit.corner(detailPane, 10)

	tooltip = Instance.new("Frame")
	tooltip.Name = "CardTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Panel
	tooltip.ZIndex = 50
	tooltip.Visible = false
	tooltip.Parent = screenGui
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

	buildPicker(screenGui)

	-- Binder changes (a card going on display) refresh the picker if it's open
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		if picker.Visible then
			renderPicker()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			picker.Visible = false
			hideTooltip()
			disconnectCase()
			casePart = nil
		end
	end)
end

return ShowcaseController
