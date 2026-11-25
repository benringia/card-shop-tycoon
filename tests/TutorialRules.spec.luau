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

local function facts(over: { [string]: boolean }): any
	local base = { firstPackHeld = false, giftHeld = false, ownsRack = false, shelvesStocked = false }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	-- Owner 2026-11-17 (playthrough): "When the player opens their first card. Pish will then ask the player to summon
	-- them. then the party UI and everything else should be displayed."
	["after his present Pish asks you to summon your pal: the party shows for it, then the whole HUD"] = function()
		expect.equal(STEPS[1], "giftPack", "his present first")
		expect.equal(STEPS[2], "summonPal", "then summon the pal it gave you")
		expect.equal(STEPS[3], "buildRack", "then the shop")
		assert(UIIcons[Pish.STEP_ICONS.summonPal] or Pish.STEP_ICONS.summonPal, "an icon over his head")
		local function focus(step: string, inTown: boolean): string
			local keep = TutorialRules.pishFocus(step, inTown, Pish)
			return if keep then table.concat(keep, ",") else "none"
		end
		expect.equal(focus("giftPack", true), "", "his present: the calm HUD")
		expect.equal(focus("summonPal", true), "party", "the summon: the party shows")
		expect.equal(focus("buildRack", true), "none", "after it: everything shows")
		expect.equal(focus("ringUp", true), "none", "for the rest of the tour")
		expect.equal(focus("bye", true), "none", "his goodbye")
		expect.equal(focus("giftPack", false), "none", "out of town the whole HUD")
		expect.equal(focus("", true), "none", "no tour")
		local fresh = TutorialRules.read({ firstVisit = "todo", step = 2 }, STEPS)
		expect.equal(TutorialRules.doneAlready(fresh, "summonPal", facts({ summoned = true })), true, "already out: done")
		expect.equal(TutorialRules.doneAlready(fresh, "summonPal", facts({})), false, "not out yet: summon it")
	end,

	-- Owner 2026-11-16 (playthrough): "Customers should only start coming when Pish introduces them": a new player's
	-- shop stays quiet until Pish sends his own customer (once ever); a skipped, finished or replayed tour never waits
	-- (a replay gets no customer from him, so the shop's own complete his step)
	-- Owner 2026-11-17 ("what can we do to make the first 10-15mins really fun"): no dead wait in Pish's tour, his first
	-- order arrives at once instead of the usual delivery time
	["the tour's first order arrives at once"] = function()
		-- Config/Stock holds a Vector3, so Lune reads its text
		local source = require("@lune/fs").readFile("src/shared/Config/Stock.luau")
		local tour = tonumber(string.match(source, "TOUR_DELIVERY_SECONDS = ([%d%.]+)"))
		local usual = tonumber(string.match(source, "%sDELIVERY_SECONDS = ([%d%.]+)"))
		assert(tour and tour <= 1, "the tour's delivery is instant")
		assert(usual and tour < usual, "faster than a normal one")
		local PishTalk = require("../src/shared/Config/PishTalk")
		assert(not string.find(PishTalk.STEPS.stockRack.now.coming, "take a bit", 1, true), "Pish doesn't say it takes a while")
	end,

	["customers wait for Pish until he sends his own"] = function()
		local fresh = TutorialRules.read({}, STEPS)
		expect.equal(TutorialRules.holdsCustomers(fresh), true, "a new player")
		expect.equal(TutorialRules.holdsCustomers(TutorialRules.customerSent(fresh)), false, "he sent his customer")
		expect.equal(TutorialRules.holdsCustomers(TutorialRules.skip(fresh)), false, "skipped")
		expect.equal(TutorialRules.holdsCustomers(TutorialRules.read({ firstVisit = "done" }, STEPS)), false, "done")
		local replay = TutorialRules.replay(TutorialRules.customerSent(TutorialRules.read({ firstVisit = "done" }, STEPS)))
		expect.equal(TutorialRules.holdsCustomers(replay), false, "a replay: his customer was sent long ago")
	end,

	["doneAlready: a replay passes the gift steps whose gift was given and opened (final review C1)"] = function()
		local migrated = TutorialRules.read({ firstVisit = "done", firstGiven = true, giftClaimed = false }, STEPS)
		expect.equal(TutorialRules.doneAlready(migrated, "giftPack", facts({})), true, "an old save: his pack long opened")
		expect.equal(TutorialRules.doneAlready(migrated, "giftPack", facts({ firstPackHeld = true })), false, "still in the Bag: open it")
		expect.equal(TutorialRules.doneAlready(migrated, "gift", facts({})), false, "his gift still to come")
		local finished = TutorialRules.read({ firstVisit = "done", firstGiven = true, giftClaimed = true }, STEPS)
		expect.equal(TutorialRules.doneAlready(finished, "gift", facts({})), true, "given and opened before")
		expect.equal(TutorialRules.doneAlready(finished, "gift", facts({ giftHeld = true })), false, "given, not opened yet")
		local fresh = TutorialRules.read({}, STEPS)
		expect.equal(TutorialRules.doneAlready(fresh, "giftPack", facts({})), false, "a new player: his pack comes now")
	end,

	["doneAlready: a rack owned or shelves stocked count; the rest never pass by themselves"] = function()
		local saved = TutorialRules.read({ firstVisit = "done", firstGiven = true, giftClaimed = true }, STEPS)
		expect.equal(TutorialRules.doneAlready(saved, "buildRack", facts({ ownsRack = true })), true)
		expect.equal(TutorialRules.doneAlready(saved, "buildRack", facts({})), false)
		expect.equal(TutorialRules.doneAlready(saved, "stockRack", facts({ shelvesStocked = true })), true)
		for _, step in { "orderStock", "customer", "ringUp", "bye" } do
			expect.equal(TutorialRules.doneAlready(saved, step, facts({ ownsRack = true, shelvesStocked = true })), false, step)
		end
	end,

	["the steps are the spec's eight and the summon after his present (owner 2026-11-17), in order"] = function()
		same(STEPS, { "giftPack", "summonPal", "buildRack", "orderStock", "stockRack", "customer", "ringUp", "gift", "bye" }, "steps")
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
		expect.equal(TutorialRules.current(saved, STEPS), "summonPal")
	end,

	["early events wait their turn"] = function()
		local saved = TutorialRules.read({ firstVisit = "todo", step = 3 }, STEPS)
		local done
		saved, done = TutorialRules.record(saved, STEPS, "orderStock")
		expect.equal(saved.step, 3, "ordering before building doesn't skip building")
		expect.equal(saved.early.orderStock, true)
		same(done, {}, "nothing completed yet")
		saved, done = TutorialRules.record(saved, STEPS, "buildRack")
		expect.equal(saved.step, 5, "building completes, then the order counts")
		same(done, { "buildRack", "orderStock" }, "both completed, in order")
		saved, done = TutorialRules.record(saved, STEPS, "ringUp")
		expect.equal(saved.step, 5, "a sale before stocking waits too")
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
	["sendsCustomer: Pish's own customer comes once ever, whatever is skipped or replayed (final review I1)"] = function()
		local fresh = TutorialRules.read({}, STEPS)
		expect.equal(TutorialRules.sendsCustomer(fresh), true, "a new player")
		local sent = TutorialRules.customerSent(fresh)
		expect.equal(fresh.customerSent, false, "a copy: the state passed in is unchanged")
		expect.equal(TutorialRules.sendsCustomer(sent), false, "sent once")
		local again = TutorialRules.replay(TutorialRules.skip(sent))
		expect.equal(TutorialRules.sendsCustomer(again), false, "skip and replay: never again")
		expect.equal(TutorialRules.read({ customerSent = true }, STEPS).customerSent, true, "saved")
		expect.equal(TutorialRules.read({ customerSent = "yes" }, STEPS).customerSent, false, "junk reads as not sent")
	end,

	-- The owner 2026-11-11: "hide the title and creature tag only on tutorial" (on your own screen)
	["a tour leads while Pish's step or Chikin's (not his wait) is on"] = function()
		expect.equal(TutorialRules.tourLeading("", "", "level4"), false, "no tour")
		expect.equal(TutorialRules.tourLeading("shop", "", "level4"), true, "Pish's tour")
		expect.equal(TutorialRules.tourLeading("bye", "", "level4"), true, "his goodbye too")
		expect.equal(TutorialRules.tourLeading("", "party", "level4"), true, "Chikin's tour")
		expect.equal(TutorialRules.tourLeading("", "level4", "level4"), false, "Chikin's wait for shop level 4")
	end,

	-- the owner 2026-11-18: "on the delivery tutorial. pish is saying put the box on the rack while highlighting the
	-- 'To bag' tile. fix it"
	["the tour's packs go on the rack: no To Bag on that step, and its tip waits until the tour is over"] = function()
		assert(table.find(STEPS, TutorialRules.STOCK_STEP) ~= nil, "the stock step is one of Pish's steps")
		expect.equal(TutorialRules.offersToBag(TutorialRules.STOCK_STEP), false, "Pish says the rack: To Bag hides (it lit up over his line)")
		expect.equal(TutorialRules.offersToBag(""), true, "after the tour: To Bag")
		expect.equal(TutorialRules.offersToBag("customer"), true, "a later step: To Bag")
		expect.equal(TutorialRules.tipWaits(TutorialRules.STOCK_STEP), true, "no To Bag tip mid-tour (Pish's face saying the opposite of Pish)")
		expect.equal(TutorialRules.tipWaits("ringUp"), true, "nor anywhere else in the tour")
		expect.equal(TutorialRules.tipWaits(""), false, "after the tour: the tip's three shows, none spent")
	end,

	-- 2026-11-25 (spec 2026-11-25-pish-first-steps-design 4): the tour talked to you on the sidewalk and the rack's
	-- preview started off screen; outside, the rack step leads you in first. `out`: studs from the floor's centre toward
	-- the street; a 50 x 60 shop, its front edge 30 studs out; the wake spot stood 38 out
	["inside the shop: within its sides and back, 3 studs past the front edge"] = function()
		local W, D, M = 50, 60, Pish.INSIDE.margin
		expect.equal(M, 3)
		expect.equal(TutorialRules.insideShop(38, 0, W, D, M), false, "the wake spot on the sidewalk")
		expect.equal(TutorialRules.insideShop(28, 0, W, D, M), false, "in the doorway")
		expect.equal(TutorialRules.insideShop(27, 0, W, D, M), true, "3 studs in")
		expect.equal(TutorialRules.insideShop(0, 26, W, D, M), false, "past the side wall")
		expect.equal(TutorialRules.insideShop(-31, 0, W, D, M), false, "behind the back wall")
		expect.equal(TutorialRules.insideShop(-20, -20, W, D, M), true, "the back corner")
	end,
}
