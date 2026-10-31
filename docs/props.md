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
| `Terminal` | the POS terminal at the left end of each shop's checkout counter, full depth; screen toward the cashier (+Z) | fits 2.4 x 2.2 x 2 | no |
| `CounterDecor` | back of the counter, right end | fits 0.8 x 1.2 x 0.6 | no |
| `Computer` | the order computer: a code-built modern workstation (`built`: white desk on black legs, a widescreen showing ORDER STOCK, keyboard, plant, drawers, office chair); a model file would replace it; moves with it | fits 10 x 5.5 x 6 | (its own hitbox) |
| `Condenser` | the Card Condenser: code-built (`built`, `CONDENSER_LOOK`), in the scan pod's style; its Rotors (the crystal with three cards, two rings of small cards) spin on each client | fills 6 x 7 x 6 | (its own hitbox) |
| `WallShelf` | the Wall Shelf: code-built (`built`, Util/ShelfLooks) | fills 8 x 7 x 2 | (its own hitbox) |
| `HookRack` | the Accessory Hook: a code-built pegboard with hooks (`built`) | fills 4 x 7 x 2 | (its own hitbox) |
| `DisplayRack` | the Big Display Rack: code-built, double-sided (`built`) | fills 8 x 7 x 4 | (its own hitbox) |
| `CardCase` | the Glass Showcase and the Collector Case: code-built (`built`, Util/CaseLook, `CASE_LOOK`), a glass case whose cards stand upright and spin over rarity beams (`cardsUpright`, CaseSpinController); the Collector Case recolours its Support, Frame, Carpet and Strip parts (`propColors` in Config/Shelves) | fills 6 x 4 x 2 | (its own hitbox) |
| `BoxPacks`, `BoxSleeves`, `BoxDecks`, `BoxBooster` | each product's delivery box (Products `boxProp`), welded to the box so it travels when carried; without a model the box is a branded case drawn on it (`Stock.CASE`: product colour, art in a gold frame, name, count pill, hand holes) | fits 2.5 x 1.5 x 2 | no |
| `Shelf` | the Small Pack Rack: a code-built one-sided gondola (`built`) | fills 4 x 7 x 2 | (the shelf's own hitbox) |

**Variants:** a slot also uses every file named after it plus a suffix starting with a capital letter or digit:
`Tree.rbxm`, `TreeA.rbxm`, `TreeB.rbxm` ... or `FlowerBlue.rbxm`, `FlowerPink.rbxm`. The game takes them in turn
(sorted by name), so every server looks the same. One file per model: a file with several models at its top level
stops Rojo from building (group them into one Model first, or save each one on its own).

Fixtures and shelves with a `prop` keep their old block until the model file exists; then the block becomes an
invisible hitbox under the model. A slot marked `built = true` (Computer, Condenser, the four product shelves) uses its
code-built look the same way, with no file. The checkout counter, POS terminal (Terminal slot) and delivery spot are built in code.

Numbers live in `Config/Town.luau` (`SLOTS`).

## The healing fountain (BloomFountain)

Not a slot: `Server/Util/BloomFountain` uses `PropModels.BloomFountain` when it exists and a part-built stand-in until
then. The model is built in Blender by `tools/blender/build_bloom_fountain.py` (run it through the Blender MCP:
`exec(open(path).read())`; it writes `assets/blender/BloomFountain/BloomFountain.{blend,fbx}` and its palette). Its
objects must keep their names: `Body` (stone, petals, pads, cup; palette texture), `Water`, `Crystal` and
`Gem_<Element>` for the five elements; the game recolours the last three as glowing parts and scales the model so the
Body is `Plaza.FOUNTAIN_RADIUS` round. To update it:

1. Studio → Import 3D → `BloomFountain.fbx` (default settings). It lands in Workspace as a Model.
2. Check the part names, right-click the Model → **Save to File…** → `assets/props/BloomFountain.rbxm`.
3. Delete the Workspace copy (the import isn't anchored, so in Play it falls apart beside the shop); Rojo syncs the
   file into PropModels. Stop and Play to see it.

## The caldera's props (Volcano, CharredTree, ObsidianShards)

Placed by SceneryService from `Config/Scenery` (`VOLCANO`, `CHARRED_TREES`, `SHARDS`), scaled to each spot's height on
the drawn ground, anchored, no collisions; until a file is saved the canyon builds without it (a warning). Built in
Blender by `tools/blender/build_volcano.py`, `build_charred_tree.py` and `build_obsidian_shards.py` on `portal_kit.py`
(open an empty file first, then run the script in a separate call; `EXPORT=0` builds without saving). Names matter
(`tests/CreatureAssets` checks the saved files): the volcano's `Body`, `Lava` (made glowing) and `Fx_Smoke` (hidden; the
plume rises from it), the shards' `Frame` and `Lava`, the tree's `Frame`. Import, save and delete the Workspace copy as
for the portals below.

## The town portals (PortalWild, PortalFrontier, PortalArena)

Slots of their own (`Town.SLOTS`), about 28 studs tall, placed where the portal frame stood; until a portal's file
exists today's `Portal` frame stands in (`Util/PortalLooks.slot`). Each is built in Blender by
`tools/blender/build_portal_<wild|frontier|arena>.py` on `portal_kit.py` (run through the Blender MCP: open an empty
file first, then `exec(open(path).read())`; `EXPORT=0` builds without saving). They write
`assets/blender/Portal<World>/Portal<World>.{blend,fbx}` and a palette, and print triangles (at most 4,000 each).
Object names matter (`Util/PortalLooks.parts`, checked by `tests/CreatureAssets` on the saved files): `Frame` (the
model, palette texture), `Opening` (a flat disc filling the arch: the game hides it and draws the vortex there),
`Fx_*` markers (hidden: where a trickle, drip, splash or mist starts) and glow parts (`Pool`, `Flowers`, `Lava`: the
game makes them glowing colour). The front faces -Y in Blender. Colours and effects: `Town.PORTAL_LOOKS`. To update one:

1. Studio → Import 3D → the `.fbx` (default settings).
2. Check the part names, right-click the Model → **Save to File…** → `assets/props/Portal<World>.rbxm` (over the old one).
3. Delete the Workspace copy (unanchored: it falls apart in Play). Stop and Play to see it.

The Wild valley reuses two of them (WildService): each boss portal is `PortalArena` scaled to 20 studs
(`WildValley.BOSS_PORTAL`) with the purple `Boss` look (`Town.PORTAL_LOOKS.Boss`: swirl, light and its `Lava` glowing
purple), and each arena copy's way home, like the valley's arrival, is `PortalWild` with its own look. The valley's
volcano is the caldera's `Volcano` (`WildValley.VOLCANO`), dressed like the canyon's: anchored, its `Lava` glowing.

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
Today: none. (A `built` slot ignores model files, so old Counter, Register, WallShelf, HookRack or Condenser copies
left in the place's PlaceProps do nothing and can be deleted.)

## Hand-placed decor (TownDecor)

Trees, bushes, flowers, rocks, crates and other scenery are placed by hand in Studio, not by code. They live in
one Model, `TownDecor`, saved as `assets/town/TownDecor.rbxm`; Rojo syncs `assets/town` to `Workspace.TownDecor`
(main game only). The Inno pieces in `assets/props` (TreeA, PineA, FlowerBlue, RockA ...) are the source pieces
for it.

- Editing: work on a copy outside `Workspace.TownDecor` (Rojo owns that folder and resets it on sync), then
  right-click the Model → Save to File over `assets/town/TownDecor.rbxm`, delete the copy, and commit.
- Save the **Model** (`Workspace.TownDecor` → `TownDecor`), not the outer folder: saving the folder wraps the Model in
  extra folders (it happened once, 2026-10-30, and was unwrapped with Lune).
- Keep out of the plots, the street, the shop fronts, the open ring round the plaza, the trail mouths at both street
  ends (Portal Worlds: `Town.PORTAL_AREAS`; five pieces were moved clear of them on 2026-10-30) and the space round
  the arches and signposts. Anchor everything; no scripts (the Lune test checks `assets/town` too, and the server
  strips them at start).
- The scenery outside the island (the portal areas, the hills, the grove between the east trails) is code-built from
  `Config/Scenery` by `SceneryService`, not hand-placed: giant trees and pines are scaled copies of the pieces in
  `assets/props` (a single-mesh piece is wrapped in a Model), standing on the drawn terrain.

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
