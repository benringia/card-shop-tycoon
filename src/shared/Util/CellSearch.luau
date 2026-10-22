--!strict
-- Grid cells ordered by distance from a start cell (pure, Lune-tested). Used to move a fixture to the
-- nearest free spot when its saved one is taken.
export type Cell = { x: number, z: number }

local CellSearch = {}

-- Every cell with 0 <= x <= maxX and 0 <= z <= maxZ, nearest to (startX, startZ) first (clamped into range);
-- ties go by z, then x, so the order is always the same
function CellSearch.byDistance(startX: number, startZ: number, maxX: number, maxZ: number): { Cell }
	local sx, sz = math.clamp(startX, 0, maxX), math.clamp(startZ, 0, maxZ)
	local cells: { Cell } = {}
	for z = 0, maxZ do
		for x = 0, maxX do
			table.insert(cells, { x = x, z = z })
		end
	end
	table.sort(cells, function(a, b)
		local da = (a.x - sx) ^ 2 + (a.z - sz) ^ 2
		local db = (b.x - sx) ^ 2 + (b.z - sz) ^ 2
		if da ~= db then
			return da < db
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		return a.x < b.x
	end)
	return cells
end

return CellSearch
