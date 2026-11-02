--!strict
local SwordRules = require("../src/shared/Util/SwordRules")
local expect = require("./lib/expect")

local COMBO = {
	{ power = 0.35, hitAt = 0.28, length = 0.56, reach = 9, arc = 70 },
	{ power = 0.35, hitAt = 0.2, length = 0.5, reach = 9, arc = 90 },
	{ power = 0.6, hitAt = 0.35, length = 0.75, reach = 10, arc = 60 },
}

return {
	["the first tap starts cut 1 now"] = function()
		local index, at = SwordRules.nextCut(COMBO, nil, 5, 0.9)
		expect.equal(index, 1)
		expect.equal(at, 5)
	end,

	["taps during a cut start nothing extra"] = function()
		expect.isNil(SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.1, 0.9))
		expect.isNil(SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.27, 0.9))
	end,

	["a tap after the hit queues the next cut at the end of this one"] = function()
		local index, at = SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.3, 0.9)
		expect.equal(index, 2)
		expect.near(at :: number, 5.56, 1e-9)
	end,

	["a tap after the cut ends continues the combo at once"] = function()
		local index, at = SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 6, 0.9)
		expect.equal(index, 2)
		expect.equal(at, 6)
	end,

	["cut 3 wraps to cut 1"] = function()
		expect.equal((SwordRules.nextCut(COMBO, { index = 3, startedAt = 0 }, 0.8, 0.9)), 1)
	end,

	["a late tap restarts the combo"] = function()
		local index, at = SwordRules.nextCut(COMBO, { index = 2, startedAt = 0 }, 2, 0.9)
		expect.equal(index, 1)
		expect.equal(at, 2)
	end,

	["reach counts from the target's edge, inside the arc"] = function()
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 0, -14, 6, 9, 70), true)
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 0, -16, 6, 9, 70), false)
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 10, 0, 6, 9, 70), false, "beside you, outside the arc")
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 3, 0, 6, 9, 70), true, "standing inside its edge")
		expect.equal(SwordRules.inReach(0, 0, 0, 0, 0, -10, 6, 9, 70), false, "no look direction: no hit")
	end,

	["the skill hits everything round you"] = function()
		expect.equal(SwordRules.inRadius(0, 0, 0, 15, 5, 11), true)
		expect.equal(SwordRules.inRadius(0, 0, 0, 17, 5, 11), false)
	end,

	["soft aim picks the nearest target in front"] = function()
		local targets = {
			{ id = "b:m", x = 0, z = -20, radius = 9 },
			{ id = "b:add1", x = 0, z = -8, radius = 3 },
			{ id = "b:add2", x = 0, z = 8, radius = 3 },
		}
		expect.equal(SwordRules.aimTarget(0, 0, 0, -1, targets, 14, 75), "b:add1")
		expect.isNil(SwordRules.aimTarget(0, 0, 0, 1, { targets[1] }, 14, 75))
		expect.isNil(SwordRules.aimTarget(0, 0, 0, -1, {}, 14, 75))
	end,

	["the starter combo out-damages a reference creature by 1.0-1.6x"] = function()
		local ratio = SwordRules.comboPowerPerSecond(COMBO) / (1 / 2) -- a SPD 10 creature: 1 ATK every 2 s
		expect.equal(ratio >= 1 and ratio <= 1.6, true, `ratio {ratio}`)
		expect.equal(SwordRules.comboPowerPerSecond({}), 0)
	end,
}
