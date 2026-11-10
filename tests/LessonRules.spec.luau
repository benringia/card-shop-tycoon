--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8): which lessons a level-up brings,
-- and when Pish comes to point at what to do next
local LessonRules = require("../src/shared/Util/LessonRules")
local Pish = require("../src/shared/Config/Pish")
local Products = require("../src/shared/Config/Products")
local Jobs = require("../src/shared/Config/Jobs")
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
	local base = { played = 300, quiet = 70, sinceNudge = 200, boxWaiting = false, shelvesStocked = true }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
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
		expect.equal(levels.jobs, 20)
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
		same(LessonRules.due(Pish.LESSONS, 1, 2, {}), { "showcase" }, "the Glass Showcase right after his first visit")
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

	["nudge: never too soon, too often or after the first hour"] = function()
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, quiet = 30 })), nil, "busy a moment ago")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, sinceNudge = 60 })), nil, "nudged a minute ago")
		expect.equal(LessonRules.nudge(Pish.STUCK, facts({ boxWaiting = true, played = 4000 })), nil, "past the first hour")
	end,
	["every town and shop unlock has a lesson that teaches it (owner: when a player unlocks something, pish visits)"] = function()
		for _, product in Products.List do
			if product.unlockLevel > 1 then
				local lesson = lessonWhere("product", product.id)
				assert(lesson, `{product.id} (Lv {product.unlockLevel}) has a lesson`)
				expect.equal(lesson.level, product.unlockLevel, `{product.id}'s lesson comes at its unlock`)
			end
		end
		local trophies = 0
		for _, shelf in shelves() do
			if shelf.kind == "Trophy" then
				trophies += 1
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
}
