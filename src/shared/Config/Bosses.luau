--!strict
-- The boss ladder (spec 2026-10-28-boss-ladder-design.md; DESIGN.md 5.8 battles part 3b). Each boss is fought at an
-- arena at the end of its zone (the Wild in the main game, the Frontier place for 4-6), unlocks with fragments the boss
-- before drops, and drops what helps beat the next. Plain data so Lune tests and the economy simulator can load it.
export type Drop = { item: string, chance: number, min: number, max: number }
export type Grant = { item: string, count: number }
-- heal below an HP fraction (every cooldown, at most `uses` times a fight); enrage once; shield: every `every` s a shield of `fraction` of max HP that takes damage
-- first (breaking it stuns the boss `breakStun` s); thunderclap: every `every` s stuns each enemy `seconds` x
-- clamp(boss SPD / its SPD, minFactor, maxFactor); adds: at each HP fraction in `at`, `count` adds (`hpShare` of max
-- HP, `atkShare` of ATK, of `species`) that are hit first, the boss taking x`guard` damage while any stands
export type Mechanics = {
	heal: { below: number, fraction: number, cooldown: number, uses: number? }?,
	enrage: { below: number, atkMultiplier: number }?,
	shield: { every: number, fraction: number, breakStun: number }?,
	thunderclap: { every: number, seconds: number, minFactor: number, maxFactor: number }?,
	adds: { at: { number }, count: number, hpShare: number, atkShare: number, guard: number, species: string }?,
}
-- One phase of a boss that has them: active while its HP share is under `below` (the first has below = 1); it
-- switches the boss's element and mechanics. Phases only go forward (a heal never takes one back).
export type BossPhase = { below: number, element: string, mechanics: Mechanics }
export type Boss = {
	name: string,
	title: string, -- under its name on the intro card
	place: "Wild" | "Frontier" | "Dungeon", -- which place its arena is in (only that place builds it)
	zone: number, -- ZONES index in that place's world (Config/Wild or Config/Frontier): its arena is at the end of it
	shape: string, -- a Wild placeholder shape until its model exists
	scale: number, -- placeholder size, times the monster height
	element: string,
	level: number,
	hp: number,
	atk: number,
	spd: number,
	recommended: number, -- the party Power it's balanced for (shown on the board; drops shrink far above it)
	shopLevel: number, -- the shop level a player needs to fight it (every member of a group), on top of its fragments
	groupAtkStep: number?, -- its own ATK step per extra player in a group (nil: GROUP_ATK_STEP)
	minFightSeconds: number, -- a win faster than this is flagged and gives no loot
	unlock: { item: string, count: number }?, -- fragments that open it the first time (nil = open from the start)
	fragment: string?, -- the next boss's fragment it drops
	mechanics: Mechanics, -- always on (a boss with phases keeps {} here: its phases bring theirs)
	phases: { BossPhase }?, -- the final boss: one per element, by HP
	announceEverywhere: boolean?, -- its first clear is told to every server of the experience, not just this one
	clearTitle: string?, -- shown over the name, in every place, of everyone who has cleared it
	heads: { string }?, -- its model's heads' elements, head 0 first (bones Hydra_<n>_3): the active phase's head glows
	ringRadius: number?, -- how far its fighters stand from it (nil: RING_RADIUS); a huge model needs more room
	introShot: { back: number, up: number }?, -- its intro camera (nil: INTRO_SHOT); further off for a huge model
	rainbowAura: boolean?, -- the model glows in slowly changing rainbow colours (RAINBOW_AURA)
	auroraFlame: boolean?, -- soft aurora-coloured flames rise off its back (AURORA_FLAME)
	drops: { Drop }, -- full loot, rolled per drop (x the farm-protection factor)
	firstClear: { Grant }, -- once, on the first win
	dailyBonus: { Grant }, -- the first rewarded win each UTC day
	cash: number,
	xp: number, -- split across the party like a Wild win
}

local BOSSES: { [string]: Boss } = {
	meadowWarden = {
		name = "Meadow Warden",
		title = "Guardian of the Meadow",
		place = "Wild",
		zone = 1,
		shape = "slime",
		scale = 2.5,
		element = "Bloom",
		level = 6,
		hp = 1800,
		atk = 11,
		spd = 8,
		recommended = 200,
		shopLevel = 3,
		minFightSeconds = 12,
		fragment = "fragment_caveBroodQueen",
		mechanics = {},
		drops = {
			{ item = "xpTonic", chance = 0.6, min = 1, max = 2 },
			{ item = "fragment_caveBroodQueen", chance = 0.7, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_caveBroodQueen", count = 3 }, { item = "trophy_meadowWarden", count = 1 }, { item = "xpTonic", count = 3 } },
		dailyBonus = { { item = "xpTonic", count = 2 } },
		cash = 36,
		xp = 620,
	},
	caveBroodQueen = {
		name = "Cave Brood Queen",
		title = "Mother of the Deep",
		place = "Wild",
		zone = 2,
		shape = "bat",
		scale = 2.8,
		element = "Shade",
		level = 11,
		hp = 3900,
		atk = 16,
		spd = 12,
		recommended = 350,
		shopLevel = 5,
		minFightSeconds = 18,
		unlock = { item = "fragment_caveBroodQueen", count = 3 },
		fragment = "fragment_emberColossus",
		mechanics = { heal = { below = 0.5, fraction = 0.15, cooldown = 12, uses = 3 } },
		drops = {
			{ item = "xpTonic", chance = 0.6, min = 1, max = 3 },
			{ item = "starShard", chance = 0.15, min = 1, max = 1 },
			{ item = "fragment_emberColossus", chance = 0.6, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_emberColossus", count = 3 }, { item = "trophy_caveBroodQueen", count = 1 }, { item = "xpTonic", count = 3 } },
		dailyBonus = { { item = "xpTonic", count = 2 } },
		cash = 66,
		xp = 1360,
	},
	emberColossus = {
		name = "Ember Colossus",
		title = "The Walking Furnace",
		place = "Wild",
		zone = 3,
		shape = "golem",
		scale = 3.2,
		element = "Ember",
		level = 16,
		hp = 7200,
		atk = 22,
		spd = 9,
		recommended = 650,
		shopLevel = 8,
		minFightSeconds = 25,
		unlock = { item = "fragment_emberColossus", count = 5 },
		fragment = "fragment_frostTyrant",
		mechanics = { enrage = { below = 0.5, atkMultiplier = 1.5 } },
		drops = {
			{ item = "gradingSeal", chance = 0.35, min = 1, max = 1 },
			{ item = "xpTonic", chance = 0.4, min = 2, max = 3 },
			{ item = "fragment_frostTyrant", chance = 0.6, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_frostTyrant", count = 3 }, { item = "trophy_emberColossus", count = 1 }, { item = "gradingSeal", count = 3 } },
		dailyBonus = { { item = "gradingSeal", count = 2 } },
		cash = 96,
		xp = 2220,
	},
	-- The Frontier bosses (phase 3): arenas in the Frontier place
	frostTyrant = {
		name = "Frost Tyrant",
		title = "Lord of the Long Winter",
		place = "Frontier",
		zone = 1,
		shape = "slime",
		scale = 3.0,
		element = "Tide",
		level = 22,
		hp = 11500,
		atk = 27,
		spd = 9,
		recommended = 1100,
		shopLevel = 12,
		groupAtkStep = 0.35, -- Legendary parties shrug off the default group ATK step
		minFightSeconds = 60,
		unlock = { item = "fragment_frostTyrant", count = 5 },
		fragment = "fragment_stormSovereign",
		mechanics = { shield = { every = 20, fraction = 0.06, breakStun = 3 } },
		drops = {
			{ item = "gradingSeal", chance = 0.4, min = 1, max = 1 },
			{ item = "starShard", chance = 0.25, min = 1, max = 2 },
			{ item = "fragment_stormSovereign", chance = 0.6, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_stormSovereign", count = 3 }, { item = "trophy_frostTyrant", count = 1 }, { item = "gradingSeal", count = 3 } },
		dailyBonus = { { item = "gradingSeal", count = 2 } },
		cash = 150,
		xp = 3600,
	},
	stormSovereign = {
		name = "Storm Sovereign",
		title = "Voice of the Thunder",
		place = "Frontier",
		zone = 2,
		shape = "bat",
		scale = 3.2,
		element = "Volt",
		level = 32,
		hp = 14500,
		atk = 26,
		spd = 14,
		recommended = 1500,
		shopLevel = 15,
		groupAtkStep = 0.35, -- Legendary parties shrug off the default group ATK step
		minFightSeconds = 70,
		unlock = { item = "fragment_stormSovereign", count = 8 },
		fragment = "fragment_riftDevourer",
		mechanics = { thunderclap = { every = 14, seconds = 2.5, minFactor = 0.3, maxFactor = 1.5 } },
		drops = {
			{ item = "goldSeal", chance = 0.25, min = 1, max = 1 },
			{ item = "fragment_riftDevourer", chance = 0.55, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_riftDevourer", count = 3 }, { item = "trophy_stormSovereign", count = 1 }, { item = "goldSeal", count = 1 } },
		dailyBonus = { { item = "goldSeal", count = 1 } },
		cash = 210,
		xp = 5200,
	},
	riftDevourer = {
		name = "Rift Devourer",
		title = "The Hunger Between Worlds",
		place = "Frontier",
		zone = 3,
		shape = "beetle",
		scale = 3.4,
		element = "Shade",
		level = 45,
		hp = 23000,
		atk = 26,
		spd = 10,
		recommended = 1900,
		shopLevel = 18,
		groupAtkStep = 0.5, -- Legendary parties shrug off the default group ATK step
		minFightSeconds = 80,
		unlock = { item = "fragment_riftDevourer", count = 8 },
		fragment = "fragment_prismHydra",
		mechanics = { adds = { at = { 0.5 }, count = 2, hpShare = 0.05, atkShare = 0.35, guard = 0.5, species = "Rift Horror" } },
		drops = {
			{ item = "goldSeal", chance = 0.3, min = 1, max = 1 },
			{ item = "starShard", chance = 0.3, min = 1, max = 2 },
			{ item = "fragment_prismHydra", chance = 0.5, min = 1, max = 1 },
		},
		firstClear = { { item = "fragment_prismHydra", count = 3 }, { item = "trophy_riftDevourer", count = 1 }, { item = "goldSeal", count = 3 } },
		dailyBonus = { { item = "goldSeal", count = 1 } },
		cash = 280,
		xp = 7400,
	},
	-- The final boss (phase 4): the Dungeon place, one phase per element and per mechanic of the ladder
	prismHydra = {
		name = "Prism Hydra",
		title = "Crown of Every Element",
		place = "Dungeon",
		zone = 1,
		shape = "golem",
		scale = 7.0,
		ringRadius = 21,
		introShot = { back = 44, up = 22 },
		rainbowAura = true,
		auroraFlame = true,
		element = "Tide", -- phase 1's
		level = 55,
		hp = 40000,
		atk = 23,
		spd = 11,
		recommended = 2400,
		shopLevel = 22,
		groupAtkStep = 0.25,
		minFightSeconds = 120,
		unlock = { item = "fragment_prismHydra", count = 10 },
		announceEverywhere = true,
		clearTitle = "Dungeon Conqueror",
		heads = { "Ember", "Tide", "Volt", "Shade", "Bloom" }, -- the middle head (0) is the finale's
		mechanics = {},
		phases = {
			{ below = 1, element = "Tide", mechanics = { shield = { every = 20, fraction = 0.06, breakStun = 3 } } },
			{ below = 0.8, element = "Volt", mechanics = { thunderclap = { every = 14, seconds = 2.5, minFactor = 0.3, maxFactor = 1.5 } } },
			{ below = 0.6, element = "Shade", mechanics = { adds = { at = { 0.6 }, count = 2, hpShare = 0.04, atkShare = 0.35, guard = 0.5, species = "Rift Horror" } } },
			{ below = 0.4, element = "Bloom", mechanics = { heal = { below = 0.4, fraction = 0.05, cooldown = 20, uses = 2 } } },
			{ below = 0.2, element = "Ember", mechanics = { enrage = { below = 0.2, atkMultiplier = 1.15 } } },
		},
		drops = {
			{ item = "goldSeal", chance = 0.4, min = 1, max = 1 },
			{ item = "starShard", chance = 0.4, min = 1, max = 2 },
			{ item = "gradingSeal", chance = 0.4, min = 1, max = 2 },
			{ item = "xpTonic", chance = 0.5, min = 2, max = 3 },
		},
		firstClear = {
			{ item = "trophy_prismHydra", count = 1 },
			{ item = "goldSeal", count = 5 },
			{ item = "starShard", count = 5 },
			{ item = "gradingSeal", count = 5 },
			{ item = "xpTonic", count = 5 },
		},
		dailyBonus = { { item = "goldSeal", count = 2 } },
		cash = 400,
		xp = 10000,
	},
}

return {
	LADDER = { "meadowWarden", "caveBroodQueen", "emberColossus", "frostTyrant", "stormSovereign", "riftDevourer", "prismHydra" },
	BOSSES = BOSSES,

	-- Farm protection (spec section 7)
	-- Loot on the ground: each player's drops scatter round the boss (only they see them); walking over one picks it up.
	-- Nothing is collected by itself: loot left on the ground when you leave the server is gone.
	LOOT_SCATTER = { min = 4, max = 10 }, -- studs from the boss
	LOOT_PICKUP_DISTANCE = 8, -- the server's limit for a pickup
	LOOT_CLIENT_REACH = 5, -- the client asks this close
	LOOT_PICKUP_COOLDOWN = 0.1, -- seconds between pickup requests (each may pick up several drops)
	LOOT_PICKUP_BATCH = 12, -- drops one pickup request may name
	LOOT_COOLDOWN = 900, -- seconds between full loot from the same boss, per player (saved Unix time)
	SOFT_CAP_AFTER = 6, -- rewarded kills of a boss a day at full drop chances
	SOFT_CAP_STEP = 0.75, -- each further rewarded kill's drop chances, times the one before
	SOFT_CAP_FLOOR = 0.2,
	OVERPOWER_RATIO = 2.5, -- party Power above this times the recommended shrinks drops...
	OVERPOWER_FACTOR = 0.35, -- ...to this

	GATE_PROMPT_DISTANCE = 10, -- the gate prompt shows this close
	GATE_DISTANCE = 12, -- studs from the gate the server accepts a start (past the prompt's reach, for lag)
	START_COOLDOWN = 2, -- seconds between start requests per player
	CLEARED_TOPIC = "BossCleared", -- MessagingService topic for announceEverywhere first clears

	-- Groups (spec section 5): 2-4 players, one boss scaled to the group, loot per player for those who helped
	GROUP_MAX = 4,
	JOIN_SECONDS = 15, -- others join this long after the leader opens a group at the gate
	GROUP_HP_STEP = 0.8, -- boss HP x (1 + this x (players - 1))
	GROUP_ATK_STEP = 0.15, -- boss ATK x (1 + this x (players - 1))
	GROUP_SWINGS_STEP = 1, -- extra creatures the boss hits per attack, per extra player (so a group isn't a free win)
	CONTRIBUTION_DAMAGE = 0.10, -- full loot needs this share of the group's damage...
	CONTRIBUTION_TANK = 0.15, -- ...or this share of the hits the group took
	CARRIED_FACTOR = 0.25, -- below both: item chances x this, never fragments, no chests
	GROUP_SPACING = 7, -- studs between group members' leaders on the ring (each extra stands Combat.EXTRA_SIDE right of its own)
	GROUP_PROMPT_OFFSET = 80, -- pixels the gate's group prompt sits below its Fight prompt

	-- Arenas: a fenced ring beside each boss's zone (on its +X side), joined to it by a path
	ARENA_RADIUS = 36,
	-- The intro: the camera flies to the boss (name card, roar), then 3, 2, 1, FIGHT. The boss can't be hit before.
	INTRO_SECONDS = 6,
	INTRO_CAMERA_SECONDS = 3,
	INTRO_SHOT = { back = 24, up = 12 }, -- studs in front of the boss and above (over the creatures), looking at it
	ROAR_SHAKE = { at = 1, seconds = 0.8, studs = 0.8 },
	PHASE_SHAKE = { seconds = 0.3, studs = 0.4 }, -- heal, enrage and the other boss moments
	MUSIC_ID = "1843821342", -- boss ambience: "Tension Repeat Drones 22" (APM, free in the Creator Store); "" plays none
	MUSIC_VOLUME = 0.1, -- a low drone under the attack and skill sounds, just enough that the fight isn't silent
	MUSIC_FADE = 1, -- seconds
	ARENA_GAP = 16, -- path length from the zone's edge to the ring
	BOSS_SPOT = 6, -- studs past the ring's centre (away from the gate) where the boss stands
	RING_RADIUS = 11, -- fighters stand this far from a boss (it's big)
	LEASH_RADIUS = 42, -- ARENA_RADIUS + BOSS_SPOT: a backstop behind the barrier (the leash is measured from the boss)
	-- While a fight runs the ring is sealed: a see-through wall all round, just outside the fence
	BARRIER_SEGMENT = 6, -- studs per wall piece
	BARRIER_HEIGHT = 14,
	BARRIER_TRANSPARENCY = 0.55,
	ADD_FADE_SECONDS = 1, -- a fallen add lies there this long before it goes
	DEATH_SECONDS = 4, -- a beaten boss lies there this long before it goes (its death scene)
	HEAD_GLOW = { brightness = 3, range = 16, particles = 14 }, -- the active phase's head (bosses with heads)
	HEAD_DROP = { gap = 0.5, seconds = 0.6, angle = 75 }, -- its death: one head after another, each over `seconds`, by `angle` degrees
	-- A boss's rainbow aura (rainbowAura): the model itself glows, a coloured outline round it and a faint colour wash
	-- over it (fillTransparency: the model always shows through) and a light, all slowly cycling through the colours
	-- (hueSeconds a cycle); it fades when the boss falls
	RAINBOW_AURA = { hueSeconds = 6, outlineTransparency = 0, fillTransparency = 0.82, lightBrightness = 1.2, lightRange = 40 },
	-- A boss's aurora flame (auroraFlame): soft flames in aurora colours (green, cyan, violet) rising off its back, above
	-- these bones at `height` x its model's height, few and see-through so they sit over the glow without hiding it
	-- (studs at the boss's size; per bone)
	AURORA_FLAME = { bones = { "Spine_0", "Spine_1", "Pelvis" }, height = 0.5, rate = 12, sizeStart = 8, sizeEnd = 2.5, lifetimeMin = 1, lifetimeMax = 1.6, rise = 10, transparency = 0.3 },
	ADD_SPACING = 6, -- studs between a boss and its adds (left and right of it)
	INSIDE_STEP = 4, -- members are moved this far past the gate (and this far apart) when the fight starts
}
