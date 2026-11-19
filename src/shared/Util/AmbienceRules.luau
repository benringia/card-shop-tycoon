--!strict
-- The Dungeon's danger (spec 2026-11-12-dungeon-atmosphere): when the next distant roar or eye glimpse comes, how loud
-- the roars are room by room, and how much heartbeat the music carries near the chamber. Pure (no requires).
local AmbienceRules = {}

-- The next moment for something that comes every `every[1]` to `every[2]` seconds (`roll` 0..1)
function AmbienceRules.nextAt(now: number, every: { number }, roll: number): number
	return now + every[1] + (every[2] - every[1]) * math.clamp(roll, 0, 1)
end

-- A roar's volume with `done` of `steps` steps done: quiet at the start, loudest at the chamber
function AmbienceRules.roarVolume(done: number, steps: number, range: { number }): number
	local share = if steps > 0 then math.clamp(done / steps, 0, 1) else 1
	return range[1] + (range[2] - range[1]) * share
end

-- The music's climb with the run (`climb`: its volume share, pitch and treble in dB, each from the first step to
-- the last): quiet, low and muffled with nothing done, full once all `steps` are
function AmbienceRules.climb(done: number, steps: number, climb: { volume: { number }, pitch: { number }, muffle: { number } }): (number, number, number)
	local share = if steps > 0 then math.clamp(done / steps, 0, 1) else 1
	local function at(range: { number }): number
		return range[1] + (range[2] - range[1]) * share
	end
	return at(climb.volume), at(climb.pitch), at(climb.muffle)
end

-- The heartbeat layer's share (0..1): none before `from` steps are done, in at `from` (the lock), full when all `steps` are
function AmbienceRules.heartbeat(done: number, from: number, steps: number): number
	if done < from then
		return 0
	end
	if steps <= from then
		return 1
	end
	return math.clamp((done - from + 1) / (steps - from + 1), 0, 1)
end

return AmbienceRules
