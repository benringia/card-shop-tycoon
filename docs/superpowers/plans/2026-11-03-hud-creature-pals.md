# Town HUD "Creature pals" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the always-on HUD (tiles, party bar, cash, level/XP, buff chip) in the owner's pick C, with a swappable mascot (Cindercub) peeking over the party bar.

**Architecture:** The look lives in the existing builders: `Util/Hud` (tiles), `PartyBarController` (party bar), `UIController` (cash, level), `BuffController` (chip). New pure modules (`Util/XpPaws`, `Util/HudMascotRules`) hold the maths and are Lune-tested; `Config/HudMascot` (plain data) holds everything about the mascot so another creature can replace it; `Client/Util/HudMascotView` draws and animates it with looping tweens and one blink timer.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Figma image generator + Pillow for the sticker, Studio MCP for checks and image upload.

**Spec:** `docs/superpowers/specs/2026-11-03-hud-creature-pals-design.md`

**Branch:** `hud-creature-pals`, cut from `fight-polish` (which holds the spec and is not merged yet).

## Global Constraints

- Every tap target at least 48 px at the smallest HUD scale (`HudLayout.SCALE.MIN` = 0.7); nothing over the mobile thumbstick or jump button.
- Elements keep today's places, size classes and behaviour; no button changes what it does.
- No per-frame work on more than a handful of instances; no per-frame tweens per tile.
- Text: plain ASCII plus `·` and emoji only; fonts FredokaOne and Nunito Bold via `Util/FontStyle`.
- UI built in code with `Util/UIKit`; numbers in config (`Config/HudLayout`, `Config/HudMascot`), none in controllers.
- Pure logic in Roblox-free modules with Lune tests; pure modules don't require siblings; Lune can't build Color3 or Vector2, so tested configs are plain data.
- Images uploaded as Roblox images; every id checked by drawing it and reading `IsLoaded`.
- Same HUD in the main game, the Frontier and the Dungeon.
- Many files are CRLF: keep each file's line endings.
- Colours from the spec: Cards `#7fb8ff`→`#4a7fe0` (ears), Bag `#ff9e7a`→`#f0603c` (ears), Bosses `#c79bff`→`#8a55e0` (horns), Manage `#ffd36b`→`#f2a52b`, Admin grey, Rip/Drop `HudLayout.CONTEXT` orange; cushion `#fff6ea`→`#f6dfc4`; cash `#8ee09a`→`#3fb35a`.

## Review Focus

1. Touch screens stack the status corner as a column from the top right (buff, cash, level, then the party bar): the mascot's head must sit in reserved headroom, never over the level pill (Task 4 reserves it from `HudMascotRules.headroom`; Task 7 checks it in the Device emulator).
2. Summon or swap spammed: the duck restarts from where the mascot is and always ends fully up (Task 1 test `a duck restarted mid-way ...`).
3. XP at the top level or still loading: `getProgress` can give a span of 0 or the XP attribute is missing; paws must not divide by zero (Task 1 test `a zero or negative span fills every paw`), and the tooltip says "Loading your shop..." while loading (Task 3).
4. No mascot picture yet (or an empty id): no headroom, no mascot, no errors (Task 1 test `no picture means no headroom`; Task 6 hides it).
5. The HUD hidden (binder open, a fight): the mascot and the XP tooltip hide with the bar and the duck tween doesn't error on a hidden frame (Task 6 step; checked in Task 7).

---

### Task 1: Pure rules and the mascot config

**Files:**
- Create: `src/shared/Util/XpPaws.luau`, `src/shared/Util/HudMascotRules.luau`, `src/shared/Config/HudMascot.luau`
- Create: `tests/XpPaws.spec.luau`, `tests/HudMascotRules.spec.luau`
- Modify: `tests/run.luau` (register both specs)

**Interfaces:**
- Produces:
  - `XpPaws.fills(into: number, span: number, count: number): { number }` — `count` shares 0-1, left to right.
  - `HudMascotRules.nextBlink(roll: number, cfg): number` — seconds until the next blink, `cfg.blink.every[1]..[2]`.
  - `HudMascotRules.duckShare(t: number, cfg): number` — how far down (0 up, 1 fully hidden) `t` s into a duck of `cfg.duck = { down, hold, up }`; 0 for `t <= 0` and after the duck.
  - `HudMascotRules.restartAt(share: number, cfg): number` — the `t` to restart a duck from so it continues from `share` on its way down.
  - `HudMascotRules.bounce(t: number, cfg): number` — the tap bounce scale, `1 + cfg.tap.scale * sin(pi * t / cfg.tap.seconds)`, 1 outside it.
  - `HudMascotRules.headroom(cfg): number` — pixels the party bar keeps free above the cushion: `cfg.headroom` when `cfg.images.peek ~= ""`, else 0.
  - `Config/HudMascot` (plain data): `{ name, images = { peek, tail }, size = { peek = {w, h}, tail = {w, h} }, eyes = { { x, y, w, h } } (shares of the peek picture), lid = { r, g, b }, voice = { id, volume, pitch = { min, max } }, headroom, offset = { right, overlap }, blink = { every = { min, max }, seconds }, breath = { period, scale }, tail = { period, degrees }, duck = { down, hold, up }, tap = { seconds, scale } }`. Pictures `""` until Task 5; voice `Party.VOICE.small[1]` (`rbxassetid://9117237144`), volume 0.3.

- [ ] **Step 1: Write the failing tests**

`tests/XpPaws.spec.luau`:
```lua
["paws fill left to right with progress"] = function()
	local f = XpPaws.fills(38, 100, 5)
	expect.equal(#f, 5)
	expect.equal(f[1], 1); expect.near(f[2], 0.9, 1e-9); expect.equal(f[3], 0); expect.equal(f[5], 0)
end,
["no progress, full progress"] = function()
	for _, v in XpPaws.fills(0, 100, 5) do expect.equal(v, 0) end
	for _, v in XpPaws.fills(100, 100, 5) do expect.equal(v, 1) end
	for _, v in XpPaws.fills(250, 100, 5) do expect.equal(v, 1, "over the span stays full") end
	for _, v in XpPaws.fills(-5, 100, 5) do expect.equal(v, 0, "below zero stays empty") end
end,
["a zero or negative span fills every paw"] = function()
	for _, v in XpPaws.fills(0, 0, 5) do expect.equal(v, 1) end
	for _, v in XpPaws.fills(3, -1, 5) do expect.equal(v, 1) end
end,
```

`tests/HudMascotRules.spec.luau` (CFG: `blink = { every = { 3, 7 }, seconds = 0.12 }, duck = { down = 0.15, hold = 0.35, up = 0.3 }, tap = { seconds = 0.35, scale = 0.12 }, headroom = 40, images = { peek = "rbxassetid://1", tail = "" }`):
```lua
["blinks come 3-7 s apart"] = function()
	expect.equal(HudMascotRules.nextBlink(0, CFG), 3); expect.equal(HudMascotRules.nextBlink(1, CFG), 7)
	expect.equal(HudMascotRules.nextBlink(9, CFG), 7, "a roll out of range is clamped")
end,
["a duck goes down, holds, comes back up"] = function()
	expect.equal(HudMascotRules.duckShare(0, CFG), 0)
	expect.near(HudMascotRules.duckShare(0.15, CFG), 1, 1e-9)
	expect.equal(HudMascotRules.duckShare(0.3, CFG), 1, "holding")
	expect.near(HudMascotRules.duckShare(0.8, CFG), 0, 1e-9, "back up")
	expect.equal(HudMascotRules.duckShare(5, CFG), 0)
	local mid = HudMascotRules.duckShare(0.65, CFG)
	expect.equal(mid > 0 and mid < 1, true, "on its way up")
end,
["a duck restarted mid-way continues from where it is and ends fully up"] = function()
	local t = HudMascotRules.restartAt(0.5, CFG)
	expect.near(HudMascotRules.duckShare(t, CFG), 0.5, 1e-6)
	expect.near(HudMascotRules.duckShare(t + 10, CFG), 0, 1e-9)
	expect.equal(HudMascotRules.restartAt(0, CFG), 0)
end,
["a tap bounce swells and settles"] = function()
	expect.equal(HudMascotRules.bounce(0, CFG), 1)
	expect.near(HudMascotRules.bounce(0.175, CFG), 1.12, 1e-9)
	expect.equal(HudMascotRules.bounce(1, CFG), 1)
end,
["no picture means no headroom"] = function()
	expect.equal(HudMascotRules.headroom(CFG), 40)
	expect.equal(HudMascotRules.headroom({ headroom = 40, images = { peek = "", tail = "" } }), 0)
end,
["the game's mascot config is sane"] = function()
	local m = require("../src/shared/Config/HudMascot")
	for _, id in { m.images.peek, m.images.tail, m.voice.id } do
		expect.equal(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
	end
	for _, eye in m.eyes do
		expect.equal(eye.x >= 0 and eye.y >= 0 and eye.x + eye.w <= 1 and eye.y + eye.h <= 1, true, "eyes inside the picture")
	end
	expect.equal(m.blink.every[1] > 0 and m.blink.every[2] >= m.blink.every[1], true)
	expect.equal(m.voice.volume > 0 and m.voice.volume <= 0.5, true, "quiet")
end,
```

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run XpPaws` and `lune run tests/run HudMascotRules`
Expected: errors requiring the missing modules.

- [ ] **Step 3: Implement `XpPaws`, `HudMascotRules` and `Config/HudMascot`**

Duck curve: down eased out over `down`, hold, up eased in over `up` (quad is enough). `restartAt(share)` returns the `t` on the down leg with that share (inverse of the down curve). Config values: `headroom = 40`, `offset = { right = 18, overlap = 10 }`, `size.peek = { 96, 72 }`, `size.tail = { 26, 36 }`, `breath = { period = 3.2, scale = 0.025 }`, `tail = { period = 2.4, degrees = 10 }`, `duck`/`blink`/`tap` as in the test CFG, `eyes = {}` until Task 5, `lid = { 220, 72, 32 }`.

- [ ] **Step 4: Run all tests**

Run: `lune run tests/run`
Expected: all pass (856 + new).

- [ ] **Step 5: Commit** — `git add src/shared/Util/XpPaws.luau src/shared/Util/HudMascotRules.luau src/shared/Config/HudMascot.luau tests/XpPaws.spec.luau tests/HudMascotRules.spec.luau tests/run.luau` then commit "HUD pals: XP paws, mascot rules and config".

### Task 2: Candy tiles

**Files:**
- Modify: `src/shared/Config/HudLayout.luau` (palette), `src/client/Util/Hud.luau` (`makeTile`, `addKeyChip`, `setFan`)

**Interfaces:**
- Produces: `HudLayout.CANDY: { [string]: { top: Color3, bottom: Color3, topper: ("ears" | "horns")? } }` keyed by tile id (`Cards`, `Bag`, `Bosses`, `Manage`, `Admin`, `Rip`, `Drop`), plus `CANDY_FAN: { { top: Color3, bottom: Color3 } }` (soft colours for Manage tray buttons by order, cycling), `OUTLINE = 4`, `SHADOW = { offset = 5, transparency = 0.75 }`, `CORNER = 0.27` (share of tile size). Unknown ids fall back to the Manage yellow.

- [ ] **Step 1: Restyle `makeTile`** — gradient fill from `CANDY[id]` (fan buttons from `CANDY_FAN`), white `UIStroke` `OUTLINE` thick, a shadow frame (same shape, black, `SHADOW.offset` px lower, behind the tile), rounded corner `CORNER * TILE_SIZE.X`; `topper = "ears"` adds two small rounded frames poking out of the top edge (tile colour, white outline, behind the tile's outline); `"horns"` two small white rotated squares. Keep the icon, label, `Motion.press`, `Activated`, Context visibility pop-in as they are.
- [ ] **Step 2: Key chip** — a white circle (24 px) on the bottom-right corner, dark FredokaOne letter.
- [ ] **Step 3: Manage open state** — `setFan` darkens the Manage gradient (both colours lerped 30% to black) instead of `TILE_DARK`; the "Close" icon and label swap stays.
- [ ] **Step 4: Check in Studio** — `rojo build -o <scratch>/test.rbxl`; Play; screenshot the bottom row, the side column and the open Manage tray; Output has no errors. Expected: tiles look like mockup C, labels readable, key circles on the corners.
- [ ] **Step 5: Commit** "HUD pals: candy tiles with ears and horns".

### Task 3: Cash, level and paws, buff chip

**Files:**
- Modify: `src/client/Controllers/UIController.luau` (`buildStatusPills`, `updateXp`), `src/client/Controllers/BuffController.luau` (chip look), `src/client/Util/Tooltip.luau`
- Modify: `src/shared/Config/HudLayout.luau` (`CASH = { top, bottom }`, `XP_PILL`, `PAWS = 5`, `PAW_ON`, `PAW_OFF_TRANSPARENCY = 0.78`)

**Interfaces:**
- Consumes: `XpPaws.fills` (Task 1).
- Produces: `Tooltip.attachLive(target: GuiObject, getText: () -> string)` — like `attach`, the text read when the tip shows.

- [ ] **Step 1: `Tooltip.attachLive`** — `hook` accepts a string or a function; `show` calls the function. `attach` unchanged.
- [ ] **Step 2: Cash pill** — green gradient (`CASH`), white outline, the `Coin` icon (`UIIcons.Coin`) larger than the pill overlapping its left end; text and `string.format("$%.2f")` unchanged; `Motion.bump` kept.
- [ ] **Step 3: Level pill** — white pill; the `Star` icon larger than the pill on its left end with the level number; the XP bar becomes `PAWS` paw images in a row, each a faint paw (`PAW_OFF_TRANSPARENCY`) with a coloured paw on top inside a clipping frame sized to its share (`XpPaws.fills(into, span, PAWS)`), updated in `updateXp` only. `Tooltip.attachLive(levelBadge, ...)` returns `XP {into} / {span}` or `Loading your shop...` while XP is missing.
- [ ] **Step 4: Buff chip** — white pill, the perk's emoji and value in the perk's colour; its tooltip unchanged.
- [ ] **Step 5: Check in Studio** — Play; screenshot the corner on PC; `/xp 50000` and watch the paws fill; hover the level for the tooltip. Expected: no errors; paws move only on XP change.
- [ ] **Step 6: Commit** "HUD pals: cash coin, level star with paws, white buff chip".

### Task 4: The cushion party bar

**Files:**
- Modify: `src/client/Controllers/PartyBarController.luau` (`Start`, `makeSlot`, `render`, `keyChip`, the rest timer loop), `src/shared/Config/Party.luau` (`BAR`)

**Interfaces:**
- Consumes: `HudMascotRules.headroom(HudMascot)` (Task 1).
- Produces: `PartyBarController.GetCushion(): Frame` (the cushion, for the mascot to sit on) and `PartyBarController.Summoned: RBXScriptSignal` (fires when the summoned slot changes, for the duck).

- [ ] **Step 1: Cushion** — `BAR.CUSHION = { top, bottom, base }` (cream colours as `{ r, g, b }`), white outline 4, a darker base line along the bottom (a gradient stop), rounded ends. Wrap it in a transparent frame with `headroom` px of top padding, so the status row (row on PC, column on touch) spaces it; the cushion keeps the bottom.
- [ ] **Step 2: Party pill** — remove the avatar button; a small cream "Party" pill (FredokaOne, at least 48 px tap area including padding) at the cushion's left end opens `PartyController.Toggle`; tapping the cushion's empty area does too.
- [ ] **Step 3: Round portraits** — `BAR.PORTRAIT = 48` and `BAR.PORTRAIT_OUT = 56`: card art in a circle with a 4 px white ring; summoned: orange ring, orange glow, "OUT" tag above, the larger size; level in a white pill under it; slot key chip (1-3) as today; empty: a faint ring with a "+" (tap picks a card, as today); resting: a dark circle over it with the timer (green with "+" at the spring, as today). Tooltip (`showTip`) unchanged.
- [ ] **Step 4: `Summoned` signal** — fire it from the `PartyChanged` handler when `summoned` changes (summon, unsummon, swap).
- [ ] **Step 5: Check in Studio** — Play; screenshot the bar on PC and with the Device emulator on a landscape phone; summon and unsummon; open the Party panel from the pill. Expected: nothing overlaps; taps work.
- [ ] **Step 6: Commit** "HUD pals: cushion party bar with round portraits".

### Task 5: The Cindercub sticker

**Files:**
- Create: `assets/ui/mascot/Cindercub_peek.png`, `assets/ui/mascot/Cindercub_tail.png` (not synced), `tools/ui-art/cutout.py`, `docs/hud-mascot.md`
- Modify: `src/shared/Config/HudMascot.luau` (ids, sizes, `eyes`, `lid`), `.gitignore` if the raw generations need it

**Interfaces:**
- Produces: `HudMascot.images.peek`, `HudMascot.images.tail` ids; `HudMascot.eyes` (two eye boxes as shares of the peek picture); `HudMascot.lid` (fur colour round the eyes).

- [ ] **Step 1: Generate** with Figma's image generator in the card art file (`docs/card-art.md` style), described from `assets/ui/card-art/Cindercub.jpg`: "cute chibi red bear cub with a small flame on its head, peeking over a ledge, only its head and two front paws visible, paws resting on the bottom edge, painterly stylized, soft lighting, flat plain pure green background, no text". The tail: "the same cub's short tail with a flame tip, alone, flat plain pure green background".
- [ ] **Step 2: `tools/ui-art/cutout.py <in> <out>`** (Pillow): keys out the green, softens the edge 1 px, trims to content, saves a transparent PNG at most 512 px. Run it on both.
- [ ] **Step 3: Upload** both PNGs (Studio MCP `upload_image` from a localhost URL, as the portal water texture was); put the ids in `HudMascot.images`; draw each in Studio and read `IsLoaded` (a one-pixel alpha nudge gives a new id if one never loads).
- [ ] **Step 4: Eyes** — measure the two eye boxes and the fur colour round them on the peek picture; set `eyes` and `lid`.
- [ ] **Step 5: `docs/hud-mascot.md`** — how to swap the mascot (the owner's real pet later): generate from a photo with the same two prompts, cut out, upload, update `Config/HudMascot` (ids, sizes, eyes, lid, voice), nothing else.
- [ ] **Step 6: Run** `lune run tests/run HudMascotRules` (config test now checks the ids and eye boxes). Expected: pass. Show the owner the sticker before Task 6.
- [ ] **Step 7: Commit** "HUD pals: Cindercub sticker".

### Task 6: The mascot on the cushion

**Files:**
- Create: `src/client/Util/HudMascotView.luau`
- Modify: `src/client/Controllers/PartyBarController.luau` (mount it)

**Interfaces:**
- Consumes: `PartyBarController.GetCushion()`, `PartyBarController.Summoned` (Task 4); `HudMascotRules` (Task 1); `HudMascot` config (Task 5).
- Produces: `HudMascotView.mount(cushion: Frame): ()`, `HudMascotView.duck(): ()` (the view is named apart from the `Config/HudMascot` data it reads).

- [ ] **Step 1: `mount`** — nothing when `images.peek == ""`. A clipping frame above the cushion's top edge near its right end (`offset.right`), bottom edge `offset.overlap` px into the cushion so the paws rest on the edge; the peek ImageLabel inside it; the tail ImageLabel on the cushion's right side (pivot at its top). Both `ZIndex` above the cushion, below the tooltip.
- [ ] **Step 2: Alive** — breathing: a looping, reversing tween on a `UIScale` (`breath`); tail: a looping, reversing rotation tween (`tail`); blink: one loop that waits `nextBlink(math.random())`, shows lid ovals (`lid` colour) over each `eyes` box for `blink.seconds`, hides them. No `RenderStepped`.
- [ ] **Step 3: Duck** — `HudMascotView.duck()` restarts from the current share (`restartAt`) and moves the peek picture down by `duckShare(t) * its height` inside the clip (a short Heartbeat connection that disconnects when the duck ends). Connected to `PartyBarController.Summoned`. Safe when the bar is hidden (check `Parent` and visibility before tweening).
- [ ] **Step 4: Tap** — a transparent button over the peek picture: `bounce` on the `UIScale` for `tap.seconds` and the voice (a `Sound` in `SoundService`, `voice.volume`, random pitch in `voice.pitch`).
- [ ] **Step 5: Check in Studio** — Play; screenshot the mascot on PC and phone; summon, unsummon and swap quickly several times (it always ends fully up); tap it; open the binder and start a fight (it hides with the bar); Output clean.
- [ ] **Step 6: Commit** "HUD pals: Cindercub peeks, blinks, ducks and chirps".

### Task 7: Check everywhere, docs

**Files:**
- Modify: `DESIGN.md` (UI section and file tree), `CLAUDE.md` (test list: `XpPaws`, `HudMascotRules`; `assets/ui/mascot` line), `docs/hud-mascot.md` if anything changed

- [ ] **Step 1: Places** — Play the Frontier window (`rojo serve frontier.project.json`, port 34873) and the Dungeon window (`rojo serve dungeon.project.json`, port 34874) and check the bar, cash and mascot in each.
- [ ] **Step 2: Phone** — Device emulator (Studio `skill` `rbx-device-simulator-lua`), two landscape phones: every tile and portrait at least 48 px, the mascot clear of the level pill, nothing over the thumbstick or jump.
- [ ] **Step 3: Frame cost** — with the HUD up, confirm no new per-frame connections besides a running duck (MicroProfiler or a RenderStepped/Heartbeat connection count before and after).
- [ ] **Step 4: Docs** — DESIGN UI section describes the creature pals HUD and the mascot swap; file tree gains `XpPaws`, `HudMascotRules`, `Config/HudMascot`, `Util/HudMascotView`, `tools/ui-art/cutout.py`, `assets/ui/mascot`.
- [ ] **Step 5: Run** `lune run tests/run`. Expected: all pass. `rojo build` succeeds.
- [ ] **Step 6: Commit** "HUD pals: docs" and tell the owner what to judge in Studio.
