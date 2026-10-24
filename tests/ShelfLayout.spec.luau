--!strict
local town = require("../src/shared/Config/Town")
local ShelfStock = require("../src/shared/Util/ShelfStock")
local ShelfLayout = require("../src/shared/Util/ShelfLayout")
local expect = require("./lib/expect")

-- Config/Shelves holds Vector3 values, so Lune can't load it: each shelf's size, look and stock override copied here
local SHELVES = {
	{ name = "Small Pack Rack", kind = "Rack" :: ShelfLayout.Kind, size = { x = 4, y = 7, z = 2 }, stock = nil },
	{ name = "Wall Shelf", kind = "Rack" :: ShelfLayout.Kind, size = { x = 8, y = 8, z = 2 }, stock = nil },
	{ name = "Accessory Hook", kind = "Pegboard" :: ShelfLayout.Kind, size = { x = 4, y = 7, z = 2 }, stock = nil },
	{
		name = "Big Display Rack",
		kind = "DoubleRack" :: ShelfLayout.Kind,
		size = { x = 8, y = 7, z = 4 },
		stock = { LEVELS = { 0.149, 0.362, 0.549 }, SIDES = { -0.19, 0.19 }, DEPTH_FILL = 0.3 },
	},
}

local EPSILON = 1e-6

local function boxesOf(shelf: typeof(SHELVES[1])): ({ ShelfLayout.Box }, ShelfStock.StockConfig)
	local config = ShelfStock.configFor(town.SHELF_STOCK, shelf.stock)
	return ShelfLayout.build(shelf.kind, shelf.size, config, town.SHELF_LOOK), config
end

local function withRole(boxes: { ShelfLayout.Box }, role: string): { ShelfLayout.Box }
	local found = {}
	for _, box in boxes do
		if box.role == role then
			table.insert(found, box)
		end
	end
	return found
end

return {
	["every part stays inside the shelf's footprint"] = function()
		for _, shelf in SHELVES do
			local size = shelf.size
			for _, box in boxesOf(shelf) do
				local where = `{shelf.name} {box.role}`
				assert(box.x - box.sx / 2 >= -size.x / 2 - EPSILON and box.x + box.sx / 2 <= size.x / 2 + EPSILON, `{where} pokes out sideways`)
				assert(box.z - box.sz / 2 >= -size.z / 2 - EPSILON and box.z + box.sz / 2 <= size.z / 2 + EPSILON, `{where} pokes out front or back`)
				assert(box.y - box.sy / 2 >= -EPSILON and box.y + box.sy / 2 <= size.y + EPSILON, `{where} pokes out top or bottom`)
			end
		end
	end,

	["a plate's top sits at every stock level, so the stock stands on it"] = function()
		for _, shelf in SHELVES do
			local boxes, config = boxesOf(shelf)
			local plates = withRole(boxes, "plate")
			for _, level in config.LEVELS do
				local top = level * shelf.size.y
				local found = false
				for _, plate in plates do
					if math.abs(plate.y + plate.sy / 2 - top) < 1e-4 then
						found = true
					end
				end
				assert(found, `{shelf.name}: no plate at level {level}`)
			end
		end
	end,

	["the top level's stock clears the header"] = function()
		for _, shelf in SHELVES do
			local _, config = boxesOf(shelf)
			local top = config.LEVELS[#config.LEVELS] * shelf.size.y + config.BOX_HEIGHT
			assert(top <= shelf.size.y - town.SHELF_LOOK.HEADER + EPSILON, `{shelf.name}: the top stock hits the header`)
		end
	end,

	["one-sided stock stays in front of the back panel"] = function()
		for _, shelf in SHELVES do
			if shelf.kind ~= "DoubleRack" then
				local boxes, config = boxesOf(shelf)
				local back = withRole(boxes, "back")[1]
				assert(back ~= nil, `{shelf.name}: no back panel`)
				local stockBack = shelf.size.z * config.DEPTH_FILL / 2
				assert(stockBack <= back.z - back.sz / 2 + EPSILON, `{shelf.name}: the stock pokes through the back`)
			end
		end
	end,

	["the double rack has a middle divider and a price rail on both faces of every plate"] = function()
		local display = SHELVES[4]
		local boxes, config = boxesOf(display)
		local divider = withRole(boxes, "back")[1]
		assert(divider ~= nil and math.abs(divider.z) < EPSILON, "no divider down the middle")
		local rails = withRole(boxes, "rail")
		expect.equal(#rails, #config.LEVELS * 2, "rails")
		local stockInner = display.size.z * (math.abs(config.SIDES[1]) - config.DEPTH_FILL / 2)
		assert(stockInner >= divider.sz / 2 - EPSILON, "the stock pokes into the divider")
	end,

	["every rack has posts, a base and a header; the pegboard has hooks"] = function()
		for _, shelf in SHELVES do
			local boxes = boxesOf(shelf)
			assert(#withRole(boxes, "post") >= 2, `{shelf.name}: posts`)
			expect.equal(#withRole(boxes, "base"), 1, `{shelf.name}: base`)
			assert(#withRole(boxes, "header") >= 1, `{shelf.name}: header`)
		end
		assert(#withRole(boxesOf(SHELVES[3]), "hook") > 0, "pegboard hooks")
	end,
}
