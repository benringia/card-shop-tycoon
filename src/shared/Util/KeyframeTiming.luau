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

-- How much a one-shot clip (an attack) shows `t` seconds in: up from 0 over `blend`, held, back to 0 over its last
-- `blend` (a clip shorter than two blends peaks at its middle); 0 before it starts and once it's over.
-- `from`: the weight a clip it follows was showing (a strike chained onto a held wind-up starts there, with no dip).
-- `hold`: seconds it keeps its last pose at full weight after its end (a wind-up waiting for its strike), then blends out
function KeyframeTiming.oneShotWeight(t: number, length: number, blend: number, from: number?, hold: number?): number
	local start = from or 0
	local held = hold or 0
	if t < 0 or t >= KeyframeTiming.oneShotEnd(length, blend, held) or (t == 0 and start <= 0) then
		return 0
	end
	local ramp = math.max(math.min(blend, length / 2), 1e-6)
	local blendIn = start + (1 - start) * math.min(1, t / ramp)
	if held <= 0 then
		return math.min(blendIn, (length - t) / ramp)
	end
	return math.min(blendIn, 1 - math.max(0, t - length - held) / ramp)
end

-- When a one-shot (KeyframeTiming.oneShotWeight) is over: at its length, or a held one after its hold and blend out
function KeyframeTiming.oneShotEnd(length: number, blend: number, hold: number?): number
	local held = hold or 0
	if held <= 0 then
		return length
	end
	return length + held + math.max(math.min(blend, length / 2), 1e-6)
end

return KeyframeTiming
