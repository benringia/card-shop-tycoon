--!strict
-- Ordering stock at the plot computer, delivering boxes to the delivery pad, carrying them,
-- and unpacking a carried box onto a shelf.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local StockConfig = require(Config:WaitForChild("Stock"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Plot = typeof(PlotService.GetPlots()[1])
type Product = typeof(Products.List[1])

type Shop = {
	owner: Player,
	plot: Plot,
	waiting: { Part }, -- boxes sitting on the delivery pad
	carried: { Part },
	incoming: number, -- ordered, not delivered yet
	active: boolean, -- false once the owner leaves, so pending deliveries cancel
}

local StockService = {}

local shops: { [Player]: Shop } = {}
local allowOrder = RateLimiter.new(StockConfig.ORDER_COOLDOWN)
local allowStock = RateLimiter.new(StockConfig.STOCK_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function getShop(player: Player): Shop?
	local existing = shops[player]
	if existing then
		return existing
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return nil
	end
	local shop: Shop = { owner = player, plot = plot, waiting = {}, carried = {}, incoming = 0, active = true }
	shops[player] = shop
	return shop
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

-- Lets the client show the right shelf prompt (Stock while carrying, Edit otherwise)
local function syncCarryCount(shop: Shop)
	shop.owner:SetAttribute("CarryCount", #shop.carried)
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
	syncCarryCount(shop)
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
	syncCarryCount(shop)
end

local function deliverBox(player: Player, shop: Shop, product: Product)
	local box = Instance.new("Part")
	box.Name = "StockBox"
	box.Size = StockConfig.BOX_SIZE
	box.Color = StockConfig.BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.Anchored = true
	box:SetAttribute("ProductId", product.id)
	box:SetAttribute("Units", product.unitsPerBox)

	local prompt = makePrompt(box, "Pick up", product.name)
	prompt.Triggered:Connect(function(triggeringPlayer)
		onPickup(triggeringPlayer, shop, box)
	end)

	table.insert(shop.waiting, box)
	layoutWaiting(shop)
	box.Parent = shop.plot.model
	notify(player, `Your {product.name} box arrived!`, false)
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
	if shop.incoming + #shop.waiting + #shop.carried >= StockConfig.MAX_BOXES_PER_PLOT then
		notify(player, "Your delivery area is full. Unpack some boxes first.", true)
		return
	end
	if not EconomyService.TrySpend(player, product.boxCost) then
		notify(player, "Not enough cash.", true)
		return
	end

	shop.incoming += 1
	notify(player, `Ordered {product.name}. Arrives in {StockConfig.DELIVERY_SECONDS}s.`, false)

	task.delay(StockConfig.DELIVERY_SECONDS, function()
		if not shop.active then
			return
		end
		shop.incoming -= 1
		deliverBox(player, shop, product)
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
		syncCarryCount(shop)
		notify(player, `Stocked {added}.`, false)
	end
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

-- No saving yet, so a leaving player's boxes are simply removed
local function onPlayerRemoving(player: Player)
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

function StockService.Start()
	for _, plot in PlotService.GetPlots() do
		local prompt = makePrompt(plot.computer, "Order stock", "Computer")
		prompt.Triggered:Connect(function(player)
			onComputerUsed(player, plot)
		end)
	end

	Remotes.OrderProduct.OnServerEvent:Connect(onOrder)
	Remotes.StockShelf.OnServerEvent:Connect(onStockShelf)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return StockService
