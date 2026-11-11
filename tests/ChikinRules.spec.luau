--!strict
-- Chikin's combat tutorial (spec 2026-11-10-chikin-combat-tutorial-design): his steps on Pish's step machine
-- (Util/TutorialRules), his two visits with a hidden wait for shop level 4 between them, and his lines
local Chikin = require("../src/shared/Config/Chikin")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
local Pish = require("../src/shared/Config/Pish")
local TutorialRules = require("../src/shared/Util/TutorialRules")
local expect = require("./lib/expect")

local STEPS = Chikin.STEPS

-- Town Chikin (the owner 2026-11-11: "after chikin's tutorial he will become an NPC too like pish, walking around the
-- town"; his picks: a combat buff for 5 minutes, the portal side of town)
local function townChecks()
	local courage = Chikin.COURAGE
	expect.equal(courage.seconds, 300, "5 minutes")
	expect.near(courage.share, 0.1, 1e-9, "creatures hit 10% harder")
	assert(courage.cooldown >= courage.seconds * 2, "not up all the time")
	assert(courage.petRange >= 8, "pettable from beside him")
	local town = Chikin.TOWN
	assert(#town.stops >= 6, "a few stops")
	local east, arena = 0, 0
	for _, stop in town.stops do
		assert(stop.weight > 0, "every stop can come up")
		assert(math.abs(stop.z) <= 32 or math.abs(stop.x) >= 100, `({stop.x}, {stop.z}) on the street or a trail`)
		if stop.x >= 60 then
			east += stop.weight
		elseif stop.x <= -90 then
			arena += stop.weight
		end
		assert(stop.x >= 60 or stop.x <= -90, `({stop.x}, {stop.z}) on the portal side, clear of Pish's shops`)
	end
	assert(east > arena, "mostly by the Wild and Frontier trails")
	for _, clip in town.idleClips do
		assert(table.find(Pish.TOWN.idleClips, clip) or clip == "nap", `{clip}: one of the dogs' clips`)
	end
end

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
	["town: Chikin's Courage and his portal-side walk"] = townChecks,

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
		-- A hello's last button starts the lesson; only his goodbyes say Bye
		expect.equal(Chikin.BYE_STEPS.firstWin, true)
		expect.equal(Chikin.BYE_STEPS.boss, true)
		expect.equal(Chikin.BYE_STEPS.hello, nil)
		expect.equal(Chikin.BYE_STEPS.sword, nil)
		expect.equal(ChikinTalk.GO, "Let's go!")
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

	["in a fight the first tip is short (a new player's first fight lasts about 12 s), the others longer"] = function()
		assert(Chikin.FIRST_TIP_SECONDS <= 4, "the creature fights by itself: a quick word")
		assert(Chikin.FIGHT_TIP_SECONDS > Chikin.FIRST_TIP_SECONDS, "time to try the button")
	end,

	["a player already at shop level 4 hears 'let's try your sword' instead of 'come back at level 4'"] = function()
		assert(ChikinTalk.SWORD_NOW, "the line")
		assert((utf8.len(ChikinTalk.SWORD_NOW) :: number) <= 60, "short")
		assert(string.find(ChikinTalk.STEPS.firstWin.intro[#ChikinTalk.STEPS.firstWin.intro], "level 4", 1, true), "the usual last line names level 4")
	end,

	["a sword fight not won stays on the fight step (the second visit needs a win to finish); the first moves on"] = function()
		expect.equal(Chikin.WIN_TO_PASS.fight2, true, "the sword fight")
		expect.equal(Chikin.WIN_TO_PASS.fight, nil, "the first fight ends either way (its own lost lines)")
		assert(ChikinTalk.RETRY and (utf8.len(ChikinTalk.RETRY) :: number) <= 60, "a short try-again line")
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

	-- The owner 2026-11-11 (the calm HUD's focus mode, pick A): while Chikin leads in town the HUD shows only what his
	-- step uses; the peeking Pish waits till the tour is over; the Wild keeps the whole HUD (fights need it)
	["while Chikin leads in town the HUD keeps only what his step uses"] = function()
		local PIECES = { party = true, weapons = true, bosses = true, buffs = true, mascot = true }
		local function keeps(step: string, inTown: boolean): string?
			local kept = TutorialRules.chikinFocus(step, inTown, Chikin.FOCUS, Chikin.WAIT_STEP)
			return if kept then table.concat(kept, ",") else nil
		end
		expect.equal(keeps("hello", true), "", "his hello: nothing extra")
		expect.equal(keeps("summon", true), "party", "summon: the party bar")
		expect.equal(keeps("sword", true), "weapons", "the sword: the weapon switch")
		expect.equal(keeps("wild", true), "", "on his way to the portal")
		expect.isNil(keeps("fight", false), "the Wild: the whole HUD")
		expect.isNil(keeps(Chikin.WAIT_STEP, true), "his wait for shop level 4: not leading")
		expect.isNil(keeps("", true), "no tour")
		for step, kept in Chikin.FOCUS do
			assert(table.find(STEPS, step), `{step} is one of his steps`)
			for _, name in kept do
				assert(PIECES[name], `{step}: {name} is a calm HUD piece`)
				assert(name ~= "mascot", "the peeking Pish waits till the tour is over")
			end
		end
	end,
}
