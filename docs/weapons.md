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
uploaded; their ids are `Config/WeaponLooks` `FORGE_COLOR_MAPS` (by model).

**Spears** (weapons round 2): `weapon_kit.build_spear(name, length)` instead of `build`: the same reduction, scaled to
the spear's length (Forge Spear 8.5, Magma Halberd 8.5, Tidal Trident 8.7, Titan's Lance 9.2), the head found from the
width (`find_head`: the first slice above 55% of the length wider than 1.35x the shaft's median, its collar counted),
the origin on the grip 31% up from the butt (held upright at the side, the butt by the foot), split into **Head** and
**Shaft**. `finish_sword` makes the Shaft the PrimaryPart. The Forge Spear's collar gems are tinted like the Forge
Sword's (`weapon_kit.FORGE_GEMS`; `forge_variants ForgeSpear`). In the game a spear's grip is `Config/Swords GRIPS.spear`
and its effects run along `SwordFx.TRAIL_BLADE_SPEAR` (the head, 2.6-5.9 studs up from the grip).

## 4. Into the game

1. The owner imports `<Name>.fbx` in Studio (3D Importer, Rig Type None); the model's pivot lands on the grip's centre.
   Right-click the model, Save to File, `assets/weapons/<Name>.rbxm` (the Forge Sword as
   `assets/weapons-source/ForgeSword.rbxm`: not synced, only its five element copies go to players).
2. `lune run tools/weapons/finish_sword assets/weapons/<Name>.rbxm`: straightens the pivots and makes Grip the
   PrimaryPart (textured parts keep their texture).
3. The Forge Sword: `lune run tools/weapons/forge_variants` writes `ForgeSword_<Element>.rbxm`, each with its
   element's colour map (the names `Config/Weapons` uses).
4. Rojo syncs `assets/weapons` to `ReplicatedStorage.WeaponModels`; `SwordController` and the reveals draw them,
   `Util/WeaponLook` adds the glow (section 6). Until a model exists, a tinted stand-in.

## 5. Portraits (the card's picture)

Each weapon with a model has a portrait: the model alone in a 360 x 500 ViewportFrame on a full-screen magenta frame
(Play, Client datamodel; Ambient 190,190,200, LightDirection (-0.5,-0.7,-1), FOV 20), tilted 30 degrees blade up-right
and turned 12, captured with the Studio MCP's `screen_capture`, then cut out:

```
python tools/ui-art/cut_product_picture.py <capture> assets/ui/weapon-portraits/<Model>.png 630 0 1000 516
```

A model with colours near magenta (the Shade Forge Sword's purple gems) is captured on green and cut with
`--key 0,255,0`. The PNGs (256 px tall) are uploaded (serve the folder on 127.0.0.1, `upload_image`) and their ids go
in `Config/WeaponLooks` (`portrait`; the Forge Sword's per element in `FORGE_PORTRAITS`). `Util/WeaponFace` draws the
portrait over the weapon's glow gradient; a weapon with no model yet keeps the big sword emoji (tested in
`WeaponsConfig`).

## 6. Glow maps (the inner glow)

The weapon glow (owner 2026-11-06) lights each model's own painting: its runes, gems or crystal. A glow map is a
grayscale emissive mask (white glows) made from the model's colour map by `tools/textures/make_glow_maps.py` (one rule
per model; the Forge Sword's is wherever an element's map differs from the base: its gems), saved in
`assets/ui/weapon-glow-maps/<Model>.png` and uploaded; the ids go in `Config/WeaponLooks` `GLOW_MAPS`.

A game script can't set a SurfaceAppearance's maps (PluginSecurity), so `lune run tools/weapons/add_glow_maps` bakes
them into the model files: every MeshPart gets a SurfaceAppearance named "Glow" with its colour map and the glow map,
strength 0. `Util/WeaponLook` sets the strength (`INNER.strength` x the level's inner glow) and the tint. Run it again
after re-importing a model or running `forge_variants`.

The aura (flames, core, smoke, sparks, +10 ribbons) and the cheap glow (sparkles, light) are particles and a light made
in code (`Util/WeaponLook`, numbers in `WeaponLooks.AURA` and `SPARKLES`); `SwordController` gives the full aura to
your own sword and the nearest few (`BUDGET`).

## Pack effects

Some effects come from free Creator Store VFX packs (owner 2026-11-08, picked from renders in town):

| Pack | Store id | Used for | Our config |
|---|---|---|---|
| Euphoric Games VFX Pack | 112672322113504 | the Ember and Tide weapon auras (its Fire-Aura-01 and Water-Aura-01) | `WeaponLooks.ELEMENT_AURA` |
| Yona VFX Pack | 18170940328 | the Bloom weapon aura (its Player-VFX Aura, recoloured green) | `WeaponLooks.ELEMENT_AURA` |
| Euphoric Games VFX Pack and Yona VFX Pack | both | a landed cut's slash streaks (Slash-Impact-01 and Slash-01) | `SwordFx.IMPACT` |

Nothing from a pack is inserted into the game: its emitters' settings were copied into our configs and our code builds
them (`Util/PackEmitter`), pointing at the pack's texture ids (`AttackFx.TEXTURES`: `fireAura`, `waterAura`,
`auraSmoke`, `auraEmber`, `auraLight`, `slashStreak`, `slashArc`, `sparkStreak`). The six identical limb emitters a
pack puts on a body are one emitter on the weapon at six times the rate. The packs draw an aura a stud behind the body
it wraps (`zOffset = -1`); a sword on the back rides a fifth of a stud off the torso, so that sank the fire into it
(owner: "the glow is blocked by the body"). Our layers start at 0, and each frame `WeaponLook.drawPastBody` moves a
part's layers `WeaponLooks.BEHIND_BODY.shift` nearer while the wearer's body (visible parts only: a hat brim or waist
accessory would count from behind) stands between the camera and that part; 1.5 studs buried the face. Some impact emitters fly a set way from their
holder (`direction`, `facing`): `HitFx.impact` stands the holder level and turns it to face your camera, as in the test
the owner picked from (tilted up toward the camera, the flat arc showed edge-on and vanished). The impact takes the
weapon's colour (`color = "tint"`, `whiten` toward white) and its element's particles (`SwordFx.ELEMENT_HIT`, our own
textures), and grows with the foe's model (`HitFx.scaleFor`, `SwordFx.IMPACT.bySize`). Those are public images other people uploaded: if one is ever deleted it shows blank, and we
draw a replacement with our texture tools (`tools/textures/`) and swap the id.

Vetting a pack before using it, without touching the place: from the Studio MCP, `game:GetObjects("rbxassetid://<id>")`
returns unparented copies; read every script (none may `require`, `loadstring`, `getfenv`, or call HTTP, teleport or
purchase APIs), PreloadAsync every particle, beam and trail texture, and check the creator (no reuploads of paid packs,
deleted accounts or other games' characters). Render candidates in a Play test (thrown away on Stop). Rejected
2026-11-08: the "Aura Pack Premium Sanzzzzz" reuploads, the "Content Deleted" account's packs, "not mine" and anime
character packs, a pack with 64 scripts.
