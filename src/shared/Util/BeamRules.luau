--!strict
-- The Dungeon's prism beams (spec 2026-11-11-dungeon-puzzles): a beam leaves the gem across a grid of cells and must
-- reach the door's prism. Crystal mirrors turn it: a mirror with facing f connects sides f and (f + 1) % 4 of its cell
-- (side s lies in direction s from the centre: 0 +x, 1 +y, 2 -x, 3 -y). A beam coming in through one of those sides
-- leaves through the other; through any other side it hits the mirror's back and stops there. Off the grid it stops
-- at the last cell. Pure (no requires, no Roblox APIs) so tests/ run it in Lune; DungeonPuzzleService traces on the
-- server and clients draw the path it publishes.
local BeamRules = {}

export type Cell = { x: number, y: number }
export type Mirror = { x: number, y: number, facing: number }
export type Layout = { width: number, height: number, gem: { x: number, y: number, dir: number }, prism: Cell, mirrors: { Mirror } }
export type Trace = { path: { Cell }, reached: boolean }

local STEP_X = { [0] = 1, [1] = 0, [2] = -1, [3] = 0 }
local STEP_Y = { [0] = 0, [1] = 1, [2] = 0, [3] = -1 }

-- A mirror after one tap: a quarter turn
function BeamRules.turn(facing: number): number
	return (facing + 1) % 4
end

-- The beam's path from the gem's cell (`facings[i]`: mirror i's facing now) and whether it reached the prism. A
-- repeated cell and direction (a loop of mirrors) stops it.
function BeamRules.trace(layout: Layout, facings: { number }): Trace
	local mirrorAt: { [string]: number } = {}
	for index, mirror in layout.mirrors do
		mirrorAt[`{mirror.x},{mirror.y}`] = facings[index] or mirror.facing
	end
	local x, y, dir = layout.gem.x, layout.gem.y, layout.gem.dir
	local path = { { x = x, y = y } }
	local seen = { [`{x},{y},{dir}`] = true }
	while true do
		local nextX, nextY = x + STEP_X[dir], y + STEP_Y[dir]
		if nextX < 1 or nextY < 1 or nextX > layout.width or nextY > layout.height then
			return { path = path, reached = false }
		end
		x, y = nextX, nextY
		table.insert(path, { x = x, y = y })
		if x == layout.prism.x and y == layout.prism.y then
			return { path = path, reached = true }
		end
		local facing = mirrorAt[`{x},{y}`]
		if facing then
			local from = (dir + 2) % 4
			if from == facing then
				dir = (facing + 1) % 4
			elseif from == (facing + 1) % 4 then
				dir = facing
			else
				return { path = path, reached = false }
			end
		end
		local key = `{x},{y},{dir}`
		if seen[key] then
			return { path = path, reached = false }
		end
		seen[key] = true
	end
end

-- The first set of facings that reaches the prism (every combination tried), or nil
function BeamRules.solve(layout: Layout): { number }?
	local count = #layout.mirrors
	local facings = table.create(count, 0)
	for _ = 1, 4 ^ count do
		if BeamRules.trace(layout, facings).reached then
			return table.clone(facings)
		end
		for index = 1, count do
			facings[index] = (facings[index] + 1) % 4
			if facings[index] ~= 0 then
				break
			end
		end
	end
	return nil
end

-- Whether some set of facings reaches the prism
function BeamRules.solvable(layout: Layout): boolean
	return BeamRules.solve(layout) ~= nil
end

return BeamRules
