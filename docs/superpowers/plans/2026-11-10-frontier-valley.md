# The Frontier valley: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Frontier becomes a valley like the Wild's, darker and more dangerous: one trail through Frostwood,
Stormpeak and the Rift, no walls, its own scenery, skies, effects, music, loading screen, boss portals with arenas, the
Dungeon portal at the farthest point, and new Meshy models for its 6 monsters and 3 bosses.

**Architecture:** One valley engine, two valleys. `Util/Place.getValley()` returns the place's valley config
(`Config/WildValley` in the main game, the new `Config/FrontierValley` in the Frontier, nil in the Dungeon), and every
reader of `Config/WildValley` (WildService, SceneryService, BossService, DayCycleController, MusicController, the
loading screens) reads that instead. `Util/WildValley` already takes the config as an argument; its Wild-only keys
(stream, stone circle, mushroom rings, cave, volcano, vents, ridge cracks, bridge) become optional, and the Frontier's
own pieces are new optional keys. The Frontier place starts the valley's builders (SceneryService's valley half, the
music, the sky) that today run only in the main game.

**Tech stack:** Luau, Rojo, Lune tests (`lune run tests/run`), Blender 5.2 through the Blender MCP (props, Meshy
models, rigs, clips), the Roblox Studio MCP for checks.

**Spec:** docs/superpowers/specs/2026-11-10-frontier-valley-design.md

## Global constraints

- The Wild must not change: its config keeps its numbers and every existing test keeps passing.
- No walls: areas close with terrain, banks, trees, rocks and the crater rim (the Wild's invisible edge walls stay).
- Nothing hurts outside a fight: lightning and tremors are light, sound and a small camera shake only.
- Frostwood calm, Stormpeak as now (elites already chase everywhere), the Rift all chases (as now).
- Frontier monsters drawn 30% bigger than the Wild's: `Frontier.MONSTER_HEIGHT` 3.9 (Wild 3).
- Fight numbers unchanged (Config/Bosses, Frontier SPECIES stats).
- Heights: Frostwood ground 0, Stormpeak about 40, the Rift's floor about -15 (a drop from the plateau).
- The terrain budget: `FrontierValley.MAX_CELLS` at most 105000 (the Wild valley's).
- Meshy: read the balance first (number only), about 270 credits for 9 generations, ask before any regeneration.
- Concepts and raw Meshy files stay out of git (`concept_*.png`, `*_raw.glb`; delete `*_Src` and purge orphans before
  saving a .blend).
- Text plain ASCII plus `·` and emoji; every remote validated and rate-limited (no new remote is expected).
- Studio: ask before changing the place itself; scripts live only in the repo.

## Review focus

1. The main game's Wild valley builds exactly as before (same terrain ops, same props, same sky and music).
2. The Dungeon place has no valley: nothing valley-related runs there and it boots as today.
3. Arriving in the Frontier never drops you through unfilled terrain: arrival waits for the Frontier's terrain flag,
   as the Wild does.
4. A lost fight sends you to the spring in the camp, and the camp has no spawn spots or scenery in the way.
5. Group boss fights: each Frontier boss has `Bosses.ARENA_COPIES` arena copies, apart from each other and far from
   the valley, and `/boss 4-6` reaches each boss's portal.

## Files

- Create: `src/shared/Config/FrontierValley.luau` (the Frontier's valley: same shape as WildValley's shared keys,
  plus CAMP, FX and its own lists), `src/client/Controllers/FrontierFxController.luau` (snow, fog eyes, lightning,
  tornado, vortex, floating rocks, tremors), `src/shared/Util/FrontierFxRules.luau` (pure: eye fade, flash timing,
  tremor shake), `tests/FrontierValley.spec.luau`, `tests/FrontierFxRules.spec.luau`,
  `tools/blender/build_frontier_props.py`, `tools/blender/rig_<species>.py` x6, `rig_<boss>.py` x3,
  `anim_<boss>.py` x3.
- Modify: `src/shared/Util/Place.luau`, `src/shared/Util/WildValley.luau`, `src/server/Services/WildService.luau`,
  `src/server/Services/SceneryService.luau`, `src/server/Services/BossService.luau`,
  `src/server/Services/DevService.luau`, `src/server/Services/DungeonGateService.luau`, `src/server/init.server.luau`,
  `src/client/init.client.luau`, `src/client/Controllers/DayCycleController.luau`,
  `src/client/Controllers/MusicController.luau`, `src/client/Controllers/LoadingController.luau`,
  `src/client/Controllers/FrontierController.luau`, `src/first/LoadingGui.luau`, `src/first/Show.client.luau`,
  `src/shared/Util/MusicRules.luau`, `src/shared/Util/LoadingRules.luau`, `src/shared/Config/Frontier.luau`,
  `src/shared/Config/DayCycle.luau`, `src/shared/Config/Music.luau`, `src/shared/Config/LoadingScreen.luau`,
  `src/shared/Config/Bosses.luau` (only `height` / `moments` for the new models), `tests/WildValley.spec.luau`,
  `tests/MusicRules.spec.luau`, `tests/LoadingRules.spec.luau`, `tests/DayCycle.spec.luau`, `tests/Frontier.spec.luau`,
  `tests/CreatureAssets.spec.luau`, DESIGN.md, CLAUDE.md, docs/props.md, docs/creatures.md.

---

### Task 1: One valley engine, place-selected

**Files:** `Util/Place`, `Util/WildValley`, WildService, SceneryService, BossService, DayCycleController,
MusicController, WildLoadingController, `tests/WildValley.spec.luau`.

**Interfaces:**
- Produces: `Place.getValley(): any?` (WildValley config in the main game, FrontierValley in the Frontier, nil in the
  Dungeon). `Util/WildValley` functions accept a valley without `STREAM`, `STONE_CIRCLE`, `MUSHROOM_RINGS`,
  `GRASS_PATCHES`, `PATHS`, `ARENA_DRESSING[zone].roof`. Services keep a local `Valley = Place.getValley()` and treat
  nil as "no valley" (today's `VALLEY` flag becomes `Valley ~= nil`). SceneryService's Wild-only builders (bridge, cave,
  volcano, vents, ridge cracks, canyon, falls, frozen falls, small life, plume) run only when their key is present.

- [ ] **Step 1: Write the failing tests** in `tests/WildValley.spec.luau`:

```lua
["a valley without the Wild's own pieces still gives terrain, scenery and clear spots"] = function()
	local bare = table.clone(valley)
	bare.STREAM, bare.STONE_CIRCLE, bare.MUSHROOM_RINGS, bare.GRASS_PATCHES, bare.PATHS = nil, nil, nil, nil, nil
	expect.equal(#WildValley.terrainOps(bare, TownTerrain.trailSegment) > 0, true)
	expect.equal(#WildValley.scenery(bare) > 0, true)
	expect.equal((WildValley.clearOf({ x = 1e6, z = 1e6 }, bare)), true)
	expect.equal(#WildValley.zoneSpots(bare, 1) > 0, true)
end,
["the Wild's terrain ops are unchanged"] = function()
	expect.equal(#WildValley.terrainOps(valley, TownTerrain.trailSegment), WILD_OP_COUNT)
end,
```
  `WILD_OP_COUNT`: measured on main before any change (run once, write the number in the test).

- [ ] **Step 2: Run** `lune run tests/run` — Expected: the first test FAILS (clearOf/scenery index nil), the second
  passes.
- [ ] **Step 3: Implement** the optional keys in `Util/WildValley`, `Place.getValley()`, and switch the six readers to
  it (no behaviour change in the main game).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass. Compile-check the changed client files
  (`lune run <scratchpad>/compile_check.luau <files>`).
- [ ] **Step 5: Studio:** main place Play: `/wild`, Output has no errors, the valley looks as before (screenshot the
  meadow from the arrival). Dungeon window boots ("Booted (Dungeon)").
- [ ] **Step 6: Commit** "Valley: one engine, the place picks its valley config".

### Task 2: The Frontier valley's layout, playable

**Files:** create `Config/FrontierValley.luau`, `tests/FrontierValley.spec.luau`; modify `Config/Frontier.luau`
(SPRING, ENTRANCE_OFFSET, DUNGEON_PORTAL into the valley, MONSTER_HEIGHT 3.9), `Util/Place` (returns it),
`init.server.luau` (Frontier: `SceneryService.StartValley()` before WildService), SceneryService (`StartValley`: the
terrain, edge walls, markers, settle; no town), WildService (the Frontier takes the valley branch: biomes, trail,
boards, arrows, spawn spots, population; the flat zones and rings go), BossService (`here == "Frontier"` uses
`buildBossPortal`), DevService (`/boss 4-6` to the portal), DungeonGateService (the portal at
`FrontierValley.DUNGEON_GATE`).

**Interfaces:**
- Consumes: Task 1's `Place.getValley()`.
- Produces: `Config/FrontierValley` with every shared key of WildValley (MAX_CELLS, SURFACE_LIFT, TRAIL_WIDTH,
  MARKER_SPACING, MAX_STEP, PORTAL_CLEAR, BOARD_CLEAR, POPULATION, SPOT_*, ARRIVAL_CLEAR, BIOMES, TRAIL,
  TRAIL_MATERIAL, BIOME_FLOOR, BIOME_CLIFF, PASS, PASS_BANKS, HILLS, EDGE_WALL, EDGE, TERRAIN_READY_ATTRIBUTE =
  "FrontierTerrainReady", TERRAIN_WAIT, SIGN_WIDTH, RETURN_SIGN, BOARD_FACE_BACK, ARROWS, MARKER, TERRAIN, SKYLINES,
  CARVES, BOSS_PORTAL, ARENA_* , PROP_LISTS, GLOW, COLLIDERS, PROPS, SETTLE, FEET, BACKDROP, MOUNTAINS) plus
  `CAMP = { spring, returnPortal, tents = {...}, campfire, tower }` and `DUNGEON_GATE = { x, z, faces }`. Biome
  `ground`: 0, 40, -15. The dead giant is TERRAIN (a long mound with rib and skull props in Task 3) between the three.
  Materials: floors Snow / Slate / Basalt, cliffs Glacier / Rock / Basalt, trail Ground / Slate / Basalt. Arenas at
  `ARENA_FIELD = { x = 1600, z = 1200, y = 0, spacing = 1200 }` (the Frontier place is empty there).

- [ ] **Step 1: Write the failing tests** in `tests/FrontierValley.spec.luau` (reads `Config/FrontierValley`,
  `Config/Frontier`, `Config/Bosses`, `Util/WildValley`, `Util/TownTerrain`):
  - `every key the Wild valley's engine reads is here` — for each shared key above, `frontier[key] ~= nil`.
  - `three biomes at 0, 40 and -15, each at least 200 studs across` — `#BIOMES == 3`, grounds `{0, 40, -15}`, outline
    bounds >= 200 on x or z.
  - `the trail runs camp → Frostwood → Stormpeak → the Rift` — `zoneAt(TRAIL[1])` nil or 1, the zones met along the
    trail in order 1, 2, 3, never back.
  - `the trail changes height only on its passes, gently` — each segment's `|dy| / length <= 0.35`, every point inside
    `EDGE`.
  - `the Rift can't be seen from the camp` — the segment from `ARRIVAL_CLEAR`'s middle to the Rift's centre crosses a
    TERRAIN block or ball topping out at least 20 above both ends (the dead giant).
  - `the Dungeon gate is the farthest point from the camp` — its distance from the arrival's middle is greater than
    every EDGE point's but 30, and it is inside the Rift.
  - `the camp holds the spring and the return portal and no spawn spots` — `Frontier.SPRING` and
    `CAMP.returnPortal` inside `ARRIVAL_CLEAR`; no `zoneSpots` point inside it.
  - `every biome has POPULATION.MAX spawn spots` — `#WildValley.zoneSpots(frontier, i) == POPULATION.MAX`.
  - `props stay clear of the trail, portals, boards and camp, in their own biome` — `WildValley.clearOf` true for every
    `WildValley.scenery` spot, `zoneAt` equals its list's biome when it has one.
  - `the terrain fits its budget` — the Wild test's cell estimate over `terrainOps(frontier)` <= MAX_CELLS (105000).
  - `arena copies stand apart and far from the valley` — `ARENA_COPIES_FOR_TERRAIN == Bosses.ARENA_COPIES`; every
    pair of copy centres at least 400 apart; every copy at least 600 from every EDGE point.
  - `each boss portal stands beside its trail on gentle ground, inside the edge` — distance to the trail between
    TRAIL_WIDTH and 40, inside EDGE, not on a hill.
  - `backdrop and mountains stand outside the walkable edge` — not `inside(EDGE, spot)`.
  - `the Frontier draws monsters 30% bigger than the Wild` — `Frontier.MONSTER_HEIGHT == 3.9`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (module missing).
- [ ] **Step 3: Write `Config/FrontierValley`** to the map on the picks page (camp south, Frostwood west, climb east to
  Stormpeak, the dead giant in the middle, drop north into the Rift, the Dungeon gate at its far end, about 600 by 750
  studs), with stand-in props (the Wild's MossRock, Ruin*, DragonSkeleton, MountainSnow/Dark) until Task 3. Wire the
  place as in Files.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Studio (Frontier window, `rojo serve frontier.project.json`):** Play; Output clean; "FrontierTerrainReady"
  set; walk camp → Frostwood → Stormpeak → Rift; no wall visible, no gap to fall through, the Rift hidden from the
  camp; monsters spawn in each; each portal's prompt opens its boss; `/boss 4`, `/boss 5`, `/boss 6` reach each portal;
  the Dungeon portal works at the end; lose a fight (`/tire`) and land at the spring. Screenshots: camp, each area,
  each portal.
- [ ] **Step 6: Commit** "Frontier: the valley's layout (trail, three areas, portals, camp)".

### Task 3: The Frontier's scenery props

**Files:** create `tools/blender/build_frontier_props.py` (on `voxel_kit.py` / `portal_kit.py` like
`build_valley_props.py`); `assets/blender/<Name>/`; `assets/props/<Name>.rbxm` (the owner imports each FBX, as in
docs/props.md); modify `Config/FrontierValley` (PROP_LISTS, GLOW, COLLIDERS, BACKDROP, MOUNTAINS), docs/props.md.

**Interfaces:**
- Produces props: `Ribcage`, `HornedSkull`, `GiantSword`, `FortRuin`, `FortWall`, `WreckedTower`, `Watchtower`,
  `Tent`, `Campfire`, `SnowPine`, `DeadPine`, `RockSpire`, `RiftCrystal`, `FloatingRock`, `CrystalArch`,
  `IcePillar`, `IceThrone`, `StormStone`, `TitanSkull` (the dead giant's head), each under 2000 triangles (4000 for
  Ribcage, HornedSkull, TitanSkull), a `Frame` and a `Glow` where it glows. Backdrop: the Wild's `MountainSnow` and
  `MountainDark` plus `TitanSilhouette` and `StormWall` (under 4000).

- [ ] **Step 1: Write the failing test** in `tests/FrontierValley.spec.luau`:
  `every model the Frontier names is a saved prop` — every `model` in `WildValley.scenery(frontier)`, BACKDROP,
  MOUNTAINS, ARENA_DRESSING and CAMP exists as `assets/props/<model>.rbxm` (`fs.isFile`).
- [ ] **Step 2: Run** — Expected: FAIL naming the new models.
- [ ] **Step 3: Build** the props in a background Blender (`blender -b --factory-startup --python
  tools/blender/build_frontier_props.py`), render previews, show the owner the renders (always show mockups), then the
  owner imports and saves each; place them in FrontierValley's lists (ribcage over the trail in Frostwood, swords in
  the snow, forts with red banners; towers, the horned skull and spires on Stormpeak; crystals, floating rocks and the
  dragon skeleton in the Rift; the TitanSkull and Ribcage on the dead giant; tents, campfire and watchtower in the
  camp).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass (Task 2's clearance tests cover placement).
- [ ] **Step 5: Studio:** walk the trail; screenshot each area against the area concept; check frame time on a
  phone-sized device (Galaxy A06 in the device simulator), 30 fps or better.
- [ ] **Step 6: Commit** "Frontier: Titans' Graveyard scenery".

### Task 4: Skies and effects

**Files:** `Config/DayCycle` (`FRONTIER = { FIXED, AREA_LOOKS = { [1..3] }, ARENA_LOOKS = { [1..3] } }`),
DayCycleController (the Frontier uses `DayCycle.FRONTIER`, no day cycle), `Config/FrontierValley.FX`,
`Util/FrontierFxRules.luau`, `Controllers/FrontierFxController.luau`, `init.client.luau` (the Frontier starts
DayCycleController and FrontierFxController), `tests/FrontierFxRules.spec.luau`, `tests/DayCycle.spec.luau`.

**Interfaces:**
- Produces: `FrontierValley.FX = { snow = { zone = 1 }, fog = { [1] = density, [2] = ..., [3] = ... },
  eyes = { { x, z, y } ... }, eyeFade = { near = 30, far = 90 }, lightning = { zone = 2, every = { 8, 16 } },
  tornado = { x, z }, vortex = { zone = 3 }, floatingRocks = { { x, z, y, bob } ... },
  tremor = { zone = 3, every = { 20, 40 }, shake = 0.3 } }`.
  `FrontierFxRules.eyeAlpha(distance: number, fade: {near: number, far: number}): number` (0 at or under near, 1 at
  or over far, linear between). `FrontierFxRules.nextFlash(rng: () -> number, every: {number}): number`.
  `FrontierFxRules.shake(t: number, length: number, strength: number): number` (0 at t = 0 and t >= length, never above
  strength).

- [ ] **Step 1: Write the failing tests:** `eyes vanish as you come close` (eyeAlpha 0 at 20, 1 at 100, 0.5 at 60
  with near 30 / far 90); `lightning comes between its bounds` (100 draws of nextFlash with every {8, 16} all in
  [8, 16]); `a tremor's shake starts and ends still, never over its strength`; `the Frontier has a look for each area
  and each arena` (DayCycle.FRONTIER AREA_LOOKS and ARENA_LOOKS have 1..3, each with the same keys as the Wild's
  AREA_LOOKS entries).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the looks (Frostwood grey snowy dusk, Stormpeak dark storm, the Rift violet-black;
  arenas: cold throne hall, storm eye, violet void) and the controller (client-only parts; eyes are two small Neon
  parts that fade by eyeAlpha; lightning flashes Lighting brightness for 0.15 s plus a thunder sound; the tremor shakes
  the camera by shake() and rumbles; no damage anywhere).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass; compile-check the client files.
- [ ] **Step 5: Studio:** each area's sky blends in on its pass; eyes fade as you walk up; a flash and thunder on
  Stormpeak; a tremor in the Rift; screenshots of each.
- [ ] **Step 6: Commit** "Frontier: skies, fog eyes, storm and rift effects".

### Task 5: Boss arenas

**Files:** `Config/FrontierValley` (ARENA_CLEARING, ARENA_LOOKS, ARENA_DRESSING, ARENA_HOME, ARENA_FENCE),
SceneryService (`buildArenaEffects` for `boss.place == "Frontier"` from the place's valley), tests.

**Interfaces:**
- Consumes: Task 3's props (IceThrone, IcePillar, StormStone, FloatingRock, RiftCrystal).
- Produces: arena 1 a frozen throne hall (ice pillars, broken throne, snow), arena 2 a broken stone ring on a summit
  (storm eye overhead from Task 4's ARENA_LOOKS), arena 3 a rock island in violet void (crystals round its edge; the
  void a dark Neon floor far below).

- [ ] **Step 1: Write the failing tests** in `tests/FrontierValley.spec.luau`, mirroring the Wild's:
  `each arena copy is walled in round its clearing, its ring and its way home inside`; `each arena's pieces stay clear
  of the fight and the way home`; `the arenas' fence radius agrees with Bosses` (`ARENA_FENCE == Bosses.ARENA_RADIUS`).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the dressing.
- [ ] **Step 4: Run** — Expected: all pass.
- [ ] **Step 5: Studio:** `/boss 4 fight`, `/boss 5 fight`, `/boss 6 fight`: the intro, the arena, its sky; win one
  (`/maxcard`), the way home returns you to its portal. Screenshots of each arena.
- [ ] **Step 6: Commit** "Frontier: the three boss arenas".

### Task 6: Loading screen and music

**Files:** `src/first/LoadingGui.luau` (`build(cfg, images, firstStep, look: string?)`: look "Frontier" draws the
Wild portal's swirl, `Config/WildLoading` SWIRL, tinted icy blue and violet, title "The Frontier", no card fan),
`src/first/Show.client.luau` (a fresh screen in the Frontier uses the Frontier look), FrontierController (main game:
`SetTeleportGui` with the Frontier look before the travel request), `Config/LoadingScreen` (FRONTIER look colours,
tips), `Util/LoadingRules` (`Status.valley: boolean?`: required in the Frontier), LoadingController (the Frontier's
valley flag: terrain flag set, the scenery round you streamed, the monsters' models loaded, the area's music
preloaded, as `Util/WildLoadingRules` checks the Wild), `Config/Music` (`FRONTIER = { areas = { frostwood,
stormpeak, rift }, arenas = { tyrant, sovereign, devourer } }`, each with 3 licensed `options`, a pick, an ambient
loop and a volume), `Util/MusicRules` (`place(music, world, arena, area, inTown, last)`; `find` searches FRONTIER too),
MusicController (the Frontier's world), `init.client.luau` (the Frontier starts MusicController), DevService
(`/music frostwood|stormpeak|rift|tyrant|sovereign|devourer <n>`), `tests/MusicRules.spec.luau`,
`tests/LoadingRules.spec.luau`.

- [ ] **Step 1: Write the failing tests:** `the Frontier's places play their own music` (MusicRules.place with
  Music.FRONTIER: arena 2 → "sovereign", area 1 → "frostwood", none and last "rift" → "rift"); `find knows the
  Frontier's keys`; `every Frontier place has 3 options and a quiet volume` (volume <= 0.02, like the Wild's);
  `the Frontier's loading waits for its valley` (LoadingRules.progress not done with `valley = false` in the Frontier,
  done with it true and everything else ready).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** Music candidates from the licensed libraries (memory: PSE 7462895450, APM 7462718749,
  toolbox API category 3): darker strings, war drums, choir; measured skill-sound rules don't apply (music).
- [ ] **Step 4: Run** — Expected: all pass.
- [ ] **Step 5: Studio:** from the main place the Frontier portal shows the Frontier screen (Studio can't teleport:
  check the built GUI with a screenshot); in the Frontier window Play shows the Frontier look and closes only once the
  camp is in; each area and arena plays its track; `/music` previews.
- [ ] **Step 6: Commit** "Frontier: its loading screen and music".

### Task 7: Six monster models

**Files:** `assets/blender/<Folder>/` (concept cut out → `<Folder>_concept.png`, `.blend`, `.fbx`, glow mask),
`tools/blender/rig_frostwisp.py`, `rig_shadelynx.py`, `rig_stormhawk.py`, `rig_lavabrute.py`, `rig_rifthorror.py`,
`rig_prismcrab.py`; `assets/monsters/<Species>.rbxm` (the owner imports); clips via `anim_wild.py` into
`assets/monster-animations/<Species>`; `Config/Party` CREATURE_STYLE entries; `tests/CreatureAssets.spec.luau`.

- [ ] **Step 1: Write the failing test:** `every Frontier species has a model` (each `Frontier.SPECIES` name has
  `assets/monsters/<name>.rbxm`), held back by the model gate's existing script/part checks.
- [ ] **Step 2: Run** — Expected: FAIL (6 missing).
- [ ] **Step 3: For each species,** read the Meshy balance (number only), cut the concept out, generate image-to-3D,
  run its rig script (bones by PetRig names: slime none but `Jaw_0`; lynx legs 0-1 and `Tail_n`; hawk `Wing_<Side>_n`
  and legs; brute pair 0 legs and `Arm_<Side>_n`; horror legs 0-2 and `Pincer_<Side>_0`; crab legs 0-2 and
  `Claw_<Side>_n`), check stretch, export, show renders, the owner imports, finish in Studio (pivot, glow
  SurfaceAppearance), then clips.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Studio:** each species in its area, normal and `/elite`; it walks, attacks, flies (hawk) and fits
  its height; screenshot each.
- [ ] **Step 6: Commit** per two species, "Frontier monsters: <A> and <B>".

### Task 8: Three boss models

**Files:** `assets/blender/FrostTyrant|StormSovereign|RiftDevourer/`, `tools/blender/rig_frosttyrant.py`,
`rig_stormsovereign.py`, `rig_riftdevourer.py`, `anim_frosttyrant.py`, `anim_stormsovereign.py`,
`anim_riftdevourer.py`, `assets/monsters/<bossId>.rbxm`, `assets/monster-animations/<bossId>`, `Config/Bosses`
(`height`, `introShot`, `moments` with the clips and bones: the Tyrant's shield, the Sovereign's thunderclap, the
Devourer's call for its Rift Horrors), `tests/CreatureAssets.spec.luau`.

- [ ] **Step 1: Write the failing test:** `every Frontier boss has a model and its clips` (`assets/monsters/<bossId>.rbxm`
  and `assets/monster-animations/<bossId>/` with idle, attack, big and the mechanic's clip).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build each** as the Wild bosses (docs/creatures.md "Wild bosses"): Meshy from the picked concept
  (Tyrant A, Sovereign B, Devourer A), rig, clips, renders to the owner, the owner imports, finish in Studio.
- [ ] **Step 4: Run** — Expected: all pass.
- [ ] **Step 5: Studio:** each boss fight from its portal: the intro, the moment, the clips; screenshots.
- [ ] **Step 6: Commit** per boss, "Frontier boss: <name>".

### Task 9: Docs and memory

- [ ] DESIGN.md (the Frontier section rewritten as a valley: layout, heights, danger, arenas, music, loading),
  CLAUDE.md (assets and commands), docs/props.md ("Frontier scenery props"), docs/creatures.md ("Frontier monsters",
  "Frontier bosses"), the Obsidian vault (decisions, lessons), memory (Frontier progress).
- [ ] `lune run tests/run` — Expected: all pass. Commit "Docs: the Frontier valley".
