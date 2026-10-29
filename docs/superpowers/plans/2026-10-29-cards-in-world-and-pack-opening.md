# UI Project 3: Cards in the World and the 3D Pack Opening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real 3D packs on shelves (open display boxes), spinning upright cards in the glass cases, and a 3D pack
opening (cinematic tear, cards stacking one by one, flips with living hit cards, a snappy sparkling results lineup)
with Blender-made effects and sounds.

**Architecture:** Blender scripts build the pack, deck box and display box meshes, their textures and the effect
flipbooks; the user imports the meshes into `ReplicatedStorage.PackModels`. The server builds shelf stock from those
models. Cases keep their server card parts; each client spins its own. The opening becomes a client-only 3D stage
(the binder's pattern: far-off parts, a Scriptable camera), split into small modules driven by a pure state machine.
Pure rules (shelf fill, case layout, reveal plans, opening flow and layout) live in Roblox-free modules with Lune
tests.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests, Blender 5.2 through the Blender MCP, Pillow, the Roblox
Studio MCP (Play checks, `upload_image`, `search_asset`).

**Spec:** `docs/superpowers/specs/2026-10-29-cards-in-world-and-pack-opening-design.md` (approved 2026-10-29). Visual
reference: `.superpowers/brainstorm/3177-1793255093/content/rip-preview-v1.html` (the approved timing) and
`combined-v1.html` (shelves and cases). Preview scripts to start from (session scratchpad,
`C:\Users\Ben\AppData\Local\Temp\claude\c--Users-Ben-Documents-roblox-project-card-shop-tycoon\795b51b0-6698-46bf-936f-7c1b6ff1c071\scratchpad\pack\`):
`build_pack.py`, `make_texture.py`, `build_vfx.py`, `make_sheets.py`, `pack_vfx_preview.blend`.

## Global Constraints

- Server authoritative; pack rolls stay on the server. Remotes unchanged: `RipPack`, `PackOpened` (productId, results
  { cardId, foil, grade }, newFlags), `PullRevealed`. `Packs.RIP_COOLDOWN` unchanged. No saved-data change, no schema bump.
- All tunable numbers in `src/shared/Config`. Pure rules in Roblox-free `src/shared/Util` modules with Lune tests,
  listed in `tests/run.luau` and in CLAUDE.md's test list. Lune has no Vector3 / Color3: numbers a test reads live in
  plain-data config modules (`Config/CaseLayout`, `Config/PackOpeningLayout`, `Config/CardReveal`, `Config/PackFx`).
- `--!strict`; no file over 200 locals in one scope (split modules); SourceOrder test (no local used above its
  definition).
- UI: mobile-first, 48 px tap targets, FredokaOne / Nunito Bold, plain ASCII plus `·` and emoji in text, UIKit for GUI,
  HUD through `Util/Hud`.
- Cases keep their grid footprint (`Shelves` size 6 x 4 x 2).
- Uploaded images are capped at 1024 x 1024: flipbook sheets at most 1024 px; flipbooks are 2 x 2, 4 x 4 or 8 x 8.
- Studio MCP: reading the place is fine; ask the user before changing the place itself. Scripts live in the repo.
- Blender files: delete raw source objects and purge orphans before saving to git; print the lengths of any
  `blendermcp_*key*` / `*secret*` scene fields and commit only if they are empty. Never print keys.
- Anti-goals from the spec: no look copied from TCG Cardshop; Commons stay quick (no tease, short flips); no
  emoji-like confetti; a revealed card never shows its back; phones cut effects, never motion; shelves stay cheap.
- Approved timings (preview): tear push 1.28x in 0.52 s, strip parts 0.7 s, snap 0.52 s, flash 0.38 s, shake 0.34 s,
  ease back 0.46 s; each card stacks in 0.19 s; Common lift 0.08 s + flip 0.23 s, teased flip 0.38 s; stow 0.22 s;
  results flight 0.22 s with the next leaving 0.085 s later; tease lengths from `Config/CardReveal`.

## Review Focus

1. Taps while the tear, the stacking or a big flip's spotlight is playing must do nothing (a double tap must not skip
   a Legendary). Pinned by OpeningFlow tests (Task 7).
2. Odd stock counts (23 of 24 packs, 1 of 96) and a product switch on a shelf: the right boxes show the right fill,
   any stock shows at least one pack, old boxes go. Pinned by ShelfStock.boxFill tests (Task 4) and the Studio check
   in Task 5.
3. The smallest phone (568 x 320, top bar inset) must fit the row and the results lineup. Pinned by OpeningLayout
   tests (Task 7).
4. A fight, death or respawn during an opening must close it and give the camera back (the binder's rule). Studio
   check in Task 10.
5. A case card re-listed, re-priced or removed while spinning: the spin drops destroyed parts and picks up new ones,
   prompts still work. Studio check in Task 6; the layout is pinned by ShowcaseLayout tests (Task 4).

---

### Task 1: The pack, deck box and display box in Blender

**Files:**
- Create: `tools/blender/build_pack.py` (from the preview's `build_pack.py`: body + strip, `detail="High"|"Low"`)
- Create: `tools/blender/build_deckbox.py` (box + lid, set art on the front, gold lid band)
- Create: `tools/blender/build_displaybox.py` (cardboard tray, front panel and flipped-up lid with the pack art, plus
  `Packs1` .. `Packs6`: rows of 1..6 low packs merged into one mesh each)
- Create: `tools/textures/make_pack_textures.py <art.jpg> <font.ttf> <out_dir> <set name>` (from `make_texture.py`:
  `Pack.png` front|back 2048 x 1600 → also writes a 1024 x 800 copy for upload, `DeckBox.png`, `DisplayBox.png`)
- Create: `assets/blender/Pack/` (Pack.blend, Pack.fbx, DeckBox.fbx, DisplayBox.fbx, the PNGs)

**Interfaces:**
- Produces: FBX meshes named `Body`, `Strip` (Pack, High), `BodyLow` (Pack, Low), `Box`, `Lid` (DeckBox), `Tray`,
  `Packs1`..`Packs6` (DisplayBox); textures per look `FirstSpark`.

- [ ] **Step 1:** Copy the preview scripts into `tools/blender/` and `tools/textures/` and give them arguments instead
  of scratchpad paths (font: Fredoka variable font, OFL, downloaded by the user into `tools/textures/fonts/` and
  git-ignored; the script prints how to fetch it if missing).
- [ ] **Step 2:** Add the Low detail (target 300-600 triangles, crimps as a flat strip with the ridge texture, no
  wrinkles) and keep High at 3,000-5,000 triangles (decimate the preview's 9,000).
- [ ] **Step 3:** Build the deck box (today's look: purple box, art front, gold lid band) and the display box (tray
  1.0 x 0.55 x 0.6 in pack units with the lid hinged back about 110°, the printed front "FIRST SPARK · 24").
- [ ] **Step 4:** Run in Blender through the MCP; `look` each model; print triangle counts.
  Expected: Pack High 3k-5k, Pack Low ≤ 600, DeckBox ≤ 800, Tray ≤ 400, each `PacksN` ≤ 250 × N.
- [ ] **Step 5:** Export one FBX per model (Y up, apply transforms, meshes only); purge orphans; check the scene's
  `blendermcp_*key*` / `*secret*` fields are empty (print lengths only); save `Pack.blend`.
- [ ] **Step 6: Commit**
```bash
git add tools/blender/build_pack.py tools/blender/build_deckbox.py tools/blender/build_displaybox.py tools/textures/make_pack_textures.py assets/blender/Pack .gitignore
git commit -m "Pack models: 3D booster pack, deck box and display box built in Blender"
```

### Task 2: PackModels in Studio

**Files:**
- Create: `assets/packs/Pack.rbxm`, `assets/packs/DeckBox.rbxm`, `assets/packs/DisplayBox.rbxm` (saved by the user)
- Modify: `default.project.json`, `frontier.project.json`, `dungeon.project.json` (`assets/packs` →
  `ReplicatedStorage.PackModels`)
- Create: `src/shared/Util/PackModels.luau`
- Modify: `src/shared/Config/Packs.luau` (each pack: `look = "FirstSpark"`, `model = "Pack" | "DeckBox"`)
- Modify: `tests/CreatureAssets.spec.luau` (also scan `assets/packs` for scripts)

**Interfaces:**
- Consumes: Task 1's FBX and textures.
- Produces:
  - `PackModels.pack(packId: string, detail: "High" | "Low"): Model` — `Body` (and `Strip` for High) MeshParts with
    the pack's look; pivot at the bottom centre, front facing -Z.
  - `PackModels.deckBox(packId: string): Model` — `Box`, `Lid`.
  - `PackModels.displayBox(packId: string, packs: number): Model` — `Tray` plus `Packs<packs>` (none for 0).
  - Each falls back to a code-built stand-in (coloured parts with the art decal) when `PackModels` lacks the model,
    so the game runs before the import.
  - Looks: each model holds `Looks/<look>/<MeshPartName>` `SurfaceAppearance`s; `PackModels` clones the right one
    into each MeshPart (scripts can't swap a SurfaceAppearance's maps).

- [ ] **Step 1: Write the failing test** in `tests/CreatureAssets.spec.luau`: `"assets/packs holds Pack, DeckBox and
  DisplayBox, with no scripts"`: asserts the three `.rbxm` files exist and, read like the creature check, contain no
  scripts. Run `lune run tests/run`. Expected: FAIL (files missing).
- [ ] **Step 2:** Ask the user to import the three FBX files (Studio 3D Importer, Rig Type None) into
  `Workspace.PackModels`; with their OK, Claude sets each MeshPart's `SurfaceAppearance` maps from the uploaded
  textures (`upload_image`), names parts per Task 1, resets pivots, builds the `Looks` folders. The user saves each
  model over `assets/packs/<Name>.rbxm`; Claude checks the synced copies then removes the workspace folder (with OK).
- [ ] **Step 3:** Add the Rojo mappings; implement `PackModels`; add `look` and `model` to `Config/Packs`.
- [ ] **Step 4:** Run `lune run tests/run` (Expected: PASS) and `rojo build -o "$TEMP/test.rbxl"` (Expected: builds).
- [ ] **Step 5: Commit**
```bash
git add assets/packs default.project.json frontier.project.json dungeon.project.json src/shared/Util/PackModels.luau src/shared/Config/Packs.luau tests/CreatureAssets.spec.luau
git commit -m "PackModels: the 3D pack, deck box and display box in ReplicatedStorage"
```

### Task 3: The effects (flipbooks) and their config

**Files:**
- Create: `tools/blender/build_pack_fx.py` (from `build_vfx.py`: RipBurst 64 frames, ShardHolo / ShardGold 16, Glint 16)
- Create: `tools/textures/make_flipbooks.py <frames_dir> <out_dir>` (from `make_sheets.py`; RipBurst 8 x 8 at 128 px
  = 1024, the others 4 x 4 at 256 px = 1024; light on black → white with alpha, edges faded)
- Create: `assets/ui/fx/RipBurst.png`, `ShardHolo.png`, `ShardGold.png`, `Glint.png`, `Mote.png` (a soft dot 64 px),
  `Rays.png` (soft rays 512 px), `Leak.png` (a soft horizontal bar 512 x 64)
- Create: `src/shared/Config/PackFx.luau`
- Create: `tests/PackFxConfig.spec.luau`; Modify: `tests/run.luau`

**Interfaces:**
- Produces: `Config/PackFx` = `{ SHEETS = { [name]: { image: string, grid: number, frames: number } }, IMAGES = {
  mote: string, rays: string, leak: string, aura: string } }` with names `RipBurst`, `ShardHolo`, `ShardGold`, `Glint`.

- [ ] **Step 1: Write the failing test** `tests/PackFxConfig.spec.luau`:
```lua
["every sheet is a Roblox flipbook grid with an uploaded image"] = function()
	for name, sheet in PackFx.SHEETS do
		equal(sheet.grid == 2 or sheet.grid == 4 or sheet.grid == 8, true, name .. " grid")
		equal(sheet.frames <= sheet.grid * sheet.grid and sheet.frames > 0, true, name .. " frames")
		equal(string.match(sheet.image, "^rbxassetid://%d+$") ~= nil, true, name .. " image")
	end
	for _, name in { "RipBurst", "ShardHolo", "ShardGold", "Glint" } do
		equal(PackFx.SHEETS[name] ~= nil, true, name)
	end
end,
```
  Run `lune run tests/run`. Expected: FAIL (module missing).
- [ ] **Step 2:** Rebuild the frames in Blender (`build_pack_fx.py`), make the sheets, check each in an image viewer
  (no square edge, frames centred); upload each PNG with the Studio MCP `upload_image`; write `Config/PackFx` with
  the ids (`aura` reuses `CardDesign.IMAGES.GLOW`).
- [ ] **Step 3:** Run `lune run tests/run`. Expected: PASS.
- [ ] **Step 4: Commit**
```bash
git add tools/blender/build_pack_fx.py tools/textures/make_flipbooks.py assets/ui/fx src/shared/Config/PackFx.luau tests/PackFxConfig.spec.luau tests/run.luau
git commit -m "Pack FX: Blender rip burst, foil shards and glint as Roblox flipbooks"
```

### Task 4: Pure rules for shelves, cases and reveal plans

**Files:**
- Modify: `src/shared/Util/ShelfStock.luau`, `tests/ShelfStock.spec.luau`
- Create: `src/shared/Util/ShowcaseLayout.luau`, `tests/ShowcaseLayout.spec.luau`
- Create: `src/shared/Config/CaseLayout.luau` (plain data: `UPRIGHT`); Modify: `src/shared/Config/Showcase.luau`
  (remove `FLAT`), `src/shared/Config/Town.luau` (`SHELF_STOCK.PACKS` → `DISPLAY = { PACKS_SHOWN = 6, LEAN = 6 }`)
- Modify: `src/shared/Util/RevealRules.luau`, `src/shared/Config/CardReveal.luau`, `tests/RevealRules.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces:
  - `ShelfStock.boxFill(units: number, capacity: number, slots: number, index: number, shown: number): number` —
    packs shown in display box `index`: 0 beyond `boxCount`, else `max(1, ceil(fill * shown))` where `fill` is that
    box's share of its `capacity / slots` units.
  - `ShowcaseLayout.uprightSlots(count: number, size: ShelfStock.Vec, look: Upright): { ShelfStock.Vec }` — card
    centres in the case part's space (centre origin, front -Z): two rows of `look.columns`, `look.rowDepth` apart
    front to back (enough for spinning cards not to touch), the back row `look.backRaise` higher so it shows. `Upright = { columns: number, spacing: number, rowDepth:
    number, backRaise: number, bedHeight: number, cardSize: { x: number, y: number } }`.
  - `RevealRules.Plan` gains `shards: number, goldShards: boolean, cinematic: boolean, holo: boolean, alive: boolean,
    glintRate: number, moteRate: number, tilt: number`; `confetti` is removed. `RevealRules.scaleCount(count: number,
    quality: number): number` (quality 1-10 → at least 25% of the count at 1, all of it from 6 up).

- [ ] **Step 1: Write the failing tests.**
```lua
-- ShelfStock.spec
["boxFill: full boxes show all, the last box shows its share, any stock shows a pack"] = function()
	equal(ShelfStock.boxFill(24, 24, 12, 1, 6), 6, "full")
	equal(ShelfStock.boxFill(23, 24, 12, 12, 6), 3, "half of the last box")
	equal(ShelfStock.boxFill(1, 96, 12, 1, 6), 1, "one pack still shows")
	equal(ShelfStock.boxFill(10, 24, 12, 6, 6), 0, "beyond the stocked boxes")
	equal(ShelfStock.boxFill(0, 24, 12, 1, 6), 0, "empty")
end,
-- ShowcaseLayout.spec
["six upright cards fit the 6 x 4 x 2 case without touching while they spin"] = function()
	local slots = ShowcaseLayout.uprightSlots(6, { x = 6, y = 4, z = 2 }, CaseLayout.UPRIGHT)
	equal(#slots, 6, "six")
	local half = CaseLayout.UPRIGHT.cardSize.x / 2
	for i, a in slots do
		equal(math.abs(a.x) + half <= 3 and math.abs(a.z) + half <= 1, true, `slot {i} inside`)
		for j = i + 1, #slots do
			local b = slots[j]
			local apart = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 2 * half
			local stacked = math.abs(a.y - b.y) >= CaseLayout.UPRIGHT.cardSize.y
			equal(apart or stacked, true, `slots {i} and {j} clear`)
		end
	end
	equal(slots[4].y > slots[1].y, true, "back row raised")
end,
-- RevealRules.spec
["plans: Legendary is cinematic with gold shards and alive; Common is plain and quick"] = function()
	local legend = RevealRules.plan(CardReveal, "Legendary", false, false)
	equal(legend.cinematic and legend.goldShards and legend.alive, true, "legendary")
	local common = RevealRules.plan(CardReveal, "Common", false, false)
	equal(common.tease == 0 and not common.alive and not common.cinematic and common.shards == 0, true, "common")
	equal(RevealRules.plan(CardReveal, "Epic", false, false).cinematic, true, "epic cinematic")
	equal(RevealRules.plan(CardReveal, "Very Rare", false, false).cinematic, false, "very rare not")
	equal(RevealRules.plan(CardReveal, "Common", true, false).holo, true, "foil is holo")
	equal(RevealRules.scaleCount(40, 1), 10, "low quality keeps a quarter")
	equal(RevealRules.scaleCount(40, 7), 40, "high quality all")
end,
```
  Also update the existing RevealRules tests that read `confetti`. Run `lune run tests/run`. Expected: FAIL.
- [ ] **Step 2:** Implement `boxFill`, `ShowcaseLayout.uprightSlots`, the new `CardReveal` tier fields (Rare: glint 4/s,
  motes 8/s, tilt 5; Very Rare 5 / 10 / 6; Epic 6 / 14 / 7, cinematic; Legendary and Frontier 7.5 / 18 / 8, cinematic,
  gold shards 30; shards: Rare 10, Very Rare 16, Epic 24 holo), `RevealRules.plan` and `scaleCount`; `CaseLayout.UPRIGHT`
  (cardSize { x = 0.84, y = 1.2 } = today's card at 0.8, columns 3, spacing 1.9, rowDepth 1.0, backRaise 0.6, bedHeight
  0.3 of the case: front cards span -0.8..0.4 in height, back -0.2..1.0, all inside the 4-stud case).
- [ ] **Step 3:** Run `lune run tests/run`. Expected: PASS (all specs).
- [ ] **Step 4: Commit**
```bash
git add src/shared/Util/ShelfStock.luau src/shared/Util/ShowcaseLayout.luau src/shared/Util/RevealRules.luau src/shared/Config/CaseLayout.luau src/shared/Config/Showcase.luau src/shared/Config/Town.luau src/shared/Config/CardReveal.luau tests
git commit -m "Rules: display box fill, upright case layout, reveal plans with shards, cinematics and living cards"
```

### Task 5: Shelves show open display boxes

**Files:**
- Modify: `src/server/Services/PlacementService.luau` (`fillWithPacks` → display box; `fillWithDecks` → deck box models)

**Interfaces:**
- Consumes: `PackModels.displayBox`, `PackModels.deckBox` (Task 2), `ShelfStock.boxFill`, `Town.SHELF_STOCK.DISPLAY`
  (Task 4).

- [ ] **Step 1:** In `updateStockBoxes`, a pack product's slot gets one display box scaled to the slot's box size,
  showing `ShelfStock.boxFill(shelf.units, capacity, slots, index, DISPLAY.PACKS_SHOWN)` packs (swap the `PacksN`
  child only when the number changes); back-row boxes turn to the back aisle as today; deck products get two
  `PackModels.deckBox` front to back. Delete the old thin-pack and part-built deck code.
- [ ] **Step 2:** `lune run tests/run` (Expected: PASS), `rojo build -o "$TEMP/test.rbxl"` (Expected: builds).
- [ ] **Step 3: Studio check (Play):** stock a Small Pack Rack, a Wall Shelf and a Big Display Rack (both faces)
  with First Spark packs and one shelf with Deck Boxes; sell some (or `/cash` and buy) until a box is half empty;
  switch a shelf's product. Screenshot each. Expected: boxes with their art lids, packs leaning in them, the last box
  part-full, empty slots without a box, tags in place, no errors in Output.
- [ ] **Step 4: Commit**
```bash
git add src/server/Services/PlacementService.luau
git commit -m "Shelves: packs stand in open display boxes that empty as they sell; 3D deck boxes"
```

### Task 6: Glass cases with spinning upright cards

**Files:**
- Create: `src/shared/Util/CaseLook.luau` (code-built case: dark base `Support`, gold or chrome `Frame`, `Carpet` bed,
  tall glass panes, a light strip in the shop's accent along the top edge)
- Modify: `src/shared/Util/Props.luau` (`buildFallback` draws `CaseLook` for slot `CardCase`)
- Modify: `src/shared/Config/Shelves.luau` (both cases: `prop = "CardCase"`, `cardsUpright = true` replacing `cardsFlat`)
- Modify: `src/server/Services/PlacementService.luau` (`getSlotCFrame`: upright slots from `ShowcaseLayout`; card part
  size from `CaseLayout.UPRIGHT.cardSize`; attribute `Upright = true`)
- Create: `src/client/Controllers/CaseSpinController.luau`; Modify: `src/client/init.client.luau` (start it)
- Modify: `src/shared/Config/Showcase.luau` (`SPIN_SECONDS = 6`, `BOB = 0.08`, `SPIN_RANGE = 80`, beam / pad sizes)

**Interfaces:**
- Consumes: `ShowcaseLayout.uprightSlots`, `CaseLayout.UPRIGHT` (Task 4).
- Produces: `CaseSpinController.Start()`: watches `DisplayedCard` parts with `Upright`; within `SPIN_RANGE` of the
  camera turns each locally (base CFrame read once at attach) and bobs it; adds a beam and a glowing pad in the rarity
  colour; drops parts when they leave the DataModel.

- [ ] **Step 1:** Implement `CaseLook`, the Shelves change, the upright slots and `CaseSpinController`.
  (`assets/props/Showcase.rbxm` stays unused; ask the user whether to delete it.)
- [ ] **Step 2:** `lune run tests/run` (Expected: PASS; ShelvesConfig spec still passes), `rojo build` (Expected: builds).
- [ ] **Step 3: Studio check (Play, Local Server 2 players):** place both cases, list 6 cards of mixed rarity and a
  Grade S Legendary (`/legendarys`), change a price, remove and re-list a card; as the second player buy from the
  Collector Case (E prompt). Expected: cards spin and bob on rarity beams in two staggered rows, prices readable, the
  supreme lightning still crackles, re-listed cards spin, the buy works, no errors.
- [ ] **Step 4: Commit**
```bash
git add src/shared/Util/CaseLook.luau src/shared/Util/Props.luau src/shared/Config/Shelves.luau src/shared/Config/Showcase.luau src/server/Services/PlacementService.luau src/client/Controllers/CaseSpinController.luau src/client/init.client.luau
git commit -m "Cases: upright cards spinning on rarity beams in a taller glass case"
```

### Task 7: The opening's flow and layout rules

**Files:**
- Create: `src/shared/Util/OpeningFlow.luau`, `tests/OpeningFlow.spec.luau`
- Create: `src/shared/Util/OpeningLayout.luau`, `tests/OpeningLayout.spec.luau`
- Create: `src/shared/Config/PackOpeningLayout.luau` (plain data: `LAYOUT`)
- Modify: `tests/run.luau`

**Interfaces:**
- Produces:
  - `OpeningFlow.State = { phase: string, index: number, count: number, lockedUntil: number }`; phases `"Ready"`,
    `"Tearing"`, `"Stacking"`, `"Stacked"`, `"Flipping"`, `"Shown"`, `"Stowing"`, `"Results"`.
  - `OpeningFlow.new(count: number): State` (phase `Ready`).
  - `OpeningFlow.tap(state: State, now: number): (State, string?)` — action `"Tear"` (Ready), `"Flip"` (Stacked),
    `"Next"` (Shown, not last: stow then flip the next), `"Results"` (Shown, last); nil while busy or locked.
  - `OpeningFlow.done(state: State, now: number, lock: number?): State` — the running animation finished
    (Tearing → Stacking → Stacked; Flipping → Shown with `lockedUntil = now + (lock or 0)`; Stowing → Flipping).
  - `OpeningFlow.skip(state: State): State` — straight to Results (for the later Fast Open pass).
  - `OpeningLayout.depthFor(pixels: number, viewHeight: number, fov: number, studs: number): number` — how far from
    the camera a `studs`-tall card shows `pixels` tall.
  - `OpeningLayout.row(count: number, view: { w: number, h: number }, inset: number, look: Layout): { Rect }` and
    `OpeningLayout.lineup(count: number, view, inset, look): { Rect }` — screen rects (`{ x, y, w, h }`, pixels);
    `Layout = { rowHeight: number, rowGap: number, rowBottom: number, maxCard: number, gap: number, side: number }`.

- [ ] **Step 1: Write the failing tests.**
```lua
-- OpeningFlow.spec
["taps do nothing while the tear, the stacking or a big flip's spotlight plays"] = function()
	local s, action = OpeningFlow.tap(OpeningFlow.new(5), 0)
	equal(action, "Tear", "first tap tears")
	local _, busy = OpeningFlow.tap(s, 0.1)
	expect.isNil(busy, "ignored while tearing")
	s = OpeningFlow.done(OpeningFlow.done(s, 1), 2) -- tear, then stacking finished
	s, action = OpeningFlow.tap(s, 3)
	equal(action, "Flip", "flip the first")
	s = OpeningFlow.done(s, 3.4, 0.6)
	local _, locked = OpeningFlow.tap(s, 3.5)
	expect.isNil(locked, "spotlight lock")
	local _, ok = OpeningFlow.tap(s, 4.1)
	equal(ok, "Next", "after the lock")
end,
["the last shown card goes to the results; skip jumps there"] = function()
	local s = { phase = "Shown", index = 5, count = 5, lockedUntil = 0 }
	local _, action = OpeningFlow.tap(s, 1)
	equal(action, "Results", "last")
	equal(OpeningFlow.skip(OpeningFlow.new(5)).phase, "Results", "skip")
end,
-- OpeningLayout.spec
["the row and the lineup fit a 568 x 320 phone under the top bar"] = function()
	for _, view in { { w = 667, h = 375 }, { w = 568, h = 320 } } do
		for _, rects in { OpeningLayout.row(5, view, 36, PackOpeningLayout.LAYOUT), OpeningLayout.lineup(5, view, 36, PackOpeningLayout.LAYOUT) } do
			for i, r in rects do
				equal(r.x >= 0 and r.x + r.w <= view.w and r.y >= 36 and r.y + r.h <= view.h, true, `{view.w}: card {i} on screen`)
				if i > 1 then equal(r.x >= rects[i - 1].x + rects[i - 1].w, true, `{view.w}: card {i} clear of {i - 1}`) end
			end
		end
	end
end,
["depthFor: twice the pixels, half the distance"] = function()
	near(OpeningLayout.depthFor(100, 400, 70, 1.5) / OpeningLayout.depthFor(200, 400, 70, 1.5), 2, 1e-9, "inverse")
end,
```
  Run `lune run tests/run`. Expected: FAIL (modules missing).
- [ ] **Step 2:** Implement both modules; `Config/PackOpeningLayout.LAYOUT` = rowHeight 0.16 of the screen, rowGap 10,
  rowBottom 0.125, maxCard 140, gap 22, side 70.
- [ ] **Step 3:** Run `lune run tests/run`. Expected: PASS.
- [ ] **Step 4: Commit**
```bash
git add src/shared/Util/OpeningFlow.luau src/shared/Util/OpeningLayout.luau src/shared/Config/PackOpeningLayout.luau tests
git commit -m "Opening rules: the reveal state machine and the row and lineup layout"
```

### Task 8: The opening stage and its effects

**Files:**
- Create: `src/client/Util/OpeningStage.luau` (replaces `Util/PackStage.luau`)
- Create: `src/client/Util/OpeningFx.luau`

**Interfaces:**
- Consumes: `Config/PackFx` (Task 3), `RevealRules.scaleCount` (Task 4), `Util/WorldTags`, `Util/ListenAtCharacter`.
- Produces:
  - `OpeningStage.show(): ()` / `OpeningStage.hide(): ()` — build once, park out of view; save/restore the camera,
    FOV and subject (respawn-safe, like `BinderDesk.show/hide`), hide world tags, keep the listener at the character,
    hide the HUD (`Hud.setHidden("PackOpening", ...)`).
  - `OpeningStage.root(): CFrame` (stage origin), `OpeningStage.camera(): Camera`.
  - `OpeningStage.push(scale: number, focus: Vector3, seconds: number): ()`, `OpeningStage.ease(seconds: number): ()`,
    `OpeningStage.shake(studs: number, seconds: number): ()`, `OpeningStage.bars(on: boolean, seconds: number): ()`,
    `OpeningStage.flash(peak: number, seconds: number): ()`, `OpeningStage.dim(amount: number, seconds: number): ()`
    (a ColorCorrection on the camera), `OpeningStage.play(sound: string): ()` (ids from `PackOpening.SOUNDS`).
  - `OpeningFx.burst(at: Vector3, color: Color3, size: number)`, `OpeningFx.shards(at: Vector3, count: number, gold:
    boolean, spread: number)`, `OpeningFx.glint(at: Vector3, size: number, color: Color3?)`, `OpeningFx.leak(from:
    Vector3, to: Vector3, seconds: number)`, `OpeningFx.rays(on: boolean, color: Color3)`, `OpeningFx.aura(on: boolean,
    color: Color3)`, `OpeningFx.motes(rate: number, around: CFrame?, color: Color3?)` (rate 0 stops), `OpeningFx.clear()`.
    Counts pass through `RevealRules.scaleCount` with `UserGameSettings().SavedQualityLevel`.

- [ ] **Step 1:** Implement both (ParticleEmitters with `FlipbookLayout` / `FlipbookMode.OneShot`, `LightEmission = 1`;
  shards `Loop`; bars, flash and hint as a ScreenGui with `IgnoreGuiInset`; Bloom + ColorCorrection + DepthOfField
  parented to the camera only while shown).
- [ ] **Step 2:** Compile check (`lune run tests/run` for SourceOrder; Expected: PASS) and `rojo build`.
- [ ] **Step 3: Commit** (nothing uses them until Task 10)
```bash
git add src/client/Util/OpeningStage.luau src/client/Util/OpeningFx.luau
git commit -m "Opening stage and effects modules"
```

### Task 9: The pack and the cards on the stage

**Files:**
- Create: `src/client/Util/OpeningPack.luau`, `src/client/Util/OpeningCards.luau`
- Modify: `src/shared/Config/PackOpening.luau` (rewrite: `STAGE_POSITION`, `FIELD_OF_VIEW`, the approved timings
  under `TEAR`, `STACK`, `FLIP`, `ALIVE`, `STOW`, `RESULTS`, `LETTERBOX = 0.11`, `SOUNDS` / `VOLUMES` (filled in
  Task 11); remove the 2D-only keys)

**Interfaces:**
- Consumes: `PackModels` (Task 2), `OpeningStage`, `OpeningFx` (Task 8), `OpeningLayout` (Task 7), `RevealRules.Plan`
  (Task 4), `CardFace`.
- Produces:
  - `OpeningPack.show(pack: Packs.Pack): ()` (idle sway and a sheen), `OpeningPack.drag(progress: number): ()` (the
    strip parting with the swipe, 0-1), `OpeningPack.tear(): ()` (yields: the whole cinematic of spec 4.2),
    `OpeningPack.open(): ()` (deck box: the lid lifts, yields), `OpeningPack.away(): ()`, `OpeningPack.mouth(): Vector3`.
  - `OpeningCards.build(pulls: { Pull }): ()` (builds the faces; call during the tear) with
    `Pull = { card: Card, foil: boolean, grade: string, isNew: boolean, plan: RevealRules.Plan }`,
    `OpeningCards.stack(from: Vector3): ()` (yields, spec 4.3), `OpeningCards.flip(index: number): ()` (yields: tease,
    flip, celebrate, alive per plan), `OpeningCards.stow(index: number): ()` (stops alive, zips to the row),
    `OpeningCards.lineup(): ()` (yields, spec 4.6), `OpeningCards.clear(): ()`.
  - The flip hides the back part outright once the card passes 90° (spec anti-goal).

- [ ] **Step 1:** Implement both modules on the approved timings; the row and lineup positions from `OpeningLayout`
  rects converted to stage positions with `depthFor`.
- [ ] **Step 2:** `lune run tests/run` (Expected: PASS) and `rojo build`.
- [ ] **Step 3: Commit**
```bash
git add src/client/Util/OpeningPack.luau src/client/Util/OpeningCards.luau src/shared/Config/PackOpening.luau
git commit -m "Opening pack and card actors"
```

### Task 10: The new PackOpeningController

**Files:**
- Modify (rewrite): `src/client/Controllers/PackOpeningController.luau` (remotes, input, the Rip tile, OpeningFlow,
  the results pills and Continue, odds / pity / "N left in box", `PullRevealed`, Rarity guide)
- Create: `src/client/Util/OpeningResults.luau` (pills, Continue, the hint capsule; UIKit)
- Delete: `src/client/Util/PackStage.luau`

**Interfaces:**
- Consumes: everything from Tasks 7-9; `Remotes.PackOpened`, `Remotes.RipPack`, `Remotes.PullRevealed`;
  `RarityGuideController`; `Hud`.
- Produces: `PackOpeningController.Start()` as today (init order unchanged).

- [ ] **Step 1:** Wire it: `PackOpened` → `OpeningStage.show`, `OpeningPack.show`, `OpeningCards.build` (during the
  tear), then `OpeningFlow` drives `tear` / `stack` / `flip` / `stow` / `lineup` on taps (tap, Space, T; a swipe
  across the pack drags the tear). Deck boxes `open()` instead of `tear()`. `BattleStarted`, death, respawn and
  Continue close the stage and give the camera back. Big pulls fire `PullRevealed` as today.
- [ ] **Step 2:** `lune run tests/run` (Expected: PASS incl. SourceOrder), `rojo build`.
- [ ] **Step 3: Studio check (Play):** `/raritypack` (one card of each rarity), `/raritypack foil`, `/testpack`
  (foil legendary), a deck box, three packs in a row from one carried box; a fight starting mid-opening (`/elite`).
  Screenshot the tear, the stack, a Common flip, the Legendary alive, the results. Expected: the approved sequence,
  Commons quick, no back showing through a face, results under the top bar, the camera back after closing, no errors.
- [ ] **Step 4: Commit**
```bash
git add src/client/Controllers/PackOpeningController.luau src/client/Util/OpeningResults.luau src/client/Util/OpeningStage.luau src/client/Util/OpeningFx.luau src/client/Util/OpeningPack.luau src/client/Util/OpeningCards.luau src/shared/Config/PackOpening.luau
git rm src/client/Util/PackStage.luau
git commit -m "Pack opening: a 3D stage with a cinematic tear, cards stacking one by one, living reveals and a sparkling results lineup"
```

### Task 11: Sounds

**Files:**
- Modify: `src/shared/Config/PackOpening.luau` (`SOUNDS`: `crinkle`, `snap`, `stack`, `flip`, `tease`, `hitRare`,
  `hitEpic`, `hitLegendary`, `shimmer`, `land`, `chime`; `VOLUMES`)

- [ ] **Step 1:** Find free Creator Store sounds with the Studio MCP `search_asset` (Audio), listen in Studio, pick
  one per moment (spec 5b); fill the ids; preload them when the stage first shows.
- [ ] **Step 2:** Studio check: play `/raritypack` with sound; adjust volumes. Expected: each moment has its sound,
  nothing too loud, no missing-asset warnings in Output.
- [ ] **Step 3: Commit**
```bash
git add src/shared/Config/PackOpening.luau src/client/Util/OpeningStage.luau
git commit -m "Pack opening sounds: tear, stack, flip, hits, shimmer, landings"
```

### Task 12: The 3D pack in menus (Set Price, Prices, Order Stock)

**Files:**
- Modify: `src/client/Util/ProductPicture.luau` (pack products: a ViewportFrame with `PackModels.pack(id, "High")`,
  a slight turn, the same 38 x 56 footprint; deck boxes the 3D deck box)

- [ ] **Step 1:** Implement; keep the icon path for other products.
- [ ] **Step 2:** Studio check: open Set Price on a pack shelf's tag, the Prices panel, Order Stock. Expected: the 3D
  pack and deck box in each row, rows aligned as before.
- [ ] **Step 3: Commit**
```bash
git add src/client/Util/ProductPicture.luau
git commit -m "Menus show the 3D pack and deck box"
```

### Task 13: Phones, performance, docs

**Files:**
- Modify: `DESIGN.md` (3 shelves and cases text, 4.3, 5.6, 5.7 rewritten for the 3D opening, 6, 10.2 file tree,
  13 UI project 3 line), `CLAUDE.md` (Stack: `assets/packs`, `assets/ui/fx`, `tools/textures`; test list:
  ShowcaseLayout, OpeningFlow, OpeningLayout, PackFxConfig; the plain-data configs CaseLayout and PackOpeningLayout), `docs/packs.md` (new: rebuilding the pack models and
  effects), the spec's status line
- Vault: `Decisions log.md`, `Lessons learned.md`

- [ ] **Step 1: Performance check:** Studio at graphics level 1 (and the device simulator, iPhone landscape): measure
  the worst frame with a RenderStepped timer during the tear, a Legendary flip and the results; a full shop (ten
  stocked shelves, four cases). Expected: under 50 ms; if not, lower particle counts in config (never the timings).
- [ ] **Step 2:** Write the docs and the vault notes.
- [ ] **Step 3:** `lune run tests/run` (Expected: PASS), `rojo build`.
- [ ] **Step 4: Commit**
```bash
git add DESIGN.md CLAUDE.md docs/packs.md docs/superpowers/specs/2026-10-29-cards-in-world-and-pack-opening-design.md
git commit -m "DESIGN: UI project 3, cards in the world and the 3D pack opening"
```
- [ ] **Step 5:** Hand over to the user for the Studio and iPhone check (stop → Play): shelves, cases, the opening
  with sound. After they approve: tick UI project 3 in DESIGN.md, merge, push.
