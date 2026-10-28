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

-- A room's pack: `count` species names, cycling through the room's list from a seeded start (mixed elements)
function DungeonRules.pack(room: { species: { string }, count: number, level: number }, seed: number): { string }
	local names = {}
	local start = math.abs(math.floor(seed)) % math.max(1, #room.species)
	for index = 1, room.count do
		table.insert(names, room.species[(start + index - 1) % #room.species + 1])
	end
	return names
end

return DungeonRules
