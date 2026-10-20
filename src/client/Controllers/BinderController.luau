--!strict
-- Binder: every Set 1 card in a grid, owned ones in colour with counts, missing ones greyed out.
-- Tap an owned card to see it large and quick sell copies. "Sell dupes" keeps one of each.
-- The server sends the whole collection whenever it changes; this only displays it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])
type Owned = { normal: number, foil: number }

type Tile = {
	card: Card,
	inner: Frame,
	stroke: UIStroke,
	countLabel: TextLabel,
}

local TILE_SIZE = Vector2.new(78, 112)
local BINDER_KEY = Enum.KeyCode.B

local BinderController = {}

local collection: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local completionLabel: TextLabel
local dupesButton: TextButton

local detail: Frame
local detailInner: Frame
local detailStroke: UIStroke
local detailInfo: TextLabel
local sellNormalButton: TextButton
local sellFoilButton: TextButton
local detailCard: Card? = nil

local function getOwned(cardId: string): Owned
	return collection[cardId] or { normal = 0, foil = 0 }
end

local function addCardFrame(parent: Instance): (Frame, UIStroke)
	local inner = Instance.new("Frame")
	inner.Name = "Face"
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = parent
	UIKit.corner(inner, 8)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner
	return inner, stroke
end

local function getDuplicatesValue(): (number, number)
	local count, value = 0, 0
	for cardId, owned in collection do
		local card = Cards.ById[cardId]
		if card then
			local extraNormal = math.max(0, owned.normal - 1)
			local extraFoil = math.max(0, owned.foil - 1)
			count += extraNormal + extraFoil
			value += extraNormal * CardRules.getQuickSellValue(card, false)
				+ extraFoil * CardRules.getQuickSellValue(card, true)
		end
	end
	return count, value
end

local function refreshDetail()
	local card = detailCard
	if not card then
		return
	end
	local owned = getOwned(card.id)
	if owned.normal + owned.foil == 0 then
		detail.Visible = false
		detailCard = nil
		return
	end

	-- Show the foil version when the player has one, it's the one they'll want to look at
	CardFace.render(detailInner, detailStroke, card, owned.foil > 0)
	detailInfo.Text = string.format(
		"#%02d %s · %s %s\nYou own %d normal, %d foil",
		card.number,
		card.name,
		card.element,
		card.rarity,
		owned.normal,
		owned.foil
	)
	sellNormalButton.Visible = owned.normal > 0
	sellNormalButton.Text = string.format("Sell 1 · $%.2f", CardRules.getQuickSellValue(card, false))
	sellFoilButton.Visible = owned.foil > 0
	sellFoilButton.Text = string.format("Sell 1 foil · $%.2f", CardRules.getQuickSellValue(card, true))
end

local function refresh()
	local ownedKinds = 0
	for _, tile in tiles do
		local owned = getOwned(tile.card.id)
		local total = owned.normal + owned.foil
		if total > 0 then
			ownedKinds += 1
			CardFace.render(tile.inner, tile.stroke, tile.card, owned.foil > 0, false)
			tile.countLabel.Text = if owned.foil == 0
				then `x{owned.normal}`
				elseif owned.normal == 0 then `{owned.foil} foil`
				else `x{owned.normal} · {owned.foil} foil`
			tile.countLabel.Visible = true
		else
			CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
			tile.countLabel.Visible = false
		end
	end

	local percent = math.floor(ownedKinds / #Cards.List * 100)
	completionLabel.Text = `{ownedKinds}/{#Cards.List} cards · {percent}%`

	local dupes, dupesValue = getDuplicatesValue()
	dupesButton.Visible = dupes > 0
	dupesButton.Text = string.format("Sell %d dupe%s · $%.2f", dupes, if dupes == 1 then "" else "s", dupesValue)

	refreshDetail()
end

local function openDetail(card: Card)
	detailCard = card
	refreshDetail()
	detail.Visible = detailCard ~= nil
end

local function buildTile(card: Card, parent: Instance): Tile
	local button = Instance.new("TextButton")
	button.Name = card.id
	button.LayoutOrder = card.number
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = parent

	local inner, stroke = addCardFrame(button)

	local countLabel = UIKit.label(button, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(0.5, 1)
	countLabel.Position = UDim2.new(0.5, 0, 1, -3)
	countLabel.Size = UDim2.new(1, -6, 0, 18)
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.BackgroundColor3 = UIKit.Colors.Panel
	countLabel.BackgroundTransparency = 0.2
	countLabel.ZIndex = 3
	UIKit.corner(countLabel, 6)

	local tile: Tile = { card = card, inner = inner, stroke = stroke, countLabel = countLabel }
	button.Activated:Connect(function()
		local owned = getOwned(card.id)
		if owned.normal + owned.foil > 0 then
			openDetail(card)
		end
	end)
	return tile
end

-- Card shown large over the grid, with quick sell buttons
local function buildDetail(parent: Frame)
	detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.Size = UDim2.fromScale(1, 1)
	detail.BackgroundColor3 = UIKit.Colors.Panel
	detail.ZIndex = 10
	detail.Visible = false
	detail.Active = true
	detail.Parent = parent
	UIKit.corner(detail, 14)

	-- Card on the left, info and buttons on the right: fits short landscape phone screens
	local cardHolder = Instance.new("Frame")
	cardHolder.Position = UDim2.fromOffset(16, 16)
	cardHolder.Size = UDim2.fromOffset(150, 214)
	cardHolder.BackgroundTransparency = 1
	cardHolder.ZIndex = 11
	cardHolder.Parent = detail
	detailInner, detailStroke = addCardFrame(cardHolder)

	detailInfo = UIKit.label(detail, "", Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	detailInfo.Position = UDim2.fromOffset(180, 16)
	detailInfo.Size = UDim2.new(1, -192, 0, 60)
	detailInfo.ZIndex = 11

	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromOffset(180, 84)
	buttons.Size = UDim2.new(1, -192, 0, 170)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 11
	buttons.Parent = detail

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons

	local function makeButton(text: string, color: Color3, order: number): TextButton
		local button = UIKit.button(buttons, text, color)
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 48)
		button.TextSize = 16
		button.ZIndex = 12
		return button
	end

	sellNormalButton = makeButton("", UIKit.Colors.Accent, 1)
	sellNormalButton.Activated:Connect(function()
		if detailCard then
			Remotes.QuickSell:FireServer(detailCard.id, false)
		end
	end)

	sellFoilButton = makeButton("", UIKit.Colors.Accent, 2)
	sellFoilButton.Activated:Connect(function()
		if detailCard then
			Remotes.QuickSell:FireServer(detailCard.id, true)
		end
	end)

	local back = makeButton("Back", UIKit.Colors.Row, 3)
	back.Activated:Connect(function()
		detail.Visible = false
		detailCard = nil
	end)
end

local function buildPanel(parent: Instance)
	local list: ScrollingFrame
	panel, list = UIKit.panel(parent, "Binder", "Binder")

	-- Room for the completion line and Sell dupes above the grid
	list.Position = UDim2.fromOffset(12, 124)
	list.Size = UDim2.new(1, -24, 1, -136)
	local listLayout = list:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	completionLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
	completionLabel.Position = UDim2.fromOffset(16, 64)
	completionLabel.Size = UDim2.new(0.5, -16, 0, 48)

	dupesButton = UIKit.button(panel, "", UIKit.Colors.Accent)
	dupesButton.AnchorPoint = Vector2.new(1, 0)
	dupesButton.Position = UDim2.new(1, -12, 0, 64)
	dupesButton.Size = UDim2.new(0.5, -12, 0, 48)
	dupesButton.TextSize = 16
	dupesButton.Activated:Connect(function()
		Remotes.SellDuplicates:FireServer()
	end)

	for _, card in Cards.List do
		table.insert(tiles, buildTile(card, list))
	end

	buildDetail(panel)
end

local function onCollectionChanged(newCollection: { [string]: Owned })
	if typeof(newCollection) ~= "table" then
		return
	end
	collection = newCollection
	refresh()
end

local function toggle()
	detail.Visible = false
	detailCard = nil
	panel.Visible = not panel.Visible
end

local function buildButton(parent: Instance)
	local button = UIKit.button(parent, "Binder (B)", UIKit.Colors.Row)
	button.Name = "BinderButton"
	-- Above the Build button on the middle-left
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, -66)
	button.Size = UDim2.fromOffset(96, 56)
	button.TextSize = 17
	button.Activated:Connect(toggle)
end

function BinderController.Start()
	local screenGui = UIController.GetScreenGui()
	buildPanel(screenGui)
	buildButton(screenGui)
	refresh()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == BINDER_KEY then
			toggle()
		end
	end)

	Remotes.CollectionChanged.OnClientEvent:Connect(onCollectionChanged)
	Remotes.RequestCollection:FireServer()
end

return BinderController
