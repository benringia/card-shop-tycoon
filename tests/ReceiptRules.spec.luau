--!strict
-- Robux purchases are granted once (spec 2026-11-12-timed-upgrades-revive-design: ProfileStore's developer product
-- recipe): each receipt's PurchaseId is remembered in the save, the newest 100 (Util/ReceiptRules, PurchaseService)
local ReceiptRules = require("../src/shared/Util/ReceiptRules")
local expect = require("./lib/expect")

return {
	["a receipt id is remembered"] = function()
		local list = ReceiptRules.record({}, "p1", 100)
		expect.equal(ReceiptRules.seen(list, "p1"), true)
		expect.equal(ReceiptRules.seen(list, "p2"), false)
	end,

	["only the newest ids are kept"] = function()
		local list: { string } = {}
		for index = 1, 105 do
			list = ReceiptRules.record(list, `p{index}`, 100)
		end
		expect.equal(#list, 100)
		expect.equal(ReceiptRules.seen(list, "p5"), false, "the oldest five went")
		expect.equal(ReceiptRules.seen(list, "p6"), true)
		expect.equal(ReceiptRules.seen(list, "p105"), true, "the last kept")
	end,
}
