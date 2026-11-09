# Tutorial with Pish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A no-text first-visit tutorial led by Pish, the owner's dog, plus Town Pish (a shared, pettable town dog
giving Pish's Luck), lesson visits at unlocks and a stuck helper, all measured as an onboarding funnel.

**Architecture:** Pure rules (`Util/TutorialRules`, `LuckRules`, `LessonRules`, Lune-tested) and plain data
(`Config/Pish`) drive two services: `PishService` moves Town Pish's invisible marker on the server (everyone sees the
same dog) and grants luck; `TutorialService` keeps each player's saved `tutorial` table, advances the first visit
from game hooks, gives the gifts, sends the tutorial customer, queues lessons and logs the funnel. On the client,
`Util/PishVisual` draws Pish on any marker (`CreatureVisuals` + `ClipPlayer` with his 16 clips);
`TownPishController` follows the server marker, `TutorialController` owns a private marker and the cues.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Blender clips already built.

**Spec:** `docs/superpowers/specs/2026-11-09-tutorial-pish-design.md` (owner approved 2026-11-09).

## Global Constraints

- Kid friendly, **no text or a word at most**: cues are Pish, a paw trail, a bouncing paw, picture bubbles
  (`Config/UIIcons` names or emoji), a paw row, the gift box. UI text: plain ASCII plus `·` and emoji only.
- Server authoritative: every remote defined in `src/shared/Remotes.luau`, args type-checked, rate-limited
  (`Server/Util/RateLimiter`), distance-checked where a place is involved. Cash/XP only through EconomyService.
- Saved state through `DataService.Register({ load, save, unload })`; `save` does nothing if `load` never ran.
  Schema bump with a Lune-tested migration; saved tables plain data only.
- All tunable numbers in `Config/Pish` (no magic numbers in services or controllers).
- Mobile-first: tap targets 48 px or more, HUD through `Util/Hud`, landscape phone checked in the Device emulator.
- Tutorial Pish exists only on its player's client; that client hides Town Pish meanwhile; others never see it.
- Luck only from petting **Town Pish** (server checks the player is within `LUCK.petRange` studs of his marker);
  3 minutes (`LUCK.seconds = 180`), once per 15 minutes per player (`LUCK.cooldown = 900`), +25% (`LUCK.boost =
  0.25`) on Very Rare, Epic and Legendary in a pack's or Deck Box's hit (last) slot, the lowest rarity in the slot
  giving up the difference; applied server-side before pity.
- The gift (`pishGift` item) opens a First Spark pack whose hit slot is **Very Rare or better**.
- Existing saves: `firstVisit = "done"` (no first visit), `giftClaimed = false`; lessons only for levels reached from now
  on.
- Licensed sounds only (Roblox's PSE catalogue); every new sound measured into `Config/SoundLevels`.
- Every Pish clip passes `tools/blender/check_stretch.py` (already true for the 16; any new clip too).
- Town Pish lives only in the main place (`workspace:GetAttribute("PlaceKind") == "Main"`).

## Review Focus

1. A player leaves mid-tutorial and rejoins: they resume at their saved step; the first pack and the gift are never
   given twice (Task 2 `TutorialRules` tests "resume" and "gifts once"; Task 7 uses `giftGiven` flags).
2. A step done early (ordering before building, two racks, a second sale): it counts when its turn comes and never
   skips the steps between (Task 2 test "early events wait their turn").
3. Petting spam or a cheating client firing the pet remote from afar or every second: luck at most once per 15 min,
   none out of range (Task 2 `LuckRules.canGrant` test; Task 5 server range check).
4. The owner's own save and every existing player: never sent through the first visit, no lessons for levels they
   already passed (Task 3 migration test; Task 2 `LessonRules.due` test "only levels crossed now").
5. Two players in the tutorial at once on one server: each sees only their own Pish, Town Pish stays for others
   (Task 8 Studio check with Local Server, 2 players).

---

### Task 1: Pish in the game files

**Files:**
- Create: `assets/npcs/Pish.rbxm` (the owner saves it from Studio; see Step 2)
- Modify: `default.project.json` (map `assets/npcs` → `ReplicatedStorage.NpcModels`)
- Modify: `tests/CreatureAssets.spec.luau` (`FOLDERS` gains `"assets/npcs"`; a test that `Pish.rbxm` has the bones
  `Pelvis`, `Head_0`, `Jaw_0`, `Ear_Left_0`, `Ear_Right_0`, `Tail_0..2`, the 12 limb bones and no scripts)
- Modify: `src/shared/Config/Party.luau` (`CREATURE_STYLE.Pish`)

**Interfaces:**
- Produces: `ReplicatedStorage.NpcModels.Pish` (a Model, PrimaryPart = the mesh, pivot at his feet), and
  `Party.CREATURE_STYLE.Pish = { fidgets = { "look", "tilt", "sniff" }, tailSpeed = 0.9, tailAmount = 1, bounce = 0.6 }`
  (a dog's quick wag and bouncy trot; the clips carry the big idles).

- [ ] **Step 1:** In Studio (MCP), on the owner's imported Pish model: reset each MeshPart's `PivotOffset` rotation
  (keep position), set `PrimaryPart`, check its bones by name. Ask nothing: this is the documented import step.
- [ ] **Step 2:** Ask the owner to right-click it → Save to File → `assets/npcs/Pish.rbxm`.
- [ ] **Step 3:** Write the CreatureAssets test for the Pish file (bones, no scripts), run `lune run tests/run`,
  expect it to FAIL before the file exists and PASS after Step 2.
- [ ] **Step 4:** Add the mapping and `CREATURE_STYLE.Pish`; `rojo build -o <scratch>/test.rbxl` builds.
- [ ] **Step 5:** Commit: `Pish: the model in the game files (NpcModels) and his walk style`.

### Task 2: The rules and Pish's config

**Files:**
- Create: `src/shared/Config/Pish.luau`, `src/shared/Util/TutorialRules.luau`, `src/shared/Util/LuckRules.luau`,
  `src/shared/Util/LessonRules.luau`
- Test: `tests/TutorialRules.spec.luau`, `tests/LuckRules.spec.luau`, `tests/LessonRules.spec.luau` (registered in
  `tests/run.luau`; named in CLAUDE.md's test list)

**Interfaces:**
- Produces `Config/Pish` (plain data):
  - `STEPS = { "giftPack", "buildRack", "orderStock", "stockRack", "customer", "ringUp", "gift", "bye" }`
  - `STEP_ICONS = { giftPack = "BoosterPack", buildRack = "Build", orderStock = "Order", stockRack = "Box",
    customer = "Customer", ringUp = "Register", gift = "Gift", bye = "Paw" }`
  - `FIRST_ITEM = "sparkPack"`, `GIFT_ITEM = "pishGift"`, `RACK = "SmallPackRack"`, `ORDER_PRODUCT = "FirstSparkPack"`
  - `LUCK = { seconds = 180, cooldown = 900, boost = 0.25, fromRarity = "Very Rare", petRange = 12 }`
  - `SKIP_HOLD = 2` (seconds), `LESSON_SECONDS = 20`
  - `LESSONS = { { id = "sleeves", level = 3, icon = "Sleeves" }, { id = "sword", level = 4, icon = "Sword" },
    { id = "condenser", level = 5, icon = "Condenser" }, { id = "forge", level = 6, icon = "Forge" },
    { id = "expand", level = 7, icon = "DeckBox" }, { id = "boosterBox", level = 11, icon = "BoosterBox" },
    { id = "grading", level = 14, icon = "GradingSeal" }, { id = "jobs", level = 20, icon = "Jobs" } }`
  - `STUCK = { firstSeconds = 3600, quiet = 60, gap = 120 }`
  - `TOWN = { speed = 7, trotSpeed = 11, visitSeconds = { 6, 12 }, idleEvery = { 5, 10 }, napChance = 0.1,
    shopChance = 0.5, idleClips = { "sit", "sniff", "bark", "roll", "dig", "shake", "playBow", "headTilt",
    "yawnStretch", "tailChase", "happyHop", "scratch" } }`
  - `HEIGHT = 2.6` (studs; a small dog beside a 5-stud player), `SOUNDS = { bark, whimper, yawn, yip, dig }` (ids
    from Task 11; `""` until then)
- Produces `TutorialRules` (pure, no requires):
  - `export type Saved = { firstVisit: "todo" | "done" | "skipped", step: number, early: { [string]: boolean },
    firstGiven: boolean, giftClaimed: boolean, lessons: { [string]: boolean }, pishLuckAt: number }`
  - `read(raw: any, steps: { string }): Saved` (anything bad → its default; `step` clamped 1..#steps)
  - `current(saved: Saved, steps: { string }): string?` (nil unless `firstVisit == "todo"`)
  - `record(saved: Saved, steps: { string }, stepId: string): (Saved, { string })` → the new state and the step ids
    completed now, in order (the current one, then any `early` ones that follow it in a row)
  - `skip(saved: Saved): Saved`, `replay(saved: Saved): Saved` (`todo`, step 1, early cleared; `giftClaimed` kept),
    `finish(saved: Saved): Saved` (`done`)
- Produces `LuckRules` (pure): `boost(slot, rank, fromRarity, amount)`, `atLeast(slot, rank, minRarity)`,
  `canGrant(lastAt: number?, now: number, cooldown: number): boolean`, `left(untilTime: number?, now: number): number`
  (`slot` is `{ { rarity: string, weight: number } }`, `rank` is `Config/PackOdds` RANK)
- Produces `LessonRules` (pure): `due(lessons, fromLevel: number, toLevel: number, seen: { [string]: boolean }): { string }`
  and `nudge(cfg, facts: { played: number, quiet: number, sinceNudge: number, boxWaiting: boolean,
  shelvesStocked: boolean }): ("order" | "stock")?`

- [ ] **Step 1: Write the failing tests** (values from the spec):

```lua
["record: the current step completes and the next becomes current"]
  -- read({}, STEPS) is todo, step 1; record(s, STEPS, "giftPack") → step 2, completed { "giftPack" }
["early events wait their turn"]
  -- at step 2, record "orderStock" → step stays 2, early.orderStock; then record "buildRack" → step 4,
  -- completed { "buildRack", "orderStock" }; record "ringUp" at step 4 → stays 4 (early), nothing completed
["resume: a saved step survives read, bad values fall back"]
  -- read({ firstVisit = "todo", step = 5 }) → step 5; step = 99 → #STEPS; step = "x" → 1; firstVisit = 3 → "done"
["gifts once: firstGiven and giftClaimed survive replay"]
  -- replay({ giftClaimed = true, firstGiven = true, ... }) keeps both true, step 1, todo
["nothing advances unless todo"] -- current() nil and record() a no-op for "done" and "skipped"
["boost: +25% on Very Rare and up, Rare gives up the difference"]
  -- boost({Rare .7, VR .15, Epic .14, Leg .01}, RANK, "Very Rare", 0.25)
  -- → VR .1875, Epic .175, Leg .0125, Rare .625 (near, 1e-9); total 1
["boost: a slot with nothing below Very Rare stays as it was"] -- e.g. { Epic 1 }
["atLeast: Very Rare or better"] -- {Rare .7, VR .15, Epic .14, Leg .01} → {VR .15, Epic .14, Leg .01};
  -- a slot with none left → { { rarity = "Very Rare", weight = 1 } }
["canGrant: once per cooldown"] -- canGrant(nil, 1000, 900) true; canGrant(500, 1000, 900) false; canGrant(100, 1000, 900) true
["due: only levels crossed now, in level order, not seen"]
  -- due(LESSONS, 2, 6, {}) → { "sleeves", "sword", "condenser", "forge" }; due(LESSONS, 6, 7, { expand = true }) → {}
  -- due(LESSONS, 20, 20, {}) → {} (an old save loading at 20 gets none)
["nudge: stock a waiting box, else order, never too soon or after the first hour"]
  -- { played = 300, quiet = 70, sinceNudge = 200, boxWaiting = true } → "stock"
  -- shelvesStocked = false, boxWaiting = false → "order"; quiet = 30 → nil; sinceNudge = 60 → nil; played = 4000 → nil
```

- [ ] **Step 2:** `lune run tests/run` → FAIL (modules missing).
- [ ] **Step 3:** Write `Config/Pish` and the three modules to those signatures.
- [ ] **Step 4:** `lune run tests/run` → all PASS.
- [ ] **Step 5:** Commit: `Tutorial rules: steps, luck and lessons (pure, tested)`.

### Task 3: Saved tutorial data (schema v17)

**Files:**
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 17`), `src/server/Util/Migrations.luau` (`[16]`),
  `src/server/Services/DataService.luau` (type `tutorial: any` and template `tutorial = { firstVisit = "todo", step
  = 1, early = {}, firstGiven = false, giftClaimed = false, lessons = {}, pishLuckAt = 0 }`), DESIGN.md 10.4
- Test: `tests/Migrations.spec.luau`

- [ ] **Step 1: Failing test** `["v17: existing players skip the first visit; no gift yet"]`: `{ version = 16 }` →
  `tutorial.firstVisit == "done"`, `step == 1`, `giftClaimed == false`, `firstGiven == true`, `lessons` empty table,
  `pishLuckAt == 0`, `version == 17`; a save with `tutorial = "junk"` gets the same.
- [ ] **Step 2:** `lune run tests/run` → FAIL. **Step 3:** add the migration, bump, template. **Step 4:** PASS.
- [ ] **Step 5:** Commit: `Save: the tutorial table (v17), old saves skip the first visit`.

### Task 4: Pack luck, the gift's floor, and the game hooks

**Files:**
- Modify: `src/server/Services/PackService.luau` (`rollPack(pack, player?, floor?)`: the hit slot through
  `LuckRules.atLeast` when `floor`, then `LuckRules.boost` while `PackService.SetLuck` has the player lucky; pity
  after, unchanged; `PackService.OnOpened(callback(player, productId, itemId?))` fired in `deliverPack`)
- Modify: `src/shared/Config/Items.luau` (`pishGift = { name = "Pish's Gift", icon = "Gift", open = "FirstSparkPack",
  floor = "Very Rare", ... }`), `src/shared/Util/ItemRules.luau` (`openablePack` returns `(productId, floor?)`),
  `src/server/Services/LevelUpService.luau` (passes the floor and the item id to `PackService.OpenItemPack(player,
  productId, floor, itemId)`)
- Modify: `src/server/Services/StockService.luau` (`OnOrdered(callback(player, productId))`, `OnStocked(callback(
  player, productId))`, `HasWaitingBox(player): boolean`, `ShelvesStocked(player): boolean`),
  `src/server/Services/PlacementService.luau` (`OnPlaced(callback(player, shelfId))`)
- Test: `tests/ItemRules.spec.luau` (or the spec that covers `ItemRules` today)

**Interfaces:**
- Produces: `PackService.SetLuck(player: Player, untilTime: number?)`, `PackService.OnOpened`,
  `StockService.OnOrdered/OnStocked/HasWaitingBox/ShelvesStocked`, `PlacementService.OnPlaced`.

- [ ] **Step 1: Failing test** `["openablePack: the gift opens a First Spark pack with a Very Rare floor"]`:
  `openablePack(Items, "pishGift")` → `"FirstSparkPack", "Very Rare"`; `"sparkPack"` → `"FirstSparkPack", nil`.
- [ ] **Step 2:** FAIL. **Step 3:** implement the item, `ItemRules`, then the PackService/LevelUpService/Stock/
  Placement changes (hooks fire only on success). **Step 4:** `lune run tests/run` PASS; compile-check the touched
  server files with `luau.compile`.
- [ ] **Step 5:** Studio: `/item pishGift 1`, open it from the Bag 5 times: every hit card is Very Rare or better.
- [ ] **Step 6:** Commit: `Packs: Pish's luck and the gift's Very Rare floor; order, stock, place and open hooks`.

### Task 5: Town Pish on the server, and petting for luck

**Files:**
- Create: `src/server/Services/PishService.luau`
- Modify: `src/shared/Remotes.luau` (`"PishPetted"` server → clients: `(userId: number, lucky: boolean)` hearts and
  the cuddle on every client; `"PetPish"` client → server: `()` petting the player's own Tutorial Pish (a cuddle, no
  luck)), `src/server/init.server.luau` (start order: after PlotService, TownWalkerService, PackService)

**Interfaces:**
- Consumes: `Config/Pish` TOWN/LUCK, `WalkerRules.townStops`, `PlotService` open plots and doors, `LuckRules.canGrant`,
  `PackService.SetLuck`, `TutorialService.GetLuckAt/SetLuckAt` (Task 7; until then a local table).
- Produces: `workspace.Pish.TownPish` (anchored invisible marker Part, `CanCollide = false`) with attributes
  `Clip: string`, `ClipId: number` (bumped per clip so the same clip twice replays), `Moving: boolean`,
  `Petting: number` (the userId being cuddled, 0 none); a server ProximityPrompt on it (ActionText "Pet",
  ObjectText "", hold 0, `MaxActivationDistance = LUCK.petRange`); player attribute `PishLuckUntil` (os.time).

- [ ] **Step 1:** Write the service: a loop that picks a target (a random town stop, or with `shopChance` an open
  shop's door), moves the marker toward it at `TOWN.speed` each Heartbeat (turning to face the way), then picks a
  random idle clip (never the last one) or waits `visitSeconds` at a door. Petting: on the prompt, stop, face the
  player, set `Clip = "petted"`; if `LuckRules.canGrant(luckAt, os.time(), LUCK.cooldown)` and the player is within
  `petRange` (server positions), set luck until `now + LUCK.seconds`, `PackService.SetLuck`, save `pishLuckAt`;
  fire `PishPetted` either way, and `AnalyticsService:LogCustomEvent(player, "PishPetted", lucky and 1 or 0)`.
  `PetPish` (tutorial cuddle) is rate-limited to one per 2 s and grants nothing. Main place only.
- [ ] **Step 2:** Compile-check; Studio Play: the marker walks the street and visits shops (log its targets), prompt
  works, luck attribute set once, a second pet inside 15 min gives none.
- [ ] **Step 3:** Commit: `Town Pish: wanders the town and visits shops; petting him gives luck`.

### Task 6: Drawing Pish on the client, and Town Pish

**Files:**
- Modify: `src/client/Util/ClipPlayer.luau` (`ClipPlayer.loadSet(key: string, model: Model): ({ [string]: Clip },
  Player?)`, moved from `MonsterController.loadClips`, which now calls it)
- Create: `src/client/Util/PishVisual.luau`, `src/client/Controllers/TownPishController.luau`

**Interfaces:**
- Produces `PishVisual`: `new(marker: BasePart): Visual` (clones `NpcModels.Pish`, `CreatureVisuals.build(model,
  marker, Pish.HEIGHT, false, "Pish")`, loads the 16 clips), `play(visual, clip: string, onDone: (() -> ())?)` (sounds
  on `Bark*`, `Yawn`, `DigStart` markers from `Pish.SOUNDS`; dirt puffs between `DigStart` and `DigEnd`),
  `hearts(visual)`, `step(visual, dt)` (CreatureVisuals.step then ClipPlayer.step), `setShown(visual, shown)`,
  `destroy(visual)`.
- Produces `TownPishController.SetHidden(hidden: boolean)` (Task 8 hides Town Pish during this player's tutorial).

- [ ] **Step 1:** Move `loadClips` into `ClipPlayer.loadSet`; MonsterController unchanged in behaviour (Studio: a
  Wild monster still plays its attack clips).
- [ ] **Step 2:** Write `PishVisual` and `TownPishController` (follows `workspace.Pish.TownPish`, plays `Clip` on each
  new `ClipId`, `PishPetted` → hearts and the yip; main place only).
- [ ] **Step 3:** Compile-check; Studio Play: Town Pish visible, walks with his trot, plays random clips, nothing
  stretches, petting shows hearts and the luck attribute.
- [ ] **Step 4:** Commit: `Town Pish on screen: his model, clips, sounds and hearts`.

### Task 7: The first visit on the server

**Files:**
- Create: `src/server/Services/TutorialService.luau`
- Modify: `src/shared/Remotes.luau` (`"TutorialAction"` client → server: `(action: "skip" | "replay" | "bye" |
  "lessonDone", lessonId: string?)`; `"TutorialState"` server → client: `{ firstVisit, step, giftClaimed, lesson:
  string? }`), `src/server/init.server.luau`

**Interfaces:**
- Consumes: `TutorialRules`, `Config/Pish`, hooks from Task 4, `RegisterService.OnSaleCompleted`,
  `CustomerService.OnReachedCounter`, `CustomerService.SpawnForTest(owner, "plain")`, `ItemService.GiveItem`,
  `WelcomeService` attribute `SeenWelcome`, `AnalyticsService`.
- Produces: `TutorialService.GetLuckAt(player): number`, `SetLuckAt(player, t)` (for PishService),
  `TutorialService.Lesson(player, lessonId)` (Task 9), player attributes `TutorialStep: string` ("" when none) and
  `TutorialDone: boolean`.

- [ ] **Step 1:** Write the service. Load: `TutorialRules.read`; a "todo" first visit starts once `SeenWelcome` is
  true. Hooks map to steps: Bag pack opened (`PackService.OnOpened` with itemId `sparkPack`) → `giftPack`;
  `PlacementService.OnPlaced(RACK)` → `buildRack`; `OnOrdered(ORDER_PRODUCT)` → `orderStock`; `OnStocked` →
  `stockRack`; tutorial customer at the counter → `customer`; `OnSaleCompleted` (owner) → `ringUp`; gift opened
  (itemId `pishGift`) → `gift`; `TutorialAction "bye"` → `bye` then `finish`. Entering `giftPack` gives `FIRST_ITEM`
  once (`firstGiven`); entering `customer` sends one plain customer (`SpawnForTest`); entering `gift` gives
  `GIFT_ITEM` once (`giftClaimed`). Each completed step logs `AnalyticsService:LogOnboardingFunnelStepEvent(player,
  index, id)`; skip logs `LogCustomEvent(player, "TutorialSkipped", step)`, the gift `LogCustomEvent(player,
  "PishGiftClaimed")`. `TutorialAction` rate-limited, args type-checked; "replay" only when not "todo". PishService
  switches from its local luck table to `GetLuckAt/SetLuckAt` (saved as `pishLuckAt`).
- [ ] **Step 2:** Compile-check; Studio with a reset save (Task 12's `/tutorial reset`, or by hand with
  `DevCommand`): walk the 8 steps with `/serve` for the sale and confirm each step's attribute and the two gifts.
- [ ] **Step 3:** Commit: `Tutorial: the first visit's steps, gifts, customer and funnel on the server`.

### Task 8: The first visit on the client (Pish, cues, skip)

**Files:**
- Create: `src/client/Controllers/TutorialController.luau`, `src/client/Util/TutorialCues.luau`
- Modify: `src/client/Util/Hud.luau` (`Hud.find(id: string): GuiObject?` for tiles and Manage tray buttons;
  `Hud.openTray(open: boolean)`)

**Interfaces:**
- Consumes: `PishVisual`, `TownPishController.SetHidden`, attributes `TutorialStep`, `TutorialDone`, `Config/Pish`.
- Produces `TutorialCues`: `trail(from: Vector3, to: Vector3): () -> ()` (glowing paw prints on the ground, returns a
  remover), `pawOn(target: GuiObject | BasePart): () -> ()` (bouncing paw), `bubble(visual, icon: string)`,
  `pawRow(done: number, total: number)`, `giftBox(shown: boolean, crossed: boolean)`, `sparkle(at: Vector3)`.

- [ ] **Step 1:** Write the controller: while `TutorialStep ~= ""`, own a local marker beside the player, draw Pish
  with `PishVisual`, hide Town Pish; per step run Pish to the place (the player's plot parts: `DeliverySpot`,
  `Register`, the `OrderComputer` fixture; HUD: `Bag`, Manage → `Build`), `point` clip and bark, the trail, the
  bouncing paw, the bubble icon from `STEP_ICONS`, the paw row, the gift box; on a step change a sparkle and
  `happyHop`; at `bye` the `celebrate` clip, run off, `TutorialAction "bye"`. If the player walks over 40 studs away,
  Pish runs after them and points back. The skip button (48 px, top corner) needs `SKIP_HOLD` seconds held (a ring
  fills); then a card with the gift crossed, Pish's droop and whimper, a big green paw (keep going) and a small grey
  skip (`TutorialAction "skip"`). A `Hud.fanButton({ id = "Pish", icon = "Paw", label = "Pish", order = 6 })` shows
  when the first visit isn't "todo" and replays it (`TutorialAction "replay"`). Petting Tutorial Pish (a client
  ProximityPrompt) plays `petted` and fires `PetPish`.
- [ ] **Step 2:** Compile-check; Studio Play with a reset save: the whole first visit with screenshots of each
  step's cues; phone landscape in the Device emulator; Local Server with 2 players: the one in the tutorial sees only
  their Pish, the other sees Town Pish.
- [ ] **Step 3:** Commit: `Tutorial: Pish leads the first visit; cues, gift box, hold-to-skip, replay`.

### Task 9: Lesson visits and the stuck helper

**Files:**
- Modify: `src/server/Services/TutorialService.luau` (lessons: `EconomyService.OnLevelUp(player, from, to)` →
  `LessonRules.due`, queued while fighting, opening or outside the main place; sent as `TutorialState.lesson`;
  `lessonDone` saves it; `LogCustomEvent(player, "LessonShown", 0, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name]
  = lessonId })` and `"LessonUsed"` the same way; stuck: every 10 s per player in the first `STUCK.firstSeconds` of play, `LessonRules.nudge`
  with `StockService.HasWaitingBox/ShelvesStocked` and the time since the last order/stock/sale/pack)
- Modify: `src/client/Controllers/TutorialController.luau` (a lesson or nudge: Tutorial Pish runs in, points at the
  lesson's HUD tile or place with its icon bubble, leaves after `LESSON_SECONDS` or when used; the sword lesson waits
  for the first-sword popup to close and points at the Wild portal)

- [ ] **Step 1:** Server queue and stuck checks; client visit. **Step 2:** Studio: `/level 4` on a level-3 save shows
  the sword lesson after the popup; `/level 7` shows Deck Boxes once; a quiet minute with a waiting box brings Pish to
  point at the shelf. **Step 3:** Commit: `Tutorial: Pish's lesson visits at unlocks and the stuck helper`.

### Task 10: Pish's Luck badge

**Files:**
- Modify: `src/client/Controllers/BuffController.luau` (a second badge in the status column: clover `🍀` and a
  `m:ss` countdown from `PishLuckUntil`; tooltip "Pish's Luck · better pulls"; hidden at 0)

- [ ] **Step 1:** Implement; **Step 2:** Studio: pet Town Pish, the badge counts down 3:00 to 0:00 and hides; phone
  layout keeps the creature badge and the cash readable. **Step 3:** Commit: `Buffs: Pish's Luck badge with its timer`.

### Task 11: Pish's sounds

**Files:**
- Modify: `src/shared/Config/Pish.luau` (`SOUNDS` ids), `src/shared/Config/SoundLevels.luau`

- [ ] **Step 1:** Search the PSE catalogue (toolbox API, `creatorTargetId=7462895450`, docs: memory "licensed sound
  search") for a small dog's bark, a whimper, a yawn, a happy yip and dirt scuffs; pick short, cute ones.
- [ ] **Step 2:** Measure each in Studio (`tools/audio/measure_loudness.luau`), add to `Config/SoundLevels`;
  `lune run tests/run` (SoundLevel test) PASS.
- [ ] **Step 3:** Studio: bark clip barks three times in time; commit: `Pish: licensed bark, whimper, yawn, yip, dig`.

### Task 12: Dev commands and the admin panel

**Files:**
- Modify: `src/server/Services/DevService.luau` (`/tutorial reset` (todo, step 1, gifts not given),
  `/tutorial step <1-8>`, `/lesson <id>`, `/pish` (Town Pish to you), `/pishluck` (clear the cooldown)),
  `src/shared/Config/AdminPanel.luau` (buttons for each), CLAUDE.md's dev command list

- [ ] **Step 1:** Implement; **Step 2:** Studio: each command works from the admin panel. **Step 3:** Commit:
  `Dev: tutorial, lesson and Pish commands`.

### Task 13: Docs, vault and the owner's check

**Files:**
- Modify: `DESIGN.md` (a Tutorial and Pish section; file tree; 10.4 save shape), `CLAUDE.md` (assets/npcs, the
  test names, Pish tools), `docs/animations.md` (already has Pish's clips), the Obsidian vault (decisions log, lessons
  learned), memory

- [ ] **Step 1:** Write the docs. **Step 2:** `lune run tests/run` → all PASS; `rojo build` builds.
- [ ] **Step 3:** Final review (fresh reviewer, most capable model) of the whole branch; fix Critical/Important with a
  failing test first.
- [ ] **Step 4:** Tell the owner exactly what to judge in Studio (first visit start to end on a reset save, skip and
  replay, Town Pish wandering and petting, a lesson, the luck badge, phone layout, two players).

---

## Amendment 2026-11-10 (spec section 14): Pish talks, labels, his walk

### Task 14: Pish's talk card and in-window pointing

**Files:**
- Create: `src/shared/Config/Game.luau` (`NAME`), `src/shared/Config/PishTalk.luau` (per step `intro` lines and `now`
  lines by situation; one line per lesson and nudge), `src/shared/Util/TalkRules.luau` (pure), `tests/TalkRules.spec.luau`,
  `src/client/Util/TutorialTalk.luau` (the card: Pish's face viewport, name, line, Next)
- Modify: `src/client/Controllers/TutorialController.luau` (situations per step, targets inside windows, bye after the
  last line), `src/client/Controllers/BinderController.luau` (name the Bag's Open button "Open"; `ItemId` attribute on
  the detail panel)

**Interfaces:**
- Produces: `TalkRules.show(talk, step, introIndex, situation): { text: string, next: boolean, last: boolean }`;
  `TalkRules.fill(text, gameName)`; `PishTalk.STEPS[step] = { intro = { string }, now = { [situation]: string } }`,
  `PishTalk.LESSONS[id]`, `PishTalk.NUDGES[kind]`.

- [ ] Step 1: tests (every step has intro and a `default` now line; lines are plain ASCII plus emoji and the middle
  dot, at most 60 characters; `show` walks the intro then the situation's line, unknown situations fall back to
  `default`; the game name is filled in). RED, implement, GREEN.
- [ ] Step 2: the card and the controller; Studio: steps 1-8 with screenshots, phone landscape. Commit:
  `Tutorial: Pish talks you through it, and points inside windows`.

### Task 15: The labelled top bar and the skip card's words

**Files:** Modify `src/client/Util/TutorialCues.luau` (`topBar(done, total)` replaces `pawRow` and `giftBox`),
`src/client/Controllers/TutorialController.luau` (skip lives in the bar; the skip card's text).

- [ ] Step 1: build; Studio PC and phone (Galaxy A06): nothing over the HUD, labels readable. Commit:
  `Tutorial: a labelled top bar and a skip card with words`.

### Task 16: Pish's walk tempo

**Files:** Modify `src/shared/Config/Pish.luau` (`TOWN.speed` 4.5, `trotSpeed` 8), `src/shared/Config/Party.luau`
(`CREATURE_STYLE.Pish` `stride`, `bounce`); Test: `tests/TutorialRules.spec.luau` or a new `tests/PishWalk.spec.luau`
(leg cycles a second walking 1.5-2.2, trotting at most 3.5, from PET_ANIM.STRIDE, CREATURE_HEIGHT, Pish.HEIGHT).

- [ ] Step 1: RED test, then the numbers, GREEN. Studio: he strolls, trots after you. Commit:
  `Pish: a small dog's walk (slower, longer steps, less bob)`.
