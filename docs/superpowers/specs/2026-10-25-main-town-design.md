# Main town and shop shells — design

World pass 1. Scope: the main game's town (street, plaza, decor, lighting) and the default look of the six shops.
Not in scope: the Wild map, the Frontier, the Arena, UI, plot expansions.

## Goals

- The main town looks like a cozy stylized village, not grey blocks on a baseplate.
- Every decoration is a **swappable prop**: a model file the owner saves into `assets/props/` replaces the
  code-built stand-in with no code change. A missing or broken file never breaks the town.
- Shops have walls, an open front, a striped awning and a roof, each plot in its own pastel colour.
- Phones stay smooth: props are light, decor never blocks shop systems.

## Decisions (agreed)

| Question | Decision |
|---|---|
| Art direction | Cozy stylized (Inno's Stylized Asset Pack outdoors) |
| Scope | Main town + default shop design only |
| Shop front | Open front: back and side walls, no front wall |
| Shop colours | Fixed pastel theme per plot (6 themes) |
| Build method | Code-built world, models swapped in by name |

## Props

`assets/props/<Name>.rbxm` syncs to `ServerStorage.PropModels` (server only: clients never need the source
models, and scripts there can't run). The owner saves models with Studio's Save to File, same as creatures.

Slots (names are the file names):

| Slot | Used for | Height (studs) | Collides |
|---|---|---|---|
| `Tree`, `TreeB`, `TreeC` | rows behind the shops, street ends | 18 / 16 / 20 | yes |
| `Bush` | plot gaps, plaza | 3 | no |
| `Flowers` | plaza beds, plot gaps | 1.5 | no |
| `Rock` | around portals, town edge | 3 | yes |
| `Crate`, `Barrel` | street side of plot gaps | 3 / 3.5 | yes |
| `Lamp` | street edges at the plot gaps | 12 | yes |
| `Bench` | around the spring | 3 | yes |
| `Fence` | one section; repeated along the back of each row | 4 | yes |
| `Portal` | frame around each plaza portal ring | 14 | no |
| `Shelf` | look of Products shelves inside shops | fits the shelf's size | n/a (hitbox part stays) |
| `Register` | sits on the register counter | 1.5 | no |

`src/server/Util/Props.luau`:

- `Props.place(name: string, at: CFrame, parent: Instance): Model` — clones `PropModels[name]`, or calls the
  slot's code-built fallback when the file is missing, has more than `Town.MAX_PROP_PARTS` (150) parts, or fails
  to clone.
- Placing a model: strip every script, sound, prompt, click detector and tool; scale with `Model:ScaleTo` so its
  bounding-box height equals the slot height (`Shelf` fits the shelf's size instead); pivot so its bounding-box
  bottom centre sits on `at`; anchor every part; set CanCollide from the slot; CanTouch off; CanQuery off for
  non-colliding props. `YawOffset` number attribute on the source model turns it (same as creatures).
- Fallbacks are simple part builds in the theme palette: trunk + ball tree, ball bush, flat flower disc, wedge
  rock, box crate, cylinder barrel, post + glowing head lamp, plank bench, post-and-rail fence, stone arch,
  shelf box, small register box.

`Config/Town.luau` holds every number: slot table above, palette, layout spacing, lighting, plot themes.

## Town layout

`src/shared/Util/TownLayout.luau` (pure, Lune-tested) turns `Config/Plots` + `Config/Town` + the portal and
spring spots into a list of `{ slot, x, z, yaw }`. TownService places each one. Layout (plots: 2 rows of 3, x
-68..68, z ±15..±55; street z -15..15):

- **Ground:** the place's `Baseplate` is recoloured to grass (no new ground part, so no z-fighting). Street:
  cobblestone strip x -100..100, z -15..15, 0.1 stud tall. Plaza: round stone pad, radius 14, around the spring.
  Paths: a short stone strip from the street to each portal.
- **Lamps:** both street edges (z ±13) at every plot gap and row end: x = -72, -24, 24, 72.
- **Plaza:** 4 benches at radius 10 facing the spring (45°, 135°, 225°, 315°), a flower bed beside each bench.
- **Plot gaps** (8 studs between plots): a bush halfway back; crate + barrel at the street end (z ±18).
- **Behind the rows:** fence along z ±60 for x -70..70; trees every 14 studs at z ±67, the three tree slots in turn.
- **Street ends:** 2 trees and a few rocks at each end, outside portal clearance.
- **Portals:** a `Portal` frame around each ring (Wild 84,0 · Frontier 84,-26 · Arena -84,0).

Layout rules (the Lune test checks each one):

1. Nothing inside a plot footprint (+1 stud margin), so shop placement and NPC paths never hit decor.
2. Only lamps sit in the street, and only within 3 studs of a plot front edge.
3. Nothing within `Town.PORTAL_CLEARANCE` (10) of a portal, except its frame.
4. Nothing within the spring's heal radius except plaza benches and flowers.
5. The output is the same every time (no randomness), so every server looks the same.

## Shop shells

PlotService builds a shell around each plot's 40×40 floor. Walls sit **outside** the floor edges, so the
placement grid, saved layouts and NPC paths are unchanged.

- **Walls:** back and both sides, `Town.WALL_HEIGHT` 12, 1 stud thick, theme wall colour, a trim strip along the
  top and a baseboard in the trim colour. Open front.
- **Front:** two corner pillars (trim colour). A striped awning across the front, sloping out 4 studs, stripes
  alternating theme awning colour and white. Code-built (no awning model).
- **Sign:** the shop sign moves from floating to a board on the awning's front, same text and rules.
- **Roof:** flat roof part over the floor, theme roof colour. The client hides your view of it (below).
- **Floor:** theme floor colour when owned; `Plots.FREE_COLOR` while for rent (the walls keep their theme).
- **Register:** the counter part stays (RegisterService uses it), coloured in the theme trim colour, with the
  `Register` prop placed on top.
- **Products shelves:** the shelf part stays as the hitbox (label, placement, customers), made invisible
  (Transparency 1, SurfaceGui label still shows), with the `Shelf` prop as a child Model. `positionShelf` moves
  the prop with the part. Card cases and the Condenser keep their current code-built look.

Themes (`Town.PLOT_THEMES`, by plot id): Mint, Peach, Lavender, Butter, Sky, Rose. Each has wall, trim, awning,
roof and floor colours. Pastel walls, a darker trim of the same hue, a white-striped awning.

## Roof hiding (client)

`TownController` (main game only): every `Town.ROOF_CHECK_SECONDS` (0.2) it finds the plot whose footprint holds
the local character, and sets that plot's roof `LocalTransparencyModifier` to 1 (others 0). The camera sees into
the shop you're in, and roofs show from the street. No remotes.

## Lighting

TownService sets, main game only: `ClockTime` 14.5, warm ambient, an `Atmosphere` (light haze), soft `Bloom`, a
`ColorCorrection` with slightly raised saturation. Values in `Town.LIGHTING`. Frontier lighting is unchanged.

## Start order

Main game: `PlotService.Start()` (shells) → … → `WildService.Start()` (plaza, spring, Wild portal) →
`ArenaService` → `FrontierService` (their portals) → `TownService.Start()` (ground, decor, portal frames,
lighting; reads portal and spring spots from config). Frontier place: TownService does not start.

## Performance

- Target: under 2k triangles per prop model, under 60k for the whole town; `MAX_PROP_PARTS` 150.
- About 90 props in total. All anchored; decor non-queryable; no scripts.
- StreamingEnabled stays on; nothing here needs to be streamed in early.

## Safety

- `tests/CreatureAssets.spec.luau` also scans `assets/props`: any script fails the suite.
- The server strips scripts from every prop it places, as a second layer.
- Licences: Inno's pack allows commercial use without credit; check every other model before launch.

## Testing

- Lune: TownLayout rules 1–5; the asset script gate on `assets/props`.
- Studio: walk the street (lamps, trees, benches, fence, portal frames); enter a shop (roof hides, walls and
  awning in its theme, register prop, shelf props); place, move and sell a Products shelf (prop follows, label
  shows, customers still buy); delete a prop file and Play (fallback appears); join with 2 players (both see the
  same town and their own plot themes).

## Docs

DESIGN.md section 3 (world layout) and 10.2 (files: Town config, TownLayout, Props, TownService,
TownController, `assets/props`); CLAUDE.md stack line for `assets/props`; `docs/props.md` with the slot table and
the save steps.
