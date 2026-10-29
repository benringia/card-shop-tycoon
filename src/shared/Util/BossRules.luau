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

-- The phase a boss with phases is in at this HP share (phases[i] is active below phases[i].below; the first has
-- below = 1). Never earlier than `current`: a heal doesn't take a boss back a phase.
function BossRules.phaseAt(phases: { { below: number } }, share: number, current: number): number
	local index = current
	for i, phase in phases do
		if i > index and share < phase.below then
			index = i
		end
	end
	return index
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

-- One boss on the board's ladder, as the player stands now. keyNeeded: fragments that open it (0: none)
export type Step = {
	cleared: boolean,
	unlocked: boolean,
	keyNeeded: number,
	fragments: number,
	shopLevel: number,
	needLevel: number,
	power: number,
	recommended: number,
}

-- beaten; ready (you can start it now, fragments in hand count, and your Power is enough); tooWeak (you can start
-- it but your Power is short); locked (shop level or fragments short)
function BossRules.stepState(step: Step): "beaten" | "ready" | "tooWeak" | "locked"
	if step.cleared then
		return "beaten"
	end
	if step.shopLevel < step.needLevel then
		return "locked"
	end
	if not step.unlocked and step.fragments < step.keyNeeded then
		return "locked"
	end
	return if step.power >= step.recommended then "ready" else "tooWeak"
end

-- What keeps a boss shut on the board: the shop level first, then its key fragments; nil when neither does
function BossRules.lockReason(step: Step): ("level" | "keys")?
	if step.cleared then
		return nil
	end
	if step.shopLevel < step.needLevel then
		return "level"
	end
	if not step.unlocked and step.fragments < step.keyNeeded then
		return "keys"
	end
	return nil
end

-- The elements strong against `element` on the element wheel (Config/Combat BEATS), sorted
function BossRules.counterElements(beats: { [string]: { string } }, element: string): { string }
	local counters = {}
	for attacker, beaten in beats do
		if table.find(beaten, element) then
			table.insert(counters, attacker)
		end
	end
	table.sort(counters)
	return counters
end

-- Rewarded wins left today at full drop chances (the soft cap)
function BossRules.fullDropsLeft(config: Config, rewardedToday: number): number
	return math.max(0, config.SOFT_CAP_AFTER - rewardedToday)
end

local function percent(share: number): string
	return `{math.max(1, math.round(share * 100))}%`
end

-- A drop's chance as the board shows it (never 0%)
function BossRules.chanceText(chance: number): string
	return percent(chance)
end

function BossRules.countText(min: number, max: number): string
	return if min == max then `x{min}` else `x{min}-{max}`
end

type Trick = { kind: string, name: string, text: string }
type TrickBoss = {
	mechanics: {
		heal: { below: number, fraction: number, uses: number? }?,
		enrage: { below: number, atkMultiplier: number }?,
		shield: { every: number, breakStun: number }?,
		thunderclap: { every: number }?,
		adds: { at: { number }, count: number, species: string }?,
	},
	phases: { { element: string } }?,
}

-- A boss's tricks (its mechanics, or its phases) in the board's kid words, in a fixed order
function BossRules.watchOut(boss: TrickBoss): { Trick }
	local tricks: { Trick } = {}
	if boss.phases then
		local elements = {}
		for _, phase in boss.phases do
			table.insert(elements, phase.element)
		end
		local first = table.remove(elements, 1)
		local text = `As it gets hurt: {first}, then {table.concat(elements, ", ")}. Each part fights like an earlier boss.`
		table.insert(tricks, { kind = "phases", name = "Changes element", text = text })
		return tricks
	end
	local mechanics = boss.mechanics
	local shield = mechanics.shield
	if shield then
		local text = `Puts up a shield every {shield.every} s. Break it to stun it for {shield.breakStun} s.`
		table.insert(tricks, { kind = "shield", name = "Shield", text = text })
	end
	local clap = mechanics.thunderclap
	if clap then
		local text = `Stuns your cards every {clap.every} s. Faster cards shake it off sooner.`
		table.insert(tricks, { kind = "thunderclap", name = "Thunderclap", text = text })
	end
	local adds = mechanics.adds
	if adds then
		local shares = {}
		for _, share in adds.at do
			table.insert(shares, percent(share))
		end
		local who = if adds.count == 1 then `1 {adds.species}` else `{adds.count} {adds.species}s`
		local text = `Calls {who} at {table.concat(shares, " and ")} health. Beat them first: it's tougher while they stand.`
		table.insert(tricks, { kind = "adds", name = "Helpers", text = text })
	end
	local heal = mechanics.heal
	if heal then
		local times = if heal.uses then ` ({heal.uses} {if heal.uses == 1 then "time" else "times"})` else ""
		local text = `Heals {percent(heal.fraction)} of its health when under {percent(heal.below)}{times}.`
		table.insert(tricks, { kind = "heal", name = "Heals", text = text })
	end
	local enrage = mechanics.enrage
	if enrage then
		local text = `Hits {enrage.atkMultiplier}x harder when under {percent(enrage.below)} health.`
		table.insert(tricks, { kind = "enrage", name = "Gets angry", text = text })
	end
	return tricks
end

-- Whether the board spells out a boss's tricks: a surprise only for locked bosses past the next one to beat
function BossRules.revealTricks(step: "beaten" | "ready" | "tooWeak" | "locked", isNext: boolean): boolean
	return step ~= "locked" or isNext
end

-- What the board's travel button does for a boss whose arena is in bossPlace ("Wild" | "Frontier" | "Dungeon")
-- while you are in `here` ("Main" | "Frontier" | "Dungeon"): its gate in this place, the normal travel to the other
-- place, the Dungeon portal's directions, or nothing (inside a Dungeon run)
function BossRules.travelChoice(bossPlace: string, here: string): "gate" | "toFrontier" | "toMain" | "viaPortal" | "none"
	if here == "Dungeon" then
		return "none"
	end
	if bossPlace == "Dungeon" then
		return "viaPortal"
	end
	if (bossPlace == "Wild" and here == "Main") or (bossPlace == "Frontier" and here == "Frontier") then
		return "gate"
	end
	return if bossPlace == "Frontier" then "toFrontier" else "toMain"
end

return BossRules
