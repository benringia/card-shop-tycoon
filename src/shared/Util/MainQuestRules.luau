--!strict
-- Main quests (owner 2026-11-18, look A of artifact Evh8Gx9pN61R5GkodcwR3C; Config/MainQuests): the next thing to
-- build for the shop. A Build menu rack, case or machine is open once the shop's level unlocks it and none stands in
-- the shop; the one shown is the first you can already pay for (a quick win), else the oldest unlock you're saving for,
-- its bar the cash toward its price. Building one the first time pays a share of its price in shop XP, once per item.
-- With everything built, the next unlock's level is the goal, its bar running from the last unlock reached.
-- Pure (no requires, no Roblox APIs): callers pass the configs, the shelves' facts and the XP curve, so tests/ can run
-- it in Lune (tests/MainQuestRules).
local MainQuestRules = {}

export type Item = { id: string, name: string, cost: number, level: number, icon: string }
export type Goal = {
	kind: "build" | "level",
	id: string, -- a Config/Shelves id, or "level<n>"
	name: string,
	icon: string,
	text: string, -- "Build the Forge" / "Reach shop Lv 10: Bulk Bin"
	amount: string, -- "$820 / $1,500" / "50%"
	progress: number, -- 0..1
	ready: boolean, -- a build goal whose price the cash covers
	cost: number, -- a build goal's price (0 for a level)
	level: number, -- the item's unlock level, or the level to reach
}
export type Unlock = { level: number, name: string }
export type State = {
	items: { Item },
	level: number,
	xp: number,
	cash: number,
	built: { [string]: boolean },
	unlocks: { Unlock },
	required: (level: number) -> number, -- total shop XP to reach a level (LevelMath.getRequiredXp)
	icon: string, -- a level goal's icon (Config/MainQuests LEVEL_ICON)
}
type Config = { ITEMS: { { id: string, icon: string } }, XP_SHARE: number, LEVEL_ICON: string }
type Facts = { [string]: { name: string, cost: number, unlockLevel: number } }

local function listed(cfg: Config, id: string): boolean
	for _, entry in cfg.ITEMS do
		if entry.id == id then
			return true
		end
	end
	return false
end

-- Whether `id` (a Config/Shelves id) is a main quest item
function MainQuestRules.isItem(cfg: Config, id: string): boolean
	return listed(cfg, id)
end

-- "$1,500": whole dollars with thousands commas
function MainQuestRules.money(amount: number): string
	local whole = tostring(math.max(0, math.floor(amount)))
	local grouped = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return "$" .. grouped
end

-- The configured items with their shelves' names, prices and unlock levels, in the order they unlock (the config's
-- order within a level); an id Config/Shelves doesn't have is skipped
function MainQuestRules.items(cfg: Config, shelves: Facts): { Item }
	local list: { Item } = {}
	local order: { [string]: number } = {}
	for index, entry in cfg.ITEMS do
		local shelf = shelves[entry.id]
		if shelf then
			order[entry.id] = index
			table.insert(list, { id = entry.id, name = shelf.name, cost = shelf.cost, level = shelf.unlockLevel, icon = entry.icon })
		end
	end
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return order[a.id] < order[b.id]
	end)
	return list
end

-- The items the shop's level unlocks with none in the shop, in unlock order
function MainQuestRules.open(items: { Item }, level: number, built: { [string]: boolean }): { Item }
	local list: { Item } = {}
	for _, item in items do
		if item.level <= level and not built[item.id] then
			table.insert(list, item)
		end
	end
	return list
end

-- The one to show: the first the cash already covers, else the oldest unlock; nil when none is open
function MainQuestRules.pick(open: { Item }, cash: number): Item?
	for _, item in open do
		if cash >= item.cost then
			return item
		end
	end
	return open[1]
end

function MainQuestRules.buildGoal(item: Item, cash: number): Goal
	local shown = math.min(math.max(cash, 0), item.cost)
	return {
		kind = "build",
		id = item.id,
		name = item.name,
		icon = item.icon,
		text = `Build the {item.name}`,
		amount = `{MainQuestRules.money(shown)} / {MainQuestRules.money(item.cost)}`,
		progress = if item.cost > 0 then math.clamp(cash / item.cost, 0, 1) else 1,
		ready = cash >= item.cost,
		cost = item.cost,
		level = item.level,
	}
end

-- The next unlock above `level` as a goal: "Reach shop Lv 10: Bulk Bin" (+N for the others at that level), its bar the
-- XP from the last unlock reached (or level 1) to it; nil when nothing is left to unlock
function MainQuestRules.levelGoal(level: number, xp: number, unlocks: { Unlock }, required: (number) -> number, icon: string): Goal?
	local target: Unlock? = nil
	local more = 0
	local base = 1
	for _, unlock in unlocks do
		if unlock.level > level then
			if not target or unlock.level < target.level then
				target, more = unlock, 0
			elseif unlock.level == target.level then
				more += 1
			end
		elseif unlock.level > base then
			base = unlock.level
		end
	end
	if not target then
		return nil
	end
	local from, to = required(base), required(target.level)
	local progress = if to > from then math.clamp((xp - from) / (to - from), 0, 1) else 0
	local name = if more > 0 then `{target.name} +{more}` else target.name
	return {
		kind = "level",
		id = `level{target.level}`,
		name = name,
		icon = icon,
		text = `Reach shop Lv {target.level}: {name}`,
		amount = `{math.floor(progress * 100)}%`,
		progress = progress,
		ready = false,
		cost = 0,
		level = target.level,
	}
end

-- What the strip's main row shows: a build goal while any item is open, else the next unlock's level, else nil
function MainQuestRules.goal(state: State): Goal?
	local item = MainQuestRules.pick(MainQuestRules.open(state.items, state.level, state.built), state.cash)
	if item then
		return MainQuestRules.buildGoal(item, state.cash)
	end
	return MainQuestRules.levelGoal(state.level, state.xp, state.unlocks, state.required, state.icon)
end

-- Shop XP a first build pays: a share of its price, at least 1
function MainQuestRules.reward(cfg: Config, cost: number): number
	return math.max(1, math.floor(cost * cfg.XP_SHARE + 0.5))
end

-- `id` placed: the done set after it, and whether this was its first time (it pays); only main quest items count
function MainQuestRules.markBuilt(done: { [string]: boolean }, cfg: Config, id: string): ({ [string]: boolean }, boolean)
	if done[id] or not listed(cfg, id) then
		return done, false
	end
	local after = table.clone(done)
	after[id] = true
	return after, true
end

-- The saved done list (an array of ids) as a set; junk and ids no longer listed dropped
function MainQuestRules.clean(saved: any, cfg: Config): { [string]: boolean }
	local done: { [string]: boolean } = {}
	if typeof(saved) ~= "table" then
		return done
	end
	for _, id in saved do
		if typeof(id) == "string" and listed(cfg, id) then
			done[id] = true
		end
	end
	return done
end

-- The done set as saved: a plain array, sorted
function MainQuestRules.toSave(done: { [string]: boolean }): { string }
	local list = {}
	for id, on in done do
		if on then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- The main quest items standing in the shop, as the player attribute the client reads ("Forge,WallShelf")
function MainQuestRules.builtText(built: { [string]: boolean }): string
	return table.concat(MainQuestRules.toSave(built), ",")
end

function MainQuestRules.parseBuilt(cfg: Config, text: any): { [string]: boolean }
	local built: { [string]: boolean } = {}
	if typeof(text) ~= "string" then
		return built
	end
	for id in string.gmatch(text, "[^,]+") do
		if listed(cfg, id) then
			built[id] = true
		end
	end
	return built
end

-- A phone's quest chip once the day's quests are done: "54%", "Build!" when paid for, or "Lv 10"
function MainQuestRules.chipText(goal: Goal): string
	if goal.kind == "level" then
		return `Lv {goal.level}`
	end
	return if goal.ready then "Build!" else `{math.floor(goal.progress * 100)}%`
end

return MainQuestRules
