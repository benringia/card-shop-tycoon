--!strict
-- A new card in a case waits for its price (owner 2026-11-17: "it automatically list at 100% market. which sometimes
-- would instantly be bought by a customer before you can set a higher price"): no customer or player buys it until the
-- owner presses Done, closes the case's window, walks away from the case (`away`, owner 2026-11-20), or the hold runs
-- out (Config/Showcase LISTING_HOLD). Pure, Lune-tested
-- (tests/ListingHold).
local ListingHold = {}

export type Holds = { [string]: { shelfUid: string, slot: number, ends: number } } -- by "<shelfUid>#<slot>"

local function key(shelfUid: string, slot: number): string
	return `{shelfUid}#{slot}`
end

function ListingHold.hold(holds: Holds, shelfUid: string, slot: number, now: number, seconds: number)
	holds[key(shelfUid, slot)] = { shelfUid = shelfUid, slot = slot, ends = now + seconds }
end

-- Whether the card in that slot still waits; a hold that ran out is forgotten
function ListingHold.isHeld(holds: Holds, shelfUid: string, slot: number, now: number): boolean
	local at = key(shelfUid, slot)
	local hold = holds[at]
	if not hold then
		return false
	end
	if now >= hold.ends then
		holds[at] = nil
		return false
	end
	return true
end

-- Whether the owner has walked away from the case: `distance` studs to it (nil: no character, or the case is gone),
-- farther than `limit` (Config/Showcase WALK_AWAY). Walking away is Done.
function ListingHold.away(distance: number?, limit: number): boolean
	return distance == nil or distance > limit
end

-- A price tap on a waiting card starts its time again; a card already on sale stays on sale. Returns whether it waits.
function ListingHold.refresh(holds: Holds, shelfUid: string, slot: number, now: number, seconds: number): boolean
	if not ListingHold.isHeld(holds, shelfUid, slot, now) then
		return false
	end
	ListingHold.hold(holds, shelfUid, slot, now, seconds)
	return true
end

-- Lets one slot go (Done), or every slot of the case (`slot` nil: its window closed). Returns the slots let go.
function ListingHold.release(holds: Holds, shelfUid: string, slot: number?): { number }
	local released: { number } = {}
	for at, hold in holds do
		if hold.shelfUid == shelfUid and (slot == nil or hold.slot == slot) then
			holds[at] = nil
			table.insert(released, hold.slot)
		end
	end
	return released
end

return ListingHold
