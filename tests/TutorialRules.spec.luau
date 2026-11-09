--!strict
-- The first visit's steps (spec 2026-11-09-tutorial-pish-design 5, 6, 9): what's saved, the step that's current, steps
-- done early waiting their turn, skipping and replaying without giving the gifts twice
local TutorialRules = require("../src/shared/Util/TutorialRules")
local Pish = require("../src/shared/Config/Pish")
local UIIcons = require("../src/shared/Config/UIIcons")
local expect = require("./lib/expect")

local STEPS = Pish.STEPS

local function same(a: { string }, b: { string }, what: string)
	expect.equal(#a, #b, `{what}: count`)
	for i = 1, #b do
		expect.equal(a[i], b[i], `{what}: #{i}`)
	end
end

return {
	["the steps are the spec's eight, in order"] = function()
		same(STEPS, { "giftPack", "buildRack", "orderStock", "stockRack", "customer", "ringUp", "gift", "bye" }, "steps")
	end,

	["every step's and lesson's picture is an uploaded icon (no words on screen)"] = function()
		for _, id in STEPS do
			local icon = Pish.STEP_ICONS[id]
			assert(icon and (UIIcons :: any)[icon], `step {id}'s icon is uploaded`)
		end
		for _, lesson in Pish.LESSONS do
			assert((UIIcons :: any)[lesson.icon], `lesson {lesson.id}'s icon is uploaded`)
		end
	end,

	["a new save starts the first visit at its first step"] = function()
		local saved = TutorialRules.read({}, STEPS)
		expect.equal(saved.firstVisit, "todo")
		expect.equal(saved.step, 1)
		expect.equal(TutorialRules.current(saved, STEPS), "giftPack")
		expect.equal(saved.firstGiven, false)
		expect.equal(saved.giftClaimed, false)
		expect.equal(saved.pishLuckAt, 0)
	end,

	["record: the current step completes and the next becomes current"] = function()
		local saved, done = TutorialRules.record(TutorialRules.read({}, STEPS), STEPS, "giftPack")
		expect.equal(saved.step, 2)
		same(done, { "giftPack" }, "completed")
		expect.equal(TutorialRules.current(saved, STEPS), "buildRack")
	end,

	["early events wait their turn"] = function()
		local saved = TutorialRules.read({ firstVisit = "todo", step = 2 }, STEPS)
		local done
		saved, done = TutorialRules.record(saved, STEPS, "orderStock")
		expect.equal(saved.step, 2, "ordering before building doesn't skip building")
		expect.equal(saved.early.orderStock, true)
		same(done, {}, "nothing completed yet")
		saved, done = TutorialRules.record(saved, STEPS, "buildRack")
		expect.equal(saved.step, 4, "building completes, then the order counts")
		same(done, { "buildRack", "orderStock" }, "both completed, in order")
		saved, done = TutorialRules.record(saved, STEPS, "ringUp")
		expect.equal(saved.step, 4, "a sale before stocking waits too")
		same(done, {}, "nothing completed")
		expect.equal(saved.early.ringUp, true)
	end,

	["an event for a step already passed changes nothing"] = function()
		local saved = TutorialRules.read({ firstVisit = "todo", step = 4 }, STEPS)
		local after, done = TutorialRules.record(saved, STEPS, "giftPack")
		expect.equal(after.step, 4)
		same(done, {}, "nothing")
		expect.equal(after.early.giftPack, nil, "not kept as early either")
	end,

	["resume: a saved step survives read, bad values fall back"] = function()
		expect.equal(TutorialRules.read({ firstVisit = "todo", step = 5 }, STEPS).step, 5)
		expect.equal(TutorialRules.read({ firstVisit = "todo", step = 99 }, STEPS).step, #STEPS)
		expect.equal(TutorialRules.read({ firstVisit = "todo", step = "x" }, STEPS).step, 1)
		expect.equal(TutorialRules.read({ firstVisit = "todo", step = 2.5 }, STEPS).step, 1)
		expect.equal(TutorialRules.read({ firstVisit = 3 }, STEPS).firstVisit, "done", "junk counts as done, never forced")
		expect.equal(TutorialRules.read({ firstVisit = "skipped" }, STEPS).firstVisit, "skipped")
		local early = TutorialRules.read({ firstVisit = "todo", early = { stockRack = true, nope = true, ringUp = 4 } }, STEPS).early
		expect.equal(early.stockRack, true)
		expect.equal(early.nope, nil, "unknown steps dropped")
		expect.equal(early.ringUp, nil, "non-true dropped")
		local lessons = TutorialRules.read({ lessons = { forge = true, jobs = false, bad = "yes" } }, STEPS).lessons
		expect.equal(lessons.forge, true)
		expect.equal(lessons.jobs, false, "a lesson waiting to be shown (false) is kept")
		expect.equal(lessons.bad, nil)
		expect.equal(TutorialRules.read({ pishLuckAt = -5 }, STEPS).pishLuckAt, 0)
	end,

	["gifts once: firstGiven and giftClaimed survive replay"] = function()
		local saved = TutorialRules.read({ firstVisit = "skipped", step = 6, firstGiven = true, giftClaimed = true, early = { bye = true } }, STEPS)
		local again = TutorialRules.replay(saved)
		expect.equal(again.firstVisit, "todo")
		expect.equal(again.step, 1)
		expect.equal(again.firstGiven, true)
		expect.equal(again.giftClaimed, true)
		expect.equal(next(again.early), nil, "early steps cleared")
	end,

	["skip and finish end it; nothing advances unless todo"] = function()
		local saved = TutorialRules.read({ firstVisit = "todo", step = 3 }, STEPS)
		local skipped = TutorialRules.skip(saved)
		expect.equal(skipped.firstVisit, "skipped")
		expect.equal(skipped.step, 3, "the step it was skipped at stays (for the funnel)")
		expect.equal(TutorialRules.current(skipped, STEPS), nil)
		local after, done = TutorialRules.record(skipped, STEPS, "buildRack")
		expect.equal(after.step, 3)
		same(done, {}, "nothing")
		local finished = TutorialRules.finish(saved)
		expect.equal(finished.firstVisit, "done")
		expect.equal(TutorialRules.current(finished, STEPS), nil)
	end,

	["record doesn't change the state it was given"] = function()
		local saved = TutorialRules.read({}, STEPS)
		TutorialRules.record(saved, STEPS, "giftPack")
		expect.equal(saved.step, 1)
	end,
}
