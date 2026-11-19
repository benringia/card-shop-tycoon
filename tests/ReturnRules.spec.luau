--!strict
-- A customer who leaves without paying puts their stock back (a haggle turned down, a given-up wait). Owner 2026-11-19:
-- "Make sure turned down deals for bargainers place back cards they took to the shelves". The shelf it came from may
-- be gone, full or holding something else by then: the units go to the owner's other shelves of that product, and what
-- still doesn't fit is paid back at what it cost, so nothing is ever lost (server Util/ReturnRules).
local ReturnRules = require("../src/server/Util/ReturnRules")
local Products = require("../src/shared/Config/Products")
local expect = require("./lib/expect")

return {
	["leftover units are paid back at what they cost; a Bulk Bin's handful at its price"] = function()
		local packs = Products.ById.FirstSparkPack
		expect.equal(ReturnRules.refund(packs, 3), 6, "3 packs of a $48 box of 24")
		expect.equal(ReturnRules.refund(Products.ById.CardSleeves, 1), 1.5)
		local bulk = Products.ById.BulkCards
		expect.equal(ReturnRules.refund(bulk, 2), 2 * bulk.marketPrice, "handfuls never cost anything: their market price")
		expect.equal(ReturnRules.refund(packs, 0), 0)
		expect.equal(ReturnRules.refund(nil, 3), 0, "an unknown product")
	end,

	-- Owner 2026-11-19 (second playthrough): "when I decline a bargainer. add an indication that the cards were back on
	-- the shelves": a toast names what went back, and each shelf it went to shows "+2 back"
	["a turned-down deal says what went back on the shelves"] = function()
		local cfg = ReturnRules.WORDS
		expect.equal(ReturnRules.backLine({ { name = "First Spark Pack", units = 2 } }, 0), "Back on your shelves: 2 First Spark Pack")
		expect.equal(
			ReturnRules.backLine({ { name = "First Spark Pack", units = 2 }, { name = "Card Sleeves", units = 1 } }, 0),
			"Back on your shelves: 2 First Spark Pack, 1 Card Sleeves"
		)
		expect.equal(ReturnRules.backLine({ { name = "First Spark Pack", units = 1 }, { name = "First Spark Pack", units = 2 } }, 0), "Back on your shelves: 3 First Spark Pack", "the same product once")
		expect.equal(ReturnRules.backLine({}, 1), "Back on your shelves: 1 card")
		expect.equal(ReturnRules.backLine({ { name = "Deck Box", units = 1 } }, 2), "Back on your shelves: 1 Deck Box, 2 cards")
		expect.isNil(ReturnRules.backLine({}, 0), "nothing went back: no toast")
		expect.isNil(ReturnRules.backLine({ { name = "Deck Box", units = 0 } }, 0), "all of it refunded: the refund's own toast says so")
		local many = {}
		for index = 1, 6 do
			table.insert(many, { name = "Thing " .. index, units = 1 })
		end
		local long = ReturnRules.backLine(many, 0) :: string
		assert(string.find(long, "and more", 1, true), "a long list is cut short")
		assert(not string.find(long, "Thing " .. (cfg.most + 1), 1, true))
		expect.equal(ReturnRules.popText(2), "+2 back")
		expect.isNil(ReturnRules.popText(0))
	end,
}
