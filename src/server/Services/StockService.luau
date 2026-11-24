--!strict
-- Ordering stock at the plot computer, delivering boxes to the delivery pad, carrying them,
-- and unpacking a carried box onto a shelf. Restocker workers (JobService) take boxes from the pad
-- through the Worker API below. Boxes (waiting, carried by the owner or a worker, or still on order) are saved
-- through DataService and come back on the delivery pad next session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PadRules = require(Shared:WaitForChild("Util"):WaitForChild("PadRules"))
local Config = Shared:WaitForChild("Config")
local StorageConfig = require(Config:WaitForChild("Storage"))
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local Products = require(Config:WaitForChild("Products"))
local Items = require(Config:WaitForChild("Items"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local OrderRules = require(Shared:WaitForChild("Util"):WaitForChild("OrderRules"))
local StockConfig = require(Config:WaitForChild("Stock"))
local CarryPose = require(Config:WaitForChild("CarryPose"))
local Delivery = require(Config:WaitForChild("Delivery"))
local DeliveryRules = require(Shared:WaitForChild("Util"):WaitForChild("DeliveryRules"))
local Offline = require(Config:WaitForChild("Offline"))
local Tips = require(Config:WaitForChild("Tips"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Blocked = require((script.Parent :: Instance).Parent:WaitForChild("Util"):WaitForChild("Blocked"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BoxLook = require(Util:WaitForChild("BoxLook"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local TipService = require(Services:WaitForChild("TipService"))

type Plot = typeof(PlotService.GetPlots()[1])
type PlayerData = DataService.PlayerData
type SavedBox = DataService.SavedBox

-- A box ordered but not delivered yet: what's in it, when it lands (os.clock) and how long its trip is
type Incoming = { productId: string, at: number, seconds: number }

type Shop = {
	owner: Player,
	plot: Plot,
	waiting: { Part }, -- boxes sitting on the delivery pad
	carried: { Part },
	workerBoxes: { Part }, -- taken off the pad by a restocker worker
	incoming: { Incoming }, -- ordered but not delivered yet
	active: boolean, -- false once the owner leaves, so pending deliveries cancel
}

local StockService = {}

local shops: { [Player]: Shop } = {}
-- The tutorial listens (TutorialService): an order placed, a shelf stocked
local orderedHandlers: { (player: Player, productId: string) -> () } = {}
local stockedHandlers: { (player: Player, productId: string) -> () } = {}

local function fire(handlers: { (player: Player, productId: string) -> () }, player: Player, productId: string)
	for _, handler in handlers do
		task.spawn(handler, player, productId)
	end
end
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

-- Arrange waiting boxes on the pad: a 2x2 grid of stacks, each product on its own (Util/PadRules; owner 2026-11-20:
-- "when there is alot of boxes piled up, and the players just want to take the one on top. it's dificult"). Only the
-- top box of a stack can be picked up, and its prompt says what the stack holds and how many of it wait.
local function layoutWaiting(shop: Shop)
	local pad = shop.plot.deliverySpot
	local size = StockConfig.BOX_SIZE
	local standHeight = pad:GetAttribute("StandHeight") -- the pallet drawn on the pad (PlotService)
	local lift = if typeof(standHeight) == "number" then standHeight else 0
	local products: { string } = {}
	local waitingOf: { [string]: number } = {}
	for index, box in shop.waiting do
		local productId = box:GetAttribute("ProductId")
		products[index] = if typeof(productId) == "string" then productId else ""
		waitingOf[products[index]] = (waitingOf[products[index]] or 0) + 1
	end
	local places = PadRules.arrange(products, StockConfig.BOXES_PER_LAYER, StockConfig.PAD_HIGH)
	local tops = PadRules.tops(places)
	for index, box in shop.waiting do
		local place = places[index]
		local slot = place.column - 1
		local x = (slot % 2 - 0.5) * size.X
		local z = (slot // 2 - 0.5) * size.Z
		local y = pad.Size.Y / 2 + lift + size.Y * (place.level + 0.5)
		box.CFrame = pad.CFrame * CFrame.new(x, y, z)
		local prompt = box:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local product = Products.ById[products[index]]
			prompt.Enabled = tops[index] == true
			prompt.ObjectText = PadRules.label(if product then product.name else "Box", waitingOf[products[index]] or 1)
		end
	end
end

-- A box in the carrier's arms (Config/CarryPose; owner 2026-11-23): in front of the belly and chest, welded to the
-- UpperTorso so it sways with the walk and the arms every client poses round it (CarryPoseController) stay on it; to the
-- root on a body without an UpperTorso. A Weld, not a WeldConstraint: its offset is exact whatever pose the body is in.
-- More boxes stack on top.
local function attachToCharacter(box: Part, root: BasePart, stackIndex: number)
	local stack = CFrame.new(0, StockConfig.BOX_SIZE.Y * (stackIndex - 1), 0)
	local torso = if root.Parent then root.Parent:FindFirstChild("UpperTorso") else nil
	local holder: BasePart = if torso and torso:IsA("BasePart") then torso else root
	local offset = if holder == root then StockConfig.CARRY_OFFSET * stack else CFrame.new(0, -CarryPose.BOX.down, -CarryPose.BOX.forward) * stack
	box.CFrame = holder.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = holder
	weld.Part1 = box
	weld.C0 = offset
	weld.Parent = box
	box.CanCollide = false
	box.Massless = true
	box.Anchored = false
end

local function detachFromCharacter(box: Part)
	local weld = box:FindFirstChild("CarryWeld") or box:FindFirstChildOfClass("WeldConstraint")
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

-- Every box the shop has: on order, on the pad, in the owner's or a worker's hands (StockConfig.MAX_BOXES_PER_PLOT)
local function boxCount(shop: Shop): number
	return #shop.incoming + #shop.waiting + #shop.carried + #shop.workerBoxes
end

-- One more box fits in the shop's shared spots: a box off a storage rack goes into hands, and from hands it can always
-- go back on the pad (spec 2026-11-24-storage-racks-design)
local function hasRoom(shop: Shop): boolean
	return boxCount(shop) < StockConfig.MAX_BOXES_PER_PLOT
end

-- Boxes on their way and boxes on the pad (Pish's stock line: "on the way" while a delivery hasn't come yet), and the
-- pad's spots used (the order computer: how many more boxes fit)
local function syncPad(shop: Shop)
	shop.owner:SetAttribute("BoxesComing", #shop.incoming)
	shop.owner:SetAttribute("BoxesWaiting", #shop.waiting)
	shop.owner:SetAttribute("BoxesUsed", boxCount(shop))
end

-- Whether this box holds packs or deck boxes (To Bag puts them in the Bag: ItemRules.stockItem)
local function holdsPacks(box: Part?): boolean
	return box ~= nil and ItemRules.stockItem(Items, box:GetAttribute("ProductId")) ~= nil
end

-- Lets the client show the right prompts and buttons (Stock vs Edit, Drop, Rip a pack + units left); the To Bag tip
-- bubble ("ToBagTip") goes once the box in your hands holds no packs
local function syncCarry(shop: Shop)
	syncPad(shop)
	local top = shop.carried[#shop.carried]
	shop.owner:SetAttribute("CarryCount", #shop.carried)
	shop.owner:SetAttribute("CarryProductId", if top then top:GetAttribute("ProductId") else nil)
	shop.owner:SetAttribute("CarryUnits", if top then top:GetAttribute("Units") else nil)
	if not holdsPacks(top) then
		shop.owner:SetAttribute("ToBagTip", nil)
	end
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
	-- the first few boxes of packs: a bubble over To Bag teaches it (Config/Tips TO_BAG; owner 2026-11-17: "make sure
	-- players know you can put packs in the bag"); never during Pish's tour, which has them stock the rack (2026-11-18)
	local step = player:GetAttribute("TutorialStep")
	local touring = TutorialRules.tipWaits(if typeof(step) == "string" then step else "")
	if holdsPacks(box) and not touring and TipService.Next(player, Tips.TO_BAG.id, Tips.TO_BAG.shows) then
		player:SetAttribute("ToBagTip", true)
	end
	syncCarry(shop)
end

-- A box of this shop's (Util/BoxLook) with its Pick up prompt, which only works while it waits on the pad (onPickup)
local function makeBox(shop: Shop, productId: string, units: number): Part
	local product = Products.ById[productId]
	local box = BoxLook.build(productId, units)
	local prompt = makePrompt(box, "Pick up", product.name)
	prompt.Triggered:Connect(function(triggeringPlayer)
		onPickup(triggeringPlayer, shop, box)
	end)
	return box
end

-- Puts a box on the delivery pad. `fromVan`: it hops out of the packenship.co van (DeliveryController flies it from the
-- van's door; its VanHop attribute says when, on the server's clock)
local function createBox(shop: Shop, productId: string, units: number, fromVan: boolean?)
	local box = makeBox(shop, productId, units)
	if fromVan then
		box:SetAttribute("VanHop", workspace:GetServerTimeNow())
	end

	table.insert(shop.waiting, box)
	layoutWaiting(shop)
	box.Parent = shop.plot.model
	syncPad(shop)
end

-- How long a box takes to arrive for this player now: Pish's tour's at once, a new shop's quick (Config/Early: 3 s up
-- to shop level 8, the full 10 from 15), Express (a Bloom creature summoned) shorter
local function deliverySecondsFor(player: Player): number
	local step = player:GetAttribute("TutorialStep")
	local touring = step == "orderStock" or step == "stockRack"
	local level = tonumber(player:GetAttribute("Level")) or 1
	local early = EarlyRules.delivery(level, Early, StockConfig.DELIVERY_SECONDS)
	return OrderRules.deliverySeconds(touring, StockConfig.TOUR_DELIVERY_SECONDS, early, PartyService.GetPerk(player, "Express"))
end

-- What the order computer shows: a box's trip time now and the boxes on the way (seconds left of each)
local function orderInfo(player: Player, boxes: number): { [string]: any }
	local shop = shops[player]
	local now = os.clock()
	local coming = {}
	for _, order in if shop then shop.incoming else {} do
		table.insert(coming, { productId = order.productId, left = math.max(0, order.at - now), seconds = order.seconds })
	end
	return { seconds = deliverySecondsFor(player), coming = coming, boxes = boxes }
end

-- The order computer's cart (OrderController): every box paid at once, all arriving together on the pad. The answer
-- (OrderPlaced) says how many went through, 0 when refused (the reason shown with Util/Blocked or BrokeService).
local function onOrderCart(player: Player, raw: unknown)
	if not allowOrder(player) then
		return
	end
	local cart = OrderRules.readCart(raw, Products.ById, StockConfig.MAX_BOXES_PER_PLOT)
	if not cart then
		return
	end
	local function refuse(reason: string?)
		if reason then
			Blocked.tell(player, reason)
		end
		Remotes.OrderPlaced:FireClient(player, orderInfo(player, 0))
	end
	local shop = getShop(player)
	if not shop then
		refuse("You need a shop to order stock.")
		return
	end
	if not isNear(player, shop.plot.computer) then
		refuse("Walk up to your computer to order.")
		return
	end
	local level = EconomyService.GetLevel(player)
	-- the bosses beaten (BossService's BossesCleared, set by the server): the Frontier Pack needs the Frost Tyrant
	local beaten = OrderRules.clearedSet(player:GetAttribute("BossesCleared"))
	for _, product in Products.List do
		if cart[product.id] and level < product.unlockLevel then
			refuse(`{product.name} unlocks at shop level {product.unlockLevel}.`)
			return
		end
		local boss = product.unlockBoss
		if cart[product.id] and boss and not OrderRules.isOpen(product, level, beaten) then
			refuse(`Beat the {boss.name} to stock {product.name}s.`)
			return
		end
	end
	local count = OrderRules.cartCount(cart)
	local room = StockConfig.MAX_BOXES_PER_PLOT - boxCount(shop)
	if count > room then
		refuse(OrderRules.roomLine(room))
		return
	end
	local cost = OrderRules.cartCost(cart, Products.ById)
	local paid, kept = EconomyService.TrySpend(player, cost, "stock")
	if not paid then
		-- kept: the shop keeps that cash for a rack and a box, and BrokeService said so
		refuse(if kept then nil else `You need {OrderRules.money(cost)} for this order.`)
		return
	end

	local seconds = deliverySecondsFor(player)
	local batch: { Incoming } = {}
	local ordered: { string } = {}
	for _, product in Products.List do
		for _ = 1, cart[product.id] or 0 do
			local order: Incoming = { productId = product.id, at = os.clock() + seconds, seconds = seconds }
			table.insert(shop.incoming, order)
			table.insert(batch, order)
		end
		if cart[product.id] then
			table.insert(ordered, product.id)
		end
	end
	syncPad(shop)
	for _, productId in ordered do
		fire(orderedHandlers, player, productId)
	end
	local name = Products.ById[batch[1].productId].name
	notify(player, OrderRules.orderedLine(count, name, seconds), false)
	Remotes.OrderPlaced:FireClient(player, orderInfo(player, count))

	-- The packenship.co van (owner 2026-11-23, pick A): it comes down the street and stops by this shop's pad when the
	-- trip ends (DeliveryController), on the orderer's screen only ("only you should see the van"); the boxes hop out of
	-- it one by one, each made as it leaves the door (everyone else sees them appear on the pad)
	Remotes.DeliveryVan:FireClient(player, shop.plot.model, workspace:GetServerTimeNow() + seconds, #batch)
	local hops = DeliveryRules.hopTimes(#batch, Delivery.TRIP)
	local arrived = 0
	for index, order in batch do
		task.delay(seconds + hops[index], function()
			local at = table.find(shop.incoming, order)
			if not shop.active or not at then -- (gone: cleared for testing)
				return
			end
			table.remove(shop.incoming, at)
			createBox(shop, order.productId, Products.ById[order.productId].unitsPerBox, true)
			arrived += 1
		end)
	end
	-- once the last box has landed
	task.delay(seconds + hops[#hops] + Delivery.TRIP.hopTime, function()
		if shop.active and arrived > 0 then
			notify(player, OrderRules.arrivedLine(arrived, name), false)
		end
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

	-- The unboxing (owner 2026-11-23, pick 1): the box opens in the stocker's hands and the packs hop onto the shelf,
	-- the count rolling up over it, for everyone near (DeliveryController); it says how many went on, so a box that
	-- emptied needs no toast
	Remotes.ShelfStocked:FireAllClients(shelf.part, player, productId, added)
	local left = units - added
	if left > 0 then
		box:SetAttribute("Units", left)
		notify(player, `Stocked {added}. {left} left in the box.`, false)
	else
		table.remove(shop.carried)
		box:Destroy()
	end
	syncCarry(shop)
	fire(stockedHandlers, player, productId)
end

-- Takes a product shelf's stock back off it into boxes on the delivery pad (as many as the pad has room
-- for); restock it elsewhere or sell it later. Prices stay as they are.
local function onRemoveStock(player: Player, uid: unknown)
	if not allowStock(player) or typeof(uid) ~= "string" then
		return
	end
	local shop = shops[player]
	local shelf = PlacementService.GetShelf(player, uid)
	if not shop or not shelf or shelf.def.kind ~= "Products" then
		return
	end
	if not isNear(player, shelf.part) then
		notify(player, "Get closer to the shelf.", true)
		return
	end
	local productId = shelf.productId
	local product = if productId then Products.ById[productId] else nil
	if not product or shelf.units <= 0 then
		notify(player, "This shelf is already empty.", true)
		return
	end
	local room = StockConfig.MAX_BOXES_PER_PLOT - boxCount(shop)
	if room <= 0 then
		notify(player, "Your delivery area is full. Unpack some boxes first.", true)
		return
	end

	local taken = PlacementService.TakeStock(shelf, math.min(shelf.units, room * product.unitsPerBox))
	local left = taken
	while left > 0 do
		local units = math.min(left, product.unitsPerBox)
		createBox(shop, product.id, units)
		left -= units
	end
	local onShelf = shelf.units
	notify(
		player,
		if onShelf > 0
			then `Boxed {taken} {product.name}. {onShelf} still on the shelf (delivery area full).`
			else `Boxed {taken} {product.name}. They're on the delivery pad.`,
		false
	)
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

-- Storage racks (spec 2026-11-24-storage-racks-design) ------------------------------------------------------------

-- Your own storage rack within reach, else nil (a toast says to get closer)
local function nearRack(player: Player, uid: unknown): (Shop?, any)
	if typeof(uid) ~= "string" then
		return nil, nil
	end
	local shop = shops[player]
	local rack = PlacementService.GetShelf(player, uid)
	if not shop or not rack or not PlacementService.IsStorage(rack) then
		return nil, nil
	end
	if not isNear(player, rack.part) then
		notify(player, "Get closer to the rack.", true)
		return nil, nil
	end
	return shop, rack
end

-- The box in your arms goes on the rack, next to its own kind, hopping there (StorageController)
local function onStoreBox(player: Player, uid: unknown)
	if not allowStock(player) then
		return
	end
	local shop, rack = nearRack(player, uid)
	if not shop or not rack then
		return
	end
	local box = shop.carried[#shop.carried]
	if not box then
		Blocked.tell(player, "Carry a box here to store it.")
		return
	end
	local productId, units = box:GetAttribute("ProductId"), box:GetAttribute("Units")
	if typeof(productId) ~= "string" or typeof(units) ~= "number" then
		return
	end
	local slot = PlacementService.StoreInRack(rack, productId, units)
	if not slot then
		Blocked.tell(player, StorageConfig.WORDS.fullRack)
		return
	end
	table.remove(shop.carried)
	box:Destroy()
	syncCarry(shop)
	Remotes.RackBoxHop:FireAllClients(rack.part, slot, productId, true, player.Character)
end

-- A box of `productId` off the rack (its half-used one first) into your arms. It needs empty hands and a free spot in
-- the shop's shared 12 (from your arms it can always go back on the pad)
local function onTakeStoredBox(player: Player, uid: unknown, productId: unknown)
	if not allowStock(player) or typeof(productId) ~= "string" then
		return
	end
	local shop, rack = nearRack(player, uid)
	if not shop or not rack then
		return
	end
	if #shop.carried >= StockConfig.MAX_CARRY then
		Blocked.tell(player, StorageConfig.WORDS.handsFull)
		return
	end
	if not hasRoom(shop) then
		Blocked.tell(player, StorageConfig.WORDS.padFull)
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	local taken, slot = PlacementService.TakeFromRack(rack, productId)
	if not taken or not slot then
		return -- gone already (a restocker took it): the clipboard follows the rack
	end
	local box = makeBox(shop, taken.productId, taken.units)
	setPromptEnabled(box, false)
	box.Parent = shop.plot.model
	table.insert(shop.carried, box)
	attachToCharacter(box, root, #shop.carried)
	syncCarry(shop)
	Remotes.RackBoxHop:FireAllClients(rack.part, slot, taken.productId, false, player.Character)
end

-- The packs in your carried boxes go in your Bag, to open anywhere (owner 2026-11-17: "on pack boxes. add an option
-- that player can put all the cardpacks inside the box to their inventory or drop to the delivery box. that way. they
-- will never have to go back to the delivery to pickup packs to rip"). A pack or deck box becomes its Bag item
-- (ItemRules.stockItem); other boxes stay in your hands, and what the Bag can't hold stays in its box.
-- A check before the owner takes stock for themselves (a pack ripped, a box into the Bag): BrokeService's, which
-- tells the player itself when it refuses (a shop's last packs pay for its next box, Config/Broke)
local takeGuard: ((player: Player, productId: string, units: number) -> boolean)? = nil

function StockService.SetTakeGuard(guard: (player: Player, productId: string, units: number) -> boolean)
	takeGuard = guard
end

local function onBagBox(player: Player)
	if not allowDrop(player) then
		return
	end
	local shop = shops[player]
	if not shop or #shop.carried == 0 then
		return
	end
	-- the tour's packs go on the rack (its step stocks it); the tile is hidden then, this is the server saying so too
	local step = player:GetAttribute("TutorialStep")
	if not TutorialRules.offersToBag(if typeof(step) == "string" then step else "") then
		Blocked.tell(player, "Put these packs on your rack first! Pish is showing you how.")
		return
	end
	local moved = 0
	local kept = false -- a box the shop needs to sell stayed (the guard said so)
	for index = #shop.carried, 1, -1 do
		local box = shop.carried[index]
		local units = box:GetAttribute("Units")
		local boxProduct = box:GetAttribute("ProductId")
		local itemId = ItemRules.stockItem(Items, boxProduct)
		if itemId and typeof(units) == "number" and units > 0 and takeGuard and typeof(boxProduct) == "string" and not takeGuard(player, boxProduct, units) then
			kept = true
		elseif itemId and typeof(units) == "number" and units > 0 then
			local added = ItemService.GiveItem(player, itemId, units)
			moved += added
			if added >= units then
				table.remove(shop.carried, index)
				box:Destroy()
			elseif added > 0 then
				box:SetAttribute("Units", units - added)
			end
		end
	end
	-- the boxes still in your hands close up the stack
	local root = getRoot(player)
	if root then
		for stackIndex, box in shop.carried do
			detachFromCharacter(box)
			attachToCharacter(box, root, stackIndex)
		end
	end
	syncCarry(shop)
	if moved == 0 then
		if not kept then
			Blocked.tell(player, "Only boxes of packs or deck boxes go in your Bag, and it has to have room.")
		end
		return
	end
	-- they know To Bag now: its tip never shows again
	TipService.Done(player, Tips.TO_BAG.id, Tips.TO_BAG.shows)
	player:SetAttribute("ToBagTip", nil)
	notify(player, `{moved} {if moved == 1 then "pack" else "packs"} put in your Bag. Open them from the Bag anywhere!`, false)
end

-- Packs or deck boxes in your Bag go back to the shop (owner 2026-11-20: "Cards in your inventory should also be
-- placed in shelves by players"): one box of them (ItemRules.boxUnits) onto your delivery pad, to stock like any box.
-- Only shop stock items (Config/Items `stock`); gifts stay gifts.
local function onShopBagStock(player: Player, itemId: unknown)
	if not allowDrop(player) or typeof(itemId) ~= "string" then
		return
	end
	local productId = ItemRules.stockOf(Items, itemId)
	local product = if productId then Products.ById[productId] else nil
	local shop = shops[player]
	if not product or not shop then
		return
	end
	local room = StockConfig.MAX_BOXES_PER_PLOT - boxCount(shop)
	if room <= 0 then
		Blocked.tell(player, "Your delivery area is full. Put some boxes on your shelves first.")
		return
	end
	local units = ItemRules.boxUnits(ItemService.GetCount(player, itemId), product.unitsPerBox, room)
	if units <= 0 or not ItemService.TakeItem(player, itemId, units) then
		return
	end
	createBox(shop, product.id, units)
	syncPad(shop)
	local what = Offline.PLURALS[product.id] or product.name
	notify(player, `{units} {what} boxed up on your delivery pad. Put the box on a shelf to sell them!`, false)
end

local function onComputerUsed(player: Player, plot: Plot)
	if plot.owner ~= player then
		notify(player, "This is someone else's shop.", true)
		return
	end
	Remotes.OpenOrderMenu:FireClient(player, orderInfo(player, 0))
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
	local shop: Shop = { owner = player, plot = plot, waiting = {}, carried = {}, workerBoxes = {}, incoming = {}, active = true }
	shops[player] = shop
	for index, saved in data.boxes do
		if index > StockConfig.MAX_BOXES_PER_PLOT then
			break
		end
		if isValidSavedBox(saved) then
			createBox(shop, saved.productId, math.floor(saved.units))
		end
	end
	-- Storage racks' boxes no rack could hold (PlacementService loads first): onto the pad while it has room, the rest
	-- paid back at their share of the box price, never lost (spec 2026-11-24-storage-racks-design)
	local refund = 0
	for _, extra in PlacementService.TakeLoadExtras(player) do
		local product = Products.ById[extra.productId]
		if product and hasRoom(shop) then
			createBox(shop, extra.productId, extra.units)
		elseif product then
			refund += product.boxCost * extra.units / product.unitsPerBox
		end
	end
	if refund > 0 then
		local cash = math.floor(refund * 100 + 0.5) / 100
		EconomyService.AddCash(player, cash)
		task.delay(StockConfig.LOAD_TOAST_DELAY, function()
			if player.Parent then
				notify(player, string.format(StorageConfig.WORDS.refunded, OrderRules.money(cash)), false)
			end
		end)
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
	for _, box in shop.workerBoxes do
		addPart(box)
	end
	for _, order in shop.incoming do
		local product = Products.ById[order.productId]
		if product then
			table.insert(boxes, { productId = order.productId, units = product.unitsPerBox })
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
	for _, box in shop.workerBoxes do
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
	local productId = box:GetAttribute("ProductId")
	if takeGuard and typeof(productId) == "string" and not takeGuard(player, productId, math.min(units, available)) then
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

-- Units of each product in the shop's boxes: on the pad, in hands (the owner's, a worker's) and on order. nil: no
-- shop loaded for this player.
function StockService.GetBoxStock(player: Player): { [string]: number }?
	local shop = shops[player]
	if not shop then
		return nil
	end
	local stock: { [string]: number } = {}
	for _, boxes in { shop.waiting, shop.carried, shop.workerBoxes } do
		for _, box in boxes do
			local productId, units = box:GetAttribute("ProductId"), box:GetAttribute("Units")
			if typeof(productId) == "string" and typeof(units) == "number" then
				stock[productId] = (stock[productId] or 0) + units
			end
		end
	end
	for _, order in shop.incoming do
		local product = Products.ById[order.productId]
		if product then
			stock[order.productId] = (stock[order.productId] or 0) + product.unitsPerBox
		end
	end
	-- and on its storage racks: stock the shop still has (BrokeService: a shop with stored boxes isn't stuck)
	for _, rack in PlacementService.GetRacks(player) do
		for _, stored in rack.stored do
			stock[stored.productId] = (stock[stored.productId] or 0) + stored.units
		end
	end
	return stock
end

-- One more box fits in the shop's shared spots (restockers taking a box off a storage rack: JobService)
function StockService.HasRoom(player: Player): boolean
	local shop = shops[player]
	return shop ~= nil and hasRoom(shop)
end

-- A box for a restocker's arms, made from one it took off a storage rack: it counts in the shop's shared spots like any
-- box in a worker's hands. Nil without room (check HasRoom before taking it off the rack)
function StockService.MakeWorkerBox(player: Player, productId: string, units: number): Part?
	local shop = shops[player]
	if not shop or not hasRoom(shop) or not Products.ById[productId] then
		return nil
	end
	local box = makeBox(shop, productId, units)
	setPromptEnabled(box, false)
	box.Parent = shop.plot.model
	table.insert(shop.workerBoxes, box)
	syncPad(shop)
	return box
end

-- Studio testing only (DevService /broke): every box gone, the ones on order too
function StockService.ClearForTesting(player: Player)
	local shop = shops[player]
	if not shop then
		return
	end
	for _, boxes in { shop.waiting, shop.carried, shop.workerBoxes } do
		for _, box in boxes do
			box:Destroy()
		end
		table.clear(boxes)
	end
	table.clear(shop.incoming)
	syncCarry(shop)
	syncPad(shop)
end

-- Worker API (JobService restockers) -------------------------------------------------------------

-- Boxes waiting on the delivery pad, in pad order
function StockService.GetWaitingBoxes(player: Player): { Part }
	local shop = shops[player]
	return if shop then table.clone(shop.waiting) else {}
end

-- A worker picks a box off the pad; false if it's gone (the owner took it first)
function StockService.TakeWaitingBox(player: Player, box: Part): boolean
	local shop = shops[player]
	local index = if shop then table.find(shop.waiting, box) else nil
	if not shop or not index then
		return false
	end
	table.remove(shop.waiting, index)
	table.insert(shop.workerBoxes, box)
	setPromptEnabled(box, false)
	layoutWaiting(shop)
	return true
end

-- A worker's box goes back on the pad (dropped, or it couldn't place the rest)
function StockService.ReturnBox(player: Player, box: Part)
	local shop = shops[player]
	local index = if shop then table.find(shop.workerBoxes, box) else nil
	if not shop or not index then
		return
	end
	table.remove(shop.workerBoxes, index)
	detachFromCharacter(box)
	setPromptEnabled(box, true)
	table.insert(shop.waiting, box)
	layoutWaiting(shop)
end

-- Units a worker stocked from its box; the box is used up at 0
function StockService.ConsumeUnits(player: Player, box: Part, units: number)
	local shop = shops[player]
	local index = if shop then table.find(shop.workerBoxes, box) else nil
	local available = box:GetAttribute("Units")
	if not shop or not index or typeof(available) ~= "number" then
		return
	end
	local left = available - units
	if left > 0 then
		box:SetAttribute("Units", left)
	else
		table.remove(shop.workerBoxes, index)
		box:Destroy()
		syncPad(shop)
	end
end

-- An order went through (the tutorial's "order stock" step)
function StockService.OnOrdered(callback: (player: Player, productId: string) -> ())
	table.insert(orderedHandlers, callback)
end

-- A shelf got stock from a carried box (the tutorial's "stock the rack" step)
function StockService.OnStocked(callback: (player: Player, productId: string) -> ())
	table.insert(stockedHandlers, callback)
end

-- A delivered box is waiting for a shelf: on the pad or carried (Pish's stuck helper points at the shelf)
function StockService.HasWaitingBox(player: Player): boolean
	local shop = shops[player]
	return shop ~= nil and (#shop.waiting > 0 or #shop.carried > 0)
end

-- Some shelf has stock on it (no point telling a stocked shop to order)
function StockService.ShelvesStocked(player: Player): boolean
	for _, shelf in PlacementService.GetShelves(player) do
		if shelf.units > 0 then
			return true
		end
	end
	return false
end

function StockService.Start()
	for _, plot in PlotService.GetPlots() do
		local prompt = makePrompt(plot.computer, "Order stock", "Computer")
		prompt.Triggered:Connect(function(player)
			onComputerUsed(player, plot)
		end)
	end

	Remotes.OrderCart.OnServerEvent:Connect(onOrderCart)
	Remotes.StockShelf.OnServerEvent:Connect(onStockShelf)
	Remotes.DropBox.OnServerEvent:Connect(onDropBox)
	Remotes.BagBox.OnServerEvent:Connect(onBagBox)
	Remotes.ShopBagStock.OnServerEvent:Connect(onShopBagStock)
	Remotes.RemoveStock.OnServerEvent:Connect(onRemoveStock)
	Remotes.StoreBox.OnServerEvent:Connect(onStoreBox)
	Remotes.TakeStoredBox.OnServerEvent:Connect(onTakeStoredBox)
	DataService.Register({ name = "StockService", load = load, save = save, unload = unload })
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return StockService
