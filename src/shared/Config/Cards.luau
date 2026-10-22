--!strict
-- Set 1 "First Spark" card list (35 cards). Names, elements and rarities from DESIGN.md section 5.4.
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
local ByRarity: { [string]: { Card } } = {} -- pack pools: First Spark only
local BySet: { [string]: { Card } } = { ["First Spark"] = {}, Frontier = {} }

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
		if set == "First Spark" then
			ByRarity[card.rarity] = ByRarity[card.rarity] or {}
			table.insert(ByRarity[card.rarity], card)
		end
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
	ELEMENTS = ELEMENTS,
}
