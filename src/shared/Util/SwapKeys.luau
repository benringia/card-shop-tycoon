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

return SwapKeys
