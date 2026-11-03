--!strict
-- How a creature appears, leaves and faints (owner 2026-11-04: light pillar summon, back-into-you unsummon, dizzy-star
-- faint; Util/SummonFx draws them): its size while popping in or shrinking away, whether a summon stamp is fresh enough
-- to show (not a creature streaming in later), and how far a faint has tipped it over. Pure, Lune-tested.
local SummonMotion = {}

local SMALLEST = 0.05 -- a model can't be scaled to nothing
local BACK = 1.70158 -- the pop's overshoot (an ease-out-back)

-- Its size share `t` seconds into a pop lasting `seconds`: from tiny to a little over full, settling at 1
function SummonMotion.popScale(t: number, seconds: number): number
	local u = math.clamp(t / seconds, 0, 1)
	if u >= 1 then
		return 1
	end
	local v = 1 + (BACK + 1) * (u - 1) ^ 3 + BACK * (u - 1) ^ 2
	return SMALLEST + (1 - SMALLEST) * v
end

-- Its size share `t` seconds into shrinking away over `seconds`: from full to tiny, quickening
function SummonMotion.shrinkScale(t: number, seconds: number): number
	local u = math.clamp(t / seconds, 0, 1)
	if u <= 0 then
		return 1
	end
	return SMALLEST + (1 - SMALLEST) * (1 - u * u)
end

-- Whether a summon stamped at `at` (server time) is recent enough at `now` to show its effect
function SummonMotion.fresh(at: number?, now: number, window: number): boolean
	return at ~= nil and now - at <= window
end

-- How far over (radians, up to `roll`) a faint has tipped it `elapsed` seconds in, easing out over `tip` seconds
function SummonMotion.faintRoll(elapsed: number, tip: number, roll: number): number
	local u = math.clamp(elapsed / tip, 0, 1)
	return roll * (1 - (1 - u) ^ 2)
end

return SummonMotion
