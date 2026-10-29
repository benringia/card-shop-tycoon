# UI project 3: cards in the world and the 3D pack opening

Date: 2026-10-29. Branch: `ui-project-3`. Status: approved by the user 2026-10-29, with the calls listed at the end.

## Why

The core loop works, and UI project 2 (the 3D binder) made the collection feel like a real binder. Two things players
look at all the time still look flat:

1. **The shop.** Packs on shelves are thin flat cards with the pack art. Cards in the glass cases lie flat on the bed
   and are hard to read from a step away. The shop should look like a real card shop when a visitor walks in.
2. **The pull.** Ripping a pack is the game's dopamine hit (DESIGN 1: "It needs to look and sound amazing, even at low
   rarities"). Today it's a 2D screen: a flat pack picture, a 2D tear, and confetti that reads like an emoji.

The user pointed at another Roblox game, TCG Cardshop, for the *feel*: a realistic rip of a real 3D pack followed by
3D light effects. We take that feel. We don't copy its look, screens or layout: our art, colours, card faces, sets
and UI stay ours.

## What the user picked (mockups in `.superpowers/brainstorm/3177-1793255093/content/`)

The user saw three directions (`world-concepts.html`: A Hobby Shop, B Glow Arcade, C Collector Boutique), then a mix
(`combined-v1.html`), then a playable preview of the opening built from real Blender assets (`rip-preview-v1.html`).
Their decisions:

- **Shelves: A (Hobby Shop).** Packs stand in open cardboard display boxes, lid flipped up with the pack art, on the
  shelves, with price tags on the shelf edge. Deck boxes stand stacked beside them.
- **Glass cases: B (spinning).** Each card floats upright over its slot and slowly spins, on a light beam in its
  rarity colour, with its price under it.
- **Pack opening: B's rip, but the cards come out one at a time like a real Pokémon pack**, with a custom Blender
  visual effect, no emoji-like confetti (Blender/Meshy-made pieces instead), and a little cinematic on the rip.
- **The pack model gets better:** a real 3D pack, not a flat picture.
- **After the rip, the cards stack up one by one with a snappy animation**, and each card gets a flip animation.
- **The shown hit card is alive:** yellow sparkles and motion so it feels satisfying.
- **Results:** the cards don't just sit in a row at the bottom; they fly one by one to the middle with sparkles,
  **snappy** (the user asked for faster after the first version; the preview's timing is the approved one).
- "all good, proceed" on `rip-preview-v1.html` as it stands.

## Goals

1. One real 3D pack model per pack type, used on the opening stage, on shelves (inside the display boxes) and in the
   Set Price window.
2. Shelves show packs in open display boxes that empty pack by pack as stock sells.
3. Glass Showcases and Collector Cases show their cards upright, floating and spinning on rarity-coloured light.
4. A 3D pack opening stage that plays the approved sequence: cinematic tear → cards stack up one by one → flip each
   card (rarity tease and celebration, the shown Rare-or-better card alive) → each card zips into a row → the results
   lineup flies to the middle with sparkles.
5. Custom effects made in Blender (rip burst, foil shards, glint), used as Roblox particle flipbooks.
6. Runs on phones: the binder's budget (Studio at graphics level 1, worst frame under 50 ms) and the user's
   iPhone 16 Pro Max for feel.

## Non-goals

- Changing what's in a pack, the odds, pity, prices or the economy. The server already rolls the cards; this only
  changes how they're shown.
- Changing saved data. No schema bump.
- The Fast Open pass (DESIGN 8, not built yet). The new opening must leave room for a skip, but doesn't build it.
- An "Open all" button (not in the game today; TCG Cardshop has one).
- Card sleeves on shelves (they keep today's packets), the Frontier world reveal (`FrontierRevealController`), the
  binder and card view, the carried-box look.

## Anti-goals (would be a failure even if it works)

- **Looks copied from TCG Cardshop.** Same feel, our own design.
- **Commons get slow.** The user's first fix was "snappier/faster". A pack of Commons must still be quick: no tease,
  short flips, the cinematic only on the tear and on the big pulls.
- **Confetti that reads like an emoji.** No flat coloured rectangles anywhere in the celebration.
- **The card back showing through a revealed face** (the preview hit this: the back's star showed through the
  Legendary). A revealed card shows its face only.
- **A slideshow on phones.** If the stage drops frames on a phone, the effects get cut down, not the motion.
- **Shelves that lag a full shop.** A Big Display Rack holds 96 packs; ten shelves must not mean thousands of
  detailed meshes.

## Constraints (from CLAUDE.md and the codebase)

- Server authoritative; pack rolls stay on the server. The remotes stay as they are: `RipPack` (client → server),
  `PackOpened` (server → client: productId, results with cardId / foil / grade, newFlags), `PullRevealed` (client →
  server, a big pull was flipped, for the announcement). Rip cooldown `Packs.RIP_COOLDOWN` unchanged.
- All tunable numbers in `src/shared/Config` (the opening's timings, sizes, effect counts; the display box and case
  layout). Pure rules in Roblox-free `src/shared/Util` modules with Lune tests.
- UI rules: mobile-first, 48 px tap targets, FredokaOne / Nunito Bold, plain ASCII plus `·` and emoji in text, UIKit
  for any GUI, HUD through `Util/Hud`.
- Placement: the cases keep their grid footprint (`Shelves` size 6 x 4 x 2), so saved shop layouts still fit.
- Assets: images uploaded to Roblox are capped at 1024 x 1024, so a flipbook sheet is at most 1024 px (an 8 x 8 sheet
  has 128 px frames, a 4 x 4 sheet 256 px frames). Roblox particle flipbooks are 2 x 2, 4 x 4 or 8 x 8.
- Studio MCP: reading the place is fine; ask before changing the place itself. Scripts live in the repo.
- Blender: delete raw source objects and purge orphans before saving a .blend to git; check `blendermcp_*key*` /
  `*secret*` scene fields are empty before committing one.

## 1. The 3D pack model

Built in Blender by script (the preview's `build_pack.py`, to move into `tools/blender/`), so it can be rebuilt and
reused for every pack type:

- **Shape:** a puffy foil pouch (about 0.64 x 1 in Blender units; scaled in Roblox to the game's pack size). It bulges
  in the middle and flattens to the sides (folded edges). Ridged **crimp seals** top and bottom (about 7% of the
  height each) with a zig-zag outer edge. Soft foil wrinkles over the bulge.
- **Two pieces:** the **body** and the **tear strip** (the top seal plus a thin band, cut along a jagged line just
  under the seal, about 10% down). After the strip comes off, the body is open at the top: the inside is plain silver
  foil (it shows where the cards come out).
- **Texture** (made by script from the pack art, the preview's `make_texture.py`): front = the pack's art (the sky
  cropped so the creature fills it), the pack's logo in Fredoka ("FIRST / SPARK"), a "BOOSTER PACK" ribbon, a
  "5 CARDS" badge, a thin gold frame, tear notches at the strip line, silver ridged crimps. Back = a seam down the
  middle, the set's emblem, the set name, "5 random cards inside" and the five rarity gems. One mesh for every pack;
  each pack type is its own look: scripts can't swap a `SurfaceAppearance`'s maps, so the model file holds one
  `SurfaceAppearance` per pack type and the game picks it (builder's call, from the check).
- **Material:** foil: glossy, metallic on the seals, a little metallic on the art (Roblox: `SurfaceAppearance` with
  colour, metalness and roughness maps baked from the Blender material).
- **Two levels of detail:** a detailed mesh (a few thousand triangles) for the opening stage and the Set Price
  window, and a low one (a few hundred) for packs in shelf display boxes.
- **The Deck Box** gets the same treatment: a real 3D box with its lid as a separate piece, the set art on the front,
  the gold lid band (today's look, in 3D).
- The import follows the creature workflow: Claude builds and exports the FBX from Blender; the user imports it in
  Studio; the models are saved as `.rbxm` in a synced folder (new: `assets/packs` → `ReplicatedStorage.PackModels`,
  one model per pack kind: Pack, DeckBox; same script test as other models).

## 2. Shelves: packs in display boxes (A)

- Every stock slot of a pack product (today: up to 12 slots, `Town.SHELF_STOCK`, 3 levels of 4) shows **an open
  cardboard display box**: cardboard tray, the front panel printed with the pack art and "FIRST SPARK · 24", the lid
  flipped up and back showing the pack art. Inside, packs stand upright in a row, leaning a little, the low-detail
  3D pack.
- **It empties as stock sells:** the box shows as many packs as its share of the shelf's stock; a slot with nothing
  left has no box (so a running-low shelf is visible from across the shop). *(My call: an empty slot's box goes away
  rather than staying empty.)*
- Price tags stay where they are (the yellow tag on the shelf edge under the row's first box; still clickable for Set
  Price on your own shelves).
- Deck boxes: the new 3D deck box, two per slot front to back as today (`DECKS.PER_STACK = 2`; two high doesn't fit
  under the racks' upper levels).
- The sealed First Spark Booster Box product may use the display box model closed (lid down). *(My call: nice to
  have, only if it's nearly free.)*
- Budget: a display box with its packs should cost about one draw of a few hundred triangles (merge the packs into
  the box mesh in fill steps, or reuse a handful of low packs), so a full Big Display Rack stays cheap.

## 3. Glass cases: spinning cards (B)

- Both case kinds (Glass Showcase, Collector Case) change. Each of the 6 cards stands **upright, floating** over its
  slot, slowly spinning round its vertical axis (front, edge, the card back, edge, front), bobbing a little. A soft
  light beam in its **rarity colour** rises from a glowing pad under it. The price stays readable under the card.
- **Layout inside the existing 6 x 4 x 2 footprint:** 6 spinning cards need room not to touch: two rows of 3 a stud
  apart front to back, the back row raised so it shows over the front, the cards at 0.8 of today's size (a staggered
  back row doesn't fit the 6-stud width; found while planning).
- **The case itself:** taller glass on a dark base with a light strip along its top edge (the Glow Arcade look), in
  each kind's colours (Collector Case: navy and gold, as today's `propColors`). Code-built like the other shelves, or a
  new prop model; footprint unchanged.
- The spin is client-only (each player's client turns its own copy), so nothing extra replicates. The card faces stay
  `CardFace` on a SurfaceGui, the back the card back; the rarity halo, sparkles and the supreme Grade S lightning
  (`Config/CardEffects`) carry over to the upright card.
- Buying keeps working as today: the Collector Case's buy prompt (E within `BUY_PROMPT_DISTANCE`), the customer
  browse of the Glass Showcase, the owner's display/remove/price flow, the browse panel.

## 4. The 3D pack opening

The same flow and timings as `rip-preview-v1.html` (approved), built as a 3D stage: client-only parts at a far-off
stage position with a Scriptable camera, as the binder and the card view do (reuse their show/hide pattern: save and
restore the camera, hide world tags, keep the listener at the character). Card faces are `CardFace` on SurfaceGuis;
the pack and deck box are the new models; effects are particles, beams and the camera's post effects.

### 4.1 Before the tear
- Opened as today: carrying a box of packs, the Rip tile (T). The server rolls; `PackOpened` arrives; the stage opens.
- The pack floats in the middle of a dark violet backdrop with a soft glow, swaying slowly; a foil sheen sweeps over
  it every couple of seconds. Hint: "Swipe across the top to open" (tap, Space or T also tears).

### 4.2 The tear (cinematic)
1. Black letterbox bars slide in (top and bottom, about 11% each); the camera pushes in on the tear line (about 1.28x,
   0.5 s).
2. A light sweep runs over the foil; the strip starts to part slowly (0.7 s) while **light leaks out of the tear**
   (a bright line along the cut), and a few foil shards spill.
3. **Snap:** the strip flies off (0.5 s), the **rip burst** goes off at the tear (tinted in the pack's colour), a white
   flash, a short camera shake, a spray of foil shards.
4. Bars slide out, the camera eases back (0.45 s).

### 4.3 The cards stack up
- The pack moves down; the cards shoot up out of its open top **one at a time**, each snapping onto a face-down stack
  in the middle with an overshoot and a tiny shake (about 0.19 s each). The best card goes in first, so it's revealed
  last. Then the empty pack drops away. Hint: "Tap to flip the first card".

### 4.4 Flipping each card
- Tap (or Space / T): the top card lifts and **flips** quickly with a small overshoot, landing bigger and a little
  higher (a Common: 0.08 s lift + 0.23 s flip). A shine sweeps across the face and a glint twinkles on its corner.
- **Rare and better tease first:** the face-down card glows in its rarity colour, rises, and shakes harder and harder;
  an aura grows behind it. The tease length follows `Config/CardReveal` (Rare 0.5 s ... Legendary 2 s; the preview's
  0.65 / 1.7 s were mockup numbers). Then a slower
  flip into a **rip burst in the rarity colour**, the banner ("RARE!", "LEGENDARY!"), rays and sparkles.
- **Legendary and Frontier** get the cinematic again: bars in, the stage dims, the camera eases in during the tease,
  then a flash, a shake and **gold foil shards** raining down. *(My call: Epic gets the bars and dim too, shorter;
  Very Rare stays with Rare's size of show.)*
- **Foil** adds a holo shimmer on the face and "FOIL" in front of the banner (as `RevealRules` does today), at least a
  short tease.
- A revealed card only ever shows its face: once it has turned past halfway, its back is hidden outright (not left to
  backface culling).
- `PullRevealed` fires on big pulls as today (the server-wide announcement).

### 4.5 The shown card is alive (Rare and better)
While a Rare-or-better card is shown, until the next tap:
- it floats and tilts slowly in 3D (like a holo card catching the light);
- a holo shimmer sweeps across its face, gold for Legendary (in the rarity colour otherwise);
- glints twinkle over and around it (Legendary about 7 a second in gold; Rare about 4 a second, blue);
- small motes rise past it, most behind, some in front;
- the aura behind it breathes, the rays turn slowly, the banner pulses.
All of it stops cleanly on the next tap.

### 4.6 Into the row, then the results
- The next tap zips the shown card into a **row along the bottom** (small cards, NEW ribbons on new ones) and shows the
  next card.
- After the last card: the row's cards **fly one by one to a lineup in the middle** (each flight 0.22 s, the next
  leaving 85 ms later, an arc with a little spin, snap into place). Each lands with a shine sweep and **sparkles round
  its edges** (Commons a few white ones, a Rare more in blue, the Legendary the most in gold plus a small gold burst and
  gold shards); NEW tags pop on. Rare-or-better cards glow in their colour.
- Then they float gently out of step and twinkle now and then; the pills pop in at the top (Your cards · NEW xN · the
  pack's value · Rarity guide, as today) and a green **Continue** at the bottom.
- The results lineup must fit a 667 x 375 landscape phone (and 568 x 320) below Roblox's top bar, like today's.

### 4.7 Deck boxes
- *(My call, the user didn't see this one:)* the deck box opens the same way with its own cinematic: the lid lifts off
  (instead of the tear), then the same stack, flips and results. Today a deck box shows all 5 at once; this gives it
  the same reveal as a pack.

### 4.8 Skipping and repeats
- Today's controls stay: tap, Space, T. Taps are ignored briefly during a big flip so a double tap can't skip it
  (`spotlight` in `CardReveal`).
- Opening several packs in a row from the carried box works as today ("N left in box"); each opening resets the stage.
- The flow should be one timeline the Fast Open pass can later jump to the end of.

## 5. The effects (Blender)

Made in Blender by script (the preview's `build_vfx.py`, to move into `tools/blender/`), rendered and packed into
flipbook sheets by script (`make_sheets.py`), uploaded as images (ids in Config). White light on black becomes white
with alpha, so one sheet can be tinted per rarity or pack (ParticleEmitter `Color`).

| Effect | What it is | Frames | Used for |
|---|---|---|---|
| Rip burst | core flash, 22 light streaks, two expanding shockwave rings, 46 sparks with motion blur | 64 (8 x 8) | the tear (pack colour), Rare+ flips (rarity colour), the Legendary's landing in the results |
| Foil shards (holo, gold) | one irregular foil shard tumbling a full turn, iridescent or gold | 16 (4 x 4) | the tear's spray, the Legendary's gold rain, landing sparkle (replaces confetti) |
| Glint | a four-point twinkle that flares and fades | 16 (4 x 4) | flips, sparkles round cards, the alive card |
| Motes | small soft dots (a plain round particle) | - | rising past the alive card |

Plus, in Roblox: rays (a turning ray image behind the card), the aura (a soft glow image), the light leak (a bright
beam along the tear), letterbox bars (a ScreenGui), flash (a ScreenGui), and the camera's post effects for the
cinematic (bloom, a colour/brightness dip for the dim, depth of field during the push-in), parented to the camera so
only that player sees them.

Today's `CardReveal` tiers keep driving how big each pull's show is; `confetti` becomes **shards** (count and gold or
holo), and the tiers gain what the new show needs (cinematic on/off, burst size and tint, the alive card's glint and
mote rates). `RevealRules.plan` stays the one place that turns rarity / foil / Frontier into a plan (Lune-tested).

## 5b. Sounds

The opening is silent today (every sound id in `Config/PackOpening` is empty). The user chose to add sounds in this
project (2026-10-29): free Creator Store sounds, picked the way the binder's page turn was (`BinderDesk.TURN_SOUND_ID`),
ids in Config, preloaded when the stage first opens. Moments:
- the tear: a foil crinkle while the strip parts, a snap when it flies off;
- the cards stacking up: a short card snap per card;
- each flip: a quick card flick; Rare and better: a rising tease and a hit in the reveal (bigger for Epic, biggest for
  Legendary and Frontier, with a short shimmer while the card is alive);
- the results: a soft pop per card landing, then a chime when the lineup is complete.
Volumes in Config; the user judges them in Studio and on the iPhone.

## 6. Phones and performance

- Budget as the binder: Studio at graphics level 1, worst frame under 50 ms during the tear, a big flip and the
  results; then the user's iPhone 16 Pro Max for feel.
- Build each card face once, before it's needed (the binder's lesson: building `CardFace` faces costs a lot; moving
  built ones is cheap). There are only 5 per pack: build them during the tear's cinematic.
- Particle counts are config numbers; on low graphics quality the counts and the post effects can be cut down. The
  motion and timings never change.
- Shelves and cases: the display box budget above; the case spin runs only for cases near the camera (like the
  Condenser's 80-stud effect range).

## 7. Assets and where they live

- `tools/blender/build_pack.py`, `build_vfx.py`, `make_pack_texture.py`, `make_flipbook_sheets.py` (from the preview,
  cleaned up). Blender sources in `assets/blender/Pack/` (.blend, .fbx, textures; not synced).
- Pack textures in `assets/ui/packs` (ids in `Config/Packs`); flipbook sheets in a new `assets/ui/fx` (ids in a new
  config, e.g. `Config/PackFx`). Not synced by Rojo; uploaded as images.
- 3D models in `assets/packs` (synced to `ReplicatedStorage.PackModels`).
- The font for the pack texture (Fredoka, OFL) is only used by the texture script; the texture is what ships.

## 8. What already exists and stays

- `PackService`, the remotes, odds, pity, NEW flags (`Util/NewPulls`), the announcements, the rarity guide pill, the
  odds text, "N left in box", the Rip tile in the HUD.
- `Config/CardReveal` + `Util/RevealRules` (extended, not replaced).
- `Util/ShelfStock` / `ShelfLayout` / `ShelfLooks` decide where stock stands; the display box replaces the pack
  stack's look, not the slot logic. `Config/Showcase` keeps the prices, cooldowns and distances; its layout numbers
  change for the upright cards.
- `PackOpeningController` (1,500 lines) and `Util/PackStage` are replaced by the 3D stage. Split it so no file passes
  the 200-locals limit (Lessons learned): e.g. a stage module (scene, camera, bars), a reveal module (stack, flips,
  alive card), a results module, and the controller wiring input and remotes.

## Left to the builder

- Exact sizes in studs, camera distances, colours beyond the ones named here, easing curves (the preview's are the
  reference: a snappy overshoot for landings, ease-out for flights).
- How the display box merges its packs (fill-step meshes or a few parts) as long as the budget holds.
- Rays and aura as images on a part or as beams.
- Whether the case is code-built or a prop model.

## My calls (approved with the doc)

1. An empty display box slot shows no box (instead of an empty box).
2. The sealed Booster Box product may use the closed display box.
3. Epic gets a shorter cinematic (bars and dim); Very Rare stays at Rare's size.
4. Deck boxes get the same stack-and-flip reveal (lid lifts instead of a tear), replacing "all 5 at once".
5. The Set Price window shows the 3D pack (for pack products).
6. ~~No new sounds~~: the user chose to add sounds now (section 5b).
