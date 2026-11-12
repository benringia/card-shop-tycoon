--!strict
-- The owner 2026-11-12: "lets do party strength for defense", "apply it to bosses too"
local DefenseRules = require("../src/shared/Util/DefenseRules")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

return {
	["Defense: the party's Power added up, none for an empty party"] = function()
		expect.equal(DefenseRules.defense({ 1000, 600, 600 }), 2200)
		expect.equal(DefenseRules.defense({}), 0)
	end,

	["a place's reference: three cards at its recommended Power"] = function()
		expect.equal(DefenseRules.reference(2400, Combat), 7200)
	end,

	["hits on you scale with reference over Defense, between 0.5 and 1.5"] = function()
		expect.equal(DefenseRules.scale(7200, 7200, Combat), 1, "at the recommended Power: as tuned")
		expect.equal(DefenseRules.scale(14400, 7200, Combat), 0.5, "twice as strong: half")
		expect.equal(DefenseRules.scale(3600, 7200, Combat), 1.5, "half as strong: 1.5 (clamped from 2)")
		expect.equal(DefenseRules.scale(0, 7200, Combat), 1.5, "no party: the weakest, never a divide by zero")
		expect.equal(DefenseRules.scale(100000, 7200, Combat), 0.5, "never immune")
	end,

	["a wild zone's reference comes from its boss (its own recommended is a level)"] = function()
		expect.equal(DefenseRules.zoneBoss(Bosses, "Wild", 3), "emberColossus")
		expect.equal(DefenseRules.zoneBoss(Bosses, "Frontier", 3), "riftDevourer")
		expect.equal(DefenseRules.zoneBoss(Bosses, "Wild", 9), nil, "no boss there")
	end,

	["the reference for a fight: a boss's own, a zone's boss's, none for a Dungeon room"] = function()
		expect.equal(DefenseRules.referenceFor(Bosses.BOSSES.prismHydra, Bosses, "Dungeon", nil, Combat), 7200)
		expect.equal(DefenseRules.referenceFor(nil, Bosses, "Wild", 3, Combat), 3 * Bosses.BOSSES.emberColossus.recommended)
		expect.equal(DefenseRules.referenceFor(nil, Bosses, "Dungeon", nil, Combat), nil, "a Dungeon room: no zone")
		expect.equal(DefenseRules.referenceFor(nil, Bosses, "Wild", nil, Combat), nil, "no zone given")
	end,
}
