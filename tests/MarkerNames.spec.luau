--!strict
local MarkerNames = require("../src/shared/Util/MarkerNames")
local expect = require("./lib/expect")

return {
	["each marker's name by its sim id"] = function()
		local names = MarkerNames.of({ ["a:b1"] = { Name = "Creature_1_b1" }, ["a:b2"] = { Name = "Creature_1" } }) :: any
		expect.equal(names["a:b1"], "Creature_1_b1")
		expect.equal(names["a:b2"], "Creature_1")
	end,

	["no markers, no names"] = function()
		expect.isNil(MarkerNames.of(nil))
		expect.equal(next(MarkerNames.of({}) :: any), nil, "an empty map stays empty")
	end,
}
