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
	MAX_ACTIVE = 12, -- effects playing at once (more are skipped; the damage numbers still show)
	MAX_ACTIVE_LOW = 4, -- with the low-graphics switch off (Util/Extras)
	-- Roblox-licensed Pro Sound Effects
	SOUNDS = {
		charge = "rbxassetid://9116394545", -- Magic Glows Chiming Hits 1
		Ember = { release = "rbxassetid://9114463208", hit = "rbxassetid://9119746598" }, -- Flame Licks 7, Sword Hit 1
		Tide = { release = "rbxassetid://9126013644", hit = "rbxassetid://9125703162" }, -- Swish Sharp 13, Mud Puddle Splash 19
		Bloom = { hit = "rbxassetid://9113612888" }, -- Buggy Whip Quick Swish Crack 11
		Volt = { hit = "rbxassetid://9114277757" }, -- Electric Zaps 12
		Shade = { hit = "rbxassetid://9119749812" }, -- Sword Swishes 4
	},
	VOLUME = 0.45,
	CHARGE_LIGHT = 3, -- a charging creature's glow (PointLight brightness at full charge)
	PROJECTILE_SIZE = 1.2, -- studs
	ARC = { Ember = 6, Tide = 0 }, -- studs a projectile rises at its midpoint
	BURST = 26, -- particles in an impact
	DASH = { combo = 0.7, zip = 0.6 }, -- share of the way to its target a creature dashes for a combo or a zip
	-- Creatures circle their fight spot: this far (studs, times the creature's size), this fast (turns a second), with
	-- darts out to `dart` studs more
	ORBIT = { radius = 4, speed = 0.15, dart = 1.5 },
}
