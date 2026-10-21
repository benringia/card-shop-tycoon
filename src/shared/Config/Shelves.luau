--!strict
-- Shelf catalog. Numbers come from DESIGN.md section 4.3.
-- Sizes are in studs and should be multiples of Placement.GRID_SIZE across X and Z.
--   kind "Products":      holds stock units that NPC customers buy
--   kind "CustomerCards": displays single cards that NPC customers may buy
--   kind "PlayerCards":   displays single cards that only other players can buy
--   kind "Condenser":     a machine that combines duplicate cards for stars (holds nothing)
export type ShelfKind = "Products" | "CustomerCards" | "PlayerCards" | "Condenser"

export type Shelf = {
	id: string,
	name: string,
	kind: ShelfKind,
	capacity: number, -- product units, or card slots for card cases
	cost: number,
	unlockLevel: number,
	size: Vector3,
	color: Color3,
	accepts: { string }?, -- product shelves only: product IDs it can hold, nil = any product
}

local List: { Shelf } = {
	{
		id = "SmallPackRack",
		name = "Small Pack Rack",
		kind = "Products",
		capacity = 24,
		cost = 100,
		unlockLevel = 1,
		size = Vector3.new(4, 7, 2), -- height is free (the grid only uses X and Z)
		color = Color3.fromRGB(170, 110, 70),
	},
	{
		id = "GlassShowcase",
		name = "Glass Showcase",
		kind = "CustomerCards",
		capacity = 6,
		cost = 250,
		unlockLevel = 1,
		size = Vector3.new(6, 4, 2),
		color = Color3.fromRGB(170, 210, 230),
	},
	{
		id = "CollectorCase",
		name = "Collector Case",
		kind = "PlayerCards",
		capacity = 6,
		cost = 300,
		unlockLevel = 1,
		size = Vector3.new(6, 4, 2),
		color = Color3.fromRGB(185, 160, 230),
	},
	{
		id = "Condenser",
		name = "Card Condenser",
		kind = "Condenser",
		capacity = 0,
		cost = 500,
		unlockLevel = 4,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(90, 200, 220),
	},
	{
		id = "WallShelf",
		name = "Wall Shelf",
		kind = "Products",
		capacity = 48,
		cost = 350,
		unlockLevel = 3,
		size = Vector3.new(8, 8, 2),
		color = Color3.fromRGB(140, 95, 60),
	},
	{
		id = "AccessoryHook",
		name = "Accessory Hook",
		kind = "Products",
		capacity = 20,
		cost = 250,
		unlockLevel = 5,
		size = Vector3.new(4, 7, 2),
		color = Color3.fromRGB(110, 110, 125),
		accepts = { "CardSleeves", "DeckBox" },
	},
	{
		id = "BigDisplayRack",
		name = "Big Display Rack",
		kind = "Products",
		capacity = 96,
		cost = 1200,
		unlockLevel = 6,
		size = Vector3.new(8, 7, 4),
		color = Color3.fromRGB(120, 80, 55),
	},
}

local ById: { [string]: Shelf } = {}
for _, shelf in List do
	ById[shelf.id] = shelf
end

return {
	List = List,
	ById = ById,
}
