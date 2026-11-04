# Wild valley, round 2: natural edges and backgrounds: design

Date: 2026-11-05. Branch: `valley-scenery` (continues round 1, `2026-11-04-valley-scenery-design.md`, not merged yet).

## Intent

After round 1's Studio check the owner said: "right now the world looks like its inside a box. I want you to make the
backgrounds more natural, mountains and etc. the meadows now look like it has random stuffs on it ... on caves it also
looks like Im in a box. the glowing things are fine. but it still looks unnatural and empty/plain. I want big trees ...
on the backgrounds." Their own references: a stylized open-world meadow with a giant tree, grassy cliffs and far
mesas; tall grass under leafy trees; a cozy village at dusk.

Why it reads as a box (confirmed in Studio): each area is walled by long flat terrain blocks of one height with
straight top edges, and nothing exists past them but sky; the Meadow's round-1 pieces are spread evenly over flat
grass, so they read as dropped at random.

From a web reference board (ArtStation, Unity/Unreal stylized scenes) the owner picked: Meadow "rolling hills trail",
"big trees on rolling hills", "bright open valley"; Caves "foggy blue mushroom forest"; Ridge "burnt slopes, lava on
the mountain". From six concept pictures built on those picks (`.superpowers/brainstorm/13775-1793692558/content/
natural-*.png`) the owner picked **Meadow B, Caves A, Ridge A**, and approved the playback below with "OK".

## The owner's picks

- **Meadow B, framed by giant trees.** Giant ancient trees (thick trunks, roots, huge layered canopies) frame both
  sides of the trail; the flat walls become grassy hills and rock outcrops of different heights with tree lines on
  top; every ruin piece (arches, pillars, walls) gathers with the stone circle on **one hill** as one old site; a
  **bigger pond**; clumps of colourful trees; snowy peaks far out in the haze.
- **Caves A, mushroom forest into the fog.** No visible walls: layers of tree-sized glowing mushrooms stand round the
  gorge and on its slopes, fading into **blue fog** so the area's end can't be seen; the crystal cave sits in a mossy
  rock face. Round 1's glowing pieces stay ("the glowing things are fine").
- **Ridge A, burnt hills to the volcano.** Rolling dark hills replace the straight cliffs; groves of ember trees rise up
  them in layers toward the volcano; **lava streams** run down the volcano's sides; a **smoky orange sky** while you're
  on the ridge (owner "OK"), blended in and out like the Caves' look.
- **Clouds** in the sky (Roblox's built-in clouds; one sky per place, so the town gets them too: owner "OK").

## Goals

- From the trail in any area, no straight wall top or flat wall face is in view: the skyline is hills, trees,
  mushrooms or mountains at different heights, with something far away behind it.
- The Meadow reads as composed: one ruin site, groves, a pond, open grass between.
- Same frame budget as round 1: each area within +1.5 ms render CPU of the pieces hidden (measured on/off in one
  session), 60 fps; town memory growth stays modest (StreamingEnabled is on).

## Non-goals

- No change to the walkable area: biome outlines, the trail, passes, the edge walls (invisible), portals, boards,
  signs, spawn rules. Nothing new is reachable.
- Boss arenas untouched. No new monsters.
- No Meshy generations (credits kept for creatures and bosses).

## Anti-goals

- Clutter or a different art style (realistic textures, spiky shapes); round 1's look stays the base.
- A visible seam: models popping in late at the edges, fog that hides the monsters, a sky that flashes on teleport.
- Frame drops on phones; the town paying for the valley.

## Constraints

- **Terrain budget.** The valley's terrain is about 92.5k estimated cells of `MAX_CELLS` 95k. New hill shapes are paid
  for by trimming the walls' hidden volume first (they are thicker than needed); any raise of `MAX_CELLS` (and
  `Scenery.MAX_CELLS`) only after measuring terrain memory, as earlier rounds did.
- **Streaming.** `Workspace.StreamingEnabled` is on (default target radius about 1024 studs). Far background models
  must not pop or vanish while seen from inside the valley: each is a whole-model stream unit (Atomic) placed where
  every viewpoint in its area is within the stream radius, or Persistent if measured cheap; checked in Play.
- **Performance and art rules** as round 1: models under 2k triangles (landmarks up to 4k: a giant tree, a mountain
  range piece), Neon for glow, no shadows on small pieces, colliders only where players can reach, background pieces
  non-colliding and non-queryable.
- **Pipeline** as round 1: Blender build scripts in the background (`tools/blender/`), sources in `assets/blender/`,
  the owner imports and saves `assets/props/<Name>.rbxm`; placement as plain data in `Config/WildValley`, Lune-tested.
- **Day-cycle looks.** The Ridge's look is `DayCycle.AREA_LOOKS[3]` (the Caves' mechanism); the Caves' look gains
  fog (atmosphere density/haze) but monsters must still read clearly.

## How it gets made (my calls)

- **Edges:** each area's wall blocks get a natural skyline: terrain lumps of varied sizes and heights on and in front
  of the wall tops (grass hills in the Meadow, mossy limestone in the Caves, basalt in the Ridge), so tops undulate
  and faces break up; trees, giant mushrooms or ember trees on the lumps. Walls trimmed where hidden to pay for it.
- **Backdrops:** new model types placed outside the walkable area (a `BACKDROP` list per area, not in the spawn and
  biome rules; a test keeps every backdrop piece outside the walkable edge and off the trail): a giant ancient tree
  (Blender, two or three variants), a far mountain range piece (Blender: snowy-capped for the Meadow, dark jagged for
  the Ridge), today's town trees scaled as tree lines, round 1's glow mushrooms scaled up for the Caves' forest, ember
  trees for the Ridge's slopes. The volcano gets more lava streams (its model's `Lava`, or added glowing ribbons).
- **Meadow composition:** the round 1 ruins move onto the stone circle's hill (one site with a path up), flower drifts
  round it; the pond widened (`CARVES`); colourful tree clumps.
- **Sky:** `Terrain.Clouds` created by the server (cover, density, colour in Config); the Ridge's smoky look tints them.
- **Review:** Studio shots from each area's trail cameras next to the picked concepts, before and after; on/off
  measurement as round 1.

## Left to the builder

Exact positions, sizes and counts; which wall volumes to trim; the model split across Blender scripts; colours within
the concepts; fog and sky values (tuned by eye, monsters still readable); stream settings per model after measuring.
