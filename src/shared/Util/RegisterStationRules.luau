--!strict
-- Manning the register in first person (Config/RegisterStation): what the register's screen and the hint show, where
-- the cash drawer's bills and coins sit and where money given lands on the counter. Pure (Lune-tested)
local RegisterStationRules = {}

export type State = {
	manned: boolean,
	checkoutOpen: boolean, -- a customer is being checked out (CheckoutUpdate)
	remaining: number, -- items still to scan
	offerOpen: boolean, -- a kid's offer or a bargain hunter's deal to answer (OfferUpdate)
	paying: string?, -- "card" | "cash" once Charge was pressed (PaymentStart)
}
export type Situation = "off" | "idle" | "scan" | "charge" | "offer" | "card" | "cash"
export type Slot = { cents: number, x: number, z: number, width: number, depth: number }

function RegisterStationRules.situation(state: State): Situation
	if not state.manned then
		return "off"
	elseif not state.checkoutOpen then
		return "idle"
	elseif state.offerOpen then
		return "offer"
	elseif state.paying == "card" then
		return "card"
	elseif state.paying == "cash" then
		return "cash"
	end
	return if state.remaining > 0 then "scan" else "charge"
end

-- The drawer's tray (`width` along X, `depth` along Z, +Z toward the cashier): bills in a row at the back taking
-- `billShare` of the depth (half when not given), coins in a row in front, in Config/Payment DRAWER order, each slot a
-- little inside its share
function RegisterStationRules.drawerSlots(drawer: { number }, width: number, depth: number, billShare: number?): { Slot }
	local bills, coins = {}, {}
	for _, cents in drawer do
		table.insert(if cents >= 100 then bills else coins, cents)
	end
	local slots: { Slot } = {}
	local margin = 0.06
	local billDepth = depth * (billShare or 0.5)
	local function row(list: { number }, z: number, rowDepth: number)
		local share = width / math.max(#list, 1)
		for index, cents in list do
			table.insert(slots, {
				cents = cents,
				x = -width / 2 + share * (index - 0.5),
				z = z,
				width = share - margin * 2,
				depth = rowDepth - margin * 2,
			})
		end
	end
	row(bills, -depth / 2 + billDepth / 2, billDepth)
	row(coins, -depth / 2 + billDepth + (depth - billDepth) / 2, depth - billDepth)
	return slots
end

-- The helper glow's next note or coin (owner 2026-11-16): the biggest that still fits the change left to give; nil
-- with nothing left (or too much given). Following it always lands on the exact change (a penny is in the drawer)
function RegisterStationRules.nextPiece(drawer: { number }, remaining: number): number?
	if remaining <= 0 then
		return nil
	end
	local best: number? = nil
	for _, cents in drawer do
		if cents <= remaining and (best == nil or cents > best) then
			best = cents
		end
	end
	return best
end

-- The town's hour (Lighting.ClockTime, 0-24) as the register's clock: "9:42 AM"
function RegisterStationRules.clock(clockTime: number): string
	local minutes = math.floor((clockTime % 24) * 60 + 1e-6)
	local hour, minute = minutes // 60, minutes % 60
	local shown = if hour % 12 == 0 then 12 else hour % 12
	return string.format("%d:%02d %s", shown, minute, if hour < 12 then "AM" else "PM")
end

-- Where the nth piece of money given lands on the counter (Config/RegisterStation GIVEN), `perRow` to a row
function RegisterStationRules.givenSpot(given: { x: number, z: number, step: number }, index: number, perRow: number): { x: number, z: number }
	local column = (index - 1) % perRow
	local row = (index - 1) // perRow
	return { x = given.x + column * given.step, z = given.z - row * given.step * 1.4 }
end

-- How many coins fly into the cash pill for a sale of `amount` dollars (Config/RegisterStation SALE_FX coins): the
-- fewest, one more each time the sale doubles, never past the most
function RegisterStationRules.saleCoins(amount: number, fx: { coins: { number } }): number
	local fewest, most = fx.coins[1], fx.coins[2]
	return math.clamp(fewest + math.floor(math.log(math.max(amount, 0) + 1, 2)), fewest, most)
end

return RegisterStationRules
