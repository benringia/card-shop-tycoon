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

	["the spec's lessons and levels"] = function()
		local levels = {}
		for _, lesson in Pish.LESSONS do
			levels[lesson.id] = lesson.level
		end
		expect.equal(levels.showcase, 2)
		expect.equal(levels.sleeves, 3)
		expect.equal(levels.collectorCase, 3)
		expect.equal(levels.sword, 4)
		expect.equal(levels.wallShelf, 4)
		expect.equal(levels.accessoryHook, 7)
		expect.equal(levels.bigRack, 9)
		expect.equal(levels.condenser, 5)
		expect.equal(levels.forge, 6)
		expect.equal(levels.expand, 7)
		expect.equal(levels.boosterBox, 11)
		expect.equal(levels.grading, 14)
		expect.equal(levels.jobs, 8) -- owner 2026-11-17: the cashier earlier (was 20)
	end,

	-- Shop decor (spec 2026-11-14-shop-decor-design): one lesson for the Decor tab, at level 2 (a level-1 lesson
	-- never comes: lessons arrive with a level-up)
	["the decor lesson comes at level 2 and points at the Potted Plant"] = function()
		local due = LessonRules.due(Pish.LESSONS, 1, 2, {})
		assert(table.find(due, "decor"), "the level 1 to 2 level-up brings the decor lesson")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "PottedPlant", "Decor"), "decor")
		assert(PishTalk.LESSONS.decor, "Pish says what decor is")
		assert(PishTalk.AFTER.decor, "and what it's for once placed")
	end,

	["due: only levels crossed now, in level order, not seen"] = function()
		same(
			LessonRules.due(Pish.LESSONS, 2, 6, {}),
			{ "sleeves", "collectorCase", "sword", "wallShelf", "condenser", "forge" },
			"2 to 6 (one level's lessons in the order Config/Pish lists them)"
		)
		same(LessonRules.due(Pish.LESSONS, 6, 7, { expand = true, accessoryHook = true }), {}, "seen")
		same(LessonRules.due(Pish.LESSONS, 20, 20, {}), {}, "an old save loading at 20 gets none")
		same(LessonRules.due(Pish.LESSONS, 3, 4, {}), { "sword", "wallShelf" }, "the level gained, not the one left")
		same(LessonRules.due(Pish.LESSONS, 1, 2, {}), { "showcase", "decor" }, "the Glass Showcase right after his first visit, then decor")
	end,

	["due: leaves out lessons already waiting (false) as well as seen"] = function()
		same(LessonRules.due(Pish.LESSONS, 6, 7, { expand = false }), { "accessoryHook" }, "queued in the Frontier")
		same(LessonRules.due(Pish.LESSONS, 4, 6, { condenser = false }), { "forge" }, "the other one still due")
	end,

	["pending: the lessons waiting to be shown, known ones in level order"] = function()
		local saved = { jobs = false, trophy = false, sleeves = false, forge = true, nope = false }
		same(LessonRules.pending(Pish.LESSONS, saved), { "sleeves", "jobs", "trophy" }, "waiting (an event lesson last)")
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
	["every town and shop unlock has a lesson that teaches it (owner: when a player unlocks something, pish visits)"] = function()
		for _, product in Products.List do
			-- a bulk product is never ordered: its bin's shelf lesson teaches it (Config/Bulk)
			if product.unlockLevel > 1 and not product.bulk then
				local lesson = lessonWhere("product", product.id)
				assert(lesson, `{product.id} (Lv {product.unlockLevel}) has a lesson`)
				expect.equal(lesson.level, product.unlockLevel, `{product.id}'s lesson comes at its unlock`)
			end
		end
		local trophies, decor = 0, 0
		for _, shelf in shelves() do
			if shelf.kind == "Trophy" then
				trophies += 1
			elseif shelf.kind == "Decor" then
				decor += 1 -- one lesson for the whole Decor tab (the decor lesson test), not one per piece
			elseif shelf.unlockLevel > 1 then
				local lesson = lessonWhere("shelf", shelf.id)
				assert(lesson, `{shelf.id} (Lv {shelf.unlockLevel}) has a lesson`)
				expect.equal(lesson.level, shelf.unlockLevel, `{shelf.id}'s lesson comes at its unlock`)
			elseif shelf.kind == "CustomerCards" or shelf.kind == "PlayerCards" then
				local lesson = lessonWhere("shelf", shelf.id)
				assert(lesson and lesson.level and lesson.level > 1, `{shelf.id} is taught after the first visit`)
			end
		end
		assert(trophies > 0, "the trophies were read")
		assert(decor > 0, "the decor pieces were read")
		local trophy = lessonWhere("trigger", "trophy")
		assert(trophy and trophy.level == nil, "the first trophy has an event lesson")
		local jobs = lessonWhere("id", "jobs")
		expect.equal(jobs.level, Jobs.UNLOCK_LEVEL, "jobs at their unlock")
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

	["forShelf / forProduct: the lesson placing or ordering a thing completes"] = function()
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "WallShelf", "Products"), "wallShelf")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "GlassShowcase", "CustomerCards"), "showcase")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "trophy_meadowWarden", "Trophy"), "trophy", "any trophy")
		expect.equal(LessonRules.forShelf(Pish.LESSONS, "SmallPackRack", "Products"), nil, "the first visit's rack")
		expect.equal(LessonRules.forProduct(Pish.LESSONS, "CardSleeves"), "sleeves")
		expect.equal(LessonRules.forProduct(Pish.LESSONS, "FirstSparkBox"), "boosterBox")
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
		assert(pace.wait >= 5 and pace.wait < Pish.LESSON_SECONDS, "he doesn't hang about while they're busy")
	end,

	["used: placing or ordering a lesson's thing marks it seen, even before its level (final review I3)"] = function()
		local seen = { showcase = false }
		local after = LessonRules.used(seen, "showcase")
		expect.equal(after.showcase, true, "a waiting lesson is done")
		expect.equal(seen.showcase, false, "a copy")
		expect.equal(LessonRules.used({}, "collectorCase").collectorCase, true, "placed at level 1: never taught later")
		same(LessonRules.due(Pish.LESSONS, 1, 3, LessonRules.used({}, "showcase")), { "decor", "sleeves", "collectorCase" }, "not queued at level 2")
	end,
}
