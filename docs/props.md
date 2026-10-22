# Town props

The main town is built in code (`TownService`, `PlotService`). Every decoration is a **prop slot**: save a
model as `assets/props/<Slot>.rbxm` and it replaces the code-built stand-in. Rojo syncs `assets/props` to
`ServerStorage.PropModels` (server only). A missing, empty or too-big file never breaks the town: that slot just
shows its stand-in.

## Slots

| File (and variants) | Used for | Height (studs) | Collides |
|---|---|---|---|
| `Lamp` | street edges | 9 | yes |
| `Bench` | around the healing spring | 3 | yes |
| `Fence` | one section, repeated every 6.5 studs round the island's edge | 4 | yes |
| `Portal` | frame around each plaza portal ring | 14 | no |
| `Register` | left end of each shop's register counter, full depth; turned -90° in code (`yaw`) | fits 2.4 x 2.2 x 2 | no |
| `CounterDecor` | back of the counter, right end | fits 0.8 x 1.2 x 0.6 | no |
| `Computer` | the order computer (ORDER STOCK); moves with it | fits 4 x 3 x 2 | (its own hitbox) |
| `Condenser` | the Card Condenser | fits 4 x 5 x 4 | (its own hitbox) |
| `Counter` | the register counter; stretched along it when built from plain blocks | fills 6 x 3.5 x 2 | (its own hitbox) |
| `GlassCase` | the look of the Collector Case: a glass cabinet stretched to fill the case; cards stand inside behind the glass | fills the case | (the case's own hitbox) |
| `Awning` | shop fronts: repeated across each front, top at the wall top; parts named `COLOUR ME` take the plot's awning colour | about 5 deep, fills the front | no |
| `Shelf` | the look of Products shelves (pack racks); turned 90° in code (`yaw`), stretched to fill the rack (`stretch`, plain blocks only) | fills the shelf | (the shelf's own hitbox) |

**Variants:** a slot also uses every file named after it plus a suffix starting with a capital letter or digit:
`Tree.rbxm`, `TreeA.rbxm`, `TreeB.rbxm` ... or `FlowerBlue.rbxm`, `FlowerPink.rbxm`. The game takes them in turn
(sorted by name), so every server looks the same. One file per model: a file with several models at its top level
stops Rojo from building (group them into one Model first, or save each one on its own).

Fixtures (Computer, Condenser, Counter, and shelves with a `prop`) keep their old block until the model file
exists; then the block becomes an invisible hitbox under the model.

Numbers live in `Config/Town.luau` (`SLOTS`).

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
