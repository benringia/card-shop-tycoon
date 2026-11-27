# What now? hints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player who has done nothing for a while gets one tip: Pish's face and words in a white bubble standing on the gold arrow that points at the one best next thing.

**Architecture:** A pure shared `Util/HintRules` (which tip, its words, when one may show, where the bubble sits) with numbers and words in `Config/Hints`. A client `HintController` gathers the facts the client already holds for its HUD (quests, main quest, boss board, Bag, shelves, stations, carry and pad attributes), watches for idle, and draws the tip with `TutorialCues.pointAt` plus a new `Util/HintBubble`. The server adds one attribute (`RegisterWaiting`), a tiny `HintService` that logs tip analytics from a validated `TipSeen` remote, and a `/tip <kind>` dev command. The quest reminder bubble and Pish's stuck helper are retired.

**Tech Stack:** Luau (Roblox), Rojo, Lune tests (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-11-27-what-now-hints-design.md`

## Global Constraints

- Look 1: a white bubble with Pish's face (Config/HudMascot `images.peek`), the words and a small x, on the gold arrow (`TutorialCues.pointAt`): over it on a button or a thing in the world, beside it when the arrow waits at the screen's edge.
- The tips, first match wins: register, claim, stock, order, station, build, packs, boss, quest, hunt.
- When: stood still 30 s, or 120 s with nothing earned (cash and XP unchanged); never in the first 60 s after joining; one tip every 120 s at most; the same tip not again for 300 s; a tip stays 20 s (45 s for a walk to a spot); x mutes that tip for the session.
- Never during Pish's tour (`TutorialDone` false), while Chikin leads (`CombatStep` not nil, "" or `Chikin.WAIT_STEP`), during Pish's lesson visits, `Hud.isCalm()`, or any `PlayerBusy.reason({ carrying = true })`.
- Main place only (`workspace:GetAttribute("PlaceKind") == "Main"`).
- Text: plain ASCII plus `·` (CLAUDE.md UI rule). Tap targets 48 px or more (the x's tap area).
- Every remote in `src/shared/Remotes.luau`, its args validated, rate-limited with `server/Util/RateLimiter`.
- Numbers and words in `Config/Hints`; pure modules don't require siblings (Lune has no `script`).
- Analytics only through `AnalyticsGate.allowed` (TutorialService's `log` pattern).

## Review Focus

1. A tip whose target isn't there (no station placed, no register built yet, the Phone hidden in the Wild): the player sees no bubble floating alone; the controller skips that tip and picks the next. Pinned by Task 4's Step "unresolved target" check in Studio and by `pick` taking a skip set (Task 1 test "skipped kinds are passed over").
2. An arrow at a screen corner or edge: the bubble stays fully on screen. Pinned by Task 2's `bubbleAt` clamp tests.
3. A phone: the claim and quest tips point at the quest strip, not a hidden Phone app. Pinned in Task 4 (`QuestController.TipTarget`) and checked in Studio's device view.
4. Ordering with boxes already on the way: no "Order packs to sell!" while boxes come. Pinned by Task 1 test "order waits for boxes on the way".
5. A tip shown when the player starts a fight or opens a window: it hides at once and isn't logged as followed unless its own window opened. Pinned in Task 4's controller rules and the Studio check.

---

### Task 1: The tips and their words (Config/Hints, HintRules.pick / holds / words)

**Files:**
- Create: `src/shared/Config/Hints.luau`, `src/shared/Util/HintRules.luau`
- Test: `tests/HintRules.spec.luau`

**Interfaces:**
- Produces: `Config/Hints` with `ORDER: { string }` = `{ "register", "claim", "stock", "order", "station", "build", "packs", "boss", "quest", "hunt" }`; `WORDS` (below); timing `IDLE = 30, LOST = 120, FIRST = 60, GAP = 120, REPEAT = 300, SHOW = 20, WALK_SHOW = 45`; `BUBBLE = { gap = 6, margin = 8, height = 46, face = 36, text = 18, x = 26, tap = 48 }`; `FACE = "rbxassetid://125657246581399"`.
- Produces: `export type Facts = { registerWaiting: boolean, questsDone: number, boxWaiting: boolean, boxesComing: number, shelvesStocked: boolean, cash: number, cheapestBox: number?, stationReady: string?, buildName: string?, packs: number, boss: { name: string, cleared: boolean }?, questText: string?, inTown: boolean }`
- Produces: `HintRules.holds(kind: string, facts: Facts): boolean`, `HintRules.pick(facts: Facts, skip: { [string]: boolean }, order: { string }): string?`, `HintRules.words(kind: string, facts: Facts, words: any): string`

`WORDS`: `register = "Customers are waiting! Ring them up."`, `claim = { one = "A quest is done! Claim it.", many = "%d quests are done! Claim them." }`, `stock = "Put your box on a shelf!"`, `order = "Order packs to sell!"`, `station = { Condenser = "Your new star is ready! Take it out.", GradingStation = "Your graded card is ready! Take it out." }`, `build = "You can build the %s!"`, `packs = { one = "Open your pack!", many = "Open your %d packs!" }`, `boss = { ready = "You're strong enough for the %s!", loot = "The %s's loot is ready!" }`, `hunt = "Hunt monsters in the Wild!"` (quest's words are `facts.questText`).

When each holds: register `registerWaiting`; claim `questsDone > 0`; stock `boxWaiting`; order `not shelvesStocked and not boxWaiting and boxesComing == 0 and cheapestBox ~= nil and cash >= cheapestBox`; station `stationReady ~= nil`; build `buildName ~= nil`; packs `packs > 0`; boss `boss ~= nil`; quest `questText ~= nil`; hunt `inTown`. An unknown kind never holds.

- [ ] **Step 1: Write the failing tests** in `tests/HintRules.spec.luau` (a `facts(over)` helper returns all-false facts with `inTown = false`, `cash = 0`, `packs = 0`, `questsDone = 0`, `boxesComing = 0`, merged with `over`):
  - "nothing to do in the Wild: no tip" — `pick(facts({}), {}, Hints.ORDER) == nil`
  - "nothing to do in town: hunt" — `pick(facts({ inTown = true }), {}, ORDER) == "hunt"`
  - "the first that's true wins" — facts with `registerWaiting`, `questsDone = 2`, `packs = 3`, `inTown` → "register"; without register → "claim"; with only packs and inTown → "packs"
  - "skipped kinds are passed over" — `registerWaiting` and `packs = 1` with skip `{ register = true }` → "packs"
  - "order needs empty shelves, the cash and nothing on the way" — `cheapestBox = 40, cash = 40` → "order"; `cash = 39` → nil (not in town); `boxesComing = 2` → nil; `boxWaiting = true` → "stock"; `shelvesStocked = true` → nil; `cheapestBox = nil` → nil
  - "words fill in counts and names" — claim 1 → "A quest is done! Claim it."; claim 3 → "3 quests are done! Claim them."; packs 1 → "Open your pack!"; packs 4 → "Open your 4 packs!"; build `buildName = "Bulk Bin"` → "You can build the Bulk Bin!"; station `"GradingStation"` → "Your graded card is ready! Take it out."; boss `{ name = "Meadow Warden", cleared = false }` → "You're strong enough for the Meadow Warden!"; cleared → "The Meadow Warden's loot is ready!"; quest → its `questText`
  - "every word is plain text" — every string in `Hints.WORDS` (nested too) matches `^[%w%s%p·]*$` after removing `·`, and none is longer than 46 characters once a `%d`/`%s` is filled with "12" / "Meadow Warden"
  - "an unknown kind never holds" — `holds("nope", facts({ inTown = true })) == false`

- [ ] **Step 2: Run them to see them fail**
  Run: `lune run tests/run HintRules`
  Expected: FAIL (module not found)

- [ ] **Step 3: Write `Config/Hints.luau` and `HintRules.holds / pick / words`** with the values above (words via `string.format`).

- [ ] **Step 4: Run them to see them pass**
  Run: `lune run tests/run HintRules`
  Expected: all pass

- [ ] **Step 5: Commit**
  `git add src/shared/Config/Hints.luau src/shared/Util/HintRules.luau tests/HintRules.spec.luau && git commit -m "What now: the tips, in order, and their words"`

### Task 2: When a tip may show, where its bubble sits, what the server accepts

**Files:**
- Modify: `src/shared/Util/HintRules.luau`
- Test: `tests/HintRules.spec.luau`

**Interfaces:**
- Consumes: `Config/Hints` timing and `BUBBLE` (Task 1).
- Produces: `export type Timing = { joinedAt: number, idleSince: number?, quietSince: number, lastShownAt: number? }`; `HintRules.due(now: number, t: Timing, cfg: { FIRST: number, IDLE: number, LOST: number, GAP: number }): boolean` (past `FIRST` since joining; idle `IDLE` s or quiet `LOST` s; `GAP` s since the last tip or none yet)
- Produces: `HintRules.skip(now: number, shownAt: { [string]: number }, muted: { [string]: boolean }, repeatSeconds: number): { [string]: boolean }` (muted kinds and kinds shown less than `repeatSeconds` ago)
- Produces: `export type Box = { x: number, y: number, w: number, h: number }`; `HintRules.bubbleAt(arrow: Box, rotation: number, bubble: { w: number, h: number }, view: { w: number, h: number }, cfg: { gap: number, margin: number }): { x: number, y: number }` (the bubble's top-left)
- Produces: `HintRules.readSeen(kind: unknown, outcome: unknown, order: { string }): (string?, string?)`: the kind when it's in `order` and the outcome when it's "shown", "done" or "closed"; nils otherwise

`bubbleAt`: the arrow points along `(-sin r, cos r)` (r in degrees: 0 down, 90 left, -90 right, 180 up). The bubble's centre is the arrow box's centre moved against that direction by the arrow's half extent along it + `gap` + the bubble's half extent along it (`|ux| * w / 2 + |uy| * h / 2` for each box), then the top-left is rounded to whole px (sin and cos of 90 and 180 aren't exact) and clamped so the bubble lies `margin` inside the view.

- [ ] **Step 1: Write the failing tests:**
  - "a tip waits past the first minute" — `due(59, { joinedAt = 0, idleSince = 0, quietSince = 0 }, Hints) == false`; at 60 with idle since 30 → true
  - "standing idle 30 s or 2 minutes with nothing earned" — joinedAt 0, now 200: idleSince 171 with quietSince 199 → false, idleSince 170 → true; idleSince nil and quietSince 81 → false, 80 → true
  - "two minutes between tips" — joinedAt 0, idleSince 0, quietSince 0, lastShownAt 100: now 219 → false; 220 → true
  - "a muted tip or one shown in the last 5 minutes is skipped" — `skip(400, { packs = 101, claim = 99 }, { hunt = true }, 300)` gives `packs = true`, `hunt = true`, no `claim`
  - "over an arrow pointing down the bubble sits above it" — arrow `{ x = 480, y = 300, w = 78, h = 78 }`, rotation 0, bubble `{ w = 240, h = 46 }`, view `{ w = 1000, h = 600 }`, cfg `{ gap = 6, margin = 8 }` → `{ x = 399, y = 248 }`
  - "beside an arrow at the left edge it sits to its right" — arrow `{ x = 17, y = 261, w = 78, h = 78 }`, rotation 90 → `{ x = 101, y = 277 }`
  - "an arrow pointing up puts it underneath" — arrow `{ x = 480, y = 20, w = 78, h = 78 }`, rotation 180 → `{ x = 399, y = 104 }`
  - "never off the screen" — arrow `{ x = 2, y = 2, w = 78, h = 78 }`, rotation 0, bubble 240 x 46 → x == 8 and y == 8; arrow at `{ x = 950, y = 300 }` rotation 0 → x == 1000 - 8 - 240
  - "the server takes only real tips and outcomes" — `readSeen("packs", "shown", Hints.ORDER)` → "packs", "shown"; `("packs", "eaten")`, `("nope", "done")`, `(5, "done")`, `("packs", nil)` → nil, nil

- [ ] **Step 2: Run them to see them fail**
  Run: `lune run tests/run HintRules`
  Expected: FAIL on the new tests (functions missing)

- [ ] **Step 3: Implement `due`, `skip`, `bubbleAt`, `readSeen`** in `HintRules.luau`.

- [ ] **Step 4: Run them to see them pass**
  Run: `lune run tests/run HintRules`
  Expected: all pass

- [ ] **Step 5: Commit**
  `git commit -am "What now: when a tip shows, where its bubble sits"` (add the files explicitly)

### Task 3: The server's part (RegisterWaiting, HintService analytics, /tip)

**Files:**
- Modify: `src/server/Services/RegisterService.luau` (the bell loop, lines 464-479)
- Create: `src/server/Services/HintService.luau`
- Modify: `src/shared/Remotes.luau` (NAMES), `src/server/init.server.luau` (start HintService), `src/server/Services/DevService.luau` (`/tip`), `src/shared/Config/AdminPanel.luau` (a "What now? tips" section)

**Interfaces:**
- Produces: player attribute `RegisterWaiting` (true while a checkout waits unattended after its first ring, nil otherwise: set each loop tick to `if rings > 0 and not isBehindCounter(owner, plot) then true else nil`, and nil when the loop ends)
- Produces: remote `TipSeen` — client → server: `(kind: string, outcome: "shown" | "done" | "closed")`; HintService validates with `HintRules.readSeen`, rate-limits with `RateLimiter.new(0.5)`, and logs `AnalyticsService:LogCustomEvent(player, "Tip" .. capitalised outcome ("TipShown", "TipDone", "TipClosed"), 0, { [CustomField01] = kind })` through `AnalyticsGate.allowed` and `pcall`
- Produces: dev command `/tip <kind>` (Studio and the owner's test save; scope "own"): sets `player:SetAttribute("TipPreview", "<kind>:<os.clock()>")` for a known kind, else Notify "Usage: /tip <register|claim|stock|order|station|build|packs|boss|quest|hunt>"
- Produces: AdminPanel section `title = "What now? tips"` with one button per kind (`label` = the kind's English name, `command = "/tip <kind>"`)

- [ ] **Step 1: Write the code** (RegisterService loop lines, HintService with `Start()`, the Remotes entry `"TipSeen", -- client → server: (kind, outcome) a tip was shown, followed or closed (HintService analytics)`, HintService required and started in `init.server.luau` after QuestService, the `/tip` command, the AdminPanel section).
- [ ] **Step 2: Verify**
  Run: `lune run tests/run` (DevRules and AdminPanel tests check every button's command and scope) and the compile check on the changed server files.
  Expected: all pass; compiled N files, 0 failed
- [ ] **Step 3: Commit** `"What now: RegisterWaiting, tip analytics, /tip"`

### Task 4: The client (HintBubble, HintController, the exports it reads)

**Files:**
- Modify: `src/client/Util/TutorialCues.luau` (`pointerOf`)
- Create: `src/client/Util/HintBubble.luau`, `src/client/Controllers/HintController.luau`
- Modify: `src/client/Controllers/QuestController.luau` (`TipTarget`, `QuestView`), `BossBoardController.luau` (`Suggested`), `TutorialController.luau` (`IsVisiting`), `StockHintController.luau` (`Glowing`), `src/client/init.client.luau` (start HintController last)

**Interfaces:**
- Consumes: Tasks 1-3 (`HintRules.*`, `Config/Hints`, `TipSeen`, `TipPreview`, `RegisterWaiting`).
- Produces: `TutorialCues.pointerOf(): { box: TalkRules.Box, rotation: number }?` — the newest pointer's arrow as drawn (its holder's AbsolutePosition and AbsoluteSize, its arrow's Rotation), nil while none shows; both `pointAt` branches set it, the remover clears it.
- Produces: `HintBubble.show(text: string, onClose: () -> ()): () -> ()` (draws on `TutorialCues.screen()`, each frame placed by `HintRules.bubbleAt` from `TutorialCues.pointerOf()`, hidden while it returns nil; the x's tap area `BUBBLE.tap` px; returns the remover)
- Produces: `QuestController.QuestView(): any?` (the quest view the panel draws), `QuestController.TipTarget(): GuiObject?` (a computer: the Phone tile `Hud.find("Manage")` while the tray is shut, else `Hud.find("Quests")`; a phone: the quest strip button)
- Produces: `BossBoardController.Suggested(): { name: string, cleared: boolean }?` — the first boss of `Bosses.LADDER` in the Wild (`boss.place == "Wild"`) that is not cleared with step "ready", or cleared with its loot timer at 0 and the party's Power at or over `boss.recommended`
- Produces: `TutorialController.IsVisiting(): boolean` (a lesson or the tour on: `visit ~= nil or step ~= ""`)
- Produces: `StockHintController.Glowing(): { BasePart }` (the shelves and racks lit now)

HintController (main place only), once a second:
- Facts: `RegisterWaiting`; `QuestView()` claimable (day + week); `BoxesWaiting`/`CarryCount` > 0; `BoxesComing`; any part in the plot's `Shelves` folder with `Units` > 0; `Cash`; `LessonRules.cheapestBox(Products.List, Level)`; `CondenserDone`/`GradingDone` set (and that station placed); `MainQuest.current()` build `ready` name; openable packs in the Bag (`ItemsChanged`, `ItemRules.openablePack`); `BossBoardController.Suggested()`; `QuestRemind.words(view, nil)` text when not "strong"; in town (`MusicRules.inTown`).
- Targets: register `RegisterHousing`; claim and quest `QuestController.TipTarget()`; stock the nearest `Glowing()` part while carrying, else `DeliverySpot`; order `OrderComputer`; station the plot's `Shelves` part named `Condenser` / `GradingStation`; build the Phone tile or `Hud.find("Build")` (as TutorialController's targetButton); packs `Hud.find("Bag")`; boss in town and hunt the Wild portal spot (`Wild.PLAZA_PORTAL`, 9 studs up, ground arrows via `TutorialCues.trail`), boss in the Wild the model named `BossPortal <name>`. A tip whose target isn't found is skipped for this pick.
- Idle: any `InputBegan` or `MoveDirection` clears `idleSince`; a `Cash` or `XP` change resets `quietSince`; `free` as Global Constraints; `HintRules.due` then `HintRules.pick(facts, HintRules.skip(now, shownAt, muted, Hints.REPEAT), Hints.ORDER)`.
- Showing: `TutorialCues.pointAt` + `HintBubble.show`; `TipSeen(kind, "shown")`; each second: not free → hide; a window opened for a button tip → done; `holds` false or the town/Wild side changed → done (`TipSeen "done"`); `SHOW` (`WALK_SHOW` for a spot) up → hide; x → mute the kind, `TipSeen "closed"`.
- `TipPreview` changed → show that kind now with its words and target, ignoring timing and facts (a missing target: Notify "Nothing to point at for <kind> here").

- [ ] **Step 1: Write TutorialCues.pointerOf, HintBubble, the four exports and HintController; start it in init.client.luau.**
- [ ] **Step 2: Verify**
  Run: the compile check on every changed client file, `lune run tests/run` (SourceOrder, RequireCycles).
  Expected: 0 failed
- [ ] **Step 3: Studio check** (Rojo serving, Play): `/tip` each kind and screenshot the bubble on its target (packs on the Bag, order on the computer, hunt from behind with the edge arrow); stand idle 35 s and see a real tip; open a window mid-tip (it hides); Output clean.
- [ ] **Step 4: Commit** `"What now: the bubble on the arrow, the controller"`

### Task 5: Retire the quest reminder and the stuck helper

**Files:**
- Modify: `src/client/Controllers/QuestController.luau` (remove `startReminder` and its call), `src/shared/Util/QuestRemind.luau` (remove `due`, keep `words`), `tests/QuestRemind.spec.luau` (remove `due` tests), `src/shared/Config/Quests.luau` (remove `REMIND` and its comment)
- Modify: `src/server/Services/TutorialService.luau` (remove `checkStuck`, `lastNudge`, `mutedNudges`, `lastActive`/`markActive`/`newcomers` where only the helper used them, the `nudgeOff` action), `src/shared/Util/LessonRules.luau` (remove `nudge` and its `Facts` type; keep `cheapestBox`), `tests/LessonRules.spec.luau` (remove the nudge tests), `src/shared/Config/Pish.luau` (remove `STUCK`), `src/shared/Config/PishTalk.luau` (remove the nudges' lines), `src/client/Controllers/TutorialController.luau` (remove `NUDGES`, `NUDGE_RANGE`, `NUDGE_KEEP`, `NUDGE_USES`, `pendingNudge`, `nudgeAt`, the "nudge" visit kind and its branches)

- [ ] **Step 1: Remove them** (grep `nudge`, `STUCK`, `REMIND`, `startReminder`, `QuestRemind.due` until only intended hits remain).
- [ ] **Step 2: Verify**
  Run: `lune run tests/run`, the compile check on each changed file.
  Expected: 0 failed
- [ ] **Step 3: Studio check:** Play, Output clean (TutorialController and QuestController start), a lesson visit still runs (`/tutorial lesson prices`).
- [ ] **Step 4: Commit** `"What now: retire the quest reminder and the stuck helper"`

### Task 6: Docs and notes

**Files:** `DESIGN.md` (a "What now? tips" section with the list, timing, look, `/tip`; the Stuck helper and quest reminder lines say they were folded into it; file tree: HintRules, Hints, HintBubble, HintController, HintService), `CLAUDE.md` (the test list: HintRules; QuestRemind's entry trimmed to its words; LessonRules' "stuck helper" wording; the dev command `/tip <kind>`), the vault (decisions log; playbook "never let a player go idle" lesson), memory.

- [ ] **Step 1: Write them.**
- [ ] **Step 2: Run** `lune run tests/run`. Expected: 0 failed.
- [ ] **Step 3: Commit** `"What now: DESIGN and CLAUDE.md"`
