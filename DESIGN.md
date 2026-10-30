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
`portalPaths`) round the healing spring. The spring is the **Elemental Bloom** fountain (plaza round 2, the user's
pick B of three fountain concepts, 2026-10-30; remodelled in Blender the same day to be bigger and much more
colourful: `tools/blender/build_bloom_fountain.py`, sources in `assets/blender/BloomFountain/`, saved as
`assets/props/BloomFountain.rbxm` (PropModels); `Server/Util/BloomFountain`, `Config/Plaza.FOUNTAIN`): a lotus on a
deep teal two-step base with gold bands and lily pads (radius 7, 12.1 tall with its card), five big cupped outer
petals, one per card element (Ember, Tide, Bloom, Volt, Shade), each in three bands from a deep shade to a bright
tip with a glowing gem spraying an arc of glowing water (a scrolling beam) into the pool; five magenta inner petals;
a golden card-shaped crystal floating over a gold cup. Bold mid tones only: pale ones washed out to white in the
town's sun. Until the model is in PropModels a part-built stand-in is drawn (petals from `Util/PlazaLayout`). The
magic: sparkles off each gem and motes in every element's colour rising from the pool (server); on each client near
it with the extras on (`FountainFxController`, tag BloomFountain), a rune circle (`assets/ui/fx/rune-circle.png`,
Figma) turning slowly on a dark teal inlay in the gazebo's floor, a column of light rising from the pool to the dome,
five glowing orbs with trails circling the card, and the column and the pool's light shifting through the element
colours; motes in the element colours rise off the gazebo's finial, so it shows over the roof from the street.
The fountain model streams Atomic (whole), so a player who joins far away (at their plot) gets the client magic
once it streams in, not a tagged model without its pool and card.
WildService adds the card's turning and bobbing, rising sparkles, a light, breathing water and a faint disc for the
12-stud healing area (the Frontier's spring is the same fountain). It replaced the free "Better Low
Poly Fountain" by scene_boy (the old HealingSpring prop slot, its model in the place's `PlaceProps`, copy
`assets/place-props/HealingSpring.rbxm`, no longer used). **Card Festival Square** (the user's pick C of three
plaza concepts, 2026-10-30; `Config/Plaza`, `Util/PlazaLayout`, `Server/Util/PlazaBuild`, built by SceneryService):
a gazebo with eight cream plaster columns and a stepped teal dome of roof tiles over the fountain (a warm light and
a lantern inside, a dark teal inlay in its floor; matte mid tones, since white plastic and a shiny roof glared in the
sun and mirrored the sky); a
fan of five giant cards on a long stone plinth (real card art, gold edges, rims in their rarity colour: Cindercub,
Boltlynx, Solarion in the middle, Thunderhorn, Tidecaller) in the north-west corner, facing where new players appear;
three festival carts (the user's pick A of three stall designs; pink PACKS, blue CARDS, green SNACKS): a wooden
box with a slatted front in its colour and white, two big spoked wheels, a handle with a prop leg, turned posts under
a rounded striped canopy with a scalloped fringe and gold corner balls, a warm lantern at one corner, card packs and
boxes on the counter and a chalkboard sign beside it (empty counters otherwise, ready for event NPCs); six round
wooden cafe tables
(a cloth under the top, a little vase of flowers) with three bistro chairs each (round seat on thin dark legs, round
back on two posts); three townsfolk sitting at every other table (the customers' blocky look, a cup in hand; anchored
rigs, so no physics; each client plays the sit animation and lifts their cups to sip now and then, `PlazaNpcController`,
only near the camera with the extras on); string lights sagging from the gazebo's rim to eight lamp posts at the edge;
five curved stone planters along the edge between the lanes (radius 25, 2 wide, grass on top; the card fan's quarter
split where its plinth reaches the edge) holding the lamps, four trees and 32 plants (11 bushes, 21 flowers) (the town's Bush and
Flower props, no shadows); two Cute Pets animals: a cat asleep on its side along the seat of the bench nearest the
spawn, a "z Z z" floating over it, and a puppy running laps along the curve of the gazebo's floor outside the columns
(`Ambient.CRITTERS`, `Wander.orbitTarget`/`orbitStep`); the four benches just outside the gazebo (13.5 studs), facing
the fountain (the Bench slot turns the model round: its seat faces its +Z). The lanes to the shop doors and along the street stay clear (Lune-tested). It replaces the old hand-placed garden: formerly `Workspace.PlazaGarden` (hand-placed in the
place, like TownDecor): 4 cherry trees between the benches (street and shop lanes left open), glowing spotted
mushrooms at the basin, a ring of flowers and bushes, four round grass lawns with clover tufts (one per quarter)
and a low wooden fence round the plaza edge (radius 21, 2 tall) with gaps at the four lanes; Creator Store pieces were stripped to parts, meshes, lights and
particles (the cherry trees came with backdoor scripts). Butterflies (`ButterflyController`, client only,
`Town.BUTTERFLIES`) flutter in loops round the spring, at Forest Falls and at the east trails' start; the lighting is
the day cycle (below; dim warm shop ceiling lights so pale walls never wash out). **Portal Worlds** (spec
`2026-10-30-town-portal-worlds-design.md`): each portal stands in its own walk-to area at the end of a trail from the
street's end (`Town.PORTAL_AREAS`, `Util/PortalTrails`): the Wild by the pool at **Forest Falls** (185, -118; south-east:
giant trees, a waterfall of scrolling streak sheets into a turquoise pool, mossy boulders, flowers, lily pads, glowing
mushrooms, fireflies, falling leaves), the Frontier on **Frostpeak**'s snowy rise (182, 128, 10 studs up; north-east: a
snow-capped peak, frosted pines with lightly snowed ones on the grass below, a frozen waterfall of ice columns over a
frozen pond, icicles, drifting snow, an aurora of hanging curtain beams), the Arena at the end of **Ember Canyon**
(-205, 0; west: striped red sandstone walls, a lava river and pool past the walkable floor, saguaros, the portal on the
sand between torch pillars, floating embers). Walks: about 8-9 s to the east portals, 6 s to the Arena (the
user kept the map's spots). Trails are paved terrain with the portal's glowing line along them; a wooden arch with the
area's name stands where each trail leaves the island (gaps in the hedge), and "This way" signposts point the way
(`Town.SIGNPOSTS`, `Server/Util/TrailProps`). The invisible walls follow `Town.WALK_EDGE` (the island plus the trails and
clearings). The scenery is built at server start from `Config/Scenery` (terrain via `Util/TownTerrain`, props by
`SceneryService`); a grove of trees fills the hill between the east trails. **The portals grow out of their worlds**
(portals remodel, spec `2026-10-30-town-portals-design`, the user's pick A of three concepts, 2026-10-30): Blender
models about 28 studs tall in slots of their own (`Town.SLOTS` `PortalWild`, `PortalFrontier`, `PortalArena`;
`tools/blender/build_portal_<world>.py` on `portal_kit.py`, sources in `assets/blender/Portal<World>/`, saved as
`assets/props/Portal<World>.rbxm`): at Forest Falls an arch of thick twisting roots crossing over the top, moss, vines
with glowing flowers, a trickle of water from the right roots into a glowing pool; at Frostpeak a ring of faceted blue
ice crystals with icicles and snow caps rising out of a blue-grey drift, frosty mist; at Ember Canyon black-purple
obsidian shards leaning into an uneven pointed arch with lava cracks, two lava streams dripping into a molten pool and
rising embers (on the sand between the torches: the round stone platform went). A swirl in the world's colours fills
each opening (the user asked for one disk in the middle covering the whole opening, with effects): three image layers
on a still, see-through panel in the opening (a SurfaceGui per face, drawn within 300 studs), sized 1.2 times the
opening's larger side so the swirl's fading disc covers it (`Town.PORTAL_FX.VORTEX_SCALE`; the overflow hides behind the
frame): a glowing core in a deep shade (`portal-glow.png`, made in code) that fills the gaps and breathes, the swirl
(`portal-vortex.png`, Figma, white with clear gaps between its arms, tinted by a gradient) and a smaller inner swirl
turning the other way, faster; the portal's light breathes with the core. The client turns the images in their own
plane (ImageLabel.Rotation; `PortalFxController`, `Util/PortalLooks.animate`, within 150 studs with the extras on,
looking the panels up every frame). A flat beam turned with its part twisted out of the opening and read as several
disks tumbling; a swirl filling the opening as a stretched beam wobbled and swung past the arch tops.
Props stands a model's lowest point on the ground, but the builds sink roots, shards and the drift below their Blender
ground: each look names a ground part and its Blender height (`PORTAL_LOOKS.ground`) and the model sinks until it
stands there (`Util/PortalLooks.groundShift`; a Lune test checks the heights against the saved files). The looks live in `Town.PORTAL_LOOKS` (vortex colours and spin, light, glowing parts, at most 4
effects with the vortex); `Server/Util/PortalBuild` dresses a placed model from its named parts (`Frame`, `Opening`,
`Fx_*` spots, glow parts; `Util/PortalLooks.parts`, checked by a Lune test on the saved files) and the model streams in
whole (tag `TownPortal`). Until a portal's model is saved, today's frame stands there (`Util/PortalLooks.slot`) with its
old look (`Town.PORTAL_EFFECTS`: ring and frame glow tinted, a soft light, 2 emitters), which also colours the trail
arches and glowing paths. The travel rings keep their prompts, hidden behind the new models; each name label floats
3 studs over whichever model stands and shows within 80 studs (`Town.PORTAL_LABEL_DISTANCE`), so it comes into view
down the trail before it climbs off the top of the default camera's view. Area scenery keeps `Town.PORTAL_SCENERY_CLEAR` (13 studs) away. Travel needs the portal: the
Wild goes through its prompt only (the WildTravel remote accepts just "home"), and the Frontier menu's choices only count
within `Town.PORTAL_REACH` (16 studs) of the Frontier portal. Plots stand 24 studs apart. The island is x ±130,
z ±110 (`Town.BOUNDS`): the Baseplate is cut to it and hidden under terrain grass (pavement-type terrain under the street
and plain ground under and 5 studs round each shop, so no blades poke through; Roblox draws terrain 2 studs above its
fill, `TownTerrain.SURFACE_LIFT`). **Day cycle** (`Config/DayCycle`, `Util/DayCycle`, `DayCycleController`): a 19.5-minute
loop, the same for everyone in town in a server: morning 7 min (the longest), afternoon 5, sunset 4, a 2-minute blue night
lit by the street, shop neon, portals and glowing mushrooms (shops stay warm and readable), dawn 1.5; each phase keeps its
sky, haze, bloom and colours, blending into the next over 40 s while the sun creeps across. Each client works the time
out from the server's `DayCycleStart` attribute (no network). Outside the town region (the Wild, the Arena stands, the
boss arenas) the old afternoon look shows at once, so fights never happen at night. **Ambient life** (client only, off
when the frame watchdog sees a slow device or the player set graphics at 3 or below: `Util/FrameWatchdog`,
`Client/Util/Extras`, `Config/Ambient`): trees near the camera sway (`TreeSwayController`), and six Cute Pets animals
run round their homes, drawn by the summoned-pet code (`TownCritterController`, `Util/Wander`): a fox at the forest edge,
a bunny on the grass by the grove, a capybara on the sidewalk outside the south shops (the tall grass between
the shops hid it), a fawn at Forest Falls, a penguin on Frostpeak, a baby dragon
in Ember Canyon. **Welcome cinematic** (`WelcomeController`, `WelcomeService`, `Config/Welcome`, `Util/WelcomePath`): on a
player's first visit, an 11 s flight past Forest Falls, Frostpeak, over the plaza and past Ember Canyon to their own shop,
as a time-lapse from morning to sunset that holds sunset for the last half; cinema bars, a title, the rest of the UI off
and the player standing still, a Skip button (top right) from the first frame. Code builds the fixed pieces (`Util/TownLayout`, same on every
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
oak middle divider, a price rail and header text on both faces). Glass Showcase and Collector Case → CardCase
(code-built, `Util/CaseLook`, `Town.CASE_LOOK`: a support, a carpet bed, a frame, see-through glass and a neon strip;
the Collector Case's strip is gold, `propColors`). Their cards stand upright in two rows, the back row a stud behind
and raised (`Util/ShowcaseLayout.uprightSlots`, `Config/CaseLayout`), and each turns slowly and bobs over a small
glowing pad with a beam of light in its rarity colour (`CaseSpinController`, each client, within 80 studs,
`Showcase.SPIN`); the card's back shows when it turns away. Condenser → Condenser (code-built, `Town.CONDENSER_LOOK`, restyled
2026-10-30 to match the Grading Station's scan pod: a dark plinth with a violet rim, a white body with a light band, a
glowing card slot and a "✨ CONDENSER" strip, a see-through chamber with a glowing floor in which a violet crystal
ringed by three gold cards spins and bobs, with a ring of small cards below it and one above it turning the other
way, out of step; a white cap with a violet ring. The rings are Rotors moved by `CondenserFxController` on each client
within 80 studs, each with its own `Spin` and `Phase`; no lights). The delivery spot is outside on the sidewalk, left of the doors (`Town.DELIVERY`, built in code): a
concrete platform level with the shop floor, a charcoal mat with a yellow safety border, "📦 DELIVERIES" on its street
face and two black bollards with yellow bands at its street corners; boxes stand on the mat, and stocker pets fetch
them from its doorway side. Delivery boxes are branded cases (the user's pick of three concepts, 2026-10-30;
`StockService`, `Stock.CASE`): printed in the product's colour with darker bands, the product's art in a gold frame
(its UI icon when it has no pack art), its name and an "x24" count pill on the front and back, hand holes on the ends
and the name on the lid, all drawn on the box itself so it travels when carried (a per-product model, Products
`boxProp`, would replace it). Products shelves and up to 12 stock boxes in
the product's colour (3 levels of 4, filling from the bottom; any stock shows at least one; `Util/ShelfStock`,
`Town.SHELF_STOCK`, `Products.color`). Every rack is 7 studs tall with its plates at the same three levels, so they
line up side by side. A shelf whose model isn't a one-sided rack sets its own sides (`Shelves` `stock`): the
Big Display Rack is double-sided, filling each level front then back, with its back rows, packs and tags facing
the back aisle. Packs stand in open cardboard display boxes (`Util/PackModels.displayBox`: the lid folded back,
up to 6 packs showing, front first), each box a share of the shelf's stock; as packs sell the last box empties pack
by pack and boxes go away (`ShelfStock.boxFill`, `Town.SHELF_STOCK.DISPLAY`). They stand at 95% of their full size
or more on every rack (the user's "Bigger", 2026-10-30; Lune-tested), filling the level up to just under the plate
above. Deck boxes stand as little 3D deck
boxes with their lids (`PackModels.deckBox`). The models are Blender builds in `assets/packs` (docs/packs.md);
without them code-built stand-ins show. First Spark Booster Boxes (Products `stockLook = "Booster"`) stand as 2
sealed booster boxes per slot, stacked, printed like their delivery case (`Util/BrandBox`, `SHELF_STOCK.BOOSTERS`;
Products `art` gives them the First Spark phoenix). Card Sleeves (Products `stockLook = "Sleeves"`) show as 2 retail
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
- How stock shows (section 3): packs in open display boxes that empty as they sell (a Small Pack Rack's 24 packs
  over its slots' boxes, 6 packs showing per box), deck boxes as 3D deck boxes, cards in cases upright and turning.
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
  Packs and deck boxes lie face up on the counter as their 3D models (`Util/PackModels`, inside an invisible scan
  target); other products are a box in the product's colour.
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
- Both cases show their cards upright in two rows of three, turning slowly over a pad and a beam in the card's
  rarity colour (section 3), so a Legendary on display reads from across the shop.
- Cards on display leave the binder while shown and come back when removed. A case can't be sold while it holds cards.
- **No quick sell.** Cards only earn money by selling to customers or players, which keeps pulls tied to running the shop.
- **Trading (post-MVP):** player to player trade window.

### 5.7 Pack opening feel (important)
- **A 3D stage** (UI project 3, spec `docs/superpowers/specs/2026-10-29-cards-in-world-and-pack-opening-design.md`):
  client-only parts far above the world (`Util/OpeningStage`, `PackOpening.STAGE_POSITION`): a violet glow fading to
  near-black behind, a warm key light and a blue rim light, and a Scriptable camera (FOV 40, 8 studs back) with
  bloom, a colour grade that dims for big pulls and a depth-of-field blur for the push-ins; letterbox bars and a
  white flash sit on top. The world stays where it is (sound stays at the character, `Util/ListenAtCharacter`; the
  HUD and world tags hide). The opening follows `Util/OpeningFlow` (Ready, Tearing, Stacking, Stacked, Flipping,
  Shown, Stowing, Results; Lune-tested) and closes on a fight, death or respawn.
- **The pack** is the 3D booster pack (`Util/PackModels`, Blender build in `assets/packs`, docs/packs.md) floating in
  the middle, bobbing while a light glides over its foil every couple of seconds (`Util/OpeningPack`,
  `PackOpening.PACK_STAGE`). It's "charged and ready to rip" (the user's pick of four, 2026-10-30): it turns toward the
  mouse or finger (up to 22 degrees, `OpeningLayout.tiltToward`, Lune-tested), blue-white sparks crackle along its
  sides over a soft pulsing glow (`OpeningFx.charge`), and a glowing dashed tear line with a gliding dot shows the
  swipe (gone on the first drag). "Swipe across the top to open" (a 60 px drag over its top; a tap, Space or T works
  too); it squares up as the tear starts.
- **The tear is a little film** (`PackOpening.TEAR`): the bars slide in and the camera pushes in on the tear line,
  the strip parts while light leaks out of the gap and a few foil shards spill, then the snap: the strip flies off
  to the right, a white flash, a short camera shake, the rip burst and a spray of tumbling foil shards, and the
  camera eases back.
- **The cards stack up** (`PackOpening.STACK`): the pack drops, the cards rise out one at a time and land face down
  on a pile with a snap and a slight tilt, and the empty pack goes away. "Tap to flip the first card".
- **Deck boxes** (`Config/Packs` entries with `kind = "Deck"`, opened the same way: carry a box of them, Open T):
  the First Spark Deck Box holds 5 cards, two of them Rare or better (Common, Common, Common/Rare 50/50, Rare 75 /
  Very Rare 25, and a hit slot of Rare 45 / Very Rare 25 / Epic 22 / Legendary 8, against a pack's 68/15/14/3), for
  $9 against a pack's $3. On the stage it is the 3D deck box: "Tap the lid to open" lifts the lid, and its cards
  stack and flip like a pack's. On shelves deck boxes stand as 3D deck boxes; menus (Set Price, Prices, Order Stock)
  show the 3D pack and deck box turned a little (`Util/ProductPicture`).
- **Each tap flips the top card** (`Util/OpeningCards`, `PackOpening.FLIP`), hit slot last: it lifts and turns over
  with a little overshoot, landing big in the middle (its back is hidden once it's past halfway). The next tap zips it
  into a row at the bottom of the screen (`PackOpening.STOW`, `Config/PackOpeningLayout`) and flips the next. Only the
  first flip has a hint ("Tap to flip the first card"); after that the bottom stays clear, since on phones a hint there
  covers the row's prices. Every pull is celebrated by rarity (`Config/CardReveal`, `Util/RevealRules`):
  - **Tease** before the flip: the face-down card glows in its rarity colour, rises and shakes harder and harder
    (Rare 0.5s · Very Rare 0.8s · Epic 1.2s · Legendary 2s; Commons flip at once). Epic and up are cinematic: the
    bars slide in, the stage dims and the camera eases in.
  - **The hit:** the rip burst in the rarity colour, foil shards (Rare 10 · Very Rare 16 · Epic 24 · Legendary 30,
    gold for Legendary and Frontier), and a banner under the card ("RARE!", "VERY RARE!"); Epic and up add turning
    light rays and an aura far behind the card and a pop (taps are ignored 0.6s so a double tap can't skip it);
    Legendary adds a white flash. Frontier cards get the Legendary show ("FRONTIER!").
  - **Alive:** a shown Rare-or-better card floats and tilts, a holo shine sweeps its face (gold on Legendary),
    glints twinkle round it (about 4 a second on Rare, 7.5 gold ones on Legendary), motes rise past it, the aura
    breathes, the rays turn and the banner pulses (`PackOpening.ALIVE`).
  - **Foil** adds a holo shimmer on the face, at least a 0.6s tease and "FOIL" in front of the banner ("FOIL RARE!",
    a plain foil "FOIL!").
  - Big pulls still get the server-wide chat announcement ("Ben pulled a FOIL Solarion!").
- **Results** (a tap after the last card, `PackOpening.RESULTS`, `Util/OpeningResults`): the row's cards fly one by one
  to a lineup in the middle (a quick arc and spin each, 0.085s apart), each landing with a shine and a ring of glints,
  then float and twinkle. A yellow NEW ribbon marks cards the player didn't own before (binder, beasts or on display;
  the server checks before adding them, `Util/NewPulls`, only the first copy in a pack); pills pop in on top (Your
  cards · NEW x2 · pack value · Rarity guide) and a green Continue gives the camera back. The "N left in box" and pity
  pills and the Odds button sit in the top corners during the opening. Laid out for a 667x375 landscape phone below
  Roblox's top bar (`Util/OpeningLayout` sizes the 3D cards from pixels, Lune-tested).
- **Effects** are our own, rendered in Blender (`tools/blender/build_pack_fx.py`, sheets cut by
  `tools/textures/make_flipbooks.py`, PNGs in `assets/ui/fx`, ids in `Config/PackFx`): the rip burst (an 8x8
  flipbook), holo and gold foil shards and four-point glints (4x4 flipbooks), plus a mote, rays, the light leak and
  an aura (`Util/OpeningFx`). No emoji-like confetti. Counts follow the player's graphics level (a quarter at level 1,
  all from level 6; `RevealRules.scaleCount`). Studio at graphics level 1: worst frame 42 ms as the stage shows,
  27 ms or less through the tear, flips and results.
- **Sounds** (`PackOpening.SOUNDS` and `VOLUMES`, free Creator Store sounds, only the opener hears them): a crinkle
  while the strip parts and a rip when it tears off, a card swipe per card stacking up, a card flick per flip; Rare
  and better get a rising tease (cut short when the card lands) and a hit (soft chimes for Rare and Very Rare, a deep
  boom for Epic, orchestral hits for Legendary and Frontier) and a shimmer while the card is alive; the results pop
  per landing card and chime when the lineup is done. Most come from Roblox's licensed libraries (Pro Sound Effects,
  APM) and Daily Sounds (made from scratch); the flip is "card_flip" by f4ngy (Freesound, CC BY).
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
  server's plain card part (0.84 x 1.2 studs, standing upright in two rows, `Config/CaseLayout`; the back drawn on
  its other side), with the asking price in gold in the value row. The full face and back draw within 30 studs
  (`Config/ShopDetail`); further away the card shows a flat picture of its art (a decal) on a card-back blue part, which
  also shows through shop windows (the windows hide 2D screens behind them). To make visitors want to buy, the face glows (it ignores the
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
         before, optional groups (spec `2026-10-28-boss-ladder-design.md`; phases 1-4 done (Wild bosses, groups, Frontier bosses and Gold Seals, the Dungeon and the Prism Hydra): 5.10).

**Battles part 3a: the Frontier.** A second Roblox place in the experience, shared by players from every server.
Not one server for everyone: Roblox fills a Frontier server to the place's Max Players (Creator Hub) and opens more.
The plaza's "The Frontier" portal opens a menu: Explore (any Frontier server) or Join a friend who is in one now.
A teleport is a leave (fights end, the save goes to the next server); your shop pauses and rebuilds from the save
when you come back. Open to everyone ("Recommended Lv 15+"). Same combat as the wild; zones Frostwood Lv 15–25
(Tide, Shade), Stormpeak 25–35 (Volt, Ember), The Rift 35–50 (all five, everything chases); elites 1 in 6; a healing
spring at the entrance and the Dungeon portal (5.10, the final boss). Frontier-only drops: Star Shards (3% normal / 10% elite)
and Frontier cards (3% / 10%; Frostfang, Gale Sprite, Riftwalker, Cinder Titan, Tideborne Kirin, Stormking, never in
packs). Frontier cards look special everywhere: an aurora border and rarity, a FRONTIER chip, a constant
shimmer, an aurora glow in shop cases, a mystery "?" slot ("Found in the Frontier") in the binder until owned; finding
an Epic or Legendary one plays a full-screen reveal and announces it to the server ("✨ Ben found a Frontier card: Stormking!").
Items: `items = { [itemId] = count }`, listed in `Config/Items` (name, icon, description, where to get, how to use)
and changed only by ItemService. The binder has two tabs, Cards and Bag (icon tabs; key I opens the Bag). The Bag
is an inventory window in the middle of the whole screen ("Bag", "1 / 20 slots" in its header): a 5x4 grid of slots (more rows if
needed), filled ones slate with the item icon and an outlined "x2" count, the rest empty; boss items (key fragments,
trophies) are tinted for their boss (`Util/BossTints`: its element's colour, the Hydra's pale prism) with the boss's
ladder number in a corner chip (`ItemRules.bossOf`), so every key looks different; the chosen item's details on the
right in a dark panel (big icon in the same tint, name, "You have 2", What it does / Where to get it / How to use it
boxes). Counts and boss numbers stay at least 14 px tall on screen when the window shrinks for a phone. It scales down to
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
panel (HUD; style kit, teal band) shows the three slots side by side with no scrolling: the card, name, grade pill,
level and star icons, its Power (big, orange), HP / ATK / SPD bars (against the best stats any card reaches,
`CardTips.reference`), its perk (element icon and a few words), "Resting m:ss" in red after fainting, and Summon
(gold) or the green Summoned (tap to unsummon), XP Tonic (icon with a gold badge on its top right corner showing how
many you hold, drawn above Remove; hidden at 0 or Lv 30) and Remove (red). The summoned column glows green with a
SUMMONED tag; the band shows "Summoned: <card>" (or "Nobody summoned") and your PvP record; an empty slot has "Add a
card" (opens the binder). A legend along the bottom names the stat icons once (Power, Health, Attack, Attack Speed), and
every icon without a label has a word tooltip (`Util/Tooltip`; Remove says "Remove from party"). Phones get a smaller card and slimmer bars so every
column fits. One creature is summoned at a time: the server moves
an invisible marker behind you on the ground (`workspace.Creatures`, 20 Hz, teleports when 40+ studs away) and every
client draws the creature on it with walking, breathing and a rarity glow (`docs/creatures.md`). Party cards can't
be displayed or given a job; they can be condensed. While a creature is summoned, a small buff badge above the cash
(bottom-right corner) shows its perk (element icon, colour, +%); hover or tap it for what it does and which card it comes from. Left of it, the party bar (a dark tray,
`Config/Party` BAR) shows your avatar with a PARTY tag (opens Party) and the 3 party slots as small cards: the card's
art in its rarity rim with "Lv 4", a key chip 1 / 2 / 3; the summoned one lifts, glows blue and has an OUT tag; an empty
one is a dashed "+"; a resting one dims with an hourglass over "2:41". Tap a slot or press 1 / 2 / 3 to summon it, again to unsummon;
an empty one picks a card in the binder. Hovering a card (or holding a finger on it for `UIStyle.LONG_PRESS`, which
then doesn't summon) shows its tooltip above the bar (`CardTips.copy`): the card, name, grade, level, Power, HP / ATK
/ SPD bars, its perk and the resting countdown, so you don't need the binder. When the party changes, a toast says
so ("Cindercub joined your party!", "Cindercub swapped in for Ashbeak!", "Ashbeak left your party";
`PartyRules.changes` / `changeText`, Lune-tested) and the slot a card joins pops up with a white rim
(`Party.BAR.POP`). Empty Party and Jobs slots have Add card / Assign buttons that open the binder. Perks, from the summoned card
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
A machine bought in the build menu (Fixtures, shop Lv 8, $5,000; `Config/Shelves` kind `Grading`), a code-built
futuristic scan pod (the user's pick of six concepts, 2026-10-30, then made bigger: a 6 x 6 spot, about 9 studs tall
with its hologram; `Town.GRADING_LOOK`): a dark plinth with a cyan rim, a white body with a light band, a slot and a
GRADING strip, and on top a see-through column where a gold card floats in a beam of light, spinning and bobbing, with
a ring of small cards below it and one above it circling the other way (Rotors moved on each client by
`CondenserFxController`), under a cap with a hologram ring showing "S". Press E on it: pick a card and the
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

Boss items at the station: Grading Seals stand in for missing duplicates (up to half a step); a Gold Seal pays one
step's cash, any step except a Legendary's A -> S (`CondenseRules.goldSealAllowed`, checked on the server).

### 5.10 Boss ladder (phases 1-4: Wild bosses 1-3, groups, Frontier bosses 4-6, the Dungeon and the Prism Hydra)

Spec `docs/superpowers/specs/2026-10-28-boss-ladder-design.md`. Each boss drops what helps you beat the next and
the fragments that open it. Numbers in `Config/Bosses`, rules in `Util/BossRules` (pure, Lune-tested), saved progress
and rewards in `BossService`.

| # | Boss | Arena | Element | Lv | HP / ATK / SPD | Recommended Power | Mechanic | Shop Lv | Opens with |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Meadow Warden | Meadow | Bloom | 6 | 1800 / 11 / 8 | 200 | - | 3 | open |
| 2 | Cave Brood Queen | Caves | Shade | 11 | 3900 / 16 / 12 | 350 | heals 15% below half HP, every 12 s, 3 times at most | 5 | 3 Brood Queen Key Fragments |
| 3 | Ember Colossus | Ember Ridge | Ember | 16 | 7200 / 22 / 9 | 650 | enrages below half HP (ATK x1.5) | 8 | 5 Colossus Key Fragments |
| 4 | Frost Tyrant | Frontier, Frostwood | Tide | 22 | 11500 / 27 / 9 | 1100 | ice shield (6% HP) every 20 s; breaking it stuns it 3 s | 12 | 5 Frost Tyrant Key Fragments |
| 5 | Storm Sovereign | Frontier, Stormpeak | Volt | 32 | 14500 / 26 / 14 | 1500 | thunderclap every 14 s (2.5 s base): stuns your creatures, shorter on fast ones | 15 | 8 Sovereign Key Fragments |
| 6 | Rift Devourer | Frontier, The Rift | Shade | 45 | 23000 / 26 / 10 | 1900 | 2 Rift Spawn at 50% HP (5% HP each): hit first, boss takes half damage meanwhile | 18 | 8 Devourer Key Fragments |
| 7 | Prism Hydra | the Dungeon (after 3 rooms) | by phase | 55 | 40000 / 23 / 11 | 2400 | five phases, one per element (below) | 22 | 10 Hydra Key Fragments |

Shop Lv (`shopLevel`, `BossRules.levelReady`): the shop level every player needs to fight that boss, solo or in a
group, checked before its fragments and every time (not only the first). Below it the board shows "Opens at shop level n".

| Boss | Cash / XP per win | Drops (full loot) | First clear | Daily bonus |
|---|---|---|---|---|
| Meadow Warden | $36 / 620 | XP Tonic 60% (1-2), Brood Queen fragment 70% | 3 fragments, trophy, 3 XP Tonics | 2 XP Tonics |
| Cave Brood Queen | $66 / 1360 | XP Tonic 60% (1-3), Star Shard 15%, Colossus fragment 60% | 3 fragments, trophy, 3 XP Tonics | 2 XP Tonics |
| Ember Colossus | $96 / 2220 | Grading Seal 35%, XP Tonic 40% (2-3), Frost Tyrant fragment 60% | 3 fragments, trophy, 3 Grading Seals | 2 Grading Seals |
| Frost Tyrant | $150 / 3600 | Grading Seal 40%, Star Shard 25% (1-2), Sovereign fragment 60% | 3 fragments, trophy, 3 Grading Seals | 2 Grading Seals |
| Storm Sovereign | $210 / 5200 | Gold Seal 25%, Devourer fragment 55% | 3 fragments, trophy, 1 Gold Seal | 1 Gold Seal |
| Rift Devourer | $280 / 7400 | Gold Seal 30%, Star Shard 30% (1-2), Hydra fragment 50% | 3 fragments, trophy, 3 Gold Seals | 1 Gold Seal |
| Prism Hydra | $400 / 10000 | Gold Seal 40%, Star Shard 40% (1-2), Grading Seal 40% (1-2), XP Tonic 50% (2-3) | trophy, 5 each of Gold Seals, Star Shards, Grading Seals, XP Tonics | 2 Gold Seals |

- **Arenas:** a fenced ring beside each zone (its +X side), joined by a path, with a gate (prompt "Fight boss",
  recommended Power on it and on a sign). The gate checks distance (12 studs), the key and that you can fight; the
  key's fragments are used the first time only. The boss is spawned for you (or your group), stands still, and always goes when
  the fight ends (win, loss or run). One fight per arena: while someone fights there, the gate tells others to wait (or to join a
  group, below). The ring (radius 36) seals while a fight runs: the members are moved just inside the gate and a
  see-through wall rises all round (`BARRIER_*`), dropping when the fight ends for any reason. Anyone else inside the ring when it seals, and a group member who
  leaves a fight that goes on, is moved out through the gate. Boss fights may last 420 s (`Combat.BOSS_MAX_FIGHT_SECONDS`), the leash is 42
  studs, stuns on a boss last at most 1 s.
- **Intro:** a boss fight opens with 6 s of drama (`INTRO_*`): the camera flies to the boss, its name and title show
  (e.g. "Guardian of the Meadow"), it roars (camera shake), then 3, 2, 1, FIGHT. Nothing moves and no button works
  until then. A low ambient drone plays through the fight ("Tension Repeat Drones 22", `MUSIC_ID`, volume 0.1: a bed under the
  attack and skill sounds to come); heals and enrages shake the camera.
- **Frontier bosses (phase 3):** their arenas are in the Frontier place (each place builds only its own bosses;
  the board lists all 6 and names the other place). Shield: the boss's HP bar shows "+n shield", "Ice shield!" and
  "Shield broken!" banners. Thunderclap: "Thunderclap!" and "Stunned" over each creature. Adds: "Rift Spawn!", the
  Spawn appear beside the boss (real monsters held still) with small HP bars under the boss bar; auto-attacks go to
  them first, abilities can still hit the boss (at half damage while any Spawn stands); the fight is won when the
  boss falls.
- **Loot on the ground:** a win's repeatable items (drops, daily bonus) pop out of the boss and scatter
  round it (4-10 studs, `LOOT_*`), each player's own drops seen only by them (LootController). Walking over one picks it
  up (the server checks it's yours and within 8 studs; one request names every drop in reach, up to
  `LOOT_PICKUP_BATCH`). Nothing is collected by itself: loot stays until you pick it up, and whatever is still on the
  ground when you leave or teleport is gone. Drops land on the ground only, never on a player or creature standing
  there. Cash and XP stay instant. The first-clear chest (fragments,
  trophy) goes straight into the Bag: it's one-time and the clear is saved at once.
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
- **UI:** the Bosses HUD tile (K, trophy icon) opens the Boss Ladder (style kit, red band): a path of seven steps,
  each a disc with the boss's icon (its element's; the Hydra a gem, `Util/BossTints`), its number and name, and a state
  from `BossRules.stepState`: beaten (gold ring, trophy), ready (green glow, check: you can start it now, key fragments
  in hand count, and your best party card's Power is enough), too weak (red ring) or locked (faded, lock: shop level or
  fragments short). A legend under the ladder names the four badges, the path fills gold up to the last boss beaten
  in a row, a gold "Next" tag sits on the first boss still to beat, and each step's tooltip says where it stands
  ("built for 1500 Power", "opens at shop level 15", "needs 8 keys"). It opens on the first step still to beat.
  Tapping a step shows it below in two columns (each scrolls when it doesn't fit, as on phones). **To fight it:** its
  name with a status pill (Beaten / Ready / Too weak / Locked) and its title; pills for its element, where it lives
  (tooltip: the zone and world) and the element to bring (`BossRules.counterElements` on `Combat.BEATS`: "Bring Shade",
  tooltip "Shade cards hit it 1.5x harder"; the Hydra "Bring a mix"); a checklist of what it needs, each row with a
  check, cross or "!" mark: shop level (You: n), its key fragments (n/N tinted for that boss, "Opened" once used,
  "No key needed" for the first; tooltip: the item, that it's used up on the first fight, and where it drops; tapping
  the row while short shows the boss before), and Power (the Power it's built for against your best party card, with
  a bar; a warning, not a lock); then a tinted box with what to do next (`BossRules.lockReason`: level up the shop,
  beat the boss before for n more keys with a "See it" button, level up or change the party with a "Party" button,
  go fight it, or fight again for loot); and its tricks spelled out under "Watch out" (`BossRules.watchOut`: shield,
  thunderclap, helpers, heals, gets angry, or the Hydra's element changes, with their real numbers). A locked boss
  past the "Next" one keeps its tricks a surprise ("???: reach it to find out", `BossRules.revealTricks`; the Hydra's
  element pill reads "???" and shows no element to bring); its needs and rewards always show. **Rewards:** a
  loot pill ("Loot ready" green, or "Loot in 12:34" counting down; tooltip: loot once every 15 min, earlier wins pay
  cash and XP only); each win's drops as slots with a count badge and the chance under each, at the chance your next
  win rolls (soft cap and over-power factors included, gold when shrunk; `BossRules.chanceText` / `countText`), a
  fragment for a boss already opened faded with "-" (it no longer drops); the first-win chest (until beaten) and the
  day's first-win chest as small slots (the payload's `bonusReady`; "Daily bonus collected: back tomorrow" once
  taken); cash and XP every win; "Full drops: n more wins today" (`BossRules.fullDropsLeft`) or "Fewer drops today";
  "Party very strong: fewer drops" above the over-power line. Item slots have rich tooltips (`Tooltip.rich`: the gold
  name, what it does, its odds or chest). Last comes the travel button
  (`BossRules.travelChoice`): "Take me there" (gold) to its gate in this place (remote `BossTravel`: validated index,
  `TRAVEL_COOLDOWN` 3 s, only a gate in this place, through the Wild's travel checks), "Go to the Frontier" / "Go home"
  (the normal Frontier travel), or for the Hydra "Enter the Dungeon portal in the Frontier". In a boss
  fight a wide HP bar sits at the top, "Healing!" / "Enraged!" banners pop up, and the end screen lists the loot.
- **Groups (phase 2):** the gate's second prompt (F) "Start group" opens a group; others press "Join group (n/4)"
  within 15 s (`JOIN_SECONDS`), the leader (whose prompt reads "Start now (n/4)", `BossRules.groupPromptText`) can
  press again to start at once, it starts by itself when full (4). The Fight and group prompts have separate limiters.
  Every member needs the boss open or its fragments (taken only if the fight starts) and a rested summoned creature,
  and must still be near the gate when it starts (others are left out with a message; if the leader is gone the next
  member leads). One boss for the group: HP x (1 + 0.8 (n - 1)), ATK x (1 + 0.15 (n - 1)) (`BossRules.groupStats`;
  the Frontier bosses use their own `groupAtkStep`, 0.35 / 0.35 / 0.5, because Legendary parties shrug off the
  default), and it hits one more creature per attack per extra player (`GROUP_SWINGS_STEP`, never more targets than
  players) so a group can't hide behind spare bodies. Wave heals only its user's own creatures (stacked Waves from a
  whole group out-healed any boss). Tuned with `lune run tools/balance/bosses [fights] [players]`: at the recommended
  Power a 2-4 player group wins, a typical party (best card at it, two at 60%) 60-80%, boss 6 with 4 players 80%.
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
- **Boss skills keep a gap:** a boss's shield, heal and thunderclap never come back to back (`Combat.BOSS_SKILL_GAP`
  6 s between any two), and heals run out (`heal.uses`: the Cave Brood Queen 3, the Prism Hydra's Bloom phase 2).
  Recommended parties now beat the Brood Queen 42% of the time (was 20%: her heals stacked).
- **Death:** a beaten boss lies there for `DEATH_SECONDS` (4) before it goes, so clients can play its fall (the
  Prism Hydra's heads drop one by one, the outer ones first).
- Studio: `/item <id> <n>`, `/boss <n>` (to boss n's gate), `/boss <n> fight` and `/boss <n> group` (use that prompt).
- Boss models are placeholders (monster shapes at 2.5-3.4x) except the Prism Hydra (below).

#### The Dungeon and the Prism Hydra (phase 4)

Spec `docs/superpowers/specs/2026-10-29-dungeon-final-boss-design.md`. The ladder's last step, about 30-45 hours in.
- **The place:** a third place (id 79143483483478, `Config/Places.DUNGEON_PLACE_ID`; `dungeon.project.json`, port
  34874, `PlaceKind = "Dungeon"`, `Place.isDungeon`). No plots, no shop. One run per reserved server.
- **Getting in:** the Frontier's Dungeon portal (`DungeonGateService`): "Enter" alone or "Start group" / "Join
  group" (2-4, 15 s, the leader starts early, like boss gates). Every member needs shop level 22, the Hydra open or 10
  Hydra Key Fragments (the Rift Devourer drops them: 50% per full loot, 3 in its first clear), and a creature ready to
  fight. Then one teleport takes them into a new reserved Dungeon server (`TeleportData.runSize`). The fragments are
  taken only when the Hydra fight first starts, so a lost run costs none.
- **The run (`DungeonService`, `Util/DungeonRules`):** a player joins the run once their save has loaded; the rooms
  stay shut ("Waiting for n more players to load...") until everyone the teleport brought has loaded
  (`DungeonRules.readyToStart`; after `ARRIVAL_WAIT` 60 s a player who never came, e.g. a failed teleport, is left
  behind). Then three rooms open in turn, each a sealed ring with a "Fight" gate. Its pack of elites appears (`Config/Dungeon.ROOMS`:
  2 Frost Wisp/Shade Lynx at Lv 45, 2 Storm Hawk/Lava Brute at Lv 47, 3 Rift Horror/Prism Crab/Lava Brute at Lv 50;
  elite stats with ATK x0.35, `PACK_SCALE`, scaled to the group like a boss, with swings) and each monster gets a
  small HP bar. Creatures keep their HP from room to room; a creature that faints is out for the rest of the run
  (even once its normal rest is over); no spring, no healing. A room win pays the pack's elite XP and cash, no cards
  or items, and opens the door on. A player whose whole party is down (they stay in the fight until it ends), who runs
  or who leaves is out: back to the Frontier after `OUT_DELAY`. Latecomers after the first fight go back too. The
  run line (top left) shows "Room n of 3" / "The Prism Hydra's chamber" with a Leave button (tap twice). On phones
  (`UIKit.isPhone`: touch only or a screen under 500 px tall) both are smaller and hide during fights.
- **The Prism Hydra** ("Crown of Every Element"): in the chamber after room 3 (`BossService.StartRun` with the run's
  HP). Five phases by HP (`phases`, `BattleSim` with `BossRules.phaseAt`: forward only, a heal never takes it back):
  100-80% Tide ice shield, 80-60% Volt thunderclap, 60-40% Shade 2 Rift Spawn, 40-20% Bloom heal (5% every 20 s),
  under 20% Ember enrage (x1.15). Each phase switches its element (so the element wheel changes mid-fight), shows a
  "Volt phase!" banner and lights that element's head on its model (marker attribute `Phase`). Tuned with the
  balance tool (it now runs the three rooms first): solo, best card at 2400 plus two at 60% wins about 50%, one maxed
  card with two Lv 1s 40%, three at 2400 75%, three maxed 88%; the recommended party reaches it with about 74% HP;
  groups: 2 players 60%, 4 players 50% (typical party), group ATK step 0.25.
- **Conquest:** the first clear shows a full-screen "DUNGEON CONQUERED", gives the chest straight into the Bag
  (trophy, 5 each of the four items), the title "Dungeon Conqueror" over your name in every place (player attribute
  `Title`, from the saved first clear, `Boss.clearTitle`; TitleController) and a chat message in every server of the
  experience ("Ben conquered the Dungeon!", MessagingService topic `BossCleared`, `announceEverywhere`). Then a portal
  home opens in the chamber (pick up your loot first). Later wins: "Victory!", the usual farm protection.
- **The model:** a blocky remodel of the Crystal Titans Rainbow Hydra (`tools/blender/build_prismHydra.py`,
  `assets/monsters/prismHydra.rbxm`) in a faceted low-poly "studded" style from the user's references (our own
  creature): chamfered chunky shapes with small raised square studs over a dark indigo hide, cream horns, muzzles and
  belly, a gold collar and claws, prism crystal shards down its back, glowing gold eyes under heavy brows and a crystal
  gem on each forehead, a long snout and a long tail; all five heads share one colour (so it doesn't read as the famous
  five-coloured dragon; in game only the active phase's head glows); about 6,500 triangles. In game it is scale 7 (about
  25 studs tall), its fighters stand 21 studs off (`ringRadius`), its intro camera further back (`introShot`), and the
  model itself glows (`rainbowAura`, `RAINBOW_AURA`: a coloured outline and a faint colour wash, a Highlight, plus a
  light), slowly cycling through the colours; the model always shows through. Over the glow, soft aurora flames
  (green into cyan into violet) rise off its back (`auroraFlame`, `AURORA_FLAME`: a few see-through flames per back
  bone, started on top of the back, never from inside the body). Boss models with PetRig bones now animate
  like creatures (`Party.CREATURE_STYLE`/`SIGNATURE` keyed by the boss id).
- **Time to reach it:** shop level 22 is 436,223 total shop XP (`Util/LevelMath`): about 9 h to level 10, then roughly
  12k XP an hour from a grown shop, about 42 h in all, inside the 30-45 h target.
- Studio: the Dungeon window (`rojo serve dungeon.project.json`) starts the run for whoever is there; `/room <2-4>`
  opens the doors up to that room and puts you at its gate (4: the chamber), also in the admin panel's Dungeon section. Teleports only work in
  the published game.

---

## 6. Products (stock you sell)

| Product | Wholesale (box) | Units | Market price / unit | Unlock |
|---|---|---|---|---|
| First Spark Booster Pack | $48 / box | 24 | $3.00 | Start |
| Card Sleeves | $30 / box | 20 | $2.50 | Lv 2 |
| Deck Box | $60 / box | 10 | $9.00 | Lv 5 |
| First Spark Booster Box (sealed) | $90 each | 1 | $120 | Lv 7 |
| Set 2 Booster Pack | TBD | 24 | TBD | Lv 10 |

Player can also open their own stock instead of selling it: packs and deck boxes (5 cards each, flipped one at a
time on the 3D stage, section 5.7). Trade-off: sell for safe profit, or gamble on a big pull.

Packs and deck boxes are 3D models everywhere (`Util/PackModels`, `Config/Packs` `model` and `look`): on shelves
(packs in open display boxes), on the opening stage and in the menus. Each pack type has a look (`look =
"FirstSpark"`: the model's SurfaceAppearance textures), so Set 2 is a new texture on the same meshes (docs/packs.md).

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
  view ("Give a job"). The **Jobs** window (style kit, option B of the 2026-10-29 mockups) explains the rules once
  in three chips (faster cards work quicker, stronger cards make fewer mistakes, +2 XP a minute), then one row per
  slot: the card's art (hover, or hold a finger, for its stats and perk), name, grade, level, a job chip (icon, and
  what the job does in its tooltip), a live status pill (green working, amber idle or waiting, red after a slip;
  updated in place, so tooltips stay up), an XP bar with "Lv 18 in 9 min" (`JobRules.minutesToNext`), Speed and
  Mistakes in kid words with the number under ("Fast · x1.46 work speed", "Some mistakes · 11% of the time";
  `JobRules.speedWord` / `mistakeWord`, thresholds in `Jobs.SPEED_WORDS` / `MISTAKE_WORDS`), and two buttons:
  **Switch job** (remote `SwitchJob(slot)`: the card takes the other job without leaving its slot,
  `JobRules.nextJob`) and Stop working. A free slot shows "+" and Pick a card (opens the binder); a locked one says
  when it opens or offers the pass. The window is only as tall as its rows.
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
├── dungeon.project.json        # Rojo project for the Dungeon place (same src, PlaceKind = "Dungeon", port 34874)
├── wally.toml
├── tests/                      # Lune unit tests for pure modules: lune run tests/run
├── assets/creatures/           # creature models (.rbxm) → ReplicatedStorage.CreatureModels (docs/creatures.md)
├── assets/monsters/            # wild monster models (.rbxm) → ReplicatedStorage.MonsterModels
├── assets/props/               # town prop models (.rbxm) → ReplicatedStorage.PropModels (docs/props.md)
├── assets/town/                # hand-placed town scenery (TownDecor.rbxm) → Workspace.TownDecor
├── assets/packs/               # pack, deck box and display box models (.rbxm) → ReplicatedStorage.PackModels (docs/packs.md)
├── assets/ui/fx/               # pack opening effect sheets rendered in Blender, uploaded as images (Config/PackFx)
├── tools/blender/              # Blender build scripts: creatures, bosses, the pack models and effects (pack_kit.py), the plaza fountain, the town portals (portal_kit.py)
├── tools/textures/             # pack textures and flipbook sheets (Pillow)
└── src/
    ├── server/                 # → ServerScriptService
    │   ├── init.server.luau    # boots services
    │   ├── Services/
    │   │   ├── DataService.luau      # ProfileStore, load/save, defaults
    │   │   ├── PlotService.luau      # claim/release plots, modern shop shells (glass front, sliding doors, sign band, roof)
    │   │   ├── TownService.luau      # main town: ground, street, plaza, decor props, portals, walls, trail lines, signs, lighting
    │   │   ├── SceneryService.luau   # main town: terrain and scenery round the town and in the three portal areas (Config/Scenery)
    │   │   ├── WelcomeService.luau   # the first-visit welcome cinematic's saved flag (SeenWelcome)
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
    │   │   ├── FrontierService.luau  # teleports: plaza Frontier portal, Explore / Join friend, back home (Dungeon: back to the Frontier)
    │   │   ├── DungeonGateService.luau # Frontier: the Dungeon portal's checks, groups and reserved-server teleport
    │   │   ├── DungeonService.luau   # Dungeon: the run (arrivals, rooms, carried HP, out, the chamber, the way back)
    │   │   ├── DevService.luau       # Studio-only test chat commands
    │   │   └── MonetizationService.luau # game passes (Extra Job Slot), cached checks, purchases
    │   └── Util/
    │       ├── Migrations.luau       # save migrations (pure, Lune-tested)
    │       ├── NpcMotion.luau        # NPC rigs, animations and path walking (customers and workers)
    │       ├── SaleRules.luau        # player-to-player buy check (pure, Lune-tested)
    │       ├── BattleSim.luau        # seeded fight simulation: packs, boss mechanics and phases, carried HP (pure, Lune-tested)
    │       ├── DungeonBuilder.luau   # the Dungeon's cavern: rooms, barriers, doors, crystals, lighting
    │       ├── PlazaBuild.luau       # the Card Festival Square: gazebo, card fan, stalls, cafe sets and townsfolk, lights, planters
    │       ├── BloomFountain.luau    # the healing spring's Elemental Bloom lotus fountain
    │       ├── PortalBuild.luau      # dresses a town portal model: vortex, glow, effects, light (and the old frame's emitters)
    │       ├── ScenePieces.luau      # anchored parts and scaled prop copies for the code-built scenery
    │       └── RateLimiter.luau      # per-player remote cooldowns
    ├── client/                 # → StarterPlayerScripts
    │   ├── init.client.luau
    │   ├── Controllers/
    │   │   ├── UIController.luau       # main ScreenGui, status corner (cash, level + XP), toasts, money toasts
    │   │   ├── OrderController.luau
    │   │   ├── BuildController.luau    # Build menu (category tabs, 3D model tiles), shelf prompts, shelf edit menu
    │   │   ├── PlacementController.luau
    │   │   ├── PricingController.luau
    │   │   ├── RegisterController.luau
    │   │   ├── CarryController.luau    # drop carried box
    │   │   ├── PackOpeningController.luau # the 3D pack opening: OpeningFlow, taps and swipes, server results, closes on fights
    │   │   ├── AnnouncementController.luau # big-pull chat messages
    │   │   ├── BinderController.luau   # the binder screen: collection data, the 3D binder's pages (cover, 2x2 pockets with chips), set tabs, Q/E page keys, page counter, Filters panel (F), set progress card, tooltips, Bag tab
    │   │   ├── CardDetailController.luau # the binder's card view: 3D card + copies panel (best first), stat tiles, XP and star bars, party / job buttons
    │   │   ├── ShowcaseController.luau # manage your own card case, marketplace style: listings, details, tooltip, Set price
    │   │   ├── CondenserController.luau # Card Condenser panel: pick card + main copy, preview, Condense
    │   │   ├── GradingController.luau # Grading Station panel: pick card + copy, next grade, cost, Grade Up
    │   │   ├── JobsController.luau      # Jobs window: rule chips, worker rows (card tip, status, XP, speed and mistake words, Switch job), free and locked slots
    │   │   ├── PartyController.luau     # Party HUD button and panel: three columns (Power, bars, perk, rest), Summon, XP Tonic, Remove
    │   │   ├── BuffController.luau      # buff badge (bottom-right) and tooltip for the summoned creature's perk
    │   │   ├── ButterflyController.luau # client butterflies at the plaza spring, Forest Falls and the trails' start
    │   │   ├── DayCycleController.luau # the town's day cycle on this client (afternoon outside town)
    │   │   ├── TreeSwayController.luau # trees near the camera lean in the wind
    │   │   ├── TownCritterController.luau # eight Cute Pets animals running round their homes (or laps, or resting)
    │   │   ├── PlazaNpcController.luau # the plaza's sitting townsfolk: sit animation and sips (client only)
    │   │   ├── FountainFxController.luau # the healing fountain's rune circle, light column and orbs (client only)
    │   │   ├── PortalFxController.luau # spins the town portals' vortexes near the camera (client only)
    │   │   ├── WelcomeController.luau # the first-visit welcome cinematic
    │   │   ├── PriceTagController.luau  # point at / tap your shelf price tags to set the price
    │   │   ├── PartyBarController.luau  # bottom-right party tray: your avatar + 3 party cards, tap or 1/2/3 to summon
    │   │   ├── MonsterController.luau   # draws wild monsters on their markers (model or placeholder); boss rigs, head glow, death
    │   │   ├── DungeonController.luau   # Dungeon: the run line and Leave
    │   │   ├── TitleController.luau     # titles over players' names (Dungeon Conqueror)
    │   │   ├── BattleController.luau    # Fight prompts, Shop button in the wild, fight bar (wild + PvP), boss HP bar and banners, damage numbers, end screen
    │   │   ├── BossBoardController.luau # Bosses HUD tile and the Boss Ladder: path of steps with legend and Next, To fight it checklist, Rewards with odds, Take me there
    │   │   ├── ChallengeController.luau # PvP: Challenge prompt on players, bet popup, incoming challenge popup
    │   │   ├── FrontierController.luau  # Frontier portal menu (Explore, Join friend); home button in the Frontier
    │   │   ├── FrontierRevealController.luau # full-screen reveal when you find a Frontier card
    │   │   ├── RarityGuideController.luau # rarity guide panel (odds from the pack configs)
    │   │   ├── CardInspectorController.luau # the 3D card you tilt and flip from the binder
    │   │   ├── CreatureController.luau  # draws summoned creatures: model or placeholder, motion, glow, name tag
    │   │   ├── CardBuyController.luau  # visitors browse other players' cases (marketplace style); buy from Collector Cases
    │   │   ├── CardEffectsController.luau # displayed cards: card face with price, halo, glows, sparkles, listing bursts
    │   │   └── CaseSpinController.luau # case cards turn and bob over a pad and beam in their rarity colour (within range)
    │   └── Util/
    │       ├── UIKit.luau              # shared UI building helpers and the style (header, close, lip buttons)
    │       ├── Motion.luau             # pop in/out, press squash, bumps
    │       ├── FontStyle.luau          # switches Gotham text to the game fonts (FredokaOne, Nunito)
    │       ├── Hud.luau                # HUD layout: Manage tray, bottom tiles, context tiles, top bar
    │       ├── Icon.luau               # draws a UIIcons icon (or an emoji) into a holder
    │       ├── CardTips.luau           # card tooltips in the style kit: binder card summary, party copy (bars, perk, rest)
    │       ├── CopyCompare.luau        # the kid swap comparison: verdict badge and sentence, IN -> OUT cards, paired stat bars, perk line
    │       ├── Tooltip.luau            # word tooltips for icons without a label (hover, or hold a finger on it); rich item tips
    │       ├── BossTints.luau          # a boss's UI icon and its key fragments' tint (ladder, Bag)
    │       ├── BinderDesk.luau         # the 3D binder's scene: desk, painted lamp light, case, rings, page canvases, set tabs, camera framing, picking by raycast
    │       ├── PageTurner.luau         # the binder's turning page: bending strips with light cards on both sides, shade, shadow, page sound, drag
    │       ├── ListenAtCharacter.luau  # keeps sounds heard at the character while the camera is on a stage (binder, card view)
    │       ├── WorldTags.luau          # switches on-top world tags and bubbles off while a stage scene shows (binder, card view)
    │       ├── CardFace.luau           # draws a card face (front, back, missing) into a frame
    │       ├── OpeningStage.luau       # the opening's 3D stage: backdrop, lights, camera, post effects, bars, flash, shake, sounds
    │       ├── OpeningPack.luau        # the pack (or deck box) on the stage: idle sway, drag, the cinematic tear, the lid
    │       ├── OpeningCards.luau       # the pulled cards: stacking, flips with teases and hits, alive, the row, the lineup
    │       ├── OpeningFx.luau          # the opening's effects: rip burst, foil shards, glints, light leak, rays, aura, motes
    │       ├── OpeningResults.luau     # the opening's screen: tap layer, hint, box and pity pills, odds, results pills, Continue
    │       ├── ProductPicture.luau     # a product's picture in menu rows: 3D pack / deck box, or its icon
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
        │   ├── PackOpening.luau # the 3D opening: stage, camera, tear, stack, flips, alive, results, sounds (client)
        │   ├── PackOpeningLayout.luau # where the opening's cards sit on screen (plain data)
        │   ├── PackFx.luau     # the opening's effect sheets and images (plain data)
        │   ├── UIMotion.luau   # UI motion timings and scales (client)
        │   ├── UIFonts.luau    # the game fonts (client)
        │   ├── UIIcons.luau    # UI icon image ids by name (HUD, top bar, customer bubbles)
        │   ├── IconTips.luau   # the words each label-less icon's tooltip shows
        │   ├── HudLayout.luau  # HUD tile sizes, fan arc, colours (client)
        │   ├── CardReveal.luau # how big each pull's reveal is: tease, rays, spotlight, sparks, banner (plain data)
        │   ├── CardDesign.luau # card face layout, colours and image ids (client)
        │   ├── Collection.luau # binder request limits
        │   ├── BinderDesk.luau # the 3D binder: stage, camera, page and pocket sizes, tabs, desk colours, page turns, the lift
        │   ├── Showcase.luau   # card case prices, customer card chance, the cards' spin, pad and beam
        │   ├── CaseLayout.luau # upright case cards: size, columns, spacing, rows (plain data)
        │   ├── Condenser.luau  # Card Condenser cooldown and use distance
        │   ├── Grading.luau    # Grading Station costs by rarity and grade, cooldown, use distance
        │   ├── Jobs.luau       # shop job slots, speeds, mistakes, work XP
        │   ├── Party.luau      # party size, perks, creature size, motion, glow
        │   ├── Combat.luau     # attack timing, element wheel, abilities, run, rest, spring
        │   ├── Wild.luau       # wild zones, monster species, spawns, rewards
        │   ├── Pvp.luau        # challenge timings, bet cap and steps, arena layout
        │   ├── Frontier.luau   # Frontier zones, species, drops (same shape as Wild)
        │   ├── Dungeon.luau    # the Dungeon: rooms and packs, timings, layout, lighting
        │   ├── Items.luau      # every item: name, icon, description; stack limit
        │   ├── Bosses.luau     # boss ladder: bosses, drops, chests, farm protection, arenas
        │   ├── Town.luau       # main town: prop slots, decor layout, shop shell sizes, plot themes, portal areas, trails, walk edge, signposts
        │   ├── Scenery.luau    # terrain shapes and scenery round the town and in the portal areas (plain data)
        │   ├── DayCycle.luau   # the day cycle's phases and looks (plain data)
        │   ├── Ambient.luau    # tree sway, the frame watchdog, the town's animals (plain data)
        │   ├── Welcome.luau    # the welcome cinematic's flight (plain data)
        │   ├── Plaza.luau      # the Card Festival Square plaza (plain data)
        │   ├── Places.luau     # place ids, Frontier portal spot
        │   ├── CardList.luau   # every card row (Set 1 and Frontier), plain data
        │   ├── CardEffects.luau # per-rarity effects on displayed cards (client)
        │   ├── ShopDetail.luau # how far each client draws shop screens and full card faces (plain data)
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
            ├── JobRules.luau      # job speed, mistakes and slots, their kid words, next job, minutes to a level (pure, Lune-tested)
            ├── CombatMath.luau    # attack interval, damage, elements, run chance, XP split, rewards (pure, Lune-tested)
            ├── PvpRules.luau      # PvP bet cap, valid bets, payouts, record (pure, Lune-tested)
            ├── ItemRules.luau     # item inventory rules (pure, Lune-tested)
            ├── Place.luau         # which place this is; its wild-map config
            ├── TownLayout.luau    # where every town decoration goes (pure, Lune-tested)
            ├── PortalTrails.luau  # portal trails, the walkable edge, portal reach (pure, Lune-tested)
            ├── TownTerrain.luau   # the town's terrain as fills; ground height (pure, Lune-tested)
            ├── DayCycle.luau      # the day cycle's phases and blended looks (pure, Lune-tested)
            ├── SkyLook.luau       # applies a day cycle look to Lighting
            ├── FrameWatchdog.luau # turns the extras off on slow frames (pure, Lune-tested)
            ├── Wander.luau        # ambient animals wandering round home (pure, Lune-tested)
            ├── WelcomePath.luau   # the welcome cinematic's camera path (pure, Lune-tested)
            ├── PlazaLayout.luau   # the Card Festival Square's placements, giant cards, string lights, lotus petals, chairs, planter plants (pure, Lune-tested)
            ├── PortalLooks.luau   # which model stands at a portal, its label height, the parts and effects a look needs (pure, Lune-tested)
            ├── Props.luau         # place swappable prop models (assets/props) or part stand-ins; server town, client ghosts
            ├── PropFit.luau       # prop fit sizes with YawOffset, register counter rows (pure, Lune-tested)
            ├── ShelfStock.luau    # stock boxes, display box fill and price tags on shelves (pure, Lune-tested)
            ├── PackModels.luau    # the 3D pack, deck box and display box (assets/packs, or stand-ins), dressed in a pack's look
            ├── CaseLook.luau      # the code-built CardCase prop: support, carpet, frame, glass, strip
            ├── ShowcaseLayout.luau # upright case card slots in rows (pure, Lune-tested)
            ├── OpeningFlow.luau   # the opening's phases and what a tap does (pure, Lune-tested)
            ├── OpeningLayout.luau # stage depths for on-screen card sizes, the row and the lineup (pure, Lune-tested)
            ├── PartyRules.luau    # perk strength and text, party changes and their toasts (pure, Lune-tested)
            ├── CreatureMotion.luau # breathing, hop, waddle, hover poses (pure, Lune-tested)
            ├── CardRules.luau     # card market value and price limits
            ├── RevealRules.luau   # a card's reveal plan from rarity, foil and set (pure, Lune-tested)
            ├── BinderSpreads.luau # binder spreads, card ranges, which page a card is on, the page counter (pure, Lune-tested)
            ├── PageCurl.luau      # a turning page's bend, its strips, drag-to-turn, fast-turn pacing, swipes and taps (pure, Lune-tested)
            ├── BinderFit.luau     # the 3D binder's pockets on a page and the camera fit for a screen rectangle (pure, Lune-tested)
            ├── BinderGesture.luau # who owns a press on the 3D binder: one pointer, lost releases, holds vs swipes (pure, Lune-tested)
            ├── OddsRules.luau     # pull odds per card from a pack's slots (pure, Lune-tested)
            ├── PityRules.luau     # pack pity: when a hit slot is raised to a Legendary or Epic (pure, Lune-tested)
            ├── BossRules.luau     # boss unlocks, loot cooldown, soft cap, over-power, phases, board words (pure, Lune-tested)
            ├── DungeonRules.luau  # the run: carried HP, out, run size, packs (pure, Lune-tested)
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

### 10.4 Player data schema (v13)
```lua
{
    version = 13,
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
    seenWelcome = false,    -- saw the first-visit welcome cinematic (WelcomeService)
}
```
Bump `version` and write a migration whenever the shape changes.
Template and types live in `DataService.luau`. Packs are opened straight from carried boxes, so there is no
separate unopened-packs inventory; unsold stock is saved as `boxes` rather than a backroom count.

Loading is defensive: unknown IDs are dropped, prices re-clamped, level recomputed from XP, and saved shelves
that no longer fit are skipped (cards from a skipped case go back to the binder).
When a player leaves, customers put picked-up stock and cards back before the save.

Schema history: v1 first release; v2 moved displayed cards onto `layout` entries and dropped the unused `showcase` list; v3 added the `beasts` table; v4 made stars start at 0 (old star counts drop by one); v5 gave every copy a grade (rolled per copy on upgrade); v6 added `jobs`; v7 added `party`; v8 added `resting`; v9 added `pvp`; v10 added `items`; v11 added `pity`; v12 added `bosses`; v13 added `seenWelcome` (true for everyone who played before it, so the cinematic only greets new players). A service that didn't load for a player (e.g. no free plot) never overwrites
their saved data.

### 10.6 UI style and HUD
Specs: `docs/superpowers/specs/2026-10-23-ui-restyle-design.md`, then look E in
`docs/superpowers/specs/2026-10-29-collection-screens-ui-design.md`.
- **Style** (`Util/UIKit` with the tokens in `Config/UIStyle`, look E "bold hybrid", chosen to suit kids, teens and
  adults): dark slate panel bodies with a thick near-black outline and a drop lip, a coloured header band per window
  (`UIKit.panel(parent, name, title, band)`: Party teal, binder and card detail blue, Boss ladder red, Bag orange,
  others teal) with an outlined white title and a dark line under it, a red close button on the top-right corner,
  slate rows, candy buttons (the colour darkening down the face to a bottom lip, a thick outline, outlined white
  text; navy text on light colours): gold for the main action, blue (`Colors.Secondary`) for other choices, red to
  remove or leave, each with an icon (`UIKit.iconButton`). Helpers: `outlined` (text outline), `pill` (rarity,
  grade, element and count chips), `bar` and `statRow` (chunky green bars), `stars` (star icons, never the
  character), `textSize` (body 15, small 13, name 22, number 23, title 28; 85% on phones). Colour rules on every
  screen: rarity from `Config/Rarities`, elements from `Cards.ELEMENTS` with their icons, grades S gold / A blue / B
  green / C grey, money green with the Cash icon, Power orange with the Power icon, green good, red bad, gold for hints
  and the selected thing. Kid-friendly: a verdict, a picture or a bar first, numbers second, few words.
- **Word tooltips** (`Util/Tooltip`, words in `Config/IconTips`): every icon shown without a label (stat icons,
  Power, stars, Cash, Copies, elements, grade pills, icon-only buttons) names itself in a small dark tip with a gold
  outline, just the name (Power, Health, Attack, Attack Speed): hover with a mouse, hold a finger on it for
  `UIStyle.LONG_PRESS` on touch. One tip per ScreenGui, over everything, above the thing (below it near the top edge,
  `UiLayout.above`); it hides when the pointer leaves, the finger lifts or the thing hides. Roblox sends MouseEnter to
  things under another window too, so a covered thing (checked with `GetGuiObjectsAtPosition`) shows no tip.
  `Tooltip.rich(target, title, lines)` shows a gold title over a few lines (coloured lines allowed; text escaped for
  RichText): the boss ladder's items.
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
  party bar), cash (a green candy pill with outlined white text), then the buff badge; money toasts pop in just
  above. Star Shards have no pill (they show in the Bag and where they're spent). On touch screens (short
  landscape phones, the jump button in the bottom right) it is one column down the right edge from the top right to
  the middle: buff, cash, level, then the party bar, then the money toasts. Nothing sits in the middle of
  the screen. The whole HUD (tiles, Manage
  tray, corner, toasts) shrinks with the screen's height (`HudLayout.SCALE`, `Hud.scaleWith`): full size from 560 px
  tall, down to 70% on short phones (tiles stay over 48 px to tap). Each icon sits over its
  pill's left end. **Icons** (`Config/UIIcons`, `Util/Icon`): glossy cartoon pictures for the
  HUD tiles (Close included), the top bar, the Shop's header and tabs, Bag items and customer mood bubbles
  (Angry, Thinking, Happy); made as four sheets with Figma's image generator and cut by
  `tools/ui-icons/slice_icons.py <sheet> <1-4>` (PNGs in `assets/ui/icons`). Sheet 4 (the style kit) adds Power, Hp,
  Atk, Spd, Xp, Copies, Summon, Remove, Job, KeyFragment (pale, tinted per boss in code), XpTonic, GradingSeal,
  GoldSeal, Travel, Best and Pvp; Bag items use icon names (`Config/Items` `icon`), not emoji. Every icon is kept drawn, tiny and nearly invisible,
  from the moment you join (Roblox only finishes loading an image once it's drawn), so hidden tiles open with
  their icons ready. Names without a picture show as text (⌛ in a bubble). Toasts sit above the bottom row:
  a candy pill (gold, red for errors) with an icon in a round badge (`UIController.Notify(message, isError,
  duration, icon)`; Info by default), popping up from below with a bounce, the icon wiggling in, a shine sweeping
  across, a thin bar counting its time down, then fading and shrinking away; a new toast while one shows bumps it. The fight screen hides the HUD groups.
- **One window at a time** (`UIKit.panel`): opening a main window (Shop, Prices, Jobs, Party, the binder...)
  closes any other; windows marked `Overlay` (the Rarity guide, a case's card picker) open on top without
  closing anything. While the Rarity guide is open, Q/E and swipes don't turn binder pages.
- **Prices** rows show each product's picture beside its name, its market price and how customers feel about your
  price (in the band's colour): packs their real front (`Packs` art, as on the shelves), others their icon
  (`Products.icon`). On the right, your price stands out big in a dark box outlined in the band's colour, with
  small - / + buttons under it (38 px with a mouse, `UIStyle.MIN_TAP` 48 px on phones; sized on every open).
- **Binder** (`Config/Collection`, `Config/BinderDesk`, `Util/BinderSpreads`, `Util/BinderDesk`, `Util/BinderFit`;
  spec `2026-10-29-3d-binder-design.md`, "Collector's Desk"): a real 3D ring binder lying open on a wooden desk on a
  client-only stage far above the world (`BinderDesk.STAGE_POSITION`), seen by a Scriptable camera from a little in
  front (the binder leans back 24 degrees, field of view 30) that frames it in the screen area the corner buttons
  leave free. The desk, case and pages are drawn with SurfaceGuis that ignore the world's light: wood planks, a
  painted warm lamp pool, darker edges, a rounded black leather case with a fine, faint dashed seam and a soft shadow on the desk, dark pages (the binder's own
  surfaces drawn a little brighter under the lamp, `BINDER_BRIGHTNESS`); a chrome ring rail
  with three chunky rings arching over the pages' inner edges; the camera fits the case and the tabs on its right (not equal room both sides), so the binder fills the room it's given. It looks the same at night and at every graphics quality. Built once at start
  and left in the world on its stage (out of sight from the ground), so opening only moves the camera; while shown, world sound stays at the character (`Util/ListenAtCharacter`) and on-top
  world tags are off (`Util/WorldTags`); closing puts the camera, its field of view and the listener back (a
  following camera picks up a character that respawned meanwhile). A fight starting (an elite, an aggro zone) closes
  the binder and the card view so the fight camera takes over. The card view keeps world sound at the character too. One set
  at a time; set dividers are small flat tabs in the set's colour sticking out of the case's right edge (rounded, a thin dark
  edge, the set's name; the open set's sticks out further with a gold edge); a tap counts over the gaps between them
  too, so each takes a 48+ px finger on a phone. Click one to open that set. Each page is a canvas of 2 x 2 pocket slots (8 cards a
  spread on every screen): the card face (`CardFace`) in a plastic sleeve with a soft glint, the chip row under it
  ("x3" with "B · Lv 4 · Job · Party", or "Owned 3"), dark "?" slots for missing cards. Each card's face is built
  once and redrawn only when what it shows changes; the other cards (the open set's first, then every other set's)
  are built in the background a few a frame, so turning to them or opening another set only moves them (building
  nine faces at once cost a 40-70 ms frame). One pointer owns a press at a time (`Util/BinderGesture`): a second
  finger can't take over a dragged page, a release that never came is ended by the next press, and closing the
  binder or leaving the window ends any press or held key. Spread 1's left page
  is the cover: full art (the pack art; leather in the set's colour without one), an embossed border, the title
  (name, "34 / 35 collected") and the set's worth in outlined text over dark fades, a progress bar; then page 1.
  The page counter pill ("2-3 / 9") sits just under the binder, arrows with Q/E key chips either side of it on wide
  screens; phones (under 900 px wide) get compact corner buttons in slim lanes (Cards and Bag down the left edge,
  Rarity guide bottom left, Filters under the close button), no arrows and no progress card. Top right: Filters (F)
  and close. The Filters panel (search, Show All/Owned/Missing, Sort by Set/Value/Copies/Rarity, rarity chips) opens
  on the right while the camera moves the binder into the room left of it. Bottom right: the set's progress card
  (owned / total with a bar, value of your copies). The Bag tab shows its window over the desk. The side and bottom
  HUD hide while the binder is open. Clicks reach the binder by raycast (`BinderDesk.pick`: a pocket, its page or a
  tab). **Turning pages** (`Util/PageTurner`, `Util/PageCurl`): the turning page is a chain of 4 strips hinged at
  the spine that bends as it goes over the rings (the outer edge leads by up to 40 degrees mid-turn, flat at both
  ends), darkening as it stands up and casting a shadow on the page under it, about half a second a turn, with a
  page sound ("Book Page Turn 12", `BinderDesk.TURN_SOUND_ID`). The moving page shows light cards (art and rim,
  each strip only the cards across its slice), built once and parked out of view between turns, so a turn only
  swaps pictures; the next turn of a riffle starts a frame after the last one lands; the page under it shows the next cards at once and the full cards are
  back as it lands. Q / E and the arrows, a tap on a page (right page forward, left page back; also on a "?" or an
  empty pocket), a swipe across the binder, or holding Q / E (repeats every 0.18 s) turn pages; requests add up to
  a target spread and turns get quicker the further there is to go (up to 4 times), so quick presses riffle through
  a set and stop at its first or last spread. A press on a page's outer 30% that moves toward the spine picks the
  page up: it follows the pointer and, let go, finishes the turn past halfway or when flicked on (else falls back).
  A collection change while a page moves is drawn once the pages stop. **Cards:** the pocket under the mouse lights
  up (a warm edge) and rises a little, with the card's tooltip; on touch, holding a finger on a card for
  `UIStyle.LONG_PRESS` without moving shows it until the finger lifts (one that moves is a swipe). The binder's X closes the card view back to the binder while it's up
  (`UIKit.setBackStep`), and the binder itself otherwise; anything else closing the binder closes the card view
  first (it gives the camera back at once, so the binder's own restore comes last). Clicking or tapping an
  owned card lifts it out of its sleeve
  (its pocket shows empty) to the middle of the screen (0.3 s, `BinderDesk.lift`; never straight at the camera, so a
  pocket near the screen's edge doesn't grow off it), then the card view opens on it (the camera moves to the card view's
  stage at the normal field of view); closing the card view brings the binder back on the same spread. The card tooltip (`Util/CardTips`: art, name, set number, rarity / element / best-grade pills, a 2x2 grid of
  strongest Power, copies with any on display, best level, best grade, the worth range and "Click for details") sits
  just outside the binder, level with the pocket (`UiLayout.beside` with the binder's and pocket's screen rects), so
  it never covers a card.
- **Rarity guide** (`RarityGuideController`, `Util/OddsRules`), from the binder's bottom-left button: each rarity
  with a sample card (no spoilers: a card of that rarity you've collected, else the binder's "?" card; redrawn on
  every open; binder tooltips stay off while it's open), its chance per card pulled from a First Spark pack (from `Config/Packs`: Common 74%, Rare
  19.6%, Very Rare 3%, Epic 2.8%, Legendary 0.6%) and "about 1 in N cards"; Frontier cards (drop chances from
  `Config/Frontier`); foil chance and value; grade chances and their stat bonus.
- **Card view** (`CardDetailController` with `CardInspectorController`, `Config/Inspector`): tapping a binder card
  shows it as a real 3D card (about 60% of the screen's height) close in front of the camera (front: the card face;
  back: the card back). While it's up the camera waits at an empty stage high above the world
  (`Inspector.STAGE_POSITION`) with a solid dark sheet behind the card, so nothing of the world (customers, your pet)
  shows; always-on-top tags switch off too. Drag to tilt (it eases back), drag far sideways or press Flip (under the
  card) to turn it over; Legendaries keep their element aura; a gold "BEST COPY" ribbon sits on the card while your
  best copy is shown. The card and the info panel are centred on the screen as a pair (`UiLayout.detailPanelLeft`;
  on narrow screens the panel keeps its right margin first), the card's right edge just left of the panel
  (`UiLayout.inspectorCard`, both Lune-tested).
  The panel (style kit, blue band): the name and worth range (green, Cash icon) in the band; rarity, element, number
  and copies pills; "Your copies, best first" (grade pill, level, star icons, FOIL or count, Power with its icon,
  value; the first wears a gold BEST ribbon, the chosen one a gold outline, with room in the list so it isn't cut off); the chosen copy's Power / HP / ATK / SPD
  tiles, an XP bar to the next level and a next-star bar (duplicates you have / need, red when short; "Max stars"),
  "In your party" or "Working: <job>"; buttons with icons: Add to party (gold), Give a job (blue; when it can't, it
  says why: In party, Working, Jobs at shop Lv N, Slots full (u/s)), side by side; the binder's X closes it. Phones get a slimmer band and no pills
  row (the card face shows rarity and element), so the stats and buttons always fit; the copies list scrolls.
  Closing puts the camera back where it was; dying closes it too. **Add to party** opens a chooser over the panel:
  "Who should <card> replace?" ("Pick a spot for <card>" while a slot is free) and the three slots side by side,
  each card as big as the room allows (name, grade, level, Power, HP / ATK / SPD bars; phones skip the bars), with a
  tinted strip saying what the swap does: "Cindercub has 180 less Power" in red, "... more Power" in green, "Free
  spot: Cindercub goes here" (`CompareRules.swapText`); a hint and a compact Cancel at the bottom. An empty slot
  fills straight away; a filled one opens the kid comparison (`Util/CopyCompare`) titled "Swap <card> for <card>?":
  a big STRONGER / WEAKER badge with the sentence under it ("Cindercub has 180 less Power than Coalbit",
  `CompareRules.powerLine`), the two cards (IN with a green border -> OUT under a dark veil), paired HP / ATK / SPD
  bars where the longer green one wins (hover a bar for its number, an icon for its name), and one line: the element
  icons ("replaces") and the perk it brings or that you lose; then "Swap with <card>" (gold, filling the row) or a
  compact Back. Phones lay the comparison out in two columns. The party bar's toast confirms the change.
- **Shop menu** (`BuildController`; was "Build"): a "Shop" panel (shop icon in its header) with icon tabs Shelves / Cases / Fixtures / Decor (each shelf's
  `category` in `Config/Shelves`; Decor says "coming soon") and a grid of tiles. Each tile shows a 3D picture of
  the real prop model (in its own colours) on a peach backdrop, the name, what it holds, and a price button:
  green price, red when you can't afford it, grey "Lv N" while locked. Buying places it as before.

### 10.5 Performance budget
- Max 6 plots × 4–8 NPCs. NPC movement on server, keep rigs simple.
- Use CollectionService tags for shelves/interactables.
- Stream-friendly: enable StreamingEnabled, test on low-end phone.
- Town props: under 2k triangles per prop model and 60k for the whole town; models over 150 parts use the
  stand-in. Landmark exception: the three portal models up to 4k each (`portal_kit.MAX_TRIANGLES`; root arch 3,472,
  ice ring 2,168, obsidian arch 856), one portal in view at a time. About 120 props (107 outdoors, 2 per register), all anchored, none with scripts.
- Shop screens (SurfaceGuis and BillboardGuis on shop items: card faces and backs, price tags, shelf headers, machine
  screens, box prints) always get a draw distance (`Config/ShopDetail`: 60 studs, full card faces 30; a Lune test fails
  a new one without it). Measured 2026-10-30 in a Play-mode stress test (6 shops x 30 items, 24 customers, 12 workers,
  6 summoned pets, 6 players), PC render CPU from the street: 14.7-17.5 ms and 45-53 fps before, 10.2-12.3 ms and 60 fps
  after; an empty town is 6.5-7.2 ms. Customers, workers, players and shop lights cost about 0.5 ms each; hiding far
  shops' small parts saved only about 0.5 ms, so it isn't done. The server stays light (heartbeat 0.4 ms, physics 0.8 ms).
- Portal Worlds (measured 2026-10-30, same full-server stress test, all in one Studio session): from the street, none of
  the new pieces 11.9 ms (level 1) / 12.8-13.1 ms (level 10), everything on 12.5-13.0 / 13.2-14.2 ms, so the whole pass
  costs about +0.8 / +1.0 ms (budget +1.5 ms); the day cycle's lighting updates about 0.4 ms, the terrain about 0.4 ms,
  props, animals and butterflies within noise; inside the areas 9-10 ms at 59-60 fps. Terrain memory about 53 MB
  (graphics 50, voxels 3). Caps (Lune-tested): terrain at most `Scenery.MAX_CELLS` estimated cells, one flowing waterfall
  (at most 4 streams, 4 falls effects), at most 4 effects per area, at most 20 butterflies, 6 animals (3 in town, one per
  area) moved only within 120 studs, tree sway within 150 studs at 30 Hz, the frozen falls at most 60 parts; small
  hand-placed decor (under 4 studs) casts no shadow; sign and arch words stop drawing beyond 120 studs. The 60k triangle
  town total no longer covers the areas: the scenery reuses the town's prop meshes (scaled copies batch together) plus
  code-built parts, so no new mesh triangles were added.
- Town portals remodel (measured 2026-10-31 in a fresh Studio session: copies of Plot1's stocked shelves in the other 5
  plots, 5 avatar clones; render CPU from fixed cameras, the portals taken away and put back in turn at each view):
  60 fps everywhere at levels 1 and 10; the street 9.2-9.5 ms with or without them (no change); standing at a portal
  +0.1 to +0.2 ms (Forest Falls 7.4 → 7.6, Ember Canyon 7.3 → 7.4, Frostpeak within noise at level 10). The plaza
  measured +1.1 ms at level 1 the day before, 60 fps held. Caps: at most 4,000 triangles per portal model, at most 4
  effects and a light per portal (Lune-tested), the vortex spins only within 150 studs with the extras on, the models
  stream Atomic. Comparing "on" then "off" in one pass over-read the cost (+1.6 ms on the street, where no portal is
  in view): alternate off/on/off/on at the same camera.

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
The core loop is complete (the shop loop, cards, jobs, party, stars, battles and the whole boss ladder). Order from
2026-10-29: UI/UX design first (with the phone layout pass), then the town's design, then the remaining monster and
boss models; the ranch and Heroic tiers come after those.
- [x] UI/UX pass 1 (spec `2026-10-29-collection-screens-ui-design.md`, branch `ui-pass-1`): look E style kit, binder
  tooltip, card view, Add to Party with the kid comparison, Party window, party bar tooltip, boss ladder with Take me
  there, Bag; no Star Shard pill. Done: approved in Studio and merged 2026-10-29. Feedback round 1 built:
  Prices price box, Party legend and tonic badge, word tooltips, card view centring, clearer chooser and comparison
  wording, compact chooser buttons, party change toast, rarity guide without spoilers. Round 2: Shop Jobs rebuilt as
  option B (with Switch job), short tooltip words, no tooltips through covering windows, livelier toasts. Round 3:
  Jobs rule chips no longer clipped (the list is padded), Boss Ladder reworked (legend, Next, To fight it checklist
  with key fragments, what to do next, Watch out, Rewards with odds and chests, item tooltips; locked bosses past
  Next keep their tricks a surprise). Next: UI project 2 (a 3D
  binder with real page flipping, absorbing the book's squeezed pages, tiny labels and cut-off set tabs), then
  project 3 (cards in the world: shelf card models, bigger cards in bigger glass cases).
- [x] UI project 2, the 3D binder (spec `2026-10-29-3d-binder-design.md`, plan `2026-10-29-3d-binder.md`, branch
  `binder-3d`): "Collector's Desk" picked from three mockups; built (desk scene, 2 x 2 sleeved pages (3 x 3 was too
  small on phones), bending page
  turns with drag, swipe, tap and riffle, divider tabs, hover and hold tooltips, the card lift into the card view,
  fights close it, world sound at the character). Studio at graphics level 1: worst frames 22 ms opening, 38 ms
  turning (budget 50). Done: approved by the user and merged 2026-10-29. Feedback rounds: the camera no longer stuck
  after closing the card view, a lighter binder, 2 x 2 big cards and a bigger binder for phones, the picked card
  lifting to the screen's middle, finer stitches, small flat tabs drawn on the case, the X closing the card view
  first (no Back button). Next: UI project 3 (cards in the world).
  Deferred minors from its review: a refresh between riffle turns cuts the riffle short and tab clicks mid-turn are
  ignored; picking a card doesn't cancel pending turns; closing on a boss fight could override the boss intro
  camera; hover rise grows down-right; the tooltip can cover the set tabs and isn't re-placed when the camera
  moves; idle tween cost of placed faces unmeasured; tabs rebuilt every refresh; some tunables still in code
  (hover, lift, desk size, warm batch, flick window, park offset); stale comments and small dead bits
  (BACKDROP_COLOR, BinderSpreads.turningSide); nearby ProximityPrompts over the binder unchecked; no gamepad
  card picking.
- [x] UI project 3, cards in the world and the 3D pack opening (spec
  `2026-10-29-cards-in-world-and-pack-opening-design.md`, plan `2026-10-29-cards-in-world-and-pack-opening.md`, branch
  `ui-project-3`): picked from concepts (shelves A: open display boxes; cases B: upright cards turning on rarity
  beams; the rip B with cards revealed one at a time). Built: the Blender pack, deck box and display box (imported
  into `assets/packs`, docs/packs.md), packs in display boxes that empty as they sell, CardCase cases
  with spinning upright cards, the 3D opening (cinematic tear, cards stacking, flips with teases and hits, a living
  shown card, a sparkling results lineup), our own Blender effects (no confetti), sounds, and the 3D pack in menus.
  Studio at graphics level 1: worst frame 42 ms as the stage shows, 27 ms or less through the opening, 19 ms in a
  stocked shop (budget 50). Review fixes: an opening closed mid-animation (a fight, a death) leaves nothing behind;
  the hint shows only before the first flip (on phones it covered the row's prices). Done: approved by the user and
  merged 2026-10-30. Feedback rounds: no square border on face-up cards, a softer pack light, the waiting pack
  "charged and ready to rip" (picked from four: turns to the pointer, crackles, a tear guide), the pack drops below
  the card stack, 3D packs on the register counter, every rack 7 studs with plates at the same levels, bigger packs on
  shelves, branded delivery cases, sealed booster boxes on shelves, a bigger futuristic scan pod for the Grading
  Station (picked from six) and the Condenser in its style, both with rings of floating cards. Deferred minors from
  its review: a CardFace error while the cards build leaves the opening stuck before the first flip (a reset gets
  out); Continue while the Rarity guide is open leaves the guide trapped until the next opening; the Odds button and
  Rarity guide pill are 46 px tall (under 48); OpeningStage.isShown and OpeningCards.count are unused and OpeningPack
  says "the controller raycasts" (it doesn't); a fully stocked double-sided Big Display Rack was never measured.
- [x] Full-server performance (branch `shop-perf`): shop screens stop drawing beyond 60 studs and full card faces beyond
  30, with a flat art picture further away (`Config/ShopDetail`, numbers in 10.5); approved by the user and merged
  2026-10-30. Next: the town's nature pass (terrain, waterfalls, big trees, tree sway, grass, butterflies, 3 Cute Pets
  animals) under the measured rules.
- [x] Town nature pass, Portal Worlds (spec `2026-10-30-town-portal-worlds-design.md`, plan
  `2026-10-30-town-portal-worlds.md`, branch `town-portal-worlds`): the three walk-to portal areas, trails, arches and
  signposts, terrain and scenery, the day cycle in town, tree sway, butterflies, six animals and the first-visit welcome
  cinematic (schema v13), measured inside the budget (10.5). Feedback rounds built: no grass in shops, Frostpeak on a
  snowy rise, lava and saguaros, more life everywhere, an aurora of curtain beams; then the snowman removed, a frozen
  waterfall of ice over a frozen pond, layered forest falls with splash and foam, bigger rocks; then a grove between the
  east trails and a dressed edge on the rise, the leftover Prism Hydra copy removed from the place; then the plaza
  redesigned as the Card Festival Square (pick C) and the spawn pad made invisible; plaza round 2: a matte gazebo, the
  Elemental Bloom fountain (pick B), cafe tables with sitting townsfolk, edge planters, a cat and a puppy; round 3:
  festival carts (pick A), the fountain remodelled in Blender bigger and in bold colours with its magic (rune circle,
  light column, orbs, motes), the cat asleep on a bench, the benches facing the fountain, the fountain streaming in
  whole. Final review fixes: the boss board shows directions to the Frontier portal instead of a travel button the
  server now refuses, and the Forest Falls pool has a floor. Done: approved by the user and merged 2026-10-30.
  Still open: re-measure the frame budget in a fresh Studio session now the plaza is in (if over: shrink
  `Scenery.GROUND`, ClockTime at 1-2 Hz); the boss board's "Take me there" stays the one shortcut to Wild boss gates.
  Deferred minors from its review: the `WildTravel` comment in Remotes still lists "wild"; SceneryService's "neither
  holds up start" comment is half wrong; TreeSwayController rescans the scene's trees every 2 s (DescendantAdded would
  be cheaper); DayCycleController moves the sun 10 times a second; WelcomeController freezes with WalkSpeed (a server
  write during the cinematic can clobber it) and hides every ScreenGui instead of `Hud.setHidden`; the Skip button's
  phone check isn't recorded; DayCycle gives NaN for a phase shorter than its blend (no config guard test) and
  `table.clone` of a look is shallow; night grading also tints the pack opening and binder views; TownService's portal
  effect fallback ignores `spot.y`; BuildController's `WaitForChild("OrderComputer")` warns when the plot streams in
  late.
- [ ] Town portals remodel (spec `2026-10-30-town-portals-design.md`, plan `2026-10-30-town-portals.md`, branch
  `town-portals`): the three portals grown from their worlds (the user's pick A): a root arch at Forest Falls, an ice
  crystal ring at Frostpeak, an obsidian arch with lava at Ember Canyon, Blender-built, a spinning swirl in each
  opening, water, mist, lava and embers; the old frame stands in until a model is saved; Ember Canyon's stone platform
  removed, its torches moved out. Measured: no change on the street, +0.1 to +0.2 ms at a portal. Also the capybara
  moved onto the sidewalk outside the south shops. Awaiting the user's check in Studio.
- Bag on phones: the window shrinks as a whole, so the info panel's text gets very small (counts and boss numbers are
  kept at 14 px). A phone layout for the Bag (info under the grid, or bigger text) is still to do.
- Fight juice: punchier floating damage numbers (size by damage, crit/strong pop, stacking so numbers don't
  overlap), hit markers and a short flash on the creature hit, a screen shake on big boss hits.
- Fight bar redesign: a portrait of each creature (its model in a ViewportFrame) beside its HP, clearer HP bars
  (damage trail, low-HP pulse), reserves shown as small portrait buttons with their HP, ability buttons with
  cooldown sweeps instead of countdown text.
- Admin moderation (live game): admins listed by UserId in a Config/Admins, every action checked on the server; a player
  list with Kick, Ban (Roblox `Players:BanAsync`, works across servers, duration and reason) and Unban. The Studio admin
  panel (dev commands as buttons) exists already; test commands stay Studio-only so the live economy can't be touched.
- Phone layout pass for fights: check the fight bar and end screen on small landscape phones in the Device emulator
  (bar height, tap targets). Done so far: phones get a narrower boss bar clear of the Roblox menu buttons
  (`BOSS_BAR_PHONE_MARGIN`), and the Dungeon run line shrinks and hides during fights (`UIKit.isPhone`).
- Heroic tiers for the Dungeon (not decided): clearing it opens a harder tier with better drops, each clear the next,
  a leaderboard of the highest tier and the fastest clear.
- The ranch (its own project, after the Dungeon): a place just for showing creatures off, unlocked early in the main
  game (about shop level 10); clearing the Dungeon adds a special Legendary habitat there.
