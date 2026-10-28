--!strict
local DungeonRules = require("../src/shared/Util/DungeonRules")
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

	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/DungeonRules.luau")), { debugName = "DungeonRules" })()
		for _, name in { "canFight", "merge", "isOut", "expectedSize", "pack" } do
			expect.equal(typeof(fresh[name]), "function", name)
		end
	end,
}
