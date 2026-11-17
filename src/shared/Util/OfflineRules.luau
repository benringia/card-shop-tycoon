--!strict
-- Welcome-back earnings' rules (Config/Offline; OfflineService sells the stock, WelcomeBackController shows it): how long
-- a player was away counts for, and what their shelves sell meanwhile. Pure (no requires, no Roblox APIs).
local OfflineRules = {}

export type Shelf = { units: number, price: number, chance: number } -- units on it, its price, the buy chance there
export type Plan = { sold: { number }, units: number, cash: number } -- units sold per shelf (in order), in all, the cash

type Config = { MIN_AWAY_MINUTES: number, MAX_MINUTES: number, UNITS_PER_MINUTE: number }

-- Whole minutes away that earn, from the last time the save was written (`lastSeen`, os.time) to `now`: none for a
-- save never written (0), a clock in the future or less than MIN_AWAY_MINUTES; at most MAX_MINUTES
function OfflineRules.minutesAway(lastSeen: number, now: number, cfg: Config): number
	if typeof(lastSeen) ~= "number" or lastSeen <= 0 or lastSeen ~= lastSeen then
		return 0
	end
	local minutes = math.floor((now - lastSeen) / 60)
	if minutes < cfg.MIN_AWAY_MINUTES then
		return 0
	end
	return math.min(minutes, cfg.MAX_MINUTES)
end

-- What the shelves sell in `minutes`: UNITS_PER_MINUTE customers' worth a minute, shared between the stocked shelves by
-- how much each holds; each buys at its shelf's chance (rounded down), never more than the shelf holds
function OfflineRules.plan(shelves: { Shelf }, minutes: number, cfg: Config): Plan
	local plan: Plan = { sold = {}, units = 0, cash = 0 }
	local stocked = 0
	for index, shelf in shelves do
		plan.sold[index] = 0
		if shelf.units > 0 and shelf.chance > 0 then
			stocked += shelf.units
		end
	end
	local budget = math.max(0, minutes) * cfg.UNITS_PER_MINUTE
	if stocked <= 0 or budget <= 0 then
		return plan
	end
	local cents = 0
	for index, shelf in shelves do
		if shelf.units > 0 and shelf.chance > 0 then
			local customers = budget * shelf.units / stocked
			local sold = math.min(shelf.units, math.floor(customers * math.min(shelf.chance, 1)))
			plan.sold[index] = sold
			plan.units += sold
			cents += math.round(sold * shelf.price * 100)
		end
	end
	plan.cash = cents / 100
	return plan
end

return OfflineRules
