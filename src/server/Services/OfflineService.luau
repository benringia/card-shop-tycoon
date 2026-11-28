--!strict
-- Welcome-back earnings (owner 2026-11-17: "yes do the three now"; Config/Offline, Util/OfflineRules): when a save
-- loads in the main game after MIN_AWAY_MINUTES or more away, the shelves sell some stock as if customers had come
-- meanwhile (at the player's prices and their buy bands, a slow pace, up to MAX_MINUTES): the units come off the
-- shelves (PlacementService.TakeStock), the cash and shop XP go through EconomyService, and the client shows what sold
-- (Remotes.WelcomeBack) once it says it's ready. Writes the time of each save (data.lastSeen); main game only (the
-- shelves live there), so time spent in the Frontier or the Dungeon counts as away from the shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Offline = require(Config:WaitForChild("Offline"))
local Products = require(Config:WaitForChild("Products"))
local OfflineRules = require(Shared:WaitForChild("Util"):WaitForChild("OfflineRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local StorageRules = require(Shared:WaitForChild("Util"):WaitForChild("StorageRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local JobService = require(Services:WaitForChild("JobService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
type PlacedShelf = PlacementService.PlacedShelf
-- restocker: the card that refilled the shelves from the racks (its name and card id); boxes: rack boxes it used;
-- base / extra: minutes selling from the shelves, then from the racks only; needsRestocker: racks held boxes but no card
-- had the Restocker job (the card's hint)
export type Summary = {
	minutes: number,
	units: number,
	cash: number,
	xp: number,
	sold: { [string]: number },
	empty: boolean,
	restocker: { name: string, cardId: string }?,
	boxes: number,
	base: number,
	extra: number,
	needsRestocker: boolean,
	nightShift: OfflineRules.NightNote?, -- away past the normal limit: Night Shift's line (Robux round)
}

-- A rack's box the Restocker can carry out: its rack, its spot and the units in it
type RackBox = { rack: PlacedShelf, slot: number, units: number }

local OfflineService = {}

local loaded: { [Player]: boolean } = {}
local pending: { [Player]: Summary } = {} -- sold while away, waiting for the client to be ready to show it
local ready: { [Player]: boolean } = {} -- the client asked (its screen is clear)
local askLimit = RateLimiter.new(1)

local function deliver(player: Player)
	local summary = pending[player]
	if summary and ready[player] then
		pending[player] = nil
		Remotes.WelcomeBack:FireClient(player, summary)
	end
end

-- Today's away selling: the stocked Products shelves alone, for up to MAX_MINUTES. Adds what sold to `sold` and returns
-- the units, the cents and the shelves that held stock
local function sellShelves(player: Player, minutes: number, sold: { [string]: number }): (number, number, { PlacedShelf })
	local stocked: { PlacedShelf } = {}
	local shelves: { OfflineRules.Shelf } = {}
	for _, shelf in PlacementService.GetShelves(player) do
		local product = if shelf.def.kind == "Products" and shelf.productId then Products.ById[shelf.productId] else nil
		if product and shelf.units > 0 then
			local price = PricingService.GetPrice(player, product.id)
			table.insert(stocked, shelf)
			table.insert(shelves, { units = shelf.units, price = price, chance = PriceRules.getChance(price, product.marketPrice) })
		end
	end
	local plan = OfflineRules.plan(shelves, minutes, Offline)
	local units, cents = 0, 0
	for index, shelf in stocked do
		local productId = shelf.productId :: string
		local taken = PlacementService.TakeStock(shelf, plan.sold[index] or 0)
		if taken > 0 then
			sold[productId] = (sold[productId] or 0) + taken
			units += taken
			cents += math.round(taken * shelves[index].price * 100)
		end
	end
	return units, cents, stocked
end

-- With a Restocker (spec 2026-11-24-shop-variety-design): every product with a shelf (even an empty one) sells from its
-- shelves, then from the racks' boxes of it (OfflineRules.planRacks): `base` minutes of both, `extra` of the racks
-- only. Customers still buy from shelves; the Restocker carries the boxes out. Adds what sold to `sold` and returns
-- the units, the cents, the rack boxes used and the product shelves
local function sellWithRacks(player: Player, base: number, extra: number, sold: { [string]: number }): (number, number, number, { PlacedShelf })
	local shelvesOf: { [string]: { PlacedShelf } } = {}
	local productShelves: { PlacedShelf } = {}
	for _, shelf in PlacementService.GetShelves(player) do
		local productId = shelf.productId
		if shelf.def.kind == "Products" and productId and Products.ById[productId] then
			shelvesOf[productId] = shelvesOf[productId] or {}
			table.insert(shelvesOf[productId], shelf)
			table.insert(productShelves, shelf)
		end
	end
	local boxesOf: { [string]: { RackBox } } = {}
	for _, rack in PlacementService.GetRacks(player) do
		for slot = 1, rack.def.capacity do
			local box = rack.stored[slot]
			if box and shelvesOf[box.productId] then -- only what the Restocker has a shelf for
				boxesOf[box.productId] = boxesOf[box.productId] or {}
				table.insert(boxesOf[box.productId], { rack = rack, slot = slot, units = box.units })
			end
		end
	end
	local ids: { string } = {}
	local stock: { OfflineRules.Stock } = {}
	for _, product in Products.List do
		local shelves = shelvesOf[product.id]
		if shelves then
			local shelfUnits, rackUnits = 0, 0
			for _, shelf in shelves do
				shelfUnits += shelf.units
			end
			for _, box in boxesOf[product.id] or {} do
				rackUnits += box.units
			end
			if shelfUnits + rackUnits > 0 then
				local price = PricingService.GetPrice(player, product.id)
				table.insert(ids, product.id)
				table.insert(stock, { productId = product.id, shelf = shelfUnits, rack = rackUnits, price = price, chance = PriceRules.getChance(price, product.marketPrice) })
			end
		end
	end
	local plan = OfflineRules.planRacks(stock, base, extra, Offline)
	local units, cents, boxes = 0, 0, 0
	for index, productId in ids do
		local taken = 0
		local fromShelves = plan.fromShelves[index] or 0
		for _, shelf in shelvesOf[productId] do
			if fromShelves <= 0 then
				break
			end
			local got = PlacementService.TakeStock(shelf, fromShelves)
			fromShelves -= got
			taken += got
		end
		local rackBoxes = boxesOf[productId] or {}
		local sizes: { number } = {}
		for _, box in rackBoxes do
			table.insert(sizes, box.units)
		end
		local takes, touched = OfflineRules.boxTakes(sizes, plan.fromRacks[index] or 0)
		for boxIndex, box in rackBoxes do
			if takes[boxIndex] > 0 then
				taken += PlacementService.TakeRackUnits(box.rack, box.slot, takes[boxIndex])
			end
		end
		boxes += touched
		if taken > 0 then
			sold[productId] = (sold[productId] or 0) + taken
			units += taken
			cents += math.round(taken * stock[index].price * 100)
		end
	end
	return units, cents, boxes, productShelves
end

-- Sells what the time away allows, once every service has loaded the save: the shelves as always, and with a Restocker
-- the racks' boxes too, for up to MAX_EXTRA_MINUTES more (Config/Offline)
local function sellAway(player: Player, lastSeen: number)
	if player:GetAttribute("DataLoaded") ~= true then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	if not loaded[player] then
		return -- gone meanwhile
	end
	-- Night Shift (the game pass; Robux round, spec 2026-11-28-robux-round-design): both limits doubled
	local nightShift = MonetizationService.HasPass(player, "NightShift")
	local factor = Offline.NIGHT_SHIFT.factor
	local cfg = OfflineRules.caps(Offline, nightShift, factor)
	local minutes = OfflineRules.minutesAway(lastSeen, os.time(), cfg, cfg.MAX_MINUTES + cfg.MAX_EXTRA_MINUTES)
	if minutes <= 0 then
		return
	end
	local away = OfflineRules.minutesAway(lastSeen, os.time(), Offline, math.huge) -- uncapped, for Night Shift's line
	local restocker = JobService.GetRestocker(player)
	local racks = 0
	for _, rack in PlacementService.GetRacks(player) do
		if StorageRules.count(rack.stored) > 0 then
			racks += 1
		end
	end
	local base, extra = OfflineRules.split(minutes, racks, restocker ~= nil, cfg)
	local sold: { [string]: number } = {}
	local units, cents, boxes = 0, 0, 0
	local shelves: { PlacedShelf }
	if restocker and racks > 0 then
		units, cents, boxes, shelves = sellWithRacks(player, base, extra, sold)
	else
		units, cents, shelves = sellShelves(player, base, sold)
	end
	if units <= 0 then
		return
	end
	local cash = cents / 100
	local xp = math.floor(cash * Offline.XP_PER_CASH)
	EconomyService.AddCash(player, cash)
	EconomyService.AddXP(player, xp)
	DataService.AddStat(player, "totalEarned", cash)
	local left = 0
	for _, shelf in shelves do
		left += shelf.units
	end
	pending[player] = {
		minutes = base + extra,
		units = units,
		cash = cash,
		xp = xp,
		sold = sold,
		empty = left == 0,
		restocker = if boxes > 0 or extra > 0 then restocker else nil,
		boxes = boxes,
		base = base,
		extra = extra,
		needsRestocker = restocker == nil and racks > 0,
		nightShift = OfflineRules.nightShiftNote(
			away,
			OfflineRules.limit(Offline, racks, restocker ~= nil),
			OfflineRules.limit(OfflineRules.caps(Offline, true, factor), racks, restocker ~= nil),
			nightShift
		),
	}
	deliver(player)
end

local function load(player: Player, data: PlayerData)
	loaded[player] = true
	task.spawn(sellAway, player, if typeof(data.lastSeen) == "number" then data.lastSeen else 0)
end

-- Nothing for a player this service never loaded (a failed load keeps their old time)
local function save(player: Player, data: PlayerData)
	if loaded[player] then
		data.lastSeen = os.time()
	end
end

local function unload(player: Player)
	loaded[player] = nil
	pending[player] = nil
	ready[player] = nil
end

-- Studio (/away <minutes>): sells as if they'd been away that long, now (their shelves' stock really goes)
function OfflineService.Dev(player: Player, minutes: number): string?
	if not loaded[player] or minutes ~= minutes or minutes <= 0 then
		return nil
	end
	ready[player] = true
	task.spawn(sellAway, player, os.time() - math.floor(minutes) * 60)
	return `Welcome back: {math.floor(minutes)} minutes away (Studio, stock sold)`
end

function OfflineService.Start()
	DataService.Register({ name = "OfflineService", load = load, save = save, unload = unload })
	Remotes.WelcomeBack.OnServerEvent:Connect(function(player)
		if askLimit(player) then
			ready[player] = true
			deliver(player)
		end
	end)
end

return OfflineService
