--!strict
-- owner 2026-11-20: "When your carrying a box. highlight the shelf with the same product as you are carrying". The
-- shelves that glow while you carry a box: the ones already holding that product with room left; if none, the empty
-- ones that can take it (a first box has no shelf of its own yet).
local StockHint = require("../src/shared/Util/StockHint")
local expect = require("./lib/expect")

local function shelf(uid: string, kind: string, capacity: number, units: number, productId: string?, accepts: { string }?): StockHint.Shelf
	return { uid = uid, kind = kind, capacity = capacity, units = units, productId = productId, accepts = accepts }
end

local function picked(shelves: { StockHint.Shelf }, carrying: string?): string
	local uids = StockHint.pick(shelves, carrying)
	table.sort(uids)
	return table.concat(uids, ",")
end

return {
	["the shelves with the same product and room left glow"] = function()
		local shelves = {
			shelf("a", "Products", 24, 10, "FirstSparkPack"),
			shelf("b", "Products", 24, 24, "FirstSparkPack"), -- full
			shelf("c", "Products", 24, 5, "CardSleeves"), -- another product
			shelf("d", "Products", 24, 0, nil), -- empty: not while one of its own has room
			shelf("e", "Products", 48, 47, "FirstSparkPack"),
		}
		expect.equal(picked(shelves, "FirstSparkPack"), "a,e")
		expect.equal(picked(shelves, "CardSleeves"), "c")
	end,

	["with no shelf of its own (or all of them full), the empty shelves that can take it glow"] = function()
		local shelves = {
			shelf("a", "Products", 24, 24, "FirstSparkPack"),
			shelf("b", "Products", 24, 0, nil),
			shelf("c", "Products", 20, 0, nil, { "CardSleeves", "DeckBox" }), -- a hook: no packs
			shelf("d", "Products", 24, 3, "CardSleeves"),
		}
		expect.equal(picked(shelves, "FirstSparkPack"), "b")
		expect.equal(picked(shelves, "DeckBox"), "b,c")
	end,

	["card cases, machines and decor never glow; nothing glows with empty hands"] = function()
		local shelves = {
			shelf("a", "CustomerCards", 6, 0, nil),
			shelf("b", "Condenser", 0, 0, nil),
			shelf("c", "Decor", 0, 0, nil),
			shelf("d", "Products", 24, 0, nil),
		}
		expect.equal(picked(shelves, "FirstSparkPack"), "d")
		expect.equal(picked(shelves, nil), "")
		expect.equal(picked({}, "FirstSparkPack"), "")
	end,

	-- Storage racks (spec 2026-11-24-storage-racks-design): a box no selling shelf takes lights your racks with room
	["racks with room glow only when no shelf takes the box"] = function()
		local racks = { { uid = "r1", count = 9, capacity = 9 }, { uid = "r2", count = 3, capacity = 9 } }
		expect.equal(table.concat(StockHint.racks(racks, { "s1" }, "FirstSparkPack"), ","), "", "a shelf takes it: the shelf glows, not the racks")
		expect.equal(table.concat(StockHint.racks(racks, {}, "FirstSparkPack"), ","), "r2", "no shelf takes it: the racks with room")
		expect.equal(table.concat(StockHint.racks(racks, {}, nil), ","), "", "empty hands: nothing glows")
	end,

	["a shelf that can't hold the product never glows, even holding it by an old rule"] = function()
		local shelves = { shelf("a", "Products", 100, 3, "BulkCards", { "BulkCards" }), shelf("b", "Products", 20, 2, "FirstSparkPack", { "CardSleeves" }) }
		expect.equal(picked(shelves, "FirstSparkPack"), "")
		expect.equal(picked(shelves, "BulkCards"), "a")
	end,
}
