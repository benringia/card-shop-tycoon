--!strict
-- Visiting other players' card cases: a "Browse cards" prompt opens a marketplace-style panel, listings
-- on the left (price and deal tag), the selected card's details on the right (hover a row with a mouse to
-- preview it). Collector Cases have a Buy button (then a confirm box whose price the server re-checks);
-- Glass Showcases are view only, since NPC customers buy from those.
-- Prompts are created on this client only, never on your own cases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

local PANEL_MAX_SIZE = Vector2.new(820, 520)
local LIST_WIDTH_SCALE = 0.55 -- listings share of the panel width; details pane gets the rest
local ROW_HEIGHT = 64
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local DETAIL_FACE_SIZE = Vector2.new(120, 171)
local PRICE_COLOR = Color3.fromRGB(120, 230, 120)
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

local pane: ScrollingFrame
local selectedPart: BasePart? = nil -- listing shown in the details pane

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

-- A displayed card's level, stars and grade (1, 0, C for a plain Grade C copy)
local function getGrowthFromPart(part: BasePart): (number, number, string)
	local level, stars, grade = part:GetAttribute("Level"), part:GetAttribute("Stars"), part:GetAttribute("Grade")
	return if typeof(level) == "number" then level else 1,
		if typeof(stars) == "number" then stars else BeastRules.START_STARS,
		if BeastRules.isGrade(grade) then grade :: string else BeastRules.DEFAULT_GRADE
end

-- Always drawn, so visitors can see the grade, level and stars of every card
local function getFaceGrowth(part: BasePart): CardFace.Growth
	local level, stars, grade = getGrowthFromPart(part)
	return { level = level, stars = stars, grade = grade }
end

-- "Grade S · Lv 12 · 2 stars"
local function describeKind(part: BasePart): string
	local level, stars, grade = getGrowthFromPart(part)
	return `{BeastRules.describeGrade(grade)} · {BeastRules.describeGrowth(level, stars)}`
end

local function getMarket(part: BasePart, card: Card, foil: boolean): number
	local level, stars, grade = getGrowthFromPart(part)
	return CardRules.getMarketValue(card, foil, level, stars, grade)
end

local function describe(part: BasePart): string
	local card, foil = getCard(part)
	local name = if card then card.name else "card"
	name = if foil then `FOIL {name}` else name
	return `{name} ({describeKind(part)})`
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
		part:GetAttribute("BeastId"),
		part:GetAttribute("Grade")
	)
end

-- Details pane --------------------------------------------------------------------------------------

local function clearPane()
	for _, child in pane:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The card large, its details, price, deal and (Collector Cases) the Buy button.
-- isPreview: hovering a row; shows the details without the Buy button.
local function renderPane(part: BasePart?, isPreview: boolean)
	clearPane()
	local card: Card?, foil = nil, false
	if part then
		card, foil = getCard(part)
	end
	if not part or not card then
		local hint = UIKit.label(pane, "Tap a card to see its details.", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, 10)
		hint.Size = UDim2.new(1, -20, 0, 40)
		return
	end
	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 8)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = pane
	makeFace(faceHolder, card, foil, UDim2.fromScale(1, 1), true, getFaceGrowth(part))

	local level, stars, grade = getGrowthFromPart(part)
	local stats = BeastRules.getStats(card, foil, level, stars, grade)
	local power = BeastRules.getPower(card, foil, level, stars, grade)
	local price = getPrice(part)
	local market = getMarket(part, card, foil)
	local info = UIKit.label(pane, table.concat({
		`{card.name}{if foil then " (FOIL)" else ""}`,
		`{card.rarity} · {card.element} · #{card.number}`,
		describeKind(part),
		`Power {power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`,
		BeastRules.describeStarProgress(stars),
		string.format("Market $%.2f", market),
	}, "\n"), Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	info.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 16, 8)
	info.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 22), 0, DETAIL_FACE_SIZE.Y)
	info.TextYAlignment = Enum.TextYAlignment.Top

	local y = DETAIL_FACE_SIZE.Y + 16
	local priceLine = UIKit.label(pane, string.format("Price  $%.2f", price), Enum.Font.FredokaOne, 22, PRICE_COLOR)
	priceLine.Position = UDim2.fromOffset(10, y)
	priceLine.Size = UDim2.new(1, -20, 0, 28)
	y += 30
	local dealText, dealColor
	if isBuyable(part) then
		dealText, dealColor = getDeal(price, market)
	else
		dealText, dealColor = "For customers only", UIKit.Colors.Subtext
	end
	local dealLine = UIKit.label(pane, dealText, Enum.Font.GothamBold, 14, dealColor)
	dealLine.Position = UDim2.fromOffset(10, y)
	dealLine.Size = UDim2.new(1, -20, 0, 18)
	y += 26

	if isPreview or not isBuyable(part) then
		return
	end
	local buy = UIKit.button(pane, string.format("Buy $%.2f", price), UIKit.Colors.Accent)
	buy.Position = UDim2.fromOffset(8, y)
	buy.Size = UDim2.new(1, -16, 0, 48)
	buy.TextSize = 18
	buy.Activated:Connect(function()
		openConfirm(part)
	end)
end

-- Listings -------------------------------------------------------------------------------------------

local function addRowLabel(row: GuiObject, text: string, position: UDim2, size: UDim2, font: Enum.Font, textSize: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, textSize, color)
	label.Position = position
	label.Size = size
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- name / grade · level · stars        price / deal tag (or market value)
local function buildRow(part: BasePart, order: number)
	local card, foil = getCard(part)
	if not card then
		return
	end
	local price = getPrice(part)
	local market = getMarket(part, card, foil)

	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Text = ""
	row.Parent = browseList
	UIKit.corner(row, 8)
	if part == selectedPart then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = row
	end

	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(6, 4)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeFace(thumbnail, card, foil, UDim2.fromScale(1, 1), false)

	local textX = THUMBNAIL_SIZE.X + 14
	local name = `{card.name}{if foil then " FOIL" else ""}`
	addRowLabel(row, name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + 104), 0, 20), Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	addRowLabel(row, describeKind(part), UDim2.fromOffset(textX, 32), UDim2.new(1, -(textX + 104), 0, 18), Enum.Font.Gotham, 12, UIKit.Colors.Subtext)

	local priceLabel = addRowLabel(row, string.format("$%.2f", price), UDim2.new(1, -100, 0, 6), UDim2.fromOffset(90, 24), Enum.Font.FredokaOne, 19, PRICE_COLOR)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	local tagText, tagColor
	if isBuyable(part) then
		tagText, tagColor = getDeal(price, market)
	else
		tagText, tagColor = string.format("market $%.2f", market), UIKit.Colors.Subtext
	end
	local tag = addRowLabel(row, tagText, UDim2.new(1, -100, 0, 34), UDim2.fromOffset(90, 18), Enum.Font.GothamBold, 12, tagColor)
	tag.TextXAlignment = Enum.TextXAlignment.Right

	row.Activated:Connect(function()
		selectedPart = part
		render()
	end)
	row.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			renderPane(part, true)
		end
	end)
	row.MouseLeave:Connect(function()
		if UserInputService.MouseEnabled then
			renderPane(selectedPart, false)
		end
	end)
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
	-- Keep the selection on a card still in the case; otherwise show the first one
	if not (selectedPart and table.find(parts, selectedPart)) then
		selectedPart = parts[1]
	end
	for index, part in parts do
		buildRow(part, index)
	end
	if #parts == 0 then
		local empty = UIKit.label(browseList, "This case is empty right now.", Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
		empty.Size = UDim2.fromOffset(280, 40)
	end
	renderPane(selectedPart, false)
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

	selectedPart = nil
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
	browsePanel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = browsePanel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	browseTitle = browsePanel:FindFirstChild("Title") :: TextLabel
	browseTitle.TextSize = 22
	browseSubtitle = UIKit.label(browsePanel, "", Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	browseSubtitle.Position = UDim2.fromOffset(16, 56)
	browseSubtitle.Size = UDim2.new(1, -32, 0, 22)

	-- Listings on the left (the panel's list keeps its vertical layout), details on the right
	browseList.Position = UDim2.fromOffset(12, 84)
	browseList.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -96)

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 84)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -96)
	pane.BackgroundColor3 = UIKit.Colors.Row
	pane.BackgroundTransparency = 0.4
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = browsePanel
	UIKit.corner(pane, 10)

	browsePanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not browsePanel.Visible then
			disconnectCase()
			browsedCase = nil
			selectedPart = nil
			closeConfirm()
		end
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
	buildConfirm(screenGui)

	local plots = workspace:WaitForChild("Plots")
	plots.DescendantAdded:Connect(addBrowsePrompt)
	for _, instance in plots:GetDescendants() do
		addBrowsePrompt(instance)
	end
	task.spawn(watchDistance)
end

return CardBuyController
