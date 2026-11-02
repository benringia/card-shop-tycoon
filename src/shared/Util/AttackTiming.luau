--!strict
-- When an attack's picture plays (attack animations spec): a "charge" event says the hit lands in `lead` seconds, so
-- the effect is released early enough to arrive with it; a charge that never gets its attack (the attacker was
-- stunned, fainted, swapped out) fades; a combo spreads its hits over a short window. Pure, Lune-tested.
local AttackTiming = {}

export type Schedule = { releaseIn: number, impactIn: number }

-- Release `flight` seconds before the impact (at once if the lead is shorter: the effect flies faster); no lead at all
-- is an instant strike
function AttackTiming.schedule(lead: number, flight: number): Schedule
	local impact = math.max(0, lead)
	return { releaseIn = math.max(0, impact - flight), impactIn = impact }
end

-- A charge whose attack hasn't come `grace` seconds after it was due
function AttackTiming.expired(chargedAt: number, lead: number, now: number, grace: number): boolean
	return now > chargedAt + lead + grace
end

-- `count` hits evenly over `window` seconds, the last at its end (where the damage number shows)
function AttackTiming.comboTimes(count: number, window: number): { number }
	local times = {}
	for index = 1, count do
		table.insert(times, window * index / count)
	end
	return times
end

return AttackTiming
