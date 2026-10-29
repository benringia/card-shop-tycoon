--!strict
-- Shelf catalog. Numbers come from DESIGN.md section 4.3.
-- Sizes are in studs and should be multiples of Placement.GRID_SIZE across X and Z.
--   kind "Products":      holds stock units that NPC customers buy
--   kind "CustomerCards": displays single cards that NPC customers may buy
--   kind "PlayerCards":   displays single cards that only other players can buy
--   kind "Condenser":     a machine that combines duplicate cards for stars (holds nothing)
--   kind "Grading":       the Grading Station, a machine that raises a card's grade (holds nothing)
--   kind "Trophy":        a boss trophy (holds nothing): placing it takes its trophy item, selling gives it back
export type ShelfKind = "Products" | "CustomerCards" | "PlayerCards" | "Condenser" | "Grading" | "Trophy"

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
	cardsUpright: boolean?, -- card cases: cards stand upright over their slots and spin (CaseLayout.UPRIGHT, CaseSpinController)
	propColors: { [string]: Color3 }?, -- recolour the prop's parts by name (e.g. Support, Carpet)
	category: "Shelves" | "Cases" | "Fixtures" | "Trophies", -- the Build menu tab it's listed under
	requiresItem: string?, -- a Config/Items id placing it takes (and selling gives back); trophies only
	-- Products shelves whose model isn't a plain one-sided rack: their own stock levels and sides
	-- (Util/ShelfStock StockOverride; fractions measured from the prop model)
	stock: { LEVELS: { number }?, SIDES: { number }?, DEPTH_FILL: number? }?,
}

local List: { Shelf } = {
	{
		id = "SmallPackRack",
		prop = "Shelf",
		name = "Small Pack Rack",
		kind = "Products",
		category = "Shelves", -- Build menu tab
		capacity = 24,
		cost = 100,
		unlockLevel = 1,
		size = Vector3.new(4, 7, 2), -- height is free (the grid only uses X and Z)
		color = Color3.fromRGB(170, 110, 70),
	},
	{
		id = "GlassShowcase",
		prop = "CardCase", -- a tall glass case (Util/CaseLook)
		cardsUpright = true, -- its cards float upright and spin on light beams in their rarity colour
		name = "Glass Showcase",
		kind = "CustomerCards",
		category = "Cases", -- Build menu tab
		capacity = 6,
		cost = 250,
		unlockLevel = 1,
		size = Vector3.new(6, 4, 2),
		color = Color3.fromRGB(170, 210, 230),
	},
	{
		id = "CollectorCase",
		prop = "CardCase", -- the same glass case as the Glass Showcase, in collector colours
		cardsUpright = true,
		propColors = {
			Support = Color3.fromRGB(38, 44, 70), -- dark navy base
			Frame = Color3.fromRGB(212, 175, 85), -- gold trim
			Carpet = Color3.fromRGB(40, 70, 170), -- royal blue bed
			Strip = Color3.fromRGB(255, 205, 90), -- gold light strip
		},
		name = "Collector Case",
		kind = "PlayerCards",
		category = "Cases", -- Build menu tab
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
		category = "Fixtures", -- Build menu tab
		capacity = 0,
		cost = 500,
		unlockLevel = 4,
		size = Vector3.new(6, 7, 6), -- big enough to read as a machine (saved ones too big for their spot move over)
		color = Color3.fromRGB(90, 200, 220),
	},
	{
		id = "GradingStation",
		prop = "GradingStation",
		name = "Grading Station",
		kind = "Grading",
		category = "Fixtures", -- Build menu tab
		capacity = 0,
		cost = 5000,
		unlockLevel = 8,
		size = Vector3.new(6, 6, 4),
		color = Color3.fromRGB(230, 185, 80),
	},
	{
		id = "trophy_meadowWarden",
		prop = "Trophy",
		name = "Meadow Warden Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_meadowWarden",
		propColors = { Gem = Color3.fromRGB(70, 175, 85) },
	},
	{
		id = "trophy_caveBroodQueen",
		prop = "Trophy",
		name = "Brood Queen Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_caveBroodQueen",
		propColors = { Gem = Color3.fromRGB(135, 70, 200) },
	},
	{
		id = "trophy_emberColossus",
		prop = "Trophy",
		name = "Ember Colossus Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_emberColossus",
		propColors = { Gem = Color3.fromRGB(235, 95, 45) },
	},
	{
		id = "trophy_frostTyrant",
		prop = "Trophy",
		name = "Frost Tyrant Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_frostTyrant",
		propColors = { Gem = Color3.fromRGB(120, 200, 255) },
	},
	{
		id = "trophy_stormSovereign",
		prop = "Trophy",
		name = "Storm Sovereign Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_stormSovereign",
		propColors = { Gem = Color3.fromRGB(255, 220, 70) },
	},
	{
		id = "trophy_riftDevourer",
		prop = "Trophy",
		name = "Rift Devourer Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_riftDevourer",
		propColors = { Gem = Color3.fromRGB(150, 70, 220) },
	},
	{
		id = "trophy_prismHydra",
		prop = "Trophy",
		name = "Prism Hydra Trophy",
		kind = "Trophy",
		category = "Trophies", -- Build menu tab
		capacity = 0,
		cost = 0,
		unlockLevel = 1,
		size = Vector3.new(4, 5, 4),
		color = Color3.fromRGB(218, 176, 84),
		requiresItem = "trophy_prismHydra",
		propColors = { Gem = Color3.fromRGB(215, 240, 255) }, -- a pale prism crystal
	},
	{
		id = "WallShelf",
		prop = "WallShelf",
		name = "Wall Shelf",
		kind = "Products",
		category = "Shelves", -- Build menu tab
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
		category = "Shelves", -- Build menu tab
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
		category = "Shelves", -- Build menu tab
		capacity = 96,
		cost = 1200,
		unlockLevel = 6,
		size = Vector3.new(8, 7, 4),
		color = Color3.fromRGB(120, 80, 55),
		-- Double-sided: shelf tops at 1.04 / 2.54 / 3.85 of 7 studs, a row each side of the middle divider
		stock = { LEVELS = { 0.149, 0.362, 0.549 }, SIDES = { -0.19, 0.19 }, DEPTH_FILL = 0.3 },
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
