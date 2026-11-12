--!strict
-- Town Chikin greeting players who come near (the owner 2026-11-11: "Make chicken greet you or other player when your
-- at a certain distance from them"): who he greets, how often, and what he says (Util/GreetRules, Config/Chikin
-- TOWN.greet, ChikinTalk.GREETS)
local GreetRules = require("../src/shared/Util/GreetRules")
local Chikin = require("../src/shared/Config/Chikin")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
local PishTalk = require("../src/shared/Config/PishTalk")
local expect = require("./lib/expect")

local CFG = { range = 16, cooldown = 120 }

return {
	-- "Support the dev" (owner 2026-11-12, pick: the town dogs thank you): a supporter gets a thank-you line, numbered
	-- after the hellos so one list holds both (Util/GreetBubble)
	["supporters get a thank-you line, never the same one twice running; everyone else a hello"] = function()
		expect.equal(GreetRules.pickLine(4, 3, false, 0, nil) <= 4, true, "a hello")
		expect.equal(GreetRules.pickLine(4, 3, true, 0, nil), 5, "the first thank-you")
		expect.equal(GreetRules.pickLine(4, 3, true, 0, 5), 6, "not the same thank-you again")
		expect.equal(GreetRules.pickLine(4, 0, true, 0.5, nil) <= 4, true, "no thank-you lines: a hello")
		for _, talk in { PishTalk, ChikinTalk } do
			assert(#talk.THANKS >= 2, "a few thank-yous")
			for _, line in talk.THANKS do
				assert(string.find(line, "%%s"), `{line}: has the name`)
				assert(#string.format(line, "AVeryLongName20Chars") <= 48, `{line}: short with a long name`)
			end
		end
	end,

	-- owner 2026-11-12: "pish is still not greeting me if i'm near him": he greeted on joining (during the loading screen)
	-- and the 2 minute wait hid the next; now a hello is for walking up to him
	["he greets a player who walks up, not one who was already there"] = function()
		local near = { { key = "a", distance = 5 }, { key = "b", distance = 8 } }
		expect.equal(GreetRules.pick(near, {}, 100, CFG, { a = true }), "b", "a was already near: b just came")
		expect.equal(GreetRules.pick(near, {}, 100, CFG, { a = true, b = true }), nil, "both were there already")
		expect.equal(GreetRules.pick(near, {}, 100, CFG), "a", "without a last look, the nearest")
	end,

	["the dogs wait a short while between hellos to one player, and skip the first seconds after joining"] = function()
		local Pish = require("../src/shared/Config/Pish")
		for name, greet in { Chikin = Chikin.TOWN.greet, Pish = Pish.TOWN.greet } do
			expect.equal(greet.cooldown <= 45, true, `{name}: a hello again after a short while`)
			expect.equal(greet.joinGrace ~= nil and greet.joinGrace >= 10, true, `{name}: not during the loading screen`)
		end
	end,

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
		assert(greet.cooldown >= 20, "not every few seconds (a hello is for walking up, owner 2026-11-12)")
		assert(greet.hold > 0 and greet.hold <= 4, "a short stop")
		assert(#greet.clips >= 2, "a few ways to say hi")
	end,
}
