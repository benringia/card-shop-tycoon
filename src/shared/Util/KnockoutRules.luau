--!strict
-- Knocked out in the Wild (owner 2026-11-12; spec 2026-11-12-timed-upgrades-revive-design): the countdown to waking at
-- the spring, which waits while the "Revive here" purchase prompt is open (a minute at most). Pure, Lune-tested.
local KnockoutRules = {}

-- Seconds left of a `total`-second countdown started at `startedAt`, with `pausedFor` seconds of it paused
function KnockoutRules.left(startedAt: number, pausedFor: number, now: number, total: number): number
	return math.max(0, total - (now - startedAt - pausedFor))
end

-- The seconds paused so far: `pausedFor` before, plus the pause running since `pausedAt` (if any), `maxPause` at most
function KnockoutRules.pausedFor(pausedAt: number?, pausedFor: number, now: number, maxPause: number): number
	local total = pausedFor + (if pausedAt then now - pausedAt else 0)
	return math.min(total, maxPause)
end

return KnockoutRules
