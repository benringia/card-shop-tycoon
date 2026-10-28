# Boss Ladder Phase 3: Dramatic Fights, Frontier Bosses 4-6, Gold Seals — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every boss fight dramatic (intro, bigger sealed arena, music, phase moments), then add the three
Frontier bosses (Frost Tyrant shields, Storm Sovereign thunderclap stuns, Rift Devourer adds) and Gold Seals.

**Architecture:** Mechanics live in the pure `BattleSim` (Lune-tested) as new `Mechanics` entries; arenas stay built
by `WildService.BuildBossArenas`, now only for the bosses of the current place (a `place` field in `Config/Bosses`);
`BossService` starts in the Frontier too. Presentation (intro camera, banners, music) is client-only in
`BattleController`, driven by an `intro` field in `BattleStarted` and by sim events.

**Tech Stack:** Roblox Luau, Rojo, Lune tests (`lune run tests/run`), Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-28-boss-ladder-design.md` (section 10, phase 3) plus the approved design
in the 2026-10-28 conversation (numbers below) and the "Dramatic boss fights" item of DESIGN.md section 13.

## Global Constraints

- Server authoritative; every remote validated and rate-limited (CLAUDE.md Rules). No new remote unless listed here.
- All tunable numbers in `src/shared/Config` (no magic numbers in services or controllers beyond layout pixels).
- UI text: plain ASCII plus `·` and emoji only. Tap targets >= 48 px.
- Pure rules go in Roblox-free modules with Lune tests; `SourceOrder` test: no local used above its definition.
- Saved shape unchanged (schema stays v12): new items and boss records fit the existing `items` and `bosses` tables.
- Every DESIGN.md number this plan changes is updated in the same task (CLAUDE.md "Keep it in sync").
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work on branch `boss-phase3`.

Approved numbers:

| # | Boss | Place / zone | Element | Lv | HP / ATK / SPD | Recommended | Mechanic | Unlock | Drops (full loot) |
|---|---|---|---|---|---|---|---|---|---|
| 4 | Frost Tyrant | Frontier, Frostwood (1) | Tide | 22 | 12500 / 30 / 9 | 1100 | shield: every 20 s, 6% max HP; breaking it stuns the boss 3 s | 5 `fragment_frostTyrant` (Ember Colossus drops, 60%) | Grading Seal 40% (1), Star Shard 25% (1-2), `fragment_stormSovereign` 60% |
| 5 | Storm Sovereign | Frontier, Stormpeak (2) | Volt | 32 | 17000 / 36 / 14 | 1500 | thunderclap: every 12 s stuns each standing enemy 3 s x clamp(bossSpd / fighterSpd, 0.3, 1.5) | 8 `fragment_stormSovereign` | Gold Seal 25% (1), `fragment_riftDevourer` 55% |
| 6 | Rift Devourer | Frontier, The Rift (3) | Shade | 45 | 22000 / 44 / 10 | 1900 | adds: at 70% and 35% HP, 2 Rift Spawn (each 6% boss max HP, ATK x0.4, species "Rift Horror"); boss takes x0.5 damage while any lives; attackers hit Spawn first | 8 `fragment_riftDevourer` | Gold Seal 30% (1), Star Shard 30% (1-2) |

Cash / XP per win: 4 = $150 / 3600, 5 = $210 / 5200, 6 = $280 / 7400. minFightSeconds: 4 = 60, 5 = 70, 6 = 80.
First clear: trophy + 3 of the next boss's fragments (6: trophy + 3 Gold Seals). Daily bonus: 4 = 2 Grading Seals,
5 = 1 Gold Seal, 6 = 1 Gold Seal. Scale (placeholder size): 3.0 / 3.2 / 3.4; shapes: reuse Frontier species shapes.

Gold Seal: pays the cash of one grade step; never the Legendary A -> S step (spec section 6).

## Review Focus

1. A boss dies while Rift Spawn are still alive: the fight must end as a win at once (not wait for the Spawn), and
   every Spawn marker must go. Pinned in Task 4 ("adds: the boss falling ends the fight with Spawn alive") and Task 5.
2. A player who disconnects or dies during the intro or while the arena is sealed: the barrier must drop when the
   fight ends for any reason, and nobody stays locked in an empty arena. Pinned in Task 1 (fight-end hook covers
   run, loss, leave) and Task 2 (actions refused during the intro).
3. Abilities, call-ins or Run pressed during the intro must not act before the fight starts. Task 2.
4. Loot left on the ground when a player leaves, teleports to the other place or disconnects: it must reach their
   Bag before the save, and a pickup request for someone else's drop, a taken drop or a far-away drop must do
   nothing. Task 7 (OnBeforeLeave grant; pickup validation) and its 2-player check. (Old saves load Frontier bosses
   locked: Task 3 test "read: Frontier bosses start locked".)
5. Gold Seal on a Legendary A -> S step: refused by the server even if the client sends useGold. Task 6 test.

---

### Task 1: Bigger sealed arenas

**Files:**
- Modify: `src/shared/Config/Bosses.luau` (ARENA_RADIUS, LEASH_RADIUS, new BARRIER values)
- Modify: `src/shared/Util/BossRules.luau` (ringSegments)
- Modify: `src/server/Services/WildService.luau` (BuildBossArenas: barrier parts, `inside` spot)
- Modify: `src/server/Services/BattleService.luau` (OnFightEnded hook)
- Modify: `src/server/Services/BossService.luau` (seal on start, unseal on end, move members inside)
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Produces: `BossRules.ringSegments(radius: number, maxWidth: number): { number }` — angles (radians) of the
  segment centres; `#result * maxWidth >= 2 * math.pi * radius` and every gap between neighbours equals
  `2 * math.pi / #result`.
- Produces: `WildService.BossArena` gains `barrier: { BasePart }` and `inside: CFrame` (a spot inside the ring,
  4 studs past the gate, facing the boss).
- Produces: `BattleService.OnFightEnded(handler: (monster: Monster) -> ())` — called once from `endFight` for every
  fight (win, loss, run, last member leaving).

- [ ] **Step 1: Write the failing test** in `tests/BossRules.spec.luau`:

```lua
["ringSegments: the barrier closes the whole ring"] = function()
	local angles = BossRules.ringSegments(Bosses.ARENA_RADIUS, Bosses.BARRIER_SEGMENT)
	expect.equal(#angles * Bosses.BARRIER_SEGMENT >= 2 * math.pi * Bosses.ARENA_RADIUS, true, "no gaps")
	expect.equal(math.abs((angles[2] - angles[1]) - 2 * math.pi / #angles) < 1e-9, true, "evenly spaced")
	expect.equal(Bosses.ARENA_RADIUS, 36, "the bigger arena")
end,
```
Also add `"ringSegments"` to the export list in the "every rule exists" test.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (ringSegments nil / BARRIER_SEGMENT nil).
- [ ] **Step 3: Implement.** Config: `ARENA_RADIUS = 36`, `LEASH_RADIUS = ARENA_RADIUS + BOSS_SPOT` written as the
  literal 42 with a comment, `BARRIER_SEGMENT = 6` (studs per wall piece), `BARRIER_HEIGHT = 14`,
  `BARRIER_TRANSPARENCY = 0.55`. `ringSegments` = `count = math.ceil(2πr / maxWidth)`, angles `i * 2π / count`.
  WildService: one Part per angle (size `BARRIER_SEGMENT + 0.5` x `BARRIER_HEIGHT` x 1, ForceField material,
  `Transparency = 1`, `CanCollide = false`, Anchored) on the ring at `ARENA_RADIUS`, in the arena folder; return them
  as `barrier`, plus `inside`. BattleService: `endFight` calls every OnFightEnded handler with `fight.monster` after
  release. BossService: after a successful `startBoss`, pivot each member's character to `arena.inside` (spread
  sideways by `GROUP_SPACING`), then set the barrier `CanCollide = true`, `Transparency = BARRIER_TRANSPARENCY`;
  OnFightEnded for a boss monster drops it again (`CanCollide = false`, `Transparency = 1`).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass. Rojo sync, Play, `/boss 1 fight`: screenshot shows
  the wall up; walking at it does not get out; after Run the wall is gone. Output has no errors.
- [ ] **Step 5: Commit** `Bigger sealed boss arenas` (DESIGN.md 5.10 Arenas bullet: radius 36, sealed while a fight runs).

### Task 2: Boss intro, music and phase moments

**Files:**
- Modify: `src/shared/Config/Bosses.luau` (INTRO_SECONDS, INTRO_CAMERA_SECONDS, MUSIC_ID, MUSIC_VOLUME, per-boss `title`)
- Modify: `src/server/Services/BattleService.luau` (Fight.startsAt, intro gate)
- Modify: `src/client/Controllers/BattleController.luau` (intro camera, name card, music, shake)
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Produces: `BattleStarted` payload field `intro: number?` (seconds; bosses only).
- Produces: `Fight.startsAt: number` (os.clock(); 0 for non-boss fights).

- [ ] **Step 1: Write the failing test:**

```lua
["intro: the camera part ends before the 3-2-1 countdown starts"] = function()
	expect.equal(Bosses.INTRO_SECONDS, 6, "intro length")
	expect.equal(Bosses.INTRO_SECONDS - Bosses.INTRO_CAMERA_SECONDS >= 3, true, "room for 3, 2, 1")
	for id, boss in Bosses.BOSSES do
		expect.equal(typeof(boss.title) == "string" and #boss.title > 0, true, `{id} has a title`)
	end
end,
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** Config `INTRO_SECONDS = 6`, `INTRO_CAMERA_SECONDS = 3`, `MUSIC_ID = ""` (filled in
  step 4), `MUSIC_VOLUME = 0.5`; titles: Meadow Warden "Guardian of the Meadow", Cave Brood Queen "Mother of the
  Deep", Ember Colossus "The Walking Furnace" (Frontier titles in Task 3). Server: `startFight` sets
  `fight.startsAt = os.clock() + Bosses.INTRO_SECONDS` for bosses; `stepFights` skips `BattleSim.step` (still runs
  `keepNear` and member checks) while `os.clock() < fight.startsAt`; `onCallIn`, `onUseAbility` and `onRun` return
  early during the intro; `BattleStarted` gets `intro = Bosses.INTRO_SECONDS`. Client, when `payload.intro`: hide
  the fight bar, set the camera Scriptable and tween it over `INTRO_CAMERA_SECONDS` to a shot 18 studs in front of
  the boss marker and 6 up, looking at it; show a centred name card (boss name in FredokaOne 44, title under it)
  with a small camera shake at 1 s (the roar); then restore `Enum.CameraType.Custom`, show the bar and call
  `showCountdown(Bosses.INTRO_SECONDS - Bosses.INTRO_CAMERA_SECONDS)`. Music: when `MUSIC_ID ~= ""`, a looped Sound
  in SoundService plays from the intro, fades out over 1 s on BattleEnded. Phase moments: the existing heal and
  enrage events (and Task 5's shield, break, thunderclap, spawn events) also call a short camera shake
  (0.3 s, 0.4 studs).
- [ ] **Step 4: Music id.** With the Studio MCP `search_asset` tool find a Roblox-owned (APM) audio track that fits
  a boss fight ("epic battle"/"boss"), confirm it plays in Studio, set `MUSIC_ID`. If none is usable, leave `""`
  and ledger a ruling.
- [ ] **Step 5: Verify.** `lune run tests/run` all pass; Play `/boss 1 fight`: screenshots of the camera shot with
  the name card and of "3"; the boss HP does not move during the intro; the fight then runs; no Output errors.
- [ ] **Step 6: Commit** `Boss intro, music and phase shakes` (DESIGN.md 5.10: intro bullet; remove the item from
  section 13).

### Task 3: Frontier bosses in the config, items and trophies

**Files:**
- Modify: `src/shared/Config/Bosses.luau` (types: `place`, mechanics types; bosses 4-6; LADDER; Colossus fragment)
- Modify: `src/shared/Config/Items.luau` (3 fragments, goldSeal, 3 trophies)
- Modify: `src/shared/Config/Shelves.luau` (3 trophy entries like `trophy_meadowWarden`)
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Produces: `Boss.place: "Wild" | "Frontier"` (bosses 1-3 "Wild"); `Boss.title: string`.
- Produces: `Mechanics` additions (also exported from BattleSim in Task 4):
  `shield: { every: number, fraction: number, breakStun: number }?`,
  `thunderclap: { every: number, seconds: number, minFactor: number, maxFactor: number }?`,
  `adds: { at: { number }, count: number, hpShare: number, atkShare: number, guard: number, species: string }?`
- Produces: item ids `fragment_frostTyrant`, `fragment_stormSovereign`, `fragment_riftDevourer`, `goldSeal`,
  `trophy_frostTyrant`, `trophy_stormSovereign`, `trophy_riftDevourer`.

- [ ] **Step 1: Write the failing tests:**

```lua
["config: the Frontier bosses sit in Frontier zones"] = function()
	expect.equal(#Bosses.LADDER, 6, "six bosses")
	for index, id in Bosses.LADDER do
		local boss = Bosses.BOSSES[id]
		local world = if boss.place == "Frontier" then Frontier else Wild
		expect.equal(world.ZONES[boss.zone] ~= nil, true, `{id} zone`)
		expect.equal(boss.place, if index <= 3 then "Wild" else "Frontier", `{id} place`)
	end
end,

["read: Frontier bosses start locked"] = function()
	expect.equal(BossRules.read(nil, Bosses.BOSSES.frostTyrant.unlock == nil).unlocked, false, "needs its key")
end,
```
(require `Config/Frontier` and `Config/Wild` at the top of the spec). The existing ladder tests
("every boss after the first unlocks...", "the ladder can be climbed") must pass for 6 bosses; ShelvesConfig and
ItemRules specs must still pass with the new items and trophies.
- [ ] **Step 2: Run** — Expected: FAIL (`#LADDER` is 3).
- [ ] **Step 3: Implement** the table at the top of this plan in `Config/Bosses` (ids `frostTyrant`,
  `stormSovereign`, `riftDevourer`), Ember Colossus `fragment = "fragment_frostTyrant"` with a 60% drop; items with
  name/icon/description/source/use like the existing ones (Gold Seal icon 🥇, use "Grading Station → Use a Gold Seal
  (pays one step's cash)"); trophy shelves copying the trophy_meadowWarden entry.
- [ ] **Step 4: Run** — Expected: all pass.
- [ ] **Step 5: Commit** `Frontier bosses 4-6 in the config` (DESIGN.md 5.10 tables: three new rows each).

### Task 4: Shield, thunderclap and adds in the sim

**Files:**
- Modify: `src/server/Util/BattleSim.luau`
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- Consumes: Task 3 `Mechanics` shapes.
- Produces events: `{type="shield", to=bossId, heal=amount}`, `{type="shieldBreak", to=bossId}`,
  `{type="thunderclap", from=bossId}` then `{type="stun", to=fighterId, damage=seconds}`,
  `{type="spawn", from=bossId, to=addId}` (add ids `b:add1`, `b:add2`, ...; each add a Fighter on side B with
  `boss = false`, `element` = the boss's).
- Rules: a side whose boss faints loses at once (adds alive or not); targeting prefers standing non-boss enemies when
  any exist; damage to a boss is x `adds.guard` while any of its adds stands; the shield uses `side.shield` (so the
  existing absorb path applies) and its break stun ignores `BOSS_MAX_STUN`.

- [ ] **Step 1: Write the failing tests** (helper `bossWith(mechanics, seed)`: one strong fighter vs a boss input
  `{ boss = true, mechanics = ..., hp = 10000 }`):
  - `shield: goes up every 20 s and absorbs damage first` — after stepping to 20.1 s, `state.sides.b.shield ==
    round(10000 * 0.06)` and a "shield" event fired; boss HP unchanged by the next hit that the shield covers.
  - `shield: breaking it stuns the boss for 3 s` — after the shield reaches 0 a "shieldBreak" event fired and the
    boss's `stunUntil - time` is 3 (not capped at 1).
  - `thunderclap: slower creatures stay stunned longer` — two fighters SPD 5 and SPD 30 vs boss SPD 14, `every = 12,
    seconds = 3, minFactor = 0.3, maxFactor = 1.5`: at 12.1 s the slow one's stun is 4.5 s, the fast one's 1.4 s.
  - `adds: two Spawn at 70% and two more at 35%` — set boss hp to 69%: 2 "spawn" events, side B has 3 fighters;
    to 34%: 5 fighters.
  - `adds: creatures hit the Spawn first and the boss takes half damage meanwhile` — next attack's `to` is an add id;
    a direct `hit` on the boss with adds standing deals half of the same hit without adds (compare two seeded states).
  - `adds: the boss falling ends the fight with Spawn alive` — boss hp to 1 with adds standing, one hit: result "a".
- [ ] **Step 2: Run** — Expected: the six FAIL.
- [ ] **Step 3: Implement** in `bossMechanics` (timers on the boss fighter: `shieldReady`, `clapReady`,
  `addsDone: { [number]: boolean }`), `targetOf` (non-boss first), `hit` (guard factor), `takeDamage` (boss faint
  ends the fight; detect the side shield breaking where it is absorbed in `hit`). Snapshot carries adds like any
  fighter.
- [ ] **Step 4: Run** — Expected: all pass (existing heal/enrage/PvP tests unchanged).
- [ ] **Step 5: Commit** `Boss shield, thunderclap and adds in the sim`.

### Task 5: Frontier arenas, Spawn markers and the fight HUD

**Files:**
- Modify: `src/server/init.server.luau` (start BossService in the Frontier after BattleService)
- Modify: `src/client/init.client.luau` (BossBoardController in the Frontier)
- Modify: `src/server/Services/WildService.luau` (BuildBossArenas: only bosses with `place` of this place)
- Modify: `src/server/Services/BattleService.luau` (spawn events → add monsters; markers; cleanup)
- Modify: `src/server/Services/DevService.luau` (`/boss <1-6>`)
- Modify: `src/client/Controllers/BattleController.luau` (banners, boss shield on the bar, stun numbers, adds row)
- Modify: `src/client/Controllers/BossBoardController.luau` (6 bosses; "In the Frontier" / "In the Wild" line)

**Interfaces:**
- Consumes: Task 4 events; `WildService.SpawnAt(position, species, level, elite, boss?)`, `WildService.Lock`,
  `WildService.Defeat`, `WildService.SetFightPose`.
- Produces: `Fight.adds: { [string]: Monster }` (sim id -> its monster).

- [ ] **Step 1: Implement.** "spawn" → `SpawnAt` next to the boss (`Bosses.BOSS_SPOT` sideways), `Lock` it to the
  fight leader, `fight.adds[to] = monster`, include its marker in the broadcast `markers`; `markerFor`/`place`
  resolve add ids; an add's "faint" → `Defeat`; `endFight` defeats every remaining add. The `/boss` usage text says
  `1-6`; using a gate of the other place says "That boss is in the Frontier/Wild." Client banners: "Ice shield!"
  (light blue), "Shield broken!", "Thunderclap!", "Rift Spawn!"; "stun" floats "Stunned" over the fighter; the boss
  bar's text shows `+<n> shield` while `sides.b.shield > 0`; in boss fights the adds show as small bars in the ally
  row area (reuse `buildEnemies` with the monster HP colour).
- [ ] **Step 2: Verify.** `lune run tests/run` all pass. `rojo serve frontier.project.json`, Play the Frontier
  place, `/rest`, `/item fragment_frostTyrant 5`, `/boss 4`, `/boss 4 fight`: screenshots of the shield banner and
  bar; `/boss 6 fight` (with `/item` fragments) shows Spawn models and their bars; Output clean. Main place: board
  lists 6 bosses, Frontier ones marked.
- [ ] **Step 3: Commit** `Frontier boss arenas, Spawn and mechanic HUD` (CLAUDE.md dev commands `/boss <1-6>`;
  DESIGN.md 5.10 mechanics bullets).

### Task 6: Gold Seals at the Grading Station

**Files:**
- Modify: `src/shared/Util/CondenseRules.luau` (goldSealAllowed)
- Modify: `src/server/Services/CardService.luau` (`GradeUp` pay callback gets the target grade)
- Modify: `src/server/Services/GradingService.luau` (7th remote arg `useGold`)
- Modify: `src/shared/Remotes.luau` (GradeUp comment: `useGold`)
- Modify: `src/client/Controllers/GradingController.luau` (Gold Seal toggle)
- Test: `tests/CondenseRules.spec.luau`

**Interfaces:**
- Produces: `CondenseRules.goldSealAllowed(rarity: string, toGrade: string): boolean`.
- Changes: `CardService.GradeUp(player, cardId, main, pay: (cash: number, grade: string) -> boolean, seals: number?)`.

- [ ] **Step 1: Write the failing test:**

```lua
["goldSealAllowed: any step except a Legendary's A to S"] = function()
	expect.equal(CondenseRules.goldSealAllowed("Legendary", "S"), false, "the chase stays paid")
	expect.equal(CondenseRules.goldSealAllowed("Legendary", "A"), true, "B to A is fine")
	expect.equal(CondenseRules.goldSealAllowed("Epic", "S"), true, "other rarities to S")
end,
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** GradingService: `useGold` must be `true` (boolean) to count; the pay callback uses one
  Gold Seal instead of `TrySpend` only when the player has one and `goldSealAllowed(card.rarity, grade)`; take the
  seal in the same step after success; notify "(used a Gold Seal)". Client: a second toggle under the Grading Seal
  one: "🥇 Use a Gold Seal: pays the $<cash> (you have n)", "🥇 Gold Seals can't pay a Legendary's A to S step",
  "🥇 No Gold Seals (Frontier bosses drop them)"; the cost line shows `$0 (Gold Seal)` when on.
- [ ] **Step 4: Verify.** `lune run tests/run` all pass; Play, `/item goldSeal 1`, grade a Rare with the toggle on:
  cash unchanged, seal gone; Output clean.
- [ ] **Step 5: Commit** `Gold Seals at the Grading Station` (DESIGN.md 5.9 Grading Station: Gold Seal line).

### Task 7: Boss loot scattered on the ground (personal)

Approved: when a boss dies, each player's item loot (drops, first-clear chest, daily bonus, trophy) pops out of the
boss and scatters on the ground. Only its owner sees and can pick up their drops. Walking over a drop picks it up.
Anything left is collected by itself after 60 s, and everything still pending is collected when the player leaves,
teleports or disconnects (never lose items). Cash and XP stay instant.

**Files:**
- Modify: `src/shared/Config/Bosses.luau` (LOOT_PICKUP_DISTANCE = 8, LOOT_AUTO_SECONDS = 60, LOOT_SCATTER = { min = 4, max = 10 }, LOOT_CLIENT_REACH = 5)
- Modify: `src/shared/Util/BossRules.luau` (scatter)
- Modify: `src/shared/Remotes.luau` (`BossLoot` server → client, `PickUpLoot` client → server)
- Modify: `src/server/Services/BossService.luau` (pending loot instead of instant grants; pickup; auto-collect)
- Create: `src/client/Controllers/LootController.luau` (drops, pop and bob, walk-over pickup, fly-to-player)
- Modify: `src/client/init.client.luau` (start LootController in both places)
- Modify: `src/client/Controllers/BattleController.luau` (end screen line "Your loot is on the ground")
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Produces: `BossRules.scatter(count: number, minRadius: number, maxRadius: number, turn: number): { { x: number, z: number } }`
  — offsets from the boss, one per drop, evenly spread round the circle starting at angle `turn` (radians), radius
  alternating between min and max so neighbours never overlap.
- Produces: `BossLoot` payloads: `{ drops = { { id: string, item: string, count: number, x: number, y: number, z: number } }, from = { x, y, z } }`
  and `{ taken = id }` (picked up or auto-collected).
- Produces: `PickUpLoot(id: string)`: the server grants only if the id is pending for that player and their root is
  within `LOOT_PICKUP_DISTANCE` of the drop; rate-limited with `RateLimiter` (0.1 s).

- [ ] **Step 1: Write the failing tests:**

```lua
["scatter: every drop lands in the ring, none on another"] = function()
	local spots = BossRules.scatter(7, Bosses.LOOT_SCATTER.min, Bosses.LOOT_SCATTER.max, 0.3)
	expect.equal(#spots, 7, "one per drop")
	for index, spot in spots do
		local distance = math.sqrt(spot.x ^ 2 + spot.z ^ 2)
		expect.equal(distance >= Bosses.LOOT_SCATTER.min - 1e-9 and distance <= Bosses.LOOT_SCATTER.max + 1e-9, true, `spot {index} in the ring`)
		for other = index + 1, #spots do
			local gap = math.sqrt((spot.x - spots[other].x) ^ 2 + (spot.z - spots[other].z) ^ 2)
			expect.equal(gap > 1.5, true, `spots {index} and {other} apart`)
		end
	end
	expect.equal(#BossRules.scatter(0, 4, 10, 0), 0, "no loot, no spots")
end,
```
Add `"scatter"` to the export list test.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** BossService: where a win now gives items, build the player's list instead (one entry
  per item stack, `HttpService:GenerateGUID(false)` ids), place them with `scatter` around the boss's last position
  (y from a downward raycast, fall back to the boss's y), store them in `pending[player][id] = { item, count,
  position, expiresAt = os.clock() + LOOT_AUTO_SECONDS }` and fire `BossLoot` to that player only. A 1 s loop grants
  expired entries (fires `{ taken = id }`); `DataService.OnBeforeLeave` grants everything pending for the leaver
  before the save. Win summary text keeps listing the loot (the end screen adds "Pick it up from the ground").
  LootController: per drop a small glowing ball in the item's colour with a BillboardGui (item icon emoji + count),
  tweened from `from` in a 0.6 s arc to its spot, bobbing and spinning; within `LOOT_CLIENT_REACH` of the character
  it fires `PickUpLoot` once; on `{ taken = id }` it flies to the player, shows "+n <item name>" and is destroyed.
  Nothing is created on other clients.
- [ ] **Step 4: Verify.** `lune run tests/run` all pass. Play `/boss 1 fight` to a win: screenshot of the drops on
  the ground; walking over one takes it (Bag count goes up); the rest go into the Bag after 60 s; a 2-player Local
  Server shows each player only their own drops; leaving with drops pending keeps them (rejoin: Bag has them).
- [ ] **Step 5: Commit** `Boss loot scattered on the ground` (DESIGN.md 5.10 loot bullet).

### Task 8: Docs and vault

- [ ] DESIGN.md 5.10 heading "phase 1-3", the board/UI bullets, roadmap line; CLAUDE.md test list if a spec file was
  added; Obsidian: Decisions log (phase 3 built), Core loop and economy (Gold Seals, Frontier bosses), Lessons
  learned (anything that bit). Commit `Boss phase 3 docs`.
