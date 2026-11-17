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
local LevelMath = require(Shared:WaitForChild("Util"):WaitForChild("LevelMath"))
local CustomerConfig = require(Shared:WaitForChild("Config"):WaitForChild("Customers"))
local HaggleRules = require(Shared:WaitForChild("Util"):WaitForChild("HaggleRules"))
local PaymentRules = require(Shared:WaitForChild("Util"):WaitForChild("PaymentRules"))
local PaymentConfig = require(Shared:WaitForChild("Config"):WaitForChild("Payment"))
local RegisterBell = require(Shared:WaitForChild("Util"):WaitForChild("RegisterBell"))
local BellConfig = require(Shared:WaitForChild("Config"):WaitForChild("RegisterBell"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Packs = require(Shared:WaitForChild("Config"):WaitForChild("Packs"))
local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products"))
local Cards = require(Shared:WaitForChild("Config"):WaitForChild("Cards"))
local ShowcaseConfig = require(Shared:WaitForChild("Config"):WaitForChild("Showcase"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local PackModels = require(Shared:WaitForChild("Util"):WaitForChild("PackModels"))
local SleevePacket = require(Shared:WaitForChild("Util"):WaitForChild("SleevePacket"))
local BulkHandful = require(Shared:WaitForChild("Util"):WaitForChild("BulkHandful"))
local BrandBox = require(Shared:WaitForChild("Util"):WaitForChild("BrandBox"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CustomerService = require(Services:WaitForChild("CustomerService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local WildService = require(Services:WaitForChild("WildService"))

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
	lastProgressAt: number, -- its start, or its last scan (the bell rings when nobody scans: Util/RegisterBell)
	payment: Payment?, -- after Charge: how the customer pays, until the owner gets it right (Config/Payment)
	lines: { Line }, -- each counter item, for the register's scan list (RegisterStationController)
}

-- `product` its product id, or `card` a single card's id: the register's scan list shows its picture
type Line = { name: string, price: number, part: BasePart, product: string?, card: string? }

type Payment = {
	method: PaymentRules.Method,
	totalCents: number,
	givenCents: number, -- cash: what they handed over (card: the total)
	price: number, -- the sale's price in dollars (the total, or a haggled price)
}

type HaggleCallback = (plot: Plot, customer: Customer, offer: number, total: number) -> ()
type SaleCallback = (customer: Customer, bought: { [string]: number }, byWorker: boolean, total: number) -> ()

local RegisterService = {}

-- A pack model lying on its back on the counter: front up, its top toward the customer (reads right for the cashier)
local FACE_UP = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))

local checkouts: { [Plot]: Checkout } = {}
local allowScan = RateLimiter.new(RegisterConfig.SCAN_COOLDOWN)
local allowCharge = RateLimiter.new(RegisterConfig.CHARGE_COOLDOWN)
local allowAnswer = RateLimiter.new(PaymentConfig.ANSWER_COOLDOWN)
local allowMan = RateLimiter.new(0.5)
-- The owners manning their register in first person (owner 2026-11-16: "Man the cashier"; RegisterStationController):
-- scanning, Charge and paying happen only there
local manning: { [Player]: boolean } = {}
local manTries: { [Player]: number } = {} -- each ask to man or leave, so a wait for the first gives way to a later one
local rng = Random.new()
local haggleCallbacks: { HaggleCallback } = {}
local saleCallbacks: { SaleCallback } = {}

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- The running total, items left, and every item's name, price and whether it's scanned (the register's scan list)
local function sendUpdate(checkout: Checkout)
	local lines = {}
	for _, line in checkout.lines do
		table.insert(lines, { name = line.name, price = line.price, done = checkout.pending[line.part] == nil, product = line.product, card = line.card })
	end
	Remotes.CheckoutUpdate:FireClient(checkout.customer.owner, checkout.total, checkout.remaining, lines)
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

-- A one-shot at the register (heard round the counter, not across town)
local function playAtRegister(plot: Plot, id: string, volume: number)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = plot.register
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function playScanSound(plot: Plot)
	playAtRegister(plot, RegisterConfig.SCAN_SOUND_ID, RegisterConfig.SCAN_VOLUME)
end

local function playSaleSound(plot: Plot)
	for _, layer in RegisterConfig.SALE_SOUNDS do
		playAtRegister(plot, layer.id, layer.volume)
	end
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
		if checkout.payment then
			Remotes.PaymentStart:FireClient(checkout.customer.owner, nil)
		end
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
	checkout.lastProgressAt = os.clock()
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
	playSaleSound(customer.plot)
	CustomerService.CompletePurchase(customer)
	if total > 0 then
		EconomyService.AddCash(owner, total)
	end
	EconomyService.AddXP(owner, LevelMath.saleXp(total, RegisterConfig.MIN_XP_PER_SALE))
	DataService.AddStat(owner, "customersServed", 1)
	-- this visit's sales, for the register's idle screen ("Today: 4 sales · $14.51")
	owner:SetAttribute("RegisterSales", (tonumber(owner:GetAttribute("RegisterSales")) or 0) + 1)
	owner:SetAttribute("RegisterTaken", (tonumber(owner:GetAttribute("RegisterTaken")) or 0) + total)
	DataService.AddStat(owner, "totalEarned", total)
	Remotes.Notify:FireClient(owner, string.format("Sale! +$%.2f", total), false, "side")
	for _, callback in saleCallbacks do
		task.spawn(callback, customer, bought, byWorker, total)
	end
end

-- What the customer is buying, for the card machine's screen ("2 First Spark Booster Pack, 1 card")
local function itemsText(customer: Customer): string
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, item in customer.items do
		local product = if item.productId then Products.ById[item.productId] else nil
		local name = if product then product.name else "card"
		if not counts[name] then
			table.insert(order, name)
		end
		counts[name] = (counts[name] or 0) + item.units
	end
	local parts = {}
	for _, name in order do
		local count = counts[name]
		table.insert(parts, `{count} x {name}`)
	end
	return table.concat(parts, ", ")
end

local function sendPayment(checkout: Checkout)
	local payment = checkout.payment
	local owner = checkout.customer.owner
	if not payment or not owner.Parent then
		return
	end
	Remotes.PaymentStart:FireClient(owner, {
		method = payment.method,
		total = payment.totalCents,
		given = payment.givenCents,
		items = itemsText(checkout.customer),
	})
end

-- After Charge the customer pays (owner 2026-11-16, mockup approved): by card (you type the total) or cash (you count
-- the change); a free sale needs nothing. While you stand at the register paying, their patience holds
local function startPayment(checkout: Checkout, price: number)
	local totalCents = math.round(price * 100)
	if totalCents <= 0 then
		completeSale(checkout, price, false)
		return
	end
	local customer = checkout.customer
	-- Pish's first sale always pays cash: it teaches the drawer, the gold glow on the next note to give from the start
	-- (owner 2026-11-16: "include the use of cash register on pish's tutorial")
	local firstSale = customer.owner:GetAttribute("TutorialStep") == "ringUp"
	local method = if firstSale then "cash" else PaymentRules.method(PaymentConfig, customer.kind, rng:NextNumber())
	checkout.payment = {
		method = method,
		totalCents = totalCents,
		givenCents = if method == "cash" then PaymentRules.given(PaymentConfig, totalCents) else totalCents,
		price = price,
	}
	checkout.lastProgressAt = os.clock()
	sendPayment(checkout)
	task.spawn(function()
		while checkouts[customer.plot] == checkout and customer.alive do
			if isBehindCounter(customer.owner, customer.plot) then
				customer.lastScanAt = os.clock()
			end
			task.wait(PaymentConfig.HOLD_SECONDS)
		end
	end)
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
	if not manning[player] then
		notify(player, "Man the register to scan!", true)
		return
	end
	if not isBehindCounter(player, plot) then
		notify(player, "Stand behind the register to scan.", true)
		return
	end
	scanItem(plot, checkout, part, false)
end

-- The owner steps onto their register (first person) or off it. Only their own, from behind its counter
local function onMan(player: Player, on: unknown)
	-- leaving is never held back (only stepping on is rate limited): a Leave dropped here kept you "on" it
	if typeof(on) ~= "boolean" or (on and not allowMan(player)) then
		return
	end
	local try = (manTries[player] or 0) + 1
	manTries[player] = try
	if not on then
		manning[player] = nil
		player:SetAttribute("ManningRegister", nil)
		return
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	-- the client steps you behind the counter as it asks: give that move a moment to get here (Config/Register MAN_GRACE)
	local deadline = os.clock() + RegisterConfig.MAN_GRACE
	while not isBehindCounter(player, plot) and os.clock() < deadline and manTries[player] == try and player.Parent do
		task.wait(0.1)
	end
	if manTries[player] ~= try or not player.Parent then
		return -- left (or asked again) meanwhile
	end
	if not isBehindCounter(player, plot) then
		notify(player, "Stand behind your register to man it.", true)
		return
	end
	manning[player] = true
	player:SetAttribute("ManningRegister", true)
	local checkout = checkouts[plot]
	if checkout then
		sendUpdate(checkout) -- what's on the counter right now, for its screen
		if checkout.payment then
			sendPayment(checkout)
		end
	end
end

-- What a counter item looks like (PropFit.counterLook): a pack, deck box or sleeve packet lies face up inside the part
-- (its 3D model, Util/PackModels; a packet, Util/SleevePacket), which turns invisible but stays the scan target; a
-- booster box is the part itself, sized like one and printed like its delivery case (Util/BrandBox); anything else is
-- the part in its product's colour. `index`: the item's place in the row (each packet the next sleeve colour)
local function dressItem(part: BasePart, productId: string?, index: number)
	local product = if productId then Products.ById[productId] else nil
	local look = if product then PropFit.counterLook(product.stockLook, Packs.ById[product.id] ~= nil) else "block"
	if not product or look == "block" then
		part.Color = if product then Color3.fromRGB(product.color[1], product.color[2], product.color[3]) else RegisterConfig.ITEM_COLOR
		return
	end
	if look == "booster" then
		-- standing on the counter, as big as the slot's footprint allows
		local box = Town.SHELF_STOCK.BOOSTERS
		local slot = part.Size
		local scale = math.min(slot.X / box.WIDTH, slot.Z / box.DEPTH)
		part.Size = Vector3.new(box.WIDTH, box.HEIGHT, box.DEPTH) * scale
		part.CFrame = part.CFrame * CFrame.new(0, (part.Size.Y - slot.Y) / 2, 0)
		BrandBox.draw(part, product, nil, box.PIXELS_PER_STUD)
		return
	end
	if look == "bulk" then
		-- a handful of card backs, already lying flat: fitted to the slot, on the counter (Util/BulkHandful)
		local handful = BulkHandful.build(nil, index)
		local _, size = handful:GetBoundingBox()
		handful:ScaleTo(math.min(part.Size.X / size.X, part.Size.Z / size.Z) * 0.9)
		handful:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0))
		handful.Parent = part
		part.Transparency = 1
		return
	end
	local model = if look == "sleeves"
		then SleevePacket.build(SleevePacket.color(index), Color3.fromRGB(product.color[1], product.color[2], product.color[3]))
		elseif look == "deck" then PackModels.deckBox(product.id)
		else PackModels.pack(product.id, "Low")
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

-- A card from the Glass Showcase on the counter (owner 2026-11-16: "cards from the glasscase should have a model in
-- cashiers too with all the effects"): a card part like the case's, its face up and its top away from the cashier, with
-- the case card's attributes, so every client draws its face, halo, sparkles and a Legendary's aura on it and plays a
-- listing burst as it lands (CardEffectsController), scaled to fit the counter slot (`slot`: Config/Register ITEM_SIZE)
local FACE_UP_AWAY = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
local function dressCard(part: BasePart, card: any, unitPrice: number, slot: Vector3, at: CFrame)
	local cardSize = ShowcaseConfig.CARD_SIZE
	local fit = math.min(slot.X / cardSize.X, slot.Z / cardSize.Y)
	part.Size = cardSize * Vector3.new(fit, fit, 1)
	part.CFrame = at * CFrame.new(0, (part.Size.Z - slot.Y) / 2, 0) * FACE_UP_AWAY
	part.Color = Color3.fromRGB(30, 26, 40)
	part.Material = Enum.Material.SmoothPlastic
	local beast = card.beast
	part:SetAttribute("CardId", card.cardId)
	part:SetAttribute("Foil", card.foil == true)
	part:SetAttribute("Grade", card.grade)
	part:SetAttribute("Level", if beast then beast.level else 1)
	part:SetAttribute("Stars", if beast then beast.stars else BeastRules.START_STARS)
	part:SetAttribute("Price", unitPrice)
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
	local names: { string } = {}
	local cardIds: { string | false } = {}
	local cardInfos: { any } = {} -- each unit's displayed card (false for a product), for its look on the counter
	for _, item in customer.items do
		local product = if item.productId then Products.ById[item.productId] else nil
		local card = if item.card then Cards.ById[item.card.cardId] else nil
		local name = if product then product.name elseif card then card.name else "Card"
		for _ = 1, item.units do
			table.insert(prices, item.unitPrice)
			table.insert(products, item.productId or false)
			table.insert(names, name)
			table.insert(cardIds, if item.card then item.card.cardId else false)
			table.insert(cardInfos, item.card or false)
		end
	end

	local checkout: Checkout = { customer = customer, pending = {}, remaining = #prices, count = #prices, total = 0, haggling = false, lastProgressAt = os.clock(), lines = {} }
	checkouts[plot] = checkout
	-- The bell (owner 2026-11-12: "when a customer is at the cashier and there's no one there. play a 'Ding' sound then
	-- notification"): while this checkout lasts, nobody scanning and the owner away from the counter, it rings on their
	-- screen (Util/RegisterBell)
	task.spawn(function()
		local rings, lastRangAt = 0, nil
		while checkouts[plot] == checkout and checkout.customer.owner.Parent do
			task.wait(BellConfig.check)
			local owner = checkout.customer.owner
			if checkouts[plot] ~= checkout or checkout.remaining == 0 or checkout.haggling then
				break
			end
			local now = os.clock()
			if RegisterBell.due({ now = now, lastProgressAt = checkout.lastProgressAt, lastRangAt = lastRangAt, rings = rings, attended = isBehindCounter(owner, plot), outOfTown = WildService.IsInWild(owner) }, BellConfig) then
				rings += 1
				lastRangAt = now
				Remotes.RegisterBell:FireClient(owner, rings)
			end
		end
	end)

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
		local cardInfo = cardInfos[index]
		if cardInfo then
			dressCard(part, cardInfo, unitPrice, size, part.CFrame)
		else
			dressItem(part, if productId then productId else nil, index)
		end

		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = RegisterConfig.REACH
		click.MouseClick:Connect(function(clickingPlayer)
			onScan(clickingPlayer, plot, part)
		end)
		click.Parent = part

		part.Parent = register
		checkout.pending[part] = unitPrice
		local cardId = cardIds[index]
		table.insert(checkout.lines, { name = names[index], price = unitPrice, part = part, product = if productId then productId else nil, card = if cardId then cardId else nil })
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
	-- Already paying: the window again (closed by mistake)
	if checkout.payment then
		sendPayment(checkout)
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
	startPayment(checkout, checkout.total)
end

-- The owner's answer on the card machine (the typed total in cents) or from the drawer (the bills and coins given):
-- right, the sale; wrong, the window says why. Checked here against the server's own total, never the client's
local function onPayAnswer(player: Player, answer: unknown)
	if not allowAnswer(player) then
		return
	end
	local checkout: Checkout? = nil
	for _, open in checkouts do
		if open.customer.owner == player then
			checkout = open
		end
	end
	local payment = if checkout then checkout.payment else nil
	if not checkout or not payment then
		return
	end
	if not manning[player] or not isBehindCounter(player, checkout.customer.plot) then
		notify(player, "Man the register to take payment!", true)
		return
	end
	local result: string
	if payment.method == "card" then
		result = if typeof(answer) == "number" and PaymentRules.cardRight(answer, payment.totalCents) then "ok" else "wrong"
	else
		result = PaymentRules.checkChange(PaymentConfig, answer, payment.givenCents - payment.totalCents)
		if result == "bad" then
			return -- not money from the drawer: only a tampered client sends that
		end
	end
	checkout.lastProgressAt = os.clock()
	if result == "ok" then
		completeSale(checkout, payment.price, false)
	else
		Remotes.PaymentResult:FireClient(player, result)
	end
end

local function onCharge(player: Player)
	if not allowCharge(player) then
		return
	end
	if not manning[player] then
		notify(player, "Man the register to charge!", true)
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
		checkout.haggling = false
		startPayment(checkout, price) -- they pay the price agreed
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
	manning[player] = true
	player:SetAttribute("ManningRegister", true)
	chargeAsOwner(player, checkout)
	return true
end

-- A bargain hunter made an offer the owner should answer
function RegisterService.OnHaggle(callback: HaggleCallback)
	table.insert(haggleCallbacks, callback)
end

-- After every sale, with what the customer bought (product id -> units), whether a cashier rang it up and what it paid
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
	Remotes.PayAnswer.OnServerEvent:Connect(onPayAnswer)
	Remotes.ManRegister.OnServerEvent:Connect(onMan)
	Players.PlayerRemoving:Connect(function(player)
		manning[player] = nil
		manTries[player] = nil
		for plot, checkout in checkouts do
			if checkout.customer.owner == player then
				endCheckout(plot)
			end
		end
	end)
end

return RegisterService
