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
local ShopTiles = require(Config:WaitForChild("ShopTiles"))
local Bulk = require(Config:WaitForChild("Bulk"))
local Products = require(Config:WaitForChild("Products"))
local Offline = require(Config:WaitForChild("Offline"))
local ShopTips = require(Shared:WaitForChild("Util"):WaitForChild("ShopTips"))
local ShopTileRules = require(Shared:WaitForChild("Util"):WaitForChild("ShopTileRules"))
local StockConfig = require(Config:WaitForChild("Stock"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))
local EditBarConfig = require(Config:WaitForChild("EditBar"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local EditBarRules = require(Shared:WaitForChild("Util"):WaitForChild("EditBarRules"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local LookTiles = require(ClientUtil:WaitForChild("LookTiles"))
local ShopTile = require(ClientUtil:WaitForChild("ShopTile"))
local WindowController = require(Controllers:WaitForChild("WindowController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))
local ForgeController = require(Controllers:WaitForChild("ForgeController"))
local GradingController = require(Controllers:WaitForChild("GradingController"))
local EditBarController = require(Controllers:WaitForChild("EditBarController"))

type ShelfDef = typeof(Shelves.List[1])

-- A machine's part name -> its station (Util/StationJobs), for its Edit bar's chip
local MACHINE_STATIONS: { [string]: string } = { Condenser = "condenser", GradingStation = "grading", Forge = "forge", Recycler = "recycler" }

local CASE_BUYERS = {
	CustomerCards = "Customers buy",
	PlayerCards = "Players buy",
}

-- Build menu tabs (Config/Shelves `category`); Decor also lists the shop looks first (Util/LookTiles). Trophies aren't
-- here: each is placed from the Bag (its Place button, BuildController.PlaceTrophy; owner 2026-11-17)
local BUILD_TABS = {
	{ name = "Shelves", icon = "Shelves" },
	{ name = "Cases", icon = "Cases" },
	{ name = "Fixtures", icon = "Fixtures" },
	{ name = "Decor", icon = "Decor" },
}
local BUILD_TILE = { PICTURE = ShopTiles.FULL.picture } -- the tile's size and its phone form: Config/ShopTiles

type ShopRow = {
	def: ShelfDef,
	button: TextButton,
}

type ShelfPrompts = {
	stock: ProximityPrompt,
	edit: ProximityPrompt,
}

local COMPUTER_PROMPT_OFFSET = 80 -- pixels below the computer's "Order stock" prompt
local CONDENSER_EDIT_OFFSET = 80 -- machines show their use prompt and Edit together, so Edit sits below
local REGISTER_PROMPT_OFFSET = 80 -- the register's Move sits below "Man the register" (its unit's prompt, on the counter)

local player = Players.LocalPlayer

local BuildController = {}

local shopPanel: Frame
local palette: UIKit.Palette -- the cream windows' colours (UIKit.colorsFor), set when the Shop is built
local shopRows: { ShopRow } = {}
local shelvesConnection: RBXScriptConnection? = nil
local computerPrompt: ProximityPrompt? = nil
local registerPrompt: ProximityPrompt? = nil
local promptsByShelf: { [BasePart]: ShelfPrompts } = {}
local items: { [string]: number } = {} -- the bag (ItemsChanged): trophies are placed from it (PlaceTrophy)

local function getNumberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- Achievement decor (spec 2026-11-14-shop-windows-design): unlocked when WindowService's DecorAchieved names it
local function needsAchievement(def: ShelfDef): boolean
	if not def.needs then
		return false
	end
	local keys = player:GetAttribute("DecorAchieved")
	return not (typeof(keys) == "string" and table.find(string.split(keys, ","), `shelf:{def.id}`) ~= nil)
end

local function isLocked(def: ShelfDef): boolean
	return getNumberAttribute(player, "Level", 1) < def.unlockLevel or needsAchievement(def)
end

-- "Meadow Warden Trophy" -> "Meadow Warden"
local function trophyBoss(def: ShelfDef): string
	return (string.gsub(def.name, " Trophy$", ""))
end

local function refreshShopRows()
	local cash = getNumberAttribute(player, "Cash", 0)
	for _, row in shopRows do
		local locked = isLocked(row.def)
		local short = not locked and cash < row.def.cost
		local achievement = needsAchievement(row.def)
		row.button.Text = if achievement then `🔒 {row.def.how}` elseif locked then `🔒 Lv {row.def.unlockLevel}` else string.format("$%d", row.def.cost)
		row.button.TextSize = if achievement then 14 else 20
		-- Soft buttons (UIKit): mint when you can buy it, pink when you're short, grey-lilac while locked
		row.button.BackgroundColor3 = if locked then UIKit.Colors.Locked elseif short then UIKit.Colors.Danger else UIKit.Colors.Success
		-- just unlocked: a NEW tag (Pish no longer visits for every unlock, owner 2026-11-19)
		local isNew = not locked and not achievement and ShopTileRules.isNew(getNumberAttribute(player, "Level", 1), row.def.unlockLevel)
		require(ClientUtil:WaitForChild("NewTag")).set(row.button.Parent, isNew)
	end
end

local function onBuy(def: ShelfDef)
	if def.requiresItem and (items[def.requiresItem] or 0) < 1 then
		UIController.Notify(`Beat the {trophyBoss(def)} to earn this trophy.`, true)
		return
	end
	if needsAchievement(def) then
		UIController.Notify(`{def.name}: {def.how}.`, true)
		return
	end
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
		title = if def.requiresItem then def.name else `{def.name} · ${def.cost}`,
	})
end

-- A 3D picture of the shelf: its prop model (or the code stand-in) in a ViewportFrame, framed on its bounds
local function addPreview(parent: GuiObject, def: ShelfDef)
	local view = Instance.new("ViewportFrame")
	view.Name = "Preview"
	view.Position = UDim2.fromOffset(8, 8)
	view.Size = UDim2.new(1, -16, 0, BUILD_TILE.PICTURE)
	view.BackgroundColor3 = palette.slotEmpty -- a soft cream stage for the 3D picture
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

-- The words for the stock a shelf takes (Config/Offline PLURALS: "packs", "sleeves"), nil for any; and every stock's
local function stockWords(ids: { string }?): { string }?
	if not ids then
		return nil
	end
	local words = {}
	for _, id in ids do
		local product = Products.ById[id]
		if product and not product.bulk then
			table.insert(words, Offline.PLURALS[id] or product.name)
		end
	end
	return words
end

local function allStockIds(): { string }
	local ids = {}
	for _, product in Products.List do
		table.insert(ids, product.id)
	end
	return ids
end

-- What it holds and what it does, on hover or a held finger (owner 2026-11-17: "add tooltips to the items in shop")
local function addTip(tile: GuiObject, def: ShelfDef)
	local item = { kind = def.kind, capacity = def.capacity, accepts = stockWords(def.accepts), bulk = def.id == Bulk.SHELF, decor = def.decor }
	Tooltip.rich(tile, def.name, ShopTips.lines(item, stockWords(allStockIds()) or {}))
end

local function buildTile(parent: Instance, order: number, def: ShelfDef)
	local tile = Instance.new("Frame")
	tile.Name = def.id
	tile.LayoutOrder = order
	tile.BackgroundColor3 = palette.row
	tile.Parent = parent
	UIKit.corner(tile, 14)
	UIKit.outline(tile)
	addTip(tile, def)
	addPreview(tile, def)
	local name = UIKit.label(tile, def.name, Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
	name.Position = UDim2.fromOffset(10, BUILD_TILE.PICTURE + 12)
	name.Size = UDim2.new(1, -20, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	-- The line under the name, " · " between its chips (Util/ShopTile.dress): what it holds, then what it takes
	local takes = stockWords(def.accepts)
	local takesWords = if takes then table.concat(takes, ", ") else "any stock"
	local detail = if def.kind == "Products" and def.id == Bulk.SHELF
		then `Holds {def.capacity * Bulk.PER} cards · Extra Commons`
		elseif def.kind == "Products" then `Holds {def.capacity} · {string.upper(string.sub(takesWords, 1, 1))}{string.sub(takesWords, 2)}`
		elseif def.kind == "Condenser" then "Duplicates to stars"
		elseif def.kind == "Grading" then "Duplicates to grades"
		elseif def.kind == "Forge" then "Make and upgrade weapons"
		elseif def.kind == "Recycler" then "Extra cards to materials"
		elseif def.kind == "Storage" then `Holds {def.capacity} boxes`
		elseif def.kind == "Decor" then `Decor +{def.decor or 0}`
		else `{def.capacity} cards · {CASE_BUYERS[def.kind]}`
	local info = UIKit.label(tile, detail, Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	info.Position = UDim2.fromOffset(10, BUILD_TILE.PICTURE + 34)
	info.Size = UDim2.new(1, -20, 0, 18)
	local button = UIKit.button(tile, "", UIKit.Colors.Success)
	button.Name = "Buy" -- Pish's paw finds it here (TutorialController: the rack step and his shop lessons)
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
	shopPanel, list = UIKit.panel(parent, "BuildMenu", "Shop", "Shop")
	palette = UIKit.colorsFor(shopPanel)
	Icon.header(shopPanel, "Shop", UIKit.HEADER_HEIGHT)
	ShopTile.cashChip(shopPanel, UIKit.HEADER_HEIGHT) -- what you have to spend, by the close button
	local window = ShopTiles.WINDOW
	local limit = shopPanel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(720, 560)
	end

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Parent = shopPanel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local oldLayout = list:FindFirstChildOfClass("UIListLayout")
	if oldLayout then
		oldLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	-- A phone (Config/ShopTiles; pre-launch QA 2026-11-19): a taller window, slimmer tabs and row tiles, so a picture
	-- and its price show together in the short list; a computer the three-tile grid (Shop A). Decided as the window
	-- opens and whenever the screen changes size (owner 2026-11-23: built once at start, a computer whose game window
	-- began short kept the phone's rows)
	local compacted: boolean? = nil
	local function fit()
		local phone = UIKit.isPhone()
		if phone == compacted then
			return
		end
		compacted = phone
		shopPanel.Size = UDim2.fromScale(if phone then 0.96 else 0.9, if phone then window.phoneHeight else window.height)
		tabs.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + (if phone then 6 else 10))
		tabs.Size = UDim2.new(1, -24, 0, if phone then window.phoneTabs else window.tabs)
		local chrome = if phone then window.phoneChrome else window.chrome
		local under = if phone then 8 else 10 -- the margin under the list
		list.Position = UDim2.fromOffset(12, chrome - under)
		list.Size = UDim2.new(1, -24, 1, -chrome)
		grid.CellSize, grid.CellPadding = ShopTile.cell(phone)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				if phone then
					ShopTile.compact(child)
				else
					ShopTile.expand(child)
				end
			end
		end
	end

	local lookTiles: { GuiObject } = {}
	local windowTiles: { GuiObject } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function showCategory(category: string)
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == category then UIKit.Colors.Accent else palette.row
			local label = button:FindFirstChild("Name", true) :: TextLabel?
			if label then
				UIKit.softText(label, button.BackgroundColor3) -- plum on the open tab's butter, white on the others' sky
			end
		end
		for _, row in shopRows do
			local tile = row.button.Parent :: GuiObject
			tile.Visible = row.def.category == category
		end
		for _, tile in lookTiles do
			-- a look tile can keep itself out (LookTiles: Sunny Shop where Roblox restricts paid random items)
			tile.Visible = category == "Decor" and tile:GetAttribute("Hidden") ~= true
		end
		for _, tile in windowTiles do
			tile.Visible = category == "Decor"
		end
		list.CanvasPosition = Vector2.zero
	end
	for index, tab in BUILD_TABS do
		local button = UIKit.button(tabs, "", palette.row)
		button.Name = "Tab" .. tab.name
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #BUILD_TABS, -8, 1, 0)
		-- The icon and the name side by side, centred on the tab
		local row = Instance.new("Frame")
		row.Name = "Content"
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.45)
		row.Size = UDim2.fromScale(0, 1)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.BackgroundTransparency = 1
		row.ZIndex = button.ZIndex + 1
		row.Parent = button
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		local tabIcon = Icon.make(row, tab.icon, UDim2.fromOffset(28, 28))
		tabIcon.LayoutOrder = 1
		tabIcon.ZIndex = row.ZIndex
		local name = UIKit.label(row, tab.name, Enum.Font.FredokaOne, 17, UIStyle.BABY_INK)
		name.Name = "Name"
		name.LayoutOrder = 2
		name.Size = UDim2.fromScale(0, 1)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.TextWrapped = false
		name.ZIndex = row.ZIndex
		button.Activated:Connect(function()
			showCategory(tab.name)
		end)
		tabButtons[tab.name] = button
	end

	lookTiles = LookTiles.build(list, palette)
	-- the windows after the looks, before the pieces (shop windows, spec 2026-11-14-shop-windows-design)
	windowTiles = WindowController.Tiles(list, palette, 50, function()
		shopPanel.Visible = false
	end)
	for index, def in Shelves.List do
		if not def.requiresItem then -- trophies come from the Bag, not here
			buildTile(list, 100 + index, def) -- after the six shop looks
		end
	end
	-- every tile (looks, windows, shelves: the same build) in the catalog look, then laid out for this screen
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			ShopTile.dress(child)
		end
	end
	ShopTile.trackOwned(list) -- "You have N" on each shelf's tile
	fit()
	shopPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if shopPanel.Visible then
			fit()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	showCategory(BUILD_TABS[1].name)
	player:GetAttributeChangedSignal("Cash"):Connect(refreshShopRows)
	player:GetAttributeChangedSignal("DecorAchieved"):Connect(refreshShopRows)
end

-- A machine's own window (its E prompt, and Use on its Edit bar)
local function openMachine(part: BasePart)
	local def = Shelves.ById[part.Name]
	if not def or PlacementController.IsActive() then
		return
	end
	if def.kind == "Condenser" then
		CondenserController.Open(part)
	elseif def.kind == "Grading" then
		GradingController.Open(part)
	elseif def.kind == "Forge" then
		ForgeController.Open(part)
	elseif def.kind == "Recycler" then
		-- (required here: this file's top level is near Luau's 200 locals)
		local RecyclerController = require(Controllers:WaitForChild("RecyclerController")) :: any
		RecyclerController.Open(part)
	elseif def.kind == "Storage" then
		-- a storage rack's stock clipboard (spec 2026-11-24-storage-racks-design)
		local StorageController = require(Controllers:WaitForChild("StorageController")) :: any
		StorageController.Open(part)
	end
end

local function moveShelf(part: BasePart)
	local def = Shelves.ById[part.Name]
	local uid = part:GetAttribute("ShelfUid")
	if not def or typeof(uid) ~= "string" then
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

-- A machine's job for its Edit bar's chip: running (its time left) or finished and waiting (Util/StationJobs, the
-- stations' "Ready!" attributes); nil for anything that isn't a machine
local function machineJob(name: string): EditBarRules.Machine?
	local station = MACHINE_STATIONS[name]
	if not station then
		return nil
	end
	local StationJobs = require(ClientUtil:WaitForChild("StationJobs")) :: any
	local job = StationJobs.get(station)
	if job then
		return { working = job.left }
	end
	local attribute = Upgrades.READY_ATTRIBUTES[station]
	return { done = attribute ~= nil and UpgradeRules.showsReady(false, player:GetAttribute(attribute)) }
end

-- What a placed shelf, case, machine, trophy or decor piece is now, for its Edit bar (Util/EditBarRules); nil once gone
local function describeShelf(part: BasePart): EditBarRules.Thing?
	local def = Shelves.ById[part.Name]
	if not def or not part:IsDescendantOf(workspace) then
		return nil
	end
	local cards = 0
	for _, child in part:GetChildren() do
		if child:GetAttribute("CardId") ~= nil then
			cards += 1
		end
	end
	local productId = part:GetAttribute("ProductId")
	local product = if typeof(productId) == "string" then Products.ById[productId] else nil
	return {
		kind = if def.id == Bulk.SHELF then "Bin" else def.kind :: any,
		name = def.name,
		capacity = def.capacity,
		-- a storage rack's boxes (PlacementService's StoredCount), a shelf's stock
		units = getNumberAttribute(part, if def.kind == "Storage" then "StoredCount" else "Units", 0),
		product = if product then product.name else nil,
		cards = cards,
		refund = getNumberAttribute(part, "Refund", 0),
		decor = def.decor,
		machine = machineJob(part.Name),
	}
end

-- Edit on a placed thing: its Edit bar (EditBarController, owner 2026-11-23 mockup C) with its own use, Move and Sell
local function openEdit(part: BasePart)
	local def = Shelves.ById[part.Name]
	if not def then
		return
	end
	local function send(remote: RemoteEvent)
		local uid = part:GetAttribute("ShelfUid")
		if typeof(uid) == "string" then
			remote:FireServer(uid)
		end
	end
	EditBarController.Open({
		target = part:FindFirstChildOfClass("Model") or part, -- the prop drawn on the invisible hitbox part
		at = part,
		describe = function()
			return describeShelf(part)
		end,
		icons = { use = (EditBarConfig.ICONS.use :: any)[def.kind] },
		actions = {
			use = function()
				openMachine(part)
			end,
			cards = function()
				ShowcaseController.Open(part)
			end,
			unstock = function()
				send(Remotes.RemoveStock)
			end,
			move = function()
				moveShelf(part)
			end,
			sell = function()
				send(Remotes.SellShelf)
			end,
			bag = function()
				send(Remotes.SellShelf) -- a trophy goes back to the Bag (PlacementService: requiresItem)
			end,
		},
	})
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
	if def and def.kind == "Storage" then
		-- a storage rack (spec 2026-11-24-storage-racks-design): E stores the box in your hands, else opens its stock
		-- clipboard, its words said before you press (a full rack too); Edit (F) beside it. Required here: this file's top
		-- level is near Luau's 200 locals
		local StorageRules = require(Shared:WaitForChild("Util"):WaitForChild("StorageRules")) :: any
		local StorageConfig = require(Config:WaitForChild("Storage")) :: any
		local productId = player:GetAttribute("CarryProductId")
		local carried = if getNumberAttribute(player, "CarryCount", 0) > 0 and typeof(productId) == "string" then Products.ById[productId] else nil
		local action, object = StorageRules.prompt(getNumberAttribute(part, "StoredCount", 0), def.capacity, if carried then carried.name else nil, StorageConfig.WORDS)
		prompts.stock.ActionText = action
		prompts.stock.ObjectText = object
		prompts.stock.Enabled = true
		prompts.edit.Enabled = true
		return
	end
	if def and (def.kind == "Condenser" or def.kind == "Grading" or def.kind == "Forge" or def.kind == "Recycler" or def.id == Bulk.SHELF) then
		-- A machine's (or a Bulk Bin's) use prompt (E) and Edit (F) both show; Edit is offset so they don't overlap
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
	-- once per shelf: the folder's first scan and its ChildAdded (deferred) can both bring the same shelf, which drew
	-- every shelf's prompts twice, one on the other, each press firing both (found 2026-11-17)
	if promptsByShelf[child] then
		return
	end
	local def = Shelves.ById[child.Name]
	if not def then
		return
	end

	local isCondenser = def.kind == "Condenser"
	local isGrading = def.kind == "Grading"
	local isForge = def.kind == "Forge"
	local isBin = def.id == Bulk.SHELF
	local isRecycler = def.kind == "Recycler"
	local isRack = def.kind == "Storage"
	-- E: stock a product shelf, open a machine's window, put your extra Commons in a Bulk Bin, or store a box on a rack
	-- (a rack's words follow what you carry: applyPromptMode)
	local action = if isCondenser then "Condense" elseif isGrading then "Grade" elseif isForge then "Forge" elseif isRecycler then "Recycle" elseif isBin then "Add extras" else "Stock shelf"
	local stock = makePrompt(child, action, def.name, Enum.KeyCode.E)
	stock.Triggered:Connect(function()
		if isRack then
			local rackUid = child:GetAttribute("ShelfUid")
			if typeof(rackUid) ~= "string" or PlacementController.IsActive() then
				return
			end
			if getNumberAttribute(player, "CarryCount", 0) > 0 then
				Remotes.StoreBox:FireServer(rackUid) -- StockService: onto the rack, or the locked card says why not
			else
				openMachine(child) -- its stock clipboard
			end
			return
		end
		if isBin then
			if not PlacementController.IsActive() then
				-- its window: the extras that go in, a tap keeps a card out (owner 2026-11-26, pick B; required here:
				-- this file's top level is near Luau's 200 locals)
				local BulkBinController = require(Controllers:WaitForChild("BulkBinController")) :: any
				BulkBinController.Open(child)
			end
			return
		end
		if isCondenser or isGrading or isForge or isRecycler then
			openMachine(child)
			return
		end
		local uid = child:GetAttribute("ShelfUid")
		if typeof(uid) == "string" then
			Remotes.StockShelf:FireServer(uid)
		end
	end)

	local edit = makePrompt(child, "Edit", def.name, Enum.KeyCode.F)
	edit.GamepadKeyCode = Enum.KeyCode.ButtonY
	if isCondenser or isGrading or isForge or isRecycler or isBin or isRack then
		edit.UIOffset = Vector2.new(0, CONDENSER_EDIT_OFFSET)
	end
	edit.Triggered:Connect(function()
		if not PlacementController.IsActive() then
			openEdit(child)
		end
	end)

	local prompts: ShelfPrompts = { stock = stock, edit = edit }
	promptsByShelf[child] = prompts
	applyPromptMode(child, prompts)
	if isRack then
		-- its count on the prompt follows the rack (you, a restocker)
		child:GetAttributeChangedSignal("StoredCount"):Connect(function()
			applyPromptMode(child, prompts)
		end)
	end
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

-- Move prompt on the owner's register (testers 2026-11-26: "Make the cash register Moveable", the owner's pick A): the
-- whole checkout moves as one box (Util/CheckoutLayout), its ghost the counter, the cashier's step and the queue's strip,
-- only in the hall. Hidden while you man it (its first-person view)
local function addRegisterPrompt(register: BasePart)
	if registerPrompt then
		registerPrompt:Destroy()
	end
	local PlotConfig = require(Config:WaitForChild("Plots")) :: any
	local Town = require(Config:WaitForChild("Town")) :: any
	local RoomsConfig = require(Config:WaitForChild("ShopRooms")) :: any
	local CheckoutLayout = require(Shared:WaitForChild("Util"):WaitForChild("CheckoutLayout"))
	local prompt = makePrompt(register, "Move", "Register", Enum.KeyCode.F)
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.UIOffset = Vector2.new(0, REGISTER_PROMPT_OFFSET)
	local function follow()
		prompt.Enabled = player:GetAttribute("ManningRegister") ~= true
	end
	follow()
	player:GetAttributeChangedSignal("ManningRegister"):Connect(follow)
	prompt.Triggered:Connect(function()
		local fixtureId = register:GetAttribute("FixtureId")
		if PlacementController.IsActive() or typeof(fixtureId) ~= "string" then
			return
		end
		local box = CheckoutLayout.fromConfig(PlotConfig, Town)
		PlacementController.Begin(Vector3.new(box.width, PlotConfig.REGISTER_SIZE.Y, box.depth), {
			kind = "MoveFixture",
			id = fixtureId,
			title = "Move Register",
			rotation = getNumberAttribute(register, "Rotation", 0),
			gridX = getNumberAttribute(register, "GridX", 0),
			gridZ = getNumberAttribute(register, "GridZ", 0),
			pieces = CheckoutLayout.pieces(PlotConfig, Town, box),
			maxRows = RoomsConfig.HALL_ROWS,
		})
	end)
	registerPrompt = prompt
end

-- Adds prompts to every shelf on the player's own plot (including ones placed later), its computer and its register
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
	task.spawn(function()
		local checkout = plot:WaitForChild("Checkout")
		addRegisterPrompt(checkout:WaitForChild("Register") :: BasePart)
	end)
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
		icon = "Shop",
		label = "Shop",
		order = 1,
		onClick = function()
			if PlacementController.IsActive() then
				return
			end
			refreshShopRows()
			shopPanel.Visible = not shopPanel.Visible
		end,
	})
end

-- How many of a Bag item this client knows the player holds (Pish's trophy lesson points at the trophy you have)
function BuildController.ItemCount(itemId: string): number
	return items[itemId] or 0
end

-- A trophy from the Bag's Place button (owner 2026-11-17): placed like a new shelf, its trophy item the price (the
-- server takes it, PlacementService). `itemId` is its Config/Shelves id too
function BuildController.PlaceTrophy(itemId: string)
	local def = Shelves.ById[itemId]
	if def and def.requiresItem == itemId then
		onBuy(def)
	end
end

-- The main quest's Build button (owner 2026-11-18): that shelf's placement at once, with the Build menu's own checks
-- (locked, not enough cash)
function BuildController.Buy(shelfId: string)
	local def = Shelves.ById[shelfId]
	if def and not def.requiresItem then
		onBuy(def)
	end
end

function BuildController.Start()
	local screenGui = UIController.GetScreenGui()
	buildShopPanel(screenGui)
	buildButton()

	player:GetAttributeChangedSignal("Level"):Connect(refreshShopRows)
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	player:GetAttributeChangedSignal("CarryCount"):Connect(refreshAllPrompts)
	player:GetAttributeChangedSignal("CarryProductId"):Connect(refreshAllPrompts) -- a rack's Store names the box
	-- The bag: trophies are placed from it
	Remotes.ItemsChanged.OnClientEvent:Connect(function(payload)
		items = if typeof(payload) == "table" then payload else {}
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the bag, whatever order the controllers start in
	task.spawn(watchOwnPlot)
end

return BuildController
