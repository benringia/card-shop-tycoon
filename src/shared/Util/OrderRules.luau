--!strict
-- The order computer (owner 2026-11-21: "redesign it to be fully immersive computer shopping layout", pick A: a
-- monitor with the packenship.co store open; Config/OrderComputer, client OrderController): money words, each card's
-- lines and Add button, the cart and its Order now button, the delivery pad's room, the shelves tag, and the server's
-- check of a cart a client sends (StockService). The server re-checks level, room, distance and cash. Pure,
-- Lune-tested (tests/OrderRules).
local OrderRules = {}

export type Product = {
	id: string,
	name: string,
	boxCost: number,
	unitsPerBox: number,
	marketPrice: number,
	unlockLevel: number,
	bulk: boolean?,
	unlockBoss: { id: string, name: string }?,
}

-- Boxes of each product: { FirstSparkPack = 2 }
export type Cart = { [string]: number }

-- The pallet deal (Config/OrderComputer PALLET): `boxes` or more of one product in one order cost `off` less
export type Pallet = { boxes: number, off: number }

-- A card's pallet meter: its slots filled (at most a pallet's), whether the deal is on, and its words
export type Meter = { filled: number, done: boolean, text: string }

export type Look = { state: string, text: string, why: string? }

-- A shelf as the client sees it (its part's attributes and Config/Shelves)
export type ShelfInfo = {
	kind: string,
	capacity: number,
	units: number,
	productId: string?,
	accepts: { string }?,
}

local MAX_CART_LINES = 16 -- products in a cart the server reads at most

local function cents(amount: number): number
	return math.round(amount * 100) / 100
end

local function commas(whole: number): string
	local digits = string.reverse((string.gsub(string.reverse(tostring(whole)), "(%d%d%d)", "%1,")))
	return if string.sub(digits, 1, 1) == "," then string.sub(digits, 2) else digits
end

-- "$48", "$2.50", "$1,250.40": whole dollars plain, cents when there are some, commas in the thousands
function OrderRules.money(amount: number): string
	local total = math.round(math.max(0, amount) * 100)
	local whole, part = total // 100, total % 100
	if part == 0 then
		return `${commas(whole)}`
	end
	return string.format("$%s.%02d", commas(whole), part)
end

-- What one unit sells for: "$3.00" under $100, "$120" from there
local function each(price: number): string
	if price >= 100 and price == math.floor(price) then
		return `${commas(price)}`
	end
	return string.format("$%.2f", price)
end

-- What one sells for: "sells $3.00 each"; a box of one (a sealed booster box): "sells $120"
function OrderRules.meta(product: Product): string
	if product.unitsPerBox == 1 then
		return `sells {each(product.marketPrice)}`
	end
	return `sells {each(product.marketPrice)} each`
end

-- The chip on a card's picture: "Box of 24"; nil for a box of one
function OrderRules.boxChip(product: Product): string?
	return if product.unitsPerBox > 1 then `Box of {product.unitsPerBox}` else nil
end

-- A whole box sold at the market price, less what the box costs
function OrderRules.profit(product: Product): number
	return cents(product.unitsPerBox * product.marketPrice - product.boxCost)
end

-- "+$24 profit a box" (a phone: "+$24 profit"); nil when a box makes nothing
function OrderRules.profitText(product: Product, short: boolean?): string?
	local profit = OrderRules.profit(product)
	if profit <= 0 then
		return nil
	end
	return if short then `+{OrderRules.money(profit)} profit` else `+{OrderRules.money(profit)} profit a box`
end

function OrderRules.cartCount(cart: Cart): number
	local count = 0
	for _, boxes in cart do
		count += boxes
	end
	return count
end

-- What `boxes` boxes of one product cost: at the pallet deal from its box count up (to the cent)
function OrderRules.lineCost(product: Product, boxes: number, pallet: Pallet?): number
	local full = product.boxCost * boxes
	if pallet and boxes >= pallet.boxes then
		return cents(full * (1 - pallet.off))
	end
	return cents(full)
end

-- What the cart costs, each line at the pallet deal when it has enough boxes; a product that isn't sold costs nothing
function OrderRules.cartCost(cart: Cart, byId: { [string]: Product }, pallet: Pallet?): number
	local cost = 0
	for productId, boxes in cart do
		local product = byId[productId]
		if product then
			cost += OrderRules.lineCost(product, boxes, pallet)
		end
	end
	return cents(cost)
end

-- What the pallet deal takes off the cart (0 when no line has enough boxes)
function OrderRules.palletSavings(cart: Cart, byId: { [string]: Product }, pallet: Pallet?): number
	return cents(OrderRules.cartCost(cart, byId) - OrderRules.cartCost(cart, byId, pallet))
end

-- One box at the pallet deal
function OrderRules.dealPrice(product: Product, pallet: Pallet): number
	return cents(product.boxCost * (1 - pallet.off))
end

-- "+$28.80 profit a box" at the deal (a phone: "+$28.80 profit"); nil when a box makes nothing
function OrderRules.dealProfitText(product: Product, pallet: Pallet, short: boolean?): string?
	local profit = cents(product.unitsPerBox * product.marketPrice - OrderRules.dealPrice(product, pallet))
	if profit <= 0 then
		return nil
	end
	return if short then `+{OrderRules.money(profit)} profit` else `+{OrderRules.money(profit)} profit a box`
end

-- A card's pallet meter with `boxes` of it in the cart: "6 for -10%", "4 more: -10%", "PALLET -10%!"
function OrderRules.meter(boxes: number, pallet: Pallet, words: { [string]: string }): Meter
	local percent = math.round(pallet.off * 100)
	local filled = math.clamp(math.floor(boxes), 0, pallet.boxes)
	if filled >= pallet.boxes then
		return { filled = filled, done = true, text = string.format(words.PALLET_DONE, percent) }
	end
	if filled == 0 then
		return { filled = 0, done = false, text = string.format(words.PALLET_NONE, pallet.boxes, percent) }
	end
	return { filled = filled, done = false, text = string.format(words.PALLET_MORE, pallet.boxes - filled, percent) }
end

-- A copy of the cart with this product's count moved by `delta`, never under zero (a zero leaves the cart)
function OrderRules.changeCount(cart: Cart, productId: string, delta: number): Cart
	local copy = table.clone(cart)
	local boxes = math.max(0, (copy[productId] or 0) + delta)
	copy[productId] = if boxes > 0 then boxes else nil
	return copy
end

-- "1 box", "3 boxes"
function OrderRules.boxes(count: number): string
	return if count == 1 then "1 box" else `{count} boxes`
end

-- Why no more boxes fit: the pad full, or how many still fit
function OrderRules.roomLine(room: number): string
	if room <= 0 then
		return "Your delivery pad is full. Put some boxes on your shelves first."
	end
	return `Your delivery pad has room for {OrderRules.boxes(room)}.`
end

-- Whether the shop's owner may order `product`: its shop level reached and, for one that needs a boss beaten (the
-- Frontier Pack: the Frost Tyrant), that boss among `cleared`
function OrderRules.isOpen(product: Product, level: number, cleared: { [string]: boolean }?): boolean
	local boss = product.unlockBoss
	return level >= product.unlockLevel and (boss == nil or (cleared ~= nil and cleared[boss.id] == true))
end

-- The bosses a player has beaten, from their BossesCleared attribute ("frostTyrant,meadowWarden")
function OrderRules.clearedSet(attribute: unknown): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if typeof(attribute) == "string" then
		for id in string.gmatch(attribute, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

-- A card's Add button (and its + while some are in the cart): "ready", "locked" below its shop level or before its
-- boss is beaten, "full" when the pad has no room for one more, "short" when the cash doesn't cover one more on top
-- of the cart (each line at the pallet deal when given). `why` says what's wrong when it's tapped anyway (never silent).
function OrderRules.addLook(product: Product, level: number, cash: number, cart: Cart, byId: { [string]: Product }, room: number, short: boolean?, cleared: { [string]: boolean }?, pallet: Pallet?): Look
	if level < product.unlockLevel then
		return {
			state = "locked",
			text = if short then `Shop level {product.unlockLevel}` else `Unlocks at shop level {product.unlockLevel}`,
			why = `Unlocks at shop level {product.unlockLevel}.`,
		}
	end
	local boss = product.unlockBoss
	if boss and not OrderRules.isOpen(product, level, cleared) then
		return {
			state = "locked",
			text = if short then `Beat {boss.name}` else `Beat the {boss.name} first`,
			why = `Beat the {boss.name} to stock {product.name}s.`,
		}
	end
	local count = OrderRules.cartCount(cart)
	if count >= room then
		return { state = "full", text = "Pad full", why = OrderRules.roomLine(room) }
	end
	local add = if short then "Add" else "Add to cart"
	if cash < OrderRules.cartCost(OrderRules.changeCount(cart, product.id, 1), byId, pallet) then
		if count == 0 then
			return { state = "short", text = `Need {OrderRules.money(product.boxCost)}`, why = `You need {OrderRules.money(product.boxCost)} for a box.` }
		end
		return { state = "short", text = add, why = "Not enough cash for another box." }
	end
	return { state = "ready", text = add }
end

-- The cart's Order now button: "empty", "full" when the pad filled up meanwhile, "short" of cash, or "ready" with the
-- total on it (a phone shows the total beside the button); each line at the pallet deal when given
function OrderRules.checkout(cart: Cart, byId: { [string]: Product }, cash: number, room: number, short: boolean?, pallet: Pallet?): Look
	local count = OrderRules.cartCount(cart)
	if count == 0 then
		return { state = "empty", text = if short then "Order now" else "Add boxes to order", why = "Add some boxes to your cart first." }
	end
	if count > room then
		return { state = "full", text = `Room for {math.max(0, room)}`, why = OrderRules.roomLine(room) }
	end
	local cost = OrderRules.cartCost(cart, byId, pallet)
	if cash < cost then
		return { state = "short", text = `Need {OrderRules.money(cost)}`, why = `You need {OrderRules.money(cost)} for this order.` }
	end
	return { state = "ready", text = if short then "Order now" else `Order now · {OrderRules.money(cost)}` }
end

-- The cart's count pill: "Empty", "1 box", "3 boxes"
function OrderRules.cartPill(count: number): string
	return if count == 0 then "Empty" else OrderRules.boxes(count)
end

-- A cart line: "Card Sleeves x2"
function OrderRules.cartLine(name: string, count: number): string
	return `{name} x{count}`
end

function OrderRules.cashAfter(cash: number, cost: number): string
	return `Cash after: {OrderRules.money(cash - cost)}`
end

-- A phone's bottom bar: "3 boxes · $126" (at the pallet deal when given)
function OrderRules.phoneSummary(cart: Cart, byId: { [string]: Product }, pallet: Pallet?): string
	local count = OrderRules.cartCount(cart)
	if count == 0 then
		return "Your cart is empty"
	end
	return `{OrderRules.boxes(count)} · {OrderRules.money(OrderRules.cartCost(cart, byId, pallet))}`
end

-- "Arrives at your door in 10 s" (a phone: "At your door in 10 s")
function OrderRules.arriveLine(seconds: number, short: boolean?): string
	return if short then `At your door in {seconds} s` else `Arrives at your door in {seconds} s`
end

-- "Delivery pad: 3 of 12 spots used" (a phone: "pad 3 of 12")
function OrderRules.padLine(used: number, max: number, short: boolean?): string
	return if short then `pad {used} of {max}` else `Delivery pad: {used} of {max} spots used`
end

local function takes(shelf: ShelfInfo, productId: string): boolean
	return shelf.kind == "Products" and (shelf.accepts == nil or table.find(shelf.accepts, productId) ~= nil)
end

-- The tag on a product no shelf holds (spec 2026-11-24-shop-variety-design): customers ask for every unlocked product
OrderRules.WANTED = "Customers want this!"

-- The pink tag on a card: "Shelves low" when the shelves holding it are at `lowShare` full or less; "Shelf empty"
-- when a shelf of it ran out (an empty shelf keeps its product); "Customers want this!" when no shelf has it as its
-- product (OrderRules.WANTED); nil when well stocked
function OrderRules.shelfTag(shelves: { ShelfInfo }, productId: string, lowShare: number): string?
	local units, capacity = 0, 0
	local ranOut = false
	for _, shelf in shelves do
		if takes(shelf, productId) and shelf.productId == productId then
			if shelf.units > 0 then
				units += shelf.units
				capacity += shelf.capacity
			else
				ranOut = true
			end
		end
	end
	if capacity > 0 then
		return if units / capacity <= lowShare then "Shelves low" else nil
	end
	return if ranOut then "Shelf empty" else OrderRules.WANTED
end

-- A cart a client sent, checked (StockService): known, orderable products (never bulk: a Bulk Bin is filled from the
-- binder) in whole boxes, one to `maxBoxes` in all. nil when anything is off.
function OrderRules.readCart(raw: unknown, byId: { [string]: Product }, maxBoxes: number): Cart?
	if typeof(raw) ~= "table" then
		return nil
	end
	local cart: Cart = {}
	local lines, total = 0, 0
	for key, value in raw :: { [unknown]: unknown } do
		lines += 1
		if lines > MAX_CART_LINES or typeof(key) ~= "string" or typeof(value) ~= "number" then
			return nil
		end
		local product = byId[key]
		if not product or product.bulk or value ~= value or value < 1 or value > maxBoxes or value ~= math.floor(value) then
			return nil
		end
		cart[key] = value
		total += value
	end
	if total < 1 or total > maxBoxes then
		return nil
	end
	return cart
end

-- How long a box takes: Pish's tour's at once, a new shop's quick (`earlySeconds`, Util/EarlyRules), Express (a Bloom
-- creature's perk) shorter, never under a second
function OrderRules.deliverySeconds(touring: boolean, tourSeconds: number, earlySeconds: number, express: number): number
	if touring then
		return tourSeconds
	end
	return math.max(1, math.round(earlySeconds * (1 - express)))
end

-- The toast when an order goes through: one box by its name, several by their count
function OrderRules.orderedLine(count: number, name: string, seconds: number): string
	if count == 1 then
		return `Ordered {name}. Arrives in {seconds}s.`
	end
	return `Ordered {count} boxes. They arrive in {seconds}s.`
end

function OrderRules.arrivedLine(count: number, name: string): string
	return if count == 1 then `Your {name} box arrived!` else `Your {count} boxes arrived!`
end

-- My deliveries: a box's countdown
function OrderRules.comingLine(left: number): string
	if left <= 0 then
		return "Arriving now"
	end
	return `Arrives in {math.ceil(left)} s`
end

-- How far along its way a box is (0 to 1)
function OrderRules.comingShare(left: number, seconds: number): number
	if seconds <= 0 then
		return 1
	end
	return math.clamp(1 - left / seconds, 0, 1)
end

-- "3 boxes waiting on your delivery pad"; nil when none
function OrderRules.waitingLine(count: number): string?
	if count <= 0 then
		return nil
	end
	return `{OrderRules.boxes(count)} waiting on your delivery pad`
end

-- A size in px
export type Box = { w: number, h: number }

-- A bottom row higher up than this share of the screen isn't the bottom row (not laid out yet): ignored
local MIN_ROOM = 0.5

-- The tablet on the screen (owner 2026-11-22: "remove the monitor stand to make it look like an ipad because its
-- overlaping with the bottom tile"): its scale and its middle's height, px down the screen gui. As big as `grow` (a
-- computer's HUD growth, Util/HudGrow; 1 on a touch screen), as far as it fits `share` of the gui's width and of the
-- room above `floor`, the bottom tiles' tops (px down the gui; nil while none show), in the middle of that room.
function OrderRules.fit(gui: Box, size: Box, floor: number?, share: number, grow: number): (number, number)
	local room = if floor and floor >= gui.h * MIN_ROOM then math.min(floor, gui.h) else gui.h
	local scale = math.min(grow, gui.w * share / size.w, room * share / size.h)
	return scale, room / 2
end

return OrderRules
