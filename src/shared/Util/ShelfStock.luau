--!strict
-- Stock boxes on Products shelves: how many show and where they sit (main town follow-up). Pure, Lune-tested.
-- Positions are in the shelf part's space: centre at the origin, front at -Z.
export type Vec = { x: number, y: number, z: number }
export type Slot = { x: number, y: number, z: number, back: boolean } -- back: on the far side, facing +Z
export type StockConfig = {
	LEVELS: { number }, -- bottom of each level's boxes, as a fraction of the shelf height
	PER_LEVEL: number, -- boxes in a row (per side)
	BOX_HEIGHT: number, -- studs
	WIDTH_FILL: number, -- of each box's share of the shelf width
	DEPTH_FILL: number, -- of the shelf depth (a double-sided shelf: of one side)
	SIDES: { number }?, -- row centres front to back as fractions of the depth (-0.5 front .. 0.5 back); nil = { 0 }
}
-- A shelf's own overrides (Config/Shelves `stock`), e.g. a double-sided rack's levels and sides
export type StockOverride = { LEVELS: { number }?, SIDES: { number }?, DEPTH_FILL: number? }

local ShelfStock = {}

-- The base layout with a shelf's overrides on top
function ShelfStock.configFor(base: StockConfig, override: StockOverride?): StockConfig
	local config = table.clone(base)
	if override then
		config.LEVELS = override.LEVELS or config.LEVELS
		config.SIDES = override.SIDES or config.SIDES
		config.DEPTH_FILL = override.DEPTH_FILL or config.DEPTH_FILL
	end
	return config
end

local function sidesOf(config: StockConfig): { number }
	return config.SIDES or { 0 }
end

function ShelfStock.slotCount(config: StockConfig): number
	return #config.LEVELS * config.PER_LEVEL * #sidesOf(config)
end

-- A stocked row (1 = bottom level, front side) as its level and side
function ShelfStock.row(index: number, sideCount: number): (number, number)
	return (index - 1) // sideCount + 1, (index - 1) % sideCount + 1
end

-- Any stock shows at least one box; a full shelf fills every slot
function ShelfStock.boxCount(units: number, capacity: number, slots: number): number
	if capacity <= 0 or units <= 0 then
		return 0
	end
	return math.ceil(math.min(units, capacity) / capacity * slots)
end

-- Packs a display box shows (UI project 3): box `index` holds its share (capacity / slots) of the shelf's units, the
-- earlier boxes full first; a box with any units shows at least one pack, one past the stocked boxes shows none
function ShelfStock.boxFill(units: number, capacity: number, slots: number, index: number, shown: number): number
	if index > ShelfStock.boxCount(units, capacity, slots) then
		return 0
	end
	local perBox = capacity / slots
	local fill = math.clamp((math.min(units, capacity) - (index - 1) * perBox) / perBox, 0, 1)
	return math.max(1, math.ceil(fill * shown - 1e-9))
end

function ShelfStock.boxSize(shelf: Vec, config: StockConfig): Vec
	return {
		x = shelf.x / config.PER_LEVEL * config.WIDTH_FILL,
		y = config.BOX_HEIGHT,
		z = shelf.z * config.DEPTH_FILL,
	}
end

-- Box centres, bottom level first; on each level the front row then the back one, left to right
function ShelfStock.slots(shelf: Vec, config: StockConfig): { Slot }
	local box = ShelfStock.boxSize(shelf, config)
	local cell = shelf.x / config.PER_LEVEL
	local slots = {}
	for _, level in config.LEVELS do
		local y = -shelf.y / 2 + level * shelf.y + box.y / 2
		for _, side in sidesOf(config) do
			for index = 1, config.PER_LEVEL do
				table.insert(slots, { x = -shelf.x / 2 + (index - 0.5) * cell, y = y, z = side * shelf.z, back = side > 0 })
			end
		end
	end
	return slots
end

-- Pack products stand as a stack of thin packs in each box's place: their z offsets from the box centre,
-- front (-Z) first, spread evenly over the box depth
function ShelfStock.stackOffsets(count: number, depth: number): { number }
	local offsets = {}
	for index = 1, count do
		offsets[index] = -depth / 2 + (index - 0.5) * depth / count
	end
	return offsets
end

-- How many rows (bottom first, front then back) have at least one box: each gets a price tag
function ShelfStock.stockedLevels(boxes: number, perLevel: number): number
	if boxes <= 0 or perLevel <= 0 then
		return 0
	end
	return math.ceil(boxes / perLevel)
end

return ShelfStock
