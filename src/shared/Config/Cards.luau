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
}

local ELEMENTS = {
	Ember = Color3.fromRGB(235, 95, 45),
	Tide = Color3.fromRGB(50, 130, 230),
	Bloom = Color3.fromRGB(70, 175, 85),
	Volt = Color3.fromRGB(235, 195, 40),
	Shade = Color3.fromRGB(135, 70, 200),
}

-- { name, element, rarity, value }
local ROWS = {
	{ "Cindercub", "Ember", "Common", 0.20 },
	{ "Puffpuddle", "Tide", "Common", 0.20 },
	{ "Sprouthop", "Bloom", "Common", 0.20 },
	{ "Zappit", "Volt", "Common", 0.20 },
	{ "Gloomlet", "Shade", "Common", 0.30 },
	{ "Ashbeak", "Ember", "Common", 0.10 },
	{ "Shellshy", "Tide", "Common", 0.10 },
	{ "Mossmole", "Bloom", "Common", 0.10 },
	{ "Fizzlebug", "Volt", "Common", 0.15 },
	{ "Wispurr", "Shade", "Common", 0.40 },
	{ "Coalbit", "Ember", "Common", 0.15 },
	{ "Driplet", "Tide", "Common", 0.10 },
	{ "Petalpaw", "Bloom", "Common", 0.25 },
	{ "Sparkrat", "Volt", "Common", 0.15 },
	{ "Hushmoth", "Shade", "Common", 0.50 },
	{ "Blazehound", "Ember", "Rare", 2.00 },
	{ "Reefray", "Tide", "Rare", 1.50 },
	{ "Thornback", "Bloom", "Rare", 1.25 },
	{ "Boltlynx", "Volt", "Rare", 2.50 },
	{ "Nightowl", "Shade", "Rare", 3.00 },
	{ "Magmaw", "Ember", "Rare", 1.00 },
	{ "Mistfin", "Tide", "Rare", 1.25 },
	{ "Vinewyrm", "Bloom", "Rare", 1.75 },
	{ "Stormjack", "Volt", "Rare", 2.00 },
	{ "Infernox", "Ember", "Epic", 12.00 },
	{ "Abyssal Koi", "Tide", "Epic", 8.00 },
	{ "Thunderhorn", "Volt", "Epic", 10.00 },
	{ "Eclipse Fox", "Shade", "Epic", 20.00 },
	{ "Solarion", "Ember", "Legendary", 90.00 },
	{ "Voidmaw", "Shade", "Legendary", 150.00 },
	{ "Emberwing", "Ember", "Very Rare", 3.00 },
	{ "Tidecaller", "Tide", "Very Rare", 3.50 },
	{ "Briarhorn", "Bloom", "Very Rare", 4.00 },
	{ "Voltkit", "Volt", "Very Rare", 5.00 },
	{ "Duskstalker", "Shade", "Very Rare", 6.00 },
}

local List: { Card } = {}
local ById: { [string]: Card } = {}
local ByRarity: { [string]: { Card } } = {}

for index, row in ROWS do
	local card: Card = {
		id = string.format("FS%02d", index),
		number = index,
		name = row[1] :: string,
		element = row[2] :: string,
		rarity = row[3] :: string,
		value = row[4] :: number,
	}
	table.insert(List, card)
	ById[card.id] = card
	ByRarity[card.rarity] = ByRarity[card.rarity] or {}
	table.insert(ByRarity[card.rarity], card)
end

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
	ELEMENTS = ELEMENTS,
}
