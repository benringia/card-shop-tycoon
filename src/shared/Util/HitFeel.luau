--!strict
-- Hit feel (spec 2026-11-25-hit-feel-design): a monster's reaction to a hit (a jolt and lean away from the hitter, a pop,
-- its clip frozen a moment) and its curve, a wild monster's lunge into a strike, its calm steps round its spot and the
-- cap on how far they take it from its server spot. Numbers: Config/HitFeel. Plain numbers in and out (no Vector3), so
-- Lune tests it; MonsterController draws it.
local HitFeel = {}

export type ReactCfg = {
	knock: number,
	bigKnock: number,
	tilt: number,
	bigTilt: number,
	pop: number,
	out: number,
	back: number,
	bigBack: number,
	stop: number,
	bigStop: number,
	bossShare: number,
}
-- `dx`, `dz`: the unit push direction (away from the hitter); `tilt` radians
export type Reaction = { at: number, dx: number, dz: number, knock: number, tilt: number, pop: number, out: number, back: number, stop: number }

-- A hit at `now` on a monster standing at (atX, atZ) from a hitter at (fromX, fromZ); `big` a finisher, dash slash, a
-- creature's finishing hit or a super; `boss` a boss (a share of the jolt, no pop). A hitter standing on it pushes it
-- straight back (+z)
function HitFeel.reaction(now: number, atX: number, atZ: number, fromX: number, fromZ: number, big: boolean, boss: boolean, cfg: ReactCfg): Reaction
	local dx, dz = atX - fromX, atZ - fromZ
	local length = math.sqrt(dx * dx + dz * dz)
	if length > 0.05 then
		dx, dz = dx / length, dz / length
	else
		dx, dz = 0, 1
	end
	local share = if boss then cfg.bossShare else 1
	return {
		at = now,
		dx = dx,
		dz = dz,
		knock = (if big then cfg.bigKnock else cfg.knock) * share,
		tilt = math.rad(cfg.tilt * (if big then cfg.bigTilt else 1)) * share,
		pop = if boss then 1 else cfg.pop,
		out = cfg.out,
		back = cfg.back * (if big then cfg.bigBack else 1),
		stop = cfg.stop * (if big then cfg.bigStop else 1),
	}
end

-- How much of the reaction shows at `now` (0..1): out fast over its `out` s, back over its `back` s (easing in); nil
-- once it's over
function HitFeel.amount(r: Reaction, now: number): number?
	local t = now - r.at
	if t < r.out then
		return math.max(0, t / r.out)
	end
	local back = (t - r.out) / r.back
	if back >= 1 then
		return nil
	end
	return (1 - back) ^ 2
end

-- Whether its own animation is held still (its hit-stop)
function HitFeel.frozen(r: Reaction, now: number): boolean
	return now - r.at < r.stop
end

-- How far into its lunge (0..1) a wild monster is `t` s into a strike clip `length` s long: out by `rise`, held to
-- `hold`, back by the end; nil once it's over (or with no clip)
function HitFeel.lunge(t: number, length: number, cfg: { rise: number, hold: number }): number?
	if length <= 0 or t >= length then
		return nil
	end
	local share = math.max(0, t / length)
	if share < cfg.rise then
		return share / cfg.rise
	elseif share < cfg.hold then
		return 1
	end
	return 1 - (share - cfg.hold) / (1 - cfg.hold)
end

-- An offset (studs, across and along its spot) pulled back to at most `max` from its spot, the same way
function HitFeel.clampDrift(x: number, z: number, max: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length <= max or length <= 0 then
		return x, z
	end
	return x / length * max, z / length * max
end

-- A wild monster's steps as the boss walks' config (Util/BossIdleRules): `base` (Config/Bosses IDLE_PACK) with the calm
-- steps of `step` (Config/HitFeel STEP) and nothing but walks
function HitFeel.stepIdle(base: any, step: { gap: { number }, radius: number, front: number, back: number, speed: number }): any
	local idle = table.clone(base)
	idle.gap = { step.gap[1], step.gap[2] }
	idle.weights = { wander = 1, roar = 0, stomp = 0 }
	idle.wander = { radius = step.radius, front = step.radius * step.front, back = step.back, speed = step.speed }
	return idle
end

return HitFeel
