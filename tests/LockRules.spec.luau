--!strict
local Bosses = require("../src/shared/Config/Bosses")
local LockRules = require("../src/shared/Util/LockRules")
local expect = require("./lib/expect")

return {
	["order: the Hydra's phases"] = function()
		expect.equal(table.concat(LockRules.order(Bosses.BOSSES.prismHydra.phases), ","), "Tide,Volt,Shade,Bloom,Ember", "order")
	end,

	["strike: right steps on, wrong resets, fifth is done"] = function()
		local order = { "Tide", "Volt", "Shade", "Bloom", "Ember" }
		local progress, result = LockRules.strike(0, "Tide", order)
		expect.equal(progress, 1, "one lit")
		expect.equal(result, "right", "first")
		progress, result = LockRules.strike(2, "Ember", order)
		expect.equal(progress, 0, "reset")
		expect.equal(result, "wrong", "wrong")
		progress, result = LockRules.strike(4, "Ember", order)
		expect.equal(progress, 5, "all lit")
		expect.equal(result, "done", "last")
	end,

	["strike: a solved lock stays solved"] = function()
		local order = { "Tide", "Volt" }
		local progress, result = LockRules.strike(2, "Tide", order)
		expect.equal(progress, 2, "kept")
		expect.equal(result, "done", "still done")
	end,
}
