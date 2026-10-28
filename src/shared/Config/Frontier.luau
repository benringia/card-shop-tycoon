--!strict
-- The Frontier (battles part 3a spec): the shared high-level place. Same shape as Config/Wild (WildService and
-- BattleService run either one through Util/Place.getWorld), plus the Frontier-only drops. Levels are a first
-- pass and meant to be retuned. Plain data only (positions are { x, y, z } tables) so Lune tests can load it.
return {
	-- The Frontier place has no plots: the map sits at the origin, the entrance at its south edge
	ORIGIN = { x = 0, y = 0, z = 0 },
	SPRING = { x = 22, y = 0, z = -70 }, -- healing spring next to the entrance
	SPRING_LABEL_DISTANCE = 35, -- the healing spring's name shows only this close
	PORTAL_SIGN_HEIGHT = 17, -- the Dungeon portal's sign floats this high over its frame
	DUNGEON_PORTAL = { x = -22, y = 0, z = -70 }, -- part 3b; "coming soon" until then
	ENTRANCE_OFFSET = { x = 0, y = 0, z = -70 }, -- arrival point relative to ORIGIN
	ZONE_SIZE = 140,
	ZONE_GAP = 24,

	ZONES = {
		{ name = "Frostwood", minLevel = 15, maxLevel = 25, recommended = 15, species = { "Frost Wisp", "Shade Lynx" }, aggro = false, color = { 170, 200, 220 } },
		{ name = "Stormpeak", minLevel = 25, maxLevel = 35, recommended = 25, species = { "Storm Hawk", "Lava Brute" }, aggro = false, color = { 110, 110, 130 } },
		{ name = "The Rift", minLevel = 35, maxLevel = 50, recommended = 35, species = { "Rift Horror", "Prism Crab" }, aggro = true, color = { 70, 40, 90 }, elements = { "Ember", "Tide", "Bloom", "Volt", "Shade" } },
	},

	-- Base stats at level 1; level L multiplies by 1 + MONSTER_GROWTH * (L - 1)
	SPECIES = {
		["Frost Wisp"] = { element = "Tide", hp = 190, atk = 6, spd = 11, shape = "slime" },
		["Shade Lynx"] = { element = "Shade", hp = 200, atk = 7, spd = 14, shape = "wolf" },
		["Storm Hawk"] = { element = "Volt", hp = 180, atk = 7, spd = 15, shape = "bat" },
		["Lava Brute"] = { element = "Ember", hp = 280, atk = 8, spd = 7, shape = "golem" },
		["Rift Horror"] = { element = "Shade", hp = 240, atk = 9, spd = 12, shape = "beetle" },
		["Prism Crab"] = { element = "Bloom", hp = 260, atk = 8, spd = 9, shape = "crab" },
	},
	FLYING = { "Storm Hawk" },
	MONSTER_GROWTH = 0.12,

	MONSTERS_PER_ZONE = 8,
	RESPAWN_MIN = 20,
	RESPAWN_MAX = 40,
	ELITE_CHANCE = 1 / 6,
	ELITE_STAT_MULTIPLIER = 1.6,
	ELITE_REWARD_MULTIPLIER = 3,

	-- Movement
	WAKE_RADIUS = 100,
	WANDER_RADIUS = 12,
	WANDER_SPEED = 5,
	AGGRO_RADIUS = 25,
	CHASE_SPEED = 12,
	CHASE_GIVE_UP = 45,
	CONTACT_DISTANCE = 4,
	CHASE_REST_SECONDS = 25,
	MARKER_RATE = 10,
	PROMPT_DISTANCE = 10,
	STREAM_TIMEOUT = 10,
	FALL_RESCUE_DEPTH = 40,

	-- Rewards (win), same formulas as the wild
	XP_BASE = 12,
	XP_EXPONENT = 1.3,
	CASH_PER_LEVEL = 0.4,
	DROP_CHANCE = 0.05, -- a Set 1 card of the zone's elements, as in the wild
	ELITE_DROP_CHANCE = 0.2,
	DROP_RARITY = { Common = 50, Rare = 30, ["Very Rare"] = 12, Epic = 6, Legendary = 2 },

	-- Frontier-only drops
	SHARD_CHANCE = 0.03, -- 1 Star Shard
	ELITE_SHARD_CHANCE = 0.10,
	CARD_CHANCE = 0.03, -- a Frontier card
	ELITE_CARD_CHANCE = 0.10,
	CARD_RARITY = { Rare = 70, Epic = 25, Legendary = 5 },

	MAX_MODEL_PARTS = 200,
	MONSTER_HEIGHT = 3.5,
	ELITE_SIZE = 1.35,
}
