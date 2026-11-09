# Thousand Cuts (the Rift Reaper's own skill, with the Grim Reaper) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Rift Reaper its own Legendary skill, Thousand Cuts: a charge that cracks the ground, a giant ghostly
Grim Reaper rising from a rift, waves of slashes, one huge harvest hit round you, and an aftermath.

**Architecture:** A moveset `riftReaper` in `Config/Swords` (the scythe's cuts and moves, its own skill: a 14-stud
spin at the harvest). The player's skill animation keyed in Blender on anim_scythe's helpers. The Reaper a Meshy model
in a new synced folder (`assets/fx-models` → `ReplicatedStorage.FxModels`), moved by client code (no rig). The look
`thousandCuts` in `Config/SwordSkillFx`, drawn by `Util/SwordSkillFx` with a camera moment.

**Tech Stack:** Luau (Roblox, Rojo), Lune tests, Blender (background + MCP for Meshy), Roblox Studio MCP.

**Spec:** docs/superpowers/specs/2026-11-09-weapons-round3-scythes-design.md section 5.4 (approved "go" 2026-11-09;
storyboard https://claude.ai/artifact/PCJiVgqYze5xDJrxcSxzFX "Rift Reaper's own skill").

## Global Constraints

- Skill rules: power 0.9, `cooldown = Swords.SKILL_COOLDOWN`, shape `{ kind = "spin", radius = 14 }`, `free = { at = hitAt }`;
  you never move; nothing makes you unhittable.
- Every tunable number in `src/shared/Config`; pure rules in Roblox-free modules with Lune tests; `--!strict`.
- Licensed sounds only, measured into `Config/SoundLevels`.
- Effects exaggerated (the owner's standing taste); other players' casts the light version.
- New synced asset folders hold no scripts (tests/CreatureAssets gate) and are mapped in all three project files.

## Review Focus

1. A dodge or switch during the charge or the cuts: nothing damaging shows after it (no harvest shake or ring), the
   Reaper leaves. Test: Task 4 (beats: the harvest beat is the skill's hit; the client checks `cancelled` before it).
2. The Reaper model missing (not imported yet): the skill still plays its other effects. Test: Task 4 Studio check.
3. Another player's Thousand Cuts: the light version, no darkening of your screen. Test: Task 4 (look's lite budget).
4. The 14-stud harvest against a boss with adds: every foe in reach hit once. Test: Task 1 (shape) via existing
   SwordRules spin tests.
5. Frame time with several casters. Test: Task 6 Studio check.

---

### Task 1: The riftReaper moveset

**Files:** Modify `src/shared/Config/Swords.luau` (SWORDS.riftReaper: the scythe's combo, sounds, cues and moves; skill
power 0.9, hitAt 1.8, length 2.6, spin 14, free at 1.8; `model = "RiftReaper"` its animation folder; `animations.skill`
"" until published; fx `{ slash = "scytheSweep", finisher = "scytheWhirl", skill = "thousandCuts" }`),
`src/shared/Config/Weapons.luau` (riftReaper `moveset = "riftReaper"`), `src/shared/Config/SwordSkillFx.luau` (a plain
`thousandCuts` look so the look test passes until Task 4). Test: `tests/SwordsConfig.spec.luau`,
`tests/SwordSkillFx.spec.luau` (look count 28).

- [ ] Failing test `["the Rift Reaper: the scythe's cuts and moves, its own skill Thousand Cuts (a 14-stud harvest)"]`;
  run → FAIL; implement; run → PASS; commit.

### Task 2: The Grim Reaper model

**Files:** Create `tools/blender/build_grim_reaper.py` (rig_kit.optimize to about 6,000 triangles and one 1024 colour
map, about 16 studs tall, origin at the bottom centre, one mesh `Reaper`, FBX + preview), `assets/fx-models/` mapped to
`ReplicatedStorage.FxModels` in `default.project.json`, `frontier.project.json`, `dungeon.project.json`; tests/CreatureAssets
(FOLDERS includes it; `GrimReaper.rbxm` holds a Model with a MeshPart once imported). Owner step: import the FBX, save
`assets/fx-models/GrimReaper.rbxm`.

### Task 3: The player's skill animation

**Files:** Create `tools/blender/anim_rift_reaper.py` (`FOLDER = "RiftReaper"`, skill only, on anim_scythe's helpers):
charge with the scythe raised (0-0.7), a low crouch fading (1.0-1.7), the X slash at the Hit (1.8), recover by 2.6.
`run_sword_moves.py -- --sword rift_reaper`; `build_kfs` into `assets/animations/RiftReaper`. Test: SwordsConfig timings
equal the markers. Owner step: publish `SwordAnimations.RiftReaper.skill`, id into `Config/Swords`.

### Task 4: The Thousand Cuts look

**Files:** `src/shared/Config/SwordSkillFx.luau` (`thousandCuts` beats: charge, rift, cuts, waves, hit, close, fade,
radius 14, cracks, reaperHeight, slashes per wave, slabs, rocks, pillar, souls, camera numbers; `SHAKE.thousandCuts` the
biggest; `REAPER` numbers: rise, hover, ghost transparency, scythe scale and offset), `src/client/Util/SwordSkillFx.luau`
(the look; the Reaper from `ReplicatedStorage.FxModels.GrimReaper` cloned, tinted ghostly, risen, spun at the harvest,
dissolved; missing model: the rest still plays), `SwordController`/`MovePreviewController` hooks (rumble, jolt), the
camera moment (`SkillCinematic`, framed on you). Test: `tests/SwordSkillFx.spec.luau` (beats order; hit = skill hitAt;
radius = shape radius; the shake the biggest; the lite budget).

### Task 5: Sounds, the button, the admin entry

**Files:** `Config/Swords` riftReaper sounds and cues (licensed, measured: charge, rumble, cracking, a ghostly choir or
wail as the Reaper rises, slashes, the harvest impact), `Config/SoundLevels`, `Config/CombatHud` SKILLS.riftReaper
(`Skull`, "Thousand Cuts", tip), `Config/AdminPanel` ("Thousand Cuts" → `/skillfx rift skill`). Tests: SkillText,
SoundLevel, SwordSkillFx admin.

### Task 6: Studio pass, balance, docs

`/skillfx rift skill`, a real Prism Hydra or Warden fight with the Rift Reaper, frame time with four casts, the light
version; `tools/balance/bosses` Rift Reaper rows; DESIGN.md 5.11, docs/animations.md, docs/weapons.md, CLAUDE.md
(fx-models folder, build_grim_reaper, anim_rift_reaper), memory, the Obsidian vault.
