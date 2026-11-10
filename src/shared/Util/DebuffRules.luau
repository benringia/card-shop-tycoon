--!strict
-- Rules for a boss's debuff on the player (spec 2026-11-02-attack-animations-design, Config/Bosses DEBUFFS): how fast
-- they walk while it holds, and the HUD chip's countdown. Pure, Lune-tested.
local DebuffRules = {}

-- Walking speed from the speed before: 0 while down, slowed by a debuff's `slow` share, else unchanged
function DebuffRules.walkSpeed(base: number, down: boolean, slow: number?): number
	if down then
		return 0
	end
	return base * (1 - (slow or 0))
end

-- Jumping from the height before: none while down or frozen solid (a `slow` of 1), else unchanged
function DebuffRules.jumpHeight(base: number, down: boolean, slow: number?): number
	if down or (slow or 0) >= 1 then
		return 0
	end
	return base
end

-- The chip's seconds left, in tenths ("1.3")
function DebuffRules.countdown(left: number): string
	return string.format("%.1f", math.max(0, left))
end

return DebuffRules
