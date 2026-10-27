# Boss Ladder Phase 1 (Wild bosses 1-3, solo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three solo Wild bosses on a key-gated ladder, with heal/enrage mechanics, fragments, XP Tonics, Grading Seals, farm protection, shop trophies and a boss board.

**Architecture:** A boss is a Wild `Monster` with a `boss` id, spawned privately at its zone's arena when the owner starts it and fought on the existing combat core (`BattleSim`, `BattleService`). Pure rules (unlock, loot eligibility, soft cap, over-power, drops) live in `Util/BossRules` and are Lune-tested; `BossService` owns the saved boss state and grants rewards through a hook `BattleService` calls on a boss win. Items go through `ItemService`, cash through `EconomyService`.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-28-boss-ladder-design.md` (phase 1 = section 10 item 1).

## Global Constraints

- Server authoritative; every remote in `src/shared/Remotes.luau`, args validated, rate-limited with `Util/RateLimiter`.
- All numbers in `src/shared/Config` (`Config/Bosses.luau` for bosses). No magic numbers in services.
- Saved state through `DataService.Register({ name, load, save, unload })`; `save` does nothing if `load` never ran.
- Schema change: bump `SCHEMA_VERSION` to 12, add `MIGRATIONS[11]` with a Lune test, update DESIGN.md 10.4.
- Items are account-bound: never tradeable or sellable.
- UI built in code with `Util/UIKit`; tap targets >= 48 px; text plain ASCII plus `·` and emoji.
- Pure modules have no requires and no Roblox APIs (tests/SourceOrder enforces declaration order).
- Farm protection values (spec section 7): loot cooldown 15 min per boss (saved Unix time), soft cap after 6 rewarded kills a day, x0.75 per further kill, floor x0.2, over-power above 2.5x recommended, `MIN_FIGHT_SECONDS` per boss.
- Unlock costs: boss 1 open, boss 2 needs 3 fragments from boss 1, boss 3 needs 5 from boss 2.

## Review Focus

- A player hops servers or rejoins mid-cooldown: full loot stays on cooldown (lootAt is saved Unix time). Test in Task 1 (`lootEligible`) and Task 4 (migration keeps `lootAt`).
- The UTC day rolls over between two kills: `rewardedToday` resets and the daily bonus is offered again. Test in Task 1 (`dayCounts`).
- A player starts a boss they haven't unlocked, or without the fragments: refused, no fragments taken. Test in Task 1 (`canStart`); server check in Task 6.
- The player leaves or dies mid boss fight: the private boss despawns, nothing is granted, no key is lost after the first clear. Covered in Task 6 Studio check.
- A Grading Seal toggle with more seals than the step allows: only half the step's duplicates are covered. Test in Task 5.

---

### Task 1: Boss config and pure rules

**Files:**
- Create: `src/shared/Config/Bosses.luau`
- Create: `src/shared/Util/BossRules.luau`
- Test: `tests/BossRules.spec.luau` (add `BossRules = require("./BossRules.spec")` to `tests/run.luau`)

**Interfaces:**
- Produces `Config/Bosses` (plain data): `LADDER = { "meadowWarden", "caveBroodQueen", "emberColossus" }`, `BOSSES[id] = { name, zone (1-3, Config/Wild ZONES index), shape (a Wild placeholder shape: "slime", "bat", "golem"), scale (placeholder size x the monster height: 2.5, 2.8, 3.2), element, level, hp, atk, spd, recommended, minFightSeconds, unlock = { item: string, count: number }?, fragment: string? (item id of the NEXT boss's fragment it drops), mechanics = { heal = { below, fraction, cooldown }?, enrage = { below, atkMultiplier }? }, drops = { { item, chance, min, max } }, firstClear = { { item, count } }, dailyBonus = { { item, count } }, cash, xp }`; `LOOT_COOLDOWN = 900`, `SOFT_CAP_AFTER = 6`, `SOFT_CAP_STEP = 0.75`, `SOFT_CAP_FLOOR = 0.2`, `OVERPOWER_RATIO = 2.5`, `OVERPOWER_FACTOR = 0.35`, `GATE_DISTANCE = 12`, `START_COOLDOWN = 2`.
- Produces `BossRules` (pure):
  - `export type Record = { unlocked: boolean, cleared: boolean, lootAt: number, day: number, rewardedToday: number, bonusDay: number }`
  - `BossRules.read(saved: unknown, startsOpen: boolean): Record` (bad fields -> safe defaults)
  - `BossRules.dayNumber(unixTime: number): number` (`math.floor(unixTime / 86400)`)
  - `BossRules.dayCounts(record: Record, today: number): Record` (new day -> `rewardedToday = 0`, `day = today`)
  - `BossRules.canStart(record: Record, unlock: { item: string, count: number }?, owned: number): (boolean, string?)` -> reasons `"locked:<have>:<need>"`
  - `BossRules.lootEligible(record: Record, now: number): boolean`
  - `BossRules.softCapFactor(config, rewardedToday: number): number`
  - `BossRules.overPowerFactor(config, partyPower: number, recommended: number): number`
  - `BossRules.dropFactor(config, record: Record, partyPower: number, recommended: number): number` (product of the two)

Boss numbers to put in the config (tunable later):

| id | name | zone | element | level | hp | atk | spd | recommended | minFightSeconds | mechanics | unlock |
|---|---|---|---|---|---|---|---|---|---|---|---|
| meadowWarden | Meadow Warden | 1 | Bloom | 6 | 1200 | 9 | 8 | 200 | 12 | none | none |
| caveBroodQueen | Cave Brood Queen | 2 | Shade | 11 | 2600 | 13 | 12 | 350 | 18 | heal below 0.5: +0.15 max HP every 12 s | 3 x `fragment_caveBroodQueen` |
| emberColossus | Ember Colossus | 3 | Ember | 16 | 4800 | 18 | 9 | 650 | 25 | enrage below 0.5: ATK x1.5 | 5 x `fragment_emberColossus` |

Drops: Warden `xpTonic` 60% (1-2) + `fragment_caveBroodQueen` 70% (1); Queen `xpTonic` 60% (1-3), `starShard` 15% (1), `fragment_emberColossus` 60% (1); Colossus `gradingSeal` 35% (1), `xpTonic` 40% (2-3), `fragment_frostTyrant` 0 (phase 3). First clear: 3 fragments of the next boss + `trophy_<id>` x1 + 3 of its main item. Daily bonus: 2 of its main item. Cash = level x 6, xp = Wild XP formula x 5.

- [ ] **Step 1: Write the failing tests** in `tests/BossRules.spec.luau`:
  - `"read: bad saves become safe defaults"`: `BossRules.read(nil, true).unlocked == true`, `BossRules.read({ lootAt = -5, rewardedToday = 0/0 }, false)` -> `lootAt == 0`, `rewardedToday == 0`, `unlocked == false`.
  - `"canStart: open bosses start, locked ones need the fragments"`: unlocked record -> `true`; locked with `{ item = "fragment_caveBroodQueen", count = 3 }` and owned 2 -> `false, "locked:2:3"`; owned 3 -> `true`.
  - `"lootEligible: once the saved cooldown has passed"`: `lootAt = 1000` -> `false` at now 999, `true` at 1000.
  - `"dayCounts: a new UTC day resets today's kills"`: `{ day = 5, rewardedToday = 9 }` with today 6 -> `rewardedToday == 0, day == 6`; same day -> unchanged.
  - `"softCapFactor: full for 6 kills, then x0.75 each, never under 0.2"`: kills 0..5 -> 1; 6 -> 0.75; 7 -> 0.5625; 40 -> 0.2.
  - `"overPowerFactor: far above the recommended Power drops less"`: power 500 vs 200 -> 1; 501 vs 200 -> 0.35.
  - `"config: every boss after the first unlocks with the fragment the one before drops"`: for `i > 1`, `BOSSES[LADDER[i]].unlock.item == BOSSES[LADDER[i-1]].fragment`; boss 1 has no `unlock`; every drop `chance` in 0..1.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (module not found).
- [ ] **Step 3: Implement** `Config/Bosses.luau` with the values above and `Util/BossRules.luau` with the signatures above (`softCapFactor = max(FLOOR, STEP ^ max(0, kills - (AFTER - 1)))` for kills >= AFTER, else 1).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git add src/shared/Config/Bosses.luau src/shared/Util/BossRules.luau tests/BossRules.spec.luau tests/run.luau && git commit -m "Boss ladder config and pure rules"`

### Task 2: Boss items

**Files:**
- Modify: `src/shared/Config/Items.luau`
- Test: `tests/ItemRules.spec.luau`

**Interfaces:**
- Produces item ids: `fragment_caveBroodQueen`, `fragment_emberColossus`, `xpTonic`, `gradingSeal`, `trophy_meadowWarden`, `trophy_caveBroodQueen`, `trophy_emberColossus`. Each entry has `name, icon, description, source, use`. `xpTonic` also `xp = 400`. Trophy entries `trophy = true`.

- [ ] **Step 1: Write the failing test** `"every boss drop, unlock and first-clear item exists in Config/Items"`: load `Config/Bosses` and `Config/Items`; assert each `drops[].item`, `unlock.item`, `firstClear[].item`, `dailyBonus[].item` is in `Items.ITEMS` (skip `fragment_frostTyrant`, phase 3, by checking `chance > 0`).
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL naming the missing items.
- [ ] **Step 3: Add the entries** to `Config/Items.ITEMS` (descriptions: fragment "N open the <boss>", XP Tonic "Gives one creature 400 XP. Use it from the Party panel.", Grading Seal "Counts as one duplicate at the Grading Station (up to half a step).", trophy "Place it in your shop from Build -> Trophies.").
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git commit -am "Boss items: fragments, XP Tonic, Grading Seal, trophies"`

### Task 3: Boss mechanics in the battle sim

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`FighterInput`, `Fighter`, `makeFighter`, `BattleSim.step`)
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- Consumes: `Config/Bosses` mechanics shape (Task 1).
- Produces: `FighterInput.mechanics: { heal: { below: number, fraction: number, cooldown: number }?, enrage: { below: number, atkMultiplier: number }? }?`; new events `{ type = "heal", to, heal }` and `{ type = "enrage", from }`; `FighterInput.boss: boolean?` (bosses can't be stunned for longer than 1 s and ignore `canRun` checks only on their side, i.e. no change for the player's Run).

- [ ] **Step 1: Write the failing tests**:
  - `"a boss heals once under half HP, then waits its cooldown"`: boss input hp 1000 with `heal = { below = 0.5, fraction = 0.15, cooldown = 12 }`; drive hits until HP < 500; step 0.1 s; expect one `heal` event of 150; step 5 s more -> no second heal; step 8 s -> a second heal.
  - `"a boss enrages once under half HP"`: `enrage = { below = 0.5, atkMultiplier = 1.5 }`; after HP < 500 exactly one `enrage` event and its later hits use atk x1.5 (compare damage before/after with fixed seed).
  - `"fighters without mechanics never heal or enrage"`: existing monster input -> no such events over a full fight.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement**: store `mechanics`, `healReady`, `enraged` on the fighter; check them in `BattleSim.step` after the burn pass for each standing fighter.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git commit -am "Battle sim: boss heal and enrage mechanics"`

### Task 4: Saved boss state (schema v12) and BossService skeleton

**Files:**
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 12`), `src/server/Util/Migrations.luau` (`[11]`), `src/server/Services/DataService.luau` (type + `TEMPLATE.bosses = {}`)
- Create: `src/server/Services/BossService.luau` (load/save/unload only in this task), start it in `src/server/init.server.luau` (main place branch, before `DataService.Start()`)
- Test: `tests/Migrations.spec.luau`

**Interfaces:**
- Produces: `data.bosses: { [bossId]: BossRules.Record }`; `BossService.GetRecord(player: Player, bossId: string): BossRules.Record?`; `BossService.Start()`.

- [ ] **Step 1: Write the failing test** `"v12: adds an empty bosses table, keeps existing"` (version 11 -> 12; `data.bosses` is an empty table; an existing `bosses.meadowWarden.lootAt = 123` is kept).
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** the migration, type, template, and BossService load (`BossRules.read(data.bosses[id], id == LADDER[1])` for each ladder boss), save (only if loaded), unload.
- [ ] **Step 4: Run** `lune run tests/run` and `rojo build -o <scratch>/test.rbxl`. Expected: pass, builds.
- [ ] **Step 5: Commit** `git commit -am "Save boss state (schema v12), BossService load and save"`

### Task 5: Grading Seals at the Grading Station

**Files:**
- Modify: `src/shared/Util/CondenseRules.luau` (`gradePlan` gains `seals: number?`), `src/shared/Config/Grading.luau` (`MAX_SEAL_SHARE = 0.5`), `src/server/Services/CardService.luau` (`GradeUp(..., seals: number?)` returns seals used), `src/server/Services/GradingService.luau` (6th remote arg `useSeals: boolean`, takes used seals via `ItemService.TakeItem` in the same step), `src/client/Controllers/GradingController.luau` (Seal toggle like the Condenser's Star Shard toggle, count from `ItemsChanged.gradingSeal`), `src/shared/Remotes.luau` (GradeUp comment)
- Test: `tests/CondenseRules.spec.luau`

**Interfaces:**
- Produces: `CondenseRules.gradePlan(grading, config, rarity, byGrade, main, seals: number?): (GradePlan?, string?)` where `GradePlan.seals: number` (used). Seals cover `min(missing, floor(copies * MAX_SEAL_SHARE), seals)`; real duplicates first.

- [ ] **Step 1: Write the failing tests**: `"grading seals cover missing duplicates, at most half a step"`: Legendary A->S needs 3; with 2 real duplicates and 5 seals -> plan with `seals == 1`; with 0 real and 5 seals -> `nil, "short:0:3"` (half of 3 is 1); without seals unchanged behaviour (existing tests still pass).
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** the plan change, server take (GradeUp reports seals used; GradingService calls `ItemService.TakeItem(player, "gradingSeal", used)` right after a successful `CardService.GradeUp`, no yields between), and the client toggle.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: pass. Studio: with `gradingSeal` given via a new Studio command `/item <id> <n>` (DevService), a Legendary A->S with 2 copies + seal grades up and the seal count drops by 1.
- [ ] **Step 5: Commit** `git commit -am "Grading Seals cover duplicates at the Grading Station"`

### Task 6: Boss fights and rewards

**Files:**
- Modify: `src/server/Services/WildService.luau` (`Monster.boss: string?`; `WildService.BuildBossArenas(onGate: (player, bossId) -> ())` builds a fenced ring and gate part with a server ProximityPrompt "Fight boss" at the end of each zone; `WildService.SpawnAt` accepts an optional `boss: string?`)
- Modify: `src/server/Services/BattleService.luau` (`BattleService.Start(player, monster): boolean` public; boss stats from `Config/Bosses` when `monster.boss`; `mechanics` and `boss = true` passed to the sim; `BattleService.SetBossRewards(handler: (player, monster, fight: { seconds: number, partyIds: { string } }) -> any)` called from `payOut` for bosses instead of the Wild drop roll; result extras merged into the `BattleEnded` summary as `summary.boss`)
- Modify: `src/server/Services/BossService.luau` (gate handler: rate limit `START_COOLDOWN`, distance `GATE_DISTANCE`, `canStart` with `ItemService.GetCount`, consume the key on the first start only (sets `unlocked = true`), spawn the private boss with `WildService.SpawnAt(arenaPoint, bossDef.name, level, false, bossId)`, `BattleService.Start`; rewards handler applying `dayCounts`, `lootEligible`, `dropFactor`, `minFightSeconds`, first clear, daily bonus; announces first clears with `Remotes.PullAnnouncement`-style chat via a new remote `BossCleared`)
- Modify: `src/shared/Remotes.luau` (`BossCleared`, `BossesChanged`, `RequestBosses`)
- Modify: `src/server/Services/DevService.luau` (`/item <id> <n>`, `/boss <n>` teleports to boss n's gate)

**Interfaces:**
- Consumes: Task 1 `BossRules`, Task 3 sim inputs, Task 4 `BossService.GetRecord`.
- Produces: `BossesChanged` payload `{ [bossId] = { unlocked, cleared, lootIn: number (seconds), rewardedToday, fragments: number } }` sent on load and after every boss fight; `BattleEnded.summary.boss = { bossId, items = { { item, count } }, firstClear: boolean, bonus: boolean, lootIn: number, reduced: boolean }`.

- [ ] **Step 1: Studio check plan written down first** (no Lune test: this is service wiring; its rules are Task 1's): in Play, `/boss 1`, fight the Warden: win -> fragments and tonics granted, `lootIn` ~900; fight again at once -> XP and cash only; leave and rejoin -> still on cooldown; `/boss 2` without fragments -> "Needs 3 fragments"; with 3 -> starts and consumes them once.
- [ ] **Step 2: Implement** the WildService, BattleService and BossService changes above.
- [ ] **Step 3: Run** `lune run tests/run` (all pass) and `rojo build`, then the Studio checks from Step 1 with screenshots of the arena and a fight.
- [ ] **Step 4: Commit** `git commit -am "Wild bosses: arenas, gated fights, rewards with farm protection"`

### Task 7: Using XP Tonics

**Files:**
- Modify: `src/shared/Remotes.luau` (`UseXpTonic`: client -> server `(beastId: string)`), `src/server/Services/PartyService.luau` (handler: rate limit, the beast is in the player's party, `ItemService.TakeItem(player, "xpTonic", 1)` then `CardService.AddXP(player, beastId, Items.ITEMS.xpTonic.xp)`; refuse at max level without taking the tonic), `src/client/Controllers/PartyController.luau` (`buildCardRow`: a "+XP Tonic (n)" button when the count > 0)

**Interfaces:**
- Consumes: Task 2 `xpTonic.xp`.

- [ ] **Step 1: Studio check written down**: give 2 tonics (`/item xpTonic 2`), use one on a party card -> its level/XP rises, count 1; a Lv 30 card -> refused, count unchanged.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** tests, build, Studio check.
- [ ] **Step 4: Commit** `git commit -am "Use XP Tonics from the Party panel"`

### Task 8: Shop trophies

**Files:**
- Modify: `src/shared/Config/Shelves.luau` (kind `"Trophy"`, category `"Trophies"`, one entry per boss: `trophy_meadowWarden` etc., `requiresItem = "trophy_<id>"`, cost 0, unlockLevel 1, size 4x5x4), `src/server/Services/PlacementService.luau` (placing takes the trophy item, selling gives it back, refund 0; `isMachine`-style helper for "holds nothing"), `src/client/Controllers/BuildController.luau` (Trophies tab; a trophy tile is locked until the item is owned, "Beat the <boss>"), `src/shared/Util/Props.luau` + `src/shared/Config/Town.luau` (`TROPHY_LOOK`: a plinth with a gold cup and the boss's element colour)
- Test: `tests/ShelvesConfig.spec.luau` (byKind gains `Trophy = "Trophies"`)

- [ ] **Step 1: Update the failing test** (byKind) and run `lune run tests/run`. Expected: FAIL until the entries exist.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** tests; Studio: after a first clear the trophy tile unlocks, places, shows in the shop, and selling it returns the item.
- [ ] **Step 4: Commit** `git commit -am "Boss trophies you can place in your shop"`

### Task 9: Boss board and fight UI

**Files:**
- Create: `src/client/Controllers/BossBoardController.luau` (HUD tile "Bosses" via `Util/Hud`; panel listing the ladder: name, lock and fragments x/N, recommended Power vs your best party Power, loot ready / ready in m:ss, today's kills and "reduced drops" note, trophy badge once cleared; data from `BossesChanged`, requested with `RequestBosses` on start)
- Modify: `src/client/Controllers/BattleController.luau` (boss fights: a wide boss HP bar at the top, "Enraged!" / "Healing!" banners from the new events, results lines from `summary.boss`)
- Modify: `src/client/init.client.luau` (start BossBoardController)

- [ ] **Step 1: Studio check written down**: board opens from the HUD tile on PC and phone-size; locked boss shows fragments 0/3; after a win the board updates without reopening; HP bar and banners show in a Queen and a Colossus fight; results list items and the cooldown.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** tests, build, Studio check with screenshots.
- [ ] **Step 4: Commit** `git commit -am "Boss board and boss fight HUD"`

### Task 10: Docs and wrap-up

**Files:**
- Modify: `DESIGN.md` (new section for the boss ladder phase 1 with the tables from Config/Bosses; 10.4 schema v12 with `bosses`; the roadmap line "phase 1 done"; file tree entries for BossService, BossBoardController, Config/Bosses, Util/BossRules), `CLAUDE.md` (BossRules in the test list; `/item`, `/boss` Studio commands)
- Obsidian: `Core loop and economy.md` (phase 1 status), `Decisions log.md`

- [ ] **Step 1: Update the docs.**
- [ ] **Step 2: Run** `lune run tests/run` (all pass) and `rojo build`.
- [ ] **Step 3: Commit** `git commit -am "Boss ladder phase 1 docs"`; merge to main and push after the user approves in Studio.
