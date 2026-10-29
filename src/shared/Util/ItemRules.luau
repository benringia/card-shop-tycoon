--!strict
-- Item inventory rules: what a saved inventory may hold, and adding or taking items without going past the
-- stack limit or below zero. Pure (no requires, no Roblox APIs): callers pass Config/Items in.
local ItemRules = {}

type Config = { MAX_STACK: number, ITEMS: { [string]: any } }
export type Items = { [string]: number }

local function whole(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

-- Known items with whole, positive counts, capped at the stack limit
function ItemRules.sanitize(config: Config, raw: unknown): Items
	local items: Items = {}
	if typeof(raw) ~= "table" then
		return items
	end
	for id, count in raw :: { [any]: any } do
		local amount = whole(count)
		if typeof(id) == "string" and config.ITEMS[id] and amount and amount > 0 then
			items[id] = math.min(amount, config.MAX_STACK)
		end
	end
	return items
end

-- A new inventory with up to n more of the item, and how many actually fit
function ItemRules.add(config: Config, items: Items, id: string, n: number): (Items, number)
	local result = table.clone(items)
	local amount = whole(n)
	if not config.ITEMS[id] or not amount or amount <= 0 then
		return result, 0
	end
	local before = result[id] or 0
	local after = math.min(before + amount, config.MAX_STACK)
	result[id] = if after > 0 then after else nil
	return result, after - before
end

-- A new inventory with n fewer of the item, or nil if there aren't that many
function ItemRules.take(items: Items, id: string, n: number): Items?
	local amount = whole(n)
	local have = items[id] or 0
	if not amount or amount > have then
		return nil
	end
	local result = table.clone(items)
	local left = have - amount
	result[id] = if left > 0 then left else nil
	return result
end

-- Which ladder step a boss item belongs to: a fragment the boss it opens, a trophy the boss beaten (ids
-- fragment_<bossId> and trophy_<bossId>); nil for any other item or an unknown boss
function ItemRules.bossOf(itemId: string, ladder: { string }): (number?, ("fragment" | "trophy")?)
	local kind, bossId = string.match(itemId, "^(%a+)_(%w+)$")
	if kind ~= "fragment" and kind ~= "trophy" then
		return nil, nil
	end
	local index = table.find(ladder, bossId :: string)
	if not index then
		return nil, nil
	end
	return index, if kind == "fragment" then "fragment" else "trophy"
end

return ItemRules
