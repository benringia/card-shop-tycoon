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

	["the dash slash connects if any target is along its path (the hit sound plays at once)"] = function()
		local targets = { { id = "b:m", x = 5, z = 2, radius = 1 }, { id = "b:add1", x = 30, z = 0, radius = 3 } }
		expect.equal(SwordRules.anyInDashPath(0, 0, 9, 0, targets, 4), true)
		expect.equal(SwordRules.anyInDashPath(0, 0, 9, 0, { targets[2] }, 4), false, "the add is far past the end")
		expect.equal(SwordRules.anyInDashPath(0, 0, 9, 0, {}, 4), false)
	end,

	["the starter combo out-damages a reference creature by 1.0-1.6x"] = function()
		local ratio = SwordRules.comboPowerPerSecond(COMBO) / (1 / 2) -- a SPD 10 creature: 1 ATK every 2 s
		expect.equal(ratio >= 1 and ratio <= 1.6, true, `ratio {ratio}`)
		expect.equal(SwordRules.comboPowerPerSecond({}), 0)
	end,

	-- The sword-moves round (spec 2026-11-04-sword-moves-design): cuts chain at their cancel point, lunges stop short of
	-- a foe, the dash slash hits along its (clamped) path, and the damage a second is measured on the chained cycle
	["a tap during the follow-through queues the next cut for the cancel point"] = function()
		local combo = { { power = 0.3, hitAt = 0.2, cancelAt = 0.35, length = 0.6, reach = 9, arc = 80 }, { power = 0.3, hitAt = 0.2, length = 0.6, reach = 9, arc = 80 } }
		local index, at = SwordRules.nextCut(combo, { index = 1, startedAt = 0 }, 0.25, 0.9)
		expect.equal(index, 2)
		expect.near(at :: number, 0.35, 1e-9, "at the cancel point, not the end")
		index, at = SwordRules.nextCut(combo, { index = 1, startedAt = 0 }, 0.40, 0.9)
		expect.equal(index, 2, "after the cancel point")
		expect.near(at :: number, 0.40, 1e-9, "at once")
		index, at = SwordRules.nextCut(combo, { index = 1, startedAt = 0 }, 0.6 + 0.9 + 0.01, 0.9)
		expect.equal(index, 1, "too late: the combo starts again")
		expect.near(at :: number, 1.51, 1e-9)
	end,

	["the damage a second runs on the chained cycle: cancel points, then the last cut's length"] = function()
		local combo = {
			{ power = 0.3, hitAt = 0.2, cancelAt = 0.34, length = 0.6, reach = 9, arc = 80 },
			{ power = 0.3, hitAt = 0.2, cancelAt = 0.32, length = 0.58, reach = 9, arc = 80 },
			{ power = 0.5, hitAt = 0.4, length = 0.88, reach = 10, arc = 70 },
		}
		expect.near(SwordRules.comboPowerPerSecond(combo), 1.1 / 1.54, 1e-9)
	end,

	["a lunge stops short of a foe, and goes its full length when nothing is ahead"] = function()
		local foe = { { id = "b:m", x = 5, z = 0, radius = 2 } }
		expect.near(SwordRules.lungeLength(0, 0, 1, 0, foe, 4, 1), 2, 1e-9, "its edge at 3, stopping 1 short")
		expect.near(SwordRules.lungeLength(0, 0, 1, 0, {}, 4, 1), 4, 1e-9, "nothing ahead")
		expect.near(SwordRules.lungeLength(2, 0, 1, 0, foe, 4, 1), 0, 1e-9, "already at the stop distance")
		expect.near(SwordRules.lungeLength(0, 0, 1, 0, { { id = "x", x = 5, z = 3, radius = 2 } }, 4, 1), 4, 1e-9, "a foe off to the side")
		expect.near(SwordRules.lungeLength(0, 0, 1, 0, { { id = "x", x = -5, z = 0, radius = 2 } }, 4, 1), 4, 1e-9, "a foe behind")
	end,

	["the dash slash hits every foe along its path"] = function()
		expect.equal(SwordRules.inDashPath(0, 0, 9, 0, 5, 2.5, 1, 4), true, "beside the path, its edge inside the band")
		expect.equal(SwordRules.inDashPath(0, 0, 9, 0, 5, 4, 1, 4), false, "too far to the side")
		expect.equal(SwordRules.inDashPath(0, 0, 9, 0, 12, 0, 2, 4), true, "past the end, its edge reaching it")
		expect.equal(SwordRules.inDashPath(0, 0, 9, 0, -4, 0, 1, 4), false, "behind the start")
		expect.equal(SwordRules.inDashPath(3, 3, 3, 3, 4, 3, 0.5, 4), true, "a zero-length path is a circle")
	end,

	["the server pulls a too-long dash path back to its longest"] = function()
		local x, z = SwordRules.clampPath(0, 0, 30, 0, 20)
		expect.near(x, 20, 1e-9)
		expect.near(z, 0, 1e-9)
		x, z = SwordRules.clampPath(0, 0, 10, 0, 20)
		expect.near(x, 10, 1e-9, "short enough: unchanged")
		x, z = SwordRules.clampPath(1, 1, 1, 1, 20)
		expect.near(x, 1, 1e-9, "no movement")
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

	["skill shapes: dash is today's path, spin hits all around, a line ahead, the wave arrives by distance"] = function()
		local t = function(id, x, z) return { id = id, x = x, z = z, radius = 1 } end
		local targets = { t("ahead", 0, -10), t("behind", 0, 6), t("far", 0, -30), t("side", 8, 0) }
		-- dash: the same foes as SwordRules.anyInDashPath along the path from start to now (clamped to maxStuds + slack)
		local dash = SwordRules.skillHits({ kind = "dash", width = 4, maxStuds = 20, slack = 3 }, 0, 0, 0, -12, 0, -1, targets)
		expect.equal(#dash, 1); expect.equal(dash[1].id, "ahead"); expect.equal(dash[1].share, 1); expect.equal(dash[1].after, 0)
		-- spin: within 9 (+ the foe's radius) of where you are, all at once
		local spin = SwordRules.skillHits({ kind = "spin", radius = 9 }, 0, 0, 0, 0, 0, -1, targets)
		local ids = {}
		for _, hit in spin do ids[hit.id] = hit.after end
		expect.equal(ids.behind, 0); expect.equal(ids.side, 0); expect.equal(ids.ahead, nil); expect.equal(ids.far, nil)
		-- line: 18 long, 4 wide ahead of you
		local line = SwordRules.skillHits({ kind = "line", length = 18, width = 4 }, 0, 0, 0, 0, 0, -1, targets)
		expect.equal(#line, 1); expect.equal(line[1].id, "ahead")
		-- wave: 24 long, 6 wide, each foe when the 40 stud-a-second wave reaches it
		local wave = SwordRules.skillHits({ kind = "wave", length = 24, width = 6, speed = 40 }, 0, 0, 0, 0, 0, -1, targets)
		expect.equal(#wave, 1); expect.near(wave[1].after, 10 / 40, 1e-6)
	end,

	["judgment: five strikes a fifth each on the aimed foe within 24 (in front first), none in range: nothing"] = function()
		local t = function(id, x, z) return { id = id, x = x, z = z, radius = 1 } end
		local shape = { kind = "judgment", range = 24, angle = 60, strikes = 5, gap = 0.15 }
		local hits = SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("front", 0, -20), t("back", 0, 5) })
		expect.equal(#hits, 5)
		local total = 0
		for index, hit in hits do
			expect.equal(hit.id, "front"); expect.near(hit.after, (index - 1) * 0.15, 1e-9); total += hit.share
		end
		expect.near(total, 1, 1e-9)
		local around = SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("back", 0, 5) })
		expect.equal(around[1].id, "back", "none in front: the nearest around")
		expect.equal(#SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("away", 0, 40) }), 0, "out of range")
		expect.equal(#SwordRules.skillHits({ kind = "spin", radius = 9 }, 0, 0, 0, 0, 0, -1, {}), 0, "no foes")
	end,
}
