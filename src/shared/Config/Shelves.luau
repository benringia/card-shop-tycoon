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
	prop: string?, -- a prop slot (Config/Town) drawn on the shelf, which becomes its invisible hitbox (when the model exists)
	cardsFlat: boolean?, -- card cases drawn with a prop: cards lie on the bed (Showcase.FLAT) instead of standing
	propColors: { [string]: Color3 }?, -- recolour the prop's parts by name (e.g. Support, Carpet)
}

local List: { Shelf } = {
	{
		id = "SmallPackRack",
		prop = "Shelf",
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
		prop = "Showcase",
		cardsFlat = true, -- a glass counter: its cards lie on the velvet bed under the glass
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
		prop = "Showcase", -- the same glass counter as the Glass Showcase, in collector colours
		cardsFlat = true,
		propColors = {
			Support = Color3.fromRGB(38, 44, 70), -- dark navy base
			Frame = Color3.fromRGB(212, 175, 85), -- gold trim
			Carpet = Color3.fromRGB(40, 70, 170), -- royal blue bed
		},
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
		prop = "Condenser",
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
		prop = "WallShelf",
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
		prop = "HookRack",
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
		prop = "DisplayRack",
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
