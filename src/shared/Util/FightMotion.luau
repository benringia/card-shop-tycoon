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

-- The way it's going at motion time `t`, as a turn about the vertical (radians; 0 faces its marker's look, -z): it
-- faces its path while it circles (owner 2026-11-05: "Thunderhorn is walking sideways")
function FightMotion.heading(seed: number, t: number, cfg: any): number
	local omega = cfg.speed * 2 * math.pi
	local angle = (seed * 2.399 + t * cfg.speed) * 2 * math.pi
	local wave = math.sin(t * 1.7 + seed * 5.1)
	local burst = math.max(0, wave) ^ 6
	local radius = cfg.radius + cfg.dart * burst
	local grow = if wave > 0 then cfg.dart * 6 * wave ^ 5 * math.cos(t * 1.7 + seed * 5.1) * 1.7 else 0
	local dx = -math.sin(angle) * radius * omega + math.cos(angle) * grow
	local dz = math.cos(angle) * radius * omega + math.sin(angle) * grow
	return math.atan2(-dx, -dz)
end

-- `current` turned toward `target` (radians) the short way round, easing in at `rate` (a long frame gets all the way)
function FightMotion.turn(current: number, target: number, dt: number, rate: number): number
	local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + diff * (1 - math.exp(-rate * dt))
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
