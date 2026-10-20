--!strict
-- Managing your own card case (Glass Showcase or Collector Case): one row per slot to price cards
-- with +/- or take them back, and a visual card picker (with rarity filters) to fill empty slots.
-- Opened from the case's Edit menu. The server checks every change; this reads the case's card parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
type PickerFilter = "All" | "Rare+" | "Epic+" | "Foil"

local PICKER_FILTERS: { PickerFilter } = { "All", "Rare+", "Epic+", "Foil" }
local PICKER_TILE_SIZE = Vector2.new(96, 136)
local THUMBNAIL_SIZE = Vector2.new(36, 50)

local SEND_DELAY = 0.4 -- price taps are sent together once tapping stops
local KIND_DESCRIPTIONS = {
	CustomerCards = "Customers may buy these at your price.",
	PlayerCards = "Other players can buy these at your price.",
}

local ShowcaseController = {}

local panel: Frame
local list: ScrollingFrame
local titleLabel: TextLabel
local subtitle: TextLabel
local picker: Frame
local pickerList: ScrollingFrame
local pickerTitle: TextLabel
local filterButtons: { [PickerFilter]: TextButton } = {}
local pickerFilter: PickerFilter = "All"

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

local function describe(card: Card, foil: boolean): string
	return if foil then `{card.name} (FOIL)` else card.name
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

-- A displayed card's level and stars (1, 1 for a fresh copy)
local function getGrowthFromPart(part: BasePart): (number, number)
	local level, stars = part:GetAttribute("Level"), part:GetAttribute("Stars")
	return if typeof(level) == "number" then level else 1, if typeof(stars) == "number" then stars else 1
end

local function getRarityOrder(card: Card): number
	local tier = Rarities.Tiers[card.rarity]
	return if tier then tier.order else 0
end

local function passesFilter(card: Card, foil: boolean): boolean
	if pickerFilter == "Foil" then
		return foil
	elseif pickerFilter == "Rare+" then
		return getRarityOrder(card) >= Rarities.Tiers.Rare.order
	elseif pickerFilter == "Epic+" then
		return getRarityOrder(card) >= Rarities.Tiers.Epic.order
	end
	return true
end

local FILLED_ROW_HEIGHT = 144
local STEP_BUTTON_WIDTH = 92
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

local function nudge(slot: number, card: Card, foil: boolean, level: number, stars: number, current: number, direction: number)
	local step = CardRules.getPriceStep(card, foil, level, stars)
	queuePrice(slot, CardRules.clampPrice(current + direction * step, card, foil, level, stars))
end

-- Accepts "275", "$275.50" or "1,200"; anything else puts the current price back.
-- Clamped here for display; the server clamps again.
local function setTypedPrice(slot: number, card: Card, foil: boolean, level: number, stars: number, box: TextBox)
	local cleaned = string.gsub(box.Text, "[%$,%s]", "")
	local typed = tonumber(cleaned)
	if not typed or typed ~= typed then
		render()
		return
	end
	queuePrice(slot, CardRules.clampPrice(typed, card, foil, level, stars))
end

-- The middle of the price stepper, between the - and + buttons
local function placePriceBox(box: GuiObject)
	box.Position = UDim2.fromOffset(STEP_BUTTON_WIDTH + 8, 0)
	box.Size = UDim2.new(1, -2 * (STEP_BUTTON_WIDTH + 8), 1, 0)
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = PRICE_BOX_COLOR
	UIKit.corner(box, 8)
end

-- One filled slot:  name + Remove  /  PRICE  [- step] [ $price ] [+ step]  /  market and buyer hint
local function buildFilledRow(slot: number, cardPart: BasePart, kind: string)
	local card = Cards.ById[cardPart:GetAttribute("CardId") :: string]
	if not card then
		return
	end
	local foil = cardPart:GetAttribute("Foil") == true
	local serverPrice = cardPart:GetAttribute("Price")
	local price = pending[slot] or (if typeof(serverPrice) == "number" then serverPrice else 0)
	local level, stars = getGrowthFromPart(cardPart)
	local grown = level > 1 or stars > 1
	local market = CardRules.getMarketValue(card, foil, level, stars)
	local step = CardRules.getPriceStep(card, foil, level, stars)

	local frame = Instance.new("Frame")
	frame.LayoutOrder = slot
	frame.Size = UDim2.new(1, 0, 0, FILLED_ROW_HEIGHT)
	frame.BackgroundColor3 = UIKit.Colors.Row
	frame.Parent = list
	UIKit.corner(frame, 10)

	-- Small card face so the slot's card is recognisable at a glance
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(10, 6)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = frame
	makeCardFace(thumbnail, card, foil, false, if grown then { level = level, stars = stars } else nil)

	local titleText = `{slot}. {describe(card, foil)}`
	if grown then
		titleText ..= ` · {BeastRules.describeGrowth(level, stars)}`
	end
	local title = UIKit.label(frame, titleText, Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	title.Position = UDim2.fromOffset(THUMBNAIL_SIZE.X + 18, 8)
	title.Size = UDim2.new(1, -(THUMBNAIL_SIZE.X + 130), 0, 32)

	local removeButton = UIKit.button(frame, "Remove", UIKit.Colors.Danger)
	removeButton.AnchorPoint = Vector2.new(1, 0)
	removeButton.Position = UDim2.new(1, -10, 0, 8)
	removeButton.Size = UDim2.fromOffset(100, 40)
	removeButton.TextSize = 16
	removeButton.Activated:Connect(function()
		pending[slot] = nil
		Remotes.RemoveDisplayedCard:FireServer(casePart and casePart:GetAttribute("ShelfUid"), slot)
	end)

	-- Price stepper
	local priceHeading = UIKit.label(frame, "PRICE", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	priceHeading.Position = UDim2.fromOffset(12, 60)
	priceHeading.Size = UDim2.fromOffset(60, 16)

	local stepper = Instance.new("Frame")
	stepper.Position = UDim2.fromOffset(12, 78)
	stepper.Size = UDim2.new(1, -24, 0, 44)
	stepper.BackgroundTransparency = 1
	stepper.Parent = frame

	local minus = UIKit.button(stepper, string.format("- $%.2f", step), STEP_BUTTON_COLOR)
	minus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	minus.TextSize = 16
	minus.Activated:Connect(function()
		nudge(slot, card, foil, level, stars, price, -1)
	end)

	-- Collector Cases (sold to players) also take a typed price; Glass Showcases use the steps only
	local priceText = string.format("$%.2f", price)
	if kind == "PlayerCards" then
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Type a price"
		box.Text = priceText
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 24
		box.TextColor3 = PRICE_TEXT_COLOR
		box.FocusLost:Connect(function()
			setTypedPrice(slot, card, foil, level, stars, box)
		end)
		box.Parent = stepper
		placePriceBox(box)
	else
		local label = UIKit.label(stepper, priceText, Enum.Font.FredokaOne, 24, PRICE_TEXT_COLOR)
		label.TextXAlignment = Enum.TextXAlignment.Center
		placePriceBox(label)
	end

	local plus = UIKit.button(stepper, string.format("+ $%.2f", step), STEP_BUTTON_COLOR)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)
	plus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	plus.TextSize = 16
	plus.Activated:Connect(function()
		nudge(slot, card, foil, level, stars, price, 1)
	end)

	-- Market comparison, plus how customers react for a Glass Showcase
	local hint = string.format("Market $%.2f · you're asking %d%% of market", market, math.round(price / market * 100))
	if kind == "PlayerCards" then
		hint = hint .. " · tap the price to type one"
	elseif kind == "CustomerCards" then
		local band = PriceRules.getBand(price, market)
		hint = hint .. " · " .. (if band then band.label else Pricing.NEVER_LABEL)
	end
	local hintLabel = UIKit.label(frame, hint, Enum.Font.Gotham, 13, UIKit.Colors.Subtext)
	hintLabel.Position = UDim2.fromOffset(12, 124)
	hintLabel.Size = UDim2.new(1, -24, 0, 16)
	hintLabel.TextTruncate = Enum.TextTruncate.AtEnd
end

local openPicker: (slot: number) -> ()

local function buildEmptyRow(slot: number)
	local _, addButton = UIKit.row(list, slot, `{slot}. Empty slot`, "Add a card from your binder")
	addButton.Text = "Add"
	addButton.Activated:Connect(function()
		openPicker(slot)
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
	clearChildren(list)
	for slot = 1, def.capacity do
		local cardPart = getCardPart(slot)
		if cardPart then
			buildFilledRow(slot, cardPart, def.kind)
		else
			buildEmptyRow(slot)
		end
	end
end

local function refreshFilterButtons()
	for filter, button in filterButtons do
		button.BackgroundColor3 = if filter == pickerFilter then UIKit.Colors.Accent else UIKit.Colors.Row
	end
end

-- Grid of card faces, rarest first; one tap puts the card in the slot (Remove undoes it)
local function renderPicker()
	clearChildren(pickerList)
	refreshFilterButtons()
	local collection = BinderController.GetCollection()
	local order = 0
	local function addTile(card: Card, foil: boolean, count: number)
		if not passesFilter(card, foil) then
			return
		end
		order += 1
		local tile = Instance.new("TextButton")
		tile.Name = describe(card, foil)
		tile.LayoutOrder = order
		tile.BackgroundTransparency = 1
		tile.Text = ""
		tile.Parent = pickerList
		makeCardFace(tile, card, foil, true)

		local badge = UIKit.label(tile, `x{count}`, Enum.Font.GothamBold, 14, UIKit.Colors.Text)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -4, 0, 4)
		badge.Size = UDim2.fromOffset(34, 20)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0.15
		badge.BackgroundColor3 = UIKit.Colors.Panel
		badge.ZIndex = 3
		UIKit.corner(badge, 6)

		tile.Activated:Connect(function()
			local part = casePart
			local slot = pickerSlot
			picker.Visible = false
			if part and slot then
				Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, card.id, foil)
			end
		end)
	end
	-- Raised beasts first, most valuable first; each tile sends that beast's ID
	local raised = {}
	for _, beast in BinderController.GetBeasts() do
		table.insert(raised, beast)
	end
	table.sort(raised, function(a, b)
		local cardA, cardB = Cards.ById[a.cardId], Cards.ById[b.cardId]
		return BeastRules.getValue(cardA, a.foil, a.level, a.stars) > BeastRules.getValue(cardB, b.foil, b.level, b.stars)
	end)
	for _, beast in raised do
		local card = Cards.ById[beast.cardId]
		if card and passesFilter(card, beast.foil) then
			order += 1
			local tile = Instance.new("TextButton")
			tile.LayoutOrder = order
			tile.BackgroundTransparency = 1
			tile.Text = ""
			tile.Parent = pickerList
			makeCardFace(tile, card, beast.foil, true, { level = beast.level, stars = beast.stars })
			tile.Activated:Connect(function()
				local part, slot = casePart, pickerSlot
				picker.Visible = false
				if part and slot then
					Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, card.id, beast.foil, beast.id)
				end
			end)
		end
	end
	-- Then fresh copies, rarest first: those are the ones worth showing off
	for index = #Cards.List, 1, -1 do
		local card = Cards.List[index]
		local owned = collection[card.id]
		if owned then
			if owned.foil > 0 then
				addTile(card, true, owned.foil)
			end
			if owned.normal > 0 then
				addTile(card, false, owned.normal)
			end
		end
	end
	if order == 0 then
		local binderEmpty = next(collection) == nil and next(BinderController.GetBeasts()) == nil
		local message = if binderEmpty then "Your binder is empty. Rip some packs first." else "No cards match this filter."
		local empty = UIKit.label(pickerList, message, Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
		empty.Size = UDim2.fromOffset(300, 60)
	end
end

openPicker = function(slot: number)
	pickerSlot = slot
	pickerTitle.Text = `Choose a card for slot {slot}`
	renderPicker()
	picker.Visible = true
end

local function buildPicker(parent: Instance)
	picker, pickerList = UIKit.panel(parent, "CardPicker", "Pick a card")
	picker.ZIndex = 5
	pickerTitle = picker:FindFirstChild("Title") :: TextLabel
	pickerTitle.TextSize = 22

	-- Rarity filter chips
	local chips = Instance.new("Frame")
	chips.Position = UDim2.fromOffset(12, 62)
	chips.Size = UDim2.new(1, -24, 0, 40)
	chips.BackgroundTransparency = 1
	chips.Parent = picker
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chips
	for index, filter in PICKER_FILTERS do
		local chip = UIKit.button(chips, filter, UIKit.Colors.Row)
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(76, 40)
		chip.TextSize = 15
		chip.Activated:Connect(function()
			pickerFilter = filter
			renderPicker()
		end)
		filterButtons[filter] = chip
	end

	-- Swap the panel's list layout for a grid of card tiles
	pickerList.Position = UDim2.fromOffset(12, 110)
	pickerList.Size = UDim2.new(1, -24, 1, -122)
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
	if not def or def.kind == "Products" then
		return
	end
	disconnectCase()
	casePart = part
	pending = {}
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
	list.Position = UDim2.fromOffset(12, 84)
	list.Size = UDim2.new(1, -24, 1, -96)

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
			disconnectCase()
			casePart = nil
		end
	end)
end

return ShowcaseController
