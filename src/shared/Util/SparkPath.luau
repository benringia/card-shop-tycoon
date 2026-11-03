--!strict
-- The XP sparks after a monster win (spec 2026-11-03-windows-round3-design): each flies on a curve from where the
-- monster was to a party portrait. Screen pixels (y grows downwards). Pure, Lune-tested.
local SparkPath = {}

-- Where a spark is `t` (0-1) of the way from (x0, y0) to (x1, y1): a quadratic curve whose control point sits `lift`
-- px above the middle, so at t = 0.5 it is lift / 2 above the straight line
function SparkPath.point(x0: number, y0: number, x1: number, y1: number, lift: number, t: number): (number, number)
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - lift
	local u = 1 - t
	return u * u * x0 + 2 * u * t * cx + t * t * x1, u * u * y0 + 2 * u * t * cy + t * t * y1
end

-- How many sparks for `xp`: more for more, never fewer than `low` or more than `high`
function SparkPath.count(xp: number, low: number, high: number): number
	local extra = math.floor(math.log10(math.max(xp, 1)))
	return math.clamp(low + extra - 1, low, high)
end

return SparkPath
