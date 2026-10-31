# The Wild valley, round 2: a winding valley, boss portals, crowds

Status: draft for the user's approval (2026-10-31). Round 1 (`2026-10-31-wild-valley-design.md`) is built on branch
`wild-valley` and was never merged; the user judged it in Studio and asked for this round instead. This round
supersedes round 1's layout, boss arenas and signs; round 1's moods, props, effects and rules stay. Concept pictures
are in the brainstorm companion (`wild-v2-concepts.html`).

## Intent

The user played round 1 and found three problems:

1. **It's a corridor.** The three zones are equal squares lined up in a straight row, so the whole valley reads as one
   strip with no turns, no height and no surprises.
2. **The fenced boss rings take up the valley,** and only one group can fight a boss at a time.
3. **The signs look wrong.** Plain dark boards with white text, unlike anything else in the game.

They also run full servers (the game holds 60 players), so eight monsters a zone runs dry when a crowd hunts together.

They picked:

- **Layout A, "Winding valley":** one trail in an S shape. The meadow basin turns right and climbs into the gorge, which
  turns left and climbs onto the ridge's volcano. Each biome is about twice as big, with real hills.
- **Boss portals:** a portal in each zone replaces the fenced ring and sends the fighters to the arena.
- **Sign style A, "Wooden trailheads":** the same wood and arrow arms as the town's signposts.

Success:

- Walking in, every bend opens a new view.
- Each biome has hills you walk over, not a flat floor.
- A full server still finds monsters to fight.
- Nobody waits in line for a boss.
- The signs look like they belong to the same game as the town.

## Goals

1. **Layout (concept A):**
   - One trail from the arrival (the root-arch return portal, as round 1) through all three biomes in an S. The
     meadow, then a right turn and a climb into the gorge, then a left turn and a climb onto the ridge.
   - No biome lines up straight with the next. From the arrival you can't see the ridge, and from the meadow you
     can't see down the gorge.
   - Each biome is at least 200 studs across at its widest (round 1: 120), with an organic outline rather than a square.
2. **Height:**
   - The meadow is low, rolling grass hills. The gorge sits about 15 studs higher, with rock shelves and cliffs. The
     ridge sits about 35 studs higher, round a volcanic cone with a glowing crater.
   - The trail climbs between them on walkable slopes.
3. **The moods stay (round 1's pieces, moved and spread over the bigger ground):**
   - **Meadow:** the stream with its bridge and pond, trees, bushes, flowers, fireflies and leaves.
   - **Gorge:** limestone, the cave mouth with blue crystals, crystal clusters and glints.
   - **Ridge:** basalt and cracked lava, glowing floor cracks, charred trees, obsidian shards, smoking vents and embers.
   - The ridge's volcano is new.
4. **Boss portals:**
   - Each zone's boss has a portal in its zone, in place of the fenced ring. It stands at the biome's far end, off the
     trail but in sight of it.
   - It keeps today's Fight and Start group prompts and a wooden board with the boss's name and recommended Power.
   - Fighting sends the fighter, or the group, to an arena of their own away from the valley.
   - After the fight (won or lost) a return portal in the arena takes them back to the zone's boss portal.
5. **Arenas of their own:**
   - Up to 4 copies of each boss's arena run at once. A solo fight never waits behind another fight or a forming group.
     When all 4 are busy the player is told so and tries again.
   - Each copy keeps its zone's look from round 1 (`ARENA_LOOKS`): grass and wood, slate and crystal tips, basalt with
     lava cracks and ember tips.
   - Each copy stands in a small clearing of its own, so no void shows from inside it.
6. **More monsters when it's busy:**
   - A zone keeps 8 monsters while it's quiet. It gets 2 more for each player in that zone past the first 3, up to 24
     a zone.
   - Respawns take 20-40 s while quiet and 10-20 s while the zone is busy (more than 8 wanted).
   - When players leave, the extra monsters aren't respawned as they're beaten. No monster vanishes in front of anyone.
7. **Wooden signs:**
   - A hanging plank board on two log posts at each biome's entrance, with the name and the zone's monster levels
     (for example "MEADOW", "Lv 1-5").
   - Wooden arrow arms at the trail's bends, naming the next biome and pointing to it.
   - "The Wild" becomes a wooden board beside the root arch.
   - Each boss portal has a wooden name board.
   - The wood, arrows and fonts match the town's signposts (`Server/Util/TrailProps`).

## Non-goals

- Monster models, species, stats, levels, rewards, drop rates and aggro (zone rules in `Wild.ZONES` stay).
- Bosses' stats, unlocks, loot, group scaling and the boss board's rules. Only where the fight happens changes.
- The Frontier and the Dungeon. Their maps and arenas stay as they are, although `WildService` builds them too.
- Healing (the plaza spring), travel to and from the Wild (the Forest Falls portal, the Shop button), the day cycle,
  sounds.
- Saved data. No save shape changes.

## Anti-goals

- **Monsters floating, sinking or walking on water or up cliffs:** they stand on the ground they're over.
- **A drop off the trail or a climb a player can fall from** without an easy way back. The trail never needs a jump.
- **Losing anything:** a boss win's loot is never lost because a player was sent back from the arena.
- **Players stuck:**
  - in an arena with no way out;
  - in a fight that started without them;
  - behind a wall.
- **A server cost that grows with an empty map:** quiet zones and idle arena copies cost nothing noticeable.
- **Frame drops or terrain memory growth past a measured budget.**
- **Signs that read as a different game from the town,** or that face away from the players walking up to them.

## Constraints

- **Repo rules (CLAUDE.md):**
  - numbers in `src/shared/Config`;
  - pure rules in Roblox-free modules with Lune tests;
  - server authoritative;
  - every remote validated and rate-limited;
  - DESIGN.md kept in sync.
- **Shared code:**
  - `WildService` builds the main game's Wild, the Frontier's map and the Dungeon. Only the main game's Wild changes:
    the `VALLEY` flag (`not Place.isFrontier() and not Place.isDungeon()`).
  - The Frontier still uses today's zone grid (`ZONE_SIZE`, `ZONE_GAP`, `zoneCenter`), its fenced rings and its
    boards. Bosses 4-6 (Frontier) and 7 (Dungeon chamber) keep their arenas.
- **Monsters and ground:**
  - Monsters snap to the ground by a downward ray (`WildService.groundAt`, today only against the map folder's
    invisible flat zone floors at y 0). With hills, what monsters stand on must follow the terrain: rays must hit
    terrain, but not water.
  - Spawn spots, wandering (12 studs), chasing (give-up 45 studs from home) and contact must keep working on slopes.
  - Monsters must not wander into the stream, off the edge or onto cliffs.
- **Boss fight flow** (`BossService`, `BattleService`):
  - The ring's barrier seals for the fight and drops when it ends.
  - A player who leaves the fight is moved out (`OnMemberLeft`).
  - The boss board's "Take me there", the dev commands `/boss n` and `/boss n fight`, and the Admin panel's
    Go/Fight/Group now point at the zone's boss portal.
  - Loot drops in the arena and waits to be picked up (`BossRules`, `pending`). Before anyone is sent back from an
    arena automatically, whatever loot they haven't picked up goes into their Bag.
  - Group prompts, lobbies, unlock keys, rewards and titles behave as today.
  - The fall rescue (`rescueFallen`) must cover the arenas too: someone who falls in an arena goes back somewhere safe.
- **Travel:**
  - The Wild stays far from town (round 1: around z 1100-1570). The map may grow in x and z and its origin may move,
    as long as nothing overlaps the town, the portal areas or the Frontier's own coordinates.
  - Arrival still waits for the valley's terrain (`WildTerrainReady`).
  - Streaming: the destination is streamed in before a move (`RequestStreamAroundAsync`), arenas included.
- **Terrain budget:**
  - Round 1's valley is about 37.7k estimated cells (cap `WildValley.MAX_CELLS` 40k; town plus valley under
    `Scenery.MAX_CELLS` 180k, Lune-tested).
  - The bigger valley and the arena clearings may raise these caps only with a before/after measurement in Play:
    terrain graphics and voxel memory in the valley and on the town street, and fps at graphics levels 1 and 10
    (DESIGN 10.5's method).
  - Terrain stays where players can see it.
- **Performance (DESIGN 10.5):**
  - at most 4 area effects per biome;
  - animated extras run on the client near the camera (`Util/Extras`);
  - 60 fps on the busiest views, measured before and after;
  - a crowded zone (24 monsters) measured too.
- **Props:**
  - town prop models;
  - the caldera's Blender props (`CharredTree`, `ObsidianShards`, `Volcano` if it fits the ridge's cone);
  - `Util/LavaCracks`;
  - code-built pieces.
  - New Blender props only if needed, scripted, with no Meshy credits.
- **Text:** plain ASCII plus `·` and emoji (the fonts draw other symbols as boxes).
- **Mockups:** in-game screenshots for the user to judge:
  - the arrival;
  - each bend;
  - each biome;
  - a boss portal with its board;
  - an arena copy;
  - the return;
  - a crowded meadow.

## Decided

- Layout A, wooden trailhead signs, boss portals (the user's picks, 2026-10-31).
- **Arenas stay in the same server,** away from the valley and out of sight and streaming range of each other: no
  loading screen, and it works in Studio. Claude's call, shown on the concepts page; the user didn't object.
- **Each fight gets its own arena copy,** up to 4 per boss at once. Claude's call, shown, not objected to.
- **The monster numbers:** 8 quiet, +2 per player in the zone past 3, cap 24, respawn 20-40 s quiet and 10-20 s busy.
  Claude's call, shown, not objected to.
- **The zone boards show the monsters' level range** ("Lv 1-5") instead of "Recommended Lv 1+" (the sign mockup the
  user picked).
- **The plaza signpost moved** into the planter by the spawn (the user's pick A, done: commit `3b46e03`).
- **The sleeping cat** shows from the start of a visit (done: commit `30168e0`).

## Left to the builder

- **The valley's exact outline, heights, slopes and bends**, the trail's course and how it climbs, within Goals 1-2.
  Also where round 1's pieces go on the bigger ground.
- **How monsters stand on the ground:** terrain in the ray (with water ignored) or shaped floor parts. Also how spawn
  spots are laid out: at least 24 per zone, spread over walkable ground, clear of the trail, stream, props, edges and
  the boss portal's surroundings.
- **The boss portal's look:**
  - a portal frame in the zone's material with a swirl, reusing the town portals' pieces where they fit;
  - its exact spot in each biome.
- **The arena copies:**
  - where they stand and how their clearings are built (terrain or parts);
  - whether they're built at start or on demand;
  - how the return portal looks.
  - Also how long players may stay after the fight before they're sent back (with loot first going into the Bag).
- **Group lobbies with copies:** a group forming at a portal must not block solo fights there. Whether more than one
  group may form at a portal at once is the builder's call.
- **How "players in a zone" is counted** for the monster rule (inside the biome's outline, for example). Also how
  spawn spots are picked as the count rises, and when an extra monster isn't respawned.
- **The signs' build** (code-built from parts like `TrailProps`, or a Blender model) and where the bend arrows stand.
- **Lune tests, at least:**
  - the monster count rule and respawn times;
  - spawn spots inside their biome and clear of the trail, stream, props and portals;
  - the trail turning at least twice;
  - the edge closing the map;
  - the terrain cell caps;
  - arena copies not overlapping each other or the valley;
  - signs clear of the trail and facing it.
