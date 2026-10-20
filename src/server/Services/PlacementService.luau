--!strict
-- Places, moves and sells shelves on a player's plot, and holds what is stocked on each shelf.
-- Shelf parts carry attributes (ShelfUid, ShelfId, GridX, GridZ, Rotation, Refund) for the client.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Shelves = require(Config:WaitForChild("Shelves"))
local Products = require(Config:WaitForChild("Products"))
local PlacementConfig = require(Config:WaitForChild("Placement"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Plot = typeof(PlotService.GetPlots()[1])
type ShelfDef = typeof(Shelves.List[1])

export type PlacedShelf = {
	uid: string,
	owner: Player,
	def: ShelfDef,
	gridX: number,
	gridZ: number,
	rotation: number,
	productId: string?,
	units: number,
	paid: number, -- what the player spent, for the sell-back refund
	part: Part,
	label: TextLabel,
}

local PlacementService = {}

local layouts: { [Player]: { [string]: PlacedShelf } } = {}
local allowAction = RateLimiter.new(PlacementConfig.ACTION_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function isGridInteger(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value) and math.abs(value) < 1e4
end

local function isValidRotation(value: unknown): boolean
	return isGridInteger(value) and (value :: number) >= 0 and (value :: number) < PlacementConfig.ROTATION_STEPS
end

local function countShelves(layout: { [string]: PlacedShelf }): number
	local count = 0
	for _ in layout do
		count += 1
	end
	return count
end

local function getRefund(shelf: PlacedShelf): number
	return math.floor(shelf.paid * PlacementConfig.SELL_REFUND * 100) / 100
end

local function updateLabel(shelf: PlacedShelf)
	local product = if shelf.productId then Products.ById[shelf.productId] else nil
	if not product or shelf.units <= 0 then
		shelf.label.Text = `Empty\n0/{shelf.def.capacity}`
		return
	end
	local price = PricingService.GetPrice(shelf.owner, product.id)
	shelf.label.Text = string.format("%s\n%d/%d · $%.2f", product.name, shelf.units, shelf.def.capacity, price)
end

local function positionShelf(plot: Plot, shelf: PlacedShelf)
	shelf.part.CFrame = plot.floor.CFrame
		* PlacementGrid.getLocalCFrame(shelf.def.size, shelf.gridX, shelf.gridZ, shelf.rotation)
	shelf.part:SetAttribute("GridX", shelf.gridX)
	shelf.part:SetAttribute("GridZ", shelf.gridZ)
	shelf.part:SetAttribute("Rotation", shelf.rotation)
end

local function buildLabel(part: Part): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.4)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return label
end

local function createShelf(
	player: Player,
	plot: Plot,
	def: ShelfDef,
	gridX: number,
	gridZ: number,
	rotation: number,
	paid: number
): PlacedShelf
	local uid = HttpService:GenerateGUID(false)

	local part = Instance.new("Part")
	part.Name = def.id
	part.Anchored = true
	part.Size = def.size
	part.Color = def.color
	part.Material = Enum.Material.Wood
	part:SetAttribute("BlocksPlacement", true)
	part:SetAttribute("ShelfUid", uid)
	part:SetAttribute("ShelfId", def.id)

	local shelf: PlacedShelf = {
		uid = uid,
		owner = player,
		def = def,
		gridX = gridX,
		gridZ = gridZ,
		rotation = rotation,
		productId = nil,
		units = 0,
		paid = paid,
		part = part,
		label = buildLabel(part),
	}
	part:SetAttribute("Refund", getRefund(shelf))
	positionShelf(plot, shelf)
	updateLabel(shelf)
	part.Parent = plot.shelvesFolder

	layouts[player][uid] = shelf
	return shelf
end

local function isNearPlot(player: Player, plot: Plot): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - plot.floor.Position).Magnitude <= PlacementConfig.MAX_EDIT_DISTANCE
end

local function canPlaceAt(plot: Plot, size: Vector3, gridX: number, gridZ: number, rotation: number, ignoreId: string?): boolean
	local blocked = PlacementGrid.getBlockedRects(plot.model, plot.floor.CFrame, ignoreId)
	return PlacementGrid.isFree(blocked, size, gridX, gridZ, rotation)
end

-- Shared checks for every edit request. Returns the plot and layout when the player may edit.
local function getEditablePlot(player: Player): (Plot?, { [string]: PlacedShelf }?)
	local plot = PlotService.GetPlot(player)
	local layout = layouts[player]
	if not plot or not layout then
		return nil, nil
	end
	if not isNearPlot(player, plot) then
		notify(player, "Go back to your shop to do that.", true)
		return nil, nil
	end
	return plot, layout
end

local function onPlace(player: Player, shelfId: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(shelfId) ~= "string" or not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local def = Shelves.ById[shelfId]
	if not def then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number

	if EconomyService.GetLevel(player) < def.unlockLevel then
		notify(player, `Unlocks at shop level {def.unlockLevel}.`, true)
		return
	end
	if countShelves(layout) >= PlacementConfig.MAX_SHELVES_PER_PLOT then
		notify(player, "Your shop can't fit any more shelves.", true)
		return
	end
	if not canPlaceAt(plot, def.size, gx, gz, rot, nil) then
		notify(player, "That spot is blocked.", true)
		return
	end
	if not EconomyService.TrySpend(player, def.cost) then
		notify(player, "Not enough cash.", true)
		return
	end

	createShelf(player, plot, def, gx, gz, rot, def.cost)
	notify(player, `Placed {def.name}.`, false)
end

local function onMove(player: Player, uid: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(uid) ~= "string" or not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local shelf = layout[uid]
	if not shelf then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number
	if not canPlaceAt(plot, shelf.def.size, gx, gz, rot, uid) then
		notify(player, "That spot is blocked.", true)
		return
	end

	shelf.gridX, shelf.gridZ, shelf.rotation = gx, gz, rot
	positionShelf(plot, shelf)
end

-- Only the order computer can be moved for now; the register stays put because the queue lines up on it
local function onMoveFixture(player: Player, fixtureId: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if fixtureId ~= PlotService.COMPUTER_FIXTURE_ID then
		return
	end
	if not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local plot = getEditablePlot(player)
	if not plot then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number
	if not canPlaceAt(plot, plot.computer.Size, gx, gz, rot, fixtureId) then
		notify(player, "That spot is blocked.", true)
		return
	end
	PlotService.SetComputerCell(plot, gx, gz, rot)
end

local function onSell(player: Player, uid: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(uid) ~= "string" then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local shelf = layout[uid]
	if not shelf then
		return
	end
	if shelf.units > 0 then
		notify(player, "Sell the stock on this shelf first.", true)
		return
	end

	local refund = getRefund(shelf)
	layout[uid] = nil
	shelf.part:Destroy()
	if refund > 0 then
		EconomyService.AddCash(player, refund)
	end
	notify(player, string.format("Sold %s for $%.2f.", shelf.def.name, refund), false)
end

-- New shops start with an empty floor; every shelf is bought from the Build menu
local function onClaimed(player: Player, _plot: Plot)
	layouts[player] = {}
end

local function onReleased(player: Player, _plot: Plot)
	local layout = layouts[player]
	if not layout then
		return
	end
	for _, shelf in layout do
		shelf.part:Destroy()
	end
	layouts[player] = nil
end

function PlacementService.GetShelf(player: Player, uid: string): PlacedShelf?
	local layout = layouts[player]
	return if layout then layout[uid] else nil
end

function PlacementService.GetShelves(player: Player): { PlacedShelf }
	local list: { PlacedShelf } = {}
	local layout = layouts[player]
	if layout then
		for _, shelf in layout do
			table.insert(list, shelf)
		end
	end
	return list
end

-- Removes up to `units` from the shelf (a customer picking them up). Returns units taken.
function PlacementService.TakeStock(shelf: PlacedShelf, units: number): number
	local taken = math.min(units, shelf.units)
	if taken <= 0 then
		return 0
	end
	shelf.units -= taken
	updateLabel(shelf)
	return taken
end

-- Puts up to maxUnits of a product on the shelf. Returns units added, or 0 and a reason.
function PlacementService.AddStock(shelf: PlacedShelf, productId: string, maxUnits: number): (number, string?)
	local accepts = shelf.def.accepts
	if accepts and not table.find(accepts, productId) then
		return 0, "This shelf can't hold that."
	end
	if shelf.units > 0 and shelf.productId ~= productId then
		return 0, "This shelf has a different product on it."
	end
	local space = shelf.def.capacity - shelf.units
	if space <= 0 then
		return 0, "This shelf is full."
	end

	local added = math.min(space, maxUnits)
	shelf.productId = productId
	shelf.units += added
	updateLabel(shelf)
	return added, nil
end

local function onPriceChanged(player: Player, productId: string, _price: number)
	local layout = layouts[player]
	if not layout then
		return
	end
	for _, shelf in layout do
		if shelf.productId == productId then
			updateLabel(shelf)
		end
	end
end

function PlacementService.Start()
	PlotService.OnClaimed(onClaimed)
	PlotService.OnReleased(onReleased)
	PricingService.OnPriceChanged(onPriceChanged)

	Remotes.PlaceShelf.OnServerEvent:Connect(onPlace)
	Remotes.MoveShelf.OnServerEvent:Connect(onMove)
	Remotes.MoveFixture.OnServerEvent:Connect(onMoveFixture)
	Remotes.SellShelf.OnServerEvent:Connect(onSell)
end

return PlacementService
