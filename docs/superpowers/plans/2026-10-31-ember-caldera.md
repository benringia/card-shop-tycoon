# Ember Canyon Caldera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Ember Canyon from a red desert canyon into a calm volcanic caldera in the portal's black-purple and
orange: dark basalt cliffs and cracked ground laced with glowing cracks, charred trees and obsidian shards, hotter lava,
and a quiet smoking volcano behind the portal.

**Architecture:** Terrain changes are config only (`Config/Scenery` terrain ops and material colours). The glowing
cracks come from a pure, tested generator (`Util/LavaCracks`) that lays out branching segments on wall and floor
regions; SceneryService turns them into glowing strips snapped onto the terrain by raycast. The volcano, a charred tree
and an obsidian shard cluster are Blender props placed by the existing `ScenePieces.placeModel`; the volcano's smoke is
the canyon's fourth area effect.

**Tech Stack:** Luau (Rojo), Lune tests, Blender 5.2 through the Blender MCP (`voxel_kit`, `portal_kit`), Roblox Studio
MCP for checks.

**Spec:** `docs/superpowers/specs/2026-10-31-ember-caldera-design.md`

## Global Constraints

- Concept A: calm and moody; glow from cracks in cliffs and ground; a quiet volcano (glowing crater, a couple of streaks,
  a slow smoke plume), no eruption, no lavafalls.
- Nothing left reading as desert: no sand colour, sandstone stripes or green cacti.
- Dark basalt reads dark charcoal under the town's sun; obsidian black-purple, not bright purple.
- Terrain within `Scenery.MAX_CELLS`; the volcano is a mesh. At most 4 area effects in Ember Canyon (embers, bubbles,
  flow, smoke).
- Blender props: scripts in `tools/blender/`, sources in `assets/blender/<Name>/`, the user imports and saves
  `assets/props/<Name>.rbxm`; under 2,000 triangles per small prop, the volcano up to 4,000; .blend secret fields 0, no
  `*_Src`; no Meshy credits.
- Props clear of the trails and the portal (`Town.PORTAL_SCENERY_CLEAR`).
- Unchanged: the portal, the trail route, `Town.WALK_EDGE`, arena travel, the town's lighting and day cycle.
- Repo rules: numbers in `Config/Scenery`, pure modules Lune-tested, DESIGN.md / docs updated with the change.
- Renders before export, in-game screenshots after.

## Review Focus

1. A crack strip floating in the air or buried: each strip must sit on the drawn terrain (the raycast snap misses →
   that strip is skipped, never placed at a guessed height) (Task 3 Studio check).
2. Cracks across the trail or under the portal: none within the trail's half width + 2 or `PORTAL_SCENERY_CLEAR` of the
   portal (Task 2 test "floor cracks stay off the trail and away from the portal").
3. The volcano missing until imported, or a model without its parts: the canyon still builds (placeModel warns), the
   glow and smoke skip (Task 6 Studio check before and after the import).
4. The volcano hidden behind the end wall from the trail, or crowding the portal: it must show over the end wall from
   the trail end and from the street (Task 6 screenshots).
5. Other areas changing colour: only materials no other area uses change colour (Task 1 test "only canyon materials
   change colour").

---

### Task 1: Caldera terrain

**Files:** Modify `src/shared/Config/Scenery.luau` (terrain ops for the canyon floor, walls, end wall, rims;
`MATERIAL_COLORS`), `src/shared/Config/Town.luau` (`PORTAL_AREAS` Arena `surface`), `tests/TownTerrain.spec.luau`.

**Interfaces:** Produces the canyon's materials: walls, end wall and rims `Basalt`, floor `CrackedLava`, the Arena
trail `Basalt`; colours `Basalt = { 46, 42, 50 }`, `CrackedLava = { 40, 30, 32 }`; `Sandstone`, `Limestone` and `Sand`
gone from ops and colours.

- [ ] **Step 1: Write the failing tests** in `tests/TownTerrain.spec.luau`:
  - `"the canyon is a caldera"`: `materialAt(OPS, -185, 32)` (north wall) and `materialAt(OPS, -185, -36)` (south wall)
    and `materialAt(OPS, -246, 0)` (end wall) are `"Basalt"`; `materialAt(OPS, -170, 0)` (floor) is `"CrackedLava"`;
    no op in `scenery.TERRAIN` uses `"Sand"`, `"Sandstone"` or `"Limestone"`.
  - `"only canyon materials change colour"`: every key of `scenery.MATERIAL_COLORS` other than `Basalt` and
    `CrackedLava` keeps its current value (Rock, Slate, Snow, Glacier, Ground as listed today), and no op outside the
    canyon box (x < -130) uses `Basalt` or `CrackedLava`.
  - Use the existing helper names in the spec file (`OPS`, `TownTerrain.materialAt`); match the real ops table name.
- [ ] **Step 2: Run** `lune run tests/run TownTerrain`. Expected: FAIL (walls are Sandstone).
- [ ] **Step 3: Implement:** swap the canyon's floor op to `CrackedLava`; the wall, layer and end-wall blocks to
  `Basalt` (the two layer blocks per side can merge into one stepped Basalt mass, keep the same footprint so the
  walkable floor is unchanged); replace the rounded `Sandstone` rim balls with 10-14 `Basalt` blocks turned by `yaw`
  (jagged rims, same height range); the Arena trail `surface = "Basalt"`; the colours above.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass (cells cap included).
- [ ] **Step 5: Studio check:** Play; screenshot the canyon from the trail start and from above. The walls read dark
  charcoal, the floor dark, no sand left. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Caldera: basalt walls, dark cracked floor, jagged rims"`

### Task 2: The crack generator

**Files:** Create `src/shared/Util/LavaCracks.luau`, `tests/LavaCracks.spec.luau`; Modify `tests/run.luau`, `CLAUDE.md`
(test list), `src/shared/Config/Scenery.luau` (`CRACKS`).

**Interfaces:**
- Config: `Scenery.CRACKS = { SEED, WIDTH = { 0.35, 0.7 }, COLOR = { 255, 110, 30 }, MAX_SEGMENTS = 160, WALLS = { {
  name, from = { x, z }, to = { x, z }, low, high, count } ... }, FLOOR = { centre = { x, z }, size = { x, z }, count } }`
  (walls: the canyon's inner faces as lines in plan view, the cracks between heights low..high; floor: the canyon floor
  box).
- `LavaCracks.wall(wall: Wall, rng: Random): { Segment }` — `Segment = { a: { along: number, y: number }, b: {...},
  width: number }`, `along` 0..1 along the wall line: a crack starts at a random point near the top, walks downward with
  sideways jitter in 4-7 steps, and branches once with a chance of 0.5.
- `LavaCracks.floor(floor: Floor, trail: { { x: number, z: number } }, portal: { x: number, z: number }, clearTrail:
  number, clearPortal: number, rng: Random): { FloorSegment }` — `FloorSegment = { a: { x, z }, b: { x, z }, width }`:
  meandering branching cracks inside the box, every point at least `clearTrail` from the trail polyline and
  `clearPortal` from the portal.
- `LavaCracks.all(cracks: any, town: any, rng: Random): (walls: { [string]: { Segment } }, floor: { FloorSegment })`
  with the total capped at `MAX_SEGMENTS`. `rng` is a Lune-friendly random: a function returning 0..1 (seeded
  `Random.new(SEED):NextNumber` in game, a seeded LCG in the test).

- [ ] **Step 1: Write the failing tests:** `"wall cracks stay on their wall"` (every point's `along` in 0..1 and `y` in
  low..high, widths within WIDTH); `"floor cracks stay off the trail and away from the portal"` (every point inside the
  box, ≥ trail half width + 2 from the Arena trail polyline, ≥ `Town.PORTAL_SCENERY_CLEAR` from the portal);
  `"cracks are capped and repeatable"` (total ≤ MAX_SEGMENTS; two runs with the same seed give equal tables);
  `"every wall gets cracks"` (each WALLS entry produces at least its count of segments).
- [ ] **Step 2: Run** `lune run tests/run LavaCracks`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** the config (walls: north face z ≈ 30 from x -136 to -232, south face z ≈ -32, end face
  x ≈ -234 from z -22 to 22; low 1, high 22; counts 6/6/4; floor box centre (-182, 0) size (96, 44), count 10) and the
  module (pure, no requires).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "Caldera: a tested lava crack generator"`

### Task 3: Cracks, hotter lava, dark torches, no cacti in game

**Files:** Modify `src/server/Services/SceneryService.luau`, `src/shared/Config/Scenery.luau` (remove `CACTI`,
`CACTUS`; `LAVA.COLOR/HOT` hotter; `TORCH_STONE` dark), `tests/TownTerrain.spec.luau` (props list without CACTI).

**Interfaces:** Consumes `LavaCracks.all` (Task 2). Produces folder `Scenery.LavaCracks` of Neon parts named `Crack`.

- [ ] **Step 1:** Implement `buildCracks(folder)`: wall segments → world points along the wall line at height y, each
  point snapped onto the terrain by a horizontal raycast from the canyon's middle toward the wall (terrain only); floor
  segments → raycast down onto the terrain; a strip = a Neon part (WIDTH × 0.2 × length) between the two snapped
  points, pushed 0.1 out along the hit normal, no collide/query/touch/shadow; a segment whose ray misses is skipped.
  Remove `buildCactus` and its config; `LAVA.COLOR` `{ 255, 120, 30 }`, `HOT` `{ 255, 210, 90 }`; `TORCH_STONE`
  `{ 52, 46, 56 }`. Update the props-clear test's lists (no CACTI). `lune run tests/run` passes; compile check.
- [ ] **Step 2: Studio check:** Play; count the strips (≤ 160), none floating (sample 10: each strip's centre within 0.5
  of a terrain ray hit); screenshots from the trail. Show the user.
- [ ] **Step 3: Commit** `git commit -m "Caldera: glowing cracks, hotter lava, dark torches, cacti gone"`

### Task 4: Blender props: charred tree and obsidian shards

**Files:** Create `tools/blender/build_charred_tree.py`, `tools/blender/build_obsidian_shards.py`.

**Interfaces:** Consumes `portal_kit` (`tube`, `crystal`, `begin`, `export`). Produces models named `CharredTree`
(one part `Frame`; a trunk and 3-5 crooked branches in charcoal and black, a few ember-orange tips) and `ObsidianShards`
(parts `Frame` and `Lava`: 5-7 black-purple crystals with thin lava ribbons, the obsidian palette of
`build_portal_arena.py`). Z up, origin at the bottom centre, about 10 and 4 studs tall.

- [ ] **Step 1:** Write both scripts; run with `EXPORT=0` (in an empty Blender file). Expected: triangles under 2,000
  each.
- [ ] **Step 2:** Render both (front three-quarter); keep for the joint review in Task 5.
- [ ] **Step 3: Commit** `git commit -m "Caldera: charred tree and obsidian shard props in Blender"`

### Task 5: Blender volcano and the review

**Files:** Create `tools/blender/build_volcano.py`.

**Interfaces:** Produces model `Volcano`: parts `Body` (a chunky low-poly cone, jagged faceted flanks, a crater rim; dark
basalt palette), `Lava` (the crater's lava surface and 2 streaks down one flank) and marker `Fx_Smoke` (a 0.2 cube at
the crater's middle). Z up, origin at the bottom centre, about 120 studs tall, base about 180 across; up to 4,000
triangles.

- [ ] **Step 1:** Write and run with `EXPORT=0`. Expected: those parts, triangles ≤ 4,000.
- [ ] **Step 2:** Show the user the three renders (volcano, tree, shards) beside concept A. Rework until approved.
- [ ] **Step 3: Commit** `git commit -m "Caldera: the volcano in Blender"`

### Task 6: Placing them in the canyon

**Files:** Modify `src/shared/Config/Scenery.luau` (`CHARRED_TREES`, `SHARDS`, `VOLCANO`, `EMITTERS` smoke),
`src/server/Services/SceneryService.luau`, `tests/TownTerrain.spec.luau`, `tests/CreatureAssets.spec.luau`;
`assets/blender/{CharredTree,ObsidianShards,Volcano}/` and `assets/props/{CharredTree,ObsidianShards,Volcano}.rbxm`
(user).

**Interfaces:** Consumes the three models (Tasks 4-5). Config: `CHARRED_TREES` (8-10 spots, height 9-12: the cacti's
old spots plus a few along the walls), `SHARDS` (5-7 spots, height 3-5), `VOLCANO = { model = "Volcano", x = -330,
z = 10, height = 120, yaw = 0 }`, `EMITTERS` gains `{ area = "EmberCanyon", kind = "smoke", ... }` placed on the
volcano's `Fx_Smoke` when it exists.

- [ ] **Step 1: Write the failing tests:** in `"props stand clear of every trail and portal"` add `CHARRED_TREES` and
  `SHARDS` to the lists; `"the volcano stands behind the canyon"`: `VOLCANO.x < -280` and its distance from the portal
  > 60; the effects-cap test now counts 4 in EmberCanyon; in CreatureAssets: `"the volcano carries its parts"` (if
  `assets/props/Volcano.rbxm` exists: MeshParts `Body`, `Lava`, `Fx_Smoke`). Run: FAIL (lists/keys missing).
- [ ] **Step 2: Implement** the config and SceneryService: place trees and shards with `placeModel`; the volcano with
  `placeModel` (its own `y` = the ground there, -4), its `Lava` (and the shards' `Lava`) glowing Neon `LAVA.COLOR`
  (texture removed), `Fx_Smoke` hidden, the smoke `EFFECT_LOOKS.smoke` (smoke texture, grey to dark, rate 2, size
  20 → 45, lifetime 10-14, rise 2, transparency 0.5 → 1) on `Fx_Smoke`, else at the config point. Lune passes.
- [ ] **Step 3:** Export the three with `EXPORT=1` (secret fields 0, no `_Src`); commit the sources; ask the user to
  import the three FBX and save `assets/props/<Name>.rbxm`, then delete the Workspace copies. Check part names first.
- [ ] **Step 4: Studio check:** Play; the volcano shows over the end wall from the trail end and from the street
  (screenshots); trees and shards stand on the ground; smoke rises from the crater; Output clean. Before the import:
  the canyon builds without them (warns only). Show the user.
- [ ] **Step 5: Commit** `git commit -m "Caldera: charred trees, obsidian shards and the volcano in the canyon"`

### Task 7: Performance and docs

**Files:** Modify `DESIGN.md` (the Ember Canyon description, 10.5, file tree), `docs/props.md`, `CLAUDE.md` (assets
line), the Obsidian vault.

- [ ] **Step 1: Measure** as on 2026-10-31 (stress: Plot1's shelves in plots 2-6, 5 avatar clones; render CPU at the
  street and the canyon trail end, Level01/Level10; the caldera's new pieces off/on/off/on at the same camera).
  Expected: 60 fps; street within noise; the canyon under +0.5 ms.
- [ ] **Step 2: Docs** and Obsidian (Town design note, Decisions log, Lessons learned).
- [ ] **Step 3:** `lune run tests/run`, `rojo build -o "$TEMP/test.rbxl"` pass.
- [ ] **Step 4: Commit** `git commit -m "Caldera: performance measured, docs"`
