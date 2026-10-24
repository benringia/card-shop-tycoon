--!strict
-- Maths for the big beasts' effects (Util/BeastAura on the client): which bones to burn on so the fire covers the
-- whole body, and the jagged path of a lightning arc. Points are plain { x, y, z } tables. Pure, Lune-tested.
export type Point = { number }

local BeastFxRules = {}

local function distance(a: Point, b: Point): number
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Up to `count` indexes into `points`, spread as far apart as possible: the point furthest from the middle first,
-- then each time the one furthest from all picked so far
function BeastFxRules.spread(points: { Point }, count: number): { number }
	local total = #points
	if total == 0 or count <= 0 then
		return {}
	end
	local middle = { 0, 0, 0 }
	for _, point in points do
		middle = { middle[1] + point[1] / total, middle[2] + point[2] / total, middle[3] + point[3] / total }
	end
	local nearest: { number } = {}
	for index, point in points do
		nearest[index] = distance(point, middle)
	end
	local picked: { number } = {}
	for _ = 1, math.min(count, total) do
		local best, bestGap = 0, -1
		for index, gap in nearest do
			if gap > bestGap then
				best, bestGap = index, gap
			end
		end
		table.insert(picked, best)
		for index, point in points do
			nearest[index] = math.min(nearest[index], distance(point, points[best]))
		end
		nearest[best] = -1
	end
	return picked
end

-- The corners of a lightning arc from `from` to `to`: segments + 1 points, the ends exact, the ones between
-- pushed off the line by up to jitter times its length. random() gives a number in 0..1.
function BeastFxRules.arc(from: Point, to: Point, segments: number, jitter: number, random: () -> number): { Point }
	local count = math.max(1, segments)
	local reach = distance(from, to) * jitter
	local path: { Point } = { from }
	for step = 1, count - 1 do
		local t = step / count
		local push = { (random() * 2 - 1) * reach, (random() * 2 - 1) * reach, (random() * 2 - 1) * reach }
		table.insert(path, {
			from[1] + (to[1] - from[1]) * t + push[1],
			from[2] + (to[2] - from[2]) * t + push[2],
			from[3] + (to[3] - from[3]) * t + push[3],
		})
	end
	table.insert(path, to)
	return path
end

return BeastFxRules
