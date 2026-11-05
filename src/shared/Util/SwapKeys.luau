--!strict
-- What a fight's 1-3 key does (owner 2026-11-04): the key is the party slot as the party bar numbers it, so it brings in
-- that slot's card, says how long a boss fight's swap is still cooling down, or that the card is already fighting or
-- resting. Pure, Lune-tested.
local SwapKeys = {}

-- beastId: the key's party slot card; reserves: sim ids that may come in; fighters: yours on the field; swaps: a boss
-- fight's swaps (they cool down swapIn seconds). Returns "swap" and the sim id, "cooling" and the seconds left,
-- "active", "resting" or "none" (an empty slot)
function SwapKeys.pick(beastId: string?, reserves: { string }, fighters: { { id: string, fainted: boolean } }, swaps: boolean, swapIn: number): (string, any)
	if not beastId then
		return "none", nil
	end
	local id = `a:{beastId}`
	if table.find(reserves, id) then
		if swaps and swapIn > 0.05 then
			return "cooling", swapIn
		end
		return "swap", id
	end
	for _, fighter in fighters do
		if fighter.id == id and not fighter.fainted then
			return "active", nil
		end
	end
	return "resting", nil
end

export type Tile = { slot: number, beastId: string, simId: string, state: string, seconds: number? }

-- The fight's party strip (owner 2026-11-05, option A: "add an indication who to summon"): one tile per filled party
-- slot, 1 to `size`, in the party bar's order, each with what its key or a tap does now (pick's action; `seconds` only
-- while it's cooling)
function SwapKeys.party(slots: { [number]: string }, size: number, reserves: { string }, fighters: { { id: string, fainted: boolean } }, swaps: boolean, swapIn: number): { Tile }
	local tiles = {}
	for slot = 1, size do
		local beastId = slots[slot]
		if beastId then
			local state, value = SwapKeys.pick(beastId, reserves, fighters, swaps, swapIn)
			table.insert(tiles, { slot = slot, beastId = beastId, simId = `a:{beastId}`, state = state, seconds = if state == "cooling" then value else nil })
		end
	end
	return tiles
end

return SwapKeys
