--!strict
-- The server wild map (battles part 1 spec): zones, monster species, spawns and rewards.
-- Plain data only (positions are { x, y, z } tables) so Lune tests can load this file.
return {
	-- Far from the plots (they sit around the origin); zones run along +Z from here
	ORIGIN = { x = 0, y = 0, z = 1200 },
	PLAZA_PORTAL = { x = 185, y = 0, z = -118 }, -- by the pool at Forest Falls, at the end of its trail (Town.PORTAL_AREAS)
	SPRING = { x = 0, y = 0, z = 0 }, -- plaza centre between the shop rows
	SPRING_LABEL_DISTANCE = 35, -- the healing spring's name shows only this close
	PORTAL_SIGN_HEIGHT = 17, -- portal signs float above the portal frame prop (Town.SLOTS.Portal)
	SIGN_WIDTH = 14, -- WildService's plain name boards (the Frontier's and the Dungeon's)
	ENTRANCE_OFFSET = { x = 0, y = 0, z = -70 }, -- arrival point relative to ORIGIN
	ZONE_SIZE = 120, -- each zone is a square this wide
	ZONE_GAP = 20, -- path between zones

	ZONES = {
		{ name = "Meadow", minLevel = 1, maxLevel = 5, recommended = 1, species = { "Mossling", "Puddle Crab" }, aggro = false, color = { 110, 180, 90 } },
		{ name = "Caves", minLevel = 5, maxLevel = 10, recommended = 5, species = { "Cave Bat", "Spark Beetle" }, aggro = false, color = { 90, 85, 100 } },
		-- danger: its monsters hurt you too and a lost fight knocks you out (owner 2026-11-12; Util/DangerRules)
		{ name = "Ember Ridge", minLevel = 10, maxLevel = 15, recommended = 10, species = { "Magma Golem", "Ash Wolf" }, aggro = true, danger = true, color = { 150, 80, 55 } },
	},

	-- Base stats at level 1; level L multiplies by 1 + MONSTER_GROWTH * (L - 1). height: studs tall (elites ELITE_SIZE
	-- times that; the user's pick B of a to-scale lineup, the meadow pair raised a stud to stand out of the grass, which
	-- is also cut shorter: Terrain GrassLength, a Studio-only property); glow: the steady emissive strength of the
	-- model's glow mask (a changing strength costs about 6.6 ms of render CPU a frame, so none pulses).
	-- HP and ATK tuned with `lune run tools/balance/wild` (owner 2026-11-03, the player fights beside their creature):
	-- about 12.5 s fought well at the zone's middle level, won about 75% standing still. The Meadow comes before the
	-- sword (shop level 4), so its pair is tuned for the creature alone (about 70-80%), and its elites set their own
	SPECIES = {
		Mossling = { element = "Bloom", hp = 175, atk = 6, eliteHp = 2.5, eliteAtk = 1.2, spd = 8, shape = "slime", height = 3.5, glow = { strength = 2 } },
		["Puddle Crab"] = { element = "Tide", hp = 179, atk = 6.1, eliteHp = 2.5, eliteAtk = 1, spd = 7, shape = "crab", height = 3, glow = { strength = 2 } },
		["Cave Bat"] = { element = "Shade", hp = 260, atk = 8.4, spd = 12, shape = "bat", height = 3, glow = { strength = 2 } },
		["Spark Beetle"] = {
			element = "Volt", hp = 258, atk = 10.1, spd = 10, shape = "beetle", height = 2.5, glow = { strength = 2 },
			fx = { kind = "sparks", bones = { "Fx_PincerLeft", "Fx_PincerRight" } }, -- crackling at the pincer tips
		},
		["Magma Golem"] = {
			element = "Ember", hp = 444, atk = 17, spd = 6, shape = "golem", height = 6.5, glow = { strength = 2.5 },
		},
		["Ash Wolf"] = {
			element = "Ember", hp = 445, atk = 10.9, spd = 13, shape = "wolf", height = 4, glow = { strength = 2 },
			fx = { kind = "smoke", bones = { "Fx_Tail" } }, -- a wisp of smoke from the tail tip
		},
	},
	-- The monsters' small effects (SPECIES fx), on zero-influence Fx_ bones of their models: only within FX_RANGE studs
	-- of the camera and with the extras on (Util/Extras). Sizes in studs; colours { r, g, b }
	FX_RANGE = 60,
	FX = {
		sparks = {
			texture = "rbxasset://textures/particles/sparkles_main.dds", color = { 255, 230, 90 }, lightEmission = 1,
			size = { 0.45, 0 }, transparency = { 0, 1 }, lifetime = { 0.15, 0.3 }, rate = 18, speed = { 2, 4 }, spread = 180,
			rise = 0,
		},
		smoke = {
			texture = "rbxasset://textures/particles/smoke_main.dds", color = { 85, 82, 80 }, lightEmission = 0,
			size = { 0.4, 1.2 }, transparency = { 0.45, 1 }, lifetime = { 1.2, 2 }, rate = 4, speed = { 0.4, 0.9 }, spread = 25,
			rise = 1.5,
		},
	},
	FLYING = { "Cave Bat" },
	MONSTER_GROWTH = 0.12,

	MONSTERS_PER_ZONE = 8,
	RESPAWN_MIN = 20,
	RESPAWN_MAX = 40,
	ELITE_CHANCE = 0.1,
	-- An elite's HP and ATK are its species' times these, unless the species sets its own eliteHp / eliteAtk (bigger;
	-- SPD x1.1). Tuned with `lune run tools/balance/wild` (owner 2026-11-03): about 25-35 s, won about 65% fighting well.
	-- A wild fight is lost once your creatures faint, so a longer fight needs softer hits: an elite has about twice the
	-- HP and hits a little softer than its species (still harder than elites before the player joined), while its quick
	-- hits on the player hit harder (ELITE_PLAYER_QUICK)
	ELITE_HP_MULTIPLIER = 2.1,
	ELITE_ATK_MULTIPLIER = 0.8,
	-- With a sword the player fights beside their creature (owner 2026-11-03): a monster's quick hits on them take this
	-- share of the player's HP (CombatMath.getMonsterAttacks); no rings outside boss fights
	PLAYER_QUICK = 0.08,
	ELITE_PLAYER_QUICK = 0.12,
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
	-- Wild Ore (Config/Weapons WILD_ORE: the Forge weapons) per win, as for the Frontier
	ORE_CHANCE = 0.15,
	ELITE_ORE_CHANCE = 0.6,
	-- Card drop rarity weights (a card of the zone's elements)
	DROP_RARITY = { Common = 70, Rare = 20, ["Very Rare"] = 7, Epic = 2.5, Legendary = 0.5 },

	MAX_MODEL_PARTS = 200,
	MONSTER_HEIGHT = 3, -- studs at size 1; elites are ELITE_SIZE times bigger
	ELITE_SIZE = 1.35,
}
