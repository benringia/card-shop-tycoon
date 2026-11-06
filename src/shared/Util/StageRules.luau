--!strict
-- Where a client-only stage goes (Config/Stages): straight above `base` (the player) at the first of `lifts` that
-- isFree says is clear, else the far stage. Pure (Lune-tested); client Util/StageSpot does the world checks.
local StageRules = {}

export type Vec = { x: number, y: number, z: number }

-- (the spot, whether it's near the player)
function StageRules.pick(base: Vec, lifts: { number }, isFree: (Vec) -> boolean, far: Vec): (Vec, boolean)
	for _, lift in lifts do
		local spot = { x = base.x, y = base.y + lift, z = base.z }
		if isFree(spot) then
			return spot, true
		end
	end
	return far, false
end

return StageRules
