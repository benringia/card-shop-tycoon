# Windows Round 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner's round 3 picks: tidy Filters, slim Prices, the Bag on its own, a big-number XP pill, party XP
sparks after monster wins, a "Return to town" pill.

**Architecture:** UI built in code with `Util/UIKit` (two new pieces: `UIKit.segmented`, `UIKit.dotTag`); pure,
Lune-tested rules in `Util/XpPill` (number text, count-up) and `Util/SparkPath` (the curved flight); numbers in
`Config/HudLayout` (XP pill, sparks) and `Config/BabyColors`.

**Tech Stack:** Luau `--!strict`, Rojo, Lune (`lune run tests/run`), Roblox Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-11-03-windows-round3-design.md`

## Global Constraints

- Cotton candy look; fight screens untouched; tap targets >= 48 px; nothing on phones grows.
- Plain ASCII plus `·`; no magic numbers in controllers; keep DESIGN.md in sync.

## Review Focus

1. Clear all resets every filter and the search box text, and the count updates.
2. The Bag opened while the binder is open (or the binder while the Bag is open): one window at a time.
3. XP count-up interrupted by another change (two quick sales): it ends on the newest value.
4. A won fight with no party portrait for a creature (swapped mid-fight): no spark to a missing portrait, no error.
5. Phones: the slim price rows and the Filters window fit a landscape phone.

---

### Task 1: XP pill (big number, thin bar)

**Files:** Create `src/shared/Util/XpPill.luau`, `tests/XpPill.spec.luau`; modify `src/client/Controllers/UIController.luau`,
`src/shared/Config/HudLayout.luau`, `tests/run.luau`; remove `src/shared/Util/XpPaws.luau` and `tests/XpPaws.spec.luau`.

- Produces: `XpPill.amount(n: number): string` ("99,800 XP", "MAX" past the top), `XpPill.total(n: number): string`
  ("/ 226,000"), `XpPill.countUp(from: number, to: number, t: number): number` (eased, whole numbers, `t` 0..1).
- [ ] Tests first: commas ("1,234,567 XP"), zero, MAX at the top level; countUp ends exactly on `to`, starts on `from`,
  never overshoots, whole numbers.
- [ ] Implement; the pill: star with the level, "99,800 XP" big and "/ 226,000" small, thin bar under; a change counts
  up over `HudLayout.XP_PILL.countSeconds` (a newer change restarts from the shown value).
- [ ] Studio: screenshot; `/xp 500` counts up. Commit "XP pill: a big number and a thin bar".

### Task 2: Party XP sparks

**Files:** Create `src/shared/Util/SparkPath.luau`, `tests/SparkPath.spec.luau`; modify
`src/client/Controllers/PartyBarController.luau` (`PartyBarController.ShowXpGains(from: Vector2, gains: { [string]: number })`
by beastId), `src/client/Controllers/BattleController.luau` (wild win -> sparks), `src/shared/Config/Party.luau`
(`BAR.SPARKS`).

- Produces: `SparkPath.point(from, to, lift, t): (x, y)` (a quadratic curve bowed up by `lift`), `SparkPath.count(xp, min, max)`.
- [ ] Tests first: t=0 is `from`, t=1 is `to`, the middle sits above the straight line by `lift/2`; count grows with xp and stays in [min, max].
- [ ] Implement; on a wild win the monster's last screen position (or screen centre) is the start; each portrait
  whose beastId is in the gains gets sparks, then "+N XP" pops and the level label counts up.
- [ ] Studio: a wild fight won; screenshot mid-flight. Commit "Party XP sparks after a monster win".

### Task 3: Return to town pill

**Files:** `src/client/Controllers/BattleController.luau`.
- [ ] The shop button becomes a soft sky icon button ("Travel" icon, "Return to town") inside a holder marked
  `SoftButtons`; same place, height 48. Studio screenshot in the Wild. Commit "Return to town pill".

### Task 4: Slim Prices rows

**Files:** `src/client/Controllers/PricingController.luau`, `src/client/Util/UIKit.luau` (`UIKit.dotTag` if shared),
`src/shared/Config/BabyColors.luau` (stepper sizes).
- [ ] Rows as the spec; the stepper's round buttons 30 px drawn inside 48 px tap areas; tapping the price types one.
- [ ] Studio: Prices on PC and a landscape phone. Commit "Prices: slim rows with a little stepper".

### Task 5: Filters (tidy column)

**Files:** `src/client/Util/UIKit.luau` (`UIKit.segmented(parent, options: {string}, chosen: string, onPick): (Frame, (string) -> ())`,
`UIKit.dotTag(parent, text, color): TextButton`), `src/client/Controllers/BinderController.luau`.
- [ ] The window as the spec; "N of M cards" from the filtered list; Clear all resets show, sort, rarity and search.
- [ ] Studio: open Filters, pick, sort, clear. Commit "Filters: a tidy column".

### Task 6: The Bag on its own

**Files:** `src/client/Controllers/BinderController.luau`.
- [ ] The Bag window parents to the main ScreenGui as a `UIKit` main panel (one window at a time, touch controls
  hidden, the HUD hidden while open); the Bag tile and I open it; the binder's Cards / Bag tabs go.
- [ ] Studio: Bag from the tile and from I; binder alone. Commit "Bag: its own window".

### Task 7: Docs and checks

- [ ] DESIGN 10.6 (XP pill, sparks, Filters, Prices, Bag, Return to town), CLAUDE.md test list (XpPill, SparkPath;
  XpPaws gone), vault. Tests, `rojo build`, two landscape phones. Commit "Round 3: docs".
