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
local UIStyle = require(Config:WaitForChild("UIStyle"))
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
	detail: TextLabel,
	price: TextLabel,
	priceEdge: UIStroke,
	priceArea: Frame,
	steps: { TextButton },
}

-- Hint colours from best to worst band, then "won't buy"
local BAND_COLORS = {
	Color3.fromRGB(110, 220, 130),
	Color3.fromRGB(240, 210, 90),
	Color3.fromRGB(245, 150, 70),
}
local NEVER_COLOR = Color3.fromRGB(240, 90, 90)
local PRICE_WIDTH = 112 -- the price box and its - / + buttons
local PRICE_HEIGHT = 30
local STEP_SIZE = 38 -- the - / + buttons with a mouse; phones keep UIStyle.MIN_TAP

local player = Players.LocalPlayer

local PricingController = {}

local panel: Frame
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

local function getBandInfo(price: number, marketPrice: number): (string, Color3)
	local band = PriceRules.getBand(price, marketPrice)
	if not band then
		return PricingConfig.NEVER_LABEL, NEVER_COLOR
	end
	local index = table.find(PricingConfig.BUY_BANDS, band) or 1
	return band.label, BAND_COLORS[index] or BAND_COLORS[1]
end

-- Sizes follow the screen (phones get bigger buttons), so they're set on every refresh, not once at start
local function fitRow(row: Row)
	local step = if UIKit.isPhone() then UIStyle.MIN_TAP else STEP_SIZE
	row.frame.Size = UDim2.new(1, 0, 0, math.max(76, PRICE_HEIGHT + step + 16))
	row.priceArea.Size = UDim2.fromOffset(PRICE_WIDTH, PRICE_HEIGHT + 4 + step)
	row.price.TextSize = UIKit.textSize("name")
	for _, button in row.steps do
		button.Size = UDim2.new(0.5, -3, 0, step)
	end
end

local function refreshRow(row: Row)
	local product = row.product
	row.frame.Visible = getLevel() >= product.unlockLevel
	fitRow(row)

	local price = getShownPrice(product)
	local hint, color = getBandInfo(price, product.marketPrice)
	row.detail.Text = string.format("Market $%.2f\n%s", product.marketPrice, hint)
	row.detail.TextColor3 = color
	row.price.Text = string.format("$%.2f", price)
	row.priceEdge.Color = color
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

local function buildRow(product: Product, parent: Instance, order: number): Row
	local frame, plus, detail = UIKit.row(parent, order, product.name, "")
	frame.Name = product.id
	detail.TextSize = 14
	-- Name and market price leave room for the price on the right; the product's picture goes first
	for _, label in frame:GetChildren() do
		if label:IsA("TextLabel") then
			label.Size = UDim2.new(1, -(PRICE_WIDTH + 24), 0, label.Size.Y.Offset)
		end
	end
	ProductPicture.add(frame, product.id, product.icon)

	-- Your price, big, over the - / + buttons
	local priceArea = Instance.new("Frame")
	priceArea.Name = "Price"
	priceArea.AnchorPoint = Vector2.new(1, 0.5)
	priceArea.Position = UDim2.new(1, -10, 0.5, 0)
	priceArea.BackgroundTransparency = 1
	priceArea.ZIndex = frame.ZIndex + 1
	priceArea.Parent = frame
	local price = UIKit.label(priceArea, "", Enum.Font.FredokaOne, 22, Color3.new(1, 1, 1))
	price.Size = UDim2.new(1, 0, 0, PRICE_HEIGHT)
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.BackgroundColor3 = UIStyle.EDGE
	price.BackgroundTransparency = 0
	price.ZIndex = priceArea.ZIndex
	UIKit.corner(price, 8)
	UIKit.outlined(price, 2)
	local priceEdge = UIKit.outline(price, BAND_COLORS[1], 2)

	local minus = UIKit.button(priceArea, "-", UIKit.Colors.Danger)
	plus.Parent = priceArea
	plus.Text = "+"
	for index, button in { minus, plus } do
		button.TextSize = 24
		button.AnchorPoint = Vector2.new(if index == 1 then 0 else 1, 1)
		button.Position = UDim2.fromScale(if index == 1 then 0 else 1, 1)
		button.ZIndex = priceArea.ZIndex
	end

	local row: Row = { product = product, frame = frame, detail = detail, price = price, priceEdge = priceEdge, priceArea = priceArea, steps = { minus, plus } }
	plus.Activated:Connect(function()
		nudge(row, 1)
	end)
	minus.Activated:Connect(function()
		nudge(row, -1)
	end)
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
	panel, list = UIKit.panel(screenGui, "PricesMenu", "Prices")
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
