# Weapons Round 4, Part 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Weapons show a whole-number Attack, the weapon window becomes layout A (one gold box, short rows, distinct
icons), and the Prism Blade keeps only "always strong".

**Architecture:** The words and numbers in `Util/WeaponText` (pure, Lune-tested) and the Prism rule in
`Util/WeaponRules`; the skills' short lines in `Config/CombatHud`; the Prism's Power in `Config/Weapons`. Client
`WeaponFace`, `ForgeController`, `CharacterController` print Attack; `WeaponDetailController`'s right side is rebuilt
as layout A from `WeaponText.rows`.

**Tech Stack:** Luau (strict), Rojo, Lune tests, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-25-weapons-round4-design.md` (Part 1)

## Global Constraints

- Attack = round(Power x 100); the multiplier stays in sims, saves and rules.
- Layout A sizes: gold box 70 px (number 36 px FredokaOne), rows 48 px (icon 30, title 15, line 12), 5 px apart;
  gold box fill 255,248,228 with the gold edge; the Prism's ALWAYS STRONG row fill 255,244,200, gold edge 2.5.
- Icons: Attack "Power", Supers "Lock", ALWAYS STRONG "Elements", perks by kind (heal Heal, burn Ember, venom Skull,
  erupt MoveInferno, chill Cooldown, chain Chain, execute Target), bond the element's.
- Prism Blade: Power 1.0, no bond, unlocks no super, shown Power = Power x Combat.STRONG.
- Plain ASCII text (plus · and emoji): FredokaOne and Gotham draw other symbols as boxes.
- Client edits: compile check + getDiagnostics. Never `sed -i` in `src`.

## Review Focus

1. A weapon whose Attack rounds across .5 (1.505 -> 151, not 150): rounding the shown value, never truncating. Test:
   WeaponText "Attack rounds the multiplier".
2. versus between two weapons whose Attacks round the same: "Same Attack as ..." (the old 0.005 rule in whole
   numbers). Test: WeaponText versus.
3. The Steel Sword and a weapon with no perk or element: no empty rows. Test: WeaponText.rows for starterSword.
4. A creature super with the Prism in hand: locked (SuperLock says which element weapon it needs). Test: WeaponRules
   superUnlocked prism false.
5. Every skill's short line fits one line in the row (about 55 characters). Test: CombatHud shorts length.

---

### Task 1: Words, numbers and the Prism rule

**Files:**
- Modify: `src/shared/Util/WeaponText.luau` (attack, attackLine; stats, powerGain, versus, powerRange, say, tabLine in
  Attack; rows), `src/shared/Util/WeaponRules.luau` (Prism: no super unlock, no bond, shownPower x STRONG),
  `src/shared/Config/Weapons.luau` (prismBlade power 1.0), `src/shared/Config/CombatHud.luau` (SKILLS `short`,
  BUTTONS.skill `short`)
- Test: `tests/WeaponText.spec.luau`, `tests/WeaponRules.spec.luau`

**Interfaces:**
- Produces: `WeaponText.attack(power: number): number` (round x 100); `WeaponText.rows(cfg, hud, combat, weaponId,
  owned?): { Row }` with `Row = { kind: "skill" | "perk" | "bond" | "strong" | "supers" | "range", icon: string, title:
  string, words: string }` in window order; `WeaponText.skill` gains `short`.

- [ ] **Step 1:** Write the tests (Review Focus 1-5, plus the new strings: card "Attack 151" via attackLine, powerGain
  "+8 Attack", versus "+41 vs Steel Sword" / "Same Attack as ...", powerRange "Attack 121 to 209" for the Rift Reaper,
  say "more Attack!", tabLine "more Attack", stats' first row { label = "Attack", value = "151" }; rows for the Verdant
  Blade (skill, perk heal, bond), the Prism (skill, strong, supers), the Steel Sword (skill only), an unowned weapon
  (range first); the Prism's shownPower 1.5 at Grade C +0; bond(prism) 1, 1).
- [ ] **Step 2:** `lune run tests/run WeaponText` and `WeaponRules`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Both pass; whole suite green.
- [ ] **Step 5:** Commit `Weapons round 4: Attack numbers, the rows, the Prism rule`.

### Task 2: On screen

**Files:**
- Modify: `src/client/Util/WeaponFace.luau` ("Attack N"), `src/client/Controllers/ForgeController.luau` (maxed "Attack
  N"), `src/client/Controllers/CharacterController.luau` (the Attack tile as a whole number),
  `src/client/Controllers/WeaponDetailController.luau` (layout A from WeaponText.rows; the gold Attack box)

**Interfaces:**
- Consumes: Task 1's WeaponText.attack / rows.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Compile check, getDiagnostics, whole suite.
- [ ] **Step 3:** Commit `Weapons round 4: the weapon window, layout A`.

### Task 3: Balance, docs and Studio check

- [ ] **Step 1:** `lune run tools/balance/bosses` for the Prism Hydra with the Prism Blade before and after; note the
  numbers. DESIGN.md (the four rules, Attack, layout A, the Prism), CLAUDE.md test lines. Commit `Weapons round 4: docs`.
- [ ] **Step 2:** Studio: the window for an owned element weapon, an unowned one, the Steel Sword and the Prism; the
  Forge; the character window; a phone; Output clean; tell the owner what to judge.
