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
	pitch: number?, -- degrees about the block's own X after the yaw: positive lifts its front (-Z) end (trail ramps)
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
local SAMPLE_DEPTH = 0.5 -- materialAt looks this far under the top of the column
local CELL = 64 -- studs^3 in one 4 x 4 x 4 terrain cell

local RAMP_DEPTH = 6 -- a sloping trail is a slab this thick, tilted between its two ends

local function flat(x: number, z: number, sizeX: number, sizeZ: number, material: string, yaw: number?, height: number?): Op
	local top = (height or 0) - TownTerrain.SURFACE_LIFT
	return { shape = "Block", x = x, y = (GROUND_BOTTOM + top) / 2, z = z, size = { x = sizeX, y = top - GROUND_BOTTOM, z = sizeZ }, yaw = yaw, material = material }
end

-- One trail segment, paved in `material`: flat at its height, or a slab tilted from a's height up (or down) to b's
function TownTerrain.trailSegment(a: { x: number, z: number, y: number? }, b: { x: number, z: number, y: number? }, width: number, material: string): Op
	local dx, dz = b.x - a.x, b.z - a.z
	local run = math.sqrt(dx * dx + dz * dz)
	local yaw = math.deg(math.atan2(-dx, -dz))
	local ya, yb = a.y or 0, b.y or 0
	if ya == yb then
		return flat((a.x + b.x) / 2, (a.z + b.z) / 2, width, run + width, material, yaw, ya)
	end
	local rise = yb - ya
	local pitch = math.atan2(rise, run)
	local length = math.sqrt(run * run + rise * rise)
	-- The slab's top runs through both ends' fill tops; its centre sits half its depth below that, square to the slope
	local topMid = (ya + yb) / 2 - TownTerrain.SURFACE_LIFT
	return {
		shape = "Block",
		x = (a.x + b.x) / 2,
		y = topMid - RAMP_DEPTH / 2 / math.cos(pitch),
		z = (a.z + b.z) / 2,
		size = { x = width, y = RAMP_DEPTH, z = length + width },
		yaw = yaw,
		pitch = math.deg(pitch),
		material = material,
	}
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
	-- Plain ground under each shop and a margin round it: terrain blends about a cell past its fill, so grass any
	-- closer pokes its blades up through the floor along the walls
	local margin = scenery.PLOT_GROUND_MARGIN
	for _, rect in plots do
		table.insert(ops, flat((rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2, rect.maxX - rect.minX + margin * 2, rect.maxZ - rect.minZ + margin * 2, "Ground"))
	end
	copy(scenery.FLOORS, ops)
	local width = town.TRAIL.WIDTH
	for _, area in town.PORTAL_AREAS do
		local trail = area.trail
		for index = 2, #trail do
			table.insert(ops, TownTerrain.trailSegment(trail[index - 1], trail[index], width, area.surface))
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
	local pitch = math.rad(op.pitch or 0)
	return math.abs(lx) <= size.x / 2 and math.abs(lz) <= size.z / 2 * math.cos(pitch)
end

local function topOf(op: Op, x: number, z: number): number
	if op.shape == "Ball" then
		local dx, dz = x - op.x, z - op.z
		return op.y + math.sqrt(math.max(0, (op.radius :: number) ^ 2 - dx * dx - dz * dz))
	end
	local half = (op.size :: { x: number, y: number, z: number }).y / 2
	local pitch = math.rad(op.pitch or 0)
	if pitch == 0 then
		return op.y + half
	end
	-- A tilted slab: its top rises toward its front (-Z) end
	local _, lz = toLocal(op, x, z)
	return op.y + half / math.cos(pitch) - lz * math.tan(pitch)
end

local function covers(op: Op, x: number, y: number, z: number): boolean
	if not overColumn(op, x, z) then
		return false
	end
	if op.shape == "Ball" then
		local dx, dy, dz = x - op.x, y - op.y, z - op.z
		return dx * dx + dy * dy + dz * dz <= (op.radius :: number) ^ 2
	end
	local top = topOf(op, x, z)
	local depth = (op.size :: { x: number, y: number, z: number }).y / math.cos(math.rad(op.pitch or 0))
	return y <= top and y >= top - depth
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

-- The material just under the surface at (x, z): the last fill covering the point just below the column's top
-- (nil = nothing)
function TownTerrain.materialAt(ops: { Op }, x: number, z: number): string?
	local top = TownTerrain.topAt(ops, x, z)
	if not top then
		return nil
	end
	local found = nil
	for _, op in ops do
		if covers(op, x, top - SAMPLE_DEPTH, z) then
			found = op.material
		end
	end
	return found
end

-- The height the ground is drawn at over (x, z), for standing props on it (nil = no terrain there)
function TownTerrain.groundAt(ops: { Op }, x: number, z: number): number?
	local top = TownTerrain.topAt(ops, x, z)
	return if top then top + TownTerrain.SURFACE_LIFT else nil
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
