--!strict
-- Collectors (spec 2026-11-06-customers-design): the one card a collector wants and whether they pay your price for it.
-- Pure (Lune-tested): reads Config/Customers COLLECTOR, passed in as cfg.
local CollectorRules = {}

export type CardEntry = { id: string, rarity: string }

local function pickIndex(count: number, roll: number): number
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

-- The card a collector wants: half the time (ownedShare) one of `owned` so a sale can happen, else any card of `all`,
-- each weighted by its rarity's want weight (rarer cards wanted less often)
function CollectorRules.wanted(cfg: any, owned: { string }, all: { CardEntry }, rollShare: number, rollPick: number): string
	local collector = cfg.COLLECTOR
	if #owned > 0 and (rollShare < collector.ownedShare or #all == 0) then
		return owned[pickIndex(#owned, rollPick)]
	end
	local total = 0
	for _, card in all do
		total += collector.wantWeights[card.rarity] or 0
	end
	if total <= 0 then
		return all[pickIndex(#all, rollPick)].id
	end
	local left = math.clamp(rollPick, 0, 0.999999) * total
	for _, card in all do
		left -= collector.wantWeights[card.rarity] or 0
		if left < 0 then
			return card.id
		end
	end
	return all[#all].id
end

-- Whether a collector pays `price` for a card worth `worth`: up to the premium over its worth
function CollectorRules.buys(cfg: any, price: number, worth: number): boolean
	if worth <= 0 then
		return false
	end
	return price <= worth * cfg.COLLECTOR.premium + 1e-9
end

return CollectorRules
