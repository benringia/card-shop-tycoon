--!strict
-- Rules for a boss's debuff on the player (spec 2026-11-02-attack-animations-design, Config/Bosses DEBUFFS): how fast
-- they walk while it holds, and the HUD chip's countdown. Pure, Lune-tested.
local DebuffRules = {}

-- Walking speed from the speed before: 0 while down, slowed by a debuff's `slow` share, else unchanged
function DebuffRules.walkSpeed(base: number, down: boolean, slow: number?): number
	if down then
		return 0
	end
	return base * (1 - (slow or 0))
end

-- Jumping from the height before: none while down or frozen solid (a `slow` of 1), else unchanged
function DebuffRules.jumpHeight(base: number, down: boolean, slow: number?): number
	if down or (slow or 0) >= 1 then
		return 0
	end
	return base
end

-- What a debuff does `elapsed` seconds after it landed: whether it stuns (no sword, skill or dodge) and the share it
-- takes off walking (1: held still). A debuff with `jolt` (Electrocuted, the Storm Sovereign's thunderclap; the owner
-- 2026-11-11: "stun for 1 sec every 3 seconds") stuns and holds only in its jolts, `jolt.seconds` at the start of every
-- `jolt.every`; the others hold the same the whole time
export type Spec = { seconds: number, stun: boolean?, slow: number?, jolt: { every: number, seconds: number }? }
function DebuffRules.effectAt(spec: Spec, elapsed: number): (boolean, number?)
	local jolt = spec.jolt
	if jolt then
		local at = elapsed + 1e-6 -- the server's clock adds up 0.1 s steps: 2.9999999 is 3
		local jolting = at >= 0 and at % jolt.every < jolt.seconds
		return jolting, if jolting then 1 else nil
	end
	return spec.stun == true, spec.slow
end

-- When each of its jolts starts, in seconds after it landed (none without jolts)
function DebuffRules.joltTimes(spec: Spec): { number }
	local times = {}
	local jolt = spec.jolt
	if not jolt or jolt.every <= 0 then
		return times
	end
	local at = 0
	while at < spec.seconds - 1e-9 do
		table.insert(times, at)
		at += jolt.every
	end
	return times
end

-- The chip's seconds left, in tenths ("1.3")
function DebuffRules.countdown(left: number): string
	return string.format("%.1f", math.max(0, left))
end

return DebuffRules
