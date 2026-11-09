--!strict
-- Pish talks the player through the first visit (spec 2026-11-09-tutorial-pish-design 14): a few lines per step, then
-- the line for what to do now, by situation; one line per lesson and nudge
local Pish = require("../src/shared/Config/Pish")
local PishTalk = require("../src/shared/Config/PishTalk")
local Game = require("../src/shared/Config/Game")
local TalkRules = require("../src/shared/Util/TalkRules")
local expect = require("./lib/expect")

local MAX_LENGTH = 60 -- characters: one short line, big text

-- Plain ASCII, the middle dot and emoji only (Gotham and Fredoka draw other symbols as empty boxes)
local function readable(text: string): boolean
	for _, code in utf8.codes(text) do
		local ok = (code >= 0x20 and code <= 0x7E) or code == 0xB7 or code >= 0x1F000 or code == 0xFE0F or code == 0x200D
		if not ok then
			return false
		end
	end
	return true
end

local function eachLine(visit: (where: string, text: string) -> ())
	for step, talk in PishTalk.STEPS do
		for i, text in talk.intro do
			visit(`{step}.intro[{i}]`, text)
		end
		for situation, text in talk.now do
			visit(`{step}.now.{situation}`, text)
		end
	end
	for id, text in PishTalk.LESSONS do
		visit(`lesson {id}`, text)
	end
	for kind, text in PishTalk.NUDGES do
		visit(`nudge {kind}`, text)
	end
	for key, text in PishTalk.LABELS do
		visit(`label {key}`, string.format(text, 3, 8))
	end
end

return {
	["every step has its talk: intro lines and a default line for now, or only intro lines (the goodbye)"] = function()
		for _, step in Pish.STEPS do
			local talk = PishTalk.STEPS[step]
			assert(talk, `{step} has a talk`)
			local hasNow = next(talk.now) ~= nil
			assert(#talk.intro > 0 or hasNow, `{step} says something`)
			if hasNow then
				assert(talk.now.default, `{step} has a default line for now`)
			end
		end
		expect.equal(next(PishTalk.STEPS.bye.now), nil, "the goodbye is only intro lines (its last Next ends the visit)")
	end,

	["every lesson and nudge has its line"] = function()
		for _, lesson in Pish.LESSONS do
			assert(PishTalk.LESSONS[lesson.id], `lesson {lesson.id}`)
		end
		for _, kind in { "order", "stock" } do
			assert(PishTalk.NUDGES[kind], `nudge {kind}`)
		end
	end,

	["every line is short and drawable"] = function()
		eachLine(function(where, text)
			local filled = TalkRules.fill(text, Game.NAME)
			assert(utf8.len(filled) and (utf8.len(filled) :: number) <= MAX_LENGTH, `{where} is at most {MAX_LENGTH} characters`)
			assert(readable(filled), `{where}: plain ASCII, the middle dot and emoji only`)
		end)
	end,

	["the top bar and the skip card say what everything is (owner: label everything)"] = function()
		local labels = PishTalk.LABELS
		expect.equal(string.format(labels.tour, 3, 8), "Pish's Tour · 3 of 8")
		expect.equal(string.format(labels.tourShort, 3, 8), "Tour · 3 of 8")
		for _, key in { "gift", "giftShort", "skip", "skipHold", "skipTitle", "skipWarning", "keepGoing", "skipYes" } do
			assert(labels[key], `label {key}`)
		end
	end,

	["the owner's welcome names the game"] = function()
		local intro = PishTalk.STEPS.giftPack.intro
		expect.equal(intro[1], "Hi! I'm Pish!")
		expect.equal(TalkRules.fill(intro[2], "Card Town"), "Welcome to Card Town!")
		expect.equal(Game.NAME, "Cardshop Simulator", "the placeholder until the name is decided")
	end,

	["show: the intro one line at a time with Next, then the line for now, by situation"] = function()
		local talk = { intro = { "a", "b" }, now = { default = "do it", bagOpen = "tap it" } }
		local first = TalkRules.show(talk, 1, "default")
		expect.equal(first.text, "a")
		expect.equal(first.next, true)
		expect.equal(first.finish, false)
		expect.equal(TalkRules.show(talk, 2, "bagOpen").text, "b", "the intro first, whatever is open")
		local now = TalkRules.show(talk, 3, "bagOpen")
		expect.equal(now.text, "tap it")
		expect.equal(now.next, false, "the line for now stays until it's done")
		expect.equal(TalkRules.show(talk, 3, "somethingElse").text, "do it", "an unknown situation: the default")
		expect.equal(TalkRules.show(talk, 9, "default").text, "do it", "past the intro")
	end,

	["show: a step with no intro starts on its line for now"] = function()
		local talk = { intro = {}, now = { default = "do it" } }
		expect.equal(TalkRules.show(talk, 1, "default").text, "do it")
		expect.equal(TalkRules.show(talk, 1, "default").next, false)
	end,

	["show: a talk with only intro lines finishes on its last Next (the goodbye)"] = function()
		local talk = { intro = { "a", "bye" }, now = {} }
		expect.equal(TalkRules.show(talk, 1, "default").finish, false)
		local last = TalkRules.show(talk, 2, "default")
		expect.equal(last.text, "bye")
		expect.equal(last.next, true)
		expect.equal(last.finish, true)
		expect.equal(TalkRules.show(talk, 5, "default").text, "bye", "past the end: the last line")
	end,
}
