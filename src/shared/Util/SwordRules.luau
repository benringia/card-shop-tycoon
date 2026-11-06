--!strict
-- The sword's rules both sides use (spec 2026-11-02-you-in-the-fight-design): which cut of the combo a tap starts and
-- when, what a cut or the skill reaches, and which target soft aim turns you to. The server decides hits with these;
-- the client mirrors them to play the right cut at once.
-- Pure (no requires, no Roblox APIs) so tests/ run it in Lune: positions are plain x, z numbers on the ground plane.
local SwordRules = {}

export type Cut = { power: number, hitAt: number, cancelAt: number?, length: number, reach: number, arc: number }
export type LastCut = { index: number, startedAt: number }
export type Target = { id: string, x: number, z: number, radius: number }

-- The cut a tap at `now` starts and when it starts, or nil (the tap is ignored). A tap before the current cut's strike
-- does nothing; from the strike until `comboReset` after the cut ends it queues the next cut (after cut 3 comes cut 1)
-- to start at this one's cancel point (`cancelAt`, the end of its follow-through; the cut's end when it has none) or at
-- once when that has passed; later taps start the combo again. (Sword-moves round: cuts chain before their recovery.)
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
		return last.index % #combo + 1, math.max(now, last.startedAt + (cut.cancelAt or cut.length))
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

-- Does a cut from (px, pz) facing (lookX, lookZ) hit any of these targets? (the client plays the hit sound at once)
function SwordRules.anyInReach(px: number, pz: number, lookX: number, lookZ: number, targets: { Target }, cut: Cut): boolean
	for _, target in targets do
		if SwordRules.inReach(px, pz, lookX, lookZ, target.x, target.z, target.radius, cut.reach, cut.arc) then
			return true
		end
	end
	return false
end

-- Does the dash slash along (sx, sz) -> (ex, ez) hit any of these targets? (the client plays the hit sound at once)
function SwordRules.anyInDashPath(sx: number, sz: number, ex: number, ez: number, targets: { Target }, width: number): boolean
	for _, target in targets do
		if SwordRules.inDashPath(sx, sz, ex, ez, target.x, target.z, target.radius, width) then
			return true
		end
	end
	return false
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

-- A dodge's length from (px, pz) along the unit direction (dirX, dirZ): `base`, or, when it would end inside a foe's
-- footprint, on to that foe's far side plus `margin` (and out of one just behind it), never past `maxLength`. The dash
-- goes through bosses and monsters instead of leaving you standing in them (owner 2026-11-04).
function SwordRules.dashLength(px: number, pz: number, dirX: number, dirZ: number, targets: { Target }, base: number, margin: number, maxLength: number): number
	local length = base
	for _ = 1, #targets do
		local moved = false
		for _, target in targets do
			local dx, dz = target.x - px, target.z - pz
			local along = dx * dirX + dz * dirZ
			local side = math.abs(dx * dirZ - dz * dirX)
			if side < target.radius then
				local half = math.sqrt(target.radius * target.radius - side * side)
				if length > along - half and length < along + half then
					length = along + half + margin
					moved = true
				end
			end
		end
		if not moved or length >= maxLength then
			break
		end
	end
	return math.min(length, maxLength)
end

-- The combo's power per second when tapped without a break (times the creature's ATK, that's its damage per second):
-- chained, each cut runs to its cancel point and the last one to its end
function SwordRules.comboPowerPerSecond(combo: { Cut }): number
	local power, seconds = 0, 0
	for index, cut in combo do
		power += cut.power
		seconds += if index < #combo then cut.cancelAt or cut.length else cut.length
	end
	return if seconds > 0 then power / seconds else 0
end

-- How far a cut's lunge may carry you from (px, pz) along the unit direction (dirX, dirZ): `studs`, or less so you stop
-- `stopMargin` short of a foe the line would run into (0 if you're already that close). Lunges never push into a boss;
-- only the dash goes through (SwordRules.dashLength).
function SwordRules.lungeLength(px: number, pz: number, dirX: number, dirZ: number, targets: { Target }, studs: number, stopMargin: number): number
	local length = studs
	for _, target in targets do
		local dx, dz = target.x - px, target.z - pz
		local along = dx * dirX + dz * dirZ
		local side = math.abs(dx * dirZ - dz * dirX)
		if along > 0 and side < target.radius then
			local entry = along - math.sqrt(target.radius * target.radius - side * side)
			length = math.min(length, entry - stopMargin)
		end
	end
	return math.max(0, length)
end

-- Is a foe (centre tx, tz, `targetRadius` round) hit by the dash slash's path from (sx, sz) to (ex, ez)? Its edge must
-- come within half the path's `width` of the segment.
function SwordRules.inDashPath(sx: number, sz: number, ex: number, ez: number, tx: number, tz: number, targetRadius: number, width: number): boolean
	local vx, vz = ex - sx, ez - sz
	local lengthSquared = vx * vx + vz * vz
	local t = if lengthSquared > 1e-9 then math.clamp(((tx - sx) * vx + (tz - sz) * vz) / lengthSquared, 0, 1) else 0
	local cx, cz = sx + vx * t, sz + vz * t
	local dx, dz = tx - cx, tz - cz
	return math.sqrt(dx * dx + dz * dz) <= targetRadius + width / 2
end

-- The end of a path from (sx, sz) to (ex, ez), pulled back to `maxLength` from its start when it's longer (the server
-- doesn't take a client's word for how far a dash went)
function SwordRules.clampPath(sx: number, sz: number, ex: number, ez: number, maxLength: number): (number, number)
	local vx, vz = ex - sx, ez - sz
	local length = math.sqrt(vx * vx + vz * vz)
	if length <= maxLength or length < 1e-9 then
		return ex, ez
	end
	return sx + vx * maxLength / length, sz + vz * maxLength / length
end

-- A sword skill's shape (sword skills round, spec 2026-11-06-sword-skills-design 3): what the server counts as hit.
-- dash: the path from where you started to where you are (clamped to maxStuds + slack), `width` wide; spin: every foe
-- within `radius` of you; line: `length` x `width` straight ahead; wave: a crescent along the same line at `speed` that
-- bursts on the first foe it touches, hitting every foe within `blast` of that point when it gets there; judgment: the foe you aim at within `range` (within `angle` of your facing, else the nearest around you),
-- `strikes` hits `gap` seconds apart
export type SkillShape = {
	kind: "dash" | "spin" | "line" | "wave" | "judgment",
	radius: number?,
	length: number?,
	width: number?,
	speed: number?,
	range: number?,
	angle: number?,
	strikes: number?,
	gap: number?,
	maxStuds: number?,
	slack: number?,
	blast: number?,
}

-- One foe hit by a skill: `after` seconds after the skill's hit moment, for `share` of its damage
export type SkillHit = { id: string, after: number, share: number }

-- The nearest foe (by its edge) within `range` of (px, pz), any direction
local function nearestWithin(px: number, pz: number, targets: { Target }, range: number): string?
	local best: string? = nil
	local bestEdge = math.huge
	for _, target in targets do
		local dx, dz = target.x - px, target.z - pz
		local edge = math.sqrt(dx * dx + dz * dz) - target.radius
		if edge <= range and edge < bestEdge then
			best, bestEdge = target.id, edge
		end
	end
	return best
end

local function unit(x: number, z: number): (number, number)
	local size = math.sqrt(x * x + z * z)
	return if size > 1e-9 then x / size else 0, if size > 1e-9 then z / size else -1
end

-- How far along a wave's line its crescent first touches a foe (studs from you), or nil when none is in its path
local function firstContact(shape: SkillShape, px: number, pz: number, dirX: number, dirZ: number, targets: { Target }): number?
	local length = shape.length or 0
	local first: number? = nil
	for _, target in targets do
		if SwordRules.inDashPath(px, pz, px + dirX * length, pz + dirZ * length, target.x, target.z, target.radius, shape.width or 0) then
			local along = (target.x - px) * dirX + (target.z - pz) * dirZ
			local contact = math.clamp(along - target.radius, 0, length)
			if not first or contact < first then
				first = contact
			end
		end
	end
	return first
end

-- Who a skill hits, when and for what share: (sx, sz) where it started, (px, pz) where you are at its hit moment and
-- (lookX, lookZ) your facing then. The server lands damage from this; the client predicts its bursts from it.
function SwordRules.skillHits(shape: SkillShape, sx: number, sz: number, px: number, pz: number, lookX: number, lookZ: number, targets: { Target }): { SkillHit }
	local hits: { SkillHit } = {}
	local dirX, dirZ = unit(lookX, lookZ)
	if shape.kind == "wave" then
		local contact = firstContact(shape, px, pz, dirX, dirZ, targets)
		if not contact then
			return hits
		end
		local bx, bz = px + dirX * contact, pz + dirZ * contact
		local after = if (shape.speed or 0) > 0 then contact / (shape.speed :: number) else 0
		for _, target in targets do
			local dx, dz = target.x - bx, target.z - bz
			if math.sqrt(dx * dx + dz * dz) - target.radius <= (shape.blast or 0) then
				table.insert(hits, { id = target.id, after = after, share = 1 })
			end
		end
		return hits
	elseif shape.kind == "judgment" then
		local range = shape.range or 0
		local id = SwordRules.aimTarget(px, pz, dirX, dirZ, targets, range, shape.angle or 0) or nearestWithin(px, pz, targets, range)
		if id then
			local strikes = math.max(1, shape.strikes or 1)
			for index = 1, strikes do
				table.insert(hits, { id = id, after = (index - 1) * (shape.gap or 0), share = 1 / strikes })
			end
		end
		return hits
	end
	for _, target in targets do
		local reached = false
		if shape.kind == "dash" then
			local ex, ez = SwordRules.clampPath(sx, sz, px, pz, (shape.maxStuds or 0) + (shape.slack or 0))
			reached = SwordRules.inDashPath(sx, sz, ex, ez, target.x, target.z, target.radius, shape.width or 0)
		elseif shape.kind == "spin" then
			local dx, dz = target.x - px, target.z - pz
			reached = math.sqrt(dx * dx + dz * dz) - target.radius < (shape.radius or 0)
		elseif shape.kind == "line" then
			local length = shape.length or 0
			reached = SwordRules.inDashPath(px, pz, px + dirX * length, pz + dirZ * length, target.x, target.z, target.radius, shape.width or 0)
		end
		if reached then
			table.insert(hits, { id = target.id, after = 0, share = 1 })
		end
	end
	return hits
end

-- How long after its hit moment a skill reaches its first foe (seconds): a wave's first contact at its speed, the end
-- of its run when none is in its path; 0 for the shapes that land at once
function SwordRules.skillTravel(shape: SkillShape, px: number, pz: number, lookX: number, lookZ: number, targets: { Target }): number
	if shape.kind ~= "wave" or (shape.speed or 0) <= 0 then
		return 0
	end
	local dirX, dirZ = unit(lookX, lookZ)
	local contact = firstContact(shape, px, pz, dirX, dirZ, targets) or shape.length or 0
	return contact / (shape.speed :: number)
end

-- How long a skill's animation holds its pose (frozen at its `hold.at`) so its next key (`snap`, track time) plays
-- just as the skill reaches its foe (`hitAt` + `travel`); 0 when the foe is reached before then
function SwordRules.holdFor(hitAt: number, travel: number, snap: number): number
	return math.max(0, hitAt + travel - snap)
end

-- When a skill frees you to attack and move again (owner 2026-11-07, "free after the hit": every skill costs about the
-- same attack time): its `free.at` (plus its `travel` with `reach`: Thornline, once the vines reach the foe), else its
-- whole length (the Steel Sword's dash, as before)
function SwordRules.skillFreeAt(skill: { hitAt: number, length: number, free: { at: number, reach: boolean? }? }, travel: number): number
	local free = skill.free
	if not free then
		return skill.length
	end
	return free.at + (if free.reach then travel else 0)
end

-- Whether a dodge (at `dodgedAt`, os.clock) between a skill's cast (`castAt`) and its hit moment (`hitAt` after it)
-- cancels its damage (the dodge cancels the move on your screen; owner 2026-11-07); one after the hit doesn't
function SwordRules.skillDodged(castAt: number, hitAt: number, dodgedAt: number?): boolean
	return dodgedAt ~= nil and dodgedAt >= castAt and dodgedAt < castAt + hitAt
end

-- Where a skill's effect lands (the client draws it there): a wave's burst on the first foe it touches, else the end of
-- its run; the judged foe; nil for the shapes drawn around you or along your path
function SwordRules.skillImpact(shape: SkillShape, px: number, pz: number, lookX: number, lookZ: number, targets: { Target }): (number?, number?)
	local dirX, dirZ = unit(lookX, lookZ)
	if shape.kind == "wave" then
		local contact = firstContact(shape, px, pz, dirX, dirZ, targets) or shape.length or 0
		return px + dirX * contact, pz + dirZ * contact
	elseif shape.kind == "judgment" then
		for _, hit in SwordRules.skillHits(shape, px, pz, px, pz, lookX, lookZ, targets) do
			for _, target in targets do
				if target.id == hit.id then
					return target.x, target.z
				end
			end
		end
	end
	return nil, nil
end

return SwordRules
