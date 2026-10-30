# Town Portals Remodel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three town portals' store-bought frame with three Blender-built portals that grow out of their
worlds (a root arch, an ice-crystal ring, an obsidian-and-lava arch), each with a spinning vortex and its world's
effects, the old frame standing in until a model is saved.

**Architecture:** Three new prop slots (`PortalWild`, `PortalFrontier`, `PortalArena`) with models built by Python
scripts in Blender and saved by the user into `assets/props`. A pure module (`Util/PortalLooks`) decides which slot
stands at each portal, the label height and which effects a model can carry; a server util (`Server/Util/PortalBuild`)
dresses a placed model from named parts in it (vortex beam, glow, world effects, light, Atomic streaming, a tag); a
client controller spins the vortex near the camera. TownService swaps the slot at placement and keeps today's path
for the fallback frame.

**Tech Stack:** Luau (Rojo), Lune tests, Blender 5.2 through the Blender MCP (`voxel_kit.Builder`), Figma image
generator for the vortex texture, Roblox Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-10-30-town-portals-design.md`

## Global Constraints

- Concept A for all three: made of the world's raw material, no stonework or carved pieces.
- About 28 studs tall with an opening about 16 wide (±15% per portal to fit its area).
- Bold mid-tone colours; ice clearly blue, obsidian black-purple with bright lava, roots warm brown, moss saturated green.
- Ember Canyon must not read as Minecraft's Nether portal: no rectangular black frame, no purple swirl.
- At most about 4,000 triangles per portal model; at most 4 effects (beams + emitters, the vortex included) and one
  light per portal, counted apart from the area's cap; the vortex spin runs on the client only, near the camera, with
  the extras on; each portal model streams Atomic.
- Budget: no measurable change on the street, under about 0.3 ms at a portal, measured before and after in one session.
- The models don't collide. Portal spots, facing, prompts, travel and `Town.PORTAL_REACH` are unchanged.
- Unchanged: the return portals inside the Wild, Arena and Frontier, the Dungeon's return portal, the boss gates.
- Until a portal's model is saved, today's `Portal` frame stands there with today's effects.
- Blender: a script per portal in `tools/blender/`, sources in `assets/blender/<Name>/`, no `*_Src` objects, orphans
  purged, the scene's `blendermcp_*key*` / `*secret*` fields empty (print lengths only) before committing a .blend.
  No Meshy credits.
- Repo rules: numbers in `src/shared/Config`, pure modules Lune-tested (no `script`, no sibling requires, plain data
  configs), `--!strict`, every world GUI has a MaxDistance, DESIGN.md / docs / CLAUDE.md updated in the same change.
- The user sees a Blender render of each portal before the FBX export, and in-game screenshots after.

## Review Focus

1. A saved model missing a named part (say `Fx_Pool`): the portal still builds, that effect is skipped with one warn
   (Task 1 test "effects skip spots the model lacks"; Task 6 uses `PortalLooks.effectsFor`).
2. Only one or two of the three models saved: each portal picks its own model or the old frame independently
   (Task 1 test "each portal falls back on its own").
3. Walking up the trail: the prompt still appears where it does today, with the ring hidden (Task 8 Studio check).
4. Extras off or low graphics: the vortex shows, standing still (Task 7 Studio check).
5. Joining far away at the plot: the portals stream in later and their vortex still spins (Task 7 Studio check).

---

### Task 1: Portal looks config and the pure rules

**Files:**
- Modify: `src/shared/Config/Town.luau` (SLOTS, new PORTAL_LOOKS and PORTAL_FX)
- Create: `src/shared/Util/PortalLooks.luau`
- Create: `tests/PortalLooks.spec.luau`; Modify: `tests/run.luau`, `CLAUDE.md` (test list)

**Interfaces:**
- Produces (config): `Town.SLOTS.PortalWild / PortalFrontier / PortalArena = { height = 28, collide = false }`;
  `Town.PORTAL_LOOKS` keyed like `PORTAL_AREAS[i].effect` (`"Wild" | "Frontier" | "Arena"`; today's
  `PORTAL_EFFECTS` stays for the fallback frame, the trail arches and the glowing paths); `Town.PORTAL_FX = { MAX_EFFECTS = 4,
  SPIN_RANGE = 150, LABEL_GAP = 3, VORTEX_TEXTURE = "" }` (texture set in Task 2);
  `Town.PORTAL_LOOKS[key] = { slot, vortex = { colors = {rgb, rgb}, spin = degrees/s, transparency }, light = { color,
  brightness, range }, glow = { [partName] = rgb }, effects = { Effect } }` where
  `Effect = { kind = "beam", from = part, to = part, texture, width, speed, color }` or
  `{ kind = "emitter", at = part, texture, rate, lifetime, speed, size, rise, spin, transparency?, colors? }`
  (emitter fields as today's `PORTAL_EFFECTS` emitters).
- Produces (pure): `PortalLooks.slot(look: string, town: any, hasModel: (slot: string) -> boolean): string`;
  `PortalLooks.labelHeight(slot: string, town: any): number`; `PortalLooks.effectCount(look: any): number`
  (effects + 1 for the vortex); `PortalLooks.parts(look: any): { string }` (sorted: `Frame`, `Opening`, every
  effect's `from`/`to`/`at` except `Opening`, every glow part); `PortalLooks.effectsFor(look: any, has: (part:
  string) -> boolean): { any }` (the effects whose spots all exist).
- Part names the Blender tasks must produce: all: `Frame`, `Opening`. Wild: `Fx_Trickle`, `Fx_Pool`, `Pool`,
  `Flowers`. Frontier: `Fx_Base`. Arena: `Fx_DripA`, `Fx_DripB`, `Fx_Pool`, `Lava`.

- [ ] **Step 1: Write the failing tests** in `tests/PortalLooks.spec.luau` (load Town and PortalLooks by path like
  `tests/PlazaLayout.spec.luau`):
  - `"each portal falls back on its own"`: with `hasModel = function(s) return s == "PortalFrontier" end`,
    `slot("Wild") == "Portal"`, `slot("Frontier") == "PortalFrontier"`, `slot("Arena") == "Portal"`.
  - `"the old frame never picks up the new models"`: `TownLayout.isVariant("Portal", "PortalWild", town.SLOTS) ==
    false` and `TownLayout.isVariant("PortalWild", "PortalWild", town.SLOTS) == true` (same for the other two).
  - `"labels float above whichever model stands"`: `labelHeight("Portal") == 14 + 3`, `labelHeight("PortalWild") ==
    28 + 3`.
  - `"each portal keeps to 4 effects"`: for every look, `effectCount(look) <= town.PORTAL_FX.MAX_EFFECTS`.
  - `"new portal slots don't collide and stand about 28 tall"`: each look's slot exists in SLOTS, `collide == false`,
    `24 <= height <= 32`.
  - `"each look names the parts its model must have"`: `parts(Wild)` equals `{ "Flowers", "Frame", "Fx_Pool",
    "Fx_Trickle", "Opening", "Pool" }`; Frontier `{ "Frame", "Fx_Base", "Opening" }`; Arena `{ "Frame",
    "Fx_DripA", "Fx_DripB", "Fx_Pool", "Lava", "Opening" }`.
  - `"effects skip spots the model lacks"`: `#effectsFor(Arena, has-all-but-Fx_DripB) == #Arena.effects - 1`.
  - `"every portal area has a look"`: each `PORTAL_AREAS[i].effect` is a key of `PORTAL_LOOKS`.
- [ ] **Step 2: Run** `lune run tests/run PortalLooks` (after adding `PortalLooks = require("./PortalLooks.spec")` to
  `tests/run.luau`). Expected: FAIL, module not found.
- [ ] **Step 3: Implement** the config and `src/shared/Util/PortalLooks.luau` (pure, no requires). Effects:
  - Wild: beam `Fx_Trickle`→`Fx_Pool` (texture `rbxassetid://139671283074387`, width 0.9, speed 1.5, colour
    {120, 220, 255}); emitter at `Fx_Pool` (splash: sparkles, rate 8, lifetime {0.6, 1}, speed {1, 2}, size
    {0.6, 0}, rise -6, spin 90); emitter at `Opening` (today's Wild sparkle motes). Light {140, 235, 110},
    brightness 2, range 24. Glow `Pool` {90, 220, 210}, `Flowers` {255, 215, 90}. Vortex colours {120, 230, 90} →
    {255, 215, 90}, spin 30.
  - Frontier: emitter at `Fx_Base` (mist: smoke_main, rate 3, lifetime {3, 4}, speed {0.2, 0.6}, size {4, 7}, rise
    0.2, spin 20, transparency {0.8, 1}, colours pale cyan {200, 240, 255}); emitter at `Opening` (today's Frontier
    falling sparkles). Light {110, 200, 255}. Vortex {70, 200, 255} → {235, 250, 255}, spin 25.
  - Arena: beams `Fx_DripA`→`Fx_Pool` and `Fx_DripB`→`Fx_Pool` (same texture, width 0.6, speed 0.8, colour
    {255, 120, 30}); emitter at `Fx_Pool` (today's Arena rising embers). Light {255, 120, 50}. Glow `Lava`
    {255, 110, 30}. Vortex {255, 70, 30} → {255, 200, 80}, spin 35.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass (554 + the new ones).
- [ ] **Step 5: Commit** `git commit -m "Portals: looks config and PortalLooks rules (slot fallback, labels, effect caps)"`

### Task 2: The vortex texture

**Files:** Create: `assets/ui/fx/portal-vortex.png`; Modify: `src/shared/Config/Town.luau` (`PORTAL_FX.VORTEX_TEXTURE`)

- [ ] **Step 1:** Generate with Figma (`generate_image`, file `rd1ves753oagkIGEJgV4qC`, `gemini-3.1-flash-image`,
  1024 x 1024): a flat front-on swirling magic vortex, bright white-to-light-grey spiral arms on pure black, perfectly
  centred and round, soft glow, nothing outside the circle, no text. Save as `assets/ui/fx/portal-vortex.png` (at most
  1024 px).
- [ ] **Step 2:** Upload (serve `assets/ui/fx` with `python -m http.server 8765 --bind 127.0.0.1`, Studio
  `upload_image` with the localhost URL, stop the server). Expected: an asset id.
- [ ] **Step 3:** Set `PORTAL_FX.VORTEX_TEXTURE = "rbxassetid://<id>"`; `lune run tests/run` passes.
- [ ] **Step 4: Commit** `git commit -m "Portals: the vortex swirl texture"`

### Task 3: Blender kit and the Forest Falls portal (PortalWild)

**Files:**
- Create: `tools/blender/portal_kit.py`, `tools/blender/build_portal_wild.py`
- Create (output): `assets/blender/PortalWild/{PortalWild.blend, PortalWild.fbx, PortalWild_palette.png}`

**Interfaces:**
- Produces: `portal_kit.tube(b, points, radii, color, sides=7)` (a tapered tube through points, for roots and vines),
  `portal_kit.crystal(b, base, direction, radius, length, color, sides=6)` (a faceted prism with a pointed tip),
  `portal_kit.marker(name, location)` (a 0.2-stud cube object), `portal_kit.export(name, objects, colors)` (the
  fountain's run/export block: links objects, one palette material, prints triangles per object and in total, asserts
  total <= 4000, saves .blend and FBX to `assets/blender/<name>/` unless `EXPORT=0`). All on `voxel_kit.Builder`.
- Conventions: Z up, 1 unit = 1 stud, origin at the bottom centre, the portal's front (the side players walk up to)
  faces **-Y** (it imports facing -Z, the props' front). `Opening` is a flat 12-sided disc in the XZ plane at the
  opening's centre sized to the opening.

- [ ] **Step 1:** Write the kit and the script: 6-8 roots (tubes, radius 1.6 → 0.5) rising from both sides and
  twisting over to meet at about 26 studs; moss blobs on the roots; 5-7 hanging vines (thin tubes) with small
  flowers (part `Flowers`); a thin water ribbon is the beam (no mesh), so `Fx_Trickle` sits where it leaves a root at
  about 20 studs on the +X side and `Fx_Pool` at the centre of a small pool disc (part `Pool`, radius about 3) at the
  foot of that side; `Opening` about 16 wide, centred about 11 up. Palette: warm browns, two saturated moss greens,
  flower gold and pink.
- [ ] **Step 2: Run** in Blender with `EXPORT=0`. Expected: prints parts `Frame, Opening, Fx_Trickle, Fx_Pool, Pool,
  Flowers` and total triangles <= 4000.
- [ ] **Step 3:** Render (`look`, front three-quarter and side) and show the user beside concept A's left panel.
  Rework until they're happy (each round: render, show).
- [ ] **Step 4:** Commit the scripts only (export comes in Task 6):
  `git commit -m "Portals: Blender kit and the Forest Falls root arch"`

### Task 4: The Frostpeak and Ember Canyon portals (PortalFrontier, PortalArena)

**Files:** Create: `tools/blender/build_portal_frontier.py`, `tools/blender/build_portal_arena.py` and their
`assets/blender/<Name>/` outputs.

**Interfaces:** Consumes `portal_kit` (Task 3); part names from Task 1.

- [ ] **Step 1:** Frontier: 14-20 jagged ice crystals (`crystal`, 3-4 blues from deep to bright, never near-white)
  growing round a ring out of a snowdrift (squashed blobs, pale blue-grey snow, not white), icicles hanging inside the
  top, snow caps on the upper crystals; `Fx_Base` at the drift's front centre; `Opening` round, about 16 across,
  centred about 12 up.
- [ ] **Step 2:** Arena: 10-14 black-purple obsidian spikes (`crystal` with 5 sides) leaning into an irregular pointed
  arch (not rectangular), lava cracks as thin bright-orange strips on the spikes and two lava streams down the front
  faces into a molten pool at the foot (all one part `Lava`); `Fx_DripA`/`Fx_DripB` at the top of each stream,
  `Fx_Pool` at the pool's centre; `Opening` about 16 wide, centred about 11 up.
- [ ] **Step 3: Run** each with `EXPORT=0`. Expected: the Task 1 part names, total triangles <= 4000 each.
- [ ] **Step 4:** Render both and show the user all three side by side. Rework until approved.
- [ ] **Step 5: Commit** `git commit -m "Portals: the Frostpeak ice ring and the Ember Canyon obsidian arch"`

### Task 5: Dressing the portals on the server

**Files:**
- Create: `src/server/Util/PortalBuild.luau`
- Modify: `src/server/Services/TownService.luau` (buildDecor, buildPortalLabels, buildPortalEffects, PORTAL_LABELS)

**Interfaces:**
- Consumes: `PortalLooks.slot/labelHeight/effectsFor` (Task 1), `Town.PORTAL_LOOKS`, `Town.PORTAL_FX`.
- Produces: `PortalBuild.dress(model: Model, look: any)`: hides `Opening` and every `Fx_*` part (Transparency 1, no
  collide/query/touch); glow parts become Neon in their colour (texture and SurfaceAppearance removed, as
  `BloomFountain.glowing`); a part named `Vortex` (invisible, anchored, no collide/query/touch) with
  `CFrame.lookAt(opening.Position, opening.Position + model:GetPivot().LookVector)` (it faces down the trail, like
  the prop) holding one beam: attachments at local (±opening width / 2, 0, 0) with default orientation (their up
  axis is the part's Y, world up at rest), FaceCamera off, Width0 = Width1 =
  the opening's height, Segments 1, TextureMode Stretch, `VORTEX_TEXTURE`, LightEmission 1, LightInfluence 0, colour
  from `vortex.colors`, transparency `vortex.transparency`; the look's PointLight on `Vortex`; each of
  `effectsFor(look, has)` (beams with both ends' attachments up-axis world up, FaceCamera on, scrolling; emitters on
  their part); `model.ModelStreamingMode = Atomic`; tag `"TownPortal"`. Missing parts: one warn per portal, never an
  error. `PortalBuild.emitter(spec: any, colors: { { number } }, parent: BasePart): ParticleEmitter` (moved out of
  TownService's buildPortalEffects, used by both paths).
- TownService: a `Portal` placement becomes `PortalLooks.slot(entry.effect, Town, Props.hasModel)`; a new slot gets
  `PortalBuild.dress`, the frame keeps `tintGlow`; buildPortalEffects keeps today's ring tint and emitters only for
  frame portals and, for new ones, sets the ring part's Transparency to 1 (its prompt stays); labels at
  `labelHeight(chosen slot)`.

- [ ] **Step 1:** Implement both files. Compile check: `lune run "$TEMP/lc/check2.luau" src/server/Util/PortalBuild.luau
  src/server/Services/TownService.luau`; `lune run tests/run` (SourceOrder included) passes.
- [ ] **Step 2: Studio check, fallback** (Play, no portal model saved yet): the three portals look exactly as today
  (frames, ring tint, emitters, labels at 17), Output clean. This is the "model missing" path.
- [ ] **Step 3: Commit** `git commit -m "Portals: TownService dresses the new models (vortex, glow, effects, labels)"`

### Task 6: Export, the user's import and the first look in game

**Files:** `assets/blender/Portal{Wild,Frontier,Arena}/*`; `assets/props/Portal{Wild,Frontier,Arena}.rbxm` (user);
Modify: `tests/CreatureAssets.spec.luau`

- [ ] **Step 1: Write the test** (it passes while no portal file exists and guards the import) in
  `tests/CreatureAssets.spec.luau`: `"portal models carry the parts the
  game dresses"`: for each `Town.PORTAL_LOOKS` look whose `assets/props/<slot>.rbxm` exists, the file's model is
  named `<slot>` and has a MeshPart for every name in `PortalLooks.parts(look)`. Missing files pass (the frame stands in).
- [ ] **Step 2:** Run all three scripts with `EXPORT=1`; delete `*_Src` objects, purge orphans, check the secret fields'
  lengths are 0; commit the three source folders.
- [ ] **Step 3:** Ask the user to import the three FBX files (Import 3D, default settings) and say when they're in.
  Check in Edit: each model's part names; no scripts; `PrimaryPart` nil. Then ask the user to **Save to File** each
  as `assets/props/<Slot>.rbxm` and delete the Workspace copies.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: pass, the new test reading three files.
- [ ] **Step 5: Studio check** (Play): each portal stands its new model at the right spot and height (the Frontier one
  on the rise at y 10), facing down its trail; vortex filling the opening; water trickle into the pool, mist, lava
  drips and embers; glow; light; label above the top; ring hidden; Output clean. Screenshot each from the trail end
  for the user.
- [ ] **Step 6: Commit** `git commit -m "Portals: the three models in PropModels"`

### Task 7: Spinning the vortex on the client

**Files:** Create: `src/client/Controllers/PortalFxController.luau`; Modify: `src/client/init.client.luau` (main
place only, after FountainFxController).

**Interfaces:** Consumes the `"TownPortal"` tag and the `Vortex` part (Task 5), `Town.PORTAL_LOOKS[...].vortex.spin`
(find the look by the model's name = slot), `Town.PORTAL_FX.SPIN_RANGE`, `Util/Extras`.

- [ ] **Step 1:** Implement: on tag added, remember the Vortex part's rest CFrame; on RenderStepped, for each portal
  within SPIN_RANGE of the camera with `Extras.enabled()`, set `Vortex.CFrame = rest * CFrame.Angles(0, 0,
  rad(spin * now))`, a turn about its own look axis, which faces down the trail (the attachments turn with it); otherwise leave it at rest;
  drop it on tag removed (streamed out).
- [ ] **Step 2: Studio check:** near a portal the swirl turns; with extras off it stands still and still shows;
  joining at the plot (far away), walking to a portal, it turns once streamed in. Output clean.
- [ ] **Step 3: Commit** `git commit -m "Portals: the vortex spins near the camera"`

### Task 8: Fitting the areas and the walk-up check

**Files:** Modify: `src/shared/Config/Scenery.luau`, `tests/TownTerrain.spec.luau`, `src/shared/Config/Town.luau`
(`PORTAL_SCENERY_CLEAR`)

- [ ] **Step 1: Write the failing test:** in `"props stand clear of every trail and portal"`, replace `toPortal >= 6`
  with `toPortal >= town.PORTAL_SCENERY_CLEAR` (new, 13 studs: half the widest model plus 2). Run: fails on the
  Arena torches at (-203, ±11).
- [ ] **Step 2:** Move the torches to z ±15 and anything else the test names; remove Ember Canyon's round stone
  `PLATFORM` and its build in the scenery code (stonework under a natural obsidian arch with its own lava pool; drop
  its "walkable" assertion; ledger it as a ruling and point it out with the screenshots). Run `lune run tests/run`:
  passes.
- [ ] **Step 3: Studio check:** walk each trail to its portal: the prompt appears as before, nothing clips the models
  (pool, waterfall, rise edge, canyon walls), the label reads on a phone (Device emulator, landscape). Screenshots of
  all three for the user.
- [ ] **Step 4: Commit** `git commit -m "Portals: area scenery clears the bigger portals"`

### Task 9: Performance and docs

**Files:** Modify: `DESIGN.md` (portal areas, 10.5 budget, file tree), `docs/props.md`, `CLAUDE.md` (assets list),
the Obsidian vault.

- [ ] **Step 1: Measure** in one Studio session (the method of 2026-10-30: copies of Plot1's shelves in plots 2-6, 5
  avatar clones, Scriptable cameras STREET `(-125,35,0)→(60,4,0)` and at each portal's trail end, Level01 and Level10,
  `Stats.RenderCPUFrameTime` × 1000 over 2 s): with the new portals, then with the `TownPortal` models parented to nil
  on the client. Expected: street within noise, at a portal under +0.3 ms.
- [ ] **Step 2:** Docs: DESIGN (the three portals, their parts, the 4k-triangle landmark exception and the numbers in
  10.5, file tree), docs/props.md (rebuilding a portal: script, import, part names), CLAUDE.md assets line, Obsidian
  (Town design note, Decisions log, Lessons learned).
- [ ] **Step 3:** `lune run tests/run` and `rojo build -o "$TEMP/test.rbxl"` pass.
- [ ] **Step 4: Commit** `git commit -m "Portals: performance measured, docs"`
