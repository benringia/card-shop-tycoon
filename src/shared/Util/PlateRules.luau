--!strict
-- The Dungeon's weight plates (spec 2026-11-11-dungeon-puzzles): the door opens once every plate needed is held at
-- the same time (then stays open). A plate is held by a run member standing on it or by a member's creature sent
-- there (DungeonPuzzleService reads both positions on the server). A run never needs more plates than the players
-- still in it can cover: each one stands on one and sends their creature to another. Pure (no requires) for Lune.
local PlateRules = {}

export type Box = { x: number, z: number, half: number }
export type Point = { x: number, z: number }

-- Plates in the room for a run of `runSize` players (config: Config/Dungeon PLATES)
function PlateRules.count(runSize: number, config: { SOLO: number, GROUP: number, GROUP_FROM: number }): number
	return if runSize >= config.GROUP_FROM then config.GROUP else config.SOLO
end

-- Plates that must be held with `active` players still in the run (the rest dim)
function PlateRules.needed(plates: number, active: number): number
	return math.min(plates, 2 * math.max(0, active))
end

-- Whether a point (a character's root or a creature's marker) stands on a plate's square
function PlateRules.inside(box: Box, point: Point): boolean
	return math.abs(point.x - box.x) <= box.half and math.abs(point.z - box.z) <= box.half
end

-- Whether the door opens: the first `needed` plates all held (none needed: never by itself)
function PlateRules.open(held: { boolean }, needed: number): boolean
	if needed <= 0 then
		return false
	end
	for index = 1, needed do
		if not held[index] then
			return false
		end
	end
	return true
end

return PlateRules
