# Loading Screen Binder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every loading screen becomes the binder with Pish, Chikin and Turts cards filling its pockets as real loading
progresses, over each world's painting, under a "ONE MORE PACK" ribbon; the game is renamed One More Pack; nobody gets
in (or moves) before their place has loaded, the Dungeon included.

**Architecture:** One builder, `ReplicatedFirst.LoadingScreen.LoadingGui`, builds and drives the binder from a place
look (`LoadingRules.look`, plain data in `Config/LoadingScreen`); the join screen (`Show.client`), the teleport copy
(`LoadingController`) and the Wild screen (`WildLoadingController`) all use it. Progress stays where it is
(`LoadingRules.progress`, `WildLoadingRules.progress`); a new pure `LoadingRules.pockets` turns a share into filled
pockets.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for checks and image
uploads.

**Spec:** `docs/superpowers/specs/2026-11-13-loading-screen-binder-design.md`

## Global Constraints

- Name: "One More Pack" (`Config/Game` NAME); ribbon text "ONE MORE PACK"; welcome "Welcome to One More Pack!".
- Accents: town gold `{255, 210, 60}` (drop `{107, 61, 0}`), Wild green `{74, 222, 128}` (drop `{13, 74, 36}`),
  Frontier icy `{150, 215, 255}` (drop `{23, 58, 99}`), Dungeon violet `{201, 162, 255}` (drop `{61, 26, 110}`).
- Place names above the count: "" (town), "THE WILD", "THE FRONTIER", "THE DUNGEON".
- Ribbon pink: top `{255, 92, 138}`, bottom `{214, 42, 100}`, text drop `{122, 15, 51}`. Tip bubble `{255, 248, 230}`,
  tip text `{59, 42, 82}`.
- Rarity rims: Legendary `{255, 200, 40}`, Epic `{170, 80, 255}`, Very Rare `{40, 210, 200}`, Rare `{70, 140, 255}`.
- 9 pockets; pockets filled = `LoadingRules.pockets(share, done, 9)`: 0-8 while loading, 9 only when done.
- Fonts: built-in `Enum.Font.Bangers` (ribbon, place, count), `Enum.Font.GothamBold` (step, tip). No uploads.
- Safety caps unchanged: join `MAX_SECONDS = 30`, Wild `MAX_SECONDS = 12`, `WAIT_SECONDS = 30`.
- Plain data only in `Config/LoadingScreen` (rgb arrays, strings, numbers): Lune reads it.
- Text: plain ASCII. Mobile-first: landscape phone (844 x 390) nothing clipped.

## Review Focus

1. A teleport's arriving screen is swapped for this place's look with no frame of nothing in between (the new one is
   parented before the old one goes).
2. A character that respawns while the join screen holds it: the hold ends anyway when loading is done (no stuck root).
3. A Wild trip cancelled ("stay") after "loading": the screen closes, nothing stays anchored, the next trip starts at
   0 pockets.
4. A card image that never loads: its pocket still fills (the rim shows), loading isn't held by the screen's own art.
5. A done-by-timeout screen: all 9 pockets and "Ready!" show, then it fades (`pockets(share, true, 9) == 9`).

---

### Task 1: The name

**Files:**
- Modify: `src/shared/Config/Game.luau`, `src/shared/Config/Welcome.luau:23`, `src/shared/Config/Places.luau:2`,
  `CLAUDE.md:136`
- Test: `tests/LoadingRules.spec.luau`

- [ ] **Step 1: Failing test** in `tests/LoadingRules.spec.luau`:

```lua
["the game is called One More Pack"] = function()
	expect.equal(Game.NAME, "One More Pack")
	expect.equal(cfg.TITLE, "ONE MORE PACK")
end,
```
(`local Game = require("../src/shared/Config/Game")` at the top.)

- [ ] **Step 2:** `lune run tests/run` → FAIL on both.
- [ ] **Step 3:** `Game.NAME = "One More Pack"` (drop "placeholder" from its comment), `LoadingScreen.TITLE = "ONE MORE PACK"`,
  `Welcome.TITLE = "Welcome to One More Pack!"`, Places comment "the One More Pack experience", CLAUDE.md "Published
  (private) as "One More Pack"".
- [ ] **Step 4:** `lune run tests/run` → the new test passes (TalkRules still green: shorter name).

### Task 2: The look in config, the pockets rule, the Dungeon's cavern step

**Files:**
- Modify: `src/shared/Config/LoadingScreen.luau`, `src/shared/Util/LoadingRules.luau`, `src/shared/Config/WildLoading.luau`
- Create: `assets/ui/loading/dog_cards/cards/*.jpg` uploads (ids only), `assets/ui/loading/dungeon_abyss.jpg` upload
- Test: `tests/LoadingRules.spec.luau`, `tests/WildLoadingRules.spec.luau`

**Interfaces:**
- Produces: `LoadingRules.pockets(share: number, done: boolean, total: number): number`;
  `Status.cavern: boolean?` (nil counts as ready, like `valley`); `LoadingRules.look(cfg, kind)` for kinds
  `"Main" | "Frontier" | "Dungeon" | "Wild"`; config keys every look carries: `TITLE, PLACE, ACCENT, ACCENT_DROP,
  BACKGROUND {top, bottom}, BACKDROP, BACKDROP_RECT, BACKDROP_TRANSPARENCY, TIPS, STEPS, READY, FIRST_STEP`;
  shared keys: `POCKETS = 9, DOG_CARDS = { {image: string, rarity: string} x9 }, RIMS, RIBBON {top, bottom, drop},
  BOOK {case, page, pocket, pocketEdge, ring, stitch}, TIP_COLORS {back, text}, FLY_SECONDS = 0.45,
  FLY_STAGGER = 0.12, READY_HOLD = 0.4`.

- [ ] **Step 1: Upload the images.** Serve `assets/ui/loading` with `python -m http.server 8766 --bind 127.0.0.1`
  and upload the 9 cards (`dog_cards/cards/<Dog>_<pose>.jpg`) and `dungeon_abyss.jpg` with the Studio MCP
  `upload_image`; note each id.
- [ ] **Step 2: Failing tests** (replace the fan/swirl tests "the fan's cards all have a small painting" and "the join
  screen swirls the Wild's spiral..." and adjust "the Frontier's look..." to `look.PLACE == "THE FRONTIER"` and
  `look.ACCENT[1] ~= cfg.ACCENT[1]`; "the Dungeon too, for now" becomes the Dungeon's own look):

```lua
["the pockets fill with progress, the last only when done"] = function()
	expect.equal(LoadingRules.pockets(0, false, 9), 0)
	expect.equal(LoadingRules.pockets(0.8, false, 9), 6)
	expect.equal(LoadingRules.pockets(1, false, 9), 8, "never all 9 before done")
	expect.equal(LoadingRules.pockets(1.4, false, 9), 8)
	expect.equal(LoadingRules.pockets(-1, false, 9), 0)
	expect.equal(LoadingRules.pockets(0.2, true, 9), 9, "done (or out of time): all 9")
end,
["the binder holds nine dog cards, three each of Pish, Chikin and Turts, each with a rim"] = function()
	expect.equal(cfg.POCKETS, 9)
	expect.equal(#cfg.DOG_CARDS, 9)
	for _, card in cfg.DOG_CARDS do
		assert(string.match(card.image, "^rbxassetid://%d+$"), card.image)
		assert(cfg.RIMS[card.rarity], card.rarity)
	end
end,
["every place has its own picture, colour and name; the ribbon is the same everywhere"] = function()
	local seen = {}
	for _, kind in { "Main", "Wild", "Frontier", "Dungeon" } do
		local look = LoadingRules.look(cfg, kind)
		assert(string.match(look.BACKDROP, "^rbxassetid://%d+$"), kind)
		assert(not seen[look.BACKDROP], `{kind} shares a picture`)
		seen[look.BACKDROP] = true
		expect.equal(look.TITLE, "ONE MORE PACK")
		expect.equal(#look.ACCENT, 3)
		assert(#look.TIPS > 0, kind)
	end
	expect.equal(LoadingRules.look(cfg, "Main").PLACE, "")
	expect.equal(LoadingRules.look(cfg, "Dungeon").PLACE, "THE DUNGEON")
	expect.equal(LoadingRules.look(cfg, "Wild").PLACE, "THE WILD")
end,
["the Dungeon's loading waits for its cavern"] = function()
	local status = { character = true, data = true, art = true, shop = true, creature = true, gear = true, cavern = false }
	local step, _, done = LoadingRules.progress(status, 1, cfg)
	expect.equal(step, 3)
	expect.equal(done, false)
	status.cavern = true
	_, _, done = LoadingRules.progress(status, 1, cfg)
	expect.equal(done, true)
	expect.equal(LoadingRules.stepText(3, "Dungeon", LoadingRules.look(cfg, "Dungeon")), "Lighting the crystal cave...")
end,
```
  In `tests/WildLoadingRules.spec.luau` "one step per thing it waits for, and plain text": the tips now come from
  `LoadingScreen.LOOKS.Wild.TIPS`; drop `WildLoading.TITLE` from the checked lines.
- [ ] **Step 3:** `lune run tests/run` → the new tests FAIL.
- [ ] **Step 4: Config.** `Config/LoadingScreen`: drop `FAN_*`, `SWIRL*`, `CARD_EDGE`, `BAR_COLOR`, `NOTE_COLOR`; add the
  keys above with the Global Constraints values. Main: `BACKDROP = "rbxassetid://89947475330742"` (Config/PackOpening
  BACKDROP.IMAGE, rect `{0, 0, 1024, 572}`), gold accent, `PLACE = ""`. `LOOKS.Wild`: the First Spark cover
  (`rbxassetid://95161168581849`, rect `{0, 500, 680, 380}`), green, "THE WILD", `TIPS` moved from `WildLoading.TIPS`,
  `READY = "Here we go!"`. `LOOKS.Frontier`: keep its BACKDROP/RECT and TIPS, `TITLE` removed (falls back to the
  ribbon), icy accent, "THE FRONTIER". `LOOKS.Dungeon`: the uploaded abyss (rect `{0, 0, 1376, 768}`), violet,
  "THE DUNGEON", `STEPS[3] = "Lighting the crystal cave..."`, tips "Tip: solve each room's puzzle to open the next
  gate." and "Tip: stay together, the Hydra hits hard!". `DOG_CARDS` in the mockup's order with rarities Legendary,
  Epic, Very Rare, Rare, Epic, Legendary, Legendary, Very Rare, Epic. `Config/WildLoading`: drop `TITLE, TIPS, SWIRL,
  GLOW, BACKDROP, BACKDROP_RECT, SWIRL_SIZE, SWIRL_TURN, COLORS` (the binder replaces them); keep steps and timings.
- [ ] **Step 5: Rules.** `LoadingRules`: `Status.cavern: boolean?`; ORDER's third step `{ "shop", "valley", "cavern" }`;
  the optional check covers both `valley` and `cavern`; add `pockets`:

```lua
function LoadingRules.pockets(share: number, done: boolean, total: number): number
	if done then
		return total
	end
	return math.clamp(math.floor(share * (total - 1) + 1e-6), 0, total - 1)
end
```
- [ ] **Step 6:** `lune run tests/run` → all green.

### Task 3: The binder builder

**Files:**
- Modify (rewrite): `src/first/LoadingGui.luau`

**Interfaces:**
- Consumes: the look keys from Task 2.
- Produces: `LoadingGui.build(look: any, firstStep: string): ScreenGui`;
  `LoadingGui.animate(gui: ScreenGui, look: any): () -> ()` (cycles tips every `TIP_SECONDS`, returns stop);
  `LoadingGui.set(gui: ScreenGui, stepText: string, pockets: number, note: string)` (slides cards in up to `pockets`,
  `FLY_STAGGER` apart; "Ready!"-styled step when `pockets == POCKETS`); `LoadingGui.fadeOut(gui, seconds)` (as today).
  Instances by name (a teleported copy is driven the same way): `Back`, `Backdrop`, `Ribbon`, `Book`, `Page`,
  `Pocket1..9` each with `Card`, `Place`, `Count`, `Step`, `Note`, `Tip`.

- [ ] **Step 1:** Rewrite `build` to the mockup (`.superpowers/brainstorm/9845-1794546987/content/loading-places-bg3.html`):
  Back frame with the BACKGROUND gradient; Backdrop ImageLabel (Crop, rect, `BACKDROP_TRANSPARENCY`) and a dim frame
  darker in the middle; Book (about 70% of the width, UIAspectRatio so the page stays card-shaped, dark leather,
  UIStroke dashed look via a slightly inset Frame with a thin accent UIStroke, UICorner); Page with a UIGridLayout of
  9 pockets (card aspect 63:88); each Card an ImageLabel (Crop) with the rim colour as its background, starting
  offset up-right, rotated 18°, at `ImageTransparency = 0.99` (kept drawn so it loads); the rings (3 white pills);
  right column: Place (Bangers, accent, hidden when ""), Count (Bangers "0 / 9", accent with a dark drop via a second
  label behind), Step (GothamBold white), Note (accent), Tip (GothamBold in a cream rounded Frame); the Ribbon
  (Bangers white on a pink UIGradient Frame, clipped-notch look via two small triangle frames or a plain rounded
  banner) centred over the book's top edge. Text sizes scale with the screen (phone height < 500: smaller).
- [ ] **Step 2:** `set` tweens each newly filled pocket's card in (`FLY_SECONDS`, Back easing) and writes Count and
  Step; `animate` cycles `look.TIPS`.
- [ ] **Step 3:** Compile check: `lune run <scratchpad>/compile_check.luau src/first/LoadingGui.luau` → compiles;
  VS Code diagnostics clean.

### Task 4: Join, teleports, the Dungeon's cavern, held still

**Files:**
- Modify: `src/first/Show.client.luau`, `src/client/Controllers/LoadingController.luau`

**Interfaces:**
- Consumes: `LoadingGui.build/animate/set/fadeOut` (Task 3), `LoadingRules.pockets`, `Status.cavern` (Task 2).
- Produces: LocalPlayer attribute `LoadingPockets: number` (0-9) next to `LoadingText`, `LoadingShare`.

- [ ] **Step 1: Show.client.** Build a fresh screen for this place's look always; if a teleport's arriving gui exists,
  parent it first (as today) and destroy it only after the fresh one is parented. Preload the fresh gui's images in a
  spawned `ContentProvider:PreloadAsync({ gui })` (never waited on). Follow `LoadingPockets` (with text and note)
  into `LoadingGui.set`; after `LoadingDone`, hold `READY_HOLD`, then fade.
- [ ] **Step 2: LoadingController.** Write `LoadingPockets = LoadingRules.pockets(share, done, LoadingScreen.POCKETS)`.
  Add `preloadCavern()` for the Dungeon (wait up to MAX_SECONDS for `workspace.Dungeon`, stream round the root,
  raycast for ground within 60 studs, `ContentProvider:PreloadAsync({ workspace.Dungeon })`), its result as
  `status.cavern` (nil outside the Dungeon). Hold still: anchor your HumanoidRootPart on your device when your
  character appears while loading (and on each new character before done); un-anchor the roots it anchored when done.
  `setTeleportScreen` builds with `LoadingGui.build(screen, screen.FIRST_STEP.Main or screen.STEPS[1])`.
- [ ] **Step 3:** Compile checks for both files → compile; diagnostics clean.

### Task 5: The Wild screen is the binder, and a dev preview

**Files:**
- Modify: `src/client/Controllers/WildLoadingController.luau`, `src/server/Services/DevService.luau`,
  `src/shared/Config/AdminPanel.luau`

**Interfaces:**
- Consumes: `LoadingGui` (from `ReplicatedFirst.LoadingScreen`), `LoadingRules.look(LoadingScreen, kind)`,
  `LoadingRules.pockets`.
- Produces: dev command `/loading <main|wild|frontier|dungeon>`.

- [ ] **Step 1:** WildLoadingController: drop its own build/swirl/glow; `show()` builds `LoadingGui.build(look,
  WildLoading.STEPS[1])` with look `"Frontier"` in the Frontier place else `"Wild"`, renamed `WildLoading`,
  `DisplayOrder = 900`, parented to PlayerGui, `LoadingGui.animate`; `animate()` calls `LoadingGui.set(gui,
  WildLoading.STEPS[step] or look.READY, LoadingRules.pockets(share, finished, 9), "")`; `close()` uses
  `LoadingGui.fadeOut` after `READY_HOLD` when finished, at once on "stay"/"home"; `keepPictures` keeps the look's
  BACKDROP and the 9 cards drawn. Anchoring and trip logic unchanged.
- [ ] **Step 2:** DevService `/loading <kind>`: fires the client to show that place's binder and fill it over ~5 s
  (a demo run, nothing loaded, closes itself); AdminPanel button "Loading screens" with the four kinds.
- [ ] **Step 3:** Compile checks → compile; `lune run tests/run` green (AdminPanel test).

### Task 6: Docs, Studio check, report

**Files:**
- Modify: `DESIGN.md` (the loading screen section and 10.x where the old fan/swirl screens are described),
  `CLAUDE.md` (dev command `/loading`, `assets/ui/loading` note: dog cards, dungeon picture, tools), Obsidian vault
  (decisions log, lessons: "a teleport's screen restyled on arrival").

- [ ] **Step 1:** Docs as above.
- [ ] **Step 2:** `rojo sourcemap default.project.json -o sourcemap.json`; `lune run tests/run` → all green.
- [ ] **Step 3:** Studio (main place): Play → screenshot the join screen mid-fill and at "Ready!"; check the character
  can't move until done; `/loading wild|frontier|dungeon` screenshots; `/wild` real trip: screen, hold, fade; Output
  clean; Device emulator landscape phone for clipping.
- [ ] **Step 4:** Report to the owner with screenshots; commit only after the OK.
