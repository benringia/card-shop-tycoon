--!strict
-- Reading your binder in the world (Config/BinderPose): how far into the pose a player is, the pose's angles at that,
-- whether a "shown" message is allowed, and when the next page turns. Pure, Lune-tested.
local BinderPoseRules = {}

export type Angles = { shoulder: number, inward: number, elbow: number, neck: number }

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 (arms down) to 1 (holding the binder up): easing in over `seconds` since `since` while `open`, out after it closes
function BinderPoseRules.weight(since: number, now: number, seconds: number, open: boolean): number
	local t = smooth((now - since) / seconds)
	return if open then t else 1 - t
end

-- The pose's angles (degrees) at `weight`
function BinderPoseRules.angles(pose: any, weight: number): Angles
	local w = math.clamp(weight, 0, 1)
	return { shoulder = pose.shoulder * w, inward = pose.inward * w, elbow = pose.elbow * w, neck = pose.neck * w }
end

-- Whether a client's "binder shown" message goes through: putting it away always; showing it only outside a fight
function BinderPoseRules.canShow(show: any, fighting: boolean): boolean
	if typeof(show) ~= "boolean" then
		return false
	end
	return not show or not fighting
end

-- Seconds until the next page turn, `roll` 0..1 across `every` (min, max)
function BinderPoseRules.nextFlip(roll: number, every: { number }): number
	return every[1] + (every[2] - every[1]) * math.clamp(roll, 0, 1)
end

return BinderPoseRules
