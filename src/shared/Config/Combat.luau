--!strict
-- Combat numbers (battles part 1 spec). Plain data only so Lune tests can load this file.
return {
	TICK_RATE = 10, -- fight steps per second on the server
	CALL_IN_SECONDS = 5, -- second party card may join only this early
	MAX_FIGHT_SECONDS = 120, -- a fight still going after this ends as a run (stuck or idle)
	BOSS_MAX_FIGHT_SECONDS = 420, -- bosses have far more HP: their fights may run this long
	BOSS_SWAP_SECONDS = 8, -- boss fights: seconds between a player's swaps (none needed when all of theirs fainted)
	BOSS_MAX_STUN = 1, -- seconds: stuns on a boss last at most this long
	BOSS_SKILL_GAP = 6, -- seconds between any two of a boss's skills (shield, heal, thunderclap): never back to back

	-- Attacks: interval = clamp(ATTACK_BASE * (SPD_REFERENCE / SPD) ^ ATTACK_CURVE, ATTACK_MIN, ATTACK_MAX): a gentle curve
	-- so every SPD a card reaches still speeds it up (SPD 10 every 2 s, 27 every 1.08 s, 47 every 0.77 s, 69 every 0.6 s)
	ATTACK_BASE = 2,
	SPD_REFERENCE = 10,
	ATTACK_CURVE = 0.62,
	ATTACK_MIN = 0.55,
	ATTACK_MAX = 2.5,
	DAMAGE_SPREAD = 0.1, -- +-10%
	CHARGE_LEAD = 0.6, -- seconds before an auto-attack lands that clients hear of it (a "charge" event: wind-up, effects)
	CHARGE_SHARE = 0.75, -- a fast attacker charges at most this share of its gap between attacks (not charging nonstop)

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
	-- A Pet button move or super move winds up this long before it fires (owner 2026-11-04, design A: the creature
	-- lifts and glows, a ring spins under it and the move's name pops above it, so everyone sees it coming)
	ABILITY_WINDUP = 0.5,
	ABILITIES = {
		Ember = { kind = "Fireball", name = "Fireball", power = 2.5 },
		-- Healing Rain (was Wave; owner 2026-11-05): `heal` of max HP over `ticks` ticks, one every `every` seconds, the
		-- first `every` after it lands (BattleSim regen); a `playerGrade` caster's rain also heals its owner's player
		-- `playerHeal` of their HP over the same ticks (the owner 2026-11-05: "S healing rain also heal player")
		Tide = { kind = "Rain", name = "Healing Rain", heal = 0.25, ticks = 5, every = 1, playerHeal = 0.15, playerGrade = "S" },
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
	REST_SECONDS = 300,
	-- The Wild's "Return to town" pill, top centre (owner 2026-11-03, round 3): px
	HOME_BUTTON = { width = 210, height = 48, textSize = 17 },
	SPRING_RADIUS = 12,
	SPRING_SPEED = 3,

	-- The player in boss fights (spec 2026-11-02-you-in-the-fight-design): a sword beside one summoned creature
	PLAYER_HP = 100, -- everyone's; boss hits on players are shares of it (Config/Bosses playerAttacks)
	DOWN_SECONDS = 5, -- at 0 HP you're down this long, then back up while one of your creatures stands
	GET_UP_SHARE = 0.5, -- of your HP back when you get up
	PLAYER_TARGET_SHARE = 1 / 3, -- of a boss's swings go at a player (a quick hit) instead of a creature
	QUICK_WARNING = 0.5, -- seconds the boss flashes before a quick hit lands
	HIT_GRACE = 0.15, -- seconds the server lands hits on players after clients show them (a late dodge still counts)
	DODGE_SECONDS = 0.35, -- untouchable after a dodge
	DODGE_COOLDOWN = 2.5, -- owner 2026-11-04 (option A, was 1): one dodge per ring still, but mashing it stops working
	DODGE_STUDS = 12, -- the dash's length
	-- A dash that would end inside a boss or monster goes on through it to this far past its edge, up to DODGE_MAX_STUDS
	-- (SwordRules.dashLength; owner 2026-11-04)
	DODGE_PASS_MARGIN = 1.5,
	DODGE_MAX_STUDS = 26,
	DODGE_FORCE = 200000, -- the dash's push (a LinearVelocity in the ground plane): enough to hold its speed
	LOSS_COUNTDOWN = 5, -- seconds a lost boss fight's defeat screen shows before town (owner 2026-11-04; it can't be skipped)
	SWORD_ACTION_COOLDOWN = 0.08, -- remote rate limit on Attack, Skill and Dodge taps
	SWORD_IDLE_ATK = 10, -- the sword's ATK when none of your creatures has been on the field (never in practice)

	-- World
	FIGHT_RANGE = 12, -- studs from player to monster to start
	RING_RADIUS = 6, -- fighters stand this far from the ring centre
	EXTRA_SIDE = 3, -- a called-in creature stands this far to its leader's right
	-- A creature that attacks from range (AttackFx: a projectile or a bolt) stands this much further back from its foe
	-- than its ring spot (owner 2026-11-03: "ranged, not melee"); combo attackers stay on the spot
	RANGED_BACK = 7,
	LEASH_RADIUS = 25, -- players may roam this far from the ring during a fight
	LUNGE_STUDS = 1.5,
	ACTION_COOLDOWN = 0.25, -- remote rate limit
	END_SCREEN_SECONDS = 4,
}
