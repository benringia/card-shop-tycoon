--!strict
-- NPC customers: spawn on the street, walk to stocked shelves, decide to buy based on price,
-- sometimes look at the Glass Showcase for a single card, queue at the register, and leave if they
-- wait too long. Each customer runs as one thread.
-- RegisterService handles checkout via OnReachedCounter / OnLeftQueue / CompletePurchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Packs = require(Config:WaitForChild("Packs"))
local Pricing = require(Config:WaitForChild("Pricing"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Products = require(Config:WaitForChild("Products"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local CollectorRules = require(Shared:WaitForChild("Util"):WaitForChild("CollectorRules"))
local CustomerTypes = require(Shared:WaitForChild("Util"):WaitForChild("CustomerTypes"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local NpcMotion = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("NpcMotion"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local ShowcaseService = require(Services:WaitForChild("ShowcaseService"))

type Plot = typeof(PlotService.GetPlots()[1])
type PlacedShelf = typeof(PlacementService.GetShelves((nil :: any))[1])
type DisplayedCard = PlacementService.DisplayedCard

-- Products have productId; single cards have card + slot. Both carry units and unitPrice for checkout.
type Item = {
	shelfUid: string,
	units: number,
	unitPrice: number, -- price when picked up, so later price changes don't affect this sale
	productId: string?,
	card: DisplayedCard?,
	slot: number?,
}

export type Customer = {
	plot: Plot,
	owner: Player,
	kind: string, -- its type (Config/Customers TYPES: plain, kid, collector, bargain, bigSpender)
	wanted: string?, -- a collector's card id (model attribute WantedCard, shown in a thought bubble by the client)
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	items: { Item },
	alive: boolean,
	thread: thread?,
	lastScanAt: number?, -- set by RegisterService on each scan; switches to checkout patience
}

type CustomerCallback = (customer: Customer) -> ()

type PlotState = {
	customers: { Customer },
	queue: { Customer },
	nextSpawnAt: number,
}

local CustomerService = {}

local plotStates: { [Plot]: PlotState } = {}
local rng = Random.new()
local customersFolder: Folder
local reachedCounterCallbacks: { CustomerCallback } = {}
local leftQueueCallbacks: { CustomerCallback } = {}
-- How each visit went, for the shop rating (RatingService): "paid", "annoyed", "gaveUp", "noStock", "happyMoment"
local outcomeCallbacks: { (owner: Player, outcome: string) -> () } = {}

local function fireOutcome(owner: Player, outcome: string)
	for _, callback in outcomeCallbacks do
		task.spawn(callback, owner, outcome)
	end
end

local function runCallbacks(callbacks: { CustomerCallback }, customer: Customer)
	for _, callback in callbacks do
		task.spawn(callback, customer)
	end
end

local function getPlotState(plot: Plot): PlotState
	local state = plotStates[plot]
	if not state then
		state = { customers = {}, queue = {}, nextSpawnAt = 0 }
		plotStates[plot] = state
	end
	return state
end

local function floorTop(plot: Plot): number
	return plot.floor.Position.Y + PlotConfig.FLOOR_THICKNESS / 2
end

-- On the street in front of the shop, turned 180° to face it
local function getEntryCFrame(plot: Plot): CFrame
	return plot.floor.CFrame
		* CFrame.new(0, 0, -PlotConfig.DEPTH / 2 - CustomerConfig.ENTRY_DISTANCE)
		* CFrame.Angles(0, math.pi, 0)
end

local function getShelfStandPoint(plot: Plot, shelf: PlacedShelf): Vector3
	local part = shelf.part
	local point = part.CFrame * CFrame.new(0, 0, -(part.Size.Z / 2 + CustomerConfig.SHELF_STAND_DISTANCE))
	return Vector3.new(point.X, floorTop(plot), point.Z)
end

-- Queue slot 1 is right at the counter; later slots line up toward the street
local function getQueuePoint(plot: Plot, index: number): Vector3
	local register = plot.register
	local offset = register.Size.Z / 2 + 1.5 + (index - 1) * CustomerConfig.QUEUE_SPACING
	local point = register.CFrame * CFrame.new(0, 0, -offset)
	return Vector3.new(point.X, floorTop(plot), point.Z)
end

-- Players walk through customers so nobody can push them around or block the queue
local function onCharacterAdded(character: Model)
	for _, descendant in character:GetDescendants() do
		NpcMotion.setGroup(descendant, NpcMotion.PLAYER_GROUP)
	end
	character.DescendantAdded:Connect(function(descendant)
		NpcMotion.setGroup(descendant, NpcMotion.PLAYER_GROUP)
	end)
end

local function pickColor(colors: { { number } }): Color3
	local rgb = colors[rng:NextInteger(1, #colors)]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A type's props (Config/Customers TYPES props): plain parts welded to a body part, sized with the rig
local function addProps(model: Model, props: { any }, scale: number)
	for _, prop in props do
		local base = model:FindFirstChild(prop.part)
		if not base or not base:IsA("BasePart") then
			continue
		end
		local part = Instance.new("Part")
		part.Name = "Prop"
		part.Shape = if prop.shape == "Ball" then Enum.PartType.Ball elseif prop.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		part.Size = Vector3.new(prop.size[1], prop.size[2], prop.size[3]) * scale
		part.Color = Color3.fromRGB(prop.color[1], prop.color[2], prop.color[3])
		part.Material = Enum.Material.SmoothPlastic
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = base.CFrame * CFrame.new(Vector3.new(prop.offset[1], prop.offset[2], prop.offset[3]) * scale)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
end

-- Today's blocky customer in its type's clothes, size and props (spec 2026-11-06-customers-design, option B)
local function createModel(spawnCFrame: CFrame, kind: string): Model
	local spec = CustomerConfig.TYPES[kind] or CustomerConfig.TYPES.plain
	local colors = spec.colors
	local description = Instance.new("HumanoidDescription")
	local skin = pickColor(CustomerConfig.SKIN_COLORS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = pickColor(if colors then colors.torso else CustomerConfig.CLOTHES_COLORS)
	local legs = pickColor(if colors then colors.legs else CustomerConfig.CLOTHES_COLORS)
	description.LeftLegColor = legs
	description.RightLegColor = legs
	local scale = spec.scale or 1
	if scale ~= 1 then
		description.HeightScale = scale
		description.WidthScale = scale
		description.DepthScale = scale
		description.HeadScale = scale
	end

	local model = NpcMotion.createRig(description, "Customer", spawnCFrame)
	model:SetAttribute("CustomerType", kind)
	addProps(model, spec.props, scale)
	return model
end

-- A mood icon over the customer's head (Config/UIIcons name), or the text itself if there's no such icon
local function showBubble(customer: Customer, icon: string)
	local head = customer.model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(56, 56)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80

	local image = UIIcons[icon]
	if image then
		local picture = Instance.new("ImageLabel")
		picture.Size = UDim2.fromScale(1, 1)
		picture.BackgroundTransparency = 1
		picture.Image = image
		picture.Parent = gui
	else
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Text = icon
		label.Parent = gui
	end

	gui.Parent = head
	task.delay(CustomerConfig.BUBBLE_SECONDS, function()
		gui:Destroy()
	end)
end

-- Walks along a computed path; falls back to a straight line if no path is found
local function walkTo(customer: Customer, target: Vector3): boolean
	return NpcMotion.walkTo(customer.humanoid, customer.root, target, CustomerConfig.PATH_AGENT, function()
		return customer.alive
	end)
end

-- Puts picked items back on the shelves they came from (customer left without paying)
local function restoreItems(customer: Customer)
	for _, item in customer.items do
		local card, productId = item.card, item.productId
		if card then
			ShowcaseService.ReturnFromCustomer(customer.owner, item.shelfUid, item.slot or 1, card)
		elseif productId then
			local shelf = PlacementService.GetShelf(customer.owner, item.shelfUid)
			if shelf then
				PlacementService.AddStock(shelf, productId, item.units)
			end
		end
	end
	table.clear(customer.items)
end

-- Every way out of the queue goes through here so RegisterService can clear the counter straight away
local function removeFromQueue(customer: Customer)
	local state = getPlotState(customer.plot)
	local index = table.find(state.queue, customer)
	if not index then
		return
	end
	table.remove(state.queue, index)
	runCallbacks(leftQueueCallbacks, customer)
end

local function despawn(customer: Customer, restore: boolean)
	if not customer.alive then
		return
	end
	customer.alive = false
	if restore then
		restoreItems(customer)
	end

	removeFromQueue(customer)
	local state = getPlotState(customer.plot)
	local index = table.find(state.customers, customer)
	if index then
		table.remove(state.customers, index)
	end
	customer.model:Destroy()

	local thread = customer.thread
	if thread and thread ~= coroutine.running() then
		task.cancel(thread)
	end
end

local function leaveShop(customer: Customer)
	walkTo(customer, getEntryCFrame(customer.plot).Position)
	despawn(customer, true)
end

-- The cheapest pack (a product that opens into cards, Config/Packs) this shop has unlocked
local function cheapestPack(level: number): string?
	local best: any = nil
	for _, product in Products.List do
		if product.unlockLevel <= level and Packs.ById[product.id] and (not best or product.marketPrice < best.marketPrice) then
			best = product
		end
	end
	return if best then best.id else nil
end

local findStockedShelf: (owner: Player, productId: string) -> PlacedShelf?

-- Products this shop has unlocked, so customers only ask for things the owner could stock. A kid wants a pack or two,
-- a big spender a booster box when one is stocked (else a stack of packs)
local function pickShoppingList(owner: Player, kind: string): { [string]: number }
	local level = EconomyService.GetLevel(owner)
	if kind == "kid" or kind == "bigSpender" then
		local list: { [string]: number } = {}
		local box = CustomerConfig.BIG_SPENDER.box
		local boxProduct = Products.ById[box]
		if kind == "bigSpender" and boxProduct and boxProduct.unlockLevel <= level and findStockedShelf(owner, box) then
			list[box] = 1
			return list
		end
		local pack = cheapestPack(level)
		if pack then
			local units = if kind == "kid" then CustomerConfig.KID.units else CustomerConfig.BIG_SPENDER.packs
			list[pack] = rng:NextInteger(units[1], units[2])
		end
		return list
	end
	local unlocked = {}
	for _, product in Products.List do
		if product.unlockLevel <= level then
			table.insert(unlocked, product.id)
		end
	end

	local list: { [string]: number } = {}
	if #unlocked == 0 then
		return list
	end
	for _ = 1, rng:NextInteger(CustomerConfig.ITEMS_MIN, CustomerConfig.ITEMS_MAX) do
		local productId = unlocked[rng:NextInteger(1, #unlocked)]
		list[productId] = (list[productId] or 0) + 1
	end
	return list
end

findStockedShelf = function(owner: Player, productId: string): PlacedShelf?
	local candidates = {}
	for _, shelf in PlacementService.GetShelves(owner) do
		if shelf.productId == productId and shelf.units > 0 then
			table.insert(candidates, shelf)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Turns a customer (standing still) to look at a shelf they're browsing
local function faceShelf(customer: Customer, shelf: PlacedShelf)
	if not customer.alive then
		return
	end
	local root = customer.root
	local toShelf = shelf.part.Position - root.Position
	local flat = Vector3.new(toShelf.X, 0, toShelf.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

-- Shelves a customer may buy from and that have something on them: stocked product shelves and Glass
-- Showcases with cards. Collector Cases (players only) and the Card Condenser are never browsed.
local function getBrowsableShelves(owner: Player): { PlacedShelf }
	local result: { PlacedShelf } = {}
	for _, shelf in PlacementService.GetShelves(owner) do
		local kind = shelf.def.kind
		if (kind == "Products" and shelf.units > 0) or (kind == "CustomerCards" and next(shelf.cards) ~= nil) then
			table.insert(result, shelf)
		end
	end
	return result
end

-- Walks to a shelf with the product and decides whether to take it at the owner's price
local function shopFor(customer: Customer, productId: string, wanted: number, visited: { [string]: boolean }): boolean
	local shelf = findStockedShelf(customer.owner, productId)
	if not shelf then
		return false
	end
	visited[shelf.uid] = true
	walkTo(customer, getShelfStandPoint(customer.plot, shelf))
	faceShelf(customer, shelf)
	if not customer.alive then
		return true
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)

	local product = Products.ById[productId]
	local price = PricingService.GetPrice(customer.owner, productId)
	-- By its type (Util/CustomerTypes): bargain hunters and big spenders still buy a band higher than the rest
	if CustomerTypes.outOfReach(CustomerConfig, customer.kind, price, product.marketPrice, Pricing.BUY_BANDS) then
		showBubble(customer, CustomerConfig.BUBBLE_ANNOYED)
		fireOutcome(customer.owner, "annoyed")
		return true
	end
	-- Haggle (Shade creature summoned): more willing to buy at the owner's price
	local haggle = PartyService.GetPerk(customer.owner, "Haggle")
	if not CustomerTypes.buys(CustomerConfig, customer.kind, price, product.marketPrice, rng:NextNumber(), haggle, Pricing.BUY_BANDS) then
		return true
	end

	-- Someone else may have emptied it while this customer walked over
	local taken = PlacementService.TakeStock(shelf, wanted)
	if taken > 0 then
		table.insert(customer.items, { shelfUid = shelf.uid, productId = productId, units = taken, unitPrice = price })
	end
	return true
end

-- What a displayed copy is worth: a levelled card against its own (higher) value
local function displayedWorth(displayed: DisplayedCard): number
	local level = if displayed.beast then displayed.beast.level else 1
	local stars = if displayed.beast then displayed.beast.stars else BeastRules.START_STARS
	return CardRules.getMarketValue(Cards.ById[displayed.cardId], displayed.foil, level, stars, displayed.grade)
end

-- Looks at one card in a Glass Showcase and maybe takes it, judged on price like packs.
-- Returns whether there was a card to look at.
local function shopForCard(customer: Customer, visited: { [string]: boolean }): boolean
	local shelf, slot = ShowcaseService.PickCardForCustomer(customer.owner)
	if not shelf or not slot then
		return false
	end
	visited[shelf.uid] = true
	walkTo(customer, getShelfStandPoint(customer.plot, shelf))
	faceShelf(customer, shelf)
	if not customer.alive then
		return true
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)

	-- The case may have been sold or the card taken while this customer walked over
	local displayed = shelf.cards[slot]
	if PlacementService.GetShelf(customer.owner, shelf.uid) ~= shelf or not displayed then
		return true
	end
	local band = PriceRules.getBand(displayed.price, displayedWorth(displayed))
	if not band then
		showBubble(customer, CustomerConfig.BUBBLE_ANNOYED)
		fireOutcome(customer.owner, "annoyed")
		return true
	end
	-- Haggle (Shade creature summoned): more willing to buy at the owner's price
	if rng:NextNumber() > math.min(1, band.chance * (1 + PartyService.GetPerk(customer.owner, "Haggle"))) then
		return true
	end

	local taken = ShowcaseService.TakeForCustomer(shelf, slot)
	if taken then
		table.insert(customer.items, { shelfUid = shelf.uid, units = 1, unitPrice = taken.price, card = taken, slot = slot })
	end
	return true
end

-- The Glass Showcases in this shop that still exist, in a random order
local function glassShowcases(owner: Player): { PlacedShelf }
	local result: { PlacedShelf } = {}
	for _, shelf in PlacementService.GetShelves(owner) do
		if shelf.def.kind == "CustomerCards" then
			table.insert(result, rng:NextInteger(1, #result + 1), shelf)
		end
	end
	return result
end

-- At the showcase holding the wanted card: takes it if it's still there at a price the collector pays
local function tryWantedCard(customer: Customer, shelf: PlacedShelf, slot: number, wanted: string): boolean
	walkTo(customer, getShelfStandPoint(customer.plot, shelf))
	faceShelf(customer, shelf)
	if not customer.alive then
		return true
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)
	-- The owner may have moved, swapped or repriced it while the collector walked over
	local displayed = if PlacementService.GetShelf(customer.owner, shelf.uid) == shelf then shelf.cards[slot] else nil
	if not displayed or not CollectorRules.stillThere(displayed, wanted, displayedWorth(displayed), CustomerConfig) then
		return false
	end
	local taken = ShowcaseService.TakeForCustomer(shelf, slot)
	if not taken then
		return false
	end
	table.insert(customer.items, { shelfUid = shelf.uid, units = 1, unitPrice = taken.price, card = taken, slot = slot })
	return true
end

-- A collector walks the Glass Showcases looking for the one card they want (the owner can still put it out while they
-- look), buys it at up to the premium over its worth, or leaves disappointed
local function huntCard(customer: Customer, visited: { [string]: boolean })
	local wanted = customer.wanted
	if not wanted then
		return
	end
	local tours = glassShowcases(customer.owner)
	local index = 0
	while customer.alive do
		local shelf, slot = ShowcaseService.FindCardForCollector(customer.owner, wanted)
		if shelf and slot then
			visited[shelf.uid] = true
			if tryWantedCard(customer, shelf, slot, wanted) then
				return
			end
			break
		end
		index += 1
		local showcase = tours[index]
		if not showcase then
			break
		end
		visited[showcase.uid] = true
		walkTo(customer, getShelfStandPoint(customer.plot, showcase))
		faceShelf(customer, showcase)
		if not customer.alive then
			return
		end
		task.wait(CustomerConfig.BROWSE_SECONDS)
	end
	if not customer.alive then
		return
	end
	showBubble(customer, CustomerConfig.BUBBLE_DISAPPOINTED)
	fireOutcome(customer.owner, "noStock")
	task.wait(CustomerConfig.BUBBLE_SECONDS)
end

-- Something they wanted wasn't on the shelves: look at a few more shelves they haven't checked yet,
-- then show the "no stock" bubble so the owner sees the lost sale. In an empty shop, walk to the middle.
local function searchShelves(customer: Customer, visited: { [string]: boolean })
	local candidates: { PlacedShelf } = {}
	for _, shelf in getBrowsableShelves(customer.owner) do
		if not visited[shelf.uid] then
			table.insert(candidates, shelf)
		end
	end
	if #candidates == 0 and next(visited) == nil then
		local floor = customer.plot.floor.Position
		walkTo(customer, Vector3.new(floor.X, floorTop(customer.plot), floor.Z))
		if not customer.alive then
			return
		end
		task.wait(CustomerConfig.BROWSE_SECONDS)
	end
	for _ = 1, math.min(CustomerConfig.SEARCH_SHELVES, #candidates) do
		local shelf = table.remove(candidates, rng:NextInteger(1, #candidates)) :: PlacedShelf
		visited[shelf.uid] = true
		walkTo(customer, getShelfStandPoint(customer.plot, shelf))
		faceShelf(customer, shelf)
		if not customer.alive then
			return
		end
		task.wait(CustomerConfig.BROWSE_SECONDS)
	end
	showBubble(customer, CustomerConfig.BUBBLE_NO_STOCK)
	fireOutcome(customer.owner, "noStock")
	task.wait(CustomerConfig.BUBBLE_SECONDS)
end

-- Turns a customer standing in the queue toward the register (and whoever is behind it)
local function faceRegister(customer: Customer)
	local look = -customer.plot.register.CFrame.LookVector -- the queue is on the register's front side
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude == 0 then
		return
	end
	local root = customer.root
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude > 0 and facing.Unit:Dot(flat.Unit) > 0.99 then
		return -- already facing it; don't keep nudging
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

local function waitInQueue(customer: Customer)
	local state = getPlotState(customer.plot)
	table.insert(state.queue, customer)
	walkTo(customer, getQueuePoint(customer.plot, #state.queue))

	-- Calm (Tide creature summoned): customers wait longer
	local queueDeadline = os.clock() + CustomerConfig.QUEUE_PATIENCE * (1 + PartyService.GetPerk(customer.owner, "Calm"))
	local function getDeadline(): number
		local lastScanAt = customer.lastScanAt
		return if lastScanAt then lastScanAt + CustomerConfig.CHECKOUT_PATIENCE else queueDeadline
	end

	while customer.alive and os.clock() < getDeadline() do
		local index = table.find(state.queue, customer)
		if not index then
			return -- served by CompletePurchase
		end
		-- Step forward as people ahead leave
		local target = getQueuePoint(customer.plot, index)
		-- Flat distance: the root part floats above the floor-level target
		local offset = customer.root.Position - target
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance > CustomerConfig.COUNTER_ARRIVE_DISTANCE then
			customer.humanoid:MoveTo(target)
		else
			faceRegister(customer)
			if index == 1 then
				-- Fired every check while waiting at the counter; RegisterService ignores repeats
				runCallbacks(reachedCounterCallbacks, customer)
			end
		end
		task.wait(CustomerConfig.QUEUE_CHECK_INTERVAL)
	end
	if not customer.alive then
		return
	end

	removeFromQueue(customer)
	showBubble(customer, CustomerConfig.BUBBLE_GAVE_UP)
	fireOutcome(customer.owner, "gaveUp")
end

local function run(customer: Customer)
	local visited: { [string]: boolean } = {} -- shelf uids this customer has looked at
	local missing = false -- something on their list wasn't on any shelf
	-- Its type's icon pops over it as it walks in (the collector shows the card it wants instead, CustomerController)
	local icon = (CustomerConfig.TYPES[customer.kind] or {}).icon
	if icon then
		showBubble(customer, icon)
	end
	for productId, wanted in pickShoppingList(customer.owner, customer.kind) do
		if not shopFor(customer, productId, wanted, visited) then
			missing = true
		end
		if not customer.alive then
			return
		end
	end
	-- A collector hunts the card they want; of the rest only some care about singles
	if customer.wanted then
		huntCard(customer, visited)
	elseif rng:NextNumber() < ShowcaseConfig.CUSTOMER_CARD_CHANCE then
		shopForCard(customer, visited)
	end
	if not customer.alive then
		return
	end
	if missing then
		searchShelves(customer, visited)
		if not customer.alive then
			return
		end
	end

	if #customer.items == 0 then
		if customer.alive then
			leaveShop(customer)
		end
		return
	end

	waitInQueue(customer)
	if customer.alive then
		leaveShop(customer)
	end
end

-- Whether the owner shows a card to customers (a Glass Showcase holding one): collectors only come then
local function showsCards(owner: Player): boolean
	for _, shelf in PlacementService.GetShelves(owner) do
		if shelf.def.kind == "CustomerCards" and next(shelf.cards) ~= nil then
			return true
		end
	end
	return false
end

-- A collector's wanted card (Util/CollectorRules): half the time one the owner has (binder, beasts or on display)
local function pickWanted(owner: Player): string
	local ownedSet = CardService.GetOwnedCardIds(owner)
	for _, shelf in PlacementService.GetShelves(owner) do
		if PlacementService.IsCardCase(shelf) then
			for _, displayed in shelf.cards do
				ownedSet[displayed.cardId] = true
			end
		end
	end
	local owned: { string } = {}
	for cardId in ownedSet do
		table.insert(owned, cardId)
	end
	table.sort(owned)
	local all: { CollectorRules.CardEntry } = {}
	for _, card in Cards.BySet["First Spark"] do
		table.insert(all, { id = card.id, rarity = card.rarity })
	end
	return CollectorRules.wanted(CustomerConfig, owned, all, rng:NextNumber(), rng:NextNumber())
end

-- forcedKind / forcedWanted: Studio's /customer command only
local function spawnCustomer(plot: Plot, owner: Player, state: PlotState, forcedKind: string?, forcedWanted: string?)
	local entry = getEntryCFrame(plot)
	local kind = forcedKind
		or CustomerTypes.pick(CustomerConfig, { hasShowcase = showsCards(owner), shopLevel = EconomyService.GetLevel(owner) }, rng:NextNumber())
	local model = createModel(entry, kind)
	local wanted = if kind == "collector" then forcedWanted or pickWanted(owner) else nil
	if wanted then
		model:SetAttribute("WantedCard", wanted)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = CustomerConfig.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local customer: Customer = {
		plot = plot,
		owner = owner,
		kind = kind,
		wanted = wanted,
		model = model,
		humanoid = humanoid,
		root = root,
		items = {},
		alive = true,
		thread = nil,
		lastScanAt = nil,
	}
	table.insert(state.customers, customer)

	model.Parent = customersFolder
	-- Server-owned physics so clients can't fling or teleport customers
	root:SetNetworkOwner(nil)
	NpcMotion.setupAnimations(humanoid, CustomerConfig.WALK_ANIMATION, CustomerConfig.IDLE_ANIMATION)

	customer.thread = task.spawn(run, customer)

	-- Safety net for customers stuck on a bad path; queued customers are left to the queue timers
	local function checkLifetime()
		if not customer.alive then
			return
		end
		if table.find(state.queue, customer) then
			task.delay(CustomerConfig.LIFETIME_RECHECK, checkLifetime)
			return
		end
		despawn(customer, true)
	end
	task.delay(CustomerConfig.MAX_LIFETIME, checkLifetime)
end

local function onReleased(_player: Player, plot: Plot)
	local state = plotStates[plot]
	if not state then
		return
	end
	-- Copy first: despawn removes from the list
	for _, customer in table.clone(state.customers) do
		despawn(customer, false)
	end
	plotStates[plot] = nil
end

local function spawnTick()
	local now = os.clock()
	for _, plot in PlotService.GetPlots() do
		local owner = plot.owner
		if not owner then
			continue
		end
		local state = getPlotState(plot)
		if state.nextSpawnAt == 0 then
			state.nextSpawnAt = now + CustomerConfig.FIRST_SPAWN_DELAY
		elseif now >= state.nextSpawnAt and #state.customers < CustomerConfig.MAX_PER_PLOT then
			-- Hype (Ember creature summoned): customers arrive more often
			local interval = rng:NextNumber(CustomerConfig.SPAWN_INTERVAL_MIN, CustomerConfig.SPAWN_INTERVAL_MAX)
			state.nextSpawnAt = now + interval / (1 + PartyService.GetPerk(owner, "Hype"))
			task.spawn(spawnCustomer, plot, owner, state)
		end
	end
end

-- Fires repeatedly while the front customer stands at the counter, ready to be checked out
function CustomerService.OnReachedCounter(callback: CustomerCallback)
	table.insert(reachedCounterCallbacks, callback)
end

-- Fires when a customer leaves the queue for any reason: paid, gave up, or removed
function CustomerService.OnLeftQueue(callback: CustomerCallback)
	table.insert(leftQueueCallbacks, callback)
end

-- A big spender tips a share of the total when every product was at or under market (Config/Customers BIG_SPENDER)
local function tipFor(customer: Customer): number
	if customer.kind ~= "bigSpender" then
		return 0
	end
	local total = 0
	for _, item in customer.items do
		local product = if item.productId then Products.ById[item.productId] else nil
		if product and item.unitPrice > product.marketPrice + 1e-9 then
			return 0
		end
		total += item.unitPrice * item.units
	end
	return math.round(total * CustomerConfig.BIG_SPENDER.tip * 100) / 100
end

-- The customer paid: their items are sold (not returned to shelves) and they head out happy
function CustomerService.CompletePurchase(customer: Customer)
	if not customer.alive then
		return
	end
	local tip = tipFor(customer)
	if tip > 0 then
		EconomyService.AddCash(customer.owner, tip)
		Remotes.Notify:FireClient(customer.owner, string.format("Tip! +$%.2f", tip), false, "side")
	end
	table.clear(customer.items)
	removeFromQueue(customer)
	showBubble(customer, CustomerConfig.BUBBLE_HAPPY)
	fireOutcome(customer.owner, "paid")
end

-- Studio's /customer command: a customer of this type now (a collector wanting `wanted` when given)
function CustomerService.SpawnForTest(owner: Player, kind: string, wanted: string?): boolean
	local plot = PlotService.GetPlot(owner)
	if not plot or not CustomerConfig.TYPES[kind] then
		return false
	end
	task.spawn(spawnCustomer, plot, owner, getPlotState(plot), kind, wanted)
	return true
end

-- Each visit's outcome ("paid", "annoyed", "gaveUp", "noStock", "happyMoment"), for the shop rating
function CustomerService.OnOutcome(callback: (owner: Player, outcome: string) -> ())
	table.insert(outcomeCallbacks, callback)
end

function CustomerService.Start()
	NpcMotion.setupCollisionGroups()

	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = workspace

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(onCharacterAdded)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end

	PlotService.OnReleased(onReleased)
	-- When the owner leaves, customers put picked-up stock and cards back first, so they're saved
	DataService.OnBeforeLeave(function(owner: Player)
		local plot = PlotService.GetPlot(owner)
		local state = if plot then plotStates[plot] else nil
		if state then
			for _, customer in table.clone(state.customers) do
				despawn(customer, true)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CustomerConfig.SPAWN_CHECK_INTERVAL)
			spawnTick()
		end
	end)
end

return CustomerService
