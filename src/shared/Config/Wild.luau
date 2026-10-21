--!strict
-- The server wild map (battles part 1 spec): zones, monster species, spawns and rewards.
-- Plain data only (positions are { x, y, z } tables) so Lune tests can load this file.
return {
	-- Far from the plots (they sit around the origin); zones run along +Z from here
	ORIGIN = { x = 0, y = 0, z = 1200 },
	PLAZA_PORTAL = { x = 84, y = 0, z = -9 }, -- east end of the street (rows span x -68..68), beside the Frontier portal
	SPRING = { x = 0, y = 0, z = 0 }, -- plaza centre between the shop rows
	PORTAL_SIGN_HEIGHT = 17, -- portal signs float above the portal frame prop (Town.SLOTS.Portal)
	ENTRANCE_OFFSET = { x = 0, y = 0, z = -70 }, -- arrival point relative to ORIGIN
	ZONE_SIZE = 120, -- each zone is a square this wide
	ZONE_GAP = 20, -- path between zones

	ZONES = {
		{ name = "Meadow", minLevel = 1, maxLevel = 5, recommended = 1, species = { "Mossling", "Puddle Crab" }, aggro = false, color = { 110, 180, 90 } },
		{ name = "Caves", minLevel = 5, maxLevel = 10, recommended = 5, species = { "Cave Bat", "Spark Beetle" }, aggro = false, color = { 90, 85, 100 } },
		{ name = "Ember Ridge", minLevel = 10, maxLevel = 15, recommended = 10, species = { "Magma Golem", "Ash Wolf" }, aggro = true, color = { 150, 80, 55 } },
	},

	-- Base stats at level 1; level L multiplies by 1 + MONSTER_GROWTH * (L - 1)
	SPECIES = {
		Mossling = { element = "Bloom", hp = 170, atk = 5, spd = 8, shape = "slime" },
		["Puddle Crab"] = { element = "Tide", hp = 200, atk = 4, spd = 7, shape = "crab" },
		["Cave Bat"] = { element = "Shade", hp = 150, atk = 6, spd = 12, shape = "bat" },
		["Spark Beetle"] = { element = "Volt", hp = 180, atk = 6, spd = 10, shape = "beetle" },
		["Magma Golem"] = { element = "Ember", hp = 260, atk = 7, spd = 6, shape = "golem" },
		["Ash Wolf"] = { element = "Ember", hp = 190, atk = 8, spd = 13, shape = "wolf" },
	},
	FLYING = { "Cave Bat" },
	MONSTER_GROWTH = 0.12,

	MONSTERS_PER_ZONE = 8,
	RESPAWN_MIN = 20,
	RESPAWN_MAX = 40,
	ELITE_CHANCE = 0.1,
	ELITE_STAT_MULTIPLIER = 1.6,
	ELITE_REWARD_MULTIPLIER = 3,

	-- Movement
	WAKE_RADIUS = 100, -- monsters sleep with no player this close
	WANDER_RADIUS = 12,
	WANDER_SPEED = 5,
	AGGRO_RADIUS = 25,
	CHASE_SPEED = 11,
	CHASE_GIVE_UP = 45, -- studs from home
	CONTACT_DISTANCE = 4, -- a chasing monster this close starts the fight
	CHASE_REST_SECONDS = 25, -- after catching you, a fight or giving up, a monster won't chase again for this long
	MARKER_RATE = 10, -- monster marker updates per second
	PROMPT_DISTANCE = 10,
	STREAM_TIMEOUT = 10, -- seconds to wait for the destination to load on the player's device before moving them
	FALL_RESCUE_DEPTH = 40, -- studs below the wild floor: put the player back at the entrance

	-- Rewards (win): xp = XP_BASE * level ^ XP_EXPONENT (split across the party), cash = CASH_PER_LEVEL * level
	XP_BASE = 12,
	XP_EXPONENT = 1.3,
	CASH_PER_LEVEL = 0.4,
	DROP_CHANCE = 0.05,
	ELITE_DROP_CHANCE = 0.2,
	-- Card drop rarity weights (a card of the zone's elements)
	DROP_RARITY = { Common = 70, Rare = 20, ["Very Rare"] = 7, Epic = 2.5, Legendary = 0.5 },

	MAX_MODEL_PARTS = 200,
	MONSTER_HEIGHT = 3, -- studs at size 1; elites are ELITE_SIZE times bigger
	ELITE_SIZE = 1.35,
}
