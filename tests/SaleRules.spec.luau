--!strict
local SaleRules = require("../src/server/Util/SaleRules")
local expect = require("./lib/expect")

local listing = { cardId = "FS30", foil = true, grade = "S", price = 500, beastId = nil }

local function expected(overrides: { [string]: any }): any
	local base: any = { cardId = "FS30", foil = true, grade = "S", price = 500, beastId = nil }
	for key, value in overrides do
		base[key] = value
	end
	return base
end

return {
	["sale: exact listing matches"] = function()
		expect.equal(SaleRules.check(listing, expected({})), "ok", "match")
	end,

	["sale: swapped to another grade is refused"] = function()
		local current = { cardId = "FS30", foil = true, grade = "C", price = 500, beastId = nil }
		expect.equal(SaleRules.check(current, expected({ grade = "S" })), "gone", "grade swap")
	end,

	["sale: missing or junk expected grade only matches the default grade"] = function()
		local plainC = { cardId = "FS30", foil = true, grade = "C", price = 500, beastId = nil }
		local noGrade = expected({})
		noGrade.grade = nil
		expect.equal(SaleRules.check(plainC, noGrade), "ok", "nil -> C")
		expect.equal(SaleRules.check(listing, expected({ grade = 7 })), "gone", "junk vs S")
	end,

	["sale: other card, foil or beast is refused"] = function()
		expect.equal(SaleRules.check(listing, expected({ cardId = "FS01" })), "gone", "card")
		expect.equal(SaleRules.check(listing, expected({ foil = false })), "gone", "foil")
		expect.equal(SaleRules.check(listing, expected({ beastId = "abc" })), "gone", "beast")
	end,

	["sale: price change is reported"] = function()
		expect.equal(SaleRules.check(listing, expected({ price = 400 })), "price", "price")
		expect.equal(SaleRules.check(listing, expected({ price = 500.0004 })), "ok", "float slack")
	end,
}
