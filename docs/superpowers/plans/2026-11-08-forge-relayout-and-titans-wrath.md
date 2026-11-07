# Forge Relayout and Titan's Wrath Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Forge window's pane relaid out as the owner's pick A (tab line, header, Now/After boxes with the blue
arrow picture, cost chips) and the Titan's Lance's own Legendary skill, Titan's Wrath.

**Architecture:** Pure text and rules in `src/shared` (Lune-tested), the window in `ForgeController`; the skill as a
new `titansLance` moveset in `Config/Swords` (the spear's cuts shared), its server shape through the existing
`SwordRules` line, its animation keyed in Blender, its effects in `Config/SwordSkillFx` + client `Util/SwordSkillFx`.

**Tech Stack:** Luau (Rojo), Lune tests, Blender 5.2 background runs (`run_sword_moves.py`), Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-08-forge-relayout-and-titans-wrath-design.md`

## Global Constraints

- Text: plain ASCII plus `·` and emoji; no "->" in the Forge boxes (the arrow is the `UIIcons.Next` picture).
- Tap targets 48 px or more; windows' colours from `UIKit.colorsFor` (cotton candy theme).
- Skill: power 0.9, cooldown 8, a dodge before the hit cancels it, the switch lock applies; shape line 14 x 4.
- Lance Power stays 1.2 (`Config/Weapons` titansLance `power`).
- Sounds: licensed Pro Sound Effects only, measured into `Config/SoundLevels` (`tests/SoundLevel` gates it).
- Background Blender only; the owner publishes the animation; scripts live only in the repo.
- Keep DESIGN.md, CLAUDE.md, docs/, memory and the Obsidian vault in sync.

## Review Focus

1. A weapon at +10 or Grade S: one box, no arrow, a disabled button with the right words.
2. Costs with three or more parts on a 667 x 375 phone: chips wrap, the button stays in view.
3. A switch or dodge during the 1.2 s charge: no damage, effects stop (`cancelled` checked).
4. Titan's Wrath against a foe beside (not ahead of) you: not hit; the line's far end at 14 studs exactly.
5. Another player's Titan's Wrath: the light version only, no camera move or shake for the watcher.

---

### Task 1: Forge text rules

**Files:** Modify `src/shared/Util/WeaponText.luau`; Test `tests/WeaponText.spec.luau`.

**Interfaces:** Produces `WeaponText.tabLine(tab: "Forge" | "Upgrade" | "Reforge"): string` (the spec's exact
lines) and `WeaponText.costChips(cost, have, cashNow, items): { { icon: string, text: string, enough: boolean } }`
(cash first with icon "Cash" and text "$250"; then items sorted by id, icon = the item's `icon`, text
"2 Wild Ore (you have 11)").

- [ ] Write tests: tabLine returns the three spec lines; costChips for `{ cash = 250, items = { wildOre = 2 } }` with
  11 ore and $100 → `{ Cash, "$250", false }, { WildOre, "2 Wild Ore (you have 11)", true }`; no cash part when cash is
  0; an unknown item id shows the id and icon "".
- [ ] Run `lune run tests/run WeaponText` — FAIL (nil functions).
- [ ] Implement both.
- [ ] Run — PASS; full suite green. Commit "Forge: tab lines and cost chips".

### Task 2: The Forge window relayout

**Files:** Modify `src/client/Controllers/ForgeController.luau` (renderPane, the toolbar for the tab line).

**Interfaces:** Consumes Task 1; `WeaponDetailController.Open(weaponId)`; `UIIcons.Next`, `UIIcons.Cash`, item icons
(a `Config/UIIcons` name, else shown as text).

- [ ] Tab line under the tabs (wrapped, `palette.hint`); header (tappable card → WeaponDetailController.Open, name,
  "Grade S · +0", rarity · element); Now/After boxes with the arrow ImageLabel between (one box at +10 / Grade S /
  Forge tab); "You pay" chips (icon 24 px + text, good/bad colours, wrapping UIListLayout); stats in words removed.
- [ ] VS Code diagnostics clean; Studio: Play, `/item wildOre 20`, open the Forge, screenshot all three tabs on desktop
  and in the Device emulator's landscape phone; check +10 and Grade S cases with `/weapon <id> S 10`.
- [ ] Commit "Forge: the window relaid out (owner's pick A)".

### Task 3: Titan's Lance moveset, hit shape, HUD button

**Files:** Modify `src/shared/Config/Swords.luau`, `src/shared/Config/Weapons.luau`, `src/shared/Config/CombatHud.luau`,
`src/shared/Config/UIIcons.luau`, `src/shared/Util/SkillText.luau` (if it needs the name); Tests
`tests/SwordsConfig.spec.luau`, `tests/SkillText.spec.luau`.

**Interfaces:** Produces `SWORDS.titansLance` (spear cuts/sounds/cues/animations shared by reference; skill
`{ power = 0.9, hitAt = 1.35, length = 2.2, cooldown = 8, shape = { kind = "line", length = 14, width = 4 }, free = { at = 1.35 } }`;
fx `{ slash = "spearStreak", finisher = "skyPierce", skill = "titansWrath" }`; skill cues for its sounds);
`Weapons.ById.titansLance.moveset == "titansLance"`; `CombatHud.SKILLS.titansLance = { icon = "LanceLeaves", name = "Titan's Wrath", tip = ... }`.

- [ ] Tests: the Lance's moveset is titansLance, shares the spear's combo table, its skill's shape is a 14 x 4 line,
  hitAt inside length; Halberd and Trident still use spear; the HUD button names "TITAN'S WRATH"; SwordRules line hits
  a foe ahead at 13 studs and not one beside you.
- [ ] RED, implement, GREEN (the `titansWrath` look is added in Task 5: ledger the order like round 2 Task 1 if a test
  needs it). Upload `LanceLeaves.png` (local http server + Studio `upload_image`) into `UIIcons`.
- [ ] Commit "Titan's Lance: its own moveset and skill shape".

### Task 4: The animation

**Files:** Create `tools/blender/anim_titans_lance.py` (FOLDER "TitansLance", NATURAL ("skill",), on anim_spear's
helpers); Create `assets/blender/Animations/TitansLance/skill.json`, `assets/animations/TitansLance/skill.rbxm`.

- [ ] Key the storyboard: low wide stance, lance drawn back two-handed with a tremble from 0.1 to 1.2 s, the peak at
  1.2, the thrust's "Hit" marker at 1.35 (matches Config), hold, recover to ready by 2.2 s; root stays put.
- [ ] Background Blender export + previews (front, side MP4); show the owner frames; build_kfs; Studio check with
  `/skillfx lance skill` (KeyframeSequence plays in Studio until published).
- [ ] Commit; the owner publishes; the id goes into `SWORDS.titansLance.animations.skill`.

### Task 5: Effects, camera, shakes, sounds

**Files:** Modify `src/shared/Config/SwordSkillFx.luau` (look `titansWrath`, SHAKE entries), `src/client/Util/SwordSkillFx.luau`
(the look and dispatch), `src/shared/Config/Swords.luau` (sounds + cues), `src/shared/Config/SoundLevels.luau`;
Tests `tests/SwordSkillFx.spec.luau`.

**Interfaces:** `titansWrath` beats: charge 0.1, peak 1.2, hit 1.35, length 14, width 4, fissureClose, petals, rocks,
rings, rumble start/peak, thorns; `form = "ahead"`, `cinematic = true`, `burstSound` the fissure's.

- [ ] Tests: the look exists with kind skill; beats ordered charge < peak < hit < fissureClose; beats.hit equals the
  skill's hitAt; beats.length equals the shape's length; every texture key exists.
- [ ] Storyboard frames to the owner first (companion page), then implement: spiralling gold/green light into the tip,
  swirling petals and sparks, creeping cracks, growing rumble (repeated small shakes rising to SHAKE.titansRumble),
  white tip flash + ground ring + lifting rocks at the peak, a lance-shaped beam and gold shockwave at the hit, the
  14-stud fissure with green light and thorns + SHAKE.titansFissure, afterglow closing with petals; checks `cancelled`
  and `live` on every beat; others' light version.
- [ ] Sounds: search PSE (toolbox API category 3), measure in Studio, SoundLevels; cues on the skill.
- [ ] Studio: `/skillfx lance skill` at C and S; a real fight vs boss 3 with the Lance; screenshots of each beat;
  Output clean. Commit.

### Task 6: Balance, docs

- [ ] `WEAPON="titansLance:10:S" lune run tools/balance/bosses 60 1 7` and at 0:C: inside the limits (0.8x well
  ≤ 85%); record in DESIGN.md's balance rows.
- [ ] DESIGN.md (the Forge window, Titan's Wrath, checklist), CLAUDE.md (assets/animations TitansLance, anim file),
  docs/animations.md, docs/weapons.md; memory and the vault. Full suite green; commit.
