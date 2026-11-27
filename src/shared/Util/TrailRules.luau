--!strict
-- The guides' trails (owner 2026-11-16: "chikin paws are passes through things. fix it and make the paws go through the
-- correct path"; client Util/TutorialCues.trail): marks spaced evenly along a walking route (the pathfinding's
-- waypoints, the ground's height at each), each facing along its own leg; since 2026-11-27 arrows lying on the ground,
-- only the next stretch ahead of the player (owner's picks B and 1, spec 2026-11-27-tutorial-arrows-design: the whole
-- route's paws piled into a gold smear at the horizon). Pure (no Roblox APIs).
local TrailRules = {}

export type Point = { x: number, y: number, z: number }
-- facing: degrees, 0 = -Z, 90 = +X (screen rotation); distance: studs along the route
export type Paw = { x: number, y: number, z: number, facing: number, distance: number }
type Leg = { a: Point, b: Point, length: number, from: number }

-- The route's legs (flat lengths; zero-length ones dropped), each with how far along the route it starts, and the total
local function legsOf(route: { Point }): ({ Leg }, number)
	local legs: { Leg } = {}
	local total = 0
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if length > 1e-6 then
			table.insert(legs, { a = a, b = b, length = length, from = total })
			total += length
		end
	end
	return legs, total
end

-- Marks every `gap` studs along the route (`maxCount` at most: a longer route spreads them out), never on its very
-- start or end; one in the middle of a route shorter than a gap; none for fewer than two points
function TrailRules.along(route: { Point }, gap: number, maxCount: number): { Paw }
	local paws: { Paw } = {}
	if #route < 2 then
		return paws
	end
	local legs, total = legsOf(route)
	if total <= 0 then
		return paws
	end
	local fits = math.ceil(total / gap) - 1 -- gap multiples short of the end
	local count = math.clamp(fits, 1, maxCount)
	local spacing = if fits > maxCount or fits < 1 then total / (count + 1) else gap
	local leg = 1
	for index = 1, count do
		local at = spacing * index
		while leg < #legs and at > legs[leg].from + legs[leg].length do
			leg += 1
		end
		local piece = legs[leg]
		local share = math.clamp((at - piece.from) / piece.length, 0, 1)
		local a, b = piece.a, piece.b
		table.insert(paws, {
			x = a.x + (b.x - a.x) * share,
			y = a.y + (b.y - a.y) * share,
			z = a.z + (b.z - a.z) * share,
			facing = math.deg(math.atan2(b.x - a.x, -(b.z - a.z))),
			distance = at,
		})
	end
	return paws
end

-- How far along the route (studs) its point nearest `at` lies, on the flat (0 for fewer than two points)
function TrailRules.progress(route: { Point }, at: Point): number
	local legs = legsOf(route)
	local best, nearest = 0, math.huge
	for _, leg in legs do
		local dx, dz = leg.b.x - leg.a.x, leg.b.z - leg.a.z
		local share = math.clamp(((at.x - leg.a.x) * dx + (at.z - leg.a.z) * dz) / (leg.length * leg.length), 0, 1)
		local px, pz = leg.a.x + dx * share, leg.a.z + dz * share
		local gap = (at.x - px) ^ 2 + (at.z - pz) ^ 2
		if gap < nearest then
			best, nearest = leg.from + leg.length * share, gap
		end
	end
	return best
end

-- Which marks show for a player `progress` studs along the route: from the first one past them, `count` at most, never
-- past the last (first > last: none)
function TrailRules.ahead(paws: { Paw }, progress: number, count: number): (number, number)
	local first = #paws + 1
	for index, paw in paws do
		if paw.distance > progress then
			first = index
			break
		end
	end
	return first, math.min(first + count - 1, #paws)
end

return TrailRules
