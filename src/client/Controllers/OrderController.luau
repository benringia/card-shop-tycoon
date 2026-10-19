--!strict
-- Order menu for the plot computer. The server opens it; tapping Order sends the product ID back.
-- The server re-checks cash, level and distance, so this UI only shows what to expect.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UIController = require((script.Parent :: Instance):WaitForChild("UIController"))

type Product = typeof(Products.List[1])

type Row = {
	product: Product,
	button: TextButton,
}

local PANEL_COLOR = Color3.fromRGB(30, 30, 42)
local ROW_COLOR = Color3.fromRGB(45, 45, 60)
local ORDER_COLOR = Color3.fromRGB(40, 160, 90)
local LOCKED_COLOR = Color3.fromRGB(90, 90, 100)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SUBTEXT_COLOR = Color3.fromRGB(190, 190, 205)

local player = Players.LocalPlayer

local OrderController = {}

local panel: Frame
local rows: { Row } = {}

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

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
		row.button.BackgroundColor3 = if locked then LOCKED_COLOR else ORDER_COLOR
		row.button.AutoButtonColor = not locked
	end
end

local function makeLabel(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

local function buildRow(product: Product, parent: Instance, order: number): Row
	local frame = Instance.new("Frame")
	frame.Name = product.id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 76)
	frame.BackgroundColor3 = ROW_COLOR
	frame.Parent = parent
	addCorner(frame, 10)

	local name = makeLabel(frame, product.name, Enum.Font.GothamBold, 18, TEXT_COLOR)
	name.Position = UDim2.fromOffset(12, 8)
	name.Size = UDim2.new(1, -130, 0, 30)

	local detail = string.format(
		"Box of %d · $%.2f  (sells ~$%.2f each)",
		product.unitsPerBox,
		product.boxCost,
		product.marketPrice
	)
	local detailLabel = makeLabel(frame, detail, Enum.Font.Gotham, 14, SUBTEXT_COLOR)
	detailLabel.Position = UDim2.fromOffset(12, 40)
	detailLabel.Size = UDim2.new(1, -130, 0, 28)

	local button = Instance.new("TextButton")
	button.Name = "Order"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(104, 52)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.TextColor3 = TEXT_COLOR
	button.Parent = frame
	addCorner(button, 10)

	button.Activated:Connect(function()
		if isLocked(product) then
			UIController.Notify(`Unlocks at shop level {product.unlockLevel}.`, true)
			return
		end
		Remotes.OrderProduct:FireServer(product.id)
	end)

	return { product = product, button = button }
end

local function buildPanel(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "OrderMenu"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.7)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	frame.Parent = parent
	addCorner(frame, 14)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 520)
	sizeLimit.Parent = frame

	local title = makeLabel(frame, "Order Stock", Enum.Font.FredokaOne, 28, TEXT_COLOR)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -80, 0, 44)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(48, 48)
	close.BackgroundColor3 = ROW_COLOR
	close.Font = Enum.Font.GothamBold
	close.TextSize = 22
	close.TextColor3 = TEXT_COLOR
	close.Text = "X"
	close.Parent = frame
	addCorner(close, 10)
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Products"
	list.Position = UDim2.fromOffset(12, 68)
	list.Size = UDim2.new(1, -24, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, product in Products.List do
		table.insert(rows, buildRow(product, list, index))
	end

	return frame
end

local function open()
	refreshRows()
	panel.Visible = true
end

function OrderController.Start()
	panel = buildPanel(UIController.GetScreenGui())
	Remotes.OpenOrderMenu.OnClientEvent:Connect(open)
	player:GetAttributeChangedSignal("Level"):Connect(refreshRows)
end

return OrderController
