--!strict
-- Stock catalog. Numbers come from DESIGN.md section 6.
export type Product = {
	id: string,
	name: string,
	boxCost: number, -- wholesale price per box
	unitsPerBox: number,
	marketPrice: number, -- per unit
	unlockLevel: number,
}

local List: { Product } = {
	{ id = "FirstSparkPack", name = "First Spark Booster Pack", boxCost = 48, unitsPerBox = 24, marketPrice = 3, unlockLevel = 1 },
	{ id = "CardSleeves", name = "Card Sleeves", boxCost = 30, unitsPerBox = 20, marketPrice = 2.5, unlockLevel = 2 },
	{ id = "DeckBox", name = "Deck Box", boxCost = 60, unitsPerBox = 10, marketPrice = 9, unlockLevel = 5 },
	{ id = "FirstSparkBox", name = "First Spark Booster Box", boxCost = 90, unitsPerBox = 1, marketPrice = 120, unlockLevel = 7 },
}

local ById: { [string]: Product } = {}
for _, product in List do
	ById[product.id] = product
end

return {
	List = List,
	ById = ById,
}
