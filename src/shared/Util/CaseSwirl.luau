--!strict
-- The glass cases' spiral lights (owner 2026-11-14, concept B "museum vitrine"; Config/Showcase SWIRL): a light circles
-- each card's beam as it climbs from the pad to the top, then starts again at the pad. Roblox-free (Lune-tested):
-- offsets in studs from the pad's middle, y up.
local CaseSwirl = {}

export type Config = { seconds: number, turns: number, radius: number, bottom: number, top: number }
export type Point = { x: number, y: number, z: number, lap: number }

-- Where the light is `t` seconds in, `phase` (0-1) of a lap ahead: `turns` times round a `radius` circle each lap of
-- `seconds`, from `bottom` to `top`; `lap` counts the laps (a new one has jumped back down to the pad)
function CaseSwirl.point(t: number, phase: number, cfg: Config): Point
	local laps = t / cfg.seconds + phase
	local lap = math.floor(laps)
	local u = laps - lap
	local angle = u * cfg.turns * math.pi * 2
	return {
		x = math.cos(angle) * cfg.radius,
		y = cfg.bottom + (cfg.top - cfg.bottom) * u,
		z = math.sin(angle) * cfg.radius,
		lap = lap,
	}
end

return CaseSwirl
