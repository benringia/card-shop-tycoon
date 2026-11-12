--!strict
local DungeonRules = require("../src/shared/Util/DungeonRules")
local Dungeon = require("../src/shared/Config/Dungeon")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

return {
	["canFight: fresh, hurt, and out for the run (even rested again)"] = function()
		expect.equal(DungeonRules.canFight({}, "a"), true, "never fought")
		expect.equal(DungeonRules.canFight({ a = 12 }, "a"), true, "hurt")
		expect.equal(DungeonRules.canFight({ a = 0 }, "a"), false, "fainted this run")
	end,

	["merge: the fight's end wins, others kept"] = function()
		local before = { a = 50, b = 20 }
		local out = DungeonRules.merge(before, { a = 0 })
		expect.equal(out.a, 0, "a fainted")
		expect.equal(out.b, 20, "b kept")
		expect.equal(before.a, 50, "a new table")
	end,

	["isOut: only when every party card is down"] = function()
		expect.equal(DungeonRules.isOut({ a = 0, b = 3 }, { "a", "b" }), false, "b can fight")
		expect.equal(DungeonRules.isOut({ a = 0, b = 0 }, { "a", "b" }), true, "all down")
		expect.equal(DungeonRules.isOut({ a = 0 }, { "a", "c" }), false, "c never fought")
		expect.equal(DungeonRules.isOut({}, {}), true, "no party")
	end,

	["expectedSize clamps and survives junk"] = function()
		expect.equal(DungeonRules.expectedSize(nil, 4), 1, "Studio")
		expect.equal(DungeonRules.expectedSize({ runSize = 3 }, 4), 3, "group of 3")
		expect.equal(DungeonRules.expectedSize({ runSize = 50 }, 4), 4, "capped")
		expect.equal(DungeonRules.expectedSize({ runSize = 2.5 }, 4), 1, "not an integer")
		expect.equal(DungeonRules.expectedSize({ runSize = 0 }, 4), 1, "at least one")
		expect.equal(DungeonRules.expectedSize("x", 4), 1, "junk")
	end,

	["pack: count names from the room's species"] = function()
		local names = DungeonRules.pack({ species = { "A", "B" }, count = 3, level = 45 }, 7)
		expect.equal(#names, 3, "three")
		for _, name in names do
			expect.equal(name == "A" or name == "B", true, name)
		end
		local mixed = DungeonRules.pack({ species = { "A", "B" }, count = 2, level = 45 }, 1)
		expect.equal(mixed[1] ~= mixed[2], true, "two different species when there are two")
	end,

	["gateCheck: a member still loading waits, one with no creature left is out"] = function()
		expect.equal(DungeonRules.gateCheck(false, false), "skip", "save not loaded yet: not out, just not this fight")
		expect.equal(DungeonRules.gateCheck(true, false), "out", "loaded, nothing can fight")
		expect.equal(DungeonRules.gateCheck(true, true), "fight", "ready")
	end,

	["leftRun: only running or leaving ends your run; a loss or a timeout keeps the creatures' HP"] = function()
		expect.equal(DungeonRules.leftRun("run"), true, "ran or left")
		expect.equal(DungeonRules.leftRun("timeout"), false, "the time limit")
		expect.equal(DungeonRules.leftRun("lose"), false, "lost")
		expect.equal(DungeonRules.leftRun("win"), false, "won")
	end,

	["canChangeParty: the party is set once the run's first fight starts"] = function()
		expect.equal(DungeonRules.canChangeParty(false), true, "before the first fight")
		expect.equal(DungeonRules.canChangeParty(true), false, "after it")
	end,

	["readyToStart: the rooms open once everyone has loaded, or after the wait for a no-show"] = function()
		expect.equal(DungeonRules.readyToStart(2, 3, 10, 60), false, "one still loading")
		expect.equal(DungeonRules.readyToStart(3, 3, 1, 60), true, "all here")
		expect.equal(DungeonRules.readyToStart(2, 3, 60, 60), true, "gave up on the third")
		expect.equal(DungeonRules.readyToStart(0, 1, 90, 60), false, "nobody here at all")
	end,

	["skipRoom: /room n lands on a real room or the chamber (rooms + 1)"] = function()
		expect.equal(DungeonRules.skipRoom(2, 3), 2, "room 2")
		expect.equal(DungeonRules.skipRoom(4, 3), 4, "the chamber")
		expect.equal(DungeonRules.skipRoom(9, 3), 4, "past the chamber: the chamber")
		expect.equal(DungeonRules.skipRoom(0, 3), 1, "before room 1: room 1")
		expect.equal(DungeonRules.skipRoom(2.7, 3), 2, "whole rooms")
	end,

	["steps: a room's gate opens only when its fight is the next step"] = function()
		local steps = Dungeon.STEPS
		expect.equal(DungeonRules.canStartRoom(steps, 0, 1), true, "room 1 first")
		expect.equal(DungeonRules.canStartRoom(steps, 1, 2), false, "beams not solved")
		expect.equal(DungeonRules.canStartRoom(steps, 2, 2), true, "after the beams")
		expect.equal(DungeonRules.canStartRoom(steps, 5, 3), false, "room 3 already won")
		expect.equal(DungeonRules.canStartRoom(steps, 0, 3), false, "skipping ahead")
		expect.equal(DungeonRules.chamberOpen(steps, 5), false, "lock not solved")
		expect.equal(DungeonRules.chamberOpen(steps, 6), true, "all done")
		expect.equal(DungeonRules.stepKind(steps, 1), "beams", "after fight 1")
		expect.equal(DungeonRules.stepKind(steps, 0), "fight", "first")
		expect.equal(DungeonRules.stepKind(steps, 6), "boss", "past the last")
	end,

	["doneBefore: /room n lands at its fight; 4 is the chamber"] = function()
		expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 1), 0, "room 1")
		expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 2), 2, "room 2 after the beams")
		expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 3), 4, "room 3 after plates")
		expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 4), 6, "chamber")
	end,

	["stepIndex: where a puzzle sits in the run (/puzzle <kind> skips to it)"] = function()
		expect.equal(DungeonRules.stepIndex(Dungeon.STEPS, "beams"), 2, "after fight 1")
		expect.equal(DungeonRules.stepIndex(Dungeon.STEPS, "plates"), 4, "after fight 2")
		expect.equal(DungeonRules.stepIndex(Dungeon.STEPS, "lock"), 6, "the last")
		expect.equal(DungeonRules.stepIndex(Dungeon.STEPS, "nope"), nil, "no such step")
	end,

	["introKind: the full welcome first, the short one after"] = function()
		expect.equal(DungeonRules.introKind(false), "full", "never seen")
		expect.equal(DungeonRules.introKind(true), "short", "seen")
	end,

	["canAct and once: members not out, each player once"] = function()
		expect.equal(DungeonRules.canAct(true, false), true, "member")
		expect.equal(DungeonRules.canAct(true, true), false, "out")
		expect.equal(DungeonRules.canAct(false, false), false, "not in the run")
		local opened = {}
		expect.equal(DungeonRules.once(opened, 7), true, "first")
		expect.equal(DungeonRules.once(opened, 7), false, "second")
		expect.equal(DungeonRules.once(opened, 8), true, "another player")
	end,

	["secretPrize: title first, then 25% material, else cash"] = function()
		expect.equal(DungeonRules.secretPrize(false, 0.99, 0.25), "title", "first find")
		expect.equal(DungeonRules.secretPrize(false, 0.01, 0.25), "title", "first find, lucky roll too")
		expect.equal(DungeonRules.secretPrize(true, 0.1, 0.25), "material", "lucky")
		expect.equal(DungeonRules.secretPrize(true, 0.5, 0.25), "cash", "not")
	end,

	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/DungeonRules.luau")), { debugName = "DungeonRules" })()
		for _, name in { "canFight", "merge", "isOut", "expectedSize", "pack", "gateCheck", "leftRun", "canChangeParty", "readyToStart", "skipRoom", "canStartRoom", "chamberOpen", "stepKind", "doneBefore", "canAct", "once", "secretPrize", "stepIndex", "introKind" } do
			expect.equal(typeof(fresh[name]), "function", name)
		end
	end,
	["packSpots: spread round the ring's far side, apart, the same each seed"] = function()
		local spots = DungeonRules.packSpots(3, 18, 5)
		expect.equal(#spots, 3, "one each")
		for index, spot in spots do
			local reach = math.sqrt(spot.x * spot.x + spot.z * spot.z)
			expect.equal(reach > 18 * 0.7 and reach < 18 * 1.3, true, `spot {index} out on the ring`)
			expect.equal(spot.x > -2, true, `spot {index} on the far side from the gate (-x)`)
			for other = index + 1, #spots do
				local apart = math.sqrt((spot.x - spots[other].x) ^ 2 + (spot.z - spots[other].z) ^ 2)
				expect.equal(apart > 10, true, `spots {index} and {other} apart`)
			end
		end
		expect.equal(DungeonRules.packSpots(3, 18, 5)[2].z, spots[2].z, "the same each seed")
		expect.equal(#DungeonRules.packSpots(1, 18, 2), 1, "a lone monster")
	end,
}
