--!strict
-- Where a customer walks when something on their list isn't on the shelves (CustomerService.searchShelves). Owner
-- 2026-11-16: "customers walk in and stand to the center of the store, make them walk in go directly to where the cards
-- are". They check shelves with something on them they haven't looked at yet; in a shop with nothing on its shelves
-- they go to its empty product shelves and look there; only a shop with no shelves sends them to the middle of the
-- floor. Collector Cases and the Card Condenser are players' only and never browsed. Pure, Lune-tested.
local ShelfSearch = {}

-- `kind` the shelf's kind (Config/Shelves): "Products" holds packs and boxes, "CustomerCards" is a Glass Showcase;
-- `stocked` whether it has something a customer could buy
export type Shelf = { uid: string, kind: string, stocked: boolean }

local BROWSED = { Products = true, CustomerCards = true }

local function takeSome(uids: { string }, count: number, roll: (count: number) -> number): { string }
	local picked: { string } = {}
	while #picked < count and #uids > 0 do
		table.insert(picked, table.remove(uids, roll(#uids)) :: string)
	end
	return picked
end

-- The shelves to walk to, in order (up to `count`), and whether to walk to the middle of the floor instead.
-- `roll(n)` picks one of n (1..n).
function ShelfSearch.pick(shelves: { Shelf }, visited: { [string]: boolean }, count: number, roll: (count: number) -> number): ({ string }, boolean)
	local stocked: { string } = {}
	local emptyProducts: { string } = {}
	for _, shelf in shelves do
		if not BROWSED[shelf.kind] or visited[shelf.uid] then
			continue
		end
		if shelf.stocked then
			table.insert(stocked, shelf.uid)
		elseif shelf.kind == "Products" then
			table.insert(emptyProducts, shelf.uid)
		end
	end
	if #stocked > 0 then
		return takeSome(stocked, count, roll), false
	end
	if next(visited) ~= nil then
		return {}, false -- they've looked already: the sigh where they stand
	end
	if #emptyProducts > 0 then
		return takeSome(emptyProducts, count, roll), false
	end
	return {}, true
end

return ShelfSearch
