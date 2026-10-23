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

	["the cover spread puts every card on the right page"] = function()
		expect.equal(BinderSpreads.side(1, 0, 9), "Right", "first pocket")
		expect.equal(BinderSpreads.side(1, 8, 9), "Right", "last pocket")
	end,

	["later spreads fill the left page, then the right"] = function()
		expect.equal(BinderSpreads.side(2, 0, 9), "Left", "first pocket")
		expect.equal(BinderSpreads.side(2, 8, 9), "Left", "end of left page")
		expect.equal(BinderSpreads.side(2, 9, 9), "Right", "start of right page")
	end,

	["turning forward folds the right page, back folds the left"] = function()
		expect.equal(BinderSpreads.turningSide(1, 2), "Right", "forward")
		expect.equal(BinderSpreads.turningSide(3, 2), "Left", "back")
		expect.equal(BinderSpreads.turningSide(2, 2), nil, "same spread: no turn")
	end,

	["no cards still has the cover spread, showing nothing"] = function()
		expect.equal(BinderSpreads.count(0, 9), 1, "spreads")
		local first, last = BinderSpreads.cards(1, 0, 9)
		assert(first > last, "empty range")
		expect.equal(BinderSpreads.label(1, 0), "0 / 0", "counter")
	end,
}
