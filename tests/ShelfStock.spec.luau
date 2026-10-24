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

	["a double-sided shelf stocks both sides, each level front then back"] = function()
		local config = ShelfStock.configFor(town.SHELF_STOCK, { SIDES = { -0.2, 0.2 }, DEPTH_FILL = 0.3 })
		local rack = { x = 8, y = 7, z = 4 }
		local slots = ShelfStock.slots(rack, config)
		local perLevel = config.PER_LEVEL
		expect.equal(#slots, #config.LEVELS * perLevel * 2, "slot count")
		expect.equal(ShelfStock.slotCount(config), #slots, "slotCount")
		expect.near(slots[1].z, -0.8, 1e-9, "front row first")
		expect.equal(slots[1].back, false, "front faces front")
		expect.near(slots[perLevel + 1].z, 0.8, 1e-9, "then the back row")
		expect.equal(slots[perLevel + 1].back, true, "back faces back")
		expect.equal(slots[1].y, slots[perLevel + 1].y, "same level")
		assert(slots[perLevel * 2 + 1].y > slots[1].y, "then the next level up")
	end,

	["stocked rows map to a level and a side"] = function()
		local level, side = ShelfStock.row(1, 2)
		expect.equal(level, 1, "row 1 level")
		expect.equal(side, 1, "row 1 side")
		level, side = ShelfStock.row(2, 2)
		expect.equal(level, 1, "row 2 level")
		expect.equal(side, 2, "row 2 side")
		level, side = ShelfStock.row(3, 2)
		expect.equal(level, 2, "row 3 level")
		expect.equal(side, 1, "row 3 side")
	end,

	["a one-sided shelf keeps the default sides"] = function()
		local config = ShelfStock.configFor(town.SHELF_STOCK, nil)
		expect.equal(ShelfStock.slotCount(config), SLOTS, "slots")
		expect.equal(ShelfStock.slots(RACK, config)[1].back, false, "front")
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

	["card sleeves stand on shelves as sleeve packets that fit their box"] = function()
		expect.equal(products.ById.CardSleeves.stockLook, "Sleeves", "Card Sleeves look")
		local look = town.SHELF_STOCK.SLEEVES
		local config = town.SHELF_STOCK
		-- The narrowest box any shelf gives a stock slot: the 4-wide racks
		local boxWidth = RACK.x / config.PER_LEVEL * config.WIDTH_FILL
		assert(look.WIDTH <= boxWidth + 1e-9, "a packet is wider than its box")
		assert(look.HEIGHT + look.TAB <= config.BOX_HEIGHT + 1e-9, "a packet is taller than its box")
		assert(#look.COLORS >= 3, "an assortment of sleeve colours")
		for _, color in look.COLORS do
			assert(#color == 3, "colours are { r, g, b }")
		end
	end,

	["deck boxes stand on shelves as little deck boxes that fit their box"] = function()
		expect.equal(products.ById.DeckBox.stockLook, "Deck", "Deck Box look")
		local look = town.SHELF_STOCK.DECKS
		local config = town.SHELF_STOCK
		local boxWidth = RACK.x / config.PER_LEVEL * config.WIDTH_FILL
		local boxDepth = RACK.z * config.DEPTH_FILL
		assert(look.WIDTH <= boxWidth + 1e-9, "a deck box is wider than its place")
		assert(look.HEIGHT <= config.BOX_HEIGHT + 1e-9, "a deck box is taller than its place")
		assert(look.PER_STACK * look.DEPTH <= boxDepth + 1e-9, "the deck boxes don't fit front to back")
	end,
}
