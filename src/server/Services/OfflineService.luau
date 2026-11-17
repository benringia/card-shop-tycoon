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
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
export type Summary = { minutes: number, units: number, cash: number, xp: number, sold: { [string]: number }, empty: boolean }

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

-- Sells what the time away allows from the stocked Products shelves, once every service has loaded the save
local function sellAway(player: Player, lastSeen: number)
	if player:GetAttribute("DataLoaded") ~= true then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	if not loaded[player] then
		return -- gone meanwhile
	end
	local minutes = OfflineRules.minutesAway(lastSeen, os.time(), Offline)
	if minutes <= 0 then
		return
	end
	local stocked: { PlacementService.PlacedShelf } = {}
	local shelves: { OfflineRules.Shelf } = {}
	for _, shelf in PlacementService.GetShelves(player) do
		local product = if shelf.def.kind == "Products" and shelf.productId then Products.ById[shelf.productId] else nil
		if product and shelf.units > 0 then
			local price = PricingService.GetPrice(player, product.id)
			local band = PriceRules.getBand(price, product.marketPrice)
			table.insert(stocked, shelf)
			table.insert(shelves, { units = shelf.units, price = price, chance = if band then band.chance else 0 })
		end
	end
	local plan = OfflineRules.plan(shelves, minutes, Offline)
	local sold: { [string]: number } = {}
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
	if units <= 0 then
		return
	end
	local cash = cents / 100
	local xp = math.floor(cash * Offline.XP_PER_CASH)
	EconomyService.AddCash(player, cash)
	EconomyService.AddXP(player, xp)
	DataService.AddStat(player, "totalEarned", cash)
	local left = 0
	for _, shelf in stocked do
		left += shelf.units
	end
	pending[player] = { minutes = minutes, units = units, cash = cash, xp = xp, sold = sold, empty = left == 0 }
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
