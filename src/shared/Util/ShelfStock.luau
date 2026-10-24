--!strict
-- Stock boxes on Products shelves: how many show and where they sit (main town follow-up). Pure, Lune-tested.
-- Positions are in the shelf part's space: centre at the origin, front at -Z.
export type Vec = { x: number, y: number, z: number }
export type StockConfig = {
	LEVELS: { number }, -- bottom of each level's boxes, as a fraction of the shelf height
	PER_LEVEL: number,
	BOX_HEIGHT: number, -- studs
	WIDTH_FILL: number, -- of each box's share of the shelf width
	DEPTH_FILL: number, -- of the shelf depth
}

local ShelfStock = {}

-- Any stock shows at least one box; a full shelf fills every slot
function ShelfStock.boxCount(units: number, capacity: number, slots: number): number
	if capacity <= 0 or units <= 0 then
		return 0
	end
	return math.ceil(math.min(units, capacity) / capacity * slots)
end

function ShelfStock.boxSize(shelf: Vec, config: StockConfig): Vec
	return {
		x = shelf.x / config.PER_LEVEL * config.WIDTH_FILL,
		y = config.BOX_HEIGHT,
		z = shelf.z * config.DEPTH_FILL,
	}
end

-- Box centres, bottom level first, left to right
function ShelfStock.slots(shelf: Vec, config: StockConfig): { Vec }
	local box = ShelfStock.boxSize(shelf, config)
	local cell = shelf.x / config.PER_LEVEL
	local slots = {}
	for _, level in config.LEVELS do
		local y = -shelf.y / 2 + level * shelf.y + box.y / 2
		for index = 1, config.PER_LEVEL do
			table.insert(slots, { x = -shelf.x / 2 + (index - 0.5) * cell, y = y, z = 0 })
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

-- How many levels (bottom first) have at least one box: each gets a price tag
function ShelfStock.stockedLevels(boxes: number, perLevel: number): number
	if boxes <= 0 or perLevel <= 0 then
		return 0
	end
	return math.ceil(boxes / perLevel)
end

return ShelfStock
