--!strict
-- The maths of the sword swing arcs (spec 2026-11-04-sword-moves-design, "Candy sparkle arc"; drawn by Util/HitFx):
-- a Beam bent into a circular arc in the swing's plane, wiped along it by a moving window of transparency, and where
-- a hit's burst sits. Angles are degrees in the swing's plane: (r cos a, r sin a). Roblox-free, so Lune tests it.
local SwordArcRules = {}

-- How far a Beam's two control points sit along its ends' tangents so it bulges into a circular arc of `sweep`
-- degrees (one cubic Bezier: close to a circle up to 180)
function SwordArcRules.curveSize(radius: number, sweep: number): number
	return 4 / 3 * radius * math.tan(math.rad(math.abs(sweep)) / 4)
end

-- The point `t` (0-1) of the way along an arc of `radius` from `start` degrees through `sweep` degrees
function SwordArcRules.point(radius: number, start: number, sweep: number, t: number): (number, number)
	local angle = math.rad(start + sweep * t)
	return radius * math.cos(angle), radius * math.sin(angle)
end

-- The unit direction the arc runs at `t` (the way of its sweep)
function SwordArcRules.tangent(start: number, sweep: number, t: number): (number, number)
	local angle = math.rad(start + sweep * t)
	local way = if sweep < 0 then -1 else 1
	return -math.sin(angle) * way, math.cos(angle) * way
end

-- The arc's transparency along its length as NumberSequence points { time, value }: lit from `trail` behind the head
-- (at `progress`, 0-1, brightest) to the head, dark ahead of it past a `soft` edge; `fade` (0-1) fades the lot out
function SwordArcRules.wipe(progress: number, trail: number, soft: number, fade: number): { { number } }
	local head = math.clamp(progress, 0, 1)
	local keep = 1 - math.clamp(fade, 0, 1)
	local function shade(value: number): number
		return 1 - (1 - value) * keep
	end
	if head <= 1e-3 or keep <= 0 then
		return { { 0, 1 }, { 1, 1 } }
	end
	local points: { { number } } = {}
	local tail = head - trail
	if tail > 1e-3 then
		table.insert(points, { 0, 1 })
		table.insert(points, { tail, 1 })
	else
		table.insert(points, { 0, shade(head / trail) })
	end
	if head >= 1 - 1e-3 then
		table.insert(points, { 1, shade(0) })
		return points
	end
	table.insert(points, { head, shade(0) })
	local after = head + soft
	if after < 1 - 1e-3 then
		table.insert(points, { after, 1 })
		table.insert(points, { 1, 1 })
	else
		table.insert(points, { 1, shade((1 - head) / soft) })
	end
	return points
end

-- Where a hit's burst goes on the ground plane: from the foe's centre (tx, tz) toward the attacker (fx, fz), `share` of
-- its radius out (on its side facing you, not hidden inside a big boss), never past the attacker
function SwordArcRules.hitPoint(tx: number, tz: number, radius: number, fx: number, fz: number, share: number): (number, number)
	local dx, dz = fx - tx, fz - tz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		return tx, tz
	end
	local reach = math.min(radius * share, distance)
	return tx + dx / distance * reach, tz + dz / distance * reach
end

-- Where a hit's impact holder looks (Util/HitFx.impact; owner 2026-11-08): toward the camera at (`eyeX`, `eyeZ`) but
-- level, at the hit's own height (turned up, the flat slash arc showed edge-on); nil with the camera straight above
function SwordArcRules.impactFacing(atX: number, atY: number, atZ: number, eyeX: number, eyeZ: number): (number?, number?, number?)
	local dx, dz = eyeX - atX, eyeZ - atZ
	if dx * dx + dz * dz < 1e-6 then
		return nil, nil, nil
	end
	return eyeX, atY, eyeZ
end

return SwordArcRules
