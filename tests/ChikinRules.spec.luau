--!strict
-- Chikin's combat tutorial (spec 2026-11-10-chikin-combat-tutorial-design): his steps on Pish's step machine
-- (Util/TutorialRules), his two visits with a hidden wait for shop level 4 between them, and his lines
local Chikin = require("../src/shared/Config/Chikin")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
local TalkRules = require("../src/shared/Util/TalkRules")
local Pish = require("../src/shared/Config/Pish")
local TutorialRules = require("../src/shared/Util/TutorialRules")
local ChikinRules = require("../src/shared/Util/ChikinRules")
local Wild = require("../src/shared/Config/Wild")
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
		-- but for his home, the dog house in the plaza (owner 2026-11-20: "add the dog house as a stop for both dogs")
		assert(stop.home or stop.x >= 60 or stop.x <= -90, `({stop.x}, {stop.z}) on the portal side, clear of Pish's shops`)
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
	["his tutorial fights keep a new player's creatures from fainting: both his first visit's fights, nothing else"] = function()
		local guarded = {}
		for step in Chikin.GUARDED_STEPS do
			assert(table.find(STEPS, step), `{step} is one of his steps`)
			table.insert(guarded, step)
		end
		table.sort(guarded)
		expect.equal(table.concat(guarded, ","), "fight,fight2", "the creature's first fight and the sword fight")
	end,

	-- Owner 2026-11-19 ("Abuse: at the chikin tutorial, where pets are unkillable. a player can go to a higher level
	-- monster and kill it without their pet dying"): the guard holds only against the monsters his fights are for
	["the guard is only for his own fights: the Meadow's normal monsters, never an elite, a boss or a higher zone"] = function()
		local meadow = Wild.ZONES[1]
		expect.equal(Chikin.GUARDED_MAX_LEVEL, meadow.maxLevel, "the Meadow's top level")
		expect.equal(ChikinRules.guards(Chikin, "fight", { level = 1 }), true)
		expect.equal(ChikinRules.guards(Chikin, "fight2", { level = meadow.maxLevel }), true)
		expect.equal(ChikinRules.guards(Chikin, "fight", { level = meadow.maxLevel + 1 }), false, "a Caves monster")
		expect.equal(ChikinRules.guards(Chikin, "fight2", { level = 12 }), false, "an Ember Ridge monster")
		expect.equal(ChikinRules.guards(Chikin, "fight", { level = 2, elite = true }), false, "an elite")
		expect.equal(ChikinRules.guards(Chikin, "fight", { level = 1, boss = "meadowWarden" }), false, "a boss")
		expect.equal(ChikinRules.guards(Chikin, "wild", { level = 1 }), false, "not one of his fight steps")
		expect.equal(ChikinRules.guards(Chikin, nil, { level = 1 }), false, "his tutorial is over")
		expect.equal(ChikinRules.guards(Chikin, "fight", { level = 0 / 0 }), false, "junk")
	end,

	-- Owner 2026-11-20: "chikin cinematic should only appear once. only on its first appearance": his run-in with the
	-- camera plays for his very first step only; every later arrival (his level 4 visit, a rejoin mid-visit, back from
	-- the Wild) he just comes to you
	["his arrival's cinematic plays once: on his first step only"] = function()
		expect.equal(ChikinRules.arrivesWithCinematic(Chikin, STEPS[1]), true, "his first hello")
		expect.equal(STEPS[1], "hello")
		for index = 2, #STEPS do
			expect.equal(ChikinRules.arrivesWithCinematic(Chikin, STEPS[index]), false, `{STEPS[index]}: no cinematic`)
		end
		expect.equal(ChikinRules.arrivesWithCinematic(Chikin, "sword"), false, "his level 4 visit")
		expect.equal(ChikinRules.arrivesWithCinematic(Chikin, ""), false, "not leading")
	end,

	-- Owner 2026-11-19 (second playthrough): "add a GOT IT for chikin too": on his level 4 visit, the line he waits on
	-- ("Follow my paws to the Wild!") has a Got it! that sends him off, like Pish's lessons. His first visit (the real
	-- tutorial, with the sword) keeps its Skip
	["Got it! sends him off on his level 4 visit's waiting line, never in his first visit"] = function()
		expect.equal(ChikinRules.gotIt(Chikin, "wild2"), true, "following his paws to the Wild")
		for _, step in Chikin.VISITS[1] do
			expect.equal(ChikinRules.gotIt(Chikin, step), false, `{step}: his first visit has no Got it`)
		end
		expect.equal(ChikinRules.gotIt(Chikin, Chikin.WAIT_STEP), false)
		expect.equal(ChikinRules.gotIt(Chikin, ""), false)
		for step in Chikin.GOT_IT_STEPS do
			assert(table.find(Chikin.VISITS[2], step), `{step} is one of his level 4 visit's steps`)
			assert(next(ChikinTalk.STEPS[step].now) ~= nil, `{step} waits on a line with no Next`)
		end
		expect.equal(ChikinTalk.GOT_IT, "Got it!")
	end,

	["town: Chikin's Courage and his portal-side walk"] = townChecks,

	-- owner 2026-11-16: "in the wilds. chikin will make you fight a monster with your summoned pet. after the monster is
	-- dead, he will give you a sword and fight another monster. then will leave"; his level 4 visit shows the boss
	["his steps: a fight with your creature, the sword, a fight with it, then at level 4 the boss"] = function()
		local order = table.concat(STEPS, ",")
		expect.equal(order, "hello,party,summon,wild,fight,firstWin,fight2,swordWin,level4,sword,wild2,boss")
		expect.equal(Chikin.WAIT_STEP, "level4")
		expect.equal(Chikin.SWORD_LEVEL, 4)
		expect.equal(#Chikin.VISITS, 2)
		expect.equal(table.concat(Chikin.VISITS[1], ","), "hello,party,summon,wild,fight,firstWin,fight2,swordWin")
		expect.equal(table.concat(Chikin.VISITS[2], ","), "sword,wild2,boss")
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
			if step == "swordWin" then
				continue -- his goodbye before level 4 ends when you open your Quests (below)
			end
			expect.equal(next(ChikinTalk.STEPS[step].now), nil, `{step} ends on its last Next`)
			assert(#ChikinTalk.STEPS[step].intro > 0, `{step} has lines`)
		end
		for _, step in { "hello", "firstWin", "swordWin", "sword", "boss" } do
			assert(Chikin.FINISH_STEPS[step], `{step} ends on its last Next`)
		end
		expect.equal(#ChikinTalk.STEPS.party.intro, 0, "the party step starts on what to do (hello said hi)")
		-- A hello's last button starts the lesson; only his goodbyes say Bye
		expect.equal(Chikin.BYE_STEPS.firstWin, nil, "he stays: the sword fight comes next")
		expect.equal(Chikin.BYE_STEPS.swordWin, true)
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

	["the first win hands over the sword; a player already at shop level 4 goes straight on to the boss"] = function()
		local handOver = table.concat(ChikinTalk.STEPS.firstWin.intro, " ")
		assert(string.find(handOver, "sword", 1, true), "the first win gives the sword")
		assert(string.find(table.concat(ChikinTalk.LOST, " "), "sword", 1, true), "a lost first fight too")
		assert(ChikinTalk.SWORD_NOW, "the line")
		assert((utf8.len(ChikinTalk.SWORD_NOW) :: number) <= 60, "short")
	end,

	["his goodbye: monsters grow the shop a little, hunt to level 4 or go sell in town, the paw on the town button"] = function()
		local goodbye = ChikinTalk.STEPS.swordWin.intro
		local all = table.concat(goodbye, " ")
		assert(not string.find(all, "not your shop", 1, true), "fights do grow the shop now (owner 2026-11-18)")
		assert(string.find(all, "little", 1, true), "a little shop XP from monsters")
		assert(string.find(all, "level 4", 1, true), "hunting to shop level 4")
		local town = Chikin.TOWN_LINE
		expect.equal(town.step, "swordWin", "his goodbye after the sword fight")
		expect.equal(town.from, #goodbye, "the last intro line points at the town button")
		expect.equal(town.upTo, #goodbye, "only that line: the next points at your Quests")
		assert(string.find(goodbye[town.from], "faster", 1, true), "selling in town is faster")
	end,

	-- owner 2026-11-20: "at the end of chikin tutorial where you need to get to level 4. make the player check the
	-- QUESTS on the phone": his goodbye ends on a line that waits for you to open Quests, the paw on the Phone and then
	-- on its Quests app; opening them finishes his visit
	["his goodbye before level 4 ends with you opening Quests on your Phone"] = function()
		local now = ChikinTalk.STEPS.swordWin.now
		assert(now.default and string.find(now.default, "Quests", 1, true) and string.find(now.default, "Phone", 1, true), "it says to open Quests on the Phone")
		assert(now.phoneOpen and string.find(now.phoneOpen, "Quests", 1, true), "with the Phone open: tap Quests")
		assert(now.closeWindow, "another window in the way: close it")
		for _, line in now do
			assert((utf8.len(line) :: number) <= 60, `short: {line}`)
		end
		expect.equal(Chikin.QUESTS_STEP, "swordWin", "the step that ends on the Quests window")
		local shown = TalkRules.show(ChikinTalk.STEPS.swordWin, #ChikinTalk.STEPS.swordWin.intro, "default")
		expect.equal(shown.finish, false, "the town line's button is Next now, not Bye")
		local waiting = TalkRules.show(ChikinTalk.STEPS.swordWin, #ChikinTalk.STEPS.swordWin.intro + 1, "default")
		expect.equal(waiting.next, false, "no button: opening Quests moves on")
		expect.equal(waiting.text, now.default)
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
		local PIECES = { party = true, weapons = true, bosses = true, buffs = true, mascot = true, quests = true }
		local function keeps(step: string, inTown: boolean): string?
			local kept = TutorialRules.chikinFocus(step, inTown, Chikin.FOCUS, Chikin.WAIT_STEP, Chikin.FOCUS_ALWAYS)
			return if kept then table.concat(kept, ",") else nil
		end
		-- Owner 2026-11-20 (first public playthrough): "the party section/character info on the bottom left side keeps
		-- disappearing specially when chikin reappeared. it should appear on the first time the player got a pet and
		-- then never disappear": the party bar stays through every step of his
		expect.equal(keeps("hello", true), "party", "his hello: the party bar stays")
		expect.equal(keeps("summon", true), "party", "summon: the party bar")
		expect.equal(keeps("sword", true), "party,weapons,quests", "the sword: the weapon switch too")
		-- Owner 2026-11-19 (second playthrough): "at level 4 when he appear. the quest disappears too. it should not":
		-- the quest strip stays through his whole level 4 visit
		for _, step in Chikin.VISITS[2] do
			local kept = TutorialRules.chikinFocus(step, true, Chikin.FOCUS, Chikin.WAIT_STEP, Chikin.FOCUS_ALWAYS)
			assert(kept and table.find(kept, "quests"), `{step}: the quest strip stays`)
		end
		expect.equal(keeps("wild", true), "party", "on his way to the portal")
		for _, step in STEPS do
			if step ~= Chikin.WAIT_STEP then
				local kept = TutorialRules.chikinFocus(step, true, Chikin.FOCUS, Chikin.WAIT_STEP, Chikin.FOCUS_ALWAYS)
				assert(kept and table.find(kept, "party"), `{step}: the party bar never goes`)
			end
		end
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
