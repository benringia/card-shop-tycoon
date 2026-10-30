# Town portals remodel: grown from their worlds

Status: approved by the user 2026-10-30 (concept A of three; concept sheets in the brainstorm companion,
`portal-concept-a.png`).

## Intent

The three town portals (Forest Falls → the Wild, Frostpeak → the Frontier, Ember Canyon → the PvP Arena) are one
dark store-bought stone frame, recoloured, about 14 studs tall. The user: "they look too ugly, their model is out of
place." After the Portal Worlds pass each portal stands at the end of its own trail in a dressed area (a waterfall,
a snowy rise with an aurora, a lava canyon), and the frame looks small and foreign there.

Each portal should look like it grew out of its own world, out of that world's raw material, with no stonework, and
be big enough to hold its own against the scenery. Success: walking up a trail, the portal reads as the doorway to
that world at a glance, and it is the thing you look at in the area.

## Goals

1. **Forest Falls (the Wild):** an arch of thick twisting tree roots growing out of the ground and meeting overhead,
   wrapped in moss, with hanging vines carrying small glowing flowers; a thin trickle of water running down one side
   into a little pool at its foot. A green and gold vortex fills the opening.
2. **Frostpeak (the Frontier):** a ring of jagged pale-blue ice crystals growing out of a snowdrift, icicles hanging
   from the top, snow caps on the crystals, frosty mist. A cyan and white vortex.
3. **Ember Canyon (the Arena):** an arch of black obsidian rock spikes with glowing orange lava cracks, lava dripping
   into a small molten pool at its base, embers floating up. A red and orange vortex.
4. About twice today's size: roughly 28 studs tall with an opening about 16 studs wide (the builder may tune within
   about ±15% so each fits its area).
5. The vortex is a spinning swirl in the world's colours filling the opening, so the portal reads as "magic doorway"
   from down the trail.

## Non-goals

- The other portals: the return portals inside the Wild, the Arena and the Frontier, the Dungeon's return portal and
  the boss gates stay as they are.
- How travel works: the prompt, its words, the travel remotes, blockers and reach (`Town.PORTAL_REACH`) are unchanged.
- The trails, signposts, trail arches, glowing paths and the floating names (other than raising the names above the
  bigger models).
- New sounds.

## Anti-goals (it fails even if it works)

- Pale colours. Pale ice and pale stone wash out to white under the town's sun (the fountain lesson): the ice must
  read clearly blue, the obsidian black-purple with bright lava, the roots warm brown with saturated moss green.
- A lookalike of a famous game's portal. In particular the Ember Canyon arch must not read as Minecraft's Nether
  portal: no rectangular black frame, no purple swirl. Irregular spikes, red and orange vortex.
- Stonework or carved, built-looking pieces (that was concept B; the user picked A).
- A portal that blocks the trail's end or swallows the prompt: players must still walk straight up and get the
  prompt as easily as today.
- Frame drops on phones: see Constraints.

## Constraints

- Repo rules (CLAUDE.md): tunable numbers in `src/shared/Config`, pure logic in Roblox-free modules with Lune tests,
  server authoritative, `--!strict`, DESIGN.md kept in sync in the same change.
- Model pipeline, as for the fountain (docs/props.md "The healing fountain"): a Python build script per portal in
  `tools/blender/` run through the Blender MCP, sources in `assets/blender/<Name>/` (.blend, .fbx, palette PNG), the
  user imports each FBX in Studio (default settings) and saves it as `assets/props/<Name>.rbxm`, Rojo syncs it into
  `ReplicatedStorage.PropModels`. Before committing a .blend: no raw `*_Src` objects, orphans purged, the scene's
  `blendermcp_*key*` / `*secret*` fields empty. No Meshy credits.
- Until a portal's model is saved, today's frame (the `Portal` prop) keeps standing there, so code and models can
  land separately.
- Style: the town's chunky stylized low-poly look (Inno's Stylized Asset Pack, the Blender fountain); flat colours
  from a palette texture; smooth, simple, readable shapes.
- Performance (DESIGN 10.5): each portal model at most about 4,000 triangles (an exception to the 2k-per-prop rule,
  as a landmark; record it in 10.5) and the town's 60k total still holds; at most 4 effects per portal (beams and
  particle emitters, the vortex included) plus one light, counted apart from the area's own cap of 4 (Claude's call:
  today's portal particles already sit outside it); anything that animates every frame (the vortex spin) runs on
  the client only near the camera with the extras on (`Util/Extras`, as `FountainFxController` does); each portal
  model streams Atomic. Budget: no measurable change on the street, under about 0.3 ms standing at a portal; measured
  before and after in one Studio session.
- Phones: the prompt stays reachable and tappable; the label stays readable.
- Mockups for every visual decision: a Blender render of each portal goes to the user before the FBX import step,
  and in-game screenshots after.

## Decided

- Concept A, "grown from its world", for all three (the user's pick).
- Built in Blender by script, not generated with Meshy (Claude's call, accepted with the description).
- The portal spots, their facing (back along the trail) and the travel rings' prompts stay where they are.
- The models don't collide, as today's frame doesn't (`Town` slot `Portal` has `collide = false`), so nobody climbs
  the roots or gets stuck in the ice (Claude's call).
- The vortex is a swirl image made like the rune circle (Figma image generator, light on black, uploaded through a
  localhost server) and spun on the client.
- Today's portal particles (`Town.PORTAL_EFFECTS`) are replaced by each world's effects, within the cap above.

## Left to the builder

- Model names, how the three models plug into the `Portal` prop slot (per-area variants or one slot per area), and
  how the old frame stays as the fallback.
- Exact shapes and proportions inside the goals, palette colours (bold mid tones), triangle split.
- How the vortex is drawn (an upright flat beam like the rune circle, a textured part, or a SurfaceGui) and how the
  travel ring part changes: it may become invisible and keep only the prompt, as long as the part keeps its name
  (TownService finds the rings by name) and the prompt keeps its reach.
- The world effects within the cap (for example: the water trickle as a scrolling beam with a splash; frost mist and
  drifting snow; lava drips as beams and an ember emitter), and which run on the server and which on the client.
- Moving area scenery (not the portal spots) that the bigger models would clip; the label height.
- Lune tests: at least the effect caps, the label above each model's top, and the old frame kept when a model is
  missing; the existing script gate already covers `assets/props`.
