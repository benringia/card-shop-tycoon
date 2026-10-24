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

- Rigged pack pets (Cute Pets, Ultra Detailed) are animated in code, on each client, by moving their bones (`Util/PetRig` works
  out the angles, Lune-tested; `Util/PetAnimator` applies them; numbers in `Party.PET_ANIM`): a trot on four legs
  (diagonal legs together) or steps on two, the spine breathing and nodding, the tail wagging in a wave, the
  Puppy's ears flopping, and standing still a random fidget every few seconds (look around, head tilt, sniff,
  stretch, happy wag, hop, spin round, shake like a wet dog, sit, scratch with a hind leg, yawn). Pets without
  tail bones (Kitsune, Baby Dragon) sway their hips so their tails swish while the spine turns back to keep the
  head still. The whole body still hops and sways a little, and moves for the hop, spin and shake.
- Rigs with generic bone names (the Ultra pack: Root.M.004, Root.L.009, Leg.R, leg.l, ik.l) get their roles
  from `Util/RigGuess` (Lune-tested). .L/.R chains (any case): high ones pointing up are ears; sideways ones
  starting above 0.4 of the height (not named leg) are arms, named only on two-legged rigs (every arm chain on a
  side: some rigs carry a second set and only one moves the mesh); with IK targets (the
  feet), each foot's leg is the chain ending nearest it, else legs are chains ending low; front and hind pairs
  by how far forward they start. The middle chain runs pelvis, spine, neck and head (a bone named "head", else
  the one furthest to the front-top), and its branch to the back is the tail. `Party.PET_BONE_ALIASES` still
  overrides a single bone. A rig without legs, wings or a body wave keeps the whole-body motion.
- What those roles do (`Util/PetRig`, `Util/PetAnimator`): T-posed arms are lowered to hang `ARM_HANG` degrees
  off straight down (measured per rig from shoulder to hand) and swing `ARM_SWING` against the leg on their side;
  IK feet are carried round with their leg's hip and lift `FOOT_LIFT` as the leg swings forward, so feet walk
  with the legs instead of staying planted. `Party.ARM_POSE` holds a model's arms another way (Flametor: up in
  front like a T-rex: less drop, reaching forward, elbows bent).
- Body waves (`Party.UNDULATE`): "swim" models (IceShark, Merilux) float and wave from head to tail
  (`SWIM_BEND`, `SWIM_LAG`, `SWIM_SECONDS`), legs paddling slowly; "slither" (GiantSnake) stays on the ground and
  waves mostly while moving (`SLITHER_STILL` standing).
- Flying: every Cute Pets creature walks, winged ones too (the pack's wings have no bones, so they can't flap).
  Ultra models listed in `Party.WINGS` (DarkBat, FairyMoth, Venowasp, NeonSwallow, StoneBird, HeronDemon) fly and beat their wings (`WING_FLAP` degrees up and down, each bone along the wing trailing by
  `WING_LAG`): the entry names the first bone of each left wing, found by hand, and the right wing is the same
  name with .R. A pack listed in `Party.FLYING_PACKS` flies too. Flying creatures: legs tucked, the body rising and dipping with each wingbeat
  (`FLAP_SECONDS`, `FLAP_LIFT`), only look, tilt, spin and wag fidgets. `Party.FLYING` only applies to cards drawn
  with their own model or the placeholder.
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

A `tint = { r, g, b }` on an entry colours the model's textures (SurfaceAppearance.Color) and multiplies the colour of
its plain parts, so two cards can
share a model without a colour variant. A `hue = 0..1` instead turns every coloured part to that hue, keeping
its lightness (plain-coloured models only: Magmaw's green Salamander becomes fire orange). `Party.WING_SPEED`
slows the wingbeat of big winged models (heron, swallow).

Models that ship their own saved animations (KeyframeSequences named Idle, Walk and Run in an `Animations`
folder) are played by `Util/KeyframePlayer` on each client: idle standing, walk, and run when fast (following a
player runs); `KEYFRAME_ANIM.AMPLIFY` exaggerates the turns (walk 2x, run 1.6x: the pack's own walk only bends the
legs 11 degrees)
(`Party.KEYFRAME_ANIM`, timing in `Util/KeyframeTiming`, Lune-tested). Standing, they also roar now and then (rear
back, lunge forward with a shudder, a shockwave ring and a spray of sparks in the card's element colour), stomp
(rise and slam down, a dust ring) or look round (`PET_ANIM.TITAN_FIDGETS`, `PetRig.body`). No upload is needed.
An entry's `size` multiplies its height (the Legendaries are 2.2x, about 9 studs) and spreads
the follow offset by the same amount. Keyframe beasts also get `CreatureVisuals.addBeastFx`: `Util/BeastAura` burns
element fire on bones spread over the body (`Util/BeastFxRules`), arcs lightning between them, adds ground
flames, a flickering light and footstep dust (`Config/BeastFx`).

Current packs: **UltraPets** (bought, "Ultra Detailed" pets: 30 skinned models with bones and an
AnimationController, no animations; every non-Legendary card uses them), **CrystalTitans** (bought, Accretion "Stud Pet Pack 03 | Crystal Titans": RubyCerberus,
SapphireCrab, RainbowHydra, each with Idle, Walk and Run; the Legendaries use them), **CutePets** (bought, "Cute Pets: 20 Pet Models, Rigged + Color Variants" by BabBabyTV; the rigged
versions: skinned meshes with bones, an AnimationController, no animations yet; no card uses them now, kept for
customers, NPCs or decoration).

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
