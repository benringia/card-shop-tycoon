# Boss Chests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a full-loot boss win, three chests on the reveal stage; the player picks one; it shows the weapon (if it
dropped) or the weapon's material, and the other two show what they held ("?" weapon on a miss).

**Architecture:** The server decides and gives everything at the win (BossService rolls the weapon as today and hands
the result to a new BossChestService, which rolls the material, builds the other two chests, gives the loot and keeps a
pending set). The client only sends a chest index; the server answers with the three contents. Pure rules in
`Util/ChestRules` (Lune-tested); the look in a new client `BossChestController` on `Util/OpeningStage`.

**Tech Stack:** Luau (Roblox), Rojo, Lune tests (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-11-11-boss-chests-design.md`

## Global Constraints

- Server authoritative; every remote in `src/shared/Remotes.luau`, args type- and range-checked, rate-limited with
  `src/server/Util/RateLimiter.luau`.
- Tunable numbers in `src/shared/Config` (plain data, readable from Lune); pure modules in `src/shared/Util` require no
  siblings and no Roblox APIs.
- `--!strict`; UI text plain ASCII plus emoji; tap targets >= 48 px; chests >= 120 px across on a landscape phone.
- Drop odds, pity, grades, refunds and all other loot unchanged; no schema change.
- 3 chests; PICK_SECONDS 20, GRACE 2; MATERIAL weights {1: 0.85, 2: 0.10, 3: 0.05}; others open 0.4 s apart; a miss
  closes on a tap after 1.5 s or by itself after 5 s.
- Docs: DESIGN.md (5.11 Drops, file tree), CLAUDE.md (test list, dev command) in the same change.

## Review Focus

1. A second boss win while a set is still pending (group farming back to back): the old set opens first, nothing lost.
2. Player leaves or teleports between the win and the pick: loot already saved, no error from firing to a gone player.
3. A drop that couldn't be given (weapons not loaded): treated as a miss (material given, pity +1 as today).
4. The chest screen arriving while another stage scene plays (the first clear's victory, a level-up pack): it waits
   for the stage to be free instead of overlapping.
5. Bosses whose material entry is missing from `boss.drops` or a weapon not `ready`: no chests, loot as today.

---

### Task 1: ChestRules and Config/BossChests (pure)

**Files:**
- Create: `src/shared/Config/BossChests.luau`, `src/shared/Util/ChestRules.luau`, `tests/ChestRules.spec.luau`
- Modify: `tests/run.luau` (register `ChestRules`)

**Interfaces:**
- Produces:
  - `export type Content = { kind: "weapon" | "material" | "mystery", weaponId: string?, item: string?, count: number? }`
  - `export type Set = { id: string, bossId: string, weaponId: string, mine: Content, others: { Content }, opened: boolean }`
  - `ChestRules.materialCount(roll: number, weights: { { count: number, weight: number } }): number`
  - `ChestRules.others(dropped: boolean, weaponId: string, material: string, rolls: { number }, weights): { Content }` (2 entries; `rolls` 3 numbers in [0,1): two counts and the order)
  - `ChestRules.layout(index: number, mine: Content, others: { Content }): { Content }` (3 entries, mine at index)
  - `ChestRules.validIndex(raw: unknown, total: number): number?`
  - `ChestRules.canOpen(set: Set?, id: unknown): boolean`
  - `ChestRules.autoIndex(roll: number, total: number): number`
  - `Config/BossChests`: `COUNT = 3, PICK_SECONDS = 20, GRACE_SECONDS = 2, MATERIAL = { { count = 1, weight = 0.85 }, { count = 2, weight = 0.10 }, { count = 3, weight = 0.05 } }, OPEN_GAP = 0.4, SKIP_AFTER = 1.5, CLOSE_AFTER = 5`, plus the look numbers Task 4 adds.

- [ ] **Step 1: Write the failing tests** (`tests/ChestRules.spec.luau`):
  - `materialCount`: roll 0 -> 1, 0.849 -> 1, 0.85 -> 2, 0.949 -> 2, 0.95 -> 3, 0.9999 -> 3; the weights' average
    `sum(count * weight) == 1.2` (within 1e-9) and weights sum to 1.
  - `others(false, ...)`: exactly one `mystery` with the weaponId and one `material` with the material id and a count
    1-3; `rolls[3] < 0.5` puts the mystery first, else second.
  - `others(true, ...)`: two `material` entries, no weapon or mystery.
  - `layout(i, mine, others)` for i = 1, 2, 3: length 3, `result[i] == mine`, the others in their order round it.
  - `validIndex`: 1, 2, 3 -> same; 0, 4, 1.5, -1, "2", nil, NaN (0/0) -> nil.
  - `canOpen`: nil set -> false; id mismatch or non-string -> false; opened -> false; matching unopened -> true.
  - `autoIndex(0, 3) == 1`, `autoIndex(0.999, 3) == 3`.
  - Config sanity: `COUNT == 3`, `PICK_SECONDS == 20`.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: ChestRules tests FAIL (module missing).

- [ ] **Step 3: Implement** `Config/BossChests.luau` and `Util/ChestRules.luau` with the values above.

- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 2: Server — BossChestService and BossService hand-off

**Files:**
- Create: `src/server/Services/BossChestService.luau`
- Modify: `src/server/Services/BossService.luau` (onBossWin, rollWeapon, DropWeapon split), `src/shared/Remotes.luau`,
  `src/server/init.server.luau` (start it before `BossService.Start()` in all three place branches)

**Interfaces:**
- Consumes: Task 1's `ChestRules`, `Config/BossChests`.
- Produces:
  - Remotes: `BossChests` (server -> owner: `{ id, bossId, seconds }`), `OpenBossChest` (client -> server:
    `(id: string, index: number)`), `BossChestOpened` (server -> owner: `{ id, index, contents = { Content x3 } }`).
  - `BossService.GiveWeapon(player, weaponId): payload?` (rolls the grade and gives; no client events) and
    `BossService.AnnounceWeapon(player, payload)` (WeaponDropped, WeaponBeacon if they're still here and it's new,
    WeaponAnnouncement if `WeaponRules.announces`); `DropWeapon(player, weaponId, delay)` keeps its behaviour as
    give + delayed announce (DevService uses it).
  - `BossChestService.Prepare(player, bossId, weaponId, payload: any?, onOpen: (any) -> ())`: rolls the material if
    `payload == nil` and gives it (`ItemService.GiveItem`), builds `others`, stores the set (replacing an older one:
    that one is opened first), after `Victory.SECONDS` fires `BossChests`, opens a random chest itself after
    `PICK_SECONDS + GRACE_SECONDS`.
  - `BossChestService.Preview(player, bossId, dropped: boolean)`: Studio-only set with nothing given (Task 3).

- [ ] **Step 1:** In `onBossWin`, when `BossRules.rollsWeapon(factor, carried)` and `weaponOf[bossId]`: skip the drop
  whose item is `Weapons.MATERIALS[bossId]` in the `boss.drops` loop; replace `rollWeapon`'s
  `DropWeapon(..., Victory.SECONDS)` with `GiveWeapon` (pity as today, `given = payload ~= nil`), then
  `BossChestService.Prepare(player, bossId, weaponId, payload, function(p) BossService.AnnounceWeapon(player, p) end)`.
  `result.weapon` stays the payload.
- [ ] **Step 2:** `OpenBossChest` handler: `RateLimiter.new(0.5)`; `ChestRules.canOpen(set, id)` and
  `ChestRules.validIndex(index, BossChests.COUNT)`; mark opened; fire `BossChestOpened` with
  `ChestRules.layout(index, set.mine, set.others)`; if `set.mine.kind == "weapon"` call `onOpen(payload)`.
  The timeout opens through the same function with `ChestRules.autoIndex(rng:NextNumber(), COUNT)`; firing to a player
  who left is skipped, but a weapon's announcement still goes out. `PlayerRemoving` clears the set.
- [ ] **Step 3: Verify:** `lune run tests/run` (SourceOrder) all pass; compile check on the changed server files.

### Task 3: Dev command and admin button

**Files:** Modify `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau` (+ `tests/AdminPanel` stays green).

- [ ] `/chests <boss id> [drop|miss]` -> `BossChestService.Preview` (nothing given; the drop preview's weapon payload
  is the `/weapondrop preview` one, grade A, refund 0). Admin panel Weapons section: "Boss chests" with placeholder
  "boss id [drop|miss]". Usage line on bad input.
- [ ] Verify: `lune run tests/run` passes.

### Task 4: Client — chest model and BossChestController

**Files:**
- Create: `src/client/Util/ChestModel.luau` (code-built chest: box, gold trim and lock, separate lid hinged at the back;
  `ChestModel.new(parent, cframe, size): { model: Model, open: (seconds) -> (), lidGlow: (Color3) -> () }`),
  `src/client/Controllers/BossChestController.luau`
- Modify: `src/client/init.client.luau` (start it next to `WeaponRevealController.Start()` in both branches),
  `src/shared/Config/BossChests.luau` (look numbers: chest size, spacing, wobble, lid angle, light colours)

- [ ] On `BossChests`: wait while `WeaponRevealController.IsPlaying()` or `OpeningStage.isShown()` (Review Focus 4),
  then `OpeningStage.show()`, bars, dim; three chests in a row on `OpeningStage.root()`, wobbling; "Tap a chest!" and
  a 20 s countdown ring; tap/click on a chest (raycast from the stage camera), keys 1-3, gamepad left/right + A.
  One input fires `OpenBossChest(id, index)` and locks input.
- [ ] On `BossChestOpened`: the picked chest rises, its lid pops with light (gold; rarity colour for a weapon), its
  content floats out (weapon portrait + name via `Config/WeaponLooks` portrait; material via `Util/Icon` + "x2" and
  the goal from `WeaponRules.materialGoal`), then the others open `OPEN_GAP` apart ("?" chest: the portrait darkened
  under a big "?"). A weapon: after 1.2 s hand over to the `WeaponDropped` reveal (it plays on the same stage; hide the
  chests when it starts). A miss: tap after `SKIP_AFTER`, closes itself after `CLOSE_AFTER`.
- [ ] Sounds: chest creak, lid pop, sparkle (licensed PSE ids via `scratchpad/sound_search.py`), in `Config/BossChests`.
- [ ] Verify: Luau Syntax Check clean (VS Code diagnostics) and the compile check; `lune run tests/run` passes.

### Task 5: Studio check and docs

- [ ] `rojo serve` running; Play; `/chests meadowWarden miss`, `/chests meadowWarden drop`, `/chests prismHydra miss`:
  screenshots of the pick, the open and the reveal hand-off; phone layout in the Device emulator.
- [ ] A real win (`/boss 1 fight`, `/bosshp 1`): chests appear after the victory screen; Bag shows the material.
- [ ] Leave mid-pick (stop Play) — no errors in Output.
- [ ] DESIGN.md 5.11 Drops (the chests), file tree (BossChestService, BossChestController, ChestModel, ChestRules,
  Config/BossChests); CLAUDE.md test list (`ChestRules: the boss chests' contents, pick and timeout`) and `/chests`.
- [ ] Tell the owner what to judge; commit after their OK.
