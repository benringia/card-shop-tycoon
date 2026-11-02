--!strict
-- Camera shake maths (Util/ScreenFx, Config/AttackFx SHAKE): hits add to one shake between 0 and 1 that dies down over
-- time, the camera moves by its square (small shakes stay subtle, big ones kick), and hits away from you shake less.
-- Pure, Lune-tested.
local ShakeRules = {}

function ShakeRules.add(shake: number, amount: number): number
	return math.min(1, shake + math.max(0, amount))
end

function ShakeRules.decay(shake: number, dt: number, rate: number): number
	return math.max(0, shake - dt * rate)
end

-- How far the camera may move now, in studs
function ShakeRules.offset(shake: number, maxStuds: number): number
	return shake * shake * maxStuds
end

-- A hit's shake `distance` studs from you: all of it inside `near`, none past `far`, fading between
function ShakeRules.falloff(strength: number, distance: number, near: number, far: number): number
	if distance <= near then
		return strength
	elseif distance >= far then
		return 0
	end
	return strength * (1 - (distance - near) / (far - near))
end

return ShakeRules
