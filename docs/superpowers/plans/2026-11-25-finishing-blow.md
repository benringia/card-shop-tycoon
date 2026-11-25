# Finishing Blow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Your own fight's last hit holds everything a beat, punches the camera in and lands a deep thud; a wild
monster then launches harder, a boss flashes white before its death scene. The numbers the owner felt ("strong").

**Architecture:** Numbers in `Config/FinishingBlow`, pure rules in `Util/FinishingBlowRules` (Lune-tested). Client
`Util/FinishingBlow` plays the moment; `MonsterController` asks it when a monster is beaten (wild: into
`MonsterKO.play`; boss: holds its whole step); `SwordController.PunchZoom` shares the hang zoom's token; BattleController
wires the hooks in `Start` (your fight's monster while fighting, the fight's creatures through
`CreatureController.Freeze`).

**Tech Stack:** Luau (strict), Rojo, Lune tests, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-25-finishing-blow-design.md`

## Global Constraints

- Numbers (spec): wild hold 0.16 s, launch x1.25, kick 0.6, zoom 8 degrees in 0.05 s, back 0.35 s, Pick Impacts 1
  (`rbxassetid://9117330384`) at 0.7, no screen flash; boss hold 0.4 s, zoom 11, kick 1.2, Deep Hits Big Reverberant
  Booms 2 (`rbxassetid://9125484367`) at 0.7, screen flash 0.3 fading over hold + 0.2 s, body flash fill 0.7 over hold
  + 0.25 s; MonsterKO SERVER_SECONDS 2.7; margin 0.1 s.
- No "KO" text or pop. Only your own running fight's monster, a win.
- Pure modules don't require siblings; Lune can't build Vector3 or Color3: configs plain data.
- BattleController sits at Luau's 200-local limit: no new file-level locals (inline requires inside `Start`).
- Client edits: compile check + getDiagnostics for unknown globals. Never `sed -i` in `src`.

## Review Focus

1. You ran from a monster and someone else beats it: no moment on your screen (`fighting` is false). Test:
   FinishingBlowRules "only your running fight's monster".
2. An elite's knockout with the moment: its own extra stays on top of the moment's launch and kick. Test:
   FinishingBlowRules "an elite keeps its extra on top".
3. The knockout with the longer hold vs the server's removal, with latency. Test: FinishingBlowRules "the knockout
   still ends the margin before the server lets go".
4. A finisher cut's hang zoom running when the last hit lands: the punch takes over from the same base, the view
   never ends narrowed. Studio: FOV back to its base after a sword-finished win.
5. A skill's or super's camera moment owning the view at the last hit: no punch. Covered in Task 2's code
   (`PunchZoom` checks); code review.

---

### Task 1: Rules and numbers

**Files:**
- Create: `src/shared/Config/FinishingBlow.luau`, `src/shared/Util/FinishingBlowRules.luau`
- Modify: `src/shared/Config/MonsterKO.luau` (SERVER_SECONDS 2.6 -> 2.7)
- Test: `tests/FinishingBlowRules.spec.luau`; register in `tests/run.luau`

**Interfaces:**
- Produces: `Config/FinishingBlow` = `{ WILD = Moment, BOSS = Moment, FLASH_TAIL = 0.2, BODY_FLASH = { fill = 0.7,
  tail = 0.25 }, MARGIN = 0.1 }` with `Moment = { hold, power, shake, zoom, zoomIn, back, sound, volume, flash }`.
- Produces: `FinishingBlowRules.mine(fighting: boolean, isFightMonster: boolean): boolean`;
  `FinishingBlowRules.knockout(ko, elite: boolean, moment: Moment?) -> (hitStop: number, power: number, shake: number)`
  (`ko` = Config/MonsterKO); `FinishingBlowRules.knockoutSeconds(ko, hitStop: number): number` (hitStop + maxFlight +
  settleSeconds + holdSeconds + poofSeconds).

- [ ] **Step 1:** Write the tests (Review Focus 1-3, plus: the config's felt numbers; holds are beats (wild <= 0.2,
  boss <= 0.5); no moment gives `ko.hitStop`, power 1 (1.3 elite), shake 0.3 (x1.6 elite); a wild moment gives 0.16,
  1.25 (x1.3 elite), 0.6 (x1.6 elite); `knockoutSeconds(ko, 0.16)` <= SERVER_SECONDS - MARGIN).
- [ ] **Step 2:** `lune run tests/run FinishingBlowRules`. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement the config, the rules, SERVER_SECONDS 2.7.
- [ ] **Step 4:** `lune run tests/run FinishingBlowRules` passes; whole suite green (MonsterKOMotion included).
- [ ] **Step 5:** Commit `Finishing blow: rules and numbers`.

### Task 2: The moment on screen

**Files:**
- Create: `src/client/Util/FinishingBlow.luau`
- Modify: `src/client/Util/MonsterKO.luau` (`play(model, away, elite, moment: Moment?)` through
  `FinishingBlowRules.knockout`)
- Modify: `src/client/Controllers/MonsterController.luau` (`SetFinishingBlow(callback)`; `knockOut` passes the moment;
  a boss's first beaten mark: `heldUntil`, white body flash, the Hydra's `fallenAt` after the hold; the frame loop
  skips a held monster entirely)
- Modify: `src/client/Controllers/SwordController.luau` (zoom token: `zoomTo`, `hangZoom` through it, `cancelHang`
  bumps it; `SwordController.PunchZoom(degrees, inSeconds, holdSeconds, backSeconds)` skipped when the camera isn't
  Custom or a super's or skill's moment owns it)
- Modify: `src/client/Controllers/BattleController.luau` (`Start`: `FinishingBlow.attach` with `isFoe` =
  `FinishingBlowRules.mine(fighting, marker == markerFor(MONSTER_ID))`, `holdCreatures` = Freeze on every fight marker)

**Interfaces:**
- Consumes: Task 1's config and rules.
- Produces: `MonsterController.SetFinishingBlow(callback: (marker: BasePart, boss: boolean) -> Moment?)`;
  `FinishingBlow.attach(hooks: { onBeaten, isFoe, punch, holdCreatures })`; `SwordController.PunchZoom`.

- [ ] **Step 1:** Implement (the moment: your character's playing tracks held at speed 0 and restored to their own
  speed, the creatures held, the punch, the sound in SoundService destroyed when it ends; a boss: the screen flash and
  the kick).
- [ ] **Step 2:** Compile check the six files, getDiagnostics, whole suite (SourceOrder, RequireCycles included).
- [ ] **Step 3:** Commit `Finishing blow: the last hit holds, punches in and lands`.

### Task 3: Docs and Studio check

- [ ] **Step 1:** DESIGN.md (a "Finishing blow" bullet after Hit feel; Config/MonsterKO's 2.7), the file tree
  (`Config/FinishingBlow`, `Util/FinishingBlowRules`, client `Util/FinishingBlow`), CLAUDE.md test list. Commit
  `Finishing blow: docs`.
- [ ] **Step 2:** Studio: a wild win finished by the creature and one by the sword (character, creature and monster
  held; FOV in and back to its base; launch), a boss win (body and tip held, flash, FOV), a phone in the Device
  emulator (the punch on a phone's fight camera); Output clean; tell the owner what to judge.
