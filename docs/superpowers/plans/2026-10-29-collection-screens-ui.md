# UI/UX Pass 1: Style Kit and Collection Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the game the look E style kit and rebuild the seven collection screens (binder tooltip, card detail, Add to Party, Party window, HUD party tooltip, boss ladder, Bag) so kids, teens and adults read them at a glance.

**Architecture:** Look E lives in `Config/UIStyle` (tokens) and `Util/UIKit` (panel, header band, candy button, outlined text, pill, bar, stat row, stars), so every window picks it up. Rules both testable and shared (tooltip placement, the 3D card's screen rect, the swap verdict and bars, the boss step state and travel choice, which boss an item belongs to) go in Roblox-free modules with Lune tests. Screens stay in their controllers; two new client widgets (`CardTips`, `CopyCompare`) build the tooltips and the comparison.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Play checks and image upload, Figma image generator plus `tools/ui-icons/slice_icons.py` (Pillow) for the icon sheet.

**Spec:** `docs/superpowers/specs/2026-10-29-collection-screens-ui-design.md`

## Global Constraints

- Branch `ui-pass-1` from `main`; nothing merged or pushed until the user approves every screen in Studio.
- Server authoritative: "Take me there" is a validated, rate-limited remote defined in `src/shared/Remotes.luau`; the client never moves itself.
- All tunable numbers and colours in `src/shared/Config` (`UIStyle`, `Inspector`, `Bosses`), none in controllers.
- UI built in code with `Util/UIKit` and `CardFace`; `UIKit.panel` windows open one at a time; panels hide the thumbstick and jump button.
- Mobile-first: tap targets 48 px or more; every screen checked on a landscape phone (`UIKit.isPhone()`); main content never needs scrolling there.
- Text: ASCII plus `·` only in this pass; no emoji; never ★ − ✦ (icons instead).
- Rarity colours stay `Config/Rarities` (Very Rare teal, Epic purple). Elements: `Cards.ELEMENTS` colours and their icons. Grades: S gold, A blue, B green, C grey. Money green with the Cash icon. Power orange with the Power icon. Good green, bad red, hints and the selected thing gold. Buttons: gold main, blue other, red remove/leave, each with an icon.
- Look E values (spec 3.1): panel #1B2233, outline #0B0F1A 3 px, drop lip, header band per window (Party teal, binder/card detail blue, Boss ladder red, Bag orange, default teal), outlined titles/names/big numbers, candy buttons, bars about 12 px, text body 15 / small 13 / name 22 / number 23 / title 28, FredokaOne titles, Nunito Bold body.
- Pure modules: no `require` of Roblox services, callers pass config in; `--!strict`; each new spec file registered in `tests/run.luau` and named in CLAUDE.md's test list.
- SourceOrder test: no local function or file-level local used above its definition, no module used without a require.
- Every change to a rule, number or file updates DESIGN.md in the same commit (10.6 for the kit and HUD, the binder, party and boss board sections for theirs).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A landscape phone (viewport height under 500): every rebuilt window fits with its main content and buttons visible, tap targets 48 px; the 3D card and the detail panel don't overlap. Tested by `UiLayout` phone-size cases (Task 2) and a Device emulator screenshot per screen.
2. Tooltips at screen edges and on narrow screens never cover the card they describe: tested by the `beside`/`above` edge cases (Task 2).
3. Empty and partial states: an empty party slot in the chooser and the comparison (no outgoing card), no boss data yet from the server, a card only on display (no binder copies), zero XP Tonics, a summoned card that is resting. Tested by `CompareRules.verdict(x, nil)`, `BossRules.stepState` with no record, plus Studio checks listed in Tasks 6-10.
4. "Take me there" from the wrong place, during a fight, spammed, or with a bad index: the server refuses; only "gate" moves you. Tested by `BossRules.travelChoice` (Task 2) and the server checks in Task 10.
5. Items that are not boss items (Star Shard, seals, tonic) and unknown boss ids in the Bag: no tint, no corner number, no error. Tested by `ItemRules.bossOf` (Task 2).

---

### Task 1: Branch, icon sheet 4 and item icons

**Files:**
- Modify: `tools/ui-icons/slice_icons.py` (add `SHEETS[4]`, usage text `1-4`)
- Create: `assets/ui/icons/<Name>.png` x16 (not synced)
- Modify: `src/shared/Config/UIIcons.luau` (16 ids)
- Modify: `src/shared/Config/Items.luau` (`icon` fields to UIIcons names)
- Modify: `DESIGN.md` 10.6 (sheet 4 in the icon pipeline)

**Interfaces:**
- Produces: UIIcons names `Power, Hp, Atk, Spd, Xp, Copies, Summon, Remove, Job, KeyFragment, XpTonic, GradingSeal, GoldSeal, Travel, Best, Pvp` (in that sheet order, 4x4).
- Produces: `Items.ITEMS[id].icon`: `starShard = "Shard"`, every `fragment_*` = `"KeyFragment"`, every `trophy_*` = `"Trophy"`, `xpTonic = "XpTonic"`, `gradingSeal = "GradingSeal"`, `goldSeal = "GoldSeal"`.

- [ ] **Step 1: Branch**

Run: `git switch -c ui-pass-1`
Expected: `Switched to a new branch 'ui-pass-1'`

- [ ] **Step 2: Generate the sheet**

Figma `generate_image`, same prompt style as sheets 1-3 (glossy cartoon icons, 4x4 grid, flat magenta #FF00FF background, one icon per cell, no text), cells in order: orange lightning fist (Power), red heart with a plus (Hp), sword (Atk), white wing (Spd), green "XP" star orb (Xp), two stacked cards (Copies), glowing summoning circle with a paw (Summon), red minus circle (Remove), little apron/briefcase (Job), **silver-white key half, light and neutral so code can tint it** (KeyFragment), green potion bottle (XpTonic), blue wax seal (GradingSeal), gold wax seal (GoldSeal), map pin with an arrow (Travel), gold ribbon rosette (Best), two crossed swords (Pvp). Save as `assets/ui/icons/sheet4.jpg` (not committed if the other sheets aren't; check `git ls-files assets/ui/icons | head`).

- [ ] **Step 3: Add `SHEETS[4]` and slice**

Run: `python tools/ui-icons/slice_icons.py assets/ui/icons/sheet4.jpg 4`
Expected: `saved 16 icons to ...assets\ui\icons`; open 3-4 PNGs with Read to check each is one centred icon with a clean transparent edge.

- [ ] **Step 4: Upload and record ids**

Studio MCP `upload_image` per PNG (as for sheets 1-3); add the 16 `name = "rbxassetid://<id>"` lines to `Config/UIIcons.luau` and update its header comment ("four sheets"). Set the `Items.ITEMS` icons listed above.

- [ ] **Step 5: Tests**

Run: `lune run tests/run`
Expected: all pass (412+), including ItemRules and AdminPanel.

- [ ] **Step 6: Commit**

```bash
git add tools/ui-icons/slice_icons.py assets/ui/icons src/shared/Config/UIIcons.luau src/shared/Config/Items.luau DESIGN.md
git commit -m "UI icons sheet 4 (Power, stats, Summon, key fragment, seals...); items use icon names"
```

### Task 2: Pure rules (layout, comparison, boss steps, boss items)

**Files:**
- Create: `src/shared/Util/UiLayout.luau`, `tests/UiLayout.spec.luau`
- Create: `src/shared/Util/CompareRules.luau`, `tests/CompareRules.spec.luau`
- Modify: `src/shared/Util/BossRules.luau`, `tests/BossRules.spec.luau`
- Modify: `src/shared/Util/ItemRules.luau`, `tests/ItemRules.spec.luau`
- Modify: `tests/run.luau`, `CLAUDE.md` (test list: UiLayout, CompareRules)

**Interfaces:**
- Produces (`UiLayout`, pure; screen pixels, origin top-left):
  - `export type Rect = { x: number, y: number, w: number, h: number }`, `export type Size = { w: number, h: number }`
  - `UiLayout.beside(anchor: Rect, tip: Size, screen: Size, gap: number): { x: number, y: number }`: right of the anchor if it fits, else left, else above (centred, clamped); y level with the anchor, clamped to the screen.
  - `UiLayout.above(anchor: Rect, tip: Size, screen: Size, gap: number): { x: number, y: number }`: centred over the anchor, clamped to the screen.
  - `UiLayout.inspectorCard(view: Size, fovDeg: number, distance: number, card: Size, offsetY: number, cardRightPx: number, marginPx: number): (number, Rect)`: the 3D card's sideways offset in studs so its right edge lands on `cardRightPx` (never left of `marginPx`), and its rect on screen. `fovDeg` is vertical (Camera.FieldOfView); `offsetY` studs up.
- Produces (`CompareRules`, pure):
  - `CompareRules.MIN_SHARE = 0.04`
  - `CompareRules.share(value: number, reference: number): number` (0..1, at least MIN_SHARE; 1 when reference <= 0)
  - `CompareRules.pair(incoming: number, outgoing: number): (number, number, "in" | "out" | "tie")` (shares against the bigger of the two)
  - `CompareRules.verdict(inPower: number, outPower: number?): ("stronger" | "weaker" | "same", number)` (rounded delta; nil out = compared with 0)
  - `CompareRules.verdictText(inPower: number, outPower: number?): string`
  - `CompareRules.swapText(inPower: number, outPower: number?): string`
  - `CompareRules.reference(statsList: { { hp: number, atk: number, spd: number } }): { hp: number, atk: number, spd: number }`
- Produces (`BossRules`):
  - `export type Step = { cleared: boolean, unlocked: boolean, keyNeeded: number, fragments: number, shopLevel: number, needLevel: number, power: number, recommended: number }`
  - `BossRules.stepState(step: Step): "beaten" | "ready" | "tooWeak" | "locked"`: cleared -> beaten; shop level short -> locked; not unlocked and fragments < keyNeeded -> locked; power >= recommended -> ready; else tooWeak.
  - `BossRules.travelChoice(bossPlace: string, here: string): "gate" | "toFrontier" | "toMain" | "viaPortal" | "none"` (`here`: "Main" | "Frontier" | "Dungeon")
- Produces (`ItemRules`): `ItemRules.bossOf(itemId: string, ladder: { string }): (number?, ("fragment" | "trophy")?)` from the `fragment_<bossId>` / `trophy_<bossId>` ids.

- [ ] **Step 1: Write the failing tests**

`tests/UiLayout.spec.luau`:
```lua
--!strict
local UiLayout = require("../src/shared/Util/UiLayout")
local expect = require("./lib/expect")

local SCREEN = { w = 1000, h = 600 }
local TIP = { w = 200, h = 150 }

return {
	["beside: right of the anchor when it fits"] = function()
		local spot = UiLayout.beside({ x = 100, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 168, "right of the card")
		expect.equal(spot.y, 50, "level with it")
	end,
	["beside: flips left near the right edge"] = function()
		local spot = UiLayout.beside({ x = 850, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 642, "left of the card")
	end,
	["beside: kept on screen at the bottom"] = function()
		local spot = UiLayout.beside({ x = 100, y = 560, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.y, 450, "pushed up to fit")
	end,
	["beside: no room either side goes above, never over the card"] = function()
		local spot = UiLayout.beside({ x = 150, y = 300, w = 60, h = 80 }, TIP, { w = 360, h = 600 }, 8)
		expect.equal(spot.y, 142, "above the card")
		expect.equal(spot.x, 80, "centred on it")
	end,
	["above: centred over the anchor, clamped to the screen"] = function()
		local spot = UiLayout.above({ x = 900, y = 500, w = 50, h = 60 }, { w = 230, h = 180 }, SCREEN, 8)
		expect.equal(spot.x, 770, "clamped to the right edge")
		expect.equal(spot.y, 312, "above the slot")
	end,
	["inspectorCard: the card's right edge lands on the panel"] = function()
		local offset, rect = UiLayout.inspectorCard({ w = 1000, h = 500 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 480, 8)
		expect.near(offset, -1.068, 0.01, "studs left of centre")
		expect.near(rect.x + rect.w, 480, 1, "right edge on the panel")
		expect.near(rect.h, 305.9, 1, "about 61% of the height")
		expect.near(rect.y, 97, 1, "centred vertically")
	end,
	["inspectorCard: a phone keeps the card on screen"] = function()
		local _, rect = UiLayout.inspectorCard({ w = 844, h = 390 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 100, 8)
		expect.near(rect.x, 8, 1, "never off the left edge")
	end,
}
```

`tests/CompareRules.spec.luau`:
```lua
--!strict
local CompareRules = require("../src/shared/Util/CompareRules")
local expect = require("./lib/expect")

return {
	["share: against the strongest card's stat, never an empty bar"] = function()
		expect.near(CompareRules.share(50, 200), 0.25, 1e-9, "a quarter")
		expect.equal(CompareRules.share(300, 200), 1, "capped")
		expect.equal(CompareRules.share(0, 200), CompareRules.MIN_SHARE, "a sliver")
		expect.equal(CompareRules.share(10, 0), 1, "no reference")
	end,
	["pair: the bigger stat fills its bar and wins"] = function()
		local a, b, winner = CompareRules.pair(120, 80)
		expect.equal(a, 1, "incoming full")
		expect.near(b, 0.667, 0.001, "outgoing two thirds")
		expect.equal(winner, "in", "incoming wins")
		local _, _, other = CompareRules.pair(5, 9)
		expect.equal(other, "out", "outgoing wins")
		local c, d, tie = CompareRules.pair(0, 0)
		expect.equal(c, CompareRules.MIN_SHARE, "empty in")
		expect.equal(d, CompareRules.MIN_SHARE, "empty out")
		expect.equal(tie, "tie", "a tie")
	end,
	["verdict: stronger, weaker or the same, by rounded Power"] = function()
		local kind, delta = CompareRules.verdict(212.4, 190.2)
		expect.equal(kind, "stronger", "stronger")
		expect.equal(delta, 22, "rounded")
		expect.equal(CompareRules.verdictText(212.4, 190.2), "STRONGER +22", "badge")
		expect.equal(CompareRules.verdictText(202, 2614), "WEAKER -2412", "badge")
		expect.equal(CompareRules.verdictText(150, 150), "SAME POWER", "badge")
		expect.equal((CompareRules.verdict(300, nil)), "stronger", "an empty slot")
	end,
	["swapText: the line on each party slot"] = function()
		expect.equal(CompareRules.swapText(212, 190), "+22 if swapped", "gain")
		expect.equal(CompareRules.swapText(190, 212), "-22 if swapped", "loss")
		expect.equal(CompareRules.swapText(190, nil), "Empty: adds it", "empty slot")
	end,
	["reference: the highest of each stat"] = function()
		local ref = CompareRules.reference({ { hp = 10, atk = 5, spd = 7 }, { hp = 8, atk = 9, spd = 7 } })
		expect.equal(ref.hp, 10, "hp")
		expect.equal(ref.atk, 9, "atk")
		expect.equal(ref.spd, 7, "spd")
		expect.equal(CompareRules.reference({}).hp, 0, "no cards")
	end,
}
```

Add to `tests/BossRules.spec.luau`:
```lua
	["stepState: beaten, ready, too weak or locked"] = function()
		local base: BossRules.Step = { cleared = false, unlocked = true, keyNeeded = 0, fragments = 0, shopLevel = 10, needLevel = 5, power = 500, recommended = 400 }
		local function with(fields: { [string]: any }): BossRules.Step
			local step = table.clone(base) :: any
			for key, value in fields do
				step[key] = value
			end
			return step
		end
		expect.equal(BossRules.stepState(with({ cleared = true, power = 1 })), "beaten", "beaten first")
		expect.equal(BossRules.stepState(base), "ready", "open and strong enough")
		expect.equal(BossRules.stepState(with({ power = 399 })), "tooWeak", "open, Power short")
		expect.equal(BossRules.stepState(with({ shopLevel = 4 })), "locked", "below the shop level")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 2 })), "locked", "short of fragments")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 3 })), "ready", "enough fragments counts as open")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 3, power = 10 })), "tooWeak", "can start, too weak")
		expect.equal(BossRules.stepState(with({ unlocked = false })), "ready", "no key needed, no data yet")
	end,
	["travelChoice: the gate in this place, else the normal travel"] = function()
		expect.equal(BossRules.travelChoice("Wild", "Main"), "gate", "Wild boss from the main game")
		expect.equal(BossRules.travelChoice("Frontier", "Main"), "toFrontier", "Frontier boss from the main game")
		expect.equal(BossRules.travelChoice("Dungeon", "Main"), "viaPortal", "the Hydra")
		expect.equal(BossRules.travelChoice("Frontier", "Frontier"), "gate", "in the Frontier")
		expect.equal(BossRules.travelChoice("Wild", "Frontier"), "toMain", "Wild boss from the Frontier")
		expect.equal(BossRules.travelChoice("Dungeon", "Frontier"), "viaPortal", "the Hydra from the Frontier")
		expect.equal(BossRules.travelChoice("Wild", "Dungeon"), "none", "in a run")
		expect.equal(BossRules.travelChoice("Dungeon", "Dungeon"), "none", "in a run")
	end,
```

Add to `tests/ItemRules.spec.luau`:
```lua
	["bossOf: fragments and trophies name their ladder step"] = function()
		local ladder = { "meadowWarden", "caveBroodQueen", "emberColossus" }
		local index, kind = ItemRules.bossOf("fragment_caveBroodQueen", ladder)
		expect.equal(index, 2, "opens boss 2")
		expect.equal(kind, "fragment", "a fragment")
		index, kind = ItemRules.bossOf("trophy_meadowWarden", ladder)
		expect.equal(index, 1, "boss 1's trophy")
		expect.equal(kind, "trophy", "a trophy")
		expect.isNil((ItemRules.bossOf("xpTonic", ladder)), "not a boss item")
		expect.isNil((ItemRules.bossOf("fragment_unknownBoss", ladder)), "unknown boss")
	end,
```
Register `UiLayout` and `CompareRules` in `tests/run.luau`.

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run`
Expected: FAIL: the two new specs can't require their modules; the BossRules and ItemRules cases fail on missing functions.

- [ ] **Step 3: Implement the four modules' functions**

`inspectorCard`: `pps = view.h / (2 * distance * tan(rad(fovDeg / 2)))`; card pixels `card.w * pps` by `card.h * pps`; left = `max(cardRightPx - cardW, marginPx)`; offset = `(left + cardW / 2 - view.w / 2) / pps`; `rect.y = view.h / 2 - offsetY * pps - cardH / 2`. `beside` falls back to `above` when neither side fits. Add CLAUDE.md test-list names.

- [ ] **Step 4: Run them to see them pass**

Run: `lune run tests/run`
Expected: all pass, SourceOrder included.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Util tests CLAUDE.md
git commit -m "UI rules: tooltip and 3D card layout, swap comparison, boss steps and travel, boss items (Lune-tested)"
```

### Task 3: Look E in Config/UIStyle and UIKit

**Files:**
- Create: `src/shared/Config/UIStyle.luau`
- Modify: `src/client/Util/UIKit.luau` (colours, panel, header, button, new helpers; header comment)
- Modify: `DESIGN.md` 10.6 (look E replaces Midnight & Gold)

**Interfaces:**
- Produces (`Config/UIStyle`, plain data, client and server safe):
  - `PANEL = Color3.fromRGB(27, 34, 51)`, `ROW = Color3.fromRGB(36, 45, 66)`, `EDGE = Color3.fromRGB(11, 15, 26)`, `EDGE_THICKNESS = 3`, `LIP = 5`
  - `HEADERS = { Party = teal (54, 209, 196) -> (26, 143, 158), Cards = blue (90, 169, 255) -> (59, 123, 224), Bosses = red (255, 122, 122) -> (226, 59, 59), Bag = orange (255, 176, 102) -> (230, 120, 40), Default = Party's }` as `{ top: Color3, bottom: Color3 }`
  - `GOLD = (245, 180, 40)`, `BLUE = (70, 140, 235)`, `RED = (226, 59, 59)`, `GREEN = (36, 168, 90)`, `POWER = (255, 176, 102)`, `MONEY = (69, 212, 131)`, `GOOD = (69, 212, 131)`, `BAD = (255, 107, 107)`, `HINT = (226, 178, 72)`
  - `GRADES = { S = (255, 200, 40), A = (70, 140, 255), B = (69, 212, 131), C = (160, 160, 160) }`
  - `BAR = { height = 12, phoneHeight = 10, fillTop = (143, 240, 181), fillBottom = (47, 191, 106) }`
  - `TEXT = { body = 15, small = 13, name = 22, number = 23, title = 28 }`, `PHONE_TEXT_SCALE = 0.85`
  - `KEY_TINT_PRISM = Color3.fromRGB(235, 235, 255)` (the Hydra's fragments; others use their boss's `Cards.ELEMENTS` colour)
  - `LONG_PRESS = 0.45` (seconds, touch tooltips)
- Produces (`UIKit`, existing signatures kept):
  - `UIKit.Colors`: same keys; `Panel = UIStyle.PANEL`, `Row = UIStyle.ROW`, `Outline = UIStyle.EDGE`, `Accent = UIStyle.GOLD`, `Danger = UIStyle.RED`, `Success = UIStyle.GREEN`, plus new `Secondary = UIStyle.BLUE`.
  - `UIKit.panel(parent: Instance, name: string, title: string, header: string?): (Frame, ScrollingFrame)`: `header` is a `UIStyle.HEADERS` key (default `"Default"`); body PANEL, EDGE outline, drop lip under the bottom edge, coloured header band with a dark line under it, outlined white title.
  - `UIKit.header(parent: GuiObject, title: string, header: string?): (Frame, TextLabel)`
  - `UIKit.button(parent: Instance, text: string, color: Color3): TextButton`: candy: vertical gradient (colour lightened at the top), EDGE outline, darker bottom lip, outlined white text on dark colours (navy on light ones as today).
  - `UIKit.outlined(text: TextLabel | TextButton, thickness: number?): UIStroke` (Contextual UIStroke in EDGE, default 2; a TextButton keeps its Border stroke as well)
  - `UIKit.iconButton(parent: Instance, text: string, icon: string, color: Color3): TextButton` (icon left of the text; `text == ""` gives an icon-only square)
  - `UIKit.pill(parent: Instance, text: string, fill: Color3, textColor: Color3?): TextLabel` (rounded, auto width, 24 px high)
  - `UIKit.bar(parent: Instance, share: number, fill: Color3?): (Frame, Frame)` (track, fill; green gradient fill by default)
  - `UIKit.statRow(parent: Instance, icon: string, share: number): Frame` (icon then bar)
  - `UIKit.stars(parent: Instance, lit: number, total: number, size: number): Frame` (Star icons, dim ones at 0.7 transparency)
  - `UIKit.textSize(kind: "body" | "small" | "name" | "number" | "title"): number` (UIStyle.TEXT, times PHONE_TEXT_SCALE on phones)

- [ ] **Step 1: Write `Config/UIStyle.luau` with the values above** (header comment points to spec 3.1 and DESIGN.md 10.6).

- [ ] **Step 2: Restyle UIKit**

Keep every existing function and signature; `UIKit.Colors` keys unchanged so the other ~60 `UIKit.button` callers just restyle. Add the helpers above (UIKit may require `Icon`; check Icon does not require UIKit). Two UIStrokes on one TextButton (Border + Contextual) give outline and text outline; if Studio shows only one, fall back to `TextStrokeTransparency = 0` / `TextStrokeColor3 = EDGE` for button text and ledger it.

- [ ] **Step 3: Tests**

Run: `lune run tests/run`
Expected: all pass (SourceOrder covers the new requires).

- [ ] **Step 4: Look at it in Studio**

Make sure the main Rojo server runs (`rojo serve` in the background if `tasks` shows none for default.project.json). Studio MCP: start Play in the main window; `get_console_output` has no new errors; open three existing windows that use UIKit (Jobs, Pricing, Rarity guide via the Manage tray) and `screen_capture` each.
Expected: dark slate panels with thick outline, teal header band with outlined title, candy buttons with lip; text readable on every button colour.

- [ ] **Step 5: DESIGN.md 10.6 and commit**

```bash
git add src/shared/Config/UIStyle.luau src/client/Util/UIKit.luau DESIGN.md
git commit -m "Look E style kit: Config/UIStyle and UIKit (header bands, candy buttons, outlined text, pills, bars, stars)"
```

### Task 4: HUD status column

**Files:**
- Modify: `src/client/Controllers/UIController.luau:285-345, 475` (shard pill out, cash pill restyled)
- Modify: `DESIGN.md` 10.6 (HUD layout line: no Star Shards pill)

**Interfaces:**
- Consumes: `UIStyle.GREEN`, `UIStyle.EDGE`, `UIKit.outlined`.

- [ ] **Step 1: Remove the Star Shard pill** (`shardsPill`, `shardsLabel`, `SHARD_COLOR`, `updateShards` and its `ItemsChanged` hook; nothing else may reference them: `grep -n "shards" src/client/Controllers/UIController.luau` returns nothing after).
- [ ] **Step 2: Cash pill as a green candy pill** with outlined white text and the Cash icon; the level pill keeps its XP bar, restyled to the kit (EDGE outline).
- [ ] **Step 3: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; `screen_capture` the bottom-right corner on desktop and in the Device emulator's landscape phone (Studio `skill` tool `rbx-device-simulator-lua`).
Expected: cash pill green with outlined text, no shard pill, level pill under it; nothing overlaps the party bar or the Roblox buttons.

- [ ] **Step 4: Commit**

```bash
git add src/client/Controllers/UIController.luau DESIGN.md
git commit -m "HUD: Star Shards pill removed (shards live in the Bag); cash as a green candy pill"
```

### Task 5: CardTips widget and the binder hover tooltip

**Files:**
- Create: `src/client/Util/CardTips.luau`
- Modify: `src/client/Controllers/BinderController.luau:923-977` (tooltip built by CardTips, placed by `UiLayout.beside`)
- Modify: `DESIGN.md` (binder tooltip line)

**Interfaces:**
- Consumes: `UiLayout.beside`, `UIKit.pill/statRow/stars/outlined/textSize`, `CardFace.render`, `Config/Rarities`, `Cards.ELEMENTS`, `UIStyle.GRADES`.
- Produces:
  - `export type CardInfo = { card: Card, owned: number, onDisplay: number, bestGrade: string?, bestLevel: number?, power: number?, worthLow: number?, worthHigh: number? }`
  - `CardTips.card(holder: Frame, info: CardInfo)`: fills `holder` (clears it first): art thumbnail, name, `#05`; pills for rarity (Rarities colour), element (icon + colour), best grade (GRADES colour); a 2x2 grid with icons: Power (Power icon, POWER colour), copies (Copies icon, "18" plus "· 2 on display" small when any), best level (Level icon), best grade (Best icon); worth range in MONEY with the Cash icon; "Click for details" in HINT. Not collected: art dimmed, rarity and element pills, "Not collected yet".
  - `export type CopyInfo = { card: Card, foil: boolean, grade: string, level: number, stars: number, power: number, stats: { hp: number, atk: number, spd: number }, reference: { hp: number, atk: number, spd: number }, perk: string?, restSeconds: number? }`
  - `CardTips.copy(holder: Frame, info: CopyInfo)`: art, name, grade pill, `Lv n`, Power; three statRows (Hp, Atk, Spd icons, `CompareRules.share` against `reference`); perk line (element icon + text); when `restSeconds > 0` a red line with the Hourglass icon "Resting m:ss".
  - `CardTips.reference(): { hp: number, atk: number, spd: number }`: `CompareRules.reference` over every card at MAX_LEVEL, MAX_STARS, grade S, foil (cached).
  - `CardTips.art(parent: Instance, card: Card, foil: boolean, size: Vector2): Frame`: a small card face (CardFace.render) with a rarity-coloured EDGE frame; the Party window, the chooser and the comparison use it too.

- [ ] **Step 1: Write CardTips** (holder auto-sizes in Y; width 250 desktop, 220 phone).
- [ ] **Step 2: Binder uses it**: `showTooltip` builds `CardInfo` from `getOwnedCounts`, `getBestGrade`, `getRaised`, `getEntries`; position from `UiLayout.beside(pocketRect, holder.AbsoluteSize, screenSize, 8)`; mouse only as today; never while the detail view or Bag shows.
- [ ] **Step 3: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; `/maxcard Solarion`, open the binder (B), hover a pocket near the right edge and one in the middle (`user_mouse_input` move), `screen_capture`.
Expected: tooltip beside the pocket, flipped left near the edge, never over the pocket; coloured pills and icons; no emoji.

- [ ] **Step 4: Commit**

```bash
git add src/client/Util/CardTips.luau src/client/Controllers/BinderController.luau DESIGN.md
git commit -m "Binder: icon tooltip (pills, stat grid, worth) placed beside the pocket"
```

### Task 6: Card detail view

**Files:**
- Modify: `src/shared/Config/Inspector.luau` (`STAGE_POSITION = Vector3.new(0, 2500, 0)`, `OFFSET_Y = 0.15`, `MARGIN_PX = 12`, `RIBBON_TEXT = "BEST COPY"`; `OFFSET_X` removed)
- Modify: `src/client/Controllers/CardInspectorController.luau`
- Modify: `src/client/Controllers/BinderController.luau:297-560, 979-990, 1098-1305` (detail panel rebuilt; Add to Party chooser shell stays for Task 7)
- Modify: `DESIGN.md` 10.6 (inspector stage), binder card view section

**Interfaces:**
- Consumes: `UiLayout.inspectorCard`, `CondenseRules.countDuplicates`, `BeastRules.getStats/getXpToNext/getCondenseCost`, UIKit helpers, `UIStyle`.
- Produces:
  - `CardInspectorController.Show(card: Card, foil: boolean, growth: Growth?, ribbon: string?)` (ribbon drawn on the card's front SurfaceGui; part of the shown key)
  - `CardInspectorController.SetCardRight(px: number)` (the panel's left edge minus a gap; the card follows it every frame)
  - `CardInspectorController.GetCardRect(): UiLayout.Rect?` (for the Flip button under the card)
  - While open the camera sits at `CFrame.new(Inspector.STAGE_POSITION)` (Scriptable); Close restores the saved CFrame then the saved CameraType.

- [ ] **Step 1: Inspector stage and placement**: save `camera.CFrame` with the CameraType on first Show; move to the stage; each RenderStepped compute `offset, rect = UiLayout.inspectorCard({w=vp.X,h=vp.Y}, camera.FieldOfView, Inspector.DISTANCE, {w=CARD_SIZE.X,h=CARD_SIZE.Y}, Inspector.OFFSET_Y, cardRight, Inspector.MARGIN_PX)`; card at `camera.CFrame * CFrame.new(offset, OFFSET_Y, -DISTANCE)`; keep the backdrop sheet and the tag hiding. Ribbon: gold band across the top corner with the Best icon and outlined text.
- [ ] **Step 2: Detail panel (blue header band look, right side)**: width `min(520, 52% of screen)` (phones: `min(440, 56%)`), full height under the binder's close button. Top: name (outlined, name size); pills rarity, element (icon), `#05`, copies (Copies icon "x18", "· 2 on display" when any); worth range right-aligned in MONEY with the Cash icon.
  - "Your copies" list (scrolls if long), best first (existing `getEntries` order): grade pill, `Lv n`, stars widget, FOIL tag or `x3` count, Power (icon, POWER), value (MONEY). Row 1 carries a gold **BEST** ribbon with the Best icon; the selected row has a gold outline. Big card ribbon: `RIBBON_TEXT` when the selected entry is entry 1.
  - Selected-copy box: four tiles Power / HP / ATK / SPD (icons, numbers); XP bar `Lv n -> n+1` (gold "MAX LEVEL" at max); next-star bar: have = `CondenseRules.countDuplicates(graded[card.id], main)` vs need = `getCondenseCost(stars)`, numbers in BAD when short, "Max stars" at max; status line "In party" / "Working: <job>" when so.
  - Buttons (icons): Add to party (gold, Party icon), Give a job (blue, Job icon; disabled grey with its reason: "In party", "Working: <job>", "Jobs at shop Lv N", "Slots full (u/s)"), Back (blue, Close icon). Flip (blue, Flip icon) sits under the 3D card from `GetCardRect()`.
  - Keep: the "how to sell" hint as one small line; a card only on display opens with its copies list showing "On display: n" and both buttons disabled.
- [ ] **Step 3: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; `/maxcard Solarion`, `/givecard 5 6`; binder, open Solarion, then card 5; `screen_capture` desktop and phone (Device emulator, landscape).
Expected: nothing of the world behind the card (walk next to a customer first); card right edge just left of the panel; BEST ribbon on row 1 and BEST COPY on the card; the next-star numbers red when short; buttons with reasons; drag-tilt, Flip and the Legendary aura still work; Back restores the camera where it was.

- [ ] **Step 4: Commit**

```bash
git add src/shared/Config/Inspector.luau src/client/Controllers/CardInspectorController.luau src/client/Controllers/BinderController.luau DESIGN.md
git commit -m "Card detail: camera on an empty stage, card beside the panel, BEST ribbons, stat tiles, XP and star bars, buttons with reasons"
```

### Task 7: Add to Party chooser and the kid comparison

**Files:**
- Create: `src/client/Util/CopyCompare.luau`
- Modify: `src/client/Controllers/BinderController.luau` (`refreshPartyChooser`, chooser frame in `buildDetail`)
- Modify: `DESIGN.md` (party section: the chooser)

**Interfaces:**
- Consumes: `CompareRules.verdict/verdictText/pair/swapText`, `PartyRules.getPerk/describe`, `CardTips.art`, UIKit.
- Produces:
  - `export type Side = { card: Card, foil: boolean, power: number, stats: { hp: number, atk: number, spd: number }, perk: string? }`
  - `CopyCompare.build(holder: Frame, incoming: Side, outgoing: Side)`: verdict badge (GOOD with Check icon / BAD with Remove icon / grey for same); IN art (green border, "IN" tag) -> Next icon -> OUT art (faded, "OUT" tag); three rows Hp/Atk/Spd icons with paired bars from `CompareRules.pair` (winner green gradient, other grey; hovering a bar shows its number); one line: incoming element icon "replaces" outgoing element icon, then "new perk: <text>" or "you lose its perk".

- [ ] **Step 1: Write CopyCompare.**
- [ ] **Step 2: Chooser**: title "Add <card> to your party" (outlined); three slot cards: art, name, `Lv n`, grade pill, Power, and `CompareRules.swapText` in GOOD/BAD. Empty slot: "Empty: adds it", tapping fires `SetPartySlot` straight away. A filled slot opens the comparison over the chooser with "Swap with <card>" (gold, Party icon) and Cancel (blue); Swap fires `Remotes.SetPartySlot:FireServer(slot, partyTarget)` as today.
- [ ] **Step 3: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; party with Solarion in one slot and an empty slot; open a weak card, Add to party; `screen_capture` the chooser, the WEAKER comparison against Solarion, then add to the empty slot; phone capture.
Expected: verdict readable without reading the rest; empty slot fills at once; buttons 48 px on the phone.

- [ ] **Step 4: Commit**

```bash
git add src/client/Util/CopyCompare.luau src/client/Controllers/BinderController.luau DESIGN.md
git commit -m "Add to Party: slot cards with the swap gain, kid comparison (verdict badge, IN/OUT, paired bars)"
```

### Task 8: Party window

**Files:**
- Modify: `src/client/Controllers/PartyController.luau` (rows -> three columns)
- Modify: `DESIGN.md` (party panel)

**Interfaces:**
- Consumes: `UIKit.panel(..., "Party")`, `CardTips.art`, `CardTips.reference`, `CompareRules.share`, `RestTimers`, `BinderController.Open`, `PartyRules`.

- [ ] **Step 1: Layout**: panel max 780 x 500 (phones fill the screen); header chips: Summon icon "Summoned: <name>" or "Nobody summoned", Pvp icon "PvP W - L" (" - D" when draws > 0). Three equal columns, no scrolling: art (CardFace, 92x124; phone 64x88), name (outlined), grade pill + `Lv n` + stars, Power big in POWER with its icon, three statRows, perk line (element icon + `PartyRules.describe`), rest line (Hourglass, BAD, "Resting m:ss" updated by the existing 0.5 s tick), buttons: Summon (gold, Summon icon) or Summoned (GREEN, Check icon; tapping unsummons as today), XP Tonic (blue icon button with a count badge; hidden at 0 tonics or max level), Remove (red icon button, Remove icon). The summoned column glows green with a "SUMMONED" tag. Empty slot: "+ Add a card" (blue) opens `BinderController.Open("Tap a card, then Add to party")`.
- [ ] **Step 2: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; party of three with one summoned and one resting (`/rest` wakes; let one faint in the Wild or skip if slow); `screen_capture` desktop and phone.
Expected: three columns fit on the phone without scrolling; summoned one green; header uncrowded.

- [ ] **Step 3: Commit**

```bash
git add src/client/Controllers/PartyController.luau DESIGN.md
git commit -m "Party window: three columns with bars, perk, rest timer; Summoned glow, tonic and remove icon buttons"
```

### Task 9: HUD party card tooltip

**Files:**
- Modify: `src/client/Controllers/PartyBarController.luau` (slot hover and long-press)
- Modify: `DESIGN.md` (party bar)

**Interfaces:**
- Consumes: `CardTips.copy`, `UiLayout.above`, `UIStyle.LONG_PRESS`, `RestTimers.GetSeconds`.

- [ ] **Step 1**: one tooltip holder on the HUD ScreenGui; MouseEnter on a filled slot shows `CardTips.copy` above it (`UiLayout.above`, gap 10), MouseLeave hides. Touch: a press held `LONG_PRESS` shows it and swallows that press's tap (no summon); release hides. Hidden while any panel is open (`UIKit.pointerBlocked`-style check) and when the slot empties.
- [ ] **Step 2: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; hover each of the three cards (`user_mouse_input`), `screen_capture`; phone emulator: confirm a tap still summons.
Expected: tooltip above the card, inside the screen, stats match the Party window.

- [ ] **Step 3: Commit**

```bash
git add src/client/Controllers/PartyBarController.luau DESIGN.md
git commit -m "Party bar: hover (or long-press) a card for its stats"
```

### Task 10: Boss ladder and "Take me there"

**Files:**
- Modify: `src/shared/Remotes.luau` (`"BossTravel", -- client → server: (index: number) go to boss n's gate in this place`, plus the table entry)
- Modify: `src/shared/Config/Bosses.luau` (`TRAVEL_COOLDOWN = 3`)
- Modify: `src/server/Services/BossService.luau` (handler)
- Modify: `src/client/Controllers/BossBoardController.luau` (rebuilt)
- Modify: `DESIGN.md` (boss board, remotes)

**Interfaces:**
- Consumes: `BossRules.stepState/travelChoice`, `ItemRules.bossOf`, `Items.ITEMS[id].icon` (Task 1), `Remotes.FrontierTravel` ("explore" / "home"), `WildService.TravelToWild(player, gate)`, `RateLimiter.new(Bosses.TRAVEL_COOLDOWN)`.
- Produces: `Remotes.BossTravel`.

- [ ] **Step 1: Server**: `onTravel(player, raw)`: `raw` an integer in `1..#Bosses.LADDER` else return; rate limit; `here` from `Place` ("Main" / "Frontier" / "Dungeon"); only `travelChoice(boss.place, here) == "gate"` with `BossService.GetGate(index)` acts: `WildService.TravelToWild(player, gate)` (its travel blockers refuse during a fight); otherwise notify why. Connect in `BossService.Start`.
- [ ] **Step 2: Board**: `UIKit.panel(screenGui, "Bosses", "Boss Ladder", "Bosses")`, Trophy icon in the header, max 860 x 540. Ladder: seven discs on a line (element icon; the Hydra the Gem icon), number and name under each, badge by `stepState`: beaten (gold ring, Trophy), ready (GOOD ring and glow, Check), tooWeak (BAD ring, no badge), locked (faded, Lock). Step data: `keyNeeded = unlock.count or 0`, `fragments`, `unlocked`, `cleared` from `states` (no state: unlocked false, fragments 0), shop level from the Level attribute, power from `bestPower()`. Selected disc scaled 1.12; default selection: the first not beaten and not locked, else the last beaten, else 1.
  - Details, left: name (outlined), element pill, place pill (zone name / "The Frontier" / "The Dungeon"); not locked: two bars You vs Needed (Power numbers in POWER) and the verdict badge ("You're ready!" GOOD with Check / "Too weak" BAD); locked: a shop-level bar (your level / needed) and a fragments bar (KeyFragment icon tinted, have / need), each BAD until enough, GOOD when enough, with "Beat the <previous> to collect them".
  - Details, right: Hourglass "Full loot ready now" (GOOD) or the countdown; Trophy "Won n times today" plus the reduced-drops note when it applies; drops as item icons (`boss.drops` items, fragments tinted) with names on hover; the travel button by `travelChoice`: gate -> "Take me there" (gold, Travel icon) fires `BossTravel`; toFrontier -> "Go to the Frontier" fires `FrontierTravel("explore")`; toMain -> "Go home" fires `FrontierTravel("home")`; viaPortal -> a line "Enter the Dungeon portal in the Frontier" (no button); none -> nothing. Locked bosses still show the button (travel is allowed; the gate refuses the fight).
- [ ] **Step 3: Tests and Studio**

Run: `lune run tests/run` (all pass). Play (main); `/level 30`, `/boss 1 fight` to beat or skip; open the board (K); select each state; press Take me there for boss 1 (you land at its gate), for boss 4 (Frontier teleport only works published: expect the existing "teleports only work in the published game" style message), and the Hydra (portal line). `screen_capture` desktop and phone.
Expected: four states readable; travel works for the Wild gates; no errors in Output.

- [ ] **Step 4: Commit**

```bash
git add src/shared/Remotes.luau src/shared/Config/Bosses.luau src/server/Services/BossService.luau src/client/Controllers/BossBoardController.luau DESIGN.md
git commit -m "Boss ladder: path of steps (beaten, ready, too weak, locked), Power bars and verdict, Take me there"
```

### Task 11: Bag

**Files:**
- Modify: `src/client/Controllers/BinderController.luau:1340-1665` (slots, detail, overlay styling)
- Modify: `DESIGN.md` (Bag)

**Interfaces:**
- Consumes: `ItemRules.bossOf(id, Bosses.LADDER)`, `Cards.ELEMENTS`, `UIStyle.KEY_TINT_PRISM`, `UIKit.panel` look (`"Bag"` header band).

- [ ] **Step 1**: the overlay takes the kit (orange header band, dark body). Slot: icon via Icon; fragments tinted `Cards.ELEMENTS[boss.element]` (the Hydra's: KEY_TINT_PRISM) with a corner chip showing the boss number on the same tint; trophies with the boss-number chip; count badge `x<n>` from the real count (fix the bare "x"); counts outlined, at least 14 px on phones. Info panel dark: big icon (tinted the same), name (outlined), "You have n" in HINT, boxes "What it does" (description), "Where to get it" (source), "How to use" (use, when set).
- [ ] **Step 2: Tests and Studio**

Run: `lune run tests/run` (all pass). Play; `/item fragment_caveBroodQueen 13`, `/item fragment_prismHydra 3`, `/item trophy_meadowWarden 1`, `/item xpTonic 5`; Bag (I); select a fragment; `screen_capture` desktop and phone.
Expected: each key a different tint with its boss number; trophy count shows; info panel dark.

- [ ] **Step 3: Commit**

```bash
git add src/client/Controllers/BinderController.luau DESIGN.md
git commit -m "Bag: keys tinted per boss with its number, real trophy counts, dark info panel"
```

### Task 12: Phone pass, notes and hand-over

**Files:**
- Modify: `DESIGN.md` (13: project 1 done pending approval; projects 2-3 next)
- Modify: Obsidian vault `C:/Users/Ben/Documents/obsidian/card-shop-tycoon` (decisions log: look E, rarity colours kept, 3D card kept with the stage camera; lessons: the mockup server serves `/files/<name>` flat, two UIStrokes per text button result)

- [ ] **Step 1: Phone pass**: Device emulator, a landscape phone; open every rebuilt screen; fix anything clipped or under 48 px.
- [ ] **Step 2: Full tests**

Run: `lune run tests/run`
Expected: all pass.

- [ ] **Step 3: Commit, then the final review and the user's Studio check** (list per screen what to judge).

```bash
git add DESIGN.md
git commit -m "DESIGN: UI pass 1 done, awaiting Studio approval"
```
