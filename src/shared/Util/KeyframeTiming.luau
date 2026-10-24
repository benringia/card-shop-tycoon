--!strict
-- Timing maths for playing saved KeyframeSequence animations ourselves (Util/KeyframePlayer on the client): which
-- two keyframes a moment falls between, and how much idle, walk and run to show at a speed. Pure, Lune-tested.
local KeyframeTiming = {}

-- The keyframes either side of `time` (indexes into the sorted `times`) and how far from the first to the second.
-- Looping animations wrap round; one-shots hold their last keyframe.
function KeyframeTiming.between(times: { number }, time: number, loop: boolean): (number, number, number)
	local count = #times
	if count <= 1 then
		return 1, 1, 0
	end
	local length = times[count]
	local t = time
	if loop and length > 0 then
		t = time % length
	elseif t >= length then
		return count, count, 0
	end
	for index = 1, count - 1 do
		local from, to = times[index], times[index + 1]
		if t >= from and t < to then
			return index, index + 1, if to > from then (t - from) / (to - from) else 0
		end
	end
	return count, count, 0
end

-- How much of idle, walk and run to show at this speed (studs a second): idle below WALK_FROM, all walk up to
-- RUN_FROM, then blending into run by RUN_FULL. Always adds up to 1.
function KeyframeTiming.weights(cfg: any, speed: number): (number, number, number)
	if speed < cfg.WALK_FROM then
		return 1, 0, 0
	end
	local run = math.clamp((speed - cfg.RUN_FROM) / math.max(cfg.RUN_FULL - cfg.RUN_FROM, 1e-3), 0, 1)
	return 0, 1 - run, run
end

return KeyframeTiming
