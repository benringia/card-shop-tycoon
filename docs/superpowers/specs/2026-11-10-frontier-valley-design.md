# The Frontier valley: design

Owner, 2026-11-10: "make the frontier feels more dangerous than the wild. apply the wilds rule too (no walls,
sceneries, musics, bosses, loading screens etc)". Picks: 6 new Meshy monster models, 3 new Meshy bosses, the Titans'
Graveyard look (concept C, picked earlier), the final area farthest away with the Dungeon portal at its end, and boss
portals to their own arenas. Boss looks (owner "proceed" on my picks): Frost Tyrant A (ice yeti king), Storm Sovereign
B (storm wyvern), Rift Devourer A (void beetle titan). All six monster concepts kept. Launch is 2026-11-19 and the
Dungeon world comes after this, so the Frontier reuses the Wild valley's code wherever it can.

## Why

Today the Frontier is three flat coloured squares, three boss rings in the open, a spring and a "coming soon" Dungeon
portal by the entrance. It's the game's level 15-50 world, where players spend the most time once the Wild is done,
and it looks like a test map. The Wild valley already shows what a world should be; the Frontier should be that,
darker and more dangerous.

## What the player sees

**Arriving.** The teleport from the town's Frontier portal shows the Frontier's loading screen: the Wild portal's
swirl in icy blue and violet, the title "The Frontier", a bar and tips. It stays up after the teleport until the ground,
the scenery round you, the monsters' models and the music are in (the Wild loading screen's rule), then fades.

**The camp** (no monsters): the arrival pad, the healing spring, the Return portal home, tents, a campfire and a wooden
watchtower, at the south end, on ground level.

**One winding trail through three areas at three heights**, like the Wild valley (layout: the map on the picks page):

1. **Frostwood** (Lv 15-25, ground level y 0): snowy ground, giant dark pines, ruined forts with red banners, a giant
   ribcage the trail walks under, huge swords stuck in the snow, frozen ponds. Fog, with pairs of red eyes in it that
   fade away as you get close. Grey snowy dusk, falling snow. Monsters: Frost Wisp, Shade Lynx. Monsters stay calm.
2. **Stormpeak** (Lv 25-35, high plateau, about y 40, reached by a climbing pass): bare rock and slate, wrecked
   watchtowers, a giant horned skull, rock spires. A thunderstorm: dark sky, lightning flashes with thunder now and
   then (light and sound only), a tornado far off. Monsters: Storm Hawk, Lava Brute. Elites chase you.
3. **The Rift** (Lv 35-50, down in a crater, the floor about y -15, reached by a pass down from the plateau): dark
   basalt split by glowing violet cracks, a dragon skeleton, floating rocks, violet crystals, a violet sky with a slow
   vortex. Monsters: Rift Horror, Prism Crab. Everything chases you (as now). **The Dungeon portal** (a crystal arch)
   stands at the far end, the farthest point from the camp.

A dead giant (a hill shaped like a fallen titan, with ribs and a skull showing) lies in the middle, so no area can be
seen from the last, as the Wild's central mass does.

**No walls anywhere** (the Wild's rule, owner 2026-11-05): snowbanks, pines, cliffs, rock spires and the crater's
rim close each area in. Far beyond, a backdrop: snowy mountain ranges, a titan's silhouette, a wall of storm clouds.

**Bosses behind portals.** Each area has a boss portal by the trail with its board (name, recommended Power), like the
Wild's. Through it, the boss's own arena far away (copies like the Wild's, so several groups can fight at once):

- **Frost Tyrant**: a frozen throne hall, ice pillars and a broken throne, snow falling.
- **Storm Sovereign**: a broken ring of stones on a summit, a storm eye overhead, lightning flashes.
- **Rift Devourer**: an island of rock floating in violet void, crystals round its edge.

Each arena has its own sky and music, and its way home inside it, as in the Wild.

**Music** for each area and each arena: lower and darker than the Wild's guitar and piano (strings, drums, choir),
with an ambient loop each (wind and snow, distant thunder, a low rift hum). I find 3 candidates per place in the
licensed libraries; the owner picks by ear with `/music`.

**More dangerous than the Wild:**
- Frontier monsters are drawn 30% bigger than the Wild's (and elites bigger again, as now).
- Stormpeak's elites chase you; the whole Rift chases you. Frostwood stays calm (you arrive there at level 15).
- Darker skies, fog, red eyes, the storm and the rift's violet glow. Lightning and rift tremors are looks and sounds
  only (a small camera shake for a tremor): nothing hurts outside a fight.

## New models

**Six monsters** from the kept concepts (`assets/blender/<Folder>/concept_A.png`), the Wild monsters' pipeline
(docs/creatures.md "How the six wild monsters were made"): cut out, Meshy image-to-3D, `rig_<species>.py` with PetRig
bone names, the glow mask, the owner imports, saved as `assets/monsters/<Species>.rbxm`, their clips from
`anim_wild.py`. Shapes: Frost Wisp a slime, Shade Lynx a four-legged cat, Storm Hawk a flyer, Lava Brute a two-legged
brute, Rift Horror a six-legged beetle, Prism Crab a crab. Bulky, never skinny; neutral poses.

**Three bosses** from the picked concepts, the Wild bosses' pipeline (docs/creatures.md "Wild bosses"): Meshy,
`rig_<boss>.py`, `anim_<boss>.py` clips (idle, attack, the big hit, its mechanic's moment: the Tyrant's shield, the
Sovereign's thunderclap, the Devourer calling its Rift Horrors), saved as `assets/monsters/<bossId>.rbxm`. Godlike and
big. Their fights' numbers stay as they are.

Meshy: 9 generations, about 270 credits; the balance is read first (number only), and each generation is right the
first time (firm prompts, cut-out concepts).

## How it's built (the parts the owner decided, and my calls)

- **One valley engine, two valleys.** `Config/FrontierValley` has the same shape as `Config/WildValley` (biomes,
  trail, passes, banks, hills, edges, terrain, skylines, carves, boss portal, arenas, props, backdrop, mountains,
  settle, population). The code that reads `Config/WildValley` today (SceneryService, WildService, BossService,
  DayCycleController, MusicController, the loading screen) reads the place's valley config instead: the Wild's in the
  main game, the Frontier's in the Frontier, none in the Dungeon. The Wild's own pieces (the stream, bridge, cave,
  volcano, vents) are optional keys the Frontier leaves out; the Frontier's own pieces (red eyes, lightning, the
  tornado, the vortex, the floating rocks, tremors) are optional keys the Wild leaves out.
- **The Wild must not change.** Its config keeps its numbers, and its tests keep passing; the same Lune tests run on
  both valley configs (trail inside the biomes, portals clear, spots clear, the cell budget).
- **Scenery props** (ribcage, horned skull, giant swords, fort ruins, watchtowers, tents, dead pines, ice pillars,
  throne, floating rocks, crystal arch) are built in Blender by scripts like the valley props
  (`tools/blender/build_frontier_props.py`), saved as `assets/props/<Slot>.rbxm`. The Wild's skeleton, ruins and
  mountains are reused where they fit.
- **The Frontier place** keeps its spring, Return portal and boss data. Its three rings and flat zones go; `/boss 4-6`
  takes you to each boss's portal (as `/boss 1-3` does in the Wild). The Dungeon portal moves to the Rift's end.
- Coordinates are the builder's, from the map: about the Wild valley's size (some 600 by 750 studs), the arenas far
  away as in the Wild.
- **Performance:** the Frontier place has no town, so it gets the Wild valley's cell budget (about 105k terrain cells)
  and the same rules (docs on town performance: cheap nature, few lights). Checked on a phone-sized device in Studio.

## Out of scope

The Dungeon world (next), new Frontier monster or boss numbers, new mechanics, hazards that hurt, new cards or drops,
weather that changes over time, and Town Chikin.

## My calls (for the owner to check)

- Frostwood stays calm, Stormpeak's elites chase, the Rift all chases.
- Frontier monsters drawn 30% bigger than the Wild's.
- Lightning and tremors are looks only, nothing hurts outside a fight.
- The camp has no monsters and keeps the spring by the arrival point.
- Music: 3 candidates per place, the owner picks by ear.
- Order of work, so something playable comes first: the valley (terrain, trail, areas, edges, camp, portals with the
  stand-in monsters) → the scenery, skies and effects → the loading screen and music → the monsters and bosses as the
  owner imports them.
