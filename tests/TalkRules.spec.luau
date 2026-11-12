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
	for key, text in PishTalk.TEACH do
		visit(`teach {key}`, string.format(text, "First Spark Booster Box")) -- the longest name a line names
	end
	for id, lines in PishTalk.AFTER do
		for i, text in lines do
			visit(`after {id}[{i}]`, text)
		end
	end
	-- Town Pish's hellos (owner 2026-11-12: "npc pish should also greet people like chikin"), with a long name
	for i, text in PishTalk.GREETS do
		visit(`greet[{i}]`, string.format(text, "Twentycharactername1"))
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

	["Town Pish greets players who come near, like Town Chikin"] = function()
		local greet = Pish.TOWN.greet
		expect.equal(greet ~= nil and greet.range > 0 and greet.cooldown >= 20 and #greet.clips > 0, true, "his greet settings")
		expect.equal(#PishTalk.GREETS >= 3, true, "a few hellos, so they don't repeat")
		for i, text in PishTalk.GREETS do
			expect.equal(string.find(text, "%s", 1, true) ~= nil, true, `greet[{i}] names the player`)
		end
	end,

	["every line is short and drawable"] = function()
		eachLine(function(where, text)
			local filled = TalkRules.fill(text, Game.NAME)
			assert(utf8.len(filled) and (utf8.len(filled) :: number) <= MAX_LENGTH, `{where} is at most {MAX_LENGTH} characters`)
			assert(readable(filled), `{where}: plain ASCII, the middle dot and emoji only`)
		end)
	end,

	["the Skip button and the tour card say what everything is (owner: label everything; round 3: a small Skip)"] = function()
		local labels = PishTalk.LABELS
		expect.equal(string.format(labels.tour, 3, 8), "Pish's Tour · 3 of 8")
		expect.equal(labels.skip, "Skip")
		expect.equal(labels.tourGift, "Finish the tour for Pish's gift!")
		expect.equal(labels.keepGoing, "Keep going")
		expect.equal(labels.skipYes, "Skip tour")
		for _, gone in { "tourShort", "gift", "giftShort", "skipHold", "skipTitle", "skipWarning" } do
			expect.equal(labels[gone], nil, `the tour bar's {gone} is gone`)
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
	["a lesson teaches step by step: a line for each place the player is at (round 4)"] = function()
		for _, situation in { "default", "trayOpen", "tab", "tile", "placing", "computer", "orderOpen", "closeWindow" } do
			assert(PishTalk.TEACH[situation], `a line for {situation}`)
		end
		expect.equal(string.format(PishTalk.TEACH.tile, "Wall Shelf"), "Tap the Wall Shelf!")
		expect.equal(string.format(PishTalk.TEACH.orderOpen, "Card Sleeves"), "Tap Order on Card Sleeves!")
		expect.equal(PishTalk.TEACH.closeWindow, PishTalk.LABELS.close)
	end,
	["once it's placed or ordered, Pish says what it's for (owner: explain what this is for)"] = function()
		for _, lesson in Pish.LESSONS do
			local lessonAny = lesson :: any
			if lessonAny.shelf or lessonAny.product or lessonAny.trigger == "trophy" then
				local lines = PishTalk.AFTER[lesson.id]
				assert(lines and #lines >= 2, `{lesson.id} has at least two lines after`)
			end
		end
		expect.equal(PishTalk.AFTER.showcase[1], "Customers buy single cards from this case!")
	end,

	-- The owner 2026-11-11: "move the dialogue at the center top so that pish model can be seen"
	["the talk card sits at the top, unless it would cover what Pish points at there"] = function()
		local TOP, HEIGHT, PAW = 66, 112, 82
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, nil, false), true, "nothing pointed at: the top")
		local tile = { top = 520, low = 580, across = true }
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, tile, false), true, "a HUD tile at the bottom: still the top")
		local high = { top = 120, low = 170, across = true }
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, high, false), false, "a button under the top card: the bottom")
		local paw = { top = 230, low = 280, across = true }
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, paw, false), false, "the paw over it would hit the card")
		local aside = { top = 120, low = 170, across = false }
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, aside, false), true, "beside the card: the top")
		expect.equal(TalkRules.cardAtTop(TOP, HEIGHT, PAW, high, true), true, "a fight keeps it at the top")
	end,
}
