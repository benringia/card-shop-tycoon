--!strict
-- The boss ladder's rules (Config/Bosses): whether a boss can be started, whether a win gives full loot, and how much
-- the farm protection shrinks its drops. Pure (no requires, no Roblox APIs): callers pass the config in, so tests/ can
-- run it in Lune. BossService keeps each player's records (saved).
local BossRules = {}

-- One player's progress on one boss
export type Record = {
	unlocked: boolean, -- its key was used (or it's open from the start)
	cleared: boolean, -- first clear done (trophy given)
	lootAt: number, -- Unix time full loot is available again
	day: number, -- UTC day number of rewardedToday
	rewardedToday: number, -- rewarded kills that day (the soft cap)
	bonusDay: number, -- UTC day the daily bonus chest was last given
}
type Config = { SOFT_CAP_AFTER: number, SOFT_CAP_STEP: number, SOFT_CAP_FLOOR: number, OVERPOWER_RATIO: number, OVERPOWER_FACTOR: number }

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value >= 0 and value ~= math.huge then math.floor(value) else 0
end

-- A saved record made safe; startsOpen: the boss needs no key
function BossRules.read(saved: unknown, startsOpen: boolean): Record
	local data: any = if typeof(saved) == "table" then saved else {}
	return {
		unlocked = startsOpen or data.unlocked == true,
		cleared = data.cleared == true,
		lootAt = readCount(data.lootAt),
		day = readCount(data.day),
		rewardedToday = readCount(data.rewardedToday),
		bonusDay = readCount(data.bonusDay),
	}
end

-- The saved bosses table: these records over what was saved, keeping records of bosses this server doesn't know
-- (a newer server added them), so an older server never drops their progress
function BossRules.write(saved: unknown, records: { [string]: Record }): { [string]: any }
	local out: { [string]: any } = {}
	if typeof(saved) == "table" then
		for bossId, entry in saved :: { [any]: any } do
			if typeof(bossId) == "string" and typeof(entry) == "table" then
				out[bossId] = table.clone(entry)
			end
		end
	end
	for bossId, record in records do
		out[bossId] = table.clone(record)
	end
	return out
end

function BossRules.dayNumber(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- The record with today's counts (a new UTC day starts them from zero)
function BossRules.dayCounts(record: Record, today: number): Record
	if record.day == today then
		return record
	end
	local copy = table.clone(record)
	copy.day = today
	copy.rewardedToday = 0
	return copy
end

-- Whether the boss can be started: unlocked already, or the player owns the fragments its key needs
-- (reason "locked:<have>:<need>")
function BossRules.canStart(record: Record, unlock: { item: string, count: number }?, owned: number): (boolean, string?)
	if record.unlocked or not unlock then
		return true, nil
	end
	if owned >= unlock.count then
		return true, nil
	end
	return false, `locked:{owned}:{unlock.count}`
end

function BossRules.lootEligible(record: Record, now: number): boolean
	return now >= record.lootAt
end

-- Drop chances times this after SOFT_CAP_AFTER rewarded kills today: STEP per extra kill, never under FLOOR
function BossRules.softCapFactor(config: Config, rewardedToday: number): number
	if rewardedToday < config.SOFT_CAP_AFTER then
		return 1
	end
	return math.max(config.SOFT_CAP_FLOOR, config.SOFT_CAP_STEP ^ (rewardedToday - config.SOFT_CAP_AFTER + 1))
end

-- Drop chances times this when the party is far stronger than the boss
function BossRules.overPowerFactor(config: Config, partyPower: number, recommended: number): number
	return if partyPower > recommended * config.OVERPOWER_RATIO then config.OVERPOWER_FACTOR else 1
end

function BossRules.dropFactor(config: Config, record: Record, partyPower: number, recommended: number): number
	return BossRules.softCapFactor(config, record.rewardedToday) * BossRules.overPowerFactor(config, partyPower, recommended)
end

return BossRules
