--!strict
-- The portal areas' geometry (Portal Worlds spec): trails from the street's ends to the portals, the walkable outline
-- the town's invisible walls follow, and the reach a portal can be used from. Pure, Lune-tested; numbers and shapes in
-- Config/Town (PORTAL_AREAS, WALK_EDGE, TRAIL). Yaws use TownLayout's convention: degrees, 0 = facing -Z.
export type Point = { x: number, z: number }
export type Wall = { centre: Point, length: number, yaw: number }

local PortalTrails = {}

-- Yaw that turns a model's front (-Z) toward the direction (dx, dz)
local function faceYaw(dx: number, dz: number): number
	return math.deg(math.atan2(-dx, -dz))
end

local function distance(a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	return math.sqrt(dx * dx + dz * dz)
end

function PortalTrails.length(trail: { Point }): number
	local total = 0
	for index = 2, #trail do
		total += distance(trail[index - 1], trail[index])
	end
	return total
end

-- The way the portal at the trail's end faces: back toward the players arriving along it
function PortalTrails.facing(trail: { Point }): Point
	local last, before = trail[#trail], trail[#trail - 1]
	local length = distance(last, before)
	return { x = (before.x - last.x) / length, z = (before.z - last.z) / length }
end

-- Where the trail crosses the island's edge at x = +-halfX (the side it heads to)
function PortalTrails.exitPoint(trail: { Point }, halfX: number): Point
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		local edge = if b.x >= a.x then halfX else -halfX
		if (a.x - edge) * (b.x - edge) <= 0 and a.x ~= b.x then
			local t = (edge - a.x) / (b.x - a.x)
			return { x = edge, z = a.z + (b.z - a.z) * t }
		end
	end
	return trail[#trail]
end

-- Even-odd rule: a ray toward +X crosses the outline an odd number of times from inside
function PortalTrails.inside(outline: { Point }, p: Point): boolean
	local inside = false
	local count = #outline
	for index = 1, count do
		local a, b = outline[index], outline[index % count + 1]
		if (a.z > p.z) ~= (b.z > p.z) then
			local crossX = a.x + (p.z - a.z) / (b.z - a.z) * (b.x - a.x)
			if p.x < crossX then
				inside = not inside
			end
		end
	end
	return inside
end

local function cross(o: Point, a: Point, b: Point): number
	return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
end

local function segmentsCross(a: Point, b: Point, c: Point, d: Point): boolean
	local d1, d2 = cross(c, d, a), cross(c, d, b)
	local d3, d4 = cross(a, b, c), cross(a, b, d)
	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))
end

-- No two sides that don't share a corner cross each other
function PortalTrails.isSimple(outline: { Point }): boolean
	local count = #outline
	for i = 1, count do
		for j = i + 1, count do
			local adjacent = j == i + 1 or (i == 1 and j == count)
			if not adjacent then
				local a, b = outline[i], outline[i % count + 1]
				local c, d = outline[j], outline[j % count + 1]
				if segmentsCross(a, b, c, d) then
					return false
				end
			end
		end
	end
	return true
end

-- One wall per side, a wall's thickness longer than its side so neighbours overlap at the corners
function PortalTrails.walls(outline: { Point }, thickness: number): { Wall }
	local walls = {}
	local count = #outline
	for index = 1, count do
		local a, b = outline[index], outline[index % count + 1]
		table.insert(walls, {
			centre = { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2 },
			length = distance(a, b) + thickness,
			yaw = faceYaw(b.x - a.x, b.z - a.z),
		})
	end
	return walls
end

function PortalTrails.near(p: Point, portal: Point, reach: number): boolean
	return distance(p, portal) <= reach
end

-- Yaw for a signpost arm at `from` pointing toward `to`
function PortalTrails.armYaw(from: Point, to: Point): number
	return faceYaw(to.x - from.x, to.z - from.z)
end

return PortalTrails
