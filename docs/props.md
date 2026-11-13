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
purple). The valley's arrival is `PortalWild`; each boss arena copy's way home is in its zone's look
(`WildValley.ARENA_HOME`): `PortalWild` in the grove, `PortalFrontier` (the ice-blue crystal ring) in the hollow,
`PortalArena` with the canyon's lava on the lava field. The valley's volcano is the caldera's `Volcano`
(`WildValley.VOLCANO`), dressed like the canyon's: anchored, its `Lava` glowing; the lava field's backdrop is the same
model.

## The Wild boss arenas' props (StandingStone, Stalagmite, Web, Cocoon, Bones, CaveDome, LavaCliff)

Built in Blender by `tools/blender/build_arena_props.py` on `voxel_kit.py` and `portal_kit.py`, in the caldera props'
smooth look (run through the Blender MCP; `PROPS="A,B"` builds only those, `EXPORT=0` builds without saving). Each is
its own `assets/blender/<Name>/<Name>.{blend,fbx}`: a `Frame` with the palette texture and, for the lava cliff, `Lava`
(the cracks, which the game turns glowing). Import with default settings, save as `assets/props/<Name>.rbxm` unchanged
and delete the Workspace copy: WildService (`arenaPiece`) anchors each piece where it places it, turns off shadows on
small ones and collisions on the roof and the backdrop, and makes `Lava` parts glow. The arenas' layouts are
`WildValley.ARENA_DRESSING` (walls, inner pieces, roof or backdrop, by zone); a Lune test checks every model they name
has a saved file. Under each copy a flat ground part runs on past the walls (`WildValley.arenaApron`, colours by zone in
`ARENA_CLEARING.apronColors`, matched by eye: a part's material draws lighter or duller than the same terrain's).

## Valley scenery props (GlowMushroomTall ... DragonSkeleton)

The Wild valley's scenery round (spec 2026-11-04-valley-scenery-design): `GlowMushroomTall`, `GlowMushroomCluster`,
`GlowMushroomSmall`, `GlowTuft`, `GlowFlowers`, `MossRockA`, `MossRockB` (the Caves); `RuinArch`, `RuinPillar`,
`RuinPillarBroken`, `RuinPillarFallen`, `RuinWall`, `Toadstool` (the Meadow; its standing stones are the arenas'
`StandingStone`); `EmberTree`, `DragonSkeleton` (Ember Ridge). Built by `tools/blender/build_valley_props.py` on
`voxel_kit.py` and `portal_kit.py`, each its own `assets/blender/<Name>/<Name>.{blend,fbx}`: a `Frame` (palette texture)
and, for the glowing ones, `Glow` (palette white). Run it in a **background** Blender, never the open one (`begin()`
clears the scene): `blender -b --factory-startup --python tools/blender/build_valley_props.py` (`PROPS="A,B"`,
`EXPORT=0` as above); each stays under 2000 triangles, the skeleton under 4000. `render_valley_props.py -- <out_dir>`
renders a preview of each. Import each FBX with default settings, save it as `assets/props/<Name>.rbxm` unchanged and
delete the Workspace copy: SceneryService (`dressValleyProp`) anchors each piece, turns off collisions, camera and touch
on its parts, makes `Glow` Neon in the spot's `glow` colour (`Config/WildValley GLOW`), drops shadows from small ones
and adds the invisible colliders in `COLLIDERS`. Positions are `Config/WildValley`'s scenery lists.

## Valley backdrop props (GiantTreeA/B/C, MountainSnow, MountainDark)

Round 2 of the Wild valley (spec 2026-11-05-valley-natural-design): three giant ancient trees (green, autumn, pink
blossom) and two far mountain range pieces (snowy, dark jagged), built by `tools/blender/build_valley_backdrop.py` in the
same way as the valley scenery props above (background Blender, `PROPS=`, `EXPORT=0`, under 4000 triangles each; render
previews with `MODULE=build_valley_backdrop` on `render_valley_props.py`, one model per run if EEVEE crashes). Each is
one `Frame`. Import and save as `assets/props/<Name>.rbxm`. SceneryService places the giant trees framing the trail
from `GIANT_TREES` (dressed with colliders) and every backdrop piece from `BACKDROP` / `MOUNTAINS` (`buildBackdrop`: no
colliders, backdrop streamed `Atomic`, mountains `Persistent` and shadowless at their own `y`).

## Frontier scenery props (Tent ... IceThrone)

The Frontier valley's Titans' Graveyard pieces (spec 2026-11-10-frontier-valley-design): the camp's `Tent`, `Campfire`
and `Watchtower`; Frostwood's `Ribcage` (the trail walks through it), `GiantSword`, `FortRuin`, `FortWall`, `SnowPine`;
Stormpeak's `WreckedTower`, `HornedSkull`, `RockSpire`, `StormStone`; the Rift's `FloatingRock` and `CrystalArch`
(built, not placed since the Dungeon gate became a portal model, 2026-11-10); the dead giant's `TitanSkull`; the Frost Tyrant's hall's `IcePillar` and `IceThrone`. Built by
`tools/blender/build_frontier_props.py` on `voxel_kit.py` and `portal_kit.py` (background Blender, `PROPS=`, `EXPORT=0`
as above; under 2000 triangles each, the ribcage and both skulls under 4000; previews with
`MODULE=build_frontier_props` on `render_valley_props.py`). Unlike the Wild's props they come as ONE pack, so they
import once: `assets/blender/FrontierProps/FrontierProps.fbx` holds every prop as an Empty `<Name>` over its meshes
`<Name>__Frame` / `<Name>__Glow`. Import it with default settings, save the imported model as
`assets/props-import/FrontierProps.rbxm` (gitignored), then `lune run tools/props/split_pack
assets/props-import/FrontierProps.rbxm` writes `assets/props/<Name>.rbxm` per prop: its parts renamed `Frame` / `Glow`,
the Frame its PrimaryPart, the pivot at the bottom centre. Positions are `Config/FrontierValley`'s lists; `LANDMARKS`
holds the pieces placed outside the scenery clearances (the ribcage over the trail, the arch round the Dungeon portal,
the camp, the floating rocks hung at their own `y`).

## Dungeon props (DungeonPillar ... CrackedWall)

The Dungeon's crystal-grown temple ruins and its puzzle pieces (spec `2026-11-11-dungeon-puzzles-design.md`, the
owner's look C; concept `assets/blender/DungeonProps/concept_look.png`), built by `tools/blender/build_dungeon_props.py`
on `voxel_kit` / `portal_kit` (smooth chunky stone in cool indigo, gold trim, Glow for rune lines and crystals):
`DungeonPillar`, `DungeonPillarBroken`, `DungeonArch` (a broken gateway), `DungeonWall`, `DungeonSlab`, `DungeonSteps`,
`DungeonBrazier`, `DungeonGate` (round every door; its 14-stud opening fits the door), `DungeonCrystals`, and the puzzle
pieces `BeamGem`, `CrystalMirror`, `DoorPrism`, `StonePlate`, `CrystalPylon`, `ElementCrystal`, `CrackedWall`. The ruins
are named `Dungeon<Piece>` because the Wild valley already has `RuinPillar`, `RuinArch`... (and the script's palettes go
to `assets/blender/<Name>/`).

1. `blender -b --factory-startup --python tools/blender/build_dungeon_props.py` writes
   `assets/blender/DungeonProps/DungeonProps.{blend,fbx}` (`EXPORT=0` to try without saving; preview renders:
   `MODULE=build_dungeon_props PROPS=<Name> blender -b --factory-startup --python tools/blender/render_valley_props.py -- <out>`,
   one prop per run: several in one run crashed Blender 5.2's background render).
2. The owner imports the FBX in Studio once (default settings) and saves the imported model as
   `assets/props-import/DungeonProps.rbxm`.
3. `lune run tools/props/split_pack assets/props-import/DungeonProps.rbxm` writes `assets/props/<Name>.rbxm`.

The Dungeon builds with them at 1 stud per Blender unit (`DungeonBuilder`'s `prop`): every puzzle piece keeps its part
(prompt, checks, the sword's target) and wears the prop as a `Look` model under it, welded where the part turns (the
mirrors); its Glow parts go Neon in the piece's colour, and `DungeonBuilder.tint` / `hide` change them (a lit prism, a
held plate, a broken pylon, the opened wall). Missing props leave the code-built stand-ins.

## The Hydra's castle (DungeonCastle)

The castle at the end of the Crystal Abyss (owner 2026-11-12: "use Blender to draw a proper castle", then "a
broken/abandoned castle instead of a proper castle"; concept `assets/blender/DungeonWorld/concept_castle.png`), built
by `tools/blender/build_castle.py` in the Dungeon props' style (it reuses `build_dungeon_props.py`'s palette and pack
export): a long-abandoned ruin round a 30-wide gate gap (the Frontier's Dungeon portal model at 1.3x stands in it, the
Hydra's door sealing it): front, side and back walls of uneven height, breached in several places with rubble at their
feet and most crenels gone, moss on their faces; two gatehouse towers (one a broken stump, one with a leaning spire),
a battlement over the gate with the hydra's sigil, four corner towers (three broken off, one still spired), a keep
with its roof fallen in and one window still lit (Glow), crystals growing through. About 10800 triangles in one prop
of its own pack: run it in a background Blender, import `assets/blender/DungeonCastle/DungeonCastle.fbx` (default
settings), save the model as `assets/props-import/DungeonCastle.rbxm` and run
`lune run tools/props/split_pack assets/props-import/DungeonCastle.rbxm`. split_pack pivots it at the bottom centre
of its bounds, not at the gate: the script prints where that pivot sits from the gate (`pivot = {...}`); copy it into
`ABYSS.CASTLE.model.pivot` after a rebuild. `DungeonBuilder` stands its gate on the castle island's gate, gives its
stone the region's rock colour and Slate under the texture (what shows while a fresh texture upload isn't served
yet, instead of black), and makes its walls and towers solid with invisible blocks (`ABYSS.CASTLE.model`; a big
mesh's collision can't be set by a script); Terrain walls stand in until it's imported.

## Dungeon world props (DungeonIslandGate ... DungeonSigil) and the Dungeon portal

The Crystal Abyss's pieces (spec `2026-11-12-dungeon-world-design.md`, the owner's concept A; concepts in
`assets/blender/DungeonWorld/concept_*.png`), built by `tools/blender/build_dungeon_world.py` in the Dungeon props'
style (it reuses `build_dungeon_props.py`'s palette, shards and pack export): `DungeonIslandGate` (the arch round each
island's barrier; its opening 12 wide and 14 tall), `DungeonHydraDoor` (the Hydra's round door, radius 13, 2.4 thick: a
five-headed hydra in relief whose eyes are the lock's sockets, placed by the game on an arc of radius 7.15 round a
point 2 below its middle), `DungeonBridge` (an 8 x 12 segment, its walking top 1.4 over its bottom; the game tiles it),
`DungeonChain` (60 long, hung from the ceiling) and `DungeonSigil` (the hydra sigil in each fight ring's floor). Caps
2000 triangles, the door 4000. The game places each on a part of its own (the floors, the bridge slabs, the barriers stay
code parts), so missing props leave code stand-ins.

1. `blender -b --factory-startup --python tools/blender/build_dungeon_world.py` writes
   `assets/blender/DungeonWorld/DungeonWorld.{blend,fbx}` (`PROPS=`, `EXPORT=0` as above; previews:
   `MODULE=build_dungeon_world PROPS=<Name> blender -b --factory-startup --python tools/blender/render_valley_props.py -- <out>`).
2. Import the FBX in Studio once (default settings), save the imported model as `assets/props-import/DungeonWorld.rbxm`.
3. `lune run tools/props/split_pack assets/props-import/DungeonWorld.rbxm` writes `assets/props/<Name>.rbxm`.

The Frontier's way into the Dungeon, `PortalDungeon` (a cave-mouth arch with five hydra heads, crystals, steps down into
the swirl), is built by `tools/blender/build_portal_dungeon.py` on `portal_kit.py` like the town portals below: parts
`Frame`, `Crystals` (glowing violet), `Opening`, `Fx_Base`, `Eye1`..`Eye5` (each dragon head's eyes, left to right:
glowing in the Hydra's elements here, dark on the Hydra's castle gate until its lock is solved); five scowling dragon
heads with horns and open jaws (owner 2026-11-12: "it looks like a duck"), 3904 triangles (the portal cap 4000); 26
studs tall (`Town.SLOTS.PortalDungeon`), look
`Town.PORTAL_LOOKS.Dungeon`; saved as `assets/props/PortalDungeon.rbxm`. Until it's saved the gate shows `PortalArena`
in the Arena look (`FrontierValley.DUNGEON_GATE.fallback`).

## Turts' rug (TurtsRug)

Turts' rug and things (DESIGN 7.9): `tools/blender/build_turts_rug.py` on `voxel_kit.py` and `portal_kit.py`, run in a
background Blender (`blender -b --factory-startup --python tools/blender/build_turts_rug.py`), writes
`assets/blender/TurtsRug/TurtsRug.{blend,fbx}` (about 1,140 triangles). Three objects keep their names: `Frame` (the rug,
cushion, crates, lantern post, packs, coins; palette texture), `Glow` (the lantern's glass: TurtsController makes it neon
with a light) and `Sign` (the board: TurtsController writes TURTS on it). The origin is where Turts sits, his customers
toward -Y. Import the FBX in Studio (default settings), save the model as `assets/props/TurtsRug.rbxm` and delete the
Workspace copy; TurtsController clones it under him (a code-built stand-in until then).

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
