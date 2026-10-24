# UI Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the game's UI the bright reference look with snappy motion, and rebuild the HUD, binder, rarity guide, card inspector and build menu.

**Architecture:** `Util/UIKit` carries the style (already restyled on this branch). New client utils own shared behaviour: `Util/Motion` (tweens), `Util/Hud` (HUD layout and registration). Pure logic that both looks and tests depend on lives in Roblox-free shared modules with Lune specs: `Util/FanLayout`, `Util/BinderSpreads`, `Util/OddsRules`. Screens stay in their controllers; the inspector is a new controller that takes over the binder's detail view.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`"$USERPROFILE/.rokit/bin/lune.exe" run tests/run < /dev/null`), Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-23-ui-restyle-design.md`

## Global Constraints

- Mobile-first: tap targets ≥ 48px; HUD clear of the thumbstick (bottom-left) and jump button (bottom-right).
- Text: plain ASCII, `·` and emoji only (no ✦ ★ − in Gotham/Fredoka).
- UI built in code with `UIKit`; card faces with `CardFace`. All tunable numbers in `src/shared/Config`.
- Panels made with `UIKit.panel` hide touch controls while open (keep `trackPanel`).
- No server or remote changes: every screen sends the remotes it sends today.
- No images except our uploaded ones and public decals already in `Config/CardDesign`.
- Each part ends with: Lune tests green → Play in Studio via MCP (desktop + one landscape-phone check) → screenshots → docs (DESIGN.md / CLAUDE.md) → commit on `feature/ui-restyle`.

## Review Focus

- A panel opened while its open/close tween is still running (double tap B) must end visible or hidden, never stuck half-scaled.
- Keys (B, I, T, G, Q/E/A/D/F) must do nothing while a TextBox (search) has focus.
- Binder with a filter that matches no cards must show an empty spread and "0 / 0", not error.
- Inspector closed by respawn / panel switch must restore the camera and controls.
- Build tile for a shelf whose prop model is missing must show the code stand-in, not an empty frame.

---

## Part A — HUD and motion

### Task A1: Motion and panel open/close

**Files:**
- Create: `src/client/Util/Motion.luau`, `src/shared/Config/UIMotion.luau`
- Modify: `src/client/Util/UIKit.luau` (panel watches Visible; button press squash)

**Interfaces:**
- Produces: `Motion.popIn(gui: GuiObject)`, `Motion.popOut(gui: GuiObject, onDone: (() -> ())?)`, `Motion.press(button: GuiButton)` (wires squash on MouseButton1Down/Up and touch), `Motion.bump(gui: GuiObject)`. Each uses a `UIScale` named `MotionScale` it creates once.
- `Config/UIMotion`: `OPEN_SECONDS = 0.16`, `CLOSE_SECONDS = 0.1`, `OPEN_FROM = 0.85`, `PRESS_SCALE = 0.95`, `PRESS_SECONDS = 0.06`, `BUMP_SCALE = 1.12`, `BUMP_SECONDS = 0.12`, `FAN_STAGGER = 0.04`, `FAN_SECONDS = 0.14`.

- [ ] **Step 1:** Implement `Motion`. popIn: scale from OPEN_FROM to 1 with `Enum.EasingStyle.Back` Out; popOut: scale to OPEN_FROM with Quad In then call onDone. A newer call on the same gui cancels the running tween (Review Focus 1).
- [ ] **Step 2:** In `UIKit.panel`, keep panels' `Visible` API: on Visible→true play popIn; closing through `UIKit.closePanel(frame)` plays popOut then sets Visible=false; the close button uses it. In `UIKit.button` call `Motion.press`.
- [ ] **Step 3:** Run tests and syntax check. Expected: all pass, `syntax OK`.
- [ ] **Step 4:** Play: open/close binder, party, jobs quickly several times; screenshot. Commit "UI: motion for panels and buttons".

### Task A2: HUD layout module with the Manage fan

**Files:**
- Create: `src/shared/Util/FanLayout.luau`, `tests/FanLayout.spec.luau`, `src/client/Util/Hud.luau`, `src/shared/Config/HudLayout.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- `FanLayout.positions(count: number, radius: number, fromDegrees: number, toDegrees: number): { { x: number, y: number } }` — evenly spread on an arc around (0, 0), angle 0 = right, counter-clockwise, y down positive for screen space; count 1 returns the middle angle.
- `Hud.tile(spec: TileSpec): TextButton` where `TileSpec = { id: string, icon: string, label: string, key: string?, group: "Side" | "Bottom" | "Context", order: number, color: Color3?, onClick: () -> () }`.
- `Hud.fanButton(spec: { id: string, icon: string, label: string, order: number, onClick: () -> () }): TextButton` (lives in the Manage fan; clicking closes the fan).
- `Hud.setVisible(id: string, visible: boolean)` (context tiles show/hide with popIn/popOut; layout re-centres).
- `Hud.getTop(): Frame` (the top-centre pill bar, for A3).
- `Config/HudLayout`: `TILE_SIZE = Vector2.new(84, 84)`, `SIDE_X = 12`, `BOTTOM_MARGIN = 16`, `GAP = 10`, `FAN = { RADIUS = 150, FROM = 80, TO = -60, BUTTON = 70 }`, colours `TILE = Color3.fromRGB(38, 110, 245)`, `CONTEXT = Color3.fromRGB(245, 140, 40)`.

- [ ] **Step 1: Failing test** `tests/FanLayout.spec.luau`:
```lua
["three buttons spread evenly from the first angle to the last"] = function()
	local p = FanLayout.positions(3, 100, 90, -90)
	expect.near(p[1].x, 0, 1e-6, "top x") expect.near(p[1].y, -100, 1e-6, "top y")
	expect.near(p[2].x, 100, 1e-6, "middle x") expect.near(p[2].y, 0, 1e-6, "middle y")
	expect.near(p[3].y, 100, 1e-6, "bottom y")
end,
["one button sits at the middle angle"] = function()
	local p = FanLayout.positions(1, 50, 90, -90)
	expect.near(p[1].x, 50, 1e-6, "x") expect.near(p[1].y, 0, 1e-6, "y")
end,
["no buttons gives an empty list"] = function() expect.equal(#FanLayout.positions(0, 50, 0, 90), 0, "empty") end,
```
(Add `expect.near(actual, wanted, tolerance, label)` to `tests/lib/expect` if missing.)
- [ ] **Step 2:** Run tests. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement `FanLayout.positions` and `Hud` (one ScreenGui child frame per group; Side column at the left middle, Bottom row centred above BOTTOM_MARGIN, Context tiles appended to the Bottom row; tile = blue rounded square, emoji icon above label, key hint chip on the corner; Manage tile toggles the fan with staggered popIn using FAN_STAGGER and becomes a white ✖).
- [ ] **Step 4:** Run tests. Expected: pass.
- [ ] **Step 5:** Move every HUD button to `Hud`: Party, Jobs (fan), Build, Prices (fan), Binder → Bottom "Cards" (B), Bag → Bottom "Bag" (I), PackOpening Rip → Context "Rip a pack" (T), Carry Drop → Context "Drop box" (G), Frontier home → under the top bar. Remove their old positions. Play: tap each; fan opens/closes; context tiles appear when carrying packs; screenshot desktop + phone. Commit "UI: HUD tiles and the Manage fan".

### Task A3: Top pills

**Files:** Modify `src/client/Controllers/UIController.luau`, `src/client/Controllers/BuffController.luau` (only if its anchor moves).

**Interfaces:** Consumes `Hud.getTop()`, `Motion.bump`. Produces nothing new; `UIController.GetStatusFrame/GetStatusRow` keep working for the party bar and buff badge.

- [ ] **Step 1:** Build in `Hud.getTop()`: cash pill (dark navy `Color3.fromRGB(20, 28, 60)`, 💵, value), round level badge (number), ✨ Star Shards pill (item count from the `items` the client already receives), and a small status pill under them: "XP 812 / 13800". Bump a pill when its value changes. Remove the old bottom-right cash/level/XP labels; keep buff badge and party bar.
- [ ] **Step 2:** Tests + syntax; Play: earn cash (`/cash 50`), level (`/xp 500`), shards (`/frontierdrop`); pills update and bump; screenshot. Update DESIGN.md (UI / HUD section, new files in 10.2) and CLAUDE.md (UI: "HUD buttons go through `Util/Hud`"). Commit "UI: top pills; docs".

## Part B — Binder 2.0

### Task B1: Spread maths

**Files:** Create `src/shared/Util/BinderSpreads.luau`, `tests/BinderSpreads.spec.luau`; modify `tests/run.luau`.

**Interfaces:**
- `BinderSpreads.count(cardCount: number, pocketsPerPage: number): number` — spread 1 = cover (left) + first page (right); later spreads two pages. 0 cards → 1 (the cover alone).
- `BinderSpreads.cards(spread: number, cardCount: number, pocketsPerPage: number): (first: number, last: number)` — card index range shown (first > last when none).
- `BinderSpreads.label(spread: number, total: number): string` — page numbers "1 / 14" for spread 1 (cover + page 1), "2-3 / 14" after; total = page count.

- [ ] **Step 1: Failing tests:** 35 cards, 9 per page → `count` = 3 (pages: 9 | 9+9 | 8) ; `cards(1)` = 1..9, `cards(2)` = 10..27, `cards(3)` = 28..35; `label(2, 4)` = "2-3 / 4"; `count(0, 9)` = 1 and `cards(1, 0, 9)` gives first > last (Review Focus 3).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → pass. Commit.

### Task B2: Full-screen binder

**Files:** Modify `src/client/Controllers/BinderController.luau`, `src/shared/Config/Collection.luau` (binder numbers).

**Interfaces:** Consumes `BinderSpreads`, `UIKit`, `Motion`, `PocketLayout`. Produces `BinderController.Open(hint: string?)` unchanged; new `BinderController.OpenSet(setName: string)`.

- [ ] **Step 1:** Replace the panel with a full-screen binder frame (dark leather book, rings in the middle, light page area): cover page for spread 1 (set name, "34 / 35", emblem in the set colour), set tabs on the left edge per `Cards.BySet` (FIRST SPARK, FRONTIER) that jump to that set's cover, page counter pill under the book (`BinderSpreads.label`), arrow buttons with key chips Q/E (one spread) and A/D (first/last spread), ✖ close top-right, set progress card bottom-right (set name, owned / total with a bar, value of owned copies), Rarity guide button bottom-left (opens C; until C exists, hidden).
- [ ] **Step 2:** Keys only when the binder is open and no TextBox has focus (`UserInputService:GetFocusedTextBox()`; Review Focus 2). Keep B to toggle, I for the Bag tab.
- [ ] **Step 3:** Tests + syntax; Play: flip through both sets with keys and arrows, check the cover, counter and progress card; phone check; screenshot. Commit "Binder 2.0: book, cover, set tabs, page keys".

### Task B3: Filters side panel

**Files:** Modify `src/client/Controllers/BinderController.luau`.

- [ ] **Step 1:** F button (key F) opens a Filters panel on the right: search box, Show (All / Owned / Missing), Sort by (Set / Value / Copies / Rarity), rarity chips multi-select (from `Rarities.Tiers` order, plus Frontier). Opening tweens the book to `Config/Collection.FILTER_BOOK_SCALE = 0.72` and slides it left; closing reverses. Remove the old chip row. Empty result → empty spread, "0 / 0" (Review Focus 3).
- [ ] **Step 2:** Tests + syntax; Play: each filter and sort; open/close with the book shrinking; screenshot. Docs (DESIGN.md binder line and section). Commit "Binder 2.0: filters panel".

## Part C — Rarity guide

### Task C1: Odds maths

**Files:** Create `src/shared/Util/OddsRules.luau`, `tests/OddsRules.spec.luau`; modify `tests/run.luau`.

**Interfaces:**
- `OddsRules.perCard(pack: { slots: { { { rarity: string, weight: number } } } }): { [string]: number }` — chance a pulled card is each rarity, averaged over the pack's slots; sums to 1.
- `OddsRules.oneIn(chance: number): number` — rounded "about 1 in N" (chance 0 → math.huge).

- [ ] **Step 1: Failing tests** with the First Spark slots copied into the spec as plain data: Common ≈ 0.74, Rare ≈ 0.196, Very Rare ≈ 0.03, Epic ≈ 0.028, Legendary ≈ 0.006 (tolerance 1e-9); total = 1; `oneIn(0.006)` = 167; a slot whose weights don't sum to 1 is normalised.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** pass. Commit.

### Task C2: Rarity guide panel

**Files:** Create `src/client/Controllers/RarityGuideController.luau`; modify `src/client/init.client.luau` (start order), `BinderController` (show the guide button, call `RarityGuideController.Open()`).

- [ ] **Step 1:** Panel (UIKit.panel, wide): intro line; groups Common · Rare and Very Rare · Epic and Legendary · Frontier, each entry = a small card face of a real card of that rarity (`CardFace.render`), name, `string.format("%.1f%%", chance * 100)` (two decimals under 1%), "about 1 in N cards"; Foil section (`Rarities.FOIL_CHANCE`, `FOIL_MULTIPLIER`); Grades section (`Beasts.GRADE_CHANCES`, `GRADE_BONUS`); Frontier line "found in the Frontier, never in packs".
- [ ] **Step 2:** Tests + syntax; Play from the binder button; screenshot; docs. Commit "Rarity guide".

## Part D — Card inspector

### Task D1: Inspector

**Files:** Create `src/client/Controllers/CardInspectorController.luau`, `src/shared/Config/Inspector.luau`; modify `BinderController` (tile tap opens the inspector; the old detail view and its copies list move into the inspector's info panel), `src/client/init.client.luau`.

**Interfaces:**
- `CardInspectorController.Open(card: Card, entries: { Entry }, actions: Actions)` where `Entry` is the binder's existing copy entry type (key, grade, foil, count, beast?) and `Actions = { addToParty: (Entry) -> (), assignJob: (Entry) -> () }`; `CardInspectorController.Close()`.
- `Config/Inspector`: `DISTANCE = 6` (studs in front of the camera), `CARD_SIZE = Vector3.new(2.45, 3.5, 0.06)`, `MAX_TILT = 35` (degrees), `RETURN_SECONDS = 0.35`, `FLIP_SECONDS = 0.3`, `BACKDROP_TRANSPARENCY = 0.35`.

- [ ] **Step 1:** Local card part in front of the camera (camera Scriptable while open), front SurfaceGui with `CardFace.render(.., growth)`, back SurfaceGui with `CardFace.renderBack`, glow/holo/aura reuse (`ElementAura.attach` for Legendaries with the copy's intensity). Drag tilts (pointer delta → yaw/pitch clamped to MAX_TILT), release eases back; Flip button / drag past 90° flips. Backdrop: a dark ScreenGui frame under the info panel is not possible over a 3D part, so dim the world with a local `ColorCorrectionEffect` (Brightness -0.3, Saturation -0.4) while open.
- [ ] **Step 2:** Info panel (UIKit style, right side): name, value, rarity chip, "#06 / 35", grade and growth; copies list (best first) with Add to party / Assign job exactly as the old detail view; Flip and ✖. Close restores camera type and removes the effect; also on character respawn and when another panel opens (Review Focus 4).
- [ ] **Step 3:** Tests + syntax; Play: open from the binder, tilt, flip, add to party, close; respawn while open; phone drag; screenshot; docs. Commit "Card inspector".

## Part E — Build menu

### Task E1: Categories and 3D tiles

**Files:** Modify `src/shared/Config/Shelves.luau` (add `category`), `tests/ShelvesConfig.spec.luau`, `src/client/Controllers/BuildController.luau`.

**Interfaces:** `category: "Shelves" | "Cases" | "Fixtures"` on every shelf def (Products → Shelves, CustomerCards/PlayerCards → Cases, Condenser → Fixtures). Decor tab shows "Coming soon".

- [ ] **Step 1: Failing test** in `ShelvesConfig.spec`: every shelf entry has a `category` from that set (text-based, like the existing duplicate-field check).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Add the fields. **Step 4:** pass.
- [ ] **Step 5:** Build panel: category tabs; grid of tiles, each a ViewportFrame showing the prop model (`Props.place` into the viewport's WorldModel at the origin, camera framed on its bounding box; code stand-in when `Props.hasModel` is false — Review Focus 5), name, price button (Accent; grey "Lv N" when locked; red price when unaffordable). Tapping keeps today's buy/place flow. Restyle the shelf edit menu.
- [ ] **Step 6:** Tests + syntax; Play: every tab, buy and place a shelf, locked and unaffordable states; phone; screenshot; docs. Commit "Build menu: categories and 3D tiles".

## Final

- [ ] Whole-branch review against the spec; fix Critical/Important findings with tests where pure logic is involved.
- [ ] DESIGN.md and CLAUDE.md complete; `rojo build` succeeds; all Lune tests pass. Ask the owner to judge in Studio, then tick DESIGN.md, merge and push when they confirm.
