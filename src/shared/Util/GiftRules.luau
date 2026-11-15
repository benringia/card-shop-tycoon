--!strict
-- Daily, weekly and monthly gifts' rules (spec 2026-11-15-daily-gifts-design, Config/Gifts): UTC days, weeks from
-- Monday and months from the day number, play time per day, what's claimable, claiming, and the gifts in words. The
-- server (GiftService) decides with them; the client (GiftController) draws their view. Pure (no requires, no Roblox
-- APIs): callers pass Config/Gifts, Config/Items and Config/Luck in.
local GiftRules = {}

local SECONDS_PER_DAY = 86400

export type Grant = { item: string, count: number }
export type Reward = { cash: number?, items: { Grant }?, luck: { strength: string, seconds: number }? }
export type Config = {
	PLAY_SECONDS: number,
	DAILY: { Reward },
	WEEKLY: { days: number, reward: Reward },
	MONTHLY: { days: number, overrides: { [number]: number }, reward: Reward },
}
export type Kind = "daily" | "weekly" | "monthly"

-- What's saved (data.gifts)
export type State = {
	streak: number, -- daily gifts claimed in this 7-day round (0-6): the next one is DAILY[streak + 1]
	lastDay: number, -- the UTC day of the last daily gift (-1: never)
	playDay: number, -- the UTC day `played` counts for
	played: number, -- seconds played that day (counted once the first visit is done)
	week: number, -- the week `weekDays` counts for
	weekDays: number, -- daily gifts claimed that week
	weekEarned: boolean, -- a weekly chest waiting to be opened
	month: number, -- the month (year * 100 + month) `monthDays` counts for
	monthDays: number,
	monthEarned: boolean,
	claims: number, -- daily gifts ever claimed
}

-- What the client draws
export type View = {
	day: number, -- today's tile (1-7): the one to claim, or the one claimed today
	claimedToday: boolean,
	ready: boolean, -- today's gift can be claimed
	secondsLeft: number, -- play time left before it (0 once ready or claimed)
	weekDays: number,
	weekTarget: number,
	weekEarned: boolean,
	monthDays: number,
	monthTarget: number,
	monthEarned: boolean,
}

-- Chests earned by a daily claim (they play right after its win moment)
export type Earned = { week: boolean, month: boolean }

-- A gift as a line on its card: the picture (a Config/UIIcons name or an emoji), its words, the item (packs: OPEN IT
-- NOW! opens it from the Bag)
export type Line = { icon: string, text: string, item: string?, pack: boolean }

function GiftRules.dayOf(time: number): number
	return math.floor(time / SECONDS_PER_DAY)
end

-- Weeks start on Monday: day 0 (1970-01-01) was a Thursday
function GiftRules.weekOf(day: number): number
	return math.floor((day + 3) / 7)
end

-- year * 100 + month of a UTC day (the civil-from-days count, so no clock or time zone is involved)
function GiftRules.monthOf(day: number): number
	local z = day + 719468
	local era = math.floor(z / 146097)
	local dayOfEra = z - era * 146097
	local yearOfEra = math.floor((dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365)
	local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
	local shifted = math.floor((5 * dayOfYear + 2) / 153) -- months from March
	local month = if shifted < 10 then shifted + 3 else shifted - 9
	local year = yearOfEra + era * 400 + (if month <= 2 then 1 else 0)
	return year * 100 + month
end

function GiftRules.monthTarget(cfg: Config, month: number): number
	return cfg.MONTHLY.overrides[month] or cfg.MONTHLY.days
end

function GiftRules.fresh(): State
	return {
		streak = 0,
		lastDay = -1,
		playDay = -1,
		played = 0,
		week = -1,
		weekDays = 0,
		weekEarned = false,
		month = -1,
		monthDays = 0,
		monthEarned = false,
		claims = 0,
	}
end

local function whole(value: any, fallback: number, low: number, high: number): number
	if typeof(value) ~= "number" or value ~= value then
		return fallback
	end
	local floored = math.floor(value)
	return if floored < low or floored > high then fallback else floored
end

-- A saved state, every field checked (a missing or broken one starts fresh)
function GiftRules.clean(saved: any): State
	local state = GiftRules.fresh()
	if typeof(saved) ~= "table" then
		return state
	end
	local huge = 2 ^ 40
	state.streak = whole(saved.streak, 0, 0, 6)
	state.lastDay = whole(saved.lastDay, -1, -1, huge)
	state.playDay = whole(saved.playDay, -1, -1, huge)
	state.played = whole(saved.played, 0, 0, huge)
	state.week = whole(saved.week, -1, -1, huge)
	state.weekDays = whole(saved.weekDays, 0, 0, 7)
	state.weekEarned = saved.weekEarned == true
	state.month = whole(saved.month, -1, -1, huge)
	state.monthDays = whole(saved.monthDays, 0, 0, 31)
	state.monthEarned = saved.monthEarned == true
	state.claims = whole(saved.claims, 0, 0, huge)
	return state
end

-- The state on `day`: a new day starts its play time over, a new week or month its bar (an earned chest stays)
function GiftRules.refresh(state: State, day: number): State
	local now = table.clone(state)
	if now.playDay ~= day then
		now.playDay = day
		now.played = 0
	end
	local week = GiftRules.weekOf(day)
	if now.week ~= week then
		now.week = week
		now.weekDays = 0
	end
	local month = GiftRules.monthOf(day)
	if now.month ~= month then
		now.month = month
		now.monthDays = 0
	end
	return now
end

-- `seconds` more play on `day`
function GiftRules.addPlay(state: State, day: number, seconds: number): State
	local now = GiftRules.refresh(state, day)
	now.played += math.max(seconds, 0)
	return now
end

function GiftRules.view(state: State, day: number, cfg: Config): View
	local now = GiftRules.refresh(state, day)
	local claimedToday = now.lastDay == day
	-- the round's next tile, or today's claimed one (the streak has already moved past it)
	local index = if claimedToday then (now.streak - 1) % #cfg.DAILY + 1 else now.streak + 1
	local left = if claimedToday then 0 else math.max(cfg.PLAY_SECONDS - now.played, 0)
	return {
		day = index,
		claimedToday = claimedToday,
		ready = not claimedToday and left == 0,
		secondsLeft = math.ceil(left),
		weekDays = now.weekDays,
		weekTarget = cfg.WEEKLY.days,
		weekEarned = now.weekEarned,
		monthDays = now.monthDays,
		monthTarget = GiftRules.monthTarget(cfg, now.month),
		monthEarned = now.monthEarned,
	}
end

-- Whether `kind` can be claimed on `day`, and why not: "claimed" (today's is done), "wait" (more play first),
-- "notEarned" (the chest's days aren't reached)
function GiftRules.canClaim(state: State, kind: Kind, day: number, cfg: Config): (boolean, string?)
	local view = GiftRules.view(state, day, cfg)
	if kind == "daily" then
		if view.claimedToday then
			return false, "claimed"
		end
		return view.ready, if view.ready then nil else "wait"
	elseif kind == "weekly" then
		return view.weekEarned, if view.weekEarned then nil else "notEarned"
	elseif kind == "monthly" then
		return view.monthEarned, if view.monthEarned then nil else "notEarned"
	end
	return false, "unknown"
end

-- Claims `kind` on `day` (check canClaim first): the new state, its gift and the chests this claim earned
function GiftRules.claim(state: State, kind: Kind, day: number, cfg: Config): (State, Reward, Earned)
	local now = GiftRules.refresh(state, day)
	local earned = { week = false, month = false }
	if kind == "weekly" then
		now.weekEarned = false
		return now, cfg.WEEKLY.reward, earned
	elseif kind == "monthly" then
		now.monthEarned = false
		return now, cfg.MONTHLY.reward, earned
	end
	local reward = cfg.DAILY[now.streak + 1]
	now.streak = (now.streak + 1) % #cfg.DAILY
	now.lastDay = day
	now.claims += 1
	now.weekDays += 1
	if now.weekDays == cfg.WEEKLY.days then
		now.weekEarned = true
		earned.week = true
	end
	now.monthDays += 1
	if now.monthDays == GiftRules.monthTarget(cfg, now.month) then
		now.monthEarned = true
		earned.month = true
	end
	return now, reward, earned
end

-- "$1,000"
local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return "$" .. grouped
end

-- A gift's lines on its card, in order: cash, items, luck
function GiftRules.lines(reward: Reward, items: any, luck: any): { Line }
	local lines: { Line } = {}
	if reward.cash and reward.cash > 0 then
		table.insert(lines, { icon = "Cash", text = money(reward.cash), pack = false })
	end
	for _, grant in reward.items or {} do
		local info = items.ITEMS[grant.item]
		local name = if info then info.name else grant.item
		table.insert(lines, {
			icon = if info then info.icon else "Gift",
			text = if grant.count > 1 then `{name} x{grant.count}` else name,
			item = grant.item,
			pack = info ~= nil and info.open ~= nil,
		})
	end
	if reward.luck then
		local strength = luck.STRENGTHS[reward.luck.strength]
		local name = if strength then strength.name else reward.luck.strength
		table.insert(lines, {
			icon = if strength then strength.icon else "🍀",
			text = `{math.floor(reward.luck.seconds / 60)} min {name}`,
			pack = false,
		})
	end
	return lines
end

return GiftRules
