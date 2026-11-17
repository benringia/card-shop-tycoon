--!strict
-- Daily quests' rules (Config/Quests; QuestService keeps the state, QuestController shows it): rolling a day's quests
-- for the shop's level, counting play toward them, claiming each and the bonus once all three are claimed, cleaning a
-- saved state and what the client shows. Pure (no requires, no Roblox APIs): callers pass Config/Quests in.
local QuestRules = {}

export type Quest = { id: string, goal: number, progress: number, claimed: boolean }
export type State = { day: number, list: { Quest }, bonus: boolean }
export type QuestView = { id: string, kind: string, text: string, icon: string, goal: number, progress: number, done: boolean, claimed: boolean, cash: number, xp: number }
export type View = { quests: { QuestView }, bonusReady: boolean, bonusClaimed: boolean, claimable: number }

type Entry = { id: string, kind: string, event: string, icon: string, text: string, minLevel: number?, maxLevel: number?, goals: { { level: number, goal: number } } }
type Config = { KINDS: { string }, EVENTS: { string }, POOL: { Entry }, REWARD: { cash: number, cashPerLevel: number, xp: number, xpPerLevel: number } }

local function whole(value: any, low: number): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.max(low, math.floor(value))
end

local function entryOf(cfg: Config, id: string): Entry?
	for _, entry in cfg.POOL do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function QuestRules.fresh(): State
	return { day = -1, list = {}, bonus = false }
end

-- The goal of `entry` at shop level `level`: its last band at or under the level (its first band below that)
function QuestRules.goalFor(entry: Entry, level: number): number
	local goal = entry.goals[1].goal
	for _, band in entry.goals do
		if band.level <= level then
			goal = band.goal
		end
	end
	return goal
end

-- A day's quests: one per KIND (in order), each picked by its roll in [0, 1) among that kind's quests unlocked at `level`
function QuestRules.roll(cfg: Config, level: number, rolls: { number }): { Quest }
	local list: { Quest } = {}
	for index, kind in cfg.KINDS do
		local open: { Entry } = {}
		for _, entry in cfg.POOL do
			if entry.kind == kind and (entry.minLevel or 1) <= level and level <= (entry.maxLevel or math.huge) then
				table.insert(open, entry)
			end
		end
		if #open > 0 then
			local roll = math.clamp(rolls[index] or 0, 0, 0.999999)
			local entry = open[math.floor(roll * #open) + 1]
			table.insert(list, { id = entry.id, goal = QuestRules.goalFor(entry, level), progress = 0, claimed = false })
		end
	end
	return list
end

-- The state on `day`: unchanged on the same day, new quests and a fresh bonus on a new one
function QuestRules.refresh(state: State, day: number, cfg: Config, level: number, rolls: { number }): State
	if state.day == day and #state.list > 0 then
		return state
	end
	return { day = day, list = QuestRules.roll(cfg, level, rolls), bonus = false }
end

-- Play counted toward every unclaimed, unfinished quest whose event is `event`, up to its goal: the new state (the same
-- one when nothing moved, so callers can skip telling the client) and the quests (indexes) it just finished
function QuestRules.add(state: State, cfg: Config, event: string, amount: number): (State, { number })
	local done: { number } = {}
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return state, done
	end
	local after = table.clone(state)
	after.list = {}
	local moved = false
	for index, quest in state.list do
		local entry = entryOf(cfg, quest.id)
		local copy = table.clone(quest)
		if entry and entry.event == event and not quest.claimed and quest.progress < quest.goal then
			copy.progress = math.min(quest.goal, quest.progress + amount)
			moved = true
			if copy.progress >= quest.goal then
				table.insert(done, index)
			end
		end
		after.list[index] = copy
	end
	return if moved then after else state, done
end

-- Claims quest `index` when it's done and not claimed yet: the new state, or nil and why ("unknown" | "notDone" |
-- "claimed")
function QuestRules.claim(state: State, index: number): (State?, string?)
	local quest = state.list[index]
	if not quest then
		return nil, "unknown"
	end
	if quest.claimed then
		return nil, "claimed"
	end
	if quest.progress < quest.goal then
		return nil, "notDone"
	end
	local after = table.clone(state)
	after.list = table.clone(state.list)
	after.list[index] = table.clone(quest)
	after.list[index].claimed = true
	return after, nil
end

-- The bonus waits for every quest of the day to be claimed, once
function QuestRules.bonusReady(state: State): boolean
	if state.bonus or #state.list == 0 then
		return false
	end
	for _, quest in state.list do
		if not quest.claimed then
			return false
		end
	end
	return true
end

function QuestRules.claimBonus(state: State): (State?, string?)
	if state.bonus then
		return nil, "claimed"
	end
	if not QuestRules.bonusReady(state) then
		return nil, "notDone"
	end
	local after = table.clone(state)
	after.bonus = true
	return after, nil
end

-- One quest's pay at shop level `level`
function QuestRules.reward(cfg: Config, level: number): { cash: number, xp: number }
	local pay = cfg.REWARD
	return { cash = pay.cash + pay.cashPerLevel * level, xp = pay.xp + pay.xpPerLevel * level }
end

-- A saved state made safe: anything but a table starts fresh, unknown quests are dropped, numbers whole and in range
function QuestRules.clean(saved: any, cfg: Config): State
	if typeof(saved) ~= "table" then
		return QuestRules.fresh()
	end
	local state: State = { day = whole(saved.day, -1) or -1, list = {}, bonus = saved.bonus == true }
	if typeof(saved.list) == "table" then
		for _, quest in saved.list do
			if typeof(quest) == "table" and typeof(quest.id) == "string" and entryOf(cfg, quest.id) then
				local goal = whole(quest.goal, 1) or 1
				table.insert(state.list, {
					id = quest.id,
					goal = goal,
					progress = math.min(goal, whole(quest.progress, 0) or 0),
					claimed = quest.claimed == true,
				})
			end
		end
	end
	return state
end

-- What the client shows: each quest's words (its goal in them), progress, pay; the bonus; how many can be claimed now
function QuestRules.view(state: State, cfg: Config, level: number): View
	local pay = QuestRules.reward(cfg, level)
	local quests: { QuestView } = {}
	local claimable = 0
	for _, quest in state.list do
		local entry = entryOf(cfg, quest.id)
		if entry then
			local done = quest.progress >= quest.goal
			if done and not quest.claimed then
				claimable += 1
			end
			local goal = tostring(quest.goal)
			table.insert(quests, {
				id = quest.id,
				kind = entry.kind,
				text = (string.gsub(entry.text, "{n}", function()
					return goal
				end)),
				icon = entry.icon,
				goal = quest.goal,
				progress = quest.progress,
				done = done,
				claimed = quest.claimed,
				cash = pay.cash,
				xp = pay.xp,
			})
		end
	end
	local bonusReady = QuestRules.bonusReady(state)
	if bonusReady then
		claimable += 1
	end
	return { quests = quests, bonusReady = bonusReady, bonusClaimed = state.bonus, claimable = claimable }
end

export type StripChanges = { progressed: { number }, finished: { number }, doneChanged: boolean, claimAppeared: boolean, allDone: boolean }

-- What the quest strip animates going from `before` to `after` (owner 2026-11-17, "immersive animations on the quest
-- strip"): the quests that moved on (a +1 and the bar filling), those that just finished (their check stamps in), whether
-- the done count changed (its chip bumps), Claim appearing, and all done (the chest opened). Nothing on the first state
-- or a new day's quests (different ids): those are shown as they are.
function QuestRules.stripChanges(before: View?, after: View): StripChanges
	local changes: StripChanges = { progressed = {}, finished = {}, doneChanged = false, claimAppeared = false, allDone = false }
	if not before or #before.quests ~= #after.quests then
		return changes
	end
	local doneBefore, doneAfter = 0, 0
	for index, quest in after.quests do
		local old = before.quests[index]
		if old.id ~= quest.id then
			return { progressed = {}, finished = {}, doneChanged = false, claimAppeared = false, allDone = false }
		end
		if quest.progress > old.progress then
			table.insert(changes.progressed, index)
		end
		if quest.done and not old.done then
			table.insert(changes.finished, index)
		end
		doneBefore += if old.done then 1 else 0
		doneAfter += if quest.done then 1 else 0
	end
	changes.doneChanged = doneBefore ~= doneAfter
	changes.claimAppeared = before.claimable == 0 and after.claimable > 0
	changes.allDone = after.bonusClaimed and not before.bonusClaimed
	return changes
end

return QuestRules
