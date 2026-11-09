--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8): which lessons a level-up brings,
-- and when Pish comes to point at what to do next
local LessonRules = require("../src/shared/Util/LessonRules")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

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
		expect.equal(levels.sleeves, 3)
		expect.equal(levels.sword, 4)
		expect.equal(levels.condenser, 5)
		expect.equal(levels.forge, 6)
		expect.equal(levels.expand, 7)
		expect.equal(levels.boosterBox, 11)
		expect.equal(levels.grading, 14)
		expect.equal(levels.jobs, 20)
	end,

	["due: only levels crossed now, in level order, not seen"] = function()
		same(LessonRules.due(Pish.LESSONS, 2, 6, {}), { "sleeves", "sword", "condenser", "forge" }, "2 to 6")
		same(LessonRules.due(Pish.LESSONS, 6, 7, { expand = true }), {}, "seen")
		same(LessonRules.due(Pish.LESSONS, 20, 20, {}), {}, "an old save loading at 20 gets none")
		same(LessonRules.due(Pish.LESSONS, 3, 4, {}), { "sword" }, "the level gained, not the one left")
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
}
