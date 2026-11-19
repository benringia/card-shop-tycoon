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
}
