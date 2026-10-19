--!strict
-- Shelf catalog. Numbers come from DESIGN.md section 4.3.
-- Sizes are in studs and should be multiples of Placement.GRID_SIZE across X and Z.
export type Shelf = {
	id: string,
	name: string,
	capacity: number, -- product units it holds
	cost: number,
	unlockLevel: number,
	size: Vector3,
	color: Color3,
	accepts: { string }?, -- product IDs it can hold, nil = any product
}

local List: { Shelf } = {
	{
		id = "SmallPackRack",
		name = "Small Pack Rack",
		capacity = 24,
		cost = 100,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 2),
		color = Color3.fromRGB(170, 110, 70),
	},
	{
		id = "WallShelf",
		name = "Wall Shelf",
		capacity = 48,
		cost = 350,
		unlockLevel = 3,
		size = Vector3.new(8, 7, 2),
		color = Color3.fromRGB(140, 95, 60),
	},
	{
		id = "GlassShowcase",
		name = "Glass Showcase",
		capacity = 6,
		cost = 800,
		unlockLevel = 4,
		size = Vector3.new(6, 4, 2),
		color = Color3.fromRGB(170, 210, 230),
		accepts = {}, -- holds single cards, handled by the showcase system later
	},
	{
		id = "AccessoryHook",
		name = "Accessory Hook",
		capacity = 20,
		cost = 250,
		unlockLevel = 5,
		size = Vector3.new(4, 6, 2),
		color = Color3.fromRGB(110, 110, 125),
		accepts = { "CardSleeves", "DeckBox" },
	},
	{
		id = "BigDisplayRack",
		name = "Big Display Rack",
		capacity = 96,
		cost = 1200,
		unlockLevel = 6,
		size = Vector3.new(8, 6, 4),
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
