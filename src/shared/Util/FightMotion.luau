--!strict
-- How a creature moves around in a fight (attack animations spec): it circles its fight spot and darts out now and
-- then, the same on every client for the same seed and time, and holds still while it charges (its motion clock
-- stops). Numbers: Config/AttackFx ORBIT. Pure, Lune-tested.
local FightMotion = {}

export type Clock = { t: number, last: number? }

-- Where the creature is (x, z studs off its spot) at motion time `t`: round the circle at `speed` turns a second,
-- pushed out up to `dart` studs in short bursts
function FightMotion.offset(seed: number, t: number, cfg: any): (number, number)
	local angle = (seed * 2.399 + t * cfg.speed) * 2 * math.pi
	local burst = math.max(0, math.sin(t * 1.7 + seed * 5.1)) ^ 6
	local radius = cfg.radius + cfg.dart * burst
	return math.cos(angle) * radius, math.sin(angle) * radius
end

function FightMotion.newClock(): Clock
	return { t = 0, last = nil }
end

-- The motion time now: it runs with the real clock, except while charging
function FightMotion.advance(clock: Clock, now: number, charging: boolean): number
	local last = clock.last
	if last and not charging then
		clock.t += math.max(0, now - last)
	end
	clock.last = now
	return clock.t
end

return FightMotion
