# Shop rooms: one big shop for everyone (2026-11-23)

Owner: "can we redesign the shop into a big shop with rooms, the rooms then become the extension. so all the players
have same sized shops", then "floor space plus one more customer. can we do 50x60 instead of 40x60", then "yes bigger
hall for everyone. I'm not sure about the prices yet. when the rooms are done. we're gonna add card battles at the
table for customers which means extra coins. so we'll figure out the prices later".

Mockups: the "Shop expansion" artifact (https://claude.ai/artifact/J471p7EtD3RHArNPDJP9hw), boards "Your idea at
50 x 60 · +1 customer a room" (the plan from above) and "Your idea · inside: a locked room" (the door before and after).

## Intent
Every shop on the street is the same building. A new shop gets a bigger main hall than today, and two rooms at the back
sit behind locked doors. Unlocking a room is how a shop grows: more floor and one more customer at a time. The street
stays tidy because no shop changes size, and the rooms give later levels something big to save up for. The rooms are
also where the coming card-battle tables can go.

## Goals
- One 50 x 60 building for everyone, the same from the street.
- A 50 x 40 main hall, open from the start (today's shop is 40 x 40).
- Two rooms at the back, the Back Room and the Gallery, behind locked doors. Unlocking one opens its door for good,
  adds its floor and lets one more customer in at a time (4, then 5, then 6).
- Every existing shop moves into the new building without losing anything: shelves, stock, cases and their cards, the
  computer's spot, windows, decor.

## Not in this round
- Table card battles (the next project; rooms are plain floor, ready for them).
- The real prices and levels (placeholders in config now; the owner sets them once card battles exist and the economy
  simulator can show the room's worth).
- A third room, an upstairs, rooms with their own bonuses, windows on the outer back wall.

## Anti-goals (a failure even if it works)
- Anyone losing a placed thing, its stock or a window in the move.
- A full server running slower (shop SurfaceGuis are the known bottleneck, DESIGN 10.5).
- Customers or players getting stuck: at a door, behind a shop, in a gap between shops.
- A new player's shop feeling huge and empty: the hall grows by a quarter only; the rooms stay shut.

## Approaches
1. **One bigger building for everyone, rooms behind locked doors (picked).** Every plot becomes 50 x 60 with the same
   shell. Locked rooms are floor the placement grid refuses, behind a closed door. Plot centres along the street and
   the shop fronts don't move; the back walls reach 20 studs further, so the hedge moves back 2 studs and the gaps
   between shops narrow from 24 to 14 studs.
2. Each shop's back wall moves back when bought (the "Expansion 1" mockup): shops on one street would differ in size
   and the tree belt behind them would be cut up shop by shop. Dropped for the owner's idea: same-size shops.
3. Rooms as add-on buildings or an upstairs floor: no room on the street for add-ons; stairs fight the customers'
   paths and the camera under the roof. Dropped.

## The building (studs, from the floor's front-left corner: x across 0..50, z from the street 0..60)
| Part | Where | Notes |
|---|---|---|
| Main hall | x 0..50, z 0..40 | open from the start; 500 grid cells (today 400) |
| Wall between hall and rooms | z 40..42 | one 2-stud cell row, never placeable |
| Back Room | x 0..24, z 42..60 | 24 x 18 of usable floor (108 cells) |
| Wall between the rooms | x 24..26 | one cell column, never placeable |
| Gallery | x 26..50, z 42..60 | 24 x 18 of usable floor (108 cells) |
| Back Room door | x 12..20 on the hall's back wall | 8 wide, 10 high (the front doors' height) |
| Gallery door | x 30..38 | the mirror of the Back Room's |
| Clear paths | 8 x 4 in front of each door, and 8 x 4 just inside it | never placeable, open or locked, so a door is never blocked |

- The outer walls stay outside the floor, as today. The front (glass, sliding doors, sign, canopy, delivery pad,
  owner's spawn) is unchanged and stays exactly where it is on the street.
- The doors sit toward the middle (my call): clear of the register by the left wall and of the computer's starting
  corner on the right.
- The register keeps its place by the left wall near the hall's back (5 studs from the left wall, 6 in front of the
  hall's back wall). Its queue strip grows from 14 to 18 studs so six customers fit (6 x the 3-stud spacing).
- The order computer's starting spot is the hall's back-right corner, as today.
- The hall's back wall is the shop's feature wall (the greige face customers see as they walk in), cut round the two
  doors. Every wall of open floor wears the shop's look (Config/Decor): the hall, the open rooms, both faces of a wall
  between open spaces. A locked room stays bare and dark (no lights built until it opens).
- Ceiling lights re-laid for the 50 x 40 hall; each room gets its own row, built when it opens.
- Room numbers live in a new `Config/ShopRooms` (cells, doors, names, levels, prices); every rule both sides need
  (which cells are open, the caps, the unlock checks, the move of old layouts) lives in a Roblox-free `Util/ShopRooms`
  with Lune tests.

## A locked room
- A solid door fills the doorway: the shop's frame colour, a big lock badge, the room's name on an unlit sign above
  ("BACK ROOM", "GALLERY"). Nobody walks through it; customers' paths never lead there.
- The owner sees a prompt on it (made on the owner's client, like every owner-only prompt): "Unlock · $5,000" with the
  `RequireLevel` attribute, so below the level it shows the lock and "Shop Lv 15" before it's pressed.
- Pressing it below the level or without the cash shows the big locked card (`Util/Blocked`): "Reach shop level 15" or
  "You need $5,000". Never a silent no.
- Visitors see the closed door and its sign only.
- The server checks everything: the player owns this plot and stands near the door, the rate limit
  (`Util/RateLimiter`), the room exists and is locked, the shop level, the cash (spent through EconomyService). New
  remote `UnlockRoom(roomId)` in `Remotes.luau`.

## Unlocking
- The door opens out of the way, the sign lights in the shop's accent colour, sparkles, the room's lights fade on,
  and a banner says "Back Room unlocked! More floor and one more customer." (the mockup's "after" picture). Everyone in
  the shop sees the door open.
- From then on the room is open floor for anything placeable, for the owner, customers, workers and visitors alike.
  Customers and shop workers already walk by pathfinding (`Util/NpcMotion`), so they use the doors with no new
  routing.
- Each open room adds one customer to the shop's cap: 4 + open rooms (`Customers.MAX_PER_PLOT` becomes the base;
  CustomerService's spawns, `/customer` and Pish's sent customer all read the one cap).
- Each open room also adds 5 to the shelf cap: 30, then 35, then 40 (my call: a full shop would otherwise gain floor and
  nothing to put on it). The decor cap stays 20.
- Either room can be unlocked once its level is reached; the levels already put them in order.
- The bigger hall on its own changes no numbers: the same caps and customers as today, just more room to lay them out.
- Pish teaches it (owner rule: every shop unlock gets a lesson): the first time the shop reaches a room's level he
  walks to its door: "This door opens a whole new room: more floor and one more customer!" Saves already past the level
  get the visit once, like the Recycler's.

## Prices and levels (placeholders)
| Room | Shop level | Price |
|---|---|---|
| Back Room | 15 | $5,000 |
| Gallery | 30 | $20,000 |

Set by the owner later, after table card battles. The economy simulator gets a `ROOMS=<0-2>` option (4, 5 or 6
customers) so a room's worth in hours shows before the prices are picked.

## The town
- `Config/Plots`: WIDTH 50, DEPTH 60, GAP 14. Plot centres along the street stay at x -64, 0, 64 (width + gap is still
  64); the fronts stay at z +-48; the backs move from +-88 to +-108.
- The hedge moves back 2 studs (`Town.BOUNDS.HALF_Z` 110 to 112, the `WALK_EDGE` corners at z +-110 to +-112) and stands
  right behind the back walls (my call): no strip back there to walk into, so nobody gets stuck. The island's grass and
  the Baseplate follow BOUNDS.
- The gaps between shops shrink to 12 studs of open ground (14 between floors, minus the walls). The four gap groups in
  `assets/town/TownDecor.rbxm` (bench, flowers, small tree, bushes) are re-placed to fit. The tree belts behind the
  shops (BeltNorth, BeltSouth) lose the trees the shops now cover: a few move into the gaps, the rest go. The Arena
  signpost by the west row's end and anything else the new walls touch moves clear. A mockup of the new gaps comes
  first (owner rule: mockups for visual decisions).
- Lamps, sidewalks, the plaza and code-placed decor follow the config (`Util/TownLayout` keeps decor off the plots).

## Moving every shop in (save schema 42)
New saved field: `rooms: { string }`, the open rooms' ids (empty for everyone at first). The migration (Lune-tested):
- Layout and fixtures (the computer): the distance from the street never changes (the hall's front and depth are the
  same). Across the shop the hall grows 5 studs each side, so: a thing that stood by a side wall (within 4 studs of it)
  stays by that wall; everything else keeps its distance from the middle line, to the nearest whole cell (so it may
  sit 1 stud off). Things move apart this way, never into each other.
- Windows: side windows keep their spot (`at` is counted from the wall's middle, which moves 10 studs back). The old
  back wall is now the hall's back wall with the doors in it, so back windows move to the first free spot on the
  hall's side walls, nearest the back (my call). If none fits (rare: six windows spaced badly), the load's existing
  check (`WindowRules.clean`) pays its full price back, so it is never lost. Posters on the front glass stay as they are.
- Then the normal load does what it already does: anything now on the longer queue strip or a door's clear path moves
  to the nearest free spot (`PlacementService`'s nearestFreeCell, which must also skip locked rooms).
- Release: publish, then "Migrate to latest update" in Creator Hub, so no old server loads a new save and writes the
  old 40 x 40 layout back.

## Rules that change
- Placement (`Util/PlacementGrid`, PlacementService, the client ghost): the grid is 25 x 30 cells; locked rooms, the
  two walls and the door paths are refused. Simplest build: invisible `BlocksPlacement` blockers like today's queue
  strip, with no extra margin round them (the shelves' margin, not the fixtures').
- `DecorRules.offWalls`: shelves keep their gap off the new inner walls too.
- Windows (`Util/WindowRules`, WindowService, WindowController): left and right walls only; each side wall is two
  stretches (the hall's 40, the room's 18), a window fits inside one and keeps 1 stud from its ends; a locked room's
  stretch takes none. `/window ... back` goes.
- Anything that used the plot's middle as "the middle of the shop floor" uses the hall's middle (the plot's middle is
  now near the hall's back wall). Everything placed from the front (spawn, doors, delivery pad, Pish's and the
  prologue's door spots, the customers' entry) already counts from the front and stays put.
- `Placement.MAX_EDIT_DISTANCE` 40 to 50 (my call: the plot's centre moved 10 studs back).

## Dev and checks
- Studio-only command `/shoproom <open|lock> <backRoom|gallery|all>` (`/room` is the Dungeon's), and admin panel
  buttons. Locking again moves anything in the room to the nearest open spot.
- Tests: ShopRooms (geometry, open cells, caps, unlock checks, the layout move), the v42 migration, WindowRules,
  DecorRules, TownLayout, PlacementGrid's numbers, and every spec that reads the plot's size.
- Studio: a fresh shop, and an old shop moved in: the owner's test save (`/slot test`) laid out on today's code first,
  then loaded with the new code. Never the main save before release: Studio saves to the real store, and a v42 save
  loaded by a live v41 server would be laid out on the old 40 x 40 floor and saved back. Then unlock both rooms,
  customers and workers using both doors, desktop and phone, a 2-player Local Server (the door opens for the visitor),
  and a full-server perf check with open-room shops (DESIGN 10.5's budget) before it goes live.
- DESIGN.md (3, 4.1, 4.3, 4.5, 4.6, 4.8, the Pish lessons, 10.2, 10.4, 10.5), CLAUDE.md, docs and the Obsidian vault
  kept in step.

## Plan outline (inline, the owner's usual)
1. `Config/ShopRooms` + `Util/ShopRooms` with tests; `Config/Plots` numbers.
2. Saved data v42 with its migration test.
3. Server: PlotService (the 50 x 60 shell, inner walls, doors, room looks and lights, the register from the hall),
   RoomService (load, save, `UnlockRoom`, Blocked), PlacementService (blocked rooms, door paths, caps), the customer
   cap, WindowService and WindowRules, DecorRules.
4. Client: the owner's door prompt, the unlock moment, WindowController's walls.
5. Town: BOUNDS and WALK_EDGE, TownDecor re-placed after its mockup.
6. Pish's lessons, `/shoproom`, the admin panel, the economy sim's `ROOMS`, docs, Studio checks.
