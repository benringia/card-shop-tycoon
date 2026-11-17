--!strict
-- The new player's first session as one onboarding funnel (owner 2026-11-17, before the Friday playtest: "do the three
-- now", the third being tracking where testers quit): joining, the prologue's acts, the welcome flight, Pish's tour step
-- by step, then the first wild win, levels and the first quest claimed. Roblox numbers the steps from 1, in order.
local Funnel = require("../src/shared/Config/Funnel")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

return {
	["the funnel is one ordered list of unique, short step names"] = function()
		local seen: { [string]: boolean } = {}
		for index, name in Funnel.ONBOARDING do
			assert(typeof(name) == "string" and name ~= "", `step {index} has a name`)
			assert(#name <= 32, `{name} is short`)
			assert(not seen[name], `{name} is listed once`)
			seen[name] = true
		end
		expect.equal(Funnel.ONBOARDING[1], "Joined", "it starts with joining")
	end,

	["the prologue and the welcome flight come before Pish's tour, his steps in his order"] = function()
		local function at(name: string): number
			return table.find(Funnel.ONBOARDING, name) or error(`{name} is in the funnel`)
		end
		assert(at("PrologueStarted") < at("PrologueDone"), "the prologue starts, then ends")
		assert(at("PrologueDone") < at("WelcomeFlightDone"), "then the welcome flight")
		local last = at("WelcomeFlightDone")
		for _, step in Pish.STEPS do
			local index = at(step)
			expect.equal(index, last + 1, `{step} follows straight on`)
			last = index
		end
		assert(at("FirstWildWin") > last and at("FirstQuestClaimed") > last, "after the tour: playing on their own")
	end,

	["levels in the funnel are real levels the shop can reach, in order"] = function()
		local Levels = require("../src/shared/Config/Levels")
		local previous = 1
		for _, level in Funnel.LEVELS do
			assert(level > previous and level <= Levels.MAX_LEVEL, `level {level} in order`)
			assert(table.find(Funnel.ONBOARDING, `Level{level}`), `Level{level} is a step`)
			previous = level
		end
	end,
}
