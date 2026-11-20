--!strict
-- A new shop's short waits (Config/Early; owner 2026-11-20: "players should NOT wait for something in early game"): how
-- much of the early game a shop still has at its level, and what an order's delivery, a fainted creature's rest and a
-- station's timer come to. Server services use them; clients show the same numbers. Pure, Lune-tested.
local EarlyRules = {}

type Early = { fullUntil: number, goneAt: number, delivery: number, rest: number, stationWait: number }

-- 1 up to `fullUntil`, 0 from `goneAt`, straight down in between
function EarlyRules.share(level: number, early: Early): number
	if level <= early.fullUntil then
		return 1
	elseif level >= early.goneAt then
		return 0
	end
	return (early.goneAt - level) / (early.goneAt - early.fullUntil)
end

local function between(level: number, early: Early, earlyValue: number, lateValue: number): number
	return lateValue + (earlyValue - lateValue) * EarlyRules.share(level, early)
end

-- Seconds an order takes at this shop level (`late`: Config/Stock DELIVERY_SECONDS)
function EarlyRules.delivery(level: number, early: Early, late: number): number
	return math.max(1, math.round(between(level, early, early.delivery, late)))
end

-- Seconds a fainted creature rests at this shop level (`late`: Config/Combat REST_SECONDS)
function EarlyRules.rest(level: number, early: Early, late: number): number
	return math.max(1, math.round(between(level, early, early.rest, late)))
end

-- "5:00"
function EarlyRules.restWords(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- A station's timer (`seconds`: Util/UpgradeRules.seconds) at this shop level
function EarlyRules.stationWait(seconds: number, level: number, early: Early): number
	return math.max(1, math.round(seconds * between(level, early, early.stationWait, 1)))
end

return EarlyRules
