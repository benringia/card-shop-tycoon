--!strict
-- The healing spring answers (owner 2026-11-20: "make the healing spring interactable. when new players interact with
-- it. It says something like 'bring your injured pet here to get healed' fix the wordings")
local SpringRules = require("../src/shared/Util/SpringRules")
local Combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

local ASK = Combat.SPRING_ASK

return {
	["nobody hurt: it says what the spring is for, in the game's own words"] = function()
		local words = SpringRules.words({}, nil, Combat.SPRING_SPEED, ASK)
		expect.equal(words, "Is a creature hurt? Bring it here! It gets better 3 times faster by the spring.")
		assert(not string.find(words, "pet", 1, true), "the game says creature")
	end,

	["one hurt creature: its name and how long it takes here"] = function()
		local words = SpringRules.words({ "Thunderhorn" }, 300, Combat.SPRING_SPEED, ASK)
		expect.equal(words, "Thunderhorn is hurt. Stay by the spring: all better in about 2 minutes!")
	end,

	["several: a count, and the time of the one that takes longest"] = function()
		local words = SpringRules.words({ "Thunderhorn", "Bramblequake", "Cindercub" }, 90, Combat.SPRING_SPEED, ASK)
		expect.equal(words, "3 creatures are hurt. Stay by the spring: all better in about 30 seconds!")
	end,

	["the time by the spring: a third of the rest left, in round words"] = function()
		expect.equal(SpringRules.timeWords(300, 3), "2 minutes", "100 s rounds up")
		expect.equal(SpringRules.timeWords(180, 3), "1 minute")
		expect.equal(SpringRules.timeWords(90, 3), "30 seconds")
		expect.equal(SpringRules.timeWords(31, 3), "15 seconds", "up to the next 5")
		expect.equal(SpringRules.timeWords(2, 3), "5 seconds", "never 0")
	end,

	["the prompt: its own key (E is the summon key), reaching the healing area's edge, every line short"] = function()
		assert(ASK.key ~= "E", "E calls your creature")
		expect.equal(ASK.distance <= Combat.SPRING_RADIUS, true, "asked from inside the healing area")
		for _, name in { "idle", "one", "many" } do
			assert(#ASK[name] <= 90, `{name} is short`)
		end
		assert(ASK.seconds >= 5, "long enough to read")
	end,
}
