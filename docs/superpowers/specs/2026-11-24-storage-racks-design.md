# Storage racks: design

Date: 2026-11-24. Branch `storage-racks`.

## What the owner asked for

> "I want storage system where box can be put to storage racks. also pets can also carry boxes to the storage racks.
> adjust the restocker walking speed to be slower than normal walking speed, fastest will still be a little bit slower
> than when its summoned from party."

> "placement of storage racks doesnt have to be the backrooms. it's the players choice as to where he put the storage
> racks."

Picks from the mockups (owner, 2026-11-24):

- Rack look **A**, the warehouse rack: https://claude.ai/artifact/Po97JXGAsEWbzdsqgXChAW.
- Taking boxes **3**, one prompt that opens a window. The owner added: "redesign the window not just a plain list".
- Window design **C**, the stock clipboard: https://claude.ai/artifact/Kya78gJEZNvM3m25VV5GmA.
- "Numbers OK" covers every number on the first mockup page.

**Why (my reading, not stated):** the delivery pad holds 12 boxes, counting boxes on order and boxes in someone's
hands. A shop can't keep stock on hand past that. Racks give the shop a stockroom, and pets hauling boxes make it feel
alive.

## Goals

- A Storage Rack you buy in the Build menu and place anywhere in your shop, like any shelf.
- **Storing:** carry a box to a rack and press Store; it goes on the rack.
- **Taking:** press Open on a rack to see its stock clipboard, then TAKE a box into your arms.
- **Restockers:**
  - They move pad boxes no shelf can take onto racks.
  - They restock low shelves from racks.
- Restockers walk slower than the player. The fastest is a little under a summoned pet, which keeps the player's pace
  (16 studs a second).
- Boxes on racks are saved and never lost.

## Non-goals

- Customers never buy from a rack. It is not a selling shelf.
- No carrying more than one box at a time (the Carry Cart upgrade stays a separate idea).
- "Remove" on a selling shelf still boxes its stock onto the pad, not onto a rack.
- The order computer does not show storage.
- Racks exist only in the main place's shops (PlacementService runs only there).

## The rack

- **Config/Shelves entry:**

  | Field | Value |
  |---|---|
  | id | `StorageRack` |
  | name | "Storage Rack" |
  | kind | `"Storage"` (a new ShelfKind) |
  | category | `"Shelves"` (the Build menu's Shelves tab) |
  | capacity | 9 (boxes) |
  | cost | 400 |
  | unlockLevel | 5 |
  | size | 10 x 7 x 2 studs |
  | prop | `"StorageRack"` |

- **Look A** (the mockup):
  - Navy steel posts, orange beams front and back, plywood decks, side bracing.
  - A yellow STORAGE sign on the top beam.
  - Three shelves, the deck tops 0.45, 2.7 and 4.95 studs up, each with three box spots 3 studs apart. Spot 1 is
    the bottom shelf, the left spot as you face the rack; spots run left to right, then up.
- **Model:** code-built from parts, like the selling shelves (`Town.SLOTS` `StorageRack = { built = true }`, drawn by
  `Util/StorageRackLook`). It is the same build the owner picked in the mockup, so there is no Blender model or import
  step. Planning found the selling racks are code-built (`Util/ShelfLooks`); the approved spec had said Blender.
- **Cap:** up to 4 racks per shop (`Placement.MAX_STORAGE_PER_PLOT`). Racks have their own count and use none of the
  30 selling-shelf spots, like decor's cap. A 5th is refused with the locked card: "Your shop has room for 4 storage
  racks. Sell one to make space."
- **Build menu:**
  - The tile's detail line: "Holds 9 boxes".
  - Its tooltip (ShopTips): "Store delivery boxes here. Restockers use it too."
  - It is a Build menu item at Lv 5, so the main quest strip and the NEW tag pick it up like any shelf.
- **Edit bar:**
  - Move: the boxes move with the rack.
  - Sell: locked until the rack is empty ("Take the boxes off first").
  - Fill line: "8 / 9 boxes", or "Empty · 0 / 9".
- **Customers, rating, offline sales:** a rack is not a selling shelf, so it is left out of all of them.

## Boxes on a rack

- **Data:** each rack keeps its boxes as plain data, spot to `{ productId, units }`, in PlacementService, saved with
  the layout.
- **Look:** each box is drawn as the real delivery box model of its product, placed on its spot.
  - Only the front sticker is kept, since the back faces the wall.
  - The sticker's SurfaceGui MaxDistance is `ShopDetail.SCREEN_DISTANCE`, so ShopLod shortens it for visitors.
  - The box parts are named `StockBox` under the rack, so the stock LOD hides them in far shops (past 80, back within
    72).
- **Arrangement:** a box goes next to its own kind, in the first free spot after the last box of that kind. With none
  of its kind on the rack, it takes the first free spot.
- **Attributes on the rack part** (for the client):
  - `StoredCount`.
  - `Stored`: a compact string of the spots, `slot:productId:units` joined by `;`.
  - `LastWorker`: the card name of the restocker that last stored or took a box there.

## Storing (the owner)

- **Prompt:** carrying a box near your rack, its E prompt says **Store** with the box's product name.
- **Server checks:** you own it, you are within `Stock.INTERACT_DISTANCE`, you carry a box, and it has room.
- **What happens:**
  - The carried box leaves your hands and lands on its spot with a quick hop (0.3 s arc). Everyone near sees the hop,
    as with the unboxing.
  - `CarryCount` drops, so your arms come down.
- **Full rack:**
  - Before you press, the prompt already reads "Rack full · 9 / 9".
  - Pressing anyway shows the locked card: "This rack is full. Take a box off, or place another rack."
- **Glow:** while you carry a box that no selling shelf can take, your racks with room glow with the same gold hint as
  shelves (Util/StockHint).

## Taking: the stock clipboard (design C)

**Opening.** With empty hands near your rack, the E prompt says **Open**, with "Storage Rack · 8 boxes" (or "Storage
Rack · empty"). It opens the clipboard. The F prompt (Edit) sits below it, offset, like the machines'.

**The look**, matched exactly to mockup C:

- **Board:** a wooden clipboard, its wood running light to dark, with a darker drop under it.
- **Clip:** a metal clip at the top middle holding the paper.
- **Paper:** off-white, with faint blue ruled lines and a red margin line.
- **Header:**
  - Title "STORAGE RACK".
  - Under it: "8 of 9 spots · counted by Cindercub". "counted by" names the rack's `LastWorker` and is left off
    when there is none.
- **One line per kind on the rack, in shelf order:**
  - Its picture as a sticker, a little tilted, with a strip of tape.
  - Its short plural name: "Booster Packs", "Deck Boxes", "Card Sleeves", "Booster Box", "Frontier Packs", "Bulk
    Cards".
  - One tally mark per box ("III").
  - The units inside ("62 packs").
  - A pink **TAKE** stamp button, slightly tilted.
- **Footer:** "Carry a box here to add it to the sheet."
- **Close:** the pink close X on the board's top right corner.
- **An empty rack:** one line, "Nothing stored yet."

**TAKE:**

- **Server checks:**
  - You own the rack and are near it.
  - Your hands are empty.
  - That kind is on the rack.
  - The 12 shared box spots have room: a box in your hands counts like a pad box.
- **What happens:**
  - It takes the box of that kind with the fewest units, so half-used boxes go first.
  - The box hops from the rack into your arms, and the window closes.
- **Refusals** (locked card, never silent):
  - "Your hands are full."
  - "Your delivery pad is full. Put a pad box on a shelf or a rack first."

**Live:** while the clipboard is open it follows the rack. A restocker storing or taking updates its lines, and a rack
that is sold or moved away closes it.

**Window rules:**

- It opens one window at a time and hides the thumbstick and jump button, like every window (built on `UIKit.panel`,
  see-through, with the clipboard drawn inside).
- It fits a landscape phone.
- Its text keeps to the game's rules: plain ASCII plus `·`.

## Restockers (JobService)

**Each trip a restocker does the first of these that applies:**

1. **Pad to shelf:** a pad box some selling shelf can take goes to that shelf. This is today's behaviour.
2. **Pad to rack:** a pad box no selling shelf can take goes to the nearest rack with room. Status: "Storing a
   <product>".
3. **Rack to shelf:** with nothing on the pad for steps 1 and 2, it finds a selling shelf half full or less, or an
   empty one that takes a product on a rack.
   - It takes that product's box with the fewest units off a rack and stocks the shelf. Status: "Restocking from
     storage".
   - Leftover units go to the next shelf that takes them.
   - If no shelf takes the rest, the box goes back to a rack with room, else to the pad.

**Idle:** with shelves and racks both full, the status reads "Idle: shelves and storage full". The other idle lines
stay as they are.

**Safety rules:**

- **Re-check on arrival:** a rack or shelf can change while the restocker walks to it (the owner took the box, sold
  the rack, filled the spot). It re-checks when it gets there and plans again.
- **Mistakes:** a dropped box goes back to where it came from. A pad box returns to the pad. A rack box returns to a
  rack with room, else the pad.
- **Box count:** a box in a restocker's arms counts toward the 12 shared spots, as now. So step 3 waits when the pad's
  spots are all used.
- **Counted by:** the rack's `LastWorker` becomes the restocker's card name.

**New APIs:**

- **StockService:**
  - Make a worker box from `{ productId, units }`, counted like any worker box.
  - Remove a worker box once it is stored.
- **PlacementService:**
  - Racks with room.
  - Store into a spot.
  - Take a box of a kind.
  - The low selling shelves.

## Walk speed (every worker)

- **New rule:** walk speed is 8 + 6 x (factor - 0.4) / 2.1 studs a second. The factor is today's work speed, (SPD /
  14)^1.5 clamped to 0.4 to 2.5.
  - The slowest card walks 8.
  - A fresh Very Rare walks 9.7.
  - A fresh Legendary walks 11.7.
  - The fastest walks 14.
  - The player, and the summoned pet that keeps the player's pace, stay at 16.
- **Unchanged:** being tired still multiplies the walk by 0.6, and work times (stocking, scanning) stay as they are.
- **Config:** `Jobs.WALK_SPEED` (12) becomes `Jobs.WALK = { min = 8, max = 14 }`, with `JobRules.walkSpeed`.
- **My call:** the cashier uses the same rule (one rule for all workers). It walks little anyway.

## Saving (schema v43)

- **Shape:** `SavedShelf` gains `boxes: { { slot: number, productId: string, units: number } }?`, on storage racks
  only.
- **Migration:** old saves have no racks, so the v43 step only bumps the version. It still gets a Lune test, and
  DESIGN 10.4 records it.
- **Load checks:**
  - The product is known.
  - Units are floored and kept between 1 and the product's `unitsPerBox`.
  - The spot is 1 to 9 and used once. A box with a bad or repeated spot goes to the next free spot.
- **Never lost:**
  - Boxes past the rack's 9, or the boxes of a rack that can't be restored anywhere on the plot, go onto the pad
    while it has room.
  - The rest are paid back as cash at their share of the box price, with a toast saying so.

## Pish's lesson

- **When:** a lesson the first time a rack is placed (`on = "placed"`), at level 5, like the machines and cases:
  `{ id = "storageRack", level = 5, icon = "Box", shelf = "StorageRack", on = "placed" }`. Saves already past level 5
  get it the first time they place one, so it needs no `late`.
- **His first line:** "Storage racks are here! Keep extra boxes in them."
- **Then, by the rack:**
  - "Carry a box over and press Store."
  - "Press Open to see the sheet and take one back."
  - "Restockers fill racks when your shelves are full!"
- Every line stays short (tests/TalkRules).

## Dev and admin (Studio only)

- `/storage fill [product id]` fills your racks with boxes; with no product, a mix.
- `/storage clear` empties them.
- The admin panel's Storage section has both as buttons.

## Approaches considered

- **Where box contents live:**
  - **Chosen:** plain data on the rack in PlacementService, saved in the layout. A rack and its boxes move, sell and
    save together.
  - **Rejected:** box parts owned by StockService, with saved boxes pointing at racks. Shelf ids change every load,
    so a saved pointer can't find its rack.
- **Box count:**
  - **Chosen:** rack boxes sit outside the pad's 12 shared spots, so storage really adds room.
  - **Rejected:** counting them, which would make racks add nothing.
- **Taking a box** (owner's pick 3):
  1. A prompt on every box.
  2. One kind per shelf, with labels.
  3. One prompt that opens a window.
- **The window** (owner's pick C):
  - A: a drawing of the rack.
  - B: product cards.
  - C: a stock clipboard.

## Left to the builder

- The clipboard's exact pixel sizes on each screen, within the mockup's proportions.
- The hop's curve.
- The stand-in rack's part list.
- Which rack counts as "nearest" when two are close (straight-line distance from the box is fine).
