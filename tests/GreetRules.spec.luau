--!strict
-- Town Chikin greeting players who come near (the owner 2026-11-11: "Make chicken greet you or other player when your
-- at a certain distance from them"): who he greets, how often, and what he says (Util/GreetRules, Config/Chikin
-- TOWN.greet, ChikinTalk.GREETS)
local GreetRules = require("../src/shared/Util/GreetRules")
local Chikin = require("../src/shared/Config/Chikin")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
local expect = require("./lib/expect")

local CFG = { range = 16, cooldown = 120 }

return {
	["he greets the nearest player in range he hasn't greeted lately"] = function()
		local near = { { key = "a", distance = 12 }, { key = "b", distance = 8 }, { key = "c", distance = 30 } }
		expect.equal(GreetRules.pick(near, {}, 1000, CFG), "b", "the nearest in range")
		expect.equal(GreetRules.pick(near, { b = 950 }, 1000, CFG), "a", "b was greeted 50 s ago: the next one")
		expect.equal(GreetRules.pick(near, { a = 950, b = 950 }, 1000, CFG), nil, "both greeted lately; c is too far")
		expect.equal(GreetRules.pick(near, { b = 850 }, 1000, CFG), "b", "two minutes on: again")
		expect.equal(GreetRules.pick({}, {}, 1000, CFG), nil, "nobody near")
	end,

	["his greetings: short, with the player's name, a different one each time"] = function()
		local lines = ChikinTalk.GREETS
		assert(#lines >= 3, "a few")
		for _, line in lines do
			assert(string.find(line, "%%s"), `{line}: has the name`)
			assert(#string.format(line, "AVeryLongName20Chars") <= 44, `{line}: short with a long name`)
			for _, code in utf8.codes(line) do
				assert((code >= 0x20 and code <= 0x7E) or code >= 0x1F000 or code == 0xB7, `{line}: drawable`)
			end
		end
		expect.equal(GreetRules.line(3, 0, 1), 2, "never the last one again")
		expect.equal(GreetRules.line(3, 0.99, nil), 3)
		expect.equal(GreetRules.line(1, 0.5, 1), 1)
		local greet = Chikin.TOWN.greet
		assert(greet.range >= 10 and greet.range <= 24, "close enough to see him")
		assert(greet.cooldown >= 60, "not every few seconds")
		assert(greet.hold > 0 and greet.hold <= 4, "a short stop")
		assert(#greet.clips >= 2, "a few ways to say hi")
	end,
}
