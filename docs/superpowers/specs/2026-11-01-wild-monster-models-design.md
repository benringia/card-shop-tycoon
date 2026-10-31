# Wild monster models (design)

Status: written 2026-11-01 after the user picked every model; the user said proceed. A builder check followed; its two
questions are settled below as Claude's calls (marked).

## Intent

The six Wild monsters in the main game's Wild valley are still part-built placeholder shapes. They get real models, made
the way the card creatures are now made (Meshy through the Blender MCP, our own rig), so the valley the user just
redesigned has creatures worth fighting. The user chose every design and approved every Meshy model one by one.

The user's two firm rules for the look:

- **Style B, "wild-touched", and not like the cards.** Card creatures are cute big-eyed pets. Wild monsters are feral:
  glowing eyes without pupils, glowing growths of their element (crystals, cracks, barnacles, lava, mushrooms), grumpy
  or snarling faces, no chibi heads. A player should tell a wild monster from a tamed card creature at a glance.
- **Made with Meshy.** The user approved Meshy for these; each model was generated from the concept picture they picked
  (image to 3D), not from a text prompt.

## The six models (all approved)

Concept pictures, cut-outs and Meshy renders are in the brainstorm companion folder
(`.superpowers/brainstorm/790-1793408175/content/`, git-ignored); the cut-out each model was made from is committed with
its sources (below). The raw Meshy meshes sit in one file, `.superpowers/monsters-raw/monsters_raw.blend` (git-ignored,
175 MB, objects `<Species>_Src` side by side along -x); re-polling a finished Meshy job re-imports it for free:

| Species (zone) | Design | Meshy job | Raw mesh |
|---|---|---|---|
| Mossling (meadow) | Boulder beast: a squat grey stone brute on four stubby legs, heavy brow, tusks, moss beard and moss patches, a row of mushrooms along its back, short stubby tail | `meshy:i2m:01a192e8-5762-73f5-a1b3-5e7ac6e35e16` | 459k tris, 4 legs |
| Puddle Crab (meadow) | Barnacle brute: a domed dark blue shell crowded with barnacles, grumpy face under the rim, two grey stone hammer claws, four legs a side | `meshy:i2m:01a192ef-e13e-752d-abe0-699d71b631ef` | 762k tris; **one extra leg** at the back middle |
| Cave Bat (caves) | Gargoyle bat: stone skin with violet cracks, curved horns, pointed ears, fanged face, solid stone wings spread wide, two clawed feet | `meshy:i2m:01a192f6-d16a-7497-82cc-f1b99b361adf` | 414k tris |
| Spark Beetle (caves) | Stag spark: a rust-copper stag beetle, big jagged pincers with yellow cracks, yellow crystals along its domed back, six thick legs | `meshy:i2m:01a192fc-d8da-7270-b789-c57e645f19ae` | 422k tris, 6 legs |
| Magma Golem (ember ridge) | Cairn cyclops: a hulking stack of grey and red-brown boulders, one orange cyclops eye, lava drips over head, chest and shoulders (the back is plain), arms held slightly out | `meshy:i2m:01a19304-b98e-71ae-bd07-26929e9d175f` | 576k tris, two legs |
| Ash Wolf (ember ridge) | Cinder mane: a charcoal wolf with a big ash-white mane, snarling fanged face, ember cracks on legs and flanks, bushy orange-tipped tail; stands in a low snarl | `meshy:i2m:01a19311-8d10-7713-beab-044f8f540535` | 422k tris, 4 legs; **leaner than the concept** |

Checked against famous creatures and our own cards: the golem is not a muscular rock gorilla (Cinder Titan), the wolf
is not purple (Duskstalker) and has no horns or collar, the beetle has no blue crystals (Stormking) or yellow-black
stripes (Fizzlebug), the crab is blue not red, the bat is not round or purple (Gloomlet).

## Decided by the user

- Style B (wild-touched), not card-like; made with Meshy; every model chosen and approved by the user.
- **Sizes by species** (option B of a to-scale lineup next to a 5-stud player), height in studs:
  Mossling 2.5, Puddle Crab 2, Cave Bat 3, Spark Beetle 2.5, Ash Wolf 4, Magma Golem 6.5. Elites stay `ELITE_SIZE`
  (1.35x) of their species' height.
- The Ash Wolf gets bulked up in Blender (about 15% on body and legs) rather than regenerated.
- The Puddle Crab's extra back leg is removed in Blender.
- The glow that Meshy painted pale (eyes, cracks, crystals, barnacle insides, mushroom caps, lava, tail tip) is made to
  glow in Roblox.

## Goals

1. Each of the six species draws its approved model in the Wild valley (and anywhere else `Wild.SPECIES` monsters are
   drawn), at its own height, elites 1.35x bigger with their gold tag and light as today.
2. Every model is rigged with bones named for `PetRig` and moves like a creature (walk, breathe, fidgets, tail), with
   its own personality through `Party.CREATURE_STYLE` keyed by species name. Today only bosses' bones move
   (`MonsterController` passes a style key only for bosses); monsters with a rigged model must animate too.
   - Mossling: a heavy, slow four-legged plod, little bounce.
   - Puddle Crab: four legs a side and both claws; it walks forward (see non-goals).
   - Cave Bat: flies (`Wild.FLYING` already lists it), wings beating (`Wing_<Side>_<n>`), feet tucked.
   - Spark Beetle: six legs, an insect gait (alternating tripods), pincers.
   - Ash Wolf: a fast four-legged prowl, tail swishing; signature idle: a roar. *Claude's call:* the existing plain
     `roar` barely shows on a rigged model (`PetRig.pose` and `PetRig.cue` leave it out, so only the body tips back), and
     the other roar kinds carry card effects, so one new plain roar kind for rigged monsters is added: head, neck and
     jaw rear back and lunge like the other roars, with the plain shockwave ring and sparks in the monster's element
     colour (`CreatureVisuals` roar effect), nothing card-specific. Plain `roar` (the Prism Hydra's signature) is left
     as it is.
   - Magma Golem: a lumbering two-legged walk with swinging arms (`stride`, `legSwing`, `sway`); signature idle: a
     stomp (an existing kind).
3. The glow: the parts listed above glow in their element's colour (green, cyan, violet, yellow, orange), day and
   night. The golem's lava pulses slowly. *Claude's call:* the Mossling's and the golem's approved faces keep their dark
   pupils (the golem's concept had a slit pupil; the user approved both models as rendered); their eyes glow around the
   pupil. The other four already have glowing eyes without pupils.
4. Two small effects: sparks crackling between the Spark Beetle's pincer tips, and a wisp of smoke from the Ash Wolf's
   tail tip. Like the portal swirls, they run only near the camera and with the extras on (`Util/Extras`).
5. The valley still runs at 60 fps where it was measured (DESIGN 10.5), including the crowded meadow with `/crowd 11`
   (24 monsters a biome).

## Non-goals

- The Frontier's six monsters and the bosses 1-6 (still placeholders; later rounds in the same style).
- New fight attack animations (the "fight juice" backlog item covers hit reactions and lunges).
- The crab scuttling sideways, and new fidget or signature kinds beyond the one plain roar above: otherwise only
  existing kinds are used.
- Sounds.

## Anti-goals (a failure even if it works)

- A monster that reads as a card creature (cute, big-eyed) or as a famous creature.
- Frame drops in the valley: monsters are many (up to 24 a biome), unlike one player's party.
- Spending more Meshy credits without asking (1420 left on 2026-11-01). Fix problems in Blender first.
- Losing the approved look: the cut-down mesh must keep the silhouette, face and colours of the approved model.

## Constraints (from the project)

- Pipeline as in docs/creatures.md "Meshy-generated originals": cut the mesh down with `tools/blender/rig_kit.py`
  (`optimize` or `remesh_bake`), one `tools/blender/rig_<species>.py` with bone positions per monster, sources in
  `assets/blender/<Species>/` (.blend, .fbx, the concept cut-out `<Species>_concept.png`, already there). Delete the raw
  `*_Src` object and purge orphans before saving a .blend; before committing one, check the scene's
  `blendermcp_*key*` / `*secret*` fields are empty (print lengths only).
- The user imports each FBX in Studio (Rig Type Custom, Keep Zero Influence Bones); Claude resets the MeshPart's
  `PivotOffset` rotation and names the model after the species; the user saves it as
  `assets/monsters/<Species>.rbxm` (species names as in `Config/Wild`, e.g. `Cave Bat.rbxm`). The model script test
  (CreatureAssets) and `Wild.MAX_MODEL_PARTS` apply.
- Numbers live in Config (heights in `Config/Wild` `SPECIES`, styles in `Config/Party`); pure rules Lune-tested.
- Studio MCP: ask before changing the place itself.

## Left to the builder

- Triangle budget per model. Guidance: about 5,000 triangles each (the golem up to about 8,000), since many are on
  screen at once; keep the silhouette and face.
- How the glow is carried: preferably an emissive mask on the model's SurfaceAppearance (Studio supports
  `EmissiveMaskContent`, `EmissiveStrength`, `EmissiveTint`), painted from the model's own glow colours; if the import
  path can't carry it, separate glowing pieces skinned to the same rig. Whichever, the glow must follow the animation.
- The exact bone layout per monster, how the crab's claws and the beetle's pincers are named (arms, jaws, or their own
  limbs), and whether six and eight legs need any change in `PetRig` (pairs 0 and 2 already share a phase, 1 and 3 the
  opposite); Lune-test the gait.
- How far-away monsters are kept cheap (for example, only the nearest few animate their bones, like `CreatureCull`
  does for pets), if the frame measurement needs it.
- Whether the bigger monsters need their own contact or prompt distances (the golem is 6.5 studs tall and about 7
  wide; `CONTACT_DISTANCE` is 4 from the marker).
- Fidget lists, tail and bounce values per species.
- The order of work, and keeping DESIGN.md, docs/creatures.md, CLAUDE.md and the Obsidian notes in step.
