# Pack models and opening effects

The booster pack, the deck box and the open display box are 3D models built by scripts in Blender, used on shelves,
on the pack opening stage and in menus (`src/shared/Util/PackModels.luau`). The opening's effects are our own Blender
renders too. This page covers rebuilding both and adding a new set's look. Design: DESIGN.md 3, 5.7 and 6; spec
`docs/superpowers/specs/2026-10-29-cards-in-world-and-pack-opening-design.md`.

## What the game expects

`ReplicatedStorage.PackModels` (synced from `assets/packs`) holds three models. Each model's pivot is its bottom
centre, with its front facing -Z.

| Model | MeshParts | Used by |
|---|---|---|
| `Pack` | `Body` (open at the top), `Strip` (the tear strip), `BodyLow` (one closed body, for shelves) | `PackModels.pack(id, "High" \| "Low")` |
| `DeckBox` | `Box`, `Lid` | `PackModels.deckBox(id)` |
| `DisplayBox` | `Tray` (lid folded back), `Packs1` .. `Packs6` (that many packs standing in it) | `PackModels.displayBox(id, packs)` |

Each model also holds `Looks/<look>/<MeshPart name>`: one SurfaceAppearance per MeshPart for each pack type. A pack's
`look` in `Config/Packs` (today `"FirstSpark"`) picks which one each clone gets. Scripts can't swap a
SurfaceAppearance's maps, so a new set means a new `Looks` folder, not new code. Packs with `model = "DeckBox"` use
the deck box.

While a model is missing, `PackModels` builds a plain stand-in from parts (the pack art as a decal), so nothing
breaks. The test `tests/CreatureAssets.spec.luau` checks that `assets/packs` holds all three with their MeshParts
and a look each.

## Rebuilding the models

Sources live in `assets/blender/Pack/` (`Pack.blend`, the FBX exports, the textures). The `.blend` holds all three
models.

1. Textures (needs Pillow and the Fredoka font, which is git-ignored; the script's header says where to get it):
   `python tools/textures/make_pack_textures.py assets/ui/packs/<Set>.jpg tools/textures/fonts/Fredoka.ttf assets/blender/Pack "<SET NAME>"`.
   This writes `Pack.png` (front | back), `Pack_1024.png` (the copy to upload), `Pack_metal.png` and `Pack_rough.png`
   (the crimped seals are metal), and the `DeckBox.png` and `DisplayBox.png` atlases. The build scripts' UVs map to
   the same regions.
2. In Blender (through the Blender MCP or the Text Editor), run `tools/blender/build_pack.py`, then
   `build_deckbox.py`, then `build_displaybox.py`. They share `pack_kit.py`, which opens `Pack.blend`, builds the
   meshes, exports `Pack.fbx`, `DeckBox.fbx` and `DisplayBox.fbx`, and saves. Set `CARD_SHOP_REPO` if the repo isn't
   in the default place.
3. Budgets: the pack is about 4,900 triangles (Body 4048 + Strip 848), BodyLow 392; the display box tray is 72
   triangles plus 192 per pack shown.
4. Before committing the `.blend`: delete any raw `*_Src` objects, purge orphans, and check that the scene's
   `blendermcp_*key*` and `*secret*` fields are empty (print their lengths only).

## Importing into Studio

1. Import each FBX (Rig Type None). Name the model `Pack`, `DeckBox` or `DisplayBox` and its MeshParts as in the
   table above. Set each model's pivot to its bottom centre, front facing -Z, and reset any rotation the importer
   put in a MeshPart's `PivotOffset`.
2. Upload the textures (`Pack_1024.png`, `Pack_metal.png`, `Pack_rough.png`, `DeckBox.png`, `DisplayBox.png`).
   Uploaded images are capped at 1024 px.
3. In each model, add `Looks/FirstSpark` with one SurfaceAppearance per MeshPart, named after its MeshPart, with the
   uploaded maps (the pack's seals use the metal and roughness maps).
4. Save each model as `assets/packs/<Name>.rbxm`. No scripts may be inside (the creature script gate applies).
5. Map `assets/packs` to `ReplicatedStorage.PackModels` in `default.project.json`, `frontier.project.json` and
   `dungeon.project.json`, then restart `rojo serve`.
6. Check in Studio: shelves (display boxes fill and empty), the opening (the pack's front faces the camera and the
   strip tears off to the screen's right; text that reads mirrored needs a 180 degree turn in `PackModels`), and
   the Prices and Order Stock rows.

## A new set's look

Run the texture script with the new set's art and name, upload the maps, and add `Looks/<SetLook>` to each model with
the new SurfaceAppearances. In `Config/Packs`, give the new pack `look = "<SetLook>"` (and `model = "DeckBox"` for a
deck box). The meshes stay the same.

## The opening's effects

The rip burst, the foil shards and the glints are flipbooks rendered in Blender; the mote, rays and light leak are
plain images. All are white light with alpha, so a ParticleEmitter's `Color` tints them. Particle flipbooks must be
2 x 2, 4 x 4 or 8 x 8.

1. In Blender, run `tools/blender/build_pack_fx.py`. It builds its own scenes (RipBurst, ShardHolo, ShardGold, Glint)
   and renders frames to `<temp>/pack_fx_frames/<name>/NNN.png`. `PACK_FX` picks one effect (`burst`, `shards`,
   `glint`; all by default), and `PACK_FX_FRAMES` changes the folder.
2. `python tools/textures/make_flipbooks.py <temp>/pack_fx_frames assets/ui/fx` packs the sheets (RipBurst 8 x 8 of
   128 px; the shards and Glint 4 x 4 of 256 px) and writes Mote, Rays and Leak.
3. Upload the PNGs and put the ids in `Config/PackFx` (`SHEETS` with their grid and frame count, `IMAGES`). The aura
   uses the public "Glow Circle / Radial Glow" image. `tests/PackFxConfig.spec.luau` checks the sheets' shapes.

How many particles show follows the player's graphics level (`RevealRules.scaleCount`: a quarter at level 1, all
from level 6). Lower the counts in `Config/CardReveal` (shards, glints, motes) or `PackOpening.TEAR`, never the
timings, if the opening gets heavy on phones.

## Sounds

`PackOpening.SOUNDS` holds one Creator Store id per moment (crinkle, snap, stack, flip, tease, the three hits,
shimmer, land, chime), with `VOLUMES` beside it. An empty id plays nothing. Each play is a one-shot of its own, so
quick repeats overlap; the tease fades out when the hit lands. Credits are in DESIGN.md 5.7.
