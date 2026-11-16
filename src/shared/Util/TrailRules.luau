--!strict
-- The guides' paw trails (owner 2026-11-16: "chikin paws are passes through things. fix it and make the paws go
-- through the correct path"; client Util/TutorialCues.trail): paw prints spaced evenly along a walking route (the
-- pathfinding's waypoints, the ground's height at each), each facing along its own leg. Pure (no Roblox APIs).
local TrailRules = {}

export type Point = { x: number, y: number, z: number }
export type Paw = { x: number, y: number, z: number, facing: number } -- facing: degrees, 0 = -Z, 90 = +X (screen rotation)

-- Paws every `gap` studs along the route (`maxCount` at most: a longer route spreads them out), never on its very
-- start or end; one in the middle of a route shorter than a gap; none for fewer than two points
function TrailRules.along(route: { Point }, gap: number, maxCount: number): { Paw }
	local paws: { Paw } = {}
	if #route < 2 then
		return paws
	end
	local legs = {}
	local total = 0
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if length > 1e-6 then
			table.insert(legs, { a = a, b = b, length = length, from = total })
			total += length
		end
	end
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
		})
	end
	return paws
end

return TrailRules
