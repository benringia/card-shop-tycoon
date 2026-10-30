# Ember Canyon becomes a caldera

Status: approved by the user 2026-10-31 (concept A "Glowing fissures" of three; concept pictures in the brainstorm
companion, `caldera-a.png`).

## Intent

Ember Canyon, the walk-to area in front of the PvP Arena portal (west of town, the portal at -205, 0), is still a red
desert canyon: sand, striped sandstone walls, green cacti. Since the portals remodel its portal is a black-purple
obsidian arch with lava, the only volcanic thing in the area. The user wants the area to match it: a volcanic caldera in
the portal's black-purple and orange, with a volcano in the background.

Concept A is calm and moody: the glow comes from cracks everywhere, in the cliffs and the ground, and the volcano behind
is quiet, a glowing crater and a smoke plume. Success: walking down the trail, the area reads as a caldera at a glance,
its colours one family with the portal, and the volcano is a landmark you can see over the cliffs, from the town too.

## Goals

1. **Cliffs:** the canyon's walls and end wall become dark basalt instead of striped sandstone; their rims read as
   jagged rock, not rounded bumps.
2. **Glowing cracks:** branching glowing orange cracks down the cliff faces and across the ground (terrain can't glow,
   so they are glowing strips laid on the surfaces).
3. **Ground:** dark cracked rock instead of sand; the trail through the canyon dark too (it keeps its red glowing line).
4. **Life:** the cacti become charred dead trees; a few small clusters of black-purple obsidian shards like the portal's.
5. **Lava:** the river along the south wall and the pool behind the portal stay, glowing hotter.
6. **Volcano:** a big chunky low-poly volcano well behind the canyon's end wall, about 120 studs tall so it rises over
   the cliffs and shows from the town street, with a glowing lava crater, a couple of glowing streaks down its side and a
   slow smoke plume.

## Non-goals

- The portal, its torches' place, the trail's route, the walkable floor (`Town.WALK_EDGE`), arena travel.
- Lighting: the town's day cycle and look stay as they are (a warmer haze only inside the canyon would need area-based
  lighting, a separate job).
- New sounds (the embers' fire sound stays).
- The other areas.

## Anti-goals

- Anything left reading as desert: sand colour, sandstone stripes, green cacti.
- Pale or washed-out darks: the basalt must read dark charcoal under the town's bright sun, and the obsidian
  black-purple, not bright purple (the portal lesson).
- An erupting, busy volcano: concept A's volcano is quiet (the user picked it over B's eruption and lavafalls).
- Frame drops or terrain memory growth: see Constraints.

## Constraints

- Repo rules (CLAUDE.md): numbers in `src/shared/Config` (`Config/Scenery`), pure logic in Roblox-free modules with Lune
  tests, DESIGN.md kept in sync.
- Terrain stays within `Scenery.MAX_CELLS` (Lune-tested); the volcano is a mesh, not terrain (terrain that size would
  cost tens of MB).
- At most 4 area effects in Ember Canyon (Lune-tested): today embers, pool bubbles and river flow; the volcano's smoke
  is the fourth.
- Blender models as for the portals (docs/props.md): a script per model in `tools/blender/` on `portal_kit.py` /
  `voxel_kit.py`, sources in `assets/blender/<Name>/`, the user imports and saves each to `assets/props/<Name>.rbxm`;
  the script gate test applies; .blend secret fields checked before committing. No Meshy credits. Under 2,000 triangles
  per small prop; the volcano is a landmark (up to 4,000, like the portals).
- Scenery props clear of the trails and the portal (`Town.PORTAL_SCENERY_CLEAR`, Lune-tested).
- Mockups: Blender renders before export, in-game screenshots after; the user judges the look.

## Decided

- Concept A (the user's pick).
- Terrain material and colour changes for cliffs and ground; the glowing cracks as code-built glowing strips from a
  tested pattern (Claude's call, accepted with the description).
- The volcano, the charred tree and the obsidian shard cluster built in Blender (Claude's call, accepted).
- The torch pillars stay, re-coloured dark (Claude's call, accepted).

## Left to the builder

- Which terrain materials and colours give dark basalt cliffs and dark cracked ground (Roblox's Basalt, CrackedLava,
  Rock ...; colours are per material across the whole map, so only materials no other area uses may change colour, or a
  material another area uses must keep its colour).
- The crack pattern: how it branches, how many strips (keep the part count modest), where they run, their glow.
- Where the volcano stands and how big exactly, so it shows over the end wall from the trail and from the street without
  crowding the portal.
- Charred tree and shard cluster shapes, how many and where (in the cacti's old spots and along the walls).
- The trail surface material inside the canyon.
- Lune tests: at least the crack pattern staying on its surfaces and clear of the trail and portal, the effect and
  terrain caps (existing tests), the props clear of the trails (existing test).
