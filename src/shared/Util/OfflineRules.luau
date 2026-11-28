--!strict
-- Welcome-back earnings' rules (Config/Offline; OfflineService sells the stock, WelcomeBackController shows it): how long
-- a player was away counts for, and what their shelves sell meanwhile. Pure (no requires, no Roblox APIs).
local OfflineRules = {}

export type Shelf = { units: number, price: number, chance: number } -- units on it, its price, the buy chance there
export type Plan = { sold: { number }, units: number, cash: number } -- units sold per shelf (in order), in all, the cash
-- A product the Restocker can refill (it has a shelf): units on its shelves and in the racks, its price and buy chance
export type Stock = { productId: string, shelf: number, rack: number, price: number, chance: number }
-- Units sold per product (in order) from its shelves and from the racks, in all, the cash
export type RackPlan = { fromShelves: { number }, fromRacks: { number }, units: number, cash: number }

type Config = { MIN_AWAY_MINUTES: number, MAX_MINUTES: number, UNITS_PER_MINUTE: number, RACK_MINUTES: number?, MAX_EXTRA_MINUTES: number? }

-- Whether the Welcome back card may open now (WelcomeBackController): the game ready (loaded, the prologue and the welcome
-- seen), no window up, no purchase dialog or Roblox menu, and nothing on the stage or waiting for it (a weapon reveal,
-- a mutation choice, a pack opening). Bug 2026-11-27: on joining, a waiting mutation choice and the card opened on top
-- of each other (the reveal isn't a window)
function OfflineRules.cardFree(facts: { ready: boolean, panelOpen: boolean, screenClear: boolean, stageShown: boolean, revealing: boolean }): boolean
	return facts.ready and not facts.panelOpen and facts.screenClear and not facts.stageShown and not facts.revealing
end

-- A Welcome back chip's words: "1 pack", "18 packs" (Config/Offline SINGULARS and PLURALS; "items" for a product
-- without words)
function OfflineRules.soldWords(count: number, productId: string, cfg: { PLURALS: { [string]: string }, SINGULARS: { [string]: string } }): string
	if count == 1 then
		return `1 {cfg.SINGULARS[productId] or "item"}`
	end
	return `{count} {cfg.PLURALS[productId] or "items"}`
end

-- Whole minutes away that earn, from the last time the save was written (`lastSeen`, os.time) to `now`: none for a
-- save never written (0), a clock in the future or less than MIN_AWAY_MINUTES; at most `cap` (MAX_MINUTES when not
-- given; the racks' extra time raises it)
function OfflineRules.minutesAway(lastSeen: number, now: number, cfg: Config, cap: number?): number
	if typeof(lastSeen) ~= "number" or lastSeen <= 0 or lastSeen ~= lastSeen then
		return 0
	end
	local minutes = math.floor((now - lastSeen) / 60)
	if minutes < cfg.MIN_AWAY_MINUTES then
		return 0
	end
	return math.min(minutes, cap or cfg.MAX_MINUTES)
end

-- The time away split in two (spec 2026-11-24-shop-variety-design): the shelves' MAX_MINUTES, then with a Restocker
-- RACK_MINUTES for each of `racks` racks holding boxes, at most MAX_EXTRA_MINUTES, selling only what's in the racks
-- The limits with Night Shift (the game pass; Robux round, spec 2026-11-28-robux-round-design): a copy of `cfg` with
-- MAX_MINUTES and MAX_EXTRA_MINUTES times `factor` when it's owned
function OfflineRules.caps(cfg: Config, nightShift: boolean, factor: number): Config
	local copy = table.clone(cfg)
	if nightShift then
		copy.MAX_MINUTES = cfg.MAX_MINUTES * factor
		copy.MAX_EXTRA_MINUTES = (cfg.MAX_EXTRA_MINUTES or 0) * factor
	end
	return copy
end

-- The most minutes away a shop sells for with this setup: MAX_MINUTES, plus each rack of boxes' RACK_MINUTES (at most
-- MAX_EXTRA_MINUTES) with a Restocker
function OfflineRules.limit(cfg: Config, racks: number, restocker: boolean): number
	local extra = if restocker and racks > 0 then math.min(racks * (cfg.RACK_MINUTES or 0), cfg.MAX_EXTRA_MINUTES or 0) else 0
	return cfg.MAX_MINUTES + extra
end

export type NightNote = { owned: boolean, sold: number, other: number }

-- The Welcome back card's Night Shift line, only when away past the normal limit: with the pass, minutes sold and what
-- it would have been without; without it, minutes sold and what Night Shift sells (minutes)
function OfflineRules.nightShiftNote(away: number, normal: number, shift: number, owned: boolean): NightNote?
	if away <= normal then
		return nil
	end
	if owned then
		return { owned = true, sold = math.min(away, shift), other = normal }
	end
	return { owned = false, sold = normal, other = shift }
end

-- Minutes as hours in plain words: "2", "2.5", "3.3"
function OfflineRules.hoursText(minutes: number): string
	local hours = math.floor(minutes / 6 + 0.5) / 10
	return if hours == math.floor(hours) then tostring(math.floor(hours)) else string.format("%.1f", hours)
end

function OfflineRules.split(minutes: number, racks: number, restocker: boolean, cfg: Config): (number, number)
	local base = math.min(math.max(0, minutes), cfg.MAX_MINUTES)
	if not restocker or racks <= 0 then
		return base, 0
	end
	local extra = math.min(minutes - base, racks * (cfg.RACK_MINUTES or 0), cfg.MAX_EXTRA_MINUTES or 0)
	return base, math.max(0, extra)
end

-- What sells with a Restocker refilling the shelves from the racks: in the `base` minutes UNITS_PER_MINUTE customers'
-- worth a minute, shared by how much of each product there is (shelves and racks), each bought at its chance, from
-- the shelves first then the racks; in the `extra` minutes the same pace, but only what's left in the racks
function OfflineRules.planRacks(stock: { Stock }, base: number, extra: number, cfg: Config): RackPlan
	local plan: RackPlan = { fromShelves = {}, fromRacks = {}, units = 0, cash = 0 }
	local pool = 0
	for index, item in stock do
		plan.fromShelves[index] = 0
		plan.fromRacks[index] = 0
		if item.chance > 0 then
			pool += item.shelf + item.rack
		end
	end
	local budget = math.max(0, base) * cfg.UNITS_PER_MINUTE
	if pool > 0 and budget > 0 then
		for index, item in stock do
			local have = item.shelf + item.rack
			if have > 0 and item.chance > 0 then
				local sold = math.min(have, math.floor(budget * have / pool * math.min(item.chance, 1)))
				local fromShelf = math.min(item.shelf, sold)
				plan.fromShelves[index] = fromShelf
				plan.fromRacks[index] = sold - fromShelf
			end
		end
	end
	local left = 0
	for index, item in stock do
		if item.chance > 0 then
			left += item.rack - plan.fromRacks[index]
		end
	end
	local more = math.max(0, extra) * cfg.UNITS_PER_MINUTE
	if left > 0 and more > 0 then
		for index, item in stock do
			local rack = item.rack - plan.fromRacks[index]
			if rack > 0 and item.chance > 0 then
				plan.fromRacks[index] += math.min(rack, math.floor(more * rack / left * math.min(item.chance, 1)))
			end
		end
	end
	local cents = 0
	for index, item in stock do
		local units = plan.fromShelves[index] + plan.fromRacks[index]
		plan.units += units
		cents += math.round(units * item.price * 100)
	end
	plan.cash = cents / 100
	return plan
end

-- `units` taken from boxes holding `boxes` units each: the half-used (fewest) first, then in order. Returns what's
-- taken from each box (in the boxes' order) and how many boxes were touched
function OfflineRules.boxTakes(boxes: { number }, units: number): ({ number }, number)
	local order: { number } = {}
	local takes: { number } = {}
	for index in boxes do
		table.insert(order, index)
		takes[index] = 0
	end
	table.sort(order, function(a: number, b: number): boolean
		if boxes[a] ~= boxes[b] then
			return boxes[a] < boxes[b]
		end
		return a < b
	end)
	local need, touched = math.max(0, math.floor(units)), 0
	for _, index in order do
		if need <= 0 then
			break
		end
		local take = math.min(need, boxes[index])
		if take > 0 then
			takes[index] = take
			need -= take
			touched += 1
		end
	end
	return takes, touched
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
