--!strict
-- Bargain hunters at the register (spec 2026-11-06-customers-design): their offer under the total, the most they pay
-- (never shown), the counter's range and face, and what a cashier settles on. Pure (Lune-tested): reads
-- Config/Customers HAGGLE and OFFER.moodBand, passed in as cfg. Money is rounded to cents.
local HaggleRules = {}

export type Edges = { sure: number, maybe: number }

local function cents(value: number): number
	return math.round(value * 100) / 100
end

local function between(low: number, high: number, roll: number): number
	return low + (high - low) * math.clamp(roll, 0, 1)
end

-- Their offer: 10-25% under the total
function HaggleRules.offer(cfg: any, total: number, roll: number): number
	return cents(total * (1 - between(cfg.HAGGLE.offLow, cfg.HAGGLE.offHigh, roll)))
end

-- The most they pay: part of the way from their offer back up to the total
function HaggleRules.ceiling(cfg: any, offer: number, total: number, roll: number): number
	return cents(offer + (total - offer) * between(cfg.HAGGLE.gapLow, cfg.HAGGLE.gapHigh, roll))
end

-- The owner's counter runs from their offer up to the full total
function HaggleRules.counterRange(offer: number, total: number): (number, number)
	return offer, total
end

function HaggleRules.accepts(price: number, ceiling: number): boolean
	return price <= ceiling + 1e-9
end

-- A cashier meets them halfway, and they always take it
function HaggleRules.cashierPrice(offer: number, total: number): number
	return cents((offer + total) / 2)
end

-- The face for the client (lower is better for them): sure up to `sure`, maybe up to `maybe`, so it never learns the
-- ceiling exactly
function HaggleRules.moodEdges(cfg: any, ceiling: number, total: number): Edges
	local band = total * cfg.OFFER.moodBand
	return { sure = cents(ceiling - band), maybe = cents(ceiling + band) }
end

return HaggleRules
