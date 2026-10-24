# Town props

The main town is built in code (`TownService`, `PlotService`). Every decoration is a **prop slot**: save a
model as `assets/props/<Slot>.rbxm` and it replaces the code-built stand-in. Rojo syncs `assets/props` to
`ReplicatedStorage.PropModels`: the server builds the town and shops with them, and each client builds
placement ghosts (a see-through copy of what you are placing) from the same models. A missing, empty or too-big file never breaks the town: that slot just
shows its stand-in.

## Slots

| File (and variants) | Used for | Height (studs) | Collides |
|---|---|---|---|
| `StreetLight` | sidewalks at every plot gap and row end; the arm reaches over the street along the model's -Z | 11 | yes |
| `Bench` | around the healing spring | 3 | yes |
| `Hedge` | one section, repeated every 6.5 studs round the island's edge | 3 | yes |
| `Portal` | frame around each plaza portal ring; its Neon parts take the portal's colour (`Town.PORTAL_EFFECTS`), particles come from code | 14 | no |
| `Register` | left end of each shop's register counter, full depth; turned -90° in code (`yaw`) | fits 2.4 x 2.2 x 2 | no |
| `CounterDecor` | back of the counter, right end | fits 0.8 x 1.2 x 0.6 | no |
| `Computer` | the order computer (ORDER STOCK): a desk set, turned 90° in code; moves with it | fits 10 x 5.5 x 6 | (its own hitbox) |
| `Condenser` | the Card Condenser: a starry glass "blender" (effects trimmed to 7) | fits 6 x 7 x 6 | (its own hitbox) |
| `Counter` | the register counter: a market stall, its front on the counter's front, reaching back over the cashier | fits 6.6 x 7.2 x 4.2 (`COUNTER.STALL`) | (the counter's own hitbox) |
| `WallShelf` | the Wall Shelf | fits 8 x 8 x 2 | (its own hitbox) |
| `HookRack` | the Accessory Hook: a pegboard, stood upright in code (`roll`) | fits 4 x 7 x 2 | (its own hitbox) |
| `DisplayRack` | the Big Display Rack (double-sided), turned 90° and stretched | fills 8 x 7 x 4 | (its own hitbox) |
| `Showcase` | the Glass Showcase and the Collector Case: a glass counter; cards lie on the bed (`cardsFlat`, `Showcase.FLAT`); the Collector Case recolours its Support, Frame and Carpet parts (`propColors` in Config/Shelves) | fills 6 x 4 x 2 | (its own hitbox) |
| `DeliveryPad` | the delivery spot: a pallet; delivered boxes stand on it | fills 6 x 1 x 6 | no |
| `BoxPacks`, `BoxSleeves`, `BoxDecks`, `BoxBooster` | each product's delivery box (Products `boxProp`), welded to the box so it travels when carried; without a model the box gets a band in the product's colour and its name (`Stock.BOX_LABEL`) | fits 2.5 x 1.5 x 2 | no |
| `Shelf` | the look of Products shelves (pack racks); turned 90° in code (`yaw`), stretched to fill the rack (`stretch`, plain blocks only) | fills the shelf | (the shelf's own hitbox) |

**Variants:** a slot also uses every file named after it plus a suffix starting with a capital letter or digit:
`Tree.rbxm`, `TreeA.rbxm`, `TreeB.rbxm` ... or `FlowerBlue.rbxm`, `FlowerPink.rbxm`. The game takes them in turn
(sorted by name), so every server looks the same. One file per model: a file with several models at its top level
stops Rojo from building (group them into one Model first, or save each one on its own).

Fixtures (Computer, Condenser, Counter, and shelves with a `prop`) keep their old block until the model file
exists; then the block becomes an invisible hitbox under the model.

Numbers live in `Config/Town.luau` (`SLOTS`).

## Models with unions (PlaceProps)

Rojo's live sync can't carry union (CSG) shapes: a synced UnionOperation arrives empty and invisible. So models
that contain unions do **not** go in `assets/props`. Their copies are kept in `assets/place-props/` (git only, not
synced), and the real ones live in the place file under `ReplicatedStorage.PlaceProps`:

1. In Studio's Explorer, right-click `ReplicatedStorage.PlaceProps` → **Insert from File…** → pick the `.rbxm`
   from `assets/place-props/`. Insert from File keeps union shapes.
2. Save the place (and publish), since PlaceProps lives in the place file.
3. After changing one in Studio, Save to File over its copy in `assets/place-props/` and commit.

`Props` looks in `PlaceProps` first, then `PropModels`. The Lune test fails if a file in `assets/props` or
`assets/town` contains a union, and checks `assets/place-props` for scripts like the rest.
Today: Condenser, Counter, HookRack, Register, WallShelf.

## Hand-placed decor (TownDecor)

Trees, bushes, flowers, rocks, crates and other scenery are placed by hand in Studio, not by code. They live in
one Model, `TownDecor`, saved as `assets/town/TownDecor.rbxm`; Rojo syncs `assets/town` to `Workspace.TownDecor`
(main game only). The Inno pieces in `assets/props` (TreeA, PineA, FlowerBlue, RockA ...) are the source pieces
for it.

- Editing: work on a copy outside `Workspace.TownDecor` (Rojo owns that folder and resets it on sync), then
  right-click the Model → Save to File over `assets/town/TownDecor.rbxm`, delete the copy, and commit.
- Keep out of the plots, the street, the shop fronts, the open ring round the plaza and the space in front of
  the portals. Anchor everything; no scripts (the Lune test checks `assets/town` too, and the server strips
  them at start).

## Adding a prop

1. In Studio, drag the model from the Toolbox or Asset Manager into the Workspace.
2. Delete every Script and LocalScript inside it (Explorer search: `ClassName:Script`).
3. Check its front faces **-Z**. If not, give the Model a number attribute `YawOffset` (degrees, e.g. `180`).
4. Rename the Model to the slot name, right-click → **Save / Export → Save to File**, and save it as
   `assets/props/<Slot>.rbxm`. Delete it from the Workspace.
5. Run `lune run tests/run`: it fails if any prop still holds a script. Stop → Play to see it.

Size doesn't matter: the game scales each prop to its slot height (or fits it in its box) and stands it on the
ground. Turn it with `YawOffset`, not by rotating parts: fitted props use the turned size.

## Rules the game applies

- **No scripts.** The Lune test is the gate; the server also strips scripts, sounds, prompts, click detectors
  and tools from every prop it places.
- **Part cap.** More than `MAX_PROP_PARTS` (150) parts → the stand-in is used.
- **Budget.** Aim for under 2k triangles per prop and under 60k for the whole town.
- Every prop is anchored and never fires touch events; non-colliding props are also skipped by raycasts.

## Licences

Inno's Stylized Asset Pack allows commercial use without credit (no redistribution). Check every other model's
licence and creator before launch, and plan original art later (DESIGN 5.5).
