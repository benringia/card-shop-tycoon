# Timed Station Upgrades and the Paid Revive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Condenser, Grading and Forge actions take time (up to 1 hour, crafting longest) with a Robux "Finish now", and a
Wild knockout gets a 20 s countdown with a Robux "Revive here", all through one idempotent purchase handler.

**Architecture:** Stations keep their checks and rolls; the result goes into a saved job (`UpgradeJobService`) that holds
the item (cards lifted out of the collection, weapons locked) until its time is up. `PurchaseService` owns
`ProcessReceipt`, records each PurchaseId in the save and hands products to registered grants (skips, revive).
`KnockoutService` replaces BattleService's instant knockout with a server countdown the client shows.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, ProfileStore (DataService), Lune tests (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-11-12-timed-upgrades-revive-design.md`

## Global Constraints

- Server authoritative: every start, skip and revive is checked on the server; remotes in `src/shared/Remotes.luau`
  (names list and return table), validated and rate-limited (`Util/RateLimiter`).
- Tunable numbers in `src/shared/Config`; pure logic in Roblox-free `src/shared/Util` modules with Lune tests.
- Saved tables hold plain data only. Schema change: `SCHEMA_VERSION` 21, a `MIGRATIONS[20]` step with a Lune test,
  DataService template and `PlayerData` type, DESIGN.md 10.4.
- Never lose an item or a purchase: an unreadable job gives its item back; a bought skip or revive always gives
  something.
- Never fail silently: refusals go through `Util/Blocked` (requirement card); a product whose ID is 0 shows "Coming
  soon" on its button.
- Text plain ASCII plus `·` and emoji. UI built with `UIKit`, cotton candy windows.
- Commit only after the owner's OK (CLAUDE.md); no per-task commits.

## Review Focus

- A job that finished while the player was away (or finishes during their join) is handed back on load, after
  CardService and WeaponService loaded (UpgradeJobService registers after them).
- A receipt arriving twice (a retry after a server stop) grants once: the PurchaseId is checked before granting.
- A skip bought after its job already finished becomes a token the next job of that tier or smaller uses at once.
- Leaving during the knockout countdown: nothing frozen or lost on rejoin (the countdown is runtime only; the save
  never holds a knockout).
- Equipping a weapon that is in the Forge (carousel, Armory, Q/Z) is refused with a card; if it was in hand it was
  swapped for the Steel Sword when the job started.

---

### Task 1: Upgrade numbers and rules

**Files:**
- Create: `src/shared/Config/Upgrades.luau`, `src/shared/Util/UpgradeRules.luau`, `tests/UpgradeRules.spec.luau`
- Modify: `tests/run.luau` (register the spec)

**Interfaces:**
- Produces: `Config/Upgrades` plain data:
  `WAITS = { star = { 30, 120, 360, 900, 1800 }, grade = { B = 60, A = 480, S = 1500 }, level = { 15, 30, 60, 120, 240, 420, 600, 900, 1320, 1800 }, reforge = 1200, craft = 3600 }`,
  `TIERS = { { name = "S", upTo = 300 }, { name = "M", upTo = 1200 }, { name = "L", upTo = 3600 } }`,
  `STATIONS = { condenser = "Condenser", grading = "Grading Station", forge = "Forge" }`.
- Produces: `UpgradeRules.seconds(cfg, kind: "star"|"grade"|"level"|"reforge"|"craft", step: number|string?): number`
  (star/level: the target stars or level, 1-based; grade: the target grade), `UpgradeRules.tier(cfg, left: number): string`,
  `UpgradeRules.clock(seconds: number): string` ("0:45", "12:30", "1:00:00"),
  `UpgradeRules.busyText(stationName: string, left: number): string`,
  `UpgradeRules.tokenFor(tokens: { [string]: number }, tier: string, cfg): string?` (the smallest owned token tier at or
  above `tier`),
  `UpgradeRules.due(job: Job, now: number): boolean`,
  `UpgradeRules.readJob(raw: any, cards: any, weapons: any): Job?` with
  `export type Job = { kind: string, startedAt: number, finishAt: number, beast: { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }?, plain: { cardId: string, foil: boolean, grade: string }?, weaponId: string?, grade: string?, level: number? }`.

- [ ] **Step 1: Write the failing tests** (`tests/UpgradeRules.spec.luau`)

```lua
["waits grow with the upgrade, crafting the longest (owner: up to 1 hour)"] = function()
	expect.equal(UpgradeRules.seconds(cfg, "star", 1), 30)
	expect.equal(UpgradeRules.seconds(cfg, "star", 5), 1800)
	expect.equal(UpgradeRules.seconds(cfg, "grade", "S"), 1500)
	expect.equal(UpgradeRules.seconds(cfg, "level", 10), 1800)
	expect.equal(UpgradeRules.seconds(cfg, "craft"), 3600)
	for kind, waits in cfg.WAITS do -- nothing longer than crafting, nothing over an hour
		local list = if typeof(waits) == "table" then waits else { waits }
		for _, s in list do expect.equal(s <= cfg.WAITS.craft and s <= 3600, true, kind) end
	end
end,
["a skip's tier by the time left"] = function()
	expect.equal(UpgradeRules.tier(cfg, 299), "S"); expect.equal(UpgradeRules.tier(cfg, 301), "M")
	expect.equal(UpgradeRules.tier(cfg, 1201), "L"); expect.equal(UpgradeRules.tier(cfg, 3600), "L")
end,
["clocks and the busy line"] = function()
	expect.equal(UpgradeRules.clock(45), "0:45"); expect.equal(UpgradeRules.clock(750), "12:30")
	expect.equal(UpgradeRules.clock(3600), "1:00:00")
	expect.equal(UpgradeRules.busyText("Forge", 750), "The Forge is busy (12:30 left)")
end,
["a token covers its tier or smaller, the smallest one first"] = function()
	expect.equal(UpgradeRules.tokenFor({ S = 0, M = 1, L = 1 }, "S", cfg), "M")
	expect.equal(UpgradeRules.tokenFor({ S = 0, M = 0, L = 0 }, "S", cfg), nil)
	expect.equal(UpgradeRules.tokenFor({ S = 2, M = 0, L = 0 }, "M", cfg), nil)
end,
["a saved job is read back, or nil when it can't be (its item is given back by the caller)"] = function()
	local cardId = next(Cards.ById) :: string
	local weaponId = Weapons.WEAPONS[1].id
	local beast = { id = "b1", cardId = cardId, foil = false, level = 1, xp = 0, stars = 1, grade = "C" }
	expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, beast = beast }, Cards, Weapons) ~= nil, true)
	expect.equal(UpgradeRules.readJob({ kind = "craft", startedAt = 100, finishAt = 3700, weaponId = weaponId, grade = "A" }, Cards, Weapons) ~= nil, true)
	expect.equal(UpgradeRules.readJob({ kind = "bake", startedAt = 100, finishAt = 130, beast = beast }, Cards, Weapons), nil, "unknown kind")
	expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130 }, Cards, Weapons), nil, "no item")
	expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 130, finishAt = 100, beast = beast }, Cards, Weapons), nil, "ends before it starts")
	expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, plain = { cardId = "nope", foil = false, grade = "B" } }, Cards, Weapons), nil, "unknown card")
end,
["a job is due once its time is up (also while you were away)"] = function()
	expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 199), false)
	expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 200), true)
	expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 90000), true, "finished hours ago, offline")
end,
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL requiring `UpgradeRules`.
- [ ] **Step 3: Implement** `Config/Upgrades` (values above, owner quotes in comments) and `Util/UpgradeRules`
  (pure, no requires of siblings; `readJob` checks types, a known card or weapon id, grades from `{C,B,A,S}`,
  `0 < finishAt - startedAt <= 3600 * 2`, exactly one of beast / plain / weaponId).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.

### Task 2: Saved data v21 and saving now

**Files:**
- Modify: `src/shared/Config/Data.luau` (SCHEMA_VERSION 21), `src/server/Util/Migrations.luau` (`[20]`),
  `src/server/Services/DataService.luau` (template, `PlayerData`, `DataService.SaveNow`), `tests/Migrations.spec.luau`,
  `DESIGN.md` 10.4

**Interfaces:**
- Produces: saved fields `upgrades: { condenser: Job?, grading: Job?, forge: Job? }` (default `{}`),
  `skipTokens: { S: number, M: number, L: number }` (default zeros), `purchases: { string }` (default `{}`).
- Produces: `DataService.SaveNow(player: Player): boolean` — `profile:Save()` then waits for the profile's
  `OnAfterSave` (10 s at most); true once saved.

- [ ] **Step 1: Failing test** `["v21: upgrades, skip tokens and purchases start empty; junk replaced"]` in
  `tests/Migrations.spec.luau`: a v20 save gains `upgrades = {}`, `skipTokens = { S = 0, M = 0, L = 0 }`,
  `purchases = {}`; a v20 save with `purchases = "x"` gets `{}`.
- [ ] **Step 2: Run** — Expected: FAIL (version 20).
- [ ] **Step 3: Implement** the migration step, template fields, type and `SaveNow`.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass. Update DESIGN.md 10.4 (v21 lines and history).

### Task 3: Purchases (one idempotent receipt handler)

**Files:**
- Create: `src/shared/Util/ReceiptRules.luau`, `tests/ReceiptRules.spec.luau`, `src/server/Services/PurchaseService.luau`
- Modify: `src/shared/Config/Monetization.luau` (`PRODUCTS`), `src/server/init.server.luau` (start it in the main
  place and Frontier branches, before DataService.Start; grants register later and are looked up per receipt; a
  product with no grant in this place answers `NotProcessedYet`, so it's retried where it can be granted),
  `tests/run.luau`

**Interfaces:**
- Produces: `Config/Monetization.PRODUCTS = { Revive = 0, SkipS = 0, SkipM = 0, SkipL = 0 }` and
  `PURCHASE_MEMORY = 100`.
- Produces: `ReceiptRules.seen(list: { string }, id: string): boolean`,
  `ReceiptRules.record(list: { string }, id: string, max: number): { string }` (appends, keeps the newest `max`).
- Produces: `PurchaseService.OnProduct(key: string, grant: (player: Player) -> boolean)` (key: a `PRODUCTS` name),
  `PurchaseService.ProductId(key: string): number` (0: not created).
- Behaviour: `MarketplaceService.ProcessReceipt`: player not here or purchases not loaded → `NotProcessedYet`; id seen →
  `PurchaseGranted`; unknown product → `NotProcessedYet` and a warn; grant `pcall`ed, must return true; then record the
  id, `DataService.SaveNow`; saved → `PurchaseGranted`, else `NotProcessedYet` (the retry finds the id recorded). Loads
  and saves `data.purchases` through `DataService.Register` (save does nothing if never loaded).

- [ ] **Step 1: Failing tests:** `["a receipt id is remembered"]` (record then seen true; another id false),
  `["only the newest ids are kept"]` (record 105 ids with max 100: length 100, the first 5 gone, the last kept).
- [ ] **Step 2: Run** — Expected: FAIL requiring `ReceiptRules`.
- [ ] **Step 3: Implement** `ReceiptRules`, `PRODUCTS`, `PurchaseService`.
- [ ] **Step 4: Run** `lune run tests/run` and `rojo build default.project.json -o <scratch>/test.rbxl` — Expected:
  pass, builds.

### Task 4: Jobs: holding items, finishing, skipping

**Files:**
- Create: `src/server/Services/UpgradeJobService.luau`
- Modify: `src/server/Services/CardService.luau` (`HoldBeast`), `src/server/Services/WeaponService.luau` (locks),
  `src/shared/Util/WeaponSwitch.luau` + `tests/WeaponSwitch.spec.luau` (`list` skips locked),
  `src/shared/Remotes.luau` (`UpgradeJobs`, `SkipUpgrade`), `src/server/init.server.luau` (start after CardService,
  WeaponService, ItemService; main place only: the stations are there, and jobs left while in the Frontier finish on
  the next main-place load)

**Interfaces:**
- Consumes: Task 1 `UpgradeRules`, `Config/Upgrades`; Task 2 saved fields; Task 3 `PurchaseService.OnProduct`.
- Produces: `CardService.HoldBeast(player, beastId): (Beast?, string?)` — removes a levelled card from the collection
  for a job; nil and `"partied" | "working" | "fighting" | "missing"` when it can't go in.
- Produces: `WeaponService.SetLocked(player, weaponId, locked: boolean)`, `WeaponService.IsLocked(player, weaponId): boolean`;
  equipping a locked weapon is refused with `Blocked.tell` ("Your <name> is in the Forge."); locking the one in hand
  equips the Steel Sword; the WeaponsChanged payload gains `locked: { [weaponId]: true }`.
- Produces: `WeaponSwitch.list(cfg, owned, unlocked, locked: { [string]: boolean }?)` — locked weapons left out.
- Produces: `UpgradeJobService.Start(player, station: "condenser"|"grading"|"forge", job: Job): boolean` (false: busy),
  `UpgradeJobService.Left(player, station): number?` (seconds left, nil: free),
  `UpgradeJobService.Finish(player, station)` (hands the item back: a held beast through `CardService.AddBeast`, a plain
  copy through `CardService.GiveCard`, a forge job through `WeaponService.SetLevel` / `WeaponService.Give(..., "reforge" | "forge")`
  and unlocks; toast "<name> is ready!"), `UpgradeJobService.Skip(player, tier: string): boolean` (the station the
  player last asked to skip (`SkipUpgrade` remote), else the running job with the least time left that the tier covers;
  none: `skipTokens[tier] += 1`), and a token is spent at once when a job starts whose tier it covers.
- Remotes: `UpgradeJobs` server → client `{ [station]: { kind, left, total, name, detail } }` (on load, start, finish,
  skip); `SkipUpgrade` client → server `(station: string)` (rate-limited; remembers the intent for 2 minutes).
- Behaviour: a 1-second loop finishes due jobs of loaded players; on load, after reading jobs (`UpgradeRules.readJob`;
  unreadable: give the item back and warn), due ones finish at once and the forge job's weapon is locked. Registers
  `PurchaseService.OnProduct("SkipS"|"SkipM"|"SkipL", ...)`.

- [ ] **Step 1: Failing test** in `tests/WeaponSwitch.spec.luau`:
  `["a weapon in the Forge is out of the switch till it's back"]` — `WeaponSwitch.list(Weapons, owned, true, { [someOwnedId] = true })`
  doesn't contain `someOwnedId`; without `locked` it does.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the `WeaponSwitch.list` parameter, `CardService.HoldBeast`, WeaponService locks, the
  remotes and `UpgradeJobService`.
- [ ] **Step 4: Run** `lune run tests/run`, compile-check the changed server files, `rojo build` — Expected: pass.

### Task 5: The stations start jobs

**Files:**
- Modify: `src/server/Services/CondenserService.luau`, `src/server/Services/GradingService.luau`,
  `src/server/Services/ForgeService.luau`

**Interfaces:**
- Consumes: Task 4 `UpgradeJobService.Start / Left`, `CardService.HoldBeast`, `CardService.TakeFresh`,
  `WeaponService.SetLocked`; Task 1 `UpgradeRules.seconds / busyText`.
- Behaviour: before anything is taken, a busy station refuses with `Blocked.tell(player, UpgradeRules.busyText(...))`,
  and a levelled main copy that is partied / working / fighting refuses with "Take <name> out of your party first." (or
  its job / fight). After today's `CardService.Condense` / `GradeUp` succeeds, the upgraded copy is held: a levelled one
  with `HoldBeast`, a plain one with `TakeFresh` (its new grade) into `plain`; the job's kind and step: condense
  `"star"`, its new stars; grade `"grade"`, its new grade. Forge: `give()` no longer grants; it builds the job (upgrade:
  `"level"`, `level = owned.level + 1`, grade kept; reforge: `"reforge"`, `grade` rolled now; forge: `"craft"`, `grade`
  rolled now) and locks the weapon (not for a craft). The "is now ..." notifications become "<name> is in the <station>
  (<clock>)". `ForgeResult` still fires so the window updates, with `waiting = seconds`.

- [ ] **Step 1: Studio check plan** (service code, no pure part left): in the main place, with `/givecard` duplicates,
  condense a card, grade a card, upgrade / reforge / forge a weapon; each goes in with its timer, a second action is
  refused with the busy card, a party card is refused, the weapon in hand becomes the Steel Sword.
- [ ] **Step 2: Implement** the three services.
- [ ] **Step 3: Run** `lune run tests/run`, compile checks, `rojo build`; Studio check per Step 1 — Expected: as listed.

### Task 6: The stations' job panels and timers (client)

**Files:**
- Create: `src/client/Util/JobPanel.luau`, `src/client/Controllers/StationTimerController.luau`
- Modify: `src/client/Controllers/CondenserController.luau`, `GradingController.luau`, `ForgeController.luau`,
  `src/client/Controllers/WeaponSwitchController.luau` (pass `locked` to `WeaponSwitch.list`), `src/client/init.client.luau`

**Interfaces:**
- Consumes: `UpgradeJobs`, `SkipUpgrade`, `PurchaseService.ProductId` values via `Config/Monetization.PRODUCTS`,
  `UpgradeRules.clock / tier`.
- Produces: `JobPanel.new(parent: GuiObject, station: string): { update: (job: any?) -> (), destroy: () -> () }` — the
  held item's name and detail, a countdown, "Finish now · R$ <price>" (price from `MarketplaceService:GetProductInfo`,
  cached; ID 0: "Coming soon", disabled); the button fires `SkipUpgrade(station)` then `PromptProductPurchase`.
- Behaviour: each station window shows its panel over its action area while a job runs (actions disabled); a
  BillboardGui countdown floats over the player's own station models (Condenser, Grading Station, Forge); mockup shown
  to the owner before polishing the look.

- [ ] **Step 1: Mockup** of the panel and the floating timer (visual companion), owner's pick.
- [ ] **Step 2: Implement** `JobPanel`, the three windows, the floating timers, the weapon switch lock.
- [ ] **Step 3: Verify** compile checks, `lune run tests/run`, Studio: each station's panel counts down, Finish now
  says "Coming soon" with IDs 0, the timer floats over the machine, the locked weapon is out of the carousel.

### Task 7: Knocked out: countdown and revive

**Files:**
- Create: `src/shared/Util/KnockoutRules.luau`, `tests/KnockoutRules.spec.luau`, `src/server/Services/KnockoutService.luau`,
  `src/client/Controllers/KnockoutController.luau`
- Modify: `src/server/Services/BattleService.luau` (`knockOut` calls `KnockoutService.KnockOut`),
  `src/server/Services/WildService.luau` (no chasing a knocked-out player), `src/shared/Config/Combat.luau`
  (`DANGER.knockout = { seconds = 20, promptWait = 60, grace = 5 }`), `src/shared/Remotes.luau` (`Knockout`,
  `KnockoutChoice`), `src/server/init.server.luau` and `src/client/init.client.luau` (main place and Frontier: both
  have dangerous places)

**Interfaces:**
- Produces: `KnockoutRules.left(startedAt: number, pausedFor: number, now: number, total: number): number` and
  `KnockoutRules.pausedFor(pausedAt: number?, pausedFor: number, now: number, maxPause: number): number` (a pause
  counts at most `maxPause`).
- Produces: `KnockoutService.KnockOut(player)`, `KnockoutService.IsOut(player): boolean`; grant
  `PurchaseService.OnProduct("Revive", ...)`: knocked out → stand up where they fell (`BattleService.ClearResting`,
  movement back, `grace` seconds no chase); not knocked out → `BattleService.ClearResting` and a toast; always true.
- Remotes: `Knockout` server → client `{ left: number }` or `nil` (over); `KnockoutChoice` client → server
  `"spring" | "revive"` ("revive" pauses the countdown while the prompt is open; `MarketplaceService.PromptProductPurchaseFinished`
  unpauses when not bought).
- Behaviour: the player's Humanoid walk and jump go to 0 (back after), the "Knocked out!" screen shows the countdown,
  "Revive here · R$ <price>" (Coming soon at ID 0) and "Wake at the spring"; at 0 or "spring" →
  `WildService.SendToSpring`. Leaving clears the state.

- [ ] **Step 1: Failing tests:** `["the countdown runs down, waits while the purchase prompt is open, a minute at most"]`
  — `KnockoutRules.left(0, 0, 5, 20) == 15`; `left(0, 10, 15, 20) == 15`; `pausedFor(10, 0, 100, 60) == 60`;
  `pausedFor(nil, 7, 100, 60) == 7`.
- [ ] **Step 2: Run** — Expected: FAIL requiring `KnockoutRules`.
- [ ] **Step 3: Implement** rules, service, controller, the BattleService / WildService changes.
- [ ] **Step 4: Verify** `lune run tests/run`, compile checks, Studio: get knocked out in Ember Ridge, the countdown
  shows, "Wake at the spring" goes home, waiting 20 s goes home, monsters ignore you meanwhile.

### Task 8: Documents and the full check

**Files:**
- Modify: `DESIGN.md` (a section for timed upgrades, Finish now, the knockout countdown and revive; 10.4 done in Task
  2), `CLAUDE.md` (test list: UpgradeRules, ReceiptRules, KnockoutRules; how to set the product IDs)

- [ ] **Step 1:** Write the docs, including "Developer products: Creator Hub → the experience → Monetization →
  Developer Products → Create; paste the IDs into Config/Monetization PRODUCTS".
- [ ] **Step 2:** `lune run tests/run`, `rojo build` for default, dungeon and frontier projects — Expected: all pass,
  all build.
