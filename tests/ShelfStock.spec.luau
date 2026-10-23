--!strict
local town = require("../src/shared/Config/Town")
local products = require("../src/shared/Config/Products")
local ShelfStock = require("../src/shared/Util/ShelfStock")
local expect = require("./lib/expect")

local RACK = { x = 4, y = 7, z = 2 } -- Small Pack Rack
local SLOTS = #town.SHELF_STOCK.LEVELS * town.SHELF_STOCK.PER_LEVEL

return {
	["a stack of packs spreads front to back over the box depth"] = function()
		local zs = ShelfStock.stackOffsets(4, 1)
		expect.equal(#zs, 4, "count")
		expect.near(zs[1], -0.375, 1e-9, "front pack")
		expect.near(zs[4], 0.375, 1e-9, "back pack")
		assert(zs[1] < zs[2], "front first")
		expect.equal(#ShelfStock.stackOffsets(0, 1), 0, "none")
	end,

	["price tags go on every level that has stock"] = function()
		expect.equal(ShelfStock.stockedLevels(0, 4), 0, "empty")
		expect.equal(ShelfStock.stockedLevels(1, 4), 1, "one box")
		expect.equal(ShelfStock.stockedLevels(4, 4), 1, "one full level")
		expect.equal(ShelfStock.stockedLevels(5, 4), 2, "into level 2")
		expect.equal(ShelfStock.stockedLevels(12, 4), 3, "full")
	end,

	["boxes follow how full the shelf is"] = function()
		expect.equal(ShelfStock.boxCount(0, 24, 12), 0, "empty")
		expect.equal(ShelfStock.boxCount(1, 24, 12), 1, "one unit still shows a box")
		expect.equal(ShelfStock.boxCount(12, 24, 12), 6, "half")
		expect.equal(ShelfStock.boxCount(24, 24, 12), 12, "full")
		expect.equal(ShelfStock.boxCount(30, 24, 12), 12, "over capacity")
		expect.equal(ShelfStock.boxCount(5, 0, 12), 0, "no capacity")
	end,

	["12 slots: 3 levels of 4"] = function()
		expect.equal(SLOTS, 12, "slots")
	end,

	["slots fill the bottom level first, left to right"] = function()
		local slots = ShelfStock.slots(RACK, town.SHELF_STOCK)
		expect.equal(#slots, SLOTS, "slot count")
		assert(slots[1].y < slots[town.SHELF_STOCK.PER_LEVEL + 1].y, "level 2 above level 1")
		assert(slots[1].x < slots[2].x, "left to right")
		expect.equal(slots[1].y, slots[town.SHELF_STOCK.PER_LEVEL].y, "one level shares a height")
	end,

	["boxes stay inside the shelf"] = function()
		local box = ShelfStock.boxSize(RACK, town.SHELF_STOCK)
		for index, slot in ShelfStock.slots(RACK, town.SHELF_STOCK) do
			assert(math.abs(slot.x) + box.x / 2 <= RACK.x / 2 + 0.001, `slot {index} pokes out the side`)
			assert(slot.y - box.y / 2 >= -RACK.y / 2 - 0.001, `slot {index} is below the shelf`)
			assert(slot.y + box.y / 2 <= RACK.y / 2 + 0.001, `slot {index} is above the shelf`)
			assert(math.abs(slot.z) + box.z / 2 <= RACK.z / 2 + 0.001, `slot {index} pokes out the front or back`)
		end
	end,

	["every product has its own delivery box model slot"] = function()
		local seen: { [string]: boolean } = {}
		for _, product in products.List do
			local slot = (product :: any).boxProp
			assert(typeof(slot) == "string", `{product.id} has no boxProp`)
			assert(town.SLOTS[slot] ~= nil, `{product.id}: no Town slot {slot}`)
			assert(not seen[slot], `{slot} used twice`)
			seen[slot] = true
		end
	end,

	["every product has a box colour"] = function()
		for _, product in products.List do
			local color = (product :: any).color
			assert(typeof(color) == "table" and #color == 3, `{product.id} has no color`)
		end
	end,
}
