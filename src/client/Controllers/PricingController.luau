--!strict
-- Prices panel: set your sell price per unlocked product. Each row: the product, its market price and how
-- customers feel about your price (in the band's colour), and on the right your price in a box outlined in that
-- colour, with small - / + buttons under it. Taps update the display instantly and are sent to the server together
-- once tapping stops.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local PricingConfig = require(Config:WaitForChild("Pricing"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ProductPicture = require(ClientUtil:WaitForChild("ProductPicture"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Product = typeof(Products.List[1])

type Row = {
	product: Product,
	frame: Frame,
	market: TextLabel,
	tag: TextLabel,
	price: TextLabel,
}

local LOOK = PricingConfig.ROWS

local player = Players.LocalPlayer

local PricingController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start

-- Hint colours from best to worst band (deep enough to read on the cream window); "won't buy" is palette.bad
local function bandColor(index: number): Color3
	local colors = { palette.good, palette.fair, palette.power }
	return colors[index] or colors[1]
end
local rows: { Row } = {}
local pending: { [string]: number } = {}
local sendToken = 0

local function getServerPrice(product: Product): number
	local value = player:GetAttribute("Price_" .. product.id)
	return if typeof(value) == "number" then value else PriceRules.getDefault(product.marketPrice)
end

local function getShownPrice(product: Product): number
	return pending[product.id] or getServerPrice(product)
end

local function getLevel(): number
	local level = player:GetAttribute("Level")
	return if typeof(level) == "number" then level else 1
end

-- The row's short tag and its colour for a price (the bands' `tag`, PricingConfig.NEVER_TAG above the last band)
local function getBandInfo(price: number, marketPrice: number): (string, Color3)
	local band = PriceRules.getBand(price, marketPrice)
	if not band then
		return PricingConfig.NEVER_TAG, palette.bad
	end
	local index = table.find(PricingConfig.BUY_BANDS, band) or 1
	return band.tag, bandColor(index)
end

local function refreshRow(row: Row)
	local product = row.product
	row.frame.Visible = getLevel() >= product.unlockLevel
	local price = getShownPrice(product)
	local hint, color = getBandInfo(price, product.marketPrice)
	row.market.Text = string.format("Market $%.2f", product.marketPrice)
	row.tag.Text = hint
	row.tag.BackgroundColor3 = color
	row.price.Text = string.format("$%.2f", price)
end

local function refreshAll()
	for _, row in rows do
		refreshRow(row)
	end
end

local function flush(token: number)
	if token ~= sendToken or next(pending) == nil then
		return
	end
	Remotes.SetPrices:FireServer(pending)
	pending = {}
end

local function nudge(row: Row, direction: number)
	local product = row.product
	local newPrice = getShownPrice(product) + direction * PricingConfig.PRICE_STEP
	pending[product.id] = PriceRules.clamp(newPrice, product.marketPrice)
	refreshRow(row)

	sendToken += 1
	local token = sendToken
	task.delay(PricingConfig.CLIENT_SEND_DELAY, flush, token)
end

-- One round - or + on the stepper: a small soft button drawn ROUND across inside a HIT-sized tap area (phones still
-- get a finger-sized target), both pressing it
local function stepButton(parent: Instance, text: string, color: Color3, onPress: () -> ()): TextButton
	local hit = Instance.new("TextButton")
	hit.Name = if text == "+" then "Plus" else "Minus"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromOffset(LOOK.HIT, LOOK.HIT)
	hit.Parent = parent
	local round = UIKit.button(hit, text, color)
	round.AnchorPoint = Vector2.new(0.5, 0.5)
	round.Position = UDim2.fromScale(0.5, 0.5)
	round.Size = UDim2.fromOffset(LOOK.ROUND, LOOK.ROUND)
	round.Font = Enum.Font.FredokaOne
	round.TextSize = 18
	local corner = round:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	hit.Activated:Connect(onPress)
	round.Activated:Connect(onPress)
	return hit
end

-- A slim row (owner 2026-11-03, round 3 pick A): the product's picture, its name, "Market $x" and a small tag in the
-- price band's colour ("Rarely buy"), and on the right one stepper pill: - , the price, +
local function buildRow(product: Product, parent: Instance, order: number): Row
	local frame = Instance.new("Frame")
	frame.Name = product.id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, LOOK.ROW_HEIGHT)
	frame.BackgroundColor3 = palette.row
	frame.Parent = parent
	UIKit.corner(frame, 16)
	UIKit.outline(frame, palette.rowEdge, 2)
	local textLeft = 12
	local textRight = LOOK.STEPPER + 20
	local name = UIKit.label(frame, product.name, Enum.Font.FredokaOne, LOOK.NAME_TEXT, palette.ink)
	name.Position = UDim2.fromOffset(textLeft, 10)
	name.Size = UDim2.new(1, -(textLeft + textRight), 0, LOOK.NAME_TEXT + 4)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local meta = Instance.new("Frame")
	meta.Name = "Meta"
	meta.BackgroundTransparency = 1
	-- ProductPicture moves the row's own labels right of the picture; the market line is a frame, so it starts there
	meta.Position = UDim2.fromOffset(textLeft + ProductPicture.WIDTH, 12 + LOOK.NAME_TEXT + 4)
	meta.Size = UDim2.new(1, -(textLeft + ProductPicture.WIDTH + textRight), 0, LOOK.TAG_HEIGHT)
	meta.Parent = frame
	local line = Instance.new("UIListLayout")
	line.FillDirection = Enum.FillDirection.Horizontal
	line.VerticalAlignment = Enum.VerticalAlignment.Center
	line.Padding = UDim.new(0, 6)
	line.SortOrder = Enum.SortOrder.LayoutOrder
	line.Parent = meta
	local market = UIKit.label(meta, "", Enum.Font.GothamBold, LOOK.META_TEXT, palette.inkSoft)
	market.LayoutOrder = 1
	market.TextWrapped = false
	market.AutomaticSize = Enum.AutomaticSize.X
	market.Size = UDim2.fromOffset(0, LOOK.TAG_HEIGHT)
	local tag = UIKit.pill(meta, "", palette.good, Color3.new(1, 1, 1))
	tag.LayoutOrder = 2
	tag.Size = UDim2.fromOffset(0, LOOK.TAG_HEIGHT)
	tag.TextSize = LOOK.META_TEXT - 1
	ProductPicture.add(frame, product.id, product.icon) -- moves the name and market line right of the picture

	-- The stepper: a pale pill with the round - and + either side of the price
	local stepper = Instance.new("Frame")
	stepper.Name = "Price"
	stepper.AnchorPoint = Vector2.new(1, 0.5)
	stepper.Position = UDim2.new(1, -LOOK.BUTTON_INSET, 0.5, 0)
	stepper.Size = UDim2.fromOffset(LOOK.STEPPER, LOOK.STEPPER_HEIGHT)
	stepper.BackgroundColor3 = palette.slotEmpty
	stepper.Parent = frame
	UIKit.corner(stepper, LOOK.STEPPER_HEIGHT / 2)
	UIKit.outline(stepper, palette.rowEdge, 2)
	local price = UIKit.label(stepper, "", Enum.Font.FredokaOne, LOOK.PRICE_TEXT, palette.ink)
	price.Size = UDim2.fromScale(1, 1)
	price.TextXAlignment = Enum.TextXAlignment.Center
	local row: Row = { product = product, frame = frame, market = market, tag = tag, price = price }
	local minus = stepButton(stepper, "-", UIKit.Colors.Danger, function()
		nudge(row, -1)
	end)
	minus.AnchorPoint = Vector2.new(0, 0.5)
	minus.Position = UDim2.new(0, -(LOOK.HIT - LOOK.STEPPER_HEIGHT) / 2, 0.5, 0)
	local plus = stepButton(stepper, "+", UIKit.Colors.Accent, function()
		nudge(row, 1)
	end)
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, (LOOK.HIT - LOOK.STEPPER_HEIGHT) / 2, 0.5, 0)
	return row
end

-- A price row for one product in another panel (a shelf's own menu): the same +/- and price as the Prices panel
function PricingController.AddRow(parent: Instance, order: number, productId: string): Frame?
	local product = Products.ById[productId]
	if not product then
		return nil
	end
	local row = buildRow(product, parent, order)
	table.insert(rows, row)
	refreshRow(row)
	row.frame.Destroying:Connect(function()
		local index = table.find(rows, row)
		if index then
			table.remove(rows, index)
		end
	end)
	return row.frame
end

local function buildButton()
	Hud.fanButton({
		id = "Prices",
		icon = "Prices",
		label = "Prices",
		order = 2,
		onClick = function()
			refreshAll()
			panel.Visible = not panel.Visible
		end,
	})
end

function PricingController.Start()
	local screenGui = UIController.GetScreenGui()
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "PricesMenu", "Prices", "Prices")
	UIKit.padList(list, LOOK.LIST_PAD) -- the rows' outlines and the buttons' glow stay inside the list
	palette = UIKit.colorsFor(panel)
	Icon.header(panel, "Prices", UIKit.HEADER_HEIGHT)
	for index, product in Products.List do
		table.insert(rows, buildRow(product, list, index))
	end
	buildButton()

	player:GetAttributeChangedSignal("Level"):Connect(refreshAll)
	for _, product in Products.List do
		player:GetAttributeChangedSignal("Price_" .. product.id):Connect(refreshAll)
	end
	refreshAll()
end

return PricingController
