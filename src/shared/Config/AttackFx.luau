--!strict
-- Attack animations and effects (spec 2026-11-02-attack-animations-design): how creatures move in a fight, how long
-- an attack's effect flies, combo timing, and each element's normal attack. Plain data (Lune-tested).
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	CHARGE_GRACE = 0.3, -- seconds a charge waits past its due time for its attack, then fades
	-- A special's spotlight (Util/Spotlight; the owner 2026-11-10: "special skills animation/fx should always be
	-- visible"): creatures' basic attacks draw nothing new while your sword skill plays (its length) and `tail` seconds
	-- after, through a super's charge and `super` seconds of its move, and a Pet button move's wind-up and `move` seconds
	-- of it (2026-11-11: "apply this and the previous adjustments to all skills")
	SPOTLIGHT = { tail = 0.8, super = 2.5, move = 1.5 },
	FLIGHT = { Ember = 0.35, Tide = 0.25, Shade = 0.3 }, -- seconds a projectile or moon slash flies
	COMBO = { count = 3, window = 0.45 }, -- a combo's hits over this many seconds, the last with the damage
	EXTRA_SHOT_GAP = 0.08, -- seconds between a grade A / S Ember's extra fireballs (they land together)
	-- Each element's normal attack: a thrown projectile, a 3-hit combo up close, a lightning bolt shot from where it
	-- stands (the owner's mockup) or a moon slash flung from a paw (owner 2026-11-05: Shade "a ranged moon slash dark
	-- purple"); everything but the combo stands back (Combat.RANGED_BACK)
	ELEMENT = {
		Ember = { kind = "projectile", color = rgb(255, 122, 58) },
		Tide = { kind = "projectile", color = rgb(74, 168, 255) },
		Bloom = { kind = "combo", color = rgb(74, 222, 128) },
		Volt = { kind = "bolt", color = rgb(250, 204, 21) },
		Shade = { kind = "slash", color = rgb(126, 58, 242) },
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
		Shade = { release = "rbxassetid://9120717850", hit = "rbxassetid://9119749812" }, -- Whoosh Fast Swish By 4, Sword Swishes 4
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
	ARC = { Ember = 6, Tide = 0, Shade = 1 }, -- studs a projectile rises at its midpoint
	-- The moon slash: a crescent `length` studs tip to tip and `width` thick (times the grade's scale), bowed `bow`
	-- studs forward, tilted `tilt` degrees, trailing a shadow `trail` seconds long; grade A adds one crossed the
	-- other way, S a third flat across
	MOON_SLASH = { length = 4.6, width = 1.5, bow = 1.6, tilt = 28, trail = 0.22, shadow = rgb(46, 12, 82) },
	BURST = 26, -- particles in an impact
	-- A combo's earlier hits and the extra moon slashes (grade A, S) land lighter than the hit with the damage: this size
	-- of it and share of its pack particles (Util/FightFx; owner 2026-11-09, the sword hit's pack effects on creatures)
	LIGHT_HIT = { size = 0.8, share = 0.5 },
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
		Rebirth = { style = "super", color = rgb(191, 230, 255) },
		Barrage = { style = "super", color = rgb(192, 107, 255) },
	},
	SPECIAL_SOUND = "rbxassetid://9116394545", -- Magic Glows Chiming Hits 1 (with the element's hit sound)
	-- Creatures circle their fight spot: this far (studs, times the creature's size), this fast (turns a second), with
	-- darts out to `dart` studs more, facing the way they go and turning back to the foe to attack at `turn` (how fast
	-- the turn eases in, per second)
	ORBIT = { radius = 4, speed = 0.15, dart = 1.5, turn = 6 },
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
		-- The owner 2026-11-10 (Util/IceFx, Config ICE below): an icy claw swipe; his ring is a giant ice spike falling
		-- from the sky that shatters in ice smoke (`spikes`), his shield a frosted ice bubble with shards (`iceShield`)
		frostTyrant = {
			strike = "frost",
			release = "frost",
			spikes = true,
			iceShield = true,
			color = rgb(150, 215, 255),
			sounds = {
				strike = "rbxassetid://9120728815", -- Whoosh Heavy Punches 1
				release = "rbxassetid://9120729339", -- Whoosh Heavy Punches 7 (his arms coming down; each spike shatters on its own)
			},
		},
		-- The owner 2026-11-11 (Util/StormFx, Config STORM below): a crackling bite; its ring a lightning strike from the
		-- sky with an electric shockwave; its thunderclap (`storm`) a storm circle, its crown charging and the clap
		stormSovereign = {
			strike = "volt",
			release = "storm",
			storm = true,
			color = rgb(120, 190, 255),
			sounds = {
				strike = "rbxassetid://9114277757", -- Electric Zaps 12
				release = "rbxassetid://9120016037", -- Thunder Cracks Big Rumbling Blasts Booming 1
			},
		},
	},
	-- The Storm Sovereign's thunderclap (the owner 2026-11-11: "add animation and effects to thunderclap"; Util/StormFx,
	-- numbers in Util/StormFxRules). While it rears up: its storm circle on the ground (an outline and a glow spreading
	-- from round it to the edge, `startFill` of the radius at first, lightning crackling round the edge `crackles` a
	-- second, each `span` degrees long), its crown crystal charging (sparks pulling in, arcs from its wing tips
	-- `arcs` a second). The clap: a flash on its crown, a bolt from the sky onto it, `waves` shockwaves out to the edge,
	-- `strikes` bolts from `skyHeight` up landing over the circle within `stagger` seconds, a screen shake and flash.
	-- An Electrocuted player: faint sparks the whole time; each jolt `arcs` arcs flickering round them, a bright flash,
	-- a zap. A pet the clap stuns crackles for its stun. Colours { r, g, b }; sounds Pro Sound Effects (all measured
	-- in Config/SoundLevels with the Volt supers)
	STORM = {
		color = { 120, 190, 255 },
		core = { 225, 240, 255 },
		circle = { startFill = 0.15, crackles = 9, span = 28, outline = 0.25, glow = 0.55, lift = 0.15 },
		crown = { arcs = 7, glow = 0.35, light = 28 },
		clap = { strikes = 9, skyHeight = 55, stagger = 0.3, waves = 2, shake = 1, flash = { strength = 0.45, seconds = 0.25 }, crownBolt = 2.4, strikeScale = 1.6 },
		electrocuted = { arcs = 5, flicker = 0.07, fill = 0.25, sparks = 10 },
		petZap = { arcs = 3, seconds = 0.6 },
		sounds = {
			charge = "rbxassetid://9125980435", -- Spaceship Pre Blast Electric Charge Up Buzzy
			clap = "rbxassetid://9126082854", -- Synth Thunder Cracks Individual Explosion
			thunder = "rbxassetid://9120016256", -- Thunder Cracks Big Rumbling Blasts Booming 3 (the roll under it)
			crackle = "rbxassetid://9116276946", -- Lightning Flashes Quick Electrical Bursts 21
			jolt = "rbxassetid://9114277757", -- Electric Zaps 12
			hum = "rbxassetid://9114245570", -- Electric Hum 7
		},
	},
	-- The Frost Tyrant's ice (Util/IceFx, numbers in Util/IceFxRules): a spike `length` long and `width` wide hanging
	-- `height` over its ring, dropping the last `fall` seconds; the shield bubble `radius` times his height across with
	-- `shards`; a frozen fighter's ice block; the colours and sounds (Pro Sound Effects)
	ICE = {
		-- 45 up and a long fall: a fight camera behind you sees it hang and come down (60 up was off the top of the view)
		spike = { height = 45, length = 22, width = 5.5, fall = 0.75, pieces = 12, smoke = 18, light = 22 },
		-- the bubble's radius and the ice block's sides: shares of the body's box (its largest side; its height and width)
		shield = { radius = 0.62, shards = 24, grow = 0.4, transparency = 0.55 },
		encase = { width = 1.05, tall = 1.08, transparency = 0.45, crystals = 6 },
		color = { 170, 220, 255 },
		core = { 235, 250, 255 },
		smoke = { 225, 240, 255 },
		sounds = {
			fall = "rbxassetid://9113077334", -- Air Whoosh Heavy Bys And Impacts 1
			shatter = "rbxassetid://9114855870", -- Ice Block Drop To Concrete Shatter 1
			shieldForm = "rbxassetid://9114858583", -- Ice Crackle Large Block Cracks 1
			shieldBreak = "rbxassetid://9114856304", -- Ice Block Drop To Concrete Shatter 3
			freeze = "rbxassetid://9114866515", -- Ice Pick Small Crunches Splinters 2
		},
	},
	-- The effects' textures (tools/textures/make_attack_fx.py, the owner's reference look): white, tinted per use, a
	-- coloured layer under a white core
	TEXTURES = {
		glow = "rbxassetid://111832033900052",
		flare = "rbxassetid://83939810863438",
		-- streaks, sparks and the lightning bolt: the Yona pack's pictures (below) since 2026-11-11 (the owner: "still
		-- using the drawn particles which is a bunch of lines"; ours were 72806596201777, 110131144237409, 118502374622454)
		streak = "rbxassetid://6763809313",
		spark = "rbxassetid://6763809313",
		ring = "rbxassetid://130539210208283",
		-- upright: a beam runs a texture's height along its length (Yona Electricity-02 and -03, flickered between)
		bolt = "rbxassetid://13592365549",
		boltAlt = "rbxassetid://13612625856",
		slash = "rbxassetid://108229178074942",
		moon = "rbxassetid://103655929836006", -- the sword's crescent (Config/SwordFx), the Shade moon slash
		shard = "rbxassetid://128916396596028",
		impact = "rbxassetid://134340523336604",
		flame = "rbxassetid://103269035765808",
		smoke = "rbxassetid://73731160930304",
		-- From free Creator Store VFX packs (owner 2026-11-08, picked in game; docs/weapons.md "Pack effects"): public
		-- images other people uploaded, referenced by id. 4x4 flipbooks unless noted.
		-- Euphoric Games VFX Pack (112672322113504): the Ember and Tide weapon auras (white, tinted per use)
		fireAura = "rbxassetid://16676455805",
		waterAura = "rbxassetid://16664715772",
		-- Yona VFX Pack (18170940328): the Bloom weapon aura (an 8x8 smoke flipbook, embers, a soft light)
		auraSmoke = "rbxassetid://13410359900",
		auraEmber = "rbxassetid://1084996976", -- single images from here on
		auraLight = "rbxassetid://1075864321",
		-- a landed cut's slash streaks (Config/SwordFx IMPACT: Euphoric Slash-Impact-01 and Yona Slash-01)
		slashStreak = "rbxassetid://16923007448",
		slashArc = "rbxassetid://13780268621",
		sparkStreak = "rbxassetid://6763809313", -- a single image
		-- Yona's Electricity Impact (Explosion-VFX): crackling bolts growing out, bolts running along the ground, dark
		-- smoke (4x4 flipbooks but the smoke)
		lightningGrow = "rbxassetid://13406902074",
		groundThunder = "rbxassetid://13923972553",
		lightningSmoke = "rbxassetid://9650504257",
		raindrop = "rbxassetid://83707706646646", -- the Tide hit's droplets (Config/SwordFx ELEMENT_HIT; MoveFx's raindrop)
	},
	-- Where lightning lands (ElementFx.bolt's end, a sky strike; the owner 2026-11-11: the packs' particles, not drawn
	-- lines): Yona's Electricity Impact copied from the pack (Explosion-VFX, its emitters' own numbers at about a third
	-- of its size, so scale 1 suits a creature's bolt; its giant white flare and 30-stud crack left out). White, tinted
	-- per use (`whiten`); `delay`: seconds after the hit it bursts (the pack's EmitDelay)
	LIGHTNING = {
		impact = {
			{ texture = "lightningGrow", count = 6, delay = 0.03, lifetime = { 0.28, 0.9 }, speed = { 3, 40 }, spread = { 45, 45 }, size = { { 0, 1.2, 0.6 }, { 1, 1.2, 0.6 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = "tint", whiten = 0.1, brightness = 2.5, zOffset = 2, rotation = { 180, 180 }, drag = 12, direction = "Top", facing = "parallel", squash = { { 0, -1 }, { 1, -1 } }, flipbook = {} },
			{ texture = "groundThunder", count = 7, delay = 0.03, lifetime = { 0.3, 0.8 }, speed = { 40, 110 }, spread = { 25, 180 }, size = { { 0, 1.5, 0.2 }, { 1, 2.1, 0.5 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = "tint", whiten = 0.1, brightness = 2.5, zOffset = 1, rotation = { -90, -90 }, drag = 25, direction = "Left", facing = "parallel", squash = { { 0, 1 }, { 1, 1 } }, flipbook = {} },
			{ texture = "lightningSmoke", count = 5, lifetime = { 0.7, 1.4 }, speed = { 50, 60 }, spread = { 0, 180 }, size = { { 0, 2.6, 0.6 }, { 1, 2.6, 1.2 } }, transparency = { { 0, 1 }, { 0.065, 0.35, 0.1 }, { 1, 1 } }, color = { 70, 70, 80 }, emission = 0.1, brightness = 1, zOffset = -0.05, rotation = { -360, 360 }, drag = 10, direction = "Back", facing = "camera" },
		},
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
		super = 0.65, -- a super move's big moment (times its grade's shake; owner 2026-11-05: "add screenshake on impact")
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
