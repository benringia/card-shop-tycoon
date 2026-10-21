--!strict
-- Checkout at the register: the front customer's items appear on the counter, the owner taps each
-- one to scan it, then charges the total. A cashier worker (JobService) can do the same through the
-- Worker API below; both end in completeSale. Cash and XP go through EconomyService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegisterConfig = require(Shared:WaitForChild("Config"):WaitForChild("Register"))
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
}

local RegisterService = {}

local checkouts: { [Plot]: Checkout } = {}
local allowScan = RateLimiter.new(RegisterConfig.SCAN_COOLDOWN)
local allowCharge = RateLimiter.new(RegisterConfig.CHARGE_COOLDOWN)

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

-- Scans one counter item: shared by the owner's taps and a cashier worker
local function scanItem(plot: Plot, checkout: Checkout, part: BasePart)
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
end

-- Charges a fully scanned checkout: shared by the owner and a cashier worker
local function completeSale(checkout: Checkout)
	local customer = checkout.customer
	local owner = customer.owner
	local total = checkout.total
	endCheckout(customer.plot)
	CustomerService.CompletePurchase(customer)
	if total > 0 then
		EconomyService.AddCash(owner, total)
	end
	EconomyService.AddXP(owner, math.max(RegisterConfig.MIN_XP_PER_SALE, math.round(total)))
	DataService.AddStat(owner, "customersServed", 1)
	DataService.AddStat(owner, "totalEarned", total)
	Remotes.Notify:FireClient(owner, string.format("Sale! +$%.2f", total), false, "side")
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
	scanItem(plot, checkout, part)
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
	for _, item in customer.items do
		for _ = 1, item.units do
			table.insert(prices, item.unitPrice)
		end
	end

	local checkout: Checkout = { customer = customer, pending = {}, remaining = #prices, count = #prices, total = 0 }
	checkouts[plot] = checkout

	local register = plot.register
	local size = RegisterConfig.ITEM_SIZE
	for index, unitPrice in prices do
		local x = (index - (#prices + 1) / 2) * RegisterConfig.ITEM_SPACING
		local part = Instance.new("Part")
		part.Name = "CounterItem"
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.Color = RegisterConfig.ITEM_COLOR
		part.CFrame = register.CFrame * CFrame.new(x, (register.Size.Y + size.Y) / 2, 0)

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

local function onCharge(player: Player)
	if not allowCharge(player) then
		return
	end
	local checkout: Checkout? = nil
	for _, candidate in checkouts do
		if candidate.customer.owner == player then
			checkout = candidate
			break
		end
	end
	if not checkout then
		return
	end
	if checkout.remaining > 0 then
		notify(player, "Scan every item first.", true)
		return
	end
	if not isBehindCounter(player, checkout.customer.plot) then
		notify(player, "Stand behind the register to charge.", true)
		return
	end
	completeSale(checkout)
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
	scanItem(plot, checkout, part)
	return true
end

-- Charges the checkout once every item is scanned; false if there's nothing to charge
function RegisterService.ChargeByWorker(plot: Plot): boolean
	local checkout = checkouts[plot]
	if not checkout or checkout.remaining > 0 then
		return false
	end
	completeSale(checkout)
	return true
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
