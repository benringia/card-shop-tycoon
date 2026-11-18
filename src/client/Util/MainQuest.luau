--!strict
-- The main quest on this client (owner 2026-11-18, look A of artifact Evh8Gx9pN61R5GkodcwR3C; Config/MainQuests,
-- Util/MainQuestRules): the goal the quest strip's main row and the Quests window show, picked from the shop's builds
-- (the ShopBuilt attribute MainQuestService sets), the cash, the shop level and its XP. Listeners hear it whenever what
-- it shows changes (whole dollars, whole percents, ready or not, another goal).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MainQuests = require(Config:WaitForChild("MainQuests"))
local Shelves = require(Config:WaitForChild("Shelves"))
local MainQuestRules = require(Shared:WaitForChild("Util"):WaitForChild("MainQuestRules"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local NextUnlock = require((script.Parent :: Instance):WaitForChild("NextUnlock"))

local MainQuest = {}

type Goal = MainQuestRules.Goal

local ATTRIBUTE = "ShopBuilt" -- MainQuestService: the main quest items standing in the shop

local player = Players.LocalPlayer
local listeners: { (Goal?) -> () } = {}
local items: { MainQuestRules.Item }? = nil
local unlocks: { MainQuestRules.Unlock }? = nil
local lastKey: string? = nil -- what listeners last heard
local watching = false

local function number(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function allItems(): { MainQuestRules.Item }
	local list = items
	if not list then
		local facts = {}
		for _, def in Shelves.List do
			facts[def.id] = { name = def.name, cost = def.cost, unlockLevel = def.unlockLevel }
		end
		list = MainQuestRules.items(MainQuests, facts)
		items = list
	end
	return list
end

local function state(): MainQuestRules.State
	local known = unlocks
	if not known then
		known = NextUnlock.list()
		unlocks = known
	end
	return {
		items = allItems(),
		level = number("Level", 1),
		xp = number("XP", 0),
		cash = number("Cash", 0),
		built = MainQuestRules.parseBuilt(MainQuests, player:GetAttribute(ATTRIBUTE)),
		unlocks = known,
		required = LevelRules.getRequiredXp,
		icon = MainQuests.LEVEL_ICON,
	}
end

-- The goal now: what to build next, or the next unlock's level; nil until the shop's builds are known, or at the top
function MainQuest.current(): Goal?
	if player:GetAttribute(ATTRIBUTE) == nil then
		return nil
	end
	return MainQuestRules.goal(state())
end

-- The other open items after the current one, in unlock order (the Quests window's "Then" lines)
function MainQuest.others(): { MainQuestRules.Item }
	local list: { MainQuestRules.Item } = {}
	if player:GetAttribute(ATTRIBUTE) == nil then
		return list
	end
	local now = state()
	local goal = MainQuestRules.goal(now)
	for _, item in MainQuestRules.open(now.items, now.level, now.built) do
		if not goal or item.id ~= goal.id then
			table.insert(list, item)
		end
	end
	return list
end

local function keyOf(goal: Goal?): string
	return if goal then `{goal.id}|{goal.amount}|{goal.ready}` else ""
end

local function changed()
	local goal = MainQuest.current()
	local key = keyOf(goal)
	if key == lastKey then
		return
	end
	lastKey = key
	for _, listener in listeners do
		task.spawn(listener, goal)
	end
end

-- `listener` hears the goal whenever what it shows changes (the cash, the level and its XP, a build or a sale)
function MainQuest.onChanged(listener: (Goal?) -> ())
	table.insert(listeners, listener)
	if watching then
		return
	end
	watching = true
	for _, name in { "Cash", "Level", "XP", ATTRIBUTE } do
		player:GetAttributeChangedSignal(name):Connect(changed)
	end
end

return MainQuest
