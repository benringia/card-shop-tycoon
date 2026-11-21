--!strict
-- The order computer (owner 2026-11-21: "redesign it to be fully immersive computer shopping layout", pick A: a
-- monitor with the packenship.co store open): money words, each card's lines and Add button, the cart and its Order
-- now button, the delivery pad's room, the shelves tag, and the server's check of a cart a client sends.
local OrderRules = require("../src/shared/Util/OrderRules")
local Products = require("../src/shared/Config/Products")
local OrderComputer = require("../src/shared/Config/OrderComputer")
local expect = require("./lib/expect")

local PACK = { id = "FirstSparkPack", name = "First Spark Booster Pack", boxCost = 48, unitsPerBox = 24, marketPrice = 3, unlockLevel = 1 }
local SLEEVES = { id = "CardSleeves", name = "Card Sleeves", boxCost = 30, unitsPerBox = 20, marketPrice = 2.5, unlockLevel = 3 }
local DECK = { id = "DeckBox", name = "Deck Box", boxCost = 60, unitsPerBox = 10, marketPrice = 9, unlockLevel = 7 }
local BOOSTER = { id = "FirstSparkBox", name = "First Spark Booster Box", boxCost = 90, unitsPerBox = 1, marketPrice = 120, unlockLevel = 11 }
local BULK = { id = "BulkCards", name = "Bulk Cards", boxCost = 0, unitsPerBox = 1, marketPrice = 1, unlockLevel = 10, bulk = true }
local BY_ID: { [string]: OrderRules.Product } = {
	FirstSparkPack = PACK,
	CardSleeves = SLEEVES,
	DeckBox = DECK,
	FirstSparkBox = BOOSTER,
	BulkCards = BULK,
}

local function shelf(units: number, productId: string?, capacity: number?, accepts: { string }?): OrderRules.ShelfInfo
	return { kind = "Products", capacity = capacity or 24, units = units, productId = productId, accepts = accepts }
end

return {
	["money: whole dollars plain, cents when there are some, commas in the thousands"] = function()
		expect.equal(OrderRules.money(48), "$48")
		expect.equal(OrderRules.money(2.5), "$2.50")
		expect.equal(OrderRules.money(1250.4), "$1,250.40")
		expect.equal(OrderRules.money(1250), "$1,250")
		expect.equal(OrderRules.money(0), "$0")
		expect.equal(OrderRules.money(1234567.891), "$1,234,567.89")
	end,

	["a card's lines: what each one sells for, and the box's chip on its picture"] = function()
		expect.equal(OrderRules.meta(PACK), "sells $3.00 each")
		expect.equal(OrderRules.meta(SLEEVES), "sells $2.50 each")
		expect.equal(OrderRules.meta(BOOSTER), "sells $120", "one in the box: no each")
		expect.equal(OrderRules.boxChip(PACK), "Box of 24")
		expect.isNil(OrderRules.boxChip(BOOSTER), "a sealed booster box comes alone")
	end,

	["profit: a whole box sold at the market price, less the box"] = function()
		expect.equal(OrderRules.profit(PACK), 24)
		expect.equal(OrderRules.profit(SLEEVES), 20)
		expect.equal(OrderRules.profit(DECK), 30)
		expect.equal(OrderRules.profitText(PACK), "+$24 profit a box")
		expect.equal(OrderRules.profitText(PACK, true), "+$24 profit")
		expect.isNil(OrderRules.profitText({ id = "X", name = "X", boxCost = 50, unitsPerBox = 10, marketPrice = 5, unlockLevel = 1 }), "no profit: no tag")
	end,

	["every product the computer sells makes a profit at the market price"] = function()
		for _, product in Products.List do
			if not product.bulk then
				assert(OrderRules.profit(product) > 0, `{product.id} makes money`)
			end
		end
	end,

	["the cart: boxes counted, cost added up to the cent"] = function()
		local cart = { FirstSparkPack = 2, CardSleeves = 1 }
		expect.equal(OrderRules.cartCount(cart), 3)
		expect.equal(OrderRules.cartCost(cart, BY_ID), 126)
		expect.equal(OrderRules.cartCount({}), 0)
		expect.equal(OrderRules.cartCost({}, BY_ID), 0)
		expect.equal(OrderRules.cartCost({ Unknown = 3 }, BY_ID), 0, "a product that isn't sold costs nothing")
	end,

	["changing a count: never under zero, a zero leaves the cart"] = function()
		local cart = OrderRules.changeCount({}, "FirstSparkPack", 1)
		expect.equal(cart.FirstSparkPack, 1)
		cart = OrderRules.changeCount(cart, "FirstSparkPack", 1)
		expect.equal(cart.FirstSparkPack, 2)
		cart = OrderRules.changeCount(cart, "FirstSparkPack", -5)
		expect.isNil(cart.FirstSparkPack, "gone at zero")
		expect.equal(OrderRules.cartCount(cart), 0)
	end,

	["a card's Add button: ready, locked, the pad full, short of cash"] = function()
		local ready = OrderRules.addLook(PACK, 5, 500, {}, BY_ID, 12)
		expect.equal(ready.state, "ready")
		expect.equal(ready.text, "Add to cart")
		expect.equal(OrderRules.addLook(PACK, 5, 500, {}, BY_ID, 12, true).text, "Add", "a phone's shorter word")

		local locked = OrderRules.addLook(BOOSTER, 5, 500, {}, BY_ID, 12)
		expect.equal(locked.state, "locked")
		expect.equal(locked.text, "Unlocks at shop level 11")
		expect.equal(locked.why, "Unlocks at shop level 11.")
		expect.equal(OrderRules.addLook(BOOSTER, 5, 500, {}, BY_ID, 12, true).text, "Shop level 11")

		local padFull = OrderRules.addLook(PACK, 5, 500, {}, BY_ID, 0)
		expect.equal(padFull.state, "full")
		expect.equal(padFull.text, "Pad full")
		expect.equal(padFull.why, "Your delivery pad is full. Put some boxes on your shelves first.")
		local cartFills = OrderRules.addLook(PACK, 5, 500, { CardSleeves = 3 }, BY_ID, 3)
		expect.equal(cartFills.state, "full", "the cart already fills the room left")
		expect.equal(cartFills.why, "Your delivery pad has room for 3 boxes.")

		local broke = OrderRules.addLook(PACK, 5, 20, {}, BY_ID, 12)
		expect.equal(broke.state, "short")
		expect.equal(broke.text, "Need $48")
		expect.equal(broke.why, "You need $48 for a box.")
		local cartSpent = OrderRules.addLook(PACK, 5, 100, { DeckBox = 1 }, BY_ID, 12)
		expect.equal(cartSpent.state, "short", "$60 in the cart leaves $40")
		expect.equal(cartSpent.text, "Add to cart")
		expect.equal(cartSpent.why, "Not enough cash for another box.")
	end,

	["the Order now button: empty, too big for the pad, short of cash, ready with its price"] = function()
		local empty = OrderRules.checkout({}, BY_ID, 500, 12)
		expect.equal(empty.state, "empty")
		expect.equal(empty.text, "Add boxes to order")
		expect.equal(empty.why, "Add some boxes to your cart first.")

		local cart = { FirstSparkPack = 2, CardSleeves = 1 }
		local ready = OrderRules.checkout(cart, BY_ID, 1250.4, 12)
		expect.equal(ready.state, "ready")
		expect.equal(ready.text, "Order now · $126")
		expect.equal(OrderRules.checkout(cart, BY_ID, 1250.4, 12, true).text, "Order now", "a phone shows the total beside it")

		local full = OrderRules.checkout(cart, BY_ID, 500, 2)
		expect.equal(full.state, "full", "boxes came onto the pad while the cart was open")
		expect.equal(full.text, "Room for 2")
		expect.equal(full.why, "Your delivery pad has room for 2 boxes.")

		local short = OrderRules.checkout(cart, BY_ID, 100, 12)
		expect.equal(short.state, "short")
		expect.equal(short.text, "Need $126")
		expect.equal(short.why, "You need $126 for this order.")
	end,

	["the cart's words: its pill, a line, cash after, a phone's summary"] = function()
		expect.equal(OrderRules.boxes(1), "1 box")
		expect.equal(OrderRules.boxes(3), "3 boxes")
		expect.equal(OrderRules.cartPill(0), "Empty")
		expect.equal(OrderRules.cartPill(3), "3 boxes")
		expect.equal(OrderRules.cartLine("Card Sleeves", 2), "Card Sleeves x2")
		expect.equal(OrderRules.cashAfter(1250.4, 126), "Cash after: $1,124.40")
		expect.equal(OrderRules.phoneSummary({ FirstSparkPack = 2, CardSleeves = 1 }, BY_ID), "3 boxes · $126")
		expect.equal(OrderRules.phoneSummary({}, BY_ID), "Your cart is empty")
	end,

	["the delivery lines: when it arrives, the pad's spots"] = function()
		expect.equal(OrderRules.arriveLine(10), "Arrives at your door in 10 s")
		expect.equal(OrderRules.arriveLine(3, true), "At your door in 3 s")
		expect.equal(OrderRules.padLine(3, 12), "Delivery pad: 3 of 12 spots used")
		expect.equal(OrderRules.padLine(3, 12, true), "pad 3 of 12")
		expect.equal(OrderRules.roomLine(0), "Your delivery pad is full. Put some boxes on your shelves first.")
		expect.equal(OrderRules.roomLine(1), "Your delivery pad has room for 1 box.")
	end,

	["the shelves tag: low when its shelves hold a quarter or less, empty when only an empty shelf could take it"] = function()
		local low = { shelf(5, "FirstSparkPack"), shelf(0) }
		expect.equal(OrderRules.shelfTag(low, "FirstSparkPack", 0.25), "Shelves low", "5 of 24")
		expect.isNil(OrderRules.shelfTag({ shelf(20, "FirstSparkPack") }, "FirstSparkPack", 0.25), "well stocked")
		expect.equal(OrderRules.shelfTag({ shelf(6, "FirstSparkPack"), shelf(0, nil, 24) }, "FirstSparkPack", 0.25), "Shelves low", "6 of 24 exactly a quarter")
		expect.equal(OrderRules.shelfTag({ shelf(20, "FirstSparkPack"), shelf(0) }, "CardSleeves", 0.25), "Shelf empty", "an empty shelf could hold sleeves")
		expect.isNil(OrderRules.shelfTag({ shelf(20, "FirstSparkPack"), shelf(0, nil, 24, { "BulkCards" }) }, "CardSleeves", 0.25), "no shelf takes sleeves: nothing to say")
		expect.isNil(OrderRules.shelfTag({ { kind = "Cases", capacity = 6, units = 0 } }, "FirstSparkPack", 0.25), "a card case holds no stock")
		expect.isNil(OrderRules.shelfTag({}, "FirstSparkPack", 0.25), "no shelves yet")
	end,

	["the server reads a cart: known products in whole boxes, never bulk, never more than the pad"] = function()
		local cart = OrderRules.readCart({ FirstSparkPack = 2, CardSleeves = 1 }, BY_ID, 12)
		assert(cart, "a fine cart")
		expect.equal(cart.FirstSparkPack, 2)
		expect.equal(cart.CardSleeves, 1)
		expect.isNil(OrderRules.readCart("FirstSparkPack", BY_ID, 12), "not a table")
		expect.isNil(OrderRules.readCart({}, BY_ID, 12), "empty")
		expect.isNil(OrderRules.readCart({ Unknown = 1 }, BY_ID, 12), "an unknown product")
		expect.isNil(OrderRules.readCart({ BulkCards = 1 }, BY_ID, 12), "bulk comes from the binder")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = 1.5 }, BY_ID, 12), "half a box")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = 0 }, BY_ID, 12), "zero")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = -1 }, BY_ID, 12), "negative")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = 0 / 0 }, BY_ID, 12), "NaN")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = math.huge }, BY_ID, 12), "infinite")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = 8, CardSleeves = 5 }, BY_ID, 12), "13 boxes on a 12-box pad")
		expect.isNil(OrderRules.readCart({ [1] = 2 }, BY_ID, 12), "a number key")
		expect.isNil(OrderRules.readCart({ FirstSparkPack = "2" }, BY_ID, 12), "a string count")
	end,

	["delivery time: the tour's at once, a new shop's quick, Express shorter, never under a second"] = function()
		expect.equal(OrderRules.deliverySeconds(true, 1, 10, 0), 1)
		expect.equal(OrderRules.deliverySeconds(false, 1, 10, 0), 10)
		expect.equal(OrderRules.deliverySeconds(false, 1, 3, 0), 3)
		expect.equal(OrderRules.deliverySeconds(false, 1, 10, 0.3), 7)
		expect.equal(OrderRules.deliverySeconds(false, 1, 1, 0.9), 1)
	end,

	["the toasts: one box by its name, several by their count"] = function()
		expect.equal(OrderRules.orderedLine(1, "Deck Box", 10), "Ordered Deck Box. Arrives in 10s.")
		expect.equal(OrderRules.orderedLine(3, "Deck Box", 10), "Ordered 3 boxes. They arrive in 10s.")
		expect.equal(OrderRules.arrivedLine(1, "Deck Box"), "Your Deck Box box arrived!")
		expect.equal(OrderRules.arrivedLine(3, "Deck Box"), "Your 3 boxes arrived!")
	end,

	["My deliveries: a box's countdown and the boxes waiting on the pad"] = function()
		expect.equal(OrderRules.comingLine(6.2), "Arrives in 7 s")
		expect.equal(OrderRules.comingLine(0), "Arriving now")
		expect.equal(OrderRules.comingShare(2.5, 10), 0.75)
		expect.equal(OrderRules.comingShare(0, 10), 1)
		expect.equal(OrderRules.comingShare(5, 0), 1, "no length: done")
		expect.isNil(OrderRules.waitingLine(0))
		expect.equal(OrderRules.waitingLine(1), "1 box waiting on your delivery pad")
		expect.equal(OrderRules.waitingLine(3), "3 boxes waiting on your delivery pad")
	end,

	["the tablet: as big as fits above the bottom tiles, never past its growth"] = function()
		local size = { w = 960, h = 600 }
		-- a big screen: the HUD's growth is the limit, its middle the middle of the room over the tiles
		local scale, middle = OrderRules.fit({ w = 1920, h = 1022 }, size, 883, 0.96, 1.35)
		expect.equal(scale, 1.35)
		expect.equal(middle, 441.5)
		-- a short window: shrunk to fit over the tiles' icons, its foot clear of them
		scale, middle = OrderRules.fit({ w = 1891, h = 672 }, size, 548, 0.96, 1.2)
		expect.near(scale, 548 * 0.96 / 600, 1e-9)
		expect.equal(middle, 274)
		assert(middle + size.h * scale / 2 < 548, "its foot over the tiles")
		-- a narrow window: its width is the limit
		scale = OrderRules.fit({ w = 900, h = 1022 }, size, 883, 0.96, 1.35)
		expect.near(scale, 900 * 0.96 / 960, 1e-9)
		-- no tiles showing (a phone's window hides them): the whole screen
		scale, middle = OrderRules.fit({ w = 800, h = 280 }, { w = 760, h = 300 }, nil, 0.96, 1)
		expect.near(scale, 280 * 0.96 / 300, 1e-9)
		expect.equal(middle, 140)
		-- a row higher than half the screen isn't the bottom row (not laid out yet): ignored
		scale, middle = OrderRules.fit({ w = 1891, h = 672 }, size, 40, 0.96, 1.2)
		expect.near(scale, 672 * 0.96 / 600, 1e-9)
		expect.equal(middle, 336)
	end,

	["the store's words are plain ASCII (and the middle dot), its name a clean one"] = function()
		for key, text in OrderComputer.WORDS do
			assert(not string.find(text, "[^%w%s%p\194\183]"), `{key}: plain ASCII`)
		end
		expect.equal(OrderComputer.WORDS.STORE, "packenship.co")
		expect.equal(OrderComputer.LOW_SHARE, 0.25)
	end,
}
