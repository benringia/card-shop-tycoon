--!strict
-- Build button and shelf shop menu, the Stock / Edit prompts on your own shelves, and the Move
-- prompt on your order computer. Prompts are created on this client only, so visitors never see them.
-- The server re-checks everything.
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

type ShelfDef = typeof(Shelves.List[1])

type ShopRow = {
	def: ShelfDef,
	button: TextButton,
}

type ShelfPrompts = {
	stock: ProximityPrompt,
	edit: ProximityPrompt,
}

local COMPUTER_PROMPT_OFFSET = 80 -- pixels below the computer's "Order stock" prompt

local player = Players.LocalPlayer

local BuildController = {}

local shopPanel: Frame
local shopRows: { ShopRow } = {}
local editPanel: Frame
local editTitle: TextLabel
local sellDetail: TextLabel
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
		local detail = string.format("Holds %d · $%.2f", def.capacity, def.cost)
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
	editingPart = part
	editTitle.Text = def.name
	sellDetail.Text = string.format("Get back $%.2f. Shelf must be empty.", getNumberAttribute(part, "Refund", 0))
	shopPanel.Visible = false
	editPanel.Visible = true
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

	local _, moveButton = UIKit.row(list, 1, "Move", "Pick a new spot. Stock stays on it.")
	moveButton.Text = "Move"
	moveButton.Activated:Connect(onMove)

	local _, sellButton, detail = UIKit.row(list, 2, "Sell", "")
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

-- Both prompts sit on the same part and would overlap, so only one shows at a time
local function applyPromptMode(prompts: ShelfPrompts)
	local carrying = getNumberAttribute(player, "CarryCount", 0) > 0
	prompts.stock.Enabled = carrying
	prompts.edit.Enabled = not carrying
end

local function refreshAllPrompts()
	for _, prompts in promptsByShelf do
		applyPromptMode(prompts)
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

	local stock = makePrompt(child, "Stock shelf", def.name, Enum.KeyCode.E)
	stock.Triggered:Connect(function()
		local uid = child:GetAttribute("ShelfUid")
		if typeof(uid) == "string" then
			Remotes.StockShelf:FireServer(uid)
		end
	end)

	local edit = makePrompt(child, "Edit", def.name, Enum.KeyCode.F)
	edit.GamepadKeyCode = Enum.KeyCode.ButtonY
	edit.Triggered:Connect(function()
		if not PlacementController.IsActive() then
			openEditPanel(child)
		end
	end)

	local prompts: ShelfPrompts = { stock = stock, edit = edit }
	promptsByShelf[child] = prompts
	applyPromptMode(prompts)
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
	button.Position = UDim2.new(0, 12, 0.5, 0)
	button.Size = UDim2.fromOffset(96, 56)
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
