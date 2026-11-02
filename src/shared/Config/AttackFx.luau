--!strict
-- Attack animations and effects (spec 2026-11-02-attack-animations-design): how creatures move in a fight, how long
-- an attack's effect flies, combo timing, and each element's normal attack. Plain data (Lune-tested).
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	CHARGE_GRACE = 0.3, -- seconds a charge waits past its due time for its attack, then fades
	FLIGHT = { Ember = 0.35, Tide = 0.25 }, -- seconds a projectile flies (elements that throw one)
	COMBO = { count = 3, window = 0.45 }, -- a combo's hits over this many seconds, the last with the damage
	-- Each element's normal attack: a thrown projectile, a 3-hit combo up close, or a lightning zip there and back
	ELEMENT = {
		Ember = { kind = "projectile", color = rgb(255, 122, 58) },
		Tide = { kind = "projectile", color = rgb(74, 168, 255) },
		Bloom = { kind = "combo", color = rgb(74, 222, 128) },
		Volt = { kind = "zip", color = rgb(250, 204, 21) },
		Shade = { kind = "combo", color = rgb(167, 139, 250) },
	},
	-- Creatures circle their fight spot: this far (studs, times the creature's size), this fast (turns a second), with
	-- darts out to `dart` studs more
	ORBIT = { radius = 4, speed = 0.15, dart = 1.5 },
}
