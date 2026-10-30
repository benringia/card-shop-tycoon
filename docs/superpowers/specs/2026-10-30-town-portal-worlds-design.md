# Town nature pass: Portal Worlds (design)

Status: approved by the user 2026-10-30 (builder check answered). Comes after the full-server performance fix (merged 2026-10-30,
`Config/ShopDetail`). DESIGN.md section 13 lists it as the next project.

## Why

The game plays end to end; what's missing is the first impression. The user wants new players to go "wow, this is
beautiful" the moment they see the town, plus a short welcome cinematic on their first visit. The user also wants the
game fast in full servers on phones before more decoration lands, which is why the performance work came first and
why this design carries measured limits.

## What players get

- Three portal areas outside the current town, each previewing the world its portal leads to. Players **walk** to each
  portal along a trail:
  - **Forest Falls** (the Wild portal): an ancient forest of giant trees, a tall waterfall into a turquoise pool with
    mist, the green portal on the grass by the pool.
  - **Frostpeak** (the Frontier portal): a snowy clearing at the foot of a tall snow-capped peak, snow-dusted pines, a
    frozen waterfall, the icy portal with drifting snow and an aurora shimmer.
  - **Ember Canyon** (the Arena portal): striped red sandstone cliffs, floating embers, a few cacti, the red portal on
    a stone platform between two torch pillars at the canyon's end.
  - The names are placeholders the user may change.
- Signposts in town ("This way to ..."), a wooden gateway arch where each trail leaves town, and the street's glowing
  portal lines carried on along each trail in the portal's colour.
- Nature in town: swaying grass on the open ground, the existing trees swaying gently near the camera, giant trees at
  the town's corners, butterflies round the plaza and along the trails, 3 Cute Pets animals running around, ambient
  sounds.
- A slow day cycle from morning to sunset (with a short night), the same for everyone in a server.
- A welcome cinematic on a player's first visit: a time-lapse flight from morning to sunset, sunset shown the longest,
  ending at the player's own shop.

## Not in this project

- New gameplay in the areas (no monsters, quests or collectibles there). They are scenery plus the portal.
- Changing what the portals do or where they lead (the Wild map, the Frontier place and the Arena stands stay as
  they are; only the portal's spot in the main town moves).
- The Frontier and Dungeon places' own scenery.
- Night as its own gameplay phase, weather, seasons.
- Customer/NPC models (separate backlog item) and the remaining monster models.

## Must not happen

- A full server (6 shops x 30 items, 24 customers, 12 workers, 6 pets, 6 players) dropping below 60 fps on PC at
  graphics levels 1 and 10, or the scenery adding more than the budget below. The user's concern was performance
  first.
- Walks longer than the approved map. The user chose to keep the map's portal spots: about 8-9 seconds at the default
  walk speed of 16 studs/s (roughly 125-140 studs of trail) from the street's east end to the two east portals, about 6
  seconds to the Arena portal. Don't stretch them further.
- A cinematic that can't be skipped, plays more than once, or leaves the player somewhere other than their shop.
- Text symbols that render as boxes (CLAUDE.md: plain ASCII plus `·` and emoji only; arrows are shapes, not glyphs).
- Shops getting hard to read at sunset or night.
- Terrain covering the town's thin ground parts. A Play-mode test on 2026-10-30 showed terrain filled to y >= 0 hides
  the plaza floor, crosswalks and street lines; keep the terrain's top below them or cut it out under them.

## Decided by the user

| Topic | Decision |
|---|---|
| Layout | Concept B "Portal Worlds" (picked from A Valley Falls, B Portal Worlds, C River and Bridge) |
| Portals | Each portal moves into its own area; players walk there along a trail |
| Signs | Signposts in town saying which way each portal is |
| Day cycle | A slow cycle from morning to sunset |
| Cinematic | First visit only; a time-lapse with sunset shown the longest |
| Animals | Only 3 Cute Pets animals for now (the user cut it from 8) |
| Mockups | Always show mockups for visual decisions (saved as a standing preference) |
| Tools | Blender and Meshy may be used where needed |
| Area look | The three concept pictures below are the feel to aim for |
| Walk length | Keep the approved map's portal spots: an 8-9 second walk to the east portals (picked over pulling them in to 6 s) |
| Where the cycle runs | Town only (the town and its three portal areas); the Wild map, the Arena stands and the boss arenas keep today's afternoon look |
| Street-end decor | The hand-placed pieces in the trails' way may be moved in Studio (not deleted), with screenshots before and after; the user saves `TownDecor.rbxm` |

Concept pictures (Figma image generator, file `rd1ves753oagkIGEJgV4qC`, nodes `106:2` Forest Falls, `106:3` Frostpeak,
`106:4` Ember Canyon; copies in the brainstorm folder `.superpowers/brainstorm/1089-1793342919/content/`, not in git).
The approved map mockup is `portal-worlds-v1.html` in the same folder. The game version will be simpler than the
pictures; the user knows this.

## The world

### Map

The town core stays as it is: the island inside the hedge (x -130..130, z -110..110), the street (x -110..110,
z -48..48), the plaza and spring at the centre, 6 plots at x -64/0/64, z +-68. Plots, shops and the plaza don't move.

The three areas sit outside the island (rough targets from the approved map; the builder sets the final shapes):

| Area | Where | Portal spot (rough) | Trail |
|---|---|---|---|
| Forest Falls | south-east, about x 135..240, z -90..-185 | by the pool at the falls' foot, about (185, -118) | from the street's east end (south side) curving south-east |
| Frostpeak | north-east, about x 135..250, z 90..200; the peak rises behind | in the snowy clearing, about (182, 128) | from the street's east end (north side) curving north-east |
| Ember Canyon | west, about x -150..-250, z -40..40 between red cliffs | at the canyon's end, about (-205, 0) | straight west from the street's west end |

Soft hills sit behind the shop rows (north and south of the island) to close the skyline. Everything players can't walk
to is backdrop: simple terrain shapes with haze over them.

The walkable edge (the invisible walls, today `Town.BOUNDS`, a rectangle) grows to take in the three trails and
clearings, so it is no longer a rectangle. Players must not be able to wander onto the peak, the canyon rims or into
the forest beyond its clearing.

Where the portals stand today (street ends, x +-104) become the trail starts, each with a gateway arch.

### In town

- Ground: terrain grass where open ground shows (Roblox's grass decoration is already on in this place, so the blades
  sway for free), pavement-type terrain under the street and paths so no blades poke through. The Baseplate's look is
  replaced; the plaza, crosswalks, sidewalks and street lines stay visible.
- Trees: the existing trees sway gently near the camera; giant trees (scaled-up copies of the existing tree models) at
  the island's four corners.
- Butterflies: the existing `ButterflyController` extended to a few more spots (plaza, along the trails), still client
  side and moving only near the camera.
- Animals: 3 Cute Pets models running around, client side. Builder's suggestion (my call): Fox at the forest edge, Bunny in
  the plaza garden, Capybara between the shops. Each runs between random points in its home area, pauses and idles.
  Positions are not synced between players (ambient only).
- Sounds (my call): the waterfall near Forest Falls, wind at Frostpeak, crackling embers in the canyon, soft birds in town;
  positioned sounds with short roll-off, quiet. Free Creator Store sounds as in the pack opening (licensed libraries;
  picked by description and measured, the user judges by ear).

### Signs and gateways

- Signposts: arrow-shaped wooden boards with the destination name glowing in its portal's colour ("THE WILD",
  "FRONTIER", "PVP ARENA"; the user is fine with "or something" for the wording) and a small "This way" under each.
  One signpost at the plaza with all three arms, one at each end of the street. The arrow is the board's shape.
- Gateway arches: a wooden arch over each trail start with the area's name (Forest Falls, Frostpeak, Ember Canyon).
- Trail lines: the glowing line from the plaza to each portal (today `TownLayout.portalPaths`, straight lines on the
  street) continues along the trail to the portal, in the portal's colour.

### Day cycle

- Where it runs (the user's pick): the town and its three portal areas only. The Wild map (z +1200, bosses 1-3), the
  Arena stands (z -1200) and the boss arenas share the main place's one Lighting, so each client switches to today's
  fixed afternoon look (`Town.LIGHTING`) the moment its player is outside the town and back to the cycle on return,
  with no fade across a teleport. Fights never happen at night.
- One loop about 20 minutes (my call), the same for everyone in town in a server: morning is the longest stretch (comfiest to
  play in), then afternoon, then sunset, then a short blue night (about 2 minutes) lit by street lights, shop signs,
  portals and glowing mushrooms, then dawn back into morning.
- Each phase has its own sky, haze, bloom, colour grading and sun brightness, blending smoothly into the next.
- Shops stay bright and easy to read at every phase (raise interior light at sunset and night if needed).
- Starting values tested in Play on 2026-10-30 (the user saw these):
  - Afternoon: today's `Town.LIGHTING`.
  - Morning: ClockTime 7.3, Brightness 2.2, Exposure 0, Ambient (105,110,130), OutdoorAmbient (135,140,165), Atmosphere
    density 0.33 offset 0.12 haze 1.8 glare 0.5 colour (255,228,200) decay (170,195,235), Bloom 0.4 / 30 / 1.6,
    saturation 0.18, contrast 0.05, tint (255,246,236), SunRays 0.07 / 0.6.
  - Sunset: ClockTime 17.75, Brightness 2.6, Exposure 0.1, Ambient (125,95,100), OutdoorAmbient (155,115,115),
    Atmosphere density 0.3 offset 0.15 haze 1.5 glare 1.2 colour (255,175,125) decay (140,100,160), Bloom 0.5 / 32 /
    1.4, saturation 0.22, contrast 0.08, tint (255,230,212), SunRays 0.12 / 0.7. Seen facing the sun it looked best;
    seen away from the sun with heavier haze it went muddy brown.
  - Night: not tested yet.
- Constraint (my call): don't replicate per-frame lighting from the server. The server publishes the cycle's start
  time once; every client works out the phase from the server clock and blends locally, so it costs no network.
- The Frontier and Dungeon places keep their own lighting (TownService already skips the Frontier).

### Welcome cinematic

- Plays once per player, on their first visit, after their plot is claimed. Saving "seen it" changes the saved data
  shape: bump `SCHEMA_VERSION` (12 today), add a migration with a Lune test, update DESIGN 10.4 (CLAUDE.md rules).
- About 10-12 seconds. A skip button from the first frame (48 px or bigger). The HUD hides while it plays.
- The camera flies past Forest Falls, Frostpeak, over the plaza, past Ember Canyon, and lands at the player's own
  shop. The time of day runs as a time-lapse from morning to sunset over the flight, holding sunset the longest
  (roughly the last half). When it ends or is skipped, the town shows the server's real time of day and the camera
  returns to the player.
- Streaming is on in this place: request streaming around the flight path before it starts so nothing pops in.
- Studio-only dev commands (my call): `/intro` replays it, `/time <morning|afternoon|sunset|night>` jumps the cycle; both
  also as Admin panel buttons.

## Performance rules (measured 2026-10-30)

A Play-mode spike on PC (terrain grass over the town, a hill ring, a cliff with a waterfall, 6 big trees, 95 trees
swaying, 8 animals) added about 0.6 ms of render CPU and 0.1-0.45 ms of script time; the only real cost was memory (+80
MB for an oversized terrain fill of 420 x 360 studs plus 33 hills). A full-server stress test then showed shop screens
were the bottleneck (fixed: `Config/ShopDetail`); after the fix a full server runs at 10.2-12.3 ms render CPU and 60
fps on PC from the street, the empty town at 6.5-7.2 ms. Rules for this project:

- Budget: on the same full-server stress test plus all the new scenery, PC render CPU stays within +1.5 ms of the
  post-fix numbers and 60 fps at graphics levels 1 and 10; client memory grows by no more than about 50 MB (my call). Checked
  in Studio at level 1 plus the user's iPhone 16 Pro Max; that phone is high-end, so level 1 stands in for mid-range.
- Terrain only where players can see it, thin (no deep fills); backdrop shapes simple.
- One flowing waterfall (Forest Falls: a few scrolling beam sheets with a proper water texture, mist and splash
  emitters, a terrain water pool) and one frozen waterfall (Frostpeak: a static mesh or terrain ice, no animation).
- Giant trees are scaled copies of the existing tree models, so copies batch into one draw.
- Tree sway: one client controller, about 30 updates a second with `BulkMoveTo`, only trees within about 150 studs of
  the camera, off at low graphics.
- Animals: 3, client side, no Humanoid, animated only within about 120 studs.
- Butterflies and particle effects: few per area, only near the camera.
- Shadows off on small decor (flowers, clover, mushrooms, small rocks); world text (signs, arches) gets a draw
  distance like the shop screens.
- A frame watchdog on each client drops the sway, animals and butterflies first if frames run slow (Roblox doesn't
  tell a game which level "Automatic" graphics picked).
- New meshes: each under 2k triangles (DESIGN 10.5's prop rule); the town's 60k triangle total will need raising for
  the areas; the builder proposes the new number from the built result and records it in DESIGN 10.5.

## Constraints from the codebase

- Portal spots live in `Wild.PLAZA_PORTAL`, `Places.FRONTIER_PORTAL` and `Pvp.ARENA_PORTAL`. `Util/TownLayout` (pure,
  Lune-tested) uses them for the portal frames, the 10-stud clearance, the crosswalks and `portalPaths`; its tests
  will need updating for portals outside the island and for paths that follow trails.
- `TownService` builds the ground, decor, portal labels and portal effects and sets the lighting. `WildService`,
  `FrontierService` and `ArenaService` build the portal rings and their prompts.
- The hedge round the island is code-built (`TownLayout`) and needs gaps where the trails leave.
- `Workspace.TownDecor` (saved as `assets/town/TownDecor.rbxm`) and `Workspace.PlazaGarden` are hand-placed in Studio.
  The street-end decor (`StreetEndEast`, `StreetEndWest`, corner belts) sits where the trails start. The user agreed
  (2026-10-30) that the pieces in the trails' way may be **moved** (not deleted) through the Studio MCP, with
  screenshots before and after; the user then saves `TownDecor.rbxm`. Any other change to the place still needs asking
  first.
- Security (found by the design review): the server's `WildTravel` remote (`WildService`, around line 813) sends a
  player to the Wild from anywhere, with no distance check. Once the portals stand at the end of trails, walking there
  must be real: every portal travel remote checks the player is within reach of that portal (CLAUDE.md remote rules),
  and the same check applies to the Frontier and Arena portals if they have remotes.
- New models: scripted Blender builds (like `tools/blender/build_pack.py`) or Meshy through the Blender MCP. Meshy has
  a credit budget (memory `meshy-credit-budget`): ask before generating, get it right first time, character-style
  prompts don't apply to scenery but "no ground, no base" still does for props. Creator Store models must be stripped
  of scripts (the cherry trees came with backdoor scripts).
- Studio MCP: reading is fine anytime; ask before changing the place itself. Code lives only in the repo.
- Text: plain ASCII plus `·` and emoji; FredokaOne / Nunito via `Util/FontStyle`.
- Tunable numbers in `src/shared/Config`; pure rules in Roblox-free modules with Lune tests (cycle phase blending,
  trail paths, the walkable edge, the cinematic's timeline are good candidates).

## Left to the builder

- Exact area shapes, the trail curves, the walkable-edge outline and the portal spots (within the targets above).
- How the terrain is laid out and which terrain materials and colours each area uses (Sandstone only appears in the
  canyon, so its global terrain colour can be canyon red).
- Which pieces are Blender builds, Meshy models, Creator Store models or code-built parts.
- The water texture for the falls, the ember and snow effects, the aurora.
- The day cycle's exact phase lengths and the night's look (within the description above).
- The cinematic's exact camera path and timing (within the description above).
- Sign and arch wording details.

## Process

The usual workflow: a plan (superpowers:writing-plans), then build on a branch, Lune tests, Rojo sync, Studio checks
with screenshots, then the user judges in Studio. Show the user mockups or screenshots for every visual choice made
along the way.
