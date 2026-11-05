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
	EXTRA_SHOT_GAP = 0.08, -- seconds between a grade A / S Ember's extra fireballs (they land together)
	-- Each element's normal attack: a thrown projectile, a 3-hit combo up close, or a lightning bolt shot from where it
	-- stands (the owner's mockup; projectile and bolt attackers stand back, Combat.RANGED_BACK)
	ELEMENT = {
		Ember = { kind = "projectile", color = rgb(255, 122, 58) },
		Tide = { kind = "projectile", color = rgb(74, 168, 255) },
		Bloom = { kind = "combo", color = rgb(74, 222, 128) },
		Volt = { kind = "bolt", color = rgb(250, 204, 21) },
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
		-- The boom layer on big hits (grade S extras): per element, else `boom`
		boom = "rbxassetid://9125484367", -- Deep Hits Big Reverberant Booms Rumbling Tail 2
		big = {
			Ember = "rbxassetid://9114438917", -- Fire Sheet 3 (erupt and burn)
			Tide = "rbxassetid://9120607089", -- Water Surge 3 (waves crash)
		},
	},
	VOLUME = 0.45,
	-- Each play picks its pitch (PlaybackSpeed) and loudness share from these ranges (owner 2026-11-04: no sound the same
	-- over and over)
	VARY = { pitch = { 0.85, 1.15 }, volume = { 0.82, 1 } },
	CHARGE_LIGHT = 3, -- a charging creature's glow (PointLight brightness at full charge)
	PROJECTILE_SIZE = 1.2, -- studs
	ARC = { Ember = 6, Tide = 0 }, -- studs a projectile rises at its midpoint
	BURST = 26, -- particles in an impact
	DASH = { combo = 0.7 }, -- share of the way to its target a creature dashes for a combo
	-- A Volt bolt: how long it flickers (seconds; the mockup's six flickers), and at grade S the strike from the sky
	-- this long after it
	BOLT = { seconds = 0.27, skyDelay = 0.14 },
	-- Pet button moves and super moves (Config/Combat ABILITIES and SIGNATURES kinds): each lands with its event, its
	-- effect at once (style, colour, how long a lasting one stays, seconds)
	SPECIALS = {
		Fireball = { style = "bigball", color = rgb(255, 122, 58) },
		-- The finished Pet button moves: their looks are Util/MoveFx's (style "move"; spec 2026-11-05-pet-moves-design)
		Rain = { style = "move", color = rgb(74, 168, 255), seconds = 5 },
		Snare = { style = "move", color = rgb(74, 222, 128), seconds = 4 },
		Overcharge = { style = "move", color = rgb(250, 204, 21), seconds = 3 },
		Curse = { style = "move", color = rgb(167, 139, 250), seconds = 5 },
		-- The super moves: their looks are Util/SuperFx's (Config/SuperFx, spec 2026-11-05-super-moves-design)
		Inferno = { style = "super", color = rgb(255, 90, 26) },
		TidalShield = { style = "super", color = rgb(96, 196, 255) },
		Stampede = { style = "super", color = rgb(250, 204, 21) },
		Eclipse = { style = "super", color = rgb(167, 139, 250) },
		Supernova = { style = "super", color = rgb(255, 209, 102) },
		Devour = { style = "super", color = rgb(139, 92, 246) },
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
			-- owner 2026-11-04: a huge fireball heaved off its back lands with the slam (scale: ElementFx.projectile's;
			-- arc: studs it rises at the midpoint)
			meteor = { scale = 7, arc = 28 },
			color = rgb(255, 112, 32),
			sounds = {
				strike = "rbxassetid://9117330384", -- Pick Impacts 1 (heavy dirt and rock hits)
				release = "rbxassetid://9113216700", -- Avalanche Crashing 3
			},
		},
	},
	-- The effects' textures (tools/textures/make_attack_fx.py, the owner's reference look): white, tinted per use, a
	-- coloured layer under a white core
	TEXTURES = {
		glow = "rbxassetid://111832033900052",
		flare = "rbxassetid://83939810863438",
		streak = "rbxassetid://72806596201777",
		spark = "rbxassetid://110131144237409",
		ring = "rbxassetid://130539210208283",
		bolt = "rbxassetid://118502374622454", -- upright: a beam runs a texture's height along its length
		slash = "rbxassetid://108229178074942",
		shard = "rbxassetid://128916396596028",
		impact = "rbxassetid://134340523336604",
		flame = "rbxassetid://103269035765808",
		smoke = "rbxassetid://73731160930304",
	},
	-- A creature's basic attack by its grade: size, spark count and shake multipliers, and extras on top (A: one,
	-- S: the big ones; Util/FightFx)
	GRADE = {
		C = { scale = 1, sparks = 1, extra = 0, shake = 1 },
		B = { scale = 1.25, sparks = 1.4, extra = 0, shake = 1.2 },
		A = { scale = 1.55, sparks = 1.8, extra = 1, shake = 1.45 },
		S = { scale = 2, sparks = 2.4, extra = 2, shake = 1.9 },
	},
	-- Camera shake (Util/ScreenFx, Util/ShakeRules): each hit adds to a 0-1 shake that dies down at DECAY a second; the
	-- camera moves up to MAX_STUDS times the shake squared. Amounts per hit; hits away from you shake less, from NEAR
	-- to FAR studs off
	SHAKE = {
		MAX_STUDS = 1.4,
		DECAY = 1.8,
		NEAR = 14,
		FAR = 70,
		creatureHit = 0.12, -- times the grade's shake
		creatureFinisher = 0.2, -- a combo's last hit, an S extra
		special = 0.3, -- a Pet button move or super move
		bossStrike = 0.3,
		bossSlam = 0.75,
		hurt = 0.45, -- a boss's hit on you
	},
	-- Screen flashes (Util/ScreenFx): colour (nil: the attack's), how strong (1 - transparency) and how long
	FLASH = {
		gradeS = { strength = 0.22, seconds = 0.16 },
		special = { strength = 0.18, seconds = 0.2 },
		bossSlam = { color = rgb(255, 255, 255), strength = 0.4, seconds = 0.22 },
	},
	-- Damage numbers (Util/DamagePop): each style bursts from `start` to `peak` size over `pop` seconds, settles back to
	-- 1 over `settle`, rises `rise` studs over its `life` and fades over the last `fade` of it; a crit wiggles `wiggle`
	-- degrees as it settles
	NUMBERS = {
		settle = 0.14,
		fade = 0.35,
		normal = { start = 0.4, peak = 1.5, pop = 0.09, life = 0.9, rise = 3 },
		crit = { start = 0.4, peak = 2.1, pop = 0.1, life = 1.25, rise = 3.6, wiggle = 14 },
		strong = { start = 0.4, peak = 1.75, pop = 0.09, life = 1, rise = 3.3 },
		weak = { start = 0.5, peak = 1.2, pop = 0.08, life = 0.75, rise = 2.4 },
		heal = { start = 0.4, peak = 1.4, pop = 0.1, life = 1, rise = 3.2 },
		tick = { start = 0.6, peak = 1.15, pop = 0.06, life = 0.7, rise = 2 },
		DRIFT = 1.2, -- studs a number drifts sideways (random each way), so numbers landing together don't overlap
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
