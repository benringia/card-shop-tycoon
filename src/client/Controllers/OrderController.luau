--!strict
-- The order computer (owner 2026-11-21: "COMPUTER: in this window, redesign it to be fully immersive computer
-- shopping layout", pick A): a cotton candy tablet with a browser open on packenship.co (a monitor on a stand until
-- 2026-11-22: it reached down over the bottom tiles; the tablet sits above them, OrderRules.fit). Product cards
-- with the real pictures, a stepper and Add to cart, a pink tag when a product's shelves run low; a cart beside them
-- with the total, the cash after, when the boxes arrive and the delivery pad's spots; a My deliveries page with each
-- box's trip; a taskbar with the town's clock. A phone gets the same store on a thin screen: four cards in a row, the
-- cart as a bar along the bottom. The computer is scaled to fit the screen. Config/OrderComputer holds the
-- look, Util/OrderRules the words and checks. The server opens it with the trip time and the boxes on the way
-- (OpenOrderMenu), takes the cart (OrderCart) and answers (OrderPlaced); it re-checks level, room, distance and cash,
-- so this only shows what to expect. Pish's tutorial points at a card's "Add" button, then at "Checkout" once the
-- card's InCart attribute is above 0 (TutorialController).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SharedUtil = Shared:WaitForChild("Util")
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))
local StockConfig = require(Config:WaitForChild("Stock"))
local OrderComputer = require(Config:WaitForChild("OrderComputer"))
local HudGrowConfig = require(Config:WaitForChild("HudGrow"))
local OrderRules = require(SharedUtil:WaitForChild("OrderRules"))
local HudGrow = require(SharedUtil:WaitForChild("HudGrow"))
local ShopTileRules = require(SharedUtil:WaitForChild("ShopTileRules"))
local RegisterStationRules = require(SharedUtil:WaitForChild("RegisterStationRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local NewTag = require(ClientUtil:WaitForChild("NewTag"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ProductPicture = require(ClientUtil:WaitForChild("ProductPicture"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Product = typeof(Products.List[1])
type Coming = { productId: string, arriveAt: number, seconds: number }

type Card = {
	product: Product,
	frame: Frame, -- named by the product's id (the tutorial finds it); InCart attribute: boxes of it in the cart
	face: Frame,
	faceEdge: UIStroke,
	picture: Frame,
	shown: GuiObject, -- the product's picture
	pictureLock: GuiObject,
	price: TextLabel,
	profit: TextLabel?,
	add: TextButton,
	stepper: Frame,
	plus: TextButton,
	count: TextLabel,
	lockLine: Frame,
	lockText: TextLabel,
	tag: TextLabel,
}

type CartLine = { frame: Frame, label: TextLabel, count: TextLabel, cost: TextLabel }
type ComingRow = { text: TextLabel, fill: Frame, item: Coming }

type Ui = {
	root: Frame,
	scale: UIScale,
	cash: TextLabel,
	badge: Frame,
	badgeText: TextLabel,
	navOrder: TextButton,
	navDeliveries: TextButton,
	orderPage: Frame,
	deliveriesPage: ScrollingFrame,
	checkout: TextButton,
	url: TextLabel?,
	clock: TextLabel?,
	taskOrder: Frame?,
	taskDeliveries: Frame?,
	cartPill: TextLabel?,
	lineList: ScrollingFrame?,
	cartEmpty: TextLabel?,
	total: TextLabel?,
	cashAfter: TextLabel?,
	arrive: TextLabel?,
	padLine: TextLabel?,
	padFill: Frame?,
	padCart: Frame?,
	summary: TextLabel?,
	summarySub: TextLabel?,
}

local WORDS = OrderComputer.WORDS
local DESK = OrderComputer.DESKTOP
local PHONE = OrderComputer.PHONE
local WHITE = Color3.new(1, 1, 1)
local MAX_BOXES = StockConfig.MAX_BOXES_PER_PLOT
local TICK = 0.25 -- seconds between the open window's countdown updates
local byId = (Products.ById :: any) :: { [string]: OrderRules.Product }

local player = Players.LocalPlayer

local OrderController = {}

local panel: Frame
local ui: Ui? = nil
local built: string? = nil -- "desktop" or "phone": the layout built now
local cards: { Card } = {}
local cartLines: { [string]: CartLine } = {}
local comingRows: { ComingRow } = {}
local cart: OrderRules.Cart = {}
local tripSeconds = StockConfig.DELIVERY_SECONDS -- a box's trip now (the server says when the computer opens)
local coming: { Coming } = {} -- boxes on the way
local page = "order"
local sending = false -- Order now pressed, the server's answer not back yet
local ticking = 0 -- the open window's refresh loop (a new one ends the old)

local function rgb(name: string): Color3
	local value = OrderComputer.COLORS[name]
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function getNumber(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function phone(): boolean
	return built == "phone"
end

local function level(): number
	return getNumber("Level", 1)
end

local function cash(): number
	return getNumber("Cash", 0)
end

local function used(): number
	return getNumber("BoxesUsed", 0)
end

local function room(): number
	return MAX_BOXES - used()
end

-- Building blocks ---------------------------------------------------------------------------------------------

local function box(parent: Instance, name: string, color: Color3?, corner: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or WHITE
	frame.BackgroundTransparency = if color then 0 else 1
	frame.Parent = parent
	if corner then
		UIKit.corner(frame, corner)
	end
	return frame
end

local function at(gui: GuiObject, x: number, y: number, w: number, h: number)
	gui.Position = UDim2.fromOffset(x, y)
	gui.Size = UDim2.fromOffset(w, h)
end

local function shade(gui: GuiObject, colors: { Color3 }, rotation: number?)
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or 90
	gradient.Color = ColorSequence.new(keys)
	gradient.Parent = gui
end

local function edge(gui: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = gui
	return stroke
end

-- One line of words that never wraps (cut with "..." when too long)
local function words(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function row(parent: Instance, gap: number, align: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	layout.Parent = parent
	return layout
end

local function column(parent: Instance, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function inset(gui: Instance, left: number, top: number, right: number, bottom: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.Parent = gui
end

-- A frame whose corners only round at the top (or the bottom): its corner, and a square strip over the other side
local function roundOneSide(frame: Frame, corner: number, top: boolean)
	UIKit.corner(frame, corner)
	local strip = box(frame, "Square", frame.BackgroundColor3)
	strip.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	strip.Position = UDim2.fromScale(0, if top then 1 else 0)
	strip.Size = UDim2.new(1, 0, 0, corner)
	strip.ZIndex = frame.ZIndex
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient:Clone().Parent = strip
	end
end

-- A small square of colour with an icon in it (the taskbar's apps)
local function appIcon(parent: Instance, name: string, icon: string, color: Color3, size: number, button: boolean): GuiObject
	local holder: GuiObject
	if button then
		local press = Instance.new("TextButton")
		press.Text = ""
		press.AutoButtonColor = false
		press.BackgroundColor3 = color
		press.BorderSizePixel = 0
		press.Parent = parent
		Motion.press(press)
		holder = press
	else
		holder = box(parent, name, color)
	end
	holder.Name = name
	holder.Size = UDim2.fromOffset(size, size)
	UIKit.corner(holder, math.floor(size / 3))
	local picture = Icon.make(holder, icon, UDim2.fromOffset(size * 0.68, size * 0.68))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	return holder
end

-- A soft round button (the stepper's - and +)
local function stepButton(parent: Instance, name: string, text: string, color: Color3, size: number): TextButton
	local button = UIKit.button(parent, text, color)
	button.Name = name
	button.Font = Enum.Font.FredokaOne
	button.TextSize = math.floor(size * 0.6)
	UIKit.makeRound(button, size)
	return button
end

-- A nav pill's look: white with blue words for the page shown, see-through on the blue otherwise (a little less while
-- the pointer is on it)
local function navStyle(pill: TextButton, hovered: boolean)
	local active = pill:GetAttribute("Active") == true
	pill.BackgroundTransparency = if active then 0 elseif hovered then 0.55 else 0.72
	pill.TextColor3 = if active then rgb("SITE_INK") else WHITE
end

-- A nav pill on the store's blue header (Order stock, My deliveries). It sizes itself to its words, so it keeps out
-- of the window kit's hover (SoftHover set first): the kit's hover edge, sized past the button, made it grow
-- without end.
local function navPill(parent: Instance, name: string, text: string, size: number, height: number): TextButton
	local pill = Instance.new("TextButton")
	pill:SetAttribute("SoftHover", true)
	pill.Name = name
	pill.AutoButtonColor = false
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, height)
	pill.BackgroundColor3 = WHITE
	pill.BorderSizePixel = 0
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = size
	pill.Text = text
	pill.Parent = parent
	UIKit.corner(pill, 999)
	inset(pill, 14, 0, 14, 0)
	Motion.press(pill)
	pill.MouseEnter:Connect(function()
		navStyle(pill, true)
	end)
	pill.MouseLeave:Connect(function()
		navStyle(pill, false)
	end)
	return pill
end

-- The pink count on My deliveries: boxes on the way
local function deliveriesBadge(pill: TextButton, size: number): (Frame, TextLabel)
	local padding = pill:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingRight = UDim.new(0, size + 18)
	end
	local badge = box(pill, "Badge", rgb("TAG"), 999)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(1, 6, 0.5, 0)
	badge.Size = UDim2.fromOffset(size, size)
	local count = words(badge, "", Enum.Font.FredokaOne, size - 6, WHITE)
	count.Size = UDim2.fromScale(1, 1)
	count.TextXAlignment = Enum.TextXAlignment.Center
	return badge, count
end

-- The cash chip: a gold coin and the cash
local function cashChip(parent: Instance, textSize: number, height: number): TextLabel
	local chip = box(parent, "Cash", WHITE, 999)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, height)
	inset(chip, 4, 0, 12, 0)
	row(chip, 8)
	local coin = box(chip, "Coin", rgb("COIN"), 999)
	coin.Size = UDim2.fromOffset(height - 8, height - 8)
	local dollar = words(coin, "$", Enum.Font.FredokaOne, textSize - 2, rgb("COIN_INK"))
	dollar.Size = UDim2.fromScale(1, 1)
	dollar.TextXAlignment = Enum.TextXAlignment.Center
	local amount = words(chip, "", Enum.Font.FredokaOne, textSize, rgb("INK"))
	amount.LayoutOrder = 1
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.Size = UDim2.fromOffset(0, height)
	return amount
end

-- The store's logo: a paw and the name, white with a blue edge
local function logo(parent: Instance, textSize: number): Frame
	local holder = box(parent, "Logo")
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.new(0, 0, 1, 0)
	row(holder, 8)
	local paw = Icon.make(holder, "Paw", UDim2.fromOffset(textSize + 6, textSize + 6))
	paw.LayoutOrder = 0
	local name = words(holder, WORDS.STORE, Enum.Font.FredokaOne, textSize, WHITE)
	name.LayoutOrder = 1
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.new(0, 0, 1, 0)
	local outline = Instance.new("UIStroke")
	outline.Color = rgb("SITE_INK")
	outline.Thickness = 2
	outline.Parent = name
	return holder
end

local function tint(product: Product): Color3
	local color = product.color
	return Color3.fromRGB(color[1], color[2], color[3]):Lerp(WHITE, OrderComputer.PICTURE_TINT)
end

-- Cards ------------------------------------------------------------------------------------------------------------

-- What a card does when tapped: one more box of it in the cart, or why not (never silent)
local function addOne(product: Product)
	local look = OrderRules.addLook(product, level(), cash(), cart, byId, room(), phone())
	if look.state ~= "ready" then
		UIController.Notify(look.why or "You can't add that now.", true)
		return
	end
	cart = OrderRules.changeCount(cart, product.id, 1)
	OrderController.Refresh()
end

local function removeOne(product: Product)
	cart = OrderRules.changeCount(cart, product.id, -1)
	OrderController.Refresh()
end

-- A card's picture panel: the product's tint, its picture, the "Box of 24" chip (under the picture, or over its
-- corner on a phone's short panel), a lock while it's locked
local function cardPicture(parent: Instance, product: Product, chipSize: number, chipOver: boolean): (Frame, GuiObject, GuiObject)
	local picture = box(parent, "Picture", tint(product), 12)
	local art = box(picture, "Art")
	art.Position = UDim2.fromOffset(6, 4)
	art.Size = UDim2.new(1, -12, 1, if chipOver then -8 else -(chipSize + 8))
	local shown = ProductPicture.fill(art, product.id, product.icon)
	local chip = OrderRules.boxChip(product)
	if chip then
		local label = UIKit.pill(picture, chip, WHITE, rgb("INK"))
		label.AnchorPoint = if chipOver then Vector2.new(1, 1) else Vector2.new(0.5, 1)
		label.Position = if chipOver then UDim2.new(1, -3, 1, -3) else UDim2.new(0.5, 0, 1, -3)
		label.Size = UDim2.fromOffset(0, chipSize)
		label.TextSize = chipSize - 7
		label.ZIndex = picture.ZIndex + 5
	end
	local lock = Icon.make(picture, "Lock", UDim2.fromOffset(32, 32))
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.45)
	lock.ZIndex = picture.ZIndex + 4
	return picture, shown, lock
end

-- The - n + stepper
local function stepper(parent: Instance, product: Product, size: number, countSize: number, wide: boolean): (Frame, TextButton, TextLabel)
	local holder = box(parent, "Stepper", rgb("STEPPER"), 999)
	holder.Size = if wide then UDim2.new(1, 0, 0, size + 4) else UDim2.fromOffset(size * 2 + 40, size + 4)
	local minus = stepButton(holder, "Minus", "-", WHITE, size)
	minus.AnchorPoint = Vector2.new(0, 0.5)
	minus.Position = UDim2.new(0, 3, 0.5, 0)
	local plus = stepButton(holder, "Plus", "+", UIKit.Colors.Success, size)
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -3, 0.5, 0)
	local count = words(holder, "0", Enum.Font.FredokaOne, countSize, rgb("INK"))
	count.Name = "Count"
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.5)
	count.Size = UDim2.fromOffset(40, size)
	count.TextXAlignment = Enum.TextXAlignment.Center
	minus.Activated:Connect(function()
		removeOne(product)
	end)
	plus.Activated:Connect(function()
		addOne(product)
	end)
	return holder, plus, count
end

-- The white line a locked card shows instead of its price and buttons: the lock and its shop level
local function lockLine(parent: Instance, textSize: number, height: number): (Frame, TextLabel)
	local line = box(parent, "LockLine", WHITE, 12)
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, height)
	inset(line, 10, 0, 8, 0)
	row(line, 8, Enum.HorizontalAlignment.Center)
	local lock = Icon.make(line, "Lock", UDim2.fromOffset(textSize + 4, textSize + 4))
	lock.LayoutOrder = 0
	local text = words(line, "", Enum.Font.GothamBold, textSize, rgb("LOCK_INK"))
	text.LayoutOrder = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, height)
	return line, text
end

-- The pink tag over a card's top edge ("Shelves low")
local function shelfTag(parent: Instance, textSize: number): TextLabel
	local tag = UIKit.pill(parent, "", rgb("TAG"), WHITE)
	tag.Name = "ShelfTag"
	tag.Position = UDim2.fromOffset(12, -9)
	tag.Size = UDim2.fromOffset(0, textSize + 8)
	tag.TextSize = textSize
	tag.ZIndex = 6
	tag.Visible = false
	local outline = tag:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = WHITE
	end
	return tag
end

-- A card's shell: its cell (named by the product id), a lip under it and its white face
local function cardShell(parent: Instance, product: Product, order: number, corner: number, padding: number): (Frame, Frame, UIStroke)
	local frame = box(parent, product.id)
	frame.LayoutOrder = order
	frame:SetAttribute("InCart", 0)
	local lip = box(frame, "Lip", rgb("CARD_LIP"), corner)
	lip.Position = UDim2.fromOffset(0, 3)
	lip.Size = UDim2.new(1, 0, 1, -3)
	local face = box(frame, "Face", rgb("CARD"), corner)
	face.Size = UDim2.new(1, 0, 1, -3)
	face.ZIndex = 2
	local faceEdge = edge(face, rgb("CARD_EDGE"), 2)
	inset(face, padding, padding, padding, padding)
	return frame, face, faceEdge
end

local function buildDesktopCard(parent: Instance, product: Product, order: number): Card
	local text = DESK.TEXT
	local frame, face, faceEdge = cardShell(parent, product, order, 16, 10)
	local picture, shown, pictureLock = cardPicture(face, product, 22, false)
	picture.Size = UDim2.new(0, DESK.PICTURE, 1, 0)

	local side = box(face, "Side")
	side.Position = UDim2.fromOffset(DESK.PICTURE + 10, 0)
	side.Size = UDim2.new(1, -(DESK.PICTURE + 10), 1, 0)
	local stack = box(side, "Stack")
	stack.Size = UDim2.fromScale(1, 1)
	column(stack, 4)
	local name = UIKit.label(stack, product.name, Enum.Font.FredokaOne, text.NAME, rgb("INK"))
	name.Name = "Name"
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, 0)
	name.AutomaticSize = Enum.AutomaticSize.Y
	local meta = words(stack, OrderRules.meta(product), Enum.Font.GothamBold, text.META, rgb("INK_SOFT"))
	meta.LayoutOrder = 2
	meta.Size = UDim2.new(1, 0, 0, text.META + 3)
	local profitText = OrderRules.profitText(product)
	local profit: TextLabel? = nil
	if profitText then
		local pill = UIKit.pill(stack, profitText, rgb("PROFIT"), WHITE)
		pill.LayoutOrder = 3
		pill.Size = UDim2.fromOffset(0, text.PILL + 10)
		pill.TextSize = text.PILL
		profit = pill
	end

	local bottom = box(side, "Bottom")
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0, DESK.ADD_HEIGHT)
	local price = words(bottom, OrderRules.money(product.boxCost), Enum.Font.FredokaOne, text.PRICE, rgb("INK"))
	price.Size = UDim2.new(0, 60, 1, 0)
	local add = UIKit.button(bottom, "", UIKit.Colors.Success)
	add.Name = "Add"
	add.Font = Enum.Font.FredokaOne
	add.TextSize = text.BUTTON - 2
	add.AnchorPoint = Vector2.new(1, 0.5)
	add.Position = UDim2.new(1, 0, 0.5, 0)
	add.Size = UDim2.new(1, -66, 0, DESK.ADD_HEIGHT)
	add.Activated:Connect(function()
		addOne(product)
	end)
	local holder, plus, count = stepper(bottom, product, DESK.STEP, text.COUNT, false)
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, 0, 0.5, 0)
	local line, lockText = lockLine(side, text.SMALL, DESK.ADD_HEIGHT)

	return {
		product = product,
		frame = frame,
		face = face,
		faceEdge = faceEdge,
		picture = picture,
		shown = shown,
		pictureLock = pictureLock,
		price = price,
		profit = profit,
		add = add,
		stepper = holder,
		plus = plus,
		count = count,
		lockLine = line,
		lockText = lockText,
		tag = shelfTag(frame, text.PILL - 1),
	}
end

local function buildPhoneCard(parent: Instance, product: Product, order: number): Card
	local text = PHONE.TEXT
	local frame, face, faceEdge = cardShell(parent, product, order, 14, 7)
	local picture, shown, pictureLock = cardPicture(face, product, 18, true)
	picture.Size = UDim2.new(1, 0, 0, PHONE.PICTURE_HEIGHT)
	local y = PHONE.PICTURE_HEIGHT + 4
	-- the name in up to two lines, smaller when it's long
	local name = UIKit.label(face, product.name, Enum.Font.FredokaOne, text.NAME, rgb("INK"))
	name.Name = "Name"
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextScaled = true
	name.Position = UDim2.fromOffset(0, y)
	name.Size = UDim2.new(1, 0, 0, text.NAME * 2 + 2)
	local fitText = Instance.new("UITextSizeConstraint")
	fitText.MaxTextSize = text.NAME
	fitText.MinTextSize = text.NAME - 4
	fitText.Parent = name
	y += text.NAME * 2 + 4
	local price = words(face, OrderRules.money(product.boxCost), Enum.Font.FredokaOne, text.PRICE, rgb("INK"))
	price.Position = UDim2.fromOffset(0, y)
	price.Size = UDim2.new(0.45, 0, 0, text.PRICE + 2)
	local profitText = OrderRules.profitText(product, true)
	local profit: TextLabel? = nil
	if profitText then
		local pill = UIKit.pill(face, profitText, rgb("PROFIT"), WHITE)
		pill.AnchorPoint = Vector2.new(1, 0)
		pill.Position = UDim2.new(1, 0, 0, y + 1)
		pill.Size = UDim2.fromOffset(0, text.PILL + 7)
		pill.TextSize = text.PILL
		profit = pill
	end

	local add = UIKit.button(face, "", UIKit.Colors.Success)
	add.Name = "Add"
	add.Font = Enum.Font.FredokaOne
	add.TextSize = text.BUTTON
	add.AnchorPoint = Vector2.new(0, 1)
	add.Position = UDim2.fromScale(0, 1)
	add.Size = UDim2.new(1, 0, 0, PHONE.ADD_HEIGHT)
	add.Activated:Connect(function()
		addOne(product)
	end)
	local holder, plus, count = stepper(face, product, PHONE.STEP, text.COUNT, true)
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.fromScale(0, 1)
	local line, lockText = lockLine(face, text.SMALL + 1, PHONE.ADD_HEIGHT)

	return {
		product = product,
		frame = frame,
		face = face,
		faceEdge = faceEdge,
		picture = picture,
		shown = shown,
		pictureLock = pictureLock,
		price = price,
		profit = profit,
		add = add,
		stepper = holder,
		plus = plus,
		count = count,
		lockLine = line,
		lockText = lockText,
		tag = shelfTag(frame, text.PILL),
	}
end

-- The product cards in a grid that scrolls when there are more than fit (room above for the shelves tags)
local function cardGrid(parent: Instance, cellSize: UDim2, gap: number): ScrollingFrame
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.ScrollBarImageColor3 = rgb("INK_SOFT")
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = parent
	inset(grid, 2, 10, 2, 4)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local index = 0
	for _, product in Products.List do
		if not product.bulk then -- bulk cards come from your binder, never the supplier (Config/Bulk)
			index += 1
			table.insert(cards, if phone() then buildPhoneCard(grid, product, index) else buildDesktopCard(grid, product, index))
		end
	end
	return grid
end

-- Pages and chrome -----------------------------------------------------------------------------------------------

local function showPage(name: string)
	page = name
	local current = ui
	if not current then
		return
	end
	local onOrder = name == "order"
	current.orderPage.Visible = onOrder
	current.deliveriesPage.Visible = not onOrder
	if current.url then
		current.url.Text = if onOrder then WORDS.URL_ORDER else WORDS.URL_DELIVERIES
	end
	current.navOrder:SetAttribute("Active", onOrder)
	current.navDeliveries:SetAttribute("Active", not onOrder)
	navStyle(current.navOrder, false)
	navStyle(current.navDeliveries, false)
	if current.taskOrder and current.taskDeliveries then
		current.taskOrder.Visible = onOrder
		current.taskDeliveries.Visible = not onOrder
	end
	OrderController.RenderDeliveries()
end

-- The store's blue header: the logo, the two pages, the cash
local function siteHeader(parent: Instance, height: number, logoSize: number, navSize: number, navHeight: number, rightRoom: number): (Frame, TextButton, TextButton, Frame, TextLabel, TextLabel)
	local header = box(parent, "Site", rgb("SITE_TOP"))
	header.Size = UDim2.new(1, 0, 0, height)
	shade(header, { rgb("SITE_TOP"), rgb("SITE_BOTTOM") })
	local inner = box(header, "Content")
	inner.Position = UDim2.fromOffset(14, 0)
	inner.Size = UDim2.new(1, -(14 + rightRoom), 1, 0)
	inner.ZIndex = 2
	local left = box(inner, "Left")
	left.Size = UDim2.fromScale(1, 1)
	row(left, 14)
	logo(left, logoSize).LayoutOrder = 0
	local navOrder = navPill(left, "NavOrder", WORDS.NAV_ORDER, navSize, navHeight)
	navOrder.LayoutOrder = 1
	local navDeliveries = navPill(left, "NavDeliveries", WORDS.NAV_DELIVERIES, navSize, navHeight)
	navDeliveries.LayoutOrder = 2
	local badge, badgeText = deliveriesBadge(navDeliveries, navHeight - 10)
	navOrder.Activated:Connect(function()
		showPage("order")
	end)
	navDeliveries.Activated:Connect(function()
		showPage("deliveries")
	end)
	local right = box(inner, "Right")
	right.Size = UDim2.fromScale(1, 1)
	row(right, 0, Enum.HorizontalAlignment.Right)
	local cashText = cashChip(right, logoSize - 3, navHeight + 2)
	return header, navOrder, navDeliveries, badge, badgeText, cashText
end

-- The page that lists the boxes on the way, filled by RenderDeliveries
local function deliveriesPage(parent: Instance, padding: number): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = "Deliveries"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = rgb("INK_SOFT")
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Size = UDim2.fromScale(1, 1)
	list.Visible = false
	list.Parent = parent
	inset(list, padding, padding, padding, padding)
	column(list, 10)
	return list
end

-- The cart beside the cards (a computer): its lines, the total, the cash after, the delivery box and Order now
local function cartAside(parent: Instance, height: number): Ui
	local text = DESK.TEXT
	local aside = box(parent, "Cart", rgb("CARD"), 16)
	aside.AnchorPoint = Vector2.new(1, 0)
	aside.Position = UDim2.new(1, 0, 0, 10)
	aside.Size = UDim2.new(0, DESK.CART_WIDTH, 0, height)
	edge(aside, rgb("CARD_EDGE"), 2)
	inset(aside, 12, 12, 12, 12)

	local head = box(aside, "Head")
	head.Size = UDim2.new(1, 0, 0, 26)
	row(head, 8)
	Icon.make(head, "Box", UDim2.fromOffset(22, 22)).LayoutOrder = 0
	local title = words(head, WORDS.CART, Enum.Font.FredokaOne, text.NAME, rgb("INK"))
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, 26)
	local pill = UIKit.pill(aside, "", rgb("STEPPER"), rgb("INK_SOFT"))
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, 0, 0, 2)
	pill.Size = UDim2.fromOffset(0, 22)
	pill.TextSize = text.PILL

	-- From the bottom up: Order now, the delivery box, cash after, the total, a rule
	local checkout = UIKit.button(aside, "", UIKit.Colors.Success)
	checkout.Name = "Checkout"
	checkout.Font = Enum.Font.FredokaOne
	checkout.TextSize = text.BUTTON + 1
	checkout.AnchorPoint = Vector2.new(0, 1)
	checkout.Position = UDim2.fromScale(0, 1)
	checkout.Size = UDim2.new(1, 0, 0, DESK.CHECKOUT_HEIGHT)
	local bottom = DESK.CHECKOUT_HEIGHT + 10

	local delivery = box(aside, "Delivery", rgb("DELIVERY"), 12)
	delivery.AnchorPoint = Vector2.new(0, 1)
	delivery.Position = UDim2.new(0, 0, 1, -bottom)
	delivery.Size = UDim2.new(1, 0, 0, 74)
	inset(delivery, 10, 9, 10, 9)
	local arriveRow = box(delivery, "Arrive")
	arriveRow.Size = UDim2.new(1, 0, 0, 18)
	row(arriveRow, 6)
	Icon.make(arriveRow, "Hourglass", UDim2.fromOffset(16, 16)).LayoutOrder = 0
	local arrive = words(arriveRow, "", Enum.Font.GothamBold, text.SMALL, rgb("DELIVERY_INK"))
	arrive.LayoutOrder = 1
	arrive.Size = UDim2.new(1, -22, 1, 0)
	local padLine = words(delivery, "", Enum.Font.GothamBold, text.SMALL - 1, rgb("DELIVERY_SOFT"))
	padLine.Position = UDim2.fromOffset(0, 24)
	padLine.Size = UDim2.new(1, 0, 0, 16)
	local track = box(delivery, "Track", rgb("BAR_TRACK"), 999)
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.fromScale(0, 1)
	track.Size = UDim2.new(1, 0, 0, 8)
	track.ClipsDescendants = true
	local padCart = box(track, "Cart", rgb("BAR_CART"), 999)
	padCart.Size = UDim2.fromScale(0, 1)
	local padFill = box(track, "Fill", rgb("BAR_FILL"), 999)
	padFill.Size = UDim2.fromScale(0, 1)
	padFill.ZIndex = 2
	bottom += 74 + 8

	local cashAfter = words(aside, "", Enum.Font.GothamBold, text.SMALL - 1, rgb("INK_SOFT"))
	cashAfter.AnchorPoint = Vector2.new(0, 1)
	cashAfter.Position = UDim2.new(0, 0, 1, -bottom)
	cashAfter.Size = UDim2.new(1, 0, 0, 16)
	bottom += 18
	local totalRow = box(aside, "TotalRow")
	totalRow.AnchorPoint = Vector2.new(0, 1)
	totalRow.Position = UDim2.new(0, 0, 1, -bottom)
	totalRow.Size = UDim2.new(1, 0, 0, 30)
	local totalWord = words(totalRow, WORDS.TOTAL, Enum.Font.GothamBold, text.LINE, rgb("INK"))
	totalWord.Size = UDim2.new(0.4, 0, 1, 0)
	local total = words(totalRow, "", Enum.Font.FredokaOne, text.TOTAL, rgb("INK"))
	total.AnchorPoint = Vector2.new(1, 0)
	total.Position = UDim2.fromScale(1, 0)
	total.Size = UDim2.new(0.6, 0, 1, 0)
	total.TextXAlignment = Enum.TextXAlignment.Right
	bottom += 34
	local rule = box(aside, "Rule", rgb("CARD_EDGE"))
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.new(0, 0, 1, -bottom)
	rule.Size = UDim2.new(1, 0, 0, 2)
	bottom += 8

	local lines = Instance.new("ScrollingFrame")
	lines.Name = "Lines"
	lines.BackgroundTransparency = 1
	lines.BorderSizePixel = 0
	lines.ScrollBarThickness = 4
	lines.ScrollBarImageColor3 = rgb("INK_SOFT")
	lines.CanvasSize = UDim2.new()
	lines.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lines.Position = UDim2.fromOffset(0, 34)
	lines.Size = UDim2.new(1, 0, 1, -(34 + bottom))
	lines.Parent = aside
	column(lines, 4)
	local empty = UIKit.label(lines, WORDS.EMPTY_CART, Enum.Font.GothamBold, text.SMALL, rgb("INK_SOFT"))
	empty.Name = "Empty"
	empty.LayoutOrder = 999
	empty.Size = UDim2.new(1, -6, 0, 40)

	return {
		checkout = checkout,
		cartPill = pill,
		lineList = lines,
		cartEmpty = empty,
		total = total,
		cashAfter = cashAfter,
		arrive = arrive,
		padLine = padLine,
		padFill = padFill,
		padCart = padCart,
	} :: any
end

-- The monitor's taskbar: the paw, the store, the deliveries, the town's clock
local function taskbar(parent: Instance): (TextLabel, Frame, Frame)
	local bar = box(parent, "Taskbar", rgb("TASKBAR"), 14)
	bar.BackgroundTransparency = 0.38
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -DESK.TASKBAR_GAP)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.Size = UDim2.fromOffset(0, DESK.TASKBAR)
	bar.ZIndex = 5
	inset(bar, 10, 0, 12, 0)
	row(bar, 8)
	appIcon(bar, "Start", "Paw", rgb("DOT_BUTTER"), 30, false).LayoutOrder = 0
	local store = appIcon(bar, "StoreApp", "Order", rgb("SITE_BOTTOM"), 30, true)
	store.LayoutOrder = 1
	local deliveries = appIcon(bar, "DeliveriesApp", "Box", rgb("DOT_PINK"), 30, true)
	deliveries.LayoutOrder = 2
	local dots: { Frame } = {}
	for _, app in { store, deliveries } do
		local dot = box(app, "Active", rgb("INK"), 999)
		dot.AnchorPoint = Vector2.new(0.5, 0)
		dot.Position = UDim2.new(0.5, 0, 1, 1)
		dot.Size = UDim2.fromOffset(5, 5)
		table.insert(dots, dot)
	end
	;(store :: TextButton).Activated:Connect(function()
		showPage("order")
	end)
	;(deliveries :: TextButton).Activated:Connect(function()
		showPage("deliveries")
	end)
	local split = box(bar, "Split", rgb("INK"))
	split.BackgroundTransparency = 0.82
	split.LayoutOrder = 3
	split.Size = UDim2.fromOffset(2, 22)
	local clock = words(bar, "", Enum.Font.FredokaOne, DESK.TEXT.CLOCK, rgb("INK"))
	clock.LayoutOrder = 4
	clock.AutomaticSize = Enum.AutomaticSize.X
	clock.Size = UDim2.fromOffset(0, DESK.TASKBAR)
	return clock, dots[1], dots[2]
end

-- The browser's tab row and address bar
local function browserChrome(browser: Frame): TextLabel
	local text = DESK.TEXT
	local tabs = box(browser, "Tabs", rgb("TAB_ROW"))
	tabs.Size = UDim2.new(1, 0, 0, DESK.TAB_ROW)
	roundOneSide(tabs, 14, true)
	local dots = box(tabs, "Dots")
	at(dots, 14, 0, 50, DESK.TAB_ROW)
	row(dots, 6)
	for _, name in { "DOT_PINK", "DOT_BUTTER", "DOT_MINT" } do
		box(dots, name, rgb(name), 999).Size = UDim2.fromOffset(11, 11)
	end
	local tab = box(tabs, "Tab", rgb("BROWSER"))
	tab.AnchorPoint = Vector2.new(0, 1)
	tab.Position = UDim2.new(0, 74, 1, 0)
	tab.Size = UDim2.fromOffset(176, 26)
	tab.ZIndex = 2
	roundOneSide(tab, 10, true)
	local tabInner = box(tab, "Content")
	tabInner.Size = UDim2.fromScale(1, 1)
	tabInner.ZIndex = 3
	inset(tabInner, 12, 0, 12, 0)
	row(tabInner, 7)
	Icon.make(tabInner, "Paw", UDim2.fromOffset(15, 15)).LayoutOrder = 0
	local tabName = words(tabInner, WORDS.STORE, Enum.Font.GothamBold, text.URL - 1, rgb("INK"))
	tabName.LayoutOrder = 1
	tabName.AutomaticSize = Enum.AutomaticSize.X
	tabName.Size = UDim2.fromOffset(0, 26)

	local address = box(browser, "Address", rgb("BROWSER"))
	address.Position = UDim2.fromOffset(0, DESK.TAB_ROW)
	address.Size = UDim2.new(1, 0, 0, DESK.ADDRESS)
	local rule = box(address, "Rule", rgb("CARD_EDGE"))
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	rule.Size = UDim2.new(1, 0, 0, 2)
	local arrows = words(address, "<   >", Enum.Font.FredokaOne, 18, rgb("BEZEL_INK"))
	at(arrows, 14, 0, 44, DESK.ADDRESS - 2)
	local bar = box(address, "Url", rgb("URL"), 999)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 66, 0.5, -1)
	bar.Size = UDim2.new(1, -80, 0, 24)
	inset(bar, 12, 0, 12, 0)
	row(bar, 8)
	Icon.make(bar, "Lock", UDim2.fromOffset(13, 13)).LayoutOrder = 0
	local url = words(bar, WORDS.URL_ORDER, Enum.Font.GothamBold, text.URL, rgb("URL_INK"))
	url.LayoutOrder = 1
	url.Size = UDim2.new(1, -30, 1, 0)
	return url
end

-- A computer: a tablet (a monitor on a stand until 2026-11-22: it reached down over the bottom tiles) with even
-- bezels and a camera dot, the browser on the store, the cart beside the cards
local function buildDesktop(holder: Frame): Ui
	local width, height = DESK.MONITOR[1], DESK.MONITOR[2]
	local face = height - DESK.LIP
	local lip = box(holder, "Lip", rgb("BEZEL_LIP"), DESK.CORNER)
	at(lip, 0, DESK.LIP, width, face)
	local monitor = box(holder, "Monitor", rgb("BEZEL_TOP"), DESK.CORNER)
	at(monitor, 0, 0, width, face)
	monitor.ZIndex = 2
	shade(monitor, { rgb("BEZEL_TOP"), rgb("BEZEL_BOTTOM") })
	edge(monitor, WHITE, 4)
	local camera = box(monitor, "Camera", rgb("BEZEL_INK"), 999)
	at(camera, width / 2 - 4, DESK.BEZEL / 2 - 4, 8, 8)

	local screen = box(monitor, "Screen", rgb("WALL_TOP"), 16)
	screen.Position = UDim2.fromOffset(DESK.BEZEL, DESK.BEZEL)
	screen.Size = UDim2.new(1, -DESK.BEZEL * 2, 1, -DESK.BEZEL * 2)
	shade(screen, { rgb("WALL_TOP"), rgb("WALL_MIDDLE"), rgb("WALL_BOTTOM") }, 60)
	edge(screen, rgb("SCREEN_EDGE"), 3)

	local browserBottom = DESK.TASKBAR + DESK.TASKBAR_GAP + DESK.BROWSER_INSET
	local browser = box(screen, "Browser", rgb("PAGE_TOP"), 14)
	browser.Position = UDim2.fromOffset(DESK.BROWSER_INSET, DESK.BROWSER_INSET)
	browser.Size = UDim2.new(1, -DESK.BROWSER_INSET * 2, 1, -(DESK.BROWSER_INSET + browserBottom))
	shade(browser, { rgb("PAGE_TOP"), rgb("PAGE_BOTTOM") })
	local url = browserChrome(browser)
	local chrome = DESK.TAB_ROW + DESK.ADDRESS
	local site, navOrder, navDeliveries, badge, badgeText, cashText = siteHeader(browser, DESK.SITE_HEADER, DESK.TEXT.LOGO, DESK.TEXT.NAV, 30, 14)
	site.Position = UDim2.fromOffset(0, chrome)
	chrome += DESK.SITE_HEADER

	local area = box(browser, "Page")
	area.Position = UDim2.fromOffset(0, chrome)
	area.Size = UDim2.new(1, 0, 1, -chrome)
	local orderPage = box(area, "Order")
	orderPage.Size = UDim2.fromScale(1, 1)
	inset(orderPage, DESK.PAD, DESK.PAD - 10, DESK.PAD, DESK.PAD)
	-- the page's room inside the browser (the browser's height less its chrome and padding)
	local screenHeight = face - DESK.BEZEL * 2
	local pageHeight = screenHeight - DESK.BROWSER_INSET - browserBottom - chrome - (DESK.PAD - 10) - DESK.PAD
	local cellHeight = math.floor((pageHeight - 14 - DESK.GAP) / 2)
	local grid = cardGrid(orderPage, UDim2.new(0.5, -DESK.GAP / 2, 0, cellHeight), DESK.GAP)
	grid.Size = UDim2.new(1, -(DESK.CART_WIDTH + DESK.PAD), 1, 0)
	local cartUi = cartAside(orderPage, pageHeight - 10)
	local deliveries = deliveriesPage(area, 16)
	local clock, taskOrder, taskDeliveries = taskbar(screen)

	cartUi.cash = cashText
	cartUi.badge = badge
	cartUi.badgeText = badgeText
	cartUi.navOrder = navOrder
	cartUi.navDeliveries = navDeliveries
	cartUi.orderPage = orderPage
	cartUi.deliveriesPage = deliveries
	cartUi.url = url
	cartUi.clock = clock
	cartUi.taskOrder = taskOrder
	cartUi.taskDeliveries = taskDeliveries
	return cartUi
end

-- A phone: a thin screen, the store's header, four cards in a row and the cart as a bar along the bottom
local function buildPhone(holder: Frame): Ui
	local width, height = PHONE.MONITOR[1], PHONE.MONITOR[2]
	local text = PHONE.TEXT
	local lip = box(holder, "Lip", rgb("BEZEL_LIP"), 22)
	at(lip, 0, 6, width, height - 6)
	local monitor = box(holder, "Monitor", rgb("BEZEL_TOP"), 22)
	at(monitor, 0, 0, width, height - 6)
	monitor.ZIndex = 2
	shade(monitor, { rgb("BEZEL_TOP"), rgb("BEZEL_BOTTOM") })
	edge(monitor, WHITE, 3)
	local screen = box(monitor, "Screen", rgb("PAGE_TOP"), 15)
	screen.Position = UDim2.fromOffset(PHONE.BEZEL, PHONE.BEZEL)
	screen.Size = UDim2.new(1, -PHONE.BEZEL * 2, 1, -PHONE.BEZEL * 2)
	shade(screen, { rgb("PAGE_TOP"), rgb("PAGE_BOTTOM") })
	edge(screen, rgb("SCREEN_EDGE"), 2)

	local site, navOrder, navDeliveries, badge, badgeText, cashText = siteHeader(screen, PHONE.HEADER, text.LOGO, text.NAV, PHONE.NAV_HEIGHT, 62)
	roundOneSide(site, 15, true)

	local screenHeight = height - 6 - PHONE.BEZEL * 2
	local pageHeight = screenHeight - PHONE.HEADER - PHONE.BAR
	local area = box(screen, "Page")
	area.Position = UDim2.fromOffset(0, PHONE.HEADER)
	area.Size = UDim2.new(1, 0, 0, pageHeight)
	local orderPage = box(area, "Order")
	orderPage.Size = UDim2.fromScale(1, 1)
	inset(orderPage, PHONE.PAD, 0, PHONE.PAD, PHONE.PAD)
	local cellHeight = pageHeight - PHONE.PAD - 14
	local grid = cardGrid(orderPage, UDim2.new(0.25, -PHONE.GAP * 3 / 4, 0, cellHeight), PHONE.GAP)
	grid.Size = UDim2.fromScale(1, 1)
	local deliveries = deliveriesPage(area, 12)

	local bar = box(screen, "CartBar", rgb("CARD"))
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, PHONE.BAR)
	roundOneSide(bar, 15, false)
	local rule = box(bar, "Rule", rgb("CARD_EDGE"))
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.ZIndex = 3
	local cartIcon = Icon.make(bar, "Box", UDim2.fromOffset(30, 30))
	cartIcon.AnchorPoint = Vector2.new(0, 0.5)
	cartIcon.Position = UDim2.new(0, 14, 0.5, 0)
	local summary = words(bar, "", Enum.Font.FredokaOne, text.SUMMARY, rgb("INK"))
	summary.Position = UDim2.fromOffset(54, 10)
	summary.Size = UDim2.new(1, -(54 + PHONE.CHECKOUT[1] + 20), 0, text.SUMMARY + 4)
	local sub = words(bar, "", Enum.Font.GothamBold, text.SMALL, rgb("DELIVERY_INK"))
	sub.Position = UDim2.fromOffset(54, 12 + text.SUMMARY + 4)
	sub.Size = UDim2.new(1, -(54 + PHONE.CHECKOUT[1] + 20), 0, text.SMALL + 4)
	local checkout = UIKit.button(bar, "", UIKit.Colors.Success)
	checkout.Name = "Checkout"
	checkout.Font = Enum.Font.FredokaOne
	checkout.TextSize = text.BUTTON
	checkout.AnchorPoint = Vector2.new(1, 0.5)
	checkout.Position = UDim2.new(1, -10, 0.5, 0)
	checkout.Size = UDim2.fromOffset(PHONE.CHECKOUT[1], PHONE.CHECKOUT[2])

	return {
		checkout = checkout,
		summary = summary,
		summarySub = sub,
		cash = cashText,
		badge = badge,
		badgeText = badgeText,
		navOrder = navOrder,
		navDeliveries = navDeliveries,
		orderPage = orderPage,
		deliveriesPage = deliveries,
	} :: any
end

-- Refreshing ---------------------------------------------------------------------------------------------------

-- Your own shop's shelves as the order computer sees them (the shelves tag)
local function myShelves(): { OrderRules.ShelfInfo }
	local shelves: { OrderRules.ShelfInfo } = {}
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in if plots then plots:GetChildren() else {} do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local folder = plot:FindFirstChild("Shelves")
			for _, part in if folder then folder:GetChildren() else {} do
				local def = Shelves.ById[part.Name]
				if def and part:IsA("BasePart") then
					local productId, units = part:GetAttribute("ProductId"), part:GetAttribute("Units")
					table.insert(shelves, {
						kind = def.kind,
						capacity = def.capacity,
						units = if typeof(units) == "number" then units else 0,
						productId = if typeof(productId) == "string" then productId else nil,
						accepts = def.accepts,
					})
				end
			end
		end
	end
	return shelves
end

local function refreshTags()
	local shelves = myShelves()
	local lv = level()
	for _, card in cards do
		local tag = if lv >= card.product.unlockLevel then OrderRules.shelfTag(shelves, card.product.id, OrderComputer.LOW_SHARE) else nil
		card.tag.Visible = tag ~= nil
		card.tag.Text = tag or ""
	end
end

local function refreshCards()
	local lv, money, space, short = level(), cash(), room(), phone()
	for _, card in cards do
		local product = card.product
		local count = cart[product.id] or 0
		local look = OrderRules.addLook(product, lv, money, cart, byId, space, short)
		local locked = look.state == "locked"
		local ready = look.state == "ready"
		card.frame:SetAttribute("InCart", count)
		card.face.BackgroundColor3 = if locked then rgb("LOCKED_CARD") else rgb("CARD")
		card.faceEdge.Color = if locked then rgb("LOCKED_EDGE") else rgb("CARD_EDGE")
		card.picture.BackgroundColor3 = if locked then rgb("LOCKED_PICTURE") else tint(product)
		card.pictureLock.Visible = locked
		if card.shown:IsA("ImageLabel") then
			card.shown.ImageTransparency = if locked then 0.55 else 0
		end
		card.lockLine.Visible = locked
		card.lockText.Text = if locked then look.text else ""
		card.price.Visible = not locked
		if card.profit then
			card.profit.Visible = not locked
		end
		card.add.Visible = not locked and count == 0
		card.add.Text = look.text
		card.add.BackgroundColor3 = if ready then UIKit.Colors.Success else UIKit.Colors.Locked
		card.stepper.Visible = not locked and count > 0
		card.plus.BackgroundColor3 = if ready then UIKit.Colors.Success else UIKit.Colors.Locked
		card.count.Text = tostring(count)
		NewTag.set(card.frame, not locked and ShopTileRules.isNew(lv, product.unlockLevel))
	end
end

-- The cart's lines (a computer's cart beside the cards): one per product in it, made once and kept
local function refreshCartLines(current: Ui)
	local lines = current.lineList
	if not lines then
		return
	end
	local any = false
	for index, product in Products.List do
		local count = cart[product.id]
		local line = cartLines[product.id]
		if count and not line then
			local frame = box(lines, `Line_{product.id}`)
			frame.LayoutOrder = index
			frame.Size = UDim2.new(1, -6, 0, 30)
			local picture = box(frame, "Picture")
			at(picture, 0, 0, 26, 30)
			ProductPicture.fill(picture, product.id, product.icon)
			local label = words(frame, product.name, Enum.Font.GothamBold, DESK.TEXT.LINE - 1, rgb("INK"))
			label.Position = UDim2.fromOffset(32, 0)
			label.Size = UDim2.new(1, -(32 + 30 + 54), 1, 0)
			local countLabel = words(frame, "", Enum.Font.FredokaOne, DESK.TEXT.LINE, rgb("INK_SOFT"))
			countLabel.AnchorPoint = Vector2.new(1, 0)
			countLabel.Position = UDim2.new(1, -56, 0, 0)
			countLabel.Size = UDim2.new(0, 30, 1, 0)
			countLabel.TextXAlignment = Enum.TextXAlignment.Right
			local cost = words(frame, "", Enum.Font.FredokaOne, DESK.TEXT.LINE + 1, rgb("INK"))
			cost.AnchorPoint = Vector2.new(1, 0)
			cost.Position = UDim2.fromScale(1, 0)
			cost.Size = UDim2.new(0, 54, 1, 0)
			cost.TextXAlignment = Enum.TextXAlignment.Right
			line = { frame = frame, label = label, count = countLabel, cost = cost }
			cartLines[product.id] = line
		end
		if line then
			line.frame.Visible = count ~= nil
			if count then
				line.count.Text = `x{count}`
				line.cost.Text = OrderRules.money(product.boxCost * count)
			end
		end
		any = any or count ~= nil
	end
	if current.cartEmpty then
		current.cartEmpty.Visible = not any
	end
end

local function refreshCart()
	local current = ui
	if not current then
		return
	end
	local short = phone()
	local count = OrderRules.cartCount(cart)
	local cost = OrderRules.cartCost(cart, byId)
	local look = OrderRules.checkout(cart, byId, cash(), room(), short)
	current.checkout.Text = if sending then WORDS.SENDING else look.text
	current.checkout.BackgroundColor3 = if look.state == "ready" and not sending then UIKit.Colors.Success else UIKit.Colors.Locked
	local spots = used()
	if current.cartPill then
		current.cartPill.Text = OrderRules.cartPill(count)
	end
	if current.total then
		current.total.Text = OrderRules.money(cost)
	end
	if current.cashAfter then
		current.cashAfter.Text = OrderRules.cashAfter(cash(), cost)
		current.cashAfter.Visible = count > 0
	end
	if current.arrive then
		current.arrive.Text = OrderRules.arriveLine(tripSeconds)
	end
	if current.padLine then
		current.padLine.Text = OrderRules.padLine(spots, MAX_BOXES)
	end
	if current.padFill and current.padCart then
		local share = math.clamp(spots / MAX_BOXES, 0, 1)
		current.padFill.Size = UDim2.fromScale(share, 1)
		current.padCart.Size = UDim2.fromScale(math.clamp((spots + math.min(count, room())) / MAX_BOXES, 0, 1), 1)
	end
	if current.summary and current.summarySub then
		current.summary.Text = OrderRules.phoneSummary(cart, byId)
		current.summarySub.Text = `{OrderRules.arriveLine(tripSeconds, true)} · {OrderRules.padLine(spots, MAX_BOXES, true)}`
	end
	refreshCartLines(current)
end

local function refreshHeader()
	local current = ui
	if not current then
		return
	end
	current.cash.Text = OrderRules.money(cash())
	local comingCount = getNumber("BoxesComing", 0)
	current.badge.Visible = comingCount > 0
	current.badgeText.Text = tostring(comingCount)
	local padding = current.navDeliveries:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingRight = UDim.new(0, if comingCount > 0 then current.badge.Size.X.Offset + 18 else 14)
	end
	if current.clock then
		current.clock.Text = RegisterStationRules.clock(Lighting.ClockTime)
	end
end

-- The countdown on each box on the way (My deliveries)
local function tickDeliveries()
	local now = os.clock()
	for _, entry in comingRows do
		local left = entry.item.arriveAt - now
		entry.text.Text = OrderRules.comingLine(left)
		entry.fill.Size = UDim2.fromScale(OrderRules.comingShare(math.max(0, left), entry.item.seconds), 1)
	end
end

-- My deliveries: the boxes on the way (one row each kind and trip), the boxes waiting on the pad and a hint
function OrderController.RenderDeliveries()
	local current = ui
	if not current then
		return
	end
	local list = current.deliveriesPage
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(comingRows)
	local short = phone()
	local text = if short then PHONE.TEXT else DESK.TEXT
	local rowHeight = if short then 52 else 62
	local order = 0
	local empty = #coming == 0
	local function line(value: string, font: Enum.Font, size: number, color: Color3)
		order += 1
		local label = UIKit.label(list, value, font, size, color)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextXAlignment = if empty then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	end
	if empty then
		order += 1
		local art = box(list, "EmptyArt")
		art.LayoutOrder = order
		art.Size = UDim2.new(1, -8, 0, if short then 56 else 84)
		local picture = Icon.make(art, "Box", UDim2.fromOffset(if short then 52 else 76, if short then 52 else 76))
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		line(WORDS.NO_DELIVERIES, Enum.Font.FredokaOne, text.NAME + 2, rgb("INK"))
	else
		line(WORDS.COMING, Enum.Font.FredokaOne, text.NAME + 2, rgb("INK"))
	end
	-- the same product on the same trip shares a row: "Card Sleeves x2"
	local groups: { { item: Coming, count: number } } = {}
	for _, item in coming do
		local found = false
		for _, group in groups do
			if group.item.productId == item.productId and math.abs(group.item.arriveAt - item.arriveAt) < 0.05 then
				group.count += 1
				found = true
				break
			end
		end
		if not found then
			table.insert(groups, { item = item, count = 1 })
		end
	end
	for _, group in groups do
		local product = Products.ById[group.item.productId]
		if product then
			order += 1
			local card = box(list, `Coming_{order}`, rgb("CARD"), 14)
			card.LayoutOrder = order
			card.Size = UDim2.new(1, -8, 0, rowHeight)
			edge(card, rgb("CARD_EDGE"), 2)
			local picture = box(card, "Picture", tint(product), 10)
			at(picture, 8, 6, rowHeight - 12, rowHeight - 12)
			ProductPicture.fill(picture, product.id, product.icon)
			local left = rowHeight + 4
			local name = words(card, OrderRules.cartLine(product.name, group.count), Enum.Font.FredokaOne, text.NAME, rgb("INK"))
			name.Position = UDim2.fromOffset(left, 6)
			name.Size = UDim2.new(0.55, -left, 0, text.NAME + 4)
			local when = words(card, "", Enum.Font.GothamBold, text.SMALL + 1, rgb("DELIVERY_INK"))
			when.Position = UDim2.fromOffset(left, rowHeight - text.SMALL - 12)
			when.Size = UDim2.new(0.55, -left, 0, text.SMALL + 4)
			local track = box(card, "Track", rgb("BAR_TRACK"), 999)
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -14, 0.5, 0)
			track.Size = UDim2.new(0.42, -14, 0, 10)
			track.ClipsDescendants = true
			local fill = box(track, "Fill", rgb("BAR_FILL"), 999)
			fill.Size = UDim2.fromScale(0, 1)
			table.insert(comingRows, { text = when, fill = fill, item = group.item })
		end
	end
	local waiting = OrderRules.waitingLine(getNumber("BoxesWaiting", 0))
	if waiting then
		line(waiting, Enum.Font.GothamBold, text.SMALL + 3, rgb("INK"))
	end
	line(WORDS.PAD_HINT, Enum.Font.GothamBold, text.SMALL + 1, rgb("INK_SOFT"))
	if empty then
		order += 1
		local holder = box(list, "Back")
		holder.LayoutOrder = order
		holder.Size = UDim2.new(1, -8, 0, 58)
		local back = UIKit.button(holder, WORDS.NAV_ORDER, UIKit.Colors.Success)
		back.Name = "BackToStore"
		back.Font = Enum.Font.FredokaOne
		back.TextSize = text.NAME
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.Position = UDim2.fromScale(0.5, 0.5)
		back.Size = UDim2.fromOffset(190, 46)
		back.Activated:Connect(function()
			showPage("order")
		end)
	end
	tickDeliveries()
end

function OrderController.Refresh()
	refreshCards()
	refreshCart()
	refreshHeader()
end

-- Fitting and opening --------------------------------------------------------------------------------------------

local function layoutSize(): Vector2
	local size = if built == "phone" then PHONE.MONITOR else DESK.MONITOR
	return Vector2.new(size[1], size[2])
end

-- The computer as big as fits: in the room under Roblox's top bar, above the bottom tiles while they show (owner
-- 2026-11-22: the monitor's stand reached down over them), growing on a big screen like the HUD (Config/HudGrow; the
-- window's own growth is off: SizesItself)
local function fit()
	local current = ui
	if not current then
		return
	end
	local parent = panel.Parent
	local gui = if parent and parent:IsA("GuiBase2d") then parent else nil
	local area = if gui then gui.AbsoluteSize else Vector2.new(1280, 720)
	local tiles = Hud.bottomTop()
	local floor = if gui and tiles then tiles - gui.AbsolutePosition.Y else nil
	local grow = if HudGrowConfig.WINDOWS then HudGrow.scale(area.Y, UserInputService.TouchEnabled, HudGrowConfig) else 1
	local size = layoutSize()
	local scale, middle = OrderRules.fit({ w = area.X, h = area.Y }, { w = size.X, h = size.Y }, floor, OrderComputer.FIT, grow)
	current.scale.Scale = scale
	panel.Size = UDim2.fromOffset(math.floor(size.X * scale), math.floor(size.Y * scale))
	panel.Position = UDim2.new(0.5, 0, 0, middle)
end

-- Builds the layout for this screen (a computer's or a phone's), again when the screen changed kind
local function ensureBuilt()
	local want = if UIKit.isShort() then "phone" else "desktop"
	if ui and built == want then
		fit()
		return
	end
	if ui then
		ui.root:Destroy()
	end
	table.clear(cards)
	table.clear(cartLines)
	table.clear(comingRows)
	built = want
	local root = box(panel, "Computer")
	local size = layoutSize()
	root.Size = UDim2.fromOffset(size.X, size.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local made = if want == "phone" then buildPhone(root) else buildDesktop(root)
	made.root = root
	made.scale = scale
	made.checkout.Activated:Connect(function()
		OrderController.Checkout()
	end)
	ui = made
	showPage(page)
	fit()
end

function OrderController.Checkout()
	if sending then
		return
	end
	local look = OrderRules.checkout(cart, byId, cash(), room(), phone())
	if look.state ~= "ready" then
		UIController.Notify(look.why or "You can't order that now.", true)
		return
	end
	sending = true
	refreshCart()
	Remotes.OrderCart:FireServer(cart)
	task.delay(OrderComputer.SEND_WAIT, function()
		if sending then
			sending = false
			refreshCart()
		end
	end)
end

-- The open window's loop: the deliveries' countdown, the shelves tags and the clock
local function startTicking()
	ticking += 1
	local token = ticking
	task.spawn(function()
		local since = 0
		while panel.Visible and ticking == token do
			local now = os.clock()
			local before = #coming
			for index = #coming, 1, -1 do
				if coming[index].arriveAt < now - 1 then
					table.remove(coming, index) -- landed on the pad
				end
			end
			if #coming ~= before and page == "deliveries" then
				OrderController.RenderDeliveries()
			else
				tickDeliveries()
			end
			since += TICK
			if since >= OrderComputer.REFRESH then
				since = 0
				refreshTags()
				refreshHeader()
			end
			task.wait(TICK)
		end
	end)
end

-- What the server says: a box's trip time now and the boxes on the way (seconds left of each)
local function readInfo(info: unknown): number
	if typeof(info) ~= "table" then
		return 0
	end
	local data = info :: { [string]: any }
	if typeof(data.seconds) == "number" then
		tripSeconds = data.seconds
	end
	if typeof(data.coming) == "table" then
		local now = os.clock()
		table.clear(coming)
		for _, item in data.coming do
			if typeof(item) == "table" and typeof(item.productId) == "string" and typeof(item.left) == "number" and typeof(item.seconds) == "number" then
				table.insert(coming, { productId = item.productId, arriveAt = now + item.left, seconds = item.seconds })
			end
		end
	end
	return if typeof(data.boxes) == "number" then data.boxes else 0
end

local function open(info: unknown)
	readInfo(info)
	ensureBuilt()
	showPage("order")
	OrderController.Refresh()
	refreshTags()
	panel.Visible = true
	startTicking()
end

-- The server's answer to Order now: the cart goes and My deliveries shows the boxes on their way
local function placed(info: unknown)
	local boxes = readInfo(info)
	sending = false
	if boxes > 0 then
		cart = {}
		if panel.Visible then
			showPage("deliveries")
		end
	end
	if panel.Visible then
		OrderController.Refresh()
		OrderController.RenderDeliveries()
	end
end

function OrderController.Start()
	local list: ScrollingFrame
	panel, list = UIKit.panel(UIController.GetScreenGui(), "OrderMenu", "Order Stock")
	list:Destroy()
	-- the computer is the window: no cream face, band or title of its own (the X stays on the monitor's corner)
	panel.BackgroundTransparency = 1
	for _, name in { "Header", "Title", "Glow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	-- it fits and grows itself, clear of the bottom tiles (fit): no window growth on top
	panel:SetAttribute("SizesItself", true)

	Remotes.OpenOrderMenu.OnClientEvent:Connect(open)
	Remotes.OrderPlaced.OnClientEvent:Connect(placed)
	for _, name in { "Level", "Cash", "BoxesUsed" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				OrderController.Refresh()
			end
		end)
	end
	for _, name in { "BoxesComing", "BoxesWaiting" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				refreshHeader()
				OrderController.RenderDeliveries()
			end
		end)
	end
	-- a window resized (or a phone turned): the computer fits again, a phone's layout if it's short now; a frame later,
	-- once the HUD's tiles have their new size
	local gui = UIController.GetScreenGui()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(function()
			if panel.Visible then
				ensureBuilt()
				OrderController.Refresh()
				refreshTags()
			end
		end)
	end)
end

return OrderController
