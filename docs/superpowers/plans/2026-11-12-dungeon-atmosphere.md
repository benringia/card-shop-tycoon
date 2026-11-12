# Dungeon Atmosphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Hydra's welcome cinematic, a plain-text objective at the top right, bigger arenas, and a dangerous
ambience (roars, eye glimpses, eerie music, spot sounds, fog) in the Dungeon.

**Architecture:** All looks and sounds are client controllers (`DungeonIntroController`, `DungeonObjectiveController`,
`DungeonAmbienceController`) driven by the run's `DungeonRun` message and the pieces' replicated attributes. The server
only decides which welcome a player gets (saved `data.dungeon.seenIntro`) and sends it when the run opens. Timings,
texts and volumes live in `Config/Dungeon`; the choices (which welcome, the objective's line, the next roar, how loud)
are pure Lune-tested rules.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests, Studio MCP (sound search, Play checks).

**Spec:** `docs/superpowers/specs/2026-11-12-dungeon-atmosphere-design.md` (owner "go" 2026-11-12; objective plain text).

## Global Constraints

- Danger never hurts: no damage, no new server state beyond `seenIntro`.
- The Hydra is never shown before its chamber.
- The welcome is always skippable; full only the first time ever (saved), short (~3 s) after.
- The objective is plain text, no box: "OBJECTIVE" label + one line + progress; hidden during the welcome.
- Fight rings radius 40 (was 28); the Hydra's chamber `arenaRadius` 48 (was 36).
- Every tunable number in `Config/Dungeon`; sounds from Pro Sound Effects / APM; music quiet.
- Text plain ASCII plus emoji; UI built in code (UIKit fonts), clear of mobile controls.
- After client edits: compile check + VS Code diagnostics; commit only after the owner confirms.

## Review Focus

1. A player who joins while the welcome plays, or whose run opens before their character exists: no camera stuck,
   the objective still appears after.
2. Skipping the welcome mid-way: camera, lighting, music, HUD and the hall's lights all back as before.
3. The objective while out of the run, after the win, or in the Hydra fight: the right line, never stale.
4. Roars and glimpses during the welcome or a fight: none during the welcome; roars quieter in fights.
5. Phones: lights and particles only near the camera, no per-frame property churn.

---

### Task 1: Rules and config

**Files:** Modify `src/shared/Config/Dungeon.luau`, `src/shared/Config/Bosses.luau` (`prismHydra.arenaRadius = 48`),
`src/shared/Util/DungeonRules.luau`, `tests/Dungeon.spec.luau`, `tests/DungeonRules.spec.luau`, `tests/run.luau`;
Create `src/shared/Util/ObjectiveRules.luau`, `src/shared/Util/AmbienceRules.luau`, `tests/ObjectiveRules.spec.luau`,
`tests/AmbienceRules.spec.luau`.

**Interfaces (produces):**
- Config/Dungeon: `ROOM_RADIUS = 40`, `CHAMBER.x` recomputed; `INTRO = { full = { {at, beat} ... }, short = {...} }`
  with beats "slam", "torches", "drift", "eyes", "pairs", "roar", "title", "end" (full ends at 9.5, short at 3);
  `OBJECTIVES = { waiting, room, beams, plates, pylons, lock, boss, won, out }` texts; `AMBIENCE = { roarEvery = {50, 80},
  roarVolume = {0.15, 0.5}, glimpseEvery = {90, 160}, glimpseSeconds = 1.6, heartbeatFrom = 5, musicVolume = 0.35 }`
  (the music's own volume set when its id is picked); `SOUNDS = {}` filled in Task 3.
- `DungeonRules.introKind(seen: boolean): "full" | "short"`
- `ObjectiveRules.line(stage: string, done: number?, total: number?, texts): { text: string, progress: string? }`
  (progress "2 / 3" when both numbers are given and total > 0; an unknown stage: the `room` text)
- `AmbienceRules.nextAt(now, every: {number}, roll): number`; `AmbienceRules.roarVolume(done, steps, range): number`
  (min at 0 steps done, max at all done); `AmbienceRules.heartbeat(done, from, steps): number` (0 below `from`, rising
  to 1 at `steps`)

- [ ] **Step 1:** Tests: Dungeon.spec "INTRO: beats ascend from 0, full ends at 9.5 with the eyes before the roar,
  short within 3 s"; layout test uses `BossRules.arenaRadius(Bosses.BOSSES.prismHydra, Bosses)` and ROOM_RADIUS 40;
  DungeonRules.spec "introKind: full first, short after"; ObjectiveRules.spec "line: text and progress, unknown stage,
  no progress without a total"; AmbienceRules.spec "nextAt within range; roarVolume grows step by step; heartbeat 0
  early, 1 at the end".
- [ ] **Step 2:** `lune run tests/run` — Expected: those fail.
- [ ] **Step 3:** Implement; CHAMBER.x = hall 40 + steps (gap 20 + 80 per fight, 64 per puzzle) + 20 + 48.
- [ ] **Step 4:** `lune run tests/run` — Expected: all pass.

### Task 2: Bigger arenas in the cavern

**Files:** Modify `src/server/Util/DungeonBuilder.luau` (the chamber radius from `BossRules.arenaRadius` for the
Hydra, not `Bosses.ARENA_RADIUS`), `src/server/Services/WildService.luau` if the chamber arena reads ARENA_RADIUS.

- [ ] **Step 1:** Build; `rojo build dungeon.project.json`; Studio: Play, screenshot room 1 and the chamber; rooms open
  through doors as before, fights start inside the wider rings.

### Task 3: Sounds and music

**Files:** Modify `src/shared/Config/Dungeon.luau` (`SOUNDS`: slam, torchOut, breath, growl, roar, dust, heartbeat,
title, chime, music, chains, chimes), `src/shared/Config/Soundscape.luau` (`DUNGEON` spots: drips, pebbles, chains,
whispers, crystal chimes).

- [ ] **Step 1:** Search Studio's Creator Store (Audio) for Pro Sound Effects / APM: a huge layered monster roar, a
  low growl, a deep breath, a heavy stone door slam, a torch blown out, falling rubble, a slow heartbeat, a soft
  bell/chime, rattling chains, crystal tinkles; an eerie ambient music loop (drone + choir, APM). Listen-check lengths
  in Studio (`TimeLength`), keep ids that load. Record ids with a comment naming each.

### Task 4: The welcome's save flag and the server's word

**Files:** Modify `src/server/Util/Migrations.luau` (`[18]` adds `seenIntro` with `secretFound`, keeps a saved true),
`src/server/Services/DataService.luau` (template), `src/server/Services/BossService.luau`
(`BossService.TakeIntro(player): "full" | "short"` marks it seen), `src/server/Services/DungeonService.luau` (when the
run opens, each member's `DungeonRun` message carries `intro`), `src/shared/Remotes.luau` (comment), `tests/Migrations.spec.luau`.

- [ ] **Step 1:** Migrations test "v19: dungeon.seenIntro false, a saved true kept" fails, then implement, pass.

### Task 5: The objective

**Files:** Create `src/client/Controllers/DungeonObjectiveController.luau`; Modify `src/client/init.client.luau`.

- [ ] **Step 1:** Top-right plain text (FredokaOne label "OBJECTIVE", white line with a dark stroke, progress after
  it), its stage from `DungeonRun` and progress from attributes: pack monsters left (markers in workspace.Monsters
  near the room), plates `Held`/`Needed`, pylons `Broken`, sockets `Lit`. Room 3 reads "pylons" while any stands.
  Chime + small pop on a change; hidden while `DungeonIntroPlaying`. Studio: screenshot each step.

### Task 6: The welcome

**Files:** Create `src/client/Controllers/DungeonIntroController.luau`; Modify `src/server/Util/DungeonBuilder.luau`
(two braziers in the hall with lights, for the torches beat), `src/client/init.client.luau`.

- [ ] **Step 1:** On `DungeonRun` with `intro`, play `Config/Dungeon.INTRO[intro]`: camera Scriptable (restored after),
  a stone slab slams down at the hall's back wall (client part), braziers' lights out one by one, the camera drifts
  down the hall, eyes (glowing client parts) open in the dark beyond the first door: one pair, then four more in the
  heads' colours (`Bosses.prismHydra.heads`), narrowing at the roar with shake + dust, then title text, heartbeat,
  eyes off, lights back, camera back. Skip button (tap/click/Space). Player attribute `DungeonIntroPlaying` set while
  it plays. Studio: run `/puzzle`-free fresh Play, screenshot beats 4, 5, 6, 7; skip mid-way restores everything.

### Task 7: Danger all the way down

**Files:** Create `src/client/Controllers/DungeonAmbienceController.luau`; Modify
`src/client/Controllers/SoundscapeController.luau` (runs in the Dungeon with `Soundscape.DUNGEON`),
`src/shared/Config/Dungeon.luau` (`LIGHTING` fog thicker), `src/client/init.client.luau`.

- [ ] **Step 1:** The eerie music loop (volume `AMBIENCE.musicVolume`, fading out in the Hydra fight and the welcome's
  silence beat), a heartbeat layer by `AmbienceRules.heartbeat`; distant roars at `AmbienceRules.nextAt` with volume by
  `roarVolume`, a small camera tremble and dust round the camera (not during the welcome; half volume in fights); eye
  glimpses: a pair of eyes in a dark spot ahead of the player for `glimpseSeconds`, never in a fight.
- [ ] **Step 2:** Studio-only `/dungeonfx <intro|introshort|roar|glimpse>` (DevService sets the player attribute
  `DungeonFxTest` = "<kind>:<os.clock()>"; the intro and ambience controllers play it, in Studio only; an admin panel
  button each). Studio: trigger and screenshot each.

### Task 8: Docs, review, owner check

- [ ] DESIGN.md (the Dungeon section: welcome, objective, ambience, bigger rings; schema 19 `seenIntro`), CLAUDE.md
  test list (ObjectiveRules, AmbienceRules); `lune run tests/run`; final review; owner's Studio check; commit after OK.
