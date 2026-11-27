# Tutorial Arrows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pish's and Chikin's paw cues become arrows: a chunky gold arrow on what to use, chevrons lying on the ground
for the next stretch of the way, an arrow at the screen's edge for an off-screen goal, the talk card clear of it.

**Architecture:** Pure rules (`TrailRules`, `CueShape`, `TalkRules`) carry every number a test can check; the client's
`Util/TutorialCues` draws them (screen pointer, edge arrow, SurfaceGui chevrons on client-side parts); `Util/TutorialTalk`
keeps its card off the world arrow. Two new pictures from a Pillow script.

**Tech Stack:** Luau (Roblox), Lune tests (`lune run tests/run`), Python + Pillow, Studio MCP (upload, Play check).

**Spec:** `docs/superpowers/specs/2026-11-27-tutorial-arrows-design.md`

## Global Constraints

- Owner's picks: B (chunky gold arrow, white sticker edge, dark outline) and 1 (ground chevrons, next stretch only).
- Ground chevrons show through walls and doors (SurfaceGui `AlwaysOnTop = true`, `LightInfluence = 0`).
- Paws stay where they mean Pish: his face, the tour card's progress paws, the Pet button, the `Paw` icon.
- Numbers live in `Config/Cues`; pure modules require no siblings (Lune); client code compiles
  (`lune run <scratchpad>/tools/compile_check.luau <files>`); edit `src` with Edit/Write only (no sed: Rojo).
- Plain ASCII text in game words.

## Review Focus

- A goal straight behind the camera: the edge arrow sits at a side edge, never at the bottom over the tiles.
- A goal off the top of the screen: the edge arrow stays in the band below the talk card.
- A player past the route's last chevron: nothing ahead shows (the goal's own arrow does).
- A route shorter than one gap: one chevron, and the window still works.
- The talk card with both a button target and a world arrow: the button wins, as today.

---

### Task 1: The pictures

**Files:** Create `tools/ui-icons/make_cue_arrows.py`, `assets/ui/icons/ArrowCue.png`, `assets/ui/icons/Chevron.png`;
Modify `src/shared/Config/UIIcons.luau`; Test `tests/CueShape.spec.luau`.

- [ ] Test "the arrows' pictures are uploaded": `UIIcons.ArrowCue` and `UIIcons.Chevron` are `rbxassetid://` strings.
      Run `lune run tests/run`, expect that test to FAIL (nil).
- [ ] Script: `ArrowCue.png` 256 px, the mockup's arrow pointing down (shaft x -15..15 from y -40 to -2, head x -35..35
      to the tip at y 38 in a 100-unit box; dark #3a1d0b outline 8 units out, white 4.5 units out, gold gradient
      #ffe789 to #ffb21f, a shine on the shaft); `Chevron.png` 256 px, a chevron pointing up (forward), the same three
      layers (dark 20, white 13, gold 7 units wide, round joins). Run it, look at both.
- [ ] Serve `assets/ui/icons` on localhost, `upload_image` both, put the ids in `Config/UIIcons`. Test PASSES.

### Task 2: The trail's next stretch

**Files:** Modify `src/shared/Util/TrailRules.luau`; Test `tests/TrailRules.spec.luau`.

**Produces:** `Paw.distance: number` (studs along the route); `TrailRules.progress(route: {Point}, at: Point): number`
(studs along the route of its point nearest `at`, XZ); `TrailRules.ahead(paws: {Paw}, progress: number, count:
number): (number, number)` (first and last index shown; first > last when none).

- [ ] Tests: distances 4, 8, 12, 16 on the L route; progress 0 at the start, 10 at the corner, 14 for a point beside
      the second leg 4 studs in, clamped to the ends; ahead: progress 0 shows 1..count, progress 9 starts at the 3rd
      (12 > 9), progress past the last shows none, count past the end clamps to #paws. RED, then implement, GREEN.

### Task 3: Shapes and numbers

**Files:** Modify `src/shared/Util/CueShape.luau`, `src/shared/Config/Cues.luau`, `src/shared/Util/TalkRules.luau`;
Test `tests/CueShape.spec.luau`, `tests/TalkRules.spec.luau`.

**Produces:** `CueShape.offscreen(rel: {x, y, z}, view: {w, h}, cfg: {margin, top, bottom}): {x, y, rotation}`
(rel in camera space: x right, y up, z ahead; rotation degrees clockwise from pointing down); `CueShape.pointerSide`
(was `pawSide`); `TalkRules.pointerBox` (was `pawBox`); `Cues.POINTER {size, min, sideShare}`, `Cues.TRAIL {gap,
ahead, fade, size, lift, pixelsPerStud, dim, rotation, max}`, `Cues.OFFSCREEN {margin, top, bottom}` (PAW, PRINT,
BACKING gone).

- [ ] Tests (view 1000 x 600, margin 50, top 0.25, bottom 0.3): straight left in front → x 50, y 300, rotation 90;
      right → x 950, rotation -90; far above → y 150 (the band's top), rotation -180; straight behind (z < 0, x 0) →
      right edge at the band's middle (y 285), rotation -90; behind-left → left edge, rotation 90; a down-left
      diagonal lands on the band's edge it meets first. Config: the old "more noticeable" checks re-pinned on POINTER
      and TRAIL. Renames in the tests. RED, then implement, GREEN.

### Task 4: Drawing them

**Files:** Modify `src/client/Util/TutorialCues.luau`, `src/client/Util/TutorialTalk.luau`,
`src/client/Controllers/TutorialController.luau`, `src/client/Controllers/ChikinController.luau`.

**Consumes:** Tasks 1-3. **Produces:** `TutorialCues.pointAt(target, around?)`, `TutorialCues.scrollHint(list)`,
`TutorialCues.worldPointerBox(): TalkRules.Box?`.

- [ ] The pointer: `ArrowCue` icon (rotation 0 down, 180 up, 90 left), no backing or halo; world: on screen as today,
      else `CueShape.offscreen` with a nudge toward the edge; keep its rest box (bounce room) for the talk card.
- [ ] The trail: pathfinding route as today, `TrailRules.along(route, TRAIL.gap, TRAIL.max)`, a pool of `TRAIL.ahead`
      parts (anchored, no collide/query/touch, transparent, `TRAIL.size` square, `TRAIL.lift` up, facing the paw's
      `facing`) each with a Top SurfaceGui (AlwaysOnTop, LightInfluence 0, PixelsPerStud) and the `Chevron` image
      (`TRAIL.rotation`); every frame `TrailRules.ahead` from the player's progress, the flow wave and the end fade.
- [ ] `TutorialTalk`: target = the button box, else `TutorialCues.worldPointerBox()`. Callers renamed. Compile check.

### Task 5: Chikin's words

**Files:** Modify `src/shared/Config/ChikinTalk.luau`; Test `tests/ChikinRules.spec.luau`.

- [ ] Test: the wild and wild2 lines say "Follow the arrows to the Wild!" and no player line says "paws". RED, edit,
      GREEN.

### Task 6: Docs and the Studio check

- [ ] DESIGN 7.6 and 7.7 (the cues), CLAUDE.md test list (CueShape, TrailRules), vault Tutorial guides + playbook,
      memory. `lune run tests/run` all green.
- [ ] Studio (3D rendering back): Pish's tour in a fresh test save or `/tutorial step`: the arrow on the Bag, on the
      order computer; Chikin's walk to the Wild: chevrons on the street, through the shop's door, the edge arrow when
      turned away, the card clear of the goal's arrow. Screenshots; fix the chevron's `rotation` if it points back.
