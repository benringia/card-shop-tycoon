--!strict
local CreatureCull = require("../src/shared/Util/CreatureCull")
local expect = require("./lib/expect")

local RULES = { drawDistance = 100, hideDistance = 120, maxDrawn = 3 }

local function entry(key: string, distance: number, own: boolean?, drawn: boolean?): CreatureCull.Entry
	return { key = key, distance = distance, own = own == true, drawn = drawn == true }
end

return {
	["cull: near creatures are drawn, far ones are not"] = function()
		local drawn = CreatureCull.pick({ entry("near", 50), entry("far", 200) }, RULES)
		expect.equal(drawn.near, true, "near")
		expect.isNil(drawn.far, "far")
	end,

	["cull: only the nearest few are drawn"] = function()
		local drawn = CreatureCull.pick({ entry("a", 40), entry("b", 10), entry("c", 30), entry("d", 20) }, RULES)
		expect.equal(drawn.b and drawn.d and drawn.c, true, "the three nearest")
		expect.isNil(drawn.a, "the fourth waits")
	end,

	["cull: your own creatures always draw, first"] = function()
		local drawn = CreatureCull.pick({ entry("mine", 500, true), entry("a", 1), entry("b", 2), entry("c", 3) }, RULES)
		expect.equal(drawn.mine, true, "own, even far away")
		expect.isNil(drawn.c, "it takes one of the places")
	end,

	["cull: a drawn creature stays until past the hide distance"] = function()
		local drawn = CreatureCull.pick({ entry("kept", 110, false, true), entry("new", 110) }, RULES)
		expect.equal(drawn.kept, true, "between the two distances it stays")
		expect.isNil(drawn.new, "a new one waits for the draw distance")
	end,

	["cull: nothing to draw"] = function()
		expect.isNil(next(CreatureCull.pick({}, RULES)), "empty")
	end,
}
