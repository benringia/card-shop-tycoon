--!strict
-- Kid offers (spec 2026-11-06-customers-design): whether a kid sells the card they pulled, what they ask, the lowest
-- they take, the ceilings on how often offers come, and the counter's range, steps and face. Pure (Lune-tested): reads
-- Config/Customers OFFER, passed in as cfg. Money is rounded to cents.
local OfferRules = {}

export type History = { offers: { number }, lastLegendary: number? }
export type Mood = "sure" | "maybe" | "no"
export type Edges = { sure: number, maybe: number }

local function cents(value: number): number
	return math.round(value * 100) / 100
end

local function between(low: number, high: number, roll: number): number
	return low + (high - low) * math.clamp(roll, 0, 1)
end

-- A kid sells a pull by its rarity's chance times its grade's factor (better grades are kept more often)
function OfferRules.wantsToSell(cfg: any, rarity: string, grade: string, roll: number): boolean
	local offer = cfg.OFFER
	local chance = offer.chance[rarity]
	if not chance then
		return false
	end
	return chance * (offer.gradeFactor[grade] or 1) > roll
end

-- What the kid asks: about what the card's worth
function OfferRules.asking(cfg: any, worth: number, roll: number): number
	return cents(worth * between(cfg.OFFER.askLow, cfg.OFFER.askHigh, roll))
end

-- The lowest the kid takes (never shown to the owner)
function OfferRules.lowest(cfg: any, worth: number, roll: number): number
	return cents(worth * between(cfg.OFFER.lowestLow, cfg.OFFER.lowestHigh, roll))
end

-- Under the ceilings: at most perHour offers in the last hour, and no Legendary within legendaryGap of the last one
function OfferRules.allowed(cfg: any, history: History, now: number, rarity: string): boolean
	local offer = cfg.OFFER
	local recent = 0
	for _, at in history.offers do
		if now - at < 3600 then
			recent += 1
		end
	end
	if recent >= offer.perHour then
		return false
	end
	local last = history.lastLegendary
	return rarity ~= "Legendary" or last == nil or now - last > offer.legendaryGap
end

-- The owner's counter runs from half the card's worth up to the kid's asking price
function OfferRules.counterRange(worth: number, asking: number): (number, number)
	return cents(worth * 0.5), asking
end

-- One - / + tap on the counter: a share of the worth, never under a cent
function OfferRules.step(cfg: any, worth: number): number
	return math.max(0.01, cents(worth * cfg.OFFER.step))
end

-- What the client gets for the kid's face: sure from `sure` up, maybe from `maybe` up, so it never learns the lowest
function OfferRules.moodEdges(cfg: any, lowest: number, worth: number): Edges
	local band = worth * cfg.OFFER.moodBand
	return { sure = cents(lowest + band), maybe = cents(lowest - band) }
end

function OfferRules.mood(cfg: any, price: number, lowest: number, worth: number): Mood
	local edges = OfferRules.moodEdges(cfg, lowest, worth)
	if price >= edges.sure - 1e-9 then
		return "sure"
	elseif price >= edges.maybe - 1e-9 then
		return "maybe"
	end
	return "no"
end

function OfferRules.accepts(price: number, lowest: number): boolean
	return price >= lowest - 1e-9
end

-- The kid waits `patience` seconds for an answer
function OfferRules.expired(cfg: any, startedAt: number, now: number): boolean
	return now - startedAt >= cfg.OFFER.patience
end

function OfferRules.canPay(cash: number, price: number): boolean
	return cash >= price - 1e-9
end

return OfferRules
