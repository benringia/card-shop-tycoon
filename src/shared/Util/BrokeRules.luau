--!strict
-- A shop can always restock (Config/Broke; owner 2026-11-20: a friend spent all his cash on packs at the start and
-- could not go on). Pure: the server (BrokeService) gives the shop's state and the two costs.
--
-- A shop earns from a rack with packs on it. So it keeps a reserve: the rack's cost until it has one, and what its
-- stock lacks of a box's cost (stock sells for the next box). Spending, opening your own stock and selling your last
-- rack are refused when they would eat the reserve; `topUp` is what a shop that is stuck anyway gets from Pish.
local BrokeRules = {}

export type State = {
	cash: number,
	shelves: number, -- shelves that can hold the packs
	stockUnits: number, -- everything still to sell: on shelves, in boxes, on order, in customers' hands
	stockValue: number, -- at market prices
}
export type Costs = { shelf: number, box: number }
type Words = { WORDS: { [string]: string } }

-- What the stock lacks of the next box's cost
local function lack(stockValue: number, costs: Costs): number
	return math.max(0, costs.box - stockValue)
end

local function shelfNeed(state: State, costs: Costs): number
	return if state.shelves <= 0 then costs.shelf else 0
end

-- The cash the shop must keep
function BrokeRules.reserve(state: State, costs: Costs): number
	return shelfNeed(state, costs) + lack(state.stockValue, costs)
end

-- Whether `amount` may be spent. `kind`: "stock" (an order: always with a rack, else the rack's cost stays), "shelf"
-- (a shelf for the packs: the first one is always the way on), anything else: the whole reserve stays
function BrokeRules.canSpend(state: State, costs: Costs, amount: number, kind: string?): boolean
	local after = state.cash - amount
	if kind == "stock" then
		return state.shelves > 0 or after >= costs.shelf
	elseif kind == "shelf" and state.shelves <= 0 then
		return true
	end
	return after >= BrokeRules.reserve(state, costs)
end

-- Whether the owner may take `value` of stock for themselves (a pack ripped, a box into the Bag)
function BrokeRules.canTake(state: State, costs: Costs, value: number): boolean
	return state.cash >= shelfNeed(state, costs) + lack(state.stockValue - value, costs)
end

-- Whether a shelf that holds the packs may be sold for `refund`: the last one only with the cash to start again
function BrokeRules.canSellShelf(state: State, costs: Costs, refund: number): boolean
	return state.shelves > 1 or state.cash + refund >= costs.shelf + lack(state.stockValue, costs)
end

-- What a stuck shop gets from Pish (0: it can still earn): with no rack, up to the rack's cost and what the stock
-- lacks of a box; with a rack and nothing left to sell, up to a box's cost. To the cent.
function BrokeRules.topUp(state: State, costs: Costs): number
	local need = 0
	if state.shelves <= 0 then
		need = costs.shelf + lack(state.stockValue, costs)
	elseif state.stockUnits <= 0 then
		need = costs.box
	end
	return math.max(0, math.round((need - state.cash) * 100) / 100)
end

-- Whether a shelf holds `product` (`accepts`: Config/Shelves, nil = anything)
function BrokeRules.sells(accepts: { string }?, product: string): boolean
	return accepts == nil or table.find(accepts, product) ~= nil
end

local function money(amount: number): string
	return if amount == math.floor(amount) then string.format("%d", amount) else string.format("%.2f", amount)
end

-- The words for the player. `what`: "order" (stock refused: no rack yet), "spend" (anything else refused), "take"
-- (their own stock), "sellShelf" (their last rack), "topUp" (Pish's help)
function BrokeRules.words(what: string, state: State, costs: Costs, cfg: Words): string
	local noShelf = state.shelves <= 0
	if what == "order" then
		return string.format(cfg.WORDS.order, money(costs.shelf))
	elseif what == "spend" then
		return string.format(if noShelf then cfg.WORDS.spendNoShelf else cfg.WORDS.spend, money(BrokeRules.reserve(state, costs)))
	elseif what == "take" then
		return string.format(if noShelf then cfg.WORDS.takeNoShelf else cfg.WORDS.take, money(if noShelf then costs.shelf else costs.box))
	elseif what == "topUp" then
		return string.format(if noShelf then cfg.WORDS.topUpNoShelf else cfg.WORDS.topUp, money(BrokeRules.topUp(state, costs)))
	end
	return cfg.WORDS.sellShelf
end

return BrokeRules
