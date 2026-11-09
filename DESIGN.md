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
(-205, 0; west), since 2026-10-31 a calm volcanic **caldera** in the portal's colours (caldera spec
`2026-10-31-ember-caldera-design.md`, the user's pick A "Glowing fissures" of three): dark basalt walls with jagged rims
and a dark cracked floor (terrain materials `Basalt` and `CrackedLava`, coloured only here), about 220 glowing orange
cracks down the cliff faces and across the floor (`Util/LavaCracks` lays them out from `Scenery.CRACKS`, clear of the
trail and the portal; SceneryService snaps each onto the terrain by raycast once the terrain has filled, wall cracks in
halves so they follow its steps), charred dead trees with ember tips and black-purple obsidian shard clusters (players can't walk through them: an
invisible collider round each trunk or base, `Scenery.CALDERA_COLLIDERS`; Blender:
`build_charred_tree.py`, `build_obsidian_shards.py`), a hotter lava river and pool, dark torch pillars beside the
portal, floating embers and two baby dragons; behind the end wall a quiet volcano (`build_volcano.py`, 120 studs tall at
(-335, 10), showing over the cliffs from the trail and the town street) with glowing lava in its crater and streaks down
its side (turned to face the canyon and the town, `VOLCANO.yaw` 270, Lune-tested against the saved model) and a slow
smoke plume: a camera-facing beam with a billowing texture made in code (`Scenery.PLUME`,
`assets/ui/fx/volcano-plume.png`; particles never showed, the client doesn't run emitters that far from the camera). Walks: about 8-9 s to the east portals, 6 s to the Arena (the
user kept the map's spots). Trails are paved terrain with the portal's glowing line along them; a wooden arch with the
area's name stands where each trail leaves the island (gaps in the hedge), and "This way" signposts point the way
(one in the planter on the plaza rim beside the spawn, one at each street end; `Town.SIGNPOSTS`, `Server/Util/TrailProps`). The invisible walls follow `Town.WALK_EDGE` (the island plus the trails and
clearings). The scenery is built at server start from `Config/Scenery` (terrain via `Util/TownTerrain`, props by
`SceneryService`, looping nature sounds at the falls, the wind, the embers and the plaza birds in `Scenery.SOUNDS`).
**Town music** (owner 2026-11-04: "subtle gentle town music" with the ambience; `MusicController`, `Config/Music`,
`Util/MusicRules`): APM "White Owl" (bells and piano, Roblox-licensed; the owner's pick 2026-11-04, after "Drifting
Into Dreamland - Underscore") at volume 0.18 (the owner's number, 2026-11-04: 0.045 and 0.07 too low, 0.21 a little loud with White Owl) through a limiter (`compressor`, threshold -48.5 dB, ratio 20: the track swells in its later parts; the threshold stayed, so the loudest part rose with it), with 6 s of
quiet between plays; it fades out over 3 s when you leave the island (more than 40 studs past `Town.BOUNDS`: the Wild
valley, a boss arena) and back in when you return. Main place only. The owner picked it from five options
(`Music.TOWN.options`, still there for trying others: in Studio `/music <n> [volume]` or the admin panel's Music
buttons loop option n over the ambience, `/music 0` goes back); the first pick ("Lakefront Days" at 0.12) overpowered
the ambience and 0.05 was still a little loud. **Wild music** (owner 2026-11-04: "finalize the wilds", music in the
valley and in every boss arena; `Music.WILD`, the same controller): each of the valley's three areas has its own APM
piece and each boss arena its own battle piece while you're in it (an arena first, then the area you're in, then the
town; on a pass between two areas the last keeps playing; `MusicRules.place`), crossfading over 2.5 s on a second
sound; the Wild bosses' fights no longer play the drone (`Bosses.MUSIC_ID`, kept for the Frontier and the Dungeon).
Each place has three options (`/music <place> <n> [volume]` or the admin panel's Wild music buttons try them; places
meadow, gorge, ridge, warden, brood, colossus). The valley plays only solo piano or acoustic guitar (owner 2026-11-04,
after hearing orchestral picks: "acoustic guitars or piano only"), very quiet; the owner picked by ear: the Meadow
"Woodland Walk" (classical solo guitar) at 0.005, the Caves "Calm Waters" (slow, sparse solo guitar) at 0.01, Ember
Ridge "Air Currents" (floating classical solo guitar, after "Hombre Solo") at 0.005 (the other options: "Butterflies",
"Running Through The Fields"; "Secret Waterfall", "Air Currents"; "Moonlight Sonata", "Live Piano Stories 04", "Hombre
Solo"). The arenas keep the owner's battle picks: the Meadow Warden's "Forest Chase" at
0.006, the Cave Brood Queen's "Creepy Crawlers" at 0.008, the Ember Colossus' "Giant's Grave" at 0.006 (owner 2026-11-05: down from 0.1, 0.13, 0.1). Each plays through a leveler (threshold -20 dB, ratio 6, +7 dB makeup: measured with PlaybackLoudness it keeps
the average the owner heard and cuts the peaks; the town's limiter would crush these). Each area also has a Pro Sound
Effects ambient loop under its music (turned down by the owner: the Meadow 0.03, the Caves 0.05, Ember Ridge's much
louder lava 0.008), crossfading the same way: a field of cicadas, birds and insects in the Meadow
("Field Birds Tweeting 1"; the first, "Birds Peaceful 2", was lost under the music: `PlaybackLoudness` ignores
`Volume`, so what you hear is about loudness x volume),
cave drips in the Caves, bubbling lava in Ember Ridge; the arenas keep their own (`ARENA_DRESSING`). A grove of trees fills the hill between the east trails. **The portals grow out of their worlds**
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
plane (ImageLabel.Rotation; `PortalFxController`, `Util/PortalLooks.animate`, within 150 studs unless the player picked low graphics (not the frame watchdog: arriving somewhere new hitched it off and froze the swirl you walked up to, fixed 2026-11-04),
looking the panels up every frame; each portal wears the look `PortalBuild.dress` stamps on it as the `PortalLook`
attribute, since the Boss and Arena looks share one model and boss portals are renamed). A flat beam turned with its part twisted out of the opening and read as several
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
Wild goes through its prompt only (the WildTravel remote accepts just "home", sent by the Wild's sky "Return to town"
pill top centre; owner 2026-11-03, round 3, `Combat.HOME_BUTTON`; it hides with the HUD while the binder or a pack
opening fills the screen, owner 2026-11-05, `Hud.hideWith`), and the Frontier menu's choices only count
within `Town.PORTAL_REACH` (16 studs) of the Frontier portal. Plots stand 24 studs apart. The island is x ±130,
z ±110 (`Town.BOUNDS`): the Baseplate is cut to it and hidden under terrain grass (pavement-type terrain under the street
and plain ground under and 5 studs round each shop, so no blades poke through; Roblox draws terrain 2 studs above its
fill, `TownTerrain.SURFACE_LIFT`). **Day cycle** (`Config/DayCycle`, `Util/DayCycle`, `DayCycleController`): a 19.5-minute
loop, the same for everyone in town in a server: morning 7 min (the longest), afternoon 5, sunset 4, a 2-minute blue night
lit by the street, shop neon, portals and glowing mushrooms (shops stay warm and readable), dawn 1.5; each phase keeps its
sky, haze, bloom and colours, blending into the next over 40 s while the sun creeps across. Each client works the time
out from the server's `DayCycleStart` attribute (no network). Outside the town region (the Wild, the Arena stands, the
boss arenas) the old afternoon look shows at once, so fights never happen at night; the Wild valley's three boss arenas
each show their own look instead (`DayCycle.ARENA_LOOKS`, 5.8 "The Wild valley"), none of them night. **Ambient life** (client only, off
when the frame watchdog sees a slow device, after the first 15 s so the join's loading doesn't count, or the player
set graphics at 3 or below; a sleeper's "z Z z" hides with it: `Util/FrameWatchdog`,
`Client/Util/Extras`, `Config/Ambient`): trees near the camera sway (`TreeSwayController`), and Cute Pets animals
run round their homes, drawn by the summoned-pet code (`TownCritterController`, `Util/Wander`): a fox at the forest edge,
a bunny on the grass by the grove, a capybara on the sidewalk outside the south shops (the tall grass between
the shops hid it), a fawn at Forest Falls, a penguin on Frostpeak, two baby dragons
in Ember Canyon's caldera in its colours (the Cute Pets Shadow and Golden variants, `variant` in `Ambient.CRITTERS`). **Welcome cinematic** (`WelcomeController`, `WelcomeService`, `Config/Welcome`, `Util/WelcomePath`): on a
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
| Card Condenser | machine: combine duplicates for +1 star (5.8) | $500 | Shop Lv 5 |
| Grading Station | machine: duplicates and cash for +1 grade (5.9) | $5,000 | Shop Lv 14 |
| Wall Shelf | 48 packs | $350 | Shop Lv 4 |
| Accessory Hook | 20 accessories | $250 | Shop Lv 7 |
| Big Display Rack | 96 packs | $1,200 | Shop Lv 9 |

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
- **Types** (`Config/Customers` TYPES, picked by `Util/CustomerTypes`, Lune-tested; spec
  `docs/superpowers/specs/2026-11-06-customers-design.md`): plain 55%, kid 20%, collector 10% (only with a Glass
  Showcase), bargain hunter 10%, big spender 5% (from shop level 11). Types a shop can't have share their weight out.
  Each wears simple welded props (kid: cap and a pack, smaller at 0.82 scale; collector: glasses and a binder;
  bargain hunter: bucket hat and coupon; big spender: shades and a gold chain) and shows its icon in a bubble on
  arrival. Kids buy 1-2 of the cheapest pack the shop sells. Bargain hunters and big spenders buy one price band
  higher than plain customers (`Pricing.BUY_BANDS`, past the last band more bands as wide as the last); past that
  they won't buy and get annoyed. Big spenders buy a display box (`BIG_SPENDER.box`) or a stack of 6-12 packs and
  tip 10% at the register.
- **Collectors** (`Util/CollectorRules`, `COLLECTOR` config) want one card, half the time one the owner has (binder,
  beasts or on display), else any First Spark card weighted by rarity (Common 30 ... Legendary 10 per card). The card
  shows in a thought bubble over their head the whole visit (client `CustomerController`). After the shelves they walk
  the Glass Showcases looking for it (the owner can still put it out), re-check it on arrival and buy the cheapest copy
  at up to 1.3x its worth; otherwise a disappointed bubble (counts as no stock).
- **Reactions** (`Util/ReactionRules`, `REACTIONS`): at each waypoint of their walk a customer within 6 studs of a
  card case holding an Epic, Legendary or foil card stops 1.5 s facing it with a 😮 bubble (one stop per card per
  visit; a Legendary holds up to 3 watchers, any other card 1). Once a visit, within 8 studs of the owner's summoned
  creature, 35% stop to pet it (Heart bubble; the creature wags: marker attribute `PetMe`, `CreatureController`).
  Each reaction is a happy moment for the rating.
- **Town walkers** (`TownWalkerService`, `Util/WalkerRules`, `WALKERS`): while a player is in town, up to 8 customers
  of every type (one more every 20 s) walk in from either end of the street and stroll all of it at 6 studs a second
  (shoppers too since 2026-11-06, were 10: "walk at a normal speed"; the walk clip keeps pace): they look in every
  shop's window from its sidewalk (two spots a shop), stand about on the road and on the plaza's three open lanes, and
  sit on a free bench 30% of the time (Roblox's sit animation, as the cafe townsfolk). Their paths never jump and keep
  off grass and water, and a stop they can't reach is skipped, so nobody climbs the fountain or runs in place against
  it; a waypoint they can't reach in 2 s past its walk time is given up (`NpcMotion.walkTo`, no straight-line
  fallback). After 40-120 s each picks an open shop (its owner in the game), weighted by rating squared and x3 for a
  collector whose card is on show there, walks to its door and becomes its customer (`CustomerService.Adopt`); a full
  shop sends it strolling again; after 5 minutes it walks off at the nearest street end. They add to each shop's
  street customers. A collector keeps its card to itself on the street: the thought bubble shows once it's a shop's
  customer (`Adopt` takes the card; the client watches `WantedCard` change). Measured 2026-11-06 (one player,
  Studio): server heartbeat work 0.45 ms before, 0.15-0.27 ms with 4 walkers on the plaza; client 16.7 ms a frame (60
  fps cap), worst 24 ms. After the street round: 5-8 walkers spread from x -90 to 99 on both sides, no jumps, a steady
  6 studs a second, nobody walking in place over 80 s.
  A walk that can't start (a tight spot: between a bench and the gazebo, where a walker stood after sitting, or by a
  planted tree) failed every time, so the walker stood there for good. Now after 2 failed walks in a row it retraces
  the route it came in on (`NpcMotion.walkRoute`, open: it just walked it), and after 5 it's removed (`WALKERS`
  unstickAfter, giveUpAfter). Measured: nobody still for 14 s off a seat over 170 s.
- **Shop customers come from the street** (owner 2026-11-06: "not at the front of the shop, random";
  `CustomerService.UseStreet`, `TownWalkerService`, `WalkerRules.spawnPoint`): when a shop's next customer is due
  (same rate as before) it walks in from a random street stop or end at least 40 studs from the shop's door and every
  player, and becomes the shop's customer at the door (`Adopt`; it doesn't count toward the 4 until then, and strolls
  the town if the shop is full or closed). Done shopping, it walks out of the door and off to the nearest street end
  (its thought bubble left in the shop). Past 24 town NPCs at once (`crowdCap`) they appear and vanish at the door
  as before; Studio's `/customer` still puts one at the door. Measured: 22 arrivals from 58-174 studs away, 11 NPCs at
  most with one shop open; the walk in adds up to ~30 s before a customer reaches the shop (the flow per hour stays
  the spawn rate's).
- **How NPCs walk** (customers, walkers, shop workers; `Util/NpcMotion`, `Util/WalkStep`, `Customers.NPC_STEP`):
  Roblox's own R15 walk (913402848; the old 507777826 looked like a jog) played at the feet's pace (speed / 6.4, the
  clip's own pace: 0.94x at 6 studs a second), and the idle clip only after 0.25 s standing, so turns don't
  flicker. Along a path each waypoint counts as reached 1.25 studs early so the next step goes out before the NPC
  stops (they stopped ~0.2 s at every one), the walk's end within 0.6. Trying to walk but covering under 0.5 studs in
  1 s is being stuck: that walk is given up (a walker picks another stop) instead of walking in place.
- Customer spawn rate scales with **shop rating** (4.7).
- Keep NPC count capped per plot (start 4 max at once) for performance. Use simple rigs, no fancy animations at first.

### 4.6 Register / checkout
- Player stands at register, customer puts items on counter, player clicks/taps each item to scan, then confirms payment.
  Packs and deck boxes lie face up on the counter as their 3D models (`Util/PackModels`, inside an invisible scan
  target); other products are a box in the product's colour.
- Payment: cash (make change, later feature) or card (instant). MVP = one tap to confirm total.
- Later: hire a cashier to automate.
- **Kid offers** (`OfferService`, `Util/OfferRules`, `Config/Customers` OFFER): after paying, a kid rips one of their
  packs at the counter (same odds, no pity: `PackService.RollForCustomer`; model attribute `Pulled` for everyone's
  reveal) and stays there `KID.revealSeconds`. A Very Rare or better pull may be offered to the owner (chance Very Rare
  40%, Epic 30%, Legendary 30%, times the grade: C 1.15, B 1.0, A 0.85, S 0.7) when the owner rang the sale up from
  behind the register (never through a cashier) and the shop is under the ceilings (at most 4 offers an hour, no two
  Legendary offers within 3 hours, per session). The kid asks 90-100% of the card's worth and takes 75-90% (hidden).
  The owner accepts (pays the asking price), counters (half the worth up to the asking price, steps of 5% of the
  worth; at or over their lowest buys it, under costs one of two tries) or declines; unanswered for 25 s the kid
  leaves with the card. The face the client shows comes from edges 5% of the worth around the lowest, so the lowest
  never reaches the client.
- **Haggling** (`Util/HaggleRules`, HAGGLE): once a bargain hunter's items are all scanned, they offer 10-25% under
  the total instead of paying (Charge says "Answer their offer first."). Deal pays their offer; a counter (their
  offer up to the total) is paid if it's at or under their hidden ceiling (40-80% of the way back up), otherwise, on
  No or after 25 s, they put everything back and leave annoyed. A cashier meets them halfway and they take it.
- Answers come through `OfferAction` (rate-limited, only the open offer's id, only from behind the register, a counter
  only inside the range the server worked out); the open offer reaches the owner through `OfferUpdate`.
- The offer panel (`RegisterController`, `Customers.PANEL`) replaces the checkout panel while an offer is open: a
  cotton candy window with the kid's card, name, rarity, grade and "$asking (worth $worth)" or "Offers $x for $total
  (-N%)", and Buy/Deal, Counter, No. Counter shows - / + (one step each), chips (-20%, -15%, -10%, Worth/Full), the
  price and their face (😀 Sure! / 😐 Hmm, maybe / 😠 No way), Offer and Back. Every button is 48 px tall. On phones it
  sits below the cash row and left of the jump button. The kid's rip (`CustomerController`, `Customers.REVEAL`): their
  best card grows in over their head for everyone nearby and holds 2.5 s; Very Rare or better adds a cheer and the
  pack opening's hit sound, a Legendary a fading column of light.

### 4.7 Shop level & rating
- **Shop XP** from every sale. Levels unlock new products, shelves, expansions.
- **Shop rating** (1-5 stars, `RatingService`, `Util/RatingRules`, `Config/Customers` RATING): every 5 s each open
  shop is scored on weighted 0-1 parts: product shelves stocked 35%, fair prices 25% (each stocked product's buy chance
  at its price against the best band's; neutral with nothing stocked), cards on display 15% (Epic 1, Legendary 3, foil
  +1 point, full at 6), happy customers 25% (paid and happy moments against annoyed, gave up and no stock over the
  last 20 visits; neutral with none) and decor at weight 0 until the Decor system (then a config weight plus its
  score). 1 + 4 x the weighted mean, smoothed over about 90 s (a fresh join starts at its score). Not saved. The stars
  show on the shop's sign, filled by quarters (`PlotService.SetSignRating`); the gap between customers is x1.4 at 1
  star, x1.0 at 3, x0.6 at 5. The owner gets `RatingUpdate` (rating and parts; a part with nothing to score yet, like
  prices with nothing stocked, is marked unknown). Scoring starts once the shop has loaded (RatingService registers
  with DataService after PlacementService).
- **Rating chip** (`RatingController`): a white pill in the status column between cash and XP with five stars filled
  by quarters and the number (48 px tap area). Tapping opens a cotton candy "Shop rating" window: the stars and
  whether customers come more or less often, then a line per part that counts, heaviest first: ✅ what's good or ⚠️
  what to fix (`Customers.RATING_TIPS`); unknown parts get no line.

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
  each client (`Util/PetRig`, `Util/PetAnimator`, `Party.PET_ANIM`): trotting or stepping (Thunderhorn gallops, owner
  2026-11-05 "make it like its running": `CREATURE_STYLE` `gait = "gallop"`, `PET_ANIM.GALLOP`: the front legs reach
  together and the hind legs half a stride later, longer swings, the body rocking and bounding), breathing, tail wags,
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
  client-only parts right above the player while it shows (`Util/OpeningStage`, `Util/StageSpot`; see the binder's
  stage note in 10.6; far away at `PackOpening.STAGE_POSITION` otherwise): a violet glow fading to
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
  show a sharp picture of the real pack and deck box (round 5, owner pick A: the 3D models rendered big in Studio, cut
  out by `tools/ui-art/cut_product_picture.py` and uploaded; `Config/ProductPictures`, `Util/ProductPictureRules`), fitted
  in 56 px with 4 px of air so nothing touches the row's edge; a pack look with no picture yet shows the drawn
  BoosterPack / DeckBox icon (`Util/ProductPicture`), which also shows under a picture until its download succeeds
  (the label itself is preloaded: an image id preloaded as a string reports Failure, and `IsLoaded` never fires a
  change). The old live 3D picture was soft and clipped. Order Stock and Prices pad their list (`Pricing.ROWS.LIST_PAD`,
  `UIKit.padList`) so the rows' outlines and the buttons' glow aren't cut at its edges.
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
min(both players' cash, $25 × the lower shop level), in $5 steps) and see both parties' Power. They have 15 s to
accept. Both bets are then held by the server and the match goes to the arena (one pad, far from the shops; others
queue first come, first served; leaving the queue refunds both). After a 3-2-1 countdown, full parties fight (cards resting from the wild sit
out), same combat rules as the wild, no call-in and no Run; you can roam your half of the pad. Winner takes both
bets; the 2-minute limit is a draw (both refunded); leaving or resetting mid-fight forfeits. No XP, drops or resting
from PvP. 10 s after the result both go home. Anyone can watch from the stands (plaza "Arena" portal, `/arena`);
creatures in a fight show floating HP bars, and players within 60 studs of the arena (`Pvp.WATCH_RADIUS`) see the
creatures' charges and attacks like the fighters (`Remotes.ArenaWatch`, `ArenaWatchController` on `Util/FightFx`; no
HUD). Wins-losses-draws are saved and shown in the Party panel. A declined
challenge blocks that pair for 30 s; 10 s cooldown between challenges. Numbers: `Config/Pvp.luau`; bet and record
rules in `Util/PvpRules` (Lune-tested). The fight engine (`BattleSim`) runs two sides of fighters: wild fights are
the party vs a one-monster side.

**Battles part 1: wild fights.** A portal at the end of the plaza street moves you to the wild map (same server, far
from the shops; your shop keeps selling). Press Fight near a monster, or get caught by one that chases you. Your
summoned creature fights (it must be rested); in the first 5 s you may call in one more party card (max 2 of yours
vs 1 monster). You can run around within 25 studs of the fight (further puts you back at the edge). Fighters attack on their own (interval from SPD, `2 x (10 / SPD)^0.62` between 0.55 and 2.5 s: SPD 10 every 2 s, 27 every 1.08 s, 47 every 0.77 s, 69 every 0.6 s, so every bit of SPD counts; a fast attacker charges for at most 75% of its gap); each has an element
ability (8 s cooldown) and the Epic/Legendary cards a super move, fired from a full super meter (owner 2026-11-06,
option A "Super meter": it was every 15 s and got pressed on cooldown). One meter per player (`Combat.SUPER_METER`,
`BattleSim` `side.meters`), empty at a fight's start: each of its creatures' hits that lands adds 1.5 (Pet button
moves too, never a super's own), each sword hit 2, each boss hit dodged or ring stepped out of 8, and every full max HP
its creatures or player lose 10; a creature's Express perk fills it that much faster. Full (100) fires the summoned
creature's super and empties it, so a full meter can wait for a swap to the creature whose super fits. About every
20-25 s fighting well, 40-45 s standing still (`tools/balance/bosses` prints how often). The Super button fills gold
from the bottom with its percent and pulses gold when full (`CombatHud.METER`); its tooltip says how it charges.
Element wheel: Ember > Bloom >
Tide > Ember, Volt and Shade strong against each other (strong ×1.5, weak ×0.75). Run is a chance
(`clamp(0.5 + 0.03 × (leader SPD − monster SPD), 0.2, 0.9)`, −0.15 vs elites; failing costs a free hit and 3 s).
Win: XP `12 × level^1.3` (×3 elite) split evenly across all 3 party cards, $0.40 × level, 5% (elite 20%) chance of a
card of the zone's elements. Lose: nothing is lost, but fainted cards rest 5 minutes (`Combat.REST_SECONDS`, 3 before the player joined boss fights) (3x faster standing at the
healing spring in the plaza centre). A fight still going after 2 minutes ends as a run. Numbers:
`Config/Combat.luau`, `Config/Wild.luau`; maths in `Util/CombatMath`, fights in `server/Util/BattleSim` (both
Lune-tested).

| Element | Ability | Effect |
|---|---|---|
| Ember | Fireball | 2.5× ATK hit |
| Tide | Healing Rain | heals your fighters 25% max HP over 5 s (5 ticks of 5%, one a second; a recast restarts them; stops when the creature faints or is swapped out); a Grade S caster also heals its own player 15% over the same ticks (owner 2026-11-05; none while down) |
| Bloom | Vine Snare | monster attacks 40% slower for 4 s |
| Volt | Overcharge | next 3 attacks twice as fast |
| Shade | Curse | monster ATK −30% for 5 s |

Healing Rain was Wave, an instant 25% (owner 2026-11-05: "Heals overtime for 25% not instant"). Measured with
`tools/balance/bosses` (400 fights a row, before and after): heals over time waste less than the instant heal did, so
parties that stand still at 0.8x the recommended Power win more (Cave Brood Queen 20% to 49%, Storm Sovereign 21% to
46%, Ember Colossus 8% to 22%, Meadow Warden 6% to 14%); at 1x and fighting well nothing moved by more than 2 points.

| Card | Signature | Effect |
|---|---|---|
| Infernox | Inferno | burns 6 s (0.4× ATK per second) |
| Abyssal Koi | Tidal Shield | every ally (you too) a shield of 30% of its own max HP for 8 s |
| Thunderhorn | Stampede | 2× ATK hit + 2 s stun |
| Eclipse Fox | Eclipse | dodges everything for 5 s |
| Solarion | Supernova | 4× ATK hit (a 3.5 s wind-up, the other Legendaries 2 s) |
| Voidmaw | Devour | 2× ATK hit, heals half the damage, at most 15% of its max HP |

The Frontier four share their base move's kind, except two that got their own (owner 2026-11-05): Cinder Titan's
Magma Slam is a Stampede, Stormking's Thunderstorm a Supernova; Tideborne Kirin's Tidal Blessing ("Rebirth Spring",
kind `Rebirth`) stands its owner's fainted creatures back up at 35% of their HP, once a fight (the first blessing that
finds one down; a benched one goes back to the reserves), and heals the rest of its owner's party, the player too, 15%;
Riftwalker's Rift Step ("Blink Barrage", kind `Barrage`) is 4 hits of 0.8x ATK, 0.25 s apart, each from another side of
the boss (the sim queues the next hit as a cast; a caster that faints stops them). Both stay with their owner only,
like Healing Rain: stacked blessings in a group would out-heal any boss.

| Zone | Monster Lv | Species (element) | Chases you |
|---|---|---|---|
| Meadow | 1–5 | Mossling (Bloom), Puddle Crab (Tide) | elites only |
| Caves | 5–10 | Cave Bat (Shade), Spark Beetle (Volt) | elites only |
| Ember Ridge | 10–15 | Magma Golem (Ember), Ash Wolf (Ember) | all |

About 8 monsters per zone, respawning 20–40 s after a win; 1 in 10 is an elite (gold tag, 1.35x size, about twice
the HP, ×3 rewards). Monsters sleep with no player within 100 studs. Studio: `/wild`, `/rest`, `/elite`.

**You in wild fights** (owner 2026-11-03): with a sword (the free starter at shop level 4) you fight normal monsters
and elites beside your creature, as in boss fights: Attack, Dodge, the sword's skill, the Pet button and Run. The
monster turns a third of its swings on you while a creature of yours stands and sends quick hits at you (8% of your HP,
elites 12%, `Wild.PLAYER_QUICK` / `ELITE_PLAYER_QUICK`, `CombatMath.getMonsterAttacks`; dodge them; no rings outside
boss fights). The fight is still lost once your creatures faint (`creaturesDecide` in `BattleSim`): you going down
only stops your sword, and you get up again while a creature stands. Without a sword yet the fight is the creature's
alone, as before. Dungeon rooms stay creature-only (only the Hydra's chamber puts you in). Monster HP and ATK were
retuned for it with `lune run tools/balance/wild [fights] [wild|frontier|both]` (the card at the monster's level whose
Power is nearest the zone boss's recommended Power; no sword / standing still / fighting well): a normal monster at its
zone's middle level takes about 12.5 s fought well (won 85-100%) and is won about 75% standing still; the Meadow comes
before the sword, so its pair is tuned for the creature alone (Mossling 79%, Puddle Crab 66%). Elites take 25-35 s and
are won about 65% fought well (55-77% by species), so a call-in helps. A wild fight is lost once the creatures faint,
so a longer fight needs softer hits: elites have about twice the HP and hit a little softer than their species
(`ELITE_HP_MULTIPLIER` / `ELITE_ATK_MULTIPLIER` Wild 2.1 / 0.8, the Meadow pair its own 2.5 / 1.2 and 2.5 / 1.0 as
`eliteHp` / `eliteAtk`; Frontier 2.3 / 0.6), still harder than elites were before. Base stats at level 1 (HP / ATK):

| Zone | Species |
|---|---|
| Meadow | Mossling 175 / 6, Puddle Crab 179 / 6.1 |
| Caves | Cave Bat 260 / 8.4, Spark Beetle 258 / 10.1 |
| Ember Ridge | Magma Golem 444 / 17, Ash Wolf 445 / 10.9 |
| Frostwood | Frost Wisp 670 / 19.9, Shade Lynx 706 / 19.4 |
| Stormpeak | Storm Hawk 797 / 19.3, Lava Brute 826 / 24 |
| The Rift | Rift Horror 801 / 20.7, Prism Crab 753 / 22.3 |

Rewards per win are unchanged, so the pace moves earnings per minute (a middle-level normal monster plus about 8 s
walking, creature alone before → fought well now): the Meadow 25-28 s → 12.5 s (about +60%), the Caves 13-15 s →
12.5 s (level), Ember Ridge 9-12 s → 12.5 s (about -15%), the Frontier 4-6 s → 12.5 s (about -40%; standing still
about -60%). The shop's earnings and the pack loop (`tools/economy/sim`) don't count monster fights.

**Wild monster models** (spec `2026-11-01-wild-monster-models-design.md`, the user's style B "wild-touched", each
design picked from concepts and kept unlike the cards): each species has its own rigged model in
`assets/monsters/<Species>.rbxm`, made with Meshy image to 3D from the picked concept and skinned by our own rig
scripts (docs/creatures.md "Wild monsters"). The Mossling is a mossy boulder beast with glowing mushrooms, the Puddle
Crab a barnacle-crusted brute on six legs, the Cave Bat a stone gargoyle with violet cracks, the Spark Beetle a copper
stag beetle with yellow crystals, the Magma Golem a boulder cyclops dripping lava and the Ash Wolf a charcoal wolf with
an ash-white mane and ember cracks. Heights by species (`Wild.SPECIES` height in studs, elites 1.35x,
`Util/MonsterLooks.height`): Mossling 3.5 and Puddle Crab 3 (a stud above the to-scale pick B so they stand out of the
meadow grass, which is also cut short: Terrain GrassLength 0.3, a Studio-only property of the place), Cave Bat 3, Spark
Beetle 2.5, Ash Wolf 4, Magma Golem 6.5. Their bones move like the cards' originals, by species (`Party.CREATURE_STYLE`:
the crab's and the beetle's six legs walk in tripods, the golem lumbers on two legs), the wolf roars
(`wildroar`, the plain shockwave) and the golem stomps (`Party.SIGNATURE`). Each model's glow mask (the
SurfaceAppearance's EmissiveMask) lights its markings at the species' steady `glow.strength` (the golem 2.5, the rest
2), set once: the spec's pulsing lava was dropped because a SurfaceAppearance whose strength keeps changing costs about
6.6 ms of render CPU a frame, even one golem (10.5; a Lune test keeps every glow to one strength). Small effects ride
zero-influence `Fx_` bones within 60 studs of the camera with the extras on (`Wild.FX_RANGE`,
`Util/MonsterLooks.effectsOn`, looks in `Wild.FX`): sparks at the beetle's pincer tips, a smoke wisp from the wolf's
tail. A species without a model (the Frontier's) keeps its
code-built placeholder.

**The Wild valley** (main game; round 1 spec `2026-10-31-wild-valley-design.md`, the user's pick A "One valley,
three moods"; round 2 spec `2026-10-31-wild-valley-v2-design.md`, the user's picks A "Winding valley", boss portals and
sign style A "Wooden trailheads"): the three zones are one walk-through valley, its land climbing as you go. You step
out beside the root-arch portal (`PortalWild`, the Forest Falls model, as the "Return to shop" portal; its old ring
hidden, the prompt kept) and follow one S-shaped trail with small glowing markers every 12 studs
(`Util/WildValley.markers`) through three biomes, each over 200 studs across, at three heights round a hollow central
mass that hides each from the last: a sunny **meadow** at ground level (rolling mounds, a stream out of the east hills
under an arched wooden bridge into a pond, town trees, bushes and flowers, fireflies and drifting leaves); a right turn
and a climb through a pass to the **gorge** 15 studs up (warm grey limestone, tall cliffs, low shelves, a dark cave mouth
in its west cliff that players walk into, blue crystals round it and the gorge, crystal glints); a left turn and a
climb to the **Ember Ridge** 35 studs up (cracked lava ground with 26 glowing floor cracks, charred trees and obsidian
shards from the caldera, three smoking vents, embers, and the caldera's volcano past its far cliff, anchored and
glowing like the canyon's). **The scenery round** (spec `2026-11-04-valley-scenery-design.md`, the owner's picks from
concept pictures, 2026-11-04): the Meadow became **ancient ruins** (a circle of nine standing stones west of the trail
as its landmark, two broken arches, standing, broken and fallen pillars, crumbled walls with vines and flowers, two
red-and-white toadstool rings, flower drifts, more trees on its edges); the Caves a **glow mushroom hollow** (27
glowing mushrooms in teal and purple, the four biggest under a new rock shelf over the cave mouth as its landmark, 30
glowing plant and flower tufts along the trail, today's rocks mossy, fireflies and low mist) with a **darker, bluer
look** while you're in them (owner: "darker"; `DayCycle.AREA_LOOKS[2]`, blended in over 2 s as you enter and out as you
leave, `DayCycle.areaMix`); Ember Ridge an **ember forest** (twelve charred trees with burning ember crowns in three
groves, ten red crystal clusters, a half-buried dragon skeleton seen across the ridge from the second pass, four of
the old charred trees kept). Fifteen new models (`tools/blender/build_valley_props.py`, docs/props.md "Valley scenery
props"), placed from `Config/WildValley` (`MUSHROOMS`, `TUFTS`, `MOSS_ROCKS`, `RUINS`, `STONE_CIRCLE`, `MUSHROOM_RINGS`,
`EMBER_TREES`, `EMBER_CRYSTALS`, `SKELETON`; `WildValley.scenery` lists them all) and dressed by SceneryService:
anchored, out of the camera's way, each `Glow` part Neon in its spot's colour (`GLOW`), invisible colliders on the big
pieces (`COLLIDERS`, `spread` for arches, walls and the skeleton). Spawn spots keep 6 studs from every piece, or a big
piece's own `clear`. The rock shelf is a terrain `overhang`: drawn, but ground lookups skip it, so what stands under it
stands on the floor. **Round 2, natural edges** (spec `2026-11-05-valley-natural-design.md`; the owner after round 1:
"it looks like its inside a box ... the meadows ... random stuffs"; picks from a web reference board, then concepts
Meadow B, Caves A, Ridge A): every wall gets a rolling skyline of terrain lumps (`SKYLINES`, `WildValley.skylineOps`,
seeded; paid for by trimming the walls' hidden backs, `MAX_CELLS` 95k to 105k after measuring); past the walls stand
`BACKDROP` pieces (giant trees and big town trees round the Meadow, tree-sized glow mushrooms on the Caves' walls, ember
and charred trees on the Ridge's hills; no colliders, streamed as whole models; each wide one stands back from its
wall's front so the roots or stems you see rest on the wall top, `FEET`, Lune-tested) and ten far mountain range pieces
(`MOUNTAINS`: snowy round the Meadow and the Caves, dark jagged round the Ridge; always loaded, no shadows); the Meadow
is composed (every ruin on a hill round the stone circle, a footpath up through its north arch, `PATHS`; a bigger pond;
giant trees framing the trail, `GIANT_TREES`); the Caves' look gets fog and its crystal cave a mossy face; Ember Ridge
gets its own smoky orange look (`DayCycle.AREA_LOOKS[3]`), a bigger volcano set further back (height 140) and lava streams down it (`VOLCANO_LAVA`,
`WildValley.lavaRays` cast onto it); the area looks snap after a teleport (`DayCycle.jumped`); Roblox clouds over the
whole place, town included (`Scenery.CLOUDS`). Every valley scenery and backdrop piece then settles onto the terrain
under its foot once it is filled (`SETTLE`, `WildValley.settleDrop`: rays measure the gaps under its lowest surfaces and
it drops by the widest, never more than a fifth of its height; the owner 2026-11-05: "floating trees/mushrooms";
measured: 247 pieces, about 71k rays, 225 ms at server start, 10 pieces a frame). Each pass is an exact ramp lined with rolling terrain banks, not walls (the owner 2026-11-05: "this wall leading to
caves is awkward ... no walls"; `PASS_BANKS`, seeded lumps grassy where the trail leaves the lower biome, the upper
biome's rock beyond, rock outcrops, trees and rocks on top from `WildValley.passProps`; about 1.3k more terrain cells,
102.8k in all) (`WildValley.terrainOps`: no step at
either end). Signs are wood like the town's (`Server/Util/TrailProps.trailhead`): "THE WILD" by the arrival, a
trailhead at each biome's entrance (MEADOW Lv 1-5, CAVES Lv 5-10, EMBER RIDGE Lv 10-15), each turned to face back
down the trail the way players come, and an arrow post at each bend pointing on and back to the SHOP. **Monsters by
crowd** (`Util/WildPopulation`): each biome has 24 spawn spots on gentle ground well inside it
(`WildValley.zoneSpots`); it keeps 8 monsters while quiet and 2 more for each player in it past the first 3, up to 24,
respawning in 10-20 s while it wants more than 8 (20-40 s quiet); a crowd leaving removes nothing, the extras just
aren't respawned (checked every 2 s; Studio's `/crowd <n>` counts extra players). Monsters stand on the terrain (the
ground ray hits terrain, not water) and never step up or down more than 1.5 studs, so they keep off cliffs, shelves
and the stream. **Boss portals:** each zone's boss has a portal in its biome (the obsidian arch, 20 studs, with a purple
swirl and purple-glowing lava, `Town.PORTAL_LOOKS.Boss`, and a trailhead board with its name and recommended Power)
with the usual Fight and Start group prompts. A fight goes to one of 4 copies of the boss's arena far from the valley
(`Bosses.ARENA_COPIES`; `WildValley.ARENA_FIELD`, x 1600-5200, z 1200-3600): the copy is held while it streams in on the
fighters' devices, everyone is checked again, then they're moved in and the ring seals. Each copy keeps its zone's
look (`ARENA_LOOKS`: grass floor and wooden fence, slate floor with stone posts and blue crystal tips, basalt floor
with lava cracks and basalt posts with ember tips; floors 0.15 above the terrain) on a terrain clearing (124 studs
wide in the grove, 164 in the hollow and the lava field: `ARENA_CLEARING.size`), and is dressed
as a place of its own round its boss (`WildValley.ARENA_DRESSING`, laid out by `Util/WildValley.arenaDressing` from a
seed, the same every start; spec `2026-11-01-wild-bosses-arenas-design.md`): rows of wall pieces all round and inner
pieces between the fence and the walls, clear of the fight, the path and the way home. **The Warden's grove:** mossy
standing stones (14-20 studs) inside a ring of giant old trees (36-46), flowers, bushes and roots, fireflies and
drifting leaves, a sunny afternoon. **The Broodmother's hollow:** stalagmites and rocks 74 studs out under a rock dome
(`CaveDome`, 64 tall, about 170 across), webs, bones, cocoons hanging from the ceiling (each one's top where the dome is
over it: `WildValley.ceilingAt`, from the dome's shape in `roof.profile`) and 10 blue crystals, glints and low mist,
dim and cold. **The Behemoth's lava field:** basalt cliffs with glowing lava cracks (30-40 studs) 74 studs out, charred
trees and obsidian shards, the caldera's volcano 180 studs behind (130 tall), embers and falling ash under a red-orange
haze. The hollow and the lava field first had their walls 56-57 studs out; the user found both too tight and the lava
field too dark (its look brightened), so they stand at 74. Each
arena's sky is its own (`DayCycle.ARENA_LOOKS`: time of day, light, haze, bloom and colour), applied on the client
while the player is in one of its copies (`WildValley.arenaZoneAt`), never night. Each loops its own ambient sound at
its centre (heard out to 90 studs: "Jungle Dawn 1", "Water Cave Trickle Thin Into Small Puddles 5", "Fireplace Constant
Burning Flame 4"), under the boss drone. The way home stands inside the walls on the -X side, 46 studs out
(`ARENA_HOME`), in its zone's look: the root arch (`PortalWild`), the ice-blue crystal ring (`PortalFrontier`), the
obsidian arch with the canyon's lava (`PortalArena`). Return sends a fighter back to the boss's portal once
the fight is over; anyone still there is sent back 60 s after it ends (`ARENA_LINGER`), loot they haven't picked up
going into their Bag first (also when they leave a copy any other way: the Shop button, a respawn). Invisible
walls ring each copy 4 studs inside its innermost wall row (24 sides, `WildValley.arenaEdge`, `ARENA_EDGE_INSET`), so
nobody walks out between the wall pieces (the hollow's roof doesn't collide). Under each copy a flat ground part 360
studs wide, coloured to match its clearing's terrain and its top half a stud under the drawn ground, runs on past the
walls (`ARENA_CLEARING.ground`, `WildValley.arenaApron`; a part, since terrain that wide is about 86k more cells), so
looking straight down from full zoom never shows the clearing's edge. A copy takes a new fight once its boss is gone and its fighters have left it (left the
game, respawned at their shop or gone home). Solo fights never wait behind a forming group while a copy is free; when
all 4 are busy the gate says so. Cliffs and hills close every side, with invisible walls along the edge (y -10 to 80, `EDGE_WALL`); travel to the
Wild waits until the valley's terrain has filled at server start (`WildTerrainReady`). Layout: `Config/WildValley`
(biomes with their outlines, heights, portal and board spots, the trail with heights, passes, hills, terrain fills
and carves, props, stream, bridge, cave, cracks, vents, volcano, population, spawn spot rules, signs, arena field and
looks, edge); rules in `Util/WildValley` (the trail and markers, which biome a spot is in, what scenery keeps clear of,
spawn spots, the terrain fills, arena copy spots, how far a monster may step) and `Util/WildPopulation`, Lune-tested.
SceneryService fills its terrain with the town's and places the dressing on the drawn ground; WildService builds the
spawn spots, signs, edges, return portal, boss portals and arena copies and runs the population check; BossService
hands fights to free copies. The Frontier and the Dungeon keep their own maps and single rings.

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
(bottom-right corner) shows its perk (element icon, colour, +%); hover or tap it for what it does and which card it comes from. Left of it, the party bar (a cream
cushion, `Config/Party` BAR, see "Creature pals HUD" in 10.6) shows a "Party" pill (opens Party, as does tapping the
cushion) and the 3 party slots as round portraits: the card's art in a white ring with "Lv 4" in a white pill under it,
a key chip 1 / 2 / 3; the summoned one is bigger with an orange ring, an orange glow and an OUT tag; an empty one is a
faint ring with a "+"; a resting one dims with an hourglass over "2:41". Each sits in a 70 px tap area (48 px at the
smallest HUD scale). Tap a slot or press 1 / 2 / 3 to summon it, again to unsummon;
an empty one picks a card in the binder. Hovering a card (or holding a finger on it for `UIStyle.LONG_PRESS`, which
then doesn't summon) shows its tooltip above the bar (`CardTips.copy`): the card, name, grade, level, Power, HP / ATK
/ SPD bars, its perk and the resting countdown, so you don't need the binder. When the party changes, a toast says
so ("Cindercub joined your party!", "Cindercub swapped in for Ashbeak!", "Ashbeak left your party";
`PartyRules.changes` / `changeText`, Lune-tested) and the slot a card joins pops up with its ring flashing gold
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

**Fight perks** (`Party.FIGHT_PERKS`, `PartyRules.getFightPerk`, `BattleSim`): in monster and boss fights (not PvP) the
same perk also works in the fight, from the creature fighting for you right now (swap and it changes), same growth
rule:

| Perk | In fights | Common, 0 stars | Legendary, 5 stars |
|---|---|---|---|
| Hype | your sword and your creature hit harder | 6% | 27% |
| Calm | you and your creature take less damage | 5% | 23% |
| Express | sword skill, element ability and signature recharge faster | 8% | 36% |
| Hustle | your creature attacks faster | 5% | 23% |
| Haggle | chance of a critical hit (double damage, "CRIT" number) on your sword and creature | 6% | 27% |

The combat HUD shows it as a chip under your creature's bar (and a toast on a swap); the Party panel, the party bar's
card tooltip and the buff badge's tooltip add a "Fights:" line. The boss balance tool gives every party its perks and
the bosses were retuned so the targets below still hold.

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
Stars come only from the **Card Condenser** (a machine bought in the build menu, shop Lv 5, $500; no level gate,
levels raise stats only). Press E on it: the window is "tidy two panes" (owner's pick A, spec `2026-11-04-round4-design`
section 3): a sky band with the Condenser icon and "N ready", one toolbar (search, then All / Ready / Raising; Raising
is everything not ready), the cards as slim rows (a Ready tag, "x21 · 4 copies for the next star" or "3 of 4 copies"
and a thin bar, `CondenseRules.rowLine`), and the chosen card on the right: its stars, Power and Value before -> after,
"Keeps Grade S · Lv 14 · uses 4 Grade C" with Change (the copies to keep), one big Condense +1 star and a small Star
Shards toggle (off: Ready counts copies only and Condense never spends shards). Buttons sit 12 px in from the pane's
edges and centre-anchored; hover never grows anything (round 5), so nothing is cut off.
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
A machine bought in the build menu (Fixtures, shop Lv 14, $5,000; `Config/Shelves` kind `Grading`), a code-built
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
| 1 | Meadow Warden | Meadow | Bloom | 6 | 1300 / 7 / 8 | 200 | - | 4 | open |
| 2 | Cave Brood Queen | Caves | Shade | 11 | 2600 / 10 / 12 | 350 | heals 15% below half HP, every 12 s, 3 times at most | 7 | 3 Brood Queen Key Fragments |
| 3 | Ember Colossus | Ember Ridge | Ember | 16 | 6300 / 29 / 9 | 650 | enrages below half HP (ATK x1.5) | 14 | 5 Colossus Key Fragments |
| 4 | Frost Tyrant | Frontier, Frostwood | Tide | 22 | 14900 / 46 / 9 | 1100 | ice shield (6% HP) every 20 s; breaking it stuns it 3 s | 26 | 5 Frost Tyrant Key Fragments |
| 5 | Storm Sovereign | Frontier, Stormpeak | Volt | 32 | 28000 / 44 / 14 | 1500 | thunderclap every 14 s (2.5 s base): stuns your creatures, shorter on fast ones | 34 | 8 Sovereign Key Fragments |
| 6 | Rift Devourer | Frontier, The Rift | Shade | 45 | 34000 / 66 / 10 | 1900 | 2 Rift Spawn at 50% HP (5% HP each): hit first, boss takes half damage meanwhile | 43 | 8 Devourer Key Fragments |
| 7 | Prism Hydra | the Dungeon (after 3 rooms) | by phase | 55 | 60000 / 38 / 11 | 2400 | five phases, one per element (below) | 57 | 10 Hydra Key Fragments |

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
  group, below). In the main game's Wild valley the gate is a portal in the zone instead and each fight gets its own
  arena copy far away (up to 4 per boss at once; see "The Wild valley" above). The ring (radius 36) seals while a fight runs: the members are moved just inside the gate and a
  see-through wall rises all round (`BARRIER_*`), dropping when the fight ends for any reason. Anyone else inside the ring when it seals, and a group member who
  leaves a fight that goes on, is moved out through the gate. Boss fights may last 420 s (`Combat.BOSS_MAX_FIGHT_SECONDS`), the leash is 42
  studs, stuns on a boss last at most 1 s.
- **Intro:** a boss fight opens with 6 s of drama (`INTRO_*`): the camera flies to the boss, its name and title show
  (e.g. "Guardian of the Meadow"), it roars (camera shake; the three Wild bosses also rear into a roar pose with their
  own sound from the model, `moments.roar` at `ROAR_VOLUME` 0.8), then 3, 2, 1, FIGHT. Nothing moves and no button works
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
- **Swaps:** in boss fights the bar's "Bring in <card>" buttons send in any rested party card for your summoned
  creature (only one of yours fights: boss fights have no call-in, `SideInput.callIn = false`); it goes back to the
  bench with its HP. Swaps wait 8 s between them (`Combat.BOSS_SWAP_SECONDS`), except when none of yours is standing;
  when yours faints, your healthiest rested card comes in by itself. A swapped-out summoned creature is hidden until it
  comes back (`BattleSim.swap`, Lune-tested).
- **The player in the fight** (spec 2026-11-02-you-in-the-fight-design): in every boss fight (the Wild's, the
  Frontier's and the Prism Hydra) each player fights beside their one creature as a player fighter (`a:@<UserId>`,
  100 HP, `Combat.PLAYER_HP`). Their sword (from shop level 4, `Config/Swords`, `SwordService`) hits through remotes
  `SwordAttack` (the server picks the combo's next cut with `SwordRules.nextCut` and hits whatever is in reach at its
  strike frame), `SwordSkill` (the dash slash, 12 s cooldown since 2026-11-09, was 8: every foe along the path from
  where they started to where they are when its cut lines appear, the path clamped to the dash's longest plus 3 studs, `SwordRules.clampPath` /
  `inDashPath`) and `Dodge` (untouchable 0.35 s, 2.5 s cooldown since 2026-11-04, was 1 s; the
  dash is the client's), all rate-limited; damage is their creature's ATK x the cut's power. The boss sends about a
  third of its swings at players as quick hits (a 0.5 s flash, then `quick` of their HP) and every `every` seconds a
  big attack: a closing orange ring (`SwordFx.RING_COLOR`, the owner's pick) on each player, a slam under them or a
  swipe from the boss toward them, one shape per boss (`playerAttacks.shape`: Meadow Warden, Ember Colossus, Frost
  Tyrant and Storm Sovereign slam; Cave Brood Queen, Rift Devourer and Prism Hydra swipe; the sim still tosses its old
  coin so fights draw the same randoms) (`Bosses.RING_*`), landing after its warning for `big` of their HP unless they stepped out (`RingRules`) or dodged
  (`Bosses.playerAttacks`, stronger up the ladder; hits land `Combat.HIT_GRACE` after clients show them). At 0 HP a
  player kneels (character attribute `Downed`, no walking) and gets up after 5 s with half their HP while one of their
  creatures stands. Boss shields, heals, thunderclaps and Healing Rain never touch players; Tidal Shield does (owner
  2026-11-05: its ward covers the caster's player and every ally, the boss's hits on players hit it first). You lose when you're
  down and none of your creatures can fight: the defeat screen counts down `Combat.LOSS_COUNTDOWN` 5 s (it can't be
  skipped; see "Defeat screen" below), then home (`BossRules.lossHome`, `WildService.SendToSpring`): the main game's plaza
  spring, the Frontier's entrance spring; the Dungeon's run handles its own. In a group a player who is out stays,
  kneeling, until the fight ends, and a win counts for them too.
- **Sword, controls and feel** (same spec): everyone gets the Steel Sword at shop level 4 (`Swords.UNLOCK_SHOP_LEVEL`,
  when boss 1 opens; worked out from the level, so no save change) with a one-time "You got your first sword!" popup
  (`seenSword`). It rests on the back everywhere (hilt over the right shoulder, the blade down to the left hip, every
  sword's tip clear of the ground, near life-size: `Swords.BACK_SCALE` 1.05), is drawn on the first attack (gleam, unsheathe sound) and goes back after 4 s without one
  (`SHEATH_SECONDS`). The model is `assets/weapons/StarterSword.rbxm` (built in Blender, docs/animations.md). The
  starter combo and skill are the sword moves round's (below). Every sword gets its own combo and skill (Forge swords,
  project 2, also their own look and effects). Weapons come in families (owner 2026-11-04: sword, spear, scythe, maybe
  later a hammer or dual blades), each with its own moves, reach and feel, trading reach for speed so none is simply
  better; rarity works inside each family (rarer: more effects and better numbers). Not built yet. Its 12 moves are keyed in Blender on the standard R15 body and exported
  as KeyframeSequences (`assets/animations`, docs/animations.md), published (ids in `Config/Swords`; the round's four
  new moves play unpublished in Studio until the owner saves them);
  the HUD's art, the sword's sounds, its moves and model download behind the loading screen (`Util/CombatAssets`, ids listed
  by `Util/CombatPreload`: every attack, pet move, boss roar, summon, creature voice and level-up sound too), so the first
  fight starts ready. Every one of those sounds stays loaded all session (`Util/SoundBank` keeps one silent copy each;
  one-shots are made from it): measured 2026-11-05, Roblox drops a sound's audio once no Sound holds it, so a sound made
  on the spot loaded again each time (a boss move 0.3-0.5 s late every time, the first plays of a fight 3-5 s late or
  silent when their holder was gone first; the owner: "some are delay some doesnt play"). After: every fight sound
  starts within 2 frames, for about 22 MB more sound memory (half of it four long loop beds: Healing Rain's rain, the
  Curse's drones). Players wear the standard body
  everywhere (their own head, face, hair and accessories kept), and in boss fights back accessories (capes, wings,
  backpacks) hide.
  Controls: the HUD's slanted neon buttons (style 3 "anime slash", `Config/CombatHud`, sheet 5 icons, placed by
  `UiLayout.combatButtons`): Attack, Dodge (Shift; Shift Lock moves to Ctrl), Skill (E), Pet skill (R),
  Signature (Epic and Legendary cards) and Run. Swaps are the **party strip** under the status (the owner 2026-11-05,
  option A: "add an indication who to summon, for good UX not just numbers"; it replaced the small Swap button): a tile
  per party card with its painting and name, its key 1-3 on a gold chip (PC; the party slot as the party bar numbers
  it, `SwapKeys.party`/`pick`, Lune-tested). Its look (option C, the owner: "Remove strong/weak/out just add an effect
  or animation or icons for who's out/dead"): the one fighting has a green light running round its edge and a
  heartbeat pulse in place of its name; a card that fainted in this fight lies face down (the card back's blue) with
  dizzy stars, one resting since an earlier fight face down with "Zzz"; while swaps cool down the others dim with the
  seconds left; a tap swaps (looks in `Config/CombatHud` PARTY_STRIP). A key while swaps cool
  down still says "Swap ready in 4s", a resting card says so (2026-11-04). The dodge is a 12-stud dash pushed by a velocity constraint in the ground plane (setting the velocity each frame
  lost half of it to the character's braking), and one that would end inside a boss or monster carries on through it
  to 1.5 studs past its edge, up to 26 studs (`SwordRules.dashLength`, owner 2026-11-04). With a mouse a click attacks and there's no Attack
  button (owner 2026-11-03: phones, tablets and devices without a mouse keep it); the Pet button takes its corner and
  Dodge and Skill move up beside it (`UiLayout.combatButtons(view, noAttack)`), and the first-sword popup says "click
  to swing, Shift to dodge" instead of "tap Attack". Top-left your headshot in a bevelled ring with
  your creature's card on a badge, beside your HP and your creature's in slanted neon bars (`Util/HpBar`, ticks every
  20%); the boss's HP is a plate across the top (owner 2026-11-04, design A: gold-edged, the boss's element in a
  gold ring, its name big with its title and level under it, the bar with the HP number on the right; `TOP_BAR` in
  `Config/CombatHud`), a normal monster's a slim red bar with its name and level over it (an elite's gold with an
  ELITE tag; `HpBar.setLook`). A hit drops the fill at once and leaves a ghost of the
  lost HP (red on yours, pale gold on the boss's) that holds 0.35 s, then drains in 0.45 s, with a white flash; a heal
  moves a pale lead ahead and the fill rises to it. When you're hit the portrait shakes with a red ring and the
  screen's edges flash red for 0.55 s, stronger for a bigger share of your HP; below 30% HP they keep pulsing
  (`Util/HpBarRules`, numbers in `Config/CombatHud`). Jumping is off
  in boss fights (the dodge replaces it). Attacks turn you softly toward the boss; the camera stays free; the server
  checks every hit. Feel (`Config/SwordFx`): hit-stop (below), a white flash on what you hit, sparks, camera shake, a
  slash trail on the blade, damage numbers, dodge after-images, closing rings (look B) and the boss's wind-up glow
  (orange for a big attack, red for a quick hit). Sounds: Roblox-licensed Pro Sound Effects (`Swords` `sounds`),
  each kept loaded on your character and replayed at a pitch picked from `Swords.SOUND_PITCH` (0.88-1.12) each time, and
  the fight effects' sounds at a pitch and loudness from `AttackFx.VARY` (owner 2026-11-04: nothing the same over and
  over); the hit sound plays the moment the blade lands when your own reach
  check connects (the server's hit arrives a round trip later and only sounds if that check missed,
  `Swords.HIT_SOUND_WINDOW`). Buttons show their names underneath in your first 3 boss fights (`CombatHud.NAME_FIGHTS`,
  counted in saved `swordFights`); the pet and signature buttons are named after the creature's moves. Resting the
  mouse on a button (or holding a finger on it for 0.4 s, which doesn't press it) shows a tooltip saying what it does,
  in one short line; the Pet and Super buttons say what the creature's own moves do, with their numbers (owner
  2026-11-05: "explain what the skill does on the tooltips"; `SkillText.buttonTip`, the card view's words).
- **Sword moves round** (spec `2026-11-04-sword-moves-design.md`, plan `2026-11-04-sword-moves.md`; owner: "satisfying,
  smooth, dramatic, anime-ish, hack and slash, not Roblox-stiff"): four new Steel Sword moves keyed with per-key easing,
  joint overlap and 60 fps export (`tools/blender/anim_kit.py`, `anim_starter_sword.py`, exported in place in a
  background Blender by `run_sword_moves.py`; docs/animations.md "Natural motion"):
  - **Cut 1, forehand:** coiled high, a snapped diagonal cut down across. 0.60 s, strike 0.217 s, power 0.298.
  - **Cut 2, backhand:** from low on the left, a rising sweep out to the right. 0.58 s, strike 0.183 s, power 0.298.
  - **Cut 3, finisher**, both hands on the hilt (an IK grip; owner 2026-11-04: a big jump with a hang, a cool-down
    finish): a deep crouch, a spinning leap about 5 studs up, a slow-motion hang at the top (0.31-0.56 s, in the keys;
    `Swords` `hang`) while your camera eases in 7 degrees (`SwordFx.HANG_ZOOM`), a hard fall into a slam that stabs the
    sword into the ground, then kneeling over it head bowed before standing. 1.25 s, strike 0.70 s, power 0.776.
  - **Skill, the dash slash** (replaces the spin): a draw stance, a 9-stud dash that goes through foes like the dodge
    (`SwordRules.dashLength`, at most 20 studs), the cut lines and the damage at 0.62 s on every foe whose edge is
    within 2 studs of the path. 1.0 s, power 0.9, 8 s cooldown.
  - **Chaining:** a tap during a cut queues the next at its cancel point (cut 1 0.34 s, cut 2 0.32 s;
    `SwordRules.nextCut`), so the recovery only plays when you stop. The damage a second is measured on that chained
    cycle (0.34 + 0.32 + 1.25 s) and kept what it was (within 2 %, tests/SwordsConfig); both balance sims chain on the
    cancel points and their targets hold. A chained cut ends the one before (they'd blend at the same priority), a
    dodge, a knock-down or the fight's end cancels a cut queued for its cancel point (its lunge, arc and hold never
    come), and no cut starts while the dash slash plays (`Util/SwingGate`, Lune-tested). The server still lands a
    queued cut a dodge cancelled on screen (a known gap, final review).
  - **Lunges:** each cut carries you forward for real (1.1 / 0.8 / 3.0 studs, `Swords` `lunge`), stopping 1 stud short
    of a foe's edge (`SwordRules.lungeLength`, `Swords.LUNGE_STOP`) and planting you at the end (no slide). The moves
    are exported in place; the game moves you, one push at a time shared with the dodge.
  - **Walking is held** from a cut's start to its cancel point and through the dash slash (and you don't auto-turn), by
    setting the humanoid's move back to nothing after Roblox's controls each frame (this game has no PlayerModule). A
    dodge, a knock-down, the fight's end or a new character gives it back; a dodge mid-swing goes the way you're
    pushing.
  - **Hit-stop:** 0.08 s on a cut, 0.12 s on the finisher and the dash slash (`SwordFx.HIT_STOP`), played the moment
    your own reach check connects; those two also shake harder. Strikes blend in over 0.04 s (`SwordFx.FADE`).
  - **The skill button** says DASH with a dash slash icon (`DashSkill`; tip "Dash through and slash everything in your
    path."); a round 1 sword's own skill shows its own icon, name and tip instead (5.11 "Sword skills"), and every
    skill's tip ends "Dodging before it lands cancels it."
  - **Sounds** (owner 2026-11-04: a whoosh as the finisher jumps, fuller slashes; all Pro Sound Effects): each move
    plays its sounds layered at set moments (`Swords` `cues`, stopped by a dodge): a cut's swish with an air layer at
    the snap (not the tap); the finisher a rising whoosh as it leaps, its swish on the fall, a hard whoosh-impact on
    the slam and a dirt hit as the sword stabs the ground; the dash slash a drawing shing, the dash's whoosh and a
    searing slice with the cut lines. Every hit is the blade's slice with a thud under it, big hits (the finisher, the
    dash slash) a beefy burst on top. Layers play quieter than the swish (`Swords.SOUND_VOLUMES`).
- **Creature attacks** (spec `2026-11-02-attack-animations-design.md`): in every fight the sim sends a `charge` event
  0.6 s (`Combat.CHARGE_LEAD`) before each auto-attack lands (it draws no random: fights and the balance numbers are
  unchanged). Creatures circle their fight spot (marker attribute `InFight`, `Util/FightMotion`, `AttackFx.ORBIT`: 4
  studs, a lap about every 7 s, darts) facing the way they go (`FightMotion.heading`; owner 2026-11-05: they used to
  keep facing the foe and strafe, "Thunderhorn is walking sideways"), and turn back to the foe and stop to charge: a
  crouch and a glow in their element colour with sparks
  pulling in. Then the element's attack (`Config/AttackFx`, `Util/FightFx`, pieces in `Util/ElementFx`, poses `charge`,
  `strike`, `combo`, `cast` in `Util/PetRig`): Ember a fireball in an arc, Tide a water blast, Bloom a dash in and a
  3-hit vine lash, Volt a flickering lightning bolt shot from where it stands (the owner's mockup: flares at both
  ends, 0.27 s, `AttackFx.BOLT`; at grade S the strike from the sky 0.14 s after), Shade a moon slash (owner
  2026-11-05: "a ranged moon slash dark purple"; kind `slash`, `AttackFx.MOON_SLASH`, `ElementFx.moonSlash`): a paw
  swipes and flings a crescent of dark purple moonlight with a white core, dragging a shadow behind it, that flies like
  a projectile (0.3 s) and lands in a slash; grade A flings a second crossed the other way, S a third flat across. Shade
  creatures stand back like the other ranged ones (`FightFxRules.isRanged`). The limbs attack with the body (owner 2026-11-05: the Eclipse Fox "doesnt have a basic attack
  animation"; `Party.PET_ANIM` `ATTACK_*`): the charge lowers the head and raises the tail, a strike bites, a combo
  swipes a front paw (two-legged rigs: an arm) each third, left, right, left, the head dipping with each, and a cast
  rears the head back then thrusts it forward. Studio: `/attackfx [C|B|A|S]` plays three of your summoned creature's
  basic attacks at a dummy. Ranged attackers (a projectile or a bolt: Ember, Tide, Volt, `FightFxRules.isRanged`) stand
  `Combat.RANGED_BACK` 7 studs further back from the foe than their ring spot (owner 2026-11-03, "ranged, not
  melee": 13 studs from a wild monster, 22-28 from a boss), set on the server (`BattleService` `standSpot`; a swap or
  call-in takes over the ring spot, `ringSpots`); Bloom and Shade stay close. A creature that joins mid-fight (a
  swap, a call-in, a PvP extra) gets a marker made that moment, which a remote delivers as nil, so fight payloads
  also send each marker's name (`markerNames`, `Util/MarkerNames`) and the client finds it in `workspace.Creatures`
  (until 2026-11-03 such a creature had no attack effects). Each lands with the
  sim's `attack` event and its damage number (`Util/AttackTiming`); the final hit waits for that event, so a charge
  whose attack never comes (a stun, a faint, a swap) fades without a hit, and an attack that comes uncharged strikes at
  once. The hit lands in the sword hit's pack look (owner 2026-11-09, "slashes on slash attacks and no slash on non
  slash attacks", all elements; `Util/PackHit`, `FightFxRules.cuts` / `hitSpecs`): a cut (the Bloom combo, the Shade
  moon slash) with the slash streaks and arc in its colour, a fireball or bolt (Ember, Tide, Volt) with its star burst
  and the spark streaks; the element's own particles on both (`SwordFx.ELEMENT_HIT`); sized to the foe like a sword
  hit (`PackHit.scaleFor`: a wolf about 1.2, the Meadow Warden about 3, times the grade); a combo's earlier hits and
  the extra moon slashes lighter (`AttackFx.LIGHT_HIT`: 0.8 the size, half the particles; the old vine slash sprites
  only for grade S's finishing X). At most 12 effects play at once (4 with the low-graphics switch off,
  `Util/FightFxRules`; the pack particles thin out too, `ElementFx.detailShare`). Sounds: Pro Sound
  Effects (`AttackFx.SOUNDS`). A broken effect never stops the damage numbers (the call is guarded).
  Pet button moves and super moves wind up first (owner 2026-11-04, design A): the press spends the cooldown (a
  super: the meter) and the
  sim sends a `cast` event, then fires the move `Combat.ABILITY_WINDUP` 0.5 s later unless the caster has fainted or
  left (`BattleSim` casts). Super moves wind up their own time (spec `2026-11-05-super-moves-design.md`): Epic 1.5 s,
  Legendary 2 s (`Combat.SIGNATURES.<card>.windup`, the cast carrying its `look`), while the caster's cinematic plays;
  the caster's player can't be hit from the press until control returns (the wind-up + `Combat.SUPER_PROTECT_TAIL`
  0.6 s): hits due then miss and the boss starts no new quick hits or rings at them meanwhile; a super whose caster
  faints first fizzles (a `fizzle` event) and the protection ends with it; its creature can't be swapped out until it
  lands; a creature winding up its super doesn't auto-attack until it lands (owner 2026-11-05). Tidal Shield wards
  every ally on the caster's side still in the fight (players and benched creatures too): a shield of `shield` of its
  own max HP for `seconds` (30% for 8 s;
  the sim's per-fighter `ward`, taken before a boss's side shield, on creature hits and on the boss's hits on
  players), a `shieldGone` naming whose when it breaks or runs out; before, one shared pool covered the creatures only
  and never ran out. The boss balance tool fires every Epic and Legendary card's super whenever it's ready (see the
  balance note below). Meanwhile the creature holds still in a big glow, a ring in the move's colour spins under
  it (`ElementFx.castRing`) and the move's name pops above it on a plate ("VINE SNARE!", `ElementFx.callout`), so
  everyone sees it coming. The moves (`AttackFx.SPECIALS`, `ElementFx.special`) land with their `ability`
  event: Fireball a blast and a fire ring on the ground; the other four Pet button moves are finished (spec
  `2026-11-05-pet-moves-design.md`; the owner: "the higher the creature grade the better the skill must look and feel"):
  each is drawn by `Util/MoveFx` from `Config/MoveFx`, a look per grade C, B, A, S (every grade a step up, Lune-tested;
  `Util/MoveFxRules` plays C for a creature with no grade and caps at B with the low-graphics switch off), its own
  Roblox-licensed sounds, and the creature's wind-up and cast pose growing with grade (`PetRig.body` amount). Healing
  Rain: a cartoon cloud over each creature it heals with rain falling on it (beams with a scrolling drop texture), a
  glow, a rising "+N" each tick (gold at S); ripples (B), healing motes (A), rising water rings and a rainbow (S). Vine
  Snare: vines (C, B) or thorny roots (A, S) climbing round the target on helices for its 4 s, then withering; leaves,
  thorns, dirt, a glowing crack and flowers by grade. Overcharge: three orbs circling the caster, one spent with each
  fast attack (the sim's `orb` field; a missed one fizzles on an `orbs` event), arcs between them (A), a bolt with
  each hit (A) or a thunderbolt and flash (S). Curse: a seven-point rune circle under the caster as it casts, then a
  hex (B), shadow chains (A), a dripping eye sigil over the target, a dark aura and smoke, the target darkened, for its
  5 s. Studio: `/movefx <rain|vine|orbs|curse> [C|B|A|S] [big]` and the admin panel's "Pet moves" buttons play any of
  them on your summoned creature against a dummy. Cost measured 2026-11-05 (render CPU, a fixed camera on the 14-stud
dummy, each move at grade S): at most +0.34 ms at graphics level 10 and +0.63 ms at level 1 over a 13.2 ms baseline.
Vine Snare's vines are solid tapering stems (cylinders with ball joints, wood at A and S) winding fewer turns round
a foe wider than it is tall. A kind with no entry plays nothing (`FightFxRules.hasEffect`).
- **Super moves** (spec `2026-11-05-super-moves-design.md`; the owner: "way epic/cooler looking" than the pet moves,
  "screen shakes / cinematics / particle effect / sound effects"): ten looks (`Config/SuperFx` LOOKS, by the super's
  `look`; the Frontier four have their own), drawn in the world for everyone by `Util/SuperFx` (routed from
  `Util/FightFx`: the charge from the press, the impact and linger with the landing; every look's big moment shakes
  the screens near it, `AttackFx.SHAKE.super` times its grade's shake; Inferno and Magma Slam's creature leaps high to
  wind up (`LOOKS.<look>.windupPose`, PetRig "leap") and drops back down as the move lands)
  and, on the caster's screen only, `Util/SuperCinematic` (driven by BattleController): the camera swoops to the
  creature (40 degrees off straight ahead, 2.2 of its heights out and 0.6 up, then backing off to 2.7 and 0.8 as it
  charges so a wind-up or leap fits, never nearer than 10 studs or lower than 4: owner 2026-11-06, "sometimes camera is
  too low or too close"; pulled in front of walls every frame; owner 2026-11-05, "sometimes ... the
  creature gets covered by the player or the boss": the shots stand off to whichever side has fewer players,
  creatures or bosses in front of it, `SuperFxRules.shot` side, and any still between the camera and the creature
  fades out on the caster's screen, `CAMERA.fade` through `LocalTransparencyModifier`, tested on their bounding boxes
  because creature parts can't be raycast), the card's painting slides across
  with the move's name in a wash of its colour, then the camera snaps to an impact shot framing the creature and its
  target with a shake and a flash, and eases back; the HUD hides, the character holds still and the sword waits
  (`SwordController.Pause`) until control returns; a fizzle, the fight ending or leaving cuts back at once. Legendary
  adds letterbox bars, its own sky grade over the world (`LOOKS.<look>.sky`: deep space, a storm, the world dimming,
  clouds parting) and a black-and-white impact frame (twice for Supernova at S; a soft white flash with the extras
  switch off). Every look grows with grade (`SuperFxRules`, Lune-tested) and has an S extra: Inferno's fire tornado
  (owner 2026-11-06 "make it more visible": a wide funnel of flame round the boss with a white-hot core spinning the
  other way, flames pouring up it, a dark smoke cap and a strong light, standing 2.8-3.8 s by grade),
  torrent and burning ring (S: lava cracks); Magma Slam's racing lava cracks, geysers, falling rocks and crust (S: a
  lava ring at the landing); Tidal Shield's wave crashing over your side, leaving a water bubble with spirit koi round
  every warded ally (S: rainbow sheen), each bubble following its ally, rippling with each hit its ward soaks (the
  sim's `absorbed`) and bursting when that ward ends (`shieldGone`) or the fight ends; Tidal Blessing's parting clouds,
  light rays and a lotus closing into a column of light, a pillar of light coming down on each creature it stands back
  up on the field (clients play `SummonFx.revive` as the server clears the marker's `Fainted`; a benched one clears it
  when it comes back in), "REVIVED!" over the Kirin, light shimmering up off everyone it heals and a soft rain of light
  (S: a halo, golden rain); Stampede's lightning dash through the boss with afterimages (one stripped copy of the model,
  then one copy a frame: six full clones in one frame cost a 45 ms hitch) and stun rings (S: a
  sky bolt); Eclipse (owner 2026-11-05): the fox holds still (`windupPose` "still") as a five-point star sigil
  draws itself under it and a black moon slides over the sun, then it glows dark purple and a see-through mirror image
  at its side copies its every pose and move (its bones copied each frame) and strikes with it (`SuperFx.echoHit`, a
  shadow slash with each of its hits) while hits pass through in shadow, for 5 s (S: two mirror images); Rift Step's
  cracks in space round it, then it shatters out of where it stands, rifts tear open round the boss (one a hit:
  behind, side to side, in front; `SuperFxRules.riftSpots`) and it bursts out of each in turn as the sim lands that hit
  (`SuperFx.blink`, the creature put at the rift by `CreatureController.Blink`), striking in a void slash, then shatters
  back home and the rifts seal (S: the arena's edge cracks); Supernova at its own pace (owner 2026-11-05: "dont rush",
  `LOOKS.Supernova.windup` 3.5 s and `timing`): the sun grows over its hands (40%), rises slowly high over the boss
  (45%), hangs there throbbing and swelling, pulls in and bursts there (`grades.burst` studs up; the cinematic's charge
  and impact shots frame that point, `SuperFxRules.shot` sky): a big white-out and two rings in the sky, fire raining
  down, then a dome of fire, rings, rays and shimmer (S: light pillars); Stampede's thunder crack and roll on impact; Thunderstorm's storm clouds, colossal
  bolt and forks, rain and crawling sparks (S: three bolts, a chain round the arena); Devour's black hole, spectral
  jaws and streams of life back to Voidmaw (S: two bites). Each look has its own licensed sounds (`SOUNDS.<look>`: call,
  charge, impact, an A/S layer, a linger loop where it lasts), kept loaded (`CombatPreload`/`SoundBank`); every super
  and Pet button move sound is turned down by how loud it measured (owner 2026-11-05: "adjust skill volumes make sure
  its not too loud"; `Config/SoundLevels`, `Util/SoundLevel`: PlaybackLoudness measured in Studio, the 70 combat sounds
  ranged from about 1 to 450; above the target 120 a sound plays at (120 / level) ^ 0.75 of its volume, so the
  Avalanche, Gas Fire Explosion, Glass Breaks, Wolf Howl and Rock Impact layers come down to 35-50% while chimes keep
  theirs; `tools/audio/sound_ids` and `measure_loudness` for new ones); new textures
  from `tools/textures/make_super_fx.py` (`assets/ui/fx-super`). Studio: `/superfx <move> [C|B|A|S]` and the admin
  panel's "Super moves" buttons play any of them with the cinematic on your summoned creature against a dummy. Cost
  measured 2026-11-05 (render CPU, each look at S from the client): a 9.6 ms idle baseline, at most 11.8 ms average
  (Magma Slam) and no frame over 18.3 ms; four at once 10.6 ms average, 14.4 ms worst.
- **Boss moves** (same spec): a boss with keyed clips has four (`ReplicatedStorage.MonsterAnimations/<boss
  id>`, docs/animations.md "Bone rigs") played by `Util/MonsterMoves`: a `windup` before each hit (0.6 s before a
  creature hit, over the 0.5 s warning before a quick hit on a player, no glow), the `strike` as it lands with an
  impact there, the `specialWindup` over a ring's warning with sparks in its colour pulling in, then the
  `specialRelease` as the ring lands, with its effect over the ring (`Config/AttackFx` BOSS, `ElementFx.monsterStrike`,
  `ElementFx.bossRelease`). One move at a time: a group hit is one strike, nothing interrupts the special. Meadow
  Warden: branch swipe (leafy slash, dust) and root slam (big roots, taller than a player, burst up across the ring and curl outward, one thick one in the middle; green shockwave). Cave Brood
  Queen: fang stab (front legs raised, then driven down; claw slashes, poison splash) and web spit (rears with wings
  up, then lunges; made big 2026-11-03 at the owner's ask: from her fangs, half her height up, a burst and 12 thick
  strands land across the whole cone with 7-stud splats, and a fan of web, 7 spokes and 4 cross threads, sticks over
  the cone for 1.4 s; `ElementFx.bossRelease` takes the boss's height; 2026-11-04: 35% of webs come huge, 1.8x as long
  and 1.6x as wide, 47 studs and 56 degrees, `Bosses` hugeSwipe, `RingRules.swipeSize`, the warning, the web and the hit
  check all that size). Ember Colossus: horn gore (sits back, head low, then
  tosses its horn; fiery burst, rock dust) and lava slam (rears on its hind legs roaring, then crashes down; fire
  shockwave, glowing cracks, molten rocks; owner 2026-11-04, design A "meteor slam": as its ring appears a huge
  fireball is heaved off its back and arcs high to land with the slam, `AttackFx.BOSS` meteor, and the eruption is
  bigger: wider, a tall fire pillar, a burst and a shockwave ring). Sounds: Pro Sound Effects. The Prism Hydra keeps its roar until its
  remodel.
- **Wild monster attacks** (same spec): each valley species has a keyed `windup` and `strike`
  (`tools/blender/anim_wild.py`, `MonsterAnimations/<species>`), played the same way as a boss's normal attack, with
  its impact (`Config/AttackFx` MONSTER, `ElementFx.monsterStrike`): Mossling a headbutt (green burst, dust), Puddle
  Crab a pincer snap (splash, two slashes), Cave Bat a dive (claw slashes, dark burst), Spark Beetle a horn charge
  (a bolt from its pincers), Ash Wolf a lunging bite (fang slashes, embers), Magma Golem a ground punch (fiery burst,
  rock dust, a ground ring).
- **Boss debuffs** (same spec): a ring that lands on a player leaves its boss's debuff (`Config/Bosses` DEBUFFS,
  `playerAttacks.debuff`, `BattleSim`): Meadow Warden Entangled (2 s, walk 60% slower), Cave Brood Queen Poison (4 s,
  2% of max HP a second), Ember Colossus Burn (3 s, 3.5% a second), Frost Tyrant Chilled (3 s, walk 30% slower, the
  dodge recharges 1.5x slower), Storm Sovereign Shocked (0.5 s, no sword or dodge; stuns never pass 1 s), Rift
  Devourer Weakened (4 s, sword 70%), Prism Hydra its current phase's element (Bloom Entangled, Shade Poison, Ember
  Burn, Tide Chilled, Volt Shocked). Quick hits and dodged or stepped-out rings give none. A new hit refreshes it (no
  stacking; Poison and Burn keep one tick a second); going down, leaving or the fight ending clears it.
  Shown (owner-approved look, 2026-11-03): a chip on its own row under the perk chip ("🌿 Tangled 1.6": emoji, name,
  tenths left over a bar draining in its colour; boss fights only, the row keeps its place so the bars don't jump), the
  emoji in a small ring on your portrait's top-right (`CombatHud.setDebuff`, looks in `Config/CombatHud` DEBUFFS,
  countdown in `Util/DebuffRules`), and an effect on the character that everyone in the fight sees (`Util/DebuffFx`):
  Tangled vine bands round the lower legs, Poisoned green bubbles rising, Burning small flames, Chilled ice crystals at
  the feet and a blue tint, Shocked yellow sparks, Weak a purple haze; each Poison or Burn tick flashes the character in
  its colour and floats its number (no flinch or shake). The walk slows are the server's: each step it reads the
  player's debuff from the sim (`BattleSim.playerDebuff`) and sets WalkSpeed to the speed before times 1 - slow
  (`BattleService` `updateMovement`, which also kneels a downed player; the speed before is kept in the humanoid's
  WalkSpeedBefore while either holds), so a refresh, another debuff, going down, running out, running away and the
  fight ending all put walking back. The Queen's web spit is a swipe: it reaches her ring radius plus 8 studs, so a
  player standing further back takes no hit and no Poison.
- **Effect quality** (same spec, "Quality bar", owner 2026-11-03): every fight effect is drawn from a texture kit in the
  owner's reference look (`tools/textures/make_attack_fx.py` -> `assets/ui/fx-attack`, ids in `AttackFx.TEXTURES`:
  glow, flare, comet streak, spark, shockwave ring, lightning, crescent slash, crystal shard, starburst, flame, smoke),
  white and tinted, a coloured layer under a white core (`Util/ElementFx`: comets with trails and flames or spiral
  rings, lightning beams, crystal eruptions, fire and water pillars). The combat preload fetches them with every
  attack sound (`CombatPreload.collect`, a beam is a blank slab until its texture is in). A creature's basic attack
  grows with its grade (`AttackFx.GRADE`, `FightFxRules.tier`): C base, B +25% and more sparks, A +55% plus one extra
  (Ember a second fireball, Tide a second ring spiral, Volt a forked bolt, Bloom/Shade a fourth slash), S +100% plus
  the big extras (Ember three fireballs and a fire pillar, Tide a water column, Volt two forked bolts and a strike from
  the sky, Bloom/Shade five slashes ending in an X, gold sparkles in trails, a boom sound layer). Pet button and super
  moves, bosses and wild monsters use the new look at a fixed size. Screen shake (`Util/ScreenFx`, `Util/ShakeRules`,
  `AttackFx.SHAKE`): every hit adds to one 0-1 shake that dies down, the camera rattling by its square, less the
  further the hit is from you; your own creature's hits light, a boss slam beside you heavy. Screen flashes
  (`AttackFx.FLASH`): your creature's S-grade hits and your Pet button moves in their colour, a boss slam near you
  white. Sounds play at a slightly random pitch. Damage numbers pop (`Util/DamagePop`, `AttackFx.NUMBERS`): they burst
  in bigger than their size and settle, rise, drift a little sideways and fade; crits are bigger, last longer and
  wiggle; a Poison or Burn tick is small, in its colour, with no flinch or shake. Low graphics: fewer particles.
- **Sword effects** (sword moves round, owner's picks 2026-11-04: candy sparkle arcs, star bursts and a ring on big
  hits; `Util/HitFx`, `Config/SwordFx`, textures by `tools/textures/make_sword_fx.py` in `assets/ui/fx-sword`):
  - **Candy sparkle arc** on every swing, hit or not: a crescent Beam bent into a circular arc in the swing's plane
    (`SwordFx.ARCS` per cut and the skill: diagonal down, rising, upright, flat; `Util/SwordArcRules`), in the sword's
    slash colour (`Swords.slash`, pale steel on the starter) with a white core, wiped along the way the swing goes,
    shedding small stars, then fading.
  - **Hits:** white slash streaks on the foe's side facing you (owner 2026-11-08, picked in game from free Creator
    Store packs, "make it look exactly like these": the Euphoric Games pack's Slash-Impact-01 and the Yona pack's
    Slash-01; `SwordFx.IMPACT`, `HitFx.impact`; they replaced the spiky star burst): a streak facing you, specks flung
    left and right, a big flat arc, a long stretched streak and sparks into the foe, standing level and turned to face
    your camera, burst again half as strong 0.12 s later, x1.35 on the finisher and the dash slash. In the weapon's
    colour with a white core, its element's particles on top (`SwordFx.ELEMENT_HIT`: Ember flames and embers, Tide
    droplets and a splash ring, Bloom leaves and motes, Volt crackling streaks and a flicker, Shade dark wisps; the
    Prism Blade a random element each hit, the Steel Sword none), and sized to what was hit
    (`SwordArcRules.impactScale`: the model's size against a 5-stud body, eased, 0.7 to 4: a Cave Bat 0.7, an Ash Wolf
    1, a Magma Golem 1.35, the Meadow Warden about 3; the ring and the dash slash's cut lines too) (owner 2026-11-08), which also snap out a ring facing
    you (flat rings stay the boss's); the white flash on what you hit and the sparks as before. Your own cut hits burst the moment your reach check connects; other players' hits, every dash
    slash and yours the check missed burst when the server's hit arrives.
  - **Dash slash:** after-images along the dash and two crossing cut lines on each foe hit, a beat after you pass.
  - **The finisher's landing** puffs a small dust ring at your feet.
  - Your swing effects are yours (on your screen, under the camera); others see your moves and your hits' bursts. The
    effects clean themselves up (a stress test of 6 foes hit every 0.1 s held 58 fps with nothing left after).
- **End screen** (owner 2026-11-03, design B "banner and loot strip"; `Util/VictoryScreen`, `Util/VictoryRules`,
  `Config/Victory`), boss fights only: normal monster fights (wild, elites, Dungeon rooms) end with a toast instead
  (`Util/FightToast`, `VictoryRules.toast`, `Victory.TOAST`): a dark pill slides down at the top, "Mossling defeated"
  with +cash and +XP pills (green edge; gold with a "New card! Petalpaw · Grade B" or Star Shard line and a chime),
  "Your party fainted" with when it's rested (red), "Got away safely" (grey), gone after 2.6 s. The boss screen: a warm flash, then a big glowing title popping in over the arena ("VICTORY!", gold; "DUNGEON
  CONQUERED!" on the first Hydra clear) with "<foe> defeated · m:ss" under it; a row of reward tiles popping in one by
  one with their icons (cash, XP each, Star Shards, a dropped card, the boss chest and ground loot, the daily bonus; a
  new card, a first-clear chest item and the bonus glow gold, with a chime); the notes (loot on the ground, carried,
  reduced, full loot again in); the party with XP bars filling (round to empty again and a LEVEL UP! badge on a level
  up; the server sends each card's progress before and after, `BeastRules.levelProgress`). A loss has its own screen
  (below), a run "Got away safely" in grey, PvP "You win!" / "You lose" / "Draw" with its "Going home in" countdown. It closes by
  itself (6 s, losses and runs `Combat.END_SCREEN_SECONDS`) or on a tap; landscape phones get it scaled down. Its
  sounds are fetched on the loading screen and kept loaded, and the silent start of the fanfare and the level-up
  shimmer is skipped (`Victory.START_AT`), so they land with the moment.
- **Balance with the player in the fight** (spec 2026-11-02-you-in-the-fight-design): boss HP and ATK were retuned
  with `lune run tools/balance/bosses`, which now plays each row twice: a player who stands still and one who fights
  well (the starter combo landing 55-90% of the time, the skill on cooldown, 40-80% of quick hits dodged, 80-97% of
  rings stepped out of; drawn per fight). Targets for a party at the recommended Power (solo): fights well wins about
  85% at 1x and 50% at 0.8x; stands still about 60% at 1x and 15% at 0.8x, taking about twice as long. Heals (later)
  add on top. The fights are nearly deterministic (the element match-up decides most of them), so rows land on steps
  of 20%; boss 1 stays easier for players who fight (it's the first). New HP / ATK: Meadow Warden 1440 / 7, Cave Brood
  Queen 2340 / 10, Ember Colossus 7200 / 26, Frost Tyrant 13800 / 43, Storm Sovereign 23200 / 31, Rift Devourer
  27600 / 57, Prism Hydra 48000 / 23. Then retuned again for fight perks (every row's party with its perks): Cave
  Brood Queen 2430 / 10, Ember Colossus 7400 / 29, Frost Tyrant 14900 / 46, Storm Sovereign 22600 / 40, Rift Devourer
  27000 / 66, Prism Hydra 50000 / 27 (the Warden unchanged: Common perks are small). The Hydra stays easier for
  players who fight well (about 96% at 1x): its parties are all starred Legendaries with strong perks, and more HP
  only pushed the still runs past the time limit. Boss debuffs (2026-11-02) left HP / ATK as they were: with them every
  row moved by a few points at most (solo and in pairs; the biggest, Ember Colossus still at 0.8x 40% to 29%, toward
  its target). `NO_DEBUFFS=1` runs the tool without them; the walk slows aren't modelled. Attack pace by SPD
  (2026-11-03, owner): the old pace (20 / SPD, floor 0.8 s) capped almost every creature above SPD 25, so a Lv 20
  Common attacked as often as a Lv 30 Legendary; the new curve slows mid creatures a little and speeds top ones up, and
  bosses were retuned to keep the targets (solo, still / well at 0.8x | 1x): Meadow Warden HP 1300 (7/60 | 100/100),
  Cave Brood Queen HP 2600 (23/60 | 60/90), Ember Colossus HP 6300 (6/60 | 60/86), Frost Tyrant unchanged (0/63 |
  49/91), Storm Sovereign 28000 / ATK 43 (20/60 | 60/90), Rift Devourer HP 34000 (23/60 | 58/82), Prism Hydra
  60000 / ATK 33 (28/68 | 61/100). Pairs stay as before (good players win about 100% at 1x). Super moves
  (2026-11-05, owner: "make sure bosses are not too easy now that we have heals"): the tool now fires each Epic and
  Legendary card's super whenever it's ready (a card of its rarity and element, taking turns; `NO_SUPERS=1`,
  `ONLY_SUPER=<card>`, `SET=` and `BOSS_SET=` to compare). Alone, two made bosses too easy: Voidmaw's Devour (the Prism
  Hydra standing still at 1x 68% to 100%, at 0.8x fighting well 60% to 99%; its heal now stops at 10% of its max HP)
  and Abyssal Koi's Tidal Shield (Rift Devourer standing still at 0.8x 27% to 60%; trimmed to 25% for 6 s, but any ward
  tips those fights, so that row stays). The rest moved a few points (Eclipse Fox the most: Rift Devourer fighting well
  at 1x 84% to 98%, its 5 s is the owner's). Late bosses then took more ATK (Storm Sovereign 46, Rift Devourer 71, Prism Hydra 42). Then
  the super meter (2026-11-06, owner's option A) made supers come about every 40 s standing still and 20 s fighting
  well instead of every 15 s, so Tidal Shield went back to 30% for 8 s, Devour's cap to 15%, and the bosses to (all
  supers on, still / well at 1x): Storm Sovereign ATK 44 (60/88), Rift Devourer ATK 66 as before (60/86), Prism Hydra
  ATK 38 (63/100). Bosses 1-4 unchanged (their rows' parties have no supers, or hit the targets).
- **Defeat screen** (owner 2026-11-04, design A "Defeated card"; `Util/DefeatScreen`, `Util/DefeatRules`,
  `Config/Defeat`), a lost boss fight: the world goes grey with a red edge (a ColorCorrectionEffect and the hit-flash
  vignette) and a quiet piano sting plays (APM "Moonlight Tides (sting)", Roblox-licensed, volume 0.22); "DEFEATED" drops in with
  "<boss> won · m:ss" under it, then a card with the fight's numbers the server sends (`summary.defeat`,
  `BattleSim.damageBy`): your sword's damage, each of your creatures' (the top 3), the boss's HP left as a bar, rings
  dodged of those aimed at you (counted per member); a tip (the boss's own, `Defeat.TIPS`); and a ring of 24 dots going
  out one by one around the seconds left, "Back to town". It can't be skipped (owner 2026-11-04); a clear button over the
  screen swallows taps meanwhile.
- **Summon, unsummon, faint** (owner 2026-11-04: light pillar, back into you, dizzy stars; `Util/SummonFx`,
  `Util/SummonMotion`, `Party.SUMMON_FX`): a summon (or a call-in, or a creature swapped back in) stamps `SummonedAt` on
  its marker and clients that see it fresh (within 1.5 s, not one streaming in later) draw a ring and a pillar of light
  in its element colour as it pops up out of them with a bounce and sparkles. An unsummon, a swap or the end of a
  call-in flags the marker `Unsummon` and removes it 0.45 s later (`PartyService.Dismiss`; renamed at once so the next
  marker's name is free): it flashes, shrinks away and a light flies back into its owner; a boss fight's benched leader
  does the same. A faint: a white flash, it tips over (`CreatureVisuals`, eased), dizzy stars circle its head for
  1.3 s, then it fades in a puff, and pops back when it's no longer fainted. Sounds (owner 2026-11-04,
  `Party.SUMMON_SOUNDS`, Pro Sound Effects), played where it stands at a steady pitch: the owner's picks of 2026-11-04
  from the options (`/summonsound`, `/unsummonsound`): a quiet twinkle as it pops up (PSE "Magic Glows Soft Clusters Of
  Chiming Hits 4", volume 0.1) and a soft magic fade as it flies back into you (PSE "Pulsing Tone Smooth Mid Range Synth
  Tone 3", volume 0.1).
- **Pet voice** (owner 2026-11-04 "an occasional chirp"; `Util/PetVoice`, `Party.VOICE`): your own summoned creature
  says hello 0.5 s after it pops up, then chirps every 18-40 s while it's out and about (not in a fight, fainted,
  swapped out or leaving) with an 8% squash-bounce. Small creatures chirp (PSE "Parakeet Chirps 8", "Mouse Vocal 3",
  one per creature), Epics and Legendaries give a low huff (PSE "Creature Vocal Spider Hiss Exhale 1"); pitched lower
  the bigger it is ((3 / height) ^ 0.45, kept within 0.55-1.3, +-8%), volume 0.22 for a chirp and 0.1 for the big
  huff (`PetVoice.volume`; owner 2026-11-06: the screech on summon was too loud, Epics and Legendaries most), heard
  within 45 studs. Only you hear your own (client-side).
- **Healing at the spring** (owner 2026-11-04; `Util/HealFx`, `Party.HEAL_FX`): while you stand in the spring's
  12-stud area (`RestChanged.nearSpring`, from the server's spring tick) your summoned creature, out and about, shows
  a green "+ Healing" pill above its name tag, green plus signs floating up off it, rising green sparkles, a green light
  breathing on it and a ring rippling at its feet every 1.6 s; resting cards' timers on the party bar turn green with a
  "+". It stops when you step away.
- **Wild fight HUD** (owner 2026-11-03, layout A: the boss fight's look without the sword): the monster's name and HP
  in the slim bar at the top (gold for an elite; a Dungeon room's other monsters as small bars under it), your creature's portrait
  ring with its HP top left (a called-in one's bar under it, the perk chip), and the slanted buttons bottom right
  (`CombatHud.new(..., wild, sword)`, `UiLayout.wildButtons`): with a sword, the boss fight's buttons (Attack, Dodge,
  the skill, the Pet button) and your HP bar on top with your creature's and a called-in one's under it; without one
  yet, the Pet button big where Attack is in boss fights (the first of your creatures on the field that's ready acts;
  R on PC) and the Super move above it when one has it. Both add Run with its chance ("RUN 90%", a cooldown after a
  failed try) and Call in showing the card it brings ("CALL IN 3S", only while the window is open; 1-3 on PC). PvP
  keeps the bar below.
- **Fight bar** (PvP): kept short for landscape phones: each creature is one 56 px row (name and HP beside its ability
  buttons), Bring in / Run below (`layoutBar` in BattleController).
- **Farm protection:** unlimited fights; XP and cash on every win. Items need a win of at least `minFightSeconds`
  (12 / 18 / 25 s) and come once per 15 minutes per boss (saved Unix time, so rejoining doesn't reset it). After 6
  rewarded wins of a boss in a UTC day each further one's chances are x0.75 of the one before (floor x0.2); a
  strongest card that fought (leader or called in; resting party cards don't count) above 2.5x the recommended
  Power makes them x0.35. Fragments for a boss you've already opened
  never drop. The first clear's chest (and the server-wide chat message) comes even on a too-fast win, so a strong
  player can still climb.
- **Items:** XP Tonic (400 card XP, used from the Party panel, never on a Lv 30 card), Grading Seal (one missing
  duplicate at the Grading Station, at most half a step, so never on a 1-duplicate step; the toggle says when they
  can't help), Star Shards, fragments, trophies, First Spark Packs (shop level rewards, opened from the Bag).
- **Trophies:** Build menu -> Trophies: placing one takes its trophy item (no cash), selling gives it back; they don't
  count toward the shop's shelf limit; a stone
  plinth with a gold cup and a gem in the boss's colour (`Town.TROPHY_LOOK`). Visitors see them.
- **UI:** the Bosses HUD tile (K, trophy icon) opens the Boss Ladder (style kit, lilac band; round 5, owner pick A
  "List and detail, like the Condenser", spec 2026-11-04-round5-design section 5). **Left:** the seven bosses top to
  bottom (270 px; phones 168 px, rows 48 px tall), one row each: a disc with the boss's icon (its element's; the Hydra
  a gem, `Util/BossTints`) in the ring of its state from `BossRules.stepState`: beaten (gold), ready (green: you can
  start it now, key fragments in hand count, and your best party card's Power is enough), too weak (red) or locked
  (faded grey: shop level or fragments short); "N. Name"; a status chip in words (Beaten / Ready / Too weak / Locked;
  phones: the state's small badge on the disc instead); a gold "Next" tag on the first boss still to beat; the chosen
  row's gold ring. Each row's tooltip says where it stands ("built for 1500 Power", "opens at shop level 34", "needs
  8 keys"). The old legend and climb path are gone (the chips say it). It opens on the first boss still to beat.
  **Right:** the chosen boss. A **banner** in its element's baby colour (`BossRules.bannerColor`: Bloom mint, Tide sky,
  Ember peach, Volt butter, Shade lilac, the Hydra pink; plum text on butter, white outlined in the deep shade on the
  rest) with a big white disc and its icon, its name, title, status chip and "Next"; under it pills for its element,
  where it lives (phones: the pills scroll at the top of the left column and the way to its place sits at the end of
  the Rewards column, `BossRules.detailsLayout`, so the columns keep their room)
  (tooltip: the zone and world) and the element to bring (`BossRules.counterElements` on `Combat.BEATS`: "Bring Shade",
  tooltip "Shade cards hit it 1.5x harder"; the Hydra "Bring a mix"); then two columns, each scrolling when it doesn't fit. **To fight it:** a checklist of what it needs, each row with a
  check, cross or "!" mark: shop level (You: n), its key fragments (n/N tinted for that boss, "Opened" once used,
  "No key needed" for the first; tooltip: the item, that it's used up on the first fight, and where it drops; tapping
  the row while short shows the boss before), and Power (the Power it's built for against your best party card, with
  a bar; a warning, not a lock); and its tricks spelled out under "Watch out" (`BossRules.watchOut`: shield,
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
  name, what it does, its odds or chest). **Footer**, always in view: what to do next on a light tint of its colour
  (`BossRules.nextStep` from `BossRules.lockReason`: level up the shop, beat the boss before for n more keys with a
  "See it" button, level up or change the party with a "Party" button, go fight it, or fight again for loot) and the
  travel button (`BossRules.travelChoice`): "Take me there" (gold) to its gate in this place (remote `BossTravel`: validated index,
  `TRAVEL_COOLDOWN` 3 s, only a gate in this place, through the Wild's travel checks), "Go to the Frontier" / "Go home"
  (the normal Frontier travel), or for the Hydra "Enter the Dungeon portal in the Frontier". In a boss
  fight a wide HP bar sits at the top, "Healing!" / "Enraged!" banners pop up, and the end screen lists the loot.
- **Groups (phase 2):** the gate's second prompt (F) "Start group" opens a group; others press "Join group (n/4)"
  within 15 s (`JOIN_SECONDS`), the leader (whose prompt reads "Start now (n/4)", `BossRules.groupPromptText`) can
  press again to start at once, it starts by itself when full (4). The Fight and group prompts have separate limiters.
  Every member needs the boss open or its fragments (taken only if the fight starts) and a rested summoned creature,
  and must still be near the gate when it starts (others are left out with a message; if the leader is gone the next
  member leads). One boss for the group: HP x (1 + 0.8 (n - 1)), ATK x (1 + 0.08 (n - 1)) (`BossRules.groupStats`;
  each boss's own `groupAtkStep`: 0.08 for the Wild bosses, 0.1 the Frontier's, 0.3 the Prism Hydra; Dungeon room packs
  keep `GROUP_ATK_STEP` 0.15), and it swings once more per attack per
  extra player (`GROUP_SWINGS_STEP`, never more targets than players; each swing may go at a player as a quick hit) so
  a group can't hide behind spare bodies. Wave heals only its user's own creatures (stacked Waves from a
  whole group out-healed any boss). Tuned with `lune run tools/balance/bosses [fights] [players]` (the player in the fight):
  at the recommended Power a group that fights wins nearly always; 2 players who stand still win about as often as one
  (40-80%), 4 who stand still less on the Frontier bosses (about 20-30%).
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
- **The Wild bosses' models** (spec `2026-11-01-wild-bosses-arenas-design.md`; the user picked each design and size B
  "Huge"): Meshy image to 3D from the picked concept, about 7,600 triangles, rigged by our own scripts
  (`tools/blender/rig_meadowwarden.py`, `rig_cavebroodqueen.py`, `rig_embercolossus.py`; docs/creatures.md "Wild
  bosses"), saved as `assets/monsters/<bossId>.rbxm` with a steady glow mask (strength 2 as saved; the Colossus lit at
  4 by the game, `Bosses` `glow`).
  Heights in studs (`Bosses` `height`, `Util/MonsterLooks.height`), the Prism Hydra still the biggest at 24.5:
  - **Meadow Warden** ("Elder Warden"), 17 tall: a hunched giant of hollow tree trunk and grey boulders, a stone face
    with glowing green eyes, antler boughs and a moss beard. It lumbers on two legs with long arms swaying and slams
    its roots now and then (`rootslam`, its `Party.SIGNATURE`).
  - **Cave Brood Queen** ("Broodmother"), 16 tall and about 21 across her legs (12 came out 16 across, smaller on
    screen than the others): a violet bat-winged spider with glowing lilac eyes and a lavender egg sac. Her eight legs
    walk in a wave and her wings spread for the roar (her screech plays at 0.3, `moments.roarVolume`: it was far louder
    than the other roars); when her heal fires the egg sac flares (violet sparkles from
    `Fx_Sac`, drawn 6 studs toward the camera so the opaque sac doesn't hide them), never at random.
  - **Ember Colossus** ("Magma Behemoth"), 17 tall and about 28 long: a basalt-plated lava rhino with glowing seams,
    eyes and mouth. Its dark plates blended into the lava field's dark ground, so its lava glows at 4 and a warm
    PointLight on it (`Bosses` `light`: brightness 2, range 26) lights it and the ground round it. It plods on four stubby
    legs (short swings: its rig holds clean up to `legSwing` 0.6) with a jaw
    that opens; when it enrages its three back vents burst with fire, then smoke while it stays enraged.
  Fighters stand 15 / 18 / 18 studs out (`ringRadius`) and the intro camera sits further back (`introShot`). Moments
  come from the boss marker's attributes (`SpawnedAt`, `Heals`, `Enraged`; `Util/BossMoments`, Lune-tested), so a
  player who streams in mid-fight sees the state, never a replay; their effects are particles on zero-influence `Fx_`
  bones (`Bosses.MOMENT_FX`, never an animated SurfaceAppearance). The Frontier bosses 4-6 are still placeholders
  (monster shapes at 2.5-3.4x); the Prism Hydra has its own model (below).

#### The Dungeon and the Prism Hydra (phase 4)

Spec `docs/superpowers/specs/2026-10-29-dungeon-final-boss-design.md`. The ladder's last step, about 30-45 hours in.
- **The place:** a third place (id 79143483483478, `Config/Places.DUNGEON_PLACE_ID`; `dungeon.project.json`, port
  34874, `PlaceKind = "Dungeon"`, `Place.isDungeon`). No plots, no shop. One run per reserved server.
- **Getting in:** the Frontier's Dungeon portal (`DungeonGateService`): "Enter" alone or "Start group" / "Join
  group" (2-4, 15 s, the leader starts early, like boss gates). Every member needs shop level 57, the Hydra open or 10
  Hydra Key Fragments (the Rift Devourer drops them: 50% per full loot, 3 in its first clear), and a creature ready to
  fight. Then one teleport takes them into a new reserved Dungeon server (`TeleportData.runSize`). The fragments are
  taken only when the Hydra fight first starts, so a lost run costs none.
- **The run (`DungeonService`, `Util/DungeonRules`):** a player joins the run once their save has loaded; the rooms
  stay shut ("Waiting for n more players to load...") until everyone the teleport brought has loaded
  (`DungeonRules.readyToStart`; after `ARRIVAL_WAIT` 60 s a player who never came, e.g. a failed teleport, is left
  behind). Then three rooms open in turn, each a sealed ring with a "Fight" gate. Its pack of elites appears (`Config/Dungeon.ROOMS`:
  2 Frost Wisp/Shade Lynx at Lv 45, 2 Storm Hawk/Lava Brute at Lv 47, 3 Rift Horror/Prism Crab/Lava Brute at Lv 50;
  elite stats times `PACK_SCALE` HP x0.21 / ATK x0.33, which keeps the rooms as they were before the Frontier's
  2026-11-03 retune, scaled to the group like a boss, with swings; the rooms stay creature-only) and each monster gets a
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
- **Time to reach it:** shop level 57 is 436,890 total shop XP (`Util/LevelMath`): about 9 h to level 20, then roughly
  12k XP an hour from a grown shop, about 42 h in all, inside the 30-45 h target.
- Studio: the Dungeon window (`rojo serve dungeon.project.json`) starts the run for whoever is there; `/room <2-4>`
  opens the doors up to that room and puts you at its gate (4: the chamber), also in the admin panel's Dungeon section. Teleports only work in
  the published game.

### 5.11 Weapons (round 1; spec docs/superpowers/specs/2026-11-06-weapons-round1-design.md; rounds 2-3, spears and scythes, below)
- **Catalogue** (`Config/Weapons`, looks in `Config/WeaponLooks`): the Steel Sword (everyone's), the Forge Sword in five
  elements (Common, $1,500 + 20 Wild Ore, shop level 6), the Verdant Blade (Rare, Meadow Warden), the Sunforged Blade
  (Epic Masterwork: $25,000, 20 Colossus Core, 10 Warden Heartwood, 10 Brood Silk, 5 Star Shards) and the Prism Blade
  (Legendary, Prism Hydra); the spears (round 2) and the scythes (round 3) below. Saved per copy: grade and upgrade level
  (`weapons`, `equippedWeapon`, schema 16; `WeaponService`). Rules: `Util/WeaponRules` (Lune-tested).
- **Materials**: each boss's own (80% on full loot, 1-2; its daily chest 2) and Wild Ore (15% from Wild and Frontier
  monsters, 60% from elites, shown in the fight toast).
- **In fights** (`BattleSim.swordHit`'s weapon, `WeaponService.HitInfo`): sword damage = the creature's ATK x the cut x
  the weapon's Power; the weapon's element goes on the wheel (x1.5 strong / x0.75 weak; the Prism Blade always strong),
  a bond with the creature fighting (same element; the Prism Blade any) adds x1.15 damage and x1.5 super meter from
  sword hits; perks: the Verdant Blade heals the creature 2% every 4th hit (a green "+N"), the Sunforged Blade burns
  3% of the creature's ATK a second for 3 s (refreshed, never stacked; its own clock beside Inferno's). Grade S perks
  are x1.2.
- **Power** = rarity base x grade (C 1, B 1.05, A 1.1, S 1.15) x (1 + 0.03 a level, +10 = x1.3). Bases tuned
  2026-11-06 against the spec's limits (no weapon lets a 0.8x party win more than 85% fighting well on its tier
  boss; +10 Grade S never more than halves a 1x fight): Common 1.15, Rare 1.25, Very Rare 1.4, Epic 1.6, Legendary
  1.8; the Prism Blade has its own base 1.0 (always strong and bonded makes it x1.73 against every foe). The spec's
  starting numbers (1.15 / 1.35 / 1.55 / 1.8 / 2.1, +5% a level) broke both limits: the Prism Blade at +0 won 93% at
  0.8x and +10 S cut the Hydra fight to 37%; the Verdant Blade +10 S won 97% at 0.8x.
- **The Forge** (a Fixture, $1,500, shop level 6; `ForgeService`, a code-built stand-in look until its model): forge
  (a weapon you don't have), upgrade (+1 at a time, never fails), reforge (half the making cost, rounded up: a new
  grade roll, the better kept). Its own Forge within 12 studs, one request at a time, costs checked and taken all or
  nothing on the server.
- **The Forge window** (`ForgeController`, owner's layout B; its pane relaid out 2026-11-08, the owner's pick A):
  tabs Forge / Upgrade / Reforge with one line under them saying what the tab does (`WeaponText.tabLine`; on phones the
  pane's first line); the weapons for the tab on the left as slim rows with their card (the Forge tab previews Grade C
  +0); the chosen one on the right: its card (tap it for its stats: the weapon card view, `WeaponDetailController`,
  which now sinks taps so none reach the window under it), its name, "Grade S · +0" and "Common · Ember"; the Forge
  weapons' element buttons (48 px; the picked one bigger, the owned ones greyed); two boxes, Now and After, with the
  kit's blue arrow picture between them (Upgrade: "+0, Power x1.32" and "+1, Power x1.36, It glows brighter"; Reforge:
  "Grade B" and "C to S, you keep the better"; one box at +10 "Fully upgraded, Awakened!", for a Grade S reforge and
  for the Forge tab's "You get: Grade C to S"); then "You pay" as picture chips ("$250", "2 Wild Ore (you have 11)",
  green when you have enough, red when not; `WeaponText.costChips`; none for a Grade S reforge). One pinned button says
  what it does ("Upgrade to +9 · $8,000") or what's missing first ("Opens at shop level 6", "Need 5 more Wild Ore",
  "Need $500 more"; `WeaponText.button`). The window steps aside for the forge reveal and comes back after it; it
  closes when you walk away. Phones (short screens): 0.97 x 0.96 of the screen, the tabs up in the header band; the
  pane shows a small card with the Now / After boxes (their first line only) or a Forge weapon's element buttons
  beside it, the cost chips under them and the tab's line last, so a 667 x 375 phone sees it all without scrolling
  (`Config/ForgeLayout`, `UiLayout.forgePhonePane` / `forgePhoneContent`, tests/UiLayout).
- **The Armory** (the binder's fourth set, `Collection.SETS`; cover `Config/BinderCovers` Armory): every weapon in
  catalogue order as a card in the creature cards' shape (`Util/WeaponFace` on `CardFace.parts`): owned ones show
  their portrait over their glow, Power, grade and +level, "Owned" / "Equipped"; locked ones a dark sword with
  where they come from and the progress toward them ("Forge: Wild Ore 15/20"); rounds 2-3's "Coming soon". Tapping
  an owned one opens its card view (`WeaponDetailController`: stats in words, Equip).
- **The Boss Board**: each boss with a weapon shows its card under the drops, "Drop chance now: 1.0%" (with the
  pity) and its material's chance.
- **Models** (`assets/weapons`, docs/weapons.md): Figma concepts picked by the owner, Meshy image-to-3D, cleaned in
  a background Blender (`tools/blender/weapon_kit.py`, `build_weapon_<id>.py`: about 4,000 triangles, Blade / Guard
  / Grip, the grip's centre on the origin), imported by the owner, finished by `tools/weapons/finish_sword`; the
  Forge Sword's five elements are one model with five colour maps (`tools/weapons/forge_variants`). Portraits: each
  model rendered on magenta, cut out, uploaded (`assets/ui/weapon-portraits`, `WeaponLooks` portrait ids).
  Every sword model has its edge along X and its flat along Z; the hand's grip (`Swords.HAND_GRIP`: 0.18 down, tilted
  -140 degrees about X, then `twist` 90 about the blade) puts the flat to the palm so the edge leads every cut (owner
  2026-11-07: "hold the sword the right way, not flat"; before it the flat led 63-92% of each swing).
- **Drops** (`BossService`): each full-loot win of a boss with a built weapon (no soft cap or over-power shrink,
  `BossRules.rollsWeapon`) rolls it at its rarity's odds plus a step per full-loot win since the last (`weaponPity` in
  its saved record; `Weapons.DROP`, owner 2026-11-06): Rare 1% + 0.5% (median 15 kills, about 2.5 days at the soft
  cap), Very Rare 0.5% + 0.2%, Epic 0.2% + 0.05% (about a week), Legendary 0.1% + 0.02% (median 79, about 2 weeks);
  carried group members never roll it. A weapon you have turns into
  10 of its material. The drop cinematic plays after the victory screen (`WeaponRevealController`, on the opening
  stage: rune circle, a light column in the rarity's colour, the weapon rising with its glow, "RARE! Verdant Blade",
  its grade, a line; a new weapon's card pops in face down beside it and turns over to its face and grade; its own
  sounds: an airy rise as the column opens, a magic burst and a long ringing blade as the weapon flashes into view, a
  cymbal swell for Epic and Legendary and a deep boom for Legendary, a card flip as the card turns), and players
  within 150 studs of the winner see a column of light in its rarity's colour rise where they stand (WeaponBeacon); Epic
  and Legendary drops are toasted to the server (not a duplicate: it says "Already yours", no card or column). A
  weapon's pity resets only once it was really given; the server refuses to reforge a Grade S weapon, and anything
  failing after a Forge payment gives it back.
  The weapon is scaled to 3.2 studs on the stage so all of it shows. The Forge's results play the same stage with the
  anvil's face under the weapon and a 1.5 s build-up with its own sounds (a fire whoosh, three rising hammer strikes),
  the hit by the grade (an anvil clank; A adds a fire burst, S and +10 a deep boom), a sword's ring as the banner pops;
  an upgrade names the glow layer it adds.
- **Glow** (owner 2026-11-06: an aura like their reference picture, hybrid for performance; `Util/WeaponLookRules`,
  client `Util/WeaponLook`, numbers in `Config/WeaponLooks`):
  - the inner glow: each model's glow map (emissive mask: the Sunforged's molten runes, the Verdant's crystal, the
    Prism's rainbow edge, the Forge Sword's gems) baked into its SurfaceAppearances, lit by rarity and level (full at
    +10, tinted its glow colour); a game script can't set the maps, so they live in the model files;
  - the full aura: flame wisps filling the weapon from its element's deep colour to its bright one, a bright core,
    drifting smoke and sparks (the Prism Blade's flames in every element's colour). Pack auras replace the flames, core
    and smoke (owner 2026-11-08, picked in game; `WeaponLooks.ELEMENT_AURA`, `WeaponLookRules.auraStyle`): Ember and
    Tide weapons wear the free Euphoric Games VFX Pack's fire or water flipbook in their deep colour; Bloom weapons the
    Yona VFX Pack's aura in green (embers, dark and bright smoke, a soft light), thinner at low grades (C 0.3, B 0.5,
    A 0.75, S 1 of its rate: "tone it down for low grades, then gradually to its max glow"); pack layers draw at their
    part, not a stud behind as in the packs (on the back that sank the fire into the torso: "the glow is blocked by
    the body"), and a stud nearer the camera while the wearer's body hides the part (seen from the front; a camera ray
    each frame against the body's visible parts, `WeaponLook.drawPastBody`, `WeaponLooks.BEHIND_BODY`); it starts at +4 (Epic and
    Legendary at +2), thickens each level and is full from +7; +10 Awakened adds ribbons streaming off the blade;
    half the aura on the back below +10; every particle is locked to the sword, so walking leaves no trail (owner);
  - the cheap glow: creature-style sparkles a second (1-5 by rarity, more per level and for Grade S) and a light
    (Epic and Legendary, in hand; on the back too once Awakened);
  - the budget: your own sword and the 3 nearest others within 60 studs get the full aura (checked every 0.5 s,
    `SwordController`), every other sword the cheap glow. Studio, max graphics: 20 +10 swords in view add 1.98 ms of
    render CPU all blazing, 0.33 ms with the budget (4 blazing), 0.17 ms all cheap.
  - a wider trail and a burst on every hit from +7; in a fight the Prism Blade's trail and slashes take the colour of
    the element strong against the foe (`SwordController.SetFoeElement`). Roblox thins particles on low graphics (most phones), so there the
    blaze is a few flames.
- **Pickup toasts**: a boss material reads "Warden Heartwood +2 (9/15)" toward what it's for next
  (`WeaponRules.materialGoal`: making its weapon, then its next upgrade).
- **Economy** (`WEAPONS=1 lune run tools/economy/sim 2000`: an Ember Forge Sword, the Verdant Blade and its upgrades to
  +5, $11,100, paid first from an early packs-only shop's $706 an hour): the Grade S Legendary goal moves from 19.6 h to
  35.4 h median (+81%). That shop earns no boss cash (players chasing weapons fight bosses), and the weapons are their
  own chase; the owner kept the costs (2026-11-06).
- **Balance rows** (`WEAPON="<id>:<level>:<grade>" lune run tools/balance/bosses 60 1 <boss>`, "well" column, solo;
  the Steel Sword's row first):

  | Weapon on its tier boss | 0.8x win: Steel / +0 C / +10 S | 1x fight: Steel / +10 S |
  |---|---|---|
  | Ember Forge Sword, Meadow Warden (strong) | 100% / 100% / 100% (Steel already above 85%) | 79 s / 43 s (54%) |
  | Verdant Blade, Cave Brood Queen | 60% / 62% / 82% | 117 s / 81 s (69%) |
  | Sunforged Blade, Frost Tyrant (weak) | 47% / 53% / 62% | 129 s / 90 s (70%) |
  | Prism Blade, Prism Hydra (after the rooms) | 62% / 70% / 80% | 178 s / 118 s (66%) |
- **Sword skills** (weapons round 1.5; spec `2026-11-06-sword-skills-design.md`, plan `2026-11-06-sword-skills.md`,
  branch `sword-skills`; owner 2026-11-07: "exaggerate everything, that's what kids want"): each round 1 sword has its own
  moveset (`Config/Swords`: the Steel Sword's three cuts, their animations and sounds shared, its own skill, skill
  animation, sounds and looks `fx`; `Config/Weapons` points each weapon at it, the five Forge Swords share one). Every
  skill keeps today's damage in total (0.9 x the weapon's Power) and one shared cooldown (`Swords.SKILL_COOLDOWN`); only
  the shape it hits, the motion and the look change. Owner 2026-11-09 ("increase the weapon skill cooldown and make the
  weapons share cooldowns. to avoid abuse (switching to another weapon then pressing the skill and repeat). and when a
  fight starts the skill should start in cooldown"): 12 s (was 8), one timer per fighter whatever weapon is in hand (the
  server's `skillReady` and the client's were already one each; checked in Studio: a skill, a switch, the skill again:
  refused), and every fight opens with the skill on its full cooldown (`SwordRules.openingSkillReady`, server and
  client; the HUD drains from the start), so it can't be thrown fight after fight. Balance (tools/balance, 60 boss fights,
  200 wild): within a few points of before at every row (the skill is a small share of the damage). The server counts the shape from its own record of where you stand (`SwordRules.skillHits`,
  Lune-tested; `BattleService.onSwordSkill` lands each hit `after` its moment with its share):

  | Sword | Skill (shape) | Slashes / finisher | Moments |
  |---|---|---|---|
  | Steel Sword | the dash slash (its path, as before) | today's | - |
  | Forge Sword (its element) | Elemental Spin: two turns whipping up a tornado of its element, a wall of it racing out to 9 studs (every foe within 9) | its element streaming off the blade / a blast of it (fire spurt, splash geyser, leaves, lightning, shadow) | hit 0.8 s, 1.1 s |
  | Verdant Blade | Thornline: the blade plunged vertical into the ground and held until thorny vines racing out (20 studs/s, 18 x 4) reach the first foe and snap shut, catching foes within 4 | leaves and petals / thorny roots | vines leave 0.45 s, the move held (`skill.hold`) until they arrive |
  | Sunforged Blade | Sunfall Cleave: a high jump, a long charge at the top, a cleave in the air launching an upright fire crescent that glides down (14 studs/s, 24 x 6) and bursts on the first foe it touches, foes within 6 | a fire trail / a lava crack and a fire spurt | hit 1.78 s, 2.45 s |
  | Prism Blade | Prism Judgment: five ghost Forge Swords in a spinning ring over the boss, each diving in turn (0.15 s apart, a fifth each, the aimed foe within 24), then a rainbow pillar | rainbow bands / crystal spikes in every colour | first strike 0.6 s, pillar 1.28 s, 1.75 s |

  A split skill's strikes fill the super meter as one hit (`BattleSim.swordHit`'s share). Free after the hit (owner
  2026-11-07, so every skill costs about the same attack time): you can cut and walk again once a skill's damage is
  committed (`skill.free`, `SwordRules.skillFreeAt`: Elemental Spin 0.8 s, Thornline when its vines reach the foe,
  Sunfall Cleave 1.78 s as the crescent leaves, Prism Judgment 1.2 s at the last dive; the Steel Sword's dash at its
  end); its effects and hit play on, its pose fades when you walk and its camera moment ends when you cut
  (`SwingGate.uncancelled`). A dodge before the hit moment cancels its damage on the server (`SwordRules.skillDodged`)
  and its damaging part on your screen (the crescent, vines, dives or ring wave). The HUD's skill button shows the
  equipped sword's skill (owner's picks 2026-11-07; `Config/CombatHud` SKILLS, picked by `SkillText.swordSkill`,
  Lune-tested): Elemental Spin the swirl `SpinSkill`, Thornline `Thornline` (the blade in the ground between thorny
  vines), Sunfall Cleave `Sunfall` (the fire crescent), Prism Judgment `PrismJudgment` (five swords ringed over a target);
  white glyphs from icon sheet 8 (`slice_icons.py`, the spare takes kept). Effects (numbers in
  `Config/SwordSkillFx`, drawing in client `Util/SwordSkillFx`, rules in `Util/SwordSkillFxRules`): charge-ups, ground
  fissures, eruptions, pillars, shockwaves and particle storms in the sword's colours (a Forge Sword's in its element),
  thinned on low graphics; your own get screen shakes (`SwordSkillFx.SHAKE`: every finisher, Sunfall's cleave and
  burst, Thornline's snap, each Prism strike and its pillar) and Sunfall Cleave and Prism Judgment a camera moment on
  your screen (`Util/SkillCinematic`; camera only, the fight runs on): from the side, a wide shot framing you, the
  effect's whole path and the boss, on whichever side is clear. Other players' cuts and skills reach every client
  (`SwordCast` remote) and draw on their character within 90 studs, the first 3 in full and the rest slash-only
  (`SwordSkillFxRules.drawsOthers`). Sounds: each sword's own, licensed and quiet, a `<key>_<Element>` version for a
  Forge Sword's element; every sword sound is measured into `Config/SoundLevels` and loud ones are turned down. The
  skill animations are keyed in a background Blender (`tools/blender/anim_<sword>.py`, docs/animations.md), published by
  the owner (2026-11-07; ids in `Config/Swords`). Studio preview: `/skillfx <sword> [cut1|cut2|cut3|skill]
  [level]` and the admin panel's "Sword skills". Balance: `lune run tools/balance/bosses 300` gives identical rows before
  and after (2026-11-07). Measured in a Warden fight: about 60 fps through each skill (Thornline was building ~200 vine
  parts at once, now row by row).
- **Spears** (weapons round 2; spec `2026-11-07-weapons-round2-design.md`, plan `2026-11-07-weapons-round2.md`, branch
  `weapons-round2`; the owner's picks 2026-11-07): the Forge Spear in five elements (Common, the Forge like the Forge
  Sword), the Magma Halberd (Very Rare, Ember Colossus), the Tidal Trident (Epic, Frost Tyrant) and the Titan's Lance
  (Legendary Masterwork: $60,000, 30 Warden Heartwood, 20 Frost Heart, 20 Storm Crystal, 10 Star Shards). Heroic size
  (8.5 / 8.5 / 8.7 / 9.2 studs, the owner's pick B), held upright at your right side between moves (pick C: the grip 31%
  up from the butt, `Config/Swords GRIPS.spear`; the hand's tilt -90, as keyed), on the back diagonally at scale 1.
  Perks: the Halberd's Eruption (every 5th hit bursts for 60% of it more, a lava burst), the Trident's Chill (the foe's
  attacks 10% slower for 3 s, never weakening a stronger slow) and the Lance's Titan's Bloom (every 4th hit heals your
  creature 1%; the Lance has its own base Power 1.2, as the Prism Blade has its own); Grade S x1.2 as for swords
  (`BattleSim` swordPerk, `WeaponText` words). Balance rows (as round 1's, 60 fights solo, "well"):

  | Spear on its tier boss | 0.8x win: Steel / +0 C / +10 S | 1x fight: Steel / +10 S |
  |---|---|---|
  | Ember Forge Spear, Meadow Warden | 100% / 100% / 100% (Steel already above 85%) | 79 s / 43 s (54%) |
  | Magma Halberd, Ember Colossus | 60% / 62% / 83% | 67 s / 49 s (73%) |
  | Tidal Trident, Frost Tyrant | 47% / 62% / 78% | 129 s / 72 s (56%) |
  | Titan's Lance, Prism Hydra (after the rooms) | 62% / 72% / 83% | 178 s / 134 s (75%) |

  The Titan's Lance first had the Legendary 1.8 and a heal on every hit: a 0.8x party won 100% even at +0 (the heal
  carried the long Hydra fight; at 1.0 with half the heal still 97% at +10 S). One moveset for all four
  (`Config/Swords` `spear`, the same damage a second as the sword combo; the owner asked for it more exaggerated):
  Thrust (a deep coil, a 2-stud lunge, reach 12 in 30 degrees), Sweep (a full spin, 11 in 120 degrees), Sky Pierce (a
  6-stud spinning leap and a plunge: a line to 8 studs ahead and a 4-stud burst there, `SwordRules.cutReaches`), and the
  skill Piercing Rush (a 12-stud rush, every foe along a 3-stud line as it arrives; free after the hit). No spear move
  reaches past 12 studs, so a boss's swipe still reaches anyone who can hit it (tests/SwordsConfig). Moves keyed on
  `tools/blender/anim_spear.py` (a spear prop on `anim_kit`, the arm without the sword's wrist lag), built into
  `assets/animations/Spear`. Effects (`spearStreak`, `skyPierce`, `piercingRush` in `Config/SwordSkillFx`, drawn by
  `Util/SwordSkillFx` along the spear's head, `SwordFx.TRAIL_BLADE_SPEAR`): a light beam along the thrust with a star
  flash, a crescent of light round the sweep, Sky Pierce's element eruption, white flash, shockwave rings, glowing
  cracks, rocks and dust, Piercing Rush's charge orb, afterimages, line flash with bursts and dust skid; six own sounds
  (Pro Sound Effects, measured). The skill button: the owner's pick C, a spear with its afterimages (`UIIcons`
  `PiercingRush`, icon sheet 9 with spares for the next spear skills). Models: Figma concepts A (the owner's picks),
  Meshy, cleaned by `weapon_kit.build_spear` (Head and Shaft, the Shaft the PrimaryPart), the Forge Spear's collar gems
  tinted per element; glow maps for the gems, lava cracks, crystal prongs and emerald veins.
- **Titan's Wrath** (weapons round 2.5, spec `2026-11-08-forge-relayout-and-titans-wrath-design.md`; the owner's
  storyboard, exaggerated): the Titan's Lance's own skill in place of Piercing Rush (its own moveset
  `Config/Swords` `titansLance`: the spear's cuts, moves and sounds; the Halberd's and the Trident's own skills below).
  Same rules as every skill (0.9 of a hit, the shared cooldown, a dodge or a switch before the hit cancels it). A long, loud
  charge in a low stance (gold and green light pouring into the tip, sparks and leaves swirling round you, glowing
  cracks creeping out from your feet, the screen rumbling harder and harder), the peak's white flash with a ring and
  rocks lifting off the ground (1.22 s), one huge thrust (the hit, 1.35 s): a lance-shaped beam and a gold shockwave,
  every foe on the 14 x 4 line ahead (`SwordRules` line: its ends rounded by half its width), a fissure tearing open
  the whole line with green light and thorns bursting out of it, the rocks flung along it, a big shake; it glows on to
  3.2 s and closes under drifting petals. Owner 2026-11-09 ("make the vines more epic and exaggerated ground cracks
  fissures and etc. this is a legendary weapon"): the fissure 3.6 studs wide with 10 cracks branching off both sides as
  the tear passes, 10 slabs of ground heaved up along it (tilted, sinking back as it closes), 16 rocks flung up out of
  it, 5 pillars of green light bursting from it; 14 thorn vines up to 8 studs tall, curling like claws (most arching
  over the fissure, every third flaring out, all different heights), and 3 titan vines 13 studs tall erupting at the
  line's end (six-piece stems leaning out and curling back over it, gold buds, an eruption of earth and leaves); the
  charge's cracks 12, reaching 9 studs; the wide shot holds 1.3 s, looking a little higher so the titan vines fit. You stay put (no rush). The rumble pulses grow to `SHAKE.titansRumble` 0.28
  and die down before the thrust (no shake at the peak), so the fissure's shake lands as a jump (tests/SwordSkillFx); a
  dodge or a switch during the charge stops all of it, its sounds too (`playCues` stops a skill's cue sounds when it is
  cancelled before its hit). Its camera moment frames the stance from the side
  (`camFocus`) and the whole fissure low (`camLookUp`). Its own sounds (charge-up, rumble, the thrust's roar, thorns,
  the fissure's crash; Pro Sound Effects, measured). Keyed in `tools/blender/anim_titans_lance.py` (on anim_spear's
  helpers), built into `assets/animations/TitansLance`; the HUD button "Titan's Wrath" with the lance-in-vines icon
  (`UIIcons.LanceLeaves`, the owner's pick 2026-11-08). The Lance's Power stays x1.20: its Legendary edge is this skill
  (owner 2026-11-08). Balance re-run with it (tools/balance/bosses, Prism Hydra, 60 fights): unchanged, +10 S 83% and
  +0 C 72% at 0.8x, the 1x fight 134 s.
- **Magma Cleave and Torrent Strike** (weapons round 2.5 part 2, spec `2026-11-09-halberd-and-trident-skills-design.md`,
  plan `2026-11-09-halberd-and-trident-skills.md`; the owner's ideas 2026-11-09, storyboard approved): the Magma
  Halberd's and the Tidal Trident's own skills in place of Piercing Rush (their own movesets `magmaHalberd`,
  `tidalTrident`: the spear's cuts, moves and sounds; the Forge Spear keeps Piercing Rush). Same rules as every skill;
  neither moves you. The skill's size follows the rarity:
  - Magma Cleave (Very Rare, "something simple is fine ... one big swipe with flaming horizontal slash effects"): pulled
    back over the right shoulder (the blade's glow brightening, embers gathering), one huge swing right to left (the
    hit, 0.6 s; 1.2 s in all): a fire crescent (a white-hot core with the pack's flame flipbook along it, flames,
    embers and smoke shedding off it) and a thinner flame slash behind it, every foe in the half circle in front of you
    11 studs out (the `arc` skill shape: a foe counts when any of it is inside, so one right beside you is swept,
    `SwordRules.skillHits`), `SHAKE.magmaCleave` 0.8; no camera moment. Sounds: a charge-up through the wind-up (owner
    2026-11-09: Flame Licks 4 swelling from the start, a reversed whoosh peaking at the swing; a dodge before the swing
    stops them), a big whoosh and Fire Sheet 3.
  - Torrent Strike (Epic, "strike the ground with the trident, while the trident is stuck to the ground, torrents of
    water appears from the ground"): raised high, water swirling round the prongs, driven tip-first into the ground
    ahead (0.55 s: a splash ring, glowing blue cracks, the release shake), leaning on the stuck shaft as a big column
    bursts under every foe in reach (the hit, 0.75 s: every foe within 12 studs, `spin`; `SHAKE.torrentStrike` 0.9).
    Owner 2026-11-09 ("make the torrents appear at a random at a time.by one or by two torrents"): 14 torrents, 18-22
    studs tall, burst round you one or two at a time over the next second, each at a random spot 3.5-12 studs out, 3.5
    apart, kept out of the lane along your left-right line where the side camera looks in
    (`SwordSkillFxRules.torrentBursts`, Lune-tested). Owner 2026-11-09 ("higher up with slowmo effect on waters and
    make the torrents last longer"): as each burst reaches its top (0.45 s after it) its water eases into slow motion (a
    quarter speed, pouring twice as fast meanwhile so it stays full) and hangs, still pouring, until 2.9 s: back to
    full speed, they stop and fall back as rain. The trident is pulled free at 1.9 s while the water still hangs (the
    animation is unchanged). Your own camera pull-back is framed on where you stand, low and 26 studs out so the
    torrents' whole height shows, held through the bursts and the slow motion. Sounds: a deep boom, a big splash, Water
    Surge 3, Heavy Rain 1 with the fall (a 51 s clip, faded out 2 s in: Config/Swords cue `stopAfter`).
  Keyed in `tools/blender/anim_magma_halberd.py` and `anim_tidal_trident.py` (on anim_spear's helpers), built into
  `assets/animations/MagmaHalberd` and `TidalTrident`; HUD buttons with the spare glyphs `HalberdFlames` and
  `TridentWave`. Balance re-run (tools/balance/bosses, 60 fights solo, "well"): unchanged from the rows above, the
  skill's damage is the same.
- **Scythes** (weapons round 3 part 1, spec `2026-11-09-weapons-round3-scythes-design.md`, plan
  `2026-11-09-weapons-round3-part1.md`; the owner: "epic. I want exaggerated moves, wide slashes in all directions", "a
  bit slower but still flashy", concepts B for all four): the Forge Scythe (Common, five elements, Wild Ore), the Widow's
  Reaper (Very Rare, Shade, Cave Brood Queen), the Storm Reaper (Epic, Volt, Storm Sovereign) and the Rift Reaper
  (Legendary, Shade, Rift Devourer; its own base Power 1.4, as the Prism Blade's and the Lance's). Tiers: the Meadow
  Warden, the Ember Colossus, the Frost Tyrant and the Prism Hydra. One moveset for all four (`Config/Swords` `scythe`),
  each cut about a third slower than the sword's and the same damage a second (tests/SwordsConfig): Reap (wound back
  over the right shoulder, one flat sweep right to left, the tip leading; reach 10 in 180 degrees, a 1.1-stud step; Hit
  0.34 of 0.85), Back Sweep (a low spin, the blade across your front, behind you and through the front again; 10 in 180
  ahead, since every cut soft-aims you at the foe; 0.42 of 0.9), Whirlwind (two spins with it held out, every foe within
  10; 0.98 of 1.7) and the skill Reaping Cyclone (three spins with it raised high, a ring of crescents thrown out at the
  end of each spin, the third the hit: every foe within 9; 0.94 of 1.6; free after the hit; the HUD button "Reaping
  Cyclone" with the spare glyph `CrescentSparks`). Held upright at the right side with the blade facing forward (owner 2026-11-09; the wrist turns it a quarter for the hold: the
  spear's grip turned half round the shaft, `GRIPS.scythe`: the imported models carry their blade along +X), on the back
  48 degrees from upright, 0.2 studs higher than the spear (the 9-stud Rift Reaper's butt 0.38 over the ground, its top
  2.66 over the head). Perks: the Widow's Venom (the Sunforged's burn as poison, 2.5% of the creature's ATK a second for 3
  s, ticks shown as "Poison"), the Storm's Chain Lightning (every 4th hit strikes the target for 40% more and arcs to
  every other standing foe for 30%, a bolt to each; new `chain` kind) and the Rift's Reap (30% more to a foe under 30%
  of its HP, a violet burst; new `execute` kind); Grade S x1.2 on the shares, the thresholds kept (`BattleSim`
  swordPerk/swordHit, `WeaponText` words). Effects (`scytheSweep`, `scytheWhirl`, `reapingCyclone` in
  `Config/SwordSkillFx`, drawn by `Util/SwordSkillFx`): the blade's element streaming off every cut and a huge crescent
  of light timed to each strike (Reap's across the front, Back Sweep's a whole low turn round you, the Whirlwind's two
  turns at shoulder height), the slash trail from the socket out along the blade (`SwordFx.TRAIL_BLADE_SCYTHE`); the
  Whirlwind's finish drawn where you stand (`SwordSkillFxRules.finisherAhead`: shockwave rings to the reach, a circle of
  crescent blades, sparks, dust, `SHAKE.scytheWhirl` 0.55); Reaping Cyclone's glowing ring and element swirl under you
  and three rings of flat crescents flying out to the radius, the third arriving with the hit (a shockwave, sparks,
  `SHAKE.reapingCyclone` 0.65; no camera moment: the Common skill). Sounds: its own mix of measured Pro Sound Effects
  (a big whoosh on Reap, a whoosh on every spin, the ring's slam). Models: Figma concepts B, Meshy, cleaned by
  `weapon_kit.build_scythe` (the shaft centred, the blade turned to one side, the head from the blade's hanging tip,
  Head and Shaft); the Forge Scythe's three socket gems tinted per element; glow maps for the gems, the Widow's lilac
  edge and eyes, the Storm's lemon lightning and cyan edge, the Rift's violet cracks and crystals; portraits in the
  reaper pose. Moves keyed in `tools/blender/anim_scythe.py` (published 2026-11-09). Balance rows (as round 1's, 200
  fights solo, "well"):

  | Scythe on its tier boss | 0.8x win: Steel / +0 C / +10 S | 1x fight: Steel / +10 S |
  |---|---|---|
  | Ember Forge Scythe, Meadow Warden | 100% / 100% / 100% (Steel already above 85%) | 80 s / 44 s (55%) |
  | Widow's Reaper, Ember Colossus | 60% / 62% / 70% | 68 s / 52 s (76%) |
  | Storm Reaper, Frost Tyrant | 47% / 62% / 75% | 130 s / 72 s (55%) |
  | Rift Reaper, Prism Hydra (after the rooms) | 61% / 68% / 84% | 179 s / 125 s (70%) |

  The Rift Reaper first had the Legendary 1.8: +10 S won 92% at 0.8x (1.3: 81%, 1.5: 85%). The Storm Reaper on the
  Rift Devourer (adds for its arcs to reach): 60% / 69% / 87%, the same with its arcs at 20% (88%) or 25% (86%): an
  Epic's Power, not the arcs; inside the limit on its own tier boss. The three boss scythes' own skills (Eight Legs,
  Storm Cyclone, Thousand Cuts) are part 2.
- **Thousand Cuts** (the Rift Reaper's own skill, spec 5.4, plan `2026-11-09-thousand-cuts.md`; the owner: "the
  legendary scythe skill is boring. make it flashy violent, exaggerated. you can even summon a grim reaper as effect.
  screenshake. ground breaking anything to make it legendary"; storyboard and Reaper concept B approved 2026-11-09).
  Its own moveset `riftReaper` (the scythe's cuts, moves and sounds, the same tables). Same rules as every skill (0.9
  of a hit, the shared cooldown, a dodge or switch before the hit cancels it, free after it, you never move and can
  always be hit). 2.6 s: raised high overhead through the charge (10 violet cracks racing out to 14 studs, your screen
  darkening, a growing rumble); at 0.7 s the butt slammed into the ground, the rift tearing open 6 studs behind you and
  the Grim Reaper rising out of it (16 studs, see-through with a glowing outline, holding a giant Rift Reaper;
  `ReplicatedStorage.FxModels.GrimReaper`, moved by code: `SwordSkillFx.REAPER`), souls swirling; a kneel while you
  fade half into the rift and four waves of slashes rip across the area, slabs of ground heaving up, a jolt each wave;
  the harvest at 1.8 s (the hit: every foe within 14 studs, `spin`): an X slash as the Reaper spins its giant scythe a
  full circle (a crescent ring), three shockwaves, 18 rocks, a 22-stud pillar of light, `SHAKE.thousandCuts` 1.25 (the
  biggest); the Reaper dissolves into rising souls and the cracks close by 3.2 s. A camera moment framed on you (the
  wide shot 30 studs out, looking up at the Reaper). Another player's cast: three slashes a wave, no darkening, slabs,
  swirl or souls, a third of the rocks. Sounds (Pro Sound Effects, measured): the charge and rumble, Avalanche Crashing
  3 as the ground splits, a spirit growl and Unhappy Angels Discordant Choral Wail as the Reaper rises, a Soul Slice
  each wave, a reversed whoosh into the X, a thunder roar and slam on the harvest. Owner 2026-11-09 ("the slashes are
  hard to see. can add the slashes and flashes across the screen, with also a sound effect of a fast slashes"): your
  own cast also rips 5 thin dark slashes (owner 2026-11-09: "darker and thinner": a 12 px deep-violet glow round a 2 px core) across your screen each wave with a white flash, and a big X
  with a bright flash on the harvest (`Config/SwordSkillFx SCREEN`, `Util/ScreenSlashRules`, client
  `Util/ScreenSlashes`); a flurry of sharp sword swishes (three Pro Sound Effects, measured) through the cuts. The HUD button "Thousand Cuts"
  (`UIIcons.Skull`). The Reaper: Meshy from concept B (the void reaper king), cleaned by
  `tools/blender/build_grim_reaper.py` (6,000 triangles); the move keyed in `tools/blender/anim_rift_reaper.py`.
  Balance re-run (tools/balance/bosses, Prism Hydra, 200 fights): unchanged, +0 C 68% and +10 S 84% at 0.8x, the 1x
  fight 125 s (the skill's damage is the same).
- **Quick weapon switch** (weapons round 2, the owner's pick A): a round chip on the right edge at mid height with your
  weapon's portrait in its rarity's ring, `<` and `>` either side, Q (next) / Z (previous, `Weapons.PREVIOUS_KEY`, its
  badge on `<`; owner 2026-11-09; Shift+Q too, but Shift is the dodge in a fight) on keyboards, a swipe on the chip; it
  steps through every weapon you own (swords, spears, scythes; by rarity, then name: `Util/WeaponSwitch`, Lune-tested)
  and asks the server to equip it (`EquipWeapon`), its name under the chip for 1.5 s. Shown with two weapons or more,
  never over a window or while placing (`WeaponSwitchController`, sizes in `Config/HudLayout` WEAPON_SWITCH). In a fight a
  switch is allowed but costs `Weapons.SWAP_SECONDS` (1 s) with no cut or skill (the dodge still works), the combo
  starts again, the old weapon's cut or skill still on its way is cancelled (the server checks `SwordRules.skillDodged`
  with the switch time), the skill's cooldown carries over, and the HUD's skill button follows the new weapon. A
  switch while the weapon is drawn shows as a draw: the new one starts on the back and its draw and ready moves bring it
  to the hand (`SwordRules.switchDraw`). A skill's later hits keep the weapon it was cast with (element, bond, perk:
  `WeaponRules.hitInfo`), so switching mid-skill gains nothing. In a fight the chip moves up above every fight button
  (`UiLayout.weaponSwitch`, Lune-tested on phones, tablets and desktops) and never scales its arrows under 48 px. Quick
  steps send only the weapon they land on (the server drops equips inside `Weapons.EQUIP_COOLDOWN`, so the chip waits
  the cooldown plus `EQUIP_SEND_SLACK`: `WeaponSwitch.sendAt`).

---

## 6. Products (stock you sell)

| Product | Wholesale (box) | Units | Market price / unit | Unlock |
|---|---|---|---|---|
| First Spark Booster Pack | $48 / box | 24 | $3.00 | Start |
| Card Sleeves | $30 / box | 20 | $2.50 | Lv 3 |
| Deck Box | $60 / box | 10 | $9.00 | Lv 7 |
| First Spark Booster Box (sealed) | $90 each | 1 | $120 | Lv 11 |
| Set 2 Booster Pack | TBD | 24 | TBD | Lv 20 |

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

Levels 1 to 100 (spec `2026-11-04-round4-design` section 8): the total XP to reach level n is
`BASE_XP × (n − 1) ^ POWER` rounded to 10 (`Config/Levels`: 40, 2.31; maths in `Util/LevelMath.luau`, Lune-tested).
Every unlock sits at the new level whose XP is nearest what it needed before (Lv 20 ≈ 36,000 XP, where shop jobs
open; `tests/LevelRemap.spec`), so the pace is the same with about twice as many level-ups. Lv 100 (1,629,210 XP) is
the cap: XP keeps counting, the level doesn't, and the HUD's XP pill shows MAX. A packs-only shop earns about 30 XP
a minute, so Lv 2 comes about 1.5 minutes after the first sale (it unlocks nothing; a level-up and its reward).
Old saves keep their XP and load on the new level for it (a Lv 10 shop is Lv 20), with no back-pay of rewards.

| Lv | XP needed | Unlocks |
|---|---|---|
| 1 | 0 | Base |
| 2 | 40 | - |
| 3 | 200 | Card Sleeves |
| 4 | 510 | Wall Shelf, starter sword, boss 1 (Meadow Warden) |
| 5 | 980 | Card Condenser |
| 7 | 2,510 | Accessory Hook, Deck Box, Expansion 1, boss 2 |
| 9 | 4,880 | Big Display Rack |
| 11 | 8,170 | Sealed Booster Box |
| 14 | 14,970 | Grading Station, boss 3 |
| 17 | 24,190 | Expansion 2 |
| 20 | 35,970 | Shop jobs (first slot), Set 2 |
| 26 / 34 / 43 / 57 | 67,810 / 128,770 / 224,780 / 436,890 | bosses 4 / 5 / 6 / 7 |
| 100 | 1,629,210 | the cap |

**Level-up rewards** (`Config/Levels`, `Util/LevelUpRules`, Lune-tested): every level pays $10 × the new level
(EconomyService, in `AddXP`; $20 at Lv 2, $1,000 at Lv 100), and every 10th level gives a First Spark Pack, a Bag item
(`Items.sparkPack`, `open = "FirstSparkPack"`) given by `LevelUpService`. A sale that crosses several levels pays every
one. The toast reads "Level 7! +$70 · Unlocked: Deck Box". In the Bag a pack item has an Open button (main game only):
the remote `OpenBagPack` (rate-limited, refused mid-fight) takes one and rolls a normal pack with pity
(`PackService.OpenItemPack`), and the usual pack opening plays ("From your Bag" in its corner). Studio: `/setxp <n>`
sets the XP total, down as well as up (no rewards), to test level-ups on a grown save.

**Level-up effect** (owner 2026-11-04: the light pillar, "pillar and spinning circle is enough"; spec section 9;
`Util/LevelUpFx`, `LevelUpController`, `Config/LevelUpFx`): a rune circle (Blender-rendered, `assets/ui/fx-levelup`)
spins open on the ground, at 0.4 s a pillar of light (a white core in a gold glow, motes rising) shoots up and the one
levelling up lights for a moment, at 1.0 s a star badge pops with the number rolling up and a candy "LEVEL UP!" under it,
and from 1.5 s the beam thins and the circle fades (3 s in all). Every 10th level the pillar runs pink, butter, mint,
sky and lilac, the circle is two-toned and a pack flies out with "+1 pack". A creature that levels up (`CardService.
OnBeastLevelUp`) gets a smaller pillar in its element's colour and a "Lv 19 -> 20" chip on its drawn model (summoned or
a shop worker; markers and worker rigs carry `BeastId`); your own after a won fight starts when its XP sparks land on
the portrait. The server sends `LevelUpFx` to everyone; others within 60 studs of their camera see it and hear it
quieter. A shop level-up never plays mid-fight (a glowing circle underfoot reads as "dodge"): `LevelUpService` holds it
until the fight (or PvP) ends, and after a boss fight its end screen too (the victory screen 6 s, the defeat countdown and the trip home 8 s, `LevelUpFx.AFTER_BOSS`), and merges several into one; the cash, the pack and the toast come at once. Bag packs don't open in a fight or PvP, nor while a pack is on the stage or a rip is on its way. Sounds
(round 5, owner: round 4's four stacked sounds were "too loud, too much"; Pro Sound Effects, APM Music): **one soft
sound** as the badge pops, and on a 10th shop level a short sting with it, from one of three sets (`LevelUpFx.SOUNDS.sets`,
`LevelUpRules.soundSet`): 1 soft sparkle ping (the default) with the "All It Takes" sting, 2 bright bell ding with the
same sting, 3 twirling chime with the "Spinning Around" link; about half round 4's volume (sound 0.06-0.07, sting
0.1-0.12, never over 0.15). A creature plays its set's sound, quieter and higher. They're preloaded on the loading
screen. Studio: `/levelfx [level]`, `/beastlevelfx`, `/levelsound <1-3> [volume]` (picks a set and plays it once; 0
for the default) and the admin panel's "Level sound" buttons. Measured: about 59 fps during the effect against 60 without it.

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
- **Slots:** 1 at shop Lv 20; the "Extra Job Slot" game pass adds 1 more (max 2). Assign from the binder card
  view ("Assign job"): the **Assign job** picker (round 5, owner pick A "Two big tiles", `JobRules.assignTiles`) covers
  the panel under its band with the Job icon, "Assign job" and "Job slots: used / total", one big tile per job side by
  side (its picture, Restocker: Shelves, Cashier: Register; its name; what it does; "Works: <word>", this copy's speed
  word in its colour, as the Jobs window says it) that assigns on a tap, and a full-width pink Cancel. The **Jobs** window (style kit, option B of the 2026-10-29 mockups) explains the rules once
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
- **Tired spells** (owner 2026-11-06; `Util/TiredRules`, `Jobs.TIRED`): after 10-15 minutes of work (random) a worker
  is tired for 5 minutes: it works and walks at x0.6 and its mistake chance is x1.5 (at most 30%), never stopping;
  then it's rested and works a new stretch. A toast tells the owner ("Nightowl is tired: scanning slower for 5 min.
  Take the register?"; restocking for a Restocker, and when it's rested again), its name tag adds "😴 Tired" and the
  Jobs panel a "😴 Tired 4:17" pill counting down. It's the owner's moment to step in at the register, where kid
  offers and haggles only come to them; the cashier steps aside as always. The clock runs while the card works (the
  owner online) and isn't saved: a worker put back to work starts rested. Studio: `/jobtired` (admin panel "Workers
  tired / rested") tires every worker now, or rests them.
- **XP:** 2 per minute per working card, only while you're online. Battles and quests will be the main way to level.
- Working cards are locked: no display, condensing or second job until unassigned.
- In the shop they walk as invisible R15 rigs (pathfinding) that each client draws as the card's creature model
  (`WorkerVisualController`, `Party.CREATURE_MODELS`; at least `Jobs.CREATURE_MIN_HEIGHT` 3.4 tall), with the motion
  kit; cards without a model show the R15 rig in the element colour, sized by rarity. Their name tag (`Jobs.TAG`, 190 x
  66 px, a solid text outline) sits 1.4 studs over the drawn creature's top, a flying one's hover included
  (`Util/CreatureFlight`, shared with the client's drawing; owner 2026-11-06: Nightowl's name sat in its wings). An
  on-top tag isn't drawn at all on the invisible rig (tried in Studio), so lamps can still cover it from some angles. The cashier stands on a low
  charcoal step behind the counter (`Town.COUNTER.STEP`, solid, 1 tall) so even a small pet shows over it.

### 7.5 Tuning goals
- First upgrade within ~3 minutes.
- Shop Lv 7 in about 1–1.5 hours of play.
- Lv 20 in about 8–10 hours.
- These are targets. Tune after playtesting, keep numbers in config files so it's easy.
- Customers round check (`lune run tools/economy/sim 2000`, 2026-11-06): before (`NO_KIDS=1 RATING=3`): first
  Legendary 15 min, Grade S Legendary with 1 star 21.0 h (median). After (kid offers on, a well-run 4-star shop): 13
  min and 19.6 h (-7%). The 4 stars alone (`NO_KIDS=1`) would make it 12 min and 16.8 h; buying every kid offer
  (about 3.5 an hour, $34 an hour, a Legendary offer every ~13 hours) gives some of that back. At 3 stars with kids:
  16 min and 24.1 h. The first Legendary is pity-bound (within 130 packs), so its minutes move with packs per hour.

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
├── assets/monsters/            # wild monster and boss models (.rbxm; Meshy image to 3D, rigged by tools/blender/rig_<species or boss>.py; bosses by id) → ReplicatedStorage.MonsterModels
├── assets/props/               # town prop models (.rbxm) → ReplicatedStorage.PropModels (docs/props.md)
├── assets/town/                # hand-placed town scenery (TownDecor.rbxm) → Workspace.TownDecor
├── assets/packs/               # pack, deck box and display box models (.rbxm) → ReplicatedStorage.PackModels (docs/packs.md)
├── assets/ui/fx/               # pack opening effect sheets rendered in Blender, uploaded as images (Config/PackFx)
├── assets/ui/combat/           # the boss-fight HUD's slanted button, HP bar, hit flash and ring textures, uploaded as images (Config/CombatHud, Config/SwordFx)
├── assets/ui/fx-sword/         # the sword effects' textures (crescent, burst flipbook, line, star), made by tools/textures/make_sword_fx.py, uploaded as images (SwordFx.TEXTURES)
├── assets/animations/          # sword moves as KeyframeSequences (.rbxm) → ReplicatedStorage.SwordAnimations: StarterSword/<move>, each round 1 sword's own skill (ForgeSword, VerdantBlade, SunforgedBlade, PrismBlade /skill) (docs/animations.md)
├── assets/monster-animations/  # monster and boss attack clips (.rbxm) → ReplicatedStorage.MonsterAnimations (docs/animations.md "Bone rigs")
├── assets/weapons/             # sword models (.rbxm) → ReplicatedStorage.WeaponModels: StarterSword, ForgeSword_<Element>, VerdantBlade, SunforgedBlade, PrismBlade (docs/weapons.md, docs/animations.md "The sword model")
├── assets/weapons-source/     # ForgeSword.rbxm, the source of the Forge Sword's five element copies (tools/weapons/forge_variants); not synced
├── assets/ui/weapon-portraits/ # the swords cut out for their cards (tools/ui-art/cut_product_picture.py), uploaded as images (WeaponLooks portrait ids)
├── assets/ui/weapon-glow-maps/ # each weapon model's glow map (tools/textures/make_glow_maps.py), uploaded (WeaponLooks GLOW_MAPS), baked in by tools/weapons/add_glow_maps
├── tools/blender/              # Blender build scripts: creatures, bosses, the pack models and effects (pack_kit.py), the plaza fountain, the town portals (portal_kit.py), the Wild boss arenas' props (build_arena_props.py), the starter sword (build_starter_sword.py), the weapons' cleanup (weapon_kit.py, build_weapon_<id>.py; spears: build_spear), the sword moves (anim_kit.py, anim_starter_sword.py; run_sword_moves.py exports them in a background Blender, `--sword <name>` for a round 1 sword's skill: anim_forge_sword.py, anim_verdant_blade.py, anim_sunforged_blade.py, anim_prism_blade.py; `--sword spear` for the spear moveset, anim_spear.py)
├── tools/anim/                 # build_kfs.luau: exported sword moves (JSON) → KeyframeSequence .rbxm; build_bone_clips.luau: monster/boss clips (Lune)
├── tools/weapons/              # finish_sword.luau: colours, pivots and PrimaryPart for an imported sword model; forge_variants.luau: the Forge Sword's five element copies (Lune)
├── tools/textures/             # pack textures and flipbook sheets, the HUD's slanted buttons and the rings, the sword effects (make_sword_fx.py) (Pillow)
└── src/
    ├── server/                 # → ServerScriptService
    │   ├── init.server.luau    # boots services
    │   ├── Services/
    │   │   ├── DataService.luau      # ProfileStore, load/save, defaults
    │   │   ├── PlotService.luau      # claim/release plots, modern shop shells (glass front, sliding doors, sign band, roof)
    │   │   ├── TownService.luau      # main town: ground, street, plaza, decor props, portals, walls, trail lines, signs, lighting
    │   │   ├── SceneryService.luau   # main town: terrain and scenery round the town, in the three portal areas (Config/Scenery) and in the Wild valley (Config/WildValley)
    │   │   ├── WelcomeService.luau   # the first-visit welcome cinematic's saved flag (SeenWelcome)
    │   │   ├── EconomyService.luau   # cash, XP, levels (ONLY place cash changes)
    │   │   ├── StockService.luau     # orders, deliveries, carrying, stocking shelves
    │   │   ├── PlacementService.luau # validate + place/move/sell shelves, shelf contents
    │   │   ├── PricingService.luau   # player sell prices per product
    │   │   ├── CustomerService.luau  # NPC spawn, types and props, pathing, buying, collectors, reactions, queue
    │   │   ├── RegisterService.luau  # checkout flow; a bargain hunter's offer (OnHaggle / SettleHaggle), OnSaleCompleted
    │   │   ├── OfferService.luau     # kid rips and offers, haggles: the open offer per shop, OfferAction
    │   │   ├── RatingService.luau    # shop rating: parts, smoothing, the sign's stars, RatingUpdate, the spawn gap
    │   │   ├── PackService.luau      # server-side pack rolls
    │   │   ├── CardService.luau      # binder contents (not named CollectionService to avoid clashing with Roblox's)
    │   │   ├── ShowcaseService.luau  # display cards, price them, player buys, customer card buys
    │   │   ├── CondenserService.luau # Card Condenser remote: validate, then CardService.Condense
    │   │   ├── GradingService.luau # Grading Station remote: validate, then CardService.GradeUp (cash via EconomyService)
    │   │   ├── JobService.luau       # shop jobs: slots, worker creatures, restocker/cashier loops, work XP
    │   │   ├── PartyService.luau     # party slots, summon, creature marker, perks
    │   │   ├── WildService.luau      # wild map (the valley's spawn spots, wooden signs, edges, return portal, boss portals and arena copies), plaza portal, healing spring, monsters (spawn, wander, chase, the valley's crowd-sized population)
    │   │   ├── BattleService.luau    # wild fights: start checks, BattleSim loop, rewards, resting, spring
    │   │   ├── SwordService.luau     # the sword: unlock, drawn/sheathed, standard body, back accessories hidden in boss fights (BattleService handles the attack/skill/dodge remotes)
    │   │   ├── WeaponService.luau    # owned and equipped weapons (saves), EquipWeapon, the Sword/SwordGrade/SwordLevel attributes, HitInfo for sword hits
    │   │   ├── ForgeService.luau     # the Forge machine: forge, upgrade, reforge (costs from WeaponRules, all or nothing, grade rolled here)
    │   │   ├── ArenaService.luau     # PvP: challenges, bet escrow, arena pad + queue, fights, saved record
    │   │   ├── ItemService.luau      # item inventory (Star Shards, boss items): give, take, save
    │   │   ├── BossService.luau      # boss ladder: saved progress, arena gates and copies, keys, boss wins' items (farm protection)
    │   │   ├── FrontierService.luau  # teleports: plaza Frontier portal, Explore / Join friend, back home (Dungeon: back to the Frontier)
    │   │   ├── DungeonGateService.luau # Frontier: the Dungeon portal's checks, groups and reserved-server teleport
    │   │   ├── DungeonService.luau   # Dungeon: the run (arrivals, rooms, carried HP, out, the chamber, the way back)
    │   │   ├── DevService.luau       # Studio-only test chat commands (/crowd: extra players counted in the Wild's biomes)
    │   │   ├── LevelUpService.luau   # shop level-up packs, opening Bag packs (OpenBagPack), the LevelUpFx broadcast (held mid-fight)
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
    ├── first/                  # → ReplicatedFirst.LoadingScreen (runs before anything else loads)
    │   ├── Show.client.luau    # the loading screen from the first frame (or the one a teleport brought), fades when done
    │   └── LoadingGui.luau     # builds, animates, updates and fades the "card fan" loading screen
    ├── client/                 # → StarterPlayerScripts
    │   ├── init.client.luau
    │   ├── Controllers/
    │   │   ├── LoadingController.luau  # the loading screen's steps (character, save, shop pictures, creature, fight gear), the teleport screen
    │   │   ├── WildLoadingController.luau # the Wild's loading screen: portal swirl, holds you still until the valley round you is in
    │   │   ├── UIController.luau       # main ScreenGui, status corner (cash, level + XP), the toasts' speech bubbles over the cash
    │   │   ├── OrderController.luau
    │   │   ├── BuildController.luau    # Build menu (category tabs, 3D model tiles), shelf prompts, shelf edit menu
    │   │   ├── PlacementController.luau
    │   │   ├── PricingController.luau
    │   │   ├── RegisterController.luau # checkout panel; the offer panel (kid offer, haggle, counter)
    │   │   ├── CustomerController.luau # collectors' thought bubbles, kids' rip reveals
    │   │   ├── RatingController.luau   # the rating chip and its tips window
    │   │   ├── CarryController.luau    # drop carried box
    │   │   ├── PackOpeningController.luau # the 3D pack opening: OpeningFlow, taps and swipes, server results, closes on fights
    │   │   ├── AnnouncementController.luau # big-pull chat messages
    │   │   ├── BinderController.luau   # the binder screen: collection data, the 3D binder's pages (cover, 2x2 pockets with chips), set tabs, Q/E page keys, page counter, Filters window (F), set progress card, tooltips, the Bag window
    │   │   ├── CardDetailController.luau # the binder's card view: 3D card + copies panel (best first), stat tiles, XP and star bars, party / job buttons
    │   │   ├── ShowcaseController.luau # manage your own card case, marketplace style: listings, details, tooltip, Set price
    │   │   ├── CondenserController.luau # Card Condenser panel (tidy two panes): toolbar, slim rows, the card's before -> after, Condense
    │   │   ├── GradingController.luau # Grading Station panel: pick card + copy, next grade, cost, Grade Up
    │   │   ├── JobsController.luau      # Jobs window: rule chips, worker rows (card tip, status, XP, speed and mistake words, Switch job), free and locked slots
    │   │   ├── PartyController.luau     # Party HUD button and panel: three columns (Power, bars, perk, rest), Summon, XP Tonic, Remove
    │   │   ├── BuffController.luau      # buff badge (bottom-right) and tooltip for the summoned creature's perk
    │   │   ├── ButterflyController.luau # client butterflies at the plaza spring, Forest Falls and the trails' start
    │   │   ├── DayCycleController.luau # the town's day cycle on this client (afternoon outside town)
    │   │   ├── MusicController.luau     # music where you are: the town, the Wild valley's areas, its boss arenas (crossfades)
    │   │   ├── TreeSwayController.luau # trees near the camera lean in the wind
    │   │   ├── TownCritterController.luau # eight Cute Pets animals running round their homes (or laps, or resting)
    │   │   ├── PlazaNpcController.luau # the plaza's sitting townsfolk: sit animation and sips (client only)
    │   │   ├── FountainFxController.luau # the healing fountain's rune circle, light column and orbs (client only)
    │   │   ├── PortalFxController.luau # spins every portal's vortex near the camera (client only)
    │   │   ├── WelcomeController.luau # the first-visit welcome cinematic
    │   │   ├── PriceTagController.luau  # point at / tap your shelf price tags to set the price
    │   │   ├── PartyBarController.luau  # bottom-right party cushion: Party pill + 3 round portraits (and the mascot), tap or 1/2/3 to summon
    │   │   ├── MonsterController.luau   # draws wild monsters on their markers (model or placeholder) at their species' height, glow masks, Fx_ bone effects; boss rigs, head glow, death
    │   │   ├── DungeonController.luau   # Dungeon: the run line and Leave
    │   │   ├── TitleController.luau     # titles over players' names (Dungeon Conqueror)
    │   │   ├── BattleController.luau    # Fight prompts, the Return to town pill in the wild, XP sparks after a win, fight bar (wild + PvP), boss HP bar and banners, damage numbers, end screen
    │   │   ├── LevelUpController.luau   # plays the level-up pillar on you, your creatures and players nearby (LevelUpFx)
    │   │   ├── SwordController.luau     # draws the equipped weapon (its glow ladder, WeaponLook) on backs and in hands, the first-sword popup, boss-fight actions (buttons, keys, dodge dash), trail, sounds, kneeling
    │   │   ├── WeaponSwitchController.luau # the quick weapon switch chip on the right edge: < and >, a swipe, Q / Z (EquipWeapon)
    │   │   ├── WeaponRevealController.luau # a boss's weapon drop and the Forge's results: the reveal on the opening stage
    │   │   ├── ForgeController.luau     # the Forge window: Forge / Upgrade / Reforge tabs and what each does, weapon rows, the chosen weapon's card, Now / After boxes, cost chips and one button
    │   │   ├── WeaponDetailController.luau # an Armory weapon's card view: its stats in words, Equip
    │   │   ├── BossBoardController.luau # Bosses HUD tile and the Boss Ladder: bosses' list with status chips and Next, the chosen one's banner, To fight it checklist, Rewards with odds, footer with next step and Take me there
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
    │       ├── FontStyle.luau          # switches Gotham text to the game fonts (FredokaOne, Montserrat)
    │       ├── Hud.luau                # HUD layout: Manage tray, bottom tiles, context tiles, top bar
    │       ├── Icon.luau               # draws a UIIcons icon (or an emoji) into a holder
    │       ├── CardTips.luau           # card tooltips in the style kit: binder card summary, party copy (bars, perk, rest)
    │       ├── CopyCompare.luau        # the kid swap comparison: verdict badge and sentence, IN -> OUT cards, paired stat bars, perk line
    │       ├── Tooltip.luau            # word tooltips for icons without a label (hover, or hold a finger on it); rich item tips
    │       ├── BossTints.luau          # a boss's UI icon and its key fragments' tint (ladder, Bag)
    │       ├── BinderDesk.luau         # the 3D binder's scene: desk, painted lamp light, case, rings, page canvases, set tabs, camera framing, picking by raycast
    │       ├── StageSpot.luau          # puts the binder, card view and pack opening stages right above the player (clear box, claims) and moves their parts
    │       ├── PageTurner.luau         # the binder's turning page: bending strips with light cards on both sides, shade, shadow, page sound, drag
    │       ├── ListenAtCharacter.luau  # keeps sounds heard at the character while the camera is on a stage (binder, card view)
    │       ├── WorldTags.luau          # switches on-top world tags and bubbles off while a stage scene shows (binder, card view)
    │       ├── CardFace.luau           # draws a card face (front, back, missing) into a frame
    │       ├── WeaponFace.luau         # draws a weapon's card (owned: portrait, Power, grade, +level; locked: source and progress) on CardFace's parts
    │       ├── WeaponLook.luau         # a weapon model's glow ladder: shell, aura, trail, burst, Awakened effect, twinkle, light; the stand-in model
    │       ├── OpeningStage.luau       # the opening's 3D stage: backdrop, lights, camera, post effects, bars, flash, shake, sounds
    │       ├── OpeningPack.luau        # the pack (or deck box) on the stage: idle sway, drag, the cinematic tear, the lid
    │       ├── OpeningCards.luau       # the pulled cards: stacking, flips with teases and hits, alive, the row, the lineup
    │       ├── OpeningFx.luau          # the opening's effects: rip burst, foil shards, glints, light leak, rays, aura, motes
    │       ├── OpeningResults.luau     # the opening's screen: tap layer, hint, box and pity pills, odds, results pills, Continue
    │       ├── ProductPicture.luau     # a product's picture in menu rows: the pack / deck box picture, or its icon
    │       ├── CreatureVisuals.luau    # shared model pipeline + motion for creatures and monsters
    │       ├── RestTimers.luau         # resting countdowns for the party bar and Party panel
    │       ├── LevelUpFx.luau          # the level-up light pillar: rune circle, beams, motes, light, star badge, sounds
    │       ├── SummonFx.luau           # a creature popping up (pillar, chime), going back to you (whoosh), fainting (dizzy stars)
    │       ├── HealFx.luau             # your creature at the healing spring: "+ Healing" pill, floating plus signs, green light
    │       ├── HudMascotView.luau      # the mascot peeking over the party cushion: breathes, blinks, ducks on a summon, chirps on a tap
    │       ├── DefeatScreen.luau       # a lost boss fight: grey world, the fight's numbers, a tip, the countdown to town
    │       ├── SwordAnims.luau         # loads and plays a sword's moves (ids, or the synced KeyframeSequences in Studio), markers
    │       ├── SwordSkillFx.luau       # the round 1 swords' slash, finisher and skill effects (Config/SwordSkillFx), coloured and sized by the weapon
    │       ├── SkillCinematic.luau     # your own skill's camera moment (Sunfall Cleave, Prism Judgment): side shots, restored after
    │       ├── CombatHud.luau          # the boss and wild fight HUD (wild: no sword buttons): slanted buttons with icons, cooldowns and key chips, your portrait and HP bars, the boss fights' party strip, the red hit flash
    │       ├── HpBar.luau              # one slanted neon HP bar: ghost of lost HP, heal lead, ticks, hit flash (HUD and boss bar)
    │       ├── CombatAssets.luau       # downloads the fight's art, sounds, moves and sword models behind the loading screen
    │       ├── SoundBank.luau          # keeps one silent loaded copy of each fight sound all session; one-shots are made from it
    │       ├── SuperFx.luau            # the ten super move looks in the world (charge, impact, linger), the shields' domes
    │       ├── SuperCinematic.luau     # a super's cinematic on the caster's screen: camera, card cut-in, wash, bars, sky, impact frame
    │       ├── RingFx.luau             # closing rings: slam circles and swipe cones on the ground
    │       ├── HitFx.luau              # sword feel: sparks, flash, the swing arcs, hit impacts, rings, cut lines, dust
    │       ├── PackEmitter.luau        # a particle emitter from a VFX pack effect's spec (the hit impact, pack auras)
    │       ├── PackHit.luau            # a hit in the packs' look, sized to the foe: sword cuts and creature attacks
    │       ├── VictoryScreen.luau      # the boss fight end screen: glowing title, reward tiles, notes, party XP bars
    │       ├── FightToast.luau         # a normal monster fight's end: a small toast with cash and XP
    │       ├── FightFx.luau            # fight events into attack pictures: charges, element attacks landing with the hit
    │       ├── ElementFx.luau          # the pieces of fight effects (textured light): charge glow, comet, burst, bolt, slash, eruption, pillar, sound
    │       ├── ScreenFx.luau           # fight screen shake (one decaying shake, falls off with distance) and screen flashes
    │       ├── ClipPlayer.luau         # one-shot attack clips on monster and boss bones (model-space poses), over the procedural motion
    │       └── AfterImage.luau         # the dodge's fading copies of the character
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
        │   ├── ProductPictures.luau # the menus' pack / deck box pictures by look, their fit, the fallback icons
        │   ├── Customers.luau  # NPC spawn, patience, bubbles
        │   ├── Stages.luau     # how high above the player the client stages go (and why: the camera's light)
        │   ├── Toasts.luau     # the toasts' bubbles: kinds and colours, sizes, how many, timings, the pop
        │   ├── Register.luau   # checkout reach, counter items
        │   ├── Packs.luau      # pack slots and odds
        │   ├── PackOpening.luau # the 3D opening: stage, camera, tear, stack, flips, alive, results, sounds (client)
        │   ├── PackOpeningLayout.luau # where the opening's cards sit on screen (plain data)
        │   ├── LevelUpFx.luau  # the level-up pillar's textures, timing, sizes, colours, sound options (plain data)
        │   ├── PackFx.luau     # the opening's effect sheets and images (plain data)
        │   ├── UIMotion.luau   # UI motion timings and scales (client)
        │   ├── UIFonts.luau    # the game fonts (client)
        │   ├── UIIcons.luau    # UI icon image ids by name (HUD, top bar, customer bubbles)
        │   ├── IconTips.luau   # the words each label-less icon's tooltip shows
        │   ├── HudLayout.luau  # HUD tile sizes, fan arc, colours (client)
        │   ├── CreamTheme.luau # the windows' colours (cotton candy now), outlines, corners, header bands (plain data)
        │   ├── BabyColors.luau # the cotton candy baby colours, roles, element rims, the soft glow, soft buttons (plain data)
        │   ├── SoftHud.luau    # the squircle HUD tiles: sizes, colours, the squishy hover (plain data)
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
        │   ├── Combat.luau     # attack timing, charge lead, element wheel, abilities, run, rest, spring, the player in boss fights (HP, down, dodge)
        │   ├── AttackFx.luau   # attack effects: each element's attack kind and colour, flight, combo, orbit, budget, sounds
        │   ├── Victory.luau    # the fight end screen: timings, sizes, colours by result, sounds
        │   ├── Swords.luau     # swords: combo, skill, moves, sounds, model, grips, unlock level (plain data)
        │   ├── Weapons.luau    # the weapons: rarity, element, source and cost, Power bases, perks, upgrade and reforge costs, drop chance (plain data)
        │   ├── WeaponLooks.luau # each weapon's glow, trail, aura, Awakened effect and portrait; the glow ladder, the reveal's timings (plain data)
        │   ├── CombatHud.luau  # the boss-fight HUD's buttons, icons, keys, colours, HP bars, portrait and hit flash (plain data)
        │   ├── SwordFx.luau    # rings, hit feel and hit-stop, the swing arcs and hit effects, slash trail, wind-up glow (plain data)
        │   ├── SwordSkillFx.luau # the round 1 swords' looks: slash, finisher and skill numbers, element particles, shakes, the camera moment (plain data)
        │   ├── Wild.luau       # wild zones, monster species, spawns, rewards
        │   ├── WildLoading.luau # the Wild's loading screen: steps, tips, times, swirl and colours (plain data)
        │   ├── SuperFx.luau    # the super moves: ten looks by grade, cinematic tiers, camera, skies, textures, sounds (plain data)
        │   ├── WildValley.luau # the Wild valley: biomes, trail, passes, hills, terrain, props, stream, bridge, cave, cracks, vents, volcano, population, signs, arena field and looks, edge (plain data)
        │   ├── Pvp.luau        # challenge timings, bet cap and steps, arena layout
        │   ├── Frontier.luau   # Frontier zones, species, drops (same shape as Wild)
        │   ├── Dungeon.luau    # the Dungeon: rooms and packs, timings, layout, lighting
        │   ├── Items.luau      # every item: name, icon, description; stack limit
        │   ├── Bosses.luau     # boss ladder: bosses, drops, chests, farm protection, arenas
        │   ├── Town.luau       # main town: prop slots, decor layout, shop shell sizes, plot themes, portal areas, trails, walk edge, signposts
        │   ├── Scenery.luau    # terrain shapes and scenery round the town and in the portal areas (plain data)
        │   ├── Music.luau      # the town music's tracks, volume, fades and edge (plain data)
        │   ├── HudMascot.luau  # the creature peeking over the party bar: pictures, sizes, eyes, voice, timing (plain data)
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
            ├── TiredRules.luau    # shop workers' tired spells: work stretch, tired time, slower and more mistakes (pure, Lune-tested)
            ├── CreatureFlight.luau # which creatures fly and how high a drawn creature's top is (pure, Lune-tested)
            ├── ToastRules.luau    # toasts as bubbles: kind, seconds, stacking (bump a repeat, drop the oldest), the chip's emoji, the mascot's hop (pure, Lune-tested)
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
            ├── ModelPreload.luau  # which creature models a client downloads in the background, and in what order (pure, Lune-tested)
            ├── CardArt.luau       # which painting a card face draws: the half-size copy when drawn small, the full one for big views (pure, Lune-tested)
            ├── PortalLooks.luau   # which model stands at a portal, its label height, the parts and effects a look needs (pure, Lune-tested)
            ├── LavaCracks.luau    # the caldera's branching glowing cracks on its cliff faces and floor (pure, Lune-tested)
            ├── WildValley.luau    # the Wild valley's trail and markers, biome lookup, what scenery keeps clear of, spawn spots, terrain fills, arena copy spots, monster steps (pure, Lune-tested)
            ├── WildPopulation.luau # how many monsters a valley biome keeps for its players, respawn times (pure, Lune-tested)
            ├── MonsterLooks.luau  # a wild monster's height, which style moves its bones, when its effects run, which monster and boss models a place preloads (pure, Lune-tested)
            ├── Props.luau         # place swappable prop models (assets/props) or part stand-ins; server town, client ghosts
            ├── PropFit.luau       # prop fit sizes with YawOffset, register counter rows (pure, Lune-tested)
            ├── ShelfStock.luau    # stock boxes, display box fill and price tags on shelves (pure, Lune-tested)
            ├── PackModels.luau    # the 3D pack, deck box and display box (assets/packs, or stand-ins), dressed in a pack's look
            ├── ProductPictureRules.luau # a menu row's pack / deck box picture, else its icon (pure, Lune-tested)
            ├── CaseLook.luau      # the code-built CardCase prop: support, carpet, frame, glass, strip
            ├── ShowcaseLayout.luau # upright case card slots in rows (pure, Lune-tested)
            ├── OpeningFlow.luau   # the opening's phases and what a tap does (pure, Lune-tested)
            ├── OpeningLayout.luau # stage depths for on-screen card sizes, the row and the lineup (pure, Lune-tested)
            ├── PartyRules.luau    # perk strength and text, fight perks, party changes and their toasts (pure, Lune-tested)
            ├── LoadingRules.luau  # the loading screen's step, bar share, slow-save note and time limit (pure, Lune-tested)
            ├── WildLoadingRules.luau # the Wild's loading screen's step, bar share and when it may close (pure, Lune-tested)
            ├── SuperFxRules.luau # a super's grade, cinematic beats and camera framing (pure, Lune-tested)
            ├── AttackTiming.luau  # when an attack effect releases and lands, charge expiry, combo hit times (pure, Lune-tested)
            ├── FightMotion.luau   # a creature's moving about in a fight, its motion clock (pure, Lune-tested)
            ├── MonsterMoves.luau  # which attack clip a boss or monster plays for each fight event, one move at a time (pure, Lune-tested)
            ├── FightFxRules.luau  # the fight effects' budget and each element's attack kind (pure, Lune-tested)
            ├── ShakeRules.luau    # screen shake maths: add, decay, the camera offset, falloff with distance (pure, Lune-tested)
            ├── DamagePop.luau     # how a damage number pops, settles, rises and fades by style (pure, Lune-tested)
            ├── VictoryRules.luau  # the end screen's reward tiles, notes and subtitle from a fight summary (pure, Lune-tested)
            ├── DefeatRules.luau   # the defeat screen's rows, subtitle and tip (pure, Lune-tested)
            ├── SummonMotion.luau  # a summon's pop, an unsummon's shrink, a faint's tip-over, fresh stamps (pure, Lune-tested)
            ├── PetVoice.luau      # your creature's chirp: voice, volume, timing, pitch by size, bounce, when it may (pure, Lune-tested)
            ├── WalkStep.luau      # NPCs following a path: waypoint reached early, stuck when walking in place, walk clip pace (pure, Lune-tested)
            ├── MusicRules.luau    # where the town is for its music, which track is next (pure, Lune-tested)
            ├── XpPill.luau        # the level pill's XP text ("99,800 XP", "/ 226,000") and its count-up (pure, Lune-tested)
            ├── SparkPath.luau     # the XP sparks' curved flight and how many fly (pure, Lune-tested)
            ├── HudMascotRules.luau # the HUD mascot's blink timing, duck curve, tap bounce, headroom (pure, Lune-tested)
            ├── ContrastRules.luau # WCAG contrast and hue of colours, for the window theme's text (pure, Lune-tested)
            ├── SoftColors.luau    # a soft button's text colour and deep outline from its fill (pure, Lune-tested)
            ├── HoverRules.luau    # what a mouse over a window's button does: glow, lilac edge or nothing (pure, Lune-tested)
            ├── SquishRules.luau   # the HUD tiles' hover: length, widest, fits the gap (pure, Lune-tested)
            ├── CreatureMotion.luau # breathing, hop, waddle, hover poses (pure, Lune-tested)
            ├── CardRules.luau     # card market value and price limits
            ├── RevealRules.luau   # a card's reveal plan from rarity, foil and set (pure, Lune-tested)
            ├── BinderSpreads.luau # binder spreads, card ranges, which page a card is on, the page counter (pure, Lune-tested)
            ├── PageCurl.luau      # a turning page's bend, its strips, drag-to-turn, fast-turn pacing, swipes and taps (pure, Lune-tested)
            ├── BinderFit.luau     # the 3D binder's pockets on a page and the camera fit for a screen rectangle (pure, Lune-tested)
            ├── StageRules.luau    # a client stage's spot: the first clear height above the player, else the far stage (pure, Lune-tested)
            ├── BinderGesture.luau # who owns a press on the 3D binder: one pointer, lost releases, holds vs swipes (pure, Lune-tested)
            ├── OddsRules.luau     # pull odds per card from a pack's slots (pure, Lune-tested)
            ├── PityRules.luau     # pack pity: when a hit slot is raised to a Legendary or Epic (pure, Lune-tested)
            ├── BossRules.luau     # boss unlocks, loot cooldown, soft cap, over-power, phases, board words, where a loss sends you (pure, Lune-tested)
            ├── WeaponRules.luau   # weapon Power, element wheel, bond, perks, costs, paying, material goals, drop chance (pure, Lune-tested)
            ├── WeaponText.luau    # a weapon in words: stats, source, cost lines, the Forge's button, pickup and upgrade lines (pure, Lune-tested)
            ├── WeaponSwitch.luau  # the quick switch's weapons in order and the step through them (pure, Lune-tested)
            ├── WeaponLookRules.luau # which glow layers a weapon shows at its rarity, level, grade and place (pure, Lune-tested)
            ├── SwordRules.luau    # the combo's next cut (cancel points), reach and arc, aiming, lunges, the dash and its path, combo damage per second, each skill's shape (skillHits, skillImpact, skillTravel, holdFor) (pure, Lune-tested)
            ├── SwordSkillFxRules.luau # effect size by the trail, others' effects budget, the camera moment's beats and wide-shot distance (pure, Lune-tested)
            ├── SwordArcRules.luau # the swing arcs' curve, points, wipe and the hit burst's spot (pure, Lune-tested)
            ├── SwingGate.luau     # which of your sword actions is still live: tokens, the dash slash's lock, the last cut that struck (pure, Lune-tested)
            ├── RingRules.luau     # inside a slam circle or swipe cone, a closing ring's scale (pure, Lune-tested)
            ├── HpBarRules.luau    # HP bar ghost and heal timing, the red edge flash and low-HP pulse, the portrait shake (pure, Lune-tested)
            ├── CombatPreload.luau # every image, sound and animation id the boss fight needs, from its configs (pure, Lune-tested)
            ├── TownPreload.luau   # the town's pictures the loading screen keeps drawn before you walk in (pure, Lune-tested)
            ├── BossMoments.luau   # the Wild bosses' moments: when the intro roar is due, when a heal flares, which effect bones a moment uses (pure, Lune-tested)
            ├── DungeonRules.luau  # the run: carried HP, out, run size, packs (pure, Lune-tested)
            ├── NewPulls.luau      # which pulls are NEW to the collection, for the pack results (pure, Lune-tested)
            ├── LevelUpRules.luau  # level-up rewards (cash every level, a pack every 10th), held effects merged (pure, Lune-tested)
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

### 10.4 Player data schema (v16)
```lua
{
    version = 16,
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
    seenSword = false,      -- closed the "You got your first sword!" popup (SwordService)
    swordFights = 0,        -- boss fights fought with the sword HUD; its buttons show names for the first 3 (SwordService)
    weapons = {},           -- weaponId -> { grade, level } (WeaponService; the Steel Sword is everyone's, never saved)
    equippedWeapon = "starterSword", -- the weapon in hand (Config/Weapons id)
}
```
Bump `version` and write a migration whenever the shape changes.
Template and types live in `DataService.luau`. Packs are opened straight from carried boxes, so there is no
separate unopened-packs inventory; unsold stock is saved as `boxes` rather than a backroom count.

Loading is defensive: unknown IDs are dropped, prices re-clamped, level recomputed from XP, and saved shelves
that no longer fit are skipped (cards from a skipped case go back to the binder).
When a player leaves, customers put picked-up stock and cards back before the save.
DataService sets the player attribute `DataLoaded` once every service has loaded (the loading screen's save step).

**Teleport hand-off** (`DataService.HandOff` / `Reclaim`): before a teleport to or from the Frontier or the Dungeon
(`FrontierService`, `DungeonGateService`), the player's live state is saved and their session closed, so the next
place loads it at once; before, the session only closed after they'd left, and the next place waited on its lock
(measured up to 12 s). The services keep the live state; if the teleport fails (`TeleportAsync` errors or
`TeleportInitFailed`), `Reclaim` opens the session again and the next save writes it. Changes in the moment before
they leave aren't saved. A session this server ended (leaving, a hand-off) never kicks the player.

Schema history: v1 first release; v2 moved displayed cards onto `layout` entries and dropped the unused `showcase` list; v3 added the `beasts` table; v4 made stars start at 0 (old star counts drop by one); v5 gave every copy a grade (rolled per copy on upgrade); v6 added `jobs`; v7 added `party`; v8 added `resting`; v9 added `pvp`; v10 added `items`; v11 added `pity`; v12 added `bosses`; v13 added `seenWelcome` (true for everyone who played before it, so the cinematic only greets new players); v14 added `seenSword` (false for everyone, so old players see the first-sword popup once too); v15 added `swordFights` (0 for everyone, so everyone sees the button names for 3 boss fights); v16 added `weapons` (empty) and `equippedWeapon` (the Steel Sword) for weapons round 1; each `bosses` record gained `weaponPity` (read as 0 when missing, no bump: an older server dropping it only resets the pity). A service that didn't load for a player (e.g. no free plot) never overwrites
their saved data.

### 10.6 UI style and HUD
- **Loading screen** (option C "card fan", `Config/LoadingScreen`): from the first frame (`ReplicatedFirst`, replacing
  Roblox's once the configs arrive), three cards fanning out over a slim gold bar and the step it's on (since
  2026-11-05 in the Wild screen's feel, the owner's option B "the card fan in the swirl": the fan in front of the Wild
  screen's spiral twice, gold in front and pink behind, turning against each other, over the First Spark cover's sky
  dimmed and darker at the top and bottom; the teleport copy too): "Opening your
  shop..." (the Frontier and the Dungeon name themselves), "Loading your cards...", "Stocking the shelves...", "Waking up your creature...",
  "Getting the fight gear ready...", then "Ready!" and a fade. It waits for the character, the save (`DataLoaded`) and
  your own cards' paintings (small copies from the first `CollectionChanged`, kept drawn tiny in a hidden
  `CardArtCache` for the session, cards you get later too: Roblox only gets an image ready once something draws it,
  and preloading by id reports failures for pictures that draw fine; so binder pages show every face as they turn),
  the shop's first pictures (round 4: the `PackModels` folder with every look, every UI icon, the pack fronts, the mascot
  stickers, the binder covers and the level-up textures, images kept drawn; a failed or timed-out fetch counts as done,
  `LoadingRules.settled`, and the step can never hold the screen), the summoned creature's model downloaded
  (`CreatureReady`, set by CreatureController; none summoned counts as done) and
  the fight art, sounds and moves (`Util/CombatAssets`). Owner 2026-11-09 ("make sure all effects/models etc are
  loaded before any fight starts. same with in town. make sure models and weapon effects are ready"; a Studio check of
  every asset's fetch status as the screen closed found these missing): it also waits for your own cards' and the town
  animals' models (`TownCreaturesReady`, `Util/ModelPreload` `soon`), the shop props' and place props' models
  (`PropModels`, `PlaceProps`), the pack opening's effects, the portals' textures and every weapon's portrait
  (`Util/TownPreload`), the town round you (owner 2026-11-09: "in town. some models still load some time after the
  loading screen": Roblox fetches a mesh only once it's drawn up close, so scenery popped in as you walked; the area round
  your character streamed in, then `LoadingScreen.TOWN_FOLDERS`' meshes and textures fetched; anything streaming in
  later is fetched as it arrives, `LoadingController.warmStreamed`), the defeat music and the Frontier and Dungeon boss
  drone (`Util/CombatPreload`), and in the
  Frontier and the Dungeon the monsters' and bosses' models; as a fight starts every fight picture is checked again
  (`CombatAssets.ensureFight`). Measured in Studio: the screen closes about 10 s in; a save still loading after 6 s gets a note ("Your save is
  still closing on another server, almost there!"); after 30 s it fades anyway. Tips cycle at the bottom. The same
  screen is handed to `TeleportService:SetTeleportGui`, so teleports show it and the next place carries it on. The
  first-visit welcome cinematic starts when it fades. The shop step preloads the menus' product pictures
  (`Config/ProductPictures`, uploaded images since round 5) with the other images.
- **The Wild's loading screen** (owner 2026-11-05: "when entering wilds can we do a loading screen that make sure
  everything is loaded before player can walk in", look A "Portal swirl"; `Config/WildLoading`,
  `Controllers/WildLoadingController`): the moment a trip to the Wild starts (the portal, `/wild`, a boss gate's Take
  me) WildService fires `WildTravel` "loading" and the screen covers everything: two copies of a white spiral
  (`tools/textures/make_portal_swirl.py`, `assets/ui/fx-portal`) turning against each other in the portal's greens
  over the First Spark cover's hills, "The Wild", a green bar, the step and a tip. After the move ("wild") your root is
  anchored on your device until the ground under you, the valley's scenery (its meshes and textures), the monsters'
  models and the arrival area's music and ambience, and every boss arena's battle music and ambience (owner
  2026-11-09, `WildLoadingRules.sounds`) are in ("Opening the portal...", "Growing the valley...", "Waking
  the monsters...", "Tuning the sounds..."; `Util/WildLoadingRules`, Lune-tested), then it fades and you walk. It
  stays up at least 1.2 s, never holds you more than 12 s after arriving or 30 s before; "stay" (the trip didn't
  happen) or "home" closes it. Its pictures are kept drawn from the start, so the first trip's swirl is there at once.
Specs: `docs/superpowers/specs/2026-10-23-ui-restyle-design.md`, then look E in
`docs/superpowers/specs/2026-10-29-collection-screens-ui-design.md`.
- **Style** (`Util/UIKit` with the tokens in `Config/UIStyle`): windows and their buttons wear the **cotton candy**
  look (owner 2026-11-03, look A of three; spec `docs/superpowers/specs/2026-11-03-cotton-candy-ui-design.md`; before
  it the cream & candy look, `2026-11-03-cream-windows-design.md`, and before that look E "bold hybrid"). Six baby
  colours that pop (`Config/BabyColors`: bubblegum pink, mint, sky, lilac, butter, peach, plus grey-lilac and white),
  each with a light and a deep shade (`UIStyle.BABY`); plum ink. `UIKit.panel(parent, name, title, band, theme?,
  softButtons?)` builds a themed window by default (the code still calls the theme "cream"; `Config/CreamTheme`): a
  milky pink-lavender body with a thick white outline, round corners and a soft lilac glow under it, a header band in
  the baby colour of the window's HUD button (Bag pink, Cards and the card windows sky, Bosses and Party lilac, Shop
  and Shelf mint, Prices and Set Price peach, Jobs sky, every other window sky), and a round pink close button with a
  white outline. Inside: white rows, slots and stat cards with a soft lilac edge; empty slots and detail panes a pale
  lilac (no big white slabs); plum text, a lighter plum for secondary text, a dark amber for hints and small headings,
  and deep green, red, orange and mustard for good, bad, Power and fair prices (`tests/ContrastRules` checks every
  text colour reaches 4.5:1 on every window surface); the chosen thing a gold ring. **Soft buttons** (`UIKit.button`
  wherever `UIKit.isSoft` says: inside a themed window, or under `SoftButtons`, which the binder's screen sets): a flat
  baby colour, a 3 px white outline, round corners, a soft glow of the same colour you can see (one script-made picture,
  `assets/ui/soft/Glow.png` from `tools/ui-art/make_soft_glow.py`, 9-sliced and tinted by `UIKit.glow`), no gloss and
  no dark lip; white labels outlined in the colour's deep shade, plum text on butter and white (`Util/SoftColors`,
  `tests/SoftColors`: every deep shade reads white at 3:1). The kit's named colours map to baby colours automatically
  (`BabyColors.ROLES`, `UIKit.softFill`): the main action butter, other choices sky, remove or leave pink, summoned or
  confirm mint, can't-use-now grey-lilac, neutral sky (never white; owner 2026-11-03: no white glossy buttons), also
  when a controller sets one later. No grey hover anywhere in the soft look (Roblox's `AutoButtonColor` stays off, on
  every button and row in a themed window too). **Hover** (round 5, owner pick A "Soft glow", spec
  2026-11-04-round5-design section 1; `UIKit` `noGreyHover`, `Util/HoverRules`, `Config/BabyColors.HOVER`): nothing changes
  size, so nothing in a list or row moves and no text jumps a size (the old grow made the Condenser text pop and pushed
  the Boss Ladder's bosses). A soft button's own glow brightens and spreads 4 px, a white sheen (15 %) lifts its
  colour and its white outline turns to its own deep shade; a row, tile or slot gets a lilac edge (a lilac copy of the
  soft glow round it, never over its gold ring) and a lavender tint (owner 2026-11-04: the first, fainter values were
  "unnoticeable" on white rows and pale slots; `tests/HoverRules` pins them visible); 0.15 s in, 0.12 s out, no overshoot. Invisible click areas and greyed-out buttons don't
  light up, and neither does a button that lays out its own children (its list or grid layout would stack the hover's
  pieces in with them: build such content in an inner frame). The pieces are the hover's own children (HoverSheen, HoverEdge, HoverTint), so a controller recolouring a
  button mid-hover is never undone. A press is a small quick squish (0.96) and straight back. The Shop's price buttons are mint (can buy), pink (short)
  or grey-lilac (locked); tab names are plum on the open tab's butter and white on the others' sky (`UIKit.softText`). Pills and chips keep their colours with white
  outlines; rarity filter chips wear their rarity as the ring. Windows built their own way (the Bag, the card detail,
  small confirm boxes, the arena challenge popups) call `UIKit.creamWindow(frame)`. The window's `Theme` attribute
  tells the pieces built inside which look to take: `UIKit.themeOf(instance)` and `UIKit.colorsFor(instance)` (a
  palette: panel, row, rowEdge, slotEmpty, ink, inkSoft, hint, good, bad, power, fair, track, outline); `Colors.Text` /
  `Subtext` labels and `UIKit.outline` pick by it. **Dark** (theme "dark", the look E tokens: slate bodies with a thick
  near-black outline and a drop lip, slate rows, outlined white text, candy buttons with a dark bottom lip): the
  binder's book and chrome (its buttons are soft: the close, magnifier, page arrows, Rarity guide and
  the filters panel's buttons; the open tab and chosen filters butter, the rest sky), every fight screen, tooltips,
  the pack opening, the loading screen, the welcome cinematic, the Dungeon's run HUD and the placement bar. Helpers:
  `outlined` (text outline), `pill` (rarity, grade, element and count chips), `bar` and `statRow` (chunky green bars on
  pale or dark tracks), `stars` (star icons, never the character), `textSize` (body 15, small 13, name 22, number 23,
  title 28; 85% on phones). Colour
  rules on every screen: rarity from `Config/Rarities`, elements from `Cards.ELEMENTS` with their icons, grades S gold / A blue / B
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
- **Font** (`Util/FontStyle`, `Config/UIFonts`): FredokaOne for titles, buttons and numbers everywhere (screens,
  card faces, tags), Montserrat Bold for body text (owner 2026-11-03, pick 4 of 4 font pairs: cute round titles, a crisp
  premium body; it was Nunito Bold). Code still names Gotham; FontStyle switches each
  text object as it appears (Fredoka was tried: it only draws in Studio Edit mode, not in Play).
- **Motion** (`Util/Motion`, `Config/UIMotion`): panels pop in (0.85 to full size, slight overshoot) and the close
  button shrinks them away; buttons squash while held (soft buttons dip to 0.96 and come straight back, no bounce);
  number pills bump when they change.
- **Creature pals HUD** (owner 2026-11-03, pick C of three mockups; spec
  `docs/superpowers/specs/2026-11-03-hud-creature-pals-design.md`): the always-on HUD grows out of the core loop.
  **Tiles** (owner 2026-11-03, cotton candy tile pick 1 "squircle, the icon pops out"; `Config/SoftHud`): one clean
  rounded square per tile in its baby colour (a gradient from the light shade to the full colour), a thick white
  outline, a soft glow of its own colour, the icon big and over the top edge with a faded shadow under it, the label
  white outlined in the deep shade and the key letter in a white circle: Manage butter (deeper while its tray is open),
  Cards sky, Bag pink, Bosses lilac, Admin grey-lilac, Rip and Drop peach; the Manage tray's tiles mint, peach, sky and
  lilac by their order. The left column leaves room for each icon over its tile (`HudLayout.SIDE_GAP`). The party bar
  is a cream cushion with round portraits, each in a thick rim in its creature's element colour (Ember peach, Tide
  sky, Bloom mint, Volt butter, Shade lilac; avatar pick b) with its deep shade showing under it, a thin white ring, the
  picture sunk in and a shine on top, the slot number outlined in the element colour, the summoned one bigger and
  higher (`Party.BAR` RIM, RIM_BASE, SINK, SHINE);
  cash a green pill under a big gold coin; the level a white pill with the gold star, the XP into the level big and
  exact ("99,800 XP", "MAX" at the top) with the level's total small after it ("/ 226,000") and a thin lilac-to-sky
  bar under them, the number counting up when it changes (owner 2026-11-03, round 3 pick B; `Util/XpPill`,
  `HudLayout.XP_PILL`); the buff a white chip in the perk's colour. **XP sparks** (owner 2026-11-03: into the party
  portraits, where a monster win's XP goes; `Util/SparkPath`, `Party.BAR.SPARKS`): after a won wild fight, glowing
  lilac sparks fly on a curve from where the monster stood into each portrait whose creature got XP, then "+N XP"
  pops over it and its level chip bumps (a level up celebrates, and the chip keeps the old level while the sparks fly, then counts up to the new one in 0.4 s: round 4, `BAR.SPARKS.levelRoll`, the server sends each card's `fromLevel`); skipped while a window covers the HUD. **Hover** (`SoftHud.SQUISH`, `Util/SquishRules`):
  under a mouse a tile gently squashes, stretches a little as it hops up 5 px, rebounds and settles 3% bigger and 4 px
  higher, about 0.45 s (owner 2026-11-03: a subtler bounce; tiles 20 px apart); a press squashes it flat (touch too) and springs back; any newer hover, leave, press or a
  release anywhere cancels what's running, and the hovered tile draws over its neighbours (`tests/SquishRules` checks a
  tile at its widest, key chip and all, stays inside the gap); the Party pill squishes on a press and hops a little under
  a mouse. Anything stacked over the tile row (the status corner on a narrow PC screen, the toast) sits above its
  popped-out icons at their highest hover (`SquishRules.rowTop`). **The mascot** (`Config/HudMascot`, `Util/HudMascotView`, `Util/HudMascotRules`):
  Cindercub, a Figma-generated sticker (`assets/ui/mascot`, cut out by `tools/ui-art/cutout.py`), peeks over the
  cushion's left end with its paws on the edge and its flame tail poking up behind it; it breathes and its tail sways
  (looping tweens), it blinks every 3-7 s (lids drawn over its eyes), it ducks behind the cushion when you summon,
  unsummon or swap and pops back up (carrying on from where it is if you swap again), and a tap makes it bounce and
  chirp. It sits over the left end because on touch screens the level pill sits above the right end. Everything about
  it is in its config so another creature can replace it (the owner plans one based on their own pet): see
  `docs/hud-mascot.md`.
- **HUD** (`Util/Hud`, `Config/HudLayout`): a **Manage** tile on the left middle slides out a tray of tiles to
  its right (Shop, Prices, Jobs, Party), popping in one by one, and turns into Close; tiles at the bottom centre (Cards B, Bag I, Bosses K) with key
  chips; orange context tiles join that row while usable (Drop G while carrying, Rip T while carrying packs).
  Bottom right, one corner cluster (above the jump button on touch screens; on a narrow screen where the party bar
  would reach over the bottom-centre tiles, it lifts above the tile row too): the party bar, and beside it a
  right-aligned column, bottom up: level (number on a star icon, the XP and a thin bar inside the pill, in line
  with the party bar), cash (a green pill with a gold coin and outlined white text), then the buff badge; the toasts pop
  in just above. Star Shards have no pill (they show in the Bag and where they're spent). On touch screens (short
  landscape phones, the jump button in the bottom right) it is one column down the right edge from the top right to
  the middle: buff, cash, level, then the party bar, then the toasts. Nothing sits in the middle of
  the screen. The whole HUD (tiles, Manage
  tray, corner, toasts) shrinks with the screen's height (`HudLayout.SCALE`, `Hud.scaleWith`): full size from 560 px
  tall, down to 70% on short phones (tiles stay over 48 px to tap). Each icon sits over its
  pill's left end. **Icons** (`Config/UIIcons`, `Util/Icon`): glossy cartoon pictures for the
  HUD tiles (Close included), the top bar, the Shop's header and tabs, Bag items and customer mood bubbles
  (Angry, Thinking, Happy); made as four sheets with Figma's image generator and cut by
  `tools/ui-icons/slice_icons.py <sheet> <1-4>` (PNGs in `assets/ui/icons`). Sheet 4 (the style kit) adds Power, Hp,
  Atk, Spd, Xp, Copies, Summon, Remove, Job, KeyFragment (pale, tinted per boss in code), XpTonic, GradingSeal,
  GoldSeal, Travel, Best and Pvp; sheet 7 (weapons round 1) the boss materials and Wild Ore (WardenHeartwood ...
  WildOre) and spare Forge icons (Anvil, Hammer, Upgrade, Reforge, Spear, Scythe, Elements, Awakened); Bag items use icon names (`Config/Items` `icon`), not emoji. Every icon is kept drawn, tiny and nearly invisible,
  from the moment you join (Roblox only finishes loading an image once it's drawn), so hidden tiles open with
  their icons ready. Names without a picture show as text (⌛ in a bubble). **Toasts** (owner's pick A, 2026-11-06;
  `Config/Toasts`, `Util/ToastRules`, `UIController.Notify(message, isError, duration, icon)` and `NotifySide` for
  money): Cindercub's speech bubbles stacked right over the cash pill (over the buff badge while one shows; under the
  column on touch screens), newest nearest the coin, messages and sales alike, at most 3 (2 on phones; a new one
  pushes the oldest out). A white bubble with the windows' soft lilac edge, a soft plum shadow and a tail pointing at
  the cash (up on phones), an icon chip in its kind's colour (mint money with the coin, butter news with Info, pink
  errors with Close; a message's own leading emoji moves into the chip) and the words in its kind's ink (plum, green,
  dark red), then a small "x" in a lilac circle. It pops up from small with an overshoot and a squash before it
  settles, stays 6 s (errors 8 s; a toast that sets its own time gets it doubled: a loot pickup 3 s, the level-up
  10 s; owner 2026-11-06 "last longer, with a close button") and leaves shrinking and fading; a click or tap anywhere
  on it closes it at once (the "x" darkens under the pointer). The same message again bumps the newest bubble instead
  of stacking a copy. The HUD's Cindercub hops (silent, `HudMascotView.hop`) once per burst. Toasts
  stay up over the binder and the pack opening (the corner hides, they don't). The fight screen hides the HUD groups.
- **One window at a time** (`UIKit.panel`): opening a main window (Shop, Prices, Jobs, Party, the binder...)
  closes any other; windows marked `Overlay` (the Rarity guide, a case's card picker) open on top without
  closing anything. While the Rarity guide is open, Q/E and swipes don't turn binder pages.
- **Prices** (owner 2026-11-03, round 3 pick A "slim rows"; `Pricing.ROWS`): one slim white row per product with its
  picture (packs their real front, others their icon), its name, "Market $x" and a small tag in the price band's
  colour, its short form (the bands' `tag`, 10 characters at most so it never runs under the stepper: "Always buy",
  "Sometimes", "Rarely buy", "Won't buy"; `tests/PricingConfig`), and on the right one pale stepper pill: a round pink - and butter + (drawn 30 px
  inside 48 px tap areas) either side of your price. A shelf's Set Price window uses the same row.
- **Order Stock** (owner 2026-11-04, round 4 pick A; spec `2026-11-04-round4-design` section 4): the same slim white rows
  as Prices (`Pricing.ROWS`): picture, name, "Box of 24" and a mint "sells ~$3.00" tag, and one mint button with the
  box price (tap it to order). It greys out with "Need $48" when you can't afford the box and shows the lock and
  "Lv 11" while locked (`Util/OrderRules`, Lune-tested); the server re-checks both.
- **Stages right above the player** (`Config/Stages`, `Util/StageRules`, client `Util/StageSpot`): the binder, the card
  view and the pack opening each show on a client-only stage. Roblox works the world's light out round the camera, and
  a stage thousands of studs up made it drop the shop's: after closing, the room showed lit like the open air for
  about 20 s (owner 2026-11-06). So while shown each stage sits straight above the player, at the first of 120 / 160 /
  200 studs whose box (`STAGE_BOX` in its config) holds no part, terrain or other stage, and only falls back to its far
  `STAGE_POSITION` when all are blocked; on closing it goes back there, out of sight. Measured: 150 and 220 studs up
  for 12-15 s kept the shop's light, 400 lost it. The card view opened from the binder lands 200 up, clear of the desk.
- **Binder** (`Config/Collection`, `Config/BinderDesk`, `Util/BinderSpreads`, `Util/BinderDesk`, `Util/BinderFit`;
  spec `2026-10-29-3d-binder-design.md`, "Collector's Desk"): a real 3D ring binder lying open on a wooden desk on a
  client-only stage, seen by a Scriptable camera from a little in
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
  is the cover (owner 2026-11-04, spec `2026-11-04-round4-design` section 1): a painting of the set's place with no
  creature on it, so new players discover them in packs (`Config/BinderCovers`, sources in `assets/ui/covers/`; First
  Spark the spark and the five element orbs over a hilltop, Frontier a frosty ridge under a purple rift), dark fades
  top and bottom, a thin white frame, the set's name as a chunky candy logo (a shadow copy, a thick white outline copy
  and a three-colour gradient fill; every line the same height), a white star pill "35 / 35" under it and "Worth
  $105,607" in a white pill at the bottom; then page 1. The pocket under the pointer lifts to 1.05 in 0.14 s with a
  small overshoot and settles in 0.1 s (`BinderDesk.HOVER`, one tween per pocket), with no border.
  The page counter pill ("2-3 / 9") sits just under the binder, arrows with Q/E key chips either side of it on wide
  screens; phones (under 900 px wide) get compact corner buttons in slim lanes (Rarity guide bottom left, Filters
  under the close button), no arrows and no progress card. Top right: Filters (F) and close. The **Filters window**
  (owner 2026-11-03, round 3 pick A "tidy column"; `Collection.FILTERS`, plain data in `Config/FiltersLayout`) opens
  on the right while the camera moves the binder into the room left of it: a cotton candy window with a pink band,
  the search box, SHOW (All / Owned / Missing) and SORT BY (Set / Value / Copies / Rarity) as two segmented switches
  (`UIKit.segmented`), the rarities as small dot tags that fill with their colour when picked (`UIKit.dotTag`; both
  drawn smaller inside 48 px tap areas, `BabyColors.SEGMENTED` / `DOT_TAG` `hit`), and at the bottom how many of the
  open set's cards match ("32 of 35 cards") and Clear all. It is as tall as its content (`UiLayout.filtersBody`):
  under the close and Filters buttons where it fits above the progress card, else from near the top over them (its
  own close in their corner), the body scrolling on a landscape phone (`UiLayout.filtersFrame`). Bottom right: the set's progress card (owned / total with a bar, value
  of your copies). **The Bag** (round 3) is its own window over the town, opened by the Bag tile or I (one window at a
  time: it closes the binder); the binder has no Cards / Bag tabs. The side and bottom
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
  beside the hovered card (round 5, owner 2026-11-04: right of its pocket, else left, else above or under it;
  `UiLayout.beside` anchored on the pocket's screen rect), so it never covers that card; it may cover its neighbours.
- **Rarity guide** (`RarityGuideController`, `Util/OddsRules`), from the binder's bottom-left button: each rarity
  with a sample card (no spoilers: a card of that rarity you've collected, else the binder's "?" card; redrawn on
  every open; binder tooltips stay off while it's open), its chance per card pulled from a First Spark pack (from `Config/Packs`: Common 74%, Rare
  19.6%, Very Rare 3%, Epic 2.8%, Legendary 0.6%) and "about 1 in N cards"; Frontier cards (drop chances from
  `Config/Frontier`); foil chance and value; grade chances and their stat bonus.
- **Card view** (`CardDetailController` with `CardInspectorController`, `Config/Inspector`): tapping a binder card
  shows it as a real 3D card (about 60% of the screen's height) close in front of the camera (front: the card face;
  back: the card back). While it's up the camera waits at an empty spot right above the player (`Util/StageSpot`;
  `Inspector.STAGE_POSITION` far above the world when none is clear) with a solid dark sheet behind the card, so
  nothing of the world (customers, your pet)
  shows; always-on-top tags switch off too. Drag to tilt (it eases back), drag far sideways or press Flip (under the
  card) to turn it over; Legendaries keep their element aura; a gold "BEST COPY" ribbon sits on the card while your
  best copy is shown. The card and the info panel are centred on the screen as a pair (`UiLayout.detailPanelLeft`;
  on narrow screens the panel keeps its right margin first), the card's right edge just left of the panel
  (`UiLayout.inspectorCard`, both Lune-tested).
  The panel (style kit, blue band): the name and worth range (green, Cash icon) in the band; rarity, element, number
  and copies pills; then a blue **Skills** box (the owner 2026-11-05, option A of `skills-on-card.html`): the card's
  Pet move (its element's) and, for Epic and Legendary cards, its super move, each with its icon on a badge, its name,
  a line from the fight's numbers (`Util/SkillText`, Lune-tested) and the button that uses it (icons from
  `Config/MoveFx` SKILL_ICONS: a Figma sheet of white glyphs, icon sheet 6, the owner's pick over script-drawn ones);
  the fight's Pet and Super buttons show the summoned creature's own move icon the same way; a green **Buffs** box
  (this copy's town perk while it's out with you and its fight perk, PartyRules); a red **Elements** box (who it
  deals 1.5x to and takes 0.75x from, and the reverse, `SkillText.matchups`); everything under the band scrolls as one
  column (the owner 2026-11-05: "I cant scroll down to other copies ... add all the details", option A), the buttons
  pinned below; then **"This copy" first** (round 5, owner pick A of the `round5.html` mockups): a gold box with
  "THIS COPY", the chosen copy's grade pill, level, star icons, FOIL and its worth on one line, its Power / HP / ATK /
  SPD tiles, an XP bar to the next level and a next-star bar (duplicates you have / need, red when short; "Max stars"),
  and "In your party" or "Working: <job>"; under it "ALL COPIES, BEST FIRST" (every copy: grade pill, level, star
  icons, FOIL or count, Power with its icon, value; the first wears a gold BEST ribbon, the chosen one a gold outline,
  with room in the list so it isn't cut off), filling the rest and scrolling; buttons with icons: Add to party (gold),
  Assign job (blue; opens the Assign job picker; when it can't, it
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
- Creature models download in the background from the start (`CreatureVisuals.preload`, `Util/ModelPreload`): only the
  models the game uses (each card's model, the town animals'), the player's own cards first (it waits up to
  `Party.PRELOAD_PARTY_WAIT` seconds for them), then the town animals (owner 2026-11-09: they walk round town from the
  start; the loading screen waits for both), then the other cards, `Party.PRELOAD_BATCH` per
  download call; each is drawn in a hidden viewport once downloaded so its textures finish. Measured 2026-10-31: the
  bought packs also hold 45 unused models with 619 of the 668 meshes, all preloaded before, so a new player's own cards
  waited behind them (about 196 queued requests for 6 s even from Studio's cache); now the 49 used models are drawn
  about 8 s into the game. The unused packs were then taken out of the synced folder (`assets/creature-packs-unused`:
  UltraPets, CrystalTitans and the full Cute Pets file; the synced Cute Pets keeps the 8 town animals), so they no longer
  replicate at join (2.1 MB of models down to 1.4 MB); a Lune test fails if a synced creature model is unused.
- Monster and boss models download in the background too, `Party.MONSTER_PRELOAD_WAIT` (5) seconds after start
  (MonsterController, `MonsterLooks.preloadOrder`: the place's bosses in ladder order, then its species), drawn in the
  same hidden viewport (`CreatureVisuals.preloadTemplates`). Measured 2026-11-02: before, a boss's model downloaded only
  when its fight began; the Colossus's mesh took 7.8 s in Studio and its textures came after it, so its intro showed an
  empty ring. Now all three Wild bosses and the six monsters are in about 12 s after joining and a boss shows the moment
  its fight starts; the street's render CPU with the viewport's 59 models is within noise of it hidden.
- Card paintings come in two sizes (`Config/CardArt`, `Util/CardArt`): the full 680 x 1014 painting for big views and a
  half-size copy (340 x 507, `assets/ui/card-art-small`) wherever a face is drawn no taller than that (binder pages,
  shelves, cases, the party bar); each face picks by its drawn height. The small copies preload first at start, then the
  full ones. Measured 2026-10-31: the full paintings took about 113 MB of the client's ~150-220 MB of textures and 6 MB
  to download (small: 1.7 MB); drawn small they were evicted under memory pressure and reloaded, leaving binder faces
  blank after a page turn. After flipping every binder page, textures 220 MB before, 183 MB after.
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
  (at most 4 streams, 4 falls effects), at most 4 effects per area, at most 20 butterflies, 10 animals (3 in town, 2 in the plaza,
  one at Forest Falls and Frostpeak, 2 in Ember Canyon) moved only within 120 studs, tree sway within 150 studs at 30 Hz, the frozen falls at most 60 parts; small
  hand-placed decor (under 4 studs) casts no shadow; sign and arch words stop drawing beyond 120 studs. The 60k triangle
  town total no longer covers the areas: the scenery reuses the town's prop meshes (scaled copies batch together) plus
  code-built parts, so no new mesh triangles were added.
- Ember Canyon caldera (measured 2026-10-31, same stress setup; its new pieces taken away and put back in turn at each
  camera): 60 fps everywhere at levels 1 and 10; the street, the street looking west at the volcano and the caldera
  itself within noise (level 1: 8.9 / 8.9 ms in the caldera, 11.8 / 11.7 on the street). About 220 small Neon crack parts
  (no shadows, no collisions), 8 trees (1,282 triangles each), 6 shard clusters (228), the volcano (448); the plume is
  one beam. The canyon keeps 4 area effects (embers, bubbles, river flow, the plume).
- Town portals remodel (measured 2026-10-31 in a fresh Studio session: copies of Plot1's stocked shelves in the other 5
  plots, 5 avatar clones; render CPU from fixed cameras, the portals taken away and put back in turn at each view):
  60 fps everywhere at levels 1 and 10; the street 9.2-9.5 ms with or without them (no change); standing at a portal
  +0.1 to +0.2 ms (Forest Falls 7.4 → 7.6, Ember Canyon 7.3 → 7.4, Frostpeak within noise at level 10). The plaza
  measured +1.1 ms at level 1 the day before, 60 fps held. Caps: at most 4,000 triangles per portal model, at most 4
  effects and a light per portal (Lune-tested), the vortex spins only within 150 studs with the extras on, the models
  stream Atomic. Comparing "on" then "off" in one pass over-read the cost (+1.6 ms on the street, where no portal is
  in view): alternate off/on/off/on at the same camera.
- Wild valley (measured 2026-10-31 in Play from fixed cameras in the meadow at the arrival, the gorge facing the cave
  and the ridge facing its arena; the valley's dressing, ridge cracks, cave wall and arena cracks and tips taken away
  and put back in turn): 60 fps everywhere at levels 1 and 10, the pieces within noise (render CPU, second off/on pair:
  meadow 8.0 / 7.8 ms level 1, 8.7 / 8.9 level 10; gorge 7.8 / 6.9, 7.1 / 7.2; ridge 8.2 / 7.1, 7.4 / 7.6). Terrain
  memory 43 MB graphics and 3.9 MB voxels in the valley, 51 / 4.1 on the town street (50 / 3 before the caldera and the
  valley). The valley's terrain is about 37.7k estimated cells (cap `WildValley.MAX_CELLS` 40k; town plus valley within
  `Scenery.MAX_CELLS` 180k, Lune-tested). The dressing folder holds about 250 instances (props reuse the town's meshes and the caldera's
  models), 53 ridge and 43 arena crack strips and 22 post tips (Neon, no shadows or collisions), at most 4 area effects
  per zone (meadow 2, gorge 1, ridge 3).
- Wild valley round 2 (measured 2026-10-31 in Play from fixed cameras at the arrival, the gorge from its entrance, the
  ridge from its pass, a crowded meadow (24 monsters, `/crowd 11`), the meadow's boss portal and a gorge arena copy, plus
  the town street): 60 fps everywhere at levels 1 and 10; render CPU 7.6 / 8.5 ms at the arrival (level 1 / 10), gorge
  7.0 / 7.5, ridge 7.1 / 7.8, crowded meadow 7.1 / 7.9, boss portal 7.7 / 8.2, arena copy 6.8 / 7.1, street 8.4 / 9.5.
  Terrain memory 45-47 MB graphics in the valley (43 in round 1), 38 in an arena copy, 51 on the street; voxels 5.4-6.0
  MB (4.1 before). The valley's terrain with its 12 arena clearings is about 86.5k estimated cells (cap
  `WildValley.MAX_CELLS` 90k); town plus valley about 225.5k, so `Scenery.MAX_CELLS` rose from 180k to 230k.
- Valley round 2, natural edges (measured 2026-11-05 in Play, the same cameras; round 2's 67 placed models (backdrop,
  mountains, giant trees, the volcano's lava) and the clouds shown and hidden in turn, three pairs, one session):
  meadow +0.02 ms render CPU at level 1 / +0.49 at level 10, gorge +0.14 / +0.10, ridge +0.16 / +0.12, 60 fps. The
  skylines are terrain (not toggled): estimated cells 92.5k to 100.5k after trimming the walls' backs (101.5k with the Caves' grass patches), valley terrain
  graphics 48.0 to 46.3 MB and voxels 5.9 to 6.4 MB (`MAX_CELLS` 95k to 105k, `Scenery.MAX_CELLS` 235k to 245k). On the
  town street at level 10: clouds +0.6 ms, the always-loaded far mountains +0.5 ms (none at level 1); street memory by
  tag about +8 MB (instances 171 to 178, mesh parts 32 to 33, terrain 52 / 6). Streaming: every backdrop model present
  from each area's far corner.
- Valley scenery round (measured 2026-11-05 in Play from fixed cameras over the meadow from the arrival, the gorge from
  its entrance and the ridge from its pass; 148 new pieces: 27 mushrooms, 30 tufts, 10 moss rocks, the stone circle,
  13 ruins, 16 toadstools, 12 ember trees, 10 crystal clusters, the skeleton): the pieces in place and hidden in turn in
  one session cost within noise (render CPU on / off, two pairs: meadow 7.0, 6.6 / 6.9, 6.3 ms level 1, 7.4, 7.2 / 6.9,
  8.2 level 10; gorge 6.4, 6.1 / 6.6, 6.1 and 6.9, 7.8 / 6.6, 7.0; ridge 6.2, 6.2 / 6.7, 6.3 and 7.2, 6.5 / 6.6, 6.3),
  60 fps throughout; separate sessions drift by 1-3 ms, so compare on/off in one. Town memory by tag grew about 18 MB
  (instances 159 to 171, mesh parts 32 to 33, textures 244 to 248). New models 212-1904 triangles each.
- Wild monster models (measured 2026-11-01 in Play from fixed cameras at round 2's views): with the golems' lava
  pulsing, 60 fps at the arrival, gorge and ridge (render CPU 8.9 / 9.8, 9.0 / 9.5 and 8.7 / 9.0 ms at levels 1 / 10)
  but 57 fps in the crowded meadow (12.8 / 13.8 ms, 73 monsters across the valley with `/crowd 11`). Taking the models
  away saved 6.7 ms, as much with the camera on the sky; static or moving clones cost nothing. The cost was the pulse:
  changing a SurfaceAppearance's EmissiveStrength (or EmissiveTint) every frame costs about 6 ms of render CPU whether
  one golem pulses or twelve (one near the camera 6.6 ms, 12 off screen 5.5 ms; written 10 or 5 times a second still
  4.3 / 2 ms on average, in spikes). Pulsing only within `Wild.FX_RANGE` still cost 6.5 ms on the crowded ridge with
  golems in view, so the glow is steady. With it: 60 fps everywhere at levels 1 and 10; render CPU arrival 6.5 / 7.4,
  gorge 6.4 / 7.0, ridge 6.4 / 6.5, crowded meadow 6.7 / 7.3 (72 monsters), crowded ridge with 4 golems in view
  7.4 / 7.9.
- Wild bosses and their arenas (measured 2026-11-02 in Play from fixed cameras, each arena copy with its boss fight
  running): 60 fps everywhere at levels 1 and 10; render CPU the Warden's grove 7.1 / 7.1 ms, the Broodmother's hollow
  6.6 / 7.2, the Behemoth's lava field 7.0 / 7.6 (a bare arena copy was 6.8 / 7.1), the valley's arrival 7.4 / 8.4, the
  town street 8.4 / 9.3. Terrain on the street unchanged (voxels 5.5 MB, graphics 51 MB): walls, the cave's roof, the
  backdrop and the ground part past each clearing are meshes and parts, not terrain. After the user's round (the hollow
  and the lava field widened to clearings 164 wide with walls 74 out, the lava field brightened, the Colossus's glow at 4
  plus a warm light): the hollow 6.7 / 6.6 ms, the lava field 7.5 / 8.1, the street 9.1 / 10.5, 60 fps everywhere;
  terrain memory unchanged (street voxels 5.3 MB, graphics 51 MB; an arena copy 3.8-4.5 / 38-39). The valley's terrain
  is about 92.3k estimated cells, so `WildValley.MAX_CELLS` rose from 90k to 95k and `Scenery.MAX_CELLS` from 230k to
  235k (town plus valley about 231.3k). Boss glows hold one strength
  (2, 2.5 for the Colossus); their moments are particles.

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
- Should customers sometimes ask for specific singles ("got any Voidmaw?") as a quest-like hook? (Collectors now do,
  4.5.)
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
- [x] Town portals remodel (spec `2026-10-30-town-portals-design.md`, plan `2026-10-30-town-portals.md`, branch
  `town-portals`): the three portals grown from their worlds (the user's pick A): a root arch at Forest Falls, an ice
  crystal ring at Frostpeak, an obsidian arch with lava at Ember Canyon, Blender-built and sunk onto their ground; a
  swirl covering each opening (a glowing core, the swirl and a counter-turning inner swirl, turned flat in place after
  two rounds of the user's feedback on the animation); water, mist, lava and embers; the old frame stands in until a
  model is saved; Ember Canyon's stone platform removed, its torches moved out; names drawn from 80 studs. Measured: no
  change on the street, +0.1 to +0.2 ms at a portal. Also the capybara moved onto the sidewalk outside the south shops.
  Approved by the user and merged 2026-10-31. Deferred minors from its review: PortalBuild's spot check doesn't test
  IsA("BasePart"); `Town.PORTAL_SCENERY_CLEAR`'s comment doesn't match its value; the stream beams' taper, texture length
  and segments are literals; `rgb` duplicates `Props.color` and the TownPortal tag string lives in two files; the
  capybara can step off the kerb; DESIGN 10.5 doesn't record the town's triangle total with the portals.
- [x] Ember Canyon caldera (spec `2026-10-31-ember-caldera-design.md`, plan `2026-10-31-ember-caldera.md`, branch
  `ember-caldera`): the desert canyon turned into a calm volcanic caldera in the portal's colours (the user's pick A):
  basalt cliffs and cracked ground with about 220 glowing cracks, charred trees and obsidian shards (players can't walk
  through them), hotter lava, dark torches, a quiet 120-stud volcano behind the end wall with its lava streaks facing the
  town and a beam smoke plume, two baby dragons (Shadow and Golden). Measured: within noise at 60 fps. Approved by the
  user and merged 2026-10-31. Deferred minors from its review: the plume still rises if the volcano model is missing; a
  wall crack's ray could hit a nearer surface if the seed or counts change (re-measure); the CRACKS MAX_SEGMENTS comment
  says strips but caps segments; floor crack tapers go under WIDTH's minimum; dead start values in buildCracks' onWall;
  doc drift (10.5 says 10 animals, there are 9; old "one per area" comments; the plume texture missing from CLAUDE.md's
  fx line); no generator committed for `volcano-plume.png`; test gaps (Arena trail by index, generated trail ops not in
  the colour test, the variant test checks only names); literals in SceneryService's crack and plume code; the volcano's
  shadow at low sun not checked.
- [x] Wild valley (specs `2026-10-31-wild-valley-design.md` and `2026-10-31-wild-valley-v2-design.md`, plans
  `2026-10-31-wild-valley.md` and `2026-10-31-wild-valley-v2.md`, branch `wild-valley`): the Wild's three flat squares
  turned into one winding valley (round 1: the moods, the root-arch return portal, the stream, cave and ridge; round 2,
  after the user judged round 1 in Studio: an S-shaped trail through three biomes at three heights with passes and
  hills, boss portals sending each fight to one of 4 arena copies, monsters growing with the players in a zone (8 to
  24), wooden trailhead signs and arrow posts). The plaza signpost moved into the planter by the spawn, and the town's
  animals show from the start of a visit. Measured: 60 fps everywhere; terrain cap raised to 230k cells. Approved by
  the user and merged 2026-11-01. Deferred minors from its reviews: respawns queued during a crowd still land after it
  leaves; Return says "Finish the fight first." during the boss's 4 s death scene; onGroup doesn't check `entering`,
  which is one boolean per player; the turned gorge and ridge floors stick out past the cliffs (seen zoomed out); no
  "opening the arena" notice while a copy streams in (up to 10 s); an elite refused at a pass wall can stand stranded;
  the return arch has no fallback if PortalWild is missing; some numbers left in WildService/SceneryService (wall
  thickness, gate clearance, crack lift, bridge/marker/cave light/vent sizes); copied numbers without a tie-in test
  (stream ops vs STREAM, BRIDGE.z vs the crossing, ventsmoke emitters vs VENTS); no test that WildValley's prop names
  exist in assets/props; EdgeWall's CanQuery false is moot while CanCollide is on; nits (PROPS comment mentions a zone
  field, PortalFxController's header says three portals, no bridge post at the far end).
- [x] Wild monster models (spec `2026-11-01-wild-monster-models-design.md`, plan `2026-11-01-wild-monster-models.md`,
  branch `wild-monsters`): the six wild monsters' placeholders replaced by rigged models in style B "wild-touched", each
  design picked by the user from concepts (Mossling boulder beast, Puddle Crab barnacle brute, Cave Bat gargoyle, Spark
  Beetle stag spark, Magma Golem cairn cyclops, Ash Wolf cinder mane), made with Meshy image to 3D and our rig scripts;
  heights by species, steady glow masks, sparks and smoke on effect bones, the wolf's roar and the golem's stomp. The
  meadow pair raised a stud and the terrain grass cut short (GrassLength 0.3); the golem's lava pulse dropped after
  measuring (any changing SurfaceAppearance strength cost about 6 ms of render CPU). Measured: 60 fps everywhere.
  Approved by the user and merged 2026-11-01. Deferred minors: the wolf's wildroar has no FIDGET_SECONDS entry (2 s
  default); PetRig.spec's source-text check is brittle; a Puddle Crab spawn spot at the pond's edge stood underwater.
- [x] Wild bosses and their arenas (spec `2026-11-01-wild-bosses-arenas-design.md`, plan
  `2026-11-01-wild-bosses-arenas.md`, branch `wild-bosses`): the Meadow Warden ("Elder Warden"), Cave Brood Queen
  ("Broodmother") and Ember Colossus ("Magma Behemoth") as rigged Meshy models picked by the user, size B (17 / 16 / 17
  tall), their moments (roars, the Brood Queen's heal flare, the Colossus's enrage vents, the Warden's root slam); each
  arena a place of its own (the grove, the hollow under its dome, the lava field with the volcano), its own sky, sound
  and way home, a ground part under each copy, invisible walls ringing it inside its walls; boss and monster models
  preloaded in the background. Tuned after the user's checks (the Brood Queen 12 -> 16 tall and her screech quieter,
  the hollow and the lava field widened, the lava field brightened, the Colossus lit). Measured: 60 fps everywhere;
  terrain caps 95k / 235k. Approved by the user and merged 2026-11-02. Deferred minors: a few arena numbers still in
  WildService (shadow cut-off, backdrop sink and yaw, sound anchor height); arena ambient sounds set no
  RollOffMinDistance; inner pieces and crystals can overlap (separate rngs); wildroar still has no FIDGET_SECONDS entry
  (the bosses' roars run 2.2-2.8 s); BossMoments.anchors returns the config's own bones table; the dome isn't
  double-sided (a camera past it sees inside); the lava field's ambient is the town's fire loop.
- [x] Fight polish and boss debuffs (on the way to the HUD branch): the bosses' ring debuffs (HUD chip and badge,
  effects on the character, server walk slows), special-move wind-ups, the boss plate, the meteor slam, summon effects,
  the unskippable defeat screen, varied fight sounds. Merged with the branch below on 2026-11-04.
- [x] HUD and windows makeover (branch `hud-creature-pals`; specs `2026-11-03-hud-creature-pals-design.md`,
  `2026-11-03-cream-windows-design.md`, `2026-11-03-cotton-candy-ui-design.md`, `2026-11-03-windows-round3-design.md`,
  `2026-11-04-round4-design.md`, `2026-11-04-round5-design.md`): the creature pals HUD (mascot, candy tiles, element-rim
  portraits, XP pill and sparks), cotton candy windows everywhere but the fights, round 3 (Filters column, Prices slim
  rows, the Bag window, Return to town, sword on the back), round 4 (shop levels 1-100 with rewards, the level-up light
  pillar, creature-free binder covers, Condenser two panes, Order Stock rows, summon sounds, the loading screen waiting
  for pictures) and round 5 (calm, visible hovers, the binder tooltip by its card, "This copy" first, Assign job, the
  Boss Ladder list and banner, sharp pack pictures, one soft level-up sound, town music 0.21). Approved by the owner
  and merged 2026-11-04. Deferred minors: the lilac edge is cut straight at the ends of scrolling lists and may tint a
  chosen row's gold ring; the Assign job picker isn't redrawn if the copy changes under it; picking a level sound set
  never previews its sting; "This copy" can crowd on small phones; a creature's level-up after a boss fight waits 4 s
  for sparks that don't come; other players' level-up sounds don't follow them; the toast's "+$1000" has no comma;
  "Stocking the shelves..." shows in the Frontier and Dungeon too; the phone layouts of the round 5 windows weren't
  checked in the emulator.
- [x] Sword moves round (spec `2026-11-04-sword-moves-design.md`, plan `2026-11-04-sword-moves.md`, branch
  `sword-moves`): four new moves (forehand, backhand, a two-handed finisher with a big jump, a slow-motion hang and a
  cool-down kneel, the dash slash), chained cuts, real lunges, walking held mid-swing, candy sparkle arcs, star bursts,
  rings, cut lines, dust, layered sword sounds, the DASH button; all four moves published. Approved by the owner
  2026-11-04. Deferred minors: the hit-sound window spans two chained cuts (a missed-then-landed cut can be silent);
  your own burst goes on the nearest foe even if it isn't the one in reach; a fight ending mid-lunge leaves the push to
  end by itself (0.23 s); a cut or dash slash a dodge cancelled on screen still lands on the server; the dash through a
  boss toward the arena wall wasn't checked in Studio.
- [x] Pet moves round (branch `pet-moves`, spec `2026-11-05-pet-moves-design.md`): Healing Rain (heals over time; a
  Grade S caster heals its player 15% too), Vine Snare, Overcharge and Curse finished, each better with grade; skill
  icons (a Figma glyph sheet) on the fight buttons and the card view; the card view as one scrolling column with
  Skills, Buffs and Elements boxes; the fight's party strip (look C: a running light and heartbeat on the fighter,
  fainted cards face down); every fight sound kept loaded (`Util/SoundBank`); the Wild's portal-swirl loading screen;
  the valley's passes as rolling banks. Approved by the owner 2026-11-05 ("merge and push"). Deferred minors: a
  withdrawn group member's creature keeps its regen and orbs for up to 5-8 s; Curse's hex flight and late vine leaves
  can start after an early stop; "+N" shows the full tick when the heal is capped at max HP; Overcharge has no extra
  sound layer at A; the Overcharge preview shows the plain hit; a Rain cloud skipped by the effects budget has no sound
  and a recast's cloud lingers ~3 s.
- [x] Valley scenery: round 1, the Meadow's ancient ruins, the Caves' glow mushroom hollow with its darker look, Ember
  Ridge's ember forest (spec `2026-11-04-valley-scenery-design.md`); round 2, natural edges, backdrops, far mountains,
  the composed Meadow, the Ridge's sky, lava streams, clouds, the Caves' grass patches, pieces settled onto the terrain
  (spec `2026-11-05-valley-natural-design.md`). Owner confirmed 2026-11-05.
- [x] Super moves round (spec `2026-11-05-super-moves-design.md`): every super winds up its own time (Epic 1.5 s,
  Legendary 2 s, Supernova 3.5 s) with a cinematic on the caster's screen while their player can't be hit, ten
  distinct looks with their own sounds, each bigger by grade with an S extra; then four rounds of owner feedback:
  leaps and slams, Tidal Shield on every ally, Eclipse's star sigil and mirror image, Tidal Blessing as Rebirth Spring,
  Rift Step as Blink Barrage, Thunderhorn's gallop, Shade's moon slash, limb attacks for every creature, skill sounds
  brought to one level, move tooltips, a cinematic camera that keeps the creature in view, and the super meter in
  place of the 15 s cooldown with the bosses rebalanced around it. Owner approved ("merge and push") 2026-11-06.
- [x] Wild music: a piece for each of the valley's three areas (the owner's solo guitar picks, very quiet, each with
  an ambient loop) and a battle piece in each Wild boss arena, crossfading as you move, each through a leveler
  (`Music.WILD`, `MusicController`); the town plays White Owl. Approved by the owner 2026-11-04.
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
  game (about shop level 20); clearing the Dungeon adds a special Legendary habitat there.
- [x] Customers with personalities (spec `2026-11-06-customers-design.md`, plan `2026-11-06-customers.md`): phase 1
  in the shop (types and looks, collectors, kid rips and offers, haggling with a counter, reactions, the shop rating on
  the sign and the HUD chip, economy check) and phase 2 town walkers, plus the owner's rounds (walkers on the whole
  street at a walk, stages right above the player, Roblox's walk clip and smooth paths, customers arriving from the
  street and walking off, stuck walkers retracing); approved and merged 2026-11-06.
- [x] Tired shop workers (owner's idea 2026-11-06, 5.8): 5 slower minutes after every 10-15 of work, a toast and a
  "Tired" pill, so the owner steps in at the register; worker name tags clear of flying creatures. Merged 2026-11-06.
  Not built: a snack in the Bag that ends a tired spell early.
- [x] Toasts as Cindercub's speech bubbles over the cash pill (owner's pick A of three mockups, 2026-11-06; 10.6
  HUD): one stack for messages and sales, 6 s (errors 8), a close "x" and tap-to-close. Merged 2026-11-06.
- [x] Weapons round 1 (5.11, spec `2026-11-06-weapons-round1-design.md`, branch `weapons-round1`): the Forge, the four
  new swords, drops with pity, the Armory, the aura glow (the owner's reference look, hybrid for performance), the
  material icons (sheet 7, owner's pick A). Approved by the owner in Studio 2026-11-06.
  Follow-ups (branch `weapons-followups`): the drop's card turning over, the light column for others nearby, the
  Prism Blade's trail by the foe, and the review's small fixes (pity, Grade S reforge, Forge refunds, equip toasts,
  the Forge window's redraws, the Forge Sword's source model out of the synced folder).
- [x] Sword skills round (5.11 "Sword skills", spec `2026-11-06-sword-skills-design.md`, merged 2026-11-07): each
  round 1 sword's own skill, animation, effects (exaggerated), sounds and camera moments; others see them; free after
  the hit (a dodge before it cancels it); each skill's own HUD button. The four skill animations are published (ids in
  `Config/Swords`). Not yet checked: others' effects in a 2-player Local Server.
- [x] Weapons round 2 (spec `2026-11-07-weapons-round2-design.md`, merged 2026-11-08): the sword hold fix, the spears
  (Forge Spear in five elements, Magma Halberd, Tidal Trident, Titan's Lance) with their shared moveset (Thrust, Sweep,
  Sky Pierce, Piercing Rush), effects, sounds, models, portraits and glow maps; their perks; the Titan's Lance's
  Masterwork recipe; the quick weapon switch. The Titan's Lance keeps Power x1.20 (no Legendary Power passes the Hydra
  limit; owner 2026-11-08: its own skill makes it Legendary).
- [x] Weapons round 2.5 part 1 (spec `2026-11-08-forge-relayout-and-titans-wrath-design.md`): the Forge window relaid
  out (the owner's pick A) and the Titan's Lance's own skill, Titan's Wrath. The skill animation is published
  (2026-11-08, id in `Config/Swords` titansLance). Merged to main 2026-11-08.
- [x] Weapons round 2.5 part 2 (spec `2026-11-09-halberd-and-trident-skills-design.md`): the Magma Halberd's Magma
  Cleave and the Tidal Trident's Torrent Strike (own movesets, the `arc` shape, animations, effects, sounds, HUD
  buttons). Both skill animations are published (2026-11-09, ids in `Config/Swords`). With the owner's Studio
  follow-ups: the torrents taller, slowed and bursting at random, Magma Cleave's charge-up, Titan's Wrath made more
  epic, one 12 s skill cooldown starting full, Z for the previous weapon, fights and the town loaded before the
  loading screens close. Merged to main 2026-11-09.
- [x] Weapons round 3 (spec `2026-11-06-weapons-round1-design.md` section 2, "The whole plan"): the scythes (Forge
  Scythe, Widow's Reaper, Storm Reaper, Rift Reaper) with their own moveset, models and portraits (spec
  `2026-11-09-weapons-round3-scythes-design.md`): models, moveset, Reaping Cyclone, perks, portraits, balance (5.11
  "Scythes"), the Rift Reaper's Thousand Cuts with the Grim Reaper (5.11 "Thousand Cuts"), the forward-facing hold;
  owner approved and merged 2026-11-09. The Forge machine's own model: later (owner 2026-11-09).
- [ ] Weapons round 3 part 2: the Widow's Reaper's Eight Legs and the Storm Reaper's Storm Cyclone (spec 5.3); the
  final review's deferred minors (Chain Lightning per foe, the capped harvest shake, the light version's cracks).
- Not reproduced (2026-11-06): pack models on a freshly stocked shelf "slow to render" after joining (the server
  builds them at once, the client had them in 0.05 s, assets preloaded); waiting on how long and which restock.
- Boss cash pays on every win with no cooldown (only items wait LOOT_COOLDOWN): a strong party farming the Meadow
  Warden makes about $2000 an hour. Owner to decide: the loot cooldown or the overpower shrink on cash too.
- Phone instead of the Manage tray (owner's idea 2026-11-06): the manage buttons as phone apps, the shop rating as a
  Reviews app (a feed of customer reviews from real visits, each with its tip). Brainstorm with mockups first.
