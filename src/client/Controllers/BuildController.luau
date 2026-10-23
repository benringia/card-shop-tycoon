--!strict
-- Build button and shelf shop menu, the Stock / Edit prompts on your own shelves (card cases get a
-- Cards option instead of stocking; the Card Condenser gets a Condense prompt), and the Move prompt
-- on your order computer. Prompts are created
-- on this client only, so visitors never see them. The server re-checks everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Shelves = require(Config:WaitForChild("Shelves"))
local StockConfig = require(Config:WaitForChild("Stock"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))

type ShelfDef = typeof(Shelves.List[1])

local CASE_BUYERS = {
	CustomerCards = "customers buy",
	PlayerCards = "players buy",
}

-- Build menu tabs (Config/Shelves `category`); Decor has nothing yet and says so
local BUILD_TABS = {
	{ name = "Shelves", icon = "🗄️" },
	{ name = "Cases", icon = "💎" },
	{ name = "Fixtures", icon = "⚙️" },
	{ name = "Decor", icon = "🌱" },
}
local BUILD_TILE = { WIDTH = 160, HEIGHT = 224, PICTURE = 110, PICTURE_COLOR = Color3.fromRGB(255, 226, 180) }

type ShopRow = {
	def: ShelfDef,
	button: TextButton,
}

type ShelfPrompts = {
	stock: ProximityPrompt,
	edit: ProximityPrompt,
}

local COMPUTER_PROMPT_OFFSET = 80 -- pixels below the computer's "Order stock" prompt
local CONDENSER_EDIT_OFFSET = 80 -- the Condenser shows Condense and Edit together, so Edit sits below

local player = Players.LocalPlayer

local BuildController = {}

local shopPanel: Frame
local shopRows: { ShopRow } = {}
local editPanel: Frame
local editTitle: TextLabel
local sellDetail: TextLabel
local cardsRow: Frame
local removeStockRow: Frame
local condenseRow: Frame
local moveDetail: TextLabel
local editingPart: BasePart? = nil
local shelvesConnection: RBXScriptConnection? = nil
local computerPrompt: ProximityPrompt? = nil
local promptsByShelf: { [BasePart]: ShelfPrompts } = {}

local function getNumberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function isLocked(def: ShelfDef): boolean
	return getNumberAttribute(player, "Level", 1) < def.unlockLevel
end

local function refreshShopRows()
	local cash = getNumberAttribute(player, "Cash", 0)
	for _, row in shopRows do
		local locked = isLocked(row.def)
		local short = not locked and cash < row.def.cost
		row.button.Text = if locked then `🔒 Lv {row.def.unlockLevel}` else string.format("$%d", row.def.cost)
		row.button.BackgroundColor3 = if locked then UIKit.Colors.Locked else UIKit.Colors.Row
		row.button.TextColor3 = if locked then Color3.new(1, 1, 1) elseif short then UIKit.Colors.Danger else UIKit.Colors.Success
	end
end

local function onBuy(def: ShelfDef)
	if isLocked(def) then
		UIController.Notify(`Unlocks at shop level {def.unlockLevel}.`, true)
		return
	end
	if getNumberAttribute(player, "Cash", 0) < def.cost then
		UIController.Notify("Not enough cash.", true)
		return
	end
	shopPanel.Visible = false
	PlacementController.Begin(def.size, {
		kind = "NewShelf",
		id = def.id,
		prop = def.prop,
		propColors = def.propColors,
		title = `{def.name} · ${def.cost}`,
	})
end

-- A 3D picture of the shelf: its prop model (or the code stand-in) in a ViewportFrame, framed on its bounds
local function addPreview(parent: GuiObject, def: ShelfDef)
	local view = Instance.new("ViewportFrame")
	view.Name = "Preview"
	view.Position = UDim2.fromOffset(8, 8)
	view.Size = UDim2.new(1, -16, 0, BUILD_TILE.PICTURE)
	view.BackgroundColor3 = BUILD_TILE.PICTURE_COLOR
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	UIKit.corner(view, 10)
	local world = Instance.new("WorldModel")
	world.Parent = view

	local model: Model
	if def.prop then
		model = Props.fit(def.prop, def.size, CFrame.new(), world)
		if def.propColors then
			for partName, color in def.propColors do
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and part.Name == partName then
						part.Color = color
					end
				end
			end
		end
	else
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Anchored = true
		block.Size = def.size
		block.Color = def.color
		block.CFrame = CFrame.new(0, def.size.Y / 2, 0)
		block.Parent = model
		model.Parent = world
	end
	local centre, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	-- Three-quarter view from the front (-Z) and a little above
	local eye = centre.Position + Vector3.new(reach * 0.9, reach * 0.7, -reach * 1.5)
	camera.CFrame = CFrame.lookAt(eye, centre.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

local function buildTile(parent: Instance, order: number, def: ShelfDef)
	local tile = Instance.new("Frame")
	tile.Name = def.id
	tile.LayoutOrder = order
	tile.BackgroundColor3 = UIKit.Colors.Row
	tile.Parent = parent
	UIKit.corner(tile, 14)
	UIKit.outline(tile)
	addPreview(tile, def)
	local name = UIKit.label(tile, def.name, Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
	name.Position = UDim2.fromOffset(10, BUILD_TILE.PICTURE + 12)
	name.Size = UDim2.new(1, -20, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	local detail = if def.kind == "Products"
		then `Holds {def.capacity}`
		elseif def.kind == "Condenser" then "Duplicates to stars"
		else `{def.capacity} cards, {CASE_BUYERS[def.kind]}`
	local info = UIKit.label(tile, detail, Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	info.Position = UDim2.fromOffset(10, BUILD_TILE.PICTURE + 34)
	info.Size = UDim2.new(1, -20, 0, 18)
	local button = UIKit.button(tile, "", UIKit.Colors.Row)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -8)
	button.Size = UDim2.new(1, -16, 0, 48)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 20
	button.Activated:Connect(function()
		onBuy(def)
	end)
	table.insert(shopRows, { def = def, button = button })
end

-- The Build panel: category tabs and a grid of tiles, each with a 3D picture of the model
local function buildShopPanel(parent: Instance)
	local list: ScrollingFrame
	shopPanel, list = UIKit.panel(parent, "BuildMenu", "🔨 Build")
	shopPanel.Size = UDim2.fromScale(0.9, 0.85)
	local limit = shopPanel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(720, 560)
	end

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + 10)
	tabs.Size = UDim2.new(1, -24, 0, 48)
	tabs.BackgroundTransparency = 1
	tabs.Parent = shopPanel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	list.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + 68)
	list.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + 78))
	local oldLayout = list:FindFirstChildOfClass("UIListLayout")
	if oldLayout then
		oldLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(BUILD_TILE.WIDTH, BUILD_TILE.HEIGHT)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local soon = UIKit.label(list, "Decor is coming soon!", Enum.Font.FredokaOne, 22, UIKit.Colors.Text)
	soon.Name = "ComingSoon"
	soon.Visible = false

	local tabButtons: { [string]: TextButton } = {}
	local function showCategory(category: string)
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == category then UIKit.Colors.Accent else UIKit.Colors.Row
		end
		local any = false
		for _, row in shopRows do
			local tile = row.button.Parent :: GuiObject
			tile.Visible = row.def.category == category
			any = any or tile.Visible
		end
		soon.Visible = not any
		list.CanvasPosition = Vector2.zero
	end
	for index, tab in BUILD_TABS do
		local button = UIKit.button(tabs, `{tab.icon} {tab.name}`, UIKit.Colors.Row)
		button.Name = "Tab" .. tab.name
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #BUILD_TABS, -8, 1, 0)
		button.TextSize = 17
		button.Activated:Connect(function()
			showCategory(tab.name)
		end)
		tabButtons[tab.name] = button
	end

	for index, def in Shelves.List do
		buildTile(list, index, def)
	end
	showCategory(BUILD_TABS[1].name)
	player:GetAttributeChangedSignal("Cash"):Connect(refreshShopRows)
end

local function openEditPanel(part: BasePart)
	local def = Shelves.ById[part.Name]
	if not def then
		return
	end
	local isCase = def.kind == "CustomerCards" or def.kind == "PlayerCards"
	editingPart = part
	editTitle.Text = def.name
	cardsRow.Visible = isCase
	condenseRow.Visible = def.kind == "Condenser"
	removeStockRow.Visible = def.kind == "Products"
	moveDetail.Text = if isCase
		then "Pick a new spot. Cards stay in it."
		elseif def.kind == "Condenser" then "Pick a new spot."
		else "Pick a new spot. Stock stays on it."
	sellDetail.Text = string.format("Get back $%.2f. Must be empty.", getNumberAttribute(part, "Refund", 0))
	shopPanel.Visible = false
	editPanel.Visible = true
end

local function onCards()
	local part = editingPart
	editPanel.Visible = false
	if part then
		ShowcaseController.Open(part)
	end
end

local function onCondense()
	local part = editingPart
	editPanel.Visible = false
	if part then
		CondenserController.Open(part)
	end
end

local function onRemoveStock()
	local part = editingPart
	local uid = part and part:GetAttribute("ShelfUid")
	editPanel.Visible = false
	if typeof(uid) == "string" then
		Remotes.RemoveStock:FireServer(uid)
	end
end

local function onMove()
	local part = editingPart
	local def = part and Shelves.ById[part.Name]
	local uid = part and part:GetAttribute("ShelfUid")
	editPanel.Visible = false
	if not part or not def or typeof(uid) ~= "string" then
		return
	end
	PlacementController.Begin(def.size, {
		kind = "MoveShelf",
		id = uid,
		prop = def.prop,
		propColors = def.propColors,
		title = `Move {def.name}`,
		rotation = getNumberAttribute(part, "Rotation", 0),
		gridX = getNumberAttribute(part, "GridX", 0),
		gridZ = getNumberAttribute(part, "GridZ", 0),
	})
end

local function onSell()
	local part = editingPart
	local uid = part and part:GetAttribute("ShelfUid")
	editPanel.Visible = false
	if typeof(uid) == "string" then
		Remotes.SellShelf:FireServer(uid)
	end
end

local function buildEditPanel(parent: Instance)
	local list: ScrollingFrame
	editPanel, list = UIKit.panel(parent, "ShelfMenu", "Shelf")
	editTitle = editPanel:FindFirstChild("Title") :: TextLabel

	local cardsButton: TextButton
	cardsRow, cardsButton = UIKit.row(list, 1, "Cards", "Put cards on display and set prices.")
	cardsButton.Text = "Cards"
	cardsButton.Activated:Connect(onCards)

	local condenseButton: TextButton
	condenseRow, condenseButton = UIKit.row(list, 2, "Condense", "Combine duplicates for +1 star.")
	condenseButton.Text = "Open"
	condenseButton.Activated:Connect(onCondense)

	local removeStockButton: TextButton
	removeStockRow, removeStockButton = UIKit.row(list, 3, "Remove stock", "Box it up onto the delivery pad.")
	removeStockButton.Text = "Remove"
	removeStockButton.Activated:Connect(onRemoveStock)

	local _, moveButton, moveLabel = UIKit.row(list, 4, "Move", "")
	moveDetail = moveLabel
	moveButton.Text = "Move"
	moveButton.Activated:Connect(onMove)

	local _, sellButton, detail = UIKit.row(list, 5, "Sell", "")
	sellDetail = detail
	sellButton.Text = "Sell"
	sellButton.BackgroundColor3 = UIKit.Colors.Danger
	sellButton.Activated:Connect(onSell)
end

local function makePrompt(part: BasePart, actionText: string, objectText: string, key: Enum.KeyCode): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = StockConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

-- Both prompts sit on the same part and would overlap, so only one shows at a time.
-- Card cases never take stock, so they always show Edit.
local function applyPromptMode(part: BasePart, prompts: ShelfPrompts)
	local def = Shelves.ById[part.Name]
	if def and def.kind == "Condenser" then
		-- Condense (E) and Edit (F) both show; Edit is offset so they don't overlap
		prompts.stock.Enabled = true
		prompts.edit.Enabled = true
		return
	end
	local takesStock = def ~= nil and def.kind == "Products"
	local carrying = getNumberAttribute(player, "CarryCount", 0) > 0
	prompts.stock.Enabled = takesStock and carrying
	prompts.edit.Enabled = not (takesStock and carrying)
end

local function refreshAllPrompts()
	for part, prompts in promptsByShelf do
		applyPromptMode(part, prompts)
	end
end

local function addShelfPrompts(child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local def = Shelves.ById[child.Name]
	if not def then
		return
	end

	local isCondenser = def.kind == "Condenser"
	-- E: stock a product shelf, or open the Condenser
	local stock = makePrompt(child, if isCondenser then "Condense" else "Stock shelf", def.name, Enum.KeyCode.E)
	stock.Triggered:Connect(function()
		if isCondenser then
			if not PlacementController.IsActive() then
				CondenserController.Open(child)
			end
			return
		end
		local uid = child:GetAttribute("ShelfUid")
		if typeof(uid) == "string" then
			Remotes.StockShelf:FireServer(uid)
		end
	end)

	local edit = makePrompt(child, "Edit", def.name, Enum.KeyCode.F)
	edit.GamepadKeyCode = Enum.KeyCode.ButtonY
	if isCondenser then
		edit.UIOffset = Vector2.new(0, CONDENSER_EDIT_OFFSET)
	end
	edit.Triggered:Connect(function()
		if not PlacementController.IsActive() then
			openEditPanel(child)
		end
	end)

	local prompts: ShelfPrompts = { stock = stock, edit = edit }
	promptsByShelf[child] = prompts
	applyPromptMode(child, prompts)
	child.Destroying:Connect(function()
		promptsByShelf[child] = nil
	end)
end

-- Move prompt on the owner's order computer. It sits below the server's "Order stock" prompt
-- on the same part, so it's offset to avoid the two drawing on top of each other.
local function addComputerPrompt(computer: BasePart)
	if computerPrompt then
		computerPrompt:Destroy()
	end
	local prompt = makePrompt(computer, "Move", "Computer", Enum.KeyCode.F)
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.UIOffset = Vector2.new(0, COMPUTER_PROMPT_OFFSET)
	prompt.Triggered:Connect(function()
		local fixtureId = computer:GetAttribute("FixtureId")
		if PlacementController.IsActive() or typeof(fixtureId) ~= "string" then
			return
		end
		PlacementController.Begin(computer.Size, {
			kind = "MoveFixture",
			id = fixtureId,
			prop = "Computer",
			title = "Move Order Stock",
			rotation = getNumberAttribute(computer, "Rotation", 0),
			gridX = getNumberAttribute(computer, "GridX", 0),
			gridZ = getNumberAttribute(computer, "GridZ", 0),
		})
	end)
	computerPrompt = prompt
end

-- Adds prompts to every shelf on the player's own plot (including ones placed later) and its computer
local function watchOwnPlot()
	if shelvesConnection then
		shelvesConnection:Disconnect()
		shelvesConnection = nil
	end
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return
	end
	local plot = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotId)
	addComputerPrompt(plot:WaitForChild("OrderComputer") :: BasePart)
	local shelvesFolder = plot:WaitForChild("Shelves")

	shelvesConnection = shelvesFolder.ChildAdded:Connect(addShelfPrompts)
	for _, child in shelvesFolder:GetChildren() do
		addShelfPrompts(child)
	end
end

local function buildButton()
	Hud.fanButton({
		id = "Build",
		icon = "Build",
		label = "Build",
		order = 1,
		onClick = function()
			if PlacementController.IsActive() then
				return
			end
			editPanel.Visible = false
			refreshShopRows()
			shopPanel.Visible = not shopPanel.Visible
		end,
	})
end

function BuildController.Start()
	local screenGui = UIController.GetScreenGui()
	buildShopPanel(screenGui)
	buildEditPanel(screenGui)
	buildButton()

	player:GetAttributeChangedSignal("Level"):Connect(refreshShopRows)
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	player:GetAttributeChangedSignal("CarryCount"):Connect(refreshAllPrompts)
	task.spawn(watchOwnPlot)
end

return BuildController
