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

-- The guide's count (owner 2026-11-20: "TAP 2X,3X that decreases with every tap"): the note or coin to give next
-- (nextPiece) and how many taps of it the change left still takes; nil and 0 with nothing left (or too much given)
function RegisterStationRules.tapsLeft(drawer: { number }, remaining: number): (number?, number)
	local piece = RegisterStationRules.nextPiece(drawer, remaining)
	if not piece then
		return nil, 0
	end
	return piece, remaining // piece
end

-- The pill's words: "Tap 3x"
function RegisterStationRules.tapWords(taps: number, tag: { text: string }): string
	return string.format(tag.text, taps)
end

-- Whether the change guide shows `sinceTap` seconds after your last tap: always (owner 2026-11-20: "a permanent
-- guide/highlight for the change"; it waited HELPER_SECONDS, 5, before)
function RegisterStationRules.guideOn(sinceTap: number, cfg: { HELPER_SECONDS: number }): boolean
	return sinceTap >= cfg.HELPER_SECONDS
end

-- The town's hour (Lighting.ClockTime, 0-24) as the register's clock: "9:42 AM"
function RegisterStationRules.clock(clockTime: number): string
	local minutes = math.floor((clockTime % 24) * 60 + 1e-6)
	local hour, minute = minutes // 60, minutes % 60
	local shown = if hour % 12 == 0 then 12 else hour % 12
	return string.format("%d:%02d %s", shown, minute, if hour < 12 then "AM" else "PM")
end

-- Where the nth piece of money given lands on the counter (Config/RegisterStation GIVEN), `perRow` to a row, each row
-- a note's length (and `rowGap`) further from the cashier
function RegisterStationRules.givenSpot(given: { x: number, z: number, step: number, billSize: { number }?, rowGap: number? }, index: number, perRow: number): { x: number, z: number }
	local column = (index - 1) % perRow
	local row = (index - 1) // perRow
	local depth = if given.billSize then given.billSize[3] + (given.rowGap or 0) else given.step * 1.4
	return { x = given.x + column * given.step, z = given.z - row * depth }
end

-- The pitch of a piece's sound as it lands, `count` pieces on the counter with it (Config/RegisterStation GIVE_FX):
-- each a little higher than the last, like counting up, never past pitchMax
function RegisterStationRules.givePitch(count: number, fx: { sounds: { pitchStep: number, pitchMax: number } }): number
	return math.min(fx.sounds.pitchMax, 1 + fx.sounds.pitchStep * math.max(0, count - 1))
end

-- Where the piece just laid down sits in the row (`pieces` high to low): the last of its value; nil when it isn't there
function RegisterStationRules.addedIndex(pieces: { number }, cents: number): number?
	local found: number? = nil
	for index, value in pieces do
		if value == cents then
			found = index
		end
	end
	return found
end

-- How high over the straight line a flying piece is `u` (0-1) of the way: 0 at both ends, `arc` in the middle
function RegisterStationRules.arcLift(u: number, arc: number): number
	local v = math.clamp(u, 0, 1)
	return 4 * arc * v * (1 - v)
end

-- Whether the card machine's keys work (owner 2026-11-19: "make the card machine unusable when it's not supposed to be
-- used"): only while a customer pays by card; asleep any other time
function RegisterStationRules.keypadOn(situation: Situation): boolean
	return situation == "card"
end

-- How many coins fly into the cash pill for a sale of `amount` dollars (Config/RegisterStation SALE_FX coins): the
-- fewest, one more each time the sale doubles, never past the most
function RegisterStationRules.saleCoins(amount: number, fx: { coins: { number } }): number
	local fewest, most = fx.coins[1], fx.coins[2]
	return math.clamp(fewest + math.floor(math.log(math.max(amount, 0) + 1, 2)), fewest, most)
end

-- Whether a key press leaves the register: Leave's own key (`pill.key`, a letter), while you man it and aren't typing
function RegisterStationRules.leaveKey(key: string, pill: { key: string }, manned: boolean, typing: boolean): boolean
	return manned and not typing and key == pill.key
end

-- Looking around while you man it (testers 2026-11-26; Config/RegisterStation CAMERA.look): a drag of (dx, dy) pixels
-- turns the view `perPixel` degrees a pixel its way (right turns right: a negative yaw; up looks up), never past the
-- limits. Degrees off the step's own view
function RegisterStationRules.look(yaw: number, pitch: number, dx: number, dy: number, perPixel: number, cfg: { yaw: number, up: number, down: number }): (number, number)
	return math.clamp(yaw - dx * perPixel, -cfg.yaw, cfg.yaw), math.clamp(pitch - dy * perPixel, -cfg.down, cfg.up)
end

-- Whether a finger has moved far enough from where it touched down to be looking around (not a tap)
function RegisterStationRules.isLookDrag(fromX: number, fromY: number, toX: number, toY: number, cfg: { dragFrom: number }): boolean
	return (toX - fromX) ^ 2 + (toY - fromY) ^ 2 >= cfg.dragFrom ^ 2
end

return RegisterStationRules
