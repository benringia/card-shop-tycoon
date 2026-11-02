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
	-- Pet button moves and super moves (Config/Combat ABILITIES and SIGNATURES kinds): each lands with its event, its
	-- effect at once (style, colour, how long a lasting one stays, seconds)
	SPECIALS = {
		Fireball = { style = "bigball", color = rgb(255, 122, 58) },
		Wave = { style = "wave", color = rgb(74, 168, 255) },
		Snare = { style = "snare", color = rgb(74, 222, 128), seconds = 4 },
		Overcharge = { style = "aura", color = rgb(250, 204, 21), seconds = 3 },
		Curse = { style = "mist", color = rgb(167, 139, 250), seconds = 5 },
		Inferno = { style = "inferno", color = rgb(255, 90, 26), seconds = 6 },
		TidalShield = { style = "shield", color = rgb(96, 196, 255), seconds = 4 },
		Stampede = { style = "stampede", color = rgb(250, 204, 21) },
		Eclipse = { style = "eclipse", color = rgb(167, 139, 250), seconds = 3 },
		Supernova = { style = "nova", color = rgb(255, 209, 102) },
		Devour = { style = "devour", color = rgb(139, 92, 246) },
	},
	SPECIAL_SOUND = "rbxassetid://9116394545", -- Magic Glows Chiming Hits 1 (with the element's hit sound)
	-- Creatures circle their fight spot: this far (studs, times the creature's size), this fast (turns a second), with
	-- darts out to `dart` studs more
	ORBIT = { radius = 4, speed = 0.15, dart = 1.5 },
	-- Bosses' moves (keyed clips in ReplicatedStorage.MonsterAnimations/<boss id>, Util/MonsterMoves): `strike` the
	-- effect where a normal attack lands, `release` where a ring's attack lands, `color` both and the particles pulling
	-- in while it winds up a ring; Pro Sound Effects for each. No Prism Hydra yet (it will be remodelled).
	BOSS = {
		meadowWarden = {
			strike = "leaves", -- a branch swipe: a leafy slash and dust
			release = "roots", -- the root slam: roots burst out across the ring with a green shockwave
			color = rgb(110, 214, 92),
			sounds = {
				strike = "rbxassetid://9120717850", -- Whoosh Fast Swish By 4 (foliage crackle)
				release = "rbxassetid://9125366799", -- Avalanche Crashing 5
			},
		},
		caveBroodQueen = {
			strike = "fangs", -- a fang stab: two slashes and a poison splash
			release = "web", -- the web spit: strands spray across the cone and stick
			color = rgb(182, 132, 255),
			sounds = {
				strike = "rbxassetid://9125466994", -- Creature Bite Pterodactyl Crunch Flying Bug 7
				release = "rbxassetid://9120628908", -- Web Shoot Juicy Releases Spurts 2
			},
		},
		emberColossus = {
			strike = "embers", -- a horn gore: a fiery burst and rock dust
			release = "lava", -- the lava slam: a fire shockwave, glowing cracks and molten rocks thrown up
			color = rgb(255, 112, 32),
			sounds = {
				strike = "rbxassetid://9117330384", -- Pick Impacts 1 (heavy dirt and rock hits)
				release = "rbxassetid://9113216700", -- Avalanche Crashing 3
			},
		},
	},
	-- Wild monsters' normal attacks (keyed clips in ReplicatedStorage.MonsterAnimations/<species>, the same flow as a
	-- boss's): `strike` the effect where it lands
	MONSTER = {
		Mossling = {
			strike = "headbutt", -- a green burst, dust and a little ground ring
			color = rgb(120, 200, 96),
			sounds = { strike = "rbxassetid://9118588165" }, -- Rock Drop On Concrete Drops Breaks 10
		},
		["Puddle Crab"] = {
			strike = "snap", -- a splash and two pincer slashes
			color = rgb(80, 196, 255),
			sounds = { strike = "rbxassetid://9125703162" }, -- Mud Puddle Splash 19
		},
		["Cave Bat"] = {
			strike = "dive", -- three claw slashes and a dark burst
			color = rgb(170, 120, 255),
			sounds = { strike = "rbxassetid://9114375469" }, -- Fast Pass By Airy Whooshes Windy 4
		},
		["Spark Beetle"] = {
			strike = "spark", -- a lightning bolt from its pincers and a burst
			color = rgb(250, 214, 60),
			sounds = { strike = "rbxassetid://9114277757" }, -- Electric Zaps 12
		},
		["Ash Wolf"] = {
			strike = "bite", -- fang slashes top and bottom, ember sparks
			color = rgb(255, 130, 50),
			sounds = { strike = "rbxassetid://9125466994" }, -- Creature Bite Pterodactyl Crunch Flying Bug 7
		},
		["Magma Golem"] = {
			strike = "embers", -- a ground punch: a fiery burst, rock dust, a ground ring
			color = rgb(255, 112, 32),
			sounds = { strike = "rbxassetid://9119037874" }, -- Shale Break 15
		},
	},
}
