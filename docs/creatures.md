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

- Static models get the motion kit (`Util/CreatureMotion`): breathing when standing, a hop-and-waddle walk,
  leaning into movement, and hovering for flyers. Numbers in `Party.MOTION`.
- Rigged models play their own animations instead: add a Folder `Animations` with two Animation objects named
  `Idle` and `Walk`, and keep the model's Humanoid or AnimationController. Animations must be owned by you or
  the group that owns the game, or Roblox won't play them.
- Flyers: add the card name to `Party.FLYING`.

## One model for several cards

`Party.MODEL_FOR_CARD = { Ashbeak = "Cindercub" }` makes Ashbeak use the Cindercub model. Shared models are
tinted toward the card's element (untextured parts only).

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
