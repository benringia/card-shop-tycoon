--!strict
local BinderSpreads = require("../src/shared/Util/BinderSpreads")
local expect = require("./lib/expect")

return {
	["35 cards at 9 a page fill three spreads (the first shares its spread with the cover)"] = function()
		expect.equal(BinderSpreads.count(35, 9), 3, "spreads")
		local first, last = BinderSpreads.cards(1, 35, 9)
		expect.equal(first, 1, "spread 1 first")
		expect.equal(last, 9, "spread 1 last")
		first, last = BinderSpreads.cards(2, 35, 9)
		expect.equal(first, 10, "spread 2 first")
		expect.equal(last, 27, "spread 2 last")
		first, last = BinderSpreads.cards(3, 35, 9)
		expect.equal(first, 28, "spread 3 first")
		expect.equal(last, 35, "spread 3 last")
	end,

	["page counter names the pages on show"] = function()
		expect.equal(BinderSpreads.pages(35, 9), 4, "pages")
		expect.equal(BinderSpreads.label(1, 4), "1 / 4", "first spread: cover + page 1")
		expect.equal(BinderSpreads.label(2, 4), "2-3 / 4", "second spread")
		expect.equal(BinderSpreads.label(3, 4), "4 / 4", "last spread has one page")
	end,

	["no cards still has the cover spread, showing nothing"] = function()
		expect.equal(BinderSpreads.count(0, 9), 1, "spreads")
		local first, last = BinderSpreads.cards(1, 0, 9)
		assert(first > last, "empty range")
		expect.equal(BinderSpreads.label(1, 0), "0 / 0", "counter")
	end,
}
