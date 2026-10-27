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
- **Size by rarity.** Any model is scaled so its height is `CREATURE_HEIGHT × SIZE_BY_RARITY` (Config/Party:
  Common 0.7, Rare 0.85, Very Rare 1, Epic 1.5, Legendary 1.4), times its model entry's `size`.
- **Grade aura.** Legendaries burn with their element (`Util/BeastAura`); grade S and A copies of the rest get a
  lighter tier of it (`BeastFx.TIERS`: fewer bones, smaller flames, a dimmer light, S keeps rare lightning; no
  ground flames or dust).
- **Part cap.** Models with more than `MAX_MODEL_PARTS` (200) parts use the placeholder.
- **No collisions.** All parts are made non-colliding, non-touching and non-queryable.

## Motion

- Rigged pack pets (Cute Pets, Ultra Detailed) are animated in code, on each client, by moving their bones (`Util/PetRig` works
  out the angles, Lune-tested; `Util/PetAnimator` applies them; numbers in `Party.PET_ANIM`): a trot on four legs
  (diagonal legs together) or steps on two, the spine breathing and nodding, the tail wagging in a wave, the
  Puppy's ears flopping, and standing still a random fidget every few seconds (look around, head tilt, sniff,
  stretch, happy wag, hop, spin round, shake like a wet dog, sit, scratch with a hind leg, yawn). Pets without
  tail bones (Kitsune, Baby Dragon) sway their hips so their tails swish while the spine turns back to keep the
  head still; two-legged ones without a tail (Sprouthop) shift their weight slowly from foot to foot instead
  (`IDLE_SWAY`). Walking on two legs, the hips turn with the forward leg and dip over the standing one, the chest
  turns back against them and the neck keeps the head facing ahead (`HIP_TWIST`, `HIP_ROLL`, `SHOULDER_COUNTER`).
  The whole body still hops and sways a little, and moves for the hop, spin and shake.
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
  front like a T-rex: less drop, reaching forward, elbows bent) and can widen the swing (`swing`: Sprouthop 32).
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

Current packs: **Originals** (our own Blender models, see below: Boltlynx, Voidmaw, Sprouthop), **UltraPets** (bought, "Ultra Detailed" pets: 30 skinned models with bones and an
AnimationController, no animations; every other non-Legendary card uses them), **CrystalTitans** (bought, Accretion "Stud Pet Pack 03 | Crystal Titans": RubyCerberus,
SapphireCrab, RainbowHydra, each with Idle, Walk and Run; both now unused: Tideborne Kirin and Stormking are originals), **CutePets** (bought, "Cute Pets: 20 Pet Models, Rigged + Color Variants" by BabBabyTV; the rigged
versions: skinned meshes with bones, an AnimationController, no animations yet; no card uses them now, kept for
customers, NPCs or decoration).

## Original models (Blender)

Original creatures are built by scripts in `tools/blender/` (run inside Blender, e.g. through the Blender MCP), which
write `assets/blender/<Card>/` (the `.blend`, an `.fbx` and its palette PNG; not synced by Rojo). Each is one
blocky mesh with a palette texture, every vertex weighted fully to one bone, on an armature whose bones already
carry `PetRig` role names (`Pelvis`, `Spine_0`, `Neck`, `Head_0`, `Arm_Left_0..2`, `0_Left_Limb_0..2`,
`Tail_0..5`, `Ear_Left_0`), so the code walk and fidgets drive them with no `RigGuess` or aliases. They face -Y in
Blender (Roblox -Z), arms in a T-pose. `voxel_kit.py` holds the shared part: the mesh builder (boxes, spikes,
`round_box` with bevelled edges, smooth `blob` ellipsoids), palette, material, armature and export; each
`build_<card>.py` only describes its creature. Most originals are blocky voxel builds (`box`, `spike`, and `cube`, a
box sized like an ellipsoid); Puffpuddle and Solarion use a smoother style (`round_box`, `blob`). Blocky is the
default: the smooth look made Eclipse Fox and Duskstalker look awkward, so they went back to blocky.

### Meshy-generated originals (the current way)

Priority (Meshy credits are capped): Very Rare, Epic and Legendary cards first, then the other cards still on bought
models if credits remain; the rest use Cute Pets models, tinted per card.

New originals are generated with Meshy through the Blender MCP and rigged with `tools/blender/rig_kit.py` (one
`rig_<card>.py` per creature). Meshy credits are capped (1000 in all), so each prompt must be right the first time.

Meshy prompt template:

```
very cute chubby cartoon <animal>, mythical <element> creature, <pose: standing still in a neutral pose on all four
legs, feet planted square, head and body facing straight forward / two-legged: T-pose>, toy-like collectible creature, round plump body, big round head, big shiny dark eyes set
close together, small centred smile, <colours>, <mythical parts: chunky, attached to the body>. Perfectly symmetrical
face. Smooth simple rounded shapes, flat clean colors, low poly, no fur detail, no realistic textures. Isolated single
character only, nothing else: no base, no ground, no grass, no rocks, no stand, no props. Legs clearly separate from
each other. One solid closed shape.
```

- Flat creatures (rays): ask for "lying flat, back facing up, belly down"; Reefray came out standing on end, belly up.
- Neutral rest pose, always: four-legged creatures "standing still in a neutral pose, all four feet planted square,
  head and body facing straight forward, head level, not turned"; two-legged / humanlike ones in a T-pose (generate_3d
  `pose_mode="t-pose"`). Never "side view", walking, prancing or turned poses: Briarhorn (turned 19 degrees), the
  Kirin (a raised leg) and Thunderhorn (body turned 16 degrees, head turned 38) all needed fixing by hand.
- Never skinny: ask for a massive, heavy, bulky body with thick legs, a broad chest and a low wide stance (chunky and
  stocky for cute ones), and match the card art's build. Briarhorn's first cow came out too slim and was remade as a bison.
- Character plus its mythical parts only; never scenery. Grass or ground under it fuses with the feet and can't be
  rigged (Mossmole's first try: a grass patch round its feet, a hollow mossy underside, 5.7M triangles).
- Keep add-ons chunky and attached (moss as a patch on the back, mushroom caps sitting on it); thin stalks and loose
  bits break up when the mesh is reduced.
- Count the legs: cluster the vertices at ground level (z < 0.05) and check there is one foot per leg; Meshy gave
  Coalbit a fifth leg, which looked like a skinning bug in game until counted.
- Check the result before spending more: one island, a clean symmetric face, under ~500k triangles, nothing that looks
  like a famous character. Fix small things in Blender (recolour, add bolts with `rig_kit.bolt`); regenerate only when
  the mesh is unusable. Re-polling a finished job re-imports it for free.

Heavy two-legged creatures can lumber: `Party.CREATURE_STYLE` `stride` (longer, slower steps), `legSwing` (smaller
leg angle) and `sway` (more hip roll and twist, the standing knee bending under the weight, `PET_ANIM.HEAVY_KNEE`).
Folded wings on the ground (`Wing_<Side>_<n>` on a creature that walks) shift a little with each breath
(`PET_ANIM.WING_REST`) and spread wide for a roar (`WING_SPREAD`).
Capes hang on their own bones (`Cape_0..2` from the chest): they billow back as the creature runs and flutter standing,
each bone trailing the one above (`PET_ANIM.CAPE_*`).
Many-tailed rigs name each tail `Tails_<tail>_0..2`: every tail swishes on its own beat, fanned out from the others,
rising and falling a little (`PET_ANIM.TAILS_*`), and they count as a tail, so the hips stay still.
Many-headed rigs name each neck `Hydra_<head>_0..2` with the head as `Hydra_<head>_3`, and each lower jaw
`Jaw_<head>`: every neck sways and nods on its own beat (the wave running up it) and joins the look, sniff, tilt,
yawn and shake fidgets; jaws snap open now and then, each at its own moment, and gape in a yawn
(`PET_ANIM.HYDRA_*`, `JAW_*`). A single `Jaw_0` stays shut except in a yawn or roar.

Each original also carries itself like the creature it is (`Party.CREATURE_STYLE`): its own idle fidgets (the big
beasts never hop or spin, Infernox stomps with a dust ring, the lynx sits and scratches like a cat, Sprouthop skips
the tail wag it can't do), a slower, smaller tail swish (a cat's swish, a T-rex's heavy sway, a hydra's drift instead
of a dog's wag) and less bounce in its walk. Two-legged rigs stretch by leaning back with their arms up.

Each original has a signature idle (`Party.SIGNATURE`: the fidget and how often it replaces an ordinary one; bone
poses in `Util/PetRig`, effects in `Util/SignatureFx`, fired once when `PetRig.cue` says so):
- **butterfly** (Sprouthop): the right hand comes up, a butterfly appears on it in a puff of sparkles, flutters round
  its head while it looks up and follows it, then flies away fading; its antlers perk up.
- **voidroar** (Voidmaw): the heads stop swaying, rear back and lunge one after another (`ROAR_RIPPLE`), jaws gaping,
  dark void smoke bursting from every mouth, with the roar's shockwave ring.
- **thunderroar** (Boltlynx): head reared back then lunging, ears flat, tail stiff; lightning crackles round its head
  and leaps off the bolts on its ear tips and tail tip in three bursts with a flash, plus the shockwave ring.
- **hiccup** (Cindercub): three little hiccups (`HICCUP_BEATS`), each a small hop with the head jolting back and
  a puff of flame and smoke from its mouth.
- **zaphop** (Zappit): a crouch and a big bunny jump (`ZAPHOP_HEIGHT`); at the top lightning crackles up off its
  ear and tail bolts with a burst of sparks.
- **sporepuff** (Mossmole): up onto its toes, leaning back, as glowing teal spores rise from its mushroom garden
  with a soft glow (`SPORE_*`).
- **petaltwirl** (Petalpaw): a happy spin on its toes (`TWIRL_LIFT`) while pink petals swirl out round it.
- **shadowloop** (Gloomlet): a loop-the-loop in the air (`LOOP_HEIGHT`) trailing violet shadow smoke, sparkles off its
  ear wisps.
- **emberflap** (Ashbeak): a hop with its folded wings beating out (`FLAP_HOP`, `EMBER_FLAP`); at the top a flame
  bursts from its crest with a puff of embers.
- **shypeek** (Shellshy): sinks into its shell with its head tucked (`SHY_DUCK`, `SHY_HEAD`), then peeks back out
  as bubbles rise and its shell sparkles aqua.
- **buzzzap** (Fizzlebug): a zigzag buzz up into the air (`BUZZ_ZIGZAG`, `BUZZ_RISE`); at the top a bolt shoots down
  from its stinger and its antenna bolts spark.
- **ghostfloat** (Wispurr): drifts up swaying (`GHOST_RISE`, `GHOST_SWAY`) while fading half see-through
  (`GHOST_FADE`), violet wisps swirling round it, then sinks back down solid.
- **flameswoop** (Emberwing): climbs, then dives nose-down (`SWOOP_HEIGHT`, `SWOOP_DIVE`) with fire streaming off
  its wing tips and tail, levelling out in a burst of embers.
- **tidecall** (Tidecaller): rears up on its hind legs (`TIDE_REAR`, `TIDE_LIFT`) and stamps down; a ring of water
  splashes out round it with spray.
- **thorncharge** (Briarhorn): head down (`CHARGE_LOWER`), a short charge forward (`CHARGE_LUNGE`, the body's
  `forward` motion) and back; thorny vines burst up in front of it with pink petals and dust.
- **galedive** (Gale Sprite): climbs (`GALE_CLIMB`), dives nose down (`GALE_DIVE`) in one full spinning roll; at the
  bottom a gust swirls round it and lightning bolts flash down from its wing tips.
- **frostpounce** (Frostfang): crouches nose down (`POUNCE_CROUCH`, `POUNCE_TIP`), leaps up and forward
  (`POUNCE_HEIGHT`, `POUNCE_LEAP`) and lands; a ring of glowing ice crystals bursts up there and melts.
- **vinebloom** (Vinewyrm): rears up tall (`BLOOM_RISE`, leaning back `BLOOM_LEAN`) and sways (`BLOOM_SWAY`) as
  pink petals and green leaves burst from its flower crown and drift out.
- **mistwave** (Mistfin): crouches (`MIST_CROUCH`), a proud little hop (`MIST_HOP`, leaning back `MIST_LEAN`), and
  as it lands a ring of glowing mist rolls out across the ground with frosty sparkles.
- **mothdust** (Hushmoth): twirls slowly in the air, drifting up (`DUST_RISE`) and swaying (`DUST_SWAY`), as glowing
  pastel dust sheds from its wing tips with a soft violet glow.
- **watershake** (Driplet): fluffs up (`WATER_FLUFF`), then shakes hard side to side (`WATER_SHAKE`) with its folded
  wings flapping out; a ring of water drops splashes off and its head drop sparkles.
- **staticshock** (Sparkrat): shivers faster as static builds (`STATIC_SHIVER`), then hops (`STATIC_HOP`) with its
  arms flung up (`STATIC_ARMS`) as lightning arcs from its bolt tail to both ears.
- **emberglow** (Coalbit): hunkers down (`EMBER_CROUCH`) and shivers (`EMBER_SHIVER`) as its ember spots flare;
  embers, sparks and smoke rise off its back in waves with a warm orange glow.
- **owlturn** (Nightowl): the head swivels round behind (`OWL_TURN` degrees over neck and head), snaps back and nods
  with a hoot (`HOOT_NOD`); eyes flash, shadow feathers burst, a silver crescent moon rises behind its head.
- **mantaroll** (Reefray): rises (`MANTA_RISE`) and turns one full barrel roll, aqua sparkles streaming off its wing
  tips, then a ring of water splashes out (the effects go by its wingspan, `MANTA_SPAN`).
- **abysschomp** (Abyssal Koi): draws back and lunges forward snapping (`CHOMP_DRAW`, `CHOMP_LUNGE`); a dark surge of
  deep water bursts from its fangs with cyan sparks and bubbles.
- **thundercall** (Thunderhorn): rears up and stamps down (`THUNDER_REAR`, `THUNDER_LIFT`; shares the tide call's
  curve) as lightning strikes from the sky onto its antlers and crackles round its hooves, with a flash.
- **riftroar** (Riftwalker): a roar (rears back, lunges, shockwave ring) that tears a swirling violet void rift open
  in the air behind it, then closes it, with dark smoke from its jaws.
- **lavaslam** (Cinder Titan): pounds its chest with each arm in turn (`SLAM_POUND`), raises both fists
  (`SLAM_RAISE`, `SLAM_LIFT`) and slams them down: a ring of fire and lava bursts out, its fists blazing.
- **blessing** (Tideborne Kirin): rears and stamps (`BLESSING_REAR`, `BLESSING_LIFT`; the tide call's curve); water
  and golden light spiral up round it, golden rays shine from its feet and a ring of light flares behind its head.
- **hornstorm** (Stormking, Stormjack): the thorn charge's motion (head down, a short charge); its horns crackle and
  lightning rains down in a ring round it with a flash.
- **stormroar** (unused since Stormjack became a ram): the three heads roar in a ripple like Voidmaw's, lightning
  leaping from mouth to mouth in four bursts, plus the shockwave ring.
- **firebreath** (Infernox): rears back, then thrusts its head out and holds it, mouth wide, while a cone of fire
  pours from its mouth (and follows it) for over a second, lighting up round it.
- **shellcrack** (Puffpuddle): sits up on its hind legs, a blue clam appears between its front paws and it looks down
  and taps it four times, a little sparkle with each tap; the clam fades away.
- **sneeze** (Blazehound): a quick rear back and a sharp snap forward, a little puff of flame, embers and smoke from
  its nose.
- **kungfu** (unused since Thornback became a boar): chops with the right scythe, then the left, twice, turning into each chop, while leaves
  whirl out round it.
- **eclipse** (Eclipse Fox): sits back on its haunches and looks to the sky as a dark orb ringed with golden light
  rises over its head, glowing violet, then fades.
- **backflip** (Duskstalker): crouches, springs up and flips right over backwards (`BACKFLIP_HEIGHT`), shadow smoke
  where it takes off and a smoky trail through the flip.
  A fidget's whole-body pitch (the flip, a roar's rear-back, a stomp's tip) turns rigged pets round their middle, so a
  flip never puts the head in the ground.
- **voltcharge** (Voltkit): brings both fists up in front, braced, its cape swept back; lightning arcs between its
  fists, building up, then a bolt shoots into the sky with a flash.
- **solarroar** (Solarion): its three heads rear and lunge one after another, jaws wide, fire bursting from every
  mouth with a flash of sunlight and the shockwave ring.

- **Boltlynx** (`rig_boltlynx.py`, the first Meshy-generated original): a golden cartoon electric lynx with tall
  ears, white zigzag stripes and a long tail; flat lightning bolts added by hand on its tail tip and ear tips (mapped
  to a pale yellow patch painted into the colour map) so it reads as mythical. One closed mesh, 24 bones (with
  `Ear_` bones), about 8,400 triangles. Replaced the blocky lion (`build_boltlynx.py`, kept for reference).
- **Cindercub** (`rig_cindercub.py`, Meshy): a very cute red-orange fire bear cub standing upright like a teddy
  bear, paws resting on its cream tummy, a little flame tuft on its head and a flame-tipped stubby tail; walks on two
  short legs with a small arm swing (`ARM_POSE` swing 14). One closed mesh, 22 bones (with `Ear_` bones), about
  8,400 triangles. Replaced the bought RedMole.
- **Zappit** (`rig_zappit.py`, Meshy): a very cute lavender bunny standing upright, white belly, pink blush, a gold
  gem on its brow, small yellow lightning bolts on its long ear tips and a round yellow ball of lightning for a tail.
  Walks on short legs with big feet, arms at its sides; two bones per ear. 24 bones, about 8,500 triangles. Replaced
  the tinted FairyRabbit. (Regenerated: the first one looked like Pikachu and had a lopsided face.)
- **Mossmole** (`rig_mossmole.py`, Meshy): a very cute upright egg-shaped mole, brown with a cream face and pink
  cheeks, hugging a little moss garden with glowing teal mushrooms to its chest; waddles on tiny feet, arms barely
  swinging. Remeshed and baked (`rig_kit.remesh_bake`). 18 bones, 10,000 triangles. Replaced the tinted RedMole.
- **Petalpaw** (`rig_petalpaw.py`, Meshy): a very cute upright orange squirrel cub with a cream belly, pink blush,
  a pink five-petal flower on its head and a big tail painted as a pink petal (rose fading to blush); walks upright,
  arms swinging, the tail swaying slowly. Remeshed and baked. 24 bones, 8,000 triangles. Replaced PlantSquirrel.
- **Gloomlet** (`rig_gloomlet.py`, Meshy): a very cute round shadow bat, dark purple with a lilac belly, big eyes,
  tiny fangs, a crescent moon on its brow and a glowing violet wisp on each ear tip (added by hand). The first original
  that flies: `flies = true` in `Party.CREATURE_MODELS`, its `Wing_<Side>_0..2` bones flap. 18 bones, about 8,000
  triangles (collapse decimation; a voxel remesh would melt the wing membranes). Replaced the DarkBat.
- **Ashbeak** (`rig_ashbeak.py`, Meshy): a very cute ash-grey chick with a cream belly, a flame crest, glowing
  ember zigzags round its back and a fiery tail (both painted by hand: Meshy left them out); waddles on orange feet,
  folded wings as arms fluttering at its sides (it no longer flies). 21 bones, about 7,000 triangles. Replaced the
  tinted StoneBird.
- **Shellshy** (`rig_shellshy.py`, Meshy): a shy mint-green baby sea turtle with a teal dome shell covered in aqua
  swirls and a small pearl on its head; plods on four stubby flippers. Right first time. 20 bones, about 6,700
  triangles. Replaced the Turtle.
- **Fizzlebug** (`rig_fizzlebug.py`, Meshy): a chubby upright bumblebee, yellow with navy stripes, with cyan
  lightning bolts on its antenna tips and a glowing cyan stinger (both added by hand: Meshy left the stinger as a loose
  crystal). Flies (`flies = true`), one `Wing_` bone per wing beating (`WING_SPEED` 0.9: faster shook the whole body). 19 bones, about 7,700
  triangles. Replaced the Venowasp.
- **Wispurr** (`rig_wispurr.py`, Meshy): a cute upright ghost kitten, tinted pale lavender by hand, with big teal
  eyes, a violet star on its forehead and a tail ending in a glowing violet wisp flame; paws held up in front. 20 bones,
  about 6,800 triangles. Replaced the tinted FairyRabbit.
- **Emberwing** (`rig_emberwing.py`, Meshy, Very Rare): a proud charcoal fire swallow with fierce amber eyes, flame-
  feather wings spread wide, a flame crest and a fanned flame tail. Flies; three `Wing_` bones per wing. Right first
  time. 22 bones, about 8,000 triangles. Replaced the tinted NeonSwallow.
- **Tidecaller** (`rig_tidecaller.py`, Meshy, Very Rare): a pale aqua sea dragon on four legs with crystal horns
  (as `Ear_` bones), a ridge of spines, crystal fin-wings on its back (`Wing_` bones, folded on the ground) and a
  fish-fin tail. Right first time. 28 bones, about 9,900 triangles. Replaced the Merilux.
- **Briarhorn** (`rig_briarhorn.py`, Meshy, Very Rare): a massive rusty forest bison with a tall hump, white horns
  (as `Ear_` bones) wrapped in thorny vines and roses, and a rose wreath on its hump, matching its card art. Remade
  27 Oct (the first model, a slim cow, was too skinny). Remeshed and baked; heavy gait (`legSwing` 0.75: its short legs
  under a deep belly looked crouched at the full swing). 23 bones, 10,000 triangles. Replaced the EarthBull.
- **Coalbit** (`rig_coalbit.py`, Meshy, Common; was the tinted Salamander): a cute charcoal baby salamander cub sitting
  up on two legs with its paws on a peach belly, ember-spotted tail, flame tuft. The first try (a splayed four-legged
  salamander) had five legs and was replaced (`Coalbit_v1.blend`). Hand fixes: a loose second tail deleted, the turned
  body and head straightened, the ear bones limited to the ear tips. No neck bone (the head sits on the short body).
  Signature ember glow. Size 1.4. 17 bones, 7,500 triangles.
- **Sparkrat** (`rig_sparkrat.py`, Meshy, Common; was the LightingMouse): a chubby mauve-pink electric mouse with a
  cream belly, buck teeth and big orange-lined ears, generated in a T-pose (right first time). Its tail came out a
  plain stub, so a big yellow bolt was added by hand (`rig_kit.bolt`). The arm band is reweighted to the arm bones (the
  still upper arms looked like a second pair once the arms moved). Arms held out (`ARM_POSE` hang 50) and bobbing
  standing (`idle` 18). Signature static shock. Size 1.4. 19 bones, 7,000 triangles.
- **Driplet** (`rig_driplet.py`, Meshy, Common; was the FrostDove): a chubby white water dove with blue wings, tail and
  feather crest, keeping its card's look. Meshy put the drop on its chest, so a big glowing water drop was added on its
  head by hand (`rig_kit.droplet`); remesh_bake (collapse decimate faceted its round body). Crest and drop on their own
  `Ear_` bones (weights kept above the head). Signature water shake. Size 1.6. 20 bones, 9,200 triangles.
- **Hushmoth** (`rig_hushmoth.py`, Meshy, Common; was the FairyMoth): a fluffy white moth with glowing blue eyes,
  golden feathery antennae and small pastel wings standing up behind its head, keeping its card's look. 1.4M triangles
  of fur: remesh_bake at a fine 4 mm voxel (keeps the wing sheets). Wings and antennae weighted by position, the wings
  fading in from their root (a hard edge creased them). Flies (`WING_SPEED` 0.7). Signature moth dust. Size 1.4.
  17 bones, 10,000 triangles.
- **Nightowl** (`rig_nightowl.py`, Meshy, Rare): a shadow owl (a redesign to match its name, replacing the bought
  heron demon): plump, dark violet, glowing violet eyes, a silver crescent moon on its forehead, smoky wing tips.
  Right first time; 1.2M triangles of feathers shattered under collapse decimate, so remesh_bake at a fine 4 mm voxel.
  Flies. Signature owl turn. 20 bones, 10,000 triangles.
- **Reefray** (`rig_reefray.py`, Meshy, Rare): a coral manta ray (a full redesign, replacing the bought metal crab):
  pale with glowing aqua spots, teal edges and curled coral head fins. Generated standing on end and belly up (turned
  over by hand). Flies; flat, so `size` 0.6 (models scale by height) and `wingAmount` 0.3 (full wingbeats folded its
  broad wings up on end). Signature manta roll. 21 bones, 8,000 triangles.
- **Abyssal Koi** (`rig_abyssalkoi.py`, Meshy, Epic): a massive fierce ice shark (remade 27 Oct on the user's call,
  replacing the first armoured koi). Meshy gave only cyan fin tips, so 19 ice crystals were added by hand with
  `rig_kit.crystal` (dorsal crown, back ridge, ice horns over the eyes, fin and tail shards; two colours from
  `paint_patch`). Swims (`Party.UNDULATE` "swim"). 10 bones, about 8,400 triangles. Replaced the tinted IceShark.
- **Thunderhorn** (`rig_thunderhorn.py`, Meshy, Epic): a majestic cream thunder stag with huge branching golden
  antlers (as `Ear_` bones, each antler wholly on its bone via `rig_kit.reweight`) and slim deer legs. Remade 27 Oct
  (the first, heavy-set one read as a bull). Generated turned and with its head turned: body turned straight, head
  straightened by hand (steps in the script). Size 1.8. 22 bones, 9,000 triangles. Replaced the tinted Lumistag.
- **Riftwalker** (`rig_riftwalker.py`, Meshy, Epic): a massive black void dragon with glowing violet rift cracks, a
  fanged roaring maw, swept-back horns, back spikes, folded wings (`Wing_` bones) and a long spiked tail; prowls on four
  legs; its lower jaw is on `Jaw_0` (cut out of the head with `rig_kit.reweight`) and opens for roars and yawns.
  Right first time. 27 bones, about 10,000 triangles. Replaced the VoidDragon.
- **Cinder Titan** (`rig_cindertitan.py`, Meshy, Epic): a massive charcoal volcano gorilla with a molten lava chest,
  glowing claws and rock shoulder armour; lumbers upright with a heavy gait (long slow steps, rolling from foot to
  foot onto a bent knee: `CREATURE_STYLE` stride/legSwing/sway), its huge arms swinging low (`ARM_POSE`). Remeshed and baked.
  18 bones, 10,000 triangles. Replaced the GorillaVulcano.
- **Tideborne Kirin** (was Aurora Drake; `rig_kirin.py`, model `Kirin`, Meshy, Legendary): a celestial sea kirin,
  pearl-white with an aqua water mane and wave tail, golden horns (as `Ear_` bones), a golden halo and golden armour.
  Meshy made it prancing: the raised right front leg was replaced by a mirror of the left (see `rig_kirin.py`). Walks
  with a long unhurried stride at size 2.5. 25 bones, 14,000 triangles. Replaced the Crystal Titans RainbowHydra.
- **Stormking** (`rig_stormking.py`, Meshy, Legendary): a colossal storm titan beetle, an armoured sapphire shell with
  glowing crystal spikes, a gold horn and a long tail spike, on four thick armoured legs. Remeshed and baked. 21 bones,
  12,000 triangles. Replaced the Crystal Titans SapphireCrab.
- **Voidmaw** (`build_voidmaw.py`): seven-headed obsidian hydra dragon with violet crystals, on four clawed legs
  (it trots), body level, a six-bone tail straight out behind and the necks rising from its chest; 57 bones (7 necks
  of 4 plus 7 jaws), about 2,750 triangles.
- **Sprouthop** (`rig_sprouthop.py`, Meshy, Common; was the voxel `build_sprouthop.py`): a chubby smiling bark sprite
  with a wide cap of green leaves, generated in a T-pose (Meshy `pose_mode="t-pose"`; the first try had a sad face and
  one waving arm, regenerated). The side leaf tips are its `Ear_` bones. Collapse decimate (thin leaves). Size 1.5.
  20 bones, 8,000 triangles.
- **Stormjack** (`rig_stormjack.py`, Meshy, Rare; was the voxel `build_stormjack.py` baby hydra): a chunky storm
  ram, picked to be light and easy to animate: a grey storm-cloud fleece, dark slate face and legs, big curled golden
  horns (its `Ear_` bones), amber eyes and one yellow bolt lying on each flank (`rig_kit.bolt`; two rising from its
  back looked random and were removed). Remeshed and baked (5 mm voxel). Hooves by `nearest_leg`. Signature hornstorm.
  Size 1.7. 20 bones, 9,000 triangles.
- **Infernox** (`rig_infernox.py`, Meshy, Epic; was the voxel `build_infernox.py`): a massive red fire T-rex with black
  tiger stripes, a cream belly and jaw, a flame crest down its neck, small arms held in front as modelled (`ARM_POSE`
  hang 0) and its lower jaw on `Jaw_0` (`rig_kit.reweight`) for the fire breath. Remeshed and baked; its turned head
  and curved tail were straightened by hand (steps in the script). Size 1.8. 24 bones, 10,000 triangles.
- **Puffpuddle** (`rig_puffpuddle.py`, Meshy, Common; was the voxel `build_puffpuddle.py`): a cute baby sea otter
  standing upright with its paws on its cream belly and a glowing aqua pearl on its forehead. Coat warmed from rusty
  red to the card's brown by hand; its lumpy left foot replaced by a mirror of the right (seam-only merge, on the full
  mesh). Arms are moulded to the belly, so only a small swing (`ARM_POSE` swing 6). Shell crack signature: the clam
  appears between its hands (`SignatureFx` frontPaws uses `Arm_` hands when it has them). Size 1.4. 22 bones, 8,000
  triangles.
- **Blazehound** (`rig_blazehound.py`, Meshy, Rare; was the voxel `build_blazehound.py`): a chubby black-and-tan
  dachshund puppy with droopy ears and golden flame tufts. Right first time apart from the tufts (a curl on one side
  only): the curl was copied mirrored onto the other side on the full mesh, nothing else touched. Ear flaps weighted to
  the `Ear_` bones by position. Size 1.3. 22 bones, 8,500 triangles.
- **Thornback** (`rig_thornback.py`, Meshy, Rare; was the voxel kung-fu mantis `build_thornback.py`): a chunky
  moss-green thorn boar with a pink snout, white tusks and a crest of thorny vines and blossoms (redesigned at the
  user's call: a Meshy mantis first came out ugly, kept in `Thornback_mantis.blend`). Remesh_bake; ears weighted to the
  `Ear_` bones by position. Signature thorn charge (shared with Briarhorn). Size 1.4. 21 bones, 10,000 triangles.
- **Magmaw** (`rig_magmaw.py`, Meshy, Rare; was the tinted Salamander): a chunky red-orange lava salamander with a
  toothy grin, glowing yellow belly and jaw and flame spikes along its back and tail. Asked for legs straight under the
  body (Coalbit's splayed legs went wrong): four square feet, right first time. Lower jaw on `Jaw_0` (kept above the
  claws, which reach under the snout); ground-level claws given to their feet. Signature fire breath (shared with
  Infernox). Size 1.3. 23 bones, 9,000 triangles.
- **Mistfin** (`rig_mistfin.py`, Meshy, Rare; was the IceShark): a proud mist seal pup standing upright (a full
  redesign, since Abyssal Koi is the shark), grey-blue with a pale belly, a frosty tuft, flipper arms and a long flat
  tail fin. Its glowing aqua marks (wavy mist lines on its back, dots on its tail) are painted into the texture by the
  script (`paint_marks`, texel by texel through the UVs). Flippers and toes weighted to their bones by position.
  Signature mist wave. Size 1.4. 20 bones, 10,000 triangles.
- **Vinewyrm** (`rig_vinewyrm.py`, Meshy, Rare; was the GiantSnake): a chunky lime-green vine serpent with a flower
  crown, blossoms and leaves along its sides, its neck raised and tail curled up. A bone chain from the head down the
  neck, along the body and up the tail; slithers (`Party.UNDULATE` "slither"). Signature vine bloom. Size 1.7 (raised
  from 1.4 on request: a Rare should read medium). 10 bones, 10,000 triangles.
- **Frostfang** (`rig_frostfang.py`, Meshy, Rare; was the tinted PurpleFox): a mythical ice fox standing square, pale
  icy blue with a simple white mane, teal ice crystals along its back and on its forehead, a pale ice blade over its
  rump. A loose first prompt gave a plain spiky fox sitting turned; the firm second prompt (see the script) came out
  right. Ears and paws weighted to their bones by position. Signature frost pounce. Size 2 (raised on request).
  22 bones, 9,000 triangles.
- **Gale Sprite** (`rig_galesprite.py`, Meshy, Rare; was the NeonSwallow, the last bought model): a mythical storm
  swift, deep blue with a white chest, a silver wind crest, lightning crackling off its spread wings and a storm-cloud
  tail puff. Firm prompt, right first time; fine remesh (3.5 mm) keeps the thin lightning strands. Each wing, with its
  lightning, weighted to its three `Wing_` bones by how far out it reaches. Flies (`WING_SPEED` 0.8). Signature gale
  dive. Size 1.9 (raised on request). 20 bones, 10,000 triangles.
- **Duskstalker** (`build_duskstalker.py`, Very Rare): a shadow Monkey King on two legs, stocky (broad shoulders,
  barrel chest, thick limbs, big fists and feet, a big head): dark plum fur, a tan face and chest, glowing amber eyes
  under low brows and a sly smile, a golden circlet with a violet gem, gold pauldrons, a red cape, purple trousers,
  gold belt, wrist and ankle bands, a golden staff with red bands, longer than it is tall, gripped through its right fist
  like a carried weapon (it crosses the fist, so with the arm hanging it points forward, nearly level, held at its
  middle), a long curled tail; 24 bones, about 650 triangles.
- **Eclipse Fox** (`rig_eclipsefox.py`, Meshy, Epic; was the voxel `build_eclipsefox.py` nine-tailed kitsune): a
  chunky shadow kitsune, deep violet with a big white ruff, a golden eclipse ring on its brow, violet rings on its
  flanks, narrow golden eyes and tall ears. Meshy swung its rear half 28 degrees (straightened by hand) and bunched its
  tails together; the user wanted two or three that animate cleanly, so every generated tail was cut off and three
  smooth white-tipped tails built in code (`rig_kit.tail`), one rising and two fanned out, each its own shell whose
  vertices follow only its own `Tails_<tail>_0..2` chain. Size 1.8. 29 bones, about 7,500 triangles.
- **Voltkit** (`build_voltkit.py`, Very Rare): a fox hero on two legs, blocky and sturdy: golden fur, a cream chest
  with magenta chevrons, magenta ear tips, cuffs and tail band, amber eyes under determined magenta brows, a pink gem on
  its brow and another on a magenta necklace, a magenta cape on `Cape_` bones, dark gloves and boots, a bushy
  cream-tipped tail; 27 bones, about 700 triangles. Replaces the tinted Ultra pack PurpleFox.
- **Solarion** (`build_solarion.py`, Legendary): a massive three-headed cerberus of black obsidian and jagged glowing
  ruby crystals: snarling wolf heads with red eyes and crystal fangs on short thick necks (`Hydra_` bones, each with a
  jaw), crystal spikes along its back, crystal talons, a crystal-tipped tail; 35 bones, about 7,300 triangles.

Import the `.fbx` with Studio's 3D Importer (rig type Custom, Keep Zero Influence Bones on), check the model
faces -Z and its bones move the mesh, then save it into the `Originals` pack file as above. The importer turns
the MeshPart's `PivotOffset` 90 degrees on X (Blender is Z-up); reset its rotation
(`mesh.PivotOffset = CFrame.new(mesh.PivotOffset.Position)`) before saving, or the game stands the model's bounding box
upright and the creature lies on its back.

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
