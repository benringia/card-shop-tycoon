--!strict
-- What each item in the Shop window holds and what it does, for its tooltip (owner 2026-11-17: "add tooltips to the
-- items in shop to explain what Items they hold and what they do"): two short lines a child understands. Pure (no
-- requires): BuildController passes each Config/Shelves item's kind, capacity, its stock words (Config/Offline PLURALS
-- of the products it takes; nil takes any) and decor points; the shop looks and windows have their own.
local ShopTips = {}

export type Item = { kind: string, capacity: number, accepts: { string }?, bulk: boolean?, decor: number? }

-- "packs, sleeves or deck boxes"
local function joinOr(words: { string }): string
	if #words <= 1 then
		return words[1] or "stock"
	end
	return `{table.concat(words, ", ", 1, #words - 1)} or {words[#words]}`
end

-- What `item` holds and what it does; `stock`: the words for every product a shelf can take
function ShopTips.lines(item: Item, stock: { string }): { string }
	local kind = item.kind
	if kind == "Products" and item.bulk then
		return { `Holds {item.capacity} handfuls of 5 extra Commons from your binder.`, "Press Add extras to fill it. Customers buy the handfuls." }
	elseif kind == "Products" then
		return { `Holds {item.capacity} of your stock: {joinOr(item.accepts or stock)}.`, "Carry a box to it to fill it. Customers buy from it." }
	elseif kind == "CustomerCards" then
		return { `Holds {item.capacity} single cards from your binder.`, "Customers buy them at the price you set." }
	elseif kind == "PlayerCards" then
		return { `Holds {item.capacity} single cards from your binder.`, "Other players who visit your shop can buy them." }
	elseif kind == "Condenser" then
		return { "A machine: it holds no stock.", "Spare copies of a card give that card stars and Power." }
	elseif kind == "Grading" then
		return { "A machine: it holds no stock.", "Spare copies and cash raise a card's grade. Better grades sell for more." }
	elseif kind == "Forge" then
		return { "A machine: it holds no stock.", "Make weapons from Wild Ore and cash, then upgrade them." }
	elseif kind == "Decor" then
		return { `Decor +{item.decor or 0} toward your shop's rating.`, "It makes your shop cosier. Customers love a nice shop!" }
	elseif kind == "Trophy" then
		return { "A boss trophy: it holds nothing.", "Everyone who visits your shop sees it." }
	end
	return {}
end

-- A shop look (Config/Decor LOOKS)
function ShopTips.look(): { string }
	return { "A new look for your whole shop: walls, floor and trim.", "Buy it once, then switch looks any time." }
end

-- A shop window (Config/Windows), worth `points` toward the rating
function ShopTips.window(points: number): { string }
	return { "A window cut into your shop's wall.", `Decor +{points} toward your shop's rating.` }
end

return ShopTips
