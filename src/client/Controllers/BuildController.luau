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

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))

type ShelfDef = typeof(Shelves.List[1])

local CASE_BUYERS = {
	CustomerCards = "customers buy",
	PlayerCards = "players buy",
}

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
	for _, row in shopRows do
		local locked = isLocked(row.def)
		row.button.Text = if locked then `Lv {row.def.unlockLevel}` else "Buy"
		row.button.BackgroundColor3 = if locked then UIKit.Colors.Locked else UIKit.Colors.Accent
		row.button.AutoButtonColor = not locked
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
	PlacementController.Begin(def.size, { kind = "NewShelf", id = def.id })
end

local function buildShopPanel(parent: Instance)
	local list: ScrollingFrame
	shopPanel, list = UIKit.panel(parent, "BuildMenu", "Build")
	for index, def in Shelves.List do
		local detail = if def.kind == "Products"
			then string.format("Holds %d · $%.2f", def.capacity, def.cost)
			elseif def.kind == "Condenser" then string.format("Combine duplicates for stars · $%.2f", def.cost)
			else string.format("%d cards, %s · $%.2f", def.capacity, CASE_BUYERS[def.kind], def.cost)
		local frame, button = UIKit.row(list, index, def.name, detail)
		frame.Name = def.id
		button.Activated:Connect(function()
			onBuy(def)
		end)
		table.insert(shopRows, { def = def, button = button })
	end
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

local function buildButton(parent: Instance)
	local button = UIKit.button(parent, "Build", UIKit.Colors.Accent)
	button.Name = "BuildButton"
	-- Middle-left keeps clear of the mobile thumbstick (bottom-left) and jump button (bottom-right)
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, 28)
	button.Size = UDim2.fromOffset(96, 50)
	button.Activated:Connect(function()
		if PlacementController.IsActive() then
			return
		end
		editPanel.Visible = false
		refreshShopRows()
		shopPanel.Visible = not shopPanel.Visible
	end)
end

function BuildController.Start()
	local screenGui = UIController.GetScreenGui()
	buildShopPanel(screenGui)
	buildEditPanel(screenGui)
	buildButton(screenGui)

	player:GetAttributeChangedSignal("Level"):Connect(refreshShopRows)
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	player:GetAttributeChangedSignal("CarryCount"):Connect(refreshAllPrompts)
	task.spawn(watchOwnPlot)
end

return BuildController
