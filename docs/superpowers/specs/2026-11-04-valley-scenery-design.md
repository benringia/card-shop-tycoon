# Wild valley scenery: design

Date: 2026-11-04. Branch: `valley-scenery`. Owner's words: "right now it's so empty. same with the meadows and ridge. I
want it to have nice scenery", "beautiful and cheap in performance". Concept pictures (Figma) were shown next to Studio
shots of today; the owner picked one look per area and said "proceed" to the draft below.

## Intent

The Wild valley's three areas (Config/WildValley BIOMES: the Meadow, the Caves (the limestone gorge) and Ember Ridge)
read as big, flat, nearly empty spaces: about 190 parts across the whole valley, a dozen thin trees in the Meadow,
ten grey rocks and eight small crystals in the Caves, ten small charred trees on the Ridge. Each area should look like a
place worth exploring: a landmark you see from the trail, plenty of life in between, in the game's soft cartoon style,
and stay at 60 fps on phones.

## The owner's picks (concepts in `.superpowers/brainstorm/13775-1793692558/content/scenery-*.png`)

- **The Caves: C, Glow Mushroom Hollow.** Giant teal and purple glowing mushrooms, small to tree-sized, in clusters
  against the cliffs and round the cave mouth; patches of glowing blue plants and small glowing flowers along the
  trail; mossy round boulders; fireflies and low mist; a big rock shelf overhanging one side. The blue crystals and the
  crystal cave mouth stay.
- **The Meadow: B, Ancient Ruins.** Overgrown stone ruins in the grass: a broken arch, mossy pillars (some fallen),
  crumbled low walls, vines and flowers on them; a circle of standing stones as the landmark; many more wildflower
  patches and a red-and-white mushroom ring; more round trees in clumps. The stream, pond and bridge stay.
- **Ember Ridge: B, Ember Forest.** Groves of charred trees with glowing orange ember crowns (bigger than today's);
  clusters of glowing red and orange crystals; a giant dragon skeleton half buried as the landmark; drifting ash and
  embers. The lava cracks, vents and volcano stay.

Items marked *(my call)* below were Claude's guesses in the draft the owner approved with "proceed"; the rest is the
owner's pick as described.

## Goals

- Each area has one landmark visible from the trail as you arrive: the standing-stone circle (Meadow), a group of the
  biggest mushrooms by the cave mouth under the rock shelf (Caves), the dragon skeleton (Ridge) *(my call: placement)*.
- Each area feels full from the trail: no stretch of bare floor wider than about 40 studs left empty in view, without
  crowding the fighting space.
- **The Caves get a darker, bluer mood while you're in them** (owner, 2026-11-04: "darker", asked because the
  picture's glow only pops in dusk light): their own sky look, blended in over a couple of seconds as you come through
  the pass and out again as you leave, so the glowing mushrooms, plants and crystals stand out by day. The Meadow and
  the Ridge keep the valley's fixed afternoon look (the valley has no day cycle: `DayCycleController` shows the fixed
  afternoon look outside the town, and each Wild boss arena its own `Config/DayCycle ARENA_LOOKS` look).

## Non-goals

- No change to the valley's layout: biome outlines, the trail, passes, edge walls, boss portals, boards and signs stay.
- No new monsters, no change to spawn numbers. No lighting change outside the Caves.
- The boss arenas are not touched.
- No Meshy generations *(my call: the credits are kept for creatures and bosses)*.

## Anti-goals (it fails even if it works)

- The trail or a monster fight gets blocked, or the camera keeps snagging on scenery mid-fight.
- Frame rate drops on phones, or the town gets slower because the valley's pieces load there.
- Clutter: so much that the areas read as noise, or pieces in a different art style (realistic, spiky, dark-grim).
- Glow so strong it hurts at night or washes out the monsters.

## Constraints

- **Performance (DESIGN 10.5).** Each new prop model under 2k triangles; the dragon skeleton is a landmark and may go to
  4k (as the portals). Glow comes from glowing materials (Neon parts), not lights: at most one PointLight per area
  *(my call)*. Small pieces cast no shadows. Particle effects reuse Scenery's effect kinds with their rates capped
  and drop out under the frame watchdog like the town's extras. Pieces are anchored; small ones don't collide and are
  skipped by raycasts (camera). Measured in Studio Play (focused window, the town's method: render CPU from a fixed
  spot in each area, before and after): each area within +1.5 ms of today and 60 fps. Measure before the build starts.
- **Placement rules (tests/WildValley).** Every piece stays clear of the trail, the stream, the portals, the boards
  and the arrival (`WildValley.clearOf`), inside its own biome, and every biome still has its 24 spawn spots well
  inside it, clear and on gentle ground. Terrain changes (the Caves' rock shelf) stay inside `MAX_CELLS`.
- **Prop pipeline (docs/props.md).** New models are built in Blender by scripts (the arena props' way:
  `tools/blender/build_*.py` on `voxel_kit.py` / `portal_kit.py`, smooth cartoon look, palette texture, glowing parts
  named so the game makes them glow), sources in `assets/blender/<Name>/`. The owner imports each FBX in Studio and
  saves it as `assets/props/<Name>.rbxm` (Claude can't save files from Studio); until a file is saved the area builds
  without it (as today). Lune tests check every model the config names has a saved file and none holds a script.
- **Config, not code.** Positions, counts, sizes and colours live in `Config/WildValley` (and effects in
  `Config/Scenery`), placed by SceneryService like today's PROPS / CRYSTALS / CHARRED.
- Style: the town's and arenas' props (smooth, chunky, flat colours, soft bevels), the Cute Pets look. Mushrooms and
  ruins rounded and friendly; the dragon skeleton big and impressive but cartoonish, not gory.

## How it gets made *(my calls unless noted)*

- **New prop models** (Blender scripts):
  - Caves: glowing mushrooms in three shapes (tall single, a cluster of two or three, a small flat-capped one), caps
    in teal and purple variants (a glowing cap part); a small glowing plant tuft; a glowing flower tuft; mossy boulders
    (two shapes, rock with a green moss top).
  - Meadow: ruin pieces (a broken arch, a standing pillar, a broken short pillar, a fallen pillar, a crumbled wall
    segment), each with vine and flower details on it; a small red-and-white mushroom for the ring. The standing
    stones reuse the arenas' `StandingStone`; trees, bushes and flowers reuse today's models.
  - Ridge: an ember tree (the charred tree's shape, bigger, with glowing orange ember clusters in its crown) and the
    dragon skeleton (skull, neck and spine, ribs arching out of the ground, a wing bone or two; half buried). Red and
    orange crystal clusters are code-built like the Caves' blue ones, in new colours.
- **The Caves' rock shelf:** a terrain ledge of limestone jutting from the west cliff over the floor near the cave
  mouth, high enough that nothing walks into it.
- **The Caves' look:** a look in `Config/DayCycle` (the same fields as `ARENA_LOOKS`: dimmer, cooler ambient, a
  blue-teal atmosphere tint, a little more bloom so Neon glows), applied by `DayCycleController` while the player stands
  in zone 2 (`WildValley.zoneAt`), blended with the afternoon look over about 2 s (`Util/DayCycle`'s blending, Lune-
  tested). Monsters must still read clearly against the floor: checked in the review shots.
- **Effects:** the Caves get fireflies and low mist (Scenery kinds `fireflies`, `mist`) beside today's glints; the
  Meadow keeps its fireflies and leaves; the Ridge gets `ash` beside today's embers.
- **Amounts** (starting points, tuned by eye in Studio): Caves about 18 mushrooms (4 big), 30 plant and flower tufts,
  10 mossy boulders (today's rocks become mossy ones); Meadow 2 arches, 6 pillars (2 fallen), 5 wall segments, a
  stone circle of 8 or 9, 2 mushroom rings of about 8, 30 more flowers, 8 more trees; Ridge 12 ember trees (today's
  charred trees kept or swapped), 10 crystal clusters, the skeleton.
- Review shots: Studio screenshots of each area from the trail and from the middle, next to the concept, for the
  owner's judgement; the Caves also mid-blend at the pass.

## Left to the builder

Exact positions, rotations, sizes and colours within the looks above; how the props are split across Blender scripts;
how the glow parts are named; which today's pieces are swapped for new ones; the effect rates within the caps.
