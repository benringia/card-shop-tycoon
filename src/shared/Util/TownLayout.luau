--!strict
-- Where the code-built town pieces go (main town spec): street lights, plaza benches, the island hedge and the
-- portal frames. Pure: takes the plot grid, portal and spring spots and Config/Town, returns a fixed list of prop
-- placements, so every server looks the same. TownService places them. The rest of the decoration (trees,
-- flowers, rocks ...) is hand-placed in Studio and saved as assets/town (docs/props.md).
-- Lune-tested: a hedge rings the island (open where the portal trails leave it); nothing lands in a plot, in the street (except lamps, portals and the plaza), near a portal or
-- in the spring area (except benches and flowers). (The Fence slot is still used by the plaza garden.)
export type Point = { x: number, z: number, y: number? } -- y: the ground's height (0 when left out)
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
	exits: { Point }, -- where each portal's trail leaves the island (PortalTrails.exitPoint), same order as portals
	facings: { Point }, -- the way each portal faces, back along its trail (PortalTrails.facing)
}
-- yaw in degrees, 0 = facing -Z (Roblox front). variant counts up per slot (1, 2, 3 ...).
export type Placement = { slot: string, x: number, z: number, yaw: number, variant: number, y: number? }
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
	local function add(slot: string, x: number, z: number, yaw: number, y: number?)
		variants[slot] = (variants[slot] or 0) + 1
		table.insert(placements, { slot = slot, x = x, z = z, yaw = yaw, variant = variants[slot], y = y })
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
		-- Street lights: on the sidewalk at every gap and past each row end
		local lampZ = side * (halfStreet - layout.LAMP_INSET)
		local lampXs = { -(rowHalf + layout.ROW_END_LAMP_OFFSET) }
		for _, x in gapXs do
			table.insert(lampXs, x)
		end
		table.insert(lampXs, rowHalf + layout.ROW_END_LAMP_OFFSET)
		for _, x in lampXs do
			add("StreetLight", x, lampZ, towardStreet)
		end
	end

	-- Hedge round the island's edge, just inside the bounds, facing in
	local edgeX = town.BOUNDS.HALF_X - layout.EDGE_FENCE_INSET
	local edgeZ = town.BOUNDS.HALF_Z - layout.EDGE_FENCE_INSET
	local function fenceLine(half: number, place: (along: number) -> ())
		local sections = math.floor(2 * half / layout.FENCE_SECTION)
		local start = -(sections * layout.FENCE_SECTION) / 2 + layout.FENCE_SECTION / 2
		for index = 0, sections - 1 do
			place(start + index * layout.FENCE_SECTION)
		end
	end
	-- No hedge where a trail leaves the island
	local function clearOfTrails(x: number, z: number): boolean
		for _, exit in world.exits do
			local dx, dz = x - exit.x, z - exit.z
			if math.sqrt(dx * dx + dz * dz) < town.TRAIL.HEDGE_GAP then
				return false
			end
		end
		return true
	end
	for _, side in SIDES do
		fenceLine(edgeX, function(x)
			if clearOfTrails(x, side * edgeZ) then
				add("Hedge", x, side * edgeZ, faceYaw(0, -side))
			end
		end)
		fenceLine(edgeZ, function(z)
			if clearOfTrails(side * edgeX, z) then
				add("Hedge", side * edgeX, z, faceYaw(-side, 0))
			end
		end)
	end

	-- Plaza: benches facing the spring
	for _, angle in layout.BENCH_ANGLES do
		local x = world.spring.x + layout.BENCH_RADIUS * math.cos(math.rad(angle))
		local z = world.spring.z + layout.BENCH_RADIUS * math.sin(math.rad(angle))
		add("Bench", x, z, faceYaw(world.spring.x - x, world.spring.z - z))
	end

	-- Portals: a frame facing back along its trail, toward arriving players
	for index, portal in world.portals do
		local facing = world.facings[index]
		add("Portal", portal.x, portal.z, faceYaw(facing.x, facing.z), portal.y)
	end

	return placements
end

-- Zebra stripes in front of every shop door: across the road from sidewalk to sidewalk, one stripe every
-- STRIPE + GAP studs, leaving out any that would sit on the plaza
function TownLayout.crosswalks(world: World, town: any): { Rect }
	local crosswalk = town.FLOOR.CROSSWALK
	local roadHalf = world.streetWidth / 2 - town.LAYOUT.SIDEWALK
	local pitch = crosswalk.STRIPE + crosswalk.GAP
	local count = math.floor((2 * roadHalf + crosswalk.GAP) / pitch)
	local start = -(count * pitch - crosswalk.GAP) / 2
	local stripes: { Rect } = {}
	for col = 0, world.perRow - 1 do
		local x = (col - (world.perRow - 1) / 2) * (world.plotWidth + world.gap)
		for index = 0, count - 1 do
			local minZ = start + index * pitch
			local z = minZ + crosswalk.STRIPE / 2
			local dx, dz = x - world.spring.x, z - world.spring.z
			if math.sqrt(dx * dx + dz * dz) > town.LAYOUT.PLAZA_RADIUS then
				table.insert(stripes, {
					minX = x - crosswalk.WIDTH / 2,
					maxX = x + crosswalk.WIDTH / 2,
					minZ = minZ,
					maxZ = minZ + crosswalk.STRIPE,
				})
			end
		end
	end
	return stripes
end

-- A glowing line for each portal (Town.PORTAL_AREAS): from the plaza's rim level with the trail's start, along every
-- trail point, stopping PATH_END_INSET short of the portal
function TownLayout.trailLines(world: World, town: any): { { points: { Point } } }
	local radius = town.LAYOUT.PLAZA_RADIUS
	local lines = {}
	for _, area in town.PORTAL_AREAS do
		local trail = area.trail
		local start = trail[1]
		local away = if start.x >= world.spring.x then 1 else -1
		local dz = math.min(math.abs(start.z - world.spring.z), radius)
		local points: { Point } = { { x = world.spring.x + away * math.sqrt(radius * radius - dz * dz), z = start.z } }
		for index = 1, #trail - 1 do
			table.insert(points, { x = trail[index].x, z = trail[index].z, y = trail[index].y })
		end
		local last, before = trail[#trail], trail[#trail - 1]
		local dx, dzz = before.x - last.x, before.z - last.z
		local length = math.sqrt(dx * dx + dzz * dzz)
		local inset = town.FLOOR.PATH_END_INSET
		table.insert(points, { x = last.x + dx / length * inset, z = last.z + dzz / length * inset, y = last.y })
		table.insert(lines, { points = points })
	end
	return lines
end

return TownLayout
