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
}
