--!strict
local NewPulls = require("../src/shared/Util/NewPulls")
local expect = require("./lib/expect")

local function pulls(...: string): { { cardId: string } }
	local list = {}
	for _, id in { ... } do
		table.insert(list, { cardId = id })
	end
	return list
end

local function owns(...: string): { [string]: boolean }
	local set = {}
	for _, id in { ... } do
		set[id] = true
	end
	return set
end

return {
	["cards not owned are new, owned ones are not"] = function()
		local flags = NewPulls.flag(pulls("a", "b", "c"), owns("b"))
		expect.equal(flags[1], true, "a")
		expect.equal(flags[2], false, "b")
		expect.equal(flags[3], true, "c")
	end,
	["only the first copy of a new card in one pack is new"] = function()
		local flags = NewPulls.flag(pulls("a", "a", "b"), owns())
		expect.equal(flags[1], true, "first a")
		expect.equal(flags[2], false, "second a")
		expect.equal(flags[3], true, "b")
	end,
	["an empty pack has no flags"] = function()
		expect.equal(#NewPulls.flag({}, owns("a")), 0, "count")
	end,
	["count adds up the new ones"] = function()
		expect.equal(NewPulls.count({ true, false, true, true }), 3, "count")
		expect.equal(NewPulls.count({}), 0, "empty")
	end,
}
