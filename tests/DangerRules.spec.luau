--!strict
-- The owner 2026-11-11/12: wild monsters attack players in the dangerous places; soft knockouts (spec
-- 2026-11-12-wild-danger-character-window-design)
local DangerRules = require("../src/shared/Util/DangerRules")
local expect = require("./lib/expect")

local function state(over: any): any
	local base = { fighting = false, locked = false, hasCard = true, summoned = true, summonedRested = true, restedSlot = 1, hasSword = true }
	for key, value in over do
		base[key] = value
	end
	if over.noRested then
		base.restedSlot = nil -- a nil in the table above wouldn't clear it
	end
	return base
end

return {
	["contact anywhere: fight, summon a rested card, sword alone, or a shove"] = function()
		expect.equal(DangerRules.onContact(state({})), "fight", "summoned and rested: the fight as today")
		local action, slot = DangerRules.onContact(state({ summoned = false, summonedRested = false, restedSlot = 2 }))
		expect.equal(action, "summon", "nothing out: the first rested card is summoned")
		expect.equal(slot, 2)
		local swap, swapSlot = DangerRules.onContact(state({ summonedRested = false, restedSlot = 3 }))
		expect.equal(swap, "summon", "the summoned one resting, another rested: that one")
		expect.equal(swapSlot, 3)
		expect.equal(DangerRules.onContact(state({ summonedRested = false, noRested = true })), "swordOnly", "every card resting, a sword: you alone")
		expect.equal(DangerRules.onContact(state({ summonedRested = false, noRested = true, hasSword = false })), "shove", "nothing to fight with: a shove")
		expect.equal(DangerRules.onContact(state({ hasCard = false, summoned = false, summonedRested = false, noRested = true })), "shove", "no party at all: a shove")
	end,

	["contact changes nothing while busy"] = function()
		expect.equal(DangerRules.onContact(state({ fighting = true })), "none", "already fighting")
		expect.equal(DangerRules.onContact(state({ locked = true })), "none", "locked (a cinematic, a menu)")
	end,

	-- owner 2026-11-12: "elite/aggressive monsters should still attack me even if my summons are not dead"
	["elites and monsters of aggro or dangerous places swing at you while your creature stands"] = function()
		expect.equal(DangerRules.playerShare(true, { aggro = false }, 0.3), 0.3, "an elite in the Meadow")
		expect.equal(DangerRules.playerShare(false, { aggro = true }, 0.3), 0.3, "Ember Ridge")
		expect.equal(DangerRules.playerShare(false, { aggro = false, danger = true }, 0.3), 0.3, "Frostwood")
		expect.equal(DangerRules.playerShare(false, { aggro = false }, 0.3), nil, "a plain Meadow monster: pets first")
		expect.equal(DangerRules.playerShare(false, nil, 0.3), nil, "no zone")
	end,

	["a knockout follows only a lost wild fight in a dangerous place"] = function()
		expect.equal(DangerRules.knockout("lose", true, false, false), true)
		expect.equal(DangerRules.knockout("win", true, false, false), false, "a win")
		expect.equal(DangerRules.knockout("run", true, false, false), false, "ran away")
		expect.equal(DangerRules.knockout("lose", false, false, false), false, "a calm place")
		expect.equal(DangerRules.knockout("lose", true, true, false), false, "a boss keeps its own defeat")
		expect.equal(DangerRules.knockout("lose", true, false, true), false, "a Dungeon room keeps its own")
	end,
}
