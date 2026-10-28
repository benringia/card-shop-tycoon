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
type GroupConfig = { GROUP_MAX: number, GROUP_HP_STEP: number, GROUP_ATK_STEP: number, GROUP_SWINGS_STEP: number, CONTRIBUTION_DAMAGE: number, CONTRIBUTION_TANK: number, CARRIED_FACTOR: number }

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

-- Whether a fight's end may drop its arena's wall: not when a newer fight there already sealed it (the end handlers
-- run deferred, so a new fight can start in between). `occupant` is the arena's current boss, if any.
function BossRules.shouldUnseal(ended: { alive: boolean }, occupant: { alive: boolean }?): boolean
	return occupant == nil or occupant == ended or not occupant.alive
end

local ID_MAX_LENGTH = 64 -- drop ids are GUIDs (36 characters); anything longer is junk

-- A client's list of drop ids made safe: distinct strings, a plain array of 1 to `max` (nil when it isn't)
function BossRules.readIds(raw: unknown, max: number): { string }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local list = raw :: { [any]: any }
	local count = 0
	for _ in list do
		count += 1
	end
	if count == 0 or count > max or #list ~= count then
		return nil
	end
	local ids, seen = {}, {}
	for _, id in ipairs(list) do
		if typeof(id) ~= "string" or #id > ID_MAX_LENGTH then
			return nil
		end
		if not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	return ids
end

-- Whether a player's shop level reaches the level a boss needs (the board shows it, BossService enforces it)
function BossRules.levelReady(shopLevel: number, level: number): boolean
	return level >= shopLevel
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

-- A boss's HP and ATK for a group of `size` players (1 = as configured)
-- A boss against `size` players: more HP and ATK, and it hits more creatures per attack (swings), never more than
-- there are players
-- atkStep: the boss's own ATK step per extra player (nil: the config's)
function BossRules.groupStats(config: GroupConfig, hp: number, atk: number, size: number, atkStep: number?): (number, number, number)
	local extra = math.max(0, size - 1)
	local swings = math.min(size, 1 + math.floor(config.GROUP_SWINGS_STEP * extra))
	return math.round(hp * (1 + config.GROUP_HP_STEP * extra)), math.round(atk * (1 + (atkStep or config.GROUP_ATK_STEP) * extra)), math.max(1, swings)
end

-- Whether a member helped enough for full loot: a share of the group's damage or of the hits it took (a share of
-- nothing counts as full)
function BossRules.contributed(config: GroupConfig, dealt: number, taken: number, totalDealt: number, totalTaken: number): boolean
	local dealtShare = if totalDealt > 0 then dealt / totalDealt else 1
	local takenShare = if totalTaken > 0 then taken / totalTaken else 1
	return dealtShare >= config.CONTRIBUTION_DAMAGE or takenShare >= config.CONTRIBUTION_TANK
end

-- A carried member's chance at a drop: a fraction of it, never a fragment
function BossRules.carriedDrop(config: GroupConfig, _item: string, chance: number, isFragment: boolean): number
	return if isFragment then 0 else chance * config.CARRIED_FACTOR
end

-- The arena barrier: centre angles (radians) of evenly spaced wall pieces at most maxWidth wide that close the ring
function BossRules.ringSegments(radius: number, maxWidth: number): { number }
	local count = math.max(3, math.ceil(2 * math.pi * radius / maxWidth))
	local angles = {}
	for index = 0, count - 1 do
		table.insert(angles, index * 2 * math.pi / count)
	end
	return angles
end

-- Whether a spot (offset from the arena's centre) is inside its sealed ring, wall line included
function BossRules.insideRing(dx: number, dz: number, radius: number): boolean
	return dx * dx + dz * dz <= (radius + 1) ^ 2
end

-- Where each of `count` drops lands round the boss (offsets in studs): evenly round the circle from angle `turn`,
-- every other one on the inner and outer radius so neighbours never land on each other
function BossRules.scatter(count: number, minRadius: number, maxRadius: number, turn: number): { { x: number, z: number } }
	local spots = {}
	for index = 1, count do
		local angle = turn + (index - 1) * 2 * math.pi / count
		local radius = if index % 2 == 1 then minRadius else maxRadius
		table.insert(spots, { x = math.cos(angle) * radius, z = math.sin(angle) * radius })
	end
	return spots
end

-- The gate's group prompt: open a group, join one, or (its leader) start it now. The server sets the text everyone
-- sees; the leader's client swaps in its own.
function BossRules.groupPromptText(config: GroupConfig, members: number, isLeader: boolean): string
	if members <= 0 then
		return "Start group"
	end
	return `{if isLeader then "Start now" else "Join group"} ({members}/{config.GROUP_MAX})`
end

return BossRules
