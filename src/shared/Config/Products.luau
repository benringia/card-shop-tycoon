--!strict
-- Stock catalog. Numbers come from DESIGN.md section 6.
export type Product = {
	id: string,
	name: string,
	boxCost: number, -- wholesale price per box
	unitsPerBox: number,
	marketPrice: number, -- per unit
	unlockLevel: number,
	color: { number }, -- { r, g, b } of its boxes on shelves
	boxProp: string, -- the delivery box's model (a Town.SLOTS slot, assets/props/<boxProp>.rbxm)
	icon: string, -- its picture in menus (a Config/UIIcons name)
}

local List: { Product } = {
	{ id = "FirstSparkPack", name = "First Spark Booster Pack", boxCost = 48, unitsPerBox = 24, marketPrice = 3, unlockLevel = 1, color = { 245, 150, 50 }, boxProp = "BoxPacks", icon = "BoosterPack" },
	{ id = "CardSleeves", name = "Card Sleeves", boxCost = 30, unitsPerBox = 20, marketPrice = 2.5, unlockLevel = 2, color = { 80, 150, 235 }, boxProp = "BoxSleeves", icon = "Sleeves" },
	{ id = "DeckBox", name = "Deck Box", boxCost = 60, unitsPerBox = 10, marketPrice = 9, unlockLevel = 5, color = { 150, 95, 210 }, boxProp = "BoxDecks", icon = "DeckBox" },
	{ id = "FirstSparkBox", name = "First Spark Booster Box", boxCost = 90, unitsPerBox = 1, marketPrice = 120, unlockLevel = 7, color = { 240, 200, 60 }, boxProp = "BoxBooster", icon = "BoosterBox" },
}

local ById: { [string]: Product } = {}
for _, product in List do
	ById[product.id] = product
end

return {
	List = List,
	ById = ById,
}
