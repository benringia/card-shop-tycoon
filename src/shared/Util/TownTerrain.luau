--!strict
-- The town's terrain as a list of fills (Portal Worlds spec), so every server builds the same ground: the ground round
-- town, the island (grass, asphalt under the street, plain ground under the shops, all drawn at y 0 under the thin
-- street and marking parts), the areas' floors, the trails paved in their area's surface, then hills, cliffs and the
-- peak. Pure, Lune-tested; shapes in Config/Scenery, trails in Config/Town. SceneryService fills them in order.
export type Op = {
	shape: "Block" | "Ball" | "Wedge",
	x: number,
	y: number,
	z: number,
	yaw: number?, -- degrees about Y, applied as CFrame.Angles(0, math.rad(yaw), 0)
	size: { x: number, y: number, z: number }?,
	radius: number?,
	material: string,
}
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local TownTerrain = {}

-- Roblox draws a terrain surface this far above the top of its fill (measured 2026-10-30: a fill topping out at y -2
-- draws its ground at y 0.02), so ground meant to be at y 0 is filled to y -2
TownTerrain.SURFACE_LIFT = 2

local GROUND_BOTTOM = -8 -- island and trail fills run from here up to -SURFACE_LIFT
local SAMPLE_Y = -2 -- materialAt looks at the ground just under the surface
local CELL = 64 -- studs^3 in one 4 x 4 x 4 terrain cell

local function flat(x: number, z: number, sizeX: number, sizeZ: number, material: string, yaw: number?): Op
	local top = -TownTerrain.SURFACE_LIFT
	return { shape = "Block", x = x, y = (GROUND_BOTTOM + top) / 2, z = z, size = { x = sizeX, y = top - GROUND_BOTTOM, z = sizeZ }, yaw = yaw, material = material }
end

local function copy(list: { any }, into: { Op })
	for _, op in list do
		table.insert(into, op)
	end
end

function TownTerrain.ops(scenery: any, town: any, plots: { Rect }): { Op }
	local ops: { Op } = {}
	copy(scenery.GROUND, ops)
	local bounds, layout = town.BOUNDS, town.LAYOUT
	table.insert(ops, flat(0, 0, bounds.HALF_X * 2, bounds.HALF_Z * 2, "Grass"))
	-- The street runs between the two shop rows: up to the nearest plot front
	local streetHalfZ = math.huge
	for _, rect in plots do
		streetHalfZ = math.min(streetHalfZ, math.min(math.abs(rect.minZ), math.abs(rect.maxZ)))
	end
	table.insert(ops, flat(0, 0, layout.STREET_HALF_LENGTH * 2, streetHalfZ * 2, "Asphalt"))
	for _, rect in plots do
		table.insert(ops, flat((rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2, rect.maxX - rect.minX, rect.maxZ - rect.minZ, "Ground"))
	end
	copy(scenery.FLOORS, ops)
	local width = town.TRAIL.WIDTH
	for _, area in town.PORTAL_AREAS do
		local trail = area.trail
		for index = 2, #trail do
			local a, b = trail[index - 1], trail[index]
			local dx, dz = b.x - a.x, b.z - a.z
			local length = math.sqrt(dx * dx + dz * dz)
			table.insert(ops, flat((a.x + b.x) / 2, (a.z + b.z) / 2, width, length + width, area.surface, math.deg(math.atan2(-dx, -dz))))
		end
	end
	copy(scenery.TERRAIN, ops)
	return ops
end

-- (x, z) in the block's own axes: Roblox's CFrame.Angles(0, t, 0) sends local (lx, lz) to
-- world (cos t * lx + sin t * lz, -sin t * lx + cos t * lz)
local function toLocal(op: Op, x: number, z: number): (number, number)
	local t = math.rad(op.yaw or 0)
	local wx, wz = x - op.x, z - op.z
	return math.cos(t) * wx - math.sin(t) * wz, math.sin(t) * wx + math.cos(t) * wz
end

local function overColumn(op: Op, x: number, z: number): boolean
	if op.shape == "Ball" then
		local dx, dz = x - op.x, z - op.z
		return dx * dx + dz * dz <= (op.radius :: number) ^ 2
	end
	local size = op.size :: { x: number, y: number, z: number }
	local lx, lz = toLocal(op, x, z)
	return math.abs(lx) <= size.x / 2 and math.abs(lz) <= size.z / 2
end

local function topOf(op: Op, x: number, z: number): number
	if op.shape == "Ball" then
		local dx, dz = x - op.x, z - op.z
		return op.y + math.sqrt(math.max(0, (op.radius :: number) ^ 2 - dx * dx - dz * dz))
	end
	return op.y + (op.size :: { x: number, y: number, z: number }).y / 2
end

local function covers(op: Op, x: number, y: number, z: number): boolean
	if not overColumn(op, x, z) then
		return false
	end
	if op.shape == "Ball" then
		local dx, dy, dz = x - op.x, y - op.y, z - op.z
		return dx * dx + dy * dy + dz * dz <= (op.radius :: number) ^ 2
	end
	local half = (op.size :: { x: number, y: number, z: number }).y / 2
	return y >= op.y - half and y <= op.y + half
end

-- The material just under the surface at (x, z): the last fill covering it (nil = nothing)
function TownTerrain.materialAt(ops: { Op }, x: number, z: number): string?
	local found = nil
	for _, op in ops do
		if covers(op, x, SAMPLE_Y, z) then
			found = op.material
		end
	end
	return found
end

-- The highest top of any solid or water fill over the column (x, z) (nil = nothing there)
function TownTerrain.topAt(ops: { Op }, x: number, z: number): number?
	local top = nil
	for _, op in ops do
		if op.material ~= "Air" and overColumn(op, x, z) then
			local here = topOf(op, x, z)
			top = if top then math.max(top, here) else here
		end
	end
	return top
end

-- A rough cell count for the memory budget (overlaps count twice, so it errs high)
function TownTerrain.estimatedCells(ops: { Op }): number
	local volume = 0
	for _, op in ops do
		if op.material ~= "Air" then
			if op.shape == "Ball" then
				volume += 4 / 3 * math.pi * (op.radius :: number) ^ 3
			else
				local size = op.size :: { x: number, y: number, z: number }
				volume += size.x * size.y * size.z * (if op.shape == "Wedge" then 0.5 else 1)
			end
		end
	end
	return volume / CELL
end

return TownTerrain
