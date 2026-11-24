--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8): which lessons a level-up brings,
-- and when Pish comes to point at what to do next
local LessonRules = require("../src/shared/Util/LessonRules")
local Pish = require("../src/shared/Config/Pish")
local Products = require("../src/shared/Config/Products")
local Jobs = require("../src/shared/Config/Jobs")
local PishTalk = require("../src/shared/Config/PishTalk")
local expect = require("./lib/expect")

-- Config/Shelves holds Vector3s, so Lune reads its text: each entry's id, kind and unlock level
local function shelves(): { { id: string, kind: string, unlockLevel: number } }
	local source = require("@lune/fs").readFile("src/shared/Config/Shelves.luau")
	local starts = {}
	for position, id in string.gmatch(source, '()id = "([%w_]+)"') do
		table.insert(starts, { position = position :: number, id = id })
	end
	local found = {}
	for index, start in starts do
		local finish = if starts[index + 1] then starts[index + 1].position - 1 else #source
		local body = string.sub(source, start.position, finish)
		local kind = string.match(body, 'kind = "([%w_]+)"') :: string
		local level = tonumber(string.match(body, "unlockLevel = (%d+)")) :: number
		table.insert(found, { id = start.id, kind = kind, unlockLevel = level })
	end
	return found
end

local function lessonWhere(field: string, value: string): any
	for _, lesson in Pish.LESSONS do
		if (lesson :: any)[field] == value then
			return lesson
		end
	end
	return nil
end

local function same(a: { string }, b: { string }, what: string)
	expect.equal(#a, #b, `{what}: count`)
	for i = 1, #b do
		expect.equal(a[i], b[i], `{what}: #{i}`)
	end
end

local function facts(over: { [string]: any }): any
	local base = { played = 300, quiet = 70, sinceNudge = 200, boxWaiting = false, shelvesStocked = true, canOrder = true, muted = false }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	-- Owner 2026-11-16: "where pish is telling players to buy glass case, pish should only tell players when the player
	-- have enough money to buy it": a lesson that has you buy something waits (keeping its place) until you can afford
	-- it; the next affordable one comes first; a lesson that buys nothing never waits
	["a lesson that has you buy something waits until you can afford it"] = function()
		local lessons = {
			{ id = "case", level = 2, icon = "Cases", shelf = "Case" },
			{ id = "jobs", level = 3, icon = "Jobs" },
			{ id = "sleeves", level = 3, icon = "Sleeves", product = "Sleeves" },
		}
		local prices = { Case = 120, Sleeves = 30 }
		local function cost(lesson: any): number
			return prices[lesson.shelf or lesson.product or ""] or 0
		end
		expect.equal(LessonRules.firstReady({ "case", "jobs" }, lessons, 50, cost), "jobs", "the case waits")
		expect.equal(LessonRules.firstReady({ "case", "jobs" }, lessons, 120, cost), "case", "affordable: in order")
		expect.equal(LessonRules.firstReady({ "case", "sleeves" }, lessons, 40, cost), "sleeves")
		expect.isNil(LessonRules.firstReady({ "case" }, lessons, 10, cost), "nothing ready")
		expect.isNil(LessonRules.firstReady({}, lessons, 999, cost))
	end,

	-- Owner 2026-11-19 ("so we should adjust the tutorial to not based on levels? whats the best move here", then "A and
	-- B now"): Pish no longer runs in at a level-up for every unlock. Plain things (shelves, racks, decor, new stock) get
	-- no visit: the main quest strip and a NEW tag on their tile carry them. A machine or a card case is explained the
	-- first time it's placed. Only what you can't place still comes at its level: the sword and jobs
	["what Pish still teaches: systems only, each at its first use"] = function()
		local by = {}
		for _, lesson in Pish.LESSONS do
			by[lesson.id] = lesson
		end
		for _, gone in { "decor", "sleeves", "wallShelf", "expand", "accessoryHook", "bigRack", "boosterBox" } do
			expect.isNil(by[gone], `{gone}: no visit for a plain shelf or new stock`)
			expect.isNil(PishTalk.LESSONS[gone], `{gone}: no line kept for it`)
		end
		for _, id in { "showcase", "collectorCase", "condenser", "forge", "bulkBin", "grading" } do
			assert(by[id], `{id} is still taught`)
			expect.equal(by[id].on, "placed", `{id}: explained the first time it's placed`)
			assert(by[id].shelf, `{id}: its shelf`)
			assert(PishTalk.AFTER[id] and #PishTalk.AFTER[id] >= 2, `{id}: what it's for, said beside it`)
		end
		expect.equal(by.sword.level, 4)
		expect.isNil(by.sword.on, "the sword is handed over at its level: taught then")
		expect.equal(by.jobs.level, Jobs.UNLOCK_LEVEL, "jobs at their unlock (nothing to place)")
		assert(by.trophy.trigger == "trophy" and by.titles.trigger == "title" and by.prices.trigger == "tourDone", "the event lessons as before")
		expect.equal(#Pish.LESSONS, 16, "sixteen lessons (the healing spring's came on launch day, the Recycler's the day after, the two shop rooms' with the rooms, the storage rack's with racks)")
	end,

	["due: a level-up only brings what's taught at its level, never a first-use lesson"] = function()
		same(LessonRules.due(Pish.LESSONS, 1, 3, {}), {}, "levels 2 and 3: nobody runs in")
		same(LessonRules.due(Pish.LESSONS, 3, 4, {}), { "sword" }, "the sword, with the sword")
		same(LessonRules.due(Pish.LESSONS, 4, 7, {}), {}, "the condenser and the forge wait to be placed")
		same(LessonRules.due(Pish.LESSONS, 7, 8, {}), { "jobs" })
		same(LessonRules.due(Pish.LESSONS, 1, 20, {}), { "sword", "jobs", "recycler", "backRoom" }, "the whole way up: four visits by level")
		same(LessonRules.due(Pish.LESSONS, 1, 20, { sword = true, jobs = false, recycler = true, backRoom = true }), {}, "seen or waiting already")
		same(LessonRules.due(Pish.LESSONS, 20, 30, {}), { "gallery" }, "the Gallery at its level")
		same(LessonRules.due(Pish.LESSONS, 20, 20, {}), {}, "an old save loading at 20 gets none")
	end,

	["onPlaced: a machine or a case is explained the first time it's placed, once"] = function()
		expect.equal(LessonRules.onPlaced(Pish.LESSONS, "Forge", "Forge", {}), "forge")
		expect.equal(LessonRules.onPlaced(Pish.LESSONS, "GlassShowcase", "CustomerCards", {}), "showcase")
		expect.isNil(LessonRules.onPlaced(Pish.LESSONS, "Forge", "Forge", { forge = true }), "explained before")
		expect.isNil(LessonRules.onPlaced(Pish.LESSONS, "Forge", "Forge", { forge = false }), "waiting already: a second one changes nothing")
		expect.isNil(LessonRules.onPlaced(Pish.LESSONS, "WallShelf", "Products", {}), "a plain shelf: no visit")
		expect.isNil(LessonRules.onPlaced(Pish.LESSONS, "trophy_meadowWarden", "Trophy", {}), "the trophy keeps its own lesson")
		-- storage racks (spec 2026-11-24-storage-racks-design): explained beside the first one placed, old saves too
		expect.equal(LessonRules.onPlaced(Pish.LESSONS, "StorageRack", "Storage", {}), "storageRack")
	end,

	["a first-use lesson never waits for cash (it's bought already); the others as before"] = function()
		local by = {}
		for _, lesson in Pish.LESSONS do
			by[lesson.id] = lesson
		end
		expect.equal(LessonRules.buys(by.forge), false, "placed: nothing left to pay")
		expect.equal(LessonRules.buys(by.showcase), false)
		expect.equal(LessonRules.buys(by.jobs), false, "nothing to buy")
		expect.equal(LessonRules.buys({ id = "x", icon = "x", shelf = "Case" }), true, "a lesson that walks you to buy a shelf")
		expect.equal(LessonRules.buys({ id = "x", icon = "x", product = "Sleeves" }), true)
	end,

	["pending: the lessons waiting to be shown, known ones in level order"] = function()
		local saved = { jobs = false, trophy = false, showcase = false, forge = true, nope = false, sleeves = false }
		same(LessonRules.pending(Pish.LESSONS, saved), { "showcase", "jobs", "trophy" }, "waiting (an event lesson last; a lesson we dropped is left out)")
		same(LessonRules.pending(Pish.LESSONS, {}), {}, "none")
	end,

	["nudge: stock a waiting box, else order"] = function()
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true })), "stock")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ shelvesStocked = false })), "order")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({})), nil, "stocked, nothing waiting: customers will come")
	end,

	-- the owner 2026-11-18: "Pish is forcing players to buy items that the player cant afford yet. maybe add close or 'ill
	-- keep that in mind' that will make pish go away. or 'dont remind me again'"
	["nudge: never to order packs you can't pay for, and never again once told Got it"] = function()
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ shelvesStocked = false, canOrder = false })), nil, "empty shelves, no cash for a box: no nagging")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, canOrder = false })), "stock", "a box already here costs nothing to stock")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ shelvesStocked = false, muted = true })), nil, "Got it: he stops coming")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, muted = true })), nil, "for any nudge")
	end,

	["cheapestBox: the least a box to order costs at a shop level (never the Bulk Bin's handfuls)"] = function()
		expect.equal(LessonRules.cheapestBox(Products.List, 1), Products.ById.FirstSparkPack.boxCost, "level 1: First Spark packs")
		expect.equal(LessonRules.cheapestBox(Products.List, 12), Products.ById.CardSleeves.boxCost, "sleeves once unlocked")
		expect.equal(LessonRules.cheapestBox({}, 1), nil, "nothing to order")
	end,

	["nudge: never too soon, too often or after the first hour"] = function()
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, quiet = 30 })), nil, "busy a moment ago")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, sinceNudge = 60 })), nil, "nudged a minute ago")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, played = 4000 })), nil, "past the first hour")
	end,
	-- Owner 2026-11-21: "when recycler is in game, pish will introduce it to old players and add it to tutorial for
	-- new players": a new player gets its lesson on reaching its level like any level lesson; a save already past that
	-- level gets it at its next join (`late`), once. Other lessons never come for what was unlocked before
	["a thing added after launch: Pish brings its lesson to players already past its level"] = function()
		local recycler = lessonWhere("shelf", "Recycler")
		assert(recycler and recycler.late == true, "the Recycler's lesson is a late one")
		expect.equal(recycler.id, "recycler")
		same(LessonRules.late(Pish.LESSONS, 30, {}), { "recycler", "backRoom", "gallery" }, "an old save at Lv 30")
		same(LessonRules.late(Pish.LESSONS, 15, { recycler = true }), { "backRoom" }, "an old save at Lv 15 that met the Recycler")
		same(LessonRules.late(Pish.LESSONS, 12, {}), { "recycler" }, "at its level")
		same(LessonRules.late(Pish.LESSONS, 11, {}), {}, "not unlocked yet: the level-up brings it")
		same(LessonRules.late(Pish.LESSONS, 30, { recycler = true, backRoom = true, gallery = true }), {}, "seen")
		same(LessonRules.late(Pish.LESSONS, 30, { recycler = false, backRoom = false, gallery = false }), {}, "waiting already")
		-- a new player: the level-up brings it, and Pish walks them to it (a lesson that has them buy it)
		same(LessonRules.due(Pish.LESSONS, 11, 12, {}), { "recycler" })
		expect.equal(LessonRules.buys(recycler), true)
		assert(PishTalk.LESSONS.recycler and PishTalk.AFTER.recycler, "his lines")
	end,

	["every machine and card case is explained on its first placement; plain shelves and stock have no lesson"] = function()
		for _, product in Products.List do
			expect.isNil(lessonWhere("product", product.id), `{product.id}: new stock shows on the order computer, no visit`)
		end
		local trophies, plain = 0, 0
		for _, shelf in shelves() do
			local lesson = lessonWhere("shelf", shelf.id)
			if shelf.kind == "Trophy" then
				trophies += 1
			elseif shelf.kind == "Decor" or (shelf.kind == "Products" and shelf.id ~= "BulkBin") then
				plain += 1
				expect.isNil(lesson, `{shelf.id}: a plain shelf or decor piece, no visit`)
			elseif shelf.kind == "CustomerCards" or shelf.kind == "PlayerCards" then
				assert(lesson and lesson.on == "placed", `{shelf.id}: a card case is explained once placed`)
			elseif lesson and lesson.late then
				-- the Recycler came after launch (owner 2026-11-21): Pish brings it himself, at its level
				expect.isNil(lesson.on, `{shelf.id}: Pish walks you to it`)
				expect.equal(lesson.level, shelf.unlockLevel, `{shelf.id}: at its level`)
			elseif lesson then
				expect.equal(lesson.on, "placed", `{shelf.id}: a machine is explained once placed`)
				expect.equal(lesson.level, shelf.unlockLevel, `{shelf.id}: its level orders the waiting lessons`)
			end
		end
		assert(trophies > 0, "the trophies were read")
		assert(plain > 0, "the plain shelves were read")
		for _, machine in { "Condenser", "Forge", "GradingStation", "BulkBin", "Recycler" } do
			assert(lessonWhere("shelf", machine), `{machine} has its lesson`)
		end
		local trophy = lessonWhere("trigger", "trophy")
		assert(trophy and trophy.level == nil, "the first trophy has an event lesson")
	end,

	-- Owner 2026-11-21 (launch day): "if a player pet dies for the first time, chikin or pish should appear and talk to
	-- them about the healing spring. with an option to skip it ofcourse": Pish's lesson, brought by the first faint, one
	-- line with Got it! (a lesson that teaches nothing step by step), his paws leading to the spring
	["a creature's first faint brings the healing spring's lesson, once"] = function()
		same(LessonRules.byEvent(Pish.LESSONS, "faint", {}), { "spring" }, "the first faint")
		same(LessonRules.byEvent(Pish.LESSONS, "faint", { spring = false }), {}, "already waiting")
		same(LessonRules.byEvent(Pish.LESSONS, "faint", { spring = true }), {}, "seen: never again")
		local spring
		for _, lesson in Pish.LESSONS do
			if lesson.id == "spring" then
				spring = lesson
			end
		end
		assert(spring and spring.level == nil and spring.shelf == nil and spring.on == nil, "an event's lesson: never by level, nothing to place")
		same(LessonRules.due(Pish.LESSONS, 1, 100, {}), LessonRules.due(Pish.LESSONS, 1, 100, { spring = true }), "never due by level")
		local line = PishTalk.LESSONS.spring
		assert(line and string.find(line, "spring", 1, true), "his line names the spring")
		assert(not PishTalk.AFTER.spring, "one line and Got it!: no walkthrough")
	end,

	["byEvent: the trophy lesson until it's been seen or is waiting; never due by level"] = function()
		same(LessonRules.byEvent(Pish.LESSONS, "trophy", {}), { "trophy" }, "the first trophy")
		same(LessonRules.byEvent(Pish.LESSONS, "trophy", { trophy = false }), {}, "already waiting")
		same(LessonRules.byEvent(Pish.LESSONS, "trophy", { trophy = true }), {}, "seen")
		same(LessonRules.byEvent(Pish.LESSONS, "nothing", {}), {}, "no such event")
		for _, id in LessonRules.due(Pish.LESSONS, 0, 100, {}) do
			assert(id ~= "trophy", "the trophy lesson isn't a level's")
		end
	end,

	["forShelf / forProduct: the lesson a placed or ordered thing belongs to"] = function()
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "GlassShowcase", "CustomerCards"), "showcase")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "trophy_meadowWarden", "Trophy"), "trophy", "any trophy")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "WallShelf", "Products"), nil, "a plain shelf has none now")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "SmallPackRack", "Products"), nil, "the first visit's rack")
		expect.equal(LessonRules.forProduct(Pish.LESSONS, "CardSleeves"), nil, "new stock has none now")
		expect.equal(LessonRules.forProduct(Pish.LESSONS, "FirstSparkPack"), nil, "the first visit's packs")
	end,

	["busyWith: the register, boxes, placing, a window, a fight, a show or a popup keep him away (owner 2026-11-18)"] = function()
		local free = { register = false, carrying = false, building = false, window = false, fight = false, show = false, popup = false }
		expect.equal(LessonRules.busyWith(free), nil, "nothing on: free")
		for reason in free do
			local busy = table.clone(free)
			busy[reason] = true
			expect.equal(LessonRules.busyWith(busy), reason, `{reason} alone`)
		end
		local many = table.clone(free)
		many.window, many.register, many.fight = true, true, true
		expect.equal(LessonRules.busyWith(many), "fight", "the biggest thing first")
		local teaching = table.clone(free)
		teaching.window, teaching.building = true, true
		expect.equal(LessonRules.busyWith(teaching, { window = true, building = true }), nil, "a lesson's own windows and placing")
		teaching.register = true
		expect.equal(LessonRules.busyWith(teaching, { window = true, building = true }), "register", "the register still counts")
	end,

	["mayStart: free Pish.PACE.free seconds, and Pish.PACE.gap seconds after his last visit ended"] = function()
		local pace = Pish.PACE
		local now = 1000
		expect.equal(LessonRules.mayStart(now, nil, nil, pace), false, "busy now")
		expect.equal(LessonRules.mayStart(now, now - pace.free + 0.5, nil, pace), false, "free a moment ago")
		expect.equal(LessonRules.mayStart(now, now - pace.free, nil, pace), true, "free long enough, no visit yet")
		expect.equal(LessonRules.mayStart(now, now - 100, now - pace.gap + 1, pace), false, "his last visit just ended")
		expect.equal(LessonRules.mayStart(now, now - 100, now - pace.gap, pace), true, "a breather later")
	end,

	-- Owner 2026-11-21: "The moment player unlock jobs. pish will introduce it to them." The jobs lesson came at its
	-- level but waited its turn: behind lessons queued earlier and Pish's breather after his last visit (PACE.gap),
	-- minutes after the unlock. It now comes first and skips the breather; he still never interrupts (free a moment)
	["the jobs lesson comes the moment jobs unlock: first in line, no breather"] = function()
		local by = {}
		for _, lesson in Pish.LESSONS do
			by[lesson.id] = lesson
		end
		expect.equal((by.jobs :: any).rush, true, "jobs rush")
		expect.equal(LessonRules.rushes(Pish.LESSONS, "jobs"), true)
		expect.equal(LessonRules.rushes(Pish.LESSONS, "forge"), false)
		expect.equal(LessonRules.rushes(Pish.LESSONS, "nope"), false, "an unknown lesson")
		same(LessonRules.rushFirst({ "showcase", "forge", "jobs", "trophy" }, Pish.LESSONS), { "jobs", "showcase", "forge", "trophy" }, "first in line, the rest in their order")
		same(LessonRules.rushFirst({ "showcase", "forge" }, Pish.LESSONS), { "showcase", "forge" }, "none rushing: as it was")
		same(LessonRules.rushFirst({}, Pish.LESSONS), {}, "nothing waiting")
		local pace = Pish.PACE
		local now = 1000
		expect.equal(LessonRules.mayStart(now, now - 100, now - 5, pace, true), true, "his last visit just ended: he comes anyway")
		expect.equal(LessonRules.mayStart(now, now - 100, now - 5, pace, false), false, "any other lesson waits the breather")
		expect.equal(LessonRules.mayStart(now, nil, nil, pace, true), false, "never while they're busy (the level-up card, a fight)")
		expect.equal(LessonRules.mayStart(now, now - pace.free + 0.5, nil, pace, true), false, "free a moment first")
	end,

	-- ...and an introduction isn't gone in 20 seconds: a lesson with words for inside its window (jobs, prices) waits
	-- longer for the tap than one that only points
	["a lesson with an introduction waits longer for the tap than one that only points"] = function()
		expect.equal(LessonRules.pointSeconds(false, Pish), Pish.LESSON_SECONDS)
		expect.equal(LessonRules.pointSeconds(true, Pish), Pish.INTRO_SECONDS)
		assert(Pish.INTRO_SECONDS >= Pish.LESSON_SECONDS * 2, "time to read, find the Phone and tap")
		assert(Pish.INTRO_SECONDS <= 60, "but he doesn't stand there for minutes")
	end,

	["whileBusy: a visit carries on, steps back while they're busy, and leaves past Pish.PACE.wait"] = function()
		local pace = Pish.PACE
		local now = 1000
		expect.equal(LessonRules.whileBusy(now, nil, pace), "on", "not busy")
		expect.equal(LessonRules.whileBusy(now, now - 1, pace), "pause", "busy a moment: he steps back")
		expect.equal(LessonRules.whileBusy(now, now - pace.wait, pace), "leave", "busy a while: he goes, the lesson waits")
	end,

	["the pacing: a few seconds free, a breather between visits, a short wait before he leaves"] = function()
		local pace = Pish.PACE
		assert(pace.free >= 3 and pace.free <= 8, "a few seconds free first")
		assert(pace.gap >= 30, "never back to back")
		-- Final tutorial check (owner 2026-11-19: "make sure the tutorial are not annoying. only appears at the right
		-- time"): at 45 s apart he was back within a minute, again and again. A real breather between visits (and since
		-- the same day only systems are taught, at first use: "what Pish still teaches")
		assert(pace.gap >= 90, `a real breather between visits ({pace.gap} s)`)
		assert(pace.wait >= 5 and pace.wait < Pish.LESSON_SECONDS, "he doesn't hang about while they're busy")
	end,

	["used: placing or ordering a lesson's thing marks it seen, even before its level (final review I3)"] = function()
		local seen = { showcase = false }
		local after = LessonRules.used(seen, "showcase")
		expect.equal(after.showcase, true, "a waiting lesson is done")
		expect.equal(seen.showcase, false, "a copy")
		expect.equal(LessonRules.used({}, "collectorCase").collectorCase, true, "placed at level 1: never taught later")
		expect.isNil(LessonRules.onPlaced(Pish.LESSONS, "GlassShowcase", "CustomerCards", LessonRules.used({}, "showcase")), "seen: never explained again")
	end,
}
