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

- **Blazehound** (HotDog): a chunky blocky voxel-style dachshund dog, glossy jet-black body with warm tan-orange
  muzzle, chest, belly and paws, droopy black ears, two little red flame tufts with yellow tips on top of its
  head, a thin black tail ending in a bright red-and-yellow flame.
- **Boltlynx** (original electric lynx, Rare): a slightly fierce cartoon electric lynx standing on four slender legs,
  rounded stylized toy-like 3D style, bright golden-orange body, white zigzag lightning-stripe markings on its back and
  flanks, cream muzzle, chest and belly, very tall pointed ears with dark inner ears, each ear tipped with a glowing
  pale yellow lightning bolt, sharp amber eyes with a confident look, a long thin tail with brown bands ending in a big
  glowing pale yellow zigzag lightning bolt, small crackling sparks leaping off its ear and tail bolts (pose: standing
  alert and confident on a rocky ledge; lighting: dramatic stormy lighting with bright flashes).
- **Voidmaw** (original hydra, legendary): a chunky blocky voxel-style hydra dragon standing on four clawed legs with
  its body level like a beast, black obsidian body with pale violet belly plates, tall jagged glowing violet crystals
  along its back and long tail, seven long blocky necks rising from its chest in a wide fan, each ending in a blocky
  dragon head with glowing pale eyes, white teeth, glowing purple mouths and a crown of violet crystals, the middle
  head tallest.
- **Sprouthop** (original tree sprite): a chunky blocky voxel-style little tree sprite standing upright on two legs
  like a person, a twisted brown bark body with lighter bark strands, a big square blocky head with a light wooden
  face, big glossy dark eyes with white shine, pink blush and a small smile, a fluffy cap of green leaf cubes with two
  small twig antlers, thin bark arms with twig fingers, its right hand raised holding a tiny sprout with a small
  butterfly landing on it, root-like feet, little mushrooms on its legs.
- **Stormjack** (original baby hydra, Rare so friendly): a cute chunky blocky voxel-style baby hydra, friendly and
  harmless, a round light electric-blue body on short stubby legs with pink toe beans, a cream yellow tummy, three
  short necks with big round blocky heads, each with big shiny dark eyes, pink blushing cheeks, a small happy smile
  with no teeth, two little yellow horn nubs and a tiny yellow lightning-bolt tuft, a short curly tail ending in a
  little yellow lightning bolt, small friendly sparks (lighting: bright playful stormy lighting).

- **Puffpuddle** (original sea otter, Common): a very cute chubby sea otter standing on all four short legs, rounded
  soft toy style (smooth rounded shapes, slightly blocky), a long dark brown body, a round pale cream fluffy face, big
  shiny dark eyes, pink blushing cheeks, a tiny black nose, whiskers and a happy smile, small round ears, a pale chest,
  big flat webbed hind feet, a flat tail (pose: standing happily on a rock).
- **Eclipse Fox** (original nine-tailed kitsune, Epic): a sturdy fierce mystical nine-tailed kitsune fox standing on
  four thick legs, rounded stylized toy-like 3D style, deep violet fur with a big fluffy white chest ruff, white cheek
  tufts, glowing violet crescent moon markings on its flanks, a small glowing violet gem on its brow, narrow sharp golden
  eyes, tall pointed ears, nine huge fluffy violet tails with white tips fanned out behind it, above its head a dark
  eclipse with a glowing golden ring of light (lighting: eerie violet moonlight).
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
