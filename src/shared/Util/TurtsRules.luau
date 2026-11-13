--!strict
-- Turts' rug shop's rules (Config/Turts; TurtsService and TurtsController): the restock clock every server shares,
-- the weighted roll of 3 different offers, the once-per-restock buy check, a player's saved state across restocks,
-- his next spot, the price rule and his head shake. Pure, Lune-tested.
local TurtsRules = {}

export type State = { index: number, bought: { string }, personal: { index: number, offers: { string } }? }

-- Which restock it is at Unix time `now` (every server agrees)
function TurtsRules.restockIndex(now: number, seconds: number): number
	return math.floor(now / seconds)
end

-- Seconds until the next restock
function TurtsRules.secondsLeft(now: number, seconds: number): number
	return seconds - (math.floor(now) % seconds)
end

-- `picks` different offer ids, each picked by weight among those not yet picked; offers are walked in id order so one
-- seed always gives the same roll
function TurtsRules.roll(offers: { [string]: any }, picks: number, random: () -> number): { string }
	local ids: { string } = {}
	for id in offers do
		table.insert(ids, id)
	end
	table.sort(ids)
	local chosen: { string } = {}
	while #chosen < math.min(picks, #ids) do
		local total = 0
		for _, id in ids do
			if not table.find(chosen, id) then
				total += offers[id].weight
			end
		end
		local roll = random() * total
		local pick = nil
		for _, id in ids do
			if not table.find(chosen, id) then
				roll -= offers[id].weight
				pick = id
				if roll < 0 then
					break
				end
			end
		end
		table.insert(chosen, pick :: string)
	end
	return chosen
end

-- Whether a player can buy `offerId` now: it's still restock `state.index`, it's in their `stock` and they haven't
-- bought it this restock; else why not ("restocked", "notInStock", "bought")
function TurtsRules.canBuy(state: State, index: number, stock: { string }, offerId: string): (boolean, string?)
	if state.index ~= index then
		return false, "restocked"
	end
	if not table.find(stock, offerId) then
		return false, "notInStock"
	end
	if table.find(state.bought, offerId) then
		return false, "bought"
	end
	return true, nil
end

-- A player's state at restock `index`: unchanged within the same restock (a rejoin keeps what they bought); a new
-- restock clears what they bought and ends a "restock now" roll from an older one
function TurtsRules.refresh(state: State, index: number): State
	if state.index == index then
		return state
	end
	local personal = state.personal
	return {
		index = index,
		bought = {},
		personal = if personal and personal.index == index then personal else nil,
	}
end

-- What a player sees on his rug: their own "restock now" roll while it's for this restock, else everyone's
function TurtsRules.stockFor(state: State, index: number, global: { string }): { string }
	local personal = state.personal
	if personal and personal.index == index then
		return personal.offers
	end
	return global
end

-- His next spot (1..count), never the one he's on (`previous`; nil the first time)
function TurtsRules.nextSpot(previous: number?, count: number, random: () -> number): number
	if not previous or count < 2 then
		return math.clamp(math.floor(random() * count) + 1, 1, count)
	end
	-- one of the other count - 1 spots, the ones after `previous` wrapping round
	local step = math.clamp(math.floor(random() * (count - 1)) + 1, 1, count - 1)
	return (previous - 1 + step) % count + 1
end

-- Whether an offer costs at least `premium` times its usual value (owner: "the prices are higher than usual")
function TurtsRules.priceOk(offer: any, premium: number): boolean
	return offer.price >= offer.value * premium
end

-- His head's wobble at time `t` (degrees): a quick shake whose size drifts slowly, so it never looks mechanical
function TurtsRules.shakeAngle(t: number, shake: { degrees: number, hz: number }): number
	local size = 0.8 + 0.2 * math.sin(2 * math.pi * 0.37 * t)
	return shake.degrees * size * math.sin(2 * math.pi * shake.hz * t)
end

return TurtsRules
