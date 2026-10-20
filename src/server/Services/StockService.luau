--!strict
-- Ordering stock at the plot computer, delivering boxes to the delivery pad, carrying them,
-- and unpacking a carried box onto a shelf. Boxes (waiting, carried or still on order) are saved
-- through DataService and come back on the delivery pad next session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local StockConfig = require(Config:WaitForChild("Stock"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Plot = typeof(PlotService.GetPlots()[1])
type PlayerData = DataService.PlayerData
type SavedBox = DataService.SavedBox

type Shop = {
	owner: Player,
	plot: Plot,
	waiting: { Part }, -- boxes sitting on the delivery pad
	carried: { Part },
	incoming: { string }, -- product IDs ordered but not delivered yet
	active: boolean, -- false once the owner leaves, so pending deliveries cancel
}

local StockService = {}

local shops: { [Player]: Shop } = {}
local allowOrder = RateLimiter.new(StockConfig.ORDER_COOLDOWN)
local allowStock = RateLimiter.new(StockConfig.STOCK_COOLDOWN)
local allowDrop = RateLimiter.new(StockConfig.DROP_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- Shops exist once the player's data has loaded and they have a plot
local function getShop(player: Player): Shop?
	return shops[player]
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isNear(player: Player, part: BasePart): boolean
	local root = getRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= StockConfig.INTERACT_DISTANCE
end

local function makePrompt(parent: Instance, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = StockConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Arrange waiting boxes in a 2x2 grid on the pad, stacking upward
local function layoutWaiting(shop: Shop)
	local pad = shop.plot.deliverySpot
	local size = StockConfig.BOX_SIZE
	for index, box in shop.waiting do
		local i = index - 1
		local layer = i // StockConfig.BOXES_PER_LAYER
		local slot = i % StockConfig.BOXES_PER_LAYER
		local x = (slot % 2 - 0.5) * size.X
		local z = (slot // 2 - 0.5) * size.Z
		local y = pad.Size.Y / 2 + size.Y * (layer + 0.5)
		box.CFrame = pad.CFrame * CFrame.new(x, y, z)
	end
end

local function attachToCharacter(box: Part, root: BasePart, stackIndex: number)
	box.CFrame = root.CFrame * StockConfig.CARRY_OFFSET * CFrame.new(0, StockConfig.BOX_SIZE.Y * (stackIndex - 1), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = root
	weld.Parent = box
	box.CanCollide = false
	box.Massless = true
	box.Anchored = false
end

local function detachFromCharacter(box: Part)
	local weld = box:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	box.Anchored = true
	box.CanCollide = true
	box.Massless = false
end

local function setPromptEnabled(box: Part, enabled: boolean)
	local prompt = box:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

-- Lets the client show the right prompts and buttons (Stock vs Edit, Drop, Rip a pack + units left)
local function syncCarry(shop: Shop)
	local top = shop.carried[#shop.carried]
	shop.owner:SetAttribute("CarryCount", #shop.carried)
	shop.owner:SetAttribute("CarryProductId", if top then top:GetAttribute("ProductId") else nil)
	shop.owner:SetAttribute("CarryUnits", if top then top:GetAttribute("Units") else nil)
end

-- Carried boxes go back to the pad when the character dies or respawns
local function returnCarried(shop: Shop)
	for _, box in shop.carried do
		detachFromCharacter(box)
		setPromptEnabled(box, true)
		table.insert(shop.waiting, box)
	end
	table.clear(shop.carried)
	layoutWaiting(shop)
	syncCarry(shop)
end

local function onPickup(player: Player, shop: Shop, box: Part)
	if not shop.active or shop.plot.owner ~= player then
		notify(player, "That box belongs to another shop.", true)
		return
	end
	local index = table.find(shop.waiting, box)
	if not index then
		return
	end
	if #shop.carried >= StockConfig.MAX_CARRY then
		notify(player, "Your hands are full.", true)
		return
	end
	local root = getRoot(player)
	if not root or not isNear(player, box) then
		return
	end

	table.remove(shop.waiting, index)
	table.insert(shop.carried, box)
	setPromptEnabled(box, false)
	attachToCharacter(box, root, #shop.carried)
	layoutWaiting(shop)
	syncCarry(shop)
end

-- Puts a box on the delivery pad
local function createBox(shop: Shop, productId: string, units: number)
	local product = Products.ById[productId]
	local box = Instance.new("Part")
	box.Name = "StockBox"
	box.Size = StockConfig.BOX_SIZE
	box.Color = StockConfig.BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.Anchored = true
	box:SetAttribute("ProductId", productId)
	box:SetAttribute("Units", units)

	local prompt = makePrompt(box, "Pick up", product.name)
	prompt.Triggered:Connect(function(triggeringPlayer)
		onPickup(triggeringPlayer, shop, box)
	end)

	table.insert(shop.waiting, box)
	layoutWaiting(shop)
	box.Parent = shop.plot.model
end

local function onOrder(player: Player, productId: unknown)
	if not allowOrder(player) then
		return
	end
	if typeof(productId) ~= "string" then
		return
	end
	local product = Products.ById[productId]
	if not product then
		return
	end
	local shop = getShop(player)
	if not shop then
		notify(player, "You need a shop to order stock.", true)
		return
	end
	if not isNear(player, shop.plot.computer) then
		notify(player, "Walk up to your computer to order.", true)
		return
	end
	if EconomyService.GetLevel(player) < product.unlockLevel then
		notify(player, `Unlocks at shop level {product.unlockLevel}.`, true)
		return
	end
	if #shop.incoming + #shop.waiting + #shop.carried >= StockConfig.MAX_BOXES_PER_PLOT then
		notify(player, "Your delivery area is full. Unpack some boxes first.", true)
		return
	end
	if not EconomyService.TrySpend(player, product.boxCost) then
		notify(player, "Not enough cash.", true)
		return
	end

	table.insert(shop.incoming, product.id)
	notify(player, `Ordered {product.name}. Arrives in {StockConfig.DELIVERY_SECONDS}s.`, false)

	task.delay(StockConfig.DELIVERY_SECONDS, function()
		local index = table.find(shop.incoming, product.id)
		if not shop.active or not index then
			return
		end
		table.remove(shop.incoming, index)
		createBox(shop, product.id, product.unitsPerBox)
		notify(player, `Your {product.name} box arrived!`, false)
	end)
end

-- Unpacks the top carried box onto the shelf. A part-used box stays in the player's hands.
local function onStockShelf(player: Player, uid: unknown)
	if not allowStock(player) then
		return
	end
	if typeof(uid) ~= "string" then
		return
	end
	local shelf = PlacementService.GetShelf(player, uid)
	if not shelf then
		return
	end
	if not isNear(player, shelf.part) then
		notify(player, "Get closer to the shelf.", true)
		return
	end
	local shop = shops[player]
	local box = if shop then shop.carried[#shop.carried] else nil
	if not shop or not box then
		notify(player, "Carry a box here to stock this shelf.", true)
		return
	end
	local productId = box:GetAttribute("ProductId")
	local units = box:GetAttribute("Units")
	if typeof(productId) ~= "string" or typeof(units) ~= "number" then
		return
	end

	local added, reason = PlacementService.AddStock(shelf, productId, units)
	if added == 0 then
		notify(player, reason or "You can't stock that here.", true)
		return
	end

	local left = units - added
	if left > 0 then
		box:SetAttribute("Units", left)
		notify(player, `Stocked {added}. {left} left in the box.`, false)
	else
		table.remove(shop.carried)
		box:Destroy()
		notify(player, `Stocked {added}.`, false)
	end
	syncCarry(shop)
end

-- Boxes go back on the delivery pad (with whatever units are left) to pick up again later
local function onDropBox(player: Player)
	if not allowDrop(player) then
		return
	end
	local shop = shops[player]
	if not shop or #shop.carried == 0 then
		return
	end
	returnCarried(shop)
	notify(player, "Box put back on the delivery pad.", false)
end

local function onComputerUsed(player: Player, plot: Plot)
	if plot.owner ~= player then
		notify(player, "This is someone else's shop.", true)
		return
	end
	Remotes.OpenOrderMenu:FireClient(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterRemoving:Connect(function()
		local shop = shops[player]
		if shop then
			returnCarried(shop)
		end
	end)
end

local function isValidSavedBox(saved: SavedBox): boolean
	if typeof(saved) ~= "table" or typeof(saved.productId) ~= "string" or typeof(saved.units) ~= "number" then
		return false
	end
	local product = Products.ById[saved.productId]
	return product ~= nil and saved.units >= 1 and saved.units <= product.unitsPerBox
end

local function load(player: Player, data: PlayerData)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return -- no free plot this session; leave the saved boxes untouched
	end
	local shop: Shop = { owner = player, plot = plot, waiting = {}, carried = {}, incoming = {}, active = true }
	shops[player] = shop
	for index, saved in data.boxes do
		if index > StockConfig.MAX_BOXES_PER_PLOT then
			break
		end
		if isValidSavedBox(saved) then
			createBox(shop, saved.productId, math.floor(saved.units))
		end
	end
	syncCarry(shop)
end

-- Every box the player owns: on the pad, in their hands, and ones paid for but not delivered yet
local function save(player: Player, data: PlayerData)
	local shop = shops[player]
	if not shop then
		return
	end
	local boxes: { SavedBox } = {}
	local function addPart(box: Part)
		local productId = box:GetAttribute("ProductId")
		local units = box:GetAttribute("Units")
		if typeof(productId) == "string" and typeof(units) == "number" and units > 0 then
			table.insert(boxes, { productId = productId, units = units })
		end
	end
	for _, box in shop.waiting do
		addPart(box)
	end
	for _, box in shop.carried do
		addPart(box)
	end
	for _, productId in shop.incoming do
		local product = Products.ById[productId]
		if product then
			table.insert(boxes, { productId = productId, units = product.unitsPerBox })
		end
	end
	data.boxes = boxes
end

local function unload(player: Player)
	local shop = shops[player]
	if not shop then
		return
	end
	shop.active = false
	for _, box in shop.waiting do
		box:Destroy()
	end
	for _, box in shop.carried do
		box:Destroy()
	end
	shops[player] = nil
end

-- Product in the box on top of the player's carried stack, if any
function StockService.GetCarriedProductId(player: Player): string?
	local shop = shops[player]
	local box = if shop then shop.carried[#shop.carried] else nil
	local productId = if box then box:GetAttribute("ProductId") else nil
	return if typeof(productId) == "string" then productId else nil
end

-- Removes up to `units` from the top carried box (opening packs yourself). Returns units taken.
function StockService.TakeCarriedUnits(player: Player, units: number): number
	local shop = shops[player]
	local box = if shop then shop.carried[#shop.carried] else nil
	local available = if box then box:GetAttribute("Units") else nil
	if not shop or not box or typeof(available) ~= "number" or available <= 0 then
		return 0
	end

	local taken = math.min(units, available)
	local left = available - taken
	if left > 0 then
		box:SetAttribute("Units", left)
	else
		table.remove(shop.carried)
		box:Destroy()
	end
	syncCarry(shop)
	return taken
end

function StockService.Start()
	for _, plot in PlotService.GetPlots() do
		local prompt = makePrompt(plot.computer, "Order stock", "Computer")
		prompt.Triggered:Connect(function(player)
			onComputerUsed(player, plot)
		end)
	end

	Remotes.OrderProduct.OnServerEvent:Connect(onOrder)
	Remotes.StockShelf.OnServerEvent:Connect(onStockShelf)
	Remotes.DropBox.OnServerEvent:Connect(onDropBox)
	DataService.Register({ name = "StockService", load = load, save = save, unload = unload })
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return StockService
