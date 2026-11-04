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

	["a cut connects if any target is in its reach (the hit sound plays at once)"] = function()
		local targets = {
			{ id = "b:m", x = 0, z = -20, radius = 9 },
			{ id = "b:add1", x = 0, z = 9, radius = 3 },
		}
		expect.equal(SwordRules.anyInReach(0, 0, 0, -1, targets, COMBO[1]), false, "the boss's edge 11 studs ahead, the add behind")
		expect.equal(SwordRules.anyInReach(0, -3, 0, -1, targets, COMBO[1]), true, "the boss's edge 8 studs ahead")
		expect.equal(SwordRules.anyInReach(0, 0, 0, -1, { targets[2] }, COMBO[1]), false, "the add is behind you")
		expect.equal(SwordRules.anyInReach(0, 0, 0, -1, {}, COMBO[1]), false)
	end,

	["the skill connects if any target is within its radius"] = function()
		local targets = { { id = "b:m", x = 0, z = 15, radius = 5 }, { id = "b:add1", x = 30, z = 0, radius = 3 } }
		expect.equal(SwordRules.anyInRadius(0, 0, targets, 11), true)
		expect.equal(SwordRules.anyInRadius(0, 0, { targets[2] }, 11), false)
		expect.equal(SwordRules.anyInRadius(0, 0, {}, 11), false)
	end,

	["the starter combo out-damages a reference creature by 1.0-1.6x"] = function()
		local ratio = SwordRules.comboPowerPerSecond(COMBO) / (1 / 2) -- a SPD 10 creature: 1 ATK every 2 s
		expect.equal(ratio >= 1 and ratio <= 1.6, true, `ratio {ratio}`)
		expect.equal(SwordRules.comboPowerPerSecond({}), 0)
	end,

	-- A dodge goes through foes (owner 2026-11-04): one that would end inside a boss or monster carries on out of it
	["a dash ending inside a foe carries on out the other side"] = function()
		expect.equal(SwordRules.dashLength(0, 0, 0, -1, {}, 12, 1, 24), 12, "nothing in the way")
		local off = { { id = "b:m", x = 20, z = -12, radius = 4 } }
		expect.equal(SwordRules.dashLength(0, 0, 0, -1, off, 12, 1, 24), 12, "a foe beside the path")
		local passed = { { id = "b:m", x = 0, z = -5, radius = 3 } }
		expect.equal(SwordRules.dashLength(0, 0, 0, -1, passed, 12, 1, 24), 12, "already out of it by the end")
		local inside = { { id = "b:m", x = 0, z = -12, radius = 4 } }
		expect.near(SwordRules.dashLength(0, 0, 0, -1, inside, 12, 1, 24), 17, 1e-9, "its far edge (16) plus the margin")
		local offCentre = { { id = "b:m", x = 3, z = -10, radius = 5 } }
		expect.near(SwordRules.dashLength(0, 0, 0, -1, offCentre, 12, 1, 24), 10 + 4 + 1, 1e-9, "the chord's far end")
		local chain = { { id = "a", x = 0, z = -12, radius = 3 }, { id = "b", x = 0, z = -17, radius = 3 } }
		expect.near(SwordRules.dashLength(0, 0, 0, -1, chain, 12, 1, 24), 21, 1e-9, "out of one, into the next, out of that")
		local huge = { { id = "b:m", x = 0, z = -12, radius = 20 } }
		expect.equal(SwordRules.dashLength(0, 0, 0, -1, huge, 12, 1, 24), 24, "never longer than the cap")
	end,
}
