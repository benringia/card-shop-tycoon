--!strict
-- Combat numbers (battles part 1 spec). Plain data only so Lune tests can load this file.
return {
	TICK_RATE = 10, -- fight steps per second on the server
	CALL_IN_SECONDS = 5, -- second party card may join only this early
	MAX_FIGHT_SECONDS = 120, -- a fight still going after this ends as a run (stuck or idle)
	BOSS_MAX_STUN = 1, -- seconds: stuns on a boss last at most this long

	-- Attacks: interval = clamp(ATTACK_BASE * SPD_REFERENCE / SPD, ATTACK_MIN, ATTACK_MAX)
	ATTACK_BASE = 2,
	SPD_REFERENCE = 10,
	ATTACK_MIN = 0.8,
	ATTACK_MAX = 2.5,
	DAMAGE_SPREAD = 0.1, -- +-10%

	-- Element wheel: each element is strong against the ones listed
	STRONG = 1.5,
	WEAK = 0.75,
	BEATS = {
		Ember = { "Bloom" },
		Bloom = { "Tide" },
		Tide = { "Ember" },
		Volt = { "Shade" },
		Shade = { "Volt" },
	},

	-- Element abilities: one per fighter, by its element
	ABILITY_COOLDOWN = 8,
	ABILITIES = {
		Ember = { kind = "Fireball", name = "Fireball", power = 2.5 },
		Tide = { kind = "Wave", name = "Wave", heal = 0.25 },
		Bloom = { kind = "Snare", name = "Vine Snare", slow = 0.4, seconds = 4 },
		Volt = { kind = "Overcharge", name = "Overcharge", attacks = 3, speed = 2 },
		Shade = { kind = "Curse", name = "Curse", weaken = 0.3, seconds = 5 },
	},
	-- Signature abilities on Epic and Legendary cards, by card name
	SIGNATURE_COOLDOWN = 15,
	SIGNATURES = {
		Infernox = { kind = "Inferno", name = "Inferno", seconds = 6, perSecond = 0.4 },
		["Abyssal Koi"] = { kind = "TidalShield", name = "Tidal Shield", shield = 0.3 },
		Thunderhorn = { kind = "Stampede", name = "Stampede", power = 2, stun = 2 },
		["Eclipse Fox"] = { kind = "Eclipse", name = "Eclipse", seconds = 3 },
		Solarion = { kind = "Supernova", name = "Supernova", power = 4 },
		Voidmaw = { kind = "Devour", name = "Devour", power = 2, lifesteal = 0.5 },
		-- Frontier cards: same ability kinds, their own names
		Riftwalker = { kind = "Eclipse", name = "Rift Step", seconds = 3 },
		["Cinder Titan"] = { kind = "Stampede", name = "Magma Slam", power = 2, stun = 2 },
		["Tideborne Kirin"] = { kind = "TidalShield", name = "Tidal Blessing", shield = 0.35 },
		Stormking = { kind = "Supernova", name = "Thunderstorm", power = 4 },
	},

	-- Run: clamp(RUN_BASE + RUN_PER_SPD * (leaderSPD - monsterSPD), RUN_MIN, RUN_MAX) - elite penalty (>= RUN_MIN)
	RUN_BASE = 0.5,
	RUN_PER_SPD = 0.03,
	RUN_MIN = 0.2,
	RUN_MAX = 0.9,
	RUN_ELITE_PENALTY = 0.15,
	RUN_RETRY_SECONDS = 3,

	-- Fainted cards rest; the plaza spring speeds it up
	REST_SECONDS = 180,
	SPRING_RADIUS = 12,
	SPRING_SPEED = 3,

	-- World
	FIGHT_RANGE = 12, -- studs from player to monster to start
	RING_RADIUS = 6, -- fighters stand this far from the ring centre
	LEASH_RADIUS = 25, -- players may roam this far from the ring during a fight
	LUNGE_STUDS = 1.5,
	ACTION_COOLDOWN = 0.25, -- remote rate limit
	END_SCREEN_SECONDS = 4,
}
