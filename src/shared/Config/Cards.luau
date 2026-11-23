--!strict
-- Set 1 "First Spark" card list (37 cards; Bloom's Epic and Legendary since 2026-11-19). Names, elements and rarities from DESIGN.md section 5.4.
-- Values are market value in dollars, inside each rarity's range (Rarities.luau). Foil = value × FOIL_MULTIPLIER.
local Rarities = require((script.Parent :: Instance):WaitForChild("Rarities"))

export type Card = {
	id: string,
	number: number,
	name: string,
	element: string,
	rarity: string,
	value: number,
	set: string, -- "First Spark" (packs) or "Frontier" (Frontier drops only)
}

local ELEMENTS = {
	Ember = Color3.fromRGB(235, 95, 45),
	Tide = Color3.fromRGB(50, 130, 230),
	Bloom = Color3.fromRGB(70, 175, 85),
	Volt = Color3.fromRGB(235, 195, 40),
	Shade = Color3.fromRGB(135, 70, 200),
}

local CardList = require((script.Parent :: Instance):WaitForChild("CardList"))

local List: { Card } = {}
local ById: { [string]: Card } = {}
local ByRarity: { [string]: { Card } } = {} -- the First Spark packs' pools
local BySet: { [string]: { Card } } = { ["First Spark"] = {}, Frontier = {} }
-- Each set's cards by rarity: a pack's pools (Config/Packs `set`; the Frontier Pack's, owner 2026-11-23, pick B)
local BySetRarity: { [string]: { [string]: { Card } } } = { ["First Spark"] = ByRarity, Frontier = {} }

local function addSet(rows: { any }, set: string, prefix: string)
	for index, row in rows do
		local card: Card = {
			id = string.format("%s%02d", prefix, index),
			number = #List + 1,
			name = row[1] :: string,
			element = row[2] :: string,
			rarity = row[3] :: string,
			value = row[4] :: number,
			set = set,
		}
		table.insert(List, card)
		ById[card.id] = card
		table.insert(BySet[set], card)
		local pools = BySetRarity[set]
		pools[card.rarity] = pools[card.rarity] or {}
		table.insert(pools[card.rarity], card)
	end
end
addSet(CardList.SET1, "First Spark", "FS")
addSet(CardList.FRONTIER, "Frontier", "FR")

-- Rarest first (then highest number), for lists that show the best cards on top.
-- Card numbers are not in rarity order: the Very Rares (31-35) came after the Legendaries.
local RarestFirst = table.clone(List)
local function getOrder(card: Card): number
	local tier = Rarities.Tiers[card.rarity]
	return if tier then tier.order else 0
end
table.sort(RarestFirst, function(a, b)
	if getOrder(a) ~= getOrder(b) then
		return getOrder(a) > getOrder(b)
	end
	return a.number > b.number
end)

return {
	List = List,
	RarestFirst = RarestFirst,
	ById = ById,
	ByRarity = ByRarity,
	BySet = BySet,
	BySetRarity = BySetRarity,
	ELEMENTS = ELEMENTS,
}
