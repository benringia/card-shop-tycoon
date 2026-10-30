# The Wild becomes one valley with three moods

Status: approved by the user 2026-10-31 (concept A "One valley, three moods" of three; concept pictures in the
brainstorm companion, `wild-a.png`).

## Intent

The Wild (the map players reach through the Forest Falls portal, built in the main game far from town at z 1200) is a
placeholder: three flat coloured squares of grass in a row, a few code-built ball trees, fenced boss rings on grey
slabs, cobblestone paths and a cobblestone arrival pad in an empty void. The town around it has been fully dressed,
and the Wild is where players spend their fighting time.

The user picked one connected valley you walk through: a sunny meadow, then a rocky gorge with a crystal cave, then a
smoking volcanic ridge, so the land itself shows you're going further and getting harder. Success: stepping out of the
portal you see a lovely place worth exploring, each zone reads as its own mood at a glance, and the way forward is
obvious.

## Goals

1. **Arrival:** players step out beside the root-arch portal (the Forest Falls portal model, `PortalWild`) as the
   Wild's "Return to shop" portal, facing down the valley.
2. **Meadow (zone 1, Lv 1-5):** grass, a winding stream with a small bridge the trail crosses, flowers, mushrooms,
   bushes and trees; bright and friendly.
3. **Gorge and Caves (zone 2, Lv 5-10):** the ground turns to rock, cliff walls rise on both sides, and a big cave
   mouth with glowing blue crystals stands at the back of the zone; rocks and crystals around.
4. **Ember Ridge (zone 3, Lv 10-15):** dark basalt ground with glowing lava cracks, smoking vents, charred trees and
   obsidian shards, in the Ember Canyon caldera's look (reusing its pieces).
5. **Boss arenas:** each beside its zone as today, dressed in the zone's style: a wooden fence and grass floor in the
   meadow, a ring of stones with crystals in the gorge, a basalt ring with lava cracks on the ridge.
6. **Trail:** a dirt trail from the arrival through the three zones, with small glowing markers along it and the zone
   signs (name and recommended level) where each zone starts.
7. **Edges:** hills and cliffs all round, so the empty void never shows from the play areas, with invisible walls
   behind them so nobody walks off.

## Non-goals

- Monsters' look (placeholder shapes until the monster models project), stats, spawns, fights, rewards, bosses.
- The zones' places and sizes (`Wild.ZONES`, `ZONE_SIZE`, `ZONE_GAP`, `ORIGIN`), the boss arenas' places and rings,
  travel to and from the Wild.
- Healing: there is no healing spring in the Wild; healing stays at the town plaza spring as today.
- The Frontier place: its map is built by the same code but with its own zones; it keeps today's look.
- Sounds, lighting, the day cycle (the Wild keeps the fixed afternoon look).

## Anti-goals

- Monsters floating, sinking, or snapping onto scenery: they stand on the zone floors as today.
- A climb or drop players can fall off, or walls that box the trail in so it's unclear where to go.
- Pale colours that wash out under the sun (the town lessons), or anything that reads as a copy of the town's areas
  rather than its own place (the ridge shares the caldera's look on purpose).
- Frame drops or terrain memory growth past the budget.

## Constraints

- Repo rules (CLAUDE.md): numbers in `src/shared/Config` (a new plain-data config for the valley's scenery), pure
  layout logic in Roblox-free modules with Lune tests, server authoritative, DESIGN.md kept in sync.
- Monsters snap to the ground by raycast against the map folder (`WildService.groundAt`: from 6 studs above, 20 down,
  `rayParams` includes only the map folder): zone floors stay walkable and mostly flat (a gentle roll is fine), and
  whatever monsters stand on must be in what that ray hits (keep part floors, or include terrain in the ray). The
  monster spawn points, wander (12 studs), chase give-up (45 studs from home) and boss leash stay valid.
- The boss arena rings and barriers (`WildService.BuildBossArenas`, `Bosses.ARENA_RADIUS` 36, `ARENA_GAP` 16) keep
  working: dress around them, don't move them.
- Main game only (`Place.isFrontier()` and the Dungeon keep today's map).
- Terrain: the Wild is in the same place as the town, so its terrain counts against the same memory budget
  (`Scenery.MAX_CELLS`, Lune-tested); keep terrain to what players see, raise the cap only with a measurement.
- Performance (DESIGN 10.5): at most 4 area effects per zone; extras that animate run on the client near the camera
  (`Util/Extras`); 60 fps on the Wild's busiest view, measured before and after.
- Props: town prop models, the caldera's Blender props (`CharredTree`, `ObsidianShards`), the crack generator
  (`Util/LavaCracks`) and code-built pieces; new Blender props only if needed (scripted, no Meshy credits).
- Mockups: in-game screenshots of each zone for the user to judge.

## Decided

- Concept A (the user's pick).
- Zones, monsters, bosses, travel and healing unchanged (Claude's call, accepted with the description).
- The Forest Falls root-arch portal model reused as the Wild's return portal (Claude's call, accepted).
- Ember Ridge reuses the caldera's look and pieces (Claude's call, accepted).
- The Frontier keeps today's map (Claude's call, accepted).

## Left to the builder

- Terrain versus parts for the ground, the stream, the gorge walls and the hills; how the zone floors stay what
  monsters snap to.
- The cave mouth's build (terrain arch, Blender prop or parts) and its crystals. The paths between zones run along the
  middle (x 0) and the boss arenas sit off the +X side, so the cave mouth goes in the gorge's back wall to the -X side
  of the path, or in its -X wall (Claude's call).
- The stream's course and bridge, the trail's course and its glowing markers, where scenery stands (clear of spawn
  points, the trail and the arena paths).
- The arenas' dressing within the ring's footprint.
- Effects per zone within the cap (for example fireflies or pollen in the meadow, crystal glints in the gorge, embers
  and vent smoke on the ridge).
- Lune tests: at least scenery clear of the trail, spawn points and arena paths; the effect and terrain caps; the edge
  walls closing the map.
