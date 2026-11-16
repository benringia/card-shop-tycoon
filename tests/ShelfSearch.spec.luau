--!strict
-- Where a customer goes when nothing on their list is on the shelves (owner 2026-11-16: "customers walk in and stand
-- to the center of the store, make them walk in go directly to where the cards are")
local ShelfSearch = require("../src/shared/Util/ShelfSearch")
local expect = require("./lib/expect")

-- Always takes the first one left, so the order is the list's
local function first(_count: number): number
	return 1
end

local function shelf(uid: string, kind: string, stocked: boolean): ShelfSearch.Shelf
	return { uid = uid, kind = kind, stocked = stocked }
end

return {
	["shelves with something on them they haven't checked, up to the count"] = function()
		local shelves = { shelf("a", "Products", true), shelf("b", "Products", true), shelf("c", "CustomerCards", true), shelf("d", "Products", true) }
		local picked, toMiddle = ShelfSearch.pick(shelves, { a = true }, 2, first)
		expect.equal(#picked, 2)
		expect.equal(picked[1], "b")
		expect.equal(picked[2], "c")
		expect.equal(toMiddle, false)
	end,

	["an empty shop: they walk to its empty product shelves, not the middle of the floor"] = function()
		local shelves = { shelf("rack", "Products", false), shelf("case", "CollectorCase", false), shelf("glass", "CustomerCards", false) }
		local picked, toMiddle = ShelfSearch.pick(shelves, {}, 2, first)
		expect.equal(#picked, 1)
		expect.equal(picked[1], "rack")
		expect.equal(toMiddle, false)
	end,

	["a shop with no shelves at all: the middle of the floor"] = function()
		local picked, toMiddle = ShelfSearch.pick({ shelf("case", "CollectorCase", false) }, {}, 2, first)
		expect.equal(#picked, 0)
		expect.equal(toMiddle, true)
	end,

	["already looked at everything with stock: no more walking, and never the middle"] = function()
		local shelves = { shelf("a", "Products", true), shelf("rack", "Products", false) }
		local picked, toMiddle = ShelfSearch.pick(shelves, { a = true }, 2, first)
		expect.equal(#picked, 0)
		expect.equal(toMiddle, false)
	end,

	["Collector Cases and other players-only shelves are never browsed, stocked or not"] = function()
		local shelves = { shelf("case", "CollectorCase", true), shelf("condenser", "Condenser", true) }
		local picked, toMiddle = ShelfSearch.pick(shelves, {}, 2, first)
		expect.equal(#picked, 0)
		expect.equal(toMiddle, true)
	end,

	["the roll picks which shelves, each once"] = function()
		local shelves = { shelf("a", "Products", true), shelf("b", "Products", true), shelf("c", "Products", true) }
		local picked = ShelfSearch.pick(shelves, {}, 3, function(count: number): number
			return count -- always the last one left
		end)
		expect.equal(table.concat(picked, ","), "c,b,a")
	end,
}
