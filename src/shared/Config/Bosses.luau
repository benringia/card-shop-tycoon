--!strict
-- The boss ladder (spec 2026-10-28-boss-ladder-design.md; DESIGN.md 5.8 battles part 3b). Each boss is fought at an
-- arena at the end of its Wild zone, unlocks with fragments the boss before drops, and drops what helps beat the next.
-- Plain data so Lune tests and the economy simulator can load it. Phase 1: the three Wild bosses, solo.
export type Drop = { item: string, chance: number, min: number, max: number }
export type Grant = { item: string, count: number }
export type Boss = {
	name: string,
	title: string, -- under its name on the intro card
	zone: number, -- Config/Wild ZONES index: its arena is at the end of this zone
	shape: string, -- a Wild placeholder shape until its model exists
	scale: number, -- placeholder size, times the monster height
	element: string,
	level: number,
	hp: number,
	atk: number,
	spd: number,
	recommended: number, -- the party Power it's balanced for (shown on the board; drops shrink far above it)
	minFightSeconds: number, -- a win faster than this is flagged and gives no loot
	unlock: { item: string, count: number }?, -- fragments that open it the first time (nil = open from the start)
	fragment: string?, -- the next boss's fragment it drops
	mechanics: { heal: { below: number, fraction: number, cooldown: number }?, enrage: { below: number, atkMultiplier: number }? },
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
		zone = 1,
		shape = "slime",
		scale = 2.5,
		element = "Bloom",
		level = 6,
		hp = 1800,
		atk = 11,
		spd = 8,
		recommended = 200,
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
		zone = 2,
		shape = "bat",
		scale = 2.8,
		element = "Shade",
		level = 11,
		hp = 3900,
		atk = 16,
		spd = 12,
		recommended = 350,
		minFightSeconds = 18,
		unlock = { item = "fragment_caveBroodQueen", count = 3 },
		fragment = "fragment_emberColossus",
		mechanics = { heal = { below = 0.5, fraction = 0.15, cooldown = 12 } },
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
		zone = 3,
		shape = "golem",
		scale = 3.2,
		element = "Ember",
		level = 16,
		hp = 7200,
		atk = 22,
		spd = 9,
		recommended = 650,
		minFightSeconds = 25,
		unlock = { item = "fragment_emberColossus", count = 5 },
		mechanics = { enrage = { below = 0.5, atkMultiplier = 1.5 } },
		drops = {
			{ item = "gradingSeal", chance = 0.35, min = 1, max = 1 },
			{ item = "xpTonic", chance = 0.4, min = 2, max = 3 },
		},
		firstClear = { { item = "trophy_emberColossus", count = 1 }, { item = "gradingSeal", count = 3 } },
		dailyBonus = { { item = "gradingSeal", count = 2 } },
		cash = 96,
		xp = 2220,
	},
}

return {
	LADDER = { "meadowWarden", "caveBroodQueen", "emberColossus" },
	BOSSES = BOSSES,

	-- Farm protection (spec section 7)
	LOOT_COOLDOWN = 900, -- seconds between full loot from the same boss, per player (saved Unix time)
	SOFT_CAP_AFTER = 6, -- rewarded kills of a boss a day at full drop chances
	SOFT_CAP_STEP = 0.75, -- each further rewarded kill's drop chances, times the one before
	SOFT_CAP_FLOOR = 0.2,
	OVERPOWER_RATIO = 2.5, -- party Power above this times the recommended shrinks drops...
	OVERPOWER_FACTOR = 0.35, -- ...to this

	GATE_PROMPT_DISTANCE = 10, -- the gate prompt shows this close
	GATE_DISTANCE = 12, -- studs from the gate the server accepts a start (past the prompt's reach, for lag)
	START_COOLDOWN = 2, -- seconds between start requests per player

	-- Groups (spec section 5): 2-4 players, one boss scaled to the group, loot per player for those who helped
	GROUP_MAX = 4,
	JOIN_SECONDS = 15, -- others join this long after the leader opens a group at the gate
	GROUP_HP_STEP = 0.8, -- boss HP x (1 + this x (players - 1))
	GROUP_ATK_STEP = 0.15, -- boss ATK x (1 + this x (players - 1))
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
	MUSIC_ID = "128007000574959", -- boss music: "Epic Boss Battle" (DistroKid, free in the Creator Store); "" plays none
	MUSIC_VOLUME = 0.5,
	MUSIC_FADE = 1, -- seconds
	ARENA_GAP = 16, -- path length from the zone's edge to the ring
	BOSS_SPOT = 6, -- studs past the ring's centre (away from the gate) where the boss stands
	RING_RADIUS = 11, -- fighters stand this far from a boss (it's big)
	LEASH_RADIUS = 42, -- ARENA_RADIUS + BOSS_SPOT: a backstop behind the barrier (the leash is measured from the boss)
	-- While a fight runs the ring is sealed: a see-through wall all round, just outside the fence
	BARRIER_SEGMENT = 6, -- studs per wall piece
	BARRIER_HEIGHT = 14,
	BARRIER_TRANSPARENCY = 0.55,
	INSIDE_STEP = 4, -- members are moved this far past the gate (and this far apart) when the fight starts
}
