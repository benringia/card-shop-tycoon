--!strict
local DebuffRules = require("../src/shared/Util/DebuffRules")
local Bosses = require("../src/shared/Config/Bosses")
local CombatHud = require("../src/shared/Config/CombatHud")
local expect = require("./lib/expect")

return {
	["walking: stopped while down, slowed by a debuff, else as before"] = function()
		expect.equal(DebuffRules.walkSpeed(16, false, nil), 16)
		expect.near(DebuffRules.walkSpeed(16, false, 0.6), 6.4, 1e-9, "Tangled: 60% slower")
		expect.near(DebuffRules.walkSpeed(20, false, 0.3), 14, 1e-9, "Chilled: 30% slower")
		expect.equal(DebuffRules.walkSpeed(16, true, nil), 0, "down")
		expect.equal(DebuffRules.walkSpeed(16, true, 0.6), 0, "down beats slowed")
	end,

	["the countdown shows tenths and never goes below zero"] = function()
		expect.equal(DebuffRules.countdown(2), "2.0")
		expect.equal(DebuffRules.countdown(1.26), "1.3")
		expect.equal(DebuffRules.countdown(0.04), "0.0")
		expect.equal(DebuffRules.countdown(-1), "0.0")
	end,

	["every boss debuff has its HUD look: emoji, name, colour"] = function()
		for kind in Bosses.DEBUFFS do
			local look = CombatHud.DEBUFFS[kind]
			assert(look, `{kind} has no look`)
			expect.equal(typeof(look.emoji) == "string" and #look.emoji > 0, true, `{kind} emoji`)
			expect.equal(typeof(look.name) == "string" and #look.name > 0, true, `{kind} name`)
			expect.equal(typeof(look.color) == "table" and #look.color == 3, true, `{kind} colour`)
		end
		for kind in CombatHud.DEBUFFS do
			assert(Bosses.DEBUFFS[kind], `{kind} is a look for a debuff that doesn't exist`)
		end
	end,

	["no jumping while down or frozen solid"] = function()
		expect.equal(DebuffRules.jumpHeight(7.2, false, nil), 7.2)
		expect.equal(DebuffRules.jumpHeight(7.2, false, 0.3), 7.2, "a slow keeps the jump")
		expect.equal(DebuffRules.jumpHeight(7.2, false, 1), 0, "Frozen")
		expect.equal(DebuffRules.jumpHeight(7.2, true, nil), 0, "down")
		expect.equal(DebuffRules.walkSpeed(16, false, 1), 0, "Frozen: no walking")
	end,

	-- The owner 2026-11-11: the Storm Sovereign's thunderclap leaves you Electrocuted, "stun for 1 sec every 3 seconds"
	["Electrocuted jolts: stunned and held 1 s in every 3, free between"] = function()
		local spec = Bosses.DEBUFFS.Electrocuted
		assert(spec, "Electrocuted exists")
		expect.equal(spec.seconds, 7, "3 jolts")
		expect.equal(spec.jolt.every, 3)
		expect.equal(spec.jolt.seconds, 1)
		local function at(elapsed: number): (boolean, number?)
			return DebuffRules.effectAt(spec, elapsed)
		end
		for _, elapsed in { 0, 0.5, 0.99, 3, 3.5, 6, 6.9 } do
			local stun, slow = at(elapsed)
			expect.equal(stun, true, `jolting at {elapsed}`)
			expect.equal(slow, 1, `held still at {elapsed}`)
		end
		for _, elapsed in { 1.01, 2, 2.99, 4.2, 5.9 } do
			local stun, slow = at(elapsed)
			expect.equal(stun, false, `free at {elapsed}`)
			expect.isNil(slow, `walking at {elapsed}`)
		end
		expect.equal(table.concat(DebuffRules.joltTimes(spec), ","), "0,3,6", "the jolts' starts")
		-- the server's clock adds up 0.1 s steps: a jolt due at 3 s still starts when it reads 2.9999999
		expect.equal((at(3 - 1e-9)), true, "a hair before 3 s is the second jolt")
	end,

	["a debuff without jolts holds the same the whole time"] = function()
		local frozenStun, frozenSlow = DebuffRules.effectAt(Bosses.DEBUFFS.Frozen, 1)
		expect.equal(frozenStun, true)
		expect.equal(frozenSlow, 1)
		local chilledStun, chilledSlow = DebuffRules.effectAt(Bosses.DEBUFFS.Chilled, 2)
		expect.equal(chilledStun, false)
		expect.equal(chilledSlow, 0.3)
		expect.equal(DebuffRules.effectAt(Bosses.DEBUFFS.Shocked, 0.2), true)
		expect.equal(#DebuffRules.joltTimes(Bosses.DEBUFFS.Shocked), 0, "no jolts")
	end,
}
