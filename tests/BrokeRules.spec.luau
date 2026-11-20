--!strict
-- A shop can always restock (owner 2026-11-20: "my friend accidentaly spend all his money for packs and could not
-- progress. fix/prevent this kind of scenarios"): it keeps the cash for a rack to sell from and a box of packs to
-- sell until it has them, its last packs can't all be opened by the owner, and a shop that is stuck anyway gets what
-- it lacks from Pish
local BrokeRules = require("../src/shared/Util/BrokeRules")
local Broke = require("../src/shared/Config/Broke")
local Products = require("../src/shared/Config/Products")
local Economy = require("../src/shared/Config/Economy")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

-- Config/Shelves needs Roblox to load: the rack's cost is read from its text
local function shelfCost(id: string): number
	local source = fs.readFile("src/shared/Config/Shelves.luau")
	local cost = string.match(source, 'id = "' .. id .. '".-cost = (%d+)')
	return assert(tonumber(cost), `{id} has a cost`)
end

local box = Products.ById[Broke.PRODUCT]
local COSTS = { shelf = shelfCost(Broke.SHELF), box = box.boxCost }
local PACK = box.marketPrice
local BOX_VALUE = box.unitsPerBox * PACK

local function shop(cash: number, shelves: number, units: number): BrokeRules.State
	return { cash = cash, shelves = shelves, stockUnits = units, stockValue = units * PACK }
end

return {
	["what a shop needs is the tour's own rack and packs"] = function()
		expect.equal(Broke.SHELF, Pish.RACK)
		expect.equal(Broke.PRODUCT, Pish.ORDER_PRODUCT)
		assert(COSTS.shelf + COSTS.box <= Economy.STARTING_CASH, "a new player can pay for both")
		assert(BOX_VALUE >= COSTS.box, "a box sells for at least what the next one costs")
	end,

	["a shop keeps the cash for what it lacks: a rack, and a box while its stock is worth less than one"] = function()
		expect.equal(BrokeRules.reserve(shop(200, 0, 0), COSTS), COSTS.shelf + COSTS.box)
		expect.equal(BrokeRules.reserve(shop(200, 1, 0), COSTS), COSTS.box)
		expect.equal(BrokeRules.reserve(shop(200, 1, 24), COSTS), 0, "a full box on the shelves pays for the next")
		expect.equal(BrokeRules.reserve(shop(200, 1, 4), COSTS), COSTS.box - 4 * PACK, "a few packs cover part of it")
		expect.equal(BrokeRules.reserve(shop(200, 0, 48), COSTS), COSTS.shelf)
	end,

	["a new player can't spend the rack's cash on packs (the friend's case)"] = function()
		local state = shop(Economy.STARTING_CASH, 0, 0)
		local orders = 0
		while BrokeRules.canSpend(state, COSTS, COSTS.box, "stock") do
			orders += 1
			state = shop(state.cash - COSTS.box, 0, state.stockUnits + box.unitsPerBox)
			assert(orders < 10, "it stops")
		end
		assert(orders >= 1, "the first box can be ordered before the rack")
		assert(state.cash >= COSTS.shelf, "the rack can still be paid for")
		expect.equal(BrokeRules.canSpend(state, COSTS, COSTS.shelf, "shelf"), true)
	end,

	["with a rack, stock can always be ordered"] = function()
		expect.equal(BrokeRules.canSpend(shop(COSTS.box, 1, 0), COSTS, COSTS.box, "stock"), true)
		expect.equal(BrokeRules.canSpend(shop(60, 1, 0), COSTS, 60, "stock"), true)
	end,

	["buying the rack leaves the cash for a box when there are no packs yet"] = function()
		expect.equal(BrokeRules.canSpend(shop(COSTS.shelf + COSTS.box, 0, 0), COSTS, COSTS.shelf, "shelf"), true)
		expect.equal(BrokeRules.canSpend(shop(COSTS.shelf + COSTS.box - 1, 0, 0), COSTS, COSTS.shelf, "shelf"), true, "the only way on: Pish covers the box after")
		expect.equal(BrokeRules.canSpend(shop(COSTS.shelf, 0, 24), COSTS, COSTS.shelf, "shelf"), true, "the packs are waiting")
	end,

	["anything else is refused while it would eat the shop's reserve"] = function()
		expect.equal(BrokeRules.canSpend(shop(300, 1, 0), COSTS, 250, "other"), true)
		expect.equal(BrokeRules.canSpend(shop(290, 1, 0), COSTS, 250, "other"), false, "empty shelves: a box's cash stays")
		expect.equal(BrokeRules.canSpend(shop(250, 1, 24), COSTS, 250, "other"), true, "stocked shelves: spend it all")
		expect.equal(BrokeRules.canSpend(shop(200, 0, 0), COSTS, 60, "other"), false, "no rack yet")
		expect.equal(BrokeRules.canSpend(shop(1000, 0, 0), COSTS, 60, "other"), true)
		expect.equal(BrokeRules.canSpend(shop(300, 1, 0), COSTS, 250, nil), true, "no kind: like anything else")
		expect.equal(BrokeRules.canSpend(shop(290, 1, 0), COSTS, 250, nil), false)
	end,

	["the last packs can't all be opened by a shop with no cash for the next box"] = function()
		local state = shop(4, 1, 24)
		local opened = 0
		while BrokeRules.canTake(state, COSTS, PACK) do
			opened += 1
			state = shop(state.cash, 1, state.stockUnits - 1)
			assert(opened <= 24, "it stops")
		end
		assert(opened > 0, "some can be opened: the rest still pay for a box")
		assert(state.cash + state.stockValue >= COSTS.box, "what's left sells for the next box")
		expect.equal(BrokeRules.canTake(shop(4, 1, 24), COSTS, BOX_VALUE), false, "not the whole last box to the Bag")
		expect.equal(BrokeRules.canTake(shop(4, 1, 48), COSTS, BOX_VALUE), true, "one of two boxes")
		expect.equal(BrokeRules.canTake(shop(COSTS.box, 1, 24), COSTS, BOX_VALUE), true, "with the cash for another, open them all")
		expect.equal(BrokeRules.canTake(shop(COSTS.box, 0, 24), COSTS, BOX_VALUE), false, "no rack: its cash stays too")
	end,

	["the last rack isn't sold from under the shop"] = function()
		expect.equal(BrokeRules.canSellShelf(shop(0, 2, 0), COSTS, 50), true, "one of two")
		expect.equal(BrokeRules.canSellShelf(shop(0, 1, 0), COSTS, 50), false)
		expect.equal(BrokeRules.canSellShelf(shop(COSTS.shelf + COSTS.box - 50, 1, 0), COSTS, 50), true, "with the cash to build again")
	end,

	["a stuck shop gets what it lacks from Pish"] = function()
		expect.equal(BrokeRules.topUp(shop(8, 1, 0), COSTS), COSTS.box - 8, "no packs, no cash for a box")
		expect.equal(BrokeRules.topUp(shop(8, 0, 96), COSTS), COSTS.shelf - 8, "four boxes and no rack (the friend's case)")
		expect.equal(BrokeRules.topUp(shop(8, 0, 0), COSTS), COSTS.shelf + COSTS.box - 8)
		expect.equal(BrokeRules.topUp(shop(8.5, 1, 0), COSTS), COSTS.box - 8.5, "to the cent")
	end,

	["a shop that can still earn gets nothing"] = function()
		expect.equal(BrokeRules.topUp(shop(Economy.STARTING_CASH, 0, 0), COSTS), 0, "a new player")
		expect.equal(BrokeRules.topUp(shop(0, 1, 1), COSTS), 0, "a pack left to sell")
		expect.equal(BrokeRules.topUp(shop(COSTS.box, 1, 0), COSTS), 0, "cash for a box")
		expect.equal(BrokeRules.topUp(shop(COSTS.shelf, 0, 24), COSTS), 0)
	end,

	["Pish's help can only go to the rack and the box, so it can't be farmed"] = function()
		local state = shop(0, 0, 0)
		state.cash = BrokeRules.topUp(state, COSTS)
		expect.equal(BrokeRules.canSpend(state, COSTS, 1, "other"), false)
		expect.equal(BrokeRules.canSpend(state, COSTS, COSTS.shelf, "shelf"), true)
		local built = shop(state.cash - COSTS.shelf, 1, 0)
		expect.equal(BrokeRules.canSpend(built, COSTS, 1, "other"), false)
		expect.equal(BrokeRules.topUp(built, COSTS), 0, "nothing more: the box's cash is there")
		local stocked = shop(built.cash - COSTS.box, 1, box.unitsPerBox)
		expect.equal(BrokeRules.topUp(stocked, COSTS), 0)
		expect.equal(BrokeRules.canTake(stocked, COSTS, BOX_VALUE), false, "the box is for selling")
	end,

	["which shelves sell packs"] = function()
		expect.equal(BrokeRules.sells(nil, Broke.PRODUCT), true, "a shelf for anything")
		expect.equal(BrokeRules.sells({ "CardSleeves", "DeckBox" }, Broke.PRODUCT), false)
		expect.equal(BrokeRules.sells({ Broke.PRODUCT }, Broke.PRODUCT), true)
	end,

	["every refusal says what to keep, in plain words"] = function()
		local seen: { [string]: boolean } = {}
		for _, case in
			{
				{ "order", shop(60, 0, 24) },
				{ "spend", shop(200, 0, 0) },
				{ "spend", shop(60, 1, 0) },
				{ "take", shop(4, 1, 24) },
				{ "take", shop(4, 0, 24) },
				{ "sellShelf", shop(0, 1, 0) },
				{ "topUp", shop(8, 1, 0) },
				{ "topUp", shop(8, 0, 0) },
			} :: { { any } }
		do
			local words = BrokeRules.words(case[1], case[2], COSTS, Broke)
			assert(#words > 10 and #words <= 110, `short enough for the card: {words}`)
			assert(not string.find(words, "[^\32-\126]"), `plain ASCII: {words}`)
			assert(not string.find(words, "%%"), `filled in: {words}`)
			assert(not seen[words], `its own words: {words}`)
			seen[words] = true
		end
		assert(string.find(BrokeRules.words("order", shop(60, 0, 24), COSTS, Broke), "$" .. COSTS.shelf, 1, true), "the rack's cost")
		assert(string.find(BrokeRules.words("spend", shop(60, 1, 0), COSTS, Broke), "$" .. COSTS.box, 1, true), "the box's cost")
		assert(string.find(BrokeRules.words("topUp", shop(8, 1, 0), COSTS, Broke), "$" .. (COSTS.box - 8), 1, true), "what Pish gave")
		assert(string.find(BrokeRules.words("topUp", shop(8.5, 1, 0), COSTS, Broke), "$39.50", 1, true), "cents when there are some")
	end,

	["the check waits for a sale in progress"] = function()
		assert(Broke.CHECK_SECONDS >= 2, "not every frame")
		assert(Broke.CHECKS >= 2, "stuck on more than one look: cash and stock change hands in steps")
	end,
}
