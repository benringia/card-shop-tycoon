# Battles Part 1 (Combat Core + Server Wild Map) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players travel from the plaza to a wild map in the same server, fight monsters in real-time auto-battles with their party, and earn card XP, cash and card drops; fainted cards rest (faster at the plaza spring).

**Architecture:** A pure, seeded fight simulation (`BattleSim`, Lune-tested) runs on the server at 10 Hz inside `BattleService`, which sends events to the fighting player's client. `WildService` builds a placeholder wild map, portals and the healing spring, and moves invisible monster markers; clients draw monsters (`MonsterController`) the way they draw summoned creatures, through a shared `CreatureVisuals` util. `BattleController` shows the fight bar.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7, Lune 0.11 tests (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-10-22-battles-wild-design.md`

## Global Constraints

- Server authoritative: clients send intents only; fights, rolls, rewards and rest timers are decided on the server.
- All cash changes through `EconomyService.AddCash`; card XP through `CardService.AddXP`; card drops through `CardService.AddFresh` with a server-rolled grade.
- Every remote is defined in `src/shared/Remotes.luau`, validated (types, ranges, ownership, distance) and rate-limited with `RateLimiter`.
- All tunable numbers in `src/shared/Config` (`Combat.luau`, `Wild.luau`). Config files read by Lune hold plain data only (no Vector3/Color3).
- Saved data plain; schema change = bump `SCHEMA_VERSION` to 8, migration `[7]` with a Lune test, types/template, DESIGN 10.4.
- `save` does nothing if that service never loaded for the player.
- UI: tap targets ≥ 48 px, plain ASCII plus `·` and emoji, built with UIKit; HUD stays clear of the jump button.
- Free models (monsters too) never run scripts: Lune gate test over `assets/monsters` plus runtime strip.
- Element wheel: Ember > Bloom > Tide > Ember; Volt and Shade strong against each other. Strong ×1.5, weak ×0.75.
- Fighters: leader (summoned, rested) + one call-in within the first 5 s; max 2 of yours vs 1 monster.
- XP split evenly across all 3 party cards (floor, at least 1 each).
- Rest 180 s; spring 3x within 12 studs; Run = clamp(0.5 + 0.03 × (leaderSPD − monsterSPD), 0.2, 0.9) − 0.15 elite (min 0.2).

## Review Focus

1. **Player leaves, resets, or their summoned card disappears mid-fight** → fight ends as a run, markers cleaned up, monster unlocked, no rewards, no error.
2. **Party changes during a fight** (Summon, SetPartySlot, condense, job, display of a fighter) → refused until the fight ends.
3. **Spam and races**: StartFight on a monster another player is fighting, two StartFights at once, UseAbility before cooldown or for a fighter not in the fight, CallIn after 5 s or twice → refused; one fight per player.
4. **Saved `resting` with junk** (unknown beast ids, strings, NaN, times far in the future) → dropped or clamped to now + REST_SECONDS.
5. **A chasing monster reaching a player who is already fighting, has no summon, or whose summon is resting** → no fight, monster gives up and returns home.

---

### Task 1: Combat and wild config + CombatMath

**Files:**
- Create: `src/shared/Config/Combat.luau`, `src/shared/Config/Wild.luau`, `src/shared/Util/CombatMath.luau`
- Test: `tests/CombatMath.spec.luau`; modify `tests/run.luau`

**Interfaces:**
- Produces:
  - `CombatMath.getAttackInterval(combat, spd: number): number`
  - `CombatMath.getElementMultiplier(combat, attacker: string, defender: string): (number, ("strong" | "weak")?)`
  - `CombatMath.getDamage(combat, atk: number, multiplier: number, roll: number): number` (roll in [0,1))
  - `CombatMath.getRunChance(combat, leaderSpd: number, monsterSpd: number, elite: boolean): number`
  - `CombatMath.splitXp(total: number, count: number): number`
  - `CombatMath.getMonsterStats(wild, species: string, level: number, elite: boolean): { hp: number, atk: number, spd: number }?`
  - `CombatMath.getRewards(wild, level: number, elite: boolean): { xp: number, cash: number, dropChance: number }`

- [ ] **Step 1: Write the failing test** `tests/CombatMath.spec.luau`

```lua
--!strict
local CombatMath = require("../src/shared/Util/CombatMath")
local combat = require("../src/shared/Config/Combat")
local wild = require("../src/shared/Config/Wild")
local expect = require("./lib/expect")

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

return {
	["element wheel: strong, weak and neutral for all 25 pairs"] = function()
		local strong = { Ember = "Bloom", Bloom = "Tide", Tide = "Ember", Volt = "Shade", Shade = "Volt" }
		for _, a in ELEMENTS do
			for _, d in ELEMENTS do
				local mult, kind = CombatMath.getElementMultiplier(combat, a, d)
				if strong[a] == d then
					expect.equal(mult, combat.STRONG, `{a}>{d}`)
					expect.equal(kind, "strong", `{a}>{d} kind`)
				elseif strong[d] == a then
					expect.equal(mult, combat.WEAK, `{a}<{d}`)
					expect.equal(kind, "weak", `{a}<{d} kind`)
				else
					expect.equal(mult, 1, `{a}={d}`)
					expect.isNil(kind, `{a}={d} kind`)
				end
			end
		end
	end,

	["attack interval: faster with SPD, clamped"] = function()
		expect.near(CombatMath.getAttackInterval(combat, 10), 2, 1e-9, "Common SPD 10")
		expect.near(CombatMath.getAttackInterval(combat, 20), 1, 1e-9, "Legendary SPD 20")
		expect.equal(CombatMath.getAttackInterval(combat, 1000), combat.ATTACK_MIN, "min")
		expect.equal(CombatMath.getAttackInterval(combat, 1), combat.ATTACK_MAX, "max")
		expect.equal(CombatMath.getAttackInterval(combat, 0), combat.ATTACK_MAX, "zero SPD")
	end,

	["damage: spread around ATK x multiplier, at least 1"] = function()
		expect.equal(CombatMath.getDamage(combat, 20, 1, 0.5), 20, "middle roll")
		expect.equal(CombatMath.getDamage(combat, 20, 1, 0), 18, "low roll -10%")
		assert(CombatMath.getDamage(combat, 20, 1.5, 0.999) <= 33, "high roll +10%")
		expect.equal(CombatMath.getDamage(combat, 0.1, 0.75, 0), 1, "at least 1")
	end,

	["run chance: SPD moves it, clamped, elite penalty"] = function()
		expect.near(CombatMath.getRunChance(combat, 10, 10, false), 0.5, 1e-9, "even")
		expect.near(CombatMath.getRunChance(combat, 14, 10, false), 0.62, 1e-9, "+4 SPD")
		expect.equal(CombatMath.getRunChance(combat, 100, 1, false), combat.RUN_MAX, "max")
		expect.equal(CombatMath.getRunChance(combat, 1, 100, false), combat.RUN_MIN, "min")
		expect.near(CombatMath.getRunChance(combat, 14, 10, true), 0.47, 1e-9, "elite")
		expect.equal(CombatMath.getRunChance(combat, 1, 100, true), combat.RUN_MIN, "elite floor")
	end,

	["xp split: floor, at least 1, never more than the total"] = function()
		expect.equal(CombatMath.splitXp(30, 3), 10, "even")
		expect.equal(CombatMath.splitXp(31, 3), 10, "floor")
		expect.equal(CombatMath.splitXp(1, 3), 1, "at least 1")
		expect.equal(CombatMath.splitXp(0, 3), 0, "nothing to split")
		expect.equal(CombatMath.splitXp(30, 0), 0, "no cards")
	end,

	["monster stats grow with level; elites stronger; unknown species nil"] = function()
		local low = CombatMath.getMonsterStats(wild, "Mossling", 1, false) :: any
		local high = CombatMath.getMonsterStats(wild, "Mossling", 5, false) :: any
		local elite = CombatMath.getMonsterStats(wild, "Mossling", 1, true) :: any
		assert(high.hp > low.hp and high.atk > low.atk, "grows")
		expect.equal(elite.hp, math.round(low.hp * wild.ELITE_STAT_MULTIPLIER), "elite hp")
		expect.isNil(CombatMath.getMonsterStats(wild, "Nope", 1, false), "unknown")
	end,

	["rewards scale with level and elite"] = function()
		local r1 = CombatMath.getRewards(wild, 1, false)
		local r10 = CombatMath.getRewards(wild, 10, false)
		local e1 = CombatMath.getRewards(wild, 1, true)
		assert(r10.xp > r1.xp and r10.cash > r1.cash, "level")
		expect.equal(e1.xp, r1.xp * wild.ELITE_REWARD_MULTIPLIER, "elite xp")
		expect.equal(r1.dropChance, wild.DROP_CHANCE, "normal drop")
		expect.equal(e1.dropChance, wild.ELITE_DROP_CHANCE, "elite drop")
	end,

	["every zone species exists and every species has a valid element"] = function()
		for _, zone in wild.ZONES do
			for _, species in zone.species do
				assert(wild.SPECIES[species], `{zone.name}: unknown species {species}`)
			end
		end
		for name, species in wild.SPECIES do
			assert(table.find(ELEMENTS, species.element), `{name}: element {species.element}`)
		end
	end,
}
```

Register in `tests/run.luau`: `CombatMath = require("./CombatMath.spec"),`

- [ ] **Step 2: Run** `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run` — Expected: FAIL (module not found).

- [ ] **Step 3: Write `src/shared/Config/Combat.luau`**

```lua
--!strict
-- Combat numbers (battles part 1 spec). Plain data only so Lune tests can load this file.
return {
	TICK_RATE = 10, -- fight steps per second on the server
	CALL_IN_SECONDS = 5, -- second party card may join only this early
	MAX_FIGHT_SECONDS = 120, -- a fight still going after this ends as a run (stuck or idle)

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
	LUNGE_STUDS = 1.5,
	ACTION_COOLDOWN = 0.25, -- remote rate limit
	END_SCREEN_SECONDS = 4,
}
```

- [ ] **Step 4: Write `src/shared/Config/Wild.luau`**

```lua
--!strict
-- The server wild map (battles part 1 spec): zones, monster species, spawns and rewards.
-- Plain data only (positions are { x, y, z } tables) so Lune tests can load this file.
return {
	-- Far from the plots (they sit around the origin); zones run along +Z from here
	ORIGIN = { x = 0, y = 0, z = 1200 },
	PLAZA_PORTAL = { x = 0, y = 0, z = -60 }, -- end of the street
	SPRING = { x = 0, y = 0, z = 0 }, -- plaza centre between the shop rows
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
	MARKER_RATE = 10, -- monster marker updates per second
	PROMPT_DISTANCE = 10,

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
```

- [ ] **Step 5: Write `src/shared/Util/CombatMath.luau`**

```lua
--!strict
-- Combat maths shared by the fight simulation, the server and the client's fight bar.
-- Pure (no requires, no Roblox APIs): callers pass Config/Combat and Config/Wild in, so tests/ run it in Lune.
local CombatMath = {}

type Combat = {
	ATTACK_BASE: number,
	SPD_REFERENCE: number,
	ATTACK_MIN: number,
	ATTACK_MAX: number,
	DAMAGE_SPREAD: number,
	STRONG: number,
	WEAK: number,
	BEATS: { [string]: { string } },
	RUN_BASE: number,
	RUN_PER_SPD: number,
	RUN_MIN: number,
	RUN_MAX: number,
	RUN_ELITE_PENALTY: number,
}

type Wild = {
	SPECIES: { [string]: { element: string, hp: number, atk: number, spd: number } },
	MONSTER_GROWTH: number,
	ELITE_STAT_MULTIPLIER: number,
	ELITE_REWARD_MULTIPLIER: number,
	XP_BASE: number,
	XP_EXPONENT: number,
	CASH_PER_LEVEL: number,
	DROP_CHANCE: number,
	ELITE_DROP_CHANCE: number,
}

function CombatMath.getAttackInterval(combat: Combat, spd: number): number
	if spd <= 0 then
		return combat.ATTACK_MAX
	end
	return math.clamp(combat.ATTACK_BASE * combat.SPD_REFERENCE / spd, combat.ATTACK_MIN, combat.ATTACK_MAX)
end

local function beats(combat: Combat, a: string, b: string): boolean
	local list = combat.BEATS[a]
	return list ~= nil and table.find(list, b) ~= nil
end

function CombatMath.getElementMultiplier(combat: Combat, attacker: string, defender: string): (number, ("strong" | "weak")?)
	if beats(combat, attacker, defender) then
		return combat.STRONG, "strong"
	elseif beats(combat, defender, attacker) then
		return combat.WEAK, "weak"
	end
	return 1, nil
end

-- roll in [0, 1): 0 is -SPREAD, 0.5 is exact, near 1 is +SPREAD
function CombatMath.getDamage(combat: Combat, atk: number, multiplier: number, roll: number): number
	local spread = 1 + combat.DAMAGE_SPREAD * (2 * roll - 1)
	return math.max(1, math.round(atk * multiplier * spread))
end

function CombatMath.getRunChance(combat: Combat, leaderSpd: number, monsterSpd: number, elite: boolean): number
	local chance = math.clamp(combat.RUN_BASE + combat.RUN_PER_SPD * (leaderSpd - monsterSpd), combat.RUN_MIN, combat.RUN_MAX)
	if elite then
		chance = math.max(combat.RUN_MIN, chance - combat.RUN_ELITE_PENALTY)
	end
	return chance
end

-- XP each party card gets: an even share, rounded down, but at least 1 when there is anything to share
function CombatMath.splitXp(total: number, count: number): number
	if total <= 0 or count <= 0 then
		return 0
	end
	return math.max(1, math.floor(total / count))
end

function CombatMath.getMonsterStats(wild: Wild, species: string, level: number, elite: boolean): { hp: number, atk: number, spd: number }?
	local base = wild.SPECIES[species]
	if not base then
		return nil
	end
	local growth = 1 + wild.MONSTER_GROWTH * (math.max(1, level) - 1)
	local boost = if elite then wild.ELITE_STAT_MULTIPLIER else 1
	return {
		hp = math.round(base.hp * growth * boost),
		atk = math.round(base.atk * growth * boost),
		spd = math.round(base.spd * (if elite then 1.1 else 1)),
	}
end

function CombatMath.getRewards(wild: Wild, level: number, elite: boolean): { xp: number, cash: number, dropChance: number }
	local boost = if elite then wild.ELITE_REWARD_MULTIPLIER else 1
	return {
		xp = math.round(wild.XP_BASE * math.max(1, level) ^ wild.XP_EXPONENT) * boost,
		cash = math.round(wild.CASH_PER_LEVEL * math.max(1, level) * 100) / 100 * boost,
		dropChance = if elite then wild.ELITE_DROP_CHANCE else wild.DROP_CHANCE,
	}
end

return CombatMath
```

- [ ] **Step 6: Run tests** — Expected: all pass (previous 72 + 8 new).
- [ ] **Step 7: Commit** `git add src/shared tests && git commit -m "Combat and wild config, CombatMath"`

---

### Task 2: BattleSim (pure fight simulation)

**Files:**
- Create: `src/server/Util/BattleSim.luau`
- Test: `tests/BattleSim.spec.luau`; modify `tests/run.luau`

**Interfaces:**
- Consumes: CombatMath (Task 1), Config/Combat.
- Produces:
  - `type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string? }`
  - `type MonsterInput = { element: string, hp: number, atk: number, spd: number, elite: boolean }`
  - `type Event = { type: "attack" | "ability" | "faint" | "callin" | "run" | "end", from: string?, to: string?, damage: number?, heal: number?, strength: string?, dodged: boolean?, kind: string?, ok: boolean?, result: ("win" | "lose" | "run")? }`
  - `BattleSim.new(combat, leader: FighterInput, reserves: { FighterInput }, monster: MonsterInput, seed: number): State`
  - `BattleSim.step(state, dt: number): { Event }`
  - `BattleSim.callIn(state, id: string): (boolean, string?)`
  - `BattleSim.useAbility(state, id: string, which: "element" | "signature"): ({ Event }?, string?)`
  - `BattleSim.tryRun(state): { Event }`
  - `BattleSim.snapshot(state): Snapshot` — plain `{ time, result, monster = {hp, maxHp, element, elite}, fighters = { { id, hp, maxHp, element, abilityReady, signature?, signatureReady, fainted } }, reserves = { ids }, callInUntil, runReadyAt, runChance }`
  - Monster id is `"monster"`.

- [ ] **Step 1: Write the failing test** `tests/BattleSim.spec.luau`

```lua
--!strict
local BattleSim = require("../src/server/Util/BattleSim")
local combat = require("../src/shared/Config/Combat")
local expect = require("./lib/expect")

local function fighter(id: string, element: string, hp: number, atk: number, spd: number, signature: string?)
	return { id = id, element = element, hp = hp, atk = atk, spd = spd, signature = signature }
end

local function monster(element: string, hp: number, atk: number, spd: number, elite: boolean?)
	return { element = element, hp = hp, atk = atk, spd = spd, elite = elite == true }
end

-- Runs until the fight ends (or max seconds); returns the result and every event
local function runToEnd(state: any, maxSeconds: number?): (string?, { any })
	local all = {}
	local t = 0
	while not state.result and t < (maxSeconds or 300) do
		for _, event in BattleSim.step(state, 0.1) do
			table.insert(all, event)
		end
		t += 0.1
	end
	return state.result, all
end

local function count(events: { any }, predicate: (any) -> boolean): number
	local n = 0
	for _, event in events do
		if predicate(event) then
			n += 1
		end
	end
	return n
end

return {
	["strong party beats a weak monster"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 100, 2, 5), 1)
		local result, events = runToEnd(state)
		expect.equal(result, "win", "result")
		assert(count(events, function(e)
			return e.type == "end" and e.result == "win"
		end) == 1, "one end event")
	end,

	["weak party loses and faints"] = function()
		local state = BattleSim.new(combat, fighter("a", "Bloom", 30, 2, 5), {}, monster("Ember", 900, 20, 12), 2)
		local result, events = runToEnd(state)
		expect.equal(result, "lose", "result")
		assert(count(events, function(e)
			return e.type == "faint" and e.to == "a"
		end) == 1, "leader fainted")
	end,

	["same seed, same fight"] = function()
		local function play(seed: number): string
			local state = BattleSim.new(combat, fighter("a", "Tide", 120, 12, 10), {}, monster("Volt", 300, 8, 10), seed)
			local _, events = runToEnd(state)
			local parts = {}
			for _, e in events do
				table.insert(parts, `{e.type}:{e.damage or 0}`)
			end
			return table.concat(parts, ",")
		end
		expect.equal(play(7), play(7), "deterministic")
	end,

	["element multiplier applies to attacks"] = function()
		local strong = BattleSim.new(combat, fighter("a", "Ember", 500, 20, 10), {}, monster("Bloom", 5000, 1, 1), 3)
		local weak = BattleSim.new(combat, fighter("a", "Bloom", 500, 20, 10), {}, monster("Ember", 5000, 1, 1), 3)
		local _, se = runToEnd(strong, 10)
		local _, we = runToEnd(weak, 10)
		local function firstHit(events: { any }): any
			for _, e in events do
				if e.type == "attack" and e.from == "a" then
					return e
				end
			end
			return nil
		end
		local s, w = firstHit(se), firstHit(we)
		expect.equal(s.strength, "strong", "strong tag")
		expect.equal(w.strength, "weak", "weak tag")
		assert(s.damage > w.damage * 1.7, `strong {s.damage} vs weak {w.damage}`)
	end,

	["call in: only within the window, only once, only a reserve"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10), fighter("c", "Volt", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		expect.equal((BattleSim.callIn(state, "zzz")), false, "not a reserve")
		expect.equal((BattleSim.callIn(state, "b")), true, "first call-in")
		expect.equal((BattleSim.callIn(state, "c")), false, "only one")
		local late = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		for _ = 1, combat.CALL_IN_SECONDS * 10 + 1 do
			BattleSim.step(late, 0.1)
		end
		expect.equal((BattleSim.callIn(late, "b")), false, "window closed")
	end,

	["abilities: cooldown, Fireball hits hard, Wave heals"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Volt", 5000, 30, 10), 5)
		BattleSim.callIn(state, "b")
		local events = BattleSim.useAbility(state, "a", "element") :: { any }
		assert(events and events[1].damage >= 22, "Fireball ~2.5x ATK")
		local again, reason = BattleSim.useAbility(state, "a", "element")
		expect.isNil(again, "cooldown")
		expect.equal(reason, "cooldown", "reason")
		for _ = 1, 30 do
			BattleSim.step(state, 0.1)
		end
		local healEvents = BattleSim.useAbility(state, "b", "element") :: { any }
		assert(healEvents and (healEvents[1].heal or 0) > 0, "Wave heals")
		local none, why = BattleSim.useAbility(state, "a", "signature")
		expect.isNil(none, "no signature")
		expect.equal(why, "none", "reason none")
	end,

	["Curse weakens and Vine Snare slows the monster"] = function()
		local function monsterDamageIn(element: string, seconds: number): number
			local state = BattleSim.new(combat, fighter("a", element, 100000, 1, 10), {}, monster("Tide", 100000, 50, 10), 6)
			BattleSim.useAbility(state, "a", "element")
			local total = 0
			for _ = 1, seconds * 10 do
				for _, e in BattleSim.step(state, 0.1) do
					if e.type == "attack" and e.from == "monster" then
						total += e.damage
					end
				end
			end
			return total
		end
		local plain = monsterDamageIn("Ember", 4) -- Fireball: no effect on the monster
		assert(monsterDamageIn("Shade", 4) < plain, "Curse")
		assert(monsterDamageIn("Bloom", 4) < plain, "Snare")
	end,

	["Stampede stun skips monster attacks; Eclipse dodges"] = function()
		local stunned = BattleSim.new(combat, fighter("a", "Volt", 100000, 1, 10, "Thunderhorn"), {}, monster("Tide", 100000, 50, 20), 7)
		BattleSim.useAbility(stunned, "a", "signature")
		local hits = 0
		for _ = 1, 15 do
			for _, e in BattleSim.step(stunned, 0.1) do
				if e.type == "attack" and e.from == "monster" then
					hits += 1
				end
			end
		end
		expect.equal(hits, 0, "stunned 1.5 s")

		local dodger = BattleSim.new(combat, fighter("a", "Shade", 1000, 1, 10, "Eclipse Fox"), {}, monster("Tide", 100000, 50, 20), 8)
		BattleSim.useAbility(dodger, "a", "signature")
		local damage = 0
		for _ = 1, 25 do
			for _, e in BattleSim.step(dodger, 0.1) do
				if e.type == "attack" and e.from == "monster" then
					damage += e.damage
				end
			end
		end
		expect.equal(damage, 0, "dodged for 2.5 s")
	end,

	["failed run gives the monster a free hit and waits"] = function()
		-- Very slow leader vs fast monster: run chance at the floor (20%); seed chosen so the first roll fails
		local state = BattleSim.new(combat, fighter("a", "Ember", 1000, 1, 1), {}, monster("Tide", 100000, 20, 100), 9)
		local events = BattleSim.tryRun(state)
		local ran = false
		local freeHit = false
		for _, e in events do
			if e.type == "run" then
				ran = e.ok
			elseif e.type == "attack" and e.from == "monster" then
				freeHit = true
			end
		end
		if not ran then
			assert(freeHit, "free hit on failure")
			local retry = BattleSim.tryRun(state)
			expect.equal(retry[1].type, "run", "run event")
			expect.equal(retry[1].ok, false, "must wait")
			expect.equal(retry[1].kind, "wait", "wait reason")
		else
			expect.equal(state.result, "run", "ran away")
		end
	end,

	["fight times out as a run"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 1e9, 0, 1), {}, monster("Ember", 1e9, 0, 1), 10)
		local result = runToEnd(state, combat.MAX_FIGHT_SECONDS + 5)
		expect.equal(result, "run", "timeout")
	end,

	["nothing happens after the end"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 10, 1, 1), 11)
		runToEnd(state)
		expect.equal(#BattleSim.step(state, 0.1), 0, "no events")
		local none, reason = BattleSim.useAbility(state, "a", "element")
		expect.isNil(none, "no ability")
		expect.equal(reason, "ended", "reason")
	end,
}
```

Register: `BattleSim = require("./BattleSim.spec"),`

- [ ] **Step 2: Run tests** — Expected: FAIL (module not found).

- [ ] **Step 3: Write `src/server/Util/BattleSim.luau`**

It needs CombatMath from both Lune (string path) and Roblox (instance path), so the require checks for `game`
(nil in Lune):

```lua
--!strict
-- One wild fight, simulated on the server: up to 2 party fighters (leader + one call-in) vs 1 monster.
-- Pure (only CombatMath; no Roblox APIs) so tests/ run it in Lune. Seeded, so the same seed and inputs replay
-- the same fight. BattleService steps it at Combat.TICK_RATE and forwards the events to the player.
local CombatMath = if game ~= nil
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CombatMath")) :: any
	else require("../../shared/Util/CombatMath") :: any

local BattleSim = {}

export type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string? }
export type MonsterInput = { element: string, hp: number, atk: number, spd: number, elite: boolean }
export type Event = {
	type: string, -- "attack" | "ability" | "faint" | "callin" | "run" | "end"
	from: string?,
	to: string?,
	damage: number?,
	heal: number?,
	strength: string?,
	dodged: boolean?,
	kind: string?,
	ok: boolean?,
	result: string?,
}

type Fighter = {
	id: string,
	element: string,
	maxHp: number,
	hp: number,
	atk: number,
	spd: number,
	signature: string?,
	nextAttack: number,
	abilityReady: number,
	signatureReady: number,
	overcharge: number, -- fast attacks left
	dodgeUntil: number,
	fainted: boolean,
}

export type State = {
	combat: any,
	time: number,
	seed: number,
	fighters: { Fighter }, -- on the field
	reserves: { Fighter }, -- may be called in
	monster: Fighter & { elite: boolean, stunUntil: number, slowUntil: number, slow: number, curseUntil: number, curse: number, burnUntil: number, burnPerSecond: number, burnTick: number },
	shield: number, -- damage your side still absorbs (Tidal Shield)
	calledIn: boolean,
	runReadyAt: number,
	result: string?, -- "win" | "lose" | "run"
}

-- Small deterministic generator (LCG) so fights replay identically in Lune and Roblox
local function random(state: State): number
	state.seed = (state.seed * 1103515245 + 12345) % 2147483648
	return state.seed / 2147483648
end

local function makeFighter(combat: any, input: FighterInput, time: number): Fighter
	return {
		id = input.id,
		element = input.element,
		maxHp = input.hp,
		hp = input.hp,
		atk = input.atk,
		spd = input.spd,
		signature = input.signature,
		nextAttack = time + CombatMath.getAttackInterval(combat, input.spd),
		abilityReady = time,
		signatureReady = time,
		overcharge = 0,
		dodgeUntil = 0,
		fainted = false,
	}
end

function BattleSim.new(combat: any, leader: FighterInput, reserves: { FighterInput }, monster: MonsterInput, seed: number): State
	local state: any = {
		combat = combat,
		time = 0,
		seed = math.floor(math.abs(seed)) % 2147483648,
		fighters = { makeFighter(combat, leader, 0) },
		reserves = {},
		shield = 0,
		calledIn = false,
		runReadyAt = 0,
		result = nil,
	}
	for _, input in reserves do
		table.insert(state.reserves, makeFighter(combat, input, 0))
	end
	local m: any = makeFighter(combat, { id = "monster", element = monster.element, hp = monster.hp, atk = monster.atk, spd = monster.spd }, 0)
	m.elite = monster.elite
	m.stunUntil, m.slowUntil, m.slow, m.curseUntil, m.curse = 0, 0, 0, 0, 0
	m.burnUntil, m.burnPerSecond, m.burnTick = 0, 0, 0
	state.monster = m
	return state
end

local function find(list: { Fighter }, id: string): Fighter?
	for _, fighter in list do
		if fighter.id == id then
			return fighter
		end
	end
	return nil
end

local function standing(state: State): { Fighter }
	local list = {}
	for _, fighter in state.fighters do
		if not fighter.fainted then
			table.insert(list, fighter)
		end
	end
	return list
end

local function finish(state: State, result: string, events: { Event })
	state.result = result
	table.insert(events, { type = "end", result = result })
end

local function hitMonster(state: State, from: Fighter, multiplier: number, events: { Event }, kind: string?): number
	local monster = state.monster
	local elementMult, strength = CombatMath.getElementMultiplier(state.combat, from.element, monster.element)
	local damage = CombatMath.getDamage(state.combat, from.atk * multiplier, elementMult, random(state))
	monster.hp = math.max(0, monster.hp - damage)
	table.insert(events, { type = if kind then "ability" else "attack", kind = kind, from = from.id, to = "monster", damage = damage, strength = strength })
	if monster.hp <= 0 and not state.result then
		finish(state, "win", events)
	end
	return damage
end

-- The monster hits the standing fighter with the lowest share of its HP (ties: the leader, first in the list)
local function monsterAttack(state: State, events: { Event })
	local targets = standing(state)
	local target = targets[1]
	for _, fighter in targets do
		if fighter.hp / fighter.maxHp < target.hp / target.maxHp then
			target = fighter
		end
	end
	if not target then
		return
	end
	local monster = state.monster
	if state.time < target.dodgeUntil then
		table.insert(events, { type = "attack", from = "monster", to = target.id, damage = 0, dodged = true })
		return
	end
	local atk = monster.atk * (if state.time < monster.curseUntil then 1 - monster.curse else 1)
	local elementMult, strength = CombatMath.getElementMultiplier(state.combat, monster.element, target.element)
	local damage = CombatMath.getDamage(state.combat, atk, elementMult, random(state))
	local absorbed = math.min(state.shield, damage)
	state.shield -= absorbed
	local taken = damage - absorbed
	target.hp = math.max(0, target.hp - taken)
	table.insert(events, { type = "attack", from = "monster", to = target.id, damage = taken, strength = strength })
	if target.hp <= 0 then
		target.fainted = true
		table.insert(events, { type = "faint", to = target.id })
		if #standing(state) == 0 then
			finish(state, "lose", events)
		end
	end
end

local function monsterInterval(state: State): number
	local monster = state.monster
	local interval = CombatMath.getAttackInterval(state.combat, monster.spd)
	if state.time < monster.slowUntil then
		interval /= 1 - monster.slow
	end
	return interval
end

function BattleSim.step(state: State, dt: number): { Event }
	local events: { Event } = {}
	if state.result then
		return events
	end
	state.time += dt
	local combat = state.combat
	local monster = state.monster

	if monster.burnUntil > 0 and state.time <= monster.burnUntil + 1e-9 and state.time >= monster.burnTick then
		monster.burnTick += 1
		local damage = math.max(1, math.round(monster.burnPerSecond))
		monster.hp = math.max(0, monster.hp - damage)
		table.insert(events, { type = "ability", kind = "Burn", to = "monster", damage = damage })
		if monster.hp <= 0 then
			finish(state, "win", events)
			return events
		end
	end

	for _, fighter in standing(state) do
		if state.result then
			break
		end
		if state.time >= fighter.nextAttack then
			hitMonster(state, fighter, 1, events, nil)
			local interval = CombatMath.getAttackInterval(combat, fighter.spd)
			if fighter.overcharge > 0 then
				fighter.overcharge -= 1
				interval /= combat.ABILITIES.Volt.speed
			end
			fighter.nextAttack = state.time + interval
		end
	end

	if not state.result and state.time >= monster.nextAttack then
		if state.time >= monster.stunUntil then
			monsterAttack(state, events)
		end
		monster.nextAttack = state.time + monsterInterval(state)
	end

	if not state.result and state.time >= combat.MAX_FIGHT_SECONDS then
		finish(state, "run", events)
	end
	return events
end

function BattleSim.callIn(state: State, id: string): (boolean, string?)
	if state.result then
		return false, "ended"
	elseif state.calledIn or state.time > state.combat.CALL_IN_SECONDS then
		return false, "closed"
	end
	local fighter = find(state.reserves, id)
	if not fighter then
		return false, "missing"
	end
	state.calledIn = true
	fighter.nextAttack = state.time + CombatMath.getAttackInterval(state.combat, fighter.spd)
	table.insert(state.fighters, fighter)
	state.reserves = {}
	return true, nil
end

local function applyAbility(state: State, fighter: Fighter, ability: any, events: { Event })
	local monster = state.monster
	local kind = ability.kind
	if kind == "Fireball" or kind == "Supernova" then
		hitMonster(state, fighter, ability.power, events, kind)
	elseif kind == "Wave" then
		local healed = 0
		for _, ally in standing(state) do
			local amount = math.round(ally.maxHp * ability.heal)
			ally.hp = math.min(ally.maxHp, ally.hp + amount)
			healed += amount
		end
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, heal = healed })
	elseif kind == "Snare" then
		monster.slowUntil, monster.slow = state.time + ability.seconds, ability.slow
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "Overcharge" then
		fighter.overcharge = ability.attacks
		fighter.nextAttack = math.min(fighter.nextAttack, state.time + CombatMath.getAttackInterval(state.combat, fighter.spd) / ability.speed)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Curse" then
		monster.curseUntil, monster.curse = state.time + ability.seconds, ability.weaken
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "Inferno" then
		monster.burnUntil = state.time + ability.seconds
		monster.burnPerSecond = fighter.atk * ability.perSecond
		monster.burnTick = state.time + 1
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "TidalShield" then
		state.shield = math.round(fighter.maxHp * ability.shield)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Stampede" then
		hitMonster(state, fighter, ability.power, events, kind)
		monster.stunUntil = state.time + ability.stun
		monster.nextAttack = math.max(monster.nextAttack, monster.stunUntil)
	elseif kind == "Eclipse" then
		fighter.dodgeUntil = state.time + ability.seconds
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Devour" then
		local damage = hitMonster(state, fighter, ability.power, events, kind)
		fighter.hp = math.min(fighter.maxHp, fighter.hp + math.round(damage * ability.lifesteal))
	end
end

function BattleSim.useAbility(state: State, id: string, which: string): ({ Event }?, string?)
	if state.result then
		return nil, "ended"
	end
	local fighter = find(state.fighters, id)
	if not fighter or fighter.fainted then
		return nil, "missing"
	end
	local combat = state.combat
	local ability
	if which == "element" then
		ability = combat.ABILITIES[fighter.element]
		if not ability then
			return nil, "none"
		elseif state.time < fighter.abilityReady then
			return nil, "cooldown"
		end
		fighter.abilityReady = state.time + combat.ABILITY_COOLDOWN
	elseif which == "signature" then
		ability = if fighter.signature then combat.SIGNATURES[fighter.signature] else nil
		if not ability then
			return nil, "none"
		elseif state.time < fighter.signatureReady then
			return nil, "cooldown"
		end
		fighter.signatureReady = state.time + combat.SIGNATURE_COOLDOWN
	else
		return nil, "none"
	end
	local events: { Event } = {}
	applyAbility(state, fighter, ability, events)
	return events, nil
end

function BattleSim.getRunChance(state: State): number
	local leader = state.fighters[1]
	return CombatMath.getRunChance(state.combat, leader.spd, state.monster.spd, state.monster.elite)
end

function BattleSim.tryRun(state: State): { Event }
	local events: { Event } = {}
	if state.result then
		return events
	elseif state.time < state.runReadyAt then
		table.insert(events, { type = "run", ok = false, kind = "wait" })
		return events
	end
	if random(state) < BattleSim.getRunChance(state) then
		table.insert(events, { type = "run", ok = true })
		finish(state, "run", events)
	else
		state.runReadyAt = state.time + state.combat.RUN_RETRY_SECONDS
		table.insert(events, { type = "run", ok = false, kind = "failed" })
		monsterAttack(state, events) -- the price of a failed run
	end
	return events
end

-- Plain view for the client's fight bar
function BattleSim.snapshot(state: State): any
	local fighters = {}
	for _, fighter in state.fighters do
		table.insert(fighters, {
			id = fighter.id,
			hp = fighter.hp,
			maxHp = fighter.maxHp,
			element = fighter.element,
			abilityIn = math.max(0, fighter.abilityReady - state.time),
			signature = fighter.signature,
			signatureIn = math.max(0, fighter.signatureReady - state.time),
			fainted = fighter.fainted,
		})
	end
	local reserves = {}
	for _, fighter in state.reserves do
		table.insert(reserves, fighter.id)
	end
	return {
		time = state.time,
		result = state.result,
		monster = { hp = state.monster.hp, maxHp = state.monster.maxHp, element = state.monster.element, elite = state.monster.elite },
		fighters = fighters,
		reserves = reserves,
		callInFor = if state.calledIn then 0 else math.max(0, state.combat.CALL_IN_SECONDS - state.time),
		runIn = math.max(0, state.runReadyAt - state.time),
		runChance = BattleSim.getRunChance(state),
		shield = state.shield,
	}
end

return BattleSim
```


- [ ] **Step 4: Run tests** — Expected: all pass. If a numeric test is off because of tuning, adjust the test inputs (not the module), and ledger it.
- [ ] **Step 5: Commit** `git add src/server/Util/BattleSim.luau tests && git commit -m "BattleSim: seeded fight simulation"`

---

### Task 3: Schema v8 resting, fight locks

**Files:**
- Modify: `src/server/Util/Migrations.luau`, `src/shared/Config/Data.luau` (SCHEMA_VERSION 8), `src/server/Services/DataService.luau` (type `resting: { [string]: number }`, template `resting = {}`), `tests/Migrations.spec.luau`
- Modify: `src/server/Services/CardService.luau` (fighting flag), `PartyService.luau` (lock + hold + extra marker + GetParty), `JobService.luau`, `ShowcaseService.luau`, `CondenserService.luau` or `CardService.Condense` (refuse fighting)

**Interfaces:**
- Produces:
  - `CardService.SetFighting(player, beastId: string, fighting: boolean)`, `CardService.IsFighting(player, beastId): boolean`; `TakeBeast` and `Condense` refuse fighting cards; sync payload gains `fighting`.
  - `PartyService.GetParty(player): { slots: { [number]: string }, summoned: number? }?`
  - `PartyService.SetLocked(player, locked: boolean)` — while locked, `SetPartySlot` and `Summon` are refused with "You can't change your party during a fight."
  - `PartyService.SetHold(player, cframe: CFrame?)` — while set, the summoned marker stays at that CFrame (BattleService moves it per lunge); nil resumes following.
  - `PartyService.GetMarker(player): BasePart?`
  - `PartyService.CreateMarker(player, beastId: string, cframe: CFrame): BasePart?` — an extra creature marker (same attributes) in `workspace.Creatures`, caller destroys it.

- [ ] **Step 1: Failing migration test** in `tests/Migrations.spec.luau`:

```lua
	["v8: adds empty resting, keeps existing"] = function()
		local data: any = { version = 7, party = { slots = {} } }
		Migrations.run(data, 8)
		expect.equal(typeof(data.resting), "table", "resting added")
		expect.equal(next(data.resting), nil, "empty")
		local kept: any = { version = 7, resting = { abc = 123 } }
		Migrations.run(kept, 8)
		expect.equal(kept.resting.abc, 123, "kept")
	end,
```

- [ ] **Step 2: Run** — Expected: FAIL (`resting` nil).
- [ ] **Step 3: Migration `[7]`**:

```lua
	-- v8: fainted cards resting until a Unix time (battles)
	[7] = function(data)
		if typeof(data.resting) ~= "table" then
			data.resting = {}
		end
	end,
```

Bump `SCHEMA_VERSION = 8`; add `resting: { [string]: number }` to `PlayerData` and `resting = {}` to the template.

- [ ] **Step 4: CardService fighting flag**, mirroring `partied`: inventory gains `fighting: { [string]: boolean }` (runtime only), `SetFighting` / `IsFighting`, sync payload includes `fighting`, `TakeBeast` returns nil when `inventory.fighting[beastId]`, `Condense` returns `nil, "fighting"` when the main is a fighting beast. JobService assign and ShowcaseService display refuse with "That card is in a fight." (same place they check `IsPartied`). CondenserService maps reason `"fighting"` to "That card is in a fight."
- [ ] **Step 5: PartyService additions**: state gains `locked: boolean`, `hold: CFrame?`. `onSetSlot` and `onSummon` start with `if state.locked then notify(...); return end`. `moveMarkers` skips players whose `state.hold` is set after placing the marker at `state.hold`. Implement `GetParty`, `SetLocked`, `SetHold`, `GetMarker`, `CreateMarker` (extract the attribute-setting body of `refreshMarker` into `setMarkerAttributes(marker, player, beast)` and reuse it). Unload clears everything as now.
- [ ] **Step 6: Run** tests, syntax, build — Expected: all pass.
- [ ] **Step 7: Commit** "Schema v8 resting; fight locks in cards and party"

---

### Task 4: Shared creature visuals + monster drawing

**Files:**
- Create: `src/client/Util/CreatureVisuals.luau`, `src/client/Controllers/MonsterController.luau`
- Modify: `src/client/Controllers/CreatureController.luau` (use CreatureVisuals), `default.project.json` (`ReplicatedStorage.MonsterModels` → `assets/monsters`), `assets/monsters/.gitkeep`, `tests/CreatureAssets.spec.luau` (scan `assets/monsters` too), `src/client/init.client.luau`

**Interfaces:**
- Produces (CreatureVisuals):
  - `CreatureVisuals.strip(model: Model)`
  - `CreatureVisuals.prepare(model: Model, height: number, rigged: boolean): (BasePart, number)` — adds the bottom root, anchors, scales to `height`; returns root, scale.
  - `CreatureVisuals.getAnimator(model: Model): Animator?`
  - `CreatureVisuals.countParts(model: Instance): number`
  - `CreatureVisuals.makeTag(root: BasePart, height: number, color: Color3): TextLabel`
  - `CreatureVisuals.step(entry, dt, now, origin, motion, flying)` — the per-frame follow + pose + breathing used by both controllers; entry has `{ marker, model, root, baseScale, rigged, cframe, speed, walked, frame, tracks }`.
- Monster markers (from Task 5): `workspace.Monsters` parts with attributes `Species`, `Level`, `Elite`, `Element`, `Zone`, `MonsterId`, `Fighting` (bool).

- [ ] **Step 1:** Move `strip`, `countParts`, `findRigRoot`, `getAnimator`, `prepare` (generalised to take a height), `makeTag` and the motion part of `step` from CreatureController into CreatureVisuals unchanged in behaviour; CreatureController keeps glow, outlines, tags text and placeholder blob. Run syntax/build; Studio behaviour unchanged (refactor: no behaviour change).
- [ ] **Step 2:** Extend `tests/CreatureAssets.spec.luau`: the scan loops over `{ "assets/creatures", "assets/monsters" }`. Run tests: pass. Rojo mapping + `.gitkeep`.
- [ ] **Step 3:** MonsterController: watches `workspace.Monsters`; per marker builds `ReplicatedStorage.MonsterModels[Species]` (≤ MAX_MODEL_PARTS) or a placeholder by `shape` in the element colour:
  - slime: squashed ball + eyes; crab: wide box body + two claw blocks; bat: ball + two thin wings (flying);
  - beetle: half-ball shell + head; golem: stacked blocks; wolf: long box body + head + ears.
  Height `MONSTER_HEIGHT × (ELITE_SIZE if elite)`. Tag "Mossling · Lv 3" (gold and "ELITE" prefix for elites). Motion via `CreatureVisuals.step` (flyers from `Wild.FLYING`). When `Fighting` is true the tag shows "⚔". Cleanup on removal.
- [ ] **Step 4:** Register MonsterController in init.client. Build, syntax, tests, sourcemap.
- [ ] **Step 5: Commit** "Monster drawing and shared creature visuals"

---

### Task 5: WildService (map, portals, spring, monsters)

**Files:**
- Create: `src/server/Services/WildService.luau`
- Modify: `src/shared/Remotes.luau` (`WildTravel`), `src/server/init.server.luau` (start after PartyService, before BattleService)

**Interfaces:**
- Consumes: Config/Wild, CombatMath.getMonsterStats.
- Produces:
  - `type Monster = { id: string, species: string, level: number, elite: boolean, element: string, zone: number, home: Vector3, marker: Part, fightingPlayer: Player?, chasing: Player?, alive: boolean }`
  - `WildService.GetMonster(id: string): Monster?`
  - `WildService.Lock(monster, player)`, `WildService.Unlock(monster)`
  - `WildService.Defeat(monster)` (despawn, schedule respawn)
  - `WildService.SetFightPose(monster, cframe: CFrame?)` (hold marker in the ring)
  - `WildService.OnContact(callback: (player: Player, monster: Monster) -> ())` (a chasing monster reached a player)
  - `WildService.TravelToWild(player)`, `WildService.TravelHome(player)`, `WildService.IsInWild(player): boolean`
  - `WildService.GetSpringPosition(): Vector3`
  - Remote `WildTravel` client → server `(where: "wild" | "home")`, server → client `(where)` after a move.

- [ ] **Step 1:** Build the placeholder map under `workspace.Wild` on Start: entrance pad at `ORIGIN + ENTRANCE_OFFSET` with a "Return to shop" portal (ProximityPrompt "Return"), three zone floors (size ZONE_SIZE, colour from config, gap paths), a sign per zone ("Meadow · Recommended Lv 1+"), 8 tagged `WildSpawn` parts per zone (CollectionService tag `WildSpawn`, attribute `Zone` = index) spread on a ring, a few part trees/rocks. If `ServerStorage` or `ReplicatedStorage` holds a `WildMap` model (later art), use it instead and read its `WildSpawn` tags.
- [ ] **Step 2:** Plaza portal part at `PLAZA_PORTAL` (neon ring + "Wild" sign + ProximityPrompt "Travel"), spring at `SPRING` (blue neon pool, ParticleEmitter, sign "Healing Spring"). Both prompts call travel. Travel moves the character (`PivotTo` to arrival + 3 studs up), `PartyService` marker follows by itself (teleport distance). `TravelHome` uses the player's plot spawn (`PlotService.GetPlot(player).spawn`) or the plaza. Fire `WildTravel` to the client after each move. Rate-limit 1 s.
- [ ] **Step 3:** Monsters: per spawn point one monster; level random in zone range; elite by `ELITE_CHANCE`; marker attributes as listed. A Heartbeat loop at `MARKER_RATE`: monsters with no player within `WAKE_RADIUS` don't move. Awake, unlocked monsters wander (random point within WANDER_RADIUS of home at WANDER_SPEED). Aggro monsters (elite, or zone.aggro) chase the nearest player within AGGRO_RADIUS at CHASE_SPEED, give up beyond CHASE_GIVE_UP from home; within CONTACT_DISTANCE call the OnContact callbacks once, then return home (the callback decides whether a fight starts). Markers ground-raycast like creature markers.
- [ ] **Step 4:** Fight prompts are client-side (Task 7); the server validates distance on StartFight.
- [ ] **Step 5:** Build, syntax, tests. **Commit** "WildService: wild map, portals, spring and monsters"

---

### Task 6: BattleService

**Files:**
- Create: `src/server/Services/BattleService.luau`
- Modify: `src/shared/Remotes.luau` (`StartFight`, `CallIn`, `UseAbility`, `RunFight`, `BattleStarted`, `BattleEvent`, `BattleEnded`, `RestChanged`), `src/server/init.server.luau` (start after WildService), `src/server/Services/DevService.luau` (`/wild`, `/rest`, `/elite`)

**Interfaces:**
- Consumes: BattleSim (Task 2), CardService fighting/AddXP/AddFresh, PartyService GetParty/SetLocked/SetHold/GetMarker/CreateMarker, WildService, EconomyService.AddCash, CombatMath.getRewards/splitXp, DataService.Register.
- Produces:
  - `BattleService.IsFighting(player): boolean`
  - `BattleService.IsResting(player, beastId): boolean`
  - Remotes: `StartFight(monsterId: string)`, `CallIn(beastId: string)`, `UseAbility(fighterId: string, which: "element" | "signature")`, `RunFight()`; server → client `BattleStarted({ monsterId, species, level, elite, snapshot, names = { [id] = cardName } })`, `BattleEvent({ events, snapshot })`, `BattleEnded({ result, xpEach?, cash?, card? = { cardId, foil, grade }, rested? = { beastId } })`, `RestChanged({ { beastId, until } })`.

- [ ] **Step 1: Data**: `load` reads `data.resting`, keeps entries whose key is a beast the player owns and whose value is a finite number > now, clamps values to `now + REST_SECONDS`; `save` writes them back (plain table); `unload` ends any fight as a run first (register after PartyService so unload runs before PartyService's). Send `RestChanged` after load.
- [ ] **Step 2: StartFight** validation, in order: rate limit; `typeof(monsterId) == "string"`; not already fighting; monster exists, alive, not locked; player character within `FIGHT_RANGE` of the monster marker; party has a summoned card that is not resting (else notify "Your creature is resting. Summon a rested one or visit the plaza spring."). Then: lock monster, `PartyService.SetLocked(true)`, `CardService.SetFighting` for the leader (and later the call-in), build `FighterInput` from `BeastRules.getStats` with `signature = card.name if Combat.SIGNATURES[card.name]`, reserves = other party cards that exist and aren't resting, monster input from `CombatMath.getMonsterStats`; seed `Random.new():NextInteger(1, 2^30)`. Anchor the player (`HumanoidRootPart.Anchored = true`) so they can't walk off. Place ring: monster at marker position, leader at `RING_RADIUS` toward the player (`SetFightPose`, `SetHold`). Fire `BattleStarted`.
- [ ] **Step 3: Loop**: one Heartbeat accumulator at `TICK_RATE` steps every fight; for `attack` events from a fighter nudge its marker `LUNGE_STUDS` toward the target for 0.15 s; `faint` sets marker attribute `Fainted = true`; send `BattleEvent` with the events and snapshot when there are events (and once a second otherwise for timers).
- [ ] **Step 4: CallIn / UseAbility / RunFight**: validate types, that the player is fighting, ids belong to the fight; forward to BattleSim; CallIn creates an extra marker with `PartyService.CreateMarker` at the ring and sets the card fighting.
- [ ] **Step 5: End**: unlock monster (Defeat on win), un-anchor player, `SetHold(nil)`, `SetLocked(false)`, clear fighting flags, destroy the extra marker, clear `Fainted`. Win: rewards via `getRewards`; `splitXp(xp, #partyCards)` to each of the 3 party cards with `CardService.AddXP(player, beastId, each)`; `EconomyService.AddCash`; drop roll → zone element card by `DROP_RARITY` weights among `Cards.List` with that element and rarity (fallback: any rarity of that element), grade via `BeastRules.rollGrade(rng:NextNumber())`, `CardService.AddFresh`. Lose: every fainted fighter rests `now + REST_SECONDS`. Fire `BattleEnded`, `RestChanged`.
- [ ] **Step 6: Edge cases**: player removing (unload), character died/reset (`Humanoid.Died`), summoned card gone, marker missing → end as "run" with no rewards. `WildService.OnContact` → start a fight only if not fighting, has a rested summoned card; otherwise ignore.
- [ ] **Step 7: Spring**: every second, for each player whose character is within `SPRING_RADIUS` of the spring, subtract `SPRING_SPEED − 1` seconds from each resting entry; send `RestChanged` (with a `nearSpring` flag) when it changes.
- [ ] **Step 8: DevService**: `/wild` → `WildService.TravelToWild`; `/rest` → clear the player's resting; `/elite` → spawn an elite monster of the player's leader level next to them (a `WildService.SpawnAt(position, species, level, elite)` helper).
- [ ] **Step 9:** Build, syntax, tests. **Commit** "BattleService: fights, rewards, resting and the spring"

---

### Task 7: Client battle UI, fight prompts, travel button, resting timers

**Files:**
- Create: `src/client/Controllers/BattleController.luau`
- Modify: `src/client/Controllers/PartyBarController.luau`, `PartyController.luau` (resting timers, "Healing faster"), `src/client/init.client.luau`

**Interfaces:**
- Consumes: remotes from Task 6, `WildTravel`, monster markers.

- [ ] **Step 1: Fight prompts**: for each monster marker (not fighting), a client ProximityPrompt "Fight" (`ObjectText` "Mossling · Lv 3", MaxActivationDistance `PROMPT_DISTANCE`) firing `StartFight(MonsterId)`; hidden while fighting.
- [ ] **Step 2: Shop button**: while in the wild (after `WildTravel("wild")`), a HUD button "Shop" at the top of the middle-left stack (`0.5, -196`, 96×50) firing `WildTravel("home")`; hidden at home.
- [ ] **Step 3: Fight bar** (bottom centre, width min(560, 92%), ZIndex above HUD): monster row (name, Lv, element icon, HP bar, ELITE chip), fighter cards (face via CardFace small, HP bar, element ability button with name and cooldown sweep, signature button if any), call-in buttons with countdown (one per reserve; first 5 s), Run button "Run 62%" (disabled with countdown after a failure). Every button ≥ 48 px. While fighting hide `PartyBar`, HUD buttons (`PartyButton`, `JobsButton`, `BinderButton`, `BuildButton`, prices) and close open panels.
- [ ] **Step 4: World feedback**: floating damage numbers above the target marker (BillboardGui, 0.8 s rise and fade): white normal, orange "STRONG!", grey weak, "Dodge", green "+N" heals; ability name pop over the fighter.
- [ ] **Step 5: End screen** (4 s): Win "Victory!" with "+N XP each" and the 3 party card names, "+$X", and a card face if a card dropped; Loss "Your party fainted" with "Rest 3:00 · the plaza spring heals faster"; Run "Got away safely".
- [ ] **Step 6: Resting timers**: PartyBarController shows "😴 2:41" over resting slots (from `RestChanged`), PartyController rows show "Resting 2:41" and "Healing faster" when near the spring; summoning a resting card is allowed (it follows) but the fight prompt refuses (server message).
- [ ] **Step 7:** Build, syntax, tests, sourcemap. **Commit** "Fight bar, fight prompts, wild travel and resting timers"

---

### Task 8: Docs

- [ ] DESIGN.md: 5.8 step 5 "Battles part 1 (combat core + server wild map; built, awaiting Studio test)", roadmap note for parts 2–3 (PvP, Frontier + bosses), combat rules and wild tables (from the spec), 10.2 tree (new files, `assets/monsters`), 10.4 v8 `resting`, schema history. CLAUDE.md: test list, `assets/monsters` mapping, dev commands `/wild`, `/rest`, `/elite`. `docs/creatures.md`: monster models section.
- [ ] Commit "Document battles part 1". Studio test list: spec section 8.
