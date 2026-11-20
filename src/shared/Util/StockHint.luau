--!strict
-- The shelves that glow while you carry a box (owner 2026-11-20: "When your carrying a box. highlight the shelf with
-- the same product as you are carrying"; client StockHintController). Pure, Lune-tested (tests/StockHint).
local StockHint = {}

export type Shelf = {
	uid: string,
	kind: string, -- Config/Shelves kind: only "Products" shelves hold stock
	capacity: number,
	units: number,
	productId: string?, -- what's on it (nil: empty)
	accepts: { string }?, -- product ids it can hold, nil = any
}

local function takes(shelf: Shelf, productId: string): boolean
	return shelf.kind == "Products" and (shelf.accepts == nil or table.find(shelf.accepts, productId) ~= nil)
end

-- The uids to light up for a box of `carrying` (nil: empty hands): the shelves already holding it with room left;
-- when there are none, the empty shelves that can take it
function StockHint.pick(shelves: { Shelf }, carrying: string?): { string }
	local same: { string } = {}
	local empty: { string } = {}
	if not carrying then
		return same
	end
	for _, shelf in shelves do
		if takes(shelf, carrying) then
			if shelf.units <= 0 then
				table.insert(empty, shelf.uid)
			elseif shelf.productId == carrying and shelf.units < shelf.capacity then
				table.insert(same, shelf.uid)
			end
		end
	end
	return if #same > 0 then same else empty
end

return StockHint
