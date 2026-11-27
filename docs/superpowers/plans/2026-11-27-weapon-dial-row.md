# Weapon dial as a row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The weapon dial becomes a row like the party dock: the weapon in hand big in the middle, the one before and the next either side with Z and Q under them, its name under it, its level on top, its grade as the cards' medal.

**Architecture:** Pure geometry (`UiLayout.switchBox`, `WeaponSwitch.rowSpot`, the track without `later`) with Lune tests; the controller redraws the row from it; UIController reads the same box for the bottom bar.

**Tech Stack:** Luau, Rojo, Lune tests.

**Spec:** `docs/superpowers/specs/2026-11-27-weapon-dial-row-design.md`

## Global Constraints
- Sizes: big 72 px (`chip`), sides 44 px (`side`), 48 px tap areas (`hit`), `row` 8 px between them, sides `drop` 8 px lower, the level pill reaching `rise` 9 px over the top, the name line `name` 20 px under it, the medal 24 px.
- Plain ASCII text. Keys only on keyboards. Phones keep the medallion alone.

## Review Focus
1. Two weapons: only the next shows on the right; Z still steps (wraps to it). Pinned by the track test.
2. A computer's fight at 0.7: tap areas still 32 px or more, clear of the fight buttons. Pinned by UiLayout tests.
3. The bottom bar and the toasts make room for the row's real width and height. Pinned by using switchBox in both.

### Task 1: Pure geometry
**Files:** `src/shared/Util/UiLayout.luau`, `src/shared/Util/WeaponSwitch.luau`, `tests/UiLayout.spec.luau`, `tests/WeaponSwitch.spec.luau`, `tests/CompactHud.spec.luau`
- `UiLayout.switchBox(look): (number, number)` = width `chip + 2 * row + side + hit`, height `rise + chip + name`; `UiLayout.weaponSwitch` sizes its box from it (compact: `compactChip` square).
- `WeaponSwitch.track(list, current)` = `{ before, after }` (two weapons: `{ after }`); `roll` over center/before/after; `WeaponSwitch.rowSpot(spot, look): (number, number)` = before `(-(chip/2 + row + side/2), drop)`, after `(+..., drop)`, center `(0, 0)`.
- [ ] Tests first (RED): the row's box at 72/44/48/8/9/20 is 180 x 101; rowSpot before (-66, 8), after (66, 8); track has no `later` with four or more; roll forward: current from "after", before from "center", after nil (fades in). Then GREEN, then commit.

### Task 2: The controller and the bar
**Files:** `src/shared/Config/HudLayout.luau`, `src/client/Controllers/WeaponSwitchController.luau`, `src/client/Controllers/UIController.luau`
- Config: drop `arc`, `angles`, `laterFade`, `laterScale`, `nameSeconds`-for-desktop; add `row = 8, drop = 8, rise = 9, name = 20, medal = 24`; `side = 44`.
- Controller: box and centre from switchBox; two orbs at rowSpot; key caps under them; the level pill, the medal, the name under; the roll along the row; the phone's medallion unchanged but with the medal.
- UIController: the bar's width and the toasts' room from switchBox.
- [ ] Compile check, suite, Studio: the row at the corner, a switch rolling, a fight's row over the buttons, a phone's medallion; commit.

### Task 3: Docs
DESIGN "Quick weapon switch" paragraph, CLAUDE.md test list (WeaponSwitch, UiLayout), vault, memory. Commit.
