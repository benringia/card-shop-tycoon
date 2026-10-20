--!strict
-- Visiting other players' card cases: a "Browse cards" prompt opens a panel of their cards as large
-- card faces with price and a deal tag. Collector Cases have Buy buttons (then a confirm box whose
-- price the server re-checks); Glass Showcases are view only, since NPC customers buy from those.
-- Prompts are created on this client only, never on your own cases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Shelves = require(Config:WaitForChild("Shelves"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])

-- Tile, top to bottom: card face, price, deal tag (or market value), Buy button
local FACE_HEIGHT = 172
local PRICE_Y = FACE_HEIGHT + 4
local TAG_Y = PRICE_Y + 24
local BUY_Y = TAG_Y + 20
local BUY_HEIGHT = 44
local TILE_SIZE = Vector2.new(124, BUY_Y + BUY_HEIGHT)
local DISTANCE_CHECK_SECONDS = 0.5
local DEAL_COLORS = {
	Good = Color3.fromRGB(110, 220, 130),
	Fair = Color3.fromRGB(240, 210, 90),
	Pricey = Color3.fromRGB(245, 150, 70),
}

local player = Players.LocalPlayer

local CardBuyController = {}

local browsePanel: Frame
local browseList: ScrollingFrame
local browseTitle: TextLabel
local browseSubtitle: TextLabel
local browsedCase: BasePart? = nil
local caseConnections: { RBXScriptConnection } = {}

local detail: Frame
local detailFaceHolder: Frame
local detailInfo: TextLabel
local detailBuy: TextButton
local detailPart: BasePart? = nil

local confirm: Frame
local confirmText: TextLabel
local pendingPart: BasePart? = nil
local pendingPrice = 0

local render: () -> ()

local function getPrice(part: BasePart): number
	local price = part:GetAttribute("Price")
	return if typeof(price) == "number" then price else 0
end

local function getCard(part: BasePart): (Card?, boolean)
	local cardId = part:GetAttribute("CardId")
	local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
	return card, part:GetAttribute("Foil") == true
end

-- A displayed card's level and stars (1, 1 for a fresh copy)
local function getGrowthFromPart(part: BasePart): (number, number)
	local level, stars = part:GetAttribute("Level"), part:GetAttribute("Stars")
	return if typeof(level) == "number" then level else 1, if typeof(stars) == "number" then stars else 1
end

-- Always drawn, so visitors can see the level of every card, fresh or raised
local function getFaceGrowth(part: BasePart): CardFace.Growth
	local level, stars = getGrowthFromPart(part)
	return { level = level, stars = stars }
end

-- A raised beast carries its ID on the part; fresh copies don't
local function isBeast(part: BasePart): boolean
	return typeof(part:GetAttribute("BeastId")) == "string"
end

-- "Lv 12 · 2 stars · raised beast" / "Lv 1 · 1 star · fresh copy"
local function describeKind(part: BasePart): string
	local level, stars = getGrowthFromPart(part)
	return `{BeastRules.describeGrowth(level, stars)} · {if isBeast(part) then "raised beast" else "fresh copy"}`
end

local function getMarket(part: BasePart, card: Card, foil: boolean): number
	local level, stars = getGrowthFromPart(part)
	return CardRules.getMarketValue(card, foil, level, stars)
end

local function describe(part: BasePart): string
	local card, foil = getCard(part)
	local name = if card then card.name else "card"
	name = if foil then `FOIL {name}` else name
	local level, stars = getGrowthFromPart(part)
	return `{name} ({BeastRules.describeGrowth(level, stars)})`
end

local function getOwner(instance: Instance): Player?
	local plot = instance:FindFirstAncestorOfClass("Model")
	local ownerUserId = if plot then plot:GetAttribute("OwnerUserId") else nil
	return if typeof(ownerUserId) == "number" and ownerUserId ~= 0 then Players:GetPlayerByUserId(ownerUserId) else nil
end

local function getDeal(price: number, market: number): (string, Color3)
	local ratio = if market > 0 then price / market else math.huge
	if ratio <= ShowcaseConfig.GOOD_DEAL_MAX_RATIO + 1e-6 then
		return "Good deal", DEAL_COLORS.Good
	elseif ratio <= ShowcaseConfig.FAIR_DEAL_MAX_RATIO + 1e-6 then
		return "Fair", DEAL_COLORS.Fair
	end
	return "Pricey", DEAL_COLORS.Pricey
end

-- showValue = false on browse tiles: the asking price sits right under the card instead
local function makeFace(parent: Instance, card: Card, foil: boolean, size: UDim2, showValue: boolean, growth: CardFace.Growth?)
	local face = Instance.new("Frame")
	face.Size = size
	face.Parent = parent
	UIKit.corner(face, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil, showValue, growth)
end

local function isBuyable(part: BasePart): boolean
	return part:GetAttribute("ShelfKind") == "PlayerCards"
end

-- Card parts in the case, in slot order
local function getCardParts(casePart: BasePart): { BasePart }
	local parts: { BasePart } = {}
	for _, child in casePart:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("CardId")) == "string" then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return (a:GetAttribute("Slot") :: number) < (b:GetAttribute("Slot") :: number)
	end)
	return parts
end

-- Confirm box ------------------------------------------------------------------------------------

local function openConfirm(part: BasePart)
	local owner = getOwner(part)
	pendingPart = part
	pendingPrice = getPrice(part)
	confirmText.Text = string.format(
		"Buy %s from %s for $%.2f?",
		describe(part),
		if owner then owner.DisplayName else "another player",
		pendingPrice
	)
	confirm.Visible = true
end

local function closeConfirm()
	confirm.Visible = false
	pendingPart = nil
end

local function onConfirmBuy()
	local part = pendingPart
	closeConfirm()
	if not part or not part.Parent then
		UIController.Notify("That card is no longer for sale.", true)
		return
	end
	Remotes.BuyDisplayedCard:FireServer(
		part:GetAttribute("OwnerUserId"),
		part:GetAttribute("ShelfUid"),
		part:GetAttribute("Slot"),
		part:GetAttribute("CardId"),
		part:GetAttribute("Foil"),
		pendingPrice,
		part:GetAttribute("BeastId")
	)
end

-- Detail view (one card large) -------------------------------------------------------------------

local function renderDetail()
	local part = detailPart
	if not part or not part.Parent then
		detail.Visible = false
		detailPart = nil
		return
	end
	local card, foil = getCard(part)
	if not card then
		detail.Visible = false
		detailPart = nil
		return
	end
	for _, child in detailFaceHolder:GetChildren() do
		child:Destroy()
	end
	makeFace(detailFaceHolder, card, foil, UDim2.fromScale(1, 1), true, getFaceGrowth(part))

	local price = getPrice(part)
	local market = getMarket(part, card, foil)
	local deal = getDeal(price, market)
	local level, stars = getGrowthFromPart(part)
	detailInfo.Text = string.format(
		"%s%s\n%s %s\n%s\n%s\n\nPrice: $%.2f\nMarket value: $%.2f\n%s",
		if foil then "FOIL " else "",
		card.name,
		card.element,
		card.rarity,
		describeKind(part),
		BeastRules.describeStarProgress(level, stars),
		price,
		market,
		if isBuyable(part) then deal else "For customers only"
	)
	detailBuy.Visible = isBuyable(part)
	detailBuy.Text = string.format("Buy $%.2f", price)
end

local function openDetail(part: BasePart)
	detailPart = part
	renderDetail()
	detail.Visible = detailPart ~= nil
end

-- Browse panel -----------------------------------------------------------------------------------

local function buildTile(part: BasePart, order: number)
	local card, foil = getCard(part)
	if not card then
		return
	end
	local price = getPrice(part)
	local market = getMarket(part, card, foil)

	local tile = Instance.new("Frame")
	tile.LayoutOrder = order
	tile.BackgroundTransparency = 1
	tile.Parent = browseList

	local faceButton = Instance.new("TextButton")
	faceButton.Size = UDim2.new(1, 0, 0, FACE_HEIGHT)
	faceButton.BackgroundTransparency = 1
	faceButton.Text = ""
	faceButton.Parent = tile
	makeFace(faceButton, card, foil, UDim2.fromScale(1, 1), false, getFaceGrowth(part))
	faceButton.Activated:Connect(function()
		openDetail(part)
	end)

	local priceLabel = UIKit.label(tile, string.format("$%.2f", price), Enum.Font.FredokaOne, 20, Color3.fromRGB(120, 230, 120))
	priceLabel.TextXAlignment = Enum.TextXAlignment.Center
	priceLabel.Position = UDim2.fromOffset(0, PRICE_Y)
	priceLabel.Size = UDim2.new(1, 0, 0, 22)

	local tagText, tagColor
	if isBuyable(part) then
		tagText, tagColor = getDeal(price, market)
	else
		tagText, tagColor = string.format("market $%.2f", market), UIKit.Colors.Subtext
	end
	local tagLabel = UIKit.label(tile, tagText, Enum.Font.GothamBold, 13, tagColor)
	tagLabel.TextXAlignment = Enum.TextXAlignment.Center
	tagLabel.Position = UDim2.fromOffset(0, TAG_Y)
	tagLabel.Size = UDim2.new(1, 0, 0, 16)

	if isBuyable(part) then
		local buy = UIKit.button(tile, "Buy", UIKit.Colors.Accent)
		buy.Position = UDim2.fromOffset(0, BUY_Y)
		buy.Size = UDim2.new(1, 0, 0, BUY_HEIGHT)
		buy.TextSize = 18
		buy.Activated:Connect(function()
			openConfirm(part)
		end)
	end
end

render = function()
	local casePart = browsedCase
	if not casePart then
		return
	end
	for _, child in browseList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local parts = getCardParts(casePart)
	for index, part in parts do
		buildTile(part, index)
	end
	if #parts == 0 then
		local empty = UIKit.label(browseList, "This case is empty right now.", Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
		empty.Size = UDim2.fromOffset(280, 40)
	end
	if detail.Visible then
		renderDetail()
	end
	-- Keep an open confirm box honest: show the new price if the owner changes it
	local part = pendingPart
	if part and confirm.Visible and part.Parent and getPrice(part) ~= pendingPrice then
		openConfirm(part)
	end
end

local function disconnectCase()
	for _, connection in caseConnections do
		connection:Disconnect()
	end
	table.clear(caseConnections)
end

local function closeBrowse()
	browsePanel.Visible = false
end

local function openBrowse(casePart: BasePart)
	local def = Shelves.ById[casePart.Name]
	local owner = getOwner(casePart)
	if not def then
		return
	end
	disconnectCase()
	browsedCase = casePart
	browseTitle.Text = `{if owner then owner.DisplayName else "Someone"}'s {def.name}`
	browseSubtitle.Text = if def.kind == "PlayerCards"
		then "Tap a card for details, or Buy it."
		else "For customers only. Tap a card for details."

	-- Live updates: cards selling, being removed or added, and price changes
	local function watchCard(child: Instance)
		if child:IsA("BasePart") then
			table.insert(caseConnections, child:GetAttributeChangedSignal("Price"):Connect(render))
		end
	end
	for _, child in casePart:GetChildren() do
		watchCard(child)
	end
	table.insert(caseConnections, casePart.ChildAdded:Connect(function(child)
		watchCard(child)
		render()
	end))
	table.insert(caseConnections, casePart.ChildRemoved:Connect(function(child)
		if child == pendingPart then
			closeConfirm()
			UIController.Notify("That card just sold.", true)
		end
		render()
	end))
	table.insert(caseConnections, casePart.AncestryChanged:Connect(function()
		if not casePart:IsDescendantOf(workspace) then
			closeBrowse()
		end
	end))

	detail.Visible = false
	render()
	browsePanel.Visible = true
end

-- Prompts ----------------------------------------------------------------------------------------

local function isOtherPlayersCase(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end
	local def = Shelves.ById[instance.Name]
	if not def or def.kind == "Products" or instance:GetAttribute("ShelfUid") == nil then
		return false
	end
	local owner = getOwner(instance)
	return owner ~= nil and owner ~= player
end

local function addBrowsePrompt(instance: Instance)
	if not isOtherPlayersCase(instance) then
		return
	end
	local casePart = instance :: BasePart
	local def = Shelves.ById[casePart.Name]
	local owner = getOwner(casePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse cards"
	prompt.ObjectText = `{if owner then owner.DisplayName else "Someone"}'s {def.name}`
	prompt.MaxActivationDistance = ShowcaseConfig.BUY_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = casePart
	prompt.Triggered:Connect(function()
		openBrowse(casePart)
	end)
end

-- UI construction --------------------------------------------------------------------------------

local function buildBrowsePanel(parent: Instance)
	browsePanel, browseList = UIKit.panel(parent, "BrowseCase", "Cards")
	browseTitle = browsePanel:FindFirstChild("Title") :: TextLabel
	browseTitle.TextSize = 22
	browseSubtitle = UIKit.label(browsePanel, "", Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	browseSubtitle.Position = UDim2.fromOffset(16, 56)
	browseSubtitle.Size = UDim2.new(1, -32, 0, 22)

	browseList.Position = UDim2.fromOffset(12, 84)
	browseList.Size = UDim2.new(1, -24, 1, -96)
	local listLayout = browseList:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = browseList

	-- Room around the grid so thick rarity borders on the outer cards aren't clipped
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = browseList

	browsePanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not browsePanel.Visible then
			disconnectCase()
			browsedCase = nil
			detail.Visible = false
			detailPart = nil
			closeConfirm()
		end
	end)
end

-- Card shown large over the grid: card on the left, info and Buy on the right
local function buildDetail()
	detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.Size = UDim2.fromScale(1, 1)
	detail.BackgroundColor3 = UIKit.Colors.Panel
	detail.ZIndex = 10
	detail.Visible = false
	detail.Active = true
	detail.Parent = browsePanel
	UIKit.corner(detail, 14)

	detailFaceHolder = Instance.new("Frame")
	detailFaceHolder.Position = UDim2.fromOffset(16, 16)
	detailFaceHolder.Size = UDim2.fromOffset(150, 214)
	detailFaceHolder.BackgroundTransparency = 1
	detailFaceHolder.Parent = detail

	detailInfo = UIKit.label(detail, "", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	detailInfo.Position = UDim2.fromOffset(180, 16)
	detailInfo.Size = UDim2.new(1, -192, 0, 170)
	detailInfo.TextYAlignment = Enum.TextYAlignment.Top

	detailBuy = UIKit.button(detail, "Buy", UIKit.Colors.Accent)
	detailBuy.Position = UDim2.fromOffset(180, 192)
	detailBuy.Size = UDim2.new(1, -192, 0, 48)
	detailBuy.Activated:Connect(function()
		if detailPart then
			openConfirm(detailPart)
		end
	end)

	local back = UIKit.button(detail, "Back", UIKit.Colors.Row)
	back.Position = UDim2.fromOffset(180, 248)
	back.Size = UDim2.new(1, -192, 0, 44)
	back.TextSize = 16
	back.Activated:Connect(function()
		detail.Visible = false
		detailPart = nil
	end)
end

local function buildConfirm(parent: Instance)
	confirm = Instance.new("Frame")
	confirm.Name = "BuyCardConfirm"
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.fromOffset(320, 170)
	confirm.BackgroundColor3 = UIKit.Colors.Panel
	confirm.Visible = false
	confirm.ZIndex = 20
	confirm.Parent = parent
	UIKit.corner(confirm, 14)

	confirmText = UIKit.label(confirm, "", Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	confirmText.TextXAlignment = Enum.TextXAlignment.Center
	confirmText.Position = UDim2.fromOffset(16, 16)
	confirmText.Size = UDim2.new(1, -32, 0, 70)

	local buy = UIKit.button(confirm, "Buy", UIKit.Colors.Accent)
	buy.Position = UDim2.new(0, 16, 1, -68)
	buy.Size = UDim2.new(0.5, -24, 0, 52)
	buy.Activated:Connect(onConfirmBuy)

	local cancel = UIKit.button(confirm, "Cancel", UIKit.Colors.Row)
	cancel.AnchorPoint = Vector2.new(1, 0)
	cancel.Position = UDim2.new(1, -16, 1, -68)
	cancel.Size = UDim2.new(0.5, -24, 0, 52)
	cancel.Activated:Connect(closeConfirm)
end

-- Closes the panel once the visitor walks away from the case
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local casePart = browsedCase
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if casePart and browsePanel.Visible and root
			and (root.Position - casePart.Position).Magnitude > ShowcaseConfig.BROWSE_CLOSE_DISTANCE
		then
			closeBrowse()
		end
	end
end

function CardBuyController.Start()
	local screenGui = UIController.GetScreenGui()
	buildBrowsePanel(screenGui)
	buildDetail()
	buildConfirm(screenGui)

	local plots = workspace:WaitForChild("Plots")
	plots.DescendantAdded:Connect(addBrowsePrompt)
	for _, instance in plots:GetDescendants() do
		addBrowsePrompt(instance)
	end
	task.spawn(watchDistance)
end

return CardBuyController
