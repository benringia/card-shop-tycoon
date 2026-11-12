--!strict
-- The worlds' soundscape rules (Config/Soundscape, SoundscapeController): how far into the night the town's clock is,
-- when a spot's next sound comes and where from, how loud a day or night group is now, and a gust's swell. Pure,
-- Lune-tested.
export type Night = { from: number, full: number, fade: number, gone: number }
export type Gust = { seconds: number, rise: number, fall: number }

local SoundscapeRules = {}

-- How far into the night `clock` o'clock is (0-1): none by day, rising from night.from to night.full, full through
-- midnight, falling from night.fade to night.gone
function SoundscapeRules.nightShare(clock: number, night: Night): number
	local hour = clock % 24
	if hour >= night.from then
		return math.clamp((hour - night.from) / (night.full - night.from), 0, 1)
	elseif hour < night.fade then
		return 1
	end
	return math.clamp(1 - (hour - night.fade) / (night.gone - night.fade), 0, 1)
end

-- When the next sound of a spot comes: `every` (min, max) seconds after `now`, by `roll` in [0, 1]
function SoundscapeRules.nextAt(now: number, every: { number }, roll: number): number
	return now + every[1] + (every[2] - every[1]) * roll
end

-- Where a spot's sound comes from, round the listener: any direction (angleRoll), its distance and height ranges
function SoundscapeRules.spotOffset(angleRoll: number, distanceRoll: number, heightRoll: number, spot: any): { x: number, y: number, z: number }
	local angle = angleRoll * 2 * math.pi
	local distance = spot.distance[1] + (spot.distance[2] - spot.distance[1]) * distanceRoll
	local height = spot.height[1] + (spot.height[2] - spot.height[1]) * heightRoll
	return { x = math.cos(angle) * distance, y = height, z = math.sin(angle) * distance }
end

-- How much of a group plays at `night` (the night share): "day" fades out, "night" fades in, a zone's always plays
function SoundscapeRules.weight(kind: string, night: number): number
	if kind == "day" then
		return 1 - night
	elseif kind == "night" then
		return night
	end
	return 1
end

-- A gust's strength `t` seconds in (0-1): in over gust.rise, held, out over gust.fall, gone after gust.seconds
function SoundscapeRules.gustShape(t: number, gust: Gust): number
	if t <= 0 or t >= gust.seconds then
		return 0
	elseif t < gust.rise then
		return t / gust.rise
	elseif t > gust.seconds - gust.fall then
		return (gust.seconds - t) / gust.fall
	end
	return 1
end

return SoundscapeRules
