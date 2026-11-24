--!strict
-- Pish talks the player through the first visit (spec 2026-11-09-tutorial-pish-design 14): a few lines per step, then
-- the line for what to do now, by situation; one line per lesson and nudge
local Pish = require("../src/shared/Config/Pish")
local PishTalk = require("../src/shared/Config/PishTalk")
local Game = require("../src/shared/Config/Game")
local Jobs = require("../src/shared/Config/Jobs")
local TalkRules = require("../src/shared/Util/TalkRules")
local ChikinTalk = require("../src/shared/Config/ChikinTalk")
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

	["Customers love choice: Pish names the product, then why variety pays"] = function()
		local lines = PishTalk.AFTER.variety
		assert(lines and #lines == 4, "four lines")
		expect.equal(TalkRules.product(lines[1], "Card Sleeves"), "That customer wanted Card Sleeves!")
		expect.equal(TalkRules.product("No {product}", "100%"), "No 100%", "a name is never read as a pattern")
		for _, text in lines do
			assert(utf8.len(TalkRules.product(text, "Frontier Packs")) :: number <= MAX_LENGTH, text)
		end
		assert(string.find(lines[3], "10%", 1, true), "the bonus")
		expect.equal(TalkRules.product(PishTalk.LESSONS.variety, "Deck Boxes"), "That customer wanted Deck Boxes!")
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
		expect.equal(TalkRules.fill(intro[2], Game.NAME), "Welcome to One More Pack!", "the name decided 2026-11-13")
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
		for _, situation in { "default", "trayOpen", "tab", "tile", "placing", "computer", "orderOpen", "orderCart", "closeWindow" } do
			assert(PishTalk.TEACH[situation], `a line for {situation}`)
		end
		expect.equal(string.format(PishTalk.TEACH.tile, "Wall Shelf"), "Tap the Wall Shelf!")
		-- the order computer's cart (owner 2026-11-21): the product into the cart, then Order now
		expect.equal(string.format(PishTalk.TEACH.orderOpen, "Card Sleeves"), "Add Card Sleeves to your cart!")
		expect.equal(PishTalk.TEACH.orderCart, "Now tap Order now!")
		expect.equal(PishTalk.STEPS.orderStock.now.orderOpen, "Add First Spark packs to your cart!")
		expect.equal(PishTalk.STEPS.orderStock.now.orderCart, "Now tap Order now!")
		expect.equal(PishTalk.TEACH.closeWindow, PishTalk.LABELS.close)
	end,
	-- Owner 2026-11-17: trophies are placed from the Bag (its Place button), so the trophy lesson walks there: the Bag,
	-- the trophy's slot, Place, then the floor
	["the trophy lesson walks through the Bag: the Bag, the trophy, Place"] = function()
		expect.equal(PishTalk.TEACH.bag, "Tap your Bag.")
		expect.equal(string.format(PishTalk.TEACH.tile, "Meadow Warden Trophy"), "Tap the Meadow Warden Trophy!")
		expect.equal(PishTalk.TEACH.bagPlace, "Tap Place!")
		assert(PishTalk.TEACH.placing, "then the floor")
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

	-- Owner 2026-11-16: "let pish teach players how to set prices through shelves or the prices tile"
	["right after his tour Pish points at Prices, then says how pricing works inside it"] = function()
		local prices
		for _, lesson in Pish.LESSONS do
			if lesson.id == "prices" then
				prices = lesson
			end
		end
		assert(prices and (prices :: any).trigger == "tourDone", "queued when the tour ends")
		assert(PishTalk.LESSONS.prices, "his line pointing at the tile")
		local lines = PishTalk.AFTER.prices
		assert(lines and #lines >= 2, "what to do inside the window")
		assert(string.find(lines[1], "+", 1, true) and string.find(lines[1], "-", 1, true), "the + and - buttons")
	end,

	-- Owner 2026-11-21: "The moment player unlock jobs. pish will introduce it to them": he points at Jobs on the Phone,
	-- then, with the window open, says what a job is, the two jobs and what it costs you (a working card can't fight)
	["Pish introduces jobs: where they are, then what they do inside the window"] = function()
		local line = PishTalk.LESSONS.jobs
		assert(string.find(line, "Jobs", 1, true) and string.find(line, "Phone", 1, true), "where to tap")
		local lines = PishTalk.AFTER.jobs
		assert(lines and #lines >= 3, "an introduction, not one line")
		local all = table.concat(lines, " ")
		for _, job in Jobs.JOBS do
			assert(string.find(string.lower(all), string.lower(job), 1, true), `he names the {job}`)
		end
		assert(string.find(all, "fight", 1, true), "a working card can't fight")
		for _, text in lines do
			assert(utf8.len(text) :: number <= MAX_LENGTH, text)
		end
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

	-- seen 2026-11-20 on Pish's first sale: at the top centre his card lay on the register's screen (what to give
	-- back), and at the bottom it would lie on the cash drawer. At the register it stands at the left side
	["at the register the talk card stands aside: the screen and the drawer stay clear"] = function()
		local TOP, HEIGHT, PAW = 66, 112, 82
		expect.equal(TalkRules.cardPlace(TOP, HEIGHT, PAW, nil, false, true), "side", "manning the register")
		expect.equal(TalkRules.cardPlace(TOP, HEIGHT, PAW, { top = 120, low = 170, across = true }, false, true), "side")
		expect.equal(TalkRules.cardPlace(TOP, HEIGHT, PAW, nil, false, false), "top", "anywhere else: as before")
		expect.equal(TalkRules.cardPlace(TOP, HEIGHT, PAW, { top = 120, low = 170, across = true }, false, false), "bottom")
		expect.equal(TalkRules.cardPlace(TOP, HEIGHT, PAW, nil, true, false), "top", "a fight")
	end,

	-- owner 2026-11-20: "My friend says tutorial is hard to notice. fix it too. and people hardly press next on
	-- tutorial"
	["Next presses itself once there has been time to read the line"] = function()
		local auto = PishTalk.AUTO_NEXT
		expect.equal(TalkRules.readSeconds(0, auto), auto.min)
		expect.equal(TalkRules.readSeconds(13, auto), math.max(auto.min, auto.base + 13 * auto.perLetter), "Hi! I'm Pish!")
		expect.equal(TalkRules.readSeconds(1000, auto), auto.max)
		assert(TalkRules.readSeconds(60, auto) > TalkRules.readSeconds(20, auto), "a longer line stays longer")
		assert(auto.min >= 2.5, "never a flash")
		assert(auto.max <= 8, "never a long wait")
		-- a child reads about two words a second: every intro line gets that
		eachLine(function(where, text)
			local words = select(2, string.gsub(text, "%S+", ""))
			assert(TalkRules.readSeconds(utf8.len(text) :: number, auto) >= math.min(auto.max, words / 2), where)
		end)
	end,

	["only a plain Next presses itself: Got it!, Bye! and Go! wait for the player"] = function()
		expect.equal(TalkRules.pressesItself(PishTalk.NEXT, PishTalk.NEXT, false), true)
		expect.equal(TalkRules.pressesItself(PishTalk.BYE, PishTalk.NEXT, false), false)
		expect.equal(TalkRules.pressesItself(PishTalk.GOT_IT, PishTalk.NEXT, true), false)
		expect.equal(TalkRules.pressesItself(PishTalk.NEXT, PishTalk.NEXT, true), false)
		expect.equal(TalkRules.pressesItself(nil, PishTalk.NEXT, false), false, "no button: the line stays")
		expect.equal(ChikinTalk.NEXT, PishTalk.NEXT, "Chikin's Next is the same button")
	end,

	["the talk card is bigger on a computer; a phone keeps its small one"] = function()
		local card = PishTalk.CARD
		assert(card.DESKTOP >= 1.2, "clearly bigger")
		expect.equal(TalkRules.cardGrow(true, 1, card), 1, "a phone's screen is crowded (owner 2026-11-11)")
		expect.equal(TalkRules.cardGrow(true, 1.35, card), 1)
		expect.equal(TalkRules.cardGrow(false, 1, card), card.DESKTOP)
		expect.equal(TalkRules.cardGrow(false, 1.35, card), 1.35 * card.DESKTOP, "on top of the HUD's own growth")
	end,

	["a new line flashes the card's edge gold, then leaves it alone"] = function()
		local glow = PishTalk.CARD.GLOW
		expect.equal(TalkRules.glow(0, glow), 0, "full gold at once")
		expect.equal(TalkRules.glow(glow.seconds, glow), 1, "gone")
		expect.equal(TalkRules.glow(glow.seconds + 5, glow), 1)
		local dips = 0
		local last = 0
		for i = 0, 100 do
			local see = TalkRules.glow(glow.seconds * i / 100, glow)
			assert(see >= 0 and see <= 1, "a transparency")
			if see < last - 0.001 and last > 0.9 then
				dips += 1
			end
			last = see
		end
		assert(dips >= 1, "it comes back at least once: a flash, not a fade")
		assert(glow.seconds <= 2.5, "short")
		assert(PishTalk.CARD.SOUND.volume <= 0.3, "a soft sound")
	end,

	-- owner 2026-11-20: "Chikin tutorial sometimes the NEXT is not clickable": his last Next was sent once and never
	-- again, so a request the server dropped left the button dead
	["a Next the server didn't answer is sent again after a moment, never in a burst"] = function()
		local Chikin = require("../src/shared/Config/Chikin")
		local wait = Chikin.RESEND_SECONDS
		expect.equal(TalkRules.maySend(-math.huge, 100, wait), true, "the first press")
		expect.equal(TalkRules.maySend(100, 100.2, wait), false, "a double tap")
		expect.equal(TalkRules.maySend(100, 100 + wait, wait), true, "still no answer: again")
		assert(wait > 0.5, "longer than the server's cooldown (0.5 s), or the second is dropped too")
		assert(wait <= 3, "not a long dead button")
	end,
}
