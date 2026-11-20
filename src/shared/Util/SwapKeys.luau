--!strict
-- What a fight's swap keys do. The strip is a carousel like the party dock's (owner 2026-11-20: "in fights, should 1
-- and 3 mean left and right creature (matching the new carousel), retiring 2: YES"): the creature fighting in the
-- middle, 1 brings in the one on its left, 3 the one on its right (`sideSlot`, `center`); `pick` says what a card's key
-- or tap does: it comes in, how long a boss fight's swap is still cooling down, or that it's already fighting or
-- resting. Pure, Lune-tested.
local SwapKeys = {}

-- beastId: the key's party slot card; reserves: sim ids that may come in; fighters: yours on the field; swaps: a boss
-- fight's swaps (they cool down swapIn seconds); unsummon: a wild fight, where the card fighting can be unsummoned
-- (owner 2026-11-12; it waits out the same cooldown). Returns "swap" and the sim id, "unsummon" and the sim id,
-- "cooling" and the seconds left, "active", "resting" or "none" (an empty slot)
function SwapKeys.pick(beastId: string?, reserves: { string }, fighters: { { id: string, fainted: boolean } }, swaps: boolean, swapIn: number, unsummon: boolean?): (string, any)
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
			if unsummon and swaps and swapIn > 0.05 then
				return "cooling", swapIn
			end
			return if unsummon then "unsummon" else "active", if unsummon then id else nil
		end
	end
	return "resting", nil
end

-- The strip's middle slot: the creature fighting (`activeId`, its sim id), else the slot last there (`last`) while it
-- holds a card, else the party's first card, else slot 1
function SwapKeys.center(slots: { [number]: string }, size: number, activeId: string?, last: number?): number
	local first: number? = nil
	for slot = 1, size do
		local beastId = slots[slot]
		if beastId then
			if activeId == `a:{beastId}` then
				return slot
			end
			first = first or slot
		end
	end
	if last and slots[last] then
		return last
	end
	return first or 1
end

-- The slot key 1 ("left") or key 3 ("right") reaches from the middle (`center`): the next card round to that side,
-- empty slots skipped; the middle's own card when it's the only one (unsummoned in a wild fight, it can come back);
-- nil with no cards
function SwapKeys.sideSlot(slots: { [number]: string }, center: number, side: "left" | "right", size: number): number?
	local step = if side == "left" then -1 else 1
	local slot = center
	for _ = 1, size - 1 do
		slot = (slot - 1 + step) % size + 1
		if slots[slot] then
			return slot
		end
	end
	return if slots[center] then center else nil
end

-- `key`: the key that brings this tile's card in ("1" or "3"), when the strip has a middle
export type Tile = { slot: number, beastId: string, simId: string, state: string, seconds: number?, key: string? }

-- The fight's party strip (owner 2026-11-05, option A: "add an indication who to summon"): one tile per filled party
-- slot, 1 to `size`, in the party bar's order, each with what its key or a tap does now (pick's action, except that a
-- card that fainted in this fight is "fainted", not "resting": option C shows it face down with dizzy stars; `seconds`
-- only while it's cooling). With a middle (`center`, SwapKeys.center) the tiles go round it like the party dock's
-- carousel: its left neighbour first, then the middle, then the right, each with the key that reaches it
function SwapKeys.party(slots: { [number]: string }, size: number, reserves: { string }, fighters: { { id: string, fainted: boolean } }, swaps: boolean, swapIn: number, center: number?): { Tile }
	local tiles = {}
	local leftSlot = if center then SwapKeys.sideSlot(slots, center, "left", size) else nil
	local rightSlot = if center then SwapKeys.sideSlot(slots, center, "right", size) else nil
	for index = 1, size do
		local slot = if center then (center - 3 + index) % size + 1 else index
		local beastId = slots[slot]
		if beastId then
			local state, value = SwapKeys.pick(beastId, reserves, fighters, swaps, swapIn)
			if state == "resting" then
				for _, fighter in fighters do
					if fighter.id == `a:{beastId}` and fighter.fainted then
						state = "fainted"
					end
				end
			end
			local key: string? = nil
			if center and leftSlot == rightSlot then
				-- one card to reach (both keys do), or the middle's own: the key of the side it sits on
				key = if slot ~= leftSlot then nil elseif slot == center or index == 1 then "1" else "3"
			elseif center then
				key = if slot == leftSlot then "1" elseif slot == rightSlot then "3" else nil
			end
			table.insert(tiles, { slot = slot, beastId = beastId, simId = `a:{beastId}`, state = state, seconds = if state == "cooling" then value else nil, key = key })
		end
	end
	return tiles
end

return SwapKeys
