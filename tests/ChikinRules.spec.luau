--!strict
-- Chikin's combat tutorial (spec 2026-11-10-chikin-combat-tutorial-design): his steps on Pish's step machine
-- (Util/TutorialRules), his two visits with a hidden wait for shop level 4 between them, and his lines
local Chikin = require("../src/shared/Config/Chikin")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
local Pish = require("../src/shared/Config/Pish")
local TutorialRules = require("../src/shared/Util/TutorialRules")
local expect = require("./lib/expect")

local STEPS = Chikin.STEPS

local function readable(text: string): boolean
	for _, code in utf8.codes(text) do
		local ok = (code >= 0x20 and code <= 0x7E) or code == 0xB7 or code >= 0x1F000 or code == 0xFE0F or code == 0x200D
		if not ok then
			return false
		end
	end
	return true
end

return {
	["his steps: the first fight, a hidden wait for level 4, then the sword"] = function()
		local order = table.concat(STEPS, ",")
		expect.equal(order, "hello,party,summon,wild,fight,firstWin,level4,sword,wild2,fight2,boss")
		expect.equal(Chikin.WAIT_STEP, "level4")
		expect.equal(Chikin.SWORD_LEVEL, 4)
		expect.equal(#Chikin.VISITS, 2)
		expect.equal(table.concat(Chikin.VISITS[1], ","), "hello,party,summon,wild,fight,firstWin")
		expect.equal(table.concat(Chikin.VISITS[2], ","), "sword,wild2,fight2,boss")
	end,

	["every step but the wait has its talk; the ends are intro lines only (their last Next moves on)"] = function()
		for _, step in STEPS do
			if step ~= Chikin.WAIT_STEP then
				local talk = ChikinTalk.STEPS[step]
				assert(talk, `{step} has a talk`)
				assert(#talk.intro > 0 or next(talk.now) ~= nil, `{step} says something`)
				if next(talk.now) then
					assert(talk.now.default, `{step} has a default line for now`)
				end
			end
		end
		-- His hellos and goodbyes are intro lines only: their last Next moves on (Config/Chikin FINISH_STEPS)
		for step in Chikin.FINISH_STEPS do
			expect.equal(next(ChikinTalk.STEPS[step].now), nil, `{step} ends on its last Next`)
			assert(#ChikinTalk.STEPS[step].intro > 0, `{step} has lines`)
		end
		for _, step in { "hello", "firstWin", "sword", "boss" } do
			assert(Chikin.FINISH_STEPS[step], `{step} ends on its last Next`)
		end
		expect.equal(#ChikinTalk.STEPS.party.intro, 0, "the party step starts on what to do (hello said hi)")
		assert(#ChikinTalk.LOST >= 2, "a lost first fight has its own lines")
	end,

	["every line is short and drawable"] = function()
		local function check(where: string, text: string)
			assert((utf8.len(text) :: number) <= 60, `{where} is at most 60 characters`)
			assert(readable(text), `{where}: plain ASCII, the middle dot and emoji only`)
		end
		for step, talk in ChikinTalk.STEPS do
			for i, text in talk.intro do
				check(`{step}.intro[{i}]`, text)
			end
			for situation, text in talk.now do
				check(`{step}.now.{situation}`, text)
			end
		end
		for i, text in ChikinTalk.LOST do
			check(`LOST[{i}]`, text)
		end
		for key, text in ChikinTalk.FIGHT do
			check(`FIGHT.{key}`, text)
		end
		for key, text in ChikinTalk.LABELS do
			check(`LABELS.{key}`, string.format(text, 3, 5))
		end
	end,

	["Pish hands over to Chikin at his goodbye"] = function()
		local bye = require("../src/shared/Config/PishTalk").STEPS.bye.intro
		local found = false
		for _, line in bye do
			found = found or string.find(line, "Chikin", 1, true) ~= nil
		end
		assert(found, "Pish's goodbye names Chikin")
	end,

	["his numbers: Pish's size and sounds, a higher bark"] = function()
		expect.equal(Chikin.HEIGHT, Pish.HEIGHT)
		expect.equal(Chikin.SOUND_VOLUME, Pish.SOUND_VOLUME)
		for key, id in Pish.SOUNDS do
			expect.equal(Chikin.SOUNDS[key], id, `{key}: Pish's sound`)
		end
		assert((Chikin.SOUND_PITCH.bark or 1) > (Pish.SOUND_PITCH.bark or 1), "a smaller, higher bark than Pish's")
	end,

	["the step machine runs his list: steps done early wait their turn"] = function()
		local saved = TutorialRules.read({}, STEPS)
		expect.equal(TutorialRules.current(saved, STEPS), "hello", "he says hi first")
		local after = TutorialRules.record(saved, STEPS, "hello")
		after = TutorialRules.record(after, STEPS, "summon")
		expect.equal(TutorialRules.current(after, STEPS), "party", "summoning first doesn't skip the party")
		after = TutorialRules.record(after, STEPS, "party")
		expect.equal(TutorialRules.current(after, STEPS), "wild", "then the summon done early counts")
	end,
}
