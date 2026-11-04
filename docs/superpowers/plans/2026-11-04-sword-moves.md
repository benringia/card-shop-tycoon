# Sword Moves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Anime, hack-and-slash sword moves for the Steel Sword: four new moves with natural easing and overlap,
lunges and chained cuts, a dash-slash special, and candy sparkle arcs with star-burst hits.

**Architecture:**
- **Blender tooling:** `anim_kit` gains per-key easing, joint overlap, a two-hand IK grip and in-place 60 fps export.
  The new moves are keyed in `anim_starter_sword.py` from the approved spike and exported to KeyframeSequences.
- **Rules:** timing, lunge and dash rules are pure functions in `SwordRules`, used by the server (`BattleService`) and
  the client (`SwordController`).
- **Effects:** the effects are client-only Beams and particles in `HitFx`, using PIL-made textures that get uploaded.

**Tech Stack:** Luau (Rojo, Lune tests), Blender 5.2 in background mode (Python), Pillow, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-04-sword-moves-design.md`

## Global Constraints

- "dont touch the combat UI's": the fight HUD, its buttons and screens. Task 8 only applies if the owner says yes.
- Server authoritative:
  - The server decides cut timing, the cancel point, reach and the dash path (clamped).
  - Movement (lunges, the dash) is client physics like today's dodge.
- The combo's damage per second on the chained cycle is within 2 % of today's (0.7182 power a second: 1.30 power over
  1.81 s).
- Blender runs only as a background process (`blender.exe -b --factory-startup --python ...`), never in the owner's
  open Blender.
- Numbers go in `src/shared/Config`. Pure rules go in `SwordRules` (no requires) with Lune tests written first.
- Sounds: reuse today's licensed sword sounds.
- The branch is `sword-moves`. Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No merge or
  push until the owner has published the moves.
- The other moves (draw, sheath, dodge, flinch, down, getUp, ready, run) are untouched and not re-exported.

## Review Focus

1. **A tap during the cancel window, a late tap, and a dodge mid-swing.** Expected: walking returns, the next cut or
   the dodge starts cleanly, and controls are never left disabled. Owner: Task 5, Studio step plus the
   `nextCut` tests.
2. **A lunge started right at a boss's edge, or facing a wall or the arena barrier.** Expected: no movement into the
   boss, and the wall stops you. Owner: the Task 3 `lungeLength` tests plus a Task 5 Studio step.
3. **A client that lies about the dash.** Expected: the server clamps the path to `maxStuds` plus slack, and foes
   beyond aren't hit. Owner: the Task 3 `clampPath` test plus a Task 4 Studio step.
4. **Effects in a group fight and with many foes (wild packs).** Expected: no errors and no leftover parts; the
   effects clean up. Owner: Task 7, Studio step.
5. **The fight ending mid-swing, or being knocked down mid-dash.** Expected: the movement push and the controls lock
   are released. Owner: Task 5, Studio step.

---

### Task 1: Animation tools: easing, overlap, two-hand grip, in-place 60 fps export

**Files:**
- Modify: `tools/blender/anim_kit.py`
- Modify: `docs/animations.md`

**Interfaces:**
- Produces:
  - `kit.ease_key(channel: str, frame: int, interp: str, easing: str)` records how a channel leaves a key.
  - `kit.key_pose(rig, frame, pose, lift=0.0, ease=("SINE","EASE_IN_OUT"), lag=None)`: `lag` defaults to the module's
    `LAG` (today's), and moves pass the new overlap `LAG_SWORD = {"W":1,"N":2,"RS":1,"RE":2,"RW":3,"LS":2,"LE":3,"LW":4}`.
  - `kit.key_root(rig, frame, forward, sideways=0.0, ease=...)` and `kit.key_foot(side, frame, pos, ease=...)` gain the
    same `ease` argument.
  - `kit.apply_eases(rig)` writes the recorded interpolation onto every fcurve key.
  - `kit.two_hands(rig, frame_of, on, full, release, off, along=-0.55)` adds the left-forearm IK grip.
  - `kit.export_move(..., in_place=False, step=EXPORT_STEP)`: with `in_place`, the rig's travel is dropped from the Root
    offset.
  - `kit.render_video(path, first, last, cam_pos, target, size=(640,480))` writes a 60 fps MP4 (FFMPEG H.264).
  - `kit.fcurves_of(obj)` reads both the layered and the legacy action API.
- The spike `anim_sword_v3.py` (scratchpad) is the reference for every helper's behaviour.

- [ ] **Step 1:** Port `EASES`, `apply_eases` and `_fcurves` from the spike into `anim_kit`. Today's moves keep today's
  behaviour: no `ease` means default Bezier, so the old keys are untouched.
- [ ] **Step 2:** Port `two_hands` (the LeftGrip empty on the RightHand bone at the grip offset, the LeftElbowPole at
  (2.5, 1.5, 2.0), IK chain 2, pole angle 180°, influence keys).
- [ ] **Step 3:** Add `in_place` to `export_move`: `entry["p"]` uses `pb.head - pb.bone.head_local` without `moved`.
  Add the `step` parameter.
- [ ] **Step 4:** Add `render_video`, using the spike's `_video_settings`.
- [ ] **Step 5: Check.** Run a background Blender that rebuilds `ready` with the old code path, export it to a scratch
  folder, and confirm its JSON matches today's `assets/blender/Animations/StarterSword/ready.json` byte for byte
  (today's moves are unchanged).
- [ ] **Step 6:** Update docs/animations.md (the new helpers, background runs, in-place export, 60 fps). Commit:
  "Animation tools: per-key easing, joint overlap, two-hand grip, in-place 60 fps export".

### Task 2: The four new moves, exported

**Files:**
- Modify: `tools/blender/anim_starter_sword.py`: `_cut1`, `_cut2`, `_cut3`, `_skill` and their `MOVES` entries
- Create: `tools/blender/run_sword_moves.py` (background runner: export, plus optional preview videos)
- Modify: `assets/blender/Animations/StarterSword/{cut1,cut2,cut3,skill}.json`,
  `assets/animations/StarterSword/{cut1,cut2,cut3,skill}.rbxm`
- Modify: `src/shared/Config/Swords.luau` (`animations.cut1..cut3, skill = ""` until published)

**Interfaces:**
- Consumes: Task 1's helpers.
- Produces: KeyframeSequences with markers:
  - cut1 `Hit` 0.217, length 0.60
  - cut2 `Hit` 0.183, length 0.58
  - cut3 `Hit` 0.40, length 0.88
  - skill `Hit` 0.62, length 1.0

  They are exported in place, at `step=1`.

- [ ] **Step 1:** Port the v3 keys exactly, with `lag=kit.LAG_SWORD` and the eases. In cut3, the `two_hands(0.02,
  0.12, 0.66, 0.80)` call and the inward arm angles. Root travel stays keyed: it drives the previews and Config's
  lunges.
- [ ] **Step 2:** Run `run_sword_moves.py` in background Blender. It writes the JSONs and preview MP4s into the
  brainstorm content folder (`moves-final-<move>-<view>.mp4`). Compare them with the approved `v3-*.mp4` stills; they
  should match.
- [ ] **Step 3:** Run `lune run tools/anim/build_kfs`. Expected: the four `.rbxm` files are rewritten and the other
  moves are unchanged (`git status` shows only those four).
- [ ] **Step 4:** Blank the four ids in `Config/Swords.animations`, so Studio registers the new KeyframeSequences.
- [ ] **Step 5:** Run `lune run tests/run`. Expected: green (SwordsConfig still sees every key). Commit: "Sword moves:
  anime forehand, backhand, two-handed spinning slam, dash slash".

### Task 3: Rules and numbers: cancel points, lunges, the dash path, the same damage per second

**Files:**
- Modify: `src/shared/Util/SwordRules.luau`
- Modify: `src/shared/Config/Swords.luau` (combo timings, powers, lunges; skill dash)
- Modify: `tests/SwordRules.spec.luau`, `tests/SwordsConfig.spec.luau`
- Modify: `tools/balance/bosses.luau`, `tools/balance/wild.luau` (chain on cancel points)

**Interfaces:**
- **Types:**
  - `Cut = { power, hitAt, cancelAt: number?, length, reach, arc, lunge: { studs: number, from: number, to: number }? }`
  - `Skill = { power, hitAt, length, cooldown, dash: { studs: number, maxStuds: number, margin: number, width: number, from: number, to: number, slack: number } }`
- **Rules:**
  - `SwordRules.nextCut(combo, last, now, comboReset)`: taps from the strike until the cancel point queue the next cut
    for the cancel point (`cancelAt` or `length`). Taps from then until `length + comboReset` start it at once. Later
    taps restart the combo.
  - `SwordRules.comboPowerPerSecond(combo)`: the cycle is each cut's `cancelAt` (or `length`), and the last cut's
    `length`.
  - `SwordRules.lungeLength(px, pz, dirX, dirZ, targets, studs, stopMargin): number`: how far you can move along the
    direction, up to `studs`, stopping `stopMargin` short of any foe's edge (0 if you're already there).
  - `SwordRules.inDashPath(sx, sz, ex, ez, tx, tz, targetRadius, width): boolean`: whether the segment comes within
    `targetRadius + width / 2` of the foe's centre.
  - `SwordRules.clampPath(sx, sz, ex, ez, maxLength): (number, number)`: the end point, pulled back to `maxLength`.
- **Config values:**
  - cut1 `{ power = 0.298, hitAt = 0.217, cancelAt = 0.34, length = 0.60, reach = 9, arc = 80, lunge = { studs = 1.1, from = 0.167, to = 0.25 } }`
  - cut2 `{ power = 0.298, hitAt = 0.183, cancelAt = 0.32, length = 0.58, reach = 9, arc = 100, lunge = { studs = 0.8, from = 0.133, to = 0.22 } }`
  - cut3 `{ power = 0.51, hitAt = 0.40, length = 0.88, reach = 10, arc = 70, lunge = { studs = 2.6, from = 0.17, to = 0.40 } }`
  - skill `{ power = 0.9, hitAt = 0.62, length = 1.0, cooldown = 8, dash = { studs = 9, maxStuds = 20, margin = 1.5, width = 4, from = 0.30, to = 0.42, slack = 3 } }`
  - `Swords.LUNGE_STOP = 1.0`: studs short of a foe's edge a lunge stops.

- [ ] **Step 1: Write failing tests** in `tests/SwordRules.spec.luau`:
  - **Cancel point:** cut `{hitAt 0.2, cancelAt 0.35, length 0.6}`, with the last cut started at 0. A tap at 0.25
    returns `2, 0.35`; at 0.40 returns `2, 0.40`; at 0.6 + reset + 0.01 returns `1, now`.
  - **Damage per second:** combo powers 0.3/0.3/0.5, cancel points 0.34/0.32, last length 0.88:
    `comboPowerPerSecond = 1.1 / 1.54`.
  - **Lunge:**
    - a foe at (5, 0) radius 2, lunging along +x with studs 4 and stop 1: returns 2.0;
    - no foe ahead: returns 4;
    - already at the stop distance: returns 0;
    - a foe off to the side (y offset larger than its radius): ignored.
  - **Dash path:** start (0, 0), end (9, 0), width 4. A foe at (5, 2.5) radius 1 is hit; one at (5, 4) radius 1 isn't;
    one at (12, 0) radius 2 is hit (its edge reaches the end).
  - **Clamped path:** `clampPath(0, 0, 30, 0, 20)` returns `20, 0`; `clampPath(0, 0, 10, 0, 20)` returns `10, 0`.
- [ ] **Step 2:** Add to `tests/SwordsConfig.spec.luau`:
  - each cut has `hitAt < (cancelAt or length) <= length`;
  - every lunge sits inside its cut, starting no later than its strike;
  - the skill's dash sits before its `hitAt`;
  - `comboPowerPerSecond(starter.combo)` is within 2 % of 0.7182.
- [ ] **Step 3:** Run `lune run tests/run SwordRules` and `SwordsConfig`. Expected: FAIL.
- [ ] **Step 4:** Implement the rules, the types and the config values. Update both balance sims so the next cut
  starts at its cancel point.
- [ ] **Step 5:** Run `lune run tests/run`. Expected: green. Then run `lune run tools/balance/bosses 400` and
  `lune run tools/balance/wild 300`. Expected: within each tool's targets (well about 85 % at 1x and 50 % at 0.8x,
  still about 60 % / 15 %; wild per its header). If they drift, re-tune only the cut powers and keep the 2 % rule.
- [ ] **Step 6:** Commit: "Sword rules: cancel points, lunges that stop short, the dash slash's path; same damage a
  second".

### Task 4: Server: the cancel point and the dash slash's path

**Files:**
- Modify: `src/server/Services/BattleService.luau` (`onSwordSkill`)

**Interfaces:**
- Consumes: `SwordRules.inDashPath` and `SwordRules.clampPath` from Task 3, plus `Skill.dash`.

- [ ] **Step 1:** In `onSwordSkill`, record the root's X and Z when the skill starts. At `hitAt`, call `strike` with a
  reach function. It clamps the current position with `clampPath(sx, sz, px, pz, dash.maxStuds + dash.slack)` and
  hits targets with `inDashPath(..., dash.width)`.
- [ ] **Step 2:** `onSwordAttack` already uses `SwordRules.nextCut`, so the cancel point needs no extra code. Keep it,
  and confirm the queued-cut delay uses the returned start time.
- [ ] **Step 3:** Run `lune run tests/run`; expected green. Then `rojo build`.
- [ ] **Step 4: Studio check.** A boss fight, through the MCP: fire the dash-slash remote from the client after
  stepping 9 studs past the boss; the boss takes the hit. Then teleport the client 40 studs mid-dash; no hit beyond the
  clamp (Review Focus 3).
- [ ] **Step 5:** Commit: "Server: the dash slash hits along its clamped path".

### Task 5: Client feel: lunges, chained cuts, the walking hold, the dash slash's movement

**Files:**
- Modify: `src/client/Controllers/SwordController.luau`
- Modify: `src/client/Util/SwordAnims.luau` (short fades for the strikes; hit-stop length passed in)
- Modify: `src/shared/Config/SwordFx.luau` (`HIT_STOP = { cut = 0.08, big = 0.12 }`; `FADE = { strike = 0.04 }`)
- Modify: `src/client/Controllers/BattleController.luau` (the hit-stop length per kind)

**Interfaces:**
- Consumes: `SwordRules.lungeLength`, `SwordRules.dashLength`, `Cut.lunge`, `Skill.dash`.
- Produces:
  - A local `push(root, direction, studs, seconds)`: today's dodge LinearVelocity code, moved into one helper that the
    dodge, the lunges and the dash all use.
  - A local `holdControls(seconds)`: `PlayerModule:GetControls():Disable()` with a token so the latest hold wins,
    re-enabled at the end, on a dodge, when combat ends, and on knock-down. `Humanoid.AutoRotate` is false while held.

- [ ] **Step 1:** Factor the dodge's push into `push`; the dodge keeps its exact behaviour.
- [ ] **Step 2: Attack.** At the cut's start:
  1. soft aim;
  2. play the cut with the strike fade;
  3. call `holdControls(cancelAt or length)`;
  4. at `lunge.from`, push forward
     `SwordRules.lungeLength(..., combatTargets(), lunge.studs, Swords.LUNGE_STOP)` studs over `lunge.to - lunge.from`.
- [ ] **Step 3: Skill.**
  1. `holdControls(length)`;
  2. play `skill`;
  3. at `dash.from`, push along your facing for `SwordRules.dashLength(..., dash.studs, dash.margin, dash.maxStuds)` over
     `dash.to - dash.from`, with `AfterImage.spawn` along it;
  4. predict the hit at `hitAt` with `inDashPath` from the recorded start.
- [ ] **Step 4:** Release the hold on a dodge, at combat end, in `GetUp` / knock-down, and on character removal.
- [ ] **Step 5:** The hit-stop per kind: cuts 0.08 s, the finisher (last cut) and the skill 0.12 s.
- [ ] **Step 6:** Suite and build.
- [ ] **Step 7: Studio check.** Against a wild monster and a boss (`/boss 1 fight`):
  - **The combo:** it chains when tapping, lunges stop at the boss, and you can't walk mid-swing but can walk after.
  - **Dodging mid-swing:** it works and controls come back (Review Focus 1).
  - **The dash slash:** it carries you through and hits.
  - **Edges** (Review Focus 2, 5): a lunge facing the barrier, and the fight ending mid-swing.

  Screenshot the frames.
- [ ] **Step 8:** Commit: "Sword feel: lunges, chained cuts, walking held mid-swing, the dash slash moves you".

### Task 6: Effect textures

**Files:**
- Create: `tools/textures/make_sword_fx.py` (Pillow) and `assets/ui/fx-sword/{Crescent,Burst,Line,Star}.png`
- Modify: `src/shared/Config/SwordFx.luau` (`TEXTURES = { crescent, burst, line, star }`)
- Modify: `tests/SwordsConfig.spec.luau` (the texture ids are uploaded ids)

- [ ] **Step 1: Write the failing test.** Every `SwordFx.TEXTURES` entry matches `^rbxassetid://%d+$`. Run it; FAIL.
- [ ] **Step 2: Write `make_sword_fx.py`:**
  - **Crescent:** 512 x 128. White, its alpha strongest in a band towards the leading (right) end, with a soft tail to
    the left and a hard bright edge along the top: a beam texture that runs along its length.
  - **Burst:** a 4 x 4 flipbook, 1024 px, of an 8-spike star popping out and fading.
  - **Line:** 256 x 32, a sharp streak tapered at both ends.
  - **Star:** 128 px, a 4-point sparkle.

  All white with alpha (tinted in game), squares where particles use them.
- [ ] **Step 3: Upload.** Run `python -m http.server 8765 --bind 127.0.0.1` in the folder, in the background. Call the
  MCP `upload_image`, put the ids in `SwordFx.TEXTURES`, then stop the server.
- [ ] **Step 4:** Run the test; PASS. Commit: "Sword effect textures: crescent, burst, line, star".

### Task 7: Effects: arcs on every swing, bursts, rings, cut lines, the landing puff

**Files:**
- Modify: `src/client/Util/HitFx.luau`
- Modify: `src/shared/Config/SwordFx.luau` (`ARCS` per cut: plane tilt, radius, sweep degrees, direction,
  wipe/fade seconds, width; `BURST`; `RING`; `CUT_LINES`; `DUST`)
- Modify: `src/client/Controllers/SwordController.luau` (an arc at each swing's start), `BattleController.luau`
  (`swordHit`: burst; ring on the finisher and skill; cut lines on skill hits)

**Interfaces:**
- **Produces in `HitFx`:**
  - `swingArc(root: BasePart, arc: ArcLook, slash: { color, scale })`: a Beam between two Attachments on a circle in
    the swing's plane (relative to the root's CFrame), with `CurveSize0/1` from the arc's sweep (4/3·r·tan(θ/4)) so it
    bulges into a circular arc. `Texture = TEXTURES.crescent`, coloured with the sword's slash colour (white core to
    colour). Each frame its Transparency NumberSequence opens a moving window (the wipe) over `wipe` seconds, then it
    fades over `fade`. A star ParticleEmitter rides an attachment along the arc during the wipe.
  - `burst(at: Vector3, size: number)`: a one-shot ParticleEmitter using the burst flipbook (Grid4x4, OneShot).
  - `ring(at: Vector3, size: number)`
  - `cutLines(at: Vector3, size: number)`: two crossing Beams that grow and fade.
  - `dust(at: Vector3)`
  - All parented to a Folder under `workspace.CurrentCamera` and cleaned with Debris.
- **`SwordFx.ARCS` arc shapes:** cut1 diagonal down-left, cut2 rising left-to-right, cut3 vertical top-to-bottom in
  front, plus a horizontal draw for the skill. Each has `{ tilt, yaw, radius, sweep, from, wipe, fade, width }`.

- [ ] **Step 1:** Implement the five functions and the config. The old `HitFx.cut` / `HitFx.spin` slash billboards are
  removed with their callers.
- [ ] **Step 2: Hook them up.**
  - `SwordController`: an arc at each swing's start (`from` offset per cut), and the dust puff at cut3's `hitAt`.
  - `BattleController.swordHit`: a burst on every sword hit; a ring on the last cut and skill hits; cut lines on skill
    hits. The existing sparks and flash stay.
- [ ] **Step 3:** Suite (including SourceOrder) and build.
- [ ] **Step 4: Studio check.** Each cut, the finisher and the dash slash against a boss and a wild pack, with
  screenshots mid-arc (freeze with a short task.wait in a capture script).
  - The arcs lie in the swing's plane, wipe the right way and fade.
  - The bursts, rings and cut lines show, and the boss's rings stay readable.
  - About 60 fps, and no leftover parts after 10 s (Review Focus 4).
- [ ] **Step 5:** Commit: "Sword effects: candy sparkle arcs on every swing, star bursts, rings, cut lines, dust".

### Task 8 (only if the owner says yes): the skill button's name

**Files:** `src/shared/Config/CombatHud.luau` (`BUTTONS.skill`)

- [ ] `name = "DASH"`, `tip = "Dash through and slash everything in your path."`, `emoji = "⚡"`. The icon stays
  `SpinSkill` unless the owner wants new art. Suite green; commit.

### Task 9: Docs

- [ ] **DESIGN.md:**
  - the sword combat section: the moves, cancel points, lunges, the walking hold, the dash slash, effects, and the
    hit-stop numbers;
  - the folder structure: `assets/ui/fx-sword` and the tools.
- [ ] **docs/animations.md:** the new moves and publishing.
- [ ] **CLAUDE.md:** the asset line for `assets/ui/fx-sword` and the tool.

Commit: "Docs: sword moves round".

After the final review: the owner saves the four KeyframeSequences to Roblox (Studio, right-click → Save to Roblox).
The ids go in `Config/Swords`, then the branch merges.
