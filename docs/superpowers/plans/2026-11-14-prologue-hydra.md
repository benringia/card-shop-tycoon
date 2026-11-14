# The Prologue (the Hydra takes it all) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A ~90 s client-only prologue on a new player's first join: a cinematic, a real fight with a maxed loadout
against a two-headed Prism Hydra, a defeat cinematic, then the existing welcome flight and tutorial.

**Architecture:** A `PrologueController` (client) orchestrates three acts on the player's own screen, reusing the
game's drawing code (CreatureController local markers, SwordController's held weapon, SwordAnims/SwordSkillFx,
FightFx/SuperCinematic, ClipPlayer) without touching the server fight. Pure pacing/hint/timing rules live in
`Util/PrologueRules` (Lune-tested) with numbers in `Config/Prologue`. The server only saves `seenPrologue`
(WelcomeService) and gates the welcome flight on it.

**Tech Stack:** Roblox Luau (Rojo), Lune tests (`lune run tests/run`), Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-11-14-prologue-hydra-design.md`

## Global Constraints

- Client only: no real cards, weapons, cash or items given or taken; nothing saved but `seenPrologue`.
- BattleService, BattleSim, BattleController, the welcome flight and the tutorial keep working as today.
- Text: plain ASCII plus `·` and emoji (fonts draw ★ → − as boxes). Fonts FredokaOne / GothamBold.
- Tap targets ≥ 48 px; works on a landscape phone.
- Sounds: Roblox-licensed only (PSE / APM), ids already in the repo where possible.
- Tunable numbers in `Config/Prologue`; pure logic Roblox-free in `src/shared/Util`, no sibling requires.
- Schema change: `SCHEMA_VERSION` 29, a migration with a Lune test, DESIGN.md 10.4.

## Review Focus

1. The character dies or respawns mid-prologue: it ends cleanly (HUD, camera, lighting, Sword attribute and local
   parts restored), counts as seen, the welcome flight starts. (Task 6 Studio check: `/prologue`, then reset.)
2. The player leaves mid-prologue: nothing saved but the flag (not set), the next join plays it again. (Task 1 test:
   the flag only changes on PrologueSeen.)
3. A phone: the fight HUD fits a landscape phone, buttons ≥ 48 px, touch works. (Task 5 Studio check in the Device
   emulator.)
4. Skip at any moment (act 1, mid-fight, act 3): the same clean end as a finished run. (Task 6 Studio check.)
5. An existing player (seenWelcome true) never sees it; a new player sees it once. (Task 1 migration test.)

---

### Task 1: The saved flag, the gate and the Studio command

**Files:**
- Modify: `src/shared/Config/Data.luau` (SCHEMA_VERSION 29), `src/server/Util/Migrations.luau` (`[28]`),
  `src/server/Services/DataService.luau` (type + template `seenPrologue = false`),
  `src/server/Services/WelcomeService.luau`, `src/shared/Remotes.luau` (`PrologueSeen`, `PrologueReplay`),
  `src/client/Controllers/WelcomeController.luau` (`check`), `src/server/Services/DevService.luau` (`/prologue`),
  `src/shared/Config/AdminPanel.luau`, DESIGN.md 10.4
- Test: `tests/Migrations.spec.luau`

**Interfaces:**
- Produces: player attribute `SeenPrologue` (boolean, set on load); `Remotes.PrologueSeen` (client → server, no args:
  mark seen); `Remotes.PrologueReplay` (server → client, no args: play it now, Studio); `WelcomeService.ReplayPrologue(player)`.

- [ ] **Step 1: Write the failing migration test** `"v29: saves from before the prologue count it as seen"`:
  `{ version = 28 }` → `seenPrologue == true`, version 29; `{ version = 28, seenPrologue = false }` keeps false.
- [ ] **Step 2: Run** `lune run tests/run` → FAIL (`seenPrologue` nil).
- [ ] **Step 3: Implement** migration `[28]`: `if typeof(data.seenPrologue) ~= "boolean" then data.seenPrologue = true end`;
  SCHEMA_VERSION 29; template `seenPrologue = false` (new saves see it).
- [ ] **Step 4: Run** `lune run tests/run` → PASS.
- [ ] **Step 5: WelcomeService** keeps `seenPrologue` like `seenWelcome` (load → attribute `SeenPrologue`, save, unload,
  `PrologueSeen` rate-limited sets true, `ReplayPrologue` sets false and fires `PrologueReplay`).
- [ ] **Step 6: WelcomeController.check** returns early while `SeenPrologue == false` (and connects its change signal);
  Pish's tutorial already waits for `SeenWelcome`.
- [ ] **Step 7: DevService** `/prologue` (ReplayPrologue) and `/prologue reset` (sets the flag false for the next join);
  AdminPanel buttons "Play the prologue" / "Prologue on next join".
- [ ] **Step 8: Commit** after Task 6's Studio pass (one commit for the feature, owner's OK).

### Task 2: Config/Prologue and Util/PrologueRules

**Files:**
- Create: `src/shared/Config/Prologue.luau`, `src/shared/Util/PrologueRules.luau`
- Test: `tests/PrologueRules.spec.luau` (register in `tests/run.luau`)

**Interfaces:**
- Produces:
  - `PrologueRules.hpShare(elapsed: number, dealt: number, cfg): number` — the Hydra's HP share (1 → `cfg.END_SHARE`):
    `dealt` (sum of action damage shares) clamped between the time floor and ceiling curves.
  - `PrologueRules.done(share: number, cfg): boolean` — at or under `END_SHARE`.
  - `PrologueRules.hint(state: { elapsed: number, cuts: number, skills: number, supers: number, swaps: number, dodged: boolean, ringUp: boolean }, cfg): string?`
  - `PrologueRules.damage(kind: "cut" | "skill" | "super" | "creature", cfg): number` — share of HP per action.
- Config (`Config/Prologue`): `END_SHARE = 0.25`, `FIGHT = { min = 35, max = 60 }` (seconds the drain can't beat /
  always reaches), `DAMAGE = { cut = 0.012, skill = 0.06, super = 0.11, creature = 0.004 }`, `HINTS` (ordered list:
  `{ id, text, when }`), `LOADOUT = { weapons = { "RiftReaper", "PrismBlade", "TitansLance" } (Weapons ids),
  creatures = { "Solarion", "Voidmaw", "Stormking" } }`, `HYDRA = { model = "prismHydra", height = 30, tucked = {
  Hydra_0_0 = {...}, Hydra_3_0 = {...}, Hydra_4_0 = {...} } }` (offset in model units and pitch/roll degrees: the
  Studio-tested `(0,-0.14,0.16) pitch 105`, `(0.17,-0.14,0.16) pitch 105 roll -20`, `(-0.17,-0.14,0.16) pitch 105 roll 20`),
  `ATTACK_EVERY = 4`, `RING_WARNING = 1.1`, `ACT1 = 15`, `ACT3 = 20`, `SKIP_AFTER = 5`, `ARENA` (height 1500, radius
  60), `CAPTIONS` (the spec's lines).

- [ ] **Step 1: Write failing tests:**
  - `"spamming can't end the fight before FIGHT.min"`: `hpShare(10, 10, cfg) > END_SHARE`.
  - `"idling still ends it by FIGHT.max"`: `done(hpShare(cfg.FIGHT.max, 0, cfg), cfg) == true`.
  - `"dealt damage shows between the curves"`: at 20 s with dealt 0.3, `hpShare` equals `1 - 0.3` when inside them.
  - `"hints teach in order"`: start → the cut hint; after a cut → the skill hint; at 15 s with no super → the super hint;
    `ringUp` → the dodge hint first.
  - `"the loadout is real"`: every LOADOUT weapon id is in `Config/Weapons` ById, every creature in `Config/CardList`.
- [ ] **Step 2: Run** → FAIL (module missing).
- [ ] **Step 3: Implement** both files (curves: ceiling `1 - (1 - END_SHARE) * clamp(t / FIGHT.min)`, floor
  `1 - (1 - END_SHARE) * clamp(t / FIGHT.max)`; share = clamp(1 - dealt, ceiling, floor) — note ceiling ≤ floor).
- [ ] **Step 4: Run** → PASS.

### Task 3: The two-headed Hydra on the client

**Files:**
- Create: `src/client/Util/PrologueHydra.luau`

**Interfaces:**
- Consumes: `Config/Prologue` HYDRA; `ClipPlayer.loadSet(key, model)`, `ClipPlayer.play`, `ClipPlayer.step`.
- Produces: `PrologueHydra.spawn(at: CFrame): Hydra` where `Hydra = { model: Model, root: BasePart, height: number,
  play: (clip: string, speed: number?) -> (), step: (dt: number) -> (), growHead: (seconds: number) -> (),
  glow: (color: Color3) -> (), destroy: () -> () }`. `root`: an invisible anchored part inside the model (FightFx's
  monster root).

- [ ] **Step 1:** Clone `MonsterModels.prismHydra`, strip scripts, anchor, no collision/query, `ScaleTo` to HYDRA.height,
  stand on `at`, SurfaceAppearance emissive as the boss (rune glow).
- [ ] **Step 2:** Tuck: per tucked bone, Transform = `base:Inverse() * (CFrame.new(base.Position + offset * scale) *
  rot * base.Rotation)` with base the bone's WorldCFrame at Transform identity. Re-apply after every `ClipPlayer.step`.
- [ ] **Step 3:** `growHead(seconds)`: Hydra_0_0's tuck lerps to identity over `seconds` (Back easing), then it's no
  longer re-tucked.
- [ ] **Step 4: Studio check** (Play, Client `execute_luau`): spawn at (0,1500,0), screenshots front and back: two heads;
  `play("strike")` animates; `growHead(1.5)` shows a third head. Output clean.

### Task 4: The stage: lair, character, HUD off, bars, captions, skip

**Files:**
- Create: `src/client/Util/PrologueStage.luau`

**Interfaces:**
- Produces: `PrologueStage.enter(): Stage` where `Stage = { arena: Model, spot: (name: "player" | "hydra" | "creature") ->
  CFrame, caption: (text: string, seconds: number) -> (), bars: (on: boolean) -> (), skipButton: (onSkip: () -> ()) ->
  (), fade: (toBlack: boolean, seconds: number) -> (), leave: () -> () }`. `leave` restores everything `enter` changed.

- [ ] **Step 1:** Arena on the client at ARENA.height above the map: a dark crystal floor disc (collidable, local),
  a glowing rune ring, crystal pillars/shards (`PropModels` DungeonPillar / CrystalMirror when present, else neon
  wedges), fog, a night sky (Lighting saved and restored: ClockTime, Ambient, OutdoorAmbient, FogStart/End/Color,
  Atmosphere density), a cold point light.
- [ ] **Step 2:** Character: save its CFrame, move it to `spot("player")` (client-owned), restore on `leave` to its
  shop door (`ownPlot` like WelcomeController) instead of where it was.
- [ ] **Step 3:** Hide every ScreenGui but the prologue's (as WelcomeController does) and restore on `leave`; cinema
  bars; a caption label (FredokaOne, fades); a Skip button (≥ 48 px) from SKIP_AFTER; fade to/from black.
- [ ] **Step 4: Studio check:** `PrologueStage.enter()` then `leave()` from the Client: the town, HUD, lighting and
  camera exactly as before; screenshot inside the arena.

### Task 5: The fight (act 2)

**Files:**
- Create: `src/client/Util/PrologueFight.luau`

**Interfaces:**
- Consumes: `PrologueRules.hpShare / done / hint / damage`; `PrologueHydra` Hydra; `PrologueStage` Stage;
  `FightFx.new(...)` (callbacks as MovePreviewController's), `SuperCinematic.play/impact/release`,
  `SwordAnims.load`, `SwordSkillFx.*`, `SkillCinematic.forLook`, `SwordController.DrawNow / PlayCues / BladeOf`,
  `CreatureController.GetFightView`.
- Produces: `PrologueFight.run(stage: Stage, hydra: Hydra): Result` (yields until the Hydra reaches END_SHARE or the
  run is stopped), `Result = { reason: "won" | "skipped" | "died" }`; `PrologueFight.stop()`.

- [ ] **Step 1: Loadout.** Set the character's `Sword` attribute locally to LOADOUT.weapons[1] (saved first, restored
  by `stop`); local creature markers in `workspace.Creatures` (CardId, Level = max, Stars = max, Grade "S", Foil
  false, OwnerUserId = you, BeastId `prologue:<card>`, SummonedAt now) following the player's side like a summoned
  creature; one out at a time. A local rainbow aura on the character (the "Legend" supporter look, `Config/Support`
  AURA[3], built on the client), removed in act 3.
- [ ] **Step 2: HUD** in the boss fight's look: the Hydra's plate and HP bar on top, buttons Cut, Skill, Super, Swap,
  Weapon, Dodge (keys: click / E / Q / R / Z / Space like the real fight where they exist). Hint bubble.
- [ ] **Step 3: Actions.** Cut/Skill: the `/skillfx` sequence (MovePreviewController.playSword) at the Hydra,
  `damage("cut")` / `damage("skill")` with big damage pops. Super: the out creature's super via FightFx cast/ability
  events + SuperCinematic (as `/superfx`), `damage("super")`. The creature's basic attacks every ~1.4 s
  (`damage("creature")`). Swap: unsummon/summon markers. Weapon: next LOADOUT weapon. Dodge: a short dash.
- [ ] **Step 4: The Hydra fights back** every ATTACK_EVERY s: a `ring` event at the player (FightFx draws it) with its
  windup/strike clips; on release a screen flash and shake, no damage.
- [ ] **Step 5: Pacing:** the HP bar shows `hpShare(elapsed, dealt)`; `done` → return `won`. Hints from `hint(...)`.
- [ ] **Step 6: Studio check** (PC and the phone emulator): every button works, supers and the Thousand Cuts play,
  rings show, the fight ends between 35 and 60 s; screenshots; Output clean.

### Task 6: Acts 1 and 3, the hand-off, the controller

**Files:**
- Create: `src/client/Controllers/PrologueController.luau`; Modify: `src/client/init.client.luau`

**Interfaces:**
- Consumes: Tasks 1-5.
- Produces: `PrologueController.Start()`; plays when `SeenPrologue == false` and `LoadingDone == true` (main place
  only), or on `PrologueReplay`; at the end fires `PrologueSeen` (welcome flight then starts by itself).

- [ ] **Step 1: Act 1** (ACT1 s): fade in, caption, camera orbit, the three creatures pop out of cards one by one
  (their markers' SummonedAt staggered), the Hydra rises (spawned below, tweened up) and roars (`enrage` clip, shake),
  "FIGHT!".
- [ ] **Step 2: Act 2:** `PrologueFight.run`.
- [ ] **Step 3: Act 3** (ACT3 s): slow motion feel (tweens), rune glow rainbow, roar; each creature's marker gets
  `Unsummon` and a card face (CardFace on a part) flies into a Hydra mouth; the held weapon shatters (shards
  particles, Sword attribute cleared); aura off; `growHead`; the character falls (ragdoll-free: a tween + camera tilt);
  white flash, black, caption "It took everything."
- [ ] **Step 4: Wake up:** `stage.leave()` puts you in your shop; Pish's and Chikin's lines as two speech bubbles
  ("Hey! Are you okay?", "Let's get it all back!") for ~3 s; then `PrologueSeen` (the welcome flight starts).
- [ ] **Step 5: Ending paths:** Skip, death/respawn (CharacterRemoving), and leaving all run one `finish()` that
  stops the fight, destroys everything local, restores attributes, HUD, lighting and camera, and fires `PrologueSeen`
  (not on leaving).
- [ ] **Step 6: Studio check:** `/prologue` end to end on PC; skip in each act; reset mid-fight; the welcome flight and
  Pish's tutorial follow; Output clean. Then the phone emulator.

### Task 7: Preload, docs, final check

**Files:**
- Modify: `src/client/Controllers/LoadingController.luau` (preload the Hydra, the three creatures' and weapons' models
  when `SeenPrologue == false`), DESIGN.md (the prologue section, 10.4), CLAUDE.md (tests list: PrologueRules; dev
  command `/prologue`), docs/creatures.md (the two-headed tuck)

- [ ] **Step 1:** Preload as described; `lune run tests/run` → all pass.
- [ ] **Step 2:** Docs.
- [ ] **Step 3:** Full Studio run once more; screenshots for the owner; commit and push after the owner's OK.
