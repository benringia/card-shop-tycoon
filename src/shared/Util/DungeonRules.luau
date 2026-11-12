--!strict
-- The Dungeon run's rules (spec 2026-10-29-dungeon-final-boss-design.md): creatures keep their HP from room to room
-- (hpLeft: beast id -> HP at the end of its last fight this run; absent = never fought, fresh), a creature at 0 is out
-- for the rest of the run even once its normal rest is over, and a player whose whole party is down is out. Pure (no
-- requires, no Roblox APIs) so tests/ run it in Lune; DungeonService keeps each player's hpLeft (never saved).
local DungeonRules = {}

-- Whether this creature may still fight in this run
function DungeonRules.canFight(hpLeft: { [string]: number }, beastId: string): boolean
	local hp = hpLeft[beastId]
	return hp == nil or hp > 0
end

-- hpLeft after a fight: what the fight reported wins, the rest is kept (a new table)
function DungeonRules.merge(hpLeft: { [string]: number }, ended: { [string]: number }): { [string]: number }
	local out = table.clone(hpLeft)
	for beastId, hp in ended do
		out[beastId] = hp
	end
	return out
end

-- Whether this player is out of the run: none of their party cards can fight (an empty party is out too)
function DungeonRules.isOut(hpLeft: { [string]: number }, partyIds: { string }): boolean
	for _, beastId in partyIds do
		if DungeonRules.canFight(hpLeft, beastId) then
			return false
		end
	end
	return true
end

-- How many players this run waits for: the teleport's runSize, a whole number from 1 to max (1 when it's missing or
-- junk, e.g. in Studio)
function DungeonRules.expectedSize(data: unknown, max: number): number
	local size = if typeof(data) == "table" then (data :: any).runSize else nil
	if typeof(size) ~= "number" or size ~= math.floor(size) or size < 1 then
		return 1
	end
	return math.min(size, max)
end

-- At a gate: a member whose save hasn't loaded yet sits this fight out ("skip", still in the run); one with no
-- creature left that can fight is out ("out"); everyone else goes in ("fight")
function DungeonRules.gateCheck(loaded: boolean, ready: boolean): "fight" | "skip" | "out"
	if not loaded then
		return "skip"
	end
	return if ready then "fight" else "out"
end

-- Whether a fight's result means the player left the run (ran or left; BattleService's "run"). A loss or the time
-- limit ("timeout") doesn't: their creatures' HP carries on and only a party that is all down is out.
function DungeonRules.leftRun(result: string): boolean
	return result == "run"
end

-- Whether players may change their party: not once the run's first fight has started (the party wears down room by
-- room; fresh cards from the binder would skip that)
function DungeonRules.canChangeParty(fought: boolean): boolean
	return not fought
end

-- Whether the run's rooms open: everyone the teleport brought has loaded, or the wait for a player who never comes
-- (a failed teleport) is over and at least one is here
function DungeonRules.readyToStart(arrived: number, expected: number, waited: number, maxWait: number): boolean
	return arrived >= 1 and (arrived >= expected or waited >= maxWait)
end

-- Where /room n lands (Studio): a whole room number from 1 to rooms + 1 (rooms + 1: the boss's chamber)
function DungeonRules.skipRoom(room: number, rooms: number): number
	return math.clamp(math.floor(room), 1, rooms + 1)
end

type Step = { kind: string, room: number? }

-- Whether room `room`'s gate may start its fight: its fight is the next step (`done` steps of Config/Dungeon STEPS done)
function DungeonRules.canStartRoom(steps: { Step }, done: number, room: number): boolean
	local step = steps[done + 1]
	return step ~= nil and step.kind == "fight" and step.room == room
end

-- Whether the Prism Hydra's chamber is open: every step done
function DungeonRules.chamberOpen(steps: { Step }, done: number): boolean
	return done >= #steps
end

-- The current step's kind ("fight", "beams", "plates", "lock"), "boss" past the last
function DungeonRules.stepKind(steps: { Step }, done: number): string
	local step = steps[done + 1]
	return if step then step.kind else "boss"
end

-- Steps done when /room n (Studio) skips to room n's gate: every step before its fight (past the last room: all)
function DungeonRules.doneBefore(steps: { Step }, room: number): number
	for index, step in steps do
		if step.kind == "fight" and step.room == room then
			return index - 1
		end
	end
	return #steps
end

-- Where a step of this kind sits in the run (its index in Config/Dungeon STEPS), nil when there's none
function DungeonRules.stepIndex(steps: { Step }, kind: string): number?
	for index, step in steps do
		if step.kind == kind then
			return index
		end
	end
	return nil
end

-- The welcome a player gets when the run opens: the full one the first time ever, the short one after
function DungeonRules.introKind(seen: boolean): "full" | "short"
	return if seen then "short" else "full"
end

-- Whether a player may work a puzzle piece or open a chest: a run member who isn't out
function DungeonRules.canAct(isMember: boolean, isOut: boolean): boolean
	return isMember and not isOut
end

-- True the first time this player (UserId) does it this run (a chest), marking it; false after
function DungeonRules.once(opened: { [number]: boolean }, userId: number): boolean
	if opened[userId] then
		return false
	end
	opened[userId] = true
	return true
end

-- The secret chest's prize: the title on a player's first find ever, then the material on a roll under `chance`, else cash
function DungeonRules.secretPrize(foundBefore: boolean, roll: number, chance: number): "title" | "material" | "cash"
	if not foundBefore then
		return "title"
	end
	return if roll < chance then "material" else "cash"
end

-- A room's pack: `count` species names, cycling through the room's list from a seeded start (mixed elements)
function DungeonRules.pack(room: { species: { string }, count: number, level: number }, seed: number): { string }
	local names = {}
	local start = math.abs(math.floor(seed)) % math.max(1, #room.species)
	for index = 1, room.count do
		table.insert(names, room.species[(start + index - 1) % #room.species + 1])
	end
	return names
end

-- Where a room's pack rises (owner 2026-11-12: "spawn in a different side of the arena, not sticking together"):
-- `count` spots `radius` studs round the ring's middle, spread over its far side from the gate (the gate is at -x),
-- each a little in or out and to the side; offsets (x, z) from the ring's middle, the same for a seed
function DungeonRules.packSpots(count: number, radius: number, seed: number): { { x: number, z: number } }
	local spots = {}
	local state = math.abs(math.floor(seed)) % 2147483646 + 1
	local function roll(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	local arc = math.rad(160) -- the far half, its ends clear of the gate's side
	for index = 1, count do
		local angle = if count == 1 then 0 else -arc / 2 + (index - 1) / (count - 1) * arc
		angle += (roll() - 0.5) * math.rad(16)
		local reach = radius * (0.88 + roll() * 0.24)
		table.insert(spots, { x = math.cos(angle) * reach, z = math.sin(angle) * reach })
	end
	return spots
end

return DungeonRules
