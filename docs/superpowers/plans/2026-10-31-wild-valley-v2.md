# Wild Valley Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the main game's Wild into a winding S-shaped valley:
- three biomes at three heights;
- boss portals that send each fight to its own arena copy;
- monster counts that grow with the players in a zone;
- wooden trailhead signs.

**Architecture:**
- **Layout:** the valley's layout is plain data in `Config/WildValley` (biome outlines, ground heights, trail points with
  heights, edge, terrain fills, arena field). Pure rules in `Util/WildValley` and `Util/WildPopulation` are Lune-tested,
  with the ground modelled by `TownTerrain.groundAt`.
- **Building:**
  - `SceneryService` fills the terrain and places the dressing on the modelled ground.
  - `WildService` builds the trail-side pieces, spawn spots, boss portals and arena copies, and runs the population
    loop.
  - `BossService` hands fights to free arena copies.
- **Frontier and Dungeon:** they keep today's code paths (`VALLEY` false).

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-31-wild-valley-v2-design.md` (round 1's spec
`2026-10-31-wild-valley-design.md` still governs the moods and props it doesn't replace).

## Global Constraints

- **Where:** main game only, gated by `VALLEY = not Place.isFrontier() and not Place.isDungeon()` in `WildService`.
  The Frontier and Dungeon maps, arenas and spawn rings stay as they are.
- **Repo rules:**
  - numbers in `src/shared/Config`;
  - pure modules don't require siblings and take configs (or builder functions) as arguments;
  - `--!strict`;
  - DESIGN.md kept in sync in the same change;
  - SourceOrder (no local used above its definition).
- **Text:** plain ASCII plus `·` and emoji.
- **Monster numbers:** a zone keeps 8 monsters quiet, +2 per player in it past the first 3, up to 24. Respawn takes
  20-40 s quiet and 10-20 s busy (more than 8 wanted). Extras are never despawned, only not respawned.
- **Biomes:** each at least 200 studs across. Meadow ground y 0, gorge y 15, ridge y 35.
- **Trail:** turns right into the gorge, then left onto the ridge. Walkable slopes (at most 25 degrees), no steps.
- **Arenas:** up to 4 arena copies per Wild boss (`Bosses.ARENA_COPIES = 4`). A solo fight is never blocked by
  another fight or a forming group while a copy is free.
- **Loot:** a win's unpicked loot goes into the Bag before anyone is sent back from an arena copy automatically.
- **Terrain budget:**
  - the valley's own cap is `WildValley.MAX_CELLS` (90000), covering the valley plus the arena clearings;
  - `Scenery.MAX_CELLS` rises from 180000 only in Task 6, after a before/after memory and fps measurement.
- **Performance:** at most 4 area effects per biome; 60 fps at graphics levels 1 and 10 on the busiest views
  (DESIGN 10.5's method).
- **Workflow (CLAUDE.md), after every task:**
  1. Lune tests, then a Rojo build check.
  2. Studio Play through the MCP: Output free of errors, screenshots of the key spots.
  3. Studio MCP: read and inspect freely, but ask before editing the place itself. Scripts live only in the repo.

## Review Focus

1. **Someone in an arena copy who dies, respawns at their shop or leaves the game:**
   - the copy must free up (members pruned);
   - it must never stay "busy" forever.
   - Test `BossRules.stillInCopy` (Task 5).
2. **A monster wandering or chasing onto a cliff edge, a shelf or the stream:** it must refuse the step and never
   climb, drop or walk on water. Test `WildValley.canStep` (Task 1).
3. **"Take me there", `/boss n` and the Admin Go button:** must land the player on the ground in front of the boss
   portal, inside the edge, on gentle ground. Test: the gate spot in Task 5.
4. **All 4 copies busy, or a group member failing the re-check after streaming:**
   - a clear message;
   - the reserved copy released;
   - nobody moved.
   - Test `BossRules.pickCopy` returning nil (Task 5) plus a Studio check.
5. **Spawn spots near the edge of a hill or shelf:** a monster's home must stand on gentle ground well inside its
   biome. Test: spot ground and slope in Task 3.

---

### Task 1: The winding valley's ground

**Files:**
- Modify: `src/shared/Config/WildValley.luau`:
  - new `BIOMES`, `TRAIL`, `EDGE`, `TERRAIN`, `CARVES`, `MAX_STEP`, `PORTAL_CLEAR`, `BOARD_CLEAR`, `MAX_CELLS = 90000`;
  - `ARRIVAL_CLEAR` kept;
  - round 1's `TERRAIN` replaced.
- Modify: `src/shared/Util/WildValley.luau`:
  - new `trail(valley)`, `zoneAt`, `clearOf(point, valley)`, `terrainOps`, `canStep`;
  - remove `zoneSign` and `arenaCenter`;
  - keep `zoneCenter`, `spawnSpots`, `markers` and `inside` for the Frontier and the markers.
- Modify: `src/shared/Util/TownTerrain.luau`: export the local `trailSegment` as `TownTerrain.trailSegment`.
- Modify: `src/server/Services/SceneryService.luau`: the valley's ops from
  `WildValley.terrainOps(WildValleyConfig, TownTerrain.trailSegment)` in `Start`.
- Modify: `src/server/Services/WildService.luau`, in `VALLEY` only:
  - no invisible zone floors or grid paths;
  - `rayParams` includes `workspace.Terrain` with `IgnoreWater = true`;
  - `moveToward` refuses a step when `not WildValley.canStep(...)`;
  - `SpawnAt` picks its zone by `WildValley.zoneAt` (else the nearest biome centre).
- Test: `tests/WildValley.spec.luau`. Rewrite the layout tests. Keep "spawn spots match today's ring" (the Frontier
  grid), "markers run the whole trail" and the arena-look test. Delete round 1's tests that pin its coordinates
  (Tasks 1, 2, 4 and 6 replace them):
  - "props stay clear of spawn spots and their wander";
  - "props stay off the trail, the stream, the arenas and the arrival";
  - "the edge closes round the zones, paths, arenas and arrival";
  - "the valley's terrain fits the budget and draws the zones at y 0";
  - "the name boards stand clear of the arch, the bridge, the stream, the props and the monsters";
  - "the edge lets players into the cave mouth but not past its carve".

**Interfaces:**
- Produces, all in `Util/WildValley`:
  - `WildValley.trail(valley: any): { { x: number, z: number, y: number } }`: returns `valley.TRAIL`.
  - `WildValley.zoneAt(valley: any, point: Point): number?`: the biome whose `outline` holds the point.
  - `WildValley.clearOf(point: Point, valley: any): (boolean, string?)`: off the trail, the stream and pond, the
    arrival, every biome's `portal` (`PORTAL_CLEAR`) and `board` (`BOARD_CLEAR`). Reasons: `"on the trail"`,
    `"in the stream"`, `"in the pond"`, `"in the arrival"`, `"by a boss portal"`, `"by a board"`.
  - `WildValley.terrainOps(valley: any, segment: (a: any, b: any, width: number, material: string) -> any): { any }`:
    returns `valley.TERRAIN`, then one `segment(TRAIL[i-1], TRAIL[i], TRAIL_WIDTH, TRAIL_MATERIAL[zone of the
    segment's end])` per trail segment, then `valley.CARVES`. Task 5 appends the arena clearings here.
  - `WildValley.canStep(fromY: number, toY: number, maxStep: number): boolean`: `math.abs(toY - fromY) <= maxStep`.
- Produces, in `Config/WildValley`:
  - `BIOMES[i] = { centre = Point, ground = number, outline = { Point }, portal = { x, z, faces = Point }, board = Point }`,
    indexed like `Wild.ZONES`;
  - `TRAIL_MATERIAL = { "Ground", "Limestone", "Basalt" }`;
  - `MAX_STEP = 1.5`, studs per monster step (0.1 s at chase speed 11 is 1.1 studs along).

- [ ] **Step 1: Write the failing tests**, in `tests/WildValley.spec.luau`. Build `OPS` once in the file as
  `WildValley.terrainOps(valley, TownTerrain.trailSegment)`.

```lua
["each biome is at least 200 studs across and stands at its height"] = function()
	local heights = { 0, 15, 35 }
	for index, biome in valley.BIOMES do
		expect.equal(biome.ground, heights[index], `biome {index} height`)
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in biome.outline do
			minX, maxX, minZ, maxZ = math.min(minX, p.x), math.max(maxX, p.x), math.min(minZ, p.z), math.max(maxZ, p.z)
		end
		assert(math.max(maxX - minX, maxZ - minZ) >= 200, `biome {index} is {maxX - minX} x {maxZ - minZ}`)
		local ground = TownTerrain.groundAt(OPS, biome.centre.x, biome.centre.z)
		assert(ground and math.abs(ground - biome.ground) <= 1, `biome {index} centre draws at {ground}`)
		expect.equal(WildValley.zoneAt(valley, biome.centre), index, `biome {index} centre`)
	end
	expect.equal(WildValley.zoneAt(valley, { x = 0, z = 0 }), nil, "the town is no biome")
end,

["the trail turns right into the gorge, then left onto the ridge"] = function()
	-- facing +z, right is -x: in (x, z) a right turn has a positive cross product
	local function turn(a: any, b: any): (number, number)
		local cross = a.x * b.z - a.z * b.x
		local cos = (a.x * b.x + a.z * b.z) / (math.sqrt(a.x ^ 2 + a.z ^ 2) * math.sqrt(b.x ^ 2 + b.z ^ 2))
		return cross, math.deg(math.acos(cos))
	end
	local m, g, r = valley.BIOMES[1].centre, valley.BIOMES[2].centre, valley.BIOMES[3].centre
	local cross1, angle1 = turn({ x = 0, z = 1 }, { x = g.x - m.x, z = g.z - m.z })
	assert(cross1 > 0 and angle1 >= 45, `into the gorge: cross {cross1}, {angle1} degrees`)
	local cross2, angle2 = turn({ x = g.x - m.x, z = g.z - m.z }, { x = r.x - g.x, z = r.z - g.z })
	assert(cross2 < 0 and angle2 >= 45, `onto the ridge: cross {cross2}, {angle2} degrees`)
end,

["the ridge can't be seen from the arrival"] = function()
	local from = valley.TRAIL[1]
	local to = valley.BIOMES[3].centre
	local blocked = false
	for step = 1, 99 do
		local t = step / 100
		local x, z = from.x + (to.x - from.x) * t, from.z + (to.z - from.z) * t
		local sight = (from.y + 5) + ((valley.BIOMES[3].ground + 5) - (from.y + 5)) * t
		local top = TownTerrain.topAt(OPS, x, z)
		blocked = blocked or (top ~= nil and top > sight)
	end
	assert(blocked, "a straight look from the arrival reaches the ridge")
end,

["the trail climbs gently, with no step, and stays inside the edge"] = function()
	local trail = WildValley.trail(valley)
	for index = 2, #trail do
		local a, b = trail[index - 1], trail[index]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local last = TownTerrain.groundAt(OPS, a.x, a.z) :: number
		for step = 1, math.floor(length / 2) do
			local t = step * 2 / length
			local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
			local ground = TownTerrain.groundAt(OPS, x, z) :: number
			assert(math.abs(ground - last) <= 2 * math.tan(math.rad(25)), `a step at {x}, {z}: {last} to {ground}`)
			assert(WildValley.inside(valley.EDGE, { x = x, z = z }), `the trail leaves the edge at {x}, {z}`)
			last = ground
		end
	end
end,

["monsters refuse a step up or down past the limit"] = function()
	expect.equal(WildValley.canStep(0, 1.5, valley.MAX_STEP), true, "a gentle rise")
	expect.equal(WildValley.canStep(15, 0, valley.MAX_STEP), false, "off a shelf")
	expect.equal(WildValley.canStep(0, -5, valley.MAX_STEP), false, "into the stream bed (water is ignored)")
end,

["the edge closes round the biomes, the trail and the arrival; the town is outside"] = function()
	-- every biome's outline pulled 3 studs toward its centre, every trail point and the arrival are inside
	-- (0, 0) and (0, 1000) are outside
end,

["the valley's terrain fits its budget"] = function()
	local cells = TownTerrain.estimatedCells(OPS)
	assert(cells <= valley.MAX_CELLS, `{cells} cells (budget {valley.MAX_CELLS})`)
end,
```

The edge test's body follows the comments exactly: sample the inset outline vertices, every `TRAIL` point and
`TRAIL[1]`, and assert `WildValley.inside` true for those and false for the two outside points.

- [ ] **Step 2: Run them**

Run: `lune run tests/run 2>&1 | tail -20`
Expected: FAIL. The new tests error on `valley.BIOMES` being nil and `WildValley.terrainOps` / `canStep` / `zoneAt`
missing.

- [ ] **Step 3: Write the layout data in `Config/WildValley.luau`.** These values are pinned. Replace round 1's
  `TERRAIN`, `EDGE` and `TRAIL_WIDTH` comment.

```lua
BIOMES = {
	{ centre = { x = -50, z = 1212 }, ground = 0, -- the meadow
		outline = { { x = -190, z = 1104 }, { x = 90, z = 1104 }, { x = 100, z = 1160 }, { x = 95, z = 1290 }, { x = 40, z = 1322 }, { x = -120, z = 1322 }, { x = -205, z = 1290 }, { x = -205, z = 1160 } },
		portal = { x = -150, z = 1300, faces = { x = -165, z = 1262 } }, board = { x = 12, z = 1152 } },
	{ centre = { x = -330, z = 1420 }, ground = 15, -- the gorge
		outline = { { x = -250, z = 1300 }, { x = -330, z = 1290 }, { x = -430, z = 1310 }, { x = -445, z = 1400 }, { x = -440, z = 1500 }, { x = -400, z = 1548 }, { x = -290, z = 1552 }, { x = -220, z = 1530 }, { x = -215, z = 1420 }, { x = -225, z = 1330 } },
		portal = { x = -365, z = 1520, faces = { x = -310, z = 1505 } }, board = { x = -232, z = 1334 } },
	{ centre = { x = -55, z = 1680 }, ground = 35, -- the ridge
		outline = { { x = -215, z = 1575 }, { x = -120, z = 1560 }, { x = 40, z = 1562 }, { x = 100, z = 1600 }, { x = 100, z = 1760 }, { x = 40, z = 1800 }, { x = -140, z = 1800 }, { x = -200, z = 1760 }, { x = -215, z = 1650 } },
		portal = { x = 0, z = 1725, faces = { x = -40, z = 1690 } }, board = { x = -190, z = 1625 } },
},
TRAIL = { -- x, z and the ground's height (y) at each point: meadow, the right turn and climb, gorge, the left turn and climb, ridge
	{ x = 0, z = 1130, y = 0 }, { x = 0, z = 1185, y = 0 }, { x = -60, z = 1235, y = 0 }, { x = -140, z = 1255, y = 0 },
	{ x = -190, z = 1275, y = 0 }, { x = -240, z = 1320, y = 15 }, { x = -310, z = 1390, y = 15 }, { x = -320, z = 1480, y = 15 },
	{ x = -290, z = 1545, y = 15 }, { x = -195, z = 1605, y = 35 }, { x = -120, z = 1650, y = 35 }, { x = -40, z = 1690, y = 35 },
},
TRAIL_WIDTH = 10, MARKER_SPACING = 12, MAX_STEP = 1.5, PORTAL_CLEAR = 30, BOARD_CLEAR = 6,
TRAIL_MATERIAL = { "Ground", "Limestone", "Basalt" },
MAX_CELLS = 90000,
```

`TERRAIN` and `EDGE` are left to you, within these rules:
- `TERRAIN`:
  - each biome's floor drawn at its `ground`: a fill whose top is `ground - 2`, at least 4 studs thick;
  - rolling grass hills in the meadow (buried `Ball`s, tops at most 6 above ground, none on the trail or over a spawn
    area's middle);
  - rock shelves in the gorge;
  - solid cliff faces wherever a higher floor meets lower ground (no slab edge with a void under it);
  - the central mass between the meadow and the ridge topping out at y 45 or more;
  - hills and cliffs all round outside the edge;
  - the ridge's volcanic cone beyond its far edge (terrain, or the `Volcano` prop in Task 2).
- `CARVES`: round 1's stream, pond and bed ops, moved to the new meadow (Task 2 places them), and the cave carve in
  the gorge's west cliff at about (-445, 1420), base y 15.
- `EDGE`: the walkable polygon (the biomes, the two pass corridors along the trail, at least 24 studs wide, and a notch
  into the cave mouth).

- [ ] **Step 4: Implement** `trail`, `zoneAt`, `clearOf`, `terrainOps` and `canStep` in `Util/WildValley.luau`, and
  export `TownTerrain.trailSegment`:
  - `trailSegment` is the existing local function, unchanged; rename its call site in `TownTerrain.ops`.
  - Remove `zoneSign` and `arenaCenter`, and their uses in `WildService` and the tests.
  - `clearOf` keeps its stream and pond checks from round 1. `segmentDistance` stays local.

- [ ] **Step 5: Wire the ground.**
  - **SceneryService:** in `SceneryService.Start`, append `WildValley.terrainOps(WildValleyConfig, TownTerrain.trailSegment)`
    in place of the `WildValleyConfig.TERRAIN` loop.
  - **`buildMap`:** in `VALLEY`, skip the zone floor and path parts and round 1's `zoneSign` boards. The zone boards
    come back in Task 4.
  - **`Start`:** in `VALLEY`, set `rayParams.FilterDescendantsInstances = { mapFolder, workspace.Terrain }` and
    `rayParams.IgnoreWater = true`.
  - **`moveToward`:** in `VALLEY`, when the new ground fails `WildValley.canStep(position.Y, nextPosition.Y,
    WildValleyConfig.MAX_STEP)`, end the move: clear `wanderTarget` and return true, so the monster picks a new target.
  - **`SpawnAt`:** in `VALLEY`, take its zone from `WildValley.zoneAt`, else the nearest `BIOMES[i].centre`.
  - Until Task 3, the valley's spawn spots are `MONSTERS_PER_ZONE` points on a ring of radius 30 round
    `BIOMES[i].centre`, at `TownTerrain.groundAt` + 0.5. The old grid's centres now fall in the central mass. Task 3
    replaces these spots.

- [ ] **Step 6: Run the tests and the build**

Run: `lune run tests/run 2>&1 | tail -5` and `rojo build -o "$TEMP/test.rbxl"`
Expected: all pass (round 1's coordinate tests were deleted in Step 1). Build OK.

- [ ] **Step 7: Play check.** Run `/wild`, then walk the trail with `character_navigation` along the `TRAIL` points.
  Screenshot:
  - the arrival looking down the meadow;
  - bend 1;
  - the gorge from its entrance;
  - bend 2;
  - the ridge.

  Check that monsters stand on the hills (no floating or sinking) and that Output is clean.

- [ ] **Step 8: Commit**

```bash
git add src/shared/Config/WildValley.luau src/shared/Util/WildValley.luau src/shared/Util/TownTerrain.luau src/server/Services/SceneryService.luau src/server/Services/WildService.luau tests/WildValley.spec.luau
git commit -m "Wild valley 2: the winding valley's ground (S trail, three heights, monsters on terrain)"
```

### Task 2: Round 1's moods moved onto the new ground

**Files:**
- Modify: `src/shared/Config/WildValley.luau`:
  - `PROPS`, `CRYSTALS`, `CHARRED`, `SHARDS`, `VENTS`, `STREAM`, `BRIDGE`, `CAVE` (new `y`), `RIDGE_CRACKS.FLOOR`,
    `ARRIVAL_CLEAR`;
  - remove `SIGN_WIDTH`, `ARCH_HALF_WIDTH`, `ZONE_SIGN_X`, which Task 4 replaces.
- Modify: `src/shared/Config/Scenery.luau`: the five `Wild*` entries in `EMITTERS` (positions and `y` on the new
  ground).
- Modify: `src/server/Services/SceneryService.luau`: every valley piece stands on `TownTerrain.groundAt(terrainOps, x,
  z)` instead of y 0:
  - `buildBridge`: the bank's ground;
  - `buildTrailMarkers`: each marker's ground, plus 0.12;
  - `buildCrystalCluster`, `buildVent`;
  - `buildCave`: its ray at `CAVE.y + CAVE.height / 2`.
- Test: `tests/WildValley.spec.luau`.

**Interfaces:**
- Consumes: Task 1's `BIOMES`, `TRAIL`, `EDGE`, `clearOf`, `terrainOps`, `zoneAt`.
- Produces: `CAVE = { x, y, z, width, height, inside, light }`. `STREAM` and `BRIDGE` keep their shapes. The bridge
  still runs along z, on the `TRAIL[1]`→`TRAIL[2]` segment.

- [ ] **Step 1: Write the failing tests**, replacing round 1's prop and cave tests:

```lua
["props stay off the trail, the stream, the portals, the boards and the arrival, in their own biome"] = function()
	for _, prop in allProps() do
		local ok, why = WildValley.clearOf(prop, valley)
		assert(ok, `{prop.model or "prop"} at {prop.x}, {prop.z}: {why}`)
	end
	for _, list in { { valley.CRYSTALS, 2 }, { valley.CHARRED, 3 }, { valley.SHARDS, 3 }, { valley.VENTS, 3 } } do
		for _, prop in list[1] do
			expect.equal(WildValley.zoneAt(valley, prop), list[2], `{prop.x}, {prop.z} dresses biome {list[2]}`)
		end
	end
end,

["the bridge carries the trail over the stream"] = function()
	local s, b = valley.STREAM, valley.BRIDGE
	-- the bridge's middle is on the trail and on the stream's line (within half the stream's width)
end,

["the edge lets players into the cave mouth but not past its carve"] = function()
	-- a point 4 studs into the mouth (from the cliff face toward CAVE.x - CAVE.width) is inside the edge; a point past
	-- the carve's back is outside; the carve op in CARVES is centred on the notch
end,

["the valley's effects stand in their biomes, at most 4 a biome"] = function()
	local scenery = require("../src/shared/Config/Scenery")
	local count = {}
	for _, e in scenery.EMITTERS do
		local biome = ({ WildMeadow = 1, WildGorge = 2, WildRidge = 3 })[e.area]
		if biome then
			count[biome] = (count[biome] or 0) + 1
			expect.equal(WildValley.zoneAt(valley, e), biome, `{e.kind} at {e.x}, {e.z}`)
			assert(math.abs(e.y - valley.BIOMES[biome].ground) <= 30, `{e.kind} floats at {e.y}`)
		end
	end
	for biome, n in count do
		assert(n <= 4, `biome {biome} has {n} effects`)
	end
end,
```

The two commented bodies follow their comments:
- **Bridge:** distance from `(BRIDGE.x, BRIDGE.z)` to the `TRAIL[1]`-`TRAIL[2]` segment is at most 0.5. Distance to
  the `STREAM.from`-`STREAM.to` line is at most `STREAM.width / 2`.
- **Cave:** as round 1's test, with the new coordinates.

- [ ] **Step 2: Run them**

Run: `lune run tests/run 2>&1 | tail -20`
Expected: FAIL on round 1's coordinates (props in the old biomes, the bridge off the new trail).

- [ ] **Step 3: Move the dressing in config.**
  - **Where things go:**
    - the stream from the meadow's east hills across `TRAIL[1]`-`TRAIL[2]` (the bridge at about (0, 1170)) to a pond
      west of the trail;
    - the meadow's trees, bushes and flowers spread over its larger ground;
    - the gorge's rocks and crystals, with a cluster at the cave's lip;
    - the ridge's charred trees, shards and vents;
    - `RIDGE_CRACKS.FLOOR` covering the ridge;
    - the volcano: `{ model = "Volcano", ... }` in `PROPS` beyond the ridge's far edge, or terrain from Task 1.
  - **Moods and density:** keep round 1's (a bigger valley gets more props; roughly double each list).
  - **Arrival:** update `ARRIVAL_CLEAR` if the arrival's surroundings changed.

- [ ] **Step 4: Ground-follow the pieces** in `SceneryService` as listed under Files. Use one local helper,
  `local function groundAt(x: number, z: number): number`, returning `TownTerrain.groundAt(terrainOps, x, z) or 0`.

- [ ] **Step 5: Run the tests**

Run: `lune run tests/run 2>&1 | tail -5`
Expected: all pass.

- [ ] **Step 6: Play check.** Screenshot each biome from the trail and from above, the bridge, the cave mouth (walk
  in) and the ridge with its cracks and vents. Check that nothing floats or is buried and that Output is clean.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/WildValley.luau src/shared/Config/Scenery.luau src/server/Services/SceneryService.luau tests/WildValley.spec.luau
git commit -m "Wild valley 2: the meadow, gorge and ridge dressed on the new ground"
```

### Task 3: Monsters by crowd

**Files:**
- Create: `src/shared/Util/WildPopulation.luau` (pure).
- Create: `tests/WildPopulation.spec.luau`, registered in `tests/run.luau`.
- Modify: `src/shared/Config/WildValley.luau`:
  - `POPULATION = { QUIET = 8, PER_PLAYER = 2, FREE_PLAYERS = 3, MAX = 24, RESPAWN_QUIET = { 20, 40 }, RESPAWN_BUSY = { 10, 20 }, CHECK_SECONDS = 2 }`;
  - `SPOT_SPACING = 18`, `SPOT_MARGIN = 20`, `SPOT_PROP_CLEAR = 6`.
- Modify: `src/shared/Util/WildValley.luau`: `zoneSpots`.
- Modify: `src/server/Services/DevService.luau`: a Studio-only `/crowd <0-60>` that sets phantom players added to
  every biome's count (`WildService.SetPhantomPlayers(count: number)`), so a crowd can be tested alone.
- Modify: `src/server/Services/WildService.luau`. In `VALLEY`:
  - `buildMap` makes `POPULATION.MAX` tagged spot parts per biome from `zoneSpots`, each at
    `TownTerrain.groundAt(ops, x, z) + 0.5`;
  - `Start` fills `QUIET` per biome at once, then a loop every `CHECK_SECONDS` schedules the deficit;
  - `Defeat` doesn't respawn valley spots (the loop does).
- Test: `tests/WildPopulation.spec.luau`, `tests/WildValley.spec.luau`.

**Interfaces:**
- Produces, in `Util/WildPopulation`:
  - `WildPopulation.target(cfg: any, players: number): number`;
  - `WildPopulation.respawnRange(cfg: any, target: number): { number }`: `RESPAWN_BUSY` when `target > QUIET`, else
    `RESPAWN_QUIET`;
  - `WildPopulation.deficit(target: number, alive: number, pending: number): number`: `max(0, target - alive - pending)`;
  - `WildPopulation.freeSpots(total: number, taken: { [number]: boolean }): { number }`: the spot indexes not taken,
    ascending.
- Produces, in `Util/WildValley`: `WildValley.zoneSpots(valley: any, index: number): { Point }`. It walks a grid
  `SPOT_SPACING` apart over the outline's bounds, in a fixed order (z, then x). It keeps points that are:
  - inside the outline and at least `SPOT_MARGIN` from every outline edge;
  - `clearOf`;
  - at least `SPOT_PROP_CLEAR` from every prop.

  It then returns `POPULATION.MAX` of them spread evenly: `candidates[math.floor((k - 1) * #candidates / MAX) + 1]`.

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/WildPopulation.spec.luau
local valley = require("../src/shared/Config/WildValley")
local WildPopulation = require("../src/shared/Util/WildPopulation")
local expect = require("./lib/expect")
local cfg = valley.POPULATION
return {
	["a quiet zone keeps 8 monsters"] = function()
		for players = 0, 3 do
			expect.equal(WildPopulation.target(cfg, players), 8, `{players} players`)
		end
	end,
	["each player past 3 adds 2, up to 24"] = function()
		expect.equal(WildPopulation.target(cfg, 4), 10, "4 players")
		expect.equal(WildPopulation.target(cfg, 5), 12, "5 players")
		expect.equal(WildPopulation.target(cfg, 11), 24, "11 players")
		expect.equal(WildPopulation.target(cfg, 60), 24, "a full server")
	end,
	["respawns are quicker while busy"] = function()
		local quiet, busy = WildPopulation.respawnRange(cfg, 8), WildPopulation.respawnRange(cfg, 10)
		expect.equal(quiet[1], 20, "quiet min"); expect.equal(quiet[2], 40, "quiet max")
		expect.equal(busy[1], 10, "busy min"); expect.equal(busy[2], 20, "busy max")
	end,
	["only the missing monsters are scheduled; extras are never removed"] = function()
		expect.equal(WildPopulation.deficit(12, 8, 2), 2, "two more")
		expect.equal(WildPopulation.deficit(8, 12, 0), 0, "a crowd left: nothing removed")
	end,
	["free spots skip the taken ones"] = function()
		local free = WildPopulation.freeSpots(5, { [2] = true, [4] = true })
		expect.equal(#free, 3, "three free"); expect.equal(free[1], 1, "first"); expect.equal(free[3], 5, "last")
	end,
}
```

```lua
-- tests/WildValley.spec.luau
["every biome has 24 spawn spots well inside it, clear, on gentle ground"] = function()
	for index, biome in valley.BIOMES do
		local spots = WildValley.zoneSpots(valley, index)
		expect.equal(#spots, valley.POPULATION.MAX, `biome {index} spots`)
		for _, p in spots do
			expect.equal(WildValley.zoneAt(valley, p), index, `{p.x}, {p.z} in biome {index}`)
			assert(WildValley.clearOf(p, valley), `{p.x}, {p.z} isn't clear`)
			local here = TownTerrain.groundAt(OPS, p.x, p.z) :: number
			assert(math.abs(here - biome.ground) <= 6, `{p.x}, {p.z} draws at {here}`)
			for _, d in { { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
				local there = TownTerrain.groundAt(OPS, p.x + d[1], p.z + d[2]) :: number
				assert(math.abs(there - here) <= 2, `steep ground at {p.x}, {p.z}`)
			end
		end
	end
end,
```

- [ ] **Step 2: Run them**

Run: `lune run tests/run 2>&1 | tail -20`
Expected: FAIL. `WildPopulation` doesn't exist, and `zoneSpots` is nil.

- [ ] **Step 3: Implement** `WildPopulation` and `zoneSpots`, and add `POPULATION` and the spot numbers to config.
  `target` is `math.clamp(QUIET + PER_PLAYER * math.max(0, players - FREE_PLAYERS), QUIET, MAX)`.

- [ ] **Step 4: Run the tests**

Run: `lune run tests/run 2>&1 | tail -5`
Expected: all pass.

- [ ] **Step 5: Wire the loop in `WildService`.**
  - **Counting players:** each check counts, per biome, the players in `inWild` whose root is inside that biome's
    outline (`WildValley.zoneAt`).
  - **Scheduling:** it computes `target` and `deficit` against the zone's live spot monsters plus those still
    pending. It schedules each missing one with `task.delay(rng:NextNumber(range[1], range[2]), ...)` onto a random
    free spot (`freeSpots` against the spots held by living monsters), checking the spot is still free when the delay
    ends.
  - **Frontier:** keeps `MONSTERS_PER_ZONE` and today's per-spot respawn.

- [ ] **Step 6: Play check.**
  - **Quiet:** count `workspace.Monsters` per zone at start (8 each).
  - **Crowded:** `/crowd 11`. Confirm each zone climbs to 24 with 10-20 s respawns. Screenshot a crowded meadow.
  - **Extras:** `/crowd 0`. Confirm the extras stay until beaten and aren't respawned.
  - **Output:** clean.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Util/WildPopulation.luau tests/WildPopulation.spec.luau tests/run.luau src/shared/Config/WildValley.luau src/shared/Util/WildValley.luau src/server/Services/WildService.luau src/server/Services/DevService.luau tests/WildValley.spec.luau
git commit -m "Wild valley 2: monsters grow with the players in a zone (8 quiet, up to 24)"
```

### Task 4: Wooden trailhead signs

**Files:**
- Modify: `src/server/Util/TrailProps.luau`: new `TrailProps.trailhead`.
- Modify: `src/shared/Config/WildValley.luau`:
  - `RETURN_SIGN = { x, z, yaw }`, beside the root arch and clear of its legs;
  - `ARROWS = { { x, z, arms = { { text, toward = Point } } } }`: one post at bend 1 and one at bend 2, each with the
    next biome's name and "THE WILD" pointing back.
- Modify: `src/server/Services/WildService.luau`. In `VALLEY`, the plain `sign()` boards are replaced:
  - "The Wild" becomes a trailhead at `RETURN_SIGN`;
  - each biome gets a trailhead at `BIOMES[i].board` reading `string.upper(zone.name)` and
    `` `Lv {zone.minLevel}-{zone.maxLevel}` ``;
  - the arrow posts come from `TrailProps.signpost`, with arm yaw from `PortalTrails.armYaw(post, arm.toward)`, arm
    colour from the zone's `Wild.ZONES[i].color`, and sub `Town.SIGN_SUBTEXT`.

  Every piece stands on `TownTerrain.groundAt(ops, x, z)`. The Frontier keeps `sign()`.
- Test: `tests/WildValley.spec.luau`.

**Interfaces:**
- Produces: `TrailProps.trailhead(parent: Instance, at: CFrame, title: string, sub: string?): Model`:
  - two log posts and a crossbar;
  - a plank board hanging under the crossbar;
  - words on both faces through the existing `words`;
  - wood colours `POST_COLOR` and `BOARD_COLOR`.

  The boss portal board in Task 5 uses it.

- [ ] **Step 1: Write the failing test**

```lua
["the boards and arrow posts stand beside the trail, not on it, inside the edge"] = function()
	local spots = { valley.RETURN_SIGN }
	for _, biome in valley.BIOMES do
		table.insert(spots, biome.board)
	end
	for _, post in valley.ARROWS do
		table.insert(spots, post)
		assert(#post.arms >= 2, "an arrow post names the way on and the way back")
	end
	for _, s in spots do
		local nearest = math.huge
		local trail = WildValley.trail(valley)
		for i = 2, #trail do
			nearest = math.min(nearest, distanceToSegment(s, trail[i - 1], trail[i]))
		end
		assert(nearest >= valley.TRAIL_WIDTH / 2 + 2 and nearest <= 20, `{s.x}, {s.z} is {nearest} from the trail`)
		assert(WildValley.inside(valley.EDGE, s), `{s.x}, {s.z} is outside the edge`)
		assert(distanceToSegment(s, valley.STREAM.from, valley.STREAM.to) >= valley.STREAM.width / 2 + 3, `{s.x}, {s.z} stands in the stream`)
	end
end,
```

`distanceToSegment` is a local helper in the spec file, the same maths as `Util/WildValley`'s `segmentDistance`.

- [ ] **Step 2: Run it**

Run: `lune run tests/run 2>&1 | tail -10`
Expected: FAIL. `valley.ARROWS` is nil, and `RETURN_SIGN` lacks the new shape.

- [ ] **Step 3: Add the config and `TrailProps.trailhead`, and build the signs in `WildService` as listed under
  Files.**

- [ ] **Step 4: Run the tests**

Run: `lune run tests/run 2>&1 | tail -5`
Expected: all pass.

- [ ] **Step 5: Play check.** Screenshot, from the side players approach:
  - "The Wild" beside the arch;
  - each biome's board;
  - both arrow posts.

  Check that the words read, nothing clips the arch or the trail, and Output is clean.

- [ ] **Step 6: Commit**

```bash
git add src/server/Util/TrailProps.luau src/shared/Config/WildValley.luau src/server/Services/WildService.luau tests/WildValley.spec.luau
git commit -m "Wild valley 2: wooden trailhead boards and arrow posts like the town's"
```

### Task 5: Boss portals and arena copies

**Files:**
- Modify: `src/shared/Config/Bosses.luau`: `ARENA_COPIES = 4`, `ARENA_LINGER = 60` (seconds after a remote copy's
  fight ends before anyone left is sent back).
- Modify: `src/shared/Config/WildValley.luau`:
  - `ARENA_FIELD = { x = 1600, z = 1200, y = 0, spacing = 1200 }`;
  - `ARENA_CLEARING = { size = 124, ring = 62, materials = { "Grass", "Limestone", "Basalt" }, props = { { "TreeA", "TreeB", "PineA" }, { "RockA", "RockB", "RockD" }, { "CharredTree", "RockD" } }, count = 12, height = { 16, 22 } }`.
    Terrain Slate is Frostpeak's ice blue across the whole map, so the gorge's clearing is Limestone;
  - `BOSS_PORTAL = { model = "PortalArena", height = 20 }`.
- Modify: `src/shared/Config/Town.luau`: `PORTAL_LOOKS.Boss`. Copy `PORTAL_LOOKS.Arena` with:
  - vortex `colors = { { 150, 70, 255 }, { 230, 130, 255 } }`, `core = { 70, 20, 150 }`;
  - light `{ 190, 140, 255 }`;
  - no lava glow;
  - the effects' colours purple.
- Modify: `src/shared/Util/WildValley.luau`:
  - `arenaCopyCenter(valley, zone, copy): Point`;
  - `arenaClearingOps(valley, zone, copy): { any }`: one ground `Block` `size` wide drawing at `ARENA_FIELD.y` in
    `ARENA_CLEARING.materials[zone]`;
  - `terrainOps` appends the clearings for zones 1-3 and copies `1..ARENA_COPIES`. `ARENA_COPIES` is passed in as
    `valley.ARENA_COPIES_FOR_TERRAIN = 4`, a plain number mirrored from Bosses and tested equal.
- Modify: `src/shared/Util/BossRules.luau`: `copyFree`, `pickCopy`, `soloBlockedByLobby`, `stillInCopy`.
- Modify: `src/server/Services/WildService.luau`:
  - **Types:** `BossArena = { gate: CFrame, gatePosition: Vector3, groupPrompt: ProximityPrompt, copies: { ArenaCopy } }`
    and `ArenaCopy = { spawn: CFrame, barrier: { BasePart }, inside: CFrame, center: Vector3, exit: CFrame, remote: boolean }`.
  - **`BuildBossArenas(onGate, onGroup, onReturn)`:**
    - in `VALLEY`: the boss portal (model, `PortalBuild.dress` with `Town.PORTAL_LOOKS.Boss`, the Fight and group
      prompts on its opening's part, a `TrailProps.trailhead` board `boss.name` / `` `Power {boss.recommended}` ``)
      at `BIOMES[boss.zone].portal`, facing `faces`, on the modelled ground;
    - in `VALLEY`: plus `ARENA_COPIES` rings (round 1's ring code, looks and cracks) at `arenaCopyCenter`, each with a
      `PortalWild` return portal outside its gate whose "Return" prompt calls `onReturn(player, bossId, copyIndex)`,
      and `ARENA_CLEARING.count` props round it;
    - elsewhere: one copy at today's ring (`remote = false`, `exit = gate`).
  - **New:** `WildService.MoveInWild(player: Player, cframe: CFrame): boolean` (streams, pivots, keeps `inWild`) and
    `WildService.Prestream(player: Player, position: Vector3)` (the `RequestStreamAroundAsync` part, yields).
  - **`SpawnAt`:** gets an optional `zone: number?` (bosses pass `boss.zone`).
  - **`rescueFallen`:** unchanged. The copies sit at y 0, so a fall there returns the player to the valley's entrance.
- Modify: `src/server/Services/BossService.luau`:
  - `occupants[bossId][copy]` and `members[bossId][copy]`;
  - `whyArenaBusy`: no free copy gives `` `All the {boss.name}'s arenas are busy. Try again in a moment.` ``. A
    forming group blocks solo fights only when `BossRules.soloBlockedByLobby(#copies)`;
  - `onGate` and `closeLobby` go through `enterCopy(bossId, players)`:
    - reserve a free copy (its members set);
    - for a remote copy, `Prestream` every player in parallel, waiting at most `Wild.STREAM_TIMEOUT`;
    - re-check each with `whyNotMember`;
    - release the copy if nobody is left;
    - otherwise `startBoss(bossId, ready, copyIndex, options)`, with no yields;
  - `dropLoot` uses the copy that held the boss;
  - `OnFightEnded` unseals that copy and, if remote, after `ARENA_LINGER` sends back every member still in it:
    `collectAll(player)`, then `MoveInWild(exit)`;
  - `onReturn` does the same at once, for a member whose fight is over;
  - `OnMemberLeft` on a remote copy: `MoveInWild(exit)`;
  - members are pruned with `stillInCopy`;
  - `StartRun` (Dungeon) and the Frontier keep their single copy.
- Test: `tests/BossRules.spec.luau`, `tests/WildValley.spec.luau`.

**Interfaces:**
- Consumes:
  - Task 1's `BIOMES[i].portal`, `terrainOps`, `clearOf`;
  - Task 3's spot clearance from portals (`PORTAL_CLEAR`);
  - Task 4's `TrailProps.trailhead`.
- Produces, in `BossRules`:
  - `BossRules.copyFree(occupant: { alive: boolean }?, members: number): boolean`: `(occupant == nil or not
    occupant.alive) and members == 0`;
  - `BossRules.pickCopy(free: { boolean }): number?`: the first true index;
  - `BossRules.soloBlockedByLobby(copies: number): boolean`: `copies <= 1`;
  - `BossRules.stillInCopy(inGame: boolean, distance: number, radius: number): boolean`: `inGame and distance <=
    radius + 30`.
- Produces, in `WildValley`: `WildValley.arenaCopyCenter(valley: any, zone: number, copy: number): Point`:
  `{ x = field.x + (copy - 1) * field.spacing, z = field.z + (zone - 1) * field.spacing }`.

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/BossRules.spec.luau
["a remote arena copy is free once its boss is gone and its fighters have left"] = function()
	expect.equal(BossRules.copyFree(nil, 0), true, "never used")
	expect.equal(BossRules.copyFree({ alive = true }, 0), false, "a fight on")
	expect.equal(BossRules.copyFree({ alive = false }, 2), false, "fighters still picking up loot")
	expect.equal(BossRules.copyFree({ alive = false }, 0), true, "done and empty")
end,
["the first free copy is picked; none when all are busy"] = function()
	expect.equal(BossRules.pickCopy({ false, true, true, false }), 2, "copy 2")
	expect.equal(BossRules.pickCopy({ false, false, false, false }), nil, "all busy")
end,
["a forming group blocks solo fights only where there's a single arena"] = function()
	expect.equal(BossRules.soloBlockedByLobby(1), true, "the Frontier's ring")
	expect.equal(BossRules.soloBlockedByLobby(4), false, "the valley's copies")
end,
["someone who left the game or the copy no longer holds it"] = function()
	expect.equal(BossRules.stillInCopy(true, 20, 36), true, "inside")
	expect.equal(BossRules.stillInCopy(false, 0, 36), false, "left the game")
	expect.equal(BossRules.stillInCopy(true, 500, 36), false, "respawned at their shop")
end,
```

```lua
-- tests/WildValley.spec.luau
["arena copies stand apart, far from the valley, each on its clearing"] = function()
	local bosses = require("../src/shared/Config/Bosses")
	expect.equal(valley.ARENA_COPIES_FOR_TERRAIN, bosses.ARENA_COPIES, "terrain and Bosses agree")
	local centres = {}
	for zone = 1, 3 do
		for copy = 1, bosses.ARENA_COPIES do
			local c = WildValley.arenaCopyCenter(valley, zone, copy)
			for _, other in centres do
				assert(math.sqrt((c.x - other.x) ^ 2 + (c.z - other.z) ^ 2) >= valley.ARENA_FIELD.spacing, "two copies too close")
			end
			assert(not WildValley.inside(valley.EDGE, c) and c.x - 100 >= 1000, `copy {zone}/{copy} near the valley`)
			local ground = TownTerrain.groundAt(OPS, c.x, c.z)
			assert(ground and math.abs(ground - valley.ARENA_FIELD.y) <= 0.01, `copy {zone}/{copy} has no ground`)
			table.insert(centres, c)
		end
	end
end,
["each boss portal stands beside its biome's trail on gentle ground, its gate spot inside the edge"] = function()
	for index, biome in valley.BIOMES do
		local p = biome.portal
		expect.equal(WildValley.zoneAt(valley, p), index, `portal {index} in its biome`)
		local here = TownTerrain.groundAt(OPS, p.x, p.z) :: number
		assert(math.abs(here - biome.ground) <= 3, `portal {index} draws at {here}`)
		-- the gate spot (8 studs in front, toward `faces`) is inside the edge and within 1.5 studs of the portal's ground
	end
end,
```

The commented line in the second test is part of the assertions: compute the spot 8 studs from `p` toward `faces`,
then assert `WildValley.inside(valley.EDGE, spot)` and `math.abs(groundAt(spot) - here) <= 1.5`.

- [ ] **Step 2: Run them**

Run: `lune run tests/run 2>&1 | tail -20`
Expected: FAIL. The new `BossRules` functions, `arenaCopyCenter`, `ARENA_FIELD` and `ARENA_COPIES` don't exist yet.

- [ ] **Step 3: Implement the pure pieces and config** (`BossRules`, `arenaCopyCenter`, `arenaClearingOps`,
  `terrainOps` appending the clearings, `Bosses`, `Town.PORTAL_LOOKS.Boss`).

- [ ] **Step 4: Run the tests**

Run: `lune run tests/run 2>&1 | tail -5`
Expected: all pass, `estimatedCells` still within `MAX_CELLS` 90000.

- [ ] **Step 5: Build the portals and copies in `WildService`, and the copy flow in `BossService`,** as listed under
  Files. The gate CFrame is 8 studs in front of the portal toward `faces`, on the modelled ground, looking at the
  portal. `/boss n`, "Take me there" and the Admin Go button use it through `BossService.GetGate`.

- [ ] **Step 6: Play check** (Local Server with 2 players for the group cases):
  - **Solo:** `/boss 1` then `/boss 1 fight`: moved into a copy, barrier up, the fight runs. Win (`/maxcard` for a
    strong card): loot drops; the Return prompt brings you back to the portal with the loot collected. Lose: back
    after `ARENA_LINGER`.
  - **Copies:** a second player fights the same boss at once and gets another copy. The all-busy message is pinned by
    the `pickCopy` test.
  - **No void:** from inside each look's ring at eye height, turn a full circle. No void or world edge shows.
  - **Group:** opens at the portal; a solo fight at the same portal still starts.
  - **Leaving:** leaving the game mid-fight frees the copy.
  - **Screenshots:** the three boss portals with their boards, an arena copy of each look, the return.
  - **Output:** clean.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Bosses.luau src/shared/Config/WildValley.luau src/shared/Config/Town.luau src/shared/Util/WildValley.luau src/shared/Util/BossRules.luau src/server/Services/WildService.luau src/server/Services/BossService.luau tests/BossRules.spec.luau tests/WildValley.spec.luau
git commit -m "Wild valley 2: boss portals send each fight to its own arena copy"
```

### Task 6: Measure, raise the budget, document

**Files:**
- Modify: `src/shared/Config/Scenery.luau`: `MAX_CELLS`, only if the measurement allows it.
- Modify: `tests/WildValley.spec.luau`: the town-plus-valley cap check (round 1's, rewritten on `OPS`).
- Modify: `DESIGN.md`:
  - the Wild valley paragraph (round 2: layout, heights, portals and copies, population, signs);
  - 10.5's Wild valley measurement;
  - the file tree lines for `Util/WildPopulation`, `Util/WildValley`, `Config/WildValley`, `TrailProps`;
  - the backlog item `- [ ] Wild valley` covering both rounds.
- Modify: `CLAUDE.md`: `/boss` now goes "to boss n's portal"; the dev commands gain `/crowd <0-60>`; the
  `tests/run` list gains `WildPopulation`.
- Modify: `docs/props.md`: the boss portal reuses `PortalArena` with the `Boss` look.

- [ ] **Step 1: Write the failing test**

```lua
["town and valley terrain fit the measured budget"] = function()
	local scenery = require("../src/shared/Config/Scenery")
	local town = require("../src/shared/Config/Town")
	local TownLayout = require("../src/shared/Util/TownLayout")
	local plots = TownLayout.plotRects({ plotCount = 6, perRow = 3, plotWidth = 40, plotDepth = 40, gap = 24, streetWidth = 96 } :: any)
	local townCells = TownTerrain.estimatedCells(TownTerrain.ops(scenery, town, plots))
	local cells = TownTerrain.estimatedCells(OPS)
	assert(townCells + cells <= scenery.MAX_CELLS, `town {townCells} + valley {cells} cells over {scenery.MAX_CELLS}`)
end,
```

- [ ] **Step 2: Run it**

Run: `lune run tests/run 2>&1 | tail -10`
Expected: FAIL while `Scenery.MAX_CELLS` is 180000 (town about 139k plus the new valley).

- [ ] **Step 3: Measure** in Play, with DESIGN 10.5's method:
  - **Cameras:** fixed at the arrival, each bend, each biome's busiest view, a boss portal and an arena copy.
  - **Each camera:** levels 1 and 10, render CPU frame time, fps, and `GraphicsTerrain` / `TerrainVoxels` memory.
  - **Comparison:** the same on the town street and against round 1's numbers in DESIGN 10.5 (43 MB graphics and
    3.9 MB voxels in the valley; 51 / 4.1 on the street).
  - **Crowd:** a crowded meadow (24 monsters).
  - **If fps or memory miss:** cut terrain (the outer hills' depth, the central mass's thickness, then the clearings)
    before raising anything. Ledger the ruling.

- [ ] **Step 4: Raise `Scenery.MAX_CELLS`** to the smallest round 10000 above town plus valley, with a comment naming
  the measurement.

- [ ] **Step 5: Run the tests and the build**

Run: `lune run tests/run 2>&1 | tail -5` and `rojo build -o "$TEMP/test.rbxl"`
Expected: all pass. Build OK.

- [ ] **Step 6: Update DESIGN.md, CLAUDE.md and `docs/props.md`** as listed. Then build the screenshot page for the
  user in the brainstorm companion: the arrival, both bends, each biome, the boards, a boss portal, an arena copy,
  the return, a crowded meadow, and the perf line.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Scenery.luau tests/WildValley.spec.luau DESIGN.md CLAUDE.md docs/props.md
git commit -m "Wild valley 2: measured terrain budget, docs"
```
