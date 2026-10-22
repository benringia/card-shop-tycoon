--!strict
-- Where the code-built town pieces go (main town spec): street lamps, plaza benches, the island fence and the
-- portal frames. Pure: takes the plot grid, portal and spring spots and Config/Town, returns a fixed list of prop
-- placements, so every server looks the same. TownService places them. The rest of the decoration (trees,
-- flowers, rocks ...) is hand-placed in Studio and saved as assets/town (docs/props.md).
-- Lune-tested: a fence rings the island; nothing lands in a plot, in the street (except lamps, portals and the plaza), near a portal or
-- in the spring area (except benches and flowers).
export type Point = { x: number, z: number }
export type World = {
	plotCount: number,
	perRow: number,
	plotWidth: number,
	plotDepth: number,
	gap: number,
	streetWidth: number,
	portals: { Point },
	spring: Point,
	springRadius: number,
}
-- yaw in degrees, 0 = facing -Z (Roblox front). variant counts up per slot (1, 2, 3 ...).
export type Placement = { slot: string, x: number, z: number, yaw: number, variant: number }
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local TownLayout = {}

local SIDES = { -1, 1 }

-- Yaw that turns a model's front (-Z) toward the direction (dx, dz)
local function faceYaw(dx: number, dz: number): number
	return math.deg(math.atan2(-dx, -dz))
end

-- Same maths as PlotService.getPlotCFrame: row 1 at -Z, row 2 at +Z, columns centred on x = 0
function TownLayout.plotRects(world: World): { Rect }
	local rects = {}
	for index = 1, world.plotCount do
		local row = (index - 1) // world.perRow
		local col = (index - 1) % world.perRow
		local side = if row == 0 then -1 else 1
		local x = (col - (world.perRow - 1) / 2) * (world.plotWidth + world.gap)
		local z = side * (world.streetWidth + world.plotDepth) / 2
		table.insert(rects, {
			minX = x - world.plotWidth / 2,
			maxX = x + world.plotWidth / 2,
			minZ = z - world.plotDepth / 2,
			maxZ = z + world.plotDepth / 2,
		})
	end
	return rects
end

local function matches(slot: string, name: string): boolean
	if string.sub(name, 1, #slot) ~= slot then
		return false
	end
	local rest = string.sub(name, #slot + 1)
	return rest == "" or string.match(rest, "^[%u%d]") ~= nil
end

-- A file belongs to a slot when it is named after it, optionally followed by a suffix that starts with a
-- capital letter or digit: Tree, TreeA, Tree2, FlowerBlue (not Treehouse or Flowers). Given every slot, a file
-- goes to the longest slot name it matches: CounterDecorA is a CounterDecor, not a Counter.
function TownLayout.isVariant(slot: string, name: string, slots: { [string]: any }?): boolean
	if not matches(slot, name) then
		return false
	end
	for other in slots or {} do
		if #other > #slot and matches(other, name) then
			return false
		end
	end
	return true
end

function TownLayout.build(world: World, town: any): { Placement }
	local layout = town.LAYOUT
	local placements: { Placement } = {}
	local variants: { [string]: number } = {}
	local function add(slot: string, x: number, z: number, yaw: number)
		variants[slot] = (variants[slot] or 0) + 1
		table.insert(placements, { slot = slot, x = x, z = z, yaw = yaw, variant = variants[slot] })
	end

	local halfStreet = world.streetWidth / 2
	local pitch = world.plotWidth + world.gap
	local rowHalf = (world.perRow * world.plotWidth + (world.perRow - 1) * world.gap) / 2
	local gapXs = {}
	for col = 0, world.perRow - 2 do
		table.insert(gapXs, (col - (world.perRow - 1) / 2) * pitch + pitch / 2)
	end

	for _, side in SIDES do
		local towardStreet = faceYaw(0, -side)
		-- Lamps: street edges at every gap and past each row end
		local lampZ = side * (halfStreet - layout.LAMP_INSET)
		local lampXs = { -(rowHalf + layout.ROW_END_LAMP_OFFSET) }
		for _, x in gapXs do
			table.insert(lampXs, x)
		end
		table.insert(lampXs, rowHalf + layout.ROW_END_LAMP_OFFSET)
		for _, x in lampXs do
			add("Lamp", x, lampZ, towardStreet)
		end
	end

	-- Fence round the island's edge, just inside the bounds, facing in
	local edgeX = town.BOUNDS.HALF_X - layout.EDGE_FENCE_INSET
	local edgeZ = town.BOUNDS.HALF_Z - layout.EDGE_FENCE_INSET
	local function fenceLine(half: number, place: (along: number) -> ())
		local sections = math.floor(2 * half / layout.FENCE_SECTION)
		local start = -(sections * layout.FENCE_SECTION) / 2 + layout.FENCE_SECTION / 2
		for index = 0, sections - 1 do
			place(start + index * layout.FENCE_SECTION)
		end
	end
	for _, side in SIDES do
		fenceLine(edgeX, function(x)
			add("Fence", x, side * edgeZ, faceYaw(0, -side))
		end)
		fenceLine(edgeZ, function(z)
			add("Fence", side * edgeX, z, faceYaw(-side, 0))
		end)
	end

	-- Plaza: benches facing the spring
	for _, angle in layout.BENCH_ANGLES do
		local x = world.spring.x + layout.BENCH_RADIUS * math.cos(math.rad(angle))
		local z = world.spring.z + layout.BENCH_RADIUS * math.sin(math.rad(angle))
		add("Bench", x, z, faceYaw(world.spring.x - x, world.spring.z - z))
	end

	-- Portals: a frame facing the town
	for _, portal in world.portals do
		local away = if portal.x >= 0 then 1 else -1
		add("Portal", portal.x, portal.z, faceYaw(-away, 0))
	end

	return placements
end

return TownLayout
