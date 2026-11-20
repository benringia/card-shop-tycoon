--!strict
-- Daily and weekly quests' rules (Config/Quests; QuestService keeps the state, QuestController shows it): rolling a
-- day's (or a week's) quests for the shop's level, counting play toward them, claiming each and the bonus once all
-- three are claimed (a week's chest once all three are done), cleaning a saved state and what the client shows. Pure
-- (no requires, no Roblox APIs): callers pass Config/Quests in.
local QuestRules = {}

export type Quest = { id: string, goal: number, progress: number, claimed: boolean }
export type State = { day: number, list: { Quest }, bonus: boolean }
export type QuestView = { id: string, kind: string, text: string, icon: string, goal: number, progress: number, done: boolean, claimed: boolean, cash: number, xp: number }
-- `week`: the week's quests in the same shape (their chest as the bonus), sent along with the day's
export type View = { quests: { QuestView }, bonusReady: boolean, bonusClaimed: boolean, claimable: number, week: View? }
-- A week's quests (owner 2026-11-17: "what players do after daily quests?"): `week` its number (GiftRules.weekOf),
-- `chest` the Weekly Chest opened; its quests are never claimed one by one
export type Week = { week: number, list: { Quest }, chest: boolean }
export type StripMode = "daily" | "weekly" | "done"
export type BandParts = { title: boolean, claim: boolean, count: boolean, fold: boolean }

type Entry = { id: string, kind: string, event: string, icon: string, text: string, one: string?, minLevel: number?, maxLevel: number?, goals: { { level: number, goal: number } } }
type Config = { KINDS: { string }, EVENTS: { string }, POOL: { Entry }, REWARD: { cash: number, cashPerLevel: number, xp: number, xpPerLevel: number }, WEEKLY: { TIMES: number } }

local DAY = 86400

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

-- One per KIND (in order), each picked by its roll in [0, 1) among that kind's quests unlocked at `level`, each goal
-- `times` its day's goal
local function rollWith(cfg: Config, level: number, rolls: { number }, times: number): { Quest }
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
			table.insert(list, { id = entry.id, goal = QuestRules.goalFor(entry, level) * times, progress = 0, claimed = false })
		end
	end
	return list
end

-- A day's quests: one per KIND (in order), each picked by its roll in [0, 1) among that kind's quests unlocked at `level`
function QuestRules.roll(cfg: Config, level: number, rolls: { number }): { Quest }
	return rollWith(cfg, level, rolls, 1)
end

-- A week's quests: picked like a day's, each goal WEEKLY.TIMES the day's
function QuestRules.rollWeek(cfg: Config, level: number, rolls: { number }): { Quest }
	return rollWith(cfg, level, rolls, cfg.WEEKLY.TIMES)
end

-- The state on `day`: unchanged on the same day, new quests and a fresh bonus on a new one
function QuestRules.refresh(state: State, day: number, cfg: Config, level: number, rolls: { number }): State
	if state.day == day and #state.list > 0 then
		return state
	end
	return { day = day, list = QuestRules.roll(cfg, level, rolls), bonus = false }
end

-- `list` with `amount` counted toward its unclaimed, unfinished quests of `event`, up to their goals: the new list (nil
-- when nothing moved) and the quests (indexes) it just finished
local function addTo(list: { Quest }, cfg: Config, event: string, amount: number): ({ Quest }?, { number })
	local done: { number } = {}
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return nil, done
	end
	local after: { Quest } = {}
	local moved = false
	for index, quest in list do
		local entry = entryOf(cfg, quest.id)
		local copy = table.clone(quest)
		if entry and entry.event == event and not quest.claimed and quest.progress < quest.goal then
			copy.progress = math.min(quest.goal, quest.progress + amount)
			moved = true
			if copy.progress >= quest.goal then
				table.insert(done, index)
			end
		end
		after[index] = copy
	end
	return if moved then after else nil, done
end

-- Play counted toward every unclaimed, unfinished quest whose event is `event`, up to its goal: the new state (the same
-- one when nothing moved, so callers can skip telling the client) and the quests (indexes) it just finished
function QuestRules.add(state: State, cfg: Config, event: string, amount: number): (State, { number })
	local list, done = addTo(state.list, cfg, event, amount)
	if not list then
		return state, done
	end
	local after = table.clone(state)
	after.list = list
	return after, done
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

-- A saved quest list made safe: unknown quests dropped, numbers whole and in range; `claims`: keep what was claimed (a
-- week's quests are never claimed one by one)
local function cleanList(saved: any, cfg: Config, claims: boolean): { Quest }
	local list: { Quest } = {}
	if typeof(saved) ~= "table" then
		return list
	end
	for _, quest in saved do
		if typeof(quest) == "table" and typeof(quest.id) == "string" and entryOf(cfg, quest.id) then
			local goal = whole(quest.goal, 1) or 1
			table.insert(list, {
				id = quest.id,
				goal = goal,
				progress = math.min(goal, whole(quest.progress, 0) or 0),
				claimed = claims and quest.claimed == true,
			})
		end
	end
	return list
end

-- A saved state made safe: anything but a table starts fresh, unknown quests are dropped, numbers whole and in range
function QuestRules.clean(saved: any, cfg: Config): State
	if typeof(saved) ~= "table" then
		return QuestRules.fresh()
	end
	return { day = whole(saved.day, -1) or -1, list = cleanList(saved.list, cfg, true), bonus = saved.bonus == true }
end

-- One quest as the client shows it: its words (its goal in them), progress and pay
local function rowOf(entry: Entry, quest: Quest, cash: number, xp: number): QuestView
	local goal = tostring(quest.goal)
	return {
		id = quest.id,
		kind = entry.kind,
		text = if quest.goal == 1 and entry.one
			then entry.one
			else (string.gsub(entry.text, "{n}", function()
				return goal
			end)),
		icon = entry.icon,
		goal = quest.goal,
		progress = quest.progress,
		done = quest.progress >= quest.goal,
		claimed = quest.claimed,
		cash = cash,
		xp = xp,
	}
end

-- What the client shows: each quest's words (its goal in them), progress, pay; the bonus; how many can be claimed now
function QuestRules.view(state: State, cfg: Config, level: number): View
	local pay = QuestRules.reward(cfg, level)
	local quests: { QuestView } = {}
	local claimable = 0
	for _, quest in state.list do
		local entry = entryOf(cfg, quest.id)
		if entry then
			local row = rowOf(entry, quest, pay.cash, pay.xp)
			if row.done and not row.claimed then
				claimable += 1
			end
			table.insert(quests, row)
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

-- The weekly quests (owner 2026-11-17: "what players do after daily quests?", look A) -----------------------------

function QuestRules.freshWeek(): Week
	return { week = -1, list = {}, chest = false }
end

-- The state in `week`: unchanged in the same week, new quests and a shut chest in a new one
function QuestRules.refreshWeek(state: Week, week: number, cfg: Config, level: number, rolls: { number }): Week
	if state.week == week and #state.list > 0 then
		return state
	end
	return { week = week, list = QuestRules.rollWeek(cfg, level, rolls), chest = false }
end

-- Play counted toward the week's quests, like a day's: the new state (the same one when nothing moved) and the quests
-- (indexes) it just finished
function QuestRules.addWeek(state: Week, cfg: Config, event: string, amount: number): (Week, { number })
	local list, done = addTo(state.list, cfg, event, amount)
	if not list then
		return state, done
	end
	local after = table.clone(state)
	after.list = list
	return after, done
end

-- The Weekly Chest waits for all of the week's quests to be done (no claims), once
function QuestRules.chestReady(state: Week): boolean
	if state.chest or #state.list == 0 then
		return false
	end
	for _, quest in state.list do
		if quest.progress < quest.goal then
			return false
		end
	end
	return true
end

function QuestRules.claimChest(state: Week): (Week?, string?)
	if state.chest then
		return nil, "claimed"
	end
	if not QuestRules.chestReady(state) then
		return nil, "notDone"
	end
	local after = table.clone(state)
	after.chest = true
	return after, nil
end

-- A saved week made safe, like a day's
function QuestRules.cleanWeek(saved: any, cfg: Config): Week
	if typeof(saved) ~= "table" then
		return QuestRules.freshWeek()
	end
	return { week = whole(saved.week, -1) or -1, list = cleanList(saved.list, cfg, false), chest = saved.chest == true }
end

-- The week as the client shows it: rows like a day's (no pay: the chest is the prize), the chest as the bonus
function QuestRules.weekView(state: Week, cfg: Config): View
	local quests: { QuestView } = {}
	for _, quest in state.list do
		local entry = entryOf(cfg, quest.id)
		if entry then
			table.insert(quests, rowOf(entry, quest, 0, 0))
		end
	end
	local ready = QuestRules.chestReady(state)
	return { quests = quests, bonusReady = ready, bonusClaimed = state.chest, claimable = if ready then 1 else 0 }
end

-- Seconds until the next week: Monday 00:00 UTC (GiftRules.weekOf's weeks: day 0, 1970-01-01, was a Thursday)
function QuestRules.weekLeft(now: number): number
	local week = math.floor((math.floor(now / DAY) + 3) / 7)
	return (week * 7 + 4) * DAY - now
end

-- "4 days left", "1 day left", "9h left", "12m left"
function QuestRules.weekLeftText(now: number): string
	local left = QuestRules.weekLeft(now)
	local days = left // DAY
	if days >= 2 then
		return `{days} days left`
	elseif days == 1 then
		return "1 day left"
	end
	local hours = left // 3600
	if hours >= 1 then
		return `{hours}h left`
	end
	return `{math.max(1, left // 60)}m left`
end

-- What the strip shows (look A): today's quests until today's chest is opened, then the week's until its chest is
-- opened too, then all done
function QuestRules.stripMode(view: View): StripMode
	if not view.bonusClaimed then
		return "daily"
	end
	local week = view.week
	if week and #week.quests > 0 and not week.bonusClaimed then
		return "weekly"
	end
	return "done"
end

-- The band's pieces: on a computer the title, Claim! while something waits, the count (not beside the week's Claim!)
-- and the arrow that folds the rows; a phone's chip by the cash only its scroll and one chip, the count or Claim! (owner
-- 2026-11-17, "go A" of artifact GtT4bM87otu1aayFVANr7z; its arrow only ever hid the title: "clicking on the quest
-- arrow in mobile doesnt do anything")
function QuestRules.bandParts(compact: boolean, claimable: boolean, weekly: boolean): BandParts
	if compact then
		return { title = false, claim = claimable, count = not claimable, fold = false }
	end
	return { title = true, claim = claimable, count = not (claimable and weekly), fold = true }
end

-- The Quests window (owner 2026-11-21: "improve quest window UI. easily understandable/immersive") ----------------

-- What a quest's row offers: "claim" (finished, its pay waits), "claimed", "done" (a weekly one finished: its chest
-- pays), or "going"
function QuestRules.rowState(quest: QuestView, weekly: boolean): string
	if weekly then
		return if quest.done then "done" else "going"
	end
	if quest.claimed then
		return "claimed"
	end
	return if quest.done then "claim" else "going"
end

-- A row's three columns for a card `width` px wide (Config/Quests WINDOW.ROW or MAIN): the picture tile at `iconX`,
-- the middle (words, bar, pay) from `middleX`, `middleW` wide, and the action column from `actionX`, `actionW` wide,
-- with the look's gap between each (owner 2026-11-20: the bar ran into the button)
export type RowBox = { iconX: number, middleX: number, middleW: number, actionX: number, actionW: number }
function QuestRules.rowBox(width: number, look: { pad: number, icon: number, gap: number, action: number }): RowBox
	local middleX = look.pad + look.icon + look.gap
	local actionX = width - look.pad - look.action
	return { iconX = look.pad, middleX = middleX, middleW = actionX - look.gap - middleX, actionX = actionX, actionW = look.action }
end

-- What a row's action column says where no button stands: how far the quest is while it's going, "Claimed" or (a
-- weekly one) "Done" after; nil while its Claim button is there
function QuestRules.actionWords(quest: QuestView, weekly: boolean): string?
	local state = QuestRules.rowState(quest, weekly)
	if state == "claim" then
		return nil
	end
	return if state == "claimed" then "Claimed" elseif state == "done" then "Done" else QuestRules.countText(quest)
end

-- "3 / 8" beside a quest's name
function QuestRules.countText(quest: QuestView): string
	return `{math.min(quest.progress, quest.goal)} / {quest.goal}`
end

-- A quest's pay as chips (a picture from Config/UIIcons and a few words): cash and shop XP, or the Weekly Chest
function QuestRules.pay(quest: QuestView, weekly: boolean): { { icon: string, text: string } }
	if weekly then
		return { { icon = "Gift", text = "Weekly Chest" } }
	end
	return { { icon = "Coin", text = `${quest.cash}` }, { icon = "Level", text = `{quest.xp} XP` } }
end

-- A section's heading words: how many of its quests are done
function QuestRules.sectionLine(view: View): string
	local done = 0
	for _, quest in view.quests do
		done += if quest.done then 1 else 0
	end
	return if done >= #view.quests then "All done!" else `{done} of {#view.quests} done`
end

-- How many quests still stand between you and a section's chest: the day's needs each one claimed, the week's each
-- one done
function QuestRules.chestLeft(view: View, weekly: boolean): number
	local left = 0
	for _, quest in view.quests do
		if weekly then
			left += if quest.done then 0 else 1
		else
			left += if quest.claimed then 0 else 1
		end
	end
	return left
end

function QuestRules.chestWaiting(left: number): string
	return if left <= 0 then "Ready!" else `{left} more to go`
end

return QuestRules
