--!strict
-- Managing your own card case (Glass Showcase or Collector Case), laid out like an MMO marketplace:
-- a listings table on the left, the selected card's details on the right (hover a row with a mouse for a
-- tooltip), a "Set price" editor that opens on demand, and a card picker (with rarity filters) for empty slots.
-- Opened from the case's Edit menu. The server checks every change; this reads the case's card parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Pricing = require(Config:WaitForChild("Pricing"))
local Rarities = require(Config:WaitForChild("Rarities"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Shelves = require(Config:WaitForChild("Shelves"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local PriceTaps = require(Shared:WaitForChild("Util"):WaitForChild("PriceTaps"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ElementBadge = require(ClientUtil:WaitForChild("ElementBadge"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Beasts = require(Config:WaitForChild("Beasts"))
local DefeatRules = require(Shared:WaitForChild("Util"):WaitForChild("DefeatRules"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
-- "All", "Foil", or a rarity name (exactly that rarity)
type PickerFilter = string

local ALL_FILTER = "All"
local FOIL_FILTER = "Foil"
local FRONTIER_FILTER = "Frontier"
local FILTER_CHIP_WIDTH = 96
local PICKER_TILE_SIZE = Vector2.new(92, 168) -- card face on top, grade/count and value underneath
local PICKER_FACE_HEIGHT = 118
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local PANEL_MAX_SIZE = Vector2.new(820, 520)
local LIST_WIDTH_SCALE = 0.55 -- listings table share of the panel width; details pane gets the rest
local LISTING_ROW_HEIGHT = 64
local DETAIL_FACE_SIZE = Vector2.new(120, 171)
local TOOLTIP_WIDTH = 240
local NEAR_MARKET_RATIO = 1.5

local SEND_DELAY = 0.4 -- price taps are sent together once tapping stops
local KIND_DESCRIPTIONS = {
	CustomerCards = "Customers may buy these at your price.",
	PlayerCards = "Other players can buy these at your price.",
}

local ShowcaseController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set when it's built
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
-- slot → the price tapped and sent, shown until the card's own price says the same (Util/PriceTaps)
local taps = PriceTaps.new(Pricing.ECHO_SECONDS)
local sendToken = 0
local pickerSlot: number? = nil
local justListed: number? = nil -- the slot a card was just put in: its price editor opens as it arrives
-- Where each price shows, so a price tap changes the words in place (owner 2026-11-18, a phone: the window rebuilt on
-- every tap scrolled back up): each row's price and % of market, and the selected card's details, price line and editor
local rowPrices: { [number]: { price: TextLabel, tag: TextLabel } } = {}
local detailPrice: { slot: number, info: TextLabel, line: TextLabel, editor: GuiObject? }? = nil

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
	local filters: { PickerFilter } = { ALL_FILTER, FRONTIER_FILTER }
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
	elseif pickerFilter == FRONTIER_FILTER then
		return card.set == "Frontier"
	end
	return card.rarity == pickerFilter
end

local STEP_BUTTON_WIDTH = 80
local STEP_BUTTON_COLOR = UIKit.Colors.Secondary -- other choices (sky in the cotton candy look)

local function flush(token: number)
	local part = casePart
	local tapped = if token == sendToken and part then PriceTaps.flush(taps, os.clock()) else nil
	if not tapped or not part then
		return
	end
	local changes = {}
	for slot, price in tapped do
		table.insert(changes, { slot = slot, price = price })
	end
	Remotes.SetCardPrice:FireServer(part:GetAttribute("ShelfUid"), changes)
end

local render: () -> ()
local showPrice: (slot: number) -> ()

local function queuePrice(slot: number, price: number)
	PriceTaps.tap(taps, slot, price)
	showPrice(slot)
	sendToken += 1
	local token = sendToken
	task.delay(SEND_DELAY, flush, token)
end

-- Sends the price taps not sent yet, then puts the case's new cards that wait for their price on sale: one (`slot`,
-- Done) or all of them (the window closed). Server Util/ListingHold (owner 2026-11-17: a new card was bought at
-- 100% market before its price was set)
local function releaseListings(slot: number?)
	local part = casePart
	if not part then
		return
	end
	sendToken += 1
	flush(sendToken)
	Remotes.ReleaseListings:FireServer(part:GetAttribute("ShelfUid"), slot)
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
		showPrice(slot)
		return
	end
	queuePrice(slot, CardRules.clampPrice(typed, card, foil, growth.level, growth.stars, growth.grade))
end

-- The middle of the price stepper, between the - and + buttons
local function placePriceBox(box: GuiObject)
	box.Position = UDim2.fromOffset(STEP_BUTTON_WIDTH + 6, 0)
	box.Size = UDim2.new(1, -2 * (STEP_BUTTON_WIDTH + 6), 1, 0)
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = palette.row
	UIKit.corner(box, 8)
	UIKit.outline(box, palette.rowEdge, 2)
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
	held: boolean, -- new, waiting for its price: nobody buys it yet (server Util/ListingHold)
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
		price = PriceTaps.shown(taps, slot, if typeof(serverPrice) == "number" then serverPrice else 0, os.clock()),
		market = CardRules.getMarketValue(card, foil, level, stars, grade),
		stats = BeastRules.getStats(card, foil, level, stars, grade),
		power = BeastRules.getPower(card, foil, level, stars, grade),
		held = cardPart:GetAttribute("PricingHold") == true,
	}
end

local function getMarketRatio(listing: Listing): number
	return if listing.market > 0 then listing.price / listing.market else math.huge
end

local function getMarketColor(listing: Listing): Color3
	local ratio = getMarketRatio(listing)
	-- At or under market sells easily; up to NEAR_MARKET_RATIO is fair; above that is pricey
	return if ratio <= 1 + 1e-6
		then palette.good
		elseif ratio <= NEAR_MARKET_RATIO then palette.fair
		else palette.bad
end

-- A row's small tag under its price. In a Glass Showcase: how many customers buy at this price ("Always buy", "33%
-- buy", "Won't buy"), which falls with every step up like a product's (owner 2026-11-20: "also do the same with glass
-- prices"; PriceRules.getTag). In a Collector Case, where players buy: the price against market
local function rowTag(listing: Listing, kind: string): string
	if kind == "CustomerCards" then
		return PriceRules.getTag(listing.price, listing.market)
	end
	return string.format("%d%% of market", math.round(getMarketRatio(listing) * 100))
end

local function describeGrowth(listing: Listing): string
	return `{BeastRules.describeGrade(listing.growth.grade)} · {BeastRules.describeGrowth(listing.growth.level, listing.growth.stars)}`
end

-- The full details, shared by the tooltip and the details pane
local function describeDetails(listing: Listing, kind: string): string
	local stats = listing.stats
	local lines = {
		`{listing.card.name}{if listing.foil then " (FOIL)" else ""}`,
		`{listing.card.rarity} · {ElementBadge.name(listing.card.element)} · #{listing.card.number}`,
		describeGrowth(listing),
		`Power {listing.power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`,
		string.format("Market $%.2f · asking %d%%", listing.market, math.round(getMarketRatio(listing) * 100)),
	}
	if kind == "CustomerCards" then
		local band = PriceRules.getBand(listing.price, listing.market)
		-- past the first band, how many buy at this price too (it slides inside a band: PriceRules.getChance)
		local first = band == Pricing.BUY_BANDS[1]
		local share = math.max(1, math.round(PriceRules.getChance(listing.price, listing.market) * 100))
		table.insert(lines, `Customers: {if not band then Pricing.NEVER_LABEL elseif first then band.label else `{band.label} ({share}%)`}`)
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
	row.BackgroundColor3 = palette.row
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
	makeCardFace(thumbnail, listing.card, listing.foil, false, listing.growth) -- its own grade on the face

	local textX = THUMBNAIL_SIZE.X + 14
	local name = `{listing.slot}. {listing.card.name}{if listing.foil then " FOIL" else ""}`
	addRowLabel(row, name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + 104), 0, 20), Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	addRowLabel(row, describeGrowth(listing), UDim2.fromOffset(textX, 32), UDim2.new(1, -(textX + 104), 0, 18), Enum.Font.Gotham, 12, UIKit.Colors.Subtext)

	local price = addRowLabel(row, string.format("$%.2f", listing.price), UDim2.new(1, -100, 0, 6), UDim2.fromOffset(90, 24), Enum.Font.FredokaOne, 19, palette.good)
	price.TextXAlignment = Enum.TextXAlignment.Right
	local tag = addRowLabel(row, rowTag(listing, kind), UDim2.new(1, -100, 0, 34), UDim2.fromOffset(90, 18), Enum.Font.GothamBold, 12, getMarketColor(listing))
	tag.TextXAlignment = Enum.TextXAlignment.Right
	rowPrices[listing.slot] = { price = price, tag = tag }

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

	-- A tap changes the price where it shows (showPrice), so each one starts from the price as it is now
	local function tapStep(direction: number)
		local cardPart = getCardPart(listing.slot)
		local now = if cardPart then readListing(listing.slot, cardPart) else nil
		if now then
			nudge(now.slot, now.card, now.foil, now.growth, now.price, direction)
		end
	end
	local minus = UIKit.button(stepper, string.format("- $%.2f", step), STEP_BUTTON_COLOR)
	minus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	minus.TextSize = 14
	minus.Activated:Connect(function()
		tapStep(-1)
	end)

	local priceText = string.format("$%.2f", listing.price)
	if kind == "PlayerCards" then
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Type a price"
		box.Text = priceText
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 22
		box.TextColor3 = palette.good
		box.FocusLost:Connect(function()
			setTypedPrice(listing.slot, listing.card, listing.foil, listing.growth, box)
		end)
		box.Parent = stepper
		placePriceBox(box)
		if detailPrice and detailPrice.slot == listing.slot then
			detailPrice.editor = box
		end
	else
		local label = UIKit.label(stepper, priceText, Enum.Font.FredokaOne, 22, palette.good)
		label.TextXAlignment = Enum.TextXAlignment.Center
		placePriceBox(label)
		if detailPrice and detailPrice.slot == listing.slot then
			detailPrice.editor = label
		end
	end

	local plus = UIKit.button(stepper, string.format("+ $%.2f", step), STEP_BUTTON_COLOR)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)
	plus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	plus.TextSize = 14
	plus.Activated:Connect(function()
		tapStep(1)
	end)
	y += 54

	if kind == "PlayerCards" then
		local hint = UIKit.label(detailPane, "Tap the price to type one.", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, y)
		hint.Size = UDim2.new(1, -20, 0, 16)
		y += 20
	end
	if listing.held then
		local who = if kind == "PlayerCards" then "Players" else "Customers"
		local wait = UIKit.label(detailPane, `{who} can't buy it until you press Done.`, Enum.Font.GothamBold, 12, palette.good)
		wait.Name = "PricingHold"
		wait.Position = UDim2.fromOffset(10, y)
		wait.Size = UDim2.new(1, -20, 0, 16)
		y += 20
	end
	addPaneButton("Done", UIKit.Colors.Accent, y, function()
		editingSlot = nil
		releaseListings(listing.slot)
		render()
	end)
	return y + 54
end

local function renderDetailPane(listings: { [number]: Listing }, kind: string, isEmpty: boolean)
	clearChildren(detailPane)
	detailPrice = nil
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
	local priceLine = UIKit.label(detailPane, string.format("Your price  $%.2f", listing.price), Enum.Font.FredokaOne, 22, palette.good)
	priceLine.Position = UDim2.fromOffset(10, y)
	priceLine.Size = UDim2.new(1, -20, 0, 28)
	y += 34
	detailPrice = { slot = listing.slot, info = info, line = priceLine, editor = nil }

	if editingSlot == listing.slot then
		buildPriceEditor(listing, kind, y)
		return
	end
	addPaneButton("Set price", STEP_BUTTON_COLOR, y, function()
		editingSlot = listing.slot
		render()
	end)
	addPaneButton("Remove", UIKit.Colors.Danger, y + 54, function()
		PriceTaps.forget(taps, listing.slot)
		editingSlot = nil
		Remotes.RemoveDisplayedCard:FireServer(casePart and casePart:GetAttribute("ShelfUid"), listing.slot)
	end)
end

-- One card's price changed (a tap, a typed price, the server's echo): its row, and the details while it's the selected
-- card, show it where they are; nothing is rebuilt, so a phone's scrolled window stays put (owner 2026-11-18)
showPrice = function(slot: number)
	local part = casePart
	local cardPart = getCardPart(slot)
	local listing = if cardPart then readListing(slot, cardPart) else nil
	if not part or not listing then
		render()
		return
	end
	local def = Shelves.ById[part.Name]
	local row = rowPrices[slot]
	if row and row.price.Parent then
		row.price.Text = string.format("$%.2f", listing.price)
		row.tag.Text = rowTag(listing, if def then def.kind else "")
		row.tag.TextColor3 = getMarketColor(listing)
	end
	local detail = detailPrice
	if detail and detail.slot == slot and detail.line.Parent then
		detail.info.Text = describeDetails(listing, if def then def.kind else "")
		detail.line.Text = string.format("Your price  $%.2f", listing.price)
		local editor = detail.editor
		if editor and editor.Parent and not (editor:IsA("TextBox") and editor:IsFocused()) then
			(editor :: any).Text = string.format("$%.2f", listing.price)
		end
	end
end

-- Each pane back where the player had scrolled it after a rebuild, and once more a moment later (a phone's scroll
-- settling after the tapped button was rebuilt under the finger)
local function keepScroll(pane: ScrollingFrame, at: Vector2)
	pane.CanvasPosition = at
	RunService.Heartbeat:Once(function()
		if pane.Parent then
			pane.CanvasPosition = at
		end
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
	local listAt, detailAt = list.CanvasPosition, detailPane.CanvasPosition
	clearChildren(list)
	rowPrices = {}
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
	-- A card just put out opens its price editor: it waits for its price until Done
	if justListed and listings[justListed] then
		selectedSlot, editingSlot = justListed, justListed
		justListed = nil
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
	keepScroll(list, listAt)
	keepScroll(detailPane, detailAt)
end

local function refreshFilterButtons()
	for filter, button in filterButtons do
		button.BackgroundColor3 = if filter == pickerFilter then UIKit.Colors.Accent else palette.row
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

local function listEntry(entry: PickerEntry)
	local part, slot = casePart, pickerSlot
	picker.Visible = false
	if not part or not slot then
		return
	end
	justListed = slot
	if entry.beastId then
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, entry.beastId)
	else
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, nil, entry.growth.grade)
	end
end

-- The picker's card sheet (owner 2026-11-18: "Choose a card for slot 2: Design the card details. right now it's just a
-- bunch of text. make it more detailed and easier to understand"; option A of three mockups, the stat sheet): the card
-- large, its name, chips for rarity, element and grade, its stars and level, four stat tiles with their icons, what it's
-- worth in a gold box, how many you have, then List
local SHEET_GOLD = Color3.fromRGB(255, 243, 201)
local SHEET_GOLD_TEXT = Color3.fromRGB(138, 90, 0)
local SHEET_WHITE = Color3.new(1, 1, 1)
local SHEET_INK = Color3.fromRGB(74, 63, 92)

local function sheetChip(parent: Instance, text: string, fill: Color3, ink: Color3, order: number): TextLabel
	local chip = UIKit.label(parent, text, Enum.Font.FredokaOne, 13, ink)
	chip.LayoutOrder = order
	chip.TextWrapped = false
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 22)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = fill
	UIKit.corner(chip, 11)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = chip
	return chip
end

-- The element's chip: its icon, then its name, on a soft lilac pill
local SHEET_LILAC = Color3.fromRGB(232, 222, 250)

local function elementChip(parent: Instance, key: string, order: number)
	local chip = Instance.new("Frame")
	chip.LayoutOrder = order
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 22)
	chip.BackgroundColor3 = SHEET_LILAC
	chip.Parent = parent
	UIKit.corner(chip, 11)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 8)
	pad.Parent = chip
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 3)
	row.Parent = chip
	local image = ElementBadge.image(key)
	if image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.LayoutOrder = 1
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(16, 16)
		icon.Image = image
		icon.Parent = chip
	end
	local text = UIKit.label(chip, ElementBadge.name(key), Enum.Font.FredokaOne, 13, SHEET_INK)
	text.LayoutOrder = 2
	text.TextWrapped = false
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, 22)
end

-- A stat as it reads: whole numbers with commas, attack speed with one decimal
local function statText(value: number): string
	return if value ~= math.floor(value) then string.format("%.1f", value) else DefeatRules.number(value)
end

local function listFrame(parent: Instance, order: number, height: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height or 0)
	frame.AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	frame.Parent = parent
	return frame
end

local function stack(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

-- Right side of the picker: the chosen card's sheet and the List button
local function renderPickerPane(entry: PickerEntry?)
	clearChildren(pickerPane)
	if not pickerPane:FindFirstChild("SheetLayout") then
		stack(pickerPane, false, 8).Name = "SheetLayout"
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = pickerPane
	end
	if not entry then
		local hint = UIKit.label(pickerPane, "Tap a card to see its details.", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		hint.Size = UDim2.new(1, 0, 0, 40)
		return
	end
	local card, growth = entry.card, entry.growth
	local stats = BeastRules.getStats(card, entry.foil, growth.level, growth.stars, growth.grade)
	local power = BeastRules.getPower(card, entry.foil, growth.level, growth.stars, growth.grade)
	local market = CardRules.getMarketValue(card, entry.foil, growth.level, growth.stars, growth.grade)

	-- The card, and beside it its name, chips, stars and stats
	local top = listFrame(pickerPane, 1)
	local faceHolder = Instance.new("Frame")
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = top
	makeCardFace(faceHolder, card, entry.foil, true, growth)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 10, 0)
	column.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 10), 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = top
	stack(column, false, 6)

	local name = UIKit.label(column, `{card.name}{if entry.foil then " FOIL" else ""}`, Enum.Font.FredokaOne, 20, UIKit.Colors.Text)
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local chips = listFrame(column, 2)
	stack(chips, true, 4).Wraps = true
	sheetChip(chips, card.rarity, CardFace.getRarityColor(card.rarity), SHEET_WHITE, 1)
	elementChip(chips, card.element, 2)
	sheetChip(chips, BeastRules.describeGrade(growth.grade), CardDesign.GRADE_COLORS[growth.grade] or CardDesign.GRADE_COLORS.C, SHEET_WHITE, 3)

	local starsRow = listFrame(column, 3)
	local starsFlow = stack(starsRow, true, 2)
	starsFlow.VerticalAlignment = Enum.VerticalAlignment.Center
	starsFlow.Wraps = true -- a narrow phone pane: the level goes under the stars
	for star = 1, Beasts.MAX_STARS do
		local icon = Icon.make(starsRow, "Star", UDim2.fromOffset(16, 16))
		icon.LayoutOrder = star
		if star > growth.stars then
			for _, image in icon:GetDescendants() do
				if image:IsA("ImageLabel") then
					image.ImageTransparency = 0.75 -- a star not earned yet
				end
			end
		end
	end
	local level = UIKit.label(starsRow, `  Lv {growth.level} · #{card.number}`, Enum.Font.GothamBold, 12, UIKit.Colors.Subtext)
	level.LayoutOrder = Beasts.MAX_STARS + 1
	level.TextWrapped = false
	level.AutomaticSize = Enum.AutomaticSize.X
	level.Size = UDim2.fromOffset(0, 18)

	local grid = listFrame(column, 4, 82)
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(0.5, -3, 0, 38)
	cells.CellPadding = UDim2.fromOffset(6, 6)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	for order, stat in { { "Power", "Power", power }, { "Hp", "HP", stats.hp }, { "Atk", "ATK", stats.atk }, { "Spd", "SPD", stats.spd } } do
		local tile = Instance.new("Frame")
		tile.LayoutOrder = order
		tile.BackgroundColor3 = palette.row
		tile.Parent = grid
		UIKit.corner(tile, 8)
		local icon = Icon.make(tile, stat[1], UDim2.fromOffset(20, 20))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 6, 0.5, 0)
		local value = UIKit.label(tile, statText(stat[3]), Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
		value.Position = UDim2.fromOffset(30, 2)
		value.Size = UDim2.new(1, -34, 0, 20)
		value.TextWrapped = false
		local word = UIKit.label(tile, stat[2], Enum.Font.GothamBold, 10, UIKit.Colors.Subtext)
		word.Position = UDim2.fromOffset(30, 21)
		word.Size = UDim2.new(1, -34, 0, 14)
	end

	-- What it's worth, in gold
	local worth = listFrame(pickerPane, 2, 44)
	worth.BackgroundTransparency = 0
	worth.BackgroundColor3 = SHEET_GOLD
	UIKit.corner(worth, 10)
	local cash = Icon.make(worth, "Cash", UDim2.fromOffset(22, 22))
	cash.AnchorPoint = Vector2.new(0, 0.5)
	cash.Position = UDim2.new(0, 10, 0.5, 0)
	local worthWord = UIKit.label(worth, "Worth", Enum.Font.GothamBold, 14, SHEET_GOLD_TEXT)
	worthWord.Position = UDim2.fromOffset(38, 0)
	worthWord.Size = UDim2.new(0.5, -38, 1, 0)
	local worthValue = UIKit.label(worth, string.format("$%.2f", market), Enum.Font.FredokaOne, 24, SHEET_GOLD_TEXT)
	worthValue.AnchorPoint = Vector2.new(1, 0)
	worthValue.Position = UDim2.new(1, -12, 0, 0)
	worthValue.Size = UDim2.new(0.5, 0, 1, 0)
	worthValue.TextXAlignment = Enum.TextXAlignment.Right
	worthValue.TextWrapped = false

	local owned = if entry.beastId
		then "Your levelled card: its own level, stars and grade"
		else `You have {entry.count} of this copy`
	local hint = UIKit.label(pickerPane, owned, Enum.Font.GothamBold, 12, UIKit.Colors.Subtext)
	hint.LayoutOrder = 3
	hint.Size = UDim2.new(1, 0, 0, 16)

	local listButton = UIKit.button(pickerPane, `List in slot {pickerSlot or 0}`, UIKit.Colors.Accent)
	listButton.LayoutOrder = 4
	listButton.Size = UDim2.new(1, 0, 0, 48)
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
	tile.BackgroundColor3 = palette.row
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
	-- the copy's own grade on its face (owner 2026-11-16: the tiles said Grade A under a face showing C)
	makeCardFace(faceHolder, entry.card, entry.foil, false, entry.growth)

	local growth = entry.growth
	local detail = if entry.beastId then `{growth.grade} · Lv {growth.level}` else `Grade {growth.grade} · x{entry.count}`
	local line = UIKit.label(tile, detail, Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	line.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 6)
	line.Size = UDim2.new(1, -4, 0, 16)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local market = CardRules.getMarketValue(entry.card, entry.foil, growth.level, growth.stars, growth.grade)
	local value = UIKit.label(tile, string.format("$%.2f", market), Enum.Font.FredokaOne, 15, palette.good)
	value.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 24)
	value.Size = UDim2.new(1, -4, 0, 18)
	value.TextXAlignment = Enum.TextXAlignment.Center

	tile.Activated:Connect(function()
		choose(entry)
	end)
end

-- Every copy the player can list: levelled cards (most valuable first), then plain stacks rarest first,
-- best grade and foil first
local function getPickerEntries(): { PickerEntry }
	local entries: { PickerEntry } = {}
	local raised = {}
	local working = BinderController.GetWorking()
	local partied = BinderController.GetPartied()
	for id, beast in BinderController.GetBeasts() do
		if not working[id] and not partied[id] then -- working and party cards stay where they are
			table.insert(raised, beast)
		end
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
	picker, pickerList = UIKit.panel(parent, "CardPicker", "Pick a card", "Cards")
	picker:SetAttribute("Overlay", true) -- opens over the case's panel
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
	chips.Position = UDim2.fromOffset(12, 60)
	chips.Size = UDim2.new(1, -24, 0, 52)
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
	-- room for the chips' rings and lips, which the row would clip (owner 2026-11-16: "some borders are cutoff")
	UIKit.padList(chips, { side = 4, right = 4, top = 4, bottom = 6 })
	for index, filter in getPickerFilters() do
		local chip = UIKit.button(chips, filter, palette.row)
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(FILTER_CHIP_WIDTH, 40)
		chip.TextSize = 15
		-- A rarity's chip (and the Frontier's) wears its colour as the ring: as text it doesn't read on white
		local tier = Rarities.Tiers[filter]
		local ringColor = if tier then tier.color elseif filter == FRONTIER_FILTER then CardEffects.FRONTIER.AURORA[1] else nil
		for _, ring in chip:GetChildren() do
			if ringColor and ring:IsA("UIStroke") and ring.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
				ring.Color = ringColor
			end
		end
		chip.Activated:Connect(function()
			pickerFilter = filter
			renderPicker()
		end)
		filterButtons[filter] = chip
	end

	-- Grid of card tiles on the left
	pickerList.Position = UDim2.fromOffset(12, 116)
	pickerList.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -128)
	UIKit.padList(pickerList, { side = 6, right = 10, top = 6, bottom = 8 }) -- the chosen tile's gold ring, unclipped
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
	pickerPane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 116)
	pickerPane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -128)
	pickerPane.BackgroundColor3 = palette.slotEmpty -- a deeper cream
	pickerPane.BackgroundTransparency = 0
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
	if casePart and casePart ~= part then
		releaseListings(nil) -- another case: the last one's new cards go on sale
	end
	disconnectCase()
	casePart = part
	PriceTaps.forget(taps, nil)
	selectedSlot = nil
	editingSlot = nil
	justListed = nil
	titleLabel.Text = def.name
	subtitle.Text = KIND_DESCRIPTIONS[def.kind] or ""

	-- Re-render whenever cards arrive, leave (sold or removed) or wait for their price; a new price only changes its words
	local function watchCard(child: Instance)
		if child:IsA("BasePart") then
			table.insert(caseConnections, child:GetAttributeChangedSignal("Price"):Connect(function()
				local slot = child:GetAttribute("Slot")
				if typeof(slot) == "number" then
					showPrice(slot)
				else
					render()
				end
			end))
			table.insert(caseConnections, child:GetAttributeChangedSignal("PricingHold"):Connect(render))
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

	panel, list = UIKit.panel(screenGui, "CardCase", "Cards", "Cards")
	palette = UIKit.colorsFor(panel)
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
	-- room for the selected listing's gold ring, which the list clipped (owner 2026-11-17: "some cut off border here")
	UIKit.padList(list, { side = 4, right = 8, top = 4, bottom = 6 })

	detailPane = Instance.new("ScrollingFrame")
	detailPane.Name = "Details"
	detailPane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 84)
	detailPane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -96)
	detailPane.BackgroundColor3 = palette.slotEmpty -- a deeper cream
	detailPane.BackgroundTransparency = 0
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
	-- Walking away from the case is Done (owner 2026-11-20: "it should be considered done when the player walks away
	-- even if they did not press DONE"): its window closes, which puts its new cards on sale with the prices set (the
	-- server lets them go by itself too: ShowcaseService)
	task.spawn(function()
		local Showcase = require(Config:WaitForChild("Showcase")) :: any
		local localPlayer = game:GetService("Players").LocalPlayer
		while true do
			task.wait(Showcase.WALK_CHECK)
			local part = casePart
			local character = localPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if panel.Visible and part and root and root:IsA("BasePart") and (root.Position - part.Position).Magnitude > Showcase.WALK_AWAY then
				panel.Visible = false
			end
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			releaseListings(nil) -- the window closed: its new cards go on sale with the prices set
			picker.Visible = false
			hideTooltip()
			disconnectCase()
			casePart = nil
			justListed = nil
		end
	end)
end

return ShowcaseController
