# Wild Valley Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the main game's Wild from three flat coloured squares in a void into one connected valley (meadow, rocky
gorge with a crystal cave, volcanic ridge) with themed boss arenas, a trail and closed edges, without changing zones,
monsters, fights or travel.

**Architecture:** A plain-data `Config/WildValley` holds the valley (terrain ops, props, trail, effects, arena looks,
edges) in world coordinates; a pure `Util/WildValley` gives the monster spawn spots, the trail's marker points and the
clearance rules (Lune-tested). SceneryService (main game only) fills the valley's terrain with the town's and places its
dressing with its existing helpers; WildService keeps its zone floor parts as invisible collidable floors so monsters
snap exactly as today, swaps the return ring for the Forest Falls portal model, dresses the arenas by zone and builds
the edge walls.

**Tech Stack:** Luau (Rojo), Lune tests, Roblox Studio MCP checks.

**Spec:** `docs/superpowers/specs/2026-10-31-wild-valley-design.md`

## Global Constraints

- Main game only: `Place.isFrontier()` and the Dungeon keep today's map.
- Zones, spawn points, wander/chase/leash, bosses, arenas' rings and barriers, travel, healing: unchanged.
- Monsters snap by `WildService.groundAt` (map folder only, 6 up / 20 down): zone floors stay at y 0 as invisible
  collidable parts in the map folder; the valley's terrain draws its ground at y 0 under them.
- Terrain: the Wild's ops at most `WildValley.MAX_CELLS` (40,000) and town + Wild within `Scenery.MAX_CELLS` (180,000);
  raising the cap only with a memory measurement recorded in DESIGN 10.5.
- At most 4 area effects per Wild zone (`Scenery.EMITTERS` areas `WildMeadow`, `WildGorge`, `WildRidge`).
- Props clear of the trail (half width + 2), spawn spots (4 studs) and arena paths; nothing in the boss rings.
- Bold mid-tone colours; the ridge reuses the caldera's look and pieces.
- Numbers in config, pure logic Lune-tested, DESIGN.md / CLAUDE.md updated; screenshots for the user.

## Review Focus

1. A monster standing on scenery or floating: spawn spots and wander circles stay clear of props (Task 1 test "props
   stay clear of spawn spots and their wander").
2. Players walking off the map or into the void: the edge walls close round every walkable spot (Task 1 test "the edge
   closes round the zones, paths, arenas and arrival").
3. The Frontier changing: it must build today's map (Task 2 Studio check in the Frontier window or a code-path check).
4. The trail hidden or blocked: markers along the whole route, no prop on it (Task 1 tests).
5. Terrain memory over budget (Task 2 test "the valley's terrain fits the budget").

---

### Task 1: Valley data and rules

**Files:** Create `src/shared/Config/WildValley.luau`, `src/shared/Util/WildValley.luau`, `tests/WildValley.spec.luau`;
Modify `tests/run.luau`, `CLAUDE.md` (test list), `src/server/Services/WildService.luau` (spawn spots from the util).

**Interfaces:**
- Pure: `WildValley.zoneCenter(wild, index): { x, z }`; `WildValley.spawnSpots(wild, index): { { x, z } }` (today's
  ring: `MONSTERS_PER_ZONE` spots at radius 0.18 / 0.32 × `ZONE_SIZE`, odd/even, angle `spot / n × 2π`);
  `WildValley.trail(wild): { { x, z } }` (arrival → zone 1 → 2 → 3 along x 0); `WildValley.markers(trail, spacing)`;
  `WildValley.clearOf(point, valley, wild, bosses): boolean`; `WildValley.inside(edge, point): boolean`.
- Config: `MAX_CELLS = 40000`, `TERRAIN` (ops), `PROPS` per zone (`{ model, x, z, height, yaw }`), `CRYSTALS`,
  `CHARRED`, `SHARDS`, `VENTS`, `STREAM` (points, width), `BRIDGE`, `CAVE` (mouth spec), `MARKER_SPACING`, `TRAIL_WIDTH`,
  `EDGE` (polygon), `ARENA_LOOKS` (per zone: floor material/colour, post material/colour, accent), `RIDGE_CRACKS`
  (`LavaCracks` floor box + count).

- [ ] **Step 1: Write the failing tests:** `"spawn spots match today's ring"` (zone 1 spot 1 at radius 0.18 × 120,
  angle 2π/8); `"props stay clear of spawn spots and their wander"` (every prop at least `Wild.WANDER_RADIUS` + 2 from
  every spawn spot: outside the circle a monster wanders in); `"props stay off the trail and
  arena paths"`; `"the edge closes round the zones, paths, arenas and arrival"` (corners of each zone, each arena
  circle's far point, the entrance pad inside `EDGE`); `"markers run the whole trail"` (first within one spacing of the
  arrival, last within one of zone 3's centre, gaps ≤ spacing).
- [ ] **Step 2: Run** `lune run tests/run WildValley`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** both modules; WildService's spawn loop uses `WildValley.spawnSpots` (same positions).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "Wild valley: layout data and rules"`

### Task 2: Terrain, floors and edges

**Files:** Modify `src/server/Services/SceneryService.luau` (fill the valley's ops after the town's),
`src/server/Services/WildService.luau` (main game: floors, paths and arrival pad invisible but collidable, no ball-tree
`decorate`, edge walls), `tests/WildValley.spec.luau`.

- [ ] **Step 1: Write the failing test** `"the valley's terrain fits the budget"`: `TownTerrain.estimatedCells(valley
  ops) ≤ MAX_CELLS` and town + valley ≤ `Scenery.MAX_CELLS`; zone floors draw at y 0 (`TownTerrain.topAt` at each zone
  centre ≈ -2, the fill top under y 0).
- [ ] **Step 2: Implement:** meadow Grass floor and soft grass hills; the stream as Water ops; the gorge's Rock/Slate
  floor and cliff walls on its two sides; the ridge's Basalt/CrackedLava floor and jagged basalt rims; a ring of hills
  closing the view; invisible edge walls (14 tall) along `EDGE`.
- [ ] **Step 3: Studio check:** Play, `/wild`; screenshots of each zone; a monster in each zone stands on the floor
  (marker y ≈ 0); Output clean. The Frontier path (`Place.isFrontier`) untouched in code.
- [ ] **Step 4: Commit** `git commit -m "Wild valley: terrain, invisible floors and closed edges"`

### Task 3: Arrival and meadow

**Files:** Modify `src/server/Services/WildService.luau` (return portal), `src/server/Services/SceneryService.luau`,
`src/shared/Config/Scenery.luau` (Wild effects).

- [ ] **Step 1:** The return portal stands the `PortalWild` model (`Props.place` + `PortalBuild.dress` with
  `Town.PORTAL_LOOKS.Wild`) at today's spot facing down the valley; its ring hidden, prompt kept. Meadow props (town
  trees, bushes, flowers, mushrooms, rocks), the bridge over the stream where the trail crosses, trail markers (small
  glowing stones), up to 4 meadow effects (fireflies, pollen). `lune run tests/run` passes.
- [ ] **Step 2: Studio check:** arriving, the portal prompt works (Return); screenshots for the user.
- [ ] **Step 3: Commit** `git commit -m "Wild valley: the arrival portal and the meadow"`

### Task 4: Gorge and ridge

**Files:** Modify `src/server/Services/SceneryService.luau`, `src/shared/Config/WildValley.luau`,
`src/shared/Config/Scenery.luau`.

- [ ] **Step 1:** Gorge: rocks, blue crystal clusters (the Frostpeak crystal builder, blue), the cave mouth on the -X
  side (a Slate terrain mound, a dark recessed mouth part, glowing crystals at its lip); up to 4 effects (crystal
  glints). Ridge: floor cracks (`LavaCracks.floor` with the Wild trail), charred trees and obsidian shards (caldera
  props), smoking vents (a dark cone of parts with a glowing core and smoke); up to 4 effects (embers, vent smoke).
  Tests pass (props clear).
- [ ] **Step 2: Studio check:** screenshots of both zones; monsters still stand clear of props.
- [ ] **Step 3: Commit** `git commit -m "Wild valley: the crystal gorge and the ember ridge"`

### Task 5: Boss arenas by zone

**Files:** Modify `src/server/Services/WildService.luau` (`BuildBossArenas`: main game Wild only),
`src/shared/Config/WildValley.luau` (`ARENA_LOOKS`).

- [ ] **Step 1:** Each Wild arena's floor, path and posts take its zone's look: meadow grass floor and wooden fence,
  gorge slate floor and stone posts with crystal tips, ridge basalt floor with lava cracks and basalt posts. Rings,
  barriers, gates, prompts unchanged. Tests pass.
- [ ] **Step 2: Studio check:** `/boss 1..3`: screenshots; a boss fight starts and the barrier rises as before.
- [ ] **Step 3: Commit** `git commit -m "Wild valley: boss arenas dressed by zone"`

### Task 6: Performance and docs

- [ ] **Step 1: Measure** in the Wild (meadow, gorge, ridge cameras, Level01/Level10, the valley's pieces off/on/off/on);
  terrain memory before/after. Expected: 60 fps, within budget.
- [ ] **Step 2: Docs:** DESIGN (the Wild's map, 10.5, file tree, backlog), CLAUDE.md, Obsidian.
- [ ] **Step 3:** `lune run tests/run`, `rojo build` pass. **Commit** `git commit -m "Wild valley: performance, docs"`
