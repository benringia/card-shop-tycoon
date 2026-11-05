--!strict
-- Shop rating (spec 2026-11-06-customers-design): each part of a shop scored 0-1 (shelves stocked, fair prices, cards on
-- display, happy customers, decor), the weighted mean of the parts that have a weight mapped to 1-5 stars, smoothed so
-- it moves over a minute or two, and how much it shortens or stretches the gap between customers. Pure (Lune-tested):
-- reads Config/Customers RATING, passed in as cfg.
local RatingRules = {}

export type Tip = { name: string, good: boolean }

local GOOD = { paid = true, happyMoment = true }
local BAD = { annoyed = true, gaveUp = true, noStock = true }
local DEFAULT_GOOD_FROM = 0.7

-- 1 + 4 x the weighted mean of the parts with a weight above 0 (a part missing from `parts` scores 0)
function RatingRules.score(parts: { [string]: number }, weights: { [string]: number }): number
	local total, weighted = 0, 0
	for name, weight in weights do
		if weight > 0 then
			total += weight
			weighted += weight * math.clamp(parts[name] or 0, 0, 1)
		end
	end
	if total <= 0 then
		return 3
	end
	return 1 + 4 * weighted / total
end

-- Eases `current` toward `target` over about `seconds` (dt: seconds since the last step)
function RatingRules.smooth(current: number, target: number, dt: number, seconds: number): number
	if seconds <= 0 then
		return target
	end
	return current + (target - current) * (1 - math.exp(-dt / seconds))
end

-- The spawn gap's multiplier: spawnAt1 at 1 star, 1 at 3 stars, spawnAt5 at 5 stars, straight lines between
function RatingRules.spawnScale(cfg: any, rating: number): number
	local clamped = math.clamp(rating, 1, 5)
	if clamped <= 3 then
		return cfg.RATING.spawnAt1 + (1 - cfg.RATING.spawnAt1) * (clamped - 1) / 2
	end
	return 1 + (cfg.RATING.spawnAt5 - 1) * (clamped - 3) / 2
end

-- Share of product shelves with stock on them
function RatingRules.stocked(stocked: number, shelves: number): number
	return if shelves > 0 then math.clamp(stocked / shelves, 0, 1) else 0
end

-- Fair prices: the mean of each stocked product's buy chance at its price (Pricing.BUY_BANDS) against the best band's
-- chance; 0 for a price over every band; neutral when nothing is stocked
function RatingRules.prices(bandChances: { number }, best: number): number
	if #bandChances == 0 or best <= 0 then
		return 0.5
	end
	local sum = 0
	for _, chance in bandChances do
		sum += math.clamp(chance / best, 0, 1)
	end
	return sum / #bandChances
end

-- Cards on display: points per Epic, Legendary and foil card, a full score at displayFull points
function RatingRules.displays(cfg: any, cards: { { rarity: string, foil: boolean } }): number
	local points = cfg.RATING.displayPoints
	local total = 0
	for _, card in cards do
		total += (points[card.rarity] or 0) + (if card.foil then points.foil or 0 else 0)
	end
	return math.clamp(total / cfg.RATING.displayFull, 0, 1)
end

-- Happy customers over the recent visits: paid and happy moments against annoyed, gave up and no stock; 0.5 with none
function RatingRules.happy(history: { string }): number
	local good, bad = 0, 0
	for _, outcome in history do
		if GOOD[outcome] then
			good += 1
		elseif BAD[outcome] then
			bad += 1
		end
	end
	return if good + bad > 0 then good / (good + bad) else 0.5
end

-- The tips chip: every part with a weight, heaviest first, good from `goodFrom` (0.7 when not given)
function RatingRules.tips(parts: { [string]: number }, weights: { [string]: number }, goodFrom: number?): { Tip }
	local names: { string } = {}
	for name, weight in weights do
		if weight > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		if weights[a] ~= weights[b] then
			return weights[a] > weights[b]
		end
		return a < b
	end)
	local tips: { Tip } = {}
	for _, name in names do
		table.insert(tips, { name = name, good = (parts[name] or 0) >= (goodFrom or DEFAULT_GOOD_FROM) - 1e-9 })
	end
	return tips
end

return RatingRules
