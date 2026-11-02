--!strict
-- A boss's big attacks on players (spec 2026-11-02-you-in-the-fight-design): a slam (a circle under a player) or a
-- swipe (a cone from the boss toward one). The server checks who is inside when a ring lands; the client draws the
-- closing ring ("B": a glowing ring closes in on the area's outline and the hit lands as it touches the edge).
-- Pure (no requires, no Roblox APIs) so tests/ run it in Lune: positions are plain x, z numbers on the ground plane.
local RingRules = {}

RingRules.START_SCALE = 1.9 -- the closing ring starts this many times the area's size

function RingRules.inSlam(cx: number, cz: number, radius: number, px: number, pz: number): boolean
	local dx, dz = px - cx, pz - cz
	return dx * dx + dz * dz <= radius * radius
end

-- From (ox, oz) toward (dirX, dirZ) (any length), `length` studs long, `halfAngleDegrees` either side
function RingRules.inSwipe(ox: number, oz: number, dirX: number, dirZ: number, length: number, halfAngleDegrees: number, px: number, pz: number): boolean
	local dx, dz = px - ox, pz - oz
	local distance = math.sqrt(dx * dx + dz * dz)
	local dirLength = math.sqrt(dirX * dirX + dirZ * dirZ)
	if dirLength < 1e-6 or distance > length then
		return false
	elseif distance < 1e-6 then
		return true
	end
	return (dx * dirX + dz * dirZ) / (distance * dirLength) >= math.cos(math.rad(halfAngleDegrees))
end

-- The closing ring's size (times the area's) `elapsed` seconds into a `warning`-second warning
function RingRules.closingScale(elapsed: number, warning: number): number
	if warning <= 0 then
		return 1
	end
	local t = math.clamp(elapsed / warning, 0, 1)
	return RingRules.START_SCALE - (RingRules.START_SCALE - 1) * t
end

return RingRules
