--!strict
-- A beaten monster's knockout flight (owner 2026-11-18, pick A "make it smooth"; Config/MonsterKO): launched away from
-- the winner on its own gravity, spinning end over end, bouncing on the ground (its middle stays half its turned height
-- above it) and off walls, until it settles; then it eases onto its back (`rest`). Plain numbers, stepped in fixed
-- slices so the flight is the same at any frame rate; the client (Util/MonsterKO) draws it. Pure, Lune-tested.
local MonsterKOMotion = {}

export type State = {
	x: number, -- its middle
	y: number,
	z: number,
	vx: number, -- studs a second
	vy: number,
	vz: number,
	angle: number, -- degrees turned end over end (backward, away from the winner)
	spin: number, -- degrees a second
	bounces: number,
	time: number, -- seconds since the launch
	settled: boolean,
}

export type Cfg = {
	speed: number,
	up: number,
	gravity: number,
	spin: number,
	restitution: number,
	friction: number,
	spinKeep: number,
	bounces: number,
	rest: number,
	maxFlight: number,
	bump: number,
}

local SLICE = 1 / 120 -- seconds: the longest step, so a slow frame flies the same path as quick ones

-- Launched from its middle at `x, y, z` along `dirX, dirZ` (any length; none: straight up), `power` times as hard (an
-- elite's)
function MonsterKOMotion.launch(x: number, y: number, z: number, dirX: number, dirZ: number, cfg: Cfg, power: number): State
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	local ux = if length > 1e-6 then dirX / length else 0
	local uz = if length > 1e-6 then dirZ / length else 0
	return {
		x = x,
		y = y,
		z = z,
		vx = ux * cfg.speed * power,
		vy = cfg.up * power,
		vz = uz * cfg.speed * power,
		angle = 0,
		spin = cfg.spin * power,
		bounces = 0,
		time = 0,
		settled = false,
	}
end

-- How far its middle sits above the ground turned `angle` degrees end over end: a box `height` tall and `depth` long
-- along its flight
function MonsterKOMotion.halfHeight(angle: number, height: number, depth: number): number
	local turn = math.rad(angle)
	return (math.abs(math.cos(turn)) * height + math.abs(math.sin(turn)) * depth) / 2
end

-- One frame of `dt` seconds over ground at height `ground`: the new state, and "bounce" or "settle" if it happened
-- this frame
function MonsterKOMotion.step(state: State, dt: number, ground: number, height: number, depth: number, cfg: Cfg): (State, string?)
	if state.settled then
		return state, nil
	end
	local s = table.clone(state)
	local left = math.max(dt, 0)
	local event: string? = nil
	while left > 1e-9 and not s.settled do
		local slice = math.min(left, SLICE)
		left -= slice
		s.vy -= cfg.gravity * slice
		s.x += s.vx * slice
		s.y += s.vy * slice
		s.z += s.vz * slice
		s.angle += s.spin * slice
		s.time += slice
		local floor = ground + MonsterKOMotion.halfHeight(s.angle, height, depth)
		if s.y <= floor then
			s.y = floor -- rising ground (a slope) or a turn putting a corner down lifts it too
			if s.vy < 0 then
				local fall = -s.vy
				s.bounces += 1
				if s.bounces >= cfg.bounces or fall * cfg.restitution < cfg.rest then
					s.settled = true
					s.vx, s.vy, s.vz = 0, 0, 0
					event = "settle"
				else
					s.vy = fall * cfg.restitution
					s.vx *= cfg.friction
					s.vz *= cfg.friction
					s.spin *= cfg.spinKeep
					event = "bounce"
				end
			end
		end
		if not s.settled and s.time >= cfg.maxFlight then
			s.settled = true -- caught on something: it settles where it is (the client eases it down)
			s.vx, s.vy, s.vz = 0, 0, 0
			event = "settle"
		end
	end
	return s, event
end

-- It hit a wall or a rock whose face points along `nx, nz` (outward): bounces back off it, `cfg.bump` as fast; moving
-- away from it, nothing changes
function MonsterKOMotion.bump(state: State, nx: number, nz: number, cfg: Cfg): State
	local length = math.sqrt(nx * nx + nz * nz)
	if length < 1e-6 then
		return state
	end
	local ux, uz = nx / length, nz / length
	local into = state.vx * ux + state.vz * uz
	if into >= 0 then
		return state
	end
	local s = table.clone(state)
	s.vx = (state.vx - 2 * into * ux) * cfg.bump
	s.vz = (state.vz - 2 * into * uz) * cfg.bump
	return s
end

-- Where it rests after landing at `angle`: lying down, never standing. A body taller than it is long lies on its back
-- or its face (90 or 270), a long one (a wolf, a crab) on its back, feet up (180); the nearest such turn, one ahead of
-- it costing less than one behind (it rolls on rather than back)
function MonsterKOMotion.rest(angle: number, height: number, depth: number): number
	local period = if height >= depth then 180 else 360
	local offset = if height >= depth then 90 else 180
	local behind = math.floor((angle - offset) / period) * period + offset
	local ahead = behind + period
	local back, forward = angle - behind, ahead - angle
	return if forward < back * 1.5 then ahead else behind
end

return MonsterKOMotion
