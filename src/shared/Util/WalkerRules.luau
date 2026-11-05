--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2): which open shop a strolling customer picks (by rating, and
-- a collector by the card it wants) and where it stops next on the plaza. Pure (Lune-tested): reads Config/Customers
-- WALKERS, passed in as cfg.
local WalkerRules = {}

export type Shop = { id: number, rating: number, open: boolean, hasWanted: boolean }
export type Stop = { kind: string, free: boolean }

-- An open shop, weighted by rating^ratingPower, times wantedBonus where a collector's card is on show; nil if none
function WalkerRules.chooseShop(cfg: any, shops: { Shop }, roll: number): number?
	local walkers = cfg.WALKERS
	local weights: { number } = {}
	local total = 0
	for index, shop in shops do
		local weight = 0
		if shop.open then
			weight = math.max(shop.rating, 0) ^ walkers.ratingPower * (if shop.hasWanted then walkers.wantedBonus else 1)
		end
		weights[index] = weight
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local left = math.clamp(roll, 0, 0.999999) * total
	local last: number? = nil
	for index, shop in shops do
		if weights[index] > 0 then
			last = shop.id
			left -= weights[index]
			if left < 0 then
				return shop.id
			end
		end
	end
	return last
end

local function pick(indices: { number }, roll: number): number
	return indices[math.clamp(math.floor(roll * #indices) + 1, 1, #indices)]
end

-- The next free stop: a free bench sitChance of the time (or whenever only benches are free), else another free stop;
-- nil when everything is taken
function WalkerRules.nextStop(cfg: any, stops: { Stop }, roll: number): number?
	local benches: { number } = {}
	local others: { number } = {}
	for index, stop in stops do
		if stop.free then
			table.insert(if stop.kind == "bench" then benches else others, index)
		end
	end
	local sitChance = cfg.WALKERS.sitChance
	if #benches > 0 and (roll < sitChance or #others == 0) then
		return pick(benches, if roll < sitChance then roll / sitChance else roll)
	end
	if #others > 0 then
		return pick(others, if roll >= sitChance then (roll - sitChance) / (1 - sitChance) else roll)
	end
	return nil
end

return WalkerRules
