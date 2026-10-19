--!strict
-- Prices panel: set your sell price per unlocked product with +/- buttons.
-- Taps update the display instantly and are sent to the server together once tapping stops.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local PricingConfig = require(Config:WaitForChild("Pricing"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Product = typeof(Products.List[1])

type Row = {
	product: Product,
	frame: Frame,
	detail: TextLabel,
}

-- Hint colours from best to worst band, then "won't buy"
local BAND_COLORS = {
	Color3.fromRGB(110, 220, 130),
	Color3.fromRGB(240, 210, 90),
	Color3.fromRGB(245, 150, 70),
}
local NEVER_COLOR = Color3.fromRGB(240, 90, 90)

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

local function refreshRow(row: Row)
	local product = row.product
	row.frame.Visible = getLevel() >= product.unlockLevel

	local price = getShownPrice(product)
	local hint, color = getBandInfo(price, product.marketPrice)
	row.detail.Text = string.format("$%.2f  (market $%.2f)\n%s", price, product.marketPrice, hint)
	row.detail.TextColor3 = color
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
	detail.Size = UDim2.new(1, -140, 0, 32)
	detail.TextSize = 14

	plus.Text = "+"
	plus.TextSize = 28
	plus.Size = UDim2.fromOffset(52, 52)

	local minus = UIKit.button(frame, "−", UIKit.Colors.Danger)
	minus.TextSize = 28
	minus.AnchorPoint = Vector2.new(1, 0.5)
	minus.Position = UDim2.new(1, -70, 0.5, 0)
	minus.Size = UDim2.fromOffset(52, 52)

	local row: Row = { product = product, frame = frame, detail = detail }
	plus.Activated:Connect(function()
		nudge(row, 1)
	end)
	minus.Activated:Connect(function()
		nudge(row, -1)
	end)
	return row
end

local function buildButton(parent: Instance)
	local button = UIKit.button(parent, "Prices", UIKit.Colors.Row)
	button.Name = "PricesButton"
	-- Sits under the Build button on the middle-left
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, 66)
	button.Size = UDim2.fromOffset(96, 56)
	button.Activated:Connect(function()
		refreshAll()
		panel.Visible = not panel.Visible
	end)
end

function PricingController.Start()
	local screenGui = UIController.GetScreenGui()
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "PricesMenu", "Prices")
	for index, product in Products.List do
		table.insert(rows, buildRow(product, list, index))
	end
	buildButton(screenGui)

	player:GetAttributeChangedSignal("Level"):Connect(refreshAll)
	for _, product in Products.List do
		player:GetAttributeChangedSignal("Price_" .. product.id):Connect(refreshAll)
	end
	refreshAll()
end

return PricingController
