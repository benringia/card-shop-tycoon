# Super Moves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ten super moves cinematic events: a wind-up the server times, a camera moment on the caster's screen, ten distinct looks with their own sounds, each bigger with grade, the caster's player safe while the camera is away.

**Naming:** client code requires the config as `SuperFxConfig` (`Config/SuperFx`), the in-world looks as `SuperFx` (`Util/SuperFx`), the caster's screen layer as `SuperCinematic` (`Util/SuperCinematic`). A "look" is one of the ten moves by its id: `Inferno`, `TidalShield`, `TidalBlessing`, `Stampede`, `MagmaSlam`, `Eclipse`, `RiftStep`, `Supernova`, `Thunderstorm`, `Devour` (the Frontier four share their base move's `kind`, so the look id, not the kind, picks the effects).

**Architecture:** `BattleSim` gives every super its own wind-up (the existing `casts` path), protects the caster's player from the press until control returns, and tells clients the look. Clients play the in-world effects for everyone (`Util/SuperFx`, routed from `Util/FightFx` in place of `ElementFx.special` for supers) and, on the caster's client only, the camera and screen layer (`Util/SuperCinematic`, driven by `BattleController`). Every per-look, per-grade number lives in plain-data `Config/SuperFx`; the pure choices (grade, beat times, camera framing) in `Util/SuperFxRules`, Lune-tested.

**Tech Stack:** Roblox Luau (Rojo), Lune tests (`lune run tests/run`), Python + Pillow for textures, background Blender (not the owner's open one) only if a look needs a mesh, Roblox Studio MCP for checks, screenshots and image uploads.

**Spec:** `docs/superpowers/specs/2026-11-05-super-moves-design.md`

## Global Constraints

- The owner's rule: "the higher the creature grade the better the skill must look and feel"; each grade a clear step up, S has extras the others don't. Grade changes looks, sounds and shake only, never numbers.
- Way beyond the pet moves: "screen shakes / cinematics / particle effect / sound effects".
- Wind-up: Epic 1.5 s, Legendary 2.0 s, per super in `Combat.SIGNATURES`. Pet moves keep `ABILITY_WINDUP` 0.5.
- The caster's player can't be hit from the press until control returns: the wind-up + 0.6 s (`Combat.SUPER_PROTECT_TAIL`). Hits due inside miss. The boss starts no new quick hits or rings aimed at that player meanwhile (it picks other targets as usual).
- What the moves do is unchanged (damage, burn, shield %, stun, dodge seconds, lifesteal, the 15 s cooldown).
- Only the caster's client plays the cinematic (camera, card cut-in, wash, bars, impact frame, sky/lighting). Others see the in-world effects, positional sound and a lighter shake; nobody else loses control or view. World objects in the sky (black moon, storm clouds, black hole, parting clouds and rays) are in the world for everyone.
- If the caster faints during the wind-up the move fizzles and the cinematic cuts back at once; swapping the caster out during its wind-up is refused.
- During the caster's cinematic: the combat HUD fades, their character holds still, fight keys do nothing; everything is restored on every exit (impact done, fizzle, fight end, defeat, leaving, death).
- Low graphics (`Util/Extras` off): no black-and-white frame (a soft white flash), the look capped at its B grade, a smaller shake; the camera beat still plays.
- Sounds: Roblox-licensed only (Pro Sound Effects or APM via the toolbox API, memory `licensed-sound-search`); kept loaded through `Util/CombatPreload` + `Util/SoundBank`.
- Combat HUD layout unchanged; combat UI text unchanged.
- Project rules (CLAUDE.md): numbers in `src/shared/Config`, pure rules Roblox-free (no sibling requires, no Vector3), `--!strict`, every remote in `src/shared/Remotes.luau`, scripts only in the repo, SourceOrder test, never run Blender builds in the owner's open Blender.

## Review Focus

1. The caster faints mid-wind-up: the move fizzles, the player's protection ends at once, the camera/HUD/character/sky come back (Task 1 test; Task 4 Studio check).
2. A ring or quick hit started before the press, landing inside the window, misses; one landing after it hits (Task 1 test).
3. The fight ends mid-cinematic (boss beaten by another player's hit, defeat, running): `SuperCinematic.cut()` restores everything (Task 4 Studio check of each exit).
4. The cinematic camera placed inside an arena wall, rock or the boss: the eye is pulled in front of whatever is between it and the creature (Task 4: raycast step, Studio check in each Wild boss arena).
5. No grade or an unknown one plays C; low graphics caps at B and drops the impact frame (Task 2 test).

---

### Task 1: Supers in the sim — wind-up, protection, fizzle, swap block

**Files:**
- Modify: `src/shared/Config/Combat.luau` (SIGNATURES entries; `SUPER_PROTECT_TAIL`)
- Modify: `src/server/Util/BattleSim.luau` (Fighter `protectedUntil`; `useAbility` signature wind-up; `releaseCasts` fizzle; pending-hit landing; `swingAtPlayer`; `bigAttack`; `BattleSim.swap`)
- Test: `tests/BattleSim.spec.luau`
- Modify: `DESIGN.md` (supers paragraph; balance numbers)

**Interfaces:**
- Produces: each `Combat.SIGNATURES` entry gains `look: string` and `windup: number`: Infernox `Inferno` 1.5, Abyssal Koi `TidalShield` 1.5, Thunderhorn `Stampede` 1.5, Eclipse Fox `Eclipse` 1.5, Solarion `Supernova` 2, Voidmaw `Devour` 2, Riftwalker `RiftStep` 1.5, Cinder Titan `MagmaSlam` 1.5, Tideborne Kirin `TidalBlessing` 2, Stormking `Thunderstorm` 2. `Combat.SUPER_PROTECT_TAIL = 0.6`.
- Produces events: a super's cast `{ type = "cast", from, kind, look, seconds = windup, protect = windup + SUPER_PROTECT_TAIL, to = <likely target id or nil> }`; its landing `ability` event (and the hit/ability events `applyAbility` emits for it) gain `look`; `{ type = "fizzle", from, look }` when its caster fainted or left before it landed.
- Produces: player Fighter `protectedUntil: number` (0 by default); `BattleSim.swap` returns `nil, "casting"` while the outgoing creature has a super winding up.

- [ ] **Step 1: Balance baseline.** `lune run tools/balance/bosses 400 > <workspace>/balance-before.txt`.
- [ ] **Step 2: Write the failing tests** (use the spec file's existing helpers: `fighter`, `side`, `castNow`, `timedEvents`, `runFor`, the boss-with-players setup of the "you in the fight" tests):
  - "a super winds up its own time and lands at the end": Infernox (signature "Infernox") — `useAbility(..., "signature")` returns a cast with `seconds == 1.5`, `look == "Inferno"`, `protect == 2.1`; the target's `burnUntil` is still 0 at 1.4 s and set by 1.6 s; `signatureReady == press + 15`.
  - "a Legendary super winds up 2 s": Solarion's cast `seconds == 2`, the 4x hit lands between 1.9 and 2.1 s.
  - "the caster's player can't be hit until control returns": a quick hit due at press + 1.0 → `dodged`; one due at press + 2.3 (Epic: 1.5 + 0.6 = 2.1) → lands.
  - "no new quick hits or rings at the caster's player meanwhile": with two players, run 2 s after the press with a boss whose `every` makes a big attack start inside the window: no `ring` or `telegraph` event `to` the caster's player during it; the other player still gets them.
  - "a super whose caster faints fizzles and ends the protection": faint the caster at 0.5 s → a `fizzle` event with its look, no ability event, the player's `protectedUntil <= state.time`.
  - "a creature winding up its super can't be swapped out": `BattleSim.swap` during the wind-up → `nil, "casting"`; after it lands → succeeds.
  - "pet moves still wind up 0.5 s": an element ability's cast `seconds == 0.5`, no `protect`.
- [ ] **Step 3:** `lune run tests/run BattleSim` — the new tests FAIL.
- [ ] **Step 4: Implement.** In `useAbility`, `which == "signature"`: windup = `ability.windup`; set the owner's player fighter (`playerOf(state, ownerKey(fighter))`, when there is one) `protectedUntil = state.time + windup + SUPER_PROTECT_TAIL`; the cast event as above (`to` from the creature's usual target). In `releaseCasts`, a super whose fighter fainted or left emits `fizzle` and sets that player's `protectedUntil = state.time`. Landing pending hits: `missed` also when `state.time < target.protectedUntil`. `swingAtPlayer` and `bigAttack` leave out players with `state.time < protectedUntil` (before any random is drawn, so fights with nobody protected replay exactly as before). `BattleSim.swap` refuses while `state.casts` holds a super by the outgoing creature.
- [ ] **Step 5:** `lune run tests/run` — all pass.
- [ ] **Step 6: Balance after.** Same command into `balance-after.txt`; compare. Report the change in one DESIGN sentence; leave numbers as they are (spec).
- [ ] **Step 7:** DESIGN: the supers paragraph (wind-up by rarity, protection, fizzle, swap block). Commit `Super moves: wind-up, protection and fizzle in the sim`.

### Task 2: Config/SuperFx, Util/SuperFxRules, preload

**Files:**
- Create: `src/shared/Config/SuperFx.luau`, `src/shared/Util/SuperFxRules.luau`, `tests/SuperFx.spec.luau`
- Modify: `src/shared/Util/CombatPreload.luau` (`More.superFx`), `src/client/Util/CombatAssets.luau` (pass it), `tests/CombatPreload.spec.luau`, `tests/run.luau` (`SuperFx = require("./SuperFx.spec")`), CLAUDE.md test list (`SuperFx`)

**Interfaces:**
- Produces `Config/SuperFx` (plain data, `rgb` tables, no Color3):
  - `TIERS = { Epic = { windup = 1.5, call = 0.3, bars = false, impactFrame = false, sky = false, swoop = <studs> }, Legendary = { windup = 2, call = 0.3, bars = true, impactFrame = true, sky = true, swoop = <studs> } }`
  - `LOOKS[<look id>] = { tier, card, element, color, grades = { C, B, A, S } }` for the ten looks; every grade has at least `scale`, `particles`, `shake` (numbers) and `extra` (boolean, true only at S); look-specific fields free.
  - `LOW_GRAPHICS_GRADE = "B"`, `CAMERA = { callDistance, callHeight, impactDistance, impactHeight, fov, ease }` (multiples of the creature's height), `TEXTURES = {}`, `SOUNDS = { [look id] = {} }` (filled in Tasks 5-14).
- Produces `Util/SuperFxRules`:
  - `grade(grade: string?, extrasOn: boolean, cfg: any): string` — "C" for nil/unknown; A and S become `LOW_GRAPHICS_GRADE` when extras are off.
  - `look(cfg: any, lookId: string, grade: string?, extrasOn: boolean): any` — `cfg.LOOKS[lookId].grades[grade(...)]`.
  - `beats(tier: string, tail: number, cfg: any): { call: number, impact: number, back: number }` — call = `TIERS[tier].call`, impact = `TIERS[tier].windup`, back = windup + tail.
  - `shot(beat: string, creature: Vec, height: number, facing: Vec, target: Vec?, cfg: any): (Vec, Vec)` — the camera's eye and focus, `Vec = { x: number, y: number, z: number }`. "call"/"charge": low and close in front of the creature (eye `callDistance` × height ahead of it along `facing`, `callHeight` × height up, focus its chest). "impact": behind and beside the creature, far enough (`impactDistance` × height) that creature and target both sit in view, focus between them; with no target, a wide shot of the creature.
- Produces: `CombatPreload.collect(..., more)` with `more.superFx` adds every `SOUNDS` id and `TEXTURES` id.

- [ ] **Step 1: Write the failing tests** in `tests/SuperFx.spec.luau`:
  - "every super has a look, for all four grades": each `Combat.SIGNATURES` entry's `look` is a `LOOKS` key, and every look has C, B, A, S; there are exactly 10 looks.
  - "a look's tier is its card's rarity, and the sim's wind-up matches": `LOOKS[l].card`'s `CardList` rarity == `LOOKS[l].tier`; `Combat.SIGNATURES[card].windup == TIERS[tier].windup`.
  - "each grade is a step up": per look, every numeric grade field never drops C→S and `scale`, `particles`, `shake` grow strictly; booleans once true stay true; `extra` only at S.
  - "no grade or an unknown one plays C; low graphics caps at B": `grade(nil, true) == "C"`, `grade("Z", true) == "C"`, `grade("S", false) == "B"`, `grade("A", false) == "B"`, `grade("C", false) == "C"`, `grade("S", true) == "S"`.
  - "the beats": `beats("Epic", 0.6, cfg)` → call 0.3, impact 1.5, back 2.1; Legendary → 0.3, 2, 2.6.
  - "the camera frames the creature, then both": `shot("call", {0,0,0}, 10, {0,0,1}, nil, cfg)` eye is in front (z > 0), within 3 × height, focus within the creature's height; `shot("impact", {0,0,0}, 10, {0,0,1}, {0,0,40}, cfg)` focus lies between them and the eye is farther from both than half their distance; a creature twice as tall puts the call eye twice as far.
  - "only Legendary has bars, the impact frame and the sky": per tier.
  - "every texture and sound is an asset id" (nested, `^rbxassetid://%d+$`).
  - In `tests/CombatPreload.spec.luau`: "the super moves' sounds and textures are fetched ahead too" — a `SOUNDS.Inferno` id placed in a copied config is in `ids.sounds` (use a table copy so the test doesn't wait for Task 5).
- [ ] **Step 2:** `lune run tests/run SuperFx` — FAIL (modules missing).
- [ ] **Step 3: Implement** the config, the rules, the preload addition.
- [ ] **Step 4:** `lune run tests/run` — all pass.
- [ ] **Step 5: Commit** `Super moves: looks config, rules and preload`.

### Task 3: Routing and the Studio preview

**Files:**
- Create: `src/client/Util/SuperFx.luau` (shared helpers and a placeholder per look that plays today's `ElementFx.special` style for its kind, replaced look by look in Tasks 5-14)
- Modify: `src/client/Util/FightFx.luau` (a cast with `look` → `SuperFx.charge`; an ability with `look` → `SuperFx.impact` instead of `ElementFx.special`; `fizzle` → stop the charge; stops kept per caster id, cleared on destroy and on the caster fainting)
- Modify: `src/shared/Remotes.luau` (`MovePreview` payload may carry `super: string` — the look id — and `grade`), `src/server/Services/DevService.luau` (`/superfx <look> [C|B|A|S]`, default S, case-insensitive look id; in the enabled-commands print), `src/shared/Config/AdminPanel.luau` (section "Super moves": a button per look at C and at S, 20), `src/client/Controllers/MovePreviewController.luau` (super previews), CLAUDE.md (`/superfx`)
- Test: `tests/AdminPanel.spec.luau` (already checks commands exist)

**Interfaces:**
- `SuperFx.charge(lookId: string, view: FightFx.View, grade: string, seconds: number, target: Vector3?): () -> ()` — everything from the call to the impact on the caster (aura, pose, light pulling in, the look's build-up, charge sounds); returns a stop.
- `SuperFx.impact(lookId: string, view: FightFx.View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number): () -> ()` — the impact and the linger for the move's seconds; returns a stop.
- Everyone's screen shakes at the impact through `ScreenFx.shakeAt(<look's grade shake> * 0.5, target)` (a lighter shake for onlookers, by distance); the caster's full shake is Task 4's.
- The preview feeds `FightFx` the real event shapes from Task 1 (`cast` with look/seconds/protect/to, `ability` with look `seconds` later), from your summoned creature at a dummy (14 studs at Legendary looks, 6 otherwise), and marks it as yours so Task 4's cinematic plays too.

- [ ] **Step 1:** Add the Admin panel buttons; `lune run tests/run AdminPanel` — FAIL (`/superfx` missing).
- [ ] **Step 2: Implement** routing, placeholder looks, the command and the preview.
- [ ] **Step 3:** `lune run tests/run` — all pass.
- [ ] **Step 4: Studio check:** stop → Play, summon, `/superfx supernova S`: Output clean, the dummy appears, today's falling sun plays after a 2 s wind-up. Then `/maxcard Solarion`, summon it, `/boss 1 fight`, fire its super: the impact lands 2 s after the press.
- [ ] **Step 5: Commit** `Super moves: routing and Studio preview`.

### Task 4: The caster's cinematic

**Files:**
- Create: `src/client/Util/SuperCinematic.luau`
- Modify: `src/client/Controllers/BattleController.luau` (on a super `cast` from your own creature: play; its `ability`: impact; `fizzle`, fight end, defeat, leaving: cut; `onCombatKey` ignores keys while playing; the HUD fades via `CombatHud.setVisible`), `src/client/Controllers/MovePreviewController.luau` (preview plays it)

**Interfaces:**
- `SuperCinematic.play(args: { look: string, tier: string, grade: string, cardName: string, art: string?, color: Color3, creature: BasePart, height: number, target: BasePart?, seconds: number, protect: number, hideHud: (hidden: boolean) -> () })`
- `SuperCinematic.impact()` — the impact beat now (also by itself at `seconds` + 0.3 if the ability event never comes).
- `SuperCinematic.cut()` — back to the player now; `SuperCinematic.isPlaying(): boolean`.
- Consumes: `SuperFxRules.beats`, `SuperFxRules.shot`, `SuperFxRules.grade`, `SuperFxConfig.TIERS/CAMERA/LOOKS`, `ScreenFx.shake/flash`, `Util/SkyLook.hold`.

- [ ] **Step 1: Implement**, in this order, checking each in Studio with `/superfx` before the next:
  - Camera: save CameraType, CFrame, FieldOfView; Scriptable; ease from the player's view to `shot("call")`, drift to `shot("charge")`, snap to `shot("impact")` at the impact, ease back to the saved view at `back`, then Custom. Raycast from the focus to each eye (excluding characters and effects); pull the eye in front of anything hit.
  - Hold still: anchor your root locally while playing (only if this module anchored it, release it).
  - Card cut-in: the card's painting slides across with the move name ("SUPERNOVA!", FredokaOne, element-coloured stroke), on its own ScreenGui above the HUD; a colour wash in `LOOKS[look].color`.
  - Legendary: letterbox bars; `SkyLook.hold(true)` and the look's sky/lighting change (per look, Tasks 5-14), eased back at `back`.
  - Impact: white flash (Epic), black-and-white frame for 2-3 frames (Legendary, a `ColorCorrectionEffect` with saturation -1 and high contrast; extras off: soft white flash), `ScreenFx.shake` by `LOOKS[look].grades[g].shake`.
  - `cut()` and every exit restore all of the above at once.
- [ ] **Step 2:** `lune run tests/run` — all pass (SourceOrder included).
- [ ] **Step 3: Studio check:** `/superfx stampede C` and `/superfx devour S`: screenshot the call (card cut-in), the charge and the impact; Output clean; control back each time. Real fights: Solarion in each of the three Wild boss arenas (the camera never inside a wall); fire, then get the creature to faint mid-wind-up (fizzle: everything back at once); fire and run (fight ends: everything back). Low graphics (`Extras` off): no black-and-white frame.
- [ ] **Step 4: Commit** `Super moves: the caster's cinematic`.

### Tasks 5-14: the ten looks, one task each

Order: Inferno, Magma Slam, Tidal Shield, Tidal Blessing, Stampede, Eclipse, Rift Step, Supernova, Thunderstorm, Devour. Every look task has the same shape:

**Files:** `src/client/Util/SuperFx.luau` (the look's `charge` and `impact`), `src/shared/Config/SuperFx.luau` (its grades tuned, `SOUNDS.<look>`, any `TEXTURES`), `tools/textures/make_super_fx.py` (created in Task 5; one function per texture, writes `assets/ui/fx-super/*.png`, white with alpha), `src/client/Util/SuperCinematic.luau` (the look's camera notes and, for Legendary looks, its sky/lighting change). A mesh only if the look can't be done with parts, beams and textures: a `tools/blender/build_super_<thing>.py` run in a background Blender, saved under `assets/super-fx/` and synced like `assets/props` (decide at that task; note it in DESIGN and CLAUDE.md).

**Steps for each:**
- [ ] **Step 1:** Textures the look needs: draw, render, upload through the Studio MCP (`upload_image` from a localhost server), ids in `TEXTURES`.
- [ ] **Step 2:** Sounds: find them through the toolbox API (licensed only): a call sting, a charge riser, the impact (boom + element layer), a linger loop or tail where the move lasts, extra layers for A and S → `SOUNDS.<look> = { call, charge, impact, layer, linger? }`. `lune run tests/run SuperFx` — passes.
- [ ] **Step 3: Implement** the look exactly as the spec's section for it describes (call / charge / impact / linger, what grows with grade, the S extra), through `LOOKS.<look>.grades`.
- [ ] **Step 4:** `lune run tests/run` — all pass.
- [ ] **Step 5: Studio check:** `/superfx <look> C`, `B`, `A`, `S`: screenshot each at the charge and at the impact; each grade visibly bigger; the S extra there; Output clean; then once in a real boss fight with `/maxcard <card>`.
- [ ] **Step 6: Commit** `Super moves: <Move name>`.

Look-specific needs (beyond the spec's description):
- **Task 5 Inferno:** the fire tornado (a funnel of spinning flame beams or a mesh); the burn's linger lasts the sim's 6 s and stops if the boss dies.
- **Task 7 Tidal Shield:** the sim reports each absorbed hit (`absorbed` on the hit event, test "a hit the shield soaks reports absorbed") and the side's shield running out (`{ type = "shieldGone", side }`, test), so the dome ripples and bursts; the dome also bursts at fight end. These two sim tests are this task's failing tests, written first.
- **Task 8 Tidal Blessing:** the lotus (petals as textured parts or a mesh); the parting clouds and rays are world objects for everyone, the sky change only in the caster's cinematic.
- **Task 9 Stampede:** the dash moves the creature's drawn body through the boss and back (`resolve.dash`), afterimages; the stun rings last `min(stun, BOSS_MAX_STUN)` on bosses.
- **Task 10 Eclipse / Task 11 Rift Step:** attacks it dodges (`dodged` attack events on it) puff shadow / hit empty rifts for the 3 s.
- **Task 12 Supernova, Task 13 Thunderstorm, Task 14 Devour:** Legendary sky changes in the caster's cinematic (deep space, storm, dimmed world); their world objects (the sun, storm clouds, black hole, jaws) for everyone.

### Task 15: Finish — completeness, cost, docs

**Files:**
- Modify: `tests/SuperFx.spec.luau` ("every look has its sounds": call, charge, impact for all ten, a linger for Inferno, Tidal Shield, Tidal Blessing, Eclipse, Rift Step, Thunderstorm, Devour), `DESIGN.md` (supers section rewritten, the fight effects paragraph, checklist line "- [ ] Super moves round (branch `super-moves`...)"), CLAUDE.md (assets/super-fx if any, `assets/ui/fx-super`, the texture tool)
- Remove: `ElementFx.special` branches and `AttackFx.SPECIALS` entries nothing uses any more (grep first)

- [ ] **Step 1: Write the failing test** above; `lune run tests/run SuperFx` — FAIL if any sound is missing; fill it.
- [ ] **Step 2: Measure** in Studio (stop → Play): render CPU frame time (`Stats.RenderCPUFrameTime`, fixed camera, graphics 10 and 1) idle, each look at S alone, and four at once (two previews from two clients in a Local Server, or the preview fired four times). Budget: within `AttackFx.MAX_ACTIVE` / `MAX_ACTIVE_LOW`, no frame over 33 ms on graphics 1; report the numbers in DESIGN.
- [ ] **Step 3:** Docs; `lune run tests/run` — all pass.
- [ ] **Step 4: Commit** `Super moves: docs and cost check`.
