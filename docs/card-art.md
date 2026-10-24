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
- **Boltlynx** (Leonstrike): a chunky blocky voxel-style anthropomorphic lion warrior standing upright, huge spiky
  golden-yellow mane, grey sleeveless tunic with a yellow lightning bolt emblem, golden shoulder armour with
  black-and-white pauldrons, golden arm guards, brown belt with pouches, dark brown trousers, black-and-gold
  striped boots, a lion tail with a golden tuft, small sparks of electricity.
- **Solarion** (RubyCerberus): a massive three-headed wolf made of jagged glowing ruby-red crystals and black
  obsidian stone, glowing red eyes, white crystal fangs, tall red crystal spikes along its back, red crystal talons.

The other 38 follow the same template with descriptions read off each model's render, part names and colours
(the tinted ones described in their tint: Zappit lemon-yellow and Wispurr lavender FairyRabbit, Magmaw fire-orange
Salamander, Voidmaw violet Hydra...). Redo one that comes out off-model (Ashbeak first came out a white owl, Voltkit on
four legs: say "made of dark charcoal-grey stone blocks", "standing upright on two legs like a person").
