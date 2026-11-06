--!strict
-- How an NPC (customer, town walker, shop worker; server Util/NpcMotion) follows a path: each waypoint on the way
-- counts as reached a little early so the next step goes out before it stops (it stuttered, stopping at every one),
-- the walk's end closely; trying to walk without getting anywhere is being stuck (it walked in place); the walk clip
-- plays at the feet's pace. Pure (Lune-tested); numbers in Config/Customers NPC_STEP and WALK_CLIP_PACE.
local WalkStep = {}

export type Config = { lookahead: number, finish: number, stallSeconds: number, stallStuds: number }

-- Whether a waypoint `flatDistance` studs away (across the ground) counts as reached
function WalkStep.reached(flatDistance: number, isLast: boolean, cfg: Config): boolean
	return flatDistance <= (if isLast then cfg.finish else cfg.lookahead)
end

-- Stuck: it has tried for stallSeconds and covered under stallStuds
function WalkStep.stalled(moved: number, seconds: number, cfg: Config): boolean
	return seconds >= cfg.stallSeconds and moved < cfg.stallStuds
end

-- Seconds a step of `distance` studs may take at `speed`: twice the walk time plus `grace`
function WalkStep.limit(distance: number, speed: number, grace: number): number
	return distance / math.max(speed, 1) * 2 + grace
end

-- The walk clip's speed for feet moving `speed` studs a second (the clip's own pace is `pace`), 0.5-2
function WalkStep.clipSpeed(speed: number, pace: number): number
	return math.clamp(speed / pace, 0.5, 2)
end

return WalkStep
