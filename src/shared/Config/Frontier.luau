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

	-- Base stats at level 1; level L multiplies by 1 + MONSTER_GROWTH * (L - 1). HP and ATK tuned with
	-- `lune run tools/balance/wild` (owner 2026-11-03): about 12.5 s fought well at the zone's middle level, won about 75%
	-- standing still
	SPECIES = {
		["Frost Wisp"] = { element = "Tide", hp = 670, atk = 19.9, spd = 11, shape = "slime" },
		["Shade Lynx"] = { element = "Shade", hp = 706, atk = 19.4, spd = 14, shape = "wolf" },
		["Storm Hawk"] = { element = "Volt", hp = 797, atk = 19.3, spd = 15, shape = "bat" },
		["Lava Brute"] = { element = "Ember", hp = 826, atk = 24, spd = 7, shape = "golem" },
		["Rift Horror"] = { element = "Shade", hp = 801, atk = 20.7, spd = 12, shape = "beetle" },
		["Prism Crab"] = { element = "Bloom", hp = 753, atk = 22.3, spd = 9, shape = "crab" },
	},
	FLYING = { "Storm Hawk" },
	MONSTER_GROWTH = 0.12,

	MONSTERS_PER_ZONE = 8,
	RESPAWN_MIN = 20,
	RESPAWN_MAX = 40,
	ELITE_CHANCE = 1 / 6,
	-- An elite's HP and ATK are its species' times these, unless the species sets its own eliteHp / eliteAtk (bigger;
	-- SPD x1.1). Tuned with `lune run tools/balance/wild` (owner 2026-11-03): about 25-35 s, won about 65% fighting well.
	-- A wild fight is lost once your creatures faint, so a longer fight needs softer hits: an elite has about twice the
	-- HP and hits a little softer than its species (still harder than elites before the player joined), while its quick
	-- hits on the player hit harder (ELITE_PLAYER_QUICK)
	ELITE_HP_MULTIPLIER = 2.3,
	ELITE_ATK_MULTIPLIER = 0.6,
	-- With a sword the player fights beside their creature (owner 2026-11-03): a monster's quick hits on them take this
	-- share of the player's HP (CombatMath.getMonsterAttacks); no rings outside boss fights
	PLAYER_QUICK = 0.08,
	ELITE_PLAYER_QUICK = 0.12,
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
	-- The monsters' small effects (Config/Wild FX): no Frontier species has one yet
	FX_RANGE = 60,
	FX = {},
}
