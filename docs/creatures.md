# Creature models

Summoned creatures (party, DESIGN 5.8) are drawn on each client by `CreatureController`. A card with no model
gets the placeholder: a round blob in its element colour, with wings if the card is a flyer.

## Adding a model

1. In Studio, insert the model (Toolbox / Creator Store) into the workspace.
2. Check it faces **-Z** (Roblox's front). If it doesn't, give the Model a number attribute `YawOffset`
   (degrees, e.g. `180`) instead of rotating parts.
3. Name the Model exactly after the card (`Cindercub`), right-click → **Save to File**, and save it as
   `assets/creatures/Cindercub.rbxm`. Delete it from the workspace.
4. Rojo syncs `assets/creatures` to `ReplicatedStorage.CreatureModels`. Stop → Play to see it.

Don't add models in Studio straight into `CreatureModels`: Rojo owns that folder and will remove them.

## Rules the game applies

- **No scripts, ever.** Delete every script from a model before saving it. `lune run tests/run` fails if any
  `.rbxm` in `assets/creatures` still holds one: run it after adding a model. This is the real gate, because a
  Script set to RunContext Server or Client runs from ReplicatedStorage as soon as the place starts. As a second
  layer the server destroys scripts in `CreatureModels` at start, and each client strips scripts, prompts, click
  detectors, sounds and tools from its own copy.
- **Size by rarity.** Any model is scaled so its height is `CREATURE_HEIGHT × SIZE_BY_RARITY` (Config/Party).
- **Part cap.** Models with more than `MAX_MODEL_PARTS` (200) parts use the placeholder.
- **No collisions.** All parts are made non-colliding, non-touching and non-queryable.

## Motion

- Rigged pack pets (Cute Pets) are animated in code, on each client, by moving their bones (`Util/PetRig` works
  out the angles, Lune-tested; `Util/PetAnimator` applies them; numbers in `Party.PET_ANIM`): a trot on four legs
  (diagonal legs together) or steps on two, the spine breathing and nodding, the tail wagging in a wave, the
  Puppy's ears flopping, and standing still a random fidget every few seconds (look around, head tilt, sniff,
  stretch, happy wag, hop, spin round, shake like a wet dog, sit, scratch with a hind leg, yawn). Pets without
  tail bones (Kitsune, Baby Dragon) sway their hips so their tails swish while the spine turns back to keep the
  head still. The whole body still hops and sways a little, and moves for the hop, spin and shake.
- Creatures without bones (placeholders, static models, wild monsters) get whole-body fidgets while standing:
  hop, spin, shake, look around, bounce (`PET_ANIM.BODY_FIDGETS`, `PetRig.body`). Bones are found by name
  (`Pet_<Model>_<Role>`); odd ones are renamed in `Party.PET_BONE_ALIASES`. No upload or animation ownership is
  needed. The pack has no eye, eyelid or wing bones, so pets can't blink and wings stay still. Walking, the tail
  sways slower and smaller (`TAIL_WALK`, `TAIL_WALK_AMOUNT`).
- Every creature model's meshes and textures download in the background when a player joins
  (`CreatureVisuals.preload`): the party bar starts its party's pets first, then the whole pack follows. A copy
  of every model also stays drawn in a 4-pixel, nearly invisible viewport (`PlayerGui.CreatureCache`), because
  Roblox only finishes loading a texture once something draws it; so a pet is fully coloured the first time it's
  summoned. The tail's wag is built up frame by frame (`PetRig.wagSpeed`), so starting or stopping a walk never
  makes it jump.
- Static models get the motion kit (`Util/CreatureMotion`): breathing when standing, a hop-and-waddle walk,
  leaning into movement, and hovering for flyers. Numbers in `Party.MOTION`.
- Rigged models play their own animations instead: add a Folder `Animations` with two Animation objects named
  `Idle` and `Walk`, and keep the model's Humanoid or AnimationController. Animations must be owned by you or
  the group that owns the game, or Roblox won't play them.
- Flyers: add the card name to `Party.FLYING`.

## Packs and colour variants

A pack is one file holding a folder of models: `assets/creatures/CutePets.rbxm` → `CreatureModels.CutePets.Cat`.
`Party.CREATURE_MODELS` gives each card a pack model and, optionally, a colour variant:
`Sparkrat = { pack = "CutePets", model = "Hamster", variant = "Golden" }`. A variant is a SurfaceAppearance in the
model's `Variants` folder that replaces the model's own (Cute Pets ships Golden, Rainbow and Shadow), so several
cards can share a model and still look different. The Lune test checks every entry's pack, model and variant
exist. Cards not listed use a model named after the card, else the placeholder.

To add or refresh a pack: put a Folder named after the pack (its models inside, named as in the config, scripts
deleted) in the workspace, right-click it → **Save to File** as `assets/creatures/<Pack>.rbxm`, delete it from
the workspace, then run `lune run tests/run`.

Current packs: **CutePets** (bought, "Cute Pets: 20 Pet Models, Rigged + Color Variants" by BabBabyTV; the rigged
versions: skinned meshes with bones, an AnimationController, no animations yet).

## Glow

Set per rarity in `Party.GLOW`: a point light in the element colour, sparkles (more with stars and an S grade),
and an outline for Epic and Legendary (Legendary pulses). Foils get a rainbow outline and sparkles. Roblox draws
at most 31 outlines on screen, so the rarest and nearest creatures get them first.

## Wild monsters

Monsters work the same way: save a model as `assets/monsters/<Species>.rbxm` (species names are in
`Config/Wild.luau`, e.g. `Mossling`, `Cave Bat`). It is scaled to `MONSTER_HEIGHT` (elites `ELITE_SIZE` times
bigger), the same script test and part cap apply, and the server and clients strip scripts the same way. Flying
species are listed in `Wild.FLYING`. Species without a model get a part-built placeholder in their element colour.

## Originality

Free and bought models are stand-ins. Check each model's licence and creator before shipping, and plan to
replace them with original art (DESIGN 5.5).
