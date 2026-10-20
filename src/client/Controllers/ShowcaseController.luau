--!strict
-- Managing your own card case (Glass Showcase or Collector Case): one row per slot to price cards
-- with +/- or take them back, and a picker to fill empty slots from your binder.
-- Opened from the case's Edit menu. The server checks every change; this reads the case's card parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Pricing = require(Config:WaitForChild("Pricing"))
local Shelves = require(Config:WaitForChild("Shelves"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])

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

local FILLED_ROW_HEIGHT = 132
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

local function nudge(slot: number, card: Card, foil: boolean, current: number, direction: number)
	local step = CardRules.getPriceStep(card, foil)
	queuePrice(slot, CardRules.clampPrice(current + direction * step, card, foil))
end

-- Accepts "275", "$275.50" or "1,200"; anything else puts the current price back.
-- Clamped here for display; the server clamps again.
local function setTypedPrice(slot: number, card: Card, foil: boolean, box: TextBox)
	local cleaned = string.gsub(box.Text, "[%$,%s]", "")
	local typed = tonumber(cleaned)
	if not typed or typed ~= typed then
		render()
		return
	end
	queuePrice(slot, CardRules.clampPrice(typed, card, foil))
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
	local market = CardRules.getMarketValue(card, foil)
	local step = CardRules.getPriceStep(card, foil)

	local frame = Instance.new("Frame")
	frame.LayoutOrder = slot
	frame.Size = UDim2.new(1, 0, 0, FILLED_ROW_HEIGHT)
	frame.BackgroundColor3 = UIKit.Colors.Row
	frame.Parent = list
	UIKit.corner(frame, 10)

	local title = UIKit.label(frame, `{slot}. {describe(card, foil)}`, Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -124, 0, 32)

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
	priceHeading.Position = UDim2.fromOffset(12, 50)
	priceHeading.Size = UDim2.fromOffset(60, 16)

	local stepper = Instance.new("Frame")
	stepper.Position = UDim2.fromOffset(12, 68)
	stepper.Size = UDim2.new(1, -24, 0, 44)
	stepper.BackgroundTransparency = 1
	stepper.Parent = frame

	local minus = UIKit.button(stepper, string.format("- $%.2f", step), STEP_BUTTON_COLOR)
	minus.Size = UDim2.new(0, STEP_BUTTON_WIDTH, 1, 0)
	minus.TextSize = 16
	minus.Activated:Connect(function()
		nudge(slot, card, foil, price, -1)
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
			setTypedPrice(slot, card, foil, box)
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
		nudge(slot, card, foil, price, 1)
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
	hintLabel.Position = UDim2.fromOffset(12, 114)
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

local function renderPicker()
	clearChildren(pickerList)
	local collection = BinderController.GetCollection()
	local order = 0
	local function addOption(card: Card, foil: boolean, count: number)
		order += 1
		local detail = string.format("x%d in binder · market $%.2f", count, CardRules.getMarketValue(card, foil))
		local _, button = UIKit.row(pickerList, order, describe(card, foil), detail)
		button.Text = "Add"
		button.Activated:Connect(function()
			local part = casePart
			local slot = pickerSlot
			picker.Visible = false
			if part and slot then
				Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, card.id, foil)
			end
		end)
	end
	-- Rarest first: those are the ones worth showing off
	for index = #Cards.List, 1, -1 do
		local card = Cards.List[index]
		local owned = collection[card.id]
		if owned then
			if owned.foil > 0 then
				addOption(card, true, owned.foil)
			end
			if owned.normal > 0 then
				addOption(card, false, owned.normal)
			end
		end
	end
	if order == 0 then
		UIKit.row(pickerList, 1, "Your binder is empty", "Rip some packs first.")
	end
end

openPicker = function(slot: number)
	pickerSlot = slot
	renderPicker()
	picker.Visible = true
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

	picker, pickerList = UIKit.panel(screenGui, "CardPicker", "Pick a card")
	picker.ZIndex = 5

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
