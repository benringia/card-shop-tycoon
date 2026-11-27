# Live Admin Panel, Footage Presets and the Creator Title Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The admin panel works in the published game for the owner on their test save, with one-tap Footage setups, and the owner gets a Creator title with an orbiting-cards aura.

**Architecture:** A pure `DevRules` decides from facts (Studio, owner, test save, players, private server) and a command's scope whether a dev command runs; `DevAccess` (server Util) builds those facts and is the one gate DevService's panel remote and every service's dev function call. Titles gain an "owner" check and hidden titles; the aura is drawn by every client for a player with a server-set `CreatorAura` attribute.

**Tech Stack:** Luau (Roblox, Rojo), Lune tests (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-11-27-live-admin-creator-design.md`

## Global Constraints
- Server authoritative: the client's word decides nothing; every live command is checked on the server (`SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name)` and the server-set `TestSave` attribute).
- Live: no chat commands, no `ServerStorage.DevCommand`; only `Remotes.DevPanel`, rate-limited (`AdminPanel.COMMAND_COOLDOWN`) and length-checked (`AdminPanel.COMMAND_MAX_LENGTH`).
- Scopes: "server" = event, time, crowd, room, winroom, puzzle, tap, dungeonfx, pish, townchikin, turts, elite, ko, bosshp (and footage golden); "studio" = jobslot; everything else "own".
- Refusals (never fail silently) through server `Util/Blocked.tell`; a non-owner's request gets no reply.
- No saved-data change (no schema bump). Player text plain ASCII plus emoji and `·`.
- Edit `src` with Edit/Write only (no sed: Rojo crash). Keep `addCommand(folder, "<alias>"` call shapes (tests/AdminPanel greps them).
- Analytics: nothing from the owner's test save.

## Review Focus
1. The owner on their real save presses a button: refused with the /slot test card, nothing changes (Task 2 test: `check` mainSave).
2. A second player in a public server while the owner presses Golden hour or an event: refused with "alone or private server" (Task 1 tests: notAlone; Task 4 footage golden goes through the same check).
3. A non-owner fires `Remotes.DevPanel` from an exploit: dropped, no reply, no side effect (Task 1 notOwner; Task 2 DevGate: handler checks first).
4. The test save's attribute missing (load not finished) when a command arrives: refused (fail closed) (Task 1: testSlot false → mainSave).
5. Another player's Titles tab: Creator never listed, never counted (Task 5 test: `listed`).

---

### Task 1: DevRules and the scope table

**Files:**
- Create: `src/server/Util/DevRules.luau`
- Modify: `src/shared/Config/AdminPanel.luau` (add `SCOPE`, `REFUSE`)
- Test: `tests/DevRules.spec.luau` (register in `tests/run.luau`)

**Interfaces:**
- Produces: `export type Facts = { studio: boolean, owner: boolean, testSlot: boolean, players: number, privateOwner: boolean }`; `export type Scope = "own" | "server" | "studio"`; `export type Reason = "notOwner" | "mainSave" | "notAlone" | "studioOnly"`; `DevRules.scope(cfg: any, alias: string): Scope`; `DevRules.check(facts: Facts, scope: Scope): (boolean, Reason?)`.
- `AdminPanel.SCOPE: { [string]: "server" | "studio" }`; `AdminPanel.REFUSE = { mainSave = "Admin works on your test save. Type /slot test, then rejoin.", notAlone = "Only when you're alone or in your own private server.", studioOnly = "That one works in Studio only." }`.

- [ ] **Step 1: Write the failing tests** (`tests/DevRules.spec.luau`)

```lua
local live = { studio = false, owner = true, testSlot = true, players = 3, privateOwner = false }
-- each with(live, overrides) builds a copy
["studio: anyone, any scope"] = check({studio=true, owner=false, testSlot=false, players=5, privateOwner=false}, s) == true for s in own, server, studio
["live: not the owner is refused, reason notOwner"] = check(with{owner=false}, "own") == false, "notOwner" (also with testSlot true)
["live: the owner's real save is refused, reason mainSave"] = check(with{testSlot=false}, "own") == false, "mainSave"
["live: the owner's test save runs own commands"] = check(live, "own") == true
["live: server scope needs alone or own private server"] = check(live, "server") == false, "notAlone"; with{players=1} -> true; with{privateOwner=true} -> true
["live: studio scope is refused, reason studioOnly"] = check(live, "studio") == false, "studioOnly"
["scope: own by default, the table for the rest"] = scope(AdminPanel, "cash") == "own"; scope(AdminPanel, "time") == "server"; scope(AdminPanel, "jobslot") == "studio"
["scope: SCOPE names only commands DevService registers"] = every key of AdminPanel.SCOPE is an alias in DevService's source (same grep as tests/AdminPanel: 'addCommand%(folder, "(%w+)"')
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (DevRules missing).
- [ ] **Step 3: Implement `DevRules`** (pure, no requires), in this order: Studio passes everything; then not the owner → notOwner; then not the test save → mainSave; then the scope ("studio" → studioOnly; "server" needs `players == 1 or privateOwner`, else notAlone). Add `SCOPE` (the server list and `jobslot = "studio"`, `footage` not listed) and `REFUSE` to `Config/AdminPanel`.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Commit** `git add src/server/Util/DevRules.luau src/shared/Config/AdminPanel.luau tests/DevRules.spec.luau tests/run.luau` — "Live admin: DevRules decides who may run a dev command, and where"

### Task 2: The gate in the server (DevAccess, DevService, the services' dev functions) and DevGate

**Files:**
- Create: `src/server/Util/DevAccess.luau`
- Modify: `src/server/Services/DevService.luau`; the dev functions in `BattleService` (SetBossHpShare), `BossService` (DevSetBeaten), `DecorService` (SetLookForDev), `EventService` (Dev), `MainQuestService` (Dev), `PlacementService` (DevPlace), `RoomService` (DevSet), `WindowService` (DevPlace), `WildService` (SetPhantomPlayers), `DungeonPuzzleService` (Solve, Tap), `DungeonService` (WinRoom, SolvePuzzle, TapGate, SkipToPuzzle, SkipTo)
- Test: rewrite `tests/DevGate.spec.luau`

**Interfaces:**
- Consumes: Task 1's `DevRules.check`, `DevRules.scope`, `AdminPanel.REFUSE`.
- Produces: `DevAccess.facts(player: Player): DevRules.Facts`; `DevAccess.can(player: Player, scope: DevRules.Scope?): boolean` (scope default "own"); `DevAccess.check(player: Player, alias: string): (boolean, DevRules.Reason?)`; `DevAccess.refuse(player: Player, reason: DevRules.Reason?)` (Blocked.tell with REFUSE words, title "Admin", nothing for notOwner or nil). Player attribute `AdminAccess`: "open" | "mainSave" (owner only, set live on load).
- Signature changes: `WildService.SetPhantomPlayers(player: Player, count: number)`, `DungeonPuzzleService.Solve(player: Player, kind: string)`, `DungeonService.WinRoom(player: Player)`; callers in DevService pass the player.

- [ ] **Step 1: Rewrite `tests/DevGate.spec.luau`** (it reads source; keep its `opening` helper):
  - "chat commands only in Studio": DevService source contains `local folder: Instance? = if RunService:IsStudio() then`, and `opening(source, "addCommand")` contains `if not folder then return end`.
  - "DevCommand only in Studio": `opening(source, "makeStudioRunner")` == `if not RunService:IsStudio() then return end`.
  - "the panel remote checks DevAccess before anything runs": `opening(source, "onPanel")` (first 3 statements) contains `DevAccess.check(`; the source connects `Remotes.DevPanel.OnServerEvent:Connect(onPanel)`.
  - keep "dev commands are registered nowhere else".
  - "every service dev function checks DevAccess": for each (file, function) pair above, `opening` contains `DevAccess.can(` and not `RunService:IsStudio()`.
  - "DevAccess fails closed": DevAccess source uses `SaveSlots.isOwner(` and `GetAttribute("TestSave") == true`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: DevGate FAIL.
- [ ] **Step 3: Implement.** DevAccess facts: `studio = RunService:IsStudio()`, `owner = SaveSlots.isOwner(...)`, `testSlot = player:GetAttribute("TestSave") == true`, `players = #Players:GetPlayers()`, `privateOwner = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == player.UserId`. DevService: `addCommand` stores the handler and returns when `folder` is nil; `makeStudioRunner()` holds the DevCommand bindable; `onPanel` = rate limit and type check, alias, `DevAccess.check`, refuse or log (live: `print("[Admin] {name}: {text}")`) and run; `Start` no longer leaves live, registers a `DataService.Register` load step setting `AdminAccess` for the owner ("open" when `TestSave`, else "mainSave"; Studio: "open"), and answers a bare "/admin" with the refusal or nothing. Each service's dev function swaps its `RunService:IsStudio()` for `DevAccess.can(player, scope)` ("server" for EventService.Dev, WildService.SetPhantomPlayers, the Dungeon ones, BattleService.SetBossHpShare). Leave FrontierService, DungeonGateService and MonetizationService alone.
- [ ] **Step 4: Run** `lune run tests/run` (all pass) and `rojo build -o <scratchpad>/test.rbxl` — Expected: builds.
- [ ] **Step 5: Commit** — "Live admin: one server gate for the panel and every dev function (owner's test save only)"

### Task 3: The Admin tile in the live game

**Files:** Modify `src/client/Controllers/AdminPanelController.luau`

**Interfaces:** Consumes the `AdminAccess` attribute; sends "/admin" for the main save's refusal.

- [ ] **Step 1:** Start: in Studio as today; live, wait for `LocalPlayer:GetAttribute("AdminAccess")` (and its changed signal) and build once it's set. "open": the panel (window title "🛠 Admin", Studio keeps "🛠 Admin (Studio)"); "mainSave": the tile only, its click sends "/admin" (the server's locked card).
- [ ] **Step 2: Verify** a compile check (client files aren't parsed by Lune: `rojo build -o <scratchpad>/test.rbxl`), then in Studio Play the tile and panel open as before.
- [ ] **Step 3: Commit** — "Live admin: the Admin tile for the owner in the published game"

### Task 4: The Footage section

**Files:**
- Modify: `src/server/Services/DevService.luau` (`/footage`), `src/shared/Config/AdminPanel.luau` (`FOOTAGE`, a "Footage" section first in SECTIONS), `src/server/Services/PartyService.luau`, `src/server/Services/TutorialService.luau`, `src/server/Services/CombatTutorialService.luau`
- Test: `tests/AdminPanel.spec.luau`

**Interfaces:**
- Produces: `PartyService.SetSlotsForTesting(player: Player, beastIds: { string }): boolean` (DevAccess-gated, fills slots 1..3); `TutorialService.SkipForTesting(player: Player)` and `CombatTutorialService.SkipForTesting(player: Player)` (first visit skipped, every lesson seen; DevAccess-gated; added to DevGate's list).
- `AdminPanel.FOOTAGE = { late = { level = 60, cash = 1000000, party = { <three Legendary card ids> }, bosses = 7, weapon = { grade = "S", level = 10, mutation = "Legendary" } }, shop = { commands = { "/shoproom open all", "/shoproom fill", "/storage place", "/storage fill", "/decor pieces", "/decor <look id>" } }, golden = { commands = { "/time sunset" } } }`.

- [ ] **Step 1: Tests** (AdminPanel.spec): "Footage is the first section with Late game, Full shop and Golden hour (/footage late|shop|golden)"; "every FOOTAGE command names a registered alias"; "FOOTAGE.late.party names three Legendary cards" (Config/Cards rarity).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `/footage <late|shop|golden>`: each inner command goes through `DevAccess.check` first and stops with its refusal; late = both tutorials skipped, `/level 60`, `/cash 1000000`, `/legendarys`, `/bossbeaten 1..7 on`, three maxed party Legendaries put in the party, every weapon `WeaponService.SetForTesting(player, id, "S", 10)` with a Legendary mutation (kind rolled by `MutationRules.roll`, rarity forced); shop = its commands, then `/stock <product>` for each product in Products order (each shelf takes the first it accepts); golden = `/time sunset`. One Notify at the end ("Footage: late game ready").
- [ ] **Step 4: Run** `lune run tests/run` — all pass.
- [ ] **Step 5: Commit** — "Live admin: Footage presets (late game, full shop, golden hour)"

### Task 5: The Creator title

**Files:** `src/shared/Config/Titles.luau`, `src/shared/Util/TitleRules.luau`, `src/server/Services/TitleService.luau`, `src/client/Controllers/TitleController.luau`, `src/client/Controllers/CharacterController.luau` (lines ~158, ~369); Test: `tests/TitleRules.spec.luau`

**Interfaces:** `Progress.owner: boolean?`; check kind "owner"; `TitleRules.listed(cfg: any, earned: { string }): { string }` (ORDER minus hidden titles not earned).

- [ ] **Step 1: Tests:** "owner kind: earned only with progress.owner"; "a hidden title isn't listed until earned" (listed without creator for a non-owner, with it for the owner); "Creator: five colours, shimmer, first in ORDER".
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement:** `creator = { name = "Creator", color = { 255, 210, 90 }, gradient = { { 255, 107, 107 }, { 255, 210, 90 }, { 110, 231, 160 }, { 110, 203, 255 }, { 185, 140, 255 } }, shimmer = true, icon = "👑", how = "Make this game", check = { kind = "owner" }, hidden = true }`, first in ORDER. TitleService `owner = SaveSlots.isOwner(...)` in progressOf and `far` only for listed titles. TitleController builds the gradient from all colours (evenly spaced keypoints). CharacterController lists and counts `TitleRules.listed`.
- [ ] **Step 4: Run** — pass. **Step 5: Commit** — "Creator title: the owner's rainbow title, hidden from everyone else"

### Task 6: The Creator aura

**Files:** Create `src/shared/Config/CreatorAura.luau`, `src/shared/Util/CreatorAuraRules.luau`, `src/client/Controllers/CreatorAuraController.luau`; Modify `src/server/Services/TitleService.luau` (attribute), `src/client/init.client.luau` (start in both branches); Test: `tests/CreatorAura.spec.luau`

**Interfaces:** `CreatorAuraRules.place(cfg: any, t: number, index: number): { x: number, y: number, z: number, scale: number, alpha: number }` (offsets in studs from the HumanoidRootPart); Config: `COUNT = 3, RADIUS = 3, HEIGHT = 0.4, LAP = 9, BOB = 0.15, SCALE = { back = 0.8, front = 1.1 }, ALPHA = { back = 0.45, front = 0 }, CARD = { w = 1.1, h = 1.6 }, GLOW = { color = { 255, 207, 74 }, size = 1.6 }`.

- [ ] **Step 1: Tests:** "three cards a third of a lap apart"; "a lap takes LAP seconds" (place at t and t + LAP equal); "front card bigger and clearer than back" (z > 0 front: scale front, alpha front).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement:** TitleService sets `player:SetAttribute("CreatorAura", shown == "creator" or nil)` where it sets the shown title. The controller watches every player's attribute and character; for each aura: three Attachments in the HumanoidRootPart, each a BillboardGui (card back `Config/CardDesign BACK.IMAGE` over a gold glow, Config/AttackFx glow texture) moved each RenderStepped by `place`; cleaned on attribute off, character removal and player leaving.
- [ ] **Step 4: Run** — pass; `rojo build`. **Step 5: Commit** — "Creator aura: three card backs circling the owner"

### Task 7: No analytics from the test save

**Files:** Create `src/server/Util/AnalyticsGate.luau`; Modify `src/server/Util/Funnel.luau`, `CombatTutorialService`, `PishService`, `TownChikinService`, `TutorialService`; Test: `tests/DevGate.spec.luau` (one more case)

**Interfaces:** `AnalyticsGate.allowed(player: Player): boolean` = `player:GetAttribute("TestSave") ~= true`.

- [ ] **Step 1: Test:** "every file that logs to AnalyticsService checks AnalyticsGate" (source scan of src/server: a file containing `AnalyticsService:Log` also contains `AnalyticsGate.allowed(`).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement** the gate at each call site (inside the services' `log` helpers where they exist). **Step 4: Run** — pass. **Step 5: Commit** — "Analytics: nothing from the owner's test save"

### Task 8: Docs, Studio check

- [ ] DESIGN.md (dev tools: the live panel, scopes, Footage; Titles: Creator, the aura), CLAUDE.md (Admin panel line, DevGate and new test lines, `/footage`), the spec's status.
- [ ] Studio: `rojo serve` running, Play; `ServerStorage.DevCommand:Invoke(player, "/footage late")`, then shop and golden; screenshot the party, weapons, shop and sunset; set the Creator title on (the owner check is false in Studio: verify with a temporary test of TitleRules only, and the aura by setting the attribute from the server in Play) and screenshot the orbit; Output has no errors.
- [ ] Tell the owner what to judge live after publishing: real save → the locked card; `/slot test` + rejoin → the panel; a second account → no tile, nothing works; Golden hour with someone else in the server → refused.
