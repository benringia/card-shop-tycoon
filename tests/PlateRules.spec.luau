--!strict
local Dungeon = require("../src/shared/Config/Dungeon")
local PlateRules = require("../src/shared/Util/PlateRules")
local expect = require("./lib/expect")

return {
	["count: 2 alone or in pairs, 3 for 3-4"] = function()
		expect.equal(PlateRules.count(1, Dungeon.PLATES), 2, "solo")
		expect.equal(PlateRules.count(2, Dungeon.PLATES), 2, "pair")
		expect.equal(PlateRules.count(3, Dungeon.PLATES), 3, "three")
		expect.equal(PlateRules.count(4, Dungeon.PLATES), 3, "four")
	end,

	["needed: never more than the players left can cover"] = function()
		expect.equal(PlateRules.needed(3, 4), 3, "full group")
		expect.equal(PlateRules.needed(3, 1), 2, "one left: self + creature")
		expect.equal(PlateRules.needed(2, 1), 2, "solo")
		expect.equal(PlateRules.needed(2, 0), 0, "nobody")
	end,

	["inside: a point on the plate's square"] = function()
		local box = { x = 0, z = 0, half = 4 }
		expect.equal(PlateRules.inside(box, { x = 3.9, z = -3 }), true, "on it")
		expect.equal(PlateRules.inside(box, { x = 4.5, z = 0 }), false, "off it")
		expect.equal(PlateRules.inside({ x = 10, z = 5, half = 4 }, { x = 7, z = 8.5 }), true, "away from the origin")
	end,

	["open: the first `needed` plates held"] = function()
		expect.equal(PlateRules.open({ true, true, false }, 2), true, "third dimmed")
		expect.equal(PlateRules.open({ true, false, true }, 2), false, "second up")
		expect.equal(PlateRules.open({ true, true, true }, 3), true, "all three")
		expect.equal(PlateRules.open({ false, false }, 0), false, "nobody left: never opens by itself")
	end,
}
