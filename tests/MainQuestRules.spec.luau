--!strict
-- Main quests (owner 2026-11-18: "when items like forge is unlocked and the players couldnt afford it yet, add it to
-- their main quests, so that when they finish all daily quest, there's always something to do"; look A): the next
-- thing to build for the shop with the cash filling its bar, a first build paying shop XP once, and the next unlock's
-- level as the goal once everything is built.
local MainQuestRules = require("../src/shared/Util/MainQuestRules")
local MainQuests = require("../src/shared/Config/MainQuests")
local Pish = require("../src/shared/Config/Pish")
local Levels = require("../src/shared/Config/Levels")
local LevelMath = require("../src/shared/Util/LevelMath")
local expect = require("./lib/expect")

type Facts = { [string]: { name: string, cost: number, unlockLevel: number, kind: string } }

-- Config/Shelves holds Vector3s, so Lune reads its text: each entry's id, name, kind, price and unlock level
local function shelves(): Facts
	local source = require("@lune/fs").readFile("src/shared/Config/Shelves.luau")
	local starts = {}
	for position, id in string.gmatch(source, '()id = "([%w_]+)"') do
		table.insert(starts, { position = position :: number, id = id })
	end
	local found: Facts = {}
	for index, start in starts do
		local finish = if starts[index + 1] then starts[index + 1].position - 1 else #source
		local body = string.sub(source, start.position, finish)
		found[start.id] = {
			name = string.match(body, 'name = "([^"]+)"') :: string,
			kind = string.match(body, 'kind = "([%w_]+)"') :: string,
			cost = tonumber(string.match(body, "cost = (%d+)")) :: number,
			unlockLevel = tonumber(string.match(body, "unlockLevel = (%d+)")) :: number,
		}
	end
	return found
end

local function items(): { MainQuestRules.Item }
	return MainQuestRules.items(MainQuests, shelves())
end

local function ids(list: { MainQuestRules.Item }): { string }
	local out = {}
	for _, item in list do
		table.insert(out, item.id)
	end
	return out
end

local function same(actual: { string }, expected: { string }, what: string)
	expect.equal(#actual, #expected, `{what}: count`)
	for index = 1, #expected do
		expect.equal(actual[index], expected[index], `{what}: #{index}`)
	end
end

local function item(id: string): MainQuestRules.Item
	for _, entry in items() do
		if entry.id == id then
			return entry
		end
	end
	error(`no main quest item {id}`)
end

local function set(list: { string }): { [string]: boolean }
	local out = {}
	for _, id in list do
		out[id] = true
	end
	return out
end

local function required(level: number): number
	return LevelMath.getRequiredXp(Levels, level)
end

local ALL = { "GlassShowcase", "CollectorCase", "WallShelf", "Condenser", "Forge", "AccessoryHook", "BigDisplayRack", "BulkBin", "GradingStation" }

local function state(over: { [string]: any }): MainQuestRules.State
	local base: any = {
		items = items(),
		level = 9,
		xp = required(9),
		cash = 0,
		built = set(ALL),
		unlocks = { { level = 9, name = "Big Display Rack" }, { level = 10, name = "Bulk Bin" }, { level = 14, name = "Grading Station" } },
		required = required,
		icon = MainQuests.LEVEL_ICON,
	}
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	["every main quest is a Build menu rack, case or machine Pish teaches, with a price and an icon"] = function()
		local facts = shelves()
		for _, entry in MainQuests.ITEMS do
			local shelf = facts[entry.id]
			assert(shelf, `{entry.id} is a Config/Shelves entry`)
			assert(shelf.cost > 0, `{entry.id} has a price`)
			assert(shelf.kind ~= "Decor" and shelf.kind ~= "Trophy", `{entry.id} isn't decor or a trophy`)
			assert(typeof(entry.icon) == "string" and #entry.icon > 0, `{entry.id} has an icon`)
		end
		-- the same things Pish's lessons walk you through building (the decor lesson covers a whole tab: left out)
		local taught = {}
		for _, lesson in Pish.LESSONS do
			if lesson.shelf and lesson.id ~= "decor" then
				table.insert(taught, lesson.shelf)
			end
		end
		table.sort(taught)
		local listed = table.clone(ids(items()))
		table.sort(listed)
		same(listed, taught, "main quests vs Pish's shelf lessons")
	end,

	["items come in the order they unlock, with their names, prices and icons"] = function()
		same(ids(items()), ALL, "unlock order")
		local forge = item("Forge")
		expect.equal(forge.name, "Forge")
		expect.equal(forge.cost, 1500)
		expect.equal(forge.level, 6)
		expect.equal(forge.icon, "Forge")
		local odd = MainQuestRules.items({ ITEMS = { { id = "Nope", icon = "X" }, { id = "Forge", icon = "Forge" } }, XP_SHARE = 0.1, LEVEL_ICON = "Level" }, shelves())
		same(ids(odd), { "Forge" }, "an unknown id is skipped")
	end,

	["open: unlocked at the shop's level, with none in the shop"] = function()
		same(ids(MainQuestRules.open(items(), 1, {})), { "GlassShowcase", "CollectorCase" }, "a new shop")
		same(ids(MainQuestRules.open(items(), 6, set({ "GlassShowcase", "CollectorCase", "WallShelf" }))), { "Condenser", "Forge" }, "level 6")
		same(ids(MainQuestRules.open(items(), 20, set(ALL))), {}, "everything built")
	end,

	["pick: one you can already pay for first, else the oldest unlock you're saving for"] = function()
		local saving = MainQuestRules.open(items(), 6, set({ "GlassShowcase", "CollectorCase", "WallShelf" }))
		expect.equal((MainQuestRules.pick(saving, 820) :: any).id, "Condenser", "the Condenser is paid for")
		expect.equal((MainQuestRules.pick(saving, 300) :: any).id, "Condenser", "neither: the oldest")
		local hook = MainQuestRules.open(items(), 7, set({ "GlassShowcase", "CollectorCase", "WallShelf", "Condenser" }))
		same(ids(hook), { "Forge", "AccessoryHook" }, "level 7")
		expect.equal((MainQuestRules.pick(hook, 820) :: any).id, "AccessoryHook", "a quick win first")
		expect.equal((MainQuestRules.pick(hook, 100) :: any).id, "Forge", "saving: the oldest")
		expect.isNil(MainQuestRules.pick({}, 1000), "nothing open")
	end,

	["a build goal: its words, the cash toward its price, ready at the price"] = function()
		local goal = MainQuestRules.buildGoal(item("Forge"), 820)
		expect.equal(goal.kind, "build")
		expect.equal(goal.id, "Forge")
		expect.equal(goal.text, "Build the Forge")
		expect.equal(goal.amount, "$820 / $1,500")
		expect.near(goal.progress, 820 / 1500, 1e-6)
		expect.equal(goal.ready, false)
		expect.equal(goal.icon, "Forge")
		local ready = MainQuestRules.buildGoal(item("Forge"), 1500.75)
		expect.equal(ready.ready, true, "the price is there")
		expect.equal(ready.progress, 1)
		local rich = MainQuestRules.buildGoal(item("Forge"), 6000)
		expect.equal(rich.progress, 1, "the bar stops full")
		expect.equal(rich.amount, "$1,500 / $1,500", "the cash shown stops at the price")
		expect.equal(MainQuestRules.buildGoal(item("GradingStation"), 1234.9).amount, "$1,234 / $5,000", "whole dollars")
		expect.equal(MainQuestRules.buildGoal(item("GlassShowcase"), 0).progress, 0)
	end,

	["while any is open the goal is to build one"] = function()
		local goal = MainQuestRules.goal(state({ cash = 820, built = set({ "GlassShowcase", "CollectorCase", "WallShelf", "Condenser", "AccessoryHook", "BigDisplayRack" }) })) :: MainQuestRules.Goal
		expect.equal(goal.kind, "build")
		expect.equal(goal.id, "Forge")
	end,

	["everything built: the next unlock's level is the goal, its bar from the last unlock reached"] = function()
		local halfway = required(9) + (required(10) - required(9)) / 2
		local goal = MainQuestRules.goal(state({ xp = halfway })) :: MainQuestRules.Goal
		expect.equal(goal.kind, "level")
		expect.equal(goal.id, "level10")
		expect.equal(goal.level, 10)
		expect.equal(goal.text, "Reach shop Lv 10: Bulk Bin")
		expect.near(goal.progress, 0.5, 1e-6)
		expect.equal(goal.amount, "50%")
		expect.equal(goal.icon, "Level")
		expect.equal(goal.ready, false)
		-- between unlocks the bar runs from the last one reached, so a level-up on the way doesn't empty it
		local at12 = required(12) + 10
		local far = MainQuestRules.goal(state({ level = 12, xp = at12, unlocks = { { level = 11, name = "Booster Box" }, { level = 14, name = "Grading Station" }, { level = 14, name = "Ember Colossus" } } })) :: MainQuestRules.Goal
		expect.equal(far.text, "Reach shop Lv 14: Grading Station +1", "two unlocks at that level")
		expect.near(far.progress, (at12 - required(11)) / (required(14) - required(11)), 1e-6)
		-- nothing left to unlock: no goal
		expect.isNil(MainQuestRules.goal(state({ level = 100, xp = required(100), unlocks = { { level = 14, name = "Grading Station" } } })), "the top")
	end,

	["a first build pays a tenth of its price in shop XP, once per item"] = function()
		expect.equal(MainQuestRules.reward(MainQuests, 1500), 150, "the Forge")
		expect.equal(MainQuestRules.reward(MainQuests, 250), 25)
		expect.equal(MainQuestRules.reward(MainQuests, 5000), 500, "the Grading Station")
		expect.equal(MainQuestRules.reward(MainQuests, 3), 1, "at least 1")
		local done, first = MainQuestRules.markBuilt({}, MainQuests, "Forge")
		expect.equal(first, true, "the first Forge pays")
		expect.equal(done.Forge, true)
		local again, second = MainQuestRules.markBuilt(done, MainQuests, "Forge")
		expect.equal(second, false, "a second Forge doesn't")
		expect.equal(again.Forge, true)
		local _, rack = MainQuestRules.markBuilt({}, MainQuests, "SmallPackRack")
		expect.equal(rack, false, "not a main quest: nothing")
		local _, plant = MainQuestRules.markBuilt({}, MainQuests, "PottedPlant")
		expect.equal(plant, false, "decor: nothing")
		expect.equal(MainQuestRules.isItem(MainQuests, "Forge"), true)
		expect.equal(MainQuestRules.isItem(MainQuests, "PottedPlant"), false)
	end,

	["the saved list is cleaned, and the shop's built list goes through an attribute"] = function()
		local done = MainQuestRules.clean({ "Forge", "Junk", 5, "Forge", "Condenser" }, MainQuests)
		expect.equal(done.Forge, true)
		expect.equal(done.Condenser, true)
		expect.isNil(done.Junk, "unknown ids dropped")
		same(MainQuestRules.toSave(done), { "Condenser", "Forge" }, "saved sorted")
		expect.equal(next(MainQuestRules.clean("x", MainQuests)), nil, "junk: nothing done")
		local text = MainQuestRules.builtText(set({ "WallShelf", "Forge" }))
		expect.equal(text, "Forge,WallShelf")
		local back = MainQuestRules.parseBuilt(MainQuests, text)
		expect.equal(back.Forge, true)
		expect.equal(back.WallShelf, true)
		expect.equal(next(MainQuestRules.parseBuilt(MainQuests, nil)), nil, "no attribute yet")
		expect.equal(next(MainQuestRules.parseBuilt(MainQuests, "")), nil)
		expect.isNil(MainQuestRules.parseBuilt(MainQuests, "Forge,,Nope").Nope, "unknown ids dropped")
	end,

	["a phone's chip: the main quest's percent, Build! once paid for, the level to reach"] = function()
		expect.equal(MainQuestRules.chipText(MainQuestRules.buildGoal(item("Forge"), 820)), "54%")
		expect.equal(MainQuestRules.chipText(MainQuestRules.buildGoal(item("Forge"), 1500)), "Build!")
		expect.equal(MainQuestRules.chipText(MainQuestRules.goal(state({})) :: MainQuestRules.Goal), "Lv 10")
	end,
}
