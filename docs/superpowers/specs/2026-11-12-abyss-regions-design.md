# The Crystal Abyss, round 3 part 2: regions, a longer way, the Hydra's castle

Owner 2026-11-12 after playing round 2: "add a terrain rather than a plain floor. and maybe make the map bigger so
players will have to walk certain distances to get to the next bosses. rather than just straight. and the rooms should
not be seen from a far." "Hydra arena from outside looks undesigned/broken: maybe a broken castle with a gate/portal
that teleports to the Hydra's lair." "Different regions per room, so the world around room 1 has a different theme."
Castle concept approved: `assets/blender/DungeonWorld/concept_castle.png`.

## Goals

- **A winding way, not a straight line.** The run snakes left and right across the cave, round rock spires and along
  ledges, about 15-20 s of walking between steps (today's run is about 770 studs straight; the new one about 1600 along
  the path). The cave grows to fit (`CAVE_HALF_WIDTH`, the walls, the backdrop band).
- **Rock, not plates.** Every island is a Terrain mesa: a rocky top (Slate, Basalt, the region's own colour), cracked
  edges and an underside. The flat parts stay only where puzzles need an exact floor (the beam grid, the plates), as
  inlaid stone slabs on the rock.
- **Rooms hidden until you get there.** Each fight room sits in a crater: a Terrain rim higher than a player's eye line
  round its ring (the ruined walls stay on it), so from the path you see the rim, not the arena. Spires and the path's
  turns block the long views.
- **Regions.** Each room's stretch has a theme from the Hydra's heads:
  - Room 1, **Tide**: blue-teal rock, ice-blue crystals, waterfalls of light, mist.
  - Room 2, **Volt**: dark slate, yellow storm crystals, flickering lights, crackles.
  - Room 3, **Ember**: black basalt with glowing lava cracks, red-orange crystals, embers rising.
  - The castle, **Shade** with **Bloom**: violet stone, green and purple crystals.
  A region is its Terrain colours, its crystal colours, its light falls' colour, a few of its props, and a haze tint
  the client blends to as you walk in (like the Wild's biomes). Puzzle islands take the colours of the region they sit
  in.
- **The Hydra's castle.** The chamber island becomes the castle plateau: broken towers and walls (Terrain plus the
  props pack's walls and pillars, scaled up), and in its broken front wall the hydra gate (today's Hydra door) over a
  violet portal, the five gems above. After the lock's cinematic the portal is open; stepping in (or its prompt) takes
  the group into **the Hydra's lair**: a separate cave far below the map (out of sight, its own Terrain dome, the
  arena ring, today's boss fight unchanged). The broken-looking arena outside is gone.

## Non-goals

- No new monsters, bosses or puzzles; fight balance unchanged (the walk is not a fight).
- No new Blender import before launch: the castle is Terrain plus the props pack we have (walls, pillars, the Hydra
  door, crystals), scaled. A real castle model can come later.

## Constraints

- Performance: the run streams (radius 1024; the lair is far enough to stream out while you walk the path and back in
  through the portal's Prestream). Lights stay capped (6 backdrop lights, 1 per region accent). Terrain does the bulk.
- Every rule the tests pin today keeps holding: gates on their bridges with only chasm past their ends, approach and
  skip spots on stone, the fall at KILL_Y, puzzles' pieces on their island, the gather stage on the right island.
- Dev commands keep working: `/room`, `/puzzle`, `/winroom`, `/boss 7` (into the lair).

## How it's built (my calls)

- `Util/AbyssLayout` gets a path: a list of waypoints the islands sit on (left, right, up and down a little), bridges
  and ledges between, spires placed beside the turns; each island tagged with its region. Lune-tested: lengths between
  steps, nothing overlapping, rooms' craters not in sight from the bridge before them (a line from the bridge's start
  to the arena's middle passes through rock).
- `DungeonBuilder` builds islands as Terrain mesas, craters for fight rooms, spires, ledges; regions from
  `Config/Dungeon REGIONS`; the castle plateau; the lair far below.
- A client `DungeonRegionController` blends the haze and lighting tint by region.
- `BossService`/`WildService` place the Hydra's arena in the lair; the castle portal teleports the group there.

## Open for the owner

- Walking time between steps: about 15-20 s (my call). Say if you want longer or shorter.
