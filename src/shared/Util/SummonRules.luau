--!strict
-- The Rift Devourer's summons (the owner 2026-11-11: "will show up to a random corner of an arena and runs to the
-- summoned pet"): which corner of the arena each comes out at, how fast it runs to its pet and where it stops to bite.
-- Points are plain { x, z } in the boss's own space (it faces the gate, -Z; the arena's centre is BOSS_SPOT in front
-- of it). Pure, Lune-tested (tests/SummonRules); BattleService moves the summons with it, Util/RiftFx draws the rifts.
local SummonRules = {}

export type Point = { x: number, z: number }

local CORNER_ANGLES = { 225, 315, 45, 135 } -- front-left, front-right, back-right, back-left (degrees round the centre)

-- Corner `index` (1-4): `share` of the arena's radius out from its centre
function SummonRules.corner(index: number, arenaRadius: number, bossSpot: number, share: number): Point
	local angle = math.rad(CORNER_ANGLES[(index - 1) % 4 + 1])
	local reach = arenaRadius * share
	return { x = math.cos(angle) * reach, z = -bossSpot + math.sin(angle) * reach }
end

-- Which corner each of a wave's `count` summons comes out at: different corners while there are some left (all four
-- used, they start again), each picked by its roll (0-1; a missing roll counts as 0)
function SummonRules.pickCorners(count: number, rolls: { number }): { number }
	local picks = {}
	local left: { number } = {}
	for slot = 1, count do
		if #left == 0 then
			left = { 1, 2, 3, 4 }
		end
		local roll = math.clamp(rolls[slot] or 0, 0, 0.999999)
		table.insert(picks, table.remove(left, math.floor(roll * #left) + 1) :: number)
	end
	return picks
end

-- Studs a second to cover `distance` in `seconds`, never under `min` or over `max`
function SummonRules.runSpeed(distance: number, seconds: number, min: number, max: number): number
	if seconds <= 0 then
		return max
	end
	return math.clamp(distance / seconds, min, max)
end

local EMERGE_START_SCALE = 0.45

-- Climbing out of its rift, `elapsed` of `seconds`: how much of its height is still under the ground (1 to 0) and its
-- size (EMERGE_START_SCALE to 1), easing out so it bursts up and settles
function SummonRules.emerge(elapsed: number, seconds: number): (number, number)
	if seconds <= 0 then
		return 0, 1
	end
	local t = math.clamp(elapsed / seconds, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	return 1 - eased, EMERGE_START_SCALE + (1 - EMERGE_START_SCALE) * eased
end

-- Where it stops to bite: `gap` studs from its pet, on the side it came from
function SummonRules.meleeSpot(target: Point, from: Point, gap: number): Point
	local dx, dz = from.x - target.x, from.z - target.z
	local reach = math.sqrt(dx * dx + dz * dz)
	if reach < 1e-6 then
		dx, dz, reach = 1, 0, 1
	end
	return { x = target.x + dx / reach * gap, z = target.z + dz / reach * gap }
end

return SummonRules
