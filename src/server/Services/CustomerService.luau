--!strict
-- NPC customers: spawn on the street, walk to stocked shelves, decide to buy based on price,
-- sometimes look at the Glass Showcase for a single card, queue at the register, and leave if they
-- wait too long. Each customer runs as one thread.
-- RegisterService handles checkout via OnReachedCounter / OnLeftQueue / CompletePurchase.
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Products = require(Config:WaitForChild("Products"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
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

local CUSTOMER_GROUP = "Customers"
local PLAYER_GROUP = "Players"

local CustomerService = {}

local plotStates: { [Plot]: PlotState } = {}
local rng = Random.new()
local customersFolder: Folder
local reachedCounterCallbacks: { CustomerCallback } = {}
local leftQueueCallbacks: { CustomerCallback } = {}

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

local function setupCollisionGroups()
	PhysicsService:RegisterCollisionGroup(CUSTOMER_GROUP)
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(CUSTOMER_GROUP, CUSTOMER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(CUSTOMER_GROUP, PLAYER_GROUP, false)
end

local function setGroup(instance: Instance, group: string)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = group
	end
end

-- Players walk through customers so nobody can push them around or block the queue
local function onCharacterAdded(character: Model)
	for _, descendant in character:GetDescendants() do
		setGroup(descendant, PLAYER_GROUP)
	end
	character.DescendantAdded:Connect(function(descendant)
		setGroup(descendant, PLAYER_GROUP)
	end)
end

local function pickColor(colors: { Color3 }): Color3
	return colors[rng:NextInteger(1, #colors)]
end

local function createModel(spawnCFrame: CFrame): Model
	local description = Instance.new("HumanoidDescription")
	local skin = pickColor(CustomerConfig.SKIN_COLORS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = pickColor(CustomerConfig.CLOTHES_COLORS)
	local legs = pickColor(CustomerConfig.CLOTHES_COLORS)
	description.LeftLegColor = legs
	description.RightLegColor = legs

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Customer"
	for _, descendant in model:GetDescendants() do
		setGroup(descendant, CUSTOMER_GROUP)
	end
	model:PivotTo(spawnCFrame + Vector3.new(0, 3, 0))
	return model
end

local function setupAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local walkAnimation = Instance.new("Animation")
	walkAnimation.AnimationId = CustomerConfig.WALK_ANIMATION
	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = CustomerConfig.IDLE_ANIMATION

	local walk = animator:LoadAnimation(walkAnimation)
	local idle = animator:LoadAnimation(idleAnimation)
	idle:Play()

	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				idle:Stop()
				walk:Play()
			end
		elseif not idle.IsPlaying then
			walk:Stop()
			idle:Play()
		end
	end)
end

local function showBubble(customer: Customer, text: string)
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

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	gui.Parent = head
	task.delay(CustomerConfig.BUBBLE_SECONDS, function()
		gui:Destroy()
	end)
end

local function moveDirect(customer: Customer, target: Vector3): boolean
	customer.humanoid:MoveTo(target)
	-- MoveToFinished fires false on its own after 8 seconds if the target isn't reached
	return customer.humanoid.MoveToFinished:Wait()
end

-- Walks along a computed path; falls back to a straight line if no path is found
local function walkTo(customer: Customer, target: Vector3): boolean
	local path = PathfindingService:CreatePath(CustomerConfig.PATH_AGENT)
	local ok = pcall(function()
		path:ComputeAsync(customer.root.Position, target)
	end)
	if not customer.alive then
		return false
	end
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return moveDirect(customer, target)
	end

	for _, waypoint in path:GetWaypoints() do
		if not customer.alive then
			return false
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			customer.humanoid.Jump = true
		end
		if not moveDirect(customer, waypoint.Position) then
			return false
		end
	end
	return true
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

-- Products this shop has unlocked, so customers only ask for things the owner could stock
local function pickShoppingList(owner: Player): { [string]: number }
	local level = EconomyService.GetLevel(owner)
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

local function findStockedShelf(owner: Player, productId: string): PlacedShelf?
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

-- Walks to a shelf with the product and decides whether to take it at the owner's price
local function shopFor(customer: Customer, productId: string, wanted: number): boolean
	local shelf = findStockedShelf(customer.owner, productId)
	if not shelf then
		return false
	end
	walkTo(customer, getShelfStandPoint(customer.plot, shelf))
	if not customer.alive then
		return true
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)

	local product = Products.ById[productId]
	local price = PricingService.GetPrice(customer.owner, productId)
	local band = PriceRules.getBand(price, product.marketPrice)
	if not band then
		showBubble(customer, CustomerConfig.BUBBLE_ANNOYED)
		return true
	end
	if rng:NextNumber() > band.chance then
		return true
	end

	-- Someone else may have emptied it while this customer walked over
	local taken = PlacementService.TakeStock(shelf, wanted)
	if taken > 0 then
		table.insert(customer.items, { shelfUid = shelf.uid, productId = productId, units = taken, unitPrice = price })
	end
	return true
end

-- Looks at one card in a Glass Showcase and maybe takes it, judged on price like packs.
-- Returns whether there was a card to look at.
local function shopForCard(customer: Customer): boolean
	local shelf, slot = ShowcaseService.PickCardForCustomer(customer.owner)
	if not shelf or not slot then
		return false
	end
	walkTo(customer, getShelfStandPoint(customer.plot, shelf))
	if not customer.alive then
		return true
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)

	-- The case may have been sold or the card taken while this customer walked over
	local displayed = shelf.cards[slot]
	if PlacementService.GetShelf(customer.owner, shelf.uid) ~= shelf or not displayed then
		return true
	end
	local card = Cards.ById[displayed.cardId]
	-- A levelled card is judged against its own (higher) value
	local level = if displayed.beast then displayed.beast.level else 1
	local stars = if displayed.beast then displayed.beast.stars else BeastRules.START_STARS
	local band = PriceRules.getBand(displayed.price, CardRules.getMarketValue(card, displayed.foil, level, stars))
	if not band then
		showBubble(customer, CustomerConfig.BUBBLE_ANNOYED)
		return true
	end
	if rng:NextNumber() > band.chance then
		return true
	end

	local taken = ShowcaseService.TakeForCustomer(shelf, slot)
	if taken then
		table.insert(customer.items, { shelfUid = shelf.uid, units = 1, unitPrice = taken.price, card = taken, slot = slot })
	end
	return true
end

-- Nothing they wanted was stocked: still walk in and look around so the owner sees the lost sale
local function browseEmptyShop(customer: Customer)
	local shelves = PlacementService.GetShelves(customer.owner)
	local target = if #shelves > 0
		then getShelfStandPoint(customer.plot, shelves[rng:NextInteger(1, #shelves)])
		else Vector3.new(customer.plot.floor.Position.X, floorTop(customer.plot), customer.plot.floor.Position.Z)
	walkTo(customer, target)
	if not customer.alive then
		return
	end
	task.wait(CustomerConfig.BROWSE_SECONDS)
	showBubble(customer, CustomerConfig.BUBBLE_NO_STOCK)
	task.wait(CustomerConfig.BUBBLE_SECONDS)
end

local function waitInQueue(customer: Customer)
	local state = getPlotState(customer.plot)
	table.insert(state.queue, customer)
	walkTo(customer, getQueuePoint(customer.plot, #state.queue))

	local queueDeadline = os.clock() + CustomerConfig.QUEUE_PATIENCE
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
		elseif index == 1 then
			-- Fired every check while waiting at the counter; RegisterService ignores repeats
			runCallbacks(reachedCounterCallbacks, customer)
		end
		task.wait(CustomerConfig.QUEUE_CHECK_INTERVAL)
	end
	if not customer.alive then
		return
	end

	removeFromQueue(customer)
	showBubble(customer, CustomerConfig.BUBBLE_GAVE_UP)
end

local function run(customer: Customer)
	local foundAny = false
	for productId, wanted in pickShoppingList(customer.owner) do
		if shopFor(customer, productId, wanted) then
			foundAny = true
		end
		if not customer.alive then
			return
		end
	end
	-- Only some customers care about singles
	if rng:NextNumber() < ShowcaseConfig.CUSTOMER_CARD_CHANCE and shopForCard(customer) then
		foundAny = true
	end
	if not customer.alive then
		return
	end

	if #customer.items == 0 then
		if not foundAny then
			browseEmptyShop(customer)
		end
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

local function spawnCustomer(plot: Plot, owner: Player, state: PlotState)
	local entry = getEntryCFrame(plot)
	local model = createModel(entry)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = CustomerConfig.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local customer: Customer = {
		plot = plot,
		owner = owner,
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
	setupAnimations(humanoid)

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
			state.nextSpawnAt = now
				+ rng:NextNumber(CustomerConfig.SPAWN_INTERVAL_MIN, CustomerConfig.SPAWN_INTERVAL_MAX)
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

-- The customer paid: their items are sold (not returned to shelves) and they head out happy
function CustomerService.CompletePurchase(customer: Customer)
	if not customer.alive then
		return
	end
	table.clear(customer.items)
	removeFromQueue(customer)
	showBubble(customer, CustomerConfig.BUBBLE_HAPPY)
end

function CustomerService.Start()
	setupCollisionGroups()

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
