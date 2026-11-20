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

-- The pack a Bag item opens (its `open` product id), or nil for a non-string, unknown or non-openable id
function ItemRules.openablePack(config: Config, itemId: any): (string?, string?, boolean)
	if typeof(itemId) ~= "string" then
		return nil, nil, false
	end
	local info = config.ITEMS[itemId]
	if typeof(info) ~= "table" or typeof(info.open) ~= "string" then
		return nil, nil, false
	end
	-- `floor`: the lowest rarity its hit card can be (Pish's gift: Very Rare); `stingyGrade`: its hit card's grade rolls
	-- the pity Legendary's stingy odds (Turts' Legendary Pack)
	return info.open, if typeof(info.floor) == "string" then info.floor else nil, info.stingyGrade == true
end

-- The Bag item a carried box of `productId` becomes (To Bag), or nil for a product with none
function ItemRules.stockItem(config: Config, productId: any): string?
	if typeof(productId) ~= "string" then
		return nil
	end
	for id, info in config.ITEMS do
		if typeof(info) == "table" and info.stock == productId then
			return id
		end
	end
	return nil
end

-- The shop product a Bag item is (its `stock`): opening one gives that product's market price in shop XP, like ripping
-- it from a carried box. Nil for gifts and every other item.
function ItemRules.stockOf(config: Config, itemId: any): string?
	if typeof(itemId) ~= "string" then
		return nil
	end
	local info = config.ITEMS[itemId]
	return if typeof(info) == "table" and typeof(info.stock) == "string" then info.stock else nil
end

-- How many of a Bag's stock item go back to the shop in one box (the Bag's To shop button; owner 2026-11-20): what's
-- there up to a box's worth (`perBox`), none without room for a box on the delivery pad (`room`: boxes it can take)
function ItemRules.boxUnits(have: number, perBox: number, room: number): number
	local whole = if typeof(have) == "number" and have == have then math.floor(have) else 0
	if whole < 1 or room < 1 then
		return 0
	end
	return math.min(whole, perBox)
end

-- How many packs Open 10 opens from a stack of `have` (owner 2026-11-17): up to `max`, and only from two up (one pack
-- has just Open)
function ItemRules.openMany(have: number, max: number): number
	local whole = if typeof(have) == "number" and have == have then math.floor(have) else 0
	return if whole >= 2 then math.min(whole, max) else 0
end

-- Whether a Bag item is placed in your shop from the Bag (its Place button; owner 2026-11-17): the boss trophies, each
-- its own Config/Shelves entry by the same id
function ItemRules.placesInShop(config: Config, itemId: any): boolean
	if typeof(itemId) ~= "string" then
		return false
	end
	local info = config.ITEMS[itemId]
	return typeof(info) == "table" and info.trophy == true
end

export type TonicTarget = { slot: number, beastId: string, cardId: string, level: number, xp: number, maxed: boolean }

-- The party cards an XP Tonic can go on (the Bag's picker), in slot order: empty slots and cards the binder doesn't
-- hold are left out; a card at `maxLevel` is listed as maxed (the server never wastes a tonic on it)
function ItemRules.tonicTargets(slots: { [number]: string }, beasts: { [string]: any }, partySize: number, maxLevel: number): { TonicTarget }
	local targets: { TonicTarget } = {}
	for slot = 1, partySize do
		local beastId = slots[slot]
		local beast = if beastId then beasts[beastId] else nil
		if beastId and beast then
			table.insert(targets, { slot = slot, beastId = beastId, cardId = beast.cardId, level = beast.level, xp = beast.xp, maxed = beast.level >= maxLevel })
		end
	end
	return targets
end

return ItemRules
