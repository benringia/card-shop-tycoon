# Wild Valley Scenery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dress the Wild valley's three areas in the owner's picks (Caves: Glow Mushroom Hollow, Meadow: Ancient Ruins,
Ridge: Ember Forest), give the Caves a darker blue look while you're in them, and stay within +1.5 ms of render CPU.

**Architecture:** Fifteen new prop models built by one Blender script (`build_valley_props.py`, the arena props' way),
imported by the owner as `assets/props/<Name>.rbxm`. Placement is plain data in `Config/WildValley` (new spot lists,
rings expanded by a pure `WildValley.scenery`), placed and dressed by SceneryService (anchored, glow parts made Neon in
each spot's colour, colliders for big pieces). The Caves' look is a `Config/DayCycle` entry the client blends in by zone.

**Tech Stack:** Luau (Rojo), Lune tests (`lune run tests/run`), Blender 5.2 in the background
(`"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python <script>`), Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-04-valley-scenery-design.md`

## Global Constraints

- Each new prop model under 2000 triangles; `DragonSkeleton` up to 4000 (landmark).
- Glow from Neon parts, not lights: at most one PointLight per area. Small pieces cast no shadow.
- Every piece anchored; all prop parts `CanQuery = false`, `CanTouch = false`; only invisible colliders collide.
- Every piece clear of the trail, stream, pond, arrival, portals, boards (`WildValley.clearOf`) and in its own biome;
  every biome keeps its 24 spawn spots; terrain stays within `MAX_CELLS`.
- No change to biome outlines, the trail, passes, edge walls, portals, boards, signs, arenas, monsters or spawn numbers.
  No lighting change outside the Caves.
- Per area: render CPU (`Stats.RenderCPUFrameTime`) within +1.5 ms of the Task 1 baseline and 60 fps.
- Style: smooth, chunky, flat colours, soft bevels (the arena props); mushrooms and ruins friendly; the skeleton big and
  cartoonish, not gory.
- Blender only in the background (never the owner's open Blender: `portal_kit.begin` wipes the scene). Before
  committing a `.blend`, print the lengths of any scene `*key*` / `*secret*` fields (must be 0 or absent).
- New UI text none. Tunable numbers in Config, none in services.

## Review Focus

1. Camera and clicks through scenery: a prop part left `CanQuery = true` snags the camera mid-fight. Task 2's Studio
   check lists every `Scenery.WildValley` part with `CanQuery` true (expected: only none).
2. Teleporting out of the Caves (to town, an arena, `/wild` again) with the blend half done: the look must not stick.
   Task 4 tests `DayCycle.areaMix` decaying to 0 and the controller resets the mix on the town and arena branches.
3. A model not imported yet: the area must build without it and without errors (warning only). Task 2's Studio check
   runs before the owner's import.
4. Monsters spawning inside a big piece: big pieces carry their own `clear` radius for spawn spots. Task 1 tests it.
5. Town clients pay for the valley: memory measured in town before and after (Task 8), growth under about 30 MB.

---

### Task 1: Scenery lists, rings and clearances (pure)

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (add `PROP_LISTS`, empty new lists, `STONE_CIRCLE`, `MUSHROOM_RINGS`)
- Modify: `src/shared/Util/WildValley.luau` (`scenery`, `ring`; `zoneSpots` uses `scenery` and each spot's `clear`)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Produces: config `PROP_LISTS = { "PROPS", "CRYSTALS", "CHARRED", "SHARDS", "VENTS", "MUSHROOMS", "TUFTS", "RUINS",
  "MOSS_ROCKS", "EMBER_TREES", "EMBER_CRYSTALS", "SKELETON" }`; each list holds spots `{ model: string?, x, z, height, yaw, glow: string?,
  clear: number? }`. `STONE_CIRCLE = { x, z, radius, count, model = "StandingStone", height, clear }`,
  `MUSHROOM_RINGS = { { x, z, radius, count, model = "Toadstool", height } }`.
- Produces: `WildValley.ring(centre: { x: number, z: number }, radius: number, count: number, template: any): { any }`
  (count spots evenly round the circle, each a copy of `template` with `x`, `z` and `yaw` facing the centre);
  `WildValley.scenery(valley: any): { any }` (every spot of every `PROP_LISTS` list, then the stone circle and the rings
  expanded by `ring`).

- [ ] **Step 0: Baseline (before any change).** Studio Play, `/wild` from the server
  (`ServerStorage.DevCommand:Invoke(player, "/wild")`), Scriptable camera at each of MEADOW `(10,30,1110)→(-80,0,1240)`,
  CAVES `(-235,45,1315)→(-370,15,1460)`, RIDGE `(-190,60,1600)→(-20,35,1710)`; average `Stats.RenderCPUFrameTime` and
  `RenderGPUFrameTime` × 1000 over 3 s at graphics Level01 and Level10, twice; `Stats:GetTotalMemoryUsageMb()` in town.
  Only trust runs that hold 60 fps (a flat 66.7 ms is Studio's window cap). Write the numbers in the ledger.
- [ ] **Step 1: Write the failing tests** in `tests/WildValley.spec.luau`:
  - `"a ring spreads its pieces evenly round its centre, each facing in"`: `WildValley.ring({x=0,z=0}, 10, 4, {model="Toadstool", height=1})`
    gives 4 spots, each 10 ± 1e-6 from the centre, neighbours 90° apart, `model` and `height` copied.
  - `"the valley's scenery is every list plus the circle and the rings"`: `#WildValley.scenery(valley)` equals the sum
    of `#valley[name]` over `PROP_LISTS` plus `STONE_CIRCLE.count` plus each ring's `count`.
  - Change `allProps()` to `WildValley.scenery(valley)` and the in-biome check to cover `MUSHROOMS`/`TUFTS` (2),
    `MOSS_ROCKS` (2), `RUINS` and the circle and rings (1), `EMBER_TREES`/`EMBER_CRYSTALS`/`SKELETON` (3).
  - `"big pieces keep spawn spots their own distance away"`: for every scenery spot with `clear`, no
    `zoneSpots` spot of its biome lies closer than `clear`.
- [ ] **Step 2: Run** `lune run tests/run` → the new tests FAIL (`ring`/`scenery` nil).
- [ ] **Step 3: Implement** `ring` and `scenery` in `Util/WildValley.luau`; `zoneSpots` reads `WildValley.scenery(valley)`
  and keeps `math.max(prop.clear or 0, valley.SPOT_PROP_CLEAR)` from each. Config: `PROP_LISTS` and the new lists
  (empty until Tasks 5-7), the real `STONE_CIRCLE` (west of the trail, about `x = -130, z = 1195`, radius 13, 9
  stones, height 9, `clear = 18`) and two `MUSHROOM_RINGS` (radius 3, 8 toadstools, height 1.4), at spots that pass
  `clearOf` (move them if a test says so).
- [ ] **Step 4: Run** `lune run tests/run` → all pass (968 + 3 new).
- [ ] **Step 5: Commit** `git commit -m "Valley scenery: scenery lists, rings, per-piece spawn clearance"`.

### Task 2: Placing and dressing valley pieces (server)

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`GLOW`, `EMBER_CRYSTAL_LOOK`, `COLLIDERS`)
- Modify: `src/server/Services/SceneryService.luau` (`buildWildValley`, new `dressValleyProp`, `buildCrystalCluster` takes a look)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Consumes: `WildValley.scenery(valley)` (Task 1).
- Produces: `GLOW = { teal = {r,g,b}, purple = {...}, blue = {...}, ember = {...} }`; a spot's `glow` names one.
  `COLLIDERS = { [model]: { radius: number, height: number } }` (shares of the spot's height, as
  `Scenery.CALDERA_COLLIDERS`) for the big pieces (`GlowMushroomTall`, `GlowMushroomCluster`, `MossRockA`, `MossRockB`,
  `RuinArch`, `RuinPillar`, `RuinWall`, `EmberTree`, `DragonSkeleton`). `EMBER_CRYSTAL_LOOK` shaped like `CRYSTAL_LOOK`.
- Produces (SceneryService, local): `dressValleyProp(model: Model, spot: any)`: every part anchored, `CanCollide`,
  `CanQuery`, `CanTouch` false; parts named `Glow` lose SurfaceAppearance/texture, become Neon in `GLOW[spot.glow]`
  (default `teal`), no shadow; a model under `Scenery.SMALL_DECOR_SIZE` studs tall casts no shadow; then a collider
  like `calderaCollider` from `COLLIDERS[spot.model]`. `buildCrystalCluster(folder, spot, look)`.

- [ ] **Step 1: Failing tests:** `"every glowing piece names a known glow colour"` (each scenery spot with `glow` has
  `valley.GLOW[spot.glow]`, three numbers 0-255); `"colliders are thin shares of a piece"` (each `COLLIDERS` entry:
  `0 < radius <= 0.5`, `0 < height <= 1`).
- [ ] **Step 2: Run** → FAIL (`GLOW` nil).
- [ ] **Step 3: Implement** the config and `dressValleyProp`. Today's lists keep their code (`PROPS` placed as is,
  `CHARRED`/`SHARDS` with `dressCalderaProp`, `CRYSTALS` and `VENTS` code-built). The new model lists (`MUSHROOMS`,
  `TUFTS`, `MOSS_ROCKS`, `RUINS`, `EMBER_TREES`, `SKELETON`), the stone circle and the rings are each placed with
  `placeModel` and dressed with `dressValleyProp` (freshly imported models arrive unanchored and colliding);
  `EMBER_CRYSTALS` are built with `buildCrystalCluster(holder, spot, WildValleyConfig.EMBER_CRYSTAL_LOOK)`.
- [ ] **Step 4: Run** `lune run tests/run` → PASS; `rojo build -o "$TEMP/claude_build.rbxl"` → builds.
- [ ] **Step 5: Studio check (models not imported yet):** Play, `/wild`; Output has only `[ScenePieces] no prop model`
  warnings for the new models and no errors; `Scenery.WildValley` parts with `CanQuery == true`: none.
- [ ] **Step 6: Commit** `"Valley scenery: place and dress valley pieces (glow colours, colliders)"`.

### Task 3: The fifteen prop models (Blender) and the owner's import

**Files:**
- Create: `tools/blender/build_valley_props.py` (on `voxel_kit.py` and `portal_kit.py`, `PROPS="A,B"`, `EXPORT=0` as
  `build_arena_props.py`; per-prop triangle cap asserted: 2000, `DragonSkeleton` 4000)
- Create: `assets/blender/<Name>/<Name>.{blend,fbx,png}` for each model
- Create: `tools/blender/render_valley_props.py` (a preview sheet PNG of all fifteen, for the owner)

**Interfaces:**
- Produces (Blender objects in each FBX; the game relies on the names): `Frame` (palette texture) and, for glowing
  ones, `Glow` (one object, palette white, made Neon by `dressValleyProp`). Origin at the bottom centre, front faces -Y
  in Blender (-Z in Roblox), Z up, proportions only (the game scales by height).
- Models: Caves `GlowMushroomTall` (single, cap Glow), `GlowMushroomCluster` (two or three, caps Glow),
  `GlowMushroomSmall` (flat cap, Glow), `GlowTuft` (leafy plant with glowing tips), `GlowFlowers` (a tuft of glowing
  bells), `MossRockA`, `MossRockB` (rounded rock, green moss top; no Glow). Meadow `RuinArch` (broken arch, one side
  taller, vines and flowers), `RuinPillar`, `RuinPillarBroken`, `RuinPillarFallen` (lying, cracked in two), `RuinWall`
  (a crumbled low wall segment), `Toadstool` (red cap, white spots). Ridge `EmberTree` (bigger charred tree, Glow =
  ember clusters in the crown), `DragonSkeleton` (half-buried skull, neck and spine, ribs arching out, a wing bone; Glow
  = faint ember in the eye sockets).

- [ ] **Step 1:** Write `build_valley_props.py`; run it in background Blender with `EXPORT=0` for all props → each
  prints `tris:` under its cap, no assertion error.
- [ ] **Step 2:** Run with export → fifteen folders under `assets/blender/`; run `render_valley_props.py` → a preview
  sheet; show it in the brainstorm companion with the concept pictures. Fix any piece the owner rejects, re-render.
- [ ] **Step 3:** Check every `.blend`: scene `*key*` / `*secret*` field lengths 0 or absent. Commit the script and
  `assets/blender/*` sources: `"Valley scenery: fifteen Blender props (build_valley_props.py)"`.
- [ ] **Step 4 (owner):** the owner imports each FBX in Studio (Import 3D, default settings) and saves it as
  `assets/props/<Name>.rbxm` unchanged; Claude checks each saved file has `Frame` (+ `Glow` where listed) and no
  scripts, then has the owner delete the Workspace copies. Tasks 4-7 continue meanwhile.

### Task 4: The Caves' darker look (client)

**Files:**
- Modify: `src/shared/Config/DayCycle.luau` (`AREA_LOOKS = { [2] = CavesLook }`, `AREA_BLEND = 2`)
- Modify: `src/shared/Util/DayCycle.luau` (`areaMix`)
- Modify: `src/client/Controllers/DayCycleController.luau`
- Test: `tests/DayCycle.spec.luau`

**Interfaces:**
- Produces: `DayCycle.areaMix(mix: number, inside: boolean, dt: number, seconds: number): number` (moves `mix` toward
  1 while inside, toward 0 outside, by `dt / seconds`, clamped 0-1).
- Starting Caves look (tuned by eye in Task 8): `clockTime = 14.5, brightness = 0.9, exposure = -0.35, ambient = {70,85,115},
  outdoorAmbient = {80,95,130}, atmosphere = { density = 0.45, offset = 0.05, haze = 1.8, glare = 0, color = {110,140,185},
  decay = {55,70,110} }, bloom = { intensity = 0.45, size = 28, threshold = 1.3 }, saturation = 0.1, contrast = 0.08,
  tint = {215,230,255}, sunRays = { intensity = 0, spread = 0 }`.

- [ ] **Step 1: Failing tests:** `"an area's look blends in over its seconds and back out"` (`areaMix(0, true, 1, 2)`
  = 0.5; `areaMix(0.5, true, 5, 2)` = 1; `areaMix(1, false, 1, 2)` = 0.5; `areaMix(0.2, false, 5, 2)` = 0);
  `"each area look has every field of the fixed look"` (keys of `AREA_LOOKS[2]` and nested tables match
  `DayCycle.fixedLook(Cycle)`'s).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `areaMix`; the controller keeps `mix` and the seconds since its last update; on the arena
  and town branches it sets `mix = 0`; otherwise `zone = WildValley.zoneAt(Valley, {x, z})`, `mix = areaMix(mix,
  Cycle.AREA_LOOKS[zone] ~= nil, step, Cycle.AREA_BLEND)` and applies `DayCycle.blend(fixed, AREA_LOOKS[2], mix)` when
  `mix > 0` (the last area with a look is remembered so it blends out on the pass).
- [ ] **Step 4: Run** `lune run tests/run` → PASS.
- [ ] **Step 5: Studio:** walk the trail from the Meadow into the Caves and back (server-side moves); screenshot
  mid-blend and inside; `/wild` from inside the Caves lands in the Meadow's normal look.
- [ ] **Step 6: Commit** `"Valley scenery: the Caves' darker blue look, blended by zone"`.

### Task 5: The Caves dressed

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`MUSHROOMS`, `TUFTS`, `MOSS_ROCKS` (today's ten gorge rocks move out of
  `PROPS`), the ledge in `TERRAIN`), `src/shared/Config/Scenery.luau` (`EMITTERS`: WildGorge `fireflies` rate 8, `groundmist` rate 3)
- Modify: `src/server/Services/SceneryService.luau` (`EFFECT_LOOKS.groundmist`: soft pale-blue puffs, Lifetime 6-9,
  Speed 0.2-0.6, Size 4-7, Transparency 0.85 → 1, LightEmission 0.2, low over the floor)

- [ ] **Step 1:** Place about 18 mushrooms (4 `GlowMushroomTall` 14-20 high as the landmark under the ledge by the
  cave mouth, clusters 6-10, smalls 2-4; `glow` teal or purple, alternating by cluster; `clear` = half the height for
  the tall ones), 30 tufts (`GlowTuft`, `GlowFlowers`, glow blue/teal/purple) in patches along the trail's edges; today's
  ten gorge rocks leave `PROPS` and become `MOSS_ROCKS` spots (`MossRockA`/`B`, same places and sizes); the ledge: a Limestone block jutting about 25 studs east from the west cliff
  over the cave mouth, its underside at least 6 studs above the mouth's top (y 31).
- [ ] **Step 2: Run** `lune run tests/run` → PASS (clearances, 24 spots, `MAX_CELLS`); `rojo build` OK.
- [ ] **Step 3: Studio** (with whatever models are imported): screenshot CAVES camera and from the middle; compare
  with `scenery-caves-c.png`.
- [ ] **Step 4: Commit** `"Valley scenery: the Caves' glow mushroom hollow"`.

### Task 6: The Meadow dressed

**Files:** `src/shared/Config/WildValley.luau` (`RUINS`, `PROPS` flowers and trees)

- [ ] **Step 1:** Place the ruins: 2 `RuinArch` (height 12-14, one by the trail as a frame for the view, `clear` 9),
  6 pillars (4 standing 7-10 high, 2 `RuinPillarFallen`), 5 `RuinWall` segments in two broken lines near the circle and
  the arches; 30 more flowers in drifts (groups of 4-6 of one colour); 8 more trees in clumps on the edges.
- [ ] **Step 2: Run** tests → PASS; `rojo build` OK.
- [ ] **Step 3: Studio:** screenshot MEADOW camera and from the circle; compare with `scenery-meadow-b.png`.
- [ ] **Step 4: Commit** `"Valley scenery: the Meadow's ancient ruins"`.

### Task 7: Ember Ridge dressed

**Files:** `src/shared/Config/WildValley.luau` (`EMBER_TREES`, `EMBER_CRYSTALS`, `SKELETON`, `CHARRED` trimmed),
`src/shared/Config/Scenery.luau` (WildRidge `ash` rate 6)

- [ ] **Step 1:** 12 `EmberTree` (height 14-20, `glow = "ember"`) in three groves; keep 4 of today's charred trees as
  small dead ones between groves; 10 ember crystal clusters (height 3-6); `DragonSkeleton` (height about 14, length
  about 40, `glow = "ember"`, `clear = 22`) in view from the second pass's top (`{-195, 1605}`), at least 25 studs off
  the trail.
- [ ] **Step 2: Run** tests → PASS; `rojo build` OK.
- [ ] **Step 3: Studio:** screenshot RIDGE camera and from the pass; compare with `scenery-ridge-b.png`.
- [ ] **Step 4: Commit** `"Valley scenery: Ember Ridge's ember forest"`.

### Task 8: Imported models, tuning, measurement, docs

**Files:**
- Test: `tests/CreatureAssets.spec.luau` (`"the valley's props are saved with their named parts"`: each of the fifteen
  `assets/props/<Name>.rbxm` exists, holds `Frame`, and `Glow` for the glowing ones; and every model any valley list
  names has a saved file)
- Modify: `DESIGN.md` (the Wild valley's scenery, 10.5 measurements, checklist line), `docs/props.md` (a "Valley
  scenery props" section), `CLAUDE.md` (`build_valley_props.py` in the assets list)

- [ ] **Step 1:** After the owner's import: write the test; `lune run tests/run` → PASS.
- [ ] **Step 2: Studio pass:** each area from its camera and from inside; tune positions, sizes, glow colours, the
  Caves look and effect rates by eye against the concepts; monsters still read clearly in the Caves.
- [ ] **Step 3: Measure** as Task 1 Step 0, same cameras and levels. Expected: each area within +1.5 ms render CPU of
  its baseline, 60 fps; town memory growth under about 30 MB. If over: cut tufts and small mushrooms first, then effect
  rates; re-measure; record what was cut.
- [ ] **Step 4:** Docs (DESIGN, props.md, CLAUDE.md); commit `"Valley scenery: tuned, measured, documented"`.
- [ ] **Step 5:** Final whole-branch review; then the owner's Studio check (stop → Play, `/wild`, walk all three areas).
