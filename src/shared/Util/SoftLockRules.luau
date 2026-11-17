--!strict
-- The soft lock's rules (owner 2026-11-15, look A; Config/SoftLock): which enemy Tab or the Target button picks next
-- (nearest edge first, on outward, round again), which one a tap lands on (on screen), what a tap does to the lock,
-- whether a lock still holds and the fight's own lock on the nearest. Client Util/SoftLock decides with these. Pure (no
-- requires, no Roblox APIs).
local SoftLockRules = {}

export type Target = { id: string, x: number, z: number, radius: number }
export type OnScreen = { id: string, x: number, y: number, r: number } -- px: its middle and its radius on screen

function SoftLockRules.has(targets: { Target }, id: string?): boolean
	if not id then
		return false
	end
	for _, target in targets do
		if target.id == id then
			return true
		end
	end
	return false
end

-- The next enemy after `current`, nearest edge to (px, pz) first; the nearest when `current` is nil or gone
function SoftLockRules.cycle(targets: { Target }, current: string?, px: number, pz: number): string?
	if #targets == 0 then
		return nil
	end
	local order = table.clone(targets)
	local function edge(target: Target): number
		local dx, dz = target.x - px, target.z - pz
		return math.sqrt(dx * dx + dz * dz) - target.radius
	end
	table.sort(order, function(a, b)
		local ea, eb = edge(a), edge(b)
		return if ea ~= eb then ea < eb else a.id < b.id
	end)
	for index, target in order do
		if target.id == current then
			return order[index % #order + 1].id
		end
	end
	return order[1].id
end

-- The lock this frame (owner 2026-11-17: "Target should be automatically locked when fight starts"): `current` while
-- it stands; with `auto` on (the fight's start, until you let go yourself) the nearest enemy when nothing is locked or
-- the locked one fell; else nothing
function SoftLockRules.keep(targets: { Target }, current: string?, auto: boolean, px: number, pz: number): string?
	if SoftLockRules.has(targets, current) then
		return current
	end
	return if auto then SoftLockRules.cycle(targets, nil, px, pz) else nil
end

-- The enemy a tap at (tapX, tapY) lands on: inside its circle on screen (plus `slack` px), the nearest middle
function SoftLockRules.pick(onScreen: { OnScreen }, tapX: number, tapY: number, slack: number): string?
	local best: string? = nil
	local bestDistance = math.huge
	for _, point in onScreen do
		local dx, dy = tapX - point.x, tapY - point.y
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance <= point.r + slack and distance < bestDistance then
			best, bestDistance = point.id, distance
		end
	end
	return best
end

-- A press that barely moved and let go quickly (a drag or a hold turns the camera)
function SoftLockRules.isTap(dx: number, dy: number, seconds: number, cfg: { TAP_PIXELS: number, TAP_SECONDS: number }): boolean
	return math.sqrt(dx * dx + dy * dy) < cfg.TAP_PIXELS and seconds <= cfg.TAP_SECONDS
end

-- The lock after a tap on `tapped` (nil: empty ground, which keeps it): your target again lets go
function SoftLockRules.afterTap(current: string?, tapped: string?): string?
	if not tapped then
		return current
	end
	return if tapped == current then nil else tapped
end

return SoftLockRules
