--!strict
-- Checkout at the register: the front customer's items appear on the counter, the owner taps each
-- one to scan it, then charges the total. A cashier worker (JobService) can do the same through the
-- Worker API below; both end in completeSale. Cash and XP go through EconomyService.
-- A bargain hunter, once everything is scanned, offers under the total instead (Util/HaggleRules): the owner answers
-- through OfferService (OnHaggle / SettleHaggle); a cashier settles halfway. After each sale OnSaleCompleted fires
-- (a kid rips their pack there).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegisterConfig = require(Shared:WaitForChild("Config"):WaitForChild("Register"))
local CustomerConfig = require(Shared:WaitForChild("Config"):WaitForChild("Customers"))
local HaggleRules = require(Shared:WaitForChild("Util"):WaitForChild("HaggleRules"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Packs = require(Shared:WaitForChild("Config"):WaitForChild("Packs"))
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local PackModels = require(Shared:WaitForChild("Util"):WaitForChild("PackModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CustomerService = require(Services:WaitForChild("CustomerService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Customer = CustomerService.Customer
type Plot = typeof(PlotService.GetPlots()[1])

type Checkout = {
	customer: Customer,
	pending: { [BasePart]: number }, -- unscanned counter items → unit price
	remaining: number,
	count: number, -- items at the start of checkout
	total: number, -- sum of scanned items
	haggleOffer: number?, -- a bargain hunter's offer once everything is scanned
	haggling: boolean, -- the owner is answering that offer (OfferService)
}

type HaggleCallback = (plot: Plot, customer: Customer, offer: number, total: number) -> ()
type SaleCallback = (customer: Customer, bought: { [string]: number }, byWorker: boolean) -> ()

local RegisterService = {}

-- A pack model lying on its back on the counter: front up, its top toward the customer (reads right for the cashier)
local FACE_UP = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))

local checkouts: { [Plot]: Checkout } = {}
local allowScan = RateLimiter.new(RegisterConfig.SCAN_COOLDOWN)
local allowCharge = RateLimiter.new(RegisterConfig.CHARGE_COOLDOWN)
local rng = Random.new()
local haggleCallbacks: { HaggleCallback } = {}
local saleCallbacks: { SaleCallback } = {}

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function sendUpdate(checkout: Checkout)
	Remotes.CheckoutUpdate:FireClient(checkout.customer.owner, checkout.total, checkout.remaining)
end

-- Owner must be close to the register and on the staff side (behind the counter)
local function isBehindCounter(player: Player, plot: Plot): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local register = plot.register
	local localPos = register.CFrame:PointToObjectSpace(root.Position)
	return localPos.Z > 0 and (root.Position - register.Position).Magnitude <= RegisterConfig.REACH
end

local function playScanSound(plot: Plot)
	if RegisterConfig.SCAN_SOUND_ID == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = RegisterConfig.SCAN_SOUND_ID
	sound.Parent = plot.register
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function endCheckout(plot: Plot)
	local checkout = checkouts[plot]
	if not checkout then
		return
	end
	checkouts[plot] = nil
	for part in checkout.pending do
		part:Destroy()
	end
	if checkout.customer.owner.Parent then
		Remotes.CheckoutUpdate:FireClient(checkout.customer.owner, nil, 0)
	end
end

-- The owner answers a bargain hunter's offer (OfferService opens the panel); Charge waits until it's settled
local function openHaggle(plot: Plot, checkout: Checkout)
	local offer = checkout.haggleOffer
	if not offer or checkout.haggling then
		return
	end
	checkout.haggling = true
	for _, callback in haggleCallbacks do
		task.spawn(callback, plot, checkout.customer, offer, checkout.total)
	end
end

-- Scans one counter item: shared by the owner's taps and a cashier worker
local function scanItem(plot: Plot, checkout: Checkout, part: BasePart, byWorker: boolean)
	local unitPrice = checkout.pending[part]
	if not unitPrice then
		return
	end
	checkout.pending[part] = nil
	part:Destroy()
	checkout.remaining -= 1
	checkout.total = math.round((checkout.total + unitPrice) * 100) / 100
	checkout.customer.lastScanAt = os.clock()
	playScanSound(plot)
	sendUpdate(checkout)
	-- All scanned: a bargain hunter makes their offer (to the owner now; a cashier settles it when charging)
	if checkout.remaining == 0 and checkout.customer.kind == "bargain" and not checkout.haggleOffer then
		checkout.haggleOffer = HaggleRules.offer(CustomerConfig, checkout.total, rng:NextNumber())
		if not byWorker then
			openHaggle(plot, checkout)
		end
	end
end

-- Charges a fully scanned checkout at `total` (the scanned total, or a haggled price): shared by the owner and a
-- cashier worker
local function completeSale(checkout: Checkout, total: number, byWorker: boolean)
	local customer = checkout.customer
	local owner = customer.owner
	local bought: { [string]: number } = {}
	for _, item in customer.items do
		local productId = item.productId
		if productId then
			bought[productId] = (bought[productId] or 0) + item.units
		end
	end
	endCheckout(customer.plot)
	CustomerService.CompletePurchase(customer)
	if total > 0 then
		EconomyService.AddCash(owner, total)
	end
	EconomyService.AddXP(owner, math.max(RegisterConfig.MIN_XP_PER_SALE, math.round(total)))
	DataService.AddStat(owner, "customersServed", 1)
	DataService.AddStat(owner, "totalEarned", total)
	Remotes.Notify:FireClient(owner, string.format("Sale! +$%.2f", total), false, "side")
	for _, callback in saleCallbacks do
		task.spawn(callback, customer, bought, byWorker)
	end
end

local function onScan(player: Player, plot: Plot, part: BasePart)
	if not allowScan(player) then
		return
	end
	local checkout = checkouts[plot]
	if not checkout or checkout.customer.owner ~= player then
		return
	end
	local unitPrice = checkout.pending[part]
	if not unitPrice then
		return
	end
	if not isBehindCounter(player, plot) then
		notify(player, "Stand behind the register to scan.", true)
		return
	end
	scanItem(plot, checkout, part, false)
end

-- What a counter item looks like: a pack or deck box shows its 3D model (Util/PackModels) lying face up inside the
-- part, which turns invisible but stays the scan target; anything else is the part in its product's colour
local function dressItem(part: BasePart, productId: string?)
	local pack = if productId then Packs.ById[productId] else nil
	if not pack or not productId then
		local product = if productId then Products.ById[productId] else nil
		part.Color = if product then Color3.fromRGB(product.color[1], product.color[2], product.color[3]) else RegisterConfig.ITEM_COLOR
		return
	end
	local model = if pack.kind == "Deck" then PackModels.deckBox(productId) else PackModels.pack(productId, "Low")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	-- Fit it in the part lying down: its width across, its thickness up, its height along the counter's depth
	model:PivotTo(CFrame.new())
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * math.min(part.Size.X / size.X, part.Size.Y / size.Z, part.Size.Z / size.Y))
	local centre, fitted = model:GetBoundingBox()
	local onCounter = part.CFrame * CFrame.new(0, (fitted.Z - part.Size.Y) / 2, 0)
	model:PivotTo(onCounter * FACE_UP * CFrame.new(-centre.Position))
	model.Parent = part
	part.Transparency = 1
end

-- Lays one counter item per unit along the counter top, each clickable/tappable to scan.
-- Called repeatedly while the front customer waits, so it must be safe to repeat.
local function startCheckout(customer: Customer)
	local plot = customer.plot
	local existing = checkouts[plot]
	if existing and existing.customer == customer then
		return
	end
	-- Only the front customer calls this, so any other open checkout is stale
	if existing then
		endCheckout(plot)
	end
	if #customer.items == 0 then
		return
	end

	local prices: { number } = {}
	local products: { string | false } = {} -- each unit's product, false for a single card (keeps the array gapless)
	for _, item in customer.items do
		for _ = 1, item.units do
			table.insert(prices, item.unitPrice)
			table.insert(products, item.productId or false)
		end
	end

	local checkout: Checkout = { customer = customer, pending = {}, remaining = #prices, count = #prices, total = 0, haggling = false }
	checkouts[plot] = checkout

	local register = plot.register
	local size = RegisterConfig.ITEM_SIZE
	-- Along the counter's front edge, right of the register prop; the decor sits along the back (PlotService)
	local counter = Town.COUNTER
	local itemZ = PropFit.counterZ(register.Size.Z, size.Z, counter.PROP_DEPTH)
	local spanMin = counter.REGISTER.x + counter.REGISTER.width / 2 + counter.ITEM_GAP
	local xs = PropFit.itemXs(#prices, spanMin, register.Size.X / 2, size.X, RegisterConfig.ITEM_SPACING)
	for index, unitPrice in prices do
		local x = xs[index]
		local part = Instance.new("Part")
		part.Name = "CounterItem"
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.CFrame = register.CFrame * CFrame.new(x, (register.Size.Y + size.Y) / 2, itemZ)
		local productId = products[index]
		dressItem(part, if productId then productId else nil)

		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = RegisterConfig.REACH
		click.MouseClick:Connect(function(clickingPlayer)
			onScan(clickingPlayer, plot, part)
		end)
		click.Parent = part

		part.Parent = register
		checkout.pending[part] = unitPrice
	end

	sendUpdate(checkout)
end

local function chargeAsOwner(player: Player, checkout: Checkout)
	if checkout.remaining > 0 then
		notify(player, "Scan every item first.", true)
		return
	end
	if not isBehindCounter(player, checkout.customer.plot) then
		notify(player, "Stand behind the register to charge.", true)
		return
	end
	-- A bargain hunter answers Charge with their offer (a cashier scanned the last item before the owner stepped in)
	if checkout.haggling then
		notify(player, "Answer their offer first.", true)
		return
	elseif checkout.haggleOffer then
		openHaggle(checkout.customer.plot, checkout)
		return
	end
	completeSale(checkout, checkout.total, false)
end

local function onCharge(player: Player)
	if not allowCharge(player) then
		return
	end
	for _, checkout in checkouts do
		if checkout.customer.owner == player then
			chargeAsOwner(player, checkout)
			return
		end
	end
end

local function onCustomerLeftQueue(customer: Customer)
	local checkout = checkouts[customer.plot]
	if checkout and checkout.customer == customer then
		endCheckout(customer.plot)
	end
end

-- Worker API (JobService cashiers) ---------------------------------------------------------------

export type CheckoutInfo = { remaining: number, scanned: number }

-- The checkout at this plot's register, if a customer is being served
function RegisterService.GetCheckout(plot: Plot): CheckoutInfo?
	local checkout = checkouts[plot]
	if not checkout then
		return nil
	end
	return { remaining = checkout.remaining, scanned = checkout.count - checkout.remaining }
end

-- Scans one counter item as the owner would; false when there is nothing left to scan
function RegisterService.ScanNext(plot: Plot): boolean
	local checkout = checkouts[plot]
	local part = if checkout then next(checkout.pending) else nil
	if not checkout or not part then
		return false
	end
	scanItem(plot, checkout, part, true)
	return true
end

-- Charges the checkout once every item is scanned; false if there's nothing to charge. A cashier meets a bargain
-- hunter halfway between their offer and the total, and they take it.
function RegisterService.ChargeByWorker(plot: Plot): boolean
	local checkout = checkouts[plot]
	if not checkout or checkout.remaining > 0 then
		return false
	end
	local offer = checkout.haggleOffer
	completeSale(checkout, if offer then HaggleRules.cashierPrice(offer, checkout.total) else checkout.total, true)
	return true
end

-- The owner's answer to a bargain hunter's offer (OfferService): the price agreed, or nil for no deal (they put their
-- items back and leave). False when no haggle is open at this register.
function RegisterService.SettleHaggle(plot: Plot, price: number?): boolean
	local checkout = checkouts[plot]
	if not checkout or not checkout.haggling then
		return false
	end
	if price then
		completeSale(checkout, price, false)
	else
		endCheckout(plot)
		CustomerService.Refuse(checkout.customer)
	end
	return true
end

-- Studio's /serve: scans everything on the counter and presses Charge, as the owner (they must stand behind it)
function RegisterService.ServeForTest(player: Player): boolean
	local plot = PlotService.GetPlot(player)
	local checkout = if plot then checkouts[plot] else nil
	if not plot or not checkout then
		return false
	end
	for part in table.clone(checkout.pending) do
		scanItem(plot, checkout, part, false)
	end
	chargeAsOwner(player, checkout)
	return true
end

-- A bargain hunter made an offer the owner should answer
function RegisterService.OnHaggle(callback: HaggleCallback)
	table.insert(haggleCallbacks, callback)
end

-- After every sale, with what the customer bought (product id -> units) and whether a cashier rang it up
function RegisterService.OnSaleCompleted(callback: SaleCallback)
	table.insert(saleCallbacks, callback)
end

function RegisterService.IsOwnerAtRegister(player: Player, plot: Plot): boolean
	return isBehindCounter(player, plot)
end

function RegisterService.Start()
	CustomerService.OnReachedCounter(startCheckout)
	CustomerService.OnLeftQueue(onCustomerLeftQueue)
	Remotes.Charge.OnServerEvent:Connect(onCharge)
	Players.PlayerRemoving:Connect(function(player)
		for plot, checkout in checkouts do
			if checkout.customer.owner == player then
				endCheckout(plot)
			end
		end
	end)
end

return RegisterService
