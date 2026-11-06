# Weapons: models

Weapons round 1 (spec `docs/superpowers/specs/2026-11-06-weapons-round1-design.md`). Rules and numbers live in
`Config/Weapons` and `Util/WeaponRules`; looks in `Config/WeaponLooks`, `Util/WeaponLookRules` and the client's
`Util/WeaponLook`. This note is how a weapon's model is made.

## 1. Concepts (Figma)

Two options per weapon, made with Figma's image generator in the file "Card Shop Tycoon - Card Art"
(`gpt-image-2.5-flare`, 1024 x 1536), shown to the owner in the visual companion; the owner picks one. The prompt
asks for exactly what Meshy's image-to-3D needs:

```
Game asset concept art of a single fantasy sword for a cute stylized adventure game: <description>. Stylized
hand-painted 3D look like a polished mobile game weapon, chunky readable shapes, smooth clean surfaces, bold clean
colours, soft highlights. The whole sword shown upright, blade pointing straight up, flat face toward the viewer,
perfectly centred, front orthographic view, nothing cropped. Plain flat light grey background, no shadow, no hands,
no other objects, no text, no letters, no watermark.
```

The picks are kept locally as `assets/blender/<Name>/concept_<A|B>.png` (out of git).

Round 1's picks (2026-11-06): Forge Sword A (polished steel broadsword, squared iron guard, ring pommel, round white
gems), Verdant Blade A (glowing green crystal grown from living wood, carved-leaf guard, vine grip, seed gem),
Sunforged Blade A (golden flame-shaped blade with molten runes, sun-disc guard), Prism Blade B (pearl-white blade with a
rainbow edge, prism gem, silver scale wings, hydra pommel).

## 2. Meshy (image to 3D)

`generate_3d(image=<concept path>, provider="meshy", name="<Name>_Src")` through the Blender MCP: about 30 credits each
(round 1: 1120 -> 1000). Meshy stands it up at real size, origin at the bottom, blade up +Z, its flat faces along Y.
Export it from the MCP's Blender as `assets/blender/<Name>/<Name>_raw.glb` (out of git); that's all the open Blender is
used for.

## 3. Cleanup (background Blender)

`tools/blender/weapon_kit.py` with one `build_weapon_<id>.py` per weapon, run in a background Blender (never the
owner's open one):

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_weapon_<id>.py
```

It reduces the model to about 4,000 triangles with one 1024-pixel colour map (`rig_kit.optimize`), scales it to its
length in studs (Forge Sword 5.0, Verdant 5.2, Prism 5.4, Sunforged 5.6; the Steel Sword is about 5), finds the guard
(the widest part of the lower half, its width smoothed so a guard of rays or leaves counts as one) and the grip (the
longest narrow run under it), puts the grip's centre on the origin, and splits the mesh into **Blade**, **Guard** and
**Grip** (the pommel goes with the grip). It writes `<Name>.fbx` (textures embedded), `<Name>_color.png`,
`<Name>.blend` (no `_Src`, orphans purged, no key fields) and two previews.

The Forge Sword's five elements share one model: `weapon_kit.recolor` tints the bright pale texels on its gems' faces
(the guard's centre and the pommel, never the blade) into each element's colour, `ForgeSword_<Element>_color.png`,
uploaded; their ids are `Config/WeaponLooks` `FORGE_COLOR_MAPS`.

## 4. Into the game

1. The owner imports `<Name>.fbx` in Studio (3D Importer, Rig Type None); the model's pivot lands on the grip's centre.
   Right-click the model, Save to File, `assets/weapons/<Name>.rbxm` (the Forge Sword as `ForgeSword.rbxm`).
2. `lune run tools/weapons/finish_sword assets/weapons/<Name>.rbxm`: straightens the pivots and makes Grip the
   PrimaryPart (textured parts keep their texture).
3. The Forge Sword: `lune run tools/weapons/forge_variants` writes `ForgeSword_<Element>.rbxm`, each with its
   element's colour map (the names `Config/Weapons` uses).
4. Rojo syncs `assets/weapons` to `ReplicatedStorage.WeaponModels`; `SwordController` and the reveals draw them,
   `Util/WeaponLook` adds the glow shell on the Blade and the ladder's effects. Until a model exists, a tinted stand-in.
