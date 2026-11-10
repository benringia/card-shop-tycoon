--!strict
-- The Frontier valley's effects (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md; Controllers/
-- FrontierFxController, numbers in Config/FrontierValley FX): pure maths, Lune-tested. Nothing here hurts anyone.
local FrontierFxRules = {}

-- How much of a pair of red eyes in the fog shows `distance` studs away: none at `near` or closer (they vanish as you
-- come close), all of it at `far` or further, in between a straight fade
function FrontierFxRules.eyeAlpha(distance: number, fade: { near: number, far: number }): number
	return math.clamp((distance - fade.near) / (fade.far - fade.near), 0, 1)
end

-- Seconds to the next lightning flash: anywhere in `every` { min, max }, from rng (0..1)
function FrontierFxRules.nextFlash(rng: () -> number, every: { number }): number
	return every[1] + (every[2] - every[1]) * rng()
end

-- How far a tremor shakes the camera `t` seconds in (studs, before the controller's own jitter): rising from still and
-- settling back over `length` seconds, never more than `strength`
function FrontierFxRules.shake(t: number, length: number, strength: number): number
	if t <= 0 or t >= length then
		return 0
	end
	return strength * math.sin(math.pi * t / length)
end

return FrontierFxRules
