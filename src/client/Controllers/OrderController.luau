--!strict
-- Order menu for the plot computer. The server opens it; tapping Order sends the product ID back.
-- The server re-checks cash, level and distance, so this UI only shows what to expect.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Product = typeof(Products.List[1])

type Row = {
	product: Product,
	button: TextButton,
}

local player = Players.LocalPlayer

local OrderController = {}

local panel: Frame
local rows: { Row } = {}

local function getLevel(): number
	local level = player:GetAttribute("Level")
	return if typeof(level) == "number" then level else 1
end

local function isLocked(product: Product): boolean
	return getLevel() < product.unlockLevel
end

local function refreshRows()
	for _, row in rows do
		local locked = isLocked(row.product)
		row.button.Text = if locked then `Lv {row.product.unlockLevel}` else "Order"
		row.button.BackgroundColor3 = if locked then UIKit.Colors.Locked else UIKit.Colors.Accent
		row.button.AutoButtonColor = not locked
	end
end

local function buildRow(product: Product, parent: Instance, order: number): Row
	local detail = string.format(
		"Box of %d · $%.2f  (sells ~$%.2f each)",
		product.unitsPerBox,
		product.boxCost,
		product.marketPrice
	)
	local frame, button = UIKit.row(parent, order, product.name, detail)
	frame.Name = product.id

	button.Activated:Connect(function()
		if isLocked(product) then
			UIController.Notify(`Unlocks at shop level {product.unlockLevel}.`, true)
			return
		end
		Remotes.OrderProduct:FireServer(product.id)
	end)

	return { product = product, button = button }
end

local function open()
	refreshRows()
	panel.Visible = true
end

function OrderController.Start()
	local list: ScrollingFrame
	panel, list = UIKit.panel(UIController.GetScreenGui(), "OrderMenu", "Order Stock")
	for index, product in Products.List do
		table.insert(rows, buildRow(product, list, index))
	end

	Remotes.OpenOrderMenu.OnClientEvent:Connect(open)
	player:GetAttributeChangedSignal("Level"):Connect(refreshRows)
end

return OrderController
