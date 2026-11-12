--!strict
-- Whether the register's bell rings now (owner 2026-11-12; Config/RegisterBell): a customer waits at the counter, you're
-- not behind it, nothing was scanned for `grace` seconds, and it hasn't rung `max` times yet or within `every`. Pure,
-- Lune-tested.
local RegisterBell = {}

export type Waiting = {
	now: number,
	lastProgressAt: number, -- the checkout's start, or its last scan
	lastRangAt: number?,
	rings: number,
	attended: boolean, -- the owner stands behind the counter
	outOfTown: boolean?, -- the owner is in the Wild (owner 2026-11-12: only heard in town)
}

function RegisterBell.due(w: Waiting, cfg: any): boolean
	if w.attended or w.outOfTown or w.rings >= cfg.max or w.now - w.lastProgressAt < cfg.grace then
		return false
	end
	return w.lastRangAt == nil or w.now - w.lastRangAt >= cfg.every
end

-- Whether ring number `ring` (1 = the first) also shows the toast: every `toastEvery`th, the first included
function RegisterBell.says(ring: number, cfg: any): boolean
	return (ring - 1) % cfg.toastEvery == 0
end

return RegisterBell
