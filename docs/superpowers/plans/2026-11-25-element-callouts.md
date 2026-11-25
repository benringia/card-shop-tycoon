# Element Callouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A matchup chip in your creature's status row (weak red, strong green, none when even) and bigger strong-hit
pops with a gold burst, exactly as the approved mockups.

**Architecture:** Pure rules in `Util/MatchupRules` (the chip for a matchup) and `Util/DamagePop.burstRays` (the
burst's layout), numbers in `Config/CombatHud` MATCHUP and `Config/AttackFx` NUMBERS. Client `Util/MatchupChip` draws
the chip inside CombatHud's ChipRow (fed `view.foeElement` by BattleController's `updateHud`); `Util/StrongBurst` draws
the burst inside BattleController's `floatText` billboard and steps with it in `stepNumbers`.

**Tech Stack:** Luau (strict), Rojo, Lune tests, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-25-element-callouts-design.md`

## Global Constraints

- Chip (spec 1): height 26; fill / edge / tag weak 254,226,226 / 243,176,176 / 214,72,72; strong 220,252,231 /
  147,224,168 / 46,160,90; ink 68,48,40; edge 2 px; icon 16 (height - 10); words 11 (floor(height x 0.44)); tag 14 tall
  (height - 12) with 9 px text (floor(14 x 0.7)); padding 8 left, 10 right; gaps 6; tag padding 7 / 9; LayoutOrder 3.
- Words "Weak vs <Foe>" / "Strong vs <Foe>", tag "<multiplier>x" from Combat.STRONG / WEAK; plain names via
  ElementNames; no chip when even, when either element is missing, or with no monster foe.
- Pop (spec 2): strong billboard 220 x 58, peak 2.1, outline 3; burst 12 rays alternating long 64 x 11 / short 44 x 7,
  inner 18, disc 70 at 0.45 transparency, colour 255,196,64, ray fade keypoints (0: 1, 0.55: 0.35, 1: 0.05) from tip
  to root; boss hit peak stays 2.2.
- Pure modules don't require siblings; Lune can't build Color3: configs hold rgb arrays.
- BattleController sits at Luau's 200-local limit: no new file-level locals (inline requires inside functions).
- Client edits: compile check + getDiagnostics. Never `sed -i` in `src`.

## Review Focus

1. A boss that changes element mid-fight (the Prism Hydra): the chip changes with it. Test: MatchupRules gives a
   different chip for the new foe element; MatchupChip re-renders on a changed key (code).
2. Electric against Dark both ways: green, never red. Test: MatchupRules "Electric and Dark".
3. A creature with no element yet or a foe-less fight (the arena): no chip, no error. Test: MatchupRules nil cases.
4. The burst's rays: each one's middle out along its angle (a GUI turns about its middle; the mock's first try
   bunched them up). Test: DamagePop "rays fan all the way round".
5. A strong hit's pop fading with its number, never left on screen. Covered in StrongBurst.step (alpha); Studio.

---

### Task 1: Rules and numbers

**Files:**
- Create: `src/shared/Util/MatchupRules.luau`; Test: `tests/MatchupRules.spec.luau` (register in `tests/run.luau`)
- Modify: `src/shared/Util/DamagePop.luau` (`burstRays`), `src/shared/Config/AttackFx.luau` (NUMBERS.strong peak 2.1,
  NUMBERS.STRONG_BURST), `src/shared/Config/CombatHud.luau` (MATCHUP); Test: `tests/DamagePop.spec.luau`

**Interfaces:**
- Produces: `MatchupRules.chip(combat, mine: string?, foe: string?, names): Chip?` with `Chip = { good: boolean,
  words: string, tag: string, element: string }` (`element`: the foe's key, for its icon); `MatchupRules.tag(multiplier:
  number): string`.
- Produces: `DamagePop.burstRays(burst): { Ray }` with `Ray = { x: number, y: number, width: number, length: number,
  rotation: number }` (x, y the ray's middle from the burst's centre, px; y down; rotation in degrees).
- Produces: `AttackFx.NUMBERS.STRONG_BURST = { rays = 12, long = { length = 64, width = 11 }, short = { length = 44,
  width = 7 }, inner = 18, disc = 70, discTransparency = 0.45, color = { 255, 196, 64 }, fade = { 1, 0.35, 0.05 } }`;
  `CombatHud.MATCHUP = { HEIGHT = 26, GOOD = { fill, edge, tag }, BAD = { fill, edge, tag }, INK }`.

- [ ] **Step 1:** Write the tests (Review Focus 2-4, plus: weak Nature vs Fire -> bad, "Weak vs Fire", "0.75x",
  element "Ember"; strong Nature vs Water -> good, "Strong vs Water", "1.5x"; even -> nil; tag(2) "2x"; strong peak
  equals crit's and stays under bossHit's; the burst config's numbers).
- [ ] **Step 2:** `lune run tests/run MatchupRules` and `lune run tests/run DamagePop`. Expected: FAIL (missing).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Both pass; whole suite green.
- [ ] **Step 5:** Commit `Element callouts: rules and numbers`.

### Task 2: The chip and the burst on screen

**Files:**
- Create: `src/client/Util/MatchupChip.luau`, `src/client/Util/StrongBurst.luau`
- Modify: `src/client/Util/CombatHud.luau` (View `foeElement`; the chip in ChipRow; set on update when the key
  changes, popping in like the perk chip), `src/client/Controllers/BattleController.luau` (`updateHud`: foeElement =
  snapshot.monster's element; `floatText`: strong at crit size and outline with a StrongBurst; `stepNumbers`: step it)

**Interfaces:**
- Consumes: Task 1's rules and configs.
- Produces: `MatchupChip.new(parent: Instance, order: number): { set: (chip: MatchupRules.Chip?) -> () }`;
  `StrongBurst.make(parent: Instance): { step: (scale: number, alpha: number) -> () }`.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Compile check the four files, getDiagnostics, whole suite.
- [ ] **Step 3:** Commit `Element callouts: the chip and bigger strong hits`.

### Task 3: Docs and Studio check

- [ ] **Step 1:** DESIGN.md (an "Element callouts" bullet after Finishing blow), the file tree, CLAUDE.md test list.
  Commit `Element callouts: docs`.
- [ ] **Step 2:** Studio: a weak, a strong and an even fight (chip), a swap mid-fight, a strong hit's pop (the burst
  drawn and gone with the number), a phone in the Device emulator; Output clean; tell the owner what to judge.
