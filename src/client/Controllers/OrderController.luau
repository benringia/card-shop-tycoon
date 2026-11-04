--!strict
-- Order Stock for the plot computer (owner's pick A, spec 2026-11-04-round4-design section 4): the same slim white
-- rows as Prices (picture, name, "Box of 24" and a mint "sells ~$3.00" tag) with one mint button showing the box
-- price; it greys out with "Need $48" when you can't afford it and shows the lock and "Lv 11" while locked
-- (Util/OrderRules). The server opens it; the server re-checks cash, level and distance, so this only shows what to
-- expect.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local PricingConfig = require(Config:WaitForChild("Pricing"))
local OrderRules = require(Shared:WaitForChild("Util"):WaitForChild("OrderRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ProductPicture = require(ClientUtil:WaitForChild("ProductPicture"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Product = typeof(Products.List[1])

type Row = {
	product: Product,
	button: TextButton,
	lock: Frame,
}

local LOOK = PricingConfig.ROWS -- the Prices window's row sizes, so both windows match
local BUTTON_WIDTH = 116
local LOCK_SIZE = 20

local player = Players.LocalPlayer

local OrderController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local rows: { Row } = {}

local function getNumber(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function getButton(product: Product): OrderRules.Button
	return OrderRules.button(getNumber("Level", 1), product.unlockLevel, getNumber("Cash", 0), product.boxCost)
end

local function refreshRows()
	for _, row in rows do
		local look = getButton(row.product)
		local ready = look.state == "ready"
		row.button.Text = look.text
		row.button.BackgroundColor3 = if ready then UIKit.Colors.Success else UIKit.Colors.Locked
		row.button.AutoButtonColor = ready
		row.lock.Visible = look.state == "locked"
		-- The lock sits before "Lv 11": the text moves over to make room for it
		local padding = row.button:FindFirstChildOfClass("UIPadding")
		if padding then
			padding.PaddingLeft = UDim.new(0, if look.state == "locked" then LOCK_SIZE + 6 else 0)
		end
	end
end

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
	local textRight = BUTTON_WIDTH + 20
	local name = UIKit.label(frame, product.name, Enum.Font.FredokaOne, LOOK.NAME_TEXT, palette.ink)
	name.Position = UDim2.fromOffset(textLeft, 10)
	name.Size = UDim2.new(1, -(textLeft + textRight), 0, LOOK.NAME_TEXT + 4)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	-- "Box of 24" and the sells tag; a frame, so it starts right of the picture (ProductPicture moves labels only)
	local meta = Instance.new("Frame")
	meta.Name = "Meta"
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromOffset(textLeft + ProductPicture.WIDTH, 12 + LOOK.NAME_TEXT + 4)
	meta.Size = UDim2.new(1, -(textLeft + ProductPicture.WIDTH + textRight), 0, LOOK.TAG_HEIGHT)
	meta.Parent = frame
	local line = Instance.new("UIListLayout")
	line.FillDirection = Enum.FillDirection.Horizontal
	line.VerticalAlignment = Enum.VerticalAlignment.Center
	line.Padding = UDim.new(0, 6)
	line.SortOrder = Enum.SortOrder.LayoutOrder
	line.Parent = meta
	local box = UIKit.label(meta, `Box of {product.unitsPerBox}`, Enum.Font.GothamBold, LOOK.META_TEXT, palette.inkSoft)
	box.LayoutOrder = 1
	box.TextWrapped = false
	box.AutomaticSize = Enum.AutomaticSize.X
	box.Size = UDim2.fromOffset(0, LOOK.TAG_HEIGHT)
	local tag = UIKit.pill(meta, OrderRules.sells(product.marketPrice), palette.good, Color3.new(1, 1, 1))
	tag.LayoutOrder = 2
	tag.Size = UDim2.fromOffset(0, LOOK.TAG_HEIGHT)
	tag.TextSize = LOOK.META_TEXT - 1
	ProductPicture.add(frame, product.id, product.icon) -- moves the name right of the picture

	-- The box price on one mint button: tap it to order
	local button = UIKit.button(frame, "", UIKit.Colors.Success)
	button.Name = "Order"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -LOOK.BUTTON_INSET, 0.5, 0)
	button.Size = UDim2.fromOffset(BUTTON_WIDTH, LOOK.BUTTON_HEIGHT)
	button.TextSize = 15
	local padding = Instance.new("UIPadding")
	padding.Parent = button
	local lock = Icon.make(button, "Lock", UDim2.fromOffset(LOCK_SIZE, LOCK_SIZE))
	lock.AnchorPoint = Vector2.new(0, 0.5)
	lock.Position = UDim2.new(0, 14, 0.5, 0)
	lock.ZIndex = button.ZIndex + 1
	Icon.set(lock, "Lock")
	lock.Visible = false

	button.Activated:Connect(function()
		local look = getButton(product)
		if look.state == "locked" then
			UIController.Notify(`Unlocks at shop level {product.unlockLevel}.`, true)
			return
		end
		if look.state == "short" then
			return
		end
		Remotes.OrderProduct:FireServer(product.id)
	end)

	return { product = product, button = button, lock = lock }
end

local function open()
	refreshRows()
	panel.Visible = true
end

function OrderController.Start()
	local list: ScrollingFrame
	panel, list = UIKit.panel(UIController.GetScreenGui(), "OrderMenu", "Order Stock")
	UIKit.padList(list, LOOK.LIST_PAD) -- the rows' outlines and the buttons' glow stay inside the list
	palette = UIKit.colorsFor(panel)
	Icon.header(panel, "Order", UIKit.HEADER_HEIGHT)
	for index, product in Products.List do
		table.insert(rows, buildRow(product, list, index))
	end

	Remotes.OpenOrderMenu.OnClientEvent:Connect(open)
	player:GetAttributeChangedSignal("Level"):Connect(refreshRows)
	player:GetAttributeChangedSignal("Cash"):Connect(refreshRows)
end

return OrderController
