# Card Shop Tycoon — Game Design Doc

> Working title. Roblox game inspired by TCG card shop simulators.
> This doc is the source of truth for scope, systems, numbers and code structure.
> If something in code disagrees with this doc, either fix the code or update the doc. Don't let them drift.

---

## 1. The pitch

You run a trading card shop. Order stock, fill your shelves, set prices, ring up customers, and grow a tiny corner store into the biggest card shop on the server. Between customers, rip packs yourself to chase legendary pulls, show off your best cards in display cases, and sell singles to other players.

**Audience:** Roblox core (mostly 9–16), mobile-first, but the shop management angle also pulls older players.

**Design pillars**

1. **Satisfying routine.** Restocking, scanning, and counting cash should feel good, like the Steam shop sims.
2. **The pull.** Pack opening is the dopamine hit. It needs to look and sound amazing, even at low rarities.
3. **Show it off.** Your shop and your cards are visible to everyone on the server. Status drives spending.
4. **Short sessions work.** A 5-minute session on mobile should still feel like progress.

---

## 2. Core loop

```
Order stock (computer) → Restock shelves → Set prices
        ↑                                      ↓
 Buy upgrades / expand  ←  Earn cash  ←  Customers buy & check out
        ↑
 Open packs yourself → pull rares → display / sell singles / keep in binder
```

**Moment to moment:** walk around your shop, carry boxes from the delivery spot to shelves, scan items at the register, open a pack while waiting for the next customer.

**Session goal:** hit the next shop level / afford the next upgrade.

**Long term:** max out your shop, complete the card set binder, own the rarest cards on the server.

---

## 3. World layout

- One server = **6 shop plots** around a central street/plaza.
- Players spawn in the plaza, claim a free plot (or auto-assign on join).
- Plaza has: leaderboard (richest shops), a "featured shop" sign, later a tournament hall.
- Plots are fixed size but have **expansion zones** that unlock (walls move back / second room opens).
- Other players can walk into your shop and see your shelves and display cases.

**Main town (world pass 1; spec `2026-10-25-main-town-design.md`; done).** A cozy stylized
village (Inno's Stylized Asset Pack outdoors). Grass ground (the Baseplate is recoloured), a charcoal asphalt street
between the two rows (x -110..110, 96 wide: shop fronts at z ±48) with a zebra crossing in front of every shop door, a pale
concrete sidewalk (8 wide, square 4-stud slabs) along each row's front, a round pale limestone plaza (radius 26, open room for
event NPCs and event stalls) with two glowing blue rings set in it (the healing area's edge at 12 and one near the rim), a
glowing line on the street from the plaza to each portal in that portal's colour (`Town.FLOOR`, `TownLayout.crosswalks` /
`portalPaths`) round the healing spring (the HealingSpring prop slot, 14 tall: the free "Better Low Poly Fountain" by scene_boy,
recoloured moonstone with glowing water, kept in the place's `PlaceProps` (copy: `assets/place-props/HealingSpring.rbxm`);
the code adds a big turning, bobbing gem over its top, rising sparkles, a blue light, breathing water and a faint
disc for the 12-stud healing area; a part-built stand-in is used if the model is missing). Around it, `Workspace.PlazaGarden` (hand-placed in the
place, like TownDecor): 4 cherry trees between the benches (street and shop lanes left open), glowing spotted
mushrooms at the basin, a ring of flowers and bushes, four round grass lawns with clover tufts (one per quarter)
and a low wooden fence round the plaza edge (radius 21, 2 tall) with gaps at the four lanes; Creator Store pieces were stripped to parts, meshes, lights and
particles (the cherry trees came with backdoor scripts). Butterflies (`ButterflyController`, client only,
`Town.BUTTERFLIES`) flutter in loops round the spring, warm afternoon lighting
with light haze, soft bloom and low wall shine (`Town.LIGHTING`; dim warm shop ceiling lights so pale walls never wash out). Portals: the Wild (104, -9) and the Frontier (104, 9) side by side at the east end of the street,
the PvP Arena (-104, 0) at the west end, each with a floating name label and its own look (`Town.PORTAL_EFFECTS`): the Wild green
with rising sparkles, the Frontier icy blue with drifting snow and an aurora shimmer, the Arena red with flying
embers; ring and frame glow tinted to match, a soft glow light, 2 emitters per portal. Plots stand 24 studs apart. The town is
the whole main-game world: the Baseplate is cut to x ±130, z ±110 and ringed with invisible walls (`Town.BOUNDS`). Code builds the fixed pieces (`Util/TownLayout`, same on every
server): modern black LED street lights (StreetLight slot, 11 tall, arm over the street) on the sidewalks at every plot gap
and row end, 4 benches round the spring, a trimmed hedge on a concrete curb (Hedge slot) round the whole island just
inside its edge, a frame at each portal. Nothing lands inside a plot, in the street (except street lights, portals
and the plaza), within 10 studs of a portal, or in the spring area (except benches). The scenery (trees, flowers,
rocks, and a modern planter each side of every plot gap) is hand-placed in Studio and saved as `assets/town/TownDecor.rbxm` → `Workspace.TownDecor`
(docs/props.md). **Shops:** one modern look for every shop (`Town.SHOP`, built in code by PlotService): smooth white
walls outside the floor (18 tall) with a charcoal band along their foot; a glass shop front 12 studs tall with thin black
frames, three panes each side and a transom; automatic sliding glass doors in the middle (12 wide, 10 tall) that part
when any player or customer comes within 9 studs, and never collide so paths are never blocked (the panes beside them
are the solid wall); a charcoal sign band above the glass carrying the shop sign, with a glowing strip in the shop's
accent colour under it; a slim flat canopy over the doors with three down-lights; a planter each side of the doorway;
a flat roof with a slim charcoal parapet (the camera stays under it inside); inside, a light oak floor (grey while for
rent), a warm greige back feature wall (the same in every shop) and 3 x 3 LED ceiling panels. Each plot has a fixed
accent for the glowing strip under its sign (Mint, Coral, Violet, Gold, Azure, Rose). The checkout counter (6 x 2.5 x 2, low so small cashier pets show) is built in code to match the
shell (`Town.COUNTER`): a white body on a charcoal plinth, a dark quartz top overhanging the customers' side, a thin
LED strip in the shop's accent colour under it, and two black pendant lights with warm bulbs hanging from the
ceiling over it (shade bottoms 7.5 up, clear of the cashier). A POS terminal (Terminal slot: a tablet on a stand,
its screen toward the cashier, a card reader on the customers' side) stands at its left end and a
counter decor prop on its back edge (scan items lie along the front edge to the right of the register); Shelves with a `prop` in Config/Shelves draw it on an invisible hitbox part. The four product shelves are
code-built modern shelving in one style (`Util/ShelfLayout` places the parts so every plate sits under a stock level,
`Util/ShelfLooks` draws them, `Town.SHELF_LOOK`; no lights of their own): charcoal posts and base, light grey plates with
dark price rails, an oak slat back and a charcoal header sign ("TRADING CARDS", "ACCESSORIES"). Small Pack Rack → Shelf
(one-sided gondola), Wall Shelf → WallShelf (the same, wider and taller), Accessory Hook → HookRack (a grey pegboard with
chrome wire shelves and a row of hooks over each level), Big Display Rack → DisplayRack (double-sided: plates through an
oak middle divider, a price rail and header text on both faces). Glass Showcase →
Showcase (a glass counter; its cards lie on the velvet bed), Collector Case → the same counter recoloured
(`propColors`: navy base, gold trim, royal blue bed), Condenser → Condenser (code-built, `Town.CONDENSER_LOOK`: a charcoal
plinth with a glowing violet ring, a "✨ CONDENSER" screen and a card slot, a glass chamber in which a violet crystal
ringed by three gold cards spins and bobs (`CondenserFxController`, each client, within 80 studs), charcoal side pillars
with light strips and a cap; no lights). The delivery spot is outside on the sidewalk, left of the doors (`Town.DELIVERY`, built in code): a
concrete platform level with the shop floor, a charcoal mat with a yellow safety border, "📦 DELIVERIES" on its street
face and two black bollards with yellow bands at its street corners; boxes stand on the mat, and stocker pets fetch
them from its doorway side. Delivery boxes show their
product: a band in the product's colour with its name (or a per-product box model, Products `boxProp`). Products shelves and up to 12 stock boxes in
the product's colour (3 levels of 4, filling from the bottom; any stock shows at least one; `Util/ShelfStock`,
`Town.SHELF_STOCK`, `Products.color`). A shelf whose model isn't a one-sided rack sets its own levels and sides (`Shelves` `stock`): the
Big Display Rack is double-sided, filling each level front then back, with its back rows, packs and tags facing
the back aisle. Packs (products with `Packs` art) show as stacks of 5 thin upright packs
with the pack art, leaning back, instead of boxes. Card Sleeves (Products `stockLook = "Sleeves"`) show as 2 retail
sleeve packets per slot, leaning back: a white backing card with a header tab and hang hole, the sleeves behind a clear
window and a strip in the product's blue; each slot takes the next colour of `SHELF_STOCK.SLEEVES.COLORS`, so a shelf
reads as an assortment. Each stocked row has a yellow price tag with the
product's price on its outer edge, under the row's first stack (so always next to stock on display). On your own shelves the tags are buttons (`PriceTagController`): point at one
(within 24 studs) and it lights up with a "Set Price" tooltip by the cursor; click or tap it for a small Set Price window with
that product's +/- row (the same price as the Prices panel; the server sets the shelf's `ProductId` attribute). **Props:** every
decoration is a slot; `assets/props/<Slot>.rbxm` and its variants (`TreeA`, `FlowerBlue` ...) replace the
code-built stand-ins (docs/props.md). Numbers: `Config/Town`.

**Placement ghost (build mode):** a see-through copy of the real model (the shelf's `prop`, or the desk), tinted
green or red with an outline, gliding between grid cells; its footprint cells drawn on the floor, a chevron at its
front, a label above it ("Wall Shelf · $350", "Move Collector Case", "Can't place here"). Buttons Rotate (R), Place
(Click; greyed while blocked), Cancel (Q). Shop prompts are hidden while placing. Numbers: `Config/Placement`.
Shelves, cases and fixtures carry no floating labels: on your own shop, pointing at one (or tapping it) gives it a
soft white outline and a tooltip by the cursor with its product and stock ("First Spark Booster Pack · 24/96"), a
case's kind and count, "✨ Card Condenser", "📦 Order Stock" or "💰 Register"
(`ShelfInfoController`, within 30 studs; the server sets the part's `Info` attribute), and an empty product shelf shows a red "📦 Empty" badge over it
(the `Empty` attribute, out past the shelf's front so walls never cut it) so it can be spotted across the shop.
Visitors see neither (`Placement.SHELF_INFO`). World hovers and taps are off while a window is open or the pointer
is over UI (`UIKit.pointerBlocked`).

---

## 4. Shop systems

### 4.1 Plots
- Claim on join. Release on leave. Shop layout loads from saved data.
- Plot owner name + shop name shown on a sign out front. Shop name is player-chosen (filtered with TextService).

### 4.2 Ordering stock
- Computer in the back room opens the **Order UI** (catalog of products unlocked so far). It is a modern workstation
  built in code (Computer slot, `built`): a white desk on black panel legs, a slim widescreen showing "ORDER STOCK",
  keyboard, mouse, a small plant, a drawer unit and an office chair.
- Ordering costs cash immediately. Delivery arrives after a short delay (10s at start, upgradable) as boxes at the delivery spot.
- Player picks up a box (carry it, one at a time at start) and places it on a shelf to stock it.

### 4.3 Shelves & placement
- Shelves are placed in the shop on a **grid** (placement mode: rotate, move, sell back for 50%).
- Each product shelf holds a set number of product units; card cases hold single cards (see 5.6).
- Customers can only buy what's on shelves. Empty shelves = lost sales.
- **Remove stock** (shelf Edit menu): boxes a product shelf's stock back onto the delivery pad, as many boxes as
  the pad has room for.

| Shelf | Capacity | Cost | Unlock |
|---|---|---|---|
| Small Pack Rack | 24 packs | $100 | Start |
| Glass Showcase | 6 single cards, NPC customers buy | $250 | Start |
| Collector Case | 6 single cards, other players buy | $300 | Start |
| Card Condenser | machine: combine duplicates for +1 star (5.8) | $500 | Shop Lv 4 |
| Grading Station | machine: duplicates and cash for +1 grade (5.9) | $5,000 | Shop Lv 8 |
| Wall Shelf | 48 packs | $350 | Shop Lv 3 |
| Accessory Hook | 20 accessories | $250 | Shop Lv 5 |
| Big Display Rack | 96 packs | $1,200 | Shop Lv 6 |

### 4.4 Pricing
- Each product has a **market price** (shown in UI). Player sets their sell price per product type.
- Customer willingness to buy depends on price vs market:
  - ≤ market: almost always buys
  - up to +20%: sometimes buys
  - +20% to +50%: rarely
  - > +50%: never, and leaves a little annoyed (shows a 😠 bubble)
- Sweet spot is slightly above market. This is the "skill" part of the sim.

### 4.5 Customers (NPCs)
- Spawn from the street, walk in using PathfindingService.
- Each customer has a small shopping list (1–3 items), browses shelves, picks items, joins the register queue.
- They only browse what they can buy: stocked product shelves and Glass Showcases with cards (never Collector
  Cases or the Card Condenser). If something on their list isn't stocked, they check up to 2 more shelves
  (`SEARCH_SHELVES`) before showing the "no stock" bubble. In the queue they face the register.
- If they wait too long in the queue they leave (no sale).
- Customer spawn rate scales with **shop rating** (cleanliness of stock, price fairness, decor score).
- Keep NPC count capped per plot (start 4 max at once) for performance. Use simple rigs, no fancy animations at first.

### 4.6 Register / checkout
- Player stands at register, customer puts items on counter, player clicks/taps each item to scan, then confirms payment.
- Payment: cash (make change, later feature) or card (instant). MVP = one tap to confirm total.
- Later: hire a cashier to automate.

### 4.7 Shop level & rating
- **Shop XP** from every sale. Levels unlock new products, shelves, expansions.
- **Shop rating** (1–5 stars) affects customer flow. Factors: % shelves stocked, prices vs market, decor points.

---

## 5. Cards & packs

### 5.1 The card game (lore/IP)
Original IP, no real-world TCGs. Working name: **Glimmerbeasts**.

Five elements, each with its own color and frame:

| Element | Color | Vibe |
|---|---|---|
| Ember | Orange/red | fiery, aggressive |
| Tide | Blue | calm, tricky |
| Bloom | Green | cute, nature |
| Volt | Yellow | fast, chaotic |
| Shade | Purple | spooky, rare-feeling |

### 5.2 Rarities

| Rarity | Frame | Market value range |
|---|---|---|
| Common | Grey | $0.10 – $0.50 |
| Rare | Blue | $1 – $3 |
| Very Rare | Cyan | $3 – $6 |
| Epic | Purple | $5 – $20 |
| Legendary | Gold, animated | $40 – $150 |

**Foil variant:** any card can roll foil (holo shimmer UI effect). Foil = 3x value. Chance: 4% per card.

### 5.3 Pack contents & odds (Set 1 Base Pack)
Each pack = 5 cards:
- Slots 1–3: Common
- Slot 4: Common 70% / Rare 30%
- Slot 5 ("hit slot"): Rare 70% / Very Rare 15% / Epic 14% / Legendary 1%

The Deck Box's hit slot: Rare 52% / Very Rare 25% / Epic 22% / Legendary 1%. Slot odds and pity live in
`Config/PackOdds` (plain data, so the Lune tests and the economy simulator use the real numbers).

**Pity** (bad-luck protection, `PackOdds.PITY`, `Util/PityRules`, Lune-tested): counted per player over every pack
and Deck Box they open (saved, `data.pity`). A player's first Legendary is guaranteed within 130 packs (a quick hook),
every later one within 210: the last pack of the run has a Legendary in its hit slot. Saves from before this that
already own a Legendary start on 210. The 40th pack without an Epic or better has an Epic. A pity Legendary guarantees the card, not a good copy: its grade rolls
C 80% / B 18% / A 1.8% / S 0.2% (a lucky pull's Legendary is S 1%). The pack screen shows "Legendary in N packs ·
Epic in M" (player attributes PityLegendary / PityEpic); the odds panel and the rarity guide explain it.

**Odds are always visible in-game** (pack info button). Required by Roblox for any paid random items, and we show them for everything anyway.

### 5.4 Set 1 — "First Spark" (35 cards)
15 Common, 9 Rare, 5 Very Rare, 4 Epic, 2 Legendary. Placeholder names, art TBD.

| # | Name | Element | Rarity |
|---|---|---|---|
| 1 | Cindercub | Ember | Common |
| 2 | Puffpuddle | Tide | Common |
| 3 | Sprouthop | Bloom | Common |
| 4 | Zappit | Volt | Common |
| 5 | Gloomlet | Shade | Common |
| 6 | Ashbeak | Ember | Common |
| 7 | Shellshy | Tide | Common |
| 8 | Mossmole | Bloom | Common |
| 9 | Fizzlebug | Volt | Common |
| 10 | Wispurr | Shade | Common |
| 11 | Coalbit | Ember | Common |
| 12 | Driplet | Tide | Common |
| 13 | Petalpaw | Bloom | Common |
| 14 | Sparkrat | Volt | Common |
| 15 | Hushmoth | Shade | Common |
| 16 | Blazehound | Ember | Rare |
| 17 | Reefray | Tide | Rare |
| 18 | Thornback | Bloom | Rare |
| 19 | Boltlynx | Volt | Rare |
| 20 | Nightowl | Shade | Rare |
| 21 | Magmaw | Ember | Rare |
| 22 | Mistfin | Tide | Rare |
| 23 | Vinewyrm | Bloom | Rare |
| 24 | Stormjack | Volt | Rare |
| 25 | Infernox | Ember | Epic |
| 26 | Abyssal Koi | Tide | Epic |
| 27 | Thunderhorn | Volt | Epic |
| 28 | Eclipse Fox | Shade | Epic |
| 29 | Solarion | Ember | Legendary |
| 30 | Voidmaw | Shade | Legendary |
| 31 | Emberwing | Ember | Very Rare |
| 32 | Tidecaller | Tide | Very Rare |
| 33 | Briarhorn | Bloom | Very Rare |
| 34 | Voltkit | Volt | Very Rare |
| 35 | Duskstalker | Shade | Very Rare |

### 5.5 Card art plan
- MVP: simple flat creature art, consistent style. Rarity frames + foil shimmer (UIGradient animation) do a lot of the heavy lifting.
- All art must be original and uploaded as decals/images to Roblox.
- Summoned creatures use free or bought Creator Store models as stand-ins for now, with a placeholder blob for
  cards without one. Each client draws only your own creatures plus the nearest 30 others within 140 studs (kept
  until 170, `Party.CULL`, `Util/CreatureCull`); the rest stay invisible server markers, so a full server stays light
  on phones. Most cards use the bought Ultra Detailed pack (`Party.CREATURE_MODELS`: a pack model per card,
  a few shared ones tinted to their element); two Legendaries use the bought Crystal Titans pack with its own walk,
  run and idle animations (Stormking is now an original storm titan beetle and Tideborne Kirin (was Aurora Drake) an original celestial kirin;
  `Util/KeyframePlayer` plays the saved animations on each client). Original Blender models are replacing
  them card by card (`Originals` pack, `tools/blender/`, docs/creatures.md): Boltlynx (cartoon electric lynx, generated with Meshy), Cindercub (fire bear cub, Meshy), Zappit (lavender electric bunny, Meshy), Mossmole (forest mole with a mushroom garden, Meshy), Petalpaw (flower squirrel, Meshy), Gloomlet (flying shadow bat, Meshy), Ashbeak (ember chick, Meshy), Shellshy (shy baby sea turtle, Meshy), Fizzlebug (flying electric bee, Meshy), Wispurr (ghost kitten, Meshy), Emberwing (flying fire swallow, Meshy), Tidecaller (sea dragon, Meshy), Briarhorn (thorn-vined forest bull, Meshy), Abyssal Koi (swimming abyss fish, Meshy), Thunderhorn (gold-armoured thunder stag, Meshy), Riftwalker (void dragon, Meshy), Cinder Titan (volcano gorilla, Meshy), Voidmaw
  (cosmic void dragon, Meshy), Solarion (sun fire god titan, Meshy),
  Sprouthop (tree sprite), Stormjack (storm ram, Meshy), Infernox (T-rex), Puffpuddle (sea otter on all fours),
  Blazehound (flame dachshund), Thornback (thorn boar, Meshy), Duskstalker (shadow wolf, Meshy), Eclipse Fox
  (shadow kitsune, Meshy, three tails built in code) and Voltkit (storm pangolin, Meshy),
  each with its own signature idle; the more common the card, the cuter the creature. The Legendaries stand 2.2x their rarity size (about 9
  studs), follow further out to match, burn with their element (`Util/BeastAura`, `Config/BeastFx`: fire on bones
  spread over the body, lightning arcing between them, ground flames, a flickering light; Ember orange fire, Shade
  purple-black fire, Tide blue spirit fire, Volt white fire with constant lightning), kick up dust as they move (grade S and A copies of other cards get a lighter aura,
  `BeastFx.TIERS`: S fire on 6 bones with now-and-then lightning, A a faint flame on 4 and a soft glow; grade S
  Legendaries get more, tier Divine: fire on 11 bones, more lightning, a turning ring of flames behind the head,
  three small suns circling it and burning embers where it walks, `BeastFx.DIVINE`; for Shade, black holes and dark
  smoking rifts instead; Epics stand
  1.5x, `Party.SIZE_BY_RARITY`), and between their idle, now and then roar (rear back, lunge, an element-coloured
  shockwave ring and sparks) or stomp (a dust ring). The pets' bones are animated in code on
  each client (`Util/PetRig`, `Util/PetAnimator`, `Party.PET_ANIM`): trotting or stepping, breathing, tail wags,
  ear flops, hip sways for tails without bones, and idle fidgets (look around, tilt, sniff, stretch, happy wag,
  hop, spin, shake, sit, scratch, yawn); the Ultra pack's bones have generic names, so `Util/RigGuess` works out
  pelvis, spine, neck, head, tail, legs (front and hind) with their IK feet, arms and ears from where they sit
  (arms hang and swing, feet step with the legs); the winged ones (`Party.WINGS`: bat, moth, wasp, swallow, stone
  bird, heron) fly and beat their wings; fish swim afloat and the snake slithers (`Party.UNDULATE`); the otter
  and creatures without bones hop, spin, shake, look round and bounce. How to
  add, size and animate them:
  `docs/creatures.md`.

### 5.6 What you do with pulled cards
- **Binder:** collection book UI, shows owned/missing, completion % (cards on display count as owned).
- **Glass Showcase:** put singles on display for NPC customers. Some customers (about 30%) look at it; whether they
  take a card depends on your price vs its market value, using the same bands as packs (4.4). They pay at the register.
  If they give up in the queue, the card goes back in the case.
- **Collector Case:** singles for other players only. Visitors press E on a card, confirm the price, and buy;
  cash goes to the owner, the card to the buyer's binder. The server rejects the buy if the price changed after
  the buyer saw it.
- Card prices default to market value; +/- steps are 10% of market value, capped at 3× market.
- Cards on display leave the binder while shown and come back when removed. A case can't be sold while it holds cards.
- **No quick sell.** Cards only earn money by selling to customers or players, which keeps pulls tied to running the shop.
- **Trading (post-MVP):** player to player trade window.

### 5.7 Pack opening feel (important)
- A midnight stage (deep navy fading to near-black, a soft glow) with the illustrated pack floating in the middle (`Config/Packs`
  art, the logo and crimped edges drawn in code; art in `assets/ui/packs`, made with Figma's image generator). It
  feels premium (`Util/PackStage`, `PackOpening.AMBIENT`): long soft light rays in the pack's colour turn slowly
  behind it, bokeh sparkles drift up the screen, a glowing pedestal pulses under it and a soft vignette darkens the
  edges; all of it stops when the screen closes. The pack pops in, bobs, rocks a little either way and a foil shine
  sweeps across it every couple of seconds.
  "Swipe across the top to open": dragging over 80% of the pack's width tears the top off along the dashed line
  (a tap, Space or T tears it by itself). The pack slides away and the cards rise out as a stack.
- **Deck boxes** (`Config/Packs` entries with `kind = "Deck"`, opened the same way: carry a box of them, Open T):
  the First Spark Deck Box holds 5 cards, two of them Rare or better (Common, Common, Common/Rare 50/50, Rare 75 /
  Very Rare 25, and a hit slot of Rare 45 / Very Rare 25 / Epic 22 / Legendary 8, against a pack's 68/15/14/3), for
  $9 against a pack's $3. On the stage it is a boxier box (`PackOpening.DECK`) with a dark lid, a gold band and a
  side face, "DECK BOX · 5 CARDS"; tapping it (or Space / T) lifts the lid, the box slides away and every card
  shows at once in the results row, with the best pull's flash and confetti. On shelves deck boxes stand as little
  upright boxes in purple with the First Spark art and a gold lid (Products `stockLook = "Deck"`); menus show the
  Deck Box icon.
- Cards are revealed one at a time, big in the middle; a tap, Space, T or the round Next button slides the card off
  to the left and shows the next ("2 / 5 · Tap for the next card" at the bottom). After the last card comes the
  results screen: every card in a big row popping in, a yellow NEW ribbon on cards the player didn't own before
  (binder, beasts or on display; the server checks before adding them, `Util/NewPulls`, only the first copy in a
  pack), pills on top (Your cards · NEW x2 · pack value · Rarity guide, which opens over the results) and a
  green Continue. The screen matches the other windows: icons from `Config/UIIcons` (no emojis), rounded pills with
  thin edges, a translucent navy hint capsule, a round accent-blue Next button with a key chip, a soft white "N left
  in box" pill and a soft shadow under the pack. Odds sit in the top right (hidden on the results, whose row and pills span the screen). Laid out to fit a 667x375 landscape phone below Roblox's top bar; on smaller ones (568x320) the results pills shrink to the screen's width and the card row moves down just enough that the NEW ribbons clear them.
- Hit slot comes last. Every pull is celebrated by rarity (`Config/CardReveal`, `Util/RevealRules`):
  - **Tease** before the flip: the face-down card glows in its rarity colour, breathes and shakes, and the
    stage dims (Rare 0.5s · Very Rare 0.8s · Epic 1.2s · Legendary 2s; Commons come out face up at once).
  - **After the flip:** sparks burst out and a banner pops ("RARE!", "VERY RARE!"); the glow stays behind the card.
  - **Epic and Legendary** add turning light rays, confetti and a pop (taps are ignored 0.6s so a double tap can't
    skip it). Legendary adds a white screen flash. Frontier cards get the Legendary show ("FRONTIER!").
  - **Foil** adds sparks, at least a 0.6s tease and "FOIL" in front of the banner ("FOIL RARE!", a plain foil "FOIL!").
  - Big pulls still get the server-wide chat announcement ("Ben pulled a FOIL Solarion!").
- Card faces (`Util/CardFace`, `Config/CardDesign`), clean full-art style (like the top Roblox card games),
  built in code with no frame images: the art fills the card inside a thin rounded rim in the rarity colour
  (white Common, blue Rare, teal Very Rare, purple Epic, gold Legendary; a turning rainbow on foil, aurora on
  Frontier). Outlined text over soft dark bands: element emoji and name top left, a grade letter pill top right,
  the value (or a case's asking price, in gold) big at the bottom. Detailed faces (binder, packs, inspector,
  everywhere but shelves and small job/party tiles) add star slots under the name, a "Lv 3" chip under the grade
  and a FOIL / FRONTIER chip. Art: every card has its own painting (`ART_IMAGES`, by name): its creature model
  described and painted into its element's scene with Figma's image generator (prompts in `docs/card-art.md`,
  JPEGs in `assets/ui/card-art`). A card without one falls back to its element's painted scene (`SCENES`:
  fireplace, coral reef, forest, stormy peak, moonlit graveyard; `assets/ui/card-scenes`) with the element emoji
  on a glow, else an element gradient. Effects on the art: Epic and up a white shine now and then, foil and Frontier a holo
  sweep. Missing binder slots: grey rim, dark silhouette and "?". The face-down back is a deep blue card with
  🃏 CARD SHOP; glows use the "Glow Circle / Radial Glow" decal (public Creator Store image).
- Cards on display in Glass Showcases and Collector Cases use the same card face, drawn by each client on the
  server's plain card part (1.05 x 1.5 studs; glass counters lie them on the bed, rows 1.12 apart), with the asking
  price in gold in the value row. To make visitors want to buy, the face glows (it ignores the
  room's light), a neon halo in the rarity colour sits just behind it (pulsing on Epic and up), and rarer cards
  sparkle more (`Config/CardEffects` BY_RARITY: sparkles, halo). Displayed cards cast no light of their own
  (`DISPLAY_LIGHTS = false`: under the glass it lit the whole case up); Legendary auras keep their particles. Grade S copies
  glow brighter and sparkle more (GRADE_S). Grade S Legendaries and Grade S Frontier cards are "supreme": a solid
  pulsing halo, golden sparkles and blue-white lightning bolts crackling off the card's edges every 0.35-1.1s
  (SUPREME; no bolts while the camera is over 70 studs away). Their card face also gets a spinning gold rim round
  the art everywhere (binder, packs, cases; `Config/CardDesign` SUPREME_RIM).
- "Open all" button for fast opening once players have lots of packs.

### 5.8 Glimmerbeasts (cards that grow)
Direction: TCG card shop meets creature collecting. Cards become beasts that grow, work and fight.
Full spec: `docs/superpowers/specs/2026-10-20-beast-cards-design.md`.

Roadmap (one sub-project at a time):
1. **Beast cards** — level, XP, stars, grades, stats, value (done).
2. **Shop jobs** — cards work in your shop as Restocker or Cashier (spec `2026-10-21-shop-jobs-design.md`; done).
3. **Party & summoning** — 3 party cards, one summoned creature follows you and gives its element's perk
   (spec `2026-10-21-party-summoning-design.md`; done).
4. **Star merging** — the Card Condenser combines duplicates to raise stars (spec `2026-10-20-stars-condenser-design.md`; done).
5. **Battles** — real-time auto-battles, in three parts:
   1. Combat core + server wild map (spec `2026-10-22-battles-wild-design.md`; done).
   2. PvP challenges and the arena (spec `2026-10-23-battles-pvp-design.md`; done).
   3. a) The Frontier (spec `2026-10-24-frontier-design.md`; done).
      b) The boss ladder: 7 bosses (3 Wild, 3 Frontier, the final one in a Dungeon place), keys from the boss
         before, optional groups (spec `2026-10-28-boss-ladder-design.md`; phase 1, the Wild bosses, and phase 2, groups, done: 5.10).

**Battles part 3a: the Frontier.** A second Roblox place in the experience, shared by players from every server.
Not one server for everyone: Roblox fills a Frontier server to the place's Max Players (Creator Hub) and opens more.
The plaza's "The Frontier" portal opens a menu: Explore (any Frontier server) or Join a friend who is in one now.
A teleport is a leave (fights end, the save goes to the next server); your shop pauses and rebuilds from the save
when you come back. Open to everyone ("Recommended Lv 15+"). Same combat as the wild; zones Frostwood Lv 15–25
(Tide, Shade), Stormpeak 25–35 (Volt, Ember), The Rift 35–50 (all five, everything chases); elites 1 in 6; a healing
spring at the entrance and a Dungeon portal (coming soon). Frontier-only drops: Star Shards (3% normal / 10% elite)
and Frontier cards (3% / 10%; Frostfang, Gale Sprite, Riftwalker, Cinder Titan, Tideborne Kirin, Stormking, never in
packs). Frontier cards look special everywhere: an aurora border and rarity, a FRONTIER chip, a constant
shimmer, an aurora glow in shop cases, a mystery "?" slot ("Found in the Frontier") in the binder until owned; finding
an Epic or Legendary one plays a full-screen reveal and announces it to the server ("✨ Ben found a Frontier card: Stormking!").
Items: `items = { [itemId] = count }`, listed in `Config/Items` (name, icon, description, where to get, how to use)
and changed only by ItemService. The binder has two tabs, Cards and Bag (icon tabs; key I opens the Bag). The Bag
is an inventory window in the middle of the whole screen ("Bag", "1 / 20 slots" in its header): a 5x4 grid of slots (more rows if
needed), filled ones soft blue with the item icon and an "x2" badge, the rest empty; the chosen item's details on
the right (big icon, name, "You have 2", what it does, Where to get it / How to use it boxes). It scales down to
fit small screens; the book and its corner buttons hide behind it. The Cards tab (and the case card picker) has a Frontier filter and a progress bar per set (First Spark, Frontier). Star Shards in the Condenser ("Use Star Shards"): real duplicates first, shards cover the rest
up to half of a star's cost. One codebase, two places: `frontier.project.json` sets the Workspace attribute
`PlaceKind = "Frontier"` and both entry scripts start only that place's parts (`Util/Place`). Numbers:
`Config/Frontier`, `Config/Items`, `Config/Places` (place ids: main 75599593337434, Frontier 73033858769620).

**Battles part 2: PvP.** Walk up to another player (within 8 studs) and press C (Challenge): pick a bet (Friendly, or up to
min(both players' cash, $50 × the lower shop level), in $5 steps) and see both parties' Power. They have 15 s to
accept. Both bets are then held by the server and the match goes to the arena (one pad, far from the shops; others
queue first come, first served; leaving the queue refunds both). After a 3-2-1 countdown, full parties fight (cards resting from the wild sit
out), same combat rules as the wild, no call-in and no Run; you can roam your half of the pad. Winner takes both
bets; the 2-minute limit is a draw (both refunded); leaving or resetting mid-fight forfeits. No XP, drops or resting
from PvP. 10 s after the result both go home. Anyone can watch from the stands (plaza "Arena" portal, `/arena`);
creatures in a fight show floating HP bars. Wins-losses-draws are saved and shown in the Party panel. A declined
challenge blocks that pair for 30 s; 10 s cooldown between challenges. Numbers: `Config/Pvp.luau`; bet and record
rules in `Util/PvpRules` (Lune-tested). The fight engine (`BattleSim`) runs two sides of fighters: wild fights are
the party vs a one-monster side.

**Battles part 1: wild fights.** A portal at the end of the plaza street moves you to the wild map (same server, far
from the shops; your shop keeps selling). Press Fight near a monster, or get caught by one that chases you. Your
summoned creature fights (it must be rested); in the first 5 s you may call in one more party card (max 2 of yours
vs 1 monster). You can run around within 25 studs of the fight (further puts you back at the edge). Fighters attack on their own (interval from SPD: Common ~2 s, Legendary ~1 s); each has an element
ability (8 s cooldown) and the 6 Epic/Legendary cards a signature ability (15 s). Element wheel: Ember > Bloom >
Tide > Ember, Volt and Shade strong against each other (strong ×1.5, weak ×0.75). Run is a chance
(`clamp(0.5 + 0.03 × (leader SPD − monster SPD), 0.2, 0.9)`, −0.15 vs elites; failing costs a free hit and 3 s).
Win: XP `12 × level^1.3` (×3 elite) split evenly across all 3 party cards, $0.40 × level, 5% (elite 20%) chance of a
card of the zone's elements. Lose: nothing is lost, but fainted cards rest 3 minutes (3x faster standing at the
healing spring in the plaza centre). A fight still going after 2 minutes ends as a run. Numbers:
`Config/Combat.luau`, `Config/Wild.luau`; maths in `Util/CombatMath`, fights in `server/Util/BattleSim` (both
Lune-tested).

| Element | Ability | Effect |
|---|---|---|
| Ember | Fireball | 2.5× ATK hit |
| Tide | Wave | heals your fighters 25% max HP |
| Bloom | Vine Snare | monster attacks 40% slower for 4 s |
| Volt | Overcharge | next 3 attacks twice as fast |
| Shade | Curse | monster ATK −30% for 5 s |

| Card | Signature | Effect |
|---|---|---|
| Infernox | Inferno | burns 6 s (0.4× ATK per second) |
| Abyssal Koi | Tidal Shield | absorbs damage up to 30% of its max HP |
| Thunderhorn | Stampede | 2× ATK hit + 2 s stun |
| Eclipse Fox | Eclipse | dodges everything for 3 s |
| Solarion | Supernova | 4× ATK hit |
| Voidmaw | Devour | 2× ATK hit, heals half the damage |

| Zone | Monster Lv | Species (element) | Chases you |
|---|---|---|---|
| Meadow | 1–5 | Mossling (Bloom), Puddle Crab (Tide) | elites only |
| Caves | 5–10 | Cave Bat (Shade), Spark Beetle (Volt) | elites only |
| Ember Ridge | 10–15 | Magma Golem (Ember), Ash Wolf (Ember) | all |

About 8 monsters per zone, respawning 20–40 s after a win; 1 in 10 is an elite (gold tag, ×1.6 stats, ×3 rewards).
Monsters sleep with no player within 100 studs. Placeholder map and monsters are built in code; monster models
go in `assets/monsters/<Species>.rbxm` (docs/creatures.md). Studio: `/wild`, `/rest`, `/elite`.

**Party & summoning.** Binder card view → Add to party (slots 1–3; a plain copy becomes its own card). The Party
panel (HUD) shows each slot with Summon / Unsummon and Remove. One creature is summoned at a time: the server moves
an invisible marker behind you on the ground (`workspace.Creatures`, 20 Hz, teleports when 40+ studs away) and every
client draws the creature on it with walking, breathing and a rarity glow (`docs/creatures.md`). Party cards can't
be displayed or given a job; they can be condensed. While a creature is summoned, a small buff badge above the cash
(bottom-right corner) shows its perk (element icon, colour, +%); hover or tap it for what it does and which card it comes from. Left of it, the party bar (a dark tray,
`Config/Party` BAR) shows your avatar with a PARTY tag (opens Party) and the 3 party slots as small cards: the card's
art in its rarity rim with "Lv 4", a key chip 1 / 2 / 3; the summoned one lifts, glows blue and has an OUT tag; an empty
one is a dashed "+"; a resting one dims with "💤 2:41". Tap a slot or press 1 / 2 / 3 to summon it, again to unsummon;
an empty one picks a card in the binder. Empty Party and Jobs slots have Add card / Assign buttons that open the binder. Perks, from the summoned card
only, read live:

| Element | Perk | Effect | Common, 0 stars |
|---|---|---|---|
| Ember | Hype | customers arrive more often (spawn interval ÷ (1 + perk)) | 5% |
| Tide | Calm | customers wait longer in the queue | 10% |
| Bloom | Express | deliveries arrive faster | 10% |
| Volt | Hustle | you walk faster | 5% |
| Shade | Haggle | customers more willing to buy at your price (buy chance, capped at 100%) | 5% |

Perk = base × rarity (Common 1, Rare 1.5, Very Rare 2, Epic 2.5, Legendary 3) × (1 + 0.10 × stars).
Numbers live in `Config/Party.luau`.

Plain copies stack by card, foil and grade; a copy becomes an individual card (keeping its grade) the first time it gains XP or a star.

**Grades** (spec `2026-10-20-card-grades-design.md`): every pulled card rolls a grade on the server, fixed forever.

| Grade | Chance | Stats and value |
|---|---|---|
| C | 55% | +0% |
| B | 30% | +3% |
| A | 13% | +6% |
| S | 2% | +10% |

Rarer cards are less often Grade S (`Beasts.GRADE_CHANCES_BY_RARITY`, the difference going to C): Epic S 1.5%
(C 55.5%), Legendary S 1% (C 56%). A Grade S Legendary is the chase: about 1 in 10,000 First Spark packs (luck alone), shown on its
own line in the rarity guide (`OddsRules.perPack`). The Grading Station (5.9) raises a copy's grade with duplicates and
cash, a slow but sure path to Grade S.

**Power** = HP + 5 × ATK + 5 × SPD, shown on cards. Rarity always beats grade at equal level and stars: the best
copy of a rarity (best element, S, foil) has less Power than the worst copy of the next rarity (unit-tested).

| Beast field | Meaning |
|---|---|
| `id` | GUID, unique per beast |
| `cardId` | which Set 1 card |
| `foil` | boolean |
| `level` | 1–30 |
| `xp` | progress toward the next level |
| `stars` | 0–5 (every card starts at 0) |

Base stats by rarity:

| Rarity | HP | ATK | SPD |
|---|---|---|---|
| Common | 60 | 12 | 10 |
| Rare | 80 | 16 | 12 |
| Very Rare | 100 | 21 | 14 |
| Epic | 135 | 27 | 17 |
| Legendary | 180 | 36 | 20 |

Element multipliers: Ember ATK ×1.20 · Tide HP ×1.20 · Bloom HP and ATK ×1.10 · Volt SPD ×1.25 · Shade ATK and SPD ×1.10.
Then × level `1 + 0.06 × (level − 1)`, × stars `1 + 0.15 × stars`, × foil 1.05, rounded.

Value (the market value used everywhere): `card.value × (foil ? 3 : 1) × (1 + 0.10 × (level − 1)) × STAR_VALUE[stars]`,
`STAR_VALUE` for 0–5 stars = `{ 1, 6, 15, 30, 50, 80 }` (roughly the duplicates condensed plus a bonus).

XP from level L to L+1: `round(50 × L^1.5)`. Extra XP carries over; at Lv 30 XP stops (stored as 0).
Stars come only from the **Card Condenser** (a machine bought in the build menu, shop Lv 4, $500; no level gate,
levels raise stats only). Press E on it, pick a card and its main copy, see the cost and before -> after, then Condense.
Duplicates used: plain copies of the same card only, all normal copies weakest grade first (C, B, A, S), then foils
weakest grade first; levelled or starred copies are never used; a plain main copy is set aside first and becomes its
own card. One star per press. Duplicates per star (`STAR_COSTS`):

| Step | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | Total |
|---|---|---|---|---|---|---|
| Duplicates | 4 | 8 | 12 | 16 | 24 | 64 |

The binder shows the next step on every card ("Stars 0/5 · condense 4 duplicates for the next star").
Player-facing text says "Owned" and "levelled", never "fresh" or "raised".
Numbers live in `Config/Beasts.luau`. Studio: `/beastxp <amount>` gives XP to your best levelled card or rarest plain card.

### 5.9 Grading Station (grade-ups)

The sure, slow path to Grade S next to the lucky pull (a Grade S Legendary pulls about 1 in 10,000 packs, 5.8).
A machine bought in the build menu (Fixtures, shop Lv 8, $5,000; `Config/Shelves` kind `Grading`, a code-built
cabinet with a scanner bed, a magnifier and a graded slab: `Town.GRADING_LOOK`). Press E on it: pick a card and the
copy to grade, see the next grade, its cost, which duplicates go, Power and value before -> after and the whole way to
Grade S, then Grade Up. One step per press (C -> B -> A -> S). Duplicates are plain copies of the same card, used in
the Condenser's order (normals weakest grade first, then foils; never levelled or starred copies, never the plain main
itself), so stars and grades compete for the same duplicates. A plain main moves up to the next grade's stack and
stays plain; a levelled main keeps its level and stars. Working or fighting cards can't be graded. The server
recomputes the plan (`Util/CondenseRules.gradePlan`) and takes the cash through EconomyService in the same step
(`CardService.GradeUp`), so a forged or stale request changes nothing.

Cost per step, duplicates + cash (`Config/Grading.COSTS`):

| Rarity | C -> B | B -> A | A -> S | C -> S in all |
|---|---|---|---|---|
| Common, Rare | 2 + $100 | 4 + $500 | 8 + $2,500 | 14 + $3,100 |
| Very Rare | 2 + $250 | 3 + $1,000 | 6 + $5,000 | 11 + $6,250 |
| Epic | 1 + $500 | 2 + $2,500 | 4 + $10,000 | 7 + $13,000 |
| Legendary | 1 + $500 | 2 + $2,500 | 3 + $12,500 | 6 + $15,500 |

### 5.10 Boss ladder (phase 1: Wild bosses 1-3, solo)

Spec `docs/superpowers/specs/2026-10-28-boss-ladder-design.md`. Each boss drops what helps you beat the next and
the fragments that open it. Numbers in `Config/Bosses`, rules in `Util/BossRules` (pure, Lune-tested), saved progress
and rewards in `BossService`.

| # | Boss | Arena | Element | Lv | HP / ATK / SPD | Recommended Power | Mechanic | Opens with |
|---|---|---|---|---|---|---|---|---|
| 1 | Meadow Warden | Meadow | Bloom | 6 | 1800 / 11 / 8 | 200 | - | open |
| 2 | Cave Brood Queen | Caves | Shade | 11 | 3900 / 16 / 12 | 350 | heals 15% below half HP, every 12 s | 3 Brood Queen Key Fragments |
| 3 | Ember Colossus | Ember Ridge | Ember | 16 | 7200 / 22 / 9 | 650 | enrages below half HP (ATK x1.5) | 5 Colossus Key Fragments |

| Boss | Cash / XP per win | Drops (full loot) | First clear | Daily bonus |
|---|---|---|---|---|
| Meadow Warden | $36 / 620 | XP Tonic 60% (1-2), Brood Queen fragment 70% | 3 fragments, trophy, 3 XP Tonics | 2 XP Tonics |
| Cave Brood Queen | $66 / 1360 | XP Tonic 60% (1-3), Star Shard 15%, Colossus fragment 60% | 3 fragments, trophy, 3 XP Tonics | 2 XP Tonics |
| Ember Colossus | $96 / 2220 | Grading Seal 35%, XP Tonic 40% (2-3) | trophy, 3 Grading Seals | 2 Grading Seals |

- **Arenas:** a fenced ring beside each zone (its +X side), joined by a path, with a gate (prompt "Fight boss",
  recommended Power on it and on a sign). The gate checks distance (12 studs), the key and that you can fight; the
  key's fragments are used the first time only. The boss is spawned for you (or your group), stands still, and always goes when
  the fight ends (win, loss or run). One fight per arena: while someone fights there, the gate tells others to wait (or to join a
  group, below). The ring (radius 36) seals while a fight runs: the members are moved just inside the gate and a
  see-through wall rises all round (`BARRIER_*`), dropping when the fight ends for any reason. Boss fights may last 420 s (`Combat.BOSS_MAX_FIGHT_SECONDS`), the leash is 42
  studs, stuns on a boss last at most 1 s.
- **Intro:** a boss fight opens with 6 s of drama (`INTRO_*`): the camera flies to the boss, its name and title show
  (e.g. "Guardian of the Meadow"), it roars (camera shake), then 3, 2, 1, FIGHT. Nothing moves and no button works
  until then. Boss music plays through the fight ("Epic Boss Battle", `MUSIC_ID`); heals and enrages shake the camera.
- **Swaps:** in boss fights the bar's "Bring in <card>" buttons send in any rested party card. In the first 5 s
  (call-in unused) it joins beside yours; after that it swaps in for your most hurt creature (or a fainted one),
  which goes back to the bench with its HP. Swaps wait 8 s between them (`Combat.BOSS_SWAP_SECONDS`), except when
  none of yours is standing; when all of yours faint, your healthiest rested card comes in by itself, and you lose
  only when none is left. A swapped-out summoned creature is hidden until it comes back. Because a player now brings
  all three party cards, boss HP went up x1.5 and ATK about x1.2 (`BattleSim.swap`, Lune-tested).
- **Fight bar:** kept short for landscape phones: each creature is one 56 px row (name and HP beside its ability
  buttons), Bring in / Run below; in boss fights the bottom bar drops its title (the slim top bar shows the boss),
  about 126 px solo (`layoutBar` in BattleController).
- **Farm protection:** unlimited fights; XP and cash on every win. Items need a win of at least `minFightSeconds`
  (12 / 18 / 25 s) and come once per 15 minutes per boss (saved Unix time, so rejoining doesn't reset it). After 6
  rewarded wins of a boss in a UTC day each further one's chances are x0.75 of the one before (floor x0.2); a
  strongest card that fought (leader or called in; resting party cards don't count) above 2.5x the recommended
  Power makes them x0.35. Fragments for a boss you've already opened
  never drop. The first clear's chest (and the server-wide chat message) comes even on a too-fast win, so a strong
  player can still climb.
- **Items:** XP Tonic (400 card XP, used from the Party panel, never on a Lv 30 card), Grading Seal (one missing
  duplicate at the Grading Station, at most half a step, so never on a 1-duplicate step; the toggle says when they
  can't help), Star Shards, fragments, trophies.
- **Trophies:** Build menu -> Trophies: placing one takes its trophy item (no cash), selling gives it back; they don't
  count toward the shop's shelf limit; a stone
  plinth with a gold cup and a gem in the boss's colour (`Town.TROPHY_LOOK`). Visitors see them.
- **UI:** the Bosses HUD tile (K) opens the Boss Ladder: lock and fragments x/N, recommended Power vs your strongest
  party card, full loot ready or its countdown, today's wins and reduced-drop notes, a trophy once cleared. In a boss
  fight a wide HP bar sits at the top, "Healing!" / "Enraged!" banners pop up, and the end screen lists the loot.
- **Groups (phase 2):** the gate's second prompt (F) "Start group" opens a group; others press "Join group (n/4)"
  within 15 s (`JOIN_SECONDS`), the leader (whose prompt reads "Start now (n/4)", `BossRules.groupPromptText`) can
  press again to start at once, it starts by itself when full (4). The Fight and group prompts have separate limiters.
  Every member needs the boss open or its fragments (taken only if the fight starts) and a rested summoned creature,
  and must still be near the gate when it starts (others are left out with a message; if the leader is gone the next
  member leads). One boss for the group: HP x (1 + 0.8 (n - 1)), ATK x (1 + 0.15 (n - 1)) (`BossRules.groupStats`).
  Each player fights with their own creatures (their own call-in and abilities); Run is Leave: they step out, the
  others fight on, and the fight ends when nobody is left standing: a loss if a fainted member is still in it, else a
  run. Leaders stand 7 studs apart on the ring (`GROUP_SPACING`), each call-in 3 studs to its own leader's right
  (`Combat.EXTRA_SIDE`). Every member counts as busy for wild aggro (BattleService tells WildService), a member who left
  doesn't. On a win each player gets their own XP, cash and loot roll.
  Full loot needs 10% of the group's damage or 15% of the hits it took (`BossRules.contributed`, counting only the
  players still in the fight); below that a player
  is **carried**: item chances x0.25, no fragments, no first-clear chest, no daily bonus (the cooldown and soft cap
  still apply). The fight bar shows your creatures and an ally row with the others' HP; the end screen says when you
  were carried. While a group forms, the solo Fight prompt tells others (and members) to wait.
- Studio: `/item <id> <n>`, `/boss <n>` (to boss n's gate), `/boss <n> fight` and `/boss <n> group` (use that prompt).
- Boss models are placeholders (Wild shapes at 2.5-3.2x). Next (spec section 10): Frontier bosses (phase 3), the Dungeon (4).

---

## 6. Products (stock you sell)

| Product | Wholesale (box) | Units | Market price / unit | Unlock |
|---|---|---|---|---|
| First Spark Booster Pack | $48 / box | 24 | $3.00 | Start |
| Card Sleeves | $30 / box | 20 | $2.50 | Lv 2 |
| Deck Box | $60 / box | 10 | $9.00 | Lv 5 |
| First Spark Booster Box (sealed) | $90 each | 1 | $120 | Lv 7 |
| Set 2 Booster Pack | TBD | 24 | TBD | Lv 10 |

Player can also open their own stock instead of selling it: packs (rip one at a time) and deck boxes (5 cards
at once, section 5.7). Trade-off: sell for safe profit, or gamble on a big pull.

---

## 7. Progression & economy

### 7.1 Start
- Starting cash: **$200**
- Starting shop: small room, register, order computer. No shelves: the first Small Pack Rack is bought from the Build menu.

### 7.2 Shop levels (XP per sale = sale price rounded, min 1)

| Lv | XP needed | Unlocks |
|---|---|---|
| 1 | 0 | Base |
| 2 | 150 | Card Sleeves |
| 3 | 500 | Wall Shelf |
| 4 | 1,200 | Card Condenser |
| 5 | 2,500 | Accessory Hook, Deck Box, Expansion 1 |
| 6 | 5,000 | Big Display Rack |
| 7 | 9,000 | Sealed Booster Box |
| 8 | 15,000 | Grading Station |
| 9 | 24,000 | Expansion 2 |
| 10 | 36,000 | Shop jobs (first slot), Set 2 |

There is no level cap: after Lv 10 each level costs 15% more XP than the step before it
(`Levels.XP_GROWTH`; Lv 11 = 49,800, Lv 12 = 65,670). Maths in `Util/LevelMath.luau` (Lune-tested).

### 7.3 Upgrades (one-off purchases)

| Upgrade | Effect | Cost |
|---|---|---|
| Faster Delivery I/II/III | Delivery 10s → 6s → 3s → instant | $300 / $900 / $2,500 |
| Carry Cart | Carry 3 boxes at once | $600 |
| Bigger Queue | Customers wait 50% longer | $400 |
| Street Sign | +10% customer spawn rate | $750 |
| Expansion 1 | +50% floor space | $2,000 |
| Expansion 2 | Second room | $8,000 |

### 7.4 Staff: shop jobs (cards that work)
Hired staff became **shop jobs**: your levelled cards do the work (spec `2026-10-21-shop-jobs-design.md`).
- **Slots:** 1 at shop Lv 10; the "Extra Job Slot" game pass adds 1 more (max 2). Assign from the binder card
  view ("Assign to job"); the **Jobs** HUD button shows each slot's card, status, XP, speed and mistakes.
- **Restocker:** carries delivered boxes from the pad to shelves that hold (or accept) that product and stocks them.
- **Cashier:** scans and charges customers like you do; steps aside while you're at the register.
- **SPD = speed**: (SPD / 14)^1.5, clamped ×0.4 to ×2.5, so a fresh Grade C Common scans in ~2.0 s and a fresh
  Legendary in ~0.7 s (base 1.2 s); levelling raises SPD. **Power = fewer mistakes** (20% for a fresh Common down to 3%):
  a dropped box goes back to the pad, a mis-scan is scanned again. Mistakes cost time only.
- **XP:** 2 per minute per working card, only while you're online. Battles and quests will be the main way to level.
- Working cards are locked: no display, condensing or second job until unassigned.
- In the shop they walk as invisible R15 rigs (pathfinding) that each client draws as the card's creature model
  (`WorkerVisualController`, `Party.CREATURE_MODELS`; at least `Jobs.CREATURE_MIN_HEIGHT` 3.4 tall), with the motion
  kit; cards without a model show the R15 rig in the element colour, sized by rarity. The cashier stands on a low
  charcoal step behind the counter (`Town.COUNTER.STEP`, solid, 1 tall) so even a small pet shows over it.

### 7.5 Tuning goals
- First upgrade within ~3 minutes.
- Shop Lv 5 in about 1–1.5 hours of play.
- Lv 10 in about 8–10 hours.
- These are targets. Tune after playtesting, keep numbers in config files so it's easy.

---

## 8. Monetization

Principle: sell **convenience, speed and looks**, not "win". Never sell anything that makes another player's experience worse.

### Game passes (one-time)
| Pass | Effect | Suggested price |
|---|---|---|
| 2x Cash | Double sale income | 299 R$ |
| Auto Restock | Shelves refill from stock automatically | 199 R$ |
| VIP | Gold name tag, VIP shop theme, +1 NPC cap | 149 R$ |
| Extra Showcase Slots | +6 showcase slots | 99 R$ |
| Fast Open | Instant pack opening animation skip + Open All x10 | 79 R$ |

### Developer products (repeatable)
| Product | Effect | Suggested price |
|---|---|---|
| Cash packs | $1k / $5k / $25k in-game | 25 / 99 / 399 R$ |
| Lucky Hour | +50% Epic/Legendary odds for 60 min (new odds shown in UI) | 49 R$ |
| Customer Rush | 2x customer spawns for 15 min | 29 R$ |

### Cosmetics
- Shop themes (floor, walls, lighting): retro arcade, neon, cozy wood, etc.
- Register skins, sign styles, card sleeve colors in binder.

### Other
- Private servers enabled (cheap price).
- Premium payouts: just having engaging sessions helps here.

**Rule:** anything with a random result bought with Robux must show odds before purchase.

---

## 9. Social features (post-MVP order)
1. Server-wide pull announcements (MVP, cheap win)
2. Buy singles from other players' Collector Cases (done)
3. Trading window (with confirm + both sides lock)
4. Leaderboards: richest shop, rarest collection
5. Play Glimmerbeasts at tables (simple card battle mini-game), tournaments bring customers
6. Weekly limited packs / events

---

## 10. Tech architecture

### 10.1 Tooling
- **Rojo** for syncing files into Studio. Code lives in the repo, not in Studio.
- **Wally** for packages.
- **ProfileStore** for player data (session locking, safe saves).
- Optional later: Selene (linter), StyLua (formatter).

### 10.2 Folder structure
```
/
├── DESIGN.md
├── default.project.json        # Rojo project (main game)
├── frontier.project.json       # Rojo project for the Frontier place (same src, PlaceKind = "Frontier", port 34873)
├── wally.toml
├── tests/                      # Lune unit tests for pure modules: lune run tests/run
├── assets/creatures/           # creature models (.rbxm) → ReplicatedStorage.CreatureModels (docs/creatures.md)
├── assets/monsters/            # wild monster models (.rbxm) → ReplicatedStorage.MonsterModels
├── assets/props/               # town prop models (.rbxm) → ReplicatedStorage.PropModels (docs/props.md)
├── assets/town/                # hand-placed town scenery (TownDecor.rbxm) → Workspace.TownDecor
└── src/
    ├── server/                 # → ServerScriptService
    │   ├── init.server.luau    # boots services
    │   ├── Services/
    │   │   ├── DataService.luau      # ProfileStore, load/save, defaults
    │   │   ├── PlotService.luau      # claim/release plots, modern shop shells (glass front, sliding doors, sign band, roof)
    │   │   ├── TownService.luau      # main town: ground, street, plaza, decor props, portal frames, lighting
    │   │   ├── EconomyService.luau   # cash, XP, levels (ONLY place cash changes)
    │   │   ├── StockService.luau     # orders, deliveries, carrying, stocking shelves
    │   │   ├── PlacementService.luau # validate + place/move/sell shelves, shelf contents
    │   │   ├── PricingService.luau   # player sell prices per product
    │   │   ├── CustomerService.luau  # NPC spawn, pathing, buying, queue
    │   │   ├── RegisterService.luau  # checkout flow
    │   │   ├── PackService.luau      # server-side pack rolls
    │   │   ├── CardService.luau      # binder contents (not named CollectionService to avoid clashing with Roblox's)
    │   │   ├── ShowcaseService.luau  # display cards, price them, player buys, customer card buys
    │   │   ├── CondenserService.luau # Card Condenser remote: validate, then CardService.Condense
    │   │   ├── GradingService.luau # Grading Station remote: validate, then CardService.GradeUp (cash via EconomyService)
    │   │   ├── JobService.luau       # shop jobs: slots, worker creatures, restocker/cashier loops, work XP
    │   │   ├── PartyService.luau     # party slots, summon, creature marker, perks
    │   │   ├── WildService.luau      # wild map, plaza portal, healing spring, monsters (spawn, wander, chase)
    │   │   ├── BattleService.luau    # wild fights: start checks, BattleSim loop, rewards, resting, spring
    │   │   ├── ArenaService.luau     # PvP: challenges, bet escrow, arena pad + queue, fights, saved record
    │   │   ├── ItemService.luau      # item inventory (Star Shards, boss items): give, take, save
    │   │   ├── BossService.luau      # boss ladder: saved progress, arena gates, keys, boss wins' items (farm protection)
    │   │   ├── FrontierService.luau  # teleports: plaza Frontier portal, Explore / Join friend, back home
    │   │   ├── DevService.luau       # Studio-only test chat commands
    │   │   └── MonetizationService.luau # game passes (Extra Job Slot), cached checks, purchases
    │   └── Util/
    │       ├── Migrations.luau       # save migrations (pure, Lune-tested)
    │       ├── NpcMotion.luau        # NPC rigs, animations and path walking (customers and workers)
    │       ├── SaleRules.luau        # player-to-player buy check (pure, Lune-tested)
    │       ├── BattleSim.luau        # seeded wild fight simulation (pure, Lune-tested)
    │       └── RateLimiter.luau      # per-player remote cooldowns
    ├── client/                 # → StarterPlayerScripts
    │   ├── init.client.luau
    │   ├── Controllers/
    │   │   ├── UIController.luau       # main ScreenGui, status corner (cash, shards, level + XP), toasts, money toasts
    │   │   ├── OrderController.luau
    │   │   ├── BuildController.luau    # Build menu (category tabs, 3D model tiles), shelf prompts, shelf edit menu
    │   │   ├── PlacementController.luau
    │   │   ├── PricingController.luau
    │   │   ├── RegisterController.luau
    │   │   ├── CarryController.luau    # drop carried box
    │   │   ├── PackOpeningController.luau
    │   │   ├── AnnouncementController.luau # big-pull chat messages
    │   │   ├── BinderController.luau   # full-screen binder book per set: cover, set tabs, Q/E page keys, page counter, Filters panel (F), set progress card; pockets (3x3, fewer on short screens) with a chip row; tooltips; card view
    │   │   ├── ShowcaseController.luau # manage your own card case, marketplace style: listings, details, tooltip, Set price
    │   │   ├── CondenserController.luau # Card Condenser panel: pick card + main copy, preview, Condense
    │   │   ├── GradingController.luau # Grading Station panel: pick card + copy, next grade, cost, Grade Up
    │   │   ├── JobsController.luau      # Jobs HUD button and panel: slots, status, XP, Unassign, Buy slot
    │   │   ├── PartyController.luau     # Party HUD button and panel: slots, perk, Summon, Remove
    │   │   ├── BuffController.luau      # buff badge (bottom-right) and tooltip for the summoned creature's perk
    │   │   ├── ButterflyController.luau # client butterflies round the plaza spring
    │   │   ├── PriceTagController.luau  # point at / tap your shelf price tags to set the price
    │   │   ├── PartyBarController.luau  # bottom-right party tray: your avatar + 3 party cards, tap or 1/2/3 to summon
    │   │   ├── MonsterController.luau   # draws wild monsters on their markers (model or placeholder)
    │   │   ├── BattleController.luau    # Fight prompts, Shop button in the wild, fight bar (wild + PvP), boss HP bar and banners, damage numbers, end screen
    │   │   ├── BossBoardController.luau # Bosses HUD tile and the Boss Ladder panel
    │   │   ├── ChallengeController.luau # PvP: Challenge prompt on players, bet popup, incoming challenge popup
    │   │   ├── FrontierController.luau  # Frontier portal menu (Explore, Join friend); home button in the Frontier
    │   │   ├── FrontierRevealController.luau # full-screen reveal when you find a Frontier card
    │   │   ├── RarityGuideController.luau # rarity guide panel (odds from the pack configs)
    │   │   ├── CardInspectorController.luau # the 3D card you tilt and flip from the binder
    │   │   ├── CreatureController.luau  # draws summoned creatures: model or placeholder, motion, glow, name tag
    │   │   ├── CardBuyController.luau  # visitors browse other players' cases (marketplace style); buy from Collector Cases
    │   │   └── CardEffectsController.luau # displayed cards: card face with price, halo, glows, sparkles, listing bursts
    │   └── Util/
    │       ├── UIKit.luau              # shared UI building helpers and the style (header, close, lip buttons)
    │       ├── Motion.luau             # pop in/out, press squash, bumps
    │       ├── FontStyle.luau          # switches Gotham text to the game fonts (FredokaOne, Nunito)
    │       ├── Hud.luau                # HUD layout: Manage tray, bottom tiles, context tiles, top bar
    │       ├── Icon.luau               # draws a UIIcons icon (or an emoji) into a holder
    │       ├── CardFace.luau           # draws a card face (front, back, missing) into a frame
    │       ├── CreatureVisuals.luau    # shared model pipeline + motion for creatures and monsters
    │       └── RestTimers.luau         # resting countdowns for the party bar and Party panel
    └── shared/                 # → ReplicatedStorage
        ├── Config/
        │   ├── Cards.luau      # Set 1 card list
        │   ├── Rarities.luau   # odds, values, colors
        │   ├── Products.luau   # stock catalog
        │   ├── Shelves.luau
        │   ├── Plots.luau      # plot layout and fixtures
        │   ├── Economy.luau    # starting cash/level
        │   ├── Stock.luau      # delivery, carrying
        │   ├── Placement.luau  # grid, placement rules
        │   ├── Pricing.luau    # price limits, customer buy bands
        │   ├── Customers.luau  # NPC spawn, patience, bubbles
        │   ├── Register.luau   # checkout reach, counter items
        │   ├── Packs.luau      # pack slots and odds
        │   ├── PackOpening.luau # reveal timings and sounds (client)
        │   ├── UIMotion.luau   # UI motion timings and scales (client)
        │   ├── UIFonts.luau    # the game fonts (client)
        │   ├── UIIcons.luau    # UI icon image ids by name (HUD, top bar, customer bubbles)
        │   ├── HudLayout.luau  # HUD tile sizes, fan arc, colours (client)
        │   ├── CardReveal.luau # how big each pull's reveal is: tease, rays, spotlight, sparks, banner (plain data)
        │   ├── CardDesign.luau # card face layout, colours and image ids (client)
        │   ├── Collection.luau # binder request limits
        │   ├── Showcase.luau   # card case prices, customer card chance, slot layout
        │   ├── Condenser.luau  # Card Condenser cooldown and use distance
        │   ├── Grading.luau    # Grading Station costs by rarity and grade, cooldown, use distance
        │   ├── Jobs.luau       # shop job slots, speeds, mistakes, work XP
        │   ├── Party.luau      # party size, perks, creature size, motion, glow
        │   ├── Combat.luau     # attack timing, element wheel, abilities, run, rest, spring
        │   ├── Wild.luau       # wild zones, monster species, spawns, rewards
        │   ├── Pvp.luau        # challenge timings, bet cap and steps, arena layout
        │   ├── Frontier.luau   # Frontier zones, species, drops (same shape as Wild)
        │   ├── Items.luau      # every item: name, icon, description; stack limit
        │   ├── Bosses.luau     # boss ladder: bosses, drops, chests, farm protection, arenas
        │   ├── Town.luau       # main town: prop slots, decor layout, shop shell sizes, plot themes, lighting
        │   ├── Places.luau     # place ids, Frontier portal spot
        │   ├── CardList.luau   # every card row (Set 1 and Frontier), plain data
        │   ├── CardEffects.luau # per-rarity effects on displayed cards (client)
        │   ├── Announcements.luau # which pulls get a server-wide chat message
        │   ├── Data.luau       # DataStore name, schema version, kick messages
        │   ├── Beasts.luau     # beast stats, value and XP numbers
        │   ├── Levels.luau
        │   ├── Upgrades.luau
        │   └── Monetization.luau # game pass IDs (0 = not created yet)
        ├── Remotes.luau        # all RemoteEvents/Functions defined in one place
        └── Util/
            ├── PlacementGrid.luau # grid maths shared by client preview + server validation
            ├── PriceRules.luau    # price clamping and buy bands
            ├── BeastMath.luau     # pure beast stat/value/XP maths (no Roblox APIs, Lune-tested)
            ├── BeastRules.luau    # BeastMath bound to the game configs
            ├── CondenseRules.luau # which duplicates a star or a grade-up uses (pure, Lune-tested)
            ├── JobRules.luau      # job speed, mistakes and slots (pure, Lune-tested)
            ├── CombatMath.luau    # attack interval, damage, elements, run chance, XP split, rewards (pure, Lune-tested)
            ├── PvpRules.luau      # PvP bet cap, valid bets, payouts, record (pure, Lune-tested)
            ├── ItemRules.luau     # item inventory rules (pure, Lune-tested)
            ├── Place.luau         # which place this is; its wild-map config
            ├── TownLayout.luau    # where every town decoration goes (pure, Lune-tested)
            ├── Props.luau         # place swappable prop models (assets/props) or part stand-ins; server town, client ghosts
            ├── PropFit.luau       # prop fit sizes with YawOffset, register counter rows (pure, Lune-tested)
            ├── ShelfStock.luau    # stock boxes, pack stacks and price tags on shelves (pure, Lune-tested)
            ├── PartyRules.luau    # perk strength and text (pure, Lune-tested)
            ├── CreatureMotion.luau # breathing, hop, waddle, hover poses (pure, Lune-tested)
            ├── CardRules.luau     # card market value and price limits
            ├── RevealRules.luau   # a card's reveal plan from rarity, foil and set (pure, Lune-tested)
            ├── BinderSpreads.luau # binder spreads, card ranges, which page a card is on, the page counter (pure, Lune-tested)
            ├── OddsRules.luau     # pull odds per card from a pack's slots (pure, Lune-tested)
            ├── PityRules.luau     # pack pity: when a hit slot is raised to a Legendary or Epic (pure, Lune-tested)
            ├── BossRules.luau     # boss unlocks, loot cooldown, soft cap, over-power (pure, Lune-tested)
            ├── NewPulls.luau      # which pulls are NEW to the collection, for the pack results (pure, Lune-tested)
            └── LevelRules.luau    # XP → level maths and unlock lists
```

### 10.3 Rules for the code
- **Server authoritative.** Client only sends intents ("I want to order X", "place shelf at Y", "open pack"). Server validates everything and changes state.
- **All cash/XP changes go through EconomyService.** No other script touches cash directly.
- **Pack rolls happen on the server only.** Client just plays the animation for the result it's given.
- Validate remote args (types, ranges, ownership of plot, distance checks for interactions).
- Rate-limit remotes that can be spammed (open pack, scan item, order).
- All tunable numbers live in `shared/Config`. No magic numbers in services.
- Use Luau type annotations (`--!strict` where practical).
- Mobile-first UI: big tap targets, test at phone resolution.

### 10.4 Player data schema (v12)
```lua
{
    version = 12,
    cash = 200,
    xp = 0,
    level = 1,
    shopName = "",
    upgrades = {},          -- { [upgradeId] = true }
    prices = {},            -- { [productId] = price }
    layout = {},            -- { { shelfId, gridX, gridZ, rotation, productId?, units, paid, cards? } }
                            --   cards (card cases): { { slot, cardId, foil, price, grade, beastId?, level?, xp?, stars? } } (stars 0-5)
    fixtures = {},          -- { [fixtureId] = { gridX, gridZ, rotation } } e.g. the moved order computer (a 10x6 desk;
                            -- restored after the shelves, to the nearest free spot if its own is taken).
                            -- Saved shelves that no longer fit their spot (a shelf grew) move to the nearest free one.
    boxes = {},             -- { { productId, units } } on the pad, carried, or ordered but not delivered
    cards = {},             -- { [cardId] = { [grade] = { normal = n, foil = n } } } plain copies in the binder, not on display
    beasts = {},            -- { [beastId] = { cardId, foil, level, xp, stars, grade } } levelled cards in the binder (stars 0-5)
    jobs = {},              -- { { slot, beastId, job } } cards working in the shop (Restocker / Cashier)
    party = { slots = {} }, -- { slots = { ["1".."3"] = beastId }, summoned = slot? } party cards and the summoned one
    resting = {},           -- { [beastId] = unixTime } cards that fainted in a fight, resting until then
    pvp = { wins = 0, losses = 0, draws = 0 }, -- PvP record
    items = {},             -- { [itemId] = count } item inventory (Config/Items), e.g. starShard
    pity = { legendary = 0, epic = 0, firstDone = false }, -- packs since the last Legendary / Epic or better; had a first Legendary
    bosses = {},            -- { [bossId] = { unlocked, cleared, lootAt, day, rewardedToday, bonusDay } } boss ladder (5.10)
    stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 },
    purchases = {},         -- processed dev product receipt IDs (for idempotency)
}
```
Bump `version` and write a migration whenever the shape changes.
Template and types live in `DataService.luau`. Packs are opened straight from carried boxes, so there is no
separate unopened-packs inventory; unsold stock is saved as `boxes` rather than a backroom count.

Loading is defensive: unknown IDs are dropped, prices re-clamped, level recomputed from XP, and saved shelves
that no longer fit are skipped (cards from a skipped case go back to the binder).
When a player leaves, customers put picked-up stock and cards back before the save.

Schema history: v1 first release; v2 moved displayed cards onto `layout` entries and dropped the unused `showcase` list; v3 added the `beasts` table; v4 made stars start at 0 (old star counts drop by one); v5 gave every copy a grade (rolled per copy on upgrade); v6 added `jobs`; v7 added `party`; v8 added `resting`; v9 added `pvp`; v10 added `items`; v11 added `pity`; v12 added `bosses`. A service that didn't load for a player (e.g. no free plot) never overwrites
their saved data.

### 10.6 UI style and HUD
Spec: `docs/superpowers/specs/2026-10-23-ui-restyle-design.md`.
- **Style** (`Util/UIKit`, "Midnight & Gold"): deep navy-charcoal panel bodies with a soft gold rim, a dark
  gradient header with the title and a thin gold rule under it, a red close button on the top-right corner, slate
  cards and rows with thin edges, chunky buttons with a darker bottom lip (warm gold primary with dark text, slate
  secondary). Text picks warm white or dark ink for the surface behind it. HUD tiles are midnight slate; the Bag,
  hover tooltips, Shop pictures and the pack opening stage use the same palette.
- **Font** (`Util/FontStyle`, `Config/UIFonts`): rounded fonts everywhere (screens, card faces, tags): FredokaOne
  for titles, buttons and numbers, Nunito Bold for body text. Code still names Gotham; FontStyle switches each
  text object as it appears (Fredoka was tried: it only draws in Studio Edit mode, not in Play).
- **Motion** (`Util/Motion`, `Config/UIMotion`): panels pop in (0.85 to full size, slight overshoot) and the close
  button shrinks them away; buttons squash while held; number pills bump when they change.
- **HUD** (`Util/Hud`, `Config/HudLayout`): a midnight **Manage** tile on the left middle slides out a tray of tiles to
  its right (Shop, Prices, Jobs, Party), popping in one by one, and turns into Close; tiles at the bottom centre (Cards B, Bag I) with key
  chips; orange context tiles join that row while usable (Drop G while carrying, Rip T while carrying packs).
  Bottom right, one corner cluster (above the jump button on touch screens; on a narrow screen where the party bar
  would reach over the bottom-centre tiles, it lifts above the tile row too): the party bar, and beside it a
  right-aligned column, bottom up: level (number on a star icon, the XP bar inside the pill, in line with the
  party bar), Star Shards, cash, then the buff badge; money toasts pop in just above. On touch screens (short
  landscape phones, the jump button in the bottom right) it is one column down the right edge from the top right to
  the middle: buff, cash, shards, level, then the party bar, then the money toasts. Nothing sits in the middle of
  the screen. The whole HUD (tiles, Manage
  tray, corner, toasts) shrinks with the screen's height (`HudLayout.SCALE`, `Hud.scaleWith`): full size from 560 px
  tall, down to 70% on short phones (tiles stay over 48 px to tap). Each icon sits over its
  pill's left end. **Icons** (`Config/UIIcons`, `Util/Icon`): glossy cartoon pictures for the
  HUD tiles (Close included), the top bar, the Shop's header and tabs, Bag items and customer mood bubbles
  (Angry, Thinking, Happy); made as three sheets with Figma's image generator and cut by
  `tools/ui-icons/slice_icons.py` (PNGs in `assets/ui/icons`). Every icon is kept drawn, tiny and nearly invisible,
  from the moment you join (Roblox only finishes loading an image once it's drawn), so hidden tiles open with
  their icons ready. Names without a picture show as text (⌛ in a bubble). Toasts sit above the bottom row. The fight screen hides the HUD groups.
- **One window at a time** (`UIKit.panel`): opening a main window (Shop, Prices, Jobs, Party, the binder...)
  closes any other; windows marked `Overlay` (the Rarity guide, a case's card picker) open on top without
  closing anything. While the Rarity guide is open, Q/E and swipes don't turn binder pages.
- **Prices** rows show each product's picture beside its name and price: packs their real front (`Packs` art, as on the shelves), others their icon (`Products.icon`).
- **Binder** (`Config/Collection`, `Util/BinderSpreads`): full screen over the dimmed world (the dim covers Roblox's top bar strip too), drawn like a real
  binder: a dark leather case with a stitched seam, a chrome rail with three rings down the spine, dark pages with
  plastic pocket sleeves (a soft glint over each card) and dark empty slots with a "?". One book per set; set tabs
  are bookmarks sticking out of its left edge (the open set's sticks out further, in its colour). Spread 1's left
  page is the cover: full art (the pack art over the whole cover; leather in the set's colour without one), an
  embossed border, the title (name, "34 / 35 collected") and the set's worth in outlined text over dark fades,
  a progress bar; then page 1. Pages hold 3x3
  pockets when cards are at least 90 px wide, else fewer, bigger ones. The book keeps a binder's shape (1.36 wide
  to 1 tall) and nearly fills the screen's height (on its own full-screen layer, rising into Roblox's top bar strip,
  with the page counter just under it) when the corner buttons stay clear; on phones (screens under 900 wide) the
  corner buttons go compact (icons only: Cards and Bag down the left edge, Rarity guide bottom left, Filters under
  the close button) and the book takes the full height between those slim lanes; otherwise it fits between the top
  row (Cards, Bag; Filters, close) and bottom row (Rarity guide, progress card). Screens under 900 px wide drop the
  page arrows (swipe) and the progress card; tiny pockets show only the "Owned 3" chip. Turning a page animates
  (0.35s, eased): the page rotates about the spine (its width follows the turn), swells a little as it lifts,
  darkens edge-on and casts a shadow on the page underneath, then lands on the other side showing the next cards. Q/E, the
  arrows and a swipe turn pages. Page counter pill ("2-3 / 9"); arrows with key chips
  (Q/E one spread). Top right: Filters (F) and close. The Filters panel (search, Show
  All/Owned/Missing, Sort by Set/Value/Copies/Rarity, rarity chips) opens on the right while the book (arrows
  included) shrinks into the room left of it. Bottom right: the set's progress card (owned / total with a bar, value of your copies).
  The side and bottom HUD hide while the binder is open. Cards / Bag tabs stay top left.
- **Rarity guide** (`RarityGuideController`, `Util/OddsRules`), from the binder's bottom-left button: each rarity
  with a sample card, its chance per card pulled from a First Spark pack (from `Config/Packs`: Common 74%, Rare
  19.6%, Very Rare 3%, Epic 2.8%, Legendary 0.6%) and "about 1 in N cards"; Frontier cards (drop chances from
  `Config/Frontier`); foil chance and value; grade chances and their stat bonus.
- **Card inspector** (`CardInspectorController`, `Config/Inspector`): tapping a binder card shows it as a real 3D
  card (about 60% of the screen's height) left of centre close in front of the camera (front: the card face; back: the card back), on a solid dark
  sheet just behind it that hides the world (and your pet); the binder's dim and always-on-top tags (customer mood bubbles) switch off while it shows. Drag to tilt (it eases back), drag far sideways or press Flip to turn it over;
  Legendaries keep their element aura. The info panel on the right has the copies list (best first), Assign job,
  Add to party and Back. Closing restores the camera; dying closes it too.
- **Shop menu** (`BuildController`; was "Build"): a "Shop" panel (shop icon in its header) with icon tabs Shelves / Cases / Fixtures / Decor (each shelf's
  `category` in `Config/Shelves`; Decor says "coming soon") and a grid of tiles. Each tile shows a 3D picture of
  the real prop model (in its own colours) on a peach backdrop, the name, what it holds, and a price button:
  green price, red when you can't afford it, grey "Lv N" while locked. Buying places it as before.

### 10.5 Performance budget
- Max 6 plots × 4–8 NPCs. NPC movement on server, keep rigs simple.
- Use CollectionService tags for shelves/interactables.
- Stream-friendly: enable StreamingEnabled, test on low-end phone.
- Town props: under 2k triangles per prop model and 60k for the whole town; models over 150 parts use the
  stand-in. About 120 props (107 outdoors, 2 per register), all anchored, none with scripts.

---

## 11. MVP scope (v0.1 — first playable)

**In:**
- [x] Rojo project set up and syncing
- [x] Plot claiming (6 plots)
- [x] Order computer + delivery + carrying boxes
- [x] Small Pack Rack placement (grid, rotate)
- [x] Pricing UI for booster packs
- [x] NPC customers: walk in, pick packs, queue, leave if waiting too long
- [x] Register checkout
- [x] Cash + XP + levels 1–5
- [x] Pack opening (Set 1, server rolls, flip animation, foil effect)
- [x] Binder UI
- [x] ~~Quick sell cards~~ (removed: cards now sell through card cases)
- [x] Saving with ProfileStore
- [x] Server pull announcements
- [x] Card cases: Glass Showcase (NPC customers buy) + Collector Case (players buy, with confirm)

**Out (later):** trading, staff, expansions, card battles, Set 2, events, most cosmetics.

**Milestone after MVP (v0.2):** game passes live, expansions, more shelves. Soft launch, watch retention (D1/D7) before adding big features.

---

## 12. Open questions
- Final game name and card game name (Glimmerbeasts is placeholder).
- Card art style and who makes it.
- Should customers sometimes ask for specific singles ("got any Voidmaw?") as a quest-like hook?
- Offline earnings: yes/no? (Usually boosts retention but needs care with balance.)
- Cash payment with making change, or keep checkout one-tap?

## 13. Polish backlog (after the core loop)
- Fight juice: punchier floating damage numbers (size by damage, crit/strong pop, stacking so numbers don't
  overlap), hit markers and a short flash on the creature hit, a screen shake on big boss hits.
- Fight bar redesign: a portrait of each creature (its model in a ViewportFrame) beside its HP, clearer HP bars
  (damage trail, low-HP pulse), reserves shown as small portrait buttons with their HP, ability buttons with
  cooldown sweeps instead of countdown text.
- Phone layout pass for fights: check the boss bar, fight bar and end screen on small landscape phones in the
  Device emulator (boss bar width against the Roblox buttons, bar height, tap targets).
