--!strict
-- The sword's rules both sides use (spec 2026-11-02-you-in-the-fight-design): which cut of the combo a tap starts and
-- when, what a cut or the skill reaches, and which target soft aim turns you to. The server decides hits with these;
-- the client mirrors them to play the right cut at once.
-- Pure (no requires, no Roblox APIs) so tests/ run it in Lune: positions are plain x, z numbers on the ground plane.
local SwordRules = {}

export type Cut = { power: number, hitAt: number, length: number, reach: number, arc: number }
export type LastCut = { index: number, startedAt: number }
export type Target = { id: string, x: number, z: number, radius: number }

-- The cut a tap at `now` starts and when it starts, or nil (the tap is ignored). A tap before the current cut's strike
-- does nothing; from the strike until `comboReset` after the cut ends it queues the next cut (after cut 3 comes cut 1)
-- to start when this one ends; later taps start the combo again.
function SwordRules.nextCut(combo: { Cut }, last: LastCut?, now: number, comboReset: number): (number?, number?)
	if #combo == 0 then
		return nil, nil
	end
	if not last then
		return 1, now
	end
	local cut = combo[last.index]
	local elapsed = now - last.startedAt
	if not cut then
		return 1, now
	elseif elapsed < cut.hitAt then
		return nil, nil
	elseif elapsed < cut.length + comboReset then
		return last.index % #combo + 1, math.max(now, last.startedAt + cut.length)
	end
	return 1, now
end

-- Is a target (centre tx, tz, `targetRadius` studs round) hit by a cut from (px, pz) facing (lookX, lookZ)? Its edge
-- must be within `reach` and its centre within `arcDegrees` / 2 of the facing; standing inside its edge always hits.
function SwordRules.inReach(px: number, pz: number, lookX: number, lookZ: number, tx: number, tz: number, targetRadius: number, reach: number, arcDegrees: number): boolean
	local dx, dz = tx - px, tz - pz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance <= targetRadius then
		return true
	elseif distance - targetRadius > reach then
		return false
	end
	local lookLength = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookLength < 1e-6 then
		return false
	end
	return (dx * lookX + dz * lookZ) / (distance * lookLength) >= math.cos(math.rad(arcDegrees / 2))
end

-- The skill: every target whose edge is within `radius` of you
function SwordRules.inRadius(px: number, pz: number, tx: number, tz: number, targetRadius: number, radius: number): boolean
	local dx, dz = tx - px, tz - pz
	return math.sqrt(dx * dx + dz * dz) - targetRadius <= radius
end

-- Soft aim: the target whose edge is nearest, within `range` and within `angleDegrees` of the facing (nil if none)
function SwordRules.aimTarget(px: number, pz: number, lookX: number, lookZ: number, targets: { Target }, range: number, angleDegrees: number): string?
	local best: string? = nil
	local bestEdge = math.huge
	for _, target in targets do
		local dx, dz = target.x - px, target.z - pz
		local distance = math.sqrt(dx * dx + dz * dz)
		local edge = distance - target.radius
		if edge <= range and edge < bestEdge and SwordRules.inReach(px, pz, lookX, lookZ, target.x, target.z, target.radius, range, angleDegrees * 2) then
			best, bestEdge = target.id, edge
		end
	end
	return best
end

-- The combo's power per second when tapped without a break (times the creature's ATK, that's its damage per second)
function SwordRules.comboPowerPerSecond(combo: { Cut }): number
	local power, seconds = 0, 0
	for _, cut in combo do
		power += cut.power
		seconds += cut.length
	end
	return if seconds > 0 then power / seconds else 0
end

return SwordRules
