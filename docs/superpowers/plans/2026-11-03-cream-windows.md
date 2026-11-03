# Cream & Candy Windows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every town/Frontier window takes the HUD's cream & candy look; the binder and every fight screen stay dark.

**Architecture:** A cream palette in plain data (`Config/CreamTheme`, Lune contrast-tested) beside today's dark tokens. `UIKit.panel` builds cream windows by default and marks them with a `Theme` attribute; the binder opts into `"dark"`. UIKit's shared pieces (header, rows, buttons, pills, bars, stat rows, close button) read the theme of the window they're built in. Each window controller then swaps its hard-coded dark colours for the theme's (`UIKit.colorsFor(instance)`), group by group, checked in Studio.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests, Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-03-cream-windows-design.md`

**Branch:** `hud-creature-pals` (continue).

## Global Constraints

- Not touched: the binder (book, pages, desk, its own buttons and labels) and the card inspector stage opened from it, every fight screen (boss and wild fight HUDs, victory and defeat screens, damage numbers, boss plate, rings, in-fight Shop button), the pack opening stage, the loading screen, the welcome cinematic, card faces, world tags, the HUD.
- Layouts, sizes and button behaviour unchanged.
- Body cream gradient `#fff8ee` → `#f6e3c9`; 4 px white window outline; corners about 22 px; a soft drop shadow, no black lip.
- Rows/slots/stat cards white with a cream edge `#f0dcc2`; empty slots deeper cream; selected a gold ring.
- Text brown `#6b4a2a`, secondary lighter brown, hints and small headings dark amber about `#a85d10`.
- Buttons: today's candy colours, 3 px white outline, white text with a soft outline; light buttons keep dark text.
- Header bands: Bag coral, Cards and card detail blue, Bosses purple, Party lilac, Shop mint, Prices sky, Jobs pink, others sky; white FredokaOne title keeping its dark outline.
- Contrast floors: body text and numbers ≥ 4.5:1 on cream and white; button labels ≥ 3:1.
- Tooltips stay dark with a gold edge.
- Numbers in config, UI built with `Util/UIKit`, `--!strict`, plain ASCII text, keep each file's line endings.

## Review Focus

1. A white or other light label hard-coded in a window, now unreadable on cream: every converted window is screenshotted in its task, and Task 7 walks them all again.
2. The binder or a fight screen picking up the cream look: Task 2 marks the binder `"dark"`; Task 7 screenshots the binder and a boss fight HUD.
3. A shared piece built before it's parented into a window (rows made then moved) keeping dark colours: `UIKit.colorsFor` reads the theme at build time from the parent passed in; Task 2 checks the row/tile builders that build-then-move (`UIKit.label` already re-picks on ancestry).
4. Light candy buttons (gold) losing their dark text when outlines turn white: Task 2 keeps `UIKit.button`'s light/dark text rule and checks a gold button.
5. Phones: nothing grows; Task 7 checks two landscape phones.

---

### Task 1: Cream palette and contrast rules

**Files:**
- Create: `src/shared/Config/CreamTheme.luau`, `src/shared/Util/ContrastRules.luau`, `tests/ContrastRules.spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces:
  - `Config/CreamTheme` (plain data, `{ r, g, b }` lists): `bodyTop`, `bodyBottom`, `row`, `rowEdge`, `rowBase`, `slotEmpty`, `ink`, `inkSoft`, `hint`, `track`, `outline`, `shadow = { offset, transparency }`, `corner`, `outlineThickness`, `buttonOutline`, `headers = { Bag, Cards, Bosses, Party, Shop, Prices, Jobs, Default }` each `{ top, bottom }`.
  - `ContrastRules.luminance(rgb: { number }): number` (WCAG relative luminance of 0-255 values), `ContrastRules.ratio(a: { number }, b: { number }): number` (≥ 1).

- [ ] **Step 1: Failing tests** (`tests/ContrastRules.spec.luau`)
```lua
["contrast of black on white is 21, a colour on itself 1"] = function()
	expect.near(ContrastRules.ratio({ 0, 0, 0 }, { 255, 255, 255 }), 21, 1e-6)
	expect.near(ContrastRules.ratio({ 120, 40, 200 }, { 120, 40, 200 }), 1, 1e-9)
	expect.near(ContrastRules.ratio({ 255, 255, 255 }, { 0, 0, 0 }), 21, 1e-6, "order doesn't matter")
end,
["the cream theme's text reads on its surfaces"] = function()
	local t = CreamTheme
	for _, surface in { t.bodyTop, t.bodyBottom, t.row, t.slotEmpty } do
		expect.equal(ContrastRules.ratio(t.ink, surface) >= 4.5, true, "body text")
		expect.equal(ContrastRules.ratio(t.inkSoft, surface) >= 4.5, true, "secondary text")
		expect.equal(ContrastRules.ratio(t.hint, surface) >= 4.5, true, "hints")
	end
end,
["every header band has a top and a bottom colour"] = function()
	for _, name in { "Bag", "Cards", "Bosses", "Party", "Shop", "Prices", "Jobs", "Default" } do
		local band = CreamTheme.headers[name]
		expect.equal(#band.top == 3 and #band.bottom == 3, true, name)
	end
end,
```
- [ ] **Step 2: Run** `lune run tests/run ContrastRules` — Expected: fails requiring the missing modules.
- [ ] **Step 3: Implement** both modules with the spec's colours (ink `#6b4a2a`, hint about `#a85d10`, inkSoft a lighter brown that still passes 4.5:1 on `bodyBottom`; header colours from `HudLayout.CANDY` / `CANDY_FAN`: Bag coral, Cards blue, Bosses purple, Party lilac, Shop mint, Prices sky, Jobs pink, Default sky).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Commit** "Cream windows: palette and contrast rules".

### Task 2: UIKit builds cream windows

**Files:**
- Modify: `src/client/Util/UIKit.luau` (`panel`, `header`, `closeButton`, `button`, `row`, `iconButton`, `pill`, `bar`, `statRow`, label ink), `src/shared/Config/UIStyle.luau` (Color3s from `CreamTheme`), `src/client/Controllers/BinderController.luau` (its panel opts into `"dark"`)

**Interfaces:**
- Consumes: `Config/CreamTheme` (Task 1).
- Produces:
  - `UIKit.panel(parent, name, title, band, theme: ("cream" | "dark")?)` — `"cream"` by default; sets the frame's `Theme` attribute.
  - `UIKit.themeOf(instance: Instance): "cream" | "dark"` — the nearest ancestor's `Theme`, `"dark"` when none.
  - `UIKit.colorsFor(instance: Instance): Palette` with `panel`, `row`, `rowEdge`, `slotEmpty`, `ink`, `inkSoft`, `hint`, `track`, `outline`, `outlineThickness` (the dark palette maps to today's tokens, so dark windows look exactly as before).

- [ ] **Step 1: Cream panel** — body: cream gradient, `CreamTheme.corner` corners, white `outlineThickness` outline, a soft shadow frame under it (`shadow.offset`, `shadow.transparency`) instead of the black lip; header: the cream band colours, the dark rule replaced by a white line, title keeps its dark outline; close button: red circle with a white outline; list scrollbar gold.
- [ ] **Step 2: Theme-aware pieces** — `row`, `iconButton`, `button`, `pill`, `bar`, `statRow` read `UIKit.themeOf(parent)`: cream rows white with a `rowEdge` stroke, cream bar tracks `track`, every outline `outline` at `buttonOutline` thickness; text colour rules unchanged (light surfaces get ink). `UIKit.textColorFor` returns the cream `ink`/`inkSoft` on light surfaces inside cream windows.
- [ ] **Step 3: Binder stays dark** — `BinderController`'s `UIKit.panel(...)` passes `"dark"`.
- [ ] **Step 4: Check in Studio** — open Party, Prices and the binder; screenshot each. Expected: Party and Prices cream with readable text and white-outlined buttons (a gold button keeps dark text); the binder unchanged; Output clean.
- [ ] **Step 5: Commit** "Cream windows: UIKit builds the cream look".

### Task 3: Manage tray windows (Party, Jobs, Prices, Set Price)

**Files:** `src/client/Controllers/PartyController.luau`, `JobsController.luau`, `PricingController.luau`, `PriceTagController.luau`

- [ ] **Step 1** Replace each file's hard-coded dark colours used inside its window (`WHITE` / `Color3.new(1, 1, 1)` text on window surfaces, `UIStyle.ROW` / `Colors.Row`, `UIStyle.PANEL` / `Colors.Panel`, `UIStyle.EDGE` outlines) with `UIKit.colorsFor(frame)` values; keep white text only on coloured fills (candy buttons, coloured pills, header). Headers: Party `"Party"`, Jobs `"Jobs"`, Prices and Set Price `"Prices"`.
- [ ] **Step 2** Studio: open each window; screenshot. Expected: all text readable, no dark slabs left, buttons work.
- [ ] **Step 3** `lune run tests/run` (Expected: all pass), commit "Cream windows: Party, Jobs, Prices".

### Task 4: Shop windows (Shop, Shelf, Order Stock) and the Bag and card detail

**Files:** `src/client/Controllers/BuildController.luau`, `OrderController.luau`, `BinderController.luau` (the Bag window only), `CardDetailController.luau`

- [ ] **Step 1** As Task 3 Step 1. Headers: Shop and Shelf `"Shop"`, Order `"Default"`, Bag `"Bag"`, card detail `"Cards"`. The Bag sits over the binder's backdrop: only the Bag window turns cream; the card detail window turns cream, the big card face beside it stays as it is.
- [ ] **Step 2** Studio: open each; screenshot. Expected as Task 3.
- [ ] **Step 3** Tests, commit "Cream windows: Shop, Bag, card detail".

### Task 5: Boss Ladder

**Files:** `src/client/Controllers/BossBoardController.luau`

- [ ] **Step 1** As Task 3 Step 1, header `"Bosses"`; boss rows keep their element colours and locked/unlocked meaning (locked greyed on cream).
- [ ] **Step 2** Studio screenshot. **Step 3** Tests, commit "Cream windows: Boss Ladder".

### Task 6: Shop machines and the rest (Condenser, Grading, card case, card picker, Frontier, Rarity guide, first sword, admin)

**Files:** `CondenserController.luau`, `GradingController.luau`, `CardBuyController.luau` (with its buy confirm box), `ShowcaseController.luau`, `FrontierController.luau`, `RarityGuideController.luau`, `SwordController.luau` (the popup only), `ChallengeController.luau` (the arena challenge popup), `AdminPanelController.luau`

- [ ] **Step 1** As Task 3 Step 1; headers `"Default"` (sky) except the card case and picker `"Cards"`.
- [ ] **Step 2** Studio screenshots of each (Condenser and Grading through `ProximityPrompt`s or by making the window visible from the Studio MCP). **Step 3** Tests, commit "Cream windows: machines and the rest".

### Task 7: Walk-through, phones, docs

**Files:** `DESIGN.md` (10.6 Style), `CLAUDE.md` (UI bullet), the vault's Design rules

- [ ] **Step 1** Studio: every window again on PC, plus the binder and a boss fight HUD (still dark), plus two landscape phones (Galaxy A06, iPhone 16 Pro) for three windows. Expected: nothing unreadable, nothing resized, fights and binder unchanged.
- [ ] **Step 2** Docs: DESIGN 10.6 describes the cream windows (tokens, theme opt-out for the binder, fights untouched); CLAUDE.md UI bullet names `UIKit.panel`'s theme and `UIKit.colorsFor`; CLAUDE.md test list gains `ContrastRules`.
- [ ] **Step 3** `lune run tests/run` and `rojo build`. Expected: all pass, builds. Commit "Cream windows: docs".
