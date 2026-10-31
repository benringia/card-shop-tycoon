--!strict
-- How many monsters a Wild valley zone keeps (round 2 spec): 8 while quiet, 2 more for each player in it past the first
-- 3, up to 24; respawns quicker while busy; a crowd leaving removes nothing (extras just aren't respawned).
local valley = require("../src/shared/Config/WildValley")
local WildPopulation = require("../src/shared/Util/WildPopulation")
local expect = require("./lib/expect")

local cfg = valley.POPULATION

return {
	["a quiet zone keeps 8 monsters"] = function()
		for players = 0, 3 do
			expect.equal(WildPopulation.target(cfg, players), 8, `{players} players`)
		end
	end,

	["each player past 3 adds 2, up to 24"] = function()
		expect.equal(WildPopulation.target(cfg, 4), 10, "4 players")
		expect.equal(WildPopulation.target(cfg, 5), 12, "5 players")
		expect.equal(WildPopulation.target(cfg, 11), 24, "11 players")
		expect.equal(WildPopulation.target(cfg, 60), 24, "a full server")
	end,

	["respawns are quicker while busy"] = function()
		local quiet, busy = WildPopulation.respawnRange(cfg, 8), WildPopulation.respawnRange(cfg, 10)
		expect.equal(quiet[1], 20, "quiet min")
		expect.equal(quiet[2], 40, "quiet max")
		expect.equal(busy[1], 10, "busy min")
		expect.equal(busy[2], 20, "busy max")
	end,

	["only the missing monsters are scheduled; extras are never removed"] = function()
		expect.equal(WildPopulation.deficit(12, 8, 2), 2, "two more")
		expect.equal(WildPopulation.deficit(8, 12, 0), 0, "a crowd left: nothing removed")
	end,

	["free spots skip the taken ones"] = function()
		local free = WildPopulation.freeSpots(5, { [2] = true, [4] = true })
		expect.equal(#free, 3, "three free")
		expect.equal(free[1], 1, "first")
		expect.equal(free[3], 5, "last")
	end,
}
