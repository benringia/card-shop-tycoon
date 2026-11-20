--!strict
-- A shop can always restock (Config/Broke, Util/BrokeRules; owner 2026-11-20: "my friend accidentaly spend all his
-- money for packs and could not progress. fix/prevent this kind of scenarios").
--
-- Prevention: every spend (EconomyService's guard), the owner taking their own stock (StockService's: a pack ripped,
-- a box into the Bag) and selling a rack (PlacementService's) is checked against the shop's reserve, and a refusal
-- says what to keep (Util/Blocked). Rescue: a shop that is stuck anyway (an older save, a path nobody thought of)
-- gets what it lacks from Pish, which the same guards then keep for the rack and the box.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Broke = require(Config:WaitForChild("Broke"))
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))
local BrokeRules = require(Shared:WaitForChild("Util"):WaitForChild("BrokeRules"))

local Services = script.Parent :: Instance
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local StockService = require(Services:WaitForChild("StockService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local Blocked = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("Blocked"))

local BrokeService = {}

local COSTS: BrokeRules.Costs = {
	shelf = Shelves.ById[Broke.SHELF].cost,
	box = Products.ById[Broke.PRODUCT].boxCost,
}

-- Looks in a row a player's shop has been stuck (Config/Broke CHECKS)
local stuck: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function count(state: BrokeRules.State, stock: { [string]: number })
	for productId, units in stock do
		local product = Products.ById[productId]
		if product and units > 0 then
			state.stockUnits += units
			state.stockValue += units * product.marketPrice
		end
	end
end

local function holdsPacks(shelf: any): boolean
	return shelf.def.kind == "Products" and BrokeRules.sells(shelf.def.accepts, Broke.PRODUCT)
end

-- The shop as the rules see it: its cash, its shelves for packs and everything still to sell (on shelves, in boxes,
-- on order, in customers' hands). nil: no shop loaded for this player.
local function stateOf(player: Player): BrokeRules.State?
	local boxes = StockService.GetBoxStock(player)
	if not boxes then
		return nil
	end
	local state: BrokeRules.State = { cash = EconomyService.GetCash(player), shelves = 0, stockUnits = 0, stockValue = 0 }
	for _, shelf in PlacementService.GetShelves(player) do
		if holdsPacks(shelf) then
			state.shelves += 1
		end
		if shelf.def.kind == "Products" and shelf.productId and shelf.units > 0 then
			count(state, { [shelf.productId] = shelf.units })
		end
	end
	count(state, boxes)
	count(state, CustomerService.HeldProducts(player))
	return state
end

local function refuse(player: Player, what: string, state: BrokeRules.State)
	Blocked.tell(player, BrokeRules.words(what, state, COSTS, Broke), { first = true })
end

local function canSpend(player: Player, amount: number, kind: string?): boolean
	local state = stateOf(player)
	if not state or BrokeRules.canSpend(state, COSTS, amount, kind) then
		return true
	end
	refuse(player, if kind == "stock" then "order" else "spend", state)
	return false
end

local function canTake(player: Player, productId: string, units: number): boolean
	local state = stateOf(player)
	local product = Products.ById[productId]
	if not state or not product or BrokeRules.canTake(state, COSTS, units * product.marketPrice) then
		return true
	end
	refuse(player, "take", state)
	return false
end

local function canSell(player: Player, shelf: any, refund: number): boolean
	if not holdsPacks(shelf) then
		return true
	end
	local state = stateOf(player)
	if not state or BrokeRules.canSellShelf(state, COSTS, refund) then
		return true
	end
	refuse(player, "sellShelf", state)
	return false
end

-- One look at a player's shop: stuck CHECKS looks in a row, Pish gives what it lacks
local function look(player: Player)
	local state = stateOf(player)
	local amount = if state then BrokeRules.topUp(state, COSTS) else 0
	if not state or amount <= 0 then
		stuck[player] = nil
		return
	end
	local looks = (stuck[player] or 0) + 1
	if looks < Broke.CHECKS then
		stuck[player] = looks
		return
	end
	stuck[player] = nil
	if EconomyService.AddCash(player, amount) then
		Blocked.tell(player, BrokeRules.words("topUp", state, COSTS, Broke), {
			tone = "info",
			title = Broke.TOP_UP.title,
			icon = Broke.TOP_UP.icon,
			seconds = Broke.TOP_UP.seconds,
		})
	end
end

function BrokeService.Start()
	EconomyService.SetSpendGuard(canSpend)
	StockService.SetTakeGuard(canTake)
	PlacementService.SetSellGuard(canSell)
	task.spawn(function()
		while true do
			task.wait(Broke.CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				look(player)
			end
		end
	end)
end

return BrokeService
