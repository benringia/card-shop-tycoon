# Shop Decor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Shop menu's Decor tab sells six whole-shop interior looks and twelve placeable decor pieces, and decor
feeds the shop rating.

**Architecture:** Looks are plain data in a new `Config/Decor`, with pure rules (`Util/DecorRules`: buy and use
checks, save clean-up, decor score). A new `DecorService` owns the saved look and the `ShopLook` remote, and
`PlotService.SetLook` dresses the shop. Pieces are `Config/Shelves` entries of a new kind `"Decor"`, so placing, moving,
selling, saving and the Build tiles come from the existing shelf code. Code-built stand-ins (`Util/DecorLooks`) draw
them until the Blender pack is imported.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Blender 5.2 (background) for the props,
Figma image generator for the wallpapers, Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-11-14-shop-decor-design.md`

## Global Constraints

- Server authoritative: the client sends `ShopLook` intents. The server checks types, a known id, level, ownership and
  cash, and rate-limits with `Util/RateLimiter`. The price always comes from config.
- All cash changes go through EconomyService.
- Every requirement refusal goes through server `Util/Blocked` (never a bare return or only a toast).
- Tunable numbers live in `src/shared/Config`. Pure logic goes in Roblox-free `src/shared/Util` modules with Lune tests.
  Configs a test reads are plain data (colours `{ r, g, b }`, materials as names).
- Saved shape change: `SCHEMA_VERSION` 24 -> 25, a `MIGRATIONS[24]` step with a Lune test, the DataService template,
  and DESIGN.md 10.4.
- Text: plain ASCII plus `·` and emoji. Mobile-first: tap targets at least 48 px.
- Numbers from the spec:
  - Looks:

    | Look | Price | Level |
    |---|---|---|
    | CozyWood | $0 | 1 |
    | CandyPastel | $500 | 3 |
    | EnchantedForest | $1,000 | 5 |
    | NeonArcade | $2,000 | 8 |
    | CrystalCave | $3,500 | 12 |
    | StarryNight | $5,000 | 16 |

  - A look other than CozyWood: 2 points. `FULL = 8`. Rating weight `decor = 0.10`. Piece cap
    `MAX_DECOR_PER_PLOT = 20`. A piece is at most 1,500 triangles.
- Keep DESIGN.md in sync in the same change; leave out of commits the untracked
  `assets/blender/{Pish,Chikin,Turts}/*_preview_*.png` / `*_pose_*.png`, `assets/ui/round5-candidates`,
  `assets/ui/store`, `assets/ui/loading/pish_walk_frames/`.
- Commit locally per task; push only after the owner's OK in Studio.

## Review Focus

1. Double taps on a look's price: the second request must not charge again. The look is owned by then, so "buy" is
   refused and the tile has turned into "Use". Pinned by Task 1's buy test and Task 3's handler using `canBuy` on
   fresh state.
2. A look owned before a level change or a config change stays usable. "use" never checks level. Pinned in Task 1.
3. A shop released and reclaimed by another player must show that player's look (or Cozy Wood), never the previous
   owner's. `PlotService.Release` calls `SetLook(plot, nil)`. Checked in Task 9 with two players.
4. Decor pieces must not count as shelves anywhere: the 30-shelf cap, the rating's stocked part, customers, and
   restock jobs. Task 2 adds the `Decor` kind to the cap count, and Task 9 checks customers in a decorated shop.
5. A piece that can't come back on load (no room, over the cap) is refunded its paid price, never lost. Pinned by
   Task 1's cap test and checked in Task 9.

---

### Task 1: Look config, decor rules, saved shape

**Files:**
- Create: `src/shared/Config/Decor.luau`
- Create: `src/shared/Util/DecorRules.luau`
- Create: `tests/DecorRules.spec.luau`
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 25`)
- Modify: `src/server/Util/Migrations.luau` (`[24]`)
- Modify: `src/server/Services/DataService.luau` (template `decor = { look = "CozyWood", owned = {} }` and the
  `PlayerData` type)
- Modify: `tests/Migrations.spec.luau`

**Interfaces:**
- Produces:
  - `Config/Decor`:
    - `DEFAULT_LOOK: string`, `LOOK_POINTS: number` (2), `FULL: number` (8).
    - `LOOKS: { Look }` in the price order above.
    - `SHELL = { HEIGHT = 17, BAND = 3.4, TRIM = 0.3, TOP_STRIP = 15.5, CRYSTALS = 16 }` (studs).
    - `SPIN_SECONDS = 6` (one turn of the Card Pedestal's card).
  - `DecorRules.Look` (exported type): `{ id, name, price, level, floor: {number}, floorMaterial: string, wall: {number},
    wallpaper: string, tile: number, band: {number}, bandMaterial: string, trim: {number}, extra: string?,
    extraColor: {number}? }`.
    - `extra` is `"topStrip"` (NeonArcade, pink `{255, 70, 200}`) or `"crystals"` (CrystalCave, `{200, 150, 255}`).
    - Colours start from the mockup values in `scratchpad/mock_look.luau`.
    - Wallpapers are `""` until Task 6. `tile = 8`.
  - `DecorRules`:
    - `export type State = { look: string, owned: { string } }`
    - `look(cfg, id: string): Look?`
    - `owns(cfg, state: State, id: string): boolean` (the default is always owned)
    - `clean(cfg, saved: any): State`
    - `canBuy(cfg, state, id, level: number, cash: number): (boolean, string?)`
    - `canUse(cfg, state, id): (boolean, string?)`
    - `lookPoints(cfg, id: string): number`
    - `score(cfg, lookId: string, piecePoints: { number }): number`
    - `fitsCap(placed: number, cap: number): boolean`

- [ ] **Step 1: Write the failing tests** in `tests/DecorRules.spec.luau`:

```lua
["a bought look plus four or five pieces fills the decor part"] = function()
	near(DecorRules.score(Decor, "CandyPastel", { 1, 1, 2, 2 }), 0.75)
	near(DecorRules.score(Decor, "CandyPastel", { 1, 1, 2, 2, 2 }), 1)
	near(DecorRules.score(Decor, "CozyWood", table.create(20, 3)), 1, "never above 1")
	near(DecorRules.score(Decor, "CozyWood", {}), 0, "the default look alone gives nothing")
end,
["buying a look: unknown, owned, locked, short, fine"] = function()
	local state = { look = "CozyWood", owned = { "CandyPastel" } }
	expect.equal(select(2, DecorRules.canBuy(Decor, state, "Disco", 50, 1e6)), "That look doesn't exist.")
	expect.equal(select(2, DecorRules.canBuy(Decor, state, "CandyPastel", 50, 1e6)), "You already own Candy Pastel.")
	expect.equal(select(2, DecorRules.canBuy(Decor, state, "CozyWood", 50, 1e6)), "You already own Cozy Wood.")
	expect.equal(select(2, DecorRules.canBuy(Decor, state, "StarryNight", 15, 1e6)), "Starry Night unlocks at shop level 16.")
	expect.equal(select(2, DecorRules.canBuy(Decor, state, "NeonArcade", 8, 1999)), "You need $2000 for Neon Arcade.")
	expect.equal(DecorRules.canBuy(Decor, state, "NeonArcade", 8, 2000), true)
end,
["using a look: any owned one, whatever the level"] = function()
	local state = { look = "CozyWood", owned = { "StarryNight" } }
	expect.equal(DecorRules.canUse(Decor, state, "StarryNight"), true, "owned at level 16 earlier, still usable")
	expect.equal(DecorRules.canUse(Decor, state, "CozyWood"), true)
	expect.equal(select(2, DecorRules.canUse(Decor, state, "CandyPastel")), "Buy Candy Pastel first.")
	expect.equal(select(2, DecorRules.canUse(Decor, state, "Disco")), "That look doesn't exist.")
end,
["a save is cleaned: unknown ids dropped, the look in use must be owned, the default never stored"] = function()
	local state = DecorRules.clean(Decor, { look = "StarryNight", owned = { "CandyPastel", "Disco", 7, "CozyWood", "CandyPastel" } })
	expect.equal(state.look, "CozyWood", "Starry Night isn't owned")
	expect.equal(table.concat(state.owned, ","), "CandyPastel")
	expect.equal(DecorRules.clean(Decor, "junk").look, "CozyWood")
	expect.equal(DecorRules.clean(Decor, { look = "CandyPastel", owned = { "CandyPastel" } }).look, "CandyPastel")
end,
["looks: the default free at level 1, then dearer and later, colours and materials Roblox knows"] = function()
	-- first LOOKS entry is Decor.DEFAULT_LOOK with price 0, level 1; price and level strictly rise down the list;
	-- every colour is three 0-255 numbers; floorMaterial / bandMaterial in
	-- { "WoodPlanks", "Wood", "SmoothPlastic", "Slate", "Grass", "Marble" }; lookPoints 0 for the default, 2 for the rest
end,
["the piece cap"] = function()
	expect.equal(DecorRules.fitsCap(19, 20), true)
	expect.equal(DecorRules.fitsCap(20, 20), false)
end,
```

Migration test in `tests/Migrations.spec.luau`:

```lua
["v25: every shop starts in Cozy Wood with no looks bought; junk cleaned"] = function()
	local data: any = { version = 24, cash = 50 }
	Migrations.run(data, 25)
	expect.equal(data.version, 25)
	expect.equal(data.decor.look, "CozyWood")
	expect.equal(#data.decor.owned, 0)
	expect.equal(data.cash, 50, "the rest untouched")
	local junk: any = { version = 24, decor = { look = 4, owned = "x" } }
	Migrations.run(junk, 25)
	expect.equal(junk.decor.look, "CozyWood")
	expect.equal(#junk.decor.owned, 0)
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: the new tests FAIL (missing module / no `decor`).
- [ ] **Step 3: Implement `Config/Decor`, `Util/DecorRules`, `MIGRATIONS[24]`, the template and `SCHEMA_VERSION = 25`.**
  The migration keeps the strings of a saved `decor` and leaves the deep cleaning to `DecorRules.clean` on load.
  `DecorRules` takes `cfg` as an argument (no sibling requires).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `Decor: look config, decor rules, saved shape v25`.

### Task 2: Decor pieces in the shelf catalogue

**Files:**
- Modify: `src/shared/Config/Shelves.luau`:
  - type: `kind` adds `"Decor"`, `category` adds `"Decor"`;
  - new fields `decor: number?` (rating points) and `flat: boolean?` (hitbox doesn't collide);
  - twelve entries.
- Modify: `src/shared/Config/Town.luau` (`SLOTS`: twelve slots `{ height = 0, collide = false, built = true }`)
- Modify: `src/shared/Config/Placement.luau` (`MAX_DECOR_PER_PLOT = 20`)
- Create: `src/shared/Util/DecorLooks.luau` (code-built stand-ins)
- Modify: `src/shared/Util/Props.luau` (`buildFallback` calls `DecorLooks.draw` for decor slots)
- Modify: `src/server/Services/PlacementService.luau`
- Modify: `src/client/Controllers/BuildController.luau` (tile detail, edit panel line)
- Test: `tests/ShelvesConfig.spec.luau`

**Interfaces:**
- Consumes: `DecorRules.fitsCap` (Task 1).
- Produces:
  - Shelf ids and prop slots, in this order with these sizes `Vector3.new(w, h, d)`, costs, levels and points:

    | Id | Size | Cost | Level | Points |
    |---|---|---|---|---|
    | PottedPlant | (2,4,2) | 80 | 1 | 1 |
    | StarRug | (6,0.2,6), flat | 150 | 1 | 1 |
    | FloorLamp | (2,6,2) | 120 | 2 | 1 |
    | Beanbag | (4,2.5,4) | 200 | 2 | 1 |
    | BalloonBunch | (2,7,2) | 250 | 3 | 1 |
    | GumballMachine | (2,4,2) | 400 | 4 | 2 |
    | ElementPennants | (6,5,2) | 500 | 5 | 2 |
    | FishTank | (4,5,2) | 900 | 7 | 2 |
    | ArcadeCabinet | (4,6,2) | 1200 | 9 | 2 |
    | DogStandee | (4,6,2) | 1500 | 10 | 3 |
    | CardPedestal | (2,5,2) | 2500 | 13 | 3 |
    | PackStatue | (4,8,4) | 4000 | 18 | 3 |

    Each is `kind = "Decor"`, `category = "Decor"`, `capacity = 0`, `prop = <id>`, `decor = <points>`.
  - `DecorLooks.isDecor(slot: string): boolean` and `DecorLooks.draw(model: Model, slot: string, size: Vector3)`.
    - The stand-ins are simple part shapes in the concept sheet's colours.
    - FloorLamp's glowing head is a part named `Bulb`; CardPedestal has a thin card part named `Spin`;
      ArcadeCabinet's screen is Neon. The Blender models use the same names.
  - `DecorLooks.finish(visual: Model, slot: string)`. PlacementService calls it on every decor piece's visual, the
    stand-in or the real model:
    - FloorLamp gets a `PointLight` on its `Bulb` with `Shadows = false`, `Range = 10`, `Brightness = 0.8`;
    - a part named `Spin` gets the card back (`CardDesign.BACK.IMAGE`) as a Decal on both faces and the
      CollectionService tag `"DecorSpin"`.
  - `PlacementService`:
    - `countShelves` skips `"Decor"` as it skips `"Trophy"`; a new `countDecor`.
    - Placing at the cap: `Blocked.tell(player, "Your shop has room for 20 decorations. Sell one to make space.")`.
    - `createShelf` gives decor hitboxes SmoothPlastic, and `CanCollide = false` when `def.flat`.
    - Every decor visual goes through `DecorLooks.finish`.
    - `restoreShelf`: a decor piece over the cap (`not DecorRules.fitsCap`) or with no free cell is refunded its
      `paid` through EconomyService's cash-giving call (the one `onSell` uses), not placed.

- [ ] **Step 1: Write the failing test** in `tests/ShelvesConfig.spec.luau`: `["decor pieces: twelve, each with
  points, a prop slot of its own id, a grid footprint, level and price rising"]`.
  - Read the entries with `kind = "Decor"`.
  - Expect 12, `category = "Decor"`, `capacity = 0`, `decor = 1..3`, `prop` equal to the id, X and Z sizes multiples
    of 2, and `unlockLevel` non-decreasing down the list.
  - Expect a `Town.luau` SLOTS line `<id> = {` for each.
  - Add `Decor = "Decor"` to the existing `byKind` map.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (no Decor entries).
- [ ] **Step 3: Implement** the config entries, slots, cap, `DecorLooks`, the Props hook, the PlacementService
  changes and the BuildController changes:
  - tile detail `` `Decor +{def.decor}` `` for `kind == "Decor"`;
  - the edit panel treats `"Decor"` like `"Trophy"` ("Pick a new spot.").
- [ ] **Step 4: Run** `lune run tests/run` (all pass), then
  `lune run <scratchpad>/compile_check.luau src/shared/Util/DecorLooks.luau` and the VS Code Luau diagnostics for the
  edited client file. Expected: no errors.
- [ ] **Step 5: Commit** `Decor: twelve placeable pieces with stand-ins and their own cap`.

### Task 3: Shop looks on the server

**Files:**
- Modify: `src/shared/Remotes.luau` (`"ShopLook"`: client -> server `(action: "buy" | "use", lookId: string)`)
- Create: `src/server/Services/DecorService.luau`
- Modify: `src/server/Services/PlotService.luau` (`SetLook`, `Release` reset)
- Modify: `src/server/init.server.luau` (start DecorService after PlacementService, before RatingService)

**Interfaces:**
- Consumes: `Config/Decor`, `DecorRules` (Task 1).
- Produces:
  - `PlotService.SetLook(plot: Plot, look: DecorRules.Look?)`. It builds a folder `ShopLook` under `plot.model`, replacing
    any old one, with:
    - the floor's colour and `Enum.Material[floorMaterial]`;
    - the two side liners (`0.1` thick, `SHELL.HEIGHT` tall, along the inner wall faces);
    - FeatureWall recoloured to `wall`;
    - a `Texture` of `wallpaper` (skipped when `""`) on each liner's and the FeatureWall's room-facing face, with
      `StudsPerTileU = StudsPerTileV = tile`;
    - the band (`SHELL.BAND` tall, `bandMaterial`) and the Neon trim (`SHELL.TRIM`) on all three walls;
    - the extras: `topStrip` is a second Neon strip at `SHELL.TOP_STRIP`; `crystals` is `SHELL.CRYSTALS` Neon wedges
      along the wall bottoms from a fixed seed.

    All the parts are anchored, `CanCollide`, `CanQuery` and `CastShadow` false. `nil` removes the folder and puts
    the floor (`Town.SHOP.FLOOR`, WoodPlanks) and FeatureWall (`Town.SHOP.FEATURE_WALL`) back.
  - `DecorService`: `DataService.Register({ load, save, unload })`. On load it cleans with `DecorRules.clean`, applies
    the look and sets the player attributes `ShopLook` (string) and `ShopLooksOwned` (ids joined by `,`). `save`
    does nothing for a player it never loaded.
  - `DecorService.GetLook(player: Player): string` (the default for unknown players).
  - `DecorService.SetLookForDev(player: Player, lookId: string)` (owned and in use; Studio only).
  - The `ShopLook` handler:
    - rate-limit;
    - `typeof` checks;
    - `canBuy` / `canUse` on the current state, refusals through `Blocked.tell` with the returned reason;
    - for buy, `EconomyService.TrySpend(player, look.price)`, then add to `owned`;
    - then apply it and set the attributes.

- [ ] **Step 1:** Everything testable here is Task 1's rules. The handler is checked in Studio (Step 3). Write
  `lune run tests/run` as the guard. Expected: still all pass.
- [ ] **Step 2: Implement** the remote, DecorService, `PlotService.SetLook` and `Release` calling `SetLook(plot, nil)`
  before it sets `FREE_COLOR`, and the start order.
- [ ] **Step 3: Verify in Studio.** Rojo is synced: stop, then Play.
  - Run `ServerStorage.DevCommand`-free checks with `execute_luau` on the Server: fire the handler path by calling
    `DecorService.SetLookForDev(player, "NeonArcade")`, then screenshot the shop (camera `[-50,15,-50]` looking at
    `[-66,2,-76]` for Plot1).
  - Then call `PlotService.SetLook(plot, nil)`. Expected: Neon Arcade dressed, then back to plain, and no errors in
    Output.
- [ ] **Step 4: Commit** `Decor: shop looks bought and switched through DecorService`.

### Task 4: Decor in the rating

**Files:**
- Modify: `src/shared/Config/Customers.luau` (`RATING.parts.decor = 0.10`, comment)
- Modify: `src/server/Services/RatingService.luau` (the decor part)
- Modify: `tests/RatingRules.spec.luau`

**Interfaces:**
- Consumes:
  - `DecorRules.score(cfg, lookId, piecePoints)` (Task 1);
  - `DecorService.GetLook(player)` (Task 3);
  - `PlacementService.GetShelves(owner)`, where a shelf whose `def.kind == "Decor"` contributes `def.decor`
    (Task 2).

- [ ] **Step 1: Update the tests** in `tests/RatingRules.spec.luau`:
  - "a well-run shop rates 4.5" passes `decor = 1` alongside the old parts and expects `1 + 4 * 0.975 / 1.1`.
  - The "decor counts only once it has a weight" test becomes
    `["decor is about a tenth: a perfect shop with no decor is about 4.6 stars"]`:
    - `near(RatingRules.score({ stocked = 1, prices = 1, displays = 1, happy = 1, decor = 0 }, WEIGHTS), 1 + 4 / 1.1)`;
    - full decor gives exactly 5.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (decor weight still 0).
- [ ] **Step 3: Implement** the weight and RatingService's `decor =` line.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `Decor: a tenth of the shop rating`.

### Task 5: The Decor tab on the client

**Files:**
- Create: `src/client/Util/LookTiles.luau`
- Create: `src/client/Controllers/DecorSpinController.luau`
- Modify: `src/client/Controllers/BuildController.luau`:
  - drop the "Decor is coming soon!" label and its comment;
  - look tiles first in the Decor grid;
  - `showCategory` shows the look tiles only on "Decor".
- Modify: `src/client/init.client.luau` (start DecorSpinController)

**Interfaces:**
- Consumes: `Config/Decor`, `Remotes.ShopLook`, and the attributes `ShopLook` / `ShopLooksOwned` / `Level` / `Cash`.
- Produces:
  - `LookTiles.build(list: ScrollingFrame, palette: any): { GuiObject }`. It returns six tiles at `LayoutOrder` 1-6;
    the Shelves tiles move to `100 + index`. Each tile is the Build tile's size and has:
    - a swatch: the floor colour as the bottom third, the wall colour with the wallpaper as a tiled ImageLabel above,
      and a trim line;
    - the look's name;
    - a "Shop look" detail line;
    - a 48 px button: "Using" (disabled, accent) / "Use" (sky) / `$price` (green, or pink when short) /
      `🔒 Lv N` (grey).

    Pressing fires `Remotes.ShopLook:FireServer(if owned then "use" else "buy", id)`; the server's Blocked card covers
    every refusal, the lock included. It refreshes on attribute changes.
  - `DecorSpinController`: turns each `"DecorSpin"`-tagged part about its own up axis, one turn per
    `Decor.SPIN_SECONDS`. It only does this within `ShopDetail.SCREEN_DISTANCE` of the camera, on RenderStepped, and
    only for tagged parts that exist (tag added and removed signals).

- [ ] **Step 1:** `lune run tests/run` as the guard (client code isn't Lune-tested). Expected: all pass.
- [ ] **Step 2: Implement** LookTiles, the BuildController changes and DecorSpinController.
- [ ] **Step 3: Check** the VS Code Luau diagnostics for the three client files. Expected: no new errors.
- [ ] **Step 4: Verify in Studio** (stop, then Play):
  - open the Shop menu, Decor tab, and screenshot it: six look tiles then twelve piece tiles;
  - buy Candy Pastel with `/cash 10000`: the shop changes and the tile says "Using";
  - press Cozy Wood ("Use"): it switches back free;
  - press Starry Night at a low level (`/level 5`): the Blocked card shows "Starry Night unlocks at shop level 16.";
  - place a Card Pedestal: its card turns;
  - Output shows no errors.
- [ ] **Step 5: Commit** `Decor: the Decor tab sells looks and pieces`.

### Task 6: Wallpapers

**Files:**
- Create: `assets/ui/decor-wallpapers/<LookId>.png` (six seamless 512 x 512 tiles, not synced)
- Modify: `src/shared/Config/Decor.luau` (`wallpaper` ids)
- Modify: `tests/DecorRules.spec.luau`

- [ ] **Step 1: Write the failing test** `["every look has its uploaded wallpaper"]`: each `look.wallpaper` matches
  `^rbxassetid://%d+$`.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Generate the six patterns** with Figma `generate_image` (`gemini-3.1-flash-image`, 1024 x 1024,
  session reused):
  - Prompt pattern: "Seamless tileable wallpaper pattern, flat soft colours, low contrast, cute cartoon style, for a
    kids' game shop wall: <motif> on <wall colour>. No text, no border."
  - Motifs per the spec's table.
  - Resize each to 512 with Pillow and make it seamless (blend the edges with an offset-and-feather pass if the
    generator's tile shows seams).
  - Save the files, serve the folder with `python -m http.server 8766 --bind 127.0.0.1`, upload with
    `mcp__Roblox_Studio__upload_image`, and put the ids in config.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass. In Studio, `SetLookForDev` each look and screenshot it
  (the six side by side for the owner).
- [ ] **Step 5: Commit** `Decor: painted wallpapers for the six looks`.

### Task 7: Pish's lesson, dev command, admin panel

**Files:**
- Modify: `src/shared/Config/Pish.luau`. Add `{ id = "decor", level = 2, icon = "Decor", shelf = "PottedPlant" }`
  after the showcase. This is a ruling against the spec's level 1: `LessonRules.due` never brings a level-1 lesson,
  since levels only go up from 1.
- Modify: the lesson lines' config (where the other lessons' Pish lines are keyed by id), following TalkRules' limits
- Modify: `src/server/Services/DevService.luau` (`/decor <lookId|pieces>`)
- Modify: `src/server/Services/PlacementService.luau` (`PlacementService.DevPlace(player: Player, shelfId: string): boolean`)
- Modify: `src/shared/Config/AdminPanel.luau` (section "Decor": one button per look `/decor <id>`, and "Every piece"
  `/decor pieces`)
- Test: `tests/LessonRules.spec.luau` (or the existing lesson spec)

- [ ] **Step 1: Write the failing test** `["the decor lesson comes at level 2 and points at the Potted Plant"]`:
  - `LessonRules.due(Pish.LESSONS, 1, 2, {})` contains `"decor"`;
  - `LessonRules.forShelf(Pish.LESSONS, "PottedPlant", "Decor") == "decor"`.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** the lesson, its lines, and DevPlace (free, the nearest free cell from the plot's middle,
  within both caps; false when it doesn't fit). Then the `/decor` command:
  - a look id: `DecorService.SetLookForDev`;
  - `pieces`: `DevPlace` for each Decor id, then a Notify with how many fit;
  - anything else: a Notify with the usage.

  Add `/decor` to the printed command list and the admin section.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass (TalkRules included). In Studio, run `/decor pieces`
  and screenshot the shop with every stand-in.
- [ ] **Step 5: Commit** `Decor: Pish's lesson, /decor and the admin panel section`.

### Task 8: The Blender pack

**Files:**
- Create: `tools/blender/build_decor_props.py` (background Blender, the stylized chunky cartoon look of the concept
  sheet, smooth rounded shapes, flat colours)
- Create: `assets/blender/DecorProps/` (`DecorProps.blend` slim, `DecorProps.fbx`)
- Modify: `docs/props.md` (a "Decor props" section: build, import once as `assets/props-import/DecorProps.rbxm`,
  `lune run tools/props/split_pack DecorProps`)

**Interfaces:**
- Produces: one FBX holding twelve top-level objects named exactly the slot ids (Task 2).
  - Each object has its origin at the base centre, faces -Y in Blender (the Roblox front), and fits its footprint.
  - Each object stays within 1,500 triangles.
  - CardPedestal's card is a separate object named `Spin`, parented to it; FloorLamp's glowing head a separate
    object named `Bulb`.
  - The lamp's bulb and the arcade's screen use a material named `Neon`.

- [ ] **Step 1: Build** with `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python
  tools/blender/build_decor_props.py`. It prints each object's triangle count and footprint.
  Expected: twelve objects, all at most 1,500 triangles, footprints within the Task 2 sizes.
- [ ] **Step 2: Render** a contact sheet (Eevee, AgX, three-quarter view) to the scratchpad, read it, and compare it
  with the concept sheet. Fix anything off-model, then rerun Step 1.
- [ ] **Step 3: Commit** `Decor: Blender pack for the twelve pieces (import once)`, then tell the owner the import
  steps (docs/props.md). The stand-ins stay until the owner saves the pack.

### Task 9: Studio checks, performance, docs

**Files:**
- Modify: `DESIGN.md`:
  - 4.7: the rating weights and the decor part;
  - the Shop menu's Decor tab line;
  - a new "Shop decor" section (looks, pieces, cap, points);
  - 10.4: `decor` and v25;
  - the file tree: Decor, DecorRules, DecorLooks, DecorService, LookTiles, DecorSpinController.
- Modify: `CLAUDE.md`:
  - the test list: DecorRules;
  - `assets/ui/decor-wallpapers`;
  - the Blender pack line;
  - the `/decor` dev command.
- Modify: the Obsidian vault (Decisions log, Home if needed).

- [ ] **Step 1: Two players** (Test tab, Local Server, 2 players):
  - Player 1 buys Neon Arcade. Player 2 sees it from the street and inside.
  - Player 1 leaves. The plot goes plain, and a rejoining player gets their own look.
  - Customers still reach every shelf in a shop with `/decor pieces` placed.
- [ ] **Step 2: Performance:** six shops at 20 pieces each (`/decor pieces` on every plot through `execute_luau`).
  Read frame time and triangle counts with `rbx-perf-profiling`. Expected: no worse than the town's budget in DESIGN
  10.5; otherwise lower `MAX_DECOR_PER_PLOT` and ledger it.
- [ ] **Step 3: Docs** as listed. Run `lune run tests/run`. Expected: all pass.
- [ ] **Step 4: Commit** `Decor: docs and checks`. Report to the owner with screenshots: the Decor tab, each look, a
  decorated shop, and the rating window. Push after their OK.
