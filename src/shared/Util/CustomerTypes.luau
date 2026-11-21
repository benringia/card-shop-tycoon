--!strict
-- Customer types (spec 2026-11-06-customers-design): which type walks in (Config/Customers TYPES, TYPE_ORDER) and
-- whether a type buys at a price. Pure (Lune-tested): the price bands come in as an argument (Config/Pricing
-- BUY_BANDS), since a pure module can't require its siblings.
local CustomerTypes = {}

export type Context = { hasShowcase: boolean, shopLevel: number }
export type Band = { maxRatio: number, chance: number }

local function allowed(spec: any, context: Context): boolean
	if spec.needsShowcase and not context.hasShowcase then
		return false
	end
	return spec.minLevel == nil or context.shopLevel >= spec.minLevel
end

-- The type of the next customer for a roll in [0, 1): the types this shop can have, by weight, in TYPE_ORDER
function CustomerTypes.pick(cfg: any, context: Context, roll: number): string
	local total = 0
	for _, kind in cfg.TYPE_ORDER do
		local spec = cfg.TYPES[kind]
		if allowed(spec, context) then
			total += spec.weight
		end
	end
	local left = math.clamp(roll, 0, 0.999999) * total
	local last = "plain"
	for _, kind in cfg.TYPE_ORDER do
		local spec = cfg.TYPES[kind]
		if allowed(spec, context) then
			last = kind
			left -= spec.weight
			if left < 0 then
				return kind
			end
		end
	end
	return last
end

-- How many price bands higher than a plain customer this type still buys in
function CustomerTypes.tolerance(cfg: any, kind: string): number
	local spec = cfg.TYPES[kind]
	return if spec and spec.tolerance then spec.tolerance else 0
end

-- Where a price sits among `bands`: its band's index (past the last band, more bands follow as wide as the last one)
-- and how far up that band it is, 0 at its cheapest price to 1 at its dearest (the first band has no up: 0)
local function place(price: number, market: number, bands: { Band }): (number, number)
	local ratio = price / market
	local lower = 0
	for i, band in bands do
		if ratio <= band.maxRatio + 1e-9 then
			if i == 1 then
				return 1, 0
			end
			return i, math.clamp((ratio - lower) / math.max(band.maxRatio - lower, 1e-6), 0, 1)
		end
		lower = band.maxRatio
	end
	local last = bands[#bands].maxRatio
	local width = math.max(last - (if #bands > 1 then bands[#bands - 1].maxRatio else 0), 1e-6)
	local over = (ratio - last) / width
	local steps = math.max(1, math.ceil(over - 1e-9))
	return #bands + steps, math.clamp(over - (steps - 1), 0, 1)
end

-- The band a price falls in for this type: its index in `bands` (past the last band, more bands follow as wide as the
-- last one), shifted `tolerance` bands cheaper; past the last band means it won't buy
local function shiftedBand(cfg: any, kind: string, price: number, market: number, bands: { Band }): number
	if market <= 0 or #bands == 0 then
		return #bands + 1
	end
	local index = place(price, market, bands)
	return math.max(1, index - CustomerTypes.tolerance(cfg, kind))
end

-- The chance a customer who looks `tolerance` bands dearer than a plain one buys at `price`. It slides inside a band
-- (owner 2026-11-20: "The prices can be abused ... the players set prices to the final step of the sometimes buy":
-- flat across a band, its dearest price cost nothing): the band's own chance at its cheapest price, down in a straight
-- line to the next band's at its dearest (nobody's after the last band). The best band stays flat: at market price
-- and under, almost always.
local function chanceFor(tolerance: number, price: number, market: number, bands: { Band }): number
	if market <= 0 or #bands == 0 then
		return 0
	end
	local index, up = place(price, market, bands)
	local shifted = math.max(1, index - tolerance)
	local band = bands[shifted]
	if not band then
		return 0
	elseif shifted == 1 then
		return band.chance
	end
	local after = bands[shifted + 1]
	return band.chance + ((if after then after.chance else 0) - band.chance) * up
end

-- The chance this type buys at `price` against `market` (before any perk)
function CustomerTypes.chance(cfg: any, kind: string, price: number, market: number, bands: { Band }): number
	return chanceFor(CustomerTypes.tolerance(cfg, kind), price, market, bands)
end

-- ...and a plain customer's (the Prices window, cards in a Glass Showcase, welcome-back sales, the rating's fair prices)
function CustomerTypes.plainChance(price: number, market: number, bands: { Band }): number
	return chanceFor(0, price, market, bands)
end

-- What the Prices window says under a product at `price`: the best band's own words ("Always buy"), then how many buy
-- ("33% buy": each step up shows what it costs), `never` once nobody does
function CustomerTypes.priceTag(price: number, market: number, bands: { Band }, never: string): string
	local chance = chanceFor(0, price, market, bands)
	if chance <= 0 or market <= 0 or #bands == 0 then
		return never
	elseif place(price, market, bands) == 1 then
		return (bands[1] :: any).tag
	end
	return `{math.max(1, math.floor(chance * 100 + 0.5 + 1e-6))}% buy`
end

-- Whether this type won't buy at all at `price` (past its last band): the annoyed bubble
function CustomerTypes.outOfReach(cfg: any, kind: string, price: number, market: number, bands: { Band }): boolean
	return shiftedBand(cfg, kind, price, market, bands) > #bands
end

-- Whether this type buys at `price` against `market`: its chance there (raised by a perk) against roll
function CustomerTypes.buys(cfg: any, kind: string, price: number, market: number, roll: number, perkBonus: number, bands: { Band }): boolean
	return CustomerTypes.chance(cfg, kind, price, market, bands) * (1 + perkBonus) > roll
end

-- What a customer does at a shelf priced `price`: "buy", "pricey" (out of its reach: the annoyed bubble) or "pass".
-- `sure` (Pish's tutorial customer, owner 2026-11-20: "the customer should always buy so that players dont have to
-- wait for a buying customer"): it always buys
function CustomerTypes.decides(cfg: any, kind: string, price: number, market: number, roll: number, perkBonus: number, bands: { Band }, sure: boolean?): string
	if sure then
		return "buy"
	elseif CustomerTypes.outOfReach(cfg, kind, price, market, bands) then
		return "pricey"
	end
	return if CustomerTypes.buys(cfg, kind, price, market, roll, perkBonus, bands) then "buy" else "pass"
end

type Sizes = { { count: number, new: number, late: number } }

-- How much of a new shop's boost a shop at `level` still has (Config/Customers NEW_SHOP): 1 up to fullUntil, 0 from
-- goneAt, straight down in between
function CustomerTypes.newShopShare(cfg: any, level: number): number
	local boost = cfg.NEW_SHOP
	if level <= boost.fullUntil then
		return 1
	elseif level >= boost.goneAt then
		return 0
	end
	return (boost.goneAt - level) / (boost.goneAt - boost.fullUntil)
end

-- What a customer leaves on top of a sale of `total` (to the cent): a big spender BIG_SPENDER.tip of it, every time;
-- the TIPS types a share of it now and then (`chanceRoll` under TIPS.chance; the share by `shareRoll`, at least
-- TIPS.min). `fair`: every product was at or under its market price; nobody tips over that
function CustomerTypes.tip(cfg: any, kind: string, total: number, fair: boolean, chanceRoll: number, shareRoll: number): number
	if not fair or total <= 0 then
		return 0
	end
	if kind == "bigSpender" then
		return math.round(total * cfg.BIG_SPENDER.tip * 100) / 100
	end
	local tips = cfg.TIPS
	if not tips or not tips.types[kind] or chanceRoll >= tips.chance then
		return 0
	end
	local share = tips.share[1] + (tips.share[2] - tips.share[1]) * math.clamp(shareRoll, 0, 1)
	return math.max(tips.min, math.round(total * share * 100) / 100)
end

-- The gap between customers times this at `level`: a new shop's NEW_SHOP.gap (about 1.4x as many customers), back to 1
function CustomerTypes.newShopGap(cfg: any, level: number): number
	return 1 + (cfg.NEW_SHOP.gap - 1) * CustomerTypes.newShopShare(cfg, level)
end

-- Each size's share at `level`: the new shop's shares blended into the late ones
local function shares(cfg: any, sizes: Sizes, level: number): { number }
	local share = CustomerTypes.newShopShare(cfg, level)
	local newTotal, lateTotal = 0, 0
	for _, entry in sizes do
		newTotal += entry.new
		lateTotal += entry.late
	end
	local out = {}
	for index, entry in sizes do
		local early = if newTotal > 0 then entry.new / newTotal else 0
		local late = if lateTotal > 0 then entry.late / lateTotal else 0
		out[index] = late + (early - late) * share
	end
	return out
end

-- A size picked by `roll` (0-1): each size's share of the rolls is its share at `level`
local function pickCount(cfg: any, sizes: Sizes, roll: number, level: number): number
	local weights = shares(cfg, sizes, level)
	local at = math.clamp(roll, 0, 0.999999)
	for index, entry in sizes do
		at -= weights[index]
		if at < 0 then
			return entry.count
		end
	end
	for index = #sizes, 1, -1 do
		if weights[index] > 0 then
			return sizes[index].count
		end
	end
	return sizes[#sizes].count
end

local function meanCount(cfg: any, sizes: Sizes, level: number): number
	local weights = shares(cfg, sizes, level)
	local sum = 0
	for index, entry in sizes do
		sum += entry.count * weights[index]
	end
	return sum
end

-- How many things a customer wants at shop `level` (Config/Customers LIST_SIZE): a new shop's usually 3 or 4, rarely
-- 1; 1 to 3 from NEW_SHOP.goneAt
function CustomerTypes.listSize(cfg: any, roll: number, level: number): number
	return pickCount(cfg, cfg.LIST_SIZE, roll, level)
end

function CustomerTypes.meanListSize(cfg: any, level: number): number
	return meanCount(cfg, cfg.LIST_SIZE, level)
end

-- How many packs a kid buys at shop `level` (Config/Customers KID.units): a new shop's mostly 2 or 3, later 1 or 2
function CustomerTypes.kidUnits(cfg: any, roll: number, level: number): number
	return pickCount(cfg, cfg.KID.units, roll, level)
end

function CustomerTypes.meanKidUnits(cfg: any, level: number): number
	return meanCount(cfg, cfg.KID.units, level)
end

-- How many of the `wanted` a customer of this type takes at `price` in a shop at `level` (owner 2026-11-19:
-- "specially if its market price"): while the new shop's boost lasts, all of them in their cheapest band (at or under
-- market for most), one fewer a band over, just one past that; once it's gone, all of them as before
function CustomerTypes.unitsAt(cfg: any, kind: string, wanted: number, price: number, market: number, bands: { Band }, level: number): number
	if CustomerTypes.newShopShare(cfg, level) <= 0 then
		return math.max(1, wanted)
	end
	local band = shiftedBand(cfg, kind, price, market, bands)
	if band <= 1 then
		return math.max(1, wanted)
	elseif band == 2 then
		return math.max(1, wanted - 1)
	end
	return 1
end

return CustomerTypes
