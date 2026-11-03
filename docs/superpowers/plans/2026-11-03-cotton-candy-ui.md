# Cotton Candy UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle windows, window buttons, the binder's buttons, the HUD tiles and the party portraits in the owner's
"Cotton candy" look: baby colours that pop, soft glows instead of dark lips and shadows, squircle tiles with popped-out
icons and squishy motion, element-coloured 3D portrait rims.

**Architecture:** Plain-data configs hold every colour and look number (`Config/BabyColors`, `Config/SoftHud`, the
window theme in `Config/CreamTheme`); two pure, Lune-tested modules decide what can be decided without Roblox
(`Util/SoftColors`: text colour on a fill and the role map; `Util/SquishRules`: hover keyframes and the gap check).
`Util/UIKit` builds soft buttons wherever `UIKit.isSoft` says so (cream windows, and panels that opt in), `Util/Hud`
builds the new tiles, `PartyBarController` the new portraits. One script-made glow picture is uploaded once.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Python + Pillow for the glow picture,
Roblox Studio MCP for upload and checks.

**Spec:** `docs/superpowers/specs/2026-11-03-cotton-candy-ui-design.md`

## Global Constraints

- Baby colours: pink `#ff7fb8`, mint `#3fd6a0`, sky `#4fb4ff`, lilac `#a274ff`, butter `#ffc93f`, peach `#ff9468`;
  light shades about `#ffc4df`, `#a9f2d5`, `#b4e0ff`, `#dccbff`, `#ffe7a3`, `#ffd0bb`; ink `#5b3d6e`.
- Windows: body `#fff8fd` to `#f6ecff`, 4 px white outline, slot base line `#f0def5`, empty slots `#f4e6fa`.
- Buttons: flat fill, 3 px white outline, soft same-colour glow, faint lighter top band, no dark lip; white labels with
  a deep-shade outline, light buttons plum text.
- Roles: `Colors.Accent` butter, `Colors.Secondary` sky, `Colors.Danger` pink, `Colors.Success` mint, `Colors.Locked`
  grey-lilac, neutral rows white with plum text.
- Tiles: one squircle, gradient light to full, 4 px white outline, own-colour glow; icon about 3/4 of the tile wide, a
  quarter above the top edge; Manage butter, Cards sky, Bag pink, Bosses lilac; tray mint, peach, sky, lilac by order;
  Admin grey-lilac; Rip and Drop peach.
- Hover: squash at most 10% wider, settle about 6% bigger, about 0.45 s; press squashes flat; hovered tile on top;
  touch gets the press only.
- Portraits: element rim (Ember peach, Tide sky, Bloom mint, Volt butter, Shade lilac), deeper rim under it, shine,
  thin white inner ring, sunk picture, number chip outlined in the element colour; summoned bigger, higher, OUT tag.
- Untouched: every fight screen, the binder's book, tooltips, the pack opening and its results, the loading screen,
  the welcome cinematic, card faces, world tags, the cushion and its pills, the mascot. No size or layout changes.
- Contrast: text 4.5:1 on window surfaces; every baby colour's deep shade 3:1 against white.
- Text: plain ASCII plus `·` and emoji. No magic numbers in controllers. `--!strict`. Keep DESIGN.md in sync.

## Review Focus

1. A controller that later sets a button's `BackgroundColor3` to a named kit colour (card detail's disabled "Slots
   full", the Shop's locked price buttons, binder filter chips): it must still get the soft colour. Task 3 remaps on
   every change and its Studio check presses through those three.
2. A `UIKit.button` on a fight screen, the pack opening results or the welcome cinematic picking up the soft look:
   Task 3's Studio check opens a boss fight and a pack opening and screenshots their buttons unchanged.
3. A button whose text colour a controller set itself (the Shop's green and red prices): the soft restyle must keep
   it. Task 3 only re-picks text colours it picked itself; checked on the Shop screenshot.
4. Fast hover in and out, or a tap on a phone: a tile must never stay squashed or lifted. Task 5 cancels the running
   keyframe chain on every change; its Studio check hovers rapidly and presses.
5. Phones at HUD scale 0.7: the popped-out icons must not cover the cushion's mascot or the status column. Task 7
   checks Galaxy A06 and iPhone 16 Pro landscape.

---

### Task 1: Baby colours, text rules and the cotton candy window theme

**Files:**
- Create: `src/shared/Config/BabyColors.luau`, `src/shared/Util/SoftColors.luau`, `tests/SoftColors.spec.luau`
- Modify: `src/shared/Config/CreamTheme.luau`, `tests/ContrastRules.spec.luau`, `tests/run.luau`,
  `src/shared/Config/UIStyle.luau` (Color3 copies of BabyColors as `UIStyle.BABY`)

**Interfaces:**
- Produces: `BabyColors.COLORS: { [name]: { fill: {r,g,b}, light: {r,g,b}, deep: {r,g,b} } }` for names `pink`,
  `mint`, `sky`, `lilac`, `butter`, `peach`, `greyLilac`, `white`; `BabyColors.INK`; `BabyColors.ROLES`
  (`Accent = "butter"`, `Secondary = "sky"`, `Danger = "pink"`, `Success = "mint"`, `Locked = "greyLilac"`,
  `Row = "white"`, `Panel = "white"`); `BabyColors.ELEMENTS` (`Ember = "peach"`, `Tide = "sky"`, `Bloom = "mint"`,
  `Volt = "butter"`, `Shade = "lilac"`); `BabyColors.GLOW` (filled in by Task 2).
  `SoftColors.textOn(fill: {number}): "ink" | "white"` (ink when the fill is light), `SoftColors.deepOf(fill: {number}):
  {number}` (a fill's deep shade: the named colour's `deep`, else the fill darkened 35%).
  `UIStyle.BABY[name] = { fill, light, deep: Color3 }`, `UIStyle.BABY_INK`.
  CreamTheme keeps its field names; its values become the cotton candy ones; `headers` map Bag pink, Cards sky,
  Bosses lilac, Party lilac, Shop mint, Prices peach, Jobs sky, Default sky.

- [ ] **Step 1: Write the failing tests** in `tests/SoftColors.spec.luau`:
  - `every baby colour's deep shade reads white labels at 3:1`: for each name but `white`, `ratio(deep, {255,255,255}) >= 3`.
  - `light buttons get plum text, bright ones white`: `textOn(butter.fill) == "ink"`, `textOn(white.fill) == "ink"`,
    `textOn(x.fill) == "white"` for pink, sky, mint, lilac, peach; `ratio(INK, butter.fill) >= 4.5`, `ratio(INK, white.fill) >= 4.5`.
  - `the kit's roles and the five elements map to baby colours`: every `ROLES` and `ELEMENTS` value is a key of `COLORS`;
    `ELEMENTS` has exactly Ember, Tide, Bloom, Volt, Shade.
  - `deepOf falls back to the fill darkened by 35%` for `{200, 100, 50}` -> `{130, 65, 32.5}` (within 1).
  In `tests/ContrastRules.spec.luau` add to the surfaces test that `t.bodyTop` is `{255, 248, 253}` and
  `t.slotEmpty` is `{244, 230, 250}` (so it fails until the theme changes). Register `SoftColors` in `tests/run.luau`.
- [ ] **Step 2: Run** `lune run tests/run SoftColors` and `lune run tests/run ContrastRules`. Expected: FAIL (module
  missing; old theme values).
- [ ] **Step 3: Implement** BabyColors (values from Global Constraints; `greyLilac` about fill `#b9a9cf`, `white` fill
  `#ffffff` light `#ffffff` deep `#d9c8e6`; tune deep shades until the 3:1 test passes), SoftColors, the new CreamTheme
  values (body `#fff8fd`/`#f6ecff`, row white, rowEdge `#f0def5`, rowBase `#e6cdee`, slotEmpty `#f4e6fa`, ink `#5b3d6e`,
  inkSoft about `#7b5a8e`, track `#f3e6f8`; hint, good, bad, power, fair re-tuned only if the contrast test fails),
  UIStyle.BABY.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** "Cotton candy: baby colours and the window theme".

### Task 2: The soft glow picture

**Files:**
- Create: `tools/ui-art/make_soft_glow.py`, `assets/ui/soft/Glow.png`
- Modify: `src/shared/Config/BabyColors.luau` (`GLOW = { image = "rbxassetid://<id>", slice = {l, t, r, b}, size = px }`)

**Interfaces:**
- Produces: `BabyColors.GLOW.image`, `.slice` (the 9-slice centre rect in the picture's pixels), `.size` (picture
  width), used by Tasks 3, 5 and 6 through `UIKit.glow(parent: GuiObject, color: Color3, spread: number,
  drop: number, transparency: number): ImageLabel` (defined in Task 3).

- [ ] **Step 1:** `make_soft_glow.py <out.png>`: a 128 x 128 white picture, a rounded square (corner 24 px) inset 32 px,
  Gaussian-blurred (radius 12), with the rounded square itself cut out (alpha 0 inside) so a glow drawn over a button
  only shows outside it. Run it; Expected: `assets/ui/soft/Glow.png` exists, centre pixel alpha 0, edge pixels soft.
- [ ] **Step 2:** Upload through the Studio MCP (`upload_image` from a localhost http server, as the mascot art was);
  put the id in `BabyColors.GLOW`; check in Studio that an ImageLabel with it reports `IsLoaded`.
- [ ] **Step 3:** `lune run tests/run`. Expected: all pass. Commit "Cotton candy: soft glow picture".

### Task 3: Soft buttons and windows in UIKit

**Files:**
- Modify: `src/client/Util/UIKit.luau`, `src/client/Util/Motion.luau`, `src/shared/Config/UIMotion.luau`

**Interfaces:**
- Consumes: `UIStyle.BABY`, `SoftColors.textOn`, `SoftColors.deepOf`, `BabyColors.ROLES`, `BabyColors.GLOW`.
- Produces: `UIKit.isSoft(instance: Instance): boolean` (true inside a cream-theme window or under an ancestor with
  attribute `SoftButtons = true`); `UIKit.softFill(color: Color3): Color3` (a named kit colour to its baby fill,
  anything else unchanged); `UIKit.glow(...)` as above; `UIKit.panel(parent, name, title, band, theme?, softButtons?)`
  (sets `SoftButtons` before building the header and close button).

- [ ] **Step 1:** Soft path in `UIKit.button` when `isSoft(parent)`: no Lip gradient, fill `softFill(color)` (and again
  whenever a controller sets `BackgroundColor3` to a named kit colour), 3 px white outline, a `Glow` child (own colour,
  dropped 4 px), a `Shine` child (thin white band along the top, about 60% see-through), text plum on light fills and
  white with a `deepOf` outline on bright ones, re-picked only while the text colour is still the one it picked.
  `closeButton` stays round pink. `creamWindow` swaps the black `Shadow` for a lilac `UIKit.glow`. The dark path is
  untouched.
- [ ] **Step 2:** `Motion.press`: a quick dip to `UIMotion.PRESS_SCALE` (0.9) and a springy release overshooting to
  `UIMotion.RELEASE_OVERSHOOT` (1.05) before settling, within about 0.25 s.
- [ ] **Step 3:** `lune run tests/run` (SourceOrder, AdminPanel). Expected: all pass. Studio: Shop, Prices, card detail
  (disabled "Slots full"), Boss Ladder, the buy confirm; then a boss fight HUD and a pack opening's results. Expected:
  windows soft with no dark lips; fights and pack opening unchanged.
- [ ] **Step 4:** Commit "Cotton candy: soft buttons and windows".

### Task 4: The binder's buttons

**Files:**
- Modify: `src/client/Controllers/BinderController.luau`

**Interfaces:**
- Consumes: `UIKit.panel(..., "dark", true)`, `UIKit.isSoft`.

- [ ] **Step 1:** The binder's panel opts in (`softButtons` true). The Cards / Bag tab names, the filter chips and the
  sort and show buttons in the filters panel use plum text on butter (open or chosen) and on white (the rest). The
  book, the set tabs, the key chips and the filters panel's own frame stay as they are.
- [ ] **Step 2:** Studio: open the binder, the filters panel and the Bag tab. Expected: close round pink, magnifier and
  arrows soft, tabs butter and white, book unchanged.
- [ ] **Step 3:** Tests; commit "Cotton candy: the binder's buttons".

### Task 5: Squircle HUD tiles with squishy motion

**Files:**
- Create: `src/shared/Config/SoftHud.luau`, `src/shared/Util/SquishRules.luau`, `tests/SquishRules.spec.luau`
- Modify: `src/shared/Config/HudLayout.luau` (TILE_SIZE, GAP, KEY_SIZE from SoftHud; CANDY and CANDY_FAN from the
  baby colours; drop EAR, HORN, SHADOW, HOVER), `src/client/Util/Hud.luau`, `tests/run.luau`

**Interfaces:**
- Produces: `SoftHud.TILE = { size = 84, gap = 10, corner = 0.3, outline = 4, keySize = 24, keyInset = 4,
  icon = 0.74, iconRise = 0.26 }`; `SoftHud.COLORS = { Manage = "butter", Cards = "sky", Bag = "pink", Bosses = "lilac",
  Admin = "greyLilac", Rip = "peach", Drop = "peach" }`, `SoftHud.FAN = { "mint", "peach", "sky", "lilac" }`;
  `SoftHud.SQUISH = { steps = { { seconds, x, y, lift } ... }, press = { x, y, seconds }, release = seconds }`.
  `SquishRules.duration(steps): number`, `SquishRules.widest(steps): number` (largest x),
  `SquishRules.fitsGap(tile, steps): boolean` (half the widest growth plus the key chip's overhang stays under the gap).

- [ ] **Step 1: Write the failing tests** `tests/SquishRules.spec.luau`:
  - `the hover lasts about 0.45 s`: `math.abs(duration(SQUISH.steps) - 0.45) <= 0.05`.
  - `it squashes at most 10% wider and settles about 6% bigger`: `widest <= 1.10`; the last step's x and y within
    0.02 of 1.06; the first step is wider than tall (a squash), the second taller than wide (a stretch).
  - `the hovered tile stays inside the gap`: `fitsGap(TILE, SQUISH.steps) == true`; and `fitsGap` with `gap = 2` is false.
  - `every tile and tray colour is a baby colour`: values of `SoftHud.COLORS` and `SoftHud.FAN` are keys of
    `BabyColors.COLORS`.
  Register `SquishRules` in `tests/run.luau`.
- [ ] **Step 2: Run** `lune run tests/run SquishRules`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** SoftHud, SquishRules, then `Hud.makeTile`: transparent button; a `Glow` (UIKit.glow in the
  tile's colour); a `Body` anchored at its bottom centre holding the squircle `Face` (gradient light to fill, white
  outline), the big icon over the top edge with a tinted, faded, offset copy as its shadow, the label inside at the
  bottom and the key chip. Hover plays `SQUISH.steps` as a chain of size and lift tweens on the body (cancelled by any
  newer hover, leave or press), the hovered tile's `ZIndex` raised; press squashes to `SQUISH.press` and springs back.
  Manage still deepens while its tray is open. Ears and horns removed.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass. Studio: hover each tile fast and slow, press, open the
  Manage tray. Expected: snappy squish, no overlap, never stuck.
- [ ] **Step 5:** Commit "Cotton candy: squircle HUD tiles".

### Task 6: Element-rim party portraits

**Files:**
- Modify: `src/shared/Config/Party.luau` (`BAR.RIM`, `BAR.RIM_BASE` drop in px, `BAR.SHINE` share, `BAR.SINK`
  transparency), `src/client/Controllers/PartyBarController.luau`

**Interfaces:**
- Consumes: `BabyColors.ELEMENTS`, `UIStyle.BABY`.

- [ ] **Step 1:** Each filled portrait: a `Base` circle in the element colour's deep shade, dropped `RIM_BASE` px, under
  a `Rim` circle (gradient light to fill) `RIM` px wider than the picture, a thin white ring round the picture, a
  `Shine` ellipse across the rim's top, a dark fade at the picture's top (sunk). Number chip outlined in the element
  colour. Summoned: bigger, `RIM_BASE` more lift, OUT tag. Empty slots unchanged.
- [ ] **Step 2:** Tests; Studio screenshot of the cushion with three cards and one summoned. Expected: rims easy to see,
  colours match elements.
- [ ] **Step 3:** Commit "Cotton candy: element-rim portraits".

### Task 7: Walk-through, phones, docs

**Files:**
- Modify: `DESIGN.md` (10.6 Style, Creature pals HUD, folder list), `CLAUDE.md` (UI bullet, test list: SoftColors,
  SquishRules), the vault's Design rules and Decisions log

- [ ] **Step 1:** Studio on PC: every window, the binder with filters, the HUD (hover, tray), the cushion, a boss fight
  and a pack opening (unchanged). Galaxy A06 and iPhone 16 Pro landscape: HUD and two windows. Expected: readable,
  nothing resized, popped icons clear of the cushion and status column.
- [ ] **Step 2:** Docs as listed.
- [ ] **Step 3:** `lune run tests/run` and `rojo build`. Expected: all pass, builds. Commit "Cotton candy: docs".
