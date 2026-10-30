# Town Nature Pass: Portal Worlds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the three portals out of the street into walk-to areas (Forest Falls, Frostpeak, Ember Canyon) with trails, signposts and arches, dress the town and areas with terrain, a waterfall, giant trees, sway, butterflies and 3 animals, add a town-only morning-to-sunset day cycle and a first-visit welcome cinematic, inside the measured performance budget.

**Architecture:** All placements, trail shapes, terrain shapes, lighting looks and the cinematic timeline live in plain-data configs read by pure, Lune-tested modules (`PortalTrails`, `TownTerrain`, `DayCycle`, `WelcomePath`, `FrameWatchdog`, `Wander`). The server builds the world from them at start (TownService for layout, a new SceneryService for terrain and dressing); everything that moves or changes over time (lighting, sway, animals, butterflies, the cinematic) runs on each client.

**Tech Stack:** Roblox, Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-30-town-portal-worlds-design.md`

## Global Constraints

- Server authoritative; every remote defined in `src/shared/Remotes.luau`, validated and rate-limited with `src/server/Util/RateLimiter.luau`.
- All tunable numbers in `src/shared/Config`; configs that tests read are plain data (no Vector3 / Color3; colours as `{ r, g, b }`, points as `{ x, z }` or `{ x, y, z }`). Pure modules don't require siblings.
- Text: plain ASCII plus `·` and emoji only; fonts via `Util/FontStyle`. Arrows are board shapes, not glyphs.
- Main place only: the Frontier and Dungeon places keep their own scenery and lighting (`Place.isFrontier()` / `Place.isDungeon()`).
- Saved-data shape change: bump `SCHEMA_VERSION` (12 → 13), add `MIGRATIONS[12]` with a Lune test, update the template, types and DESIGN 10.4; `save` does nothing if the service never loaded for the player.
- Terrain inside the island (x -130..130, z -110..110) never rises above y = 0 (the street, plaza, crosswalks and markings are thin parts at y 0..0.3).
- Walks: east portals 125-140 studs of trail from the street's east end (8-9 s at 16 studs/s), the Arena portal 85-100 studs (about 6 s).
- Performance budget: on the full-server stress test plus all new scenery, PC render CPU within +1.5 ms of 10.2-12.3 ms and 60 fps at graphics levels 1 and 10; client memory grows by no more than about 50 MB.
- Studio MCP: read freely; ask before changing the place, except moving (never deleting) the hand-placed street-end decor in the trails' way, which the user approved (screenshots before and after; the user saves `TownDecor.rbxm`).
- Show the user screenshots for every visual result (standing preference: mockups for visual decisions).
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit on branch `town-portal-worlds`; merge and push only after the user approves in Studio.

## Review Focus

1. Existing players must not get the welcome cinematic after the update: `profile:Reconcile()` can add `seenWelcome = false` before the migration runs, so `MIGRATIONS[12]` sets it to `true` unconditionally (test in Task 10).
2. The day cycle wraps past midnight (night ClockTime 21.5 → dawn 5.6): the sun must move forward through 24, never spin backwards (test in Task 7).
3. Leaving the town (teleport to the Wild or the Arena) switches to the fixed afternoon look at once, and coming back returns to the cycle; the region test must put the Wild (z +1200) and the Arena (z -1200) outside and every portal area inside (test in Task 7).
4. The walkable edge must be a closed, simple outline that keeps every plot, the plaza, every trail point and every portal inside, with walls overlapping at the corners so there are no gaps to slip through (tests in Task 1, wall build in Task 4).
5. Players skipping the trail by firing travel remotes from anywhere: the Wild travel remote's unused `"wild"` branch is removed and Frontier `explore` / `friend` require the player within `Town.PORTAL_REACH` of the Frontier portal (pure reach test in Task 1, server use in Task 4).

---

### Task 1: Portal areas, trails and the walkable edge (pure)

**Files:**
- Create: `src/shared/Util/PortalTrails.luau`
- Create: `tests/PortalTrails.spec.luau`
- Modify: `src/shared/Config/Town.luau` (new `PORTAL_AREAS`, `WALK_EDGE`, `TRAIL`, `SIGNPOSTS`, `PORTAL_REACH`, `SIGN_DISTANCE`)
- Modify: `src/shared/Config/Wild.luau:7` (`PLAZA_PORTAL = { x = 185, y = 0, z = -118 }`), `src/shared/Config/Places.luau:8` (`FRONTIER_PORTAL = { x = 182, y = 0, z = 128 }`), `src/shared/Config/Pvp.luau:18` (`ARENA_PORTAL = { x = -205, y = 0, z = 0 }`)
- Modify: `tests/run.luau` (register `PortalTrails`)

**Interfaces:**
- Produces (`PortalTrails`, pure):
  - `export type Point = { x: number, z: number }`
  - `PortalTrails.length(trail: { Point }): number` (sum of segment lengths)
  - `PortalTrails.facing(trail: { Point }): Point` (unit vector from the last point toward the one before it: the way the portal faces, toward arriving players)
  - `PortalTrails.exitPoint(trail: { Point }, halfX: number): Point` (where the trail crosses x = ±halfX, interpolated)
  - `PortalTrails.inside(outline: { Point }, p: Point): boolean` (even-odd point-in-polygon)
  - `PortalTrails.isSimple(outline: { Point }): boolean` (no two non-adjacent segments cross)
  - `PortalTrails.walls(outline: { Point }, thickness: number): { { centre: Point, length: number, yaw: number } }` (one wall per segment; `length = segment length + thickness` so corners overlap; yaw in degrees, 0 = along -Z like TownLayout)
  - `PortalTrails.near(p: Point, portal: Point, reach: number): boolean`
  - `PortalTrails.armYaw(from: Point, to: Point): number` (degrees, same convention as TownLayout's `faceYaw`)
- Produces (config, `Town`):
  - `PORTAL_AREAS = { { key = "Wild", name = "Forest Falls", effect = "Wild", sign = "THE WILD", surface = "Ground", trail = { {x=110,z=-20}, {x=130,z=-26}, {x=148,z=-55}, {x=165,z=-95}, {x=185,z=-118} } }, { key = "Frontier", name = "Frostpeak", effect = "Frontier", sign = "FRONTIER", surface = "Snow", trail = { {x=110,z=20}, {x=130,z=26}, {x=148,z=58}, {x=166,z=100}, {x=182,z=128} } }, { key = "Arena", name = "Ember Canyon", effect = "Arena", sign = "PVP ARENA", surface = "Sand", trail = { {x=-110,z=0}, {x=-130,z=0}, {x=-205,z=0} } } }` (order matches `TownService.getWorld().portals`: Wild, Frontier, Arena; each trail's last point is its portal spot)
  - `WALK_EDGE` (starting outline, the builder may refine within the tests): `{ {x=-130,z=-110}, {x=130,z=-110}, {x=130,z=-45}, {x=140,z=-60}, {x=150,z=-90}, {x=150,z=-165}, {x=230,z=-165}, {x=230,z=-85}, {x=178,z=-80}, {x=158,z=-45}, {x=140,z=-15}, {x=140,z=15}, {x=160,z=48}, {x=180,z=85}, {x=235,z=90}, {x=235,z=170}, {x=150,z=170}, {x=150,z=98}, {x=140,z=62}, {x=130,z=45}, {x=130,z=110}, {x=-130,z=110}, {x=-130,z=30}, {x=-225,z=30}, {x=-225,z=-30}, {x=-130,z=-30} }`
  - `TRAIL = { WIDTH = 12, HEDGE_GAP = 8, WALK_SPEED = 16, EAST_LENGTH = { 125, 140 }, ARENA_LENGTH = { 85, 100 } }`
  - `SIGNPOSTS = { { x = 30, z = 0, arms = { "Wild", "Frontier", "Arena" } }, { x = 112, z = 0, arms = { "Wild", "Frontier" } }, { x = -112, z = 12, arms = { "Arena" } } }`
  - `PORTAL_REACH = 16`, `SIGN_DISTANCE = 120`
  - `BOUNDS.WALL_HEIGHT` stays; `BOUNDS.HALF_X/HALF_Z` stay as the island (hedge, baseplate).

- [ ] **Step 1: Write the failing tests** in `tests/PortalTrails.spec.luau` (load `Town`, `Wild`, `Places`, `Pvp` and `TownLayout` like `tests/TownLayout.spec.luau`):

```luau
["each trail ends at its portal"] = function()
	local spots = { wild.PLAZA_PORTAL, places.FRONTIER_PORTAL, pvp.ARENA_PORTAL }
	for index, area in town.PORTAL_AREAS do
		local last = area.trail[#area.trail]
		expect.equal(last.x, spots[index].x, `{area.key} x`); expect.equal(last.z, spots[index].z, `{area.key} z`)
	end
end,
["the walks are as long as the user chose"] = function()
	for _, area in town.PORTAL_AREAS do
		local range = if area.key == "Arena" then town.TRAIL.ARENA_LENGTH else town.TRAIL.EAST_LENGTH
		local length = PortalTrails.length(area.trail)
		assert(length >= range[1] and length <= range[2], `{area.key} trail is {length} studs`)
	end
end,
["the walkable edge is closed, simple and holds the town, every trail and every portal"] = function()
	expect.equal(PortalTrails.isSimple(town.WALK_EDGE), true, "no crossing edges")
	local points = {}
	for _, rect in TownLayout.plotRects(WORLD) do -- WORLD copied from tests/TownLayout.spec.luau
		for _, p in { { x = rect.minX, z = rect.minZ }, { x = rect.maxX, z = rect.minZ }, { x = rect.minX, z = rect.maxZ }, { x = rect.maxX, z = rect.maxZ } } do table.insert(points, p) end
	end
	for step = 0, 15 do
		local a = step / 16 * 2 * math.pi
		table.insert(points, { x = town.LAYOUT.PLAZA_RADIUS * math.cos(a), z = town.LAYOUT.PLAZA_RADIUS * math.sin(a) })
	end
	for _, area in town.PORTAL_AREAS do for _, p in area.trail do table.insert(points, p) end end
	for _, p in points do expect.equal(PortalTrails.inside(town.WALK_EDGE, p), true, `{p.x}, {p.z} is walkable`) end
end,
["walls overlap at the corners"] = function()
	for index, wall in PortalTrails.walls(town.WALK_EDGE, 1) do
		local a, b = town.WALK_EDGE[index], town.WALK_EDGE[index % #town.WALK_EDGE + 1]
		expect.near(wall.length, math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2) + 1, 1e-9, `wall {index}`)
	end
end,
["portals face back along their trail"] = function()
	local f = PortalTrails.facing({ { x = 0, z = 0 }, { x = 10, z = 0 } })
	expect.near(f.x, -1, 1e-9, "faces the way players come from"); expect.near(f.z, 0, 1e-9, "level")
end,
["a portal can only be used from close by"] = function()
	expect.equal(PortalTrails.near({ x = 0, z = 0 }, { x = 10, z = 0 }, 16), true, "inside reach")
	expect.equal(PortalTrails.near({ x = 0, z = 0 }, { x = 100, z = 0 }, 16), false, "from the plaza")
end,
["trails leave the island where the hedge has its gaps"] = function()
	local exit = PortalTrails.exitPoint(town.PORTAL_AREAS[1].trail, town.BOUNDS.HALF_X)
	expect.near(exit.x, 130, 1e-9, "on the island edge"); expect.near(exit.z, -26, 1e-9, "Wild trail exit")
end,
["signposts stand in walkable ground and every arm names a known area"] = function()
	local keys = {}
	for _, area in town.PORTAL_AREAS do keys[area.key] = true end
	for _, sign in town.SIGNPOSTS do
		expect.equal(PortalTrails.inside(town.WALK_EDGE, sign), true, `signpost at {sign.x}, {sign.z}`)
		for _, arm in sign.arms do expect.equal(keys[arm], true, `arm {arm}`) end
	end
end,
```

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run`
Expected: FAIL (module `PortalTrails` not found).

- [ ] **Step 3: Implement `PortalTrails` and the config values above.** Point-in-polygon by ray casting; `isSimple` by segment-segment intersection over non-adjacent pairs.

- [ ] **Step 4: Run the tests**

Run: `lune run tests/run`
Expected: `PortalTrails` passes. `TownLayout` tests that assert portals stand on the street ("every plaza portal stands at a street end", "a portal is too close to the edge", "a glowing path from the plaza edge to each portal") now fail: Task 2 rewrites them. Note them; don't change them here.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Util/PortalTrails.luau tests/PortalTrails.spec.luau tests/run.luau src/shared/Config/Town.luau src/shared/Config/Wild.luau src/shared/Config/Places.luau src/shared/Config/Pvp.luau
git commit -m "Portal areas: trails, walkable edge and portal spots in config (pure, tested)"
```

---

### Task 2: TownLayout follows the trails

**Files:**
- Modify: `src/shared/Util/TownLayout.luau` (hedge gaps, portal frame yaw, `trailLines` replacing `portalPaths`)
- Modify: `tests/TownLayout.spec.luau` (rewrite the three portal tests, add hedge-gap and signpost tests)

**Interfaces:**
- Consumes: `PortalTrails.exitPoint`, `PortalTrails.facing` (Task 1). Pure modules don't require siblings, so TownLayout doesn't require PortalTrails: the caller computes them and passes them in the `World` (TownService in Task 4; `tests/TownLayout.spec.luau` builds its WORLD the same way from PortalTrails).
- Produces:
  - `World.exits: { Point }`, `World.facings: { Point }`
  - `TownLayout.trailLines(world: World, town: any): { { points: { Point } } }`: per area, the plaza rim point level with the trail's first point, then every trail point, the last one moved `town.FLOOR.PATH_END_INSET` back toward the previous point.
  - `TownLayout.build` places Portal frames at each portal with yaw from `world.facings[i]` and skips Hedge sections whose centre is within `town.TRAIL.HEDGE_GAP` of any `world.exits[i]` along that edge.

- [ ] **Step 1: Rewrite the failing tests:**
  - "every portal stands at the end of its trail, outside the island": `math.abs(portal.x) > town.BOUNDS.HALF_X` for each portal, and it equals the area's last trail point.
  - "the hedge rings the island except at the trail exits": no Hedge placement within `HEDGE_GAP` of an exit; at least one Hedge on every side.
  - "a glowing line runs from the plaza along each trail": `#lines == 3`; first point on the plaza rim (`distance to spring == PLAZA_RADIUS` within 1e-6); last point `PATH_END_INSET` from the portal; all middle points equal the trail points.
  - "portal frames face back along their trail": the Portal placement's yaw equals `faceYaw(facing.x, facing.z)`.
  - Keep "portals stay clear" (clearance from decor) as is.

- [ ] **Step 2: Run** `lune run tests/run`. Expected: the rewritten tests FAIL (`trailLines` missing, frames facing the old way, hedge closed).

- [ ] **Step 3: Implement** the World fields, hedge gaps, frame yaw and `trailLines`; delete `portalPaths`.

- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.

- [ ] **Step 5: Commit** `git commit -m "TownLayout: hedge gaps at the trail exits, frames facing the trails, glowing lines along them"`

---

### Task 3: Terrain from config (pure shapes, server fill)

**Files:**
- Create: `src/shared/Config/Scenery.luau` (plain data: `TERRAIN`, `FALLS`, `FROZEN_FALLS`, `GIANT_TREES`, `PINES`, `CACTI`, `TORCHES`, `PLATFORM`, `SOUNDS`, `EMITTERS`, `MAX_CELLS = 180000`, `MATERIAL_COLORS = { Sandstone = { 190, 90, 60 }, Snow = { 240, 246, 255 } }`)
- Create: `src/shared/Util/TownTerrain.luau`
- Create: `tests/TownTerrain.spec.luau`
- Create: `src/server/Services/SceneryService.luau` (main place only; this task: terrain only)
- Modify: `src/server/init.server.luau` (start SceneryService after TownService)
- Modify: `src/server/Services/TownService.luau:70-103` (Baseplate `Transparency = 1`, `CanCollide` stays true)

**Interfaces:**
- Produces (`TownTerrain`, pure):
  - `export type Op = { shape: "Block" | "Ball" | "Wedge", x: number, y: number, z: number, yaw: number?, size: { x: number, y: number, z: number }?, radius: number?, material: string }`
  - `TownTerrain.ops(scenery: any, town: any): { Op }`: in this order: island Grass block (x -130..130, z -110..110, y -8..0); Asphalt block under the street rect (x -110..110, z -48..48, y -8..0); Ground block under every plot rect; each area's floor and trail corridor (blocks along each trail segment, `TRAIL.WIDTH` wide, of the area's `surface`, top at 0); then `scenery.TERRAIN` shapes (hills behind the shop rows, forest floor and cliff, the falls' pool basin and water, Frostpeak's clearing, peak and glacier falls, Ember Canyon's floor, striped Sandstone walls and end wall).
  - `TownTerrain.materialAt(ops: { Op }, x: number, z: number): string?` (material of the last op whose footprint covers (x, -2, z); for tests)
  - `TownTerrain.topAt(ops: { Op }, x: number, z: number): number?` (highest top of ops covering that column; for tests)
  - `TownTerrain.estimatedCells(ops: { Op }): number` (sum of op volumes / 64)
- Server: `SceneryService.Start()` applies ops with `Terrain:FillBlock` / `FillBall` / `FillWedge` (yaw → CFrame rotation), sets `Terrain:SetMaterialColor` from `MATERIAL_COLORS`, yields between ops (`task.wait()` every 20 ops).

- [ ] **Step 1: Write the failing tests:**

```luau
["nothing in the island rises above the ground parts"] = function()
	for x = -128, 128, 8 do for z = -108, 108, 8 do
		local top = TownTerrain.topAt(OPS, x, z)
		assert(top == nil or top <= 0, `terrain at {x}, {z} reaches {top}`)
	end end
end,
["no grass grows through the street or under the shops"] = function()
	for _, spot in { { x = 0, z = 0 }, { x = 90, z = 30 }, { x = -64, z = -68 }, { x = 64, z = 68 } } do
		assert(TownTerrain.materialAt(OPS, spot.x, spot.z) ~= "Grass", `grass at {spot.x}, {spot.z}`)
	end
	expect.equal(TownTerrain.materialAt(OPS, -32, 100), "Grass", "open ground behind the shops is grass")
end,
["island fills sit on the 4-stud grid"] = function() -- every op inside the island has y top and bottom multiples of 4
end,
["every trail is walkable ground at y 0"] = function() -- materialAt and topAt == 0 at every trail point and segment midpoint
end,
["terrain stays inside the memory budget"] = function()
	assert(TownTerrain.estimatedCells(OPS) <= scenery.MAX_CELLS, "too much terrain")
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `Config/Scenery.TERRAIN` shapes (use the approved map: forest SE, Frostpeak NE with the peak beyond the walls around (215, 230), canyon W with walls z ±30..±70 rising 25-40, end wall at x -232), `TownTerrain`, and SceneryService's terrain fill.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Studio check:** `rojo serve` running; start Play through the MCP; Output has no errors; screenshots: the plaza (the plaza floor, crosswalks and glowing lines still show; grass blades on open ground, none through the street), each area from above, the town from the cinematic's aerial angle. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Scenery: terrain for the town and the three portal areas, built from config"`

---

### Task 4: Walls, trails, signposts, arches, moved portals and reach checks

**Files:**
- Create: `src/server/Util/TrailProps.luau` (code-built wooden signpost with arrow-shaped arms, trail arch with a name board and two lantern lights, all text SurfaceGuis with `MaxDistance = Town.SIGN_DISTANCE`)
- Modify: `src/server/Services/TownService.luau` (walls from `PortalTrails.walls(Town.WALK_EDGE, 1)` replacing the 4 rectangle walls; `getWorld()` fills `exits` / `facings`; glowing lines from `TownLayout.trailLines` drawn as rotated neon strips segment by segment, on the street at street top and on the trails at y 0.05; signposts from `Town.SIGNPOSTS`, arm yaw from `PortalTrails.armYaw(sign, area.trail[1])`; an arch at each `exitPoint` facing along the trail with the area's `name`)
- Modify: `src/server/Services/WildService.luau:347-352` (Wild portal facing from `PortalTrails.facing(Town.PORTAL_AREAS[1].trail)`) and `:813-819` (delete the `where == "wild"` branch; only `"home"` stays)
- Modify: `src/server/Services/FrontierService.luau:118-121` (facing from the Frontier area) and `onTravel` (`explore` and `friend` return early unless `PortalTrails.near(root position, Places.FRONTIER_PORTAL, Town.PORTAL_REACH)`)
- Modify: `src/server/Services/ArenaService.luau:231` (facing from the Arena area)

**Interfaces:**
- Consumes: Task 1 (`PortalTrails.*`, `Town.PORTAL_AREAS`, `WALK_EDGE`, `SIGNPOSTS`, `PORTAL_REACH`, `SIGN_DISTANCE`), Task 2 (`TownLayout.trailLines`, `World.exits/facings`).
- Produces: `TrailProps.signpost(parent: Instance, at: CFrame, arms: { { text: string, sub: string, color: Color3, yaw: number } }): Model`, `TrailProps.arch(parent: Instance, at: CFrame, name: string, color: Color3, width: number): Model`.

- [ ] **Step 1: Implement** the changes above. (Server builders aren't Lune-testable; their placements were tested in Tasks 1-2.)
- [ ] **Step 2: Run** `lune run tests/run` and `lune run "$TEMP/lc/check2.luau" <changed files>`. Expected: all pass, all files compile.
- [ ] **Step 3: Studio check (Play):**
  - Walk the character (MCP `character_navigation`) from the plaza along each trail to each portal; each prompt works (Wild travels; Frontier opens its menu; Arena watches).
  - Firing `Remotes.FrontierTravel:FireServer("explore")` from the plaza does nothing; firing `WildTravel:FireServer("wild")` does nothing.
  - The character can't leave the walk edge (try walking into a corner and along each wall).
  - Screenshots: each signpost, each arch, the glowing lines along the street and trails. Show the user.
- [ ] **Step 4: Commit** `git commit -m "Portals move to their areas: walls, trails, signposts, arches; travel needs the portal"`

---

### Task 5: Move the hand-placed street-end decor (Studio)

**Files:** none in the repo (the user saves `assets/town/TownDecor.rbxm` afterwards).

- [ ] **Step 1:** In Edit mode, list every `Workspace.TownDecor` / `PlazaGarden` model whose bounding box overlaps a trail corridor (each trail segment inside the island, `Town.TRAIL.WIDTH` + 2 wide) or an arch, signpost or hedge gap. Screenshot the street ends (before).
- [ ] **Step 2:** Move each listed model sideways the least distance that clears the corridor, staying inside the island and off the plots (`PivotTo`; nothing deleted). Screenshot the street ends (after) from the same camera.
- [ ] **Step 3:** Show the user before/after and ask them to save `Workspace.TownDecor` over `assets/town/TownDecor.rbxm` (and `PlazaGarden` if touched, which lives in the place). Wait for "saved".
- [ ] **Step 4:** Check the synced file loads (stop/Play, the moved pieces stay moved, Output clean). Commit the new `.rbxm` if the user saved it in the repo: `git add assets/town/TownDecor.rbxm && git commit -m "TownDecor: street-end pieces moved clear of the trails"`

---

### Task 6: Dress the areas and the town

**Files:**
- Modify: `src/shared/Config/Scenery.luau` (placements filled in: `GIANT_TREES` (8 round the forest clearing, 4 just outside the island corners at about (±142, ±122)), `PINES` (about 10 round Frostpeak, `snow = true`), `CACTI` (about 6 in the canyon), `PLATFORM` and `TORCHES` (the Arena portal's stone platform and two torch pillars), `FALLS` (top `{ x = 185, y = 34, z = -150 }`, bottom `{ x = 185, y = 0, z = -140 }`, 2 beams, `TEXTURE` id, mist and splash emitters), `FROZEN_FALLS` (glacier terrain already from Task 3, plus a few ice crystal parts), `EMITTERS` (snow 2, embers 2, torch fire 2, aurora 1 beam ribbon), `SOUNDS` (falls at the pool, wind at Frostpeak, embers in the canyon, birds in town; ids from the Creator Store, volume and roll-off), `SMALL_DECOR_SIZE = 4`)
- Modify: `src/shared/Config/Town.luau` (`SLOTS`: `GiantTree = { height = 55, collide = true }` (variants TreeA / TreeB), `SnowPine = { height = 26, collide = true }` (variants Pine / PineA / PineB))
- Modify: `src/server/Services/SceneryService.luau` (place the props with `Props.place` / `Props.fit`; tint SnowPine leaves to snow; falls beams + emitters; ice crystals; cacti, platform and torches built from parts in `TrailProps` style; positioned sounds; at start set `CastShadow = false` on every part under `TownDecor` / `PlazaGarden` whose largest size is under `SMALL_DECOR_SIZE`)
- Create (asset): a tileable vertical water-streak texture (Figma image generator or a Blender render), uploaded through the Studio MCP `upload_image`; id in `Scenery.FALLS.TEXTURE`
- Modify: `tests/TownTerrain.spec.luau` (placement tests)

- [ ] **Step 1: Write the failing tests** (in `tests/TownTerrain.spec.luau`):
  - "every placed prop stands on walkable ground or is backdrop outside the walls": giant trees, pines, cacti, torches are either outside `WALK_EDGE` or at least 4 studs from every trail point and portal.
  - "one flowing waterfall, emitters within the caps": `#Scenery.FALLS.beams <= 3`, mist + splash ≤ 2, `EMITTERS` per area ≤ 4.
  - "small decor rule": `Scenery.SMALL_DECOR_SIZE == 4`.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (placements missing).
- [ ] **Step 3: Implement** the placements and SceneryService dressing; make and upload the water texture.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Studio check:** Play; Output clean; screenshots of Forest Falls, Frostpeak and Ember Canyon from the trail arch and from the portal, beside the concept pictures; the town corners. Show the user and take their feedback (one round of fixes inside this task).
- [ ] **Step 6: Commit** `git commit -m "Scenery: Forest Falls, Frostpeak and Ember Canyon dressed; giant trees, sounds, shadows off on small decor"`

---

### Task 7: Day cycle (town only)

**Files:**
- Create: `src/shared/Config/DayCycle.luau` (plain data; replaces `Town.LIGHTING`)
- Create: `src/shared/Util/DayCycle.luau`
- Create: `tests/DayCycle.spec.luau`
- Create: `src/client/Util/SkyLook.luau` (applies a Look to Lighting and its Atmosphere / Bloom / ColorCorrection / SunRays; a hold flag other controllers set)
- Create: `src/client/Controllers/DayCycleController.luau`
- Modify: `src/server/Services/TownService.luau:334-358` (`setLighting` applies `DayCycle.fixedLook`; creates the SunRaysEffect too; sets `workspace:SetAttribute("DayCycleStart", workspace:GetServerTimeNow())`)
- Modify: `src/shared/Config/Town.luau` (remove `LIGHTING`; update every reference)
- Modify: `src/server/Services/DevService.luau` (`addCommand(folder, "time", ...)`: `/time <morning|afternoon|sunset|night|dawn>` sets `DayCycleStart = DayCycle.startFor(cycle, phase, now)`)
- Modify: `src/shared/Config/AdminPanel.luau` (section "Town": Morning, Afternoon, Sunset, Night buttons)
- Modify: `src/client/init.client.luau` (start DayCycleController)

**Interfaces:**
- Produces (config `DayCycle`):
  - `PHASES = { { name = "morning", seconds = 420, look = MORNING }, { name = "afternoon", seconds = 300, look = AFTERNOON }, { name = "sunset", seconds = 240, look = SUNSET }, { name = "night", seconds = 120, look = NIGHT }, { name = "dawn", seconds = 90, look = DAWN } }`, `BLEND_SECONDS = 40` (each phase blends into the next over its last 40 s), `FIXED = "afternoon"`, `TOWN_REGION = { HALF_X = 320, HALF_Z = 300 }`, `UPDATE_HZ = 10`.
  - Look shape: `{ clockTime, brightness, exposure, ambient = {r,g,b}, outdoorAmbient = {r,g,b}, atmosphere = { density, offset, haze, glare, color = {r,g,b}, decay = {r,g,b} }, bloom = { intensity, size, threshold }, saturation, contrast, tint = {r,g,b}, sunRays = { intensity, spread } }`.
  - MORNING and SUNSET: the spec's tested values verbatim. AFTERNOON: today's `Town.LIGHTING` (clockTime 15.5, brightness 1.6, exposure -0.25, ambient (110,102,96), outdoorAmbient (120,112,105), atmosphere 0.25 / 0.1 / 1.2 / 0.2 / (225,215,200) / (140,160,190), bloom 0.25 / 24 / 2, saturation 0.12, contrast 0, tint (255,255,255), sunRays 0 / 0). NIGHT starting values: clockTime 21.5, brightness 0.6, exposure 0, ambient (70,80,120), outdoorAmbient (60,70,110), atmosphere 0.35 / 0.1 / 1 / 0 / (90,110,170) / (40,50,90), bloom 0.6 / 30 / 1.2, saturation 0.1, contrast 0.1, tint (200,215,255), sunRays 0 / 0. DAWN starting values: clockTime 5.6, brightness 1.2, exposure 0, ambient (110,105,130), outdoorAmbient (130,120,150), atmosphere 0.36 / 0.12 / 2 / 0.4 / (255,200,190) / (150,150,200), bloom 0.45 / 30 / 1.5, saturation 0.15, contrast 0.04, tint (255,235,235), sunRays 0.06 / 0.6. Night and dawn are tuned in Studio (step 5).
- Produces (`DayCycle`, pure):
  - `DayCycle.loopSeconds(cycle): number`
  - `DayCycle.phaseAt(cycle, seconds: number): (string, number)` (phase name, 0..1 progress; seconds wraps by the loop)
  - `DayCycle.lookAt(cycle, seconds: number): Look` (blended)
  - `DayCycle.blend(a: Look, b: Look, t: number): Look` (numbers and colours linearly; `clockTime` forward through 24 when b < a)
  - `DayCycle.fixedLook(cycle): Look`
  - `DayCycle.startFor(cycle, phase: string, now: number): number`
  - `DayCycle.inTown(cycle, x: number, z: number): boolean`
  - `DayCycle.timelapse(cycle, progress: number): Look` (0 = morning, 1 = sunset; through afternoon; clamps)
- Produces (`SkyLook`, client): `SkyLook.apply(look: DayCycle.Look)`, `SkyLook.hold(on: boolean)` (while held, DayCycleController stops applying; the cinematic holds it), `SkyLook.isHeld(): boolean`.

- [ ] **Step 1: Write the failing tests:**

```luau
["a loop is about 20 minutes and morning is the longest phase"] = function()
	expect.equal(DayCycle.loopSeconds(cycle), 1170, "loop")
	local _, longest = nil, 0
	for _, phase in cycle.PHASES do longest = math.max(longest, phase.seconds) end
	expect.equal(cycle.PHASES[1].name, "morning", "starts in the morning"); expect.equal(cycle.PHASES[1].seconds, longest, "morning longest")
end,
["the sun never runs backwards, even past midnight"] = function()
	local last = DayCycle.lookAt(cycle, 0).clockTime
	for s = 1, 1170, 1 do
		local now = DayCycle.lookAt(cycle, s).clockTime
		local step = (now - last) % 24
		assert(step < 6, `clock jumped back at {s}s: {last} -> {now}`)
		last = now
	end
end,
["each phase holds its own look before blending"] = function()
	expect.equal(DayCycle.lookAt(cycle, 10).clockTime, 7.3, "early morning is the morning look")
	expect.near(DayCycle.lookAt(cycle, 420 + 300 + 10).clockTime, 17.75, 1e-9, "sunset")
end,
["the Wild and the Arena are outside the town; every portal area is inside"] = function()
	expect.equal(DayCycle.inTown(cycle, 0, 1200), false, "the Wild"); expect.equal(DayCycle.inTown(cycle, 0, -1200), false, "the Arena")
	for _, p in town.WALK_EDGE do expect.equal(DayCycle.inTown(cycle, p.x, p.z), true, "walk edge") end
end,
["/time puts now at the start of that phase"] = function()
	local start = DayCycle.startFor(cycle, "sunset", 5000)
	local name, progress = DayCycle.phaseAt(cycle, 5000 - start)
	expect.equal(name, "sunset", "phase"); expect.near(progress, 0, 1e-9, "at its start")
end,
["the time-lapse runs morning to sunset"] = function()
	expect.equal(DayCycle.timelapse(cycle, 0).clockTime, 7.3, "starts in the morning")
	expect.equal(DayCycle.timelapse(cycle, 1).clockTime, 17.75, "ends at sunset")
end,
["outside the town the look is today's afternoon"] = function()
	expect.equal(DayCycle.fixedLook(cycle).clockTime, 15.5, "afternoon")
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** the config, `DayCycle`, `SkyLook`, DayCycleController (every `1 / UPDATE_HZ` s: if `SkyLook.isHeld()` skip; position = the camera's focus; `SkyLook.apply(if inTown then lookAt(now - DayCycleStart) else fixedLook)`), TownService, DevService `/time`, AdminPanel buttons.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass (AdminPanel spec: the new buttons map to a registered command).
- [ ] **Step 5: Studio check:** Play; `/time` each phase: screenshot the plaza, a shop interior and Forest Falls for each phase. Tune NIGHT and DAWN until the town reads and shops stay bright; teleport to the Wild (`/wild`) at night: afternoon look at once; back home: the cycle. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Day cycle: morning to sunset in town, fixed afternoon in the Wild and the Arena"`

---

### Task 8: Frame watchdog, tree sway and butterflies

**Files:**
- Create: `src/shared/Config/Ambient.luau` (plain data: `SWAY = { RANGE = 150, HZ = 30, ANGLE = 0.025, SPEED = 1.3, CULL_INTERVAL = 0.5 }`, `WATCHDOG = { SLOW_FRAME = 1 / 45, SLOW_SECONDS = 3, FAST_FRAME = 1 / 55, FAST_SECONDS = 10, LOW_QUALITY = 3 }`, `BUTTERFLY_RANGE = 120`, `CRITTERS` (Task 9))
- Create: `src/shared/Util/FrameWatchdog.luau`, `tests/FrameWatchdog.spec.luau`
- Create: `src/client/Util/Extras.luau` (one Heartbeat watchdog for the client; `Extras.enabled(): boolean` = watchdog on and the saved graphics level isn't an explicit level ≤ `LOW_QUALITY`)
- Create: `src/client/Controllers/TreeSwayController.luau` (trees by model name TreeA-D, Pine*, CherryTree, GiantTree, SnowPine under TownDecor / PlazaGarden / Town / Scenery; canopy = highest MeshPart, pivot = its lower part; `BulkMoveTo` at `HZ` for trees within `RANGE` of the camera; restores rest CFrames when extras are off)
- Modify: `src/shared/Config/Town.luau` (`BUTTERFLIES.SPOTS = { { x = 0, z = 0, count = 10, minRadius = 6, maxRadius = 17 }, { x = 190, z = -120, count = 5, minRadius = 6, maxRadius = 18 }, { x = 136, z = 0, count = 3, minRadius = 3, maxRadius = 10 } }`)
- Modify: `src/client/Controllers/ButterflyController.luau` (one flock per spot; skip updating a flock beyond `BUTTERFLY_RANGE`; hide all when `Extras.enabled()` is false)

**Interfaces:**
- Produces: `FrameWatchdog.new(cfg): Watchdog`, `Watchdog:push(dt: number)`, `Watchdog.on: boolean` (starts true).

- [ ] **Step 1: Write the failing tests:**

```luau
["extras switch off after 3 s of slow frames"] = function()
	local dog = FrameWatchdog.new(ambient.WATCHDOG)
	for _ = 1, 3 * 30 do dog:push(1 / 30) end
	expect.equal(dog.on, false, "off after a slow stretch")
end,
["a short hitch doesn't switch them off"] = function()
	local dog = FrameWatchdog.new(ambient.WATCHDOG)
	for _ = 1, 10 do dog:push(1 / 20) end
	for _ = 1, 120 do dog:push(1 / 60) end
	expect.equal(dog.on, true, "still on")
end,
["they come back only after 10 s of fast frames"] = function()
	local dog = FrameWatchdog.new(ambient.WATCHDOG)
	for _ = 1, 3 * 30 do dog:push(1 / 30) end
	for _ = 1, 5 * 60 do dog:push(1 / 60) end
	expect.equal(dog.on, false, "not yet")
	for _ = 1, 6 * 60 do dog:push(1 / 60) end
	expect.equal(dog.on, true, "back on")
end,
["butterflies stay within the agreed number"] = function()
	local total = 0
	for _, spot in town.BUTTERFLIES.SPOTS do total += spot.count end
	assert(total <= 20, `{total} butterflies`)
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** FrameWatchdog (running averages over the window lengths), Extras, TreeSwayController, butterfly spots.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Studio check:** Play; trees near the camera sway, far ones still; set `settings().Rendering.QualityLevel` to Level01: unchanged (explicit saved levels only); measure the sway script time with a RenderStepped `os.clock` probe (expected about 0.2 ms on PC as in the spike). Screenshot butterflies at the forest clearing. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Ambient: frame watchdog, tree sway near the camera, butterflies at three spots"`

---

### Task 9: Three animals running around

**Files:**
- Modify: `src/shared/Config/Ambient.luau` (`CRITTERS = { { model = "Fox", home = { x = 150, z = -62 }, radius = 8 }, { model = "Bunny", home = { x = 0, z = 0 }, radius = 18, avoid = 9 }, { model = "Capybara", home = { x = -32, z = 68 }, radius = 8 } }`, `CRITTER = { SPEED = 10, PAUSE = { 1.5, 4 }, RANGE = 120 }`)
- Create: `src/shared/Util/Wander.luau`, `tests/Wander.spec.luau`
- Create: `src/client/Controllers/TownCritterController.luau` (per critter: a client-only invisible marker part; the Cute Pets model from `CreatureVisuals.getTemplate` (pack `CutePets`), `CreatureVisuals.strip`, `CreatureVisuals.build(model, marker, height, false, name)`; each frame within `RANGE` of the camera and with `Extras.enabled()`: move the marker with `Wander.step`, pick a new target with `Wander.target` after a pause, `CreatureVisuals.step(body, dt, now, origin, Party.MOTION)`; beyond range or extras off: hidden and not stepped)
- Modify: `src/client/init.client.luau`

**Interfaces:**
- Produces: `Wander.target(home: Point, radius: number, avoid: number?, rng: Random-like { NextNumber: (self, number, number) -> number }): Point` (uniform in the ring avoid..radius), `Wander.step(pos: Point, target: Point, speed: number, dt: number): (Point, boolean)` (moves toward the target without passing it; true when arrived).

- [ ] **Step 1: Write the failing tests:**
  - "targets stay in the home area, clear of the spring": 1000 targets for the Bunny all within `radius` of home and at least `avoid` from it (use a deterministic stub rng in the test).
  - "a step never overshoots": from (0,0) toward (1,0) at speed 10 for dt 1 lands exactly on (1,0) and returns true.
  - "only 3 animals": `#ambient.CRITTERS == 3`.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** Wander and TownCritterController.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Studio check:** Play; screenshots of each animal in its home; walk away past 120 studs and back: hidden then running again; Output clean. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Ambient: a fox, a bunny and a capybara running around town"`

---

### Task 10: Welcome cinematic

**Files:**
- Modify: `src/shared/Config/Data.luau:6` (`SCHEMA_VERSION = 13`)
- Modify: `src/server/Util/Migrations.luau` (`MIGRATIONS[12] = function(data) data.seenWelcome = true end`: existing players aren't first-timers, set unconditionally because `Reconcile` may already have added `false`)
- Modify: `tests/Migrations.spec.luau`
- Modify: `src/server/Services/DataService.luau` (`PlayerData.seenWelcome: boolean`, `TEMPLATE.seenWelcome = false`)
- Create: `src/server/Services/WelcomeService.luau` (`DataService.Register`: load sets `player:SetAttribute("SeenWelcome", data.seenWelcome == true)`; save writes it back only if loaded; `Remotes.WelcomeSeen` (rate-limited) sets the attribute true)
- Modify: `src/shared/Remotes.luau` (`"WelcomeSeen", -- client → server: () the welcome cinematic finished or was skipped`)
- Create: `src/shared/Config/Welcome.luau`, `src/shared/Util/WelcomePath.luau`, `tests/WelcomePath.spec.luau`
- Create: `src/client/Controllers/WelcomeController.luau`
- Modify: `src/server/Services/DevService.luau` (`/intro`: sets `SeenWelcome` false), `src/shared/Config/AdminPanel.luau` ("Replay intro" in "Town"), `src/server/init.server.luau`, `src/client/init.client.luau`

**Interfaces:**
- Consumes: `DayCycle.timelapse` (Task 7), `SkyLook.apply` / hold (Task 7).
- Produces (config `Welcome`): `SECONDS = 11`, `SUNSET_SHARE = 0.5`, `KEYS = { { t = 0, pos = { x = 205, y = 38, z = -80 }, look = { x = 185, y = 18, z = -145 } }, { t = 0.22, pos = { x = 150, y = 40, z = 90 }, look = { x = 200, y = 40, z = 180 } }, { t = 0.45, pos = { x = 40, y = 45, z = -30 }, look = { x = 0, y = 5, z = 0 } }, { t = 0.68, pos = { x = -120, y = 40, z = -25 }, look = { x = -210, y = 12, z = 0 } } }`, `SHOP_VIEW = { back = 22, up = 9 }`, `SKIP_SIZE = { 140, 56 }`, `STREAM_TIMEOUT = 3`.
- Produces (`WelcomePath`, pure): `WelcomePath.keys(cfg, door: { x: number, y: number, z: number }, outward: { x: number, z: number }): { Key }` (config keys plus the shop key at t = 1: `door + outward * back + up`, looking at the door), `WelcomePath.sample(keys, t: number): (pos, look)` (Catmull-Rom through the keys by t), `WelcomePath.dayProgress(cfg, t: number): number` (= `math.min(1, t / (1 - SUNSET_SHARE))`).
- Client flow: when the local player's plot (a `workspace.Plots` child with `OwnerUserId == player.UserId`) exists and `SeenWelcome == false`: request streaming around every key (`player:RequestStreamAroundAsync`, pcall, `STREAM_TIMEOUT`), hold SkyLook, hide the other ScreenGuis and lock movement, Scriptable camera along `sample(keys, elapsed / SECONDS)` with `SkyLook.apply(DayCycle.timelapse(cycle, dayProgress))`; a Skip button (`SKIP_SIZE`, bottom right, clear of the jump button); on finish, skip or the character dying: restore camera, GUIs, movement and the lighting hold, then `Remotes.WelcomeSeen:FireServer()`.

- [ ] **Step 1: Write the failing tests:**

```luau
-- tests/Migrations.spec.luau
["v13: existing players have already seen the welcome"] = function()
	local data = { version = 12, seenWelcome = false } -- Reconcile may add false first
	Migrations.run(data, 13)
	expect.equal(data.seenWelcome, true, "no cinematic for existing players")
end,
-- tests/WelcomePath.spec.luau
["the flight lasts 10-12 seconds"] = function()
	assert(welcome.SECONDS >= 10 and welcome.SECONDS <= 12, "length")
end,
["it ends at the player's own shop"] = function()
	local keys = WelcomePath.keys(welcome, { x = -64, y = 0, z = -48 }, { x = 0, z = 1 })
	local pos, look = WelcomePath.sample(keys, 1)
	expect.near(pos.z, -48 + welcome.SHOP_VIEW.back, 1e-6, "in front of the door"); expect.near(look.x, -64, 1e-6, "looking at it")
end,
["sunset holds for the last half"] = function()
	expect.equal(WelcomePath.dayProgress(welcome, 0.5), 1, "sunset by halfway")
	expect.equal(WelcomePath.dayProgress(welcome, 0), 0, "morning at the start")
	assert(WelcomePath.dayProgress(welcome, 0.25) > 0 and WelcomePath.dayProgress(welcome, 0.25) < 1, "time-lapse in between")
end,
["keys run in order through the three areas and the plaza"] = function() -- t strictly increasing, 0 first, 1 last
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** the data change, WelcomeService, remote, config, WelcomePath, WelcomeController, `/intro`, admin button.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Studio check:** Play with `SeenWelcome` false (`/intro`): screenshots at about 0 s, 3 s, 6 s and the end (shop at sunset); Skip mid-flight restores everything; reset the character mid-flight: camera and controls restored; rejoin (stop/Play): no replay. Phone layout in the Device emulator: the Skip button clear of the jump button and at least 48 px. Show the user.
- [ ] **Step 6: Commit** `git commit -m "Welcome cinematic: a first-visit time-lapse from Forest Falls to your shop at sunset (schema v13)"`

---

### Task 11: Performance check and docs

**Files:**
- Modify: `DESIGN.md` (section 3 main town and portals; 4.x travel notes if they name portal spots; 10.2 file tree; 10.4 `seenWelcome`; 10.5 measured numbers, the new triangle total, the caps from this plan; 13 backlog entry), `CLAUDE.md` (tests list: PortalTrails, TownTerrain, DayCycle, FrameWatchdog, Wander, WelcomePath; dev commands `/intro`, `/time <phase>`), `docs/props.md` (GiantTree, SnowPine slots; TownDecor moved)
- Obsidian vault: lessons learned and decisions log

- [ ] **Step 1: Stress test** in Play (the 2026-10-30 method: clone a full shop into all 6 plots, 24 customers, 12 workers, 6 summoned-pet markers, 5 avatar clones; fixed Scriptable cameras STREET `(-125,35,0)→(60,4,0)`, SHOP `(-64,9,-50)→(-64,3,-82)`, CORNER at Forest Falls; `Stats.RenderCPUFrameTime` / `RenderGPUFrameTime` over 3 s at Level01 and Level10, twice; `Stats:GetTotalMemoryUsageMb()` before and after the scenery builds).
  Expected: STREET and SHOP render CPU within +1.5 ms of 10.2-12.3 ms; 60 fps; memory growth ≤ about 50 MB. If over: cut terrain extent (`MAX_CELLS`), emitters or sway range first, re-measure, record what was cut.
- [ ] **Step 2: Phone check:** Device emulator (landscape phone) screenshots of the plaza, a trail and the cinematic's Skip button.
- [ ] **Step 3: Docs** as listed; `lune run tests/run` all pass; `rojo build -o "$TEMP/test.rbxl"` builds.
- [ ] **Step 4: Commit** `git commit -m "DESIGN: Portal Worlds measured and documented"`
- [ ] **Step 5:** Final whole-branch review (per the chosen execution method), then tell the user exactly what to judge in Studio.
