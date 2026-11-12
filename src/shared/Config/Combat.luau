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
	CLAP_BREATHER = 1, -- seconds after a warned thunderclap lands before the boss's next big attack can start

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
	-- The super meter (owner 2026-11-06, option A: "there should be some kind of condition ... instead of just spamming
	-- it"): one per player, `start` at a fight's start, `full` to fire a super (which empties it). It fills `hit` for each
	-- of its creatures' hits that lands (Pet button moves too, never a super's own), `sword` for each sword hit, `dodge`
	-- for each boss hit dodged or ring stepped out of, and `hurt` for each full max HP its creatures or player lose (a
	-- comeback); a creature's Express perk fills it that much faster. About 25 s fighting well, 45 s standing still.
	SUPER_METER = { start = 0, full = 100, hit = 1.5, sword = 2, dodge = 8, hurt = 10 },
	-- Super moves (spec 2026-11-05-super-moves-design): `look` picks its effects (Config/SuperFx LOOKS; the Frontier
	-- four share their base move's kind but have looks of their own), `windup` the seconds it winds up before landing
	-- (Epic 1.5, Legendary 2: the caster's cinematic plays meanwhile)
	SIGNATURES = {
		Infernox = { kind = "Inferno", name = "Inferno", seconds = 6, perSecond = 0.4, look = "Inferno", windup = 1.5 },
		-- Tidal Shield: every ally (players too) a ward of `shield` of its own max HP for `seconds` (owner 2026-11-05;
		-- trimmed to 25% / 6 s while supers came every 15 s, back to 30% / 8 s with the super meter)
		["Abyssal Koi"] = { kind = "TidalShield", name = "Tidal Shield", shield = 0.3, seconds = 8, look = "TidalShield", windup = 1.5 },
		Thunderhorn = { kind = "Stampede", name = "Stampede", power = 2, stun = 2, look = "Stampede", windup = 1.5 },
		-- Eclipse: its mirror image evades everything for `seconds` (owner 2026-11-05: 5)
		["Eclipse Fox"] = { kind = "Eclipse", name = "Eclipse", seconds = 5, look = "Eclipse", windup = 1.5 },
		-- Supernova winds up longer than the other Legendaries (owner 2026-11-05: "dont rush"; Config/SuperFx timing)
		Solarion = { kind = "Supernova", name = "Supernova", power = 4, look = "Supernova", windup = 3.5 },
		-- Devour heals `lifesteal` of the hit, at most `healCap` of its max HP (boss balance 2026-11-05: uncapped, Voidmaw
		-- alone made the Prism Hydra a sure win standing still; 15% with the super meter)
		Voidmaw = { kind = "Devour", name = "Devour", power = 2, lifesteal = 0.5, healCap = 0.15, look = "Devour", windup = 2 },
		-- Frontier cards: same ability kinds, their own names and looks
		-- Rift Step (owner 2026-11-05, option C "Blink Barrage"): `hits` hits of `power` x ATK, `gap` seconds apart, each
		-- from another side of the foe (the first lands as the wind-up ends)
		Riftwalker = { kind = "Barrage", name = "Rift Step", hits = 4, power = 0.8, gap = 0.25, look = "RiftStep", windup = 1.5 },
		["Cinder Titan"] = { kind = "Stampede", name = "Magma Slam", power = 2, stun = 2, look = "MagmaSlam", windup = 1.5 },
		-- Tidal Blessing (owner 2026-11-05, option B "Rebirth Spring"): its owner's fainted creatures stand back up at
		-- `revive` of their max HP (once a fight), the rest of its owner's party (the player too) heals `heal` of theirs
		["Tideborne Kirin"] = { kind = "Rebirth", name = "Tidal Blessing", revive = 0.35, heal = 0.15, look = "TidalBlessing", windup = 2 },
		Stormking = { kind = "Supernova", name = "Thunderstorm", power = 4, look = "Thunderstorm", windup = 2 },
	},
	-- The caster's player can't be hit from a super's press until control returns: its wind-up plus this (the impact
	-- beat and the camera's ease back); the boss starts nothing new at them meanwhile (owner 2026-11-05: "while your
	-- camera is away, boss attacks can't hit you")
	SUPER_PROTECT_TAIL = 0.6,

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
	-- of a boss's swings go at a player (a quick hit) while a creature of theirs stands: none, bosses go for pets first
	-- (the owner 2026-11-10; was 1 / 3); with no creature standing every swing goes at a player. Its warned big
	-- attacks (rings, the Frost Tyrant's spikes) still come for players
	PLAYER_TARGET_SHARE = 0,
	-- A boss with player attacks swings this many times slower than its SPD says: with every normal hit now at pets, its
	-- pets take the same hits a second as when one in three went at the player (1 / (1 - 1 / 3))
	BOSS_PACE = 1.5,
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
	PET_PYLON_SHARE = 0.5, -- a creature sent at the Dungeon's crystal pylons hits them for this share of its ATK
	PET_PYLON_COOLDOWN = 0.5, -- remote rate limit on the pylons' "Send creature" prompts
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
