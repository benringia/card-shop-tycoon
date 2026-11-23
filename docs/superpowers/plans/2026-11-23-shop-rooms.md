# Shop Rooms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every shop becomes the same 50 x 60 building: a 50 x 40 main hall open from the start and two rooms (Back
Room, Gallery) behind locked doors that the owner unlocks for more floor, one more customer and 5 more shelves.

**Architecture:** All room geometry and rules live in a Roblox-free `Util/ShopRooms` over plain data in
`Config/ShopRooms` (cells, doors, walls, the walls' faces inside open space, window stretches, caps, unlock checks).
`PlotService` builds the inner walls, doors, signs, lights and invisible placement blockers from it, and dresses every
open wall face with the shop's look. A new `RoomService` owns the saved `rooms` list and the `UnlockRoom` remote. The
caps read the plot's open rooms. Save v42 moves every old 40 x 40 layout into the wider hall, and windows learn wall
stretches (`spans`) instead of fixed wall lengths.

**Tech Stack:** Luau (`--!strict`), Rojo (main `rojo serve` already running: background shell bskq95get, never
restarted), Lune tests (`lune run tests/run [Spec]`), `@lune/roblox` for the TownDecor tool, Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-11-23-shop-rooms-design.md` (approved 2026-11-23, commit 18010e1)

## Global Constraints

- Server authoritative: `UnlockRoom(roomId)` is declared in `src/shared/Remotes.luau`; the server checks the type, a
  known room, ownership, distance to the door, `Util/RateLimiter`, level and cash. Prices come from config only.
- Cash only through EconomyService (`TrySpend`, `AddCash`).
- Every refusal goes through server `Util/Blocked` (`Blocked.tell`); the door prompt carries `RequireLevel`.
- Owner-only prompts are created on the owner's client for the owner's own plot.
- Tunable numbers in `src/shared/Config`; rules both sides need in Roblox-free `src/shared/Util` with Lune tests; pure
  modules don't require siblings; configs a test reads are plain data. `Config/Plots` holds Vector3 / Color3, so Lune
  tests can't load it: tests pass plot numbers as literals (as `TownLayout.spec` does).
- Saved shape: `SCHEMA_VERSION` 41 -> 42, `MIGRATIONS[41]` with a Lune test, the DataService template and type,
  DESIGN.md 10.4. Never lose a placed thing, its stock or a window.
- Text: plain ASCII plus `·` and emoji; Fredoka/Montserrat via `Util/FontStyle`. Tap targets at least 48 px.
- Numbers from the spec (the exact ones):
  - Plot 50 x 60 (`WIDTH 50`, `DEPTH 60`, `GAP 14`); hall 50 x 40; hall's back wall in studs 40..42 from the street;
    Back Room x 0..24, Gallery x 26..50, both z 42..60 (24 x 18 usable); wall between the rooms x 24..26.
  - Doors 8 wide, 10 high: Back Room x 12..20, Gallery x 30..38; clear paths 8 x 4 in front of and just inside each.
  - Register 5 studs from the left wall, 6 in front of the hall's back wall; queue strip 18 (`QUEUE_ZONE_LENGTH`).
  - Customers 4 + 1 per open room; shelves 30 + 5 per open room; decor 20; `MAX_EDIT_DISTANCE` 50.
  - Placeholders: Back Room shop Lv 15, $5,000; Gallery Lv 30, $20,000.
  - Town: `BOUNDS.HALF_Z` 112, `WALK_EDGE` z +-110 -> +-112; plot centres x -64, 0, 64 and fronts z +-48 unchanged.
  - Words: "Back Room unlocked! More floor and one more customer." (and the Gallery's).
- Studio: only the owner's test save (Studio key `<prefix><userId>_studio`, chosen by `/slot test`); never the main
  save. Reading the place is fine; ask before changing it; never stop a Play session the owner started; check the Edit
  data model's Source before Play.
- Work on the local branch `shop-rooms` in this folder (not a worktree: Rojo serves this folder). Commit per task on the
  branch; nothing goes to main or GitHub before the owner's OK. Never add the untracked
  `assets/blender/{Pish,Chikin,Turts}/*_preview_*.png` / `*_pose_*.png`, `assets/blender/Register/RegisterBody_preview.png`,
  `assets/ui/round5-candidates`, `assets/ui/store`, `assets/ui/loading/pish_walk_frames`.
- No helper agents (owner rule): the final review is a self-review. No paid credits (Meshy, Figma AI).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Client files: Lune never parses them. After client edits run the compile check
  (`lune run <scratchpad>/compile_check.luau src`; if the scratchpad was cleared, recreate it: walk the folders given
  and `pcall(luau.compile, fs.readFile(path))` every `.luau`, print failures and a count) and `getDiagnostics` for
  "Undefined global". BinderController and BattleController are at the 200-local limit: untouched here.

## Review Focus

1. A turned or wide shelf in an old layout (a Big Display Rack across the old middle, a rack turned by a wall): it
   must land by the right wall or centred by its real turned width (Task 4 test "a turned rack uses its turned width").
2. A back window with no free spot left on the hall's side walls: paid back in full, not dropped (Task 3 test "a back
   window with no room left is paid back").
3. Unlocking an open room, or pressing twice: never charged twice (Task 1 test "unlocking ... open already"; Task 6
   step: the check, `TrySpend` and the list insert run with no yield between them).
4. Door paths and the wall cells stay unplaceable whether a room is open or locked, and a saved shelf on them moves
   on load (Task 1 test "walls, door paths and locked rooms are never placeable"; Task 5 Studio check on the moved
   save).
5. Nobody can walk behind the shops: the hedge stands within 1 stud of every back wall (Task 2 test "the hedge stands
   right behind the shops").

---

## Pre-flight (before Task 1)

- [ ] **Branch:** `git checkout -b shop-rooms` (from main at 18010e1). Expected: `Switched to a new branch 'shop-rooms'`.
- [ ] **Baseline:** `lune run tests/run` -> Expected: `2513 passed, 0 failed` (or today's count, 0 failed). Note the count.
- [ ] **Studio save slot:** with the Studio MCP, read the stored slot (read-only, Server or Edit data model):
  `DataStoreService:GetDataStore(<Config/Data SLOT_STORE>):GetAsync(tostring(ownerUserId))`. Expected `test = true`.
  If not, stop and ask the owner to type `/slot test` in Studio and rejoin (a v42 save must never be the main one).
- [ ] **Old layout snapshot:** the owner's `_studio` save is still v41 (today's code). In Play (if the owner isn't
  playing), read every shelf part's `ShelfId`, `GridX`, `GridZ`, `Rotation` and the `OrderComputer`'s cell, and the
  `Windows` folder's `Style/Side/At` attributes into the ledger; screenshot the shop from the door. Stop Play.

---

### Task 1: Shop room rules (`Config/ShopRooms`, `Util/ShopRooms`)

**Files:**
- Create: `src/shared/Config/ShopRooms.luau`, `src/shared/Util/ShopRooms.luau`, `tests/ShopRooms.spec.luau`
- Modify: `tests/run.luau` (register `ShopRooms = require("./ShopRooms.spec")`)

**Interfaces:**
- Produces (types exported from `Util/ShopRooms`):
  - `Open = { [string]: boolean }`, `Rect = { x: number, z: number, w: number, d: number }` (cells, PlacementGrid's
    counting: x from the floor's left edge, z from the street), `Grid = { cellsX: number, cellsZ: number, size: number }`
  - `Blocker = { name: string, room: string?, rect: Rect }`
  - `Hole = { from: number, to: number, top: number }` (along a wall, from the floor up to `top`)
  - `Wall = { name: string, axis: "x" | "z", at: number, from: number, to: number, holes: { Hole } }`
  - `Run = { side: string, axis: "x" | "z", at: number, from: number, to: number, inward: number, holes: { Hole } }`
    (`side`: "left" | "right" | "back" (the hall's back face) | "inner" | "outerBack")
  - `Door = { room: string, part: string, x: number, z: number, width: number, height: number, slide: number }`
  - `Span = { from: number, to: number, posters: boolean?, room: string?, name: string?, locked: boolean? }`
    (`name`: the room's display name, for WindowRules' "Open the Back Room first.")
  - Floor-local studs everywhere: origin the floor's centre, x across, +z toward the back (the street at -30).
- Produces (functions, `cfg` = `Config/ShopRooms`):
  - `ShopRooms.grid(width: number, depth: number, size: number): Grid`
  - `ShopRooms.clean(cfg, saved: unknown): { string }` — known ids, once each, in `cfg.ORDER`
  - `ShopRooms.openSet(list: { string }): Open`; `ShopRooms.format(list: { string }): string`;
    `ShopRooms.parse(text: unknown): Open`
  - `ShopRooms.customerCap(cfg, base: number, open: Open): number`; `ShopRooms.shelfCap(cfg, base: number, open: Open): number`
  - `ShopRooms.canUnlock(cfg, roomId: unknown, open: Open, level: number, cash: number): (boolean, string?)`
  - `ShopRooms.hallRect(cfg, grid): Rect`; `ShopRooms.roomRect(cfg, grid, roomId: string): Rect`
  - `ShopRooms.toLocal(grid, rect): (number, number, number, number)` — middle x, middle z, width, depth in studs
  - `ShopRooms.hallBack(cfg, grid): number`; `ShopRooms.hallMiddleCell(cfg, grid): (number, number)`
  - `ShopRooms.blockers(cfg, grid, open): { Blocker }`; `ShopRooms.doors(cfg, grid): { Door }`;
    `ShopRooms.innerWalls(cfg, grid): { Wall }`; `ShopRooms.runs(cfg, grid, open): { Run }`;
    `ShopRooms.windowSpans(cfg, grid, open): { [string]: { Span } }`
  - `ShopRooms.gaps(from: number, to: number, holes: { Hole }, low: number, high: number): { { from: number, to: number } }`
    — the stretches of `[from, to]` no hole covers between heights `low` and `high`

- [ ] **Step 1: Write `Config/ShopRooms`** (plain data; a header comment citing the spec and the cell counting):
  `HALL_ROWS = 20`, `WALL_ROW = 20`, `SPLIT_COLUMN = 12`, `WALL_THICK = 1`, `DOOR_HEIGHT = 10`, `DOOR_CELLS = 4`,
  `PATH_ROWS = 2`, `OPEN_SECONDS = 1.2`, `DOOR_REACH = 14`, `CUSTOMERS_PER_ROOM = 1`, `SHELVES_PER_ROOM = 5`,
  `PANEL_OFFSETS = { -6, 6 }`, `ORDER = { "backRoom", "gallery" }`,
  `ROOMS = { backRoom = { name = "Back Room", sign = "BACK ROOM", part = "BackRoomDoor", x = 0, w = 12, door = 6, slide = -1, level = 15, price = 5000 }, gallery = { name = "Gallery", sign = "GALLERY", part = "GalleryDoor", x = 13, w = 12, door = 15, slide = 1, level = 30, price = 20000 } }`
  (levels and prices commented as placeholders until table card battles, owner 2026-11-23),
  `UNLOCKED = "%s unlocked! More floor and one more customer."`,
  `SIGN = { unlit = { 75, 58, 92 }, unlitText = { 233, 223, 239 }, litText = { 90, 52, 16 } }` (lit plate: the
  shop's accent), `UNLOCK_SOUND` = the id in `Config/Luck` `WIN.SOUND` (already licensed).

- [ ] **Step 2: Write the failing tests** in `tests/ShopRooms.spec.luau`
  (`local cfg = require("../src/shared/Config/ShopRooms")`, `local GRID = ShopRooms.grid(50, 60, 2)`):

```lua
["the grid, the hall and the rooms in cells"] = function()
	expect.equal(GRID.cellsX, 25); expect.equal(GRID.cellsZ, 30)
	local hall, back, gallery = ShopRooms.hallRect(cfg, GRID), ShopRooms.roomRect(cfg, GRID, "backRoom"), ShopRooms.roomRect(cfg, GRID, "gallery")
	expect.equal(hall.w, 25); expect.equal(hall.d, 20); expect.equal(hall.x, 0); expect.equal(hall.z, 0)
	expect.equal(back.x, 0); expect.equal(back.z, 21); expect.equal(back.w, 12); expect.equal(back.d, 9)
	expect.equal(gallery.x, 13); expect.equal(gallery.z, 21)
	local x, z, w, d = ShopRooms.toLocal(GRID, back)
	expect.equal(x, -13); expect.equal(z, 21); expect.equal(w, 24); expect.equal(d, 18)
	expect.equal(select(2, ShopRooms.toLocal(GRID, hall)), -10)
	expect.equal(ShopRooms.hallBack(cfg, GRID), 10)
	local mx, mz = ShopRooms.hallMiddleCell(cfg, GRID)
	expect.equal(mx, 12); expect.equal(mz, 10)
end,
["saved rooms cleaned: known, once each, in order"] = function()
	local list = ShopRooms.clean(cfg, { "gallery", "backRoom", "gallery", "attic", 5 })
	expect.equal(#list, 2); expect.equal(list[1], "backRoom"); expect.equal(list[2], "gallery")
	expect.equal(#ShopRooms.clean(cfg, nil), 0); expect.equal(#ShopRooms.clean(cfg, "backRoom"), 0)
end,
["the open rooms as a plot attribute and back"] = function()
	expect.equal(ShopRooms.format({ "backRoom", "gallery" }), "backRoom,gallery")
	expect.equal(ShopRooms.format({}), "")
	local open = ShopRooms.parse("backRoom,gallery")
	expect.equal(open.backRoom, true); expect.equal(open.gallery, true)
	expect.isNil(next(ShopRooms.parse(nil))); expect.isNil(next(ShopRooms.parse("")))
end,
["each open room adds a customer and 5 shelves"] = function()
	expect.equal(ShopRooms.customerCap(cfg, 4, {}), 4)
	expect.equal(ShopRooms.customerCap(cfg, 4, { backRoom = true }), 5)
	expect.equal(ShopRooms.customerCap(cfg, 4, { backRoom = true, gallery = true }), 6)
	expect.equal(ShopRooms.customerCap(cfg, 4, { attic = true }), 4, "unknown rooms count for nothing")
	expect.equal(ShopRooms.shelfCap(cfg, 30, { gallery = true }), 35)
	expect.equal(ShopRooms.shelfCap(cfg, 30, { backRoom = true, gallery = true }), 40)
end,
["unlocking: the room, then open already, the level, then the cash"] = function()
	expect.equal((ShopRooms.canUnlock(cfg, "backRoom", {}, 15, 5000)), true)
	expect.equal(select(2, ShopRooms.canUnlock(cfg, "attic", {}, 99, 1e9)), "That room doesn't exist.")
	expect.equal(select(2, ShopRooms.canUnlock(cfg, 7, {}, 99, 1e9)), "That room doesn't exist.")
	expect.equal(select(2, ShopRooms.canUnlock(cfg, "backRoom", { backRoom = true }, 99, 1e9)), "The Back Room is open already.")
	expect.equal(select(2, ShopRooms.canUnlock(cfg, "backRoom", {}, 14, 1e9)), "Reach shop level 15 to open the Back Room.")
	expect.equal(select(2, ShopRooms.canUnlock(cfg, "gallery", {}, 30, 19999)), "You need $20,000 to open the Gallery.")
end,
["walls, door paths and locked rooms are never placeable; an open room's floor is"] = function()
	local function find(list, name, room)
		for _, b in list do if b.name == name and b.room == room then return b.rect end end
		return nil
	end
	local closed = ShopRooms.blockers(cfg, GRID, {})
	local wall = find(closed, "InnerWall", nil) :: any
	expect.equal(wall.x, 0); expect.equal(wall.z, 20); expect.equal(wall.w, 25); expect.equal(wall.d, 1)
	local split = find(closed, "RoomWall", nil) :: any
	expect.equal(split.x, 12); expect.equal(split.z, 21); expect.equal(split.w, 1); expect.equal(split.d, 9)
	local hallPath = find(closed, "DoorPathHall", "backRoom") :: any
	expect.equal(hallPath.x, 6); expect.equal(hallPath.z, 18); expect.equal(hallPath.w, 4); expect.equal(hallPath.d, 2)
	local roomPath = find(closed, "DoorPathRoom", "gallery") :: any
	expect.equal(roomPath.x, 15); expect.equal(roomPath.z, 21)
	expect.equal((find(closed, "LockedRoom", "backRoom") :: any).w, 12)
	local open = ShopRooms.blockers(cfg, GRID, { backRoom = true })
	expect.isNil(find(open, "LockedRoom", "backRoom"), "an open room's floor is free")
	expect.equal(find(open, "LockedRoom", "gallery") ~= nil, true)
	expect.equal(find(open, "DoorPathRoom", "backRoom") ~= nil, true, "its door path stays clear")
end,
["the doors: 8 wide, 10 high, in the hall's back wall, sliding into the wall beside them"] = function()
	local doors = ShopRooms.doors(cfg, GRID)
	expect.equal(#doors, 2)
	expect.equal(doors[1].room, "backRoom"); expect.equal(doors[1].part, "BackRoomDoor")
	expect.equal(doors[1].x, -9); expect.equal(doors[1].z, 11); expect.equal(doors[1].width, 8); expect.equal(doors[1].height, 10); expect.equal(doors[1].slide, -1)
	expect.equal(doors[2].x, 9); expect.equal(doors[2].slide, 1)
	-- each door's slide side has at least a door's width of wall to hide in
	expect.equal((doors[1].x - 4) - -25 >= 8, true); expect.equal(25 - (doors[2].x + 4) >= 8, true)
end,
["the inner walls: the hall's back wall with two doorways and the wall between the rooms"] = function()
	local walls = ShopRooms.innerWalls(cfg, GRID)
	expect.equal(#walls, 2)
	local back, split = walls[1], walls[2]
	expect.equal(back.axis, "x"); expect.equal(back.at, 11); expect.equal(back.from, -25); expect.equal(back.to, 25)
	expect.equal(#back.holes, 2); expect.equal(back.holes[1].from, -13); expect.equal(back.holes[1].to, -5); expect.equal(back.holes[1].top, 10)
	expect.equal(split.axis, "z"); expect.equal(split.at, 0); expect.equal(split.from, 11.5); expect.equal(split.to, 30)
end,
["the walls inside open space: the hall's, then each open room's"] = function()
	local hall = ShopRooms.runs(cfg, GRID, {})
	expect.equal(#hall, 3)
	expect.equal(hall[1].side, "left"); expect.equal(hall[1].at, -25); expect.equal(hall[1].from, -30); expect.equal(hall[1].to, 10.5); expect.equal(hall[1].inward, 1)
	expect.equal(hall[2].side, "right"); expect.equal(hall[2].inward, -1)
	expect.equal(hall[3].side, "back"); expect.equal(hall[3].at, 10.5); expect.equal(#hall[3].holes, 2); expect.equal(hall[3].inward, -1)
	local both = ShopRooms.runs(cfg, GRID, { backRoom = true, gallery = true })
	expect.equal(#both, 11, "3 + 4 a room")
	local backRoom = ShopRooms.runs(cfg, GRID, { backRoom = true })
	-- the Back Room: its left wall, the wall between the rooms, the outer back wall, the hall wall's room face
	expect.equal(backRoom[4].side, "left"); expect.equal(backRoom[4].from, 11.5); expect.equal(backRoom[4].to, 30)
	expect.equal(backRoom[5].side, "inner"); expect.equal(backRoom[5].at, -0.5); expect.equal(backRoom[5].inward, -1)
	expect.equal(backRoom[6].side, "outerBack"); expect.equal(backRoom[6].at, 30); expect.equal(backRoom[6].to, -0.5)
	expect.equal(backRoom[7].side, "inner"); expect.equal(backRoom[7].at, 11.5); expect.equal(#backRoom[7].holes, 1); expect.equal(backRoom[7].inward, 1)
end,
["windows go on the side walls' open stretches, posters also between the doors"] = function()
	local spans = ShopRooms.windowSpans(cfg, GRID, {})
	expect.equal(#spans.left, 2)
	expect.equal(spans.left[1].from, -30); expect.equal(spans.left[1].to, 10.5); expect.isNil(spans.left[1].locked)
	expect.equal(spans.left[2].from, 11.5); expect.equal(spans.left[2].to, 30); expect.equal(spans.left[2].room, "backRoom"); expect.equal(spans.left[2].locked, true)
	expect.equal(spans.left[2].name, "Back Room")
	expect.equal(spans.right[2].room, "gallery")
	expect.equal(#spans.back, 3); expect.equal(spans.back[2].from, -5); expect.equal(spans.back[2].to, 5); expect.equal(spans.back[2].posters, true)
	expect.isNil(ShopRooms.windowSpans(cfg, GRID, { backRoom = true }).left[2].locked)
end,
["a strip along a wall is cut where a doorway reaches it"] = function()
	local holes = ShopRooms.innerWalls(cfg, GRID)[1].holes
	local band = ShopRooms.gaps(-25, 25, holes, 0, 3.4)
	expect.equal(#band, 3); expect.equal(band[1].to, -13); expect.equal(band[2].from, -5); expect.equal(band[3].from, 13)
	expect.equal(#ShopRooms.gaps(-25, 25, holes, 15.5, 15.8), 1, "over the doors it runs on")
end,
["the inner walls leave room for the look's band and the wall gap"] = function()
	local shell = require("../src/shared/Config/Decor").SHELL
	local spare = (2 - cfg.WALL_THICK) / 2 -- a wall in the middle of its 2-stud cell row
	expect.equal(spare >= shell.LINER + shell.BAND_DEEP + shell.WALL_GAP, true)
end,
["Pish's room lessons come at the rooms' levels"] = function()
	local pish = require("../src/shared/Config/Pish")
	for _, id in cfg.ORDER do
		local found = nil
		for _, lesson in pish.LESSONS do if lesson.id == id then found = lesson end end
		expect.equal(found ~= nil and found.level == cfg.ROOMS[id].level and found.late == true, true, id)
	end
end,
```

- [ ] **Step 3: Run** `lune run tests/run ShopRooms`. Expected: FAIL (`ShopRooms` module missing).
- [ ] **Step 4: Implement `Util/ShopRooms`** with the signatures above. Rooms' rows run from `WALL_ROW + 1` to
  `cellsZ - 1`. A cell rect's local middle is `-cellsX*size/2 + (x + w/2)*size`, `-cellsZ*size/2 + (z + d/2)*size`
  (PlacementGrid's maths). The hall's back wall's middle plane is the middle of `WALL_ROW` (local 11), its faces
  `+-WALL_THICK/2`; the wall between the rooms is the middle of `SPLIT_COLUMN` (local 0) from the hall wall's room face
  to the back. Door holes span the door's cells, `top = DOOR_HEIGHT`. Run order: hall left, hall right, hall back, then
  per open room in `ORDER`: its outer side wall, the wall between the rooms' face, the outer back wall (`outerBack`),
  the hall wall's room face (with its doorway). Window spans: per side the hall stretch, then the room's stretch
  (`room`, `locked = true` while closed); `back` is the hall's back face minus the doorways, `posters = true`.
  Money in reasons as `$5,000` (WindowRules' `money` pattern).
- [ ] **Step 5: Add the two lessons to `Config/Pish` LESSONS** (after `recycler`):
  `{ id = "backRoom", level = 15, icon = "Shop", late = true }`, `{ id = "gallery", level = 30, icon = "Shop", late = true }`
  (comment: rooms came after launch; the door is pointed at by TutorialController POINT_AT, Task 7), and their lines in
  `Config/PishTalk` LESSONS: `backRoom = "The Back Room can open now! More floor, more customers."`,
  `gallery = "The Gallery can open now! More floor, more customers."`.
- [ ] **Step 6: Run** `lune run tests/run`. Expected: `0 failed` (TalkRules' short-line test included; shorten a line
  if it trips).
- [ ] **Step 7: Commit** `git add src/shared/Config/ShopRooms.luau src/shared/Util/ShopRooms.luau tests/ShopRooms.spec.luau tests/run.luau src/shared/Config/Pish.luau src/shared/Config/PishTalk.luau`
  then `git commit` ("Shop rooms: room rules and config").

### Task 2: The bigger plot, the town's edge and decor out of the shops

**Files:**
- Modify: `src/shared/Config/Plots.luau` (`WIDTH = 50`, `DEPTH = 60`, `GAP = 14` with the rows' new span in its
  comment, `COMPUTER_GRID_X = 20`, `QUEUE_ZONE_LENGTH = 18`, its comment "Keep >= (Customers.MAX_PER_PLOT + open
  rooms) * QUEUE_SPACING")
- Modify: `src/shared/Config/Placement.luau` (`MAX_EDIT_DISTANCE = 50`, comment: the plot's centre moved 10 back)
- Modify: `src/shared/Config/Customers.luau` (`MAX_PER_PLOT` comment: the base; +1 per open room, Config/ShopRooms)
- Modify: `src/shared/Config/Town.luau` (`BOUNDS.HALF_Z = 112`; the four `WALK_EDGE` points at z +-110 -> +-112;
  `SHOP.PANEL_ROWS = { -12, 0, 12 }` now from the hall's middle, `SHOP.PANEL_COLS = { -16, 0, 16 }`)
- Modify: `src/shared/Util/PlacementGrid.luau:94-96` (a `PlacementMargin` number attribute overrides
  `RESERVED_MARGIN` for non-shelf blockers)
- Modify: `src/shared/Util/TownLayout.luau` (add `TownLayout.touches(box: Rect, rects: { Rect }, margin: number): boolean`)
- Create: `tools/town/fit_town_decor.luau`, `tests/TownDecorFit.spec.luau`; Modify: `assets/town/TownDecor.rbxm`,
  `tests/run.luau`, `tests/TownLayout.spec.luau`, and any spec that pinned the old numbers

**Interfaces:**
- Consumes: none.
- Produces: `TownLayout.touches(box, rects, margin): boolean` (box overlaps any rect grown by `margin`);
  `PlacementMargin` attribute (number) on blocker parts; the new config numbers.

- [ ] **Step 1: Failing tests.** In `tests/TownLayout.spec.luau` add:

```lua
["the hedge stands right behind the shops: no gap a player fits in"] = function()
	local backWall = 96 / 2 + 60 + town.WALL_THICKNESS -- Config/Plots STREET_WIDTH 96, DEPTH 60 (Lune can't load Plots)
	local curb = town.BOUNDS.HALF_Z - town.LAYOUT.EDGE_FENCE_INSET - 0.9 -- the hedge's curb is 1.8 deep (Util/Props)
	expect.equal(curb - backWall >= 0, true, "the hedge clears the wall")
	expect.equal(curb - backWall < 1, true, "too narrow to walk into")
end,
["touches: a box against a shop's wall, and one clear of it"] = function()
	local rects = { { minX = -25, maxX = 25, minZ = 48, maxZ = 108 } }
	expect.equal(TownLayout.touches({ minX = 25.5, maxX = 27, minZ = 60, maxZ = 62 }, rects, 1), true)
	expect.equal(TownLayout.touches({ minX = 26.5, maxX = 30, minZ = 60, maxZ = 62 }, rects, 1), false)
end,
```

  and create `tests/TownDecorFit.spec.luau`:
  `["no hand-placed decor below the roofline stands in a shop"]` — loads `assets/town/TownDecor.rbxm` with
  `@lune/roblox`, builds `TownLayout.plotRects({ plotCount = 6, perRow = 3, plotWidth = 50, plotDepth = 60, gap = 14, streetWidth = 96 })`,
  and for every BasePart whose bottom (its world AABB's lowest y, from `CFrame` axes and `Size`) is under `ROOFLINE = 20`
  asserts `not TownLayout.touches(itsXZBox, rects, town.WALL_THICKNESS)`, failing with the piece's group and name.
- [ ] **Step 2: Run** `lune run tests/run TownLayout` and `lune run tests/run TownDecorFit`. Expected: both FAIL (the
  hedge at 110; ~117 pieces in the way; `touches` missing).
- [ ] **Step 3: Change the config numbers and `PlacementGrid`** listed above. `TownLayout.touches` uses the overlap
  maths `clearOf` already has.
- [ ] **Step 4: Write `tools/town/fit_town_decor.luau`**: usage `lune run tools/town/fit_town_decor [apply]`. Same rule
  as the test; a piece is a child of one of TownDecor's groups (a Model or a Part). Without `apply` it lists the pieces
  in the way and exits 1 if any; with `apply` it removes them and writes the file back (`serializeModel`). A comment
  points at the spec and at Task 8 (pieces added back after the owner picks the gaps' mockup).
- [ ] **Step 5: Run** `lune run tools/town/fit_town_decor` (Expected: a list, exit 1), then
  `lune run tools/town/fit_town_decor apply` (Expected: "removed N pieces"; N about 117 — the tree belts behind the shops,
  the four gap groups' pieces near the walls, the row-end corners' nearest trees). Rojo re-syncs the file.
- [ ] **Step 6: Run** `lune run tests/run`. Expected: `0 failed` after updating the specs that pinned old numbers
  (likely TownLayout, TownTerrain, WalkerRules, ShopDetail, PortalTrails, WildValley, DayCycle, MusicRules, PropFit,
  TurtsRules): change only numbers that follow from the new plot, bounds and walk edge, never a rule.
- [ ] **Step 7: Commit** (configs, PlacementGrid, TownLayout, the tool, the rbxm, the specs): "Shop rooms: 50 x 60
  plots, the hedge behind them, decor out of the shops".

### Task 3: Windows on wall stretches

**Files:**
- Modify: `src/shared/Config/Windows.luau` (`FRONT.outerWidth = 52`; remove `WALLS`; comment: stretches come from
  `Util/ShopRooms.windowSpans`)
- Modify: `src/shared/Util/WindowRules.luau`, `src/shared/Util/WindowLooks.luau:183-200`
- Modify: `src/server/Services/WindowService.luau`, `src/server/Services/PlotService.luau` (Plot type gains
  `rooms: { [string]: boolean }`, `{}` in buildPlot; `SetWindows` passes the new cframe argument),
  `src/client/Controllers/WindowController.luau`, `src/server/Services/DevService.luau:561-575` (`/window` usage
  `<left|right>`), `src/shared/Config/AdminPanel.luau` (the Stained button: `/window Stained left -24`)
- Test: `tests/WindowRules.spec.luau` (rewritten for spans)

**Interfaces:**
- Consumes: `ShopRooms.windowSpans`, `ShopRooms.grid`, `ShopRooms.parse` (Task 1).
- Produces:
  - `WindowRules.Spans = { [string]: { ShopRooms.Span-shaped } }` (structural type in WindowRules)
  - `WindowRules.canPlace(cfg, spans: Spans, windows: { Window }, window: Window, ignore: number?): (boolean, string?)`
  - `WindowRules.spots(cfg, spans: Spans, window: Window): { Window }` — where a misplaced piece may go, best first
  - `WindowRules.clean(cfg, spans: Spans, saved: unknown): ({ Window }, number)` — moves what no longer fits, else pays
    its price back
  - `WindowLooks.cframe(floor, window, cfg, width, depth, thick, backZ: number): CFrame` — `back` pieces hang on the
    wall whose middle plane is at local `backZ` (the hall's back wall: 11)

- [ ] **Step 1: Rewrite the failing tests** (`local SPANS = ShopRooms.windowSpans(roomsCfg, ShopRooms.grid(50, 60, 2), {})`,
  `OPEN` the same with `{ backRoom = true }`); keep the snap, canBuy, count, pieces and poster tests, replacing
  `canPlace(Windows, list, w)` with `canPlace(Windows, SPANS, list, w)`:

```lua
["a window fits on a side wall's open stretch, clear of its ends and of other windows"] = function()
	expect.equal((WindowRules.canPlace(Windows, SPANS, {}, window("Square", "left", 6))), true)
	expect.equal(select(2, WindowRules.canPlace(Windows, SPANS, {}, window("Square", "left", 8))), "Too close to the corner.")
	expect.equal((WindowRules.canPlace(Windows, SPANS, {}, window("Square", "left", -26))), true)
	expect.equal((WindowRules.canPlace(Windows, SPANS, {}, window("Square", "left", -28))), false)
end,
["a room's wall takes windows only once the room is open"] = function()
	expect.equal(select(2, WindowRules.canPlace(Windows, SPANS, {}, window("Square", "left", 20))), "Open the Back Room first.")
	expect.equal((WindowRules.canPlace(Windows, OPEN, {}, window("Square", "left", 20))), true)
	expect.equal((WindowRules.canPlace(Windows, OPEN, {}, window("Square", "right", 20))), false, "the Gallery is still shut")
end,
["the hall's back wall takes posters, never windows, and never in a doorway"] = function()
	expect.equal(select(2, WindowRules.canPlace(Windows, SPANS, {}, window("Square", "back", 0))), "Windows go on the side walls.")
	expect.equal((WindowRules.canPlace(Windows, SPANS, {}, window("PosterOneMore", "back", 0))), true)
	expect.equal((WindowRules.canPlace(Windows, SPANS, {}, window("PosterOneMore", "back", -8))), false)
end,
["front posters sit on the wider front's outer panes"] = function()
	local spots = WindowRules.frontSpots(Windows)
	expect.near(spots[1], -6 - 2.5 * 20 / 3, 1e-6); expect.near(spots[2], -16, 1e-6)
end,
["clean: a back window moves to the hall's side walls, nearest the back"] = function()
	local kept, refunded = WindowRules.clean(Windows, SPANS, { window("Square", "back", 0) })
	expect.equal(refunded, 0); expect.equal(kept[1].side, "left"); expect.equal(kept[1].at, 6)
end,
["clean: a back window with no room left is paid back"] = function()
	local saved = { window("Wide", "left", -24), window("Wide", "left", -14), window("Wide", "left", -4),
		window("Wide", "right", -20), window("Wide", "right", -2), window("Wide", "back", 0) }
	local kept, refunded = WindowRules.clean(Windows, SPANS, saved)
	expect.equal(#kept, 5); expect.equal(refunded, Windows.STYLES.Wide.price)
end,
["clean: a poster in a doorway moves along its wall"] = function()
	local kept = WindowRules.clean(Windows, SPANS, { window("PosterOneMore", "back", -8) })
	expect.equal(kept[1].side, "back"); expect.equal(kept[1].at, -2)
end,
```

- [ ] **Step 2: Run** `lune run tests/run WindowRules`. Expected: FAIL (old signature, `WALLS` lookups).
- [ ] **Step 3: Implement.** `canPlace`: front unchanged; a side with no spans: "Windows go on the side walls."
  (posters: "Posters go on a wall or the front glass."); a window on a side whose spans are all posters-only (`back`):
  "Windows go on the side walls."; otherwise the span containing `[at - w/2 - CORNER, at + w/2 + CORNER]`: none ->
  "Too close to the corner.", a locked one -> `Open the {span.name} first.`; grid and overlap checks unchanged.
  WindowRules never requires ShopRooms (the spans come in as data). `spots`: a window
  whose side takes no windows -> every grid spot on the open left/right stretches, `at` high to low, left before right;
  anything else -> its own side's spots by distance from its `at`, then the other sides' by the same distance.
  `clean`: keep if it fits, else the first of `spots` that fits, else refund its price. `WindowLooks.cframe`: `back`
  uses `backZ` (+ the poster depth as today).
- [ ] **Step 4: Wire the callers.** WindowService: `spansFor(player)` =
  `ShopRooms.windowSpans(RoomsCfg, ShopRooms.grid(PlotConfig.WIDTH, PlotConfig.DEPTH, Placement.GRID_SIZE), plot.rooms)`
  for place, move, `DevPlace` and load (`WindowRules.clean(Windows, spans, data.windows)`; load reads
  `ShopRooms.openSet(ShopRooms.clean(RoomsCfg, data.rooms))` because the plot's rooms may not be applied yet).
  PlotService.SetWindows and WindowController pass `backZ = ShopRooms.innerWalls(...)[1].at`. WindowController reads
  the open rooms from the plot model's `OpenRooms` attribute (`ShopRooms.parse`), and its wall raycast keeps using
  `WallSide` parts (Task 5 moves `back` onto the hall's back wall).
- [ ] **Step 5: Run** `lune run tests/run` (Expected `0 failed`) and the compile check on `src` (Expected 0 failed).
- [ ] **Step 6: Commit** "Shop rooms: windows on wall stretches".

### Task 4: Save v42 (rooms field, old layouts moved in)

**Files:**
- Modify: `src/server/Util/Migrations.luau` (step `[41]`, `run`'s new optional `footprint` argument passed to every
  step as the third argument), `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 42`),
  `src/server/Services/DataService.luau` (type `rooms: { string }`, TEMPLATE `rooms = {}`, `Migrations.run(..., rollGrade, footprintCells)`)
- Test: `tests/Migrations.spec.luau`

**Interfaces:**
- Consumes: none (Migrations stays require-free; its numbers are frozen in the step).
- Produces: `Migrations.run(data: any, targetVersion: number, rollGrade: (() -> string)?, footprint: ((id: string, rotation: number) -> number?)?)`;
  DataService's `footprintCells(id, rotation)`: the cells wide along x of a shelf (`Shelves.ById[id].size`) or the
  order computer (`PlotService.COMPUTER_FIXTURE_ID` -> `PlotConfig.COMPUTER_SIZE`) through
  `PlacementGrid.getFootprint`, nil for anything else.

- [ ] **Step 1: Failing tests** (`local function v41(t) t.version = 41 return t end`,
  `local WIDTHS = { WallShelf = { 1, 4 }, Shelf = { 2, 1 }, DisplayRack = { 4, 2 }, OrderComputer = { 5, 3 } }`,
  `local function footprint(id, rot) local w = WIDTHS[id] return if w then w[rot % 2 + 1] else nil end`):

```lua
["v42: rooms start closed; a junk value replaced"] = function()
	local data = v41({ rooms = "x" }); Migrations.run(data, 42, nil, footprint)
	expect.equal(typeof(data.rooms), "table"); expect.equal(#data.rooms, 0)
end,
["v42: things by a side wall stay by it, the rest stay centred"] = function()
	local data = v41({ layout = {
		{ shelfId = "WallShelf", gridX = 0, gridZ = 5, rotation = 0 }, -- by the left wall
		{ shelfId = "Shelf", gridX = 2, gridZ = 6, rotation = 0 },     -- within 4 studs of it
		{ shelfId = "Shelf", gridX = 3, gridZ = 7, rotation = 0 },     -- the middle: +3
		{ shelfId = "DisplayRack", gridX = 8, gridZ = 8, rotation = 0 },
		{ shelfId = "Shelf", gridX = 16, gridZ = 9, rotation = 0 },    -- its right edge within 4 studs of the right wall: +5
		{ shelfId = "Shelf", gridX = 18, gridZ = 10, rotation = 0 },
	}, fixtures = { OrderComputer = { gridX = 15, gridZ = 17, rotation = 0 } } })
	Migrations.run(data, 42, nil, footprint)
	local xs = {}
	for i, entry in data.layout do xs[i] = entry.gridX end
	expect.equal(table.concat(xs, ","), "0,2,6,11,21,23")
	expect.equal(data.layout[4].gridZ, 8, "the distance from the street never changes")
	expect.equal(data.fixtures.OrderComputer.gridX, 20)
end,
["v42: a turned rack uses its turned width"] = function()
	local data = v41({ layout = { { shelfId = "DisplayRack", gridX = 16, gridZ = 3, rotation = 1 } } }) -- 2 wide turned: 16..18
	Migrations.run(data, 42, nil, footprint)
	expect.equal(data.layout[1].gridX, 21)
end,
["v42: side windows keep their spot; front posters stay on their pane"] = function()
	local data = v41({ windows = {
		{ style = "Square", side = "left", at = 0 }, { style = "PosterBeware", side = "right", at = 12 },
		{ style = "PosterWanted", side = "front", at = 18.5 }, { style = "PosterOneMore", side = "front", at = -13.5 },
		{ style = "Wide", side = "back", at = 4 },
	} })
	Migrations.run(data, 42, nil, footprint)
	expect.equal(data.windows[1].at, -10); expect.equal(data.windows[2].at, 2)
	expect.near(data.windows[3].at, 6 + 2.5 * 20 / 3, 1e-6); expect.equal(data.windows[4].at, -16)
	expect.equal(data.windows[5].side, "back"); expect.equal(data.windows[5].at, 4, "the load's clean moves it")
end,
["v42: junk and unknown things are left for the loader"] = function()
	local data = v41({ layout = { "junk", { shelfId = "Gone", gridX = 19, gridZ = 1, rotation = 0 } }, fixtures = "x", windows = 5 })
	Migrations.run(data, 42, nil, footprint)
	expect.equal(data.layout[1], "junk"); expect.equal(data.layout[2].gridX, 24, "1 wide when unknown: by the right wall")
end,
```

- [ ] **Step 2: Run** `lune run tests/run Migrations`. Expected: FAIL (no step 41).
- [ ] **Step 3: Implement `[41]`** (comment: v42, the shop rooms; frozen numbers): `rooms` = `{}` unless a table;
  for each layout entry and `fixtures.OrderComputer` with whole-number `gridX`/`rotation`: `w = footprint(id, rotation) or 1`;
  `gridX <= 2` stays; `gridX + w >= 18` gets `+5`; else `+3`. Windows: `left`/`right` entries' `at -= 10`; `front`
  entries at `+-18.5` -> `+-(6 + 2.5 * 20 / 3)`, at `+-13.5` -> `+-16` (sign kept); `back` untouched. Non-tables
  and non-numbers untouched.
- [ ] **Step 4: Wire DataService** (type, TEMPLATE, `footprintCells`, the `run` call) and set `SCHEMA_VERSION = 42`.
- [ ] **Step 5: Run** `lune run tests/run`. Expected: `0 failed`.
- [ ] **Step 6: Commit** "Shop rooms: save v42 moves old shops into the wider hall".

### Task 5: The building (PlotService)

**Files:**
- Modify: `src/server/Services/PlotService.luau` (shell, inner walls, doors and signs, blockers, lights, register,
  walls and look over runs, `SetRooms`, `Release`)
- Modify: `src/server/Services/CustomerService.luau:846-848` (an empty shop sends customers to the hall's middle),
  `src/server/Services/PlacementService.luau:1109` (`DevPlace` starts at `ShopRooms.hallMiddleCell`)

**Interfaces:**
- Consumes: `ShopRooms.grid/innerWalls/doors/blockers/runs/gaps/toLocal/roomRect/hallBack/hallMiddleCell/format` (Task 1);
  `WindowRules.pieces`, `WindowLooks.cframe(..., backZ)` (Task 3).
- Produces: `PlotService.SetRooms(plot: Plot, open: ShopRooms.Open, animate: boolean?)`; `plot.rooms`; the plot
  model's `OpenRooms` attribute (`ShopRooms.format` in ORDER); door parts named `BackRoomDoor` / `GalleryDoor`
  (attribute `RoomId`) while locked; blocker parts (folder `RoomBlocks`: `BlocksPlacement = true`,
  `PlacementMargin = 0`, `RoomId`); the hall's back wall pieces with `WallSide = "back"`; the outer back wall with no
  `WallSide`.

- [ ] **Step 1: Shell.** `buildWall` takes the side to stamp (`nil` for the outer back wall). After the outer walls,
  build `ShopRooms.innerWalls` as white collidable `InnerWall` parts round their holes (`WindowRules.pieces`, from the
  floor's top to the wall top); the hall's back wall pieces get `WallSide = "back"`. Remove the single `FeatureWall`
  part. The register's z becomes `ShopRooms.hallBack(cfg, grid) - REGISTER_BACK_INSET`. Ceiling panels: at the hall's
  middle plus `PANEL_ROWS`/`PANEL_COLS`, the SurfaceLight on the middle row. `DecorRules.offWalls` needs no change:
  each inner wall stands in the middle of its blocked 2-stud cell row, 0.5 studs from the nearest placeable cell, more
  than the look's liner, band and wall gap (Task 1 test).
- [ ] **Step 2: Rooms.** `SetRooms` rebuilds `RoomBlocks` from `ShopRooms.blockers` (each cell rect -> an invisible
  part from `ShopRooms.toLocal`); for each room: locked -> its door part (the door's size, `Town.SHOP.FRAME`, a
  SurfaceGui with the `Lock` icon on the hall side) and an unlit sign plate (`cfg.SIGN`, the room's `sign` text via
  `addSurfaceLabel`) above the doorway on the hall face; open -> no door (with `animate`: the door tweens `slide x
  width` along the wall in `OPEN_SECONDS`, then is destroyed), the sign lit (the theme accent, Neon, `litText`), two
  ceiling panels at the room's middle `+ PANEL_OFFSETS` with one SurfaceLight (brightness tweened up from 0 when
  animating). Then `plot.rooms = open`, `OpenRooms` attribute, `PlotService.SetLook(plot, plot.look)`. `buildPlot`
  calls `SetRooms(plot, {}, false)`; `Release` calls it before `SetLook(plot, nil)`.
- [ ] **Step 3: Walls and look over runs.** `drawWalls`: window holes only for `left`/`right`; outer side walls cut as
  today; then for each `ShopRooms.runs(cfg, grid, plot.rooms)`: the hall's `back` run always draws the feature wall
  (`FeatureWall` pieces round its doorways: the look's wall colour and wallpaper, else `Town.SHOP.FEATURE_WALL`); with
  a look every other run draws `Liner` pieces round its doorways and (left/right) its windows' holes, wallpaper carried
  on along the run. `SetLook`: floor as today; `Band`, `Trim`, `TopStrip` along every run in the pieces
  `ShopRooms.gaps(run.from, run.to, run.holes, low, high)` leaves; crystals on random runs (seeded 7), never in a hole.
- [ ] **Step 4: Customers and DevPlace.** CustomerService's empty-shop walk goes to
  `plot.floor.CFrame * CFrame.new(hallMiddleX, 0, hallMiddleZ)` (from `ShopRooms.toLocal(grid, hallRect)`); DevPlace
  starts its search at `ShopRooms.hallMiddleCell`. The other floor-centre checks stay: ShowcaseService's
  `BUY_DISTANCE * 3` (42) still covers the rooms' far corners (39 from the centre), WindowService's `NEAR` is 60, and
  PlacementService / QuestController use `MAX_EDIT_DISTANCE` (50 from Task 2).
- [ ] **Step 5: Checks.** `lune run tests/run` (Expected `0 failed`), the compile check (Expected 0 failed), then Studio
  (Rojo synced; the owner not in Play; Edit data model's Source matches the repo): Play solo on the `_studio` save.
  Expected: Output with no new errors; the shop 50 x 60 with the hall open and both doors locked with their signs;
  every snapshot shelf at its moved cell (left-wall ones unmoved in grid, middle +3, right +5, all `GridZ` unchanged),
  except any the load moved off a door path or the longer queue strip to the nearest free cell; the computer at 20;
  the back window (if any) moved to a side wall; nothing on a door path or the queue strip.
  Screenshots: the street, the hall from the door, the doors, a wall look's band cut at the doorways (`/decor
  CandyPastel`, then back to the save's look). Stop Play.
- [ ] **Step 6: Commit** "Shop rooms: the 50 x 60 building with locked rooms".

### Task 6: Unlocking (RoomService) and the caps

**Files:**
- Create: `src/server/Services/RoomService.luau`
- Modify: `src/shared/Remotes.luau` (`"UnlockRoom", -- client -> server: (roomId: string) unlock one of your shop's rooms (RoomService)` and its export)
- Modify: `src/server/init.server.luau` (main block: `RoomService.Start()` right before `PlacementService.Start()`,
  comment: before PlacementService and WindowService, their loads read the open floor)
- Modify: `src/server/Services/CustomerService.luau:1124,1252,1281` (one local `capOf(plot)` =
  `ShopRooms.customerCap(RoomsCfg, CustomerConfig.MAX_PER_PLOT, plot.rooms)`)
- Modify: `src/server/Services/PlacementService.luau` (shelf cap via `ShopRooms.shelfCap(..., plot.rooms)` at
  lines 752 and 1104; new `PlacementService.Refit(player)`)
- Modify: `src/server/Services/DevService.luau` (`/shoproom`), `src/shared/Config/AdminPanel.luau` ("Shop rooms" section)

**Interfaces:**
- Consumes: `ShopRooms.clean/openSet/canUnlock/doors/grid`, `PlotService.SetRooms`, `TutorialService.MarkLessonSeen`,
  `EconomyService.TrySpend/GetLevel/GetCash`, `Blocked.tell`.
- Produces: `RoomService.Start()`, `RoomService.GetOpen(player: Player): ShopRooms.Open`,
  `RoomService.DevSet(player: Player, which: string, open: boolean): (boolean, string?)` (Studio only);
  `PlacementService.Refit(player: Player)` (every shelf and the computer standing on a blocked cell goes to its nearest
  free cell; `nearestFreeCell` with the thing itself ignored).

- [ ] **Step 1: RoomService.** `DataService.Register({ load, save, unload })`: load cleans `data.rooms`, keeps the
  list, applies `PlotService.SetRooms(plot, open, false)`; save writes a copy only when loaded; unload forgets.
  `onUnlock(player, roomId: unknown)`: string type, `RateLimiter.new(1)`, loaded, owns a plot, within `DOOR_REACH` of
  that room's door (`plot.floor.CFrame * CFrame.new(door.x, 0, door.z)`; else Blocked "Walk up to the door to open
  it."), `ShopRooms.canUnlock` (else Blocked with its reason), `TrySpend(price)` (false with the guard's `true`: it told
  them; plain false: Blocked "You need $X to open the <name>."), then append, `SetRooms(plot, open, true)`,
  `TutorialService.MarkLessonSeen(player, roomId)`, `Remotes.Notify:FireClient(player, cfg.UNLOCKED:format(name), false)`.
  No yield between the check, the spend and the append.
- [ ] **Step 2: Caps and Refit.** CustomerService's three reads use `capOf`. PlacementService's two shelf-cap reads use
  `ShopRooms.shelfCap`; the cap message stays. `Refit` as in Interfaces.
- [ ] **Step 3: Dev.** `/shoproom <open|lock|fill> [backRoom|gallery|all]` (Studio only, DevService's `addCommand`):
  open/lock via `RoomService.DevSet` (lock calls `PlacementService.Refit` after `SetRooms`; free, no lesson),
  `fill` places Small Pack Racks (`PlacementService.DevPlace(player, "Shelf")`) until the cap. Admin panel section
  "Shop rooms": Open Back Room, Open Gallery, Open both, Lock both, Fill with racks, Lesson: Back Room
  (`/tutorial lesson backRoom`), Lesson: Gallery. Add `/shoproom` to DevService's printed command list.
- [ ] **Step 4: Checks.** `lune run tests/run` (Expected `0 failed`), compile check, then Studio (`_studio` save):
  `/level 15`, `/cash 6000`, walk to the Back Room door, fire `UnlockRoom` via the owner's client path once Task 7
  exists — for now through `ServerStorage.DevCommand:Invoke(player, "/shoproom open backRoom")` and confirm: the door
  slides, the sign lights, the room's lights come on, placement allowed inside (DevPlace there), `/customer plain`
  six times shows 5 at once max, `/shoproom lock all` moves the room's racks out. Stop Play.
- [ ] **Step 5: Commit** "Shop rooms: unlocking, the customer and shelf caps".

### Task 7: The owner's door, the unlock moment, Pish's lessons

**Files:**
- Create: `src/client/Controllers/ShopRoomController.luau`
- Modify: `src/client/init.client.luau` (start it after WindowController), `src/client/Controllers/TutorialController.luau:93-99`
  (`POINT_AT.backRoom = { part = "BackRoomDoor" }`, `POINT_AT.gallery = { part = "GalleryDoor" }`)

**Interfaces:**
- Consumes: the door parts and `OpenRooms` (Task 5), `Remotes.UnlockRoom` (Task 6), `Config/ShopRooms`, the lessons
  (Task 1).
- Produces: `ShopRoomController.Start()`.

- [ ] **Step 1: Prompts.** For the local player's own plot (`PlotId` attribute -> `workspace.Plots.Plot<id>`), a
  ProximityPrompt on each locked room's door part: `ActionText = "Unlock"`, `ObjectText = "<name> · $5,000"` (money
  words as the Order tablet's), `MaxActivationDistance = 10`, `RequiresLineOfSight = false`,
  `RequireLevel = room.level` (BlockedController shows the lock and level), triggered ->
  `Remotes.UnlockRoom:FireServer(roomId)`. Rebuilt when `OpenRooms` changes or the door part appears or goes.
- [ ] **Step 2: The moment.** Watching every plot's `OpenRooms`: a room id added while the local player is within 60
  studs of its door -> a sparkle burst at the doorway (a ParticleEmitter `:Emit`, the theme accent) and
  `cfg.UNLOCK_SOUND` (SoundBank.make). The owner's words come from the server's Notify (Task 6).
- [ ] **Step 3: Checks.** Compile check (Expected 0 failed), getDiagnostics on the touched client files (no "Undefined
  global"), `lune run tests/run` (Expected `0 failed`), then Studio on the `_studio` save:
  1. `/shoproom lock all`, `/level 14`: the prompt shows the lock and "Shop Lv 15"; pressing it shows the big locked
     card.
  2. `/level 15`, `/cash 100`: "You need $5,000 to open the Back Room." in the locked card.
  3. `/cash 6000`: press -> door slides, sign lights, sparkles and sound, toast "Back Room unlocked! More floor and one
     more customer.", cash down $5,000; a second press does nothing (no door, no prompt).
  4. `/tutorial lesson gallery`: Pish's paws lead to the Gallery door with his line.
  5. Customers: shelves stocked in the room (`/stock FirstSparkPack`) are visited through the door; a worker with the
     Restocker job walks in too.
  6. Phone: Device emulator (iPhone 17 Pro landscape, device first then orientation): the prompt is reachable and
     tappable at the door (calibrated taps, gotchas memory).
  7. Local Server, 2 players: player 2 visits; sees the locked door, no prompt; sees it slide when player 1 unlocks.
  8. Measure a customer visit: over 3 minutes of a stocked shop, the average seconds from a customer model's arrival in
     `workspace.Customers` to its removal (execute_luau read-only polling) -> ledger (Task 9's `VISIT`).
  Screenshots of 1, 3, 4 and 6. Stop Play.
- [ ] **Step 4: Commit** "Shop rooms: the owner's door, the unlock moment, Pish's lessons".
- [ ] **Step 5: CHECKPOINT A (stop and report).** Tell the owner exactly what to judge in Studio (the list above, stop
  -> Play to load new code), and publish a new board on the "Shop expansion" artifact: the street's gaps (12 studs) and
  row ends as they are after Task 2's removals, with two or three dressings to pick from (which removed trees come back
  into the alleys and corners, a bench or not). Wait for the owner's answers before Task 8.

### Task 8: The town's gaps and corners, dressed (after the owner's pick)

**Files:**
- Modify: `tools/town/fit_town_decor.luau` (a `PLACE` list: `{ source = "<group>/<piece>", group = "<group>", x, z, yaw }`
  from the picked mockup, cloned from pieces still in the file or from the git copy at 18010e1), `assets/town/TownDecor.rbxm`
- Test: `tests/TownDecorFit.spec.luau` (unchanged rule; it must stay green with the new pieces)

- [ ] **Step 1:** Fill `PLACE` from the owner's pick; `lune run tools/town/fit_town_decor place`. Expected: "placed N".
- [ ] **Step 2:** `lune run tests/run TownDecorFit` -> Expected PASS; `lune run tests/run` -> `0 failed`.
- [ ] **Step 3:** Studio: Play, screenshots of each gap and both row ends from the street and from behind a shop's
  side; the hedge line behind the shops (no gap to walk into). Stop Play.
- [ ] **Step 4: Commit** "Shop rooms: the town's gaps and corners dressed".

### Task 9: A room's worth in the economy simulator

**Files:**
- Modify: `tools/economy/sim.luau` (env `ROOMS=<0-2>` and `VISIT=<seconds>`; header usage lines), `CLAUDE.md`
  (the sim's command line)

- [ ] **Step 1:** Customers a minute become `min(arrivals, (Customers.MAX_PER_PLOT + ROOMS) * 60 / VISIT)` when `ROOMS`
  is set (unset: today's model, unchanged output). `VISIT` defaults to the Task 7 measurement (rounded to whole
  seconds, a comment with the date). A printed line: "Rooms open N: up to C customers in the shop, V s a visit".
- [ ] **Step 2:** `lune run tools/economy/sim 500` (Expected: the same hours as before, within Monte Carlo noise),
  `ROOMS=1 lune run tools/economy/sim 500` and `ROOMS=2 ...` (Expected: shorter or equal hours). Ledger the three
  results for the owner's price talk.
- [ ] **Step 3: Commit** "Shop rooms: the economy sim models open rooms".

### Task 10: Performance, docs, review

**Files:**
- Modify: `DESIGN.md` (3, 4.1, 4.3, 4.5, 4.6, 4.8, the Pish lessons, 10.2 folder tree, 10.4 schema v42 with `rooms`,
  10.5 budget numbers), `CLAUDE.md` (new files, the `ShopRooms` and `TownDecorFit` test entries, `/shoproom`,
  `tools/town/fit_town_decor`), `docs/props.md` (TownDecor: the fit tool), the Obsidian vault
  (`C:/Users/Ben/Documents/obsidian/card-shop-tycoon`: decisions log, lessons learned), memory (`next-focus-uiux`)

- [ ] **Step 1: Perf.** Studio Local Server, 2 players, both shops with both rooms open, filled to 40 shelves
  (`/shoproom open all`, `/shoproom fill`, `/stock FirstSparkPack`). Count SurfaceGuis + BillboardGuis in workspace
  and read the client's frame time (the `rbx-perf-profiling` skill); compare with DESIGN 10.5's recorded budget. Never
  check out main to re-measure: main's v41 code would lay the v42 test save out on the old floor and save it back.
  Expected: within DESIGN 10.5's budget; if over, stop and report the numbers before going on.
- [ ] **Step 2: Docs** as listed, in the same commit as nothing else: "Shop rooms: docs".
- [ ] **Step 3: Self-review** (no helper agents): the branch diff against `main` with the spec in hand, the Review
  Focus list one by one, the ledger's rulings. Fix anything Critical or Important with a failing test first, suite
  green, commit.
- [ ] **Step 4: CHECKPOINT B.** Report: what to judge in Studio, the sim's numbers, the perf numbers, the rulings made,
  and that release needs "Migrate to latest update" after publishing. Merge and push only on the owner's OK.
