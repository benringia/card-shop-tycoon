# Dungeon World: the Crystal Abyss Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Dungeon from a walled box into the Crystal Abyss: islands over a bottomless chasm in a giant cave,
linked by bridges, with three designed gates and death by falling.

**Architecture:** A new pure module `Util/AbyssLayout` computes every island, bridge, door spot and approach from
`Config/Dungeon` (Lune-tested). `DungeonBuilder` builds from it: Terrain for the cave shell and the islands' rocky
undersides, Parts for the walkable floors, props from a new Blender pack (`DungeonWorld`) with stand-ins until it is
imported. `DungeonService` gains a server fall sweep. A new `PortalDungeon` model replaces the borrowed Arena portal in
the Frontier.

**Tech Stack:** Luau (Rojo), Lune tests, Blender 5.2 (background) on `voxel_kit` / `portal_kit`, Roblox Terrain.

**Spec:** `docs/superpowers/specs/2026-11-12-dungeon-world-design.md`

## Global Constraints

- Launch 2026-11-20; the round should land in about two days.
- Server authoritative: islands, bridges, the fall check and the return happen on the server; a client never decides
  a fall.
- No change to the run's rules, puzzles, chests, rewards, monsters, the Hydra fight, the objective text, the welcome's
  beats or the ambience; no saved-data change.
- Today's dev commands and admin buttons keep working: `/room`, `/puzzle`, `/tap`, `/dungeonfx`.
- Props: one Blender pack FBX (`assets/blender/DungeonWorld/DungeonWorld.fbx`) the owner imports once and saves as
  `assets/props-import/DungeonWorld.rbxm`, split by `lune run tools/props/split_pack`. Each prop under 2000 triangles;
  the Hydra's door, the entrance arch and the portal under 4000. Code-built stand-ins while a prop is missing.
- `PortalDungeon` is its own FBX like the other portals (`assets/blender/PortalDungeon/`), imported once by the owner.
- Bridges about 8 studs wide with low broken railings; walked, never jumped.
- The chasm glows from fog, Atmosphere and a few dim lights low down; never a bright neon plane. No sky or stars.
- The coloured light shafts over the fight rooms are removed.
- Cool indigo and violet with rainbow crystal light; it must not read as the Wild's ember caldera.
- Phones: few lights (today one crystal in four carries a light).
- Text plain ASCII; numbers and colours in `Config/Dungeon`.
- Claude never edits the place file without asking; the owner imports models in Studio.
- DESIGN.md, docs/props.md and CLAUDE.md are updated in the same change.

## Review Focus

1. Dev teleports onto angled bridges (`/puzzle`, `/room`) must land on stone, not over the chasm; pinned by the
   `approach` / `afterDoor` spots lying on a bridge or island (Task 1 test `approach spots stand on stone`).
2. The fight leash's put-back point must stay on the island: measured from the ring's centre at `ROOM_RADIUS`
   (Task 1 test `run leash puts you back inside the ring`, Task 2 BattleService change).
3. A teleport onto a far island before it has streamed in must not drop the player into the kill sweep: every server
   pivot to a Dungeon spot prestreams first (Task 3 step), checked in Studio with `/room 3`.
4. A summoned creature walking off a bridge must never be lost or stuck below: it is put back beside its owner
   (Task 3 step, Studio check).
5. A player who walks off the ledge before the run opens, or off a puzzle island, dies the same way: out of the run
   and back to the Frontier (Task 3 Studio check), never a soft-lock in the dark.

---

### Task 1: The Abyss layout (pure rules and config)

**Files:**
- Create: `src/shared/Util/AbyssLayout.luau`
- Modify: `src/shared/Config/Dungeon.luau` (new `ABYSS` table; `ROOM_LEASH` redefined)
- Test: `tests/AbyssLayout.spec.luau` (register in `tests/run.luau`), `tests/Dungeon.spec.luau` (the leash test)

**Interfaces:**
- Produces:
  - `export type Spot = { x: number, z: number }`
  - `export type Island = { kind: "ledge" | "fight" | "beams" | "plates" | "lock" | "chamber", step: number?, x: number, z: number, round: boolean, size: number, entry: Spot, exit: Spot }`
    (`size` is the radius of a round island, the half side of a square one; `entry` is on its -X edge, `exit` on its +X
    edge, both at the island's z)
  - `export type Bridge = { from: Spot, to: Spot, length: number, yaw: number }` (yaw in radians, about Y, 0 along +X)
  - `AbyssLayout.islands(dungeon: any, chamberRadius: number): { Island }`, in walking order: the ledge, one per
    `dungeon.STEPS`, the chamber
  - `AbyssLayout.bridges(islands: { Island }): { Bridge }`, island i's exit to island i+1's entry
  - `AbyssLayout.onStone(islands: { Island }, bridges: { Bridge }, width: number, point: Spot): boolean`
  - `AbyssLayout.alongBridge(bridge: Bridge, studs: number): Spot` (a point that far from `from` toward `to`)
  - `AbyssLayout.fallen(y: number, killY: number): boolean`
- `Config/Dungeon.ABYSS`:

  ```lua
  ABYSS = {
  	WIND = { 0, 14, -14, 14, -14, 8 }, -- each step's island z (left/right of the line); the chamber stays at z 0
  	RIM = 2, -- a fight island reaches this far past its ring (the barrier sits at the edge)
  	PUZZLE_HALF = 32, -- a puzzle island's half side
  	LEDGE = { back = -12, halfWidth = 16 }, -- the entrance ledge from x back to HALL.length
  	BRIDGE_WIDTH = 8,
  	RAIL_HEIGHT = 1.5,
  	UNDERSIDE = 34, -- how deep an island's rock hangs under its floor
  	KILL_Y = -60, -- below this you have fallen
  	CEILING_Y = 110,
  	CAVE_HALF_WIDTH = 220,
  	GLOW = { y = -70, every = 120, range = 60, brightness = 2, color = { 150, 90, 255 } },
  	DOOR_RADIUS = 13, -- the Hydra's door
  	FALL_MESSAGE = "You fell into the abyss.",
  	FALL_FX_ABOVE = 20, -- the client's scream and fade start this far above KILL_Y
  },
  ```
  and `ROOM_LEASH = 42` (the ring plus `RIM`, measured from the ring's centre; the put-back point lands at 40).

- [ ] **Step 1: Write the failing tests** in `tests/AbyssLayout.spec.luau`:
  - `islands in walking order`: 8 islands; kinds `ledge`, then the six steps' kinds, then `chamber`; island i+1's
    `entry.x` > island i's `exit.x`.
  - `the chamber where the Hydra's arena stands`: last island `x == Dungeon.CHAMBER.x`, `z == 0`, `size == 48`.
  - `fight islands hold their ring`: each fight island `round`, `size == Dungeon.ROOM_RADIUS + ABYSS.RIM`.
  - `puzzle pieces stand on their island`: every `PUZZLE.PLATES` spot, every lock crystal z
    (`(i - 3) * LOCK_SPACING`) and the beam grid's half extent `(max(width, height) + 1) / 2 * BEAMS.CELL` for every
    `BEAMS.LAYOUTS` entry are within `PUZZLE_HALF - 2`.
  - `the secret ledge sits on the plates island's +z side`: `PUZZLE.ALCOVE.z <= PUZZLE_HALF + 2`.
  - `islands never overlap`: centre distance > sum of sizes for every pair (square size as its half side's circle).
  - `bridges link neighbours and stay walkable`: 7 bridges; each `length` between 8 and `ROOM_GAP * 1.6`; the bridge's
    midpoint is on no island (`onStone` false without bridges, true with them).
  - `approach spots stand on stone`: for every bridge, `alongBridge(b, 6)` and `alongBridge(b, b.length - 8)` are
    `onStone`.
  - `everything inside the cave`: every island's `|z| + size < CAVE_HALF_WIDTH`, `KILL_Y < -UNDERSIDE - 5`,
    `CEILING_Y > 60`.
  - `fallen`: `fallen(-61, -60) == true`, `fallen(-59, -60) == false`.
  - In `tests/Dungeon.spec.luau`, replace the leash test with `run leash puts you back inside the ring`:
    `ROOM_LEASH == ROOM_RADIUS + ABYSS.RIM` and `ROOM_LEASH - 2 <= ROOM_RADIUS`.

- [ ] **Step 2: Run** `lune run tests/run` → Expected: the new tests FAIL (`AbyssLayout` missing, `ABYSS` nil).

- [ ] **Step 3: Implement** `Config/Dungeon.ABYSS`, `ROOM_LEASH = 42`, and `AbyssLayout` (no requires; pure). Island x
  centres follow today's sums so the chamber stays at 660: the ledge spans `LEDGE.back .. HALL.length`; each step's
  section starts `ROOM_GAP` after the previous edge with length `ROOM_RADIUS * 2` (fight) or `PUZZLE.LENGTH`; the
  chamber's centre is `CHAMBER.x`. Fight islands are round, puzzle islands square, the ledge square-ish
  (`size = LEDGE.halfWidth`, centred on its span), the chamber round with `chamberRadius`.

- [ ] **Step 4: Run** `lune run tests/run` → Expected: all pass.

---

### Task 2: Build the Abyss (DungeonBuilder, leash from the ring)

**Files:**
- Modify: `src/server/Util/DungeonBuilder.luau`, `src/server/Services/BattleService.luau` (keepNear),
  `src/server/Services/DungeonService.luau` (openDoor, SkipTo, SkipToPuzzle, run fights' options)

**Interfaces:**
- Consumes: Task 1's `AbyssLayout.islands / bridges / alongBridge`, `Dungeon.ABYSS`.
- Produces (DungeonLayout additions): `islands: { AbyssLayout.Island }`, `bridges: { AbyssLayout.Bridge }`,
  `Room.approach: CFrame` (on the bridge, 8 studs before the ring's gate, facing it),
  `afterDoor: { CFrame }` (per door, 6 studs past it along its bridge, facing along it),
  `RunOptions.leashCenter: Vector3?` in BattleService.

- [ ] **Step 1: Remove** the box: the long floor, the side and end walls, `crossWall`, the light shafts (`shaft` and
  its calls) and the wall-side crystal rows in `DungeonBuilder.build`.
- [ ] **Step 2: Cave shell in Terrain:** `workspace.Terrain:Clear()` then Slate/Basalt `FillBlock`s for the ceiling at
  `CEILING_Y`, the two side walls at `±CAVE_HALF_WIDTH` and both end walls (behind the ledge at `LEDGE.back - 4`, past
  the chamber), a few `FillBall` stalactite lumps under the ceiling. No terrain above y = -0.5 under any island.
- [ ] **Step 3: Islands:** for each island a flat floor Part (top at y 0; Cylinder for round, Block for square; Slate,
  `COLORS.FLOOR`) and its rocky underside in Terrain hanging `UNDERSIDE` deep (a cylinder/block then a smaller ball
  below). `room()` keeps its posts, barrier and gate but no longer makes its own disc; the chamber's floor stays
  WildService's ring (only its underside and rim come from here).
- [ ] **Step 4: Bridges:** for each `Bridge`, `DungeonBridge` props tiled along it (stand-in: a `BRIDGE_WIDTH` x 1.5
  slab plus broken railing stubs `RAIL_HEIGHT` tall at both edges, gaps every few studs).
- [ ] **Step 5: Gates:** `door(parent, name, at: Vector3, yaw: number): Part` places each step's door at its island's
  `exit` (an invisible collider `BRIDGE_WIDTH + 2` wide, 12 tall, wearing `DungeonIslandGate` as its Look; stand-in: a
  stone arch plus the ForceField barrier). The ChamberDoor sits at the chamber island's `entry` wearing
  `DungeonHydraDoor` (stand-in: a Cylinder disc of radius `DOOR_RADIUS`); `sockets()` puts `LockSocket<n>` on that
  door's face as the hydra's five eyes. Chest spots stay 8 in and 16 to the side of each door, on its island.
- [ ] **Step 6: Entrance ledge:** spawn, steps, the four `HALL_BRAZIERS`, a `DungeonArch` set into the cave wall at
  x = -10 (the way back the welcome's slab seals). The plates island's alcove gets its small rock ledge on +z.
- [ ] **Step 7: Dressing and light:** per island, ruins and `DungeonCrystals` round the rim (one in four lit), chains
  (`DungeonChain`) from the ceiling over a few islands, the hydra sigil in each fight island's floor (`DungeonSigil`,
  stand-in none). `GLOW` PointLights every `GLOW.every` studs at `GLOW.y`. The place's `Sky`: `StarCount = 0`,
  `CelestialBodiesShown = false`.
- [ ] **Step 8: DungeonService:** `openDoor` calls `DungeonBuilder.hide(door)`; `SkipTo` pivots to
  `layout.rooms[target].approach`; `SkipToPuzzle` to `layout.afterDoor[index - 1]`; run fights pass
  `leashCenter = room.center`. BattleService `keepNear` measures from `fight.leashCenter or fight.center`.
- [ ] **Step 9: Verify:** `lune run tests/run` (all pass), the compile check on the touched files,
  `rojo build dungeon.project.json -o <scratch>/test.rbxl`, then Studio (Dungeon window): screenshots of the ledge,
  a bridge, an island, the Hydra's door; `/puzzle beams|plates|lock` and `/room 2|3|4` land on stone; one fight in
  room 1 with no "Stay near the fight!".

---

### Task 3: Falling is death

**Files:**
- Modify: `src/server/Services/DungeonService.luau`, `src/shared/Config/Dungeon.luau` (`SOUNDS.fall`)
- Create: `src/client/Controllers/DungeonFallController.luau` (register in `src/client/init.client.luau`'s Dungeon branch)

**Interfaces:**
- Consumes: `AbyssLayout.fallen`, `ABYSS.KILL_Y / FALL_MESSAGE / FALL_FX_ABOVE`, today's `markOut`.

- [ ] **Step 1: Server sweep:** every 0.25 s, for each run member not out with a character: if
  `AbyssLayout.fallen(root.Position.Y, KILL_Y)`, anchor the root and `markOut(player, ABYSS.FALL_MESSAGE)` (which
  already returns them to the Frontier after `OUT_DELAY`). Members who joined but the run hasn't started count too
  (the ledge).
- [ ] **Step 2: Creatures:** find where a summoned creature's model is moved (PartyService / its client motion); if
  its root falls below `KILL_Y`, put it beside its owner.
- [ ] **Step 3: Prestream:** every server pivot to a Dungeon spot (`SkipTo`, `SkipToPuzzle`, room entry) calls
  `WildService.Prestream(player, spot)` first.
- [ ] **Step 4: Client:** `DungeonFallController` watches the local root each frame; below `KILL_Y + FALL_FX_ABOVE`
  once: play `SOUNDS.fall` (a short scream, picked with `python scratchpad/sound_search.py pse "fall scream"`) and fade
  a black frame in over 0.8 s, kept until the teleport. Never during the welcome (`DungeonIntroPlaying`).
- [ ] **Step 5: Verify:** tests and compile; Studio: walk off a bridge → scream, black, "You fell into the abyss.",
  back in the Frontier window's flow (in Studio the teleport is skipped; the out message and the run line's "out"
  show); walk off the ledge before Fight → same.

---

### Task 4: The props pack and the Dungeon portal

**Files:**
- Create: `tools/blender/build_dungeon_world.py` (pack `DungeonWorld`), `tools/blender/build_portal_dungeon.py`
- Modify: `src/shared/Config/Town.luau` (`SLOTS.PortalDungeon`, `PORTAL_LOOKS.Dungeon`),
  `src/shared/Config/FrontierValley.luau` (`DUNGEON_GATE.model = "PortalDungeon"`, `look = "Dungeon"`)
- Test: `tests/PortalLooks.spec.luau` (LOOKS gains "Dungeon")

- [ ] **Step 1: Failing test:** add `"Dungeon"` to `LOOKS` in `tests/PortalLooks.spec.luau`; run → FAIL
  (`PORTAL_LOOKS.Dungeon` nil).
- [ ] **Step 2: Config:** `SLOTS.PortalDungeon = { height = 26, collide = false }`; `PORTAL_LOOKS.Dungeon` with slot
  `PortalDungeon`, a violet vortex (`{ 150, 70, 255 }`, `{ 90, 200, 255 }`, core `{ 60, 20, 130 }`), light
  `{ 180, 140, 255 }`, glow `{ Crystals = { 190, 150, 255 } }`, at most `MAX_EFFECTS` effects (dust at the steps,
  sparkles in the Opening). `DUNGEON_GATE` uses it, falling back to `PortalArena` while the model is missing. Run →
  PASS.
- [ ] **Step 3: Pack script** `build_dungeon_world.py` (like `build_dungeon_props.py`: one FBX, Empties `<Name>` over
  `<Name>__Frame` / `<Name>__Glow`, palettes to `assets/blender/<Name>/`): `DungeonIslandGate` (ruined arch, opening
  10 wide 11 tall, Glow crystal barrier with a hydra-eye mark), `DungeonHydraDoor` (round door radius 13, a five-headed
  hydra in relief, Glow cracks; no gems, the code's sockets are the eyes), `DungeonBridge` (8 x 12 segment, broken
  railings), `DungeonChain`, `DungeonStalactite`, `DungeonRimRocks`, `DungeonSigil`. Names must not clash with existing
  `assets/props` (check before saving).
- [ ] **Step 4: Portal script** `build_portal_dungeon.py` on `portal_kit` (Frame, Crystals, Opening, Fx_ markers;
  about 26 tall, opening 14 wide): a cave-mouth arch split in the ground, five hydra heads on top, crystal-grown, steps
  down into it.
- [ ] **Step 5: Build and look:** run both in background Blender; one preview render per prop with
  `render_valley_props.py` (one prop per run); show the owner the renders before export.
- [ ] **Step 6: Owner imports:** `DungeonWorld.fbx` → `assets/props-import/DungeonWorld.rbxm` → `split_pack`;
  `PortalDungeon.fbx` → `assets/props/PortalDungeon.rbxm`. Studio: the props replace the stand-ins; the Frontier window
  shows the new portal.

---

### Task 5: Welcome re-aim, docs, Studio pass

**Files:**
- Modify: `src/client/Controllers/DungeonIntroController.luau` (only if the shots need it), `DESIGN.md`,
  `docs/props.md`, `CLAUDE.md`

- [ ] **Step 1: Welcome:** play `/dungeonfx intro` from the server side; screenshot the slam (the arch behind the
  ledge), the eyes over the chasm, the title. Re-aim only shots that miss.
- [ ] **Step 2: Docs:** DESIGN.md's Dungeon section (the Abyss, islands, bridges, gates, the fall), docs/props.md
  "Dungeon world props" and the portal, CLAUDE.md asset lines (`build_dungeon_world.py`, `PortalDungeon`) and the test
  list (`AbyssLayout`).
- [ ] **Step 3: Full Studio pass:** the whole run start to finish (`/puzzle solve` to move fast), the Hydra's door's
  eyes lighting and opening, a fall, Output free of errors; then tell the owner exactly what to judge.
