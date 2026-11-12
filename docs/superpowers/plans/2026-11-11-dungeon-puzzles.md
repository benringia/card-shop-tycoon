# Dungeon Puzzles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Dungeon run into fight → prism beams → fight → weight plates (secret wall) → pylon fight → element
lock → Prism Hydra, in crystal-grown temple ruins, with puzzle chests, a secret chest and a Meshy Prism Hydra.

**Architecture:** The run's order becomes data (`Config/Dungeon.STEPS`); `DungeonService` keeps the run and its fights
and asks `DungeonRules` whether a gate may open. A new `DungeonPuzzleService` owns the three puzzles, the secret wall
and the chests, with server-side ProximityPrompts and state published as part attributes that a new client
`DungeonPuzzleController` draws. Puzzle logic lives in pure, Lune-tested modules (`BeamRules`, `PlateRules`,
`LockRules`); the pylons are a new list in `BattleSim` that blocks damage to their side until swords break them.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests, Blender MCP + Meshy (props, Hydra).

**Spec:** `docs/superpowers/specs/2026-11-11-dungeon-puzzles-design.md` (owner "go" 2026-11-11). Older context:
`docs/superpowers/specs/2026-10-29-dungeon-final-boss-design.md`.

## Global Constraints

- Server authoritative: clients only trigger server-side ProximityPrompts (and sword actions already checked by
  BattleService). Every prompt handler checks: run member, not out, the piece belongs to the current step, distance
  rechecked on the server, `RateLimiter` cooldown.
- All tunable numbers in `src/shared/Config/Dungeon.luau` (no magic numbers in services). Pure logic in
  `src/shared/Util` modules with no requires (Lune).
- Cash/XP only through `EconomyService`; items through `ItemService.GiveItem`.
- Every new file `--!strict`; text plain ASCII plus `·` and emoji; tap targets ≥ 48 px; mobile-first.
- Saved shape change: `SCHEMA_VERSION` 18 → 19, migration `[18]` with a Lune test, DESIGN.md 10.4.
- Phones: few real lights, glow with Neon/emission; re-measure frame time (`town-design-perf-rules`).
- The run order (spec): fight 1 → beams → fight 2 → plates (secret wall) → fight 3 with 3 pylons → element lock → Hydra.
- Puzzles: solvable alone, 2-4 players, no reading needed, 30-90 s, a wrong move only resets, never hurts or ends
  the run.
- Never edit synced scripts in Studio. Commit only after the owner confirms in Studio (CLAUDE.md Workflow); the boss
  chests and the immersion round are still uncommitted on main: ask the owner to check and commit those first.
- After client edits: compile check (`lune run <scratchpad>/compile_check.luau <files>`, Lune never parses
  `src/client`) and VS Code diagnostics.

## Review Focus

1. A player who goes out or leaves while their creature holds a plate: the plate releases and the plates needed drop
   to what the players left can cover (`PlateRules.needed`), so the run never gets stuck.
2. A fight gate or the chamber gate triggered before the step before it is done (an exploiter walking through a closed
   door): refused (`DungeonRules.canStartRoom`, `chamberOpen`).
3. A chest opened twice in a run by the same player, or a prompt used by someone out, a latecomer or a non-member:
   ignored (`DungeonRules.once`, `canAct`).
4. A beam that bounces round a loop of mirrors: the trace stops (visited cell+direction), never hangs the server.
5. Room 3 lost or timed out with pylons half broken: the next try starts with all 3 pylons whole, and a creature-only
   player (no sword) can still win by waiting for the others' swords (solo: everyone has a sword at shop level 57).

---

### Task 1: The run's steps (config + rules)

**Files:**
- Modify: `src/shared/Config/Dungeon.luau`, `src/shared/Util/DungeonRules.luau`
- Test: `tests/Dungeon.spec.luau`, `tests/DungeonRules.spec.luau`

**Interfaces:**
- Produces (Config/Dungeon): `STEPS = { {kind="fight",room=1}, {kind="beams"}, {kind="fight",room=2}, {kind="plates"},
  {kind="fight",room=3}, {kind="lock"} }`; `ROOMS[3].pylons = { count = 3, hp = 900 }` (hp tuned in Task 9);
  `BEAMS = { TURN_COOLDOWN = 0.4, CELL = 8, LAYOUTS = {...} }` (Task 2 fills LAYOUTS);
  `PLATES = { CHECK_EVERY = 0.25, SOLO = 2, GROUP = 3, GROUP_FROM = 3, SIZE = 8 }`;
  `LOCK = { STRIKE_COOLDOWN = 0.4 }`; `SECRET = { TAPS = 3, TAP_COOLDOWN = 0.5, TITLE = "Crystal Seeker",
  MATERIAL = "material_prismHydra", MATERIAL_CHANCE = 0.25, CASH = 250 }`; `CHEST = { DISTANCE = 10, SCALE = 0.6 }`;
  `CRYSTAL_LOOK = { shards = 4, glow = 0.25 }`; `STAGES` names for the run line: beams "Prism beams", plates
  "Weight plates", lock "Element lock".
- Produces (DungeonRules, pure):
  - `canStartRoom(steps, done: number, room: number): boolean` — true only when `steps[done + 1]` is that room's fight
  - `chamberOpen(steps, done: number): boolean` — `done >= #steps`
  - `stepKind(steps, done: number): string` — the current step's kind, "boss" past the last
  - `doneBefore(steps, room: number): number` — steps done when /room skips to room n's gate (rooms + 1: all)
  - `canAct(isMember: boolean, isOut: boolean): boolean`
  - `once(opened: { [number]: boolean }, userId: number): boolean` — true and marks the first time only
  - `secretPrize(foundBefore: boolean, roll: number, chance: number): "title" | "material" | "cash"`

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/DungeonRules.spec.luau
["steps: a room's gate opens only when its fight is the next step"] = function()
	local steps = Dungeon.STEPS
	expect.equal(DungeonRules.canStartRoom(steps, 0, 1), true, "room 1 first")
	expect.equal(DungeonRules.canStartRoom(steps, 1, 2), false, "beams not solved")
	expect.equal(DungeonRules.canStartRoom(steps, 2, 2), true, "after the beams")
	expect.equal(DungeonRules.canStartRoom(steps, 5, 3), false, "room 3 already won")
	expect.equal(DungeonRules.chamberOpen(steps, 5), false, "lock not solved")
	expect.equal(DungeonRules.chamberOpen(steps, 6), true, "all done")
	expect.equal(DungeonRules.stepKind(steps, 1), "beams", "after fight 1")
	expect.equal(DungeonRules.stepKind(steps, 6), "boss", "past the last")
end,
["doneBefore: /room n lands at its fight; 4 is the chamber"] = function()
	expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 1), 0, "room 1")
	expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 3), 4, "room 3 after plates")
	expect.equal(DungeonRules.doneBefore(Dungeon.STEPS, 4), 6, "chamber")
end,
["canAct and once: members not out, each player once"] = function()
	expect.equal(DungeonRules.canAct(true, false), true, "member")
	expect.equal(DungeonRules.canAct(true, true), false, "out")
	expect.equal(DungeonRules.canAct(false, false), false, "not in the run")
	local opened = {}
	expect.equal(DungeonRules.once(opened, 7), true, "first")
	expect.equal(DungeonRules.once(opened, 7), false, "second")
	expect.equal(DungeonRules.once(opened, 8), true, "another player")
end,
["secretPrize: title first, then 25% material, else cash"] = function()
	expect.equal(DungeonRules.secretPrize(false, 0.99, 0.25), "title", "first find")
	expect.equal(DungeonRules.secretPrize(true, 0.1, 0.25), "material", "lucky")
	expect.equal(DungeonRules.secretPrize(true, 0.5, 0.25), "cash", "not")
end,
```

```lua
-- tests/Dungeon.spec.luau
["steps: the owner's order, three fights, room 3 has 3 pylons"] = function()
	local kinds = {}
	for _, step in Dungeon.STEPS do table.insert(kinds, step.kind) end
	expect.equal(table.concat(kinds, ","), "fight,beams,fight,plates,fight,lock", "order")
	expect.equal(Dungeon.ROOMS[3].pylons.count, 3, "pylons")
	expect.equal(Dungeon.SECRET.TITLE, "Crystal Seeker", "title")
	expect.equal(Dungeon.SECRET.MATERIAL_CHANCE, 0.25, "material chance")
end,
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL on the new tests (`canStartRoom` nil, `STEPS` nil).
- [ ] **Step 3: Implement** the config values and the seven functions above (DungeonRules stays require-free; it gets
  `steps` passed in).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 2: Prism beams (pure)

**Files:**
- Create: `src/shared/Util/BeamRules.luau`, `tests/BeamRules.spec.luau`
- Modify: `src/shared/Config/Dungeon.luau` (`BEAMS.LAYOUTS`), `tests/run.luau`

**Interfaces:**
- Layout type: `{ width: number, height: number, gem: { x: number, y: number, dir: number }, prism: { x: number, y: number },
  mirrors: { { x: number, y: number, facing: number } } }` — cells 1-based, `dir`/`facing` 0..3 = +x, +y, -x, -y.
- `BeamRules.trace(layout, facings: { number }): { path: { { x: number, y: number } }, reached: boolean }`
- `BeamRules.turn(facing: number): number` — `(facing + 1) % 4`
- `BeamRules.solvable(layout): boolean` — brute force over 4^#mirrors

Algorithm (not fixed by the tests alone): a mirror with facing f connects sides f and (f+1)%4 of its cell (side s
lies in direction s from the centre). The beam leaves the gem in `gem.dir`; entering a cell travelling direction d it
comes in through side (d+2)%4. In a mirror cell: in through side f → travel (f+1)%4; in through (f+1)%4 → travel f;
any other side: the beam stops there (it hit the mirror's back). Out of the grid: stops at the last cell. Reaching the
prism's cell: `reached = true`. A repeated (cell, direction) stops the trace (the gem's own cell and `gem.dir` count
as visited from the start). `path` starts with the gem's cell.

- [ ] **Step 1: Write the failing tests** (`tests/BeamRules.spec.luau`, registered in `tests/run.luau`):

```lua
["trace: a straight beam reaches a prism in line"] = function()
	local layout = { width = 5, height = 1, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 5, y = 1 }, mirrors = {} }
	local out = BeamRules.trace(layout, {})
	expect.equal(out.reached, true, "reached")
	expect.equal(#out.path, 5, "every cell")
end,
["trace: a mirror turns the beam; its back stops it"] = function()
	local layout = { width = 3, height = 3, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 3, y = 3 },
		mirrors = { { x = 3, y = 1, facing = 1 } } }
	-- in through side 2 (-x); facing 2 connects sides 2 and 3 -> travels -y, off the grid
	expect.equal(BeamRules.trace(layout, { 2 }).reached, false, "wrong facing")
	-- facing 1 connects sides 1 and 2: in through 2, out toward +y, down to the prism
	expect.equal(BeamRules.trace(layout, { 1 }).reached, true, "right facing")
	expect.equal(BeamRules.trace(layout, { 0 }).reached, false, "back of the mirror stops it")
end,
["trace: a loop of mirrors ends"] = function()
	-- gem (2,1) east -> (3,1) south -> (3,2) west -> (2,2) -> (1,2) north -> (1,1) east -> back at the gem going east
	local layout = { width = 3, height = 2, gem = { x = 2, y = 1, dir = 0 }, prism = { x = 9, y = 9 },
		mirrors = { { x = 3, y = 1, facing = 1 }, { x = 3, y = 2, facing = 2 }, { x = 1, y = 2, facing = 3 }, { x = 1, y = 1, facing = 0 } } }
	local out = BeamRules.trace(layout, { 1, 2, 3, 0 })
	expect.equal(out.reached, false, "no prism, no hang")
	expect.equal(#out.path <= 3 * 2 * 4, true, "stopped on the repeat")
end,
["layouts: three, 4 mirrors each, not solved at the start, solvable"] = function()
	expect.equal(#Dungeon.BEAMS.LAYOUTS, 3, "three")
	for index, layout in Dungeon.BEAMS.LAYOUTS do
		expect.equal(#layout.mirrors, 4, `layout {index} mirrors`)
		local start = {}
		for i, mirror in layout.mirrors do start[i] = mirror.facing end
		expect.equal(BeamRules.trace(layout, start).reached, false, `layout {index} unsolved at start`)
		expect.equal(BeamRules.solvable(layout), true, `layout {index} solvable`)
	end
end,
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `BeamRules` and three hand-made layouts (grids up to 6x5, every mirror needed on the
  solution path, each solution 2+ turns away from the start).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 3: Plates and the element lock (pure)

**Files:**
- Create: `src/shared/Util/PlateRules.luau`, `src/shared/Util/LockRules.luau`, `tests/PlateRules.spec.luau`,
  `tests/LockRules.spec.luau`; Modify: `tests/run.luau`

**Interfaces:**
- `PlateRules.count(runSize: number, config): number` — `config.SOLO` (2) below `GROUP_FROM` (3), else `GROUP` (3)
- `PlateRules.needed(plates: number, active: number): number` — `math.min(plates, 2 * active)`
- `PlateRules.inside(box: { x: number, z: number, half: number }, point: { x: number, z: number }): boolean`
- `PlateRules.open(held: { boolean }, needed: number): boolean` — the first `needed` plates all held
- `LockRules.order(phases: { { element: string } }): { string }`
- `LockRules.strike(progress: number, element: string, order: { string }): (number, "right" | "wrong" | "done")`

- [ ] **Step 1: Write the failing tests:**

```lua
-- tests/PlateRules.spec.luau
["count: 2 alone or in pairs, 3 for 3-4"] = function()
	expect.equal(PlateRules.count(1, Dungeon.PLATES), 2, "solo")
	expect.equal(PlateRules.count(2, Dungeon.PLATES), 2, "pair")
	expect.equal(PlateRules.count(4, Dungeon.PLATES), 3, "four")
end,
["needed: never more than the players left can cover"] = function()
	expect.equal(PlateRules.needed(3, 4), 3, "full group")
	expect.equal(PlateRules.needed(3, 1), 2, "one left: self + creature")
	expect.equal(PlateRules.needed(2, 0), 0, "nobody")
end,
["open: the first `needed` plates held"] = function()
	expect.equal(PlateRules.open({ true, true, false }, 2), true, "third dimmed")
	expect.equal(PlateRules.open({ true, false, true }, 2), false, "second up")
	expect.equal(PlateRules.inside({ x = 0, z = 0, half = 4 }, { x = 3.9, z = -3 }), true, "on it")
	expect.equal(PlateRules.inside({ x = 0, z = 0, half = 4 }, { x = 4.5, z = 0 }), false, "off it")
end,
```

```lua
-- tests/LockRules.spec.luau
["order: the Hydra's phases"] = function()
	expect.equal(table.concat(LockRules.order(Bosses.BOSSES.prismHydra.phases), ","), "Tide,Volt,Shade,Bloom,Ember", "order")
end,
["strike: right steps on, wrong resets, fifth is done"] = function()
	local order = { "Tide", "Volt", "Shade", "Bloom", "Ember" }
	expect.equal(select(2, LockRules.strike(0, "Tide", order)), "right", "first")
	local progress, result = LockRules.strike(2, "Ember", order)
	expect.equal(progress, 0, "reset"); expect.equal(result, "wrong", "wrong")
	expect.equal(select(2, LockRules.strike(4, "Ember", order)), "done", "last")
end,
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (modules missing).
- [ ] **Step 3: Implement** both modules.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 4: Pylons in the fight sim

**Files:**
- Modify: `src/server/Util/BattleSim.luau`; Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- `SideInput.pylons: { { id: string, hp: number } }?` (side B in Dungeon room 3)
- `BattleSim.swordHit(state, owner, targetId, ...)` accepts a pylon id: the sword's power hits the pylon (no perks,
  no element), events `{ type = "pylonHit", to = id, amount = n }`, `{ type = "pylonBroken", to = id }`, and after the
  last one `{ type = "shieldDown" }`
- While any pylon of a side stands, damage to that side's fighters is 0 (in `guarded`), the hit event carries
  `shielded = true`; pylons never attack, are never a creature's target, never count for "side beaten"
- `BattleSim.pylonsLeft(state, sideName: string): number`

- [ ] **Step 1: Write the failing tests** (in `tests/BattleSim.spec.luau`, with the file's existing helpers):
  `"pylons: the pack takes no damage while one stands"` (creature hits a pack monster with pylons up → monster HP
  unchanged, event `shielded`); `"pylons: sword hits break them, then the shield is down"` (3 `swordHit`s on each
  pylon id at hp ≤ power → `pylonsLeft` 0, a `shieldDown` event, a later creature hit lowers the monster's HP);
  `"pylons: not targets, not counted"` (a step with only pylons standing on side B ends the fight as won for A).
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL on the three.
- [ ] **Step 3: Implement** in `BattleSim` (pylons kept in `side.pylons`, outside `side.fighters`).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass (every old BattleSim test too).

### Task 5: Crystal Seeker (save flag and title)

**Files:**
- Modify: `src/shared/Config/Data.luau` (19), `src/server/Util/Migrations.luau` (`[18]`), `src/server/Services/DataService.luau`
  (TEMPLATE `dungeon = { secretFound = false }`), `src/shared/Util/BossRules.luau`, `src/server/Services/BossService.luau`
- Test: `tests/Migrations.spec.luau`, `tests/BossRules.spec.luau`

**Interfaces:**
- `BossRules.pickTitle(clearTitle: string?, secretFound: boolean, secretTitle: string): string?` — the clear title
  wins, else the secret title when found, else nil
- `BossService.MarkSecretFound(player: Player): boolean` — true the first time (sets the saved flag, refreshes the
  `Title` attribute); `BossService.HasFoundSecret(player: Player): boolean`. BossService's load/save read and write
  `data.dungeon.secretFound` (save does nothing if never loaded).

- [ ] **Step 1: Write the failing tests:** Migrations `"v19: dungeon.secretFound added, false"` (a v18 save run to 19
  gains `dungeon = { secretFound = false }`, keeps a present `true`); BossRules `"pickTitle: Conqueror outranks Crystal
  Seeker"` (`("Dungeon Conqueror", true, "Crystal Seeker")` → Conqueror; `(nil, true, ...)` → Crystal Seeker;
  `(nil, false, ...)` → nil).
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL on both.
- [ ] **Step 3: Implement** the bump, the migration, the template field, `pickTitle`, and use it in BossService's
  `setTitle`; add the two BossService functions.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 6: The longer cavern with stand-in pieces

**Files:**
- Modify: `src/server/Util/DungeonBuilder.luau`, `src/shared/Config/Dungeon.luau` (section lengths, `CHAMBER`),
  `src/server/Services/WildService.luau` (builds with the chosen beam layout)

**Interfaces:**
- `DungeonBuilder.build(parent: Instance, beamLayout: number): DungeonLayout`
- `DungeonLayout` gains: `beams: { gem: BasePart, mirrors: { BasePart }, prism: BasePart, door: BasePart, chestSpot: CFrame }`,
  `plates: { plates: { BasePart }, door: BasePart, wall: BasePart, alcove: CFrame, chestSpot: CFrame, secretSpot: CFrame }`,
  `lock: { crystals: { [string]: BasePart }, sockets: { BasePart }, door: BasePart, chestSpot: CFrame }`;
  `Room.pylons: { BasePart }` (room 3 only, 3 parts named `Pylon1..3`), `Room.shield: BasePart?`
- Pieces are named for clients: `BeamGem`, `Mirror1..4` (attribute `Facing`), `DoorPrism`, `Plate1..3`, `SecretWall`,
  `LockCrystal_<Element>`, `LockSocket1..5`, `PuzzleDoor_<kind>`.
- Stand-ins are blocks in the look's colours until Task 11's props exist (`ReplicatedStorage.PropModels:FindFirstChild`).

- [ ] **Step 1:** Lay out hall → room 1 → beam room → room 2 → plate room (secret alcove off its +Z side) → room 3
  (pylons at 120° round its ring, a shield sphere round the pack spot) → lock room → chamber, each section behind a
  door, from `STEPS` order. `CHAMBER.x` recomputed from the lengths (keep the existing `tests/Dungeon.spec.luau` layout
  checks passing or update them to the new lengths).
- [ ] **Step 2: Run** `lune run tests/run` and `rojo build -o <scratchpad>/test.rbxl` — Expected: pass, builds.
- [ ] **Step 3:** Studio (Dungeon window, `rojo serve dungeon.project.json`): Play, screenshot each section from above;
  Output has no errors.

### Task 7: The run walks the steps

**Files:**
- Modify: `src/server/Services/DungeonService.luau`, `src/client/Controllers/DungeonController.luau`,
  `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau`, `src/shared/Remotes.luau`
- Test: `tests/AdminPanel.spec.luau`

**Interfaces:**
- `Run.done: number` (steps done) replaces `cleared` as the gate source; `cleared` stays as rooms won for the run line.
- `DungeonService.CompleteStep(kind: string)` — the current step is done: opens its door, `sendAll`, tells
  `DungeonPuzzleService.Open(nextKind)` when the next one is a puzzle.
- `onRoomGate` uses `DungeonRules.canStartRoom`; `onChamberGate` uses `chamberOpen`; a won fight calls `CompleteStep("fight")`.
- `DungeonRun` payload `stage` gains "beams" | "plates" | "lock"; the run line shows `Dungeon.STAGES[stage]`.
- Dev: `/room <2-4>` uses `doneBefore`; new `/puzzle solve` (Studio only) solves the current puzzle; AdminPanel
  Dungeon section gets a "Solve puzzle" button (and its test).

- [ ] **Step 1: Write the failing test:** AdminPanel `"dungeon: a Solve puzzle button runs /puzzle solve"`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL.
- [ ] **Step 3: Implement** the above.
- [ ] **Step 4: Run** `lune run tests/run` + compile check of the client file — Expected: pass, no errors.

### Task 8: DungeonPuzzleService and the client (beams, plates, secret wall, lock, chests)

**Files:**
- Create: `src/server/Services/DungeonPuzzleService.luau`, `src/client/Controllers/DungeonPuzzleController.luau`
- Modify: `src/server/Services/PartyService.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`,
  `src/shared/Remotes.luau`

**Interfaces:**
- `DungeonPuzzleService.Start(layout, hooks: { canAct: (Player) -> boolean, active: () -> { Player }, runSize: () -> number,
  solved: (kind: string) -> () })` (DungeonService passes its own checks: no circular require)
- `DungeonPuzzleService.Open(kind: string)`, `DungeonPuzzleService.Solve(kind: string)` (dev)
- `PartyService.SetPost(player: Player, cframe: CFrame?)` — the summoned creature's marker walks there and stays
  (nil: follows again); released on resummon/unsummon; `PartyService.GetMarker` gives its position for the plates.
- State for clients as attributes: mirror `Facing`; `BeamGem` `Path` ("x,y;x,y;...") and `Reached`; plate `Held`,
  `Needed`; `SecretWall` `Taps`, `Open`; `LockSocket<n>` `Lit`; lock room `Wrong` (a counter, flashes red);
  `PuzzleDoor_<kind>` `Open`; chests `Shown`.
- Remote `DungeonChest` (server → client): `{ kind = "puzzle" | "secret", cash: number?, xp: number?, item: string?,
  count: number?, title: string? }` — your chest's lid opens and the item popup shows (Util/ItemPopupRules).
- Puzzle chest pay: the previous fight room's pay (sum of `CombatMath.getRewards(Wild, level, true)` over its
  `count`): cash via `EconomyService.AddCash`, the XP as shop XP via `EconomyService.AddXP`.
- Secret chest: `DungeonRules.secretPrize(BossService.HasFoundSecret(player), rng, Dungeon.SECRET.MATERIAL_CHANCE)`;
  "title" → `BossService.MarkSecretFound`; "material" → `ItemService.GiveItem(player, SECRET.MATERIAL, 1)`; "cash" →
  `AddCash(SECRET.CASH)`.

- [ ] **Step 1:** Beams: "Turn" prompt per mirror (`BEAMS.TURN_COOLDOWN` per player) → `BeamRules.turn`, retrace,
  publish; reached → solved. Client draws the beam as neon segments along `Path` with a sparkle at its end.
- [ ] **Step 2:** Plates: a 0.25 s loop reads members' root positions and posted creature markers, `PlateRules`
  decides; plates past `needed` dim; open latches. "Send <creature>" prompt on each plate (posts your creature there;
  tap again to call it back); a player out or leaving releases their post.
- [ ] **Step 3:** Secret wall: "Break" prompt, `SECRET.TAPS` taps total (shared), `TAP_COOLDOWN` per player, the
  character plays its sword's cut; opens the alcove; its chest opens once per member (`DungeonRules.once`).
- [ ] **Step 4:** Lock: "Strike" prompt per crystal (`LOCK.STRIKE_COOLDOWN`), `LockRules.strike` on the shared
  progress; sockets light; wrong flashes; done → solved.
- [ ] **Step 5:** Chests: on each solved puzzle a chest (Util/ChestModel's model, `CHEST.SCALE`) at its `chestSpot`
  with an "Open" prompt; each member once (`DungeonRules.once` keyed by UserId).
- [ ] **Step 6: Run** `lune run tests/run` + compile check of the client files — Expected: pass.
- [ ] **Step 7:** Studio: solo through all three puzzles with `/room` and `/puzzle solve` only for skipping fights;
  screenshots of each; Output clean. Two-player check (Local Server, 2 players): both turn mirrors, plates with two
  players, each opens their own chest.

### Task 9: The pylon fight

**Files:**
- Modify: `src/server/Services/BattleService.luau`, `src/server/Services/DungeonService.luau`,
  `src/client/Controllers/DungeonPuzzleController.luau` (pylon and shield looks), `tools/balance/bosses.luau` (room 3)

**Interfaces:**
- `RunOptions` gains `swords: boolean?` and `pylons: { { id: string, hp: number, position: Vector3 } }?`; DungeonService
  passes both for room 3 (`ROOMS[3].pylons`).
- `fightsWithSword(player, boss, run, swords)`: `boss or ((swords or not run) and has a sword)`.
- `swordTargets` lists the standing pylons (from `fight.pylons`) while any stands, else the pack; `strike` routes a
  pylon target to `BattleSim.swordHit`. Pack foes in a swords room get `CombatMath.getMonsterAttacks(Wild, true)`.
- Server sets `Broken` on each `Pylon<n>` part and `Down` on the room's shield on the sim's events (clients draw the
  beams, flicker and shatter from them); attributes reset when the room's fight ends.

- [ ] **Step 1:** Implement; a lost or timed-out room 3 resets the pylons' attributes.
- [ ] **Step 2: Run** `lune run tests/run` + compile check — Expected: pass.
- [ ] **Step 3:** Studio: room 3 solo: "Shielded!" on the pack until the pylons fall, then normal hits.
- [ ] **Step 4:** `lune run tools/balance/bosses 200 1 7` — tune `ROOMS[3].pylons.hp` so a player fighting well breaks
  all 3 in about 15 s and the Hydra is still reached about as often as before (78-89% HP left).

### Task 10: The crystal ruins (props pack)

**Files:**
- Create: `tools/blender/build_dungeon_props.py`, `assets/blender/DungeonProps/` (concept_look.png, .blend, FBX)
- Modify: `src/server/Util/DungeonBuilder.luau` (props in place of stand-ins), `src/shared/Config/Dungeon.luau`
  (`LIGHTING`, colours), `docs/props.md`

- [ ] **Step 1:** Blender (MCP, on the valley-props kit): pillars (whole, broken), broken arch, wall pieces, floor slabs,
  steps, crystal clusters ×5 element colours, rune brazier; puzzle pieces: beam gem, mirror on stand, door prism, stone
  plate, pylon, element crystal, lock door with 5 sockets, cracked wall, alcove. Render a look check against
  `concept_look.png` and show the owner.
- [ ] **Step 2 (owner):** import the pack FBX once, save `assets/props-import/DungeonProps.rbxm`; then
  `lune run tools/props/split_pack assets/props-import/DungeonProps.rbxm` → `assets/props/<Name>.rbxm`.
- [ ] **Step 3:** DungeonBuilder places them (`Props.place`, stand-in when missing); lighting cool indigo with rainbow
  crystal glow, few PointLights. Studio screenshots of every section; frame time measured (`rbx-perf-profiling`).

### Task 11: Crystal monsters

**Files:** Modify: `src/client/Controllers/MonsterController.luau`

- [ ] **Step 1:** In the Dungeon only, each pack monster's model gets `CRYSTAL_LOOK.shards` rainbow crystal shards on
  its back (Neon wedges welded to its torso bone/part) and a soft rainbow Highlight at `CRYSTAL_LOOK.glow`.
- [ ] **Step 2:** Compile check; Studio screenshot of a room's pack.

### Task 12: The new Prism Hydra (Meshy)

**Files:**
- Create: `assets/blender/PrismHydra/concept_B.png`, `tools/blender/prep_prismHydra.py`, `tools/blender/rig_prismHydra.py`,
  `tools/blender/anim_prismHydra.py`; Modify: `assets/monsters/prismHydra.rbxm`, `src/shared/Config/Party.luau`
  (style/signature if needed), `docs/creatures.md`

- [ ] **Step 1:** Meshy image-to-3D from `concept_B.png` (one generation; ask the owner before any second). Prep:
  straighten, scale to about 25 studs at game scale, a few thousand triangles.
- [ ] **Step 2:** Rig: body, tail chain, five neck chains with head and jaw bones named for `PetRig` and today's head
  order (`Bosses.prismHydra.heads`); clips (idle, attack, roar, hit, faint) by `anim_prismHydra.py`, built with
  `lune run tools/anim/build_bone_clips prismHydra`.
- [ ] **Step 3 (owner):** import the FBX (Rig Type Custom, Keep Zero Influence Bones), save over
  `assets/monsters/prismHydra.rbxm`.
- [ ] **Step 4:** Phase glow: a glow sphere + light on each head bone, the phase's one lit (marker attribute `Phase`);
  rune lines: a glow map of the bright rune pixels baked like the weapons' (`tools/textures/make_glow_maps.py`,
  `lune run tools/weapons/add_glow_maps` pattern); first check in Studio whether a script may set the SurfaceAppearance
  emissive tint to the phase colour, else colour today's `rainbowAura` Highlight by phase.
- [ ] **Step 5:** Studio: `/room 4`, fight, screenshot each phase.

### Task 13: Docs, perf, owner check

**Files:** `DESIGN.md` (5.10 Dungeon, 10.4 schema 19, file tree), `CLAUDE.md` (test list: BeamRules, PlateRules,
LockRules; `/puzzle solve`), `docs/props.md`, `docs/creatures.md`, memory + Obsidian vault.

- [ ] **Step 1:** `lune run tests/run` — Expected: all pass.
- [ ] **Step 2:** Full run in the Dungeon window (solo) and a 2-player Local Server run; frame time per section.
- [ ] **Step 3:** Tell the owner exactly what to judge; after their OK: tick DESIGN.md, commit, push.
