# You in the fight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In every boss fight the player fights with a Blender-animated sword beside one summoned creature, the boss
attacks the player with dodgeable attacks (closing-ring warnings), and losing sends the player home after a 3-2-1.

**Architecture:** The player joins the existing pure, seeded fight sim (`server/Util/BattleSim.luau`) as a new
**player fighter** (`player = true`): never auto-attacks, never targeted by auto-attacks, goes **down** instead of
fainting, and takes boss hits as a share of a flat 100 HP. The boss's attacks on players (quick hit, big ring attack)
are scheduled inside the sim as pending hits; ring geometry is checked by BattleService through a resolver the sim
calls when a ring lands. Sword timing and geometry live in two new pure modules (`SwordRules`, `RingRules`). The
server validates intents (attack, skill, dodge) and feeds hits into the sim; clients draw everything (sword on the
back, anime-slash HUD, rings, hit effects) from attributes and fight events.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Blender 5.2 through the Blender
MCP (animations, sword model, effect frames), Roblox Studio MCP (Play checks, screenshots).

**Spec:** `docs/superpowers/specs/2026-11-02-you-in-the-fight-design.md`

## Global Constraints

- Read `DESIGN.md` first; update it in the same change when a rule, number or file changes. Tick the system in
  DESIGN.md only after the user confirms it works in Studio.
- Server authoritative: clients send intents only. Every remote is defined in `src/shared/Remotes.luau`, validates arg
  types/ranges, ownership and distance, and is rate-limited with `src/server/Util/RateLimiter.luau`.
- All tunable numbers live in `src/shared/Config`. No magic numbers in services or controllers.
- Pure logic goes in Roblox-free modules with Lune tests; pure modules don't require siblings (BattleSim's existing
  `if game ~= nil` require pattern is the only exception); geometry uses plain numbers (Lune has no Vector3).
- Every new spec file is added to `tests/run.luau` and to the Lune test list in `CLAUDE.md`. `SourceOrder.spec` must
  stay green (no local used above its definition, no module used without a require).
- `--!strict` and type annotations; match the surrounding comment density and naming.
- UI: built in code with `Util/UIKit` and `Util/Hud`; tap targets ≥ 48 px; clear of the thumbstick and jump button;
  text plain ASCII plus `·` and emoji; fonts via `Util/FontStyle`. Check landscape phone in the Device emulator.
- Saved data: `SCHEMA_VERSION` bump + migration with a Lune test + types/template + DESIGN.md 10.4 for any shape change.
- Studio MCP: reading the place is fine anytime; **ask before changing the place itself**. Scripts live only in the repo.
- Never print the Meshy API key. Before committing any `.blend`: scene `blendermcp_*key*` / `*secret*` fields empty
  (print lengths only, Blender 5: `scene.bl_system_properties_get()`); delete raw `*_Src` objects and purge orphans.
- Show the user a mockup, render or GIF for **every visual decision** (sword model, each animation, effects, icons,
  ring look in game) before it is final.
- Leave the untracked files in `git status` alone (`.playwright-mcp/`, `assets/blender/*_prev/`, sheet images, etc.).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work on branch `you-in-the-fight`.
- Exact spec values: `Combat.REST_SECONDS = 300`; player HP 100; down 5 s, back up at half HP while one of your
  creatures stands; boss targets a player 1 in 3 attacks; loss countdown "Teleporting back to town in 3, 2, 1"; dodge
  ≈0.35 s untouchable, ≈1 s cooldown; sheath after 4 s; starter sword at shop level 3; sword skill cooldown ≈8 s;
  big-attack ladder (every / warning / big / quick): 10/1.4/30%/10%, 9/1.3/35%/12%, 8/1.2/40%/14%, 7/1.1/45%/15%,
  6.5/1.0/50%/17%, 6/1.0/55%/18%, 5/0.9/60%/20% (+ sometimes two rings) for bosses 1-7 in `Bosses.LADDER` order.
- Win-rate targets (solo, balance tool): fights well 85% at 1× / 50% at 0.8×; stands still 60% at 1× / 15% at 0.8×.

## Review Focus

1. **A player who leaves, resets or dies while down** must withdraw their player fighter with their creatures; the
   fight goes on for the others and ends as today when nobody is left. (Task 3 test `withdraw takes the player fighter
   out too`.)
2. **Latency on dodges and rings:** a dodge pressed at the last moment on the client arrives up to ~0.15 s late; the
   server lands every pending hit `Combat.HIT_GRACE` after the client shows it, so it still counts. (Task 4 test
   `a dodge inside the grace still avoids the hit`.)
3. **Tap spam / remote flooding on Attack:** taps inside a cut's lock never start extra cuts; one buffered tap after
   the cut's hit moment queues exactly the next cut. (Task 2 test `taps during a cut start nothing extra`.)
4. **The boss falls while rings or quick hits are pending:** nothing lands after the fight's result. (Task 4 test
   `pending hits never land after the end`.)
5. **The player goes down in the same step the last creature faints:** the fight ends as a loss, never stuck with a
   down player waiting to get up. (Task 3 test `down with no creature left ends the fight`.)

---

### Task 1: Config: rest time, player numbers, the boss attack ladder, the starter sword

**Files:**
- Modify: `src/shared/Config/Combat.luau`
- Modify: `src/shared/Config/Bosses.luau` (type `Boss`, every boss in `BOSSES`, top-level constants)
- Create: `src/shared/Config/Swords.luau`
- Test: `tests/SwordsConfig.spec.luau` (new; add to `tests/run.luau`)

**Interfaces:**
- Produces (Combat): `REST_SECONDS = 300`, `PLAYER_HP = 100`, `DOWN_SECONDS = 5`, `GET_UP_SHARE = 0.5`,
  `PLAYER_TARGET_SHARE = 1 / 3`, `QUICK_WARNING = 0.5` (boss flash before a quick hit), `HIT_GRACE = 0.15`,
  `DODGE_SECONDS = 0.35`, `DODGE_COOLDOWN = 1`, `DODGE_STUDS = 12`, `LOSS_COUNTDOWN = 3`,
  `SWORD_ACTION_COOLDOWN = 0.08` (remote limiter), `SWORD_IDLE_ATK = 10` (sword ATK when the player never had a creature
  on the field; practically unused, keeps the sim total).
- Produces (Bosses): type `PlayerAttacks = { every: number, warning: number, big: number, quick: number, doubleChance: number? }`;
  field `playerAttacks: PlayerAttacks` on every boss; constants `RING_SLAM_RADIUS = 7`, `RING_SWIPE_EXTRA = 8` (swipe
  length = the boss's ring radius + this), `RING_SWIPE_HALF_ANGLE = 35` (degrees), `HIT_RADIUS_SHARE = 0.6` (a boss's
  sword-hit radius = its ring radius × this), `ADD_HIT_RADIUS = 3`.
- Produces (Swords): `STARTER = "starterSword"`, `UNLOCK_SHOP_LEVEL = 3`, `SHEATH_SECONDS = 4`, `COMBO_RESET = 0.9`,
  `SOFT_AIM_RANGE = 14`, `SOFT_AIM_ANGLE = 75`, `PLAYER_DAMAGE_COLOR = { 255, 214, 92 }`, and
  `SWORDS: { [string]: Sword }` with type
  `Sword = { name: string, power: number, element: string?, combo: { Cut }, skill: Skill, animations: { [string]: string }, sounds: { [string]: string } }`,
  `Cut = { power: number, hitAt: number, length: number, reach: number, arc: number }`,
  `Skill = { power: number, hitAt: number, length: number, radius: number, cooldown: number }`.
  Animation keys: `draw, sheath, cut1, cut2, cut3, skill, dodge, flinch, down, getUp, ready, run` (values `""` until
  published, Task 9). Sound keys: `swing1, swing2, swing3, hit, draw, dodge, ring, down, getUp` (`""` until Task 13).

- [ ] **Step 1: Write the failing test** `tests/SwordsConfig.spec.luau`:

```lua
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Swords = require("../src/shared/Config/Swords")
local expect = require("./lib/expect")

return {
	["rest takes five minutes"] = function()
		expect.equal(Combat.REST_SECONDS, 300)
	end,
	["every ladder boss attacks players, harder up the ladder"] = function()
		local want = { { 10, 1.4, 0.30, 0.10 }, { 9, 1.3, 0.35, 0.12 }, { 8, 1.2, 0.40, 0.14 }, { 7, 1.1, 0.45, 0.15 },
			{ 6.5, 1.0, 0.50, 0.17 }, { 6, 1.0, 0.55, 0.18 }, { 5, 0.9, 0.60, 0.20 } }
		for index, bossId in Bosses.LADDER do
			local attacks = Bosses.BOSSES[bossId].playerAttacks
			expect.equal(attacks.every, want[index][1], `{bossId} every`)
			expect.equal(attacks.warning, want[index][2], `{bossId} warning`)
			expect.near(attacks.big, want[index][3], 1e-9, `{bossId} big`)
			expect.near(attacks.quick, want[index][4], 1e-9, `{bossId} quick`)
		end
		expect.equal((Bosses.BOSSES.prismHydra.playerAttacks.doubleChance or 0) > 0, true, "the Hydra sometimes rings twice")
	end,
	["the starter sword has three cuts, a skill and every animation key"] = function()
		local sword = Swords.SWORDS[Swords.STARTER]
		expect.equal(#sword.combo, 3)
		expect.equal(sword.skill.cooldown, 8)
		for _, key in { "draw", "sheath", "cut1", "cut2", "cut3", "skill", "dodge", "flinch", "down", "getUp", "ready", "run" } do
			expect.equal(typeof(sword.animations[key]), "string", key)
		end
	end,
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL in SwordsConfig (`REST_SECONDS` is 180; `Config/Swords` missing).

- [ ] **Step 3: Implement the config**

Combat: change `REST_SECONDS` to 300 and add the player block above (comments in the file's style). Bosses: add the
`PlayerAttacks` type and field (the ladder values above; `prismHydra.playerAttacks.doubleChance = 0.35`), the ring and
hit-radius constants, and return them from the module's table. Swords: the starter sword
`{ name = "Steel Sword", power = 1, combo = { { power = 0.35, hitAt = 0.28, length = 0.56, reach = 9, arc = 70 },
{ power = 0.35, hitAt = 0.2, length = 0.5, reach = 9, arc = 90 }, { power = 0.6, hitAt = 0.35, length = 0.75, reach = 10, arc = 60 } },
skill = { power = 0.9, hitAt = 0.3, length = 0.8, radius = 11, cooldown = 8 } }` (starting numbers; Task 5 tunes
power). Plain data only.

- [ ] **Step 4: Run tests to verify they pass**

Run: `lune run tests/run`
Expected: all specs PASS (the old count + 3).

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config/Combat.luau src/shared/Config/Bosses.luau src/shared/Config/Swords.luau tests/SwordsConfig.spec.luau tests/run.luau
git commit -m "Combat: 5-minute rest, player and boss-attack config, starter sword data"
```

---

### Task 2: SwordRules and RingRules (pure)

**Files:**
- Create: `src/shared/Util/SwordRules.luau`
- Create: `src/shared/Util/RingRules.luau`
- Test: `tests/SwordRules.spec.luau`, `tests/RingRules.spec.luau` (add both to `tests/run.luau`)

**Interfaces:**
- Consumes: `Swords.Cut`, `Swords.Skill` shapes (Task 1), passed in as plain tables.
- Produces (SwordRules, no requires):
  - `SwordRules.nextCut(combo: { Cut }, last: { index: number, startedAt: number }?, now: number, comboReset: number): (number?, number?)`
    returns the cut index that may start and the time it starts (`now`, or the current cut's end when the tap is
    buffered), or `nil` when the tap is ignored. Rules: no current cut → cut 1 at `now`; a tap before the current cut's
    `hitAt` → nil; a tap at or after `hitAt` and before `length + comboReset` → the next cut (wrapping 3 → 1) at
    `max(now, startedAt + length)`; later → cut 1 at `now`.
  - `SwordRules.inReach(px: number, pz: number, lookX: number, lookZ: number, tx: number, tz: number, targetRadius: number, reach: number, arcDegrees: number): boolean`
    (distance to the target's edge ≤ reach and the target's centre within `arc / 2` of the look direction; a target
    whose edge you stand inside always counts).
  - `SwordRules.inRadius(px: number, pz: number, tx: number, tz: number, targetRadius: number, radius: number): boolean`
  - `SwordRules.aimTarget(px: number, pz: number, lookX: number, lookZ: number, targets: { { id: string, x: number, z: number, radius: number } }, range: number, angleDegrees: number): string?`
    (the nearest target whose edge is within `range` and whose centre is within `angle` of the look; soft aim).
  - `SwordRules.comboPowerPerSecond(combo: { Cut }): number` (sum of powers / sum of lengths).
- Produces (RingRules, no requires):
  - `RingRules.inSlam(cx: number, cz: number, radius: number, px: number, pz: number): boolean`
  - `RingRules.inSwipe(ox: number, oz: number, dirX: number, dirZ: number, length: number, halfAngleDegrees: number, px: number, pz: number): boolean`
  - `RingRules.closingScale(elapsed: number, warning: number): number` — 1.9 at 0, 1.0 at `warning`, linear, clamped.

- [ ] **Step 1: Write the failing tests**

`tests/SwordRules.spec.luau` (cases with these exact assertions):

```lua
local SwordRules = require("../src/shared/Util/SwordRules")
local expect = require("./lib/expect")
local COMBO = { { power = 0.35, hitAt = 0.28, length = 0.56, reach = 9, arc = 70 },
	{ power = 0.35, hitAt = 0.2, length = 0.5, reach = 9, arc = 90 },
	{ power = 0.6, hitAt = 0.35, length = 0.75, reach = 10, arc = 60 } }

return {
	["the first tap starts cut 1 now"] = function()
		local index, at = SwordRules.nextCut(COMBO, nil, 5, 0.9)
		expect.equal(index, 1); expect.equal(at, 5)
	end,
	["taps during a cut start nothing extra"] = function()
		expect.isNil(SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.1, 0.9))
		expect.isNil(SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.27, 0.9))
	end,
	["a tap after the hit queues the next cut at the end of this one"] = function()
		local index, at = SwordRules.nextCut(COMBO, { index = 1, startedAt = 5 }, 5.3, 0.9)
		expect.equal(index, 2); expect.near(at :: number, 5.56, 1e-9)
	end,
	["cut 3 wraps to cut 1"] = function()
		expect.equal((SwordRules.nextCut(COMBO, { index = 3, startedAt = 0 }, 0.8, 0.9)), 1)
	end,
	["a late tap restarts the combo"] = function()
		local index, at = SwordRules.nextCut(COMBO, { index = 2, startedAt = 0 }, 2, 0.9)
		expect.equal(index, 1); expect.equal(at, 2)
	end,
	["reach counts from the target's edge, inside the arc"] = function()
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 0, -14, 6, 9, 70), true)
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 0, -16, 6, 9, 70), false)
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 10, 0, 6, 9, 70), false, "behind the arc")
		expect.equal(SwordRules.inReach(0, 0, 0, -1, 3, 0, 6, 9, 70), true, "standing inside its edge")
	end,
	["soft aim picks the nearest target in front"] = function()
		local targets = { { id = "b:m", x = 0, z = -20, radius = 9 }, { id = "b:add1", x = 0, z = -8, radius = 3 }, { id = "b:add2", x = 0, z = 8, radius = 3 } }
		expect.equal(SwordRules.aimTarget(0, 0, 0, -1, targets, 14, 75), "b:add1")
		expect.isNil(SwordRules.aimTarget(0, 0, 0, 1, { targets[1] }, 14, 75))
	end,
	["the starter combo out-damages a reference creature by 1.0-1.6x"] = function()
		local ratio = SwordRules.comboPowerPerSecond(COMBO) / (1 / 2) -- a SPD 10 creature: 1 ATK every 2 s
		expect.equal(ratio >= 1 and ratio <= 1.6, true, `ratio {ratio}`)
	end,
}
```

`tests/RingRules.spec.luau`: `inSlam(0, 0, 7, 0, 6.9) == true`, `inSlam(0, 0, 7, 0, 7.1) == false`; `inSwipe` from
(0, 0) toward (0, -1), length 20, half angle 35: (0, -10) true, (5, -10) true (26.6°), (8, -10) false (38.7°),
(0, -21) false, (0, 5) false; `closingScale(0, 1.2) == 1.9`, `closingScale(0.6, 1.2) ≈ 1.45`, `closingScale(2, 1.2) == 1`.

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run`
Expected: FAIL (`SwordRules`/`RingRules` not found).

- [ ] **Step 3: Implement both modules** with the signatures above (plain maths; `math.atan2`-free dot products with
  `math.cos(math.rad(arc / 2))`; a zero-length look or direction counts as no arc check failing safe = false).

- [ ] **Step 4: Run tests to verify they pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Util/SwordRules.luau src/shared/Util/RingRules.luau tests/SwordRules.spec.luau tests/RingRules.spec.luau tests/run.luau
git commit -m "SwordRules and RingRules: combo timing, reach, soft aim, ring shapes"
```

---

### Task 3: BattleSim: the player fighter, going down, getting up, losing

**Files:**
- Modify: `src/server/Util/BattleSim.luau`
- Test: `tests/BattleSim.spec.luau` (new cases)

**Interfaces:**
- Consumes: `Combat.PLAYER_HP`, `DOWN_SECONDS`, `GET_UP_SHARE`, `DODGE_SECONDS`, `DODGE_COOLDOWN`, `SWORD_IDLE_ATK` (Task 1).
- Produces:
  - `FighterInput.player: boolean?` — a player fighter. Callers pass `{ id = "@" .. owner, player = true, owner = owner, element = "None", hp = Combat.PLAYER_HP, atk = 0, spd = 10 }`; its sim id is `"a:@<owner>"`.
  - `SideInput.callIn: boolean?` — `false` closes the call-in window (boss fights): `callIn` refuses and `swap` never
    turns into a call-in; nil keeps today's behaviour.
  - `BattleSim._hurtPlayer(state: State, id: string, amount: number): { Event }` — damage a player fighter directly
    (the same path the boss's hits use). A seam for Lune tests and the balance tool only; services never call it.
  - Event types: `"down"` (to = player id), `"getUp"` (to, heal = HP back), `"out"` (to: down for good, no creature left), `"dodge"` (from = player id).
  - `BattleSim.swordHit(state: State, owner: string, targetId: string, power: number, kind: string): ({ Event }?, string?)`
    — one hit from `owner`'s player fighter on `targetId` (side B, standing): damage from the ATK of the owner's
    first standing creature on the field (else the last one that stood; else `SWORD_IDLE_ATK`) × `power`, through the
    usual `hit()` (element "None" is neutral; adds' guard and the boss's shield apply), credited to the player fighter
    (`dealt`). Event `{ type = "attack", kind = kind, from = "a:@<owner>", to, damage }` (kind `"Sword"` or `"Skill"`).
    Errors: `"ended"`, `"missing"` (no player fighter), `"down"`, `"target"`.
  - `BattleSim.dodge(state: State, owner: string): ({ Event }?, string?)` — `dodgeUntil = time + DODGE_SECONDS`,
    `dodgeReady = time + DODGE_COOLDOWN`; errors `"ended"`, `"missing"`, `"down"`, `"cooldown"`.
  - Snapshot fighter views add `player: boolean`, `down: boolean`, `downIn: number` (seconds until back up, 0 if up or out), `out: boolean`.

Rules (each needs a test):
- Player fighters never auto-attack, are never picked by `targetOf` (auto-attacks or abilities), are not stunned by a
  thunderclap, not healed by Wave, and their hits are not absorbed by their side's Tidal Shield.
- At 0 HP a player fighter goes **down** (not fainted): `downUntil = time + DOWN_SECONDS`. When `downUntil` passes and
  one of the owner's creatures stands, it gets up with `maxHp × GET_UP_SHARE` (event `getUp`). If none stands when it
  would get up, it stays down: event `out` once; it is never targeted again.
- `standing(side)` counts up players and standing creatures; a side with nobody standing loses (as today). A player
  alone (creatures fainted, no reserves left) keeps fighting.
- `hpLeft`, `getFainted` and the Dungeon carry ignore player fighters. `withdraw(owner)` takes the player fighter out
  too. `contribution` counts its `dealt` and `taken`.

- [ ] **Step 1: Write the failing tests** (add a helper `bossFightWithPlayer(seed, foeAtk, playerHp?)`: side A
  `{ owned("p1","1"), player fighter for "1" }`, reserves `{ owned("r1","1") }`, `swapSeconds = 10`, `callIn = false`;
  side B one boss `{ boss = true, hp = 100000, atk = foeAtk, spd = 10 }` without `playerAttacks`):

```lua
["boss auto-attacks never pick the player"] = function()
	local state = bossFightWithPlayer(1, 30)
	local _, events = runToEnd(state, 20)
	expect.equal(count(events, function(e) return e.type == "attack" and e.to == "a:@1" end), 0)
end,
["no call-in when callIn is false"] = function()
	local state = bossFightWithPlayer(2, 1)
	expect.equal(BattleSim.callIn(state, "a:r1", "1"), false)
	local events = BattleSim.swap(state, "a:r1", "1") :: { any }
	expect.equal(events[1].type, "swap", "a swap, never a call-in")
end,
["sword hits use the creature's ATK and count as the player's damage"] = function()
	local state = bossFightWithPlayer(3, 1)
	local events = BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword") :: { any }
	expect.equal(events[1].from, "a:@1")
	expect.near(events[1].damage, 10, 1.01) -- owned() ATK 20 × 0.5, ±10% spread
	expect.equal(BattleSim.contribution(state, "1").dealt, events[1].damage)
end,
["a down player gets up at half HP while a creature stands"] = function()
	local state = bossFightWithPlayer(4, 1)
	BattleSim._hurtPlayer(state, "a:@1", 100)
	expect.equal(BattleSim.snapshot(state).sides.a.fighters[2].down, true)
	runFor(state, 5.1) -- helper: BattleSim.step in 0.1 s steps for that long
	local view = BattleSim.snapshot(state).sides.a.fighters[2]
	expect.equal(view.down, false); expect.equal(view.hp, 50)
end,
["down with no creature left ends the fight"] = function()
	local state = bossFightWithPlayer(5, 100000) -- each creature faints on the boss's first hit on it
	BattleSim._hurtPlayer(state, "a:@1", 100)
	runFor(state, 6) -- p1 faints ~2 s, r1 swaps in and faints ~4 s: nobody standing
	expect.equal(state.result, "b")
end,
-- Also, with the same helper:
-- "a player alone keeps fighting": boss ATK 100000, player NOT hurt, run 6 s → state.result == nil, player still up.
-- "withdraw takes the player fighter out too": BattleSim.withdraw(state, "1") → the "a:@1" view has left = true and a
--   "leave" event names it.
-- "hpLeft and getFainted ignore the player": after the player goes down and p1 faints, hpLeft(state, "a", "1") has no
--   "@1" key and getFainted(state, "a") lists "p1" only.
-- "dodge has a cooldown and fails while down": dodge → events; dodge again at once → nil, "cooldown"; after
--   _hurtPlayer(…, 100) → nil, "down".
-- "thunderclap, Wave and Tidal Shield leave the player alone": a thunderclap boss emits no "stun" to "a:@1"; a Tide
--   creature's Wave doesn't raise the player's HP; with a side shield up, _hurtPlayer still lowers the player's HP.
```

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run`
Expected: FAIL on the new BattleSim cases (`swordHit` missing etc.); old cases still PASS.

- [ ] **Step 3: Implement** the player fighter in BattleSim (fields `player`, `down`, `downUntil`, `out`,
  `dodgeReady`, `lastCreatureAtk` by owner on the side), the rules above, `swordHit`, `dodge`, the snapshot fields, and
  `SideInput.callIn`. Update the file's header comment.

- [ ] **Step 4: Run tests to verify they pass**

Run: `lune run tests/run`
Expected: every spec PASS (no old BattleSim case changed).

- [ ] **Step 5: Commit**

```bash
git add src/server/Util/BattleSim.luau tests/BattleSim.spec.luau
git commit -m "BattleSim: player fighters that go down, get up and fight with sword hits"
```

---

### Task 4: BattleSim: boss attacks on players (quick hits and rings)

**Files:**
- Modify: `src/server/Util/BattleSim.luau`
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- Consumes: Task 3 player fighters; `Bosses.PlayerAttacks` shape; `Combat.PLAYER_TARGET_SHARE`, `QUICK_WARNING`, `HIT_GRACE`.
- Produces:
  - `FighterInput.playerAttacks: PlayerAttacks?` on the boss (BattleService passes the boss's config).
  - `State.ringCheck: ((ring: { id: number, target: string, shape: string }) -> boolean)?` — called when a ring lands;
    true = the target player is inside. Nil = always inside (the balance tool sets its own).
  - Event type gains `ring: number?` and `seconds: number?`. Events:
    `{ type = "telegraph", kind = "quick", from = boss id, to = player id, seconds = QUICK_WARNING }`;
    `{ type = "ring", kind = "slam" | "swipe", from = boss id, to = player id, seconds = warning, ring = ringId }`
    (ring ids count up per fight); landing hits are
    `{ type = "attack", kind = "Quick" | "Slam" | "Swipe", from = boss, to = player, damage, dodged? }`.

Rules (each needs a test):
- Each boss swing (`swings` per attack) goes at a standing player with probability `PLAYER_TARGET_SHARE` (a player not
  already hit this attack), otherwise at a creature as today. When no creature stands on side A, every swing goes at a
  player. Down/out players are never picked. Adds never attack players.
- A swing at a player becomes a **pending quick hit**: telegraph now, lands at `time + QUICK_WARNING + HIT_GRACE`
  for `quick × maxHp` (rounded) unless the player's `dodgeUntil` covers the landing time.
- Every `every` seconds (first after `every`) the boss starts a **big attack**: one ring per up player (shape
  `"slam"` or `"swipe"`, picked with the sim's seeded random), plus, with `doubleChance`, a second ring on a random up
  player; each lands at `time + warning + HIT_GRACE` for `big × maxHp` unless dodging or `ringCheck` returns false.
- Pending hits never land after `state.result`, and are dropped for a player who is down, out or left.
- A boss without `playerAttacks`, or a fight with no player fighters, behaves exactly as today (all old tests green).

- [ ] **Step 1: Write the failing tests**: `about a third of boss swings go at the player` (2000 s of a boss fight
  with one player and a huge-HP creature, `playerAttacks = { every = 1e9, warning = 1, big = 0, quick = 0.001 }` so
  quick hits round to 0 and the player never goes down: telegraphs / (telegraphs + boss attack events on creatures)
  within 0.28-0.39); `a quick hit lands after the warning and
  grace` (first telegraph at t; HP drops at t + 0.65 ± one step); `a dodge inside the grace still avoids the hit`
  (dodge at t + 0.55: the landing event is `dodged = true`, HP unchanged); `big attacks come every interval with one
  ring per up player` (two players, `every = 10`: rings at ≈10 s and ≈20 s, two per attack); `ringCheck false means
  the ring misses`; `the Hydra's double chance adds a second ring sometimes` (over 200 attacks, some attacks have 3 rings
  for 2 players); `pending hits never land after the end` (boss HP 1, a pending quick hit, a sword hit kills the boss,
  run 2 s: no attack event on the player after the end event); `every swing goes at players when no creature
  stands`; `a boss without playerAttacks never rings`.

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run`
Expected: the new cases FAIL; everything else PASS.

- [ ] **Step 3: Implement** the swing split in `attack()`, `state.pending` (list of `{ kind, at, target, damage, ringId? }`)
  resolved at the start of `step()`, the big-attack timer (`bigReady` on the boss fighter), `ringCheck`, and the events.

- [ ] **Step 4: Run tests to verify they pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/server/Util/BattleSim.luau tests/BattleSim.spec.luau
git commit -m "BattleSim: bosses hit players with quick hits and closing-ring attacks"
```

---

### Task 5: Balance tool player modes and the boss retune

**Files:**
- Modify: `tools/balance/bosses.luau`
- Modify: `src/shared/Config/Bosses.luau` (hp, atk, `groupAtkStep` where needed), `src/shared/Config/Swords.luau` (powers only if needed)
- Modify: `DESIGN.md` (boss balance lines: the ×1.5 note, win rates, "Swaps" paragraph)

**Interfaces:**
- Consumes: Task 3-4 sim API (`swordHit`, `dodge`, `ringCheck`, player fighters, `callIn = false`), `SwordRules.comboPowerPerSecond`.
- Produces: tool rows per boss × Power (0.8× / 1× / 1.3×) × mode, where modes are
  `stands still` (no sword, never dodges, `ringCheck` always true) and `fights well` (cuts in a loop at 75% uptime
  through `swordHit` with the starter combo's powers and lengths, uses the skill on cooldown, dodges 60% of quick hits
  and gets out of 90% of rings), solo and with `players > 1`. The party is today's: the summoned creature at the row's
  Power plus two reserves at the same Power, swaps on, abilities fired when ready.

- [ ] **Step 1: Extend the tool** with the two modes and print `win% | avg seconds` per row; keep today's party rows
  for comparison under a `--legacy` flag if cheap, else drop them.
- [ ] **Step 2: Run it before tuning and record the table**

Run: `lune run tools/balance/bosses 300`
Expected: prints a row per boss/power/mode (numbers will be off target).
- [ ] **Step 3: Retune** each boss's `hp` and `atk` (remove the ×1.5 / ×1.2 from the three-card era as a starting
  point), and only if the ratio drifts, the sword `power`, until solo rows land within ±7 points of: fights well 85% at
  1× / 50% at 0.8×; stands still 60% at 1× / 15% at 0.8×; fights well wins in about half the time of stands still at 1×;
  no row times out (`BOSS_MAX_FIGHT_SECONDS` 420). The Hydra's rows start from its Dungeon state as today.
- [ ] **Step 4: Check groups**

Run: `lune run tools/balance/bosses 300 2` and `lune run tools/balance/bosses 300 4`
Expected: group rows within ±10 points of the solo targets (adjust `groupAtkStep` if not).
- [ ] **Step 5: Run the unit tests**

Run: `lune run tests/run`
Expected: PASS (fix any BattleSim/Bosses spec that pinned old boss HP).
- [ ] **Step 6: Update DESIGN.md** (the "Swaps" ×1.5 sentence, the groups tuning sentence, a new line with the
  win-rate targets and the final table summary) and **commit**

```bash
git add tools/balance/bosses.luau src/shared/Config/Bosses.luau src/shared/Config/Swords.luau DESIGN.md
git commit -m "Boss balance: model the player and retune bosses to the new win-rate targets"
```

---

### Task 6: Saved popup flag and SwordService (body, sword ownership, back accessories)

**Files:**
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 14`), `src/server/Util/Migrations.luau` (`[13]`),
  `src/server/Services/DataService.luau` (type + template `seenSword: boolean = false`)
- Create: `src/server/Services/SwordService.luau`
- Modify: `src/server/init.server.luau` (start order: after DataService, EconomyService, PartyService; before BattleService)
- Modify: `src/shared/Remotes.luau` (`SwordState`, `SwordSeen`)
- Modify: `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau` (`/swordpopup`: clear `seenSword` and resend)
- Test: `tests/Migrations.spec.luau`

**Interfaces:**
- Consumes: `Swords.UNLOCK_SHOP_LEVEL`, `Swords.STARTER`; EconomyService's shop level getter and its level-up signal
  (read EconomyService for the exact names; `Remotes.LevelUp` fires from it).
- Produces:
  - Remotes: `SwordState` (server → client: `{ sword: string?, popup: boolean }`; client → server: `()` ask),
    `SwordSeen` (client → server: `()` the popup was closed).
  - Character attributes set by the server: `Sword` (sword id string, or nil below level 3), `SwordDrawn` (boolean).
  - `SwordService.GetSword(player: Player): string?` — the equipped sword id (the starter at shop level ≥ 3, else nil).
  - `SwordService.Touch(player: Player)` — sets `SwordDrawn = true` and restarts the `SHEATH_SECONDS` timer.
  - `SwordService.SetBackHidden(player: Player, hidden: boolean)` — hides/restores accessories whose
    `AccessoryType` is `Back` (Handle transparency to 1, the original kept in an attribute; restored on `false`, on
    respawn nothing to restore).
- Standard body (spike-proven): on each character, after its appearance loads, `Humanoid:ApplyDescription` with
  Torso/LeftArm/RightArm/LeftLeg/RightLeg = 0, BodyTypeScale = 0, ProportionScale = 0, HeightScale/WidthScale/DepthScale = 1,
  keeping Head and everything else from `Players:GetHumanoidDescriptionFromUserId` (pcall; on failure keep the avatar).
  This is character setup, not saved state, so CharacterAdded is fine here; `seenSword` goes through
  `DataService.Register({ name = "SwordService", load, save, unload })` (save does nothing if load never ran).

- [ ] **Step 1: Write the failing migration test** in `tests/Migrations.spec.luau`:

```lua
["v14: seenSword starts false so existing players see the sword popup once"] = function()
	local data: any = { version = 13 }
	Migrations.run(data, 14)
	expect.equal(data.seenSword, false)
	expect.equal(data.version, 14)
end,
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL (`seenSword` nil).

- [ ] **Step 3: Implement** the schema bump, migration `[13] = function(data) if typeof(data.seenSword) ~= "boolean" then data.seenSword = false end end`,
  the template/type field, SwordService (body, `Sword` attribute on load/level-up/respawn, `SwordState` push on load and
  when reaching level 3, `SwordSeen` sets the flag; both remotes rate-limited), the two remotes, `/swordpopup`.
  DESIGN.md 10.4 gets the new field.

- [ ] **Step 4: Run tests**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Studio check** (Rojo serving `default.project.json`; Play via MCP). Confirm in the place (read only)
  that `StarterPlayer.GameSettingsAvatar` is R15; if it isn't, **ask the user** to set Avatar Type R15 in Game Settings.
  Then: Output has no errors; your character has the standard body with its own head; `/level 3` sets the `Sword`
  attribute and fires `SwordState` with `popup = true`. Screenshot the character.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Config/Data.luau src/server/Util/Migrations.luau src/server/Services/DataService.luau src/server/Services/SwordService.luau src/server/init.server.luau src/shared/Remotes.luau src/server/Services/DevService.luau src/shared/Config/AdminPanel.luau tests/Migrations.spec.luau DESIGN.md
git commit -m "SwordService: standard body, starter sword at shop level 3, once-only popup flag"
```

---

### Task 7: BattleService: the player in boss fights

**Files:**
- Modify: `src/server/Services/BattleService.luau`
- Modify: `src/shared/Remotes.luau` (`SwordAttack`, `SwordSkill`, `Dodge`)

**Interfaces:**
- Consumes: Task 3-4 sim API; `SwordRules` (Task 2); `RingRules` (Task 2); `SwordService.GetSword/Touch/SetBackHidden` (Task 6);
  `Bosses.RING_*`, `HIT_RADIUS_SHARE`, `ADD_HIT_RADIUS`; `Combat.HIT_GRACE`, `SWORD_ACTION_COOLDOWN`.
- Produces:
  - Remotes: `SwordAttack` (client → server: `()` an Attack tap), `SwordSkill` (client → server: `()`),
    `Dodge` (client → server: `()`). Each: in a boss fight, past the intro, own player fighter up, rate-limited
    (`SWORD_ACTION_COOLDOWN`); invalid calls are dropped silently.
  - Boss fights (`monster.boss`, including the Hydra): each member gets a player fighter (`"@" .. owner`), side A
    `callIn = false`, the boss gets its `playerAttacks`; `sim.ringCheck` looks up the ring recorded for its id and checks
    the target player's current root position with `RingRules` (a missing character counts as inside).
  - Ring events are broadcast with geometry added: `x, z` (slam centre: the target's root at telegraph time; swipe
    origin: the boss) and `dirX, dirZ, length, radius, halfAngle` so clients draw the same shape.
  - Attack flow: `SwordAttack` → `SwordRules.nextCut` on the member's last cut → `SwordService.Touch` → at
    `startAt + cut.hitAt` (task.delay; skip if the fight ended or the player is down) every boss/add whose edge is in
    reach (`SwordRules.inReach` with the root's position and look; boss radius = ring radius × `HIT_RADIUS_SHARE`, adds
    `ADD_HIT_RADIUS`) takes `BattleSim.swordHit(sim, owner, id, cut.power * sword.power, "Sword")`. `SwordSkill`: same
    with `skill`, `inRadius`, kind `"Skill"`, the cooldown tracked per member.
  - `Dodge` → `BattleSim.dodge(sim, owner)` (the sim owns the untouchable window and cooldown; the movement is the
    client's, Task 11).
  - `telegraph` and `ring` events set the boss marker's attribute `WindUp` to the warning seconds (and bump a
    `WindUps` counter so repeats fire), so every client can pose the boss's lean-back and glow (Task 12).
  - `down` / `getUp` / `out` events set the character attribute `Downed` (true/nil) and the Humanoid's WalkSpeed to 0 /
    back; `out` in a group leaves the member in the fight (spectating, kneeling, untargeted).
  - `markerFor("a:@<owner>")` returns that player's HumanoidRootPart; `BattleStarted.markers` include each member's root.
  - `SwordService.SetBackHidden(player, true)` when a boss fight starts, `false` in `release`.
  - Wild fights, Dungeon rooms and PvP: unchanged (no player fighter, call-in kept).

- [ ] **Step 1: Implement** the above. No new pure logic here (it all lives in Tasks 2-4); keep helpers small.
- [ ] **Step 2: Run tests**

Run: `lune run tests/run`
Expected: PASS (SourceOrder included).
- [ ] **Step 3: Studio check via MCP**: Play; `/level 3`, `/maxcard Solarion`, summon it, `/boss 1 fight`. Through
  `execute_luau` on the Server: fire the remote handlers for the test player (or call `Remotes.SwordAttack` from the
  Client datamodel) and confirm in Output/a print of `BattleSim.snapshot` that sword hits land with `from = "a:@<id>"`,
  rings appear about every 10 s, standing in one lowers player HP, and at 0 HP `Downed` is set and clears after 5 s.
  No errors in Output.
- [ ] **Step 4: Commit**

```bash
git add src/server/Services/BattleService.luau src/shared/Remotes.luau
git commit -m "BattleService: players fight bosses with validated sword hits, dodges and rings"
```

---

### Task 8: Losing: the 3-2-1 home, group spectating

**Files:**
- Modify: `src/server/Services/BossService.luau`, `src/server/Services/WildService.luau`, `src/server/Services/BattleService.luau`
- Modify: `src/shared/Util/BossRules.luau`
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Consumes: `Combat.LOSS_COUNTDOWN`; `BattleService.OnFightEnded(monster, result, hpLeft)`.
- Produces:
  - `BossRules.lossHome(place: string): "spring" | "frontierSpring" | "dungeon"` — `"Main"` → `"spring"`, `"Frontier"` →
    `"frontierSpring"`, `"Dungeon"` → `"dungeon"`.
  - `BossRules.countdownText(secondsLeft: number): string` — `"Teleporting back to town in 3"` style; the client shows
    3, 2, 1 from it.
  - `WildService.SendToSpring(player: Player): boolean` — main game: `MoveTo` a spot 8 studs beside `Wild.SPRING` (the
    plaza spring, out of the Wild); Frontier: `MoveInWild` beside its entrance spring.
  - `BattleEnded` summary for a boss loss carries `countdown = Combat.LOSS_COUNTDOWN`.
  - BossService: on a boss fight's `"lose"`, after `LOSS_COUNTDOWN` seconds every member still present goes home by
    `lossHome` (`"dungeon"`: DungeonService's existing out handling, unchanged); remote arena copies skip the loot linger
    on a loss. Wins and runs keep today's behaviour.

- [ ] **Step 1: Write the failing tests** in `tests/BossRules.spec.luau`: `lossHome` for the three places;
  `countdownText(3) == "Teleporting back to town in 3"`.
- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run`
Expected: FAIL (functions missing).
- [ ] **Step 3: Implement** the functions, `SendToSpring`, the summary field and the delayed move.
- [ ] **Step 4: Run tests**

Run: `lune run tests/run`
Expected: PASS.
- [ ] **Step 5: Studio check**: lose boss 1 on purpose (weak creature, stand in rings); Output clean; after 3 s you
  are beside the plaza spring. Frontier window (`rojo serve frontier.project.json`): lose boss 4 → beside its entrance
  spring. Screenshot both.
- [ ] **Step 6: Commit**

```bash
git add src/server/Services/BossService.luau src/server/Services/WildService.luau src/server/Services/BattleService.luau src/shared/Util/BossRules.luau tests/BossRules.spec.luau
git commit -m "Boss losses: 3-2-1 back to the spring, group members watch until the end"
```

---

### Task 9: Blender animations for the starter sword

**Files:**
- Create: `tools/blender/anim_kit.py` (the standard R15 rig, IK legs with a 0.06 forward knee pre-bend, feet
  `use_inherit_rotation = False`, render front/side frames, export per-frame JSON), built from
  `.superpowers/combat-spike/sword_anim_spike.py`
- Create: `tools/blender/anim_starter_sword.py` (one function per move: `draw, sheath, cut1, cut2, cut3, skill, dodge,
  flinch, down, getUp, ready, run`; `ready` and `run` loop)
- Create: `tools/anim/build_kfs.luau` (Lune, `@lune/roblox`: JSON → KeyframeSequence `.rbxm`; Pose tree
  HumanoidRootPart > LowerTorso > UpperTorso > …; `Pose.CFrame` from the exported quaternions; loop flag for `ready`/`run`)
- Create: `assets/animations/StarterSword/<Move>.rbxm` (12 files) and `assets/animations/src/<move>.json`
- Modify: `default.project.json`, `frontier.project.json`, `dungeon.project.json` (`assets/animations` →
  `ReplicatedStorage.SwordAnimations`)
- Create: `src/client/Util/SwordAnims.luau`
- Create: `docs/animations.md` (the pipeline: rig, axes, export, build, publish, ids)
- Modify: `src/shared/Config/Swords.luau` (animation ids once published)

**Interfaces:**
- Produces: `SwordAnims.load(humanoid: Humanoid, swordId: string): { play: (key: string, speed: number?) -> AnimationTrack?, stop: (key: string) -> (), hitStop: (seconds: number) -> () }`
  — plays published ids from `Swords.SWORDS[id].animations`; in Studio, a key whose id is `""` falls back to
  `KeyframeSequenceProvider:RegisterKeyframeSequence(ReplicatedStorage.SwordAnimations.<SwordName>.<Move>)`.
  `hitStop` sets every playing sword track's speed to 0 for `seconds`, then back.
- Axis rules (from the spike): x_r = -x_b, y_r = z_b, z_r = y_b; character faces -Y in Blender, its left is +X;
  export `T_r = M·(Fp⁻¹·Fc)·M` with `F = pose_bone.matrix @ rest_rot⁻¹`, `M = ((-1,0,0),(0,0,1),(0,1,0))`.

- [ ] **Step 1:** Build the kit and `cut1` (re-create the spike's cut). Render front + side GIFs (real speed) into the
  visual companion and **show the user**; adjust until approved.
- [ ] **Step 2:** Make the other 11 moves in batches (combo cuts 2-3 + skill; dodge + flinch + down + getUp; draw +
  sheath + ready + run), each batch shown to the user as GIFs before moving on. Timings must match `Swords` (each cut's
  strike frame at `hitAt`, total `length`); if the user's approved timing differs, update `Swords` and re-run Task 2's
  DPS test.
- [ ] **Step 3:** Export JSON, build the `.rbxm` files with `lune run tools/anim/build_kfs`, add the Rojo mapping,
  restart `rojo serve` (project file changed), write `SwordAnims`.
- [ ] **Step 4: Studio check**: Play; from the client datamodel load `SwordAnims` on your humanoid and play each key;
  screenshot the strike frame of each cut. Output clean.
- [ ] **Step 5:** Ask the user to publish the 12 KeyframeSequences (Studio: select under
  `ReplicatedStorage.SwordAnimations` → right-click → Save to Roblox, owned by the experience owner) and paste the ids;
  put them in `Swords.SWORDS.starterSword.animations`.
- [ ] **Step 6: Run tests and commit**

Run: `lune run tests/run`
Expected: PASS.

```bash
git add tools/blender/anim_kit.py tools/blender/anim_starter_sword.py tools/anim/build_kfs.luau assets/animations default.project.json frontier.project.json dungeon.project.json src/client/Util/SwordAnims.luau src/shared/Config/Swords.luau docs/animations.md
git commit -m "Starter sword animations: Blender kit, 12 moves, KeyframeSequences and loader"
```

---

### Task 10: The sword model on the back and in the hand, the first-sword popup

**Files:**
- Create: `tools/blender/build_starter_sword.py` (sources in `assets/blender/StarterSword/`)
- Create: `assets/weapons/StarterSword.rbxm` (saved by the user after import)
- Modify: the three project files (`assets/weapons` → `ReplicatedStorage.WeaponModels`)
- Create: `src/client/Controllers/SwordController.luau` (this task: rendering + popup; Task 11 adds input)
- Modify: `src/client/init.client.luau` (start order)

**Interfaces:**
- Consumes: character attributes `Sword`, `SwordDrawn`, `Downed` (Tasks 6-7); `SwordState`, `SwordSeen` remotes;
  `SwordAnims` (Task 9).
- Produces:
  - Every client renders a sword for **every** character whose `Sword` attribute is set: a clone of
    `WeaponModels.<model>` welded to the UpperTorso's back attachment when `SwordDrawn` is false and to the RightHand's
    grip attachment when true (re-welded on change, removed when `Sword` clears or the character goes).
    The owner's client sets its own visual immediately on attack (prediction); the attribute follows.
  - Draw/sheath plays `draw`/`sheath` with a gleam and the draw sound on the owner's client.
  - The popup: on `SwordState` with `popup = true`, a `UIKit.panel` "You got your first sword!" with a turning sword
    viewport and one button; closing fires `SwordSeen`.
  - The model: plain steel blade, cartoon style matching the game (smooth, simple shapes, flat colours), a `Handle`
    with `Grip` and `Back` attachments, roughly 4.5 studs long.

- [ ] **Step 1:** Build the sword in Blender; render it and **show the user**; adjust until approved. Slim the
  `.blend` (no `*_Src`, orphans purged, key fields empty — print lengths only).
- [ ] **Step 2:** Export FBX; the user imports it in Studio; Claude (asking first, it changes the place) adds the
  attachments and the user saves `assets/weapons/StarterSword.rbxm`. Add the Rojo mapping, restart `rojo serve`.
- [ ] **Step 3:** Write SwordController's rendering and popup.
- [ ] **Step 4: Run tests**

Run: `lune run tests/run`
Expected: PASS (CreatureAssets-style script gate: if the weapon folder is scanned for scripts, add it to the gate test).
- [ ] **Step 5: Studio check**: Play; `/level 3` → popup shows once (rejoin: not again; `/swordpopup`: again); the
  sword sits on the back; Local Server with 2 players: each sees the other's sword. Screenshots: back view, popup.
- [ ] **Step 6: Commit**

```bash
git add tools/blender/build_starter_sword.py assets/blender/StarterSword assets/weapons default.project.json frontier.project.json dungeon.project.json src/client/Controllers/SwordController.luau src/client/init.client.luau
git commit -m "Starter sword: Blender model on the back and in the hand, first-sword popup"
```

---

### Task 11: The boss-fight HUD and controls

**Files:**
- Create: `src/client/Util/CombatHud.luau`
- Create: `src/client/Util/AfterImage.luau`
- Modify: `src/client/Controllers/SwordController.luau` (input, soft aim, dodge dash, Shift Lock to Ctrl)
- Modify: `src/client/Controllers/BattleController.luau` (boss fights use CombatHud instead of the fight bar; player rows)
- Modify: `src/client/Controllers/PartyBarController.luau` (keys 1-3 swap in boss fights instead of summoning)
- Modify: `src/shared/Config/HudLayout.luau` or a new `Config/CombatHud.luau` (sizes, colours, positions)
- Test: `tests/UiLayout.spec.luau` only if a pure layout helper is added (prefer one: `UiLayout.combatButtons(viewW, viewH)` returning rects ≥ 48 px that avoid the thumbstick and jump zones)

**Interfaces:**
- Consumes: snapshot fields `player`, `down`, `downIn`, `out` (Task 3); remotes `SwordAttack`, `SwordSkill`, `Dodge`,
  `UseAbility`, `CallIn` (swap), `RunFight`; `SwordRules.aimTarget`; `SwordAnims`.
- Produces:
  - `CombatHud.new(parent: ScreenGui, callbacks: { attack: () -> (), dodge: () -> (), skill: () -> (), pet: () -> (), signature: () -> (), swap: (beastId: string) -> (), run: () -> () }): CombatHud`
    with `:update(view: { playerHp: number, playerMax: number, creatureName: string, creatureHp: number, creatureMax: number, skillIn: number, petIn: number, signatureIn: number?, dodgeIn: number, swapIn: number, reserves: { { id: string, name: string, hp: number, maxHp: number } }, down: boolean, out: boolean })`
    and `:destroy()`. Style 3 "Anime slash": slanted cut-corner panels with neon edges per button colour (Attack
    #ffb347, Dodge #4da3ff, Skill #a78bfa, Pet #4ade80, Run #f87171); layout A (big Attack bottom-right, Dodge left of
    it, Skill above Dodge, Pet above Attack, Signature small beside Pet when present, small Swap and Run icon buttons at
    the bottom centre); cooldown sweep with seconds left; PC key labels (Click, Shift, E, R); player HP and creature HP
    top-left. Icons: placeholders (simple shapes) until Task 13 delivers the art.
  - Swap pops out the rested party cards as small portraits; with one rested card it swaps straight away.
  - The sword is only swung in boss fights: outside them none of these inputs are bound (Click keeps its shop uses).
  - PC keys in boss fights: Mouse1 = attack (not over GUI), **LeftShift = dodge**, E = skill, R = pet skill, 1-3 = swap
    to that party slot's card. Shift Lock moves to Ctrl: set the PlayerModule `MouseLockController`'s `BoundKeys`
    StringValue to `"LeftControl,RightControl"` once on start.
  - Attack: soft aim (`SwordRules.aimTarget` over the boss and adds with `SOFT_AIM_RANGE` / `SOFT_AIM_ANGLE`; turn the
    root toward the pick), play the next cut locally (mirroring `SwordRules.nextCut`), fire `SwordAttack`.
  - Dodge: fire `Dodge`, dash `DODGE_STUDS` over `DODGE_SECONDS` in the move direction (backward when still) with the
    Humanoid/velocity (never a CFrame jump, so the arena barrier stops it), `dodge` animation, 3-4 fading after-images
    (`AfterImage.spawn(character: Model, count: number, seconds: number)`).
  - While `Downed`: buttons dim, `down` animation; `getUp` when it clears.

- [ ] **Step 1 (if a layout helper is added): write the failing `UiLayout` test** for `combatButtons` (every rect ≥ 48 px,
  none overlapping the thumbstick zone or the jump button zone at 844×390 and 1920×1080). Run `lune run tests/run`:
  FAIL. Implement. Run: PASS.
- [ ] **Step 2:** Mock the HUD first as a screenshot in Studio (or the companion) on a landscape phone frame and **show
  the user** before wiring everything.
- [ ] **Step 3:** Implement CombatHud, AfterImage, the inputs, soft aim, dodge, Shift Lock rebinding, PartyBar keys,
  and BattleController's switch.
- [ ] **Step 4: Run tests**

Run: `lune run tests/run`
Expected: PASS.
- [ ] **Step 5: Studio check**: Play, boss 1: tap/click Attack chains 3 cuts; Shift dodges with after-images and
  avoids a ring; E spins; R fires Fireball; swap pops out; Run leaves. Device emulator landscape phone: no button under
  the thumbstick or jump button. Screenshots: PC and phone HUD mid-fight.
- [ ] **Step 6: Commit**

```bash
git add src/client/Util/CombatHud.luau src/client/Util/AfterImage.luau src/client/Controllers/SwordController.luau src/client/Controllers/BattleController.luau src/client/Controllers/PartyBarController.luau src/shared/Config src/shared/Util/UiLayout.luau tests/UiLayout.spec.luau
git commit -m "Boss-fight HUD: anime-slash buttons, sword controls, dodge with after-images"
```

---

### Task 12: Rings, hit feel and the loss countdown on the client

**Files:**
- Create: `src/client/Util/RingFx.luau`
- Create: `src/client/Util/HitFx.luau`
- Create: `src/shared/Config/SwordFx.luau` (texture ids, colours, sizes, hit-stop seconds, shake strengths)
- Modify: `src/client/Controllers/BattleController.luau`, `src/client/Controllers/SwordController.luau`
- Modify: `src/client/Controllers/MonsterController.luau` (the boss's wind-up pose)

**Interfaces:**
- Consumes: the boss marker's `WindUp` / `WindUps` attributes (Task 7): the boss leans back on its rig (a pose in the
  style of `Util/PetRig`, eased in over the warning, snapping forward on the hit) and its glow masks brighten for the
  warning.
- Consumes: ring events with geometry (Task 7), telegraph events, attack events with kinds `"Sword"`, `"Skill"`,
  `"Quick"`, `"Slam"`, `"Swipe"`; `RingRules.closingScale`; `BattleEnded.countdown` (Task 8); `SwordAnims.hitStop`.
- Produces:
  - `RingFx.show(ring: { shape: string, x: number, z: number, dirX: number?, dirZ: number?, radius: number?, length: number?, halfAngle: number?, warning: number }): ()`
    — look B "closing ring": a thin white outline of the area on the ground plus a glowing white ring closing from
    1.9× to the edge over `warning` (`RingRules.closingScale`), a white flash when it lands; at most 2 parts per ring,
    raycast to the ground.
  - `HitFx.onHit(target: BasePart, damage: number, byPlayer: boolean, kind: string): ()` — sparks (flipbook), white
    flash on the boss (Highlight, ~0.08 s), damage number (player hits in `Swords.PLAYER_DAMAGE_COLOR`), shake (small on
    cuts, bigger on cut 3 and the skill), hit-stop on the owner's sword tracks (~0.06 s).
  - A slash trail (Trail between two blade attachments) enabled during cuts.
  - The quick-hit telegraph: the boss flashes (Highlight pulse) for `QUICK_WARNING`.
  - When the local player is hit (not dodged), their character plays `flinch`.
  - The loss screen: "Teleporting back to town in 3", "… 2", "… 1" from `BossRules.countdownText`.
  - Sounds from `Swords.SWORDS[id].sounds` at each moment (silent while ids are `""`).

- [ ] **Step 1:** Implement with placeholder textures (plain white ring/outline images made by
  `tools/textures/make_ring_textures.py`, PIL, uploaded) and Roblox's built-in spark texture; Task 13 swaps in the art.
- [ ] **Step 2: Run tests**

Run: `lune run tests/run`
Expected: PASS.
- [ ] **Step 3: Studio check**: Play boss 1 and boss 3 (Ember arena: the white ring must read on lava); 4 rings at once
  with `/crowd`-style group test or two Local Server players; frame time stays steady (Studio's `rbx-perf-profiling`
  skill on a phone emulator). Screenshots: a ring closing on grass and on lava, a hit with sparks and number, the loss
  countdown. **Show the user.**
- [ ] **Step 4: Commit**

```bash
git add src/client/Util/RingFx.luau src/client/Util/HitFx.luau src/shared/Config/SwordFx.luau src/client/Controllers/BattleController.luau src/client/Controllers/SwordController.luau src/client/Controllers/MonsterController.luau tools/textures/make_ring_textures.py
git commit -m "Fight feel: closing-ring warnings, hit-stop, sparks, flashes, damage numbers, loss countdown"
```

---

### Task 13: Art pass: effect frames, icons, sounds

**Files:**
- Create: `tools/blender/build_sword_fx.py` (spark burst, slash smear, dodge whoosh frames) → `assets/ui/fx/sword/`
  through `tools/textures/make_flipbooks.py`
- Create: icon sheet `assets/ui/icons/combat-sheet.png` (Figma image generator) cut by
  `tools/ui-icons/slice_icons.py`
- Modify: `src/shared/Config/SwordFx.luau`, `src/shared/Config/UIIcons.luau`, `src/shared/Config/Swords.luau` (sounds)

**Interfaces:**
- Produces: uploaded image ids for sparks, smear, ring outline/closing ring, and the icons `attack, dodge, skill, pet,
  signature, swap, run`; sound ids for `swing1-3, hit, draw, dodge, ring, down, getUp` (Creator Store search through
  the Studio MCP; free, Roblox-licensed).

- [ ] **Step 1:** Render the effect frames in Blender (smooth cartoon look, use pixelfx only as a timing/idea
  reference), make the flipbooks, **show the user** side by side in the companion.
- [ ] **Step 2:** Generate the icon sheet in Figma (white line icons that sit on the anime-slash panels), slice,
  **show the user** on the HUD mock.
- [ ] **Step 3:** Pick sounds; list them with a short description each for the user to approve.
- [ ] **Step 4:** Upload (local http server + `upload_image`, as for the arenas), put ids in config.
- [ ] **Step 5: Run tests and the Studio check** (the HUD with real icons, a hit with the new sparks, sounds play).

Run: `lune run tests/run`
Expected: PASS.
- [ ] **Step 6: Commit**

```bash
git add tools/blender/build_sword_fx.py assets/ui/fx/sword assets/ui/icons src/shared/Config/SwordFx.luau src/shared/Config/UIIcons.luau src/shared/Config/Swords.luau
git commit -m "Sword fight art: effect flipbooks, HUD icons, sounds"
```

---

### Task 14: Docs and the whole-flow check

**Files:**
- Modify: `DESIGN.md` (combat: the player in boss fights, controls, rings, losing, rest 5 min, starter sword, files
  tree; 10.4 already done), `CLAUDE.md` (new asset folders `assets/animations`, `assets/weapons`; the animation and sword
  build scripts; new Lune specs in the test list; `/swordpopup`), `docs/animations.md` (finished)
- Obsidian vault `C:/Users/Ben/Documents/obsidian/card-shop-tycoon`: a "Sword combat" topic note, decisions log entry,
  lessons (Blender → KeyframeSequence pipeline, AnimationConstraint findings, ring latency grace)

- [ ] **Step 1:** Update the docs and the vault.
- [ ] **Step 2: Full check**

Run: `lune run tests/run` and `lune run tools/balance/bosses 300`
Expected: PASS; balance rows within the Task 5 targets.

Studio, main place: solo boss 1 (win by fighting, lose by standing still in rings → 3-2-1 to the spring), boss 3 on a
phone emulator; Local Server 2 players vs boss 2 (both ringed, one out and watching, the win counts for both).
Frontier window: boss 4. Dungeon window: `/room 4`, the Hydra (double rings). Output clean throughout. Screenshots of each.
- [ ] **Step 3:** Tell the user exactly what to judge in Studio (stop → Play): the feel of the combo, dodge timing on
  rings, button reach on a phone, how often they win standing still vs fighting.
- [ ] **Step 4: Commit**

```bash
git add DESIGN.md CLAUDE.md docs/animations.md
git commit -m "Docs: the player in boss fights"
```

Ticking the system in DESIGN.md, merging and pushing wait for the user's confirmation.
