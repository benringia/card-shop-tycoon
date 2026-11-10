--!strict
-- A boss between its moves (the owner 2026-11-10: "add random animations to the boss instead of just standing still
-- and attacking... walking around while waiting for his next attack or roaring. something intimidating but not
-- limiting its attack speed"; Config/Bosses IDLE, drawn by MonsterController): it walks to a new spot near its own,
-- roars or stomps, a second or two apart, only after its intro and never while a move plays; it attacks from wherever
-- it stands (a move only stops its feet). All on the client: its attacks keep the server's clock. Positions are in its
-- spot's own space: x to its right, z behind it (the fighters are in front, -z). Pure, Lune-tested.
local BossIdleRules = {}

local function smooth(a: number): number
	local t = math.clamp(a, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Whether it may start something now: past its intro (`introEnd`), past its last move (`busyUntil`), standing
function BossIdleRules.free(now: number, busyUntil: number, introEnd: number, fainted: boolean): boolean
	return not fainted and now >= introEnd and now >= busyUntil
end

-- Which idle action a roll (0-1) picks, by `weights` (action -> weight; the same pick for the same roll)
function BossIdleRules.pick(roll: number, weights: { [string]: number }): string
	local names = {}
	local total = 0
	for name, weight in weights do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local at = roll * total
	for _, name in names do
		at -= weights[name]
		if at < 0 then
			return name
		end
	end
	return names[#names]
end

-- Seconds till the next action, from a roll (0-1) across `range`
function BossIdleRules.gap(roll: number, range: { number }): number
	return range[1] + (range[2] - range[1]) * roll
end

-- A spot to walk to from two rolls (0-1), `scale` times the config's reach (a bigger boss walks further): up to
-- `wander.radius` either side, from `wander.front` in front of its own spot to `back` of the radius behind it
function BossIdleRules.spot(rollX: number, rollZ: number, scale: number, cfg: any): (number, number)
	local wander = cfg.wander
	local x = (rollX * 2 - 1) * wander.radius * scale
	local z = -wander.front * scale + rollZ * (wander.front + wander.radius * wander.back) * scale
	return x, z
end

-- How long a walk from (ax, az) to (bx, bz) takes at `speed` studs a second
function BossIdleRules.walkSeconds(ax: number, az: number, bx: number, bz: number, speed: number): number
	return math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) / math.max(speed, 1e-3)
end

-- Where that walk has it `t` seconds in (eased at both ends), its yaw facing the way it goes (yaw 0 faces -z, the
-- fight), and whether it's there (then facing the fight again)
function BossIdleRules.walk(t: number, ax: number, az: number, bx: number, bz: number, speed: number): (number, number, number, boolean)
	local seconds = BossIdleRules.walkSeconds(ax, az, bx, bz, speed)
	if t >= seconds then
		return bx, bz, 0, true
	end
	local share = smooth(t / math.max(seconds, 1e-3))
	local dx, dz = bx - ax, bz - az
	return ax + dx * share, az + dz * share, math.atan2(-dx, -dz), false
end

return BossIdleRules
