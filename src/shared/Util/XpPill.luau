--!strict
-- A number counting up when it changes (the party's level chips, the level-up pillar's number; it began as the XP
-- pill's, owner 2026-11-03 round 3 pick B, now in the party dock: Util/PartyDock). Pure, Lune-tested.
local XpPill = {}

-- The number shown `t` (0-1) of the way through a count from `from` to `to`: eased out, whole numbers, never past `to`
function XpPill.countUp(from: number, to: number, t: number): number
	local progress = math.clamp(t, 0, 1)
	local eased = 1 - (1 - progress) ^ 3
	local shown = from + (to - from) * eased
	if progress >= 1 then
		return to
	end
	return if to >= from then math.min(math.floor(shown), to) else math.max(math.ceil(shown), to)
end

return XpPill
