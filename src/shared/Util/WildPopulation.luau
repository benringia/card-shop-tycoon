--!strict
-- How many monsters a Wild valley zone keeps (round 2 spec): QUIET while few players are in it, PER_PLAYER more for each
-- player past FREE_PLAYERS, up to MAX; respawns quicker while it wants more than QUIET. A crowd leaving removes
-- nothing: the extras just aren't respawned as they're beaten. Pure, Lune-tested; numbers in Config/WildValley POPULATION.
local WildPopulation = {}

function WildPopulation.target(cfg: any, players: number): number
	return math.clamp(cfg.QUIET + cfg.PER_PLAYER * math.max(0, players - cfg.FREE_PLAYERS), cfg.QUIET, cfg.MAX)
end

-- Seconds a beaten monster waits to come back ({ min, max })
function WildPopulation.respawnRange(cfg: any, target: number): { number }
	return if target > cfg.QUIET then cfg.RESPAWN_BUSY else cfg.RESPAWN_QUIET
end

-- How many more to schedule: never below zero, so a crowd leaving removes nothing
function WildPopulation.deficit(target: number, alive: number, pending: number): number
	return math.max(0, target - alive - pending)
end

-- The spot indexes (1..total) nobody holds, ascending
function WildPopulation.freeSpots(total: number, taken: { [number]: boolean }): { number }
	local free = {}
	for index = 1, total do
		if not taken[index] then
			table.insert(free, index)
		end
	end
	return free
end

return WildPopulation
