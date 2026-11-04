# Wild Valley Round 2 (Natural Edges and Backdrops) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the Wild valley out of its "box": natural skylines on every wall, giant trees, a foggy mushroom forest,
burnt hills and far mountain ranges behind, a composed Meadow, the Ridge's smoky sky, lava down the volcano, clouds.

**Architecture:** Terrain lumps generated from plain-data skyline lines (`WildValley.skylineOps`) give the walls an
undulating top; five new Blender models (three giant trees, two mountain ranges) plus round 1's models are placed
outside the walkable edge from `BACKDROP` / `MOUNTAINS` lists; the Ridge gets `DayCycle.AREA_LOOKS[3]` and the area
looks snap on a teleport; lava strips are raycast onto the volcano from `WildValley.lavaRays`.

**Tech Stack:** Luau (Rojo), Lune tests (`lune run tests/run`), Blender 5.2 in the background, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-05-valley-natural-design.md` (round 1: `2026-11-04-valley-scenery-design.md`)

## Global Constraints

- No change to the walkable area: biome outlines, the trail, passes, edge walls, portals, boards, signs, spawn rules;
  nothing new is reachable. Arenas untouched; no new monsters; no Meshy.
- Terrain: pay for new shapes by trimming hidden wall volume first; raise `MAX_CELLS` / `Scenery.MAX_CELLS` only
  after measuring terrain memory.
- `Workspace.StreamingEnabled` is on: far background models must not pop or vanish seen from inside the valley
  (mountains `ModelStreamingMode.Persistent`, backdrop pieces `Atomic`), checked in Play.
- Models under 2k triangles; landmarks (giant trees, mountain range pieces) up to 4k. Background pieces anchored,
  non-colliding, non-queryable, no touch; colliders only on pieces players can reach.
- Blender only in the background (never the open one); before committing a `.blend`, scene `*key*`/`*secret*`
  field lengths 0 or absent. The owner imports and saves `assets/props/<Name>.rbxm`.
- Budget: each area within +1.5 ms render CPU of round 2's pieces hidden (on/off in one session), 60 fps; town memory
  growth modest. Anti-goal: no sky flash on teleport, no fog that hides monsters.

## Review Focus

1. Streaming: a mountain or giant tree missing or popping in when seen from an area's far corner (Task 7 check).
2. Arriving by teleport (an arena's way home into the Caves or the Ridge, `/wild` out of them): the look must be
   right at once, no bright-then-dark fade (Task 3 test + check).
3. The Caves' fog: a monster 50 studs away must still read clearly (Task 3 check).
4. Lumps near an edge must not let a player climb out or onto a wall top (Task 1 check against the edge walls).
5. Clouds and always-loaded mountains costing the town (Task 8 measures the street with them on and off).

---

### Task 1: Natural skylines and the terrain budget

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`SKYLINES`; wall trims in `TERRAIN`; `MAX_CELLS` only if Step 6 says so)
- Modify: `src/shared/Util/WildValley.luau` (`skylineOps`; `terrainOps` appends it right after `TERRAIN`)
- Modify (only if Step 6 says so): `src/shared/Config/Scenery.luau` (`MAX_CELLS`)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Produces: config `SKYLINES = { { material: string, top: number, seed: number, points: { {x,z} }, spacing: number,
  radius: { number, number }, rise: { number, number }, drift: number } }`, one entry per wall run (each area's walls
  and the central mass's top on each side; lines kept off the passes).
- Produces: `WildValley.skylineOps(valley: any): { any }`: Ball ops along each line every `spacing` studs, radius in
  `radius`, top (`y + radius`) at `top` + a rise in `rise`, centre moved up to `drift` studs across the line; random
  from a seeded LCG in the module (`seed = (seed * 1103515245 + 12345) % 2^31`), so it is the same every run.

- [ ] **Step 0: Baseline.** Same as round 1 (Play, `/wild`, Scriptable cameras MEADOW `(10,30,1110)→(-80,0,1240)`,
  CAVES `(-235,45,1315)→(-370,15,1460)`, RIDGE `(-190,60,1600)→(-20,35,1710)`, Level01/Level10, two runs); plus
  terrain memory tags (graphics, voxels) in the valley and on the town street. Ledger the numbers.
- [ ] **Step 1: Failing tests:** `"a skyline's lumps are steady and rise above its wall"` (two `skylineOps` calls
  equal; every op a Ball with `radius` in range and `y + radius - top` in `rise`; every centre within `drift` + 0.01
  of its line); `"skyline lumps stand outside the walkable edge"` (no op centre `WildValley.inside(valley.EDGE, op)`).
- [ ] **Step 2: Run** `lune run tests/run` → FAIL (`skylineOps` nil).
- [ ] **Step 3: Implement** `skylineOps`, the `SKYLINES` lines (Meadow grass, Caves limestone, Ridge basalt, central
  mass top per side: rises 4-14 studs, radii 8-22) and the `terrainOps` hook.
- [ ] **Step 4: Run** → the new tests pass; "the valley's terrain fits its budget" likely fails.
- [ ] **Step 5: Trim** the walls' hidden volume (outer halves of the thickest wall blocks, never their inner faces or
  tops); rerun.
- [ ] **Step 6: Only if still over the cap:** measure terrain memory in Studio with and without the lumps; raise
  `MAX_CELLS` and `Scenery.MAX_CELLS` by the same amount (to the estimate rounded up to 5k) if terrain graphics grows
  10 MB or less, the numbers in the config comment; otherwise cut lumps. Rerun → all pass (24 spawn spots included).
- [ ] **Step 7: Studio:** screenshots from the three cameras; walk into the edge at three lumps per area: the
  invisible edge stops you, no wall top is reachable.
- [ ] **Step 8: Commit** `"Valley round 2: natural skylines on the walls"`.

### Task 2: Five backdrop models (Blender) and the owner's import

**Files:**
- Create: `tools/blender/build_valley_backdrop.py` (on `voxel_kit.py` / `portal_kit.py`, `PROPS=`, `EXPORT=0`, cap 4000
  each asserted before export, `if __name__ == "__main__": run()`)
- Modify: `tools/blender/render_valley_props.py` (`MODULE` env: the builder module to render, default
  `build_valley_props`)
- Create: `assets/blender/<Name>/` for `GiantTreeA`, `GiantTreeB`, `GiantTreeC`, `MountainSnow`, `MountainDark`

**Interfaces:**
- Produces: models with one `Frame` object each (palette texture), origin bottom centre, front -Y. `GiantTreeA` green,
  `GiantTreeB` autumn yellow-orange, `GiantTreeC` pink blossom: a thick flared trunk with roots, a few big branches,
  a wide layered canopy of rounded clumps (about as wide as tall). `MountainSnow`: a range piece of 3-5 rounded peaks
  with snow caps, about 3 wide to 1 tall. `MountainDark`: jagged dark basalt peaks, same proportions.

- [ ] **Step 1:** Write the script; `EXPORT=0` background run → every model prints `OK <name> <tris>` under 4000.
- [ ] **Step 2:** Export; render the preview (`MODULE=build_valley_backdrop`) and show it in the companion next to the
  picked concepts; fix what the owner rejects.
- [ ] **Step 3:** `.blend` key/secret check; commit script and sources `"Valley round 2: giant trees and mountain
  ranges (build_valley_backdrop.py)"`.
- [ ] **Step 4 (owner):** imports each FBX and saves `assets/props/<Name>.rbxm`; Claude checks `Frame` and no scripts.
  Tasks 3-7 continue meanwhile.

### Task 3: The Ridge's smoky sky, thicker Caves fog, no flash on teleport

**Files:**
- Modify: `src/shared/Config/DayCycle.luau` (`AREA_LOOKS[3]`; `AREA_LOOKS[2]` fog; `AREA_SNAP_SPEED = 150`)
- Modify: `src/shared/Util/DayCycle.luau` (`jumped`)
- Modify: `src/client/Controllers/DayCycleController.luau`
- Test: `tests/DayCycle.spec.luau`

**Interfaces:**
- Produces: `DayCycle.jumped(from: { x: number, z: number }?, to: { x: number, z: number }, dt: number, speed: number): boolean`
  (true when `from` is nil or the move is faster than `speed` studs a second).
- Starting Ridge look: `Cycle.ARENA_LOOKS[3]`'s values (tuned in Task 8). Caves: atmosphere `density` 0.6, `haze` 2.4.

- [ ] **Step 1: Failing tests:** `"a teleport is a jump, walking isn't"` (`jumped({x=0,z=0},{x=1.6,z=0},0.1,150)` false;
  `jumped({x=0,z=0},{x=300,z=0},0.1,150)` true; `jumped(nil,{x=0,z=0},0.1,150)` true); `"each area look has every
  field of the fixed look"` extended to `AREA_LOOKS[3]`; `"the Ridge's sky is smoky and warm, the Caves foggier"`
  (`AREA_LOOKS[3].tint[1] > AREA_LOOKS[3].tint[3]`; `AREA_LOOKS[2].atmosphere.density > fixed.atmosphere.density`).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement:** the controller keeps the last position and, when `jumped` (or the last update took the
  arena or town branch), sets `mix` straight to 1 inside an area with a look and 0 outside before blending; the looks.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Studio:** `/boss 3 fight`, leave by the way home → brightness equals the Ridge look on the first
  sample after arriving; same for `/boss 2` into the Caves; `/wild` from the Ridge → normal look at once; a Caves
  screenshot with a monster about 50 studs away.
- [ ] **Step 6: Commit** `"Valley round 2: the Ridge's smoky sky, Caves fog, looks snap on a teleport"`.

### Task 4: Lava streams down the volcano

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`VOLCANO_LAVA = { streams = { { angle, wobble, from, to } }, steps, width, reach }`)
- Modify: `src/shared/Util/WildValley.luau` (`lavaRays`)
- Modify: `src/server/Services/SceneryService.luau` (strips cast before `dressCalderaProp(volcano)`)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Produces: `WildValley.lavaRays(volcano: { x: number, z: number, y: number, height: number }, stream: { angle: number,
  wobble: number, from: number, to: number }, steps: number, reach: number): { { origin: { x: number, y: number, z: number },
  direction: { x: number, y: number, z: number } } }`: `steps + 1` horizontal rays aimed at the volcano's axis from
  `reach * height` out, at heights from share `from` down to `to` of its height; angle 0 faces -Z (the ridge), positive
  toward +X, swaying by `wobble` degrees down the stream.

- [ ] **Step 1: Failing test** `"lava rays run down the volcano's face toward its axis"`: 9 rays for 8 steps; heights
  strictly falling from `y + height * from` to `y + height * to`; every `direction.y == 0`; every ray's line passes
  within 0.01 of the axis.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `lavaRays`, the config (4-5 streams on the -Z face), the server
  strips (raycast `Include` the volcano model, `strip` between consecutive hits in `Scenery.LAVA` colour, skipped
  misses). **Step 4: Run** → PASS; `rojo build` OK.
- [ ] **Step 5: Studio:** screenshot of the volcano from the RIDGE camera; strips on its face, none floating.
- [ ] **Step 6: Commit** `"Valley round 2: lava streams down the volcano"`.

### Task 5: Backdrop placement, mountains, clouds (server)

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`BACKDROP = {}` per piece spots `{ model, x, z, height, yaw, glow? }`;
  `MOUNTAINS` spots `{ model, x, z, y, height, yaw }` round the whole valley)
- Modify: `src/shared/Config/Scenery.luau` (`CLOUDS = { cover, density, color }`)
- Modify: `src/server/Services/SceneryService.luau` (`buildBackdrop`, clouds in `Start`)
- Test: `tests/WildValley.spec.luau`, `tests/TownTerrain.spec.luau`

**Interfaces:**
- Consumes: `dressValleyProp(model, spot)` (round 1), given an optional third argument `solid: boolean?` (default
  true; false skips the colliders) so backdrop glow mushrooms and ember trees get their glow but no colliders.
- Produces: backdrop pieces placed on the drawn ground with `placeModel`, then every part `CanCollide`/`CanQuery`/
  `CanTouch` false (no colliders), `ModelStreamingMode.Atomic`; mountains at their explicit `y`, no shadows,
  `ModelStreamingMode.Persistent`; `Terrain.Clouds` made once with `CLOUDS`.

- [ ] **Step 1: Failing tests:** `"backdrops and mountains stand outside the walkable edge"` (every `BACKDROP` and
  `MOUNTAINS` spot: not `WildValley.inside(valley.EDGE, spot)`); `"mountains stand far out"` (each at least 150 studs
  from every biome outline point); `"the clouds are a soft cover"` (`CLOUDS.cover` and `density` in 0-1, colour three
  0-255 numbers).
- [ ] **Step 2: Run** → FAIL (`MOUNTAINS` / `CLOUDS` nil). **Step 3: Implement**, with 8-12 mountain pieces (snowy south,
  west and east of the Meadow and Caves, dark north and east of the Ridge, sunk so no base shows). **Step 4: Run** →
  PASS; `rojo build` OK.
- [ ] **Step 5: Studio:** Output only "no prop model" warnings for unimported models; clouds over the town and valley.
- [ ] **Step 6: Commit** `"Valley round 2: backdrop placement, far mountains, clouds"`.

### Task 6: The Meadow composed

**Files:**
- Modify: `src/shared/Config/WildValley.luau` (`HILLS` ruin hill under the circle; `RUINS` regrouped; `PATHS`;
  `STREAM.pond.radius` and the pond's `CARVES`; `GIANT_TREES` in `PROP_LISTS`; `COLLIDERS` for the giant trees)
- Modify: `src/shared/Util/WildValley.luau` (`terrainOps` draws `PATHS` with `segment` after the trail)
- Modify: `src/server/Services/SceneryService.luau` (`GIANT_TREES` placed and dressed like round 1's lists)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Produces: `PATHS = { { from = { x, z, y }, to = { x, z, y }, width } }`; `GIANT_TREES` spots (2-4 framing the trail,
  `clear` about half their canopy); `COLLIDERS.GiantTreeA/B/C = { radius = 0.08, height = 0.5 }`.

- [ ] **Step 1: Failing tests:** `"the ruins stand together on the ruin hill"` (every `RUINS` spot within 32 studs of
  `STONE_CIRCLE`; a `HILLS` entry within 5 studs of the circle's centre); `"a path climbs from the trail to the ruins"`
  (`PATHS[1].from` within `TRAIL_WIDTH` of the trail, `PATHS[1].to` within 20 of the circle's centre).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (pond radius about 13 with its carve, fill and floor widened to
  match). **Step 4: Run** → PASS (24 spawn spots, clearances, cells).
- [ ] **Step 5: Studio:** MEADOW camera and from the ruin hill, compared with `natural-meadow-b.png`.
- [ ] **Step 6: Commit** `"Valley round 2: the Meadow composed: one ruin hill, a bigger pond, giant trees"`.

### Task 7: Backdrops dressed per area

**Files:** `src/shared/Config/WildValley.luau` (`BACKDROP` entries; the cave's mossy skin in `TERRAIN`/`SKYLINES`)

- [ ] **Step 1:** Meadow: giant trees on the skyline lumps both sides, town trees scaled 30-40 as tree lines between
  them. Caves: round 1's glow mushrooms scaled 30-60 in layers on the walls and lumps (glow teal/purple), fading into
  the fog; the crystal cave's rock face made mossy (a `LeafyGrass` skin on the shelf's top and a few mossy lumps round
  the mouth, in `TERRAIN`/`SKYLINES`, the mouth and its carve unchanged). Ridge: ember trees scaled 22-30 and charred
  trees on the hills, rising toward the volcano.
- [ ] **Step 2: Run** tests → PASS; `rojo build` OK.
- [ ] **Step 3: Studio:** each camera, compared with `natural-meadow-b/caves-a/ridge-a.png`; from each area's far
  corner count the client's backdrop and mountain models present (streaming): none missing.
- [ ] **Step 4: Commit** `"Valley round 2: backdrops dressed"`.

### Task 8: Imported models, tuning, measurement, docs

**Files:** `tests/CreatureAssets.spec.luau` (the five models hold `Frame`; every model a valley list names is saved),
`DESIGN.md`, `docs/props.md`, `CLAUDE.md`

- [ ] **Step 1:** After the import: the test (watch it fail on a wrong expectation first, then pass).
- [ ] **Step 2: Studio pass:** tune against the concepts; the Ridge look and Caves fog by eye.
- [ ] **Step 3: Measure:** Task 1's cameras and levels, round 2's backdrop and mountain models and clouds on/off in one
  session; terrain memory; the town street with clouds and mountains on/off. Expected: +1.5 ms or less per area, 60
  fps; if over, cut backdrop counts first.
- [ ] **Step 4:** Docs; commit `"Valley round 2: tuned, measured, documented"`.
- [ ] **Step 5:** Final whole-branch review, then the owner's Studio check.
