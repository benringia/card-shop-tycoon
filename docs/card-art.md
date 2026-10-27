# Card art

Each card's face shows its creature painted into its element's scene: the creature is described from its
in-game model (colours, shape, outfit, effects) and generated with Figma's image generator
(`gemini-3.1-flash-lite-image`, 768 x 1088 requested, 848 x 1264 returned) in the file "Card Shop Tycoon - Card
Art". The JPEG is resized to 680 wide, kept in `assets/ui/card-art/<Card>.jpg`, uploaded to Roblox and its id
put in `Config/CardDesign` `ART_IMAGES`. A card without one shows its element scene and emoji.

## Prompt

```
Tall vertical trading card game creature illustration, one single continuous scene, painterly stylized digital
painting, <lighting>, vibrant colors, fantasy style. The creature: <description from the model>. Full body,
three-quarter view, <pose> in the lower middle of the picture, plenty of room above its head. Background:
<element scene>, <ground> continuing down to the bottom edge. No text, no letters, no border, no frame.
```

- Say "chunky blocky voxel-style" for Ultra Detailed models so the art keeps their look; the Crystal Titans are
  "made of jagged glowing crystals".
- Don't ask for calm areas for the card text: the generator then paints a blurred copy into the bottom.
- Legendaries: "legendary creature", "epic dramatic lighting".

Element scenes (matching `CardDesign.SCENES`):

| Element | Scene |
|---|---|
| Ember | a cozy cabin interior with a glowing stone fireplace, floating embers, soft orange firelight and bokeh |
| Tide | a sunlit coral reef underwater, light rays, bubbles, colourful corals |
| Bloom | a sunny forest clearing, flowers, soft green light, floating petals |
| Volt | a stormy mountain peak at night, purple and indigo storm clouds, bright yellow lightning bolts, sparks |
| Shade | a moonlit graveyard, purple mist, glowing violet wisps, a big pale moon |

## Creature descriptions used

- **Blazehound** (original dachshund puppy, Rare; Meshy remake): a cute chubby cartoon dachshund puppy, rounded
  stylized toy-like 3D style, a long low plump body on four short stubby legs, glossy black coat with warm tan-orange
  muzzle, eyebrows, chest patch and paws, long droopy black ears, big kind shiny brown eyes, a black nose and a friendly
  smile, three small golden flame tufts on top of its head (one in the middle and a matching curled one on each side),
  a thin black tail held up, a few glowing embers floating around it (pose: standing happily on a rug; lighting: warm
  cozy firelight).
- **Thornback** (original thorn boar, Rare; was the voxel kung-fu mantis): a slightly fierce chunky cartoon thorn
  boar, rounded stylized toy-like 3D style, a stocky round moss green body on four short legs with dark hooves, a big
  round pink snout, two white curved tusks, fierce amber eyes, small pointed ears with pink insides, a cream belly, a
  thick crest of dark green thorny vines with small pink blossoms on top of its head, a short curly tail (pose:
  standing firmly on a mossy path; lighting: soft green sunlight).
- **Magmaw** (original lava salamander, Rare; was the tinted Salamander): a slightly fierce chunky cartoon lava
  salamander, rounded stylized toy-like 3D style, a long plump bright red-orange body on four short thick legs with
  small white claws, a glowing yellow belly and lower jaw, a wide open toothy grin with small white teeth, fierce dark
  eyes, a row of big chunky orange flame-shaped spikes along its back and long tail, small embers and a little puff of
  flame rising from its mouth (pose: crawling across a rug; lighting: warm cozy firelight).
- **Mistfin** (original mist seal pup, Rare; was the IceShark): a slightly fierce, proud chunky cartoon seal pup
  standing upright, rounded stylized toy-like 3D style, a plump grey-blue body with a pale peach belly, big shiny dark
  eyes with a determined look, rosy cheeks, a small black nose and whiskers, a fluffy frosty white tuft on top of its
  head, two flipper arms at its sides, a long flat tail fin, three wavy glowing aqua mist lines across its back and
  glowing aqua dots on its tail fin, swirls of glowing mist curling around it (pose: standing proudly on a rock;
  lighting: bright underwater light rays with soft mist).
- **Vinewyrm** (original vine serpent, Rare; was the GiantSnake): a slightly fierce chunky cartoon vine serpent,
  rounded stylized toy-like 3D style, a thick plump lime green snake body lying along the ground with its neck raised
  up tall and its tail curling up behind, a pale yellow-green banded belly, big glowing amber eyes, a small forked red
  tongue, a crown of pink flowers and green leaves on its head, pink blossoms and leafy sprigs along its sides, a few
  pink petals drifting around it (pose: raised up proudly on a mossy log; lighting: soft green sunlight).
- **Frostfang** (original ice fox, Rare; was the tinted PurpleFox): a slightly fierce mythical cartoon ice fox,
  rounded stylized toy-like 3D style, a sturdy pale icy blue body standing on four legs, a white chest and a simple
  smooth white mane on its neck, big pointed ears, fierce glowing ice-blue eyes, glowing teal ice crystal spikes along
  its back, a glowing teal crystal gem on its forehead, a big pale ice blade rising over its rump above a fluffy white
  tail, small ice crystals glittering around its paws (pose: standing proudly on an icy rock; lighting: bright
  underwater light rays with icy glints).
- **Gale Sprite** (original storm swift, Rare; was the NeonSwallow): a slightly fierce mythical cartoon storm swift
  bird, rounded stylized toy-like 3D style, a plump deep blue body with a white chest, fierce glowing yellow eyes, a
  sharp orange beak, a swirling silver wind-shaped crest on its head, both wings spread wide with bright yellow
  lightning crackling off them, a long tail ending in a fluffy grey storm cloud puff, small orange talons, swirls of
  wind around it (pose: soaring with wings spread; lighting: dramatic stormy lighting with bright flashes).
- **Stormjack** (original storm ram, Rare; was the voxel baby hydra): a slightly fierce chunky cartoon storm ram,
  rounded stylized toy-like 3D style, a plump round body covered in fluffy grey storm-cloud fleece, a dark slate blue
  face and short legs with dark hooves, fierce amber eyes, two big thick curled golden horns, a bright yellow lightning
  bolt mark on each side of its fleece, little sparks crackling round its horns (pose: standing firmly on a rocky
  ledge; lighting: dramatic stormy lighting with bright flashes, stormy mountain peak at night).
- **Boltlynx** (original electric lynx, Rare): a slightly fierce cartoon electric lynx standing on four slender legs,
  rounded stylized toy-like 3D style, bright golden-orange body, white zigzag lightning-stripe markings on its back and
  flanks, cream muzzle, chest and belly, very tall pointed ears with dark inner ears, each ear tipped with a glowing
  pale yellow lightning bolt, sharp amber eyes with a confident look, a long thin tail with brown bands ending in a big
  glowing pale yellow zigzag lightning bolt, small crackling sparks leaping off its ear and tail bolts (pose: standing
  alert and confident on a rocky ledge; lighting: dramatic stormy lighting with bright flashes).
- **Cindercub** (original fire bear cub, Common): a very cute chubby cartoon fire bear cub standing upright on two
  short stubby legs like a teddy bear, rounded stylized toy-like 3D style, bright red-orange body, big round head with
  small round ears, big shiny dark eyes, pink blushing cheeks, a tiny happy smile with its little pink tongue out, a
  cream muzzle and a big round cream tummy with its small paws resting on it, a little flame tuft on its head, a short
  stubby tail with a tiny flame, a small puff of flame and smoke as it hiccups (lighting: warm cozy firelight).
- **Zappit** (original electric bunny, Common): a very cute chubby cartoon bunny standing upright on two short legs
  with big feet, rounded stylized toy-like 3D style, soft lavender-violet body with a white tummy, big round head, two
  big round shiny dark eyes set close together, soft pink blush, tiny pink nose and small happy smile, a small golden
  gem on its forehead, long upright ears with pink insides each tipped with a small glowing yellow lightning bolt, a
  round glowing yellow ball of crackling lightning as its tail (lighting: bright playful stormy lighting).
- **Mossmole** (original forest mole, Common): a very cute chubby cartoon mole standing upright on tiny pink feet,
  rounded egg-shaped toy-like 3D style, warm reddish-brown body, a cream face with big round eyes, long eyelashes, big
  pink cheeks and a round pink nose, hugging a little round moss garden with three small glowing teal mushrooms, tiny
  glowing teal spores floating up (lighting: soft green sunlight).
- **Petalpaw** (original flower squirrel, Common): a very cute chubby cartoon squirrel cub standing upright on two
  short legs, warm orange body with a big cream belly, big shiny dark eyes, soft pink blush, a pink five-petal flower
  on its head, a big fluffy tail shaped like a soft pink petal (rose at the base fading to blush), pink petals
  swirling round it as it twirls (lighting: soft warm sunlight).
- **Gloomlet** (original shadow bat, Common): a very cute chubby round cartoon bat flying with its wings spread wide,
  dark purple body with a lilac belly, big shiny eyes, soft pink blush, a small smile with two tiny fangs, a small
  glowing violet flame wisp on each ear tip, a glowing pale crescent moon on its forehead, a trail of violet shadow
  smoke (lighting: eerie violet moonlight).
- **Ashbeak** (original ember chick, Common): a very cute chubby round cartoon baby chick on two orange feet, ash-grey
  body with a cream belly, big shiny eyes, soft pink blush, a small orange beak, a little flame crest, glowing orange
  ember zigzag cracks across its back, a short fiery tail, small folded wings flapping, a puff of embers (lighting:
  warm cozy firelight).
- **Shellshy** (original baby sea turtle, Common): a very cute chubby shy cartoon baby sea turtle on four stubby
  flippers, mint-green skin, big shiny eyes, soft pink blush, a shy smile, a teal dome shell with glowing aqua swirls,
  a small glowing pearl on its head, little bubbles round it (lighting: soft sunlit underwater light).
- **Fizzlebug** (original electric bee, Common): a very cute chubby round cartoon bumblebee flying, soft yellow with
  dark navy stripes, big shiny eyes, soft pink blush, antennae tipped with small glowing cyan bolts, small lilac wings,
  little arms, a small glowing cyan stinger crackling with a spark (lighting: bright playful stormy lighting).
- **Wispurr** (original ghost kitten, Common): a very cute chubby round cartoon ghost kitten standing upright, pale
  lavender and faintly see-through, big teal eyes, soft pink blush, a violet star on its forehead, paws held up, a thin
  tail ending in a glowing violet wisp flame, violet wisps round it (lighting: eerie violet moonlight).
- **Emberwing** (original fire swallow, Very Rare): a proud slightly fierce cartoon fire swallow flying, wings spread,
  charcoal-black body, glowing amber eyes with determined brows, a golden beak, flame-feather wings, a flame crest and a
  fanned flame tail, embers trailing (lighting: warm dramatic firelight).
- **Tidecaller** (original sea dragon, Very Rare): a confident slightly fierce cartoon sea dragon on four legs, pale
  aqua-white scales with a teal belly, a long neck, glowing aqua eyes, swept-back crystal horns, crystal spines and
  fin-wings, a long tail ending in an aqua fish fin, water currents swirling round it (lighting: soft sunlit underwater).
- **Riftwalker** (original void dragon, Epic): a massive menacing void dragon crouched low and roaring, black
  obsidian armour with glowing violet rift cracks, glowing violet eyes, an open fanged jaw, swept-back horns, back
  spikes, dark purple wings spread, a spiked tail, a swirling violet void rift tearing open behind it (lighting:
  menacing eerie violet).
- **Cinder Titan** (original volcano gorilla, Epic): a massive menacing volcano gorilla lava golem, huge bulky body,
  dark charcoal rock skin with glowing molten cracks across its chest, black volcanic rock shoulder armour, glowing orange
  eyes, giant flaming boulder fists slamming the ground in a ring of fire and lava (lighting: dramatic fiery).
- **Tideborne Kirin** (original celestial sea kirin, Legendary; was Aurora Drake): a majestic divine sea kirin
  standing proudly, pearl-white with aqua shading, a flowing aqua water mane and wave tail, glowing aqua eyes, curved
  golden horns, a golden halo, golden armour, glowing aqua hooves, water and golden light spiralling round it (lighting:
  epic divine golden and aqua).
- **Stormking** (original storm titan beetle, Legendary): a colossal godlike storm titan beetle, a massive armoured
  sapphire shell with glowing blue crystal spikes and gold trim, a huge golden horn crackling with lightning, four thick
  armoured legs, a long tail spike, lightning striking in a ring round it (lighting: epic dramatic storm).
- **Nightowl** (original shadow owl, Rare; was the heron demon): a slightly fierce cartoon shadow owl, rounded stylized
  toy-like 3D style, plump stocky round body and big round head, large fierce glowing violet eyes, a small sharp hooked
  dark beak, dark violet and deep purple feathers with a pale lilac face disc and lilac patterned chest, small ear
  tufts, a glowing silver crescent moon mark on its forehead, wings spread wide with ghostly purple smoke-tipped
  feathers, short legs with dark talons (pose: hovering with wings spread above a tilted gravestone; lighting: eerie
  moonlit lighting with soft violet glow).
- **Coalbit** (original baby coal salamander, Common; was the tinted Salamander): a very cute chubby cartoon baby coal
  salamander cub sitting up on two short stubby legs like a teddy bear, rounded stylized toy-like 3D style, dark
  charcoal grey skin, a big round head with big shiny dark eyes, pink blush cheeks and a small happy smile, small
  rounded ears with pink insides, a round peach-coloured belly with its little paws resting on it, a small orange flame
  tuft on top of its head, a short thick tail with glowing orange ember spots, a few glowing embers floating around it
  (pose: sitting happily on a rug; lighting: warm cozy firelight).
- **Sparkrat** (original electric mouse, Common; was the LightingMouse): a very cute chubby cartoon electric mouse,
  rounded stylized toy-like 3D style, a round plump egg-shaped body of soft mauve pink fur, a big round cream belly,
  big shiny dark eyes, rosy pink cheeks, a small pink nose and a cheeky happy grin with two little buck teeth, two big
  round ears with orange insides, short stubby arms held out happily, tiny feet, a short tail with a big glowing yellow
  lightning bolt rising from it, little sparks of static crackling around its ears and tail (pose: standing happily on
  a rocky ledge; lighting: bright playful stormy lighting with flashes).
- **Reefray** (original coral manta ray, Rare; was the metal crab): a slightly fierce cartoon coral manta ray, rounded
  stylized toy-like 3D style, wide graceful wings spread out, pale cream-white back covered in glowing aqua spots, teal
  edges along its wings and head, two curled coral-pink head fins like horns at the front, fierce glowing aqua eyes, a
  long thin coral-pink tail, aqua sparkles trailing from its wing tips (pose: gliding, seen from slightly above;
  lighting: bright underwater light rays).
- **Voidmaw** (original hydra, legendary): a chunky blocky voxel-style hydra dragon standing on four clawed legs with
  its body level like a beast, black obsidian body with pale violet belly plates, tall jagged glowing violet crystals
  along its back and long tail, seven long blocky necks rising from its chest in a wide fan, each ending in a blocky
  dragon head with glowing pale eyes, white teeth, glowing purple mouths and a crown of violet crystals, the middle
  head tallest.
- **Sprouthop** (original tree sprite, Common; Meshy remake): a very cute chubby cartoon tree sprite, rounded stylized
  toy-like 3D style, a round plump body of smooth brown bark with wood grain, a big rounded wooden head with big shiny
  dark eyes, pink blush cheeks and a small happy smile, a big wide cap of bright green leaves on top of its head like a
  bush, short chunky bark arms with little twig fingers, short stubby root feet, one hand raised with a small blue
  butterfly landing on it (pose: standing happily; lighting: soft warm green sunlight).

- **Puffpuddle** (original sea otter, Common; Meshy remake, upright): a very cute chubby cartoon baby sea otter
  standing upright on two short legs, rounded stylized toy-like 3D style, warm chocolate brown fur, a lighter brown
  head, a cream face and a big round cream belly with its little paws resting on it, big shiny dark eyes, a black
  button nose, pink blush cheeks and a small happy smile, small round ears, a small glowing aqua pearl on its forehead,
  a thick flat brown tail, a small blue clam shell beside its feet (pose: standing happily on a mossy rock; lighting:
  bright underwater light rays).
- **Eclipse Fox** (original shadow kitsune, Epic; Meshy remake with three tails): a fierce menacing mythical
  shadow kitsune fox, rounded stylized toy-like 3D style, a sturdy muscular deep violet body standing on four thick
  legs, a big fluffy white chest ruff, narrow glowing golden eyes, sharp fangs, tall pointed ears with glowing violet
  insides, a glowing golden eclipse ring on its forehead, glowing violet ring marks on its flanks, exactly three big
  smooth bushy violet tails with white tips, one rising and two spread to the sides (pose: standing on a dark rocky
  outcrop; lighting: eerie violet moonlight under a huge solar eclipse ringed with golden light).
- **Duskstalker** (original Monkey King, Very Rare): a stocky confident monkey king warrior standing upright on two
  legs, rounded stylized toy-like 3D style, dark plum fur, a tan face and chest, big round head, glowing amber eyes
  under low brows with a sly half smile, a golden circlet with a violet gem, gold shoulder armour, a red cape, purple
  trousers with a gold belt, gold wrist and ankle bands, big fists, a long curling tail, a tall golden staff with red
  bands upright in its right hand (lighting: moonlit night with purple mist).

Tone follows rarity: the more common the card, the cuter and less dangerous the creature and its art.
- **Solarion** (RubyCerberus): a massive three-headed wolf made of jagged glowing ruby-red crystals and black
  obsidian stone, glowing red eyes, white crystal fangs, tall red crystal spikes along its back, red crystal talons.

The other 38 follow the same template with descriptions read off each model's render, part names and colours
(the tinted ones described in their tint: Zappit lemon-yellow and Wispurr lavender FairyRabbit, Magmaw fire-orange
Salamander, Voidmaw violet Hydra...). Redo one that comes out off-model (Ashbeak first came out a white owl, Voltkit on
four legs: say "made of dark charcoal-grey stone blocks", "standing upright on two legs like a person").
