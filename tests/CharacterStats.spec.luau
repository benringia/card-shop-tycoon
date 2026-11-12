--!strict
-- The character window's Stats tab (owner 2026-11-12: "their attack or defense", "add power so that player can compare
-- it to whatever boss their planning to take")
local CharacterStats = require("../src/shared/Util/CharacterStats")
local expect = require("./lib/expect")

return {
	["Power: the strongest card; Attack: the weapon's; Defense: the party added up"] = function()
		local stats = CharacterStats.compute({ 2614, 1200, 900 }, 1240)
		expect.equal(stats.power, 2614, "what the boss board compares")
		expect.equal(stats.attack, 1240)
		expect.equal(stats.defense, 4714)
	end,

	["an empty party and no weapon: zeros, no error"] = function()
		local stats = CharacterStats.compute({}, 0)
		expect.equal(stats.power, 0)
		expect.equal(stats.attack, 0)
		expect.equal(stats.defense, 0)
	end,
}
