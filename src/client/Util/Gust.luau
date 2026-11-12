--!strict
-- The wind's strength right now on this client (0 still, 1 a full gust): SoundscapeController sets it as gusts come and
-- go (Config/Soundscape GUST), TreeSwayController bends the trees harder by it.
local Gust = {}

local strength = 0

function Gust.set(value: number)
	strength = math.clamp(value, 0, 1)
end

function Gust.strength(): number
	return strength
end

return Gust
