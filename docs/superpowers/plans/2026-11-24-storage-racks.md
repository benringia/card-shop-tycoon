# Storage Racks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a Storage Rack for delivery boxes, with a store prompt, a stock clipboard window to take boxes back,
restockers that haul boxes to and from racks, slower worker walking, saved rack contents (v43) and Pish's lesson.

**Architecture:**
- **Plain data:** a rack's boxes are plain data on the placed shelf in PlacementService (`stored: { [slot]: Box }`).
  PlacementService saves them in the layout and draws them as the real delivery box models.
- **Hands:** StockService owns boxes in hands. It moves one between a player's (or a worker's) hands and a rack
  through new PlacementService calls.
- **Pure decisions:** where a box goes, which box comes out, clipboard lines, prompt words, the restocker's
  rack-to-shelf pick and load cleaning all live in the Roblox-free `Util/StorageRules`, tested in Lune.
- **Client:** the owner's prompts are added in BuildController. The clipboard is a see-through `UIKit.panel` drawn
  by the new `StorageController`.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-11-24-storage-racks-design.md`

## Global Constraints

**Server rules:**
- Server authoritative. Every remote is defined in `src/shared/Remotes.luau`.
- Every remote handler checks argument types, ownership and distance (`Stock.INTERACT_DISTANCE` 14), and is
  rate-limited with `RateLimiter`.
- Cash moves only through EconomyService.
- Refusals go through server `Util/Blocked` (`Blocked.tell`), never a bare `return` or only a toast.

**Code style:**
- Player text is plain ASCII plus `·`.
- Every tunable number lives in `src/shared/Config`.
- Pure modules don't require siblings and use no Roblox APIs. Their tests are registered by hand in `tests/run.luau`.
- `--!strict` and type annotations.
- Saved tables hold plain data only.

**Workflow:**
- Edit `src/` only with Edit/Write, never `sed -i` (it crashed Rojo).
- Client files: after edits, run a compile check (`@lune/luau` `luau.compile` in a pcall, see memory
  client-syntax-check) and getDiagnostics for "Undefined global".
- BinderController and BattleController are at the 200-local limit: add no file-level locals there.
- Commit per task on branch `storage-racks`. Merge and push only on the owner's OK.

**Numbers fixed by the spec:**
- Rack: capacity 9, cost 400, unlock level 5, size 10 x 7 x 2.
- Up to 4 racks (`Placement.MAX_STORAGE_PER_PLOT`).
- Walk speed 8 to 14 (`Jobs.WALK`).
- "Low" shelf: half full or less (`LOW_SHARE` 0.5).
- Hop: 0.3 s at 2.2 studs.
- Schema 43.

## Review Focus

These failure modes are not covered by the Lune tests. Each is checked in the Studio task (Task 10).

1. **A rack sold or moved while a restocker walks to it.** The restocker plans again; the box goes back to a rack
   with room or the pad, never lost.
2. **Two fast TAKE presses, or TAKE with a box already in your hands.** Exactly one box comes out; the second press
   shows "Your hands are full.".
3. **Leaving with a box in a restocker's arms that came off a rack.** It is saved, coming back as a pad box (it counts
   in the 12, so it always fits).
4. **A full pad (12 used) and TAKE.** The locked card says the pad is full; the rack keeps the box.
5. **Rejoining with 4 full racks and a full pad.** Every rack box comes back on its rack; nothing is refunded unless a
   rack truly can't be placed.

---

### Task 1: Workers walk 8 to 14

**Files:**
- Modify: `src/shared/Config/Jobs.luau` (replace `WALK_SPEED = 12`).
- Modify: `src/shared/Util/JobRules.luau` (Config type gets `WALK`; new function).
- Modify: `src/server/Services/JobService.luau:243` and `:747` (both WalkSpeed lines).
- Test: `tests/JobRules.spec.luau`.

**Interfaces:**
- Produces: `JobRules.walkSpeed(config: Config, spd: number): number`, and `Jobs.WALK = { min = 8, max = 14 }`.

- [ ] **Step 1: Write the failing tests** in `tests/JobRules.spec.luau`:

```lua
["walk speed: 8 for the slowest card up to 14 for the fastest, always under the player's 16"] = function()
	expect.near(JobRules.walkSpeed(config, 1), 8, 1e-9, "slowest (factor clamped to 0.4)")
	expect.near(JobRules.walkSpeed(config, 1000), 14, 1e-9, "fastest (factor clamped to 2.5)")
	expect.near(JobRules.walkSpeed(config, 14), 8 + 6 * 0.6 / 2.1, 1e-9, "a fresh Very Rare ~9.7")
	expect.near(JobRules.walkSpeed(config, 20), 8 + 6 * ((20 / 14) ^ 1.5 - 0.4) / 2.1, 1e-9, "a fresh Legendary ~11.7")
	local last = 0
	for spd = 1, 200 do
		local walk = JobRules.walkSpeed(config, spd)
		assert(walk < 16, `SPD {spd}: {walk} is under the player's 16`)
		assert(walk >= last, `SPD {spd}: never slower than a weaker card`)
		last = walk
	end
end,
```

- [ ] **Step 2: Run them** with `lune run tests/run`. Expected: FAIL on `walkSpeed` (attempt to call a nil value).
- [ ] **Step 3: Implement it.** `walkSpeed` is `WALK.min + (WALK.max - WALK.min) * (factor - SPEED_MIN) / (SPEED_MAX -
  SPEED_MIN)`, with `factor = getSpeedFactor(config, spd)`. In `Config/Jobs`, replace `WALK_SPEED = 12` with `WALK =
  { min = 8, max = 14 }`, commented with the owner's line. Both JobService lines become
  `JobRules.walkSpeed(Jobs, profile.spd) * TiredRules.speed(...)`. Grep `WALK_SPEED` in src for other readers of
  `Jobs.WALK_SPEED`.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** with message `Workers: walk 8 to 14 studs a second, under the player's 16`.

### Task 2: StorageRules and Config/Storage (pure)

**Files:**
- Create: `src/shared/Config/Storage.luau` (plain data).
- Create: `src/shared/Util/StorageRules.luau` (pure).
- Test: create `tests/StorageRules.spec.luau`, and register `StorageRules = require("./StorageRules.spec")` in
  `tests/run.luau`.

**Interfaces:**
- **Produces, in `Config/Storage`:**
  - `SPOTS = { x = { 3, 0, -3 }, decks = { 0.45, 2.7, 4.95 }, boxHeight = 1.5 }`. Part space: the rack faces its
    part's -Z, so +X is your left as you face it. Spot `n` is deck `ceil(n/3)`, x index `(n-1)%3+1`.
  - `LOW_SHARE = 0.5`.
  - `HOP = { seconds = 0.3, height = 2.2 }`.
  - `NAMES`: line names per product id:

    | Product | Name |
    |---|---|
    | FirstSparkPack | "Booster Packs" |
    | CardSleeves | "Card Sleeves" |
    | DeckBox | "Deck Boxes" |
    | FirstSparkBox | "Booster Boxes" |
    | FrontierPack | "Frontier Packs" |
    | BulkCards | "Bulk Cards" |

  - `UNITS`: `{ singular, plural }` per product id:

    | Product | Singular | Plural |
    |---|---|---|
    | FirstSparkPack | "pack" | "packs" |
    | CardSleeves | "packet" | "packets" |
    | DeckBox | "deck box" | "deck boxes" |
    | FirstSparkBox | "booster box" | "booster boxes" |
    | FrontierPack | "pack" | "packs" |
    | BulkCards | "handful" | "handfuls" |

  - `WORDS = { store = "Store", open = "Open", rack = "Storage Rack", full = "Rack full · %d / %d", empty = "empty",
    title = "STORAGE RACK", spots = "%d of %d spots", countedBy = " · counted by %s", nothing = "Nothing stored yet.",
    footer = "Carry a box here to add it to the sheet.", take = "TAKE", fullRack = "This rack is full. Take a box off,
    or place another rack.", handsFull = "Your hands are full.", padFull = "Your delivery pad is full. Put a pad box on
    a shelf or a rack first.", cap = "Your shop has room for %d storage racks. Sell one to make space.", sellLocked =
    "Take the boxes off this rack first.", refunded = "Some stored boxes had no room, so you got %s back.", storing =
    "Storing a %s", restocking = "Restocking from storage", idleFull = "Idle: shelves and storage full" }`.
  - `RACK`: look A's colours (navy 44,56,92; orange 247,132,38; ply 222,188,140; sign 255,208,60 with ink 30,36,58).
  - `CLIPBOARD`: mockup C's sizes and colours:
    - Design size 460 x 504.
    - Board 201,139,85 to 168,105,58, drop 125,74,36.
    - Clip 242,244,248 to 169,177,189, hole 108,116,128.
    - Paper 255,253,246, insets 18 / 22 / 18 / 18.
    - Rules 223,233,246 every 43 px, margin 235,110,120 at x 46.
    - Ink 47,53,80, soft ink 107,114,144.
    - Stamp 212,60,130, tilt -4.
    - Sticker tilt -4, tape 255,225,150.
    - Line height 43.
- **Produces, in `Util/StorageRules`** (types and functions):

```lua
export type Box = { productId: string, units: number }
export type Stored = { [number]: Box }
export type Line = { productId: string, name: string, boxes: number, units: number, words: string, tally: string }
export type ShelfView = { uid: string, units: number, capacity: number, productId: string?, accepts: { string }? }
export type RackView = { uid: string, stored: Stored }
export type Pick = { rack: string, slot: number, shelf: string, productId: string }
StorageRules.count(stored: Stored): number
StorageRules.slotFor(stored: Stored, capacity: number, productId: string): number?
StorageRules.takeSlot(stored: Stored, productId: string): number?
StorageRules.encode(stored: Stored): string                 -- "1:FirstSparkPack:24;2:FirstSparkPack:14", slots ascending
StorageRules.decode(text: unknown, capacity: number): Stored -- junk parts skipped
StorageRules.clean(saved: unknown, capacity: number, unitsPerBox: { [string]: number }): (Stored, { Box })
StorageRules.lines(stored: Stored, names: { [string]: string }, units: { [string]: { string } }): { Line }
StorageRules.prompt(count: number, capacity: number, carrying: string?, words: any): (string, string)
StorageRules.subtitle(count: number, capacity: number, worker: string?, words: any): string
StorageRules.isLow(units: number, capacity: number, share: number): boolean
StorageRules.restockPick(shelves: { ShelfView }, racks: { RackView }, share: number): Pick?
StorageRules.pickRack(racks: { { uid: string, free: number, distance: number } }): string?
StorageRules.spot(slot: number, spots: any, rackHeight: number): (number, number) -- part-space x, y of a box's middle
```

- [ ] **Step 1: Write the failing tests** in `tests/StorageRules.spec.luau`. Each is its own test:
  - **"a stored box goes next to its own kind, else the first free spot":**
    - `slotFor({}, 9, "A")` is 1.
    - `slotFor({[1]=A,[2]=A,[3]=D}, 9, "A")` is 4.
    - `slotFor({[1]=A,[2]=D}, 9, "D")` is 3.
    - `slotFor({[1]=A,[3]=D}, 9, "S")` is 2.
    - A full rack (9 boxes) gives nil.
    - `{[2]=A}` with every spot 3..9 taken gives 1 for "A" (wraps to the first free spot).
  - **"TAKE takes the half-used box of a kind first, then the lowest spot":** `takeSlot({[1]=A24,[2]=A14,[4]=A24},
    "A")` is 2. A tie gives the lowest spot, and a missing kind gives nil.
  - **"the rack's attribute round-trips its boxes":**
    - `decode(encode(s), 9)` deep-equals s.
    - `decode("x;3:A:5;12:A:1;2:B:0", 9)` keeps only spot 3. The 12 is past the capacity, and B has 0 units.
  - **"a saved rack is cleaned: unknown kinds dropped, units floored and capped, bad spots moved, extras returned":**
    1. `clean` of `{ {slot=1,productId="A",units=24.7}, {slot=1,productId="A",units=5}, {slot=99,productId="A",units=3},
       {slot=2,productId="Gone",units=4}, "junk" }` with capacity 9 and `{A=24}` gives spot 1 holding A 24.
    2. The duplicate spot-1 box moves to 2, and the slot-99 box goes to 3.
    3. "Gone" is dropped.
    4. Then, 11 valid boxes at capacity 9 give 9 stored and 2 extras.
    5. A non-table input gives `{}` and `{}`.
  - **"the clipboard has one line per kind, in shelf order, with tallies and unit words":**
    - Stored `{[1]=A24,[2]=A24,[3]=A14,[4]=D10,[5]=D10,[7]=B1}` with Config/Storage NAMES and UNITS gives three lines.
    - The first line is A with name "Booster Packs", boxes 3, units 62, words "62 packs", tally "III".
    - The third line is B with words "1 booster box".
  - **"prompt words: Store with the kind, Rack full when full, Open with the count":**
    - `prompt(8,9,"Deck Box",W)` gives "Store" and "Deck Box".
    - `prompt(9,9,"Deck Box",W)` gives "Store" and "Rack full · 9 / 9".
    - `prompt(8,9,nil,W)` gives "Open" and "Storage Rack · 8 boxes".
    - `prompt(1,9,nil,W)` gives "Storage Rack · 1 box".
    - `prompt(0,9,nil,W)` gives "Storage Rack · empty".
  - **"the sheet's subtitle names the last restocker when there is one":** `subtitle(8,9,"Cindercub",W)` gives "8 of 9
    spots · counted by Cindercub", and `subtitle(8,9,nil,W)` gives "8 of 9 spots".
  - **"restockers fill the emptiest low shelf from a rack, then empty shelves":**
    1. A pack shelf at 10/24 with a rack holding A24 at spot 1 and A14 at spot 2 picks spot 2 for that shelf.
    2. At 13/24 it picks nil.
    3. An empty any-product shelf with a rack holding D picks D.
    4. An empty hook accepting `{"CardSleeves","DeckBox"}` with only packs racked picks nil.
    5. Shelves at 2/24 and 10/24 pick the 2/24 one.
    6. A holding shelf at 10/24 is chosen before an empty shelf.
  - **"a restocker takes the nearest rack with room":** `pickRack({{uid="a",free=0,distance=1},{uid="b",free=2,
    distance=9},{uid="c",free=1,distance=4}})` gives "c", and all-full gives nil.
  - **"each spot sits on its deck, the first on your left":**
    - `spot(1, SPOTS, 7)` is x 3, y `-3.5 + 0.45 + 0.75`.
    - `spot(9, SPOTS, 7)` is x -3, y `-3.5 + 4.95 + 0.75`.
- [ ] **Step 2: Run them.** Expected: FAIL (`StorageRules` module not found).
- [ ] **Step 3: Implement** Config/Storage and StorageRules per the Interfaces block.
  - `clean`: valid entries keep their spot when free, else go to `slotFor`. Past capacity they go to extras.
  - `restockPick`: candidates are shelves holding a product at or below `share` of capacity, emptiest share first,
    then empty shelves in input order. For each candidate, the first rack (input order) holding a box it takes wins,
    via `takeSlot`.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** with message `Storage racks: StorageRules and Config/Storage`.

### Task 3: Save format v43

**Files:**
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 43`, its comment).
- Modify: `src/server/Services/DataService.luau:47-56` (`SavedShelf` gets `boxes: { SavedRackBox }?`, and a new
  `export type SavedRackBox = { slot: number, productId: string, units: number }`).
- Modify: `src/server/Util/Migrations.luau` (`[42]` step).
- Test: `tests/Migrations.spec.luau`.

- [ ] **Step 1: Write the failing test** "v43 (storage racks): nothing moves; a v42 layout comes through as it was":
  1. A v42 save (`v41({...})` then run to 42) with two layout entries is copied.
  2. Run `Migrations.run(data, 43, nil, footprint)`.
  3. Expect `data.version == 43`, the layout deep-equal to the copy, and no `boxes` key added.
- [ ] **Step 2: Run it.** Expected: FAIL (version stays 42).
- [ ] **Step 3: Implement** `[42] = function(_data) end`, with a comment naming the spec: racks' boxes ride on layout
  entries, and old saves have no racks.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** with message `Save v43: storage racks' boxes on layout entries`.

### Task 4: The rack item, its look, cap, tooltip and Edit bar

**Files:**
- Modify: `src/shared/Config/Shelves.luau`:
  - Add `"Storage"` to `ShelfKind`.
  - Add the entry `{ id = "StorageRack", prop = "StorageRack", name = "Storage Rack", kind = "Storage", category =
    "Shelves", capacity = 9, cost = 400, unlockLevel = 5, size = Vector3.new(10, 7, 2), color = Color3.fromRGB(44, 56,
    92) }` after `WallShelf`.
- Modify: `src/shared/Config/Town.luau` SLOTS: `StorageRack = { height = 0, collide = false, built = true }`.
- Create: `src/shared/Util/StorageRackLook.luau`:
  - `StorageRackLook.draw(model: Model, size: Vector3)`: look A from Config/Storage RACK.
  - Parts: 4 posts 0.3 wide, feet, 3 rungs and 2 braces per end, a front and back beam per deck, decks, top beams, and
    a sign part with a SurfaceGui "STORAGE".
  - The model sits on y = 0. Thin parts get `CastShadow = false`, and every part `CanCollide`, `CanQuery` and
    `CanTouch` false.
- Modify: `src/shared/Util/Props.luau` `buildFallback`: `elseif slot == "StorageRack" then StorageRackLook.draw(model,
  size or Vector3.new(10, 7, 2))`.
- Modify: `src/shared/Config/Placement.luau`: `MAX_STORAGE_PER_PLOT = 4`.
- Modify: `src/server/Services/PlacementService.luau`:
  - `countShelves` skips `"Storage"`.
  - A new `countStorage`.
  - `onPlace` refuses a 5th rack with `Blocked.tell(string.format(WORDS.cap, MAX))`.
  - `restoreShelf` treats an over-cap rack like an over-cap decor piece: its `paid` back, its boxes kept for Task 5's
    extras.
- Modify: `src/shared/Util/ShopTips.luau`: `kind == "Storage"` gives `{ "Holds 9 delivery boxes.", "Store boxes here for
  later. Restockers use it too." }`, the 9 taken from `item.capacity`.
- Modify: `src/shared/Util/EditBarRules.luau`:
  - `Kind` gets `"Storage"`.
  - A new `storageBar(thing)`:
    - Chip `"<units> / <capacity> boxes"` (tone full), or `"Empty · 0 / <capacity>"` (tone empty).
    - Hint: "Boxes waiting for your shelves." when it holds boxes, else "Carry a box here to store it.".
    - Tiles: use ("Open", sub "See the sheet"), `move("Boxes stay on")`, `sell(thing, if units > 0 then WORDS.sellLocked
      else nil)`.
- Modify: `src/shared/Config/EditBar.luau`: `ICONS.use.Storage = "Box"`.
- Modify: `src/client/Controllers/BuildController.luau`:
  - Detail line: `elseif def.kind == "Storage" then "Holds 9 boxes"` (use `def.capacity`).
  - The Edit bar thing for a rack: `units` read from the part's `StoredCount` attribute.
- Test: `tests/ShopTips.spec.luau`, `tests/EditBarRules.spec.luau`.

- [ ] **Step 1: Write the failing tests:**
  - **ShopTips:** the StorageRack item's two lines match exactly.
  - **EditBarRules "a storage rack: its boxes on the chip, Open first, Sell locked until it's empty":**
    1. `bar({kind="Storage", name="Storage Rack", capacity=9, units=8, refund=200})` gives chip text "8 / 9 boxes" with
       tone "full".
    2. Its tiles are use, move and sell, with use's label "Open".
    3. Sell's state is "locked", and its why is "Take the boxes off this rack first.".
    4. With units 0 the chip reads "Empty · 0 / 9" and sell is "ready".
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the files above.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass. Fix any suite test that counts shelves or Lv 5
  unlocks, such as MainQuestRules and LevelUpRules, by reading why it counts. The new item is expected to show there.
  Record that as a ruling.
- [ ] **Step 5: Compile-check** BuildController.
- [ ] **Step 6: Commit** with message `Storage racks: the rack in the Build menu (look A), its cap, tooltip and Edit bar`.

### Task 5: Rack contents on the server (store, take, draw, save)

**Files:**
- Create: `src/server/Util/BoxLook.luau`, moved out of `StockService.createBox`:
  - `BoxLook.build(productId: string, units: number, frontOnly: boolean?): Part`.
  - It returns the 2.5 x 1.5 x 2 hitbox Part named `StockBox`, Anchored, with the product's model welded on (or
    BrandBox) and the stickers from DeliveryLooks.
  - With `frontOnly`, the PictureBack sticker is removed and every sticker SurfaceGui gets `MaxDistance =
    ShopDetail.SCREEN_DISTANCE`.
- Modify: `src/server/Services/StockService.luau`:
  - `createBox` uses `BoxLook.build`. The prompt and pad logic stay.
  - New local `hasRoom(shop)`: `boxCount(shop) < MAX_BOXES_PER_PLOT`.
- Modify: `src/server/Services/PlacementService.luau`:
  - `PlacedShelf` gets `stored: StorageRules.Stored` and `rackBoxes: { [number]: Part }`, both `{}` for every shelf.
  - `drawRack(shelf)` rebuilds the box parts (`BoxLook.build(..., true)`, `CanCollide`/`CanQuery` false, parented to
    `shelf.part`, at `shelf.part.CFrame * CFrame.new(StorageRules.spot(slot, Storage.SPOTS, def.size.Y))`). It is called
    after any change and from `positionShelf`.
  - `syncRack(shelf)` sets `StoredCount` and `Stored` (encode).
  - `save` writes `boxes` for racks.
  - `restoreShelf` for racks: `StorageRules.clean(saved.boxes, def.capacity, unitsPerBox)`. Extras, or the boxes of a
    rack that can't be restored, go to `pendingExtras[player]`.
  - `onSell` refuses a rack holding boxes with `Blocked.tell(WORDS.sellLocked)`.
  - Exports:

```lua
PlacementService.IsStorage(shelf: PlacedShelf): boolean
PlacementService.GetRacks(player: Player): { PlacedShelf }
PlacementService.StoreInRack(shelf: PlacedShelf, productId: string, units: number): number?   -- spot used, nil if full
PlacementService.TakeFromRack(shelf: PlacedShelf, productId: string): StorageRules.Box?      -- StorageRules.takeSlot
PlacementService.SetRackWorker(shelf: PlacedShelf, name: string)                             -- LastWorker attribute
PlacementService.TakeLoadExtras(player: Player): { StorageRules.Box }                         -- once, then cleared
PlacementService.ClearRacksForTesting(player: Player)
```

- Modify: `src/server/Services/StockService.luau`:
  - **Handlers** for `Remotes.StoreBox(uid)` and `Remotes.TakeStoredBox(uid, productId)`, with the spec's checks and
    words (`Blocked.tell`).
  - **Store:** the top carried box goes out of `shop.carried` (Part destroyed) after `StoreInRack` returns a spot,
    then `syncCarry`, then fire `RackBoxHop`.
  - **Take:** `TakeFromRack`, then a new box Part goes into `shop.carried` (built with the pad's prompt disabled) and
    is attached with `attachToCharacter`, then `syncCarry` and `RackBoxHop`.
  - **load:** after the saved pad boxes, `TakeLoadExtras` boxes go on the pad while `hasRoom`. The rest are paid back:
    `boxCost * units / unitsPerBox`, rounded to cents, through `EconomyService.AddCash`, with a toast using
    `WORDS.refunded`.
  - **Exports:**

```lua
StockService.HasRoom(player: Player): boolean
StockService.MakeWorkerBox(player: Player, productId: string, units: number): Part?   -- into workerBoxes; nil without room
```

- Modify: `src/shared/Remotes.luau`, adding three remotes to NAMES and the export table:
  - `"StoreBox"`: client to server, `(uid: string)`.
  - `"TakeStoredBox"`: client to server, `(uid: string, productId: string)`.
  - `"RackBoxHop"`: server to all clients, `(rack: BasePart, slot: number, productId: string, toRack: boolean,
    carrier: Model?)`.

- [ ] **Step 1:** BoxLook extraction. Run `lune run tests/run`; expected: all pass (no behaviour change).
- [ ] **Step 2:** PlacementService storage data, drawing, attributes, save/restore, sell lock and exports.
- [ ] **Step 3:** StockService handlers, load extras and exports. Add the Remotes.
- [ ] **Step 4:** `lune run tests/run` (SourceOrder and RequireCycles cover the new requires). Expected: all pass.
  Then `rojo build default.project.json -o <scratch>/test.rbxl` exits 0.
- [ ] **Step 5: Commit** with message `Storage racks: boxes stored and taken, drawn, saved`.

### Task 6: The owner's prompts, the stock clipboard and the hop

**Files:**
- Modify: `src/client/Controllers/BuildController.luau` `addShelfPrompts` / `applyPromptMode`:
  - For `def.kind == "Storage"`, E's words come from `StorageRules.prompt(StoredCount, capacity, carrying product
    name, WORDS)`. They refresh on `CarryCount` / `CarryProductId` (player) and `StoredCount` (part).
  - Triggered while carrying: `Remotes.StoreBox:FireServer(uid)`. Otherwise `StorageController.Open(part)`.
  - F (Edit) is offset like the machines'. Both always show.
- Create: `src/client/Controllers/StorageController.luau`:
  - **The panel:** `Open(rack: BasePart)` builds once with
    `UIKit.panel(UIController.GetScreenGui(), "StorageRack", "Storage Rack")`, then:
    - Hides its `Header` and `Title`, and sets `BackgroundTransparency = 1`.
    - Draws mockup C inside at the CLIPBOARD design size 460 x 504, scaled with a UIScale to fit the panel's
      AbsoluteSize. The pattern for a custom drawing inside a panel is OrderController's tablet.
  - **The drawing:** board, clip, paper with rules and margin, title, `StorageRules.subtitle`, lines from
    `StorageRules.lines`, and the footer.
    - Each line has a sticker image (`DeliveryLooks.picture`) tilted -4 with a tape strip, name, tally and units
      words, and a TAKE stamp.
    - The TAKE stamp is a TextButton with a UIStroke in the stamp colour, tilted -4, and pops on press.
  - **Taking:** a stamp fires `Remotes.TakeStoredBox:FireServer(uid, productId)` and closes the panel.
  - **Live:** while open, it redraws on the rack's `Stored` / `StoredCount` / `LastWorker` attribute changes, and
    closes when the rack is Destroying.
  - **The hop:** `Remotes.RackBoxHop.OnClientEvent` flies a local copy of the box for `HOP.seconds` along an arc
    `HOP.height` high, between the carrier's UpperTorso (or root) and the spot. Meanwhile it hides the real box at the
    destination with LocalTransparencyModifier, on parts and decals, and SurfaceGui Enabled false.
- Modify: `src/client/init.client.luau`: `StorageController.Start()` after BuildController.
- Modify: `src/shared/Util/StockHint.luau`: add `StockHint.racks(racks: { { uid: string, count: number, capacity:
  number } }, shelvesLit: { string }, carrying: string?): { string }`. It gives racks with room when carrying and no
  shelf is lit, else `{}`.
- Modify: `src/client/Controllers/StockHintController.luau`: lights those racks with the same Highlight.
- Test: `tests/StockHint.spec.luau`, "racks with room glow only when no shelf takes the box":
  - Carrying with lit shelves gives `{}`.
  - Carrying with none lit gives only the racks with room.
  - Not carrying gives `{}`.

- [ ] **Step 1:** Write the StockHint test and run it. Expected: FAIL.
- [ ] **Step 2:** Implement `StockHint.racks` and run. Expected: PASS.
- [ ] **Step 3:** Prompts, StorageController and StockHintController. Compile-check all the client files touched and
  run getDiagnostics for undefined globals.
- [ ] **Step 4: Commit** with message `Storage racks: Store and Open prompts, the stock clipboard, the hop`.

### Task 7: Restockers use racks

**Files:**
- Modify: `src/server/Services/JobService.luau` `runRestocker` and helpers.

**Interfaces:**
- Consumes:
  - From Task 2: `StorageRules.restockPick`, `pickRack`, `isLow`, and `Storage.LOW_SHARE`, `WORDS`.
  - From Task 5: `PlacementService.GetRacks/StoreInRack/TakeFromRack/SetRackWorker/GetShelf`, and
    `StockService.MakeWorkerBox/HasRoom/ConsumeUnits/ReturnBox/TakeWaitingBox`.

- [ ] **Step 1: Restructure `runRestocker`** into three trips per the spec, in this order:
  1. **Pad to shelf:** unchanged code path.
  2. **Pad to rack:** the first waiting box no shelf takes, to `pickRack` (distance from the pad point). Walk, take it,
     carry it, status `WORDS.storing:format(product.name)`. Then walk to the rack's front point (as `getShelfPoint`).
     - On arrival, re-check with `GetShelf` that it is the same rack, and `StoreInRack`.
     - Success: `ConsumeUnits(box, all)` and `SetRackWorker`.
     - Failure: choose another rack with room, else `putBack`.
     - A mistake there: `putBack` to the pad.
  3. **Rack to shelf:** only when `HasRoom`. Use `restockPick` over views of `GetShelves` (Products only) and
     `GetRacks`.
     - Walk to the rack, `TakeFromRack(pick.productId)` (nil: plan again), `MakeWorkerBox`, `carry`, status
       `WORDS.restocking`.
     - Then the existing shelf-after-shelf loop.
     - Leftovers, and a mistake: `StoreInRack` on a rack with room (walk there), else `putBack`.
  - **Idle:** "Idle: no boxes" with nothing anywhere. `WORDS.idleFull` when pad boxes wait but no shelf or rack takes
    them. "Idle: shelves full" otherwise.
- [ ] **Step 2:** `lune run tests/run` and `rojo build`. Expected: pass, exit 0.
- [ ] **Step 3: Commit** with message `Restockers: pad boxes to racks, racks to low shelves`.

### Task 8: Pish's lesson, dev commands and the admin panel

**Files:**
- Modify: `src/shared/Config/Pish.luau` LESSONS: `{ id = "storageRack", level = 5, icon = "Box", shelf = "StorageRack",
  on = "placed" }`, after condenser.
- Modify: `src/shared/Config/PishTalk.luau`:
  - `LESSONS.storageRack = "Storage racks are here! Keep extra boxes in them."`.
  - `AFTER.storageRack = { "Carry a box over and press Store.", "Press Open to see the sheet and take one back.",
    "Restockers fill racks when your shelves are full!" }`.
- Modify: `src/server/Services/DevService.luau`:
  - `/storage fill [productId]`: every rack is filled to 9 with that product's full boxes, or a mix of the orderable
    products.
  - `/storage clear`: `PlacementService.ClearRacksForTesting`.
  - Both are Studio-only, like the others.
- Modify: `src/shared/Config/AdminPanel.luau`: a section `"Storage"` with "Fill my racks" (`/storage fill`) and "Empty
  my racks" (`/storage clear`).
- Test: `tests/LessonRules.spec.luau`:
  - The lesson count becomes 16, with its message naming the storage rack.
  - New: `LessonRules.onPlaced(Pish.LESSONS, "StorageRack", "Storage", {})` is "storageRack".
  - `tests/TalkRules` checks the new lines' length as it is.

- [ ] **Step 1: Write the test changes.** Run. Expected: FAIL (15 lessons, nil).
- [ ] **Step 2: Implement.** Run `lune run tests/run`. Expected: all pass. TalkRules fails if a line is too long: then
  shorten the line, keeping its meaning.
- [ ] **Step 3: Commit** with message `Storage racks: Pish's lesson, /storage, admin buttons`.

### Task 9: Docs

**Files:**
- Modify: `DESIGN.md`:
  - 4.2 "Storage racks" (storing, the clipboard, taking, the 12 spots).
  - 4.3 (the rack in the catalogue, its own cap).
  - 7.4 (restocker trips, walk 8 to 14).
  - 10.4 (schema v43).
  - The file tree (StorageRules, Config/Storage, StorageRackLook, BoxLook, StorageController).
  - Mark it built on 2026-11-24, waiting on the owner's check.
- Modify: `CLAUDE.md`:
  - The tests list gets StorageRules, with JobRules' walk speed, EditBarRules', ShopTips' and StockHint's additions.
  - The dev commands get `/storage fill|clear`.
- [ ] **Step 1:** Write the docs. Run `lune run tests/run`; expected: all pass.
- [ ] **Step 2: Commit** with message `Storage racks: docs`.

### Task 10: Studio check (Play, test save)

- [ ] **Step 1: Prepare.** Restart Rojo serves for all three places (main 34872, Frontier 34873, Dungeon 34874),
  then Play the main place (the test save).
- [ ] **Step 2: Place and store.** Place a rack by dev (`PlacementService.DevPlace` via `/stock`-style admin, or the
  Build menu). Then:
  - Check the look A stand-in.
  - Carry a pad box to it: the Store prompt words, store, the hop.
  - Use `/storage fill`, then Store on a full rack: the words and the locked card.
- [ ] **Step 3: Open and take.** Check the clipboard against mockup C (screenshot), TAKE, the box in your arms, and
  the two Review Focus refusals (hands full, pad full).
- [ ] **Step 4: Restocker.** On the test save, put a Restocker on and watch the trips: pad to rack when shelves are
  full, rack to a low shelf. Check the walk speed attribute values.
- [ ] **Step 5: Leave and rejoin.** Stop and Play again: the boxes are back on their racks.
- [ ] **Step 6: Check Output.** No errors. Report what changed on the test save.
