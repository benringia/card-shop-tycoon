# Halberd and Trident Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Magma Halberd's own skill, Magma Cleave (one big flaming swipe), and the Tidal Trident's, Torrent Strike
(the trident slammed into the ground, torrents of water bursting up round you), in place of Piercing Rush.

**Architecture:** Two new movesets in `Config/Swords` built like `titansLance` (the spear's cuts shared, own skill);
a new `arc` skill shape in `SwordRules` for the Halberd, the existing `spin` for the Trident; their looks as data in
`Config/SwordSkillFx` and drawn by the client's `Util/SwordSkillFx`; animations keyed in Blender on the spear helpers.

**Tech Stack:** Luau (Rojo), Lune tests, Blender 5.2 background runs (`run_sword_moves.py`), Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-09-halberd-and-trident-skills-design.md` (storyboard:
https://claude.ai/artifact/HkLTNkje58RoWU4pc4Q3V6)

## Global Constraints

- Both skills: power 0.9, cooldown 8, a dodge before the hit cancels it, the switch lock applies, free from the hit,
  no `dash` / lunge (neither moves you); facing as the server already takes it for every skill (`skillHits`).
- Magma Cleave: shape `{ kind = "arc", radius = 11, angle = 180 }`, hitAt 0.6, length 1.2, `free = { at = 0.6 }`.
- Torrent Strike: shape `{ kind = "spin", radius = 12 }`, slam 0.55, hitAt 0.75, second wave 1.0 (show only), held to
  about 1.5, length 1.9, `free = { at = 0.75 }`; damage once, on the first wave.
- HUD: `magmaHalberd` "Magma Cleave", icon `HalberdFlames`; `tidalTrident` "Torrent Strike", icon `TridentWave`.
- Weapons' Power and perks unchanged (Eruption, Chill); the Forge Spear keeps Piercing Rush (`moveset = "spear"`).
- Sounds: licensed Pro Sound Effects only, measured into `Config/SoundLevels` (`tests/SoundLevel` gates it).
- Effects exaggerated; others see the light version within `OTHERS` range; only your own gets shakes and the camera.
- Background Blender only; the owner publishes both animations (give the exact `SwordAnimations.<Folder>.skill` path).
- Text plain ASCII plus `·` and emoji. Keep DESIGN.md, CLAUDE.md, docs/, memory and the vault in sync.

## Review Focus

1. A foe at 90 degrees to your side, 10 studs out: Magma Cleave hits it; one at 135 degrees (behind-side): not hit.
2. A big boss standing on you (its centre within its own radius): both skills hit it.
3. A boss of radius 8 whose centre is 19 studs away: Torrent Strike hits it (edge 11 < 12); at 21 studs: not hit.
4. A dodge or switch between the Trident's slam (0.55) and the torrents (0.75): no damage and no torrents drawn
   (`cancelled` checked on every beat after the slam).
5. Another player's skill: the light version, no camera move or shake for the watcher.

---

### Task 1: Movesets, the arc shape, the HUD buttons

**Files:** Modify `src/shared/Util/SwordRules.luau`, `src/shared/Config/Swords.luau`, `src/shared/Config/Weapons.luau`,
`src/shared/Config/CombatHud.luau`, `src/shared/Config/SwordSkillFx.luau` (look data only), `src/shared/Config/UIIcons.luau`;
Tests `tests/SwordRules.spec.luau`, `tests/SwordsConfig.spec.luau`, `tests/SkillText.spec.luau`.

**Interfaces:** Produces `SkillShape.kind` gains `"arc"` (`radius`, `angle` in degrees, centred on your facing; both
`SwordRules.SkillShape` and `Config/Swords` `SkillShape`), decided in `SwordRules.skillHits` with
`SwordRules.inReach(px, pz, dirX, dirZ, t.x, t.z, t.radius, shape.radius, shape.angle)`; `SWORDS.magmaHalberd` and
`SWORDS.tidalTrident` (name, model, the spear's combo/cues/animations/sounds cloned or shared as `titansLance` does;
skill per Global Constraints; `fx = { slash = "spearStreak", finisher = "skyPierce", skill = "magmaCleave" | "torrentStrike" }`);
`Weapons.ById.magmaHalberd.moveset == "magmaHalberd"`, `tidalTrident.moveset == "tidalTrident"`; `CombatHud.SKILLS`
entries (exact tips: "One huge flaming swipe hits every foe in front of you." and "Slam the trident into the ground:
torrents of water burst up round you, hitting every foe near you."); `SwordSkillFx.LOOKS.magmaCleave` /
`torrentStrike` (kind "skill", form "around", beats below; Torrent Strike `cinematic = true`).

Look beats (data; the client draws them in Tasks 3-4): magmaCleave `{ windup = 0.1, hit = 0.6, radius = 11, angle = 180,
crescent = 2.2, embers = 40, smoke = 0.8 }`; torrentStrike `{ raise = 0.05, slam = 0.55, hit = 0.75, second = 1.0,
fall = 1.5, radius = 12, inner = 6, columns = 8, columnHeight = 9, outerHeight = 11, cracks = 6, camAt = 0.75,
camHold = 0.7, camFocus = 0.5, camLookUp = 2 }`.

- [ ] Tests (SwordRules): arc 11 / 180 hits a foe ahead at 10 studs, beside you at 90 degrees and 10 studs, one standing
  on you; misses one at 135 degrees and one ahead at 12.5 studs (edge past 11); spin 12 hits a radius-8 foe at 19 and
  misses it at 21.
- [ ] Tests (SwordsConfig): the Halberd's and Trident's movesets are their own, share the spear's `combo` table, have
  the Global Constraints' skill numbers (hitAt < length, cooldown 8, power 0.9, no `dash`), and name their looks; each
  look exists with kind "skill" and `beats.hit` equal to its skill's `hitAt`; the Forge Spear still uses `spear`.
- [ ] Tests (SkillText): `SkillText.swordSkill(CombatHud, "magmaHalberd").name == "Magma Cleave"`, icon
  `HalberdFlames`; the Trident's "Torrent Strike", `TridentWave`.
- [ ] `lune run tests/run` — the new tests FAIL (unknown kind, nil movesets).
- [ ] Implement. Upload `assets/ui/icons/HalberdFlames.png` and `TridentWave.png` (local http server + Studio
  `upload_image`, as LanceLeaves was) into `Config/UIIcons`.
- [ ] `lune run tests/run` — all PASS; `rojo build` OK. Commit "Halberd and Trident: own movesets, the arc shape".

### Task 2: The animations

**Files:** Create `tools/blender/anim_magma_halberd.py` (FOLDER "MagmaHalberd") and `tools/blender/anim_tidal_trident.py`
(FOLDER "TidalTrident"), both `NATURAL = ("skill",)` on `anim_spear`'s helpers like `anim_titans_lance.py`; outputs
`assets/blender/Animations/<Folder>/skill.json`, `assets/animations/<Folder>/skill.rbxm`.

- [ ] Magma Cleave keys: into both hands, pulled back over the right shoulder (0.1-0.5 s, the torso coiled right), one
  huge horizontal swing right to left with the "Hit" marker at 0.6, the blade ending low on the left, back to ready by
  1.2. The root stays put.
- [ ] Torrent Strike keys: raised overhead in both hands, prongs down (to 0.45), driven down into the ground ahead at
  0.55 (a "Slam" marker), crouched leaning on the stuck shaft with the "Hit" marker at 0.75, held to about 1.5, pulled
  free and back to ready by 1.9. The root stays put; the prongs end under the ground line.
- [ ] Background Blender: `run_sword_moves.py -- --sword magma_halberd --preview <dir>` and `--sword tidal_trident`;
  show the owner preview frames; `lune run tools/anim/build_kfs` for each folder; Studio: `/skillfx halberd skill` and
  `/skillfx trident skill` play the KeyframeSequences.
- [ ] Commit. Ask the owner to publish `ReplicatedStorage.SwordAnimations.MagmaHalberd.skill` and
  `...TidalTrident.skill` (select each via Selection); their ids go into the movesets' `animations.skill`.

### Task 3: Magma Cleave's effects and sounds

**Files:** Modify `src/client/Util/SwordSkillFx.luau` (a `magmaCleave(root, spec, colors, scale, hooks)` look and its
dispatch in `SwordSkillFx.skill`), `src/shared/Config/SwordSkillFx.luau` (`SHAKE.magmaCleave`), `src/shared/Config/Swords.luau`
(sounds and skill cues), `src/shared/Config/SoundLevels.luau`; Test `tests/SwordSkillFx.spec.luau`.

- [ ] Tests: `SHAKE.magmaCleave` exists and sits between `finisher` and `titansWrath`; every texture key of the look
  exists; the skill's cue keys are sounds of the moveset.
- [ ] RED, then implement the storyboard: embers gathering on the blade and the blade's glow brightening from
  `windup`; at `hit` a big fire crescent `radius` studs round your front over `angle` degrees and `crescent` studs
  thick (orange-red, white-hot core, `embers` flames and embers shedding along it), a thinner flame slash a beat
  behind, `SHAKE.magmaCleave` on your own; smoke and falling embers over `smoke` seconds. Foes hit already get the pack
  hit in the weapon's colour and element from `BattleController.swordHit` (every "Skill" hit; nothing to add).
  `cancelled(hooks)` on every beat; the light version for others (`hooks.lite`).
- [ ] Sounds: a heavy whoosh at the swing and a fire burst at the hit (search Pro Sound Effects, measure in Studio,
  `Config/SoundLevels`); cues on the skill.
- [ ] GREEN; Studio: `/skillfx halberd skill` at grades C and S, a real fight vs the Ember Colossus (`/boss 3 fight`)
  with the Halberd; screenshots of each beat; Output clean. Commit "Magma Cleave: effects and sounds".

### Task 4: Torrent Strike's effects, camera and sounds

**Files:** Modify `src/client/Util/SwordSkillFx.luau` (`torrentStrike(root, spec, colors, scale, hooks)` and its
dispatch), `src/shared/Config/SwordSkillFx.luau` (`SHAKE.torrentSlam`, `SHAKE.torrentStrike`), `src/shared/Config/Swords.luau`
(sounds, cues), `src/shared/Config/SoundLevels.luau`; Test `tests/SwordSkillFx.spec.luau`.

- [ ] Tests: `SHAKE.torrentSlam < SHAKE.torrentStrike <= SHAKE.titansWrath`; beats ordered raise < slam < hit < second
  < fall; `beats.radius` equals the shape's radius; `inner < radius`; the look has `cinematic = true`.
- [ ] RED, then implement the storyboard: water swirling round the prongs from `raise`; at `slam` a splash ring and
  `cracks` glowing blue cracks spreading from the prongs (`SHAKE.torrentSlam`); at `hit` `columns` columns burst up on
  a ring `inner` studs round you (`columnHeight` tall; spray, falling droplets, mist, a splash ring at each foot) and a
  big column under every foe hit (through the skill's `strike` / `burst` hooks), `SHAKE.torrentStrike` and the camera
  pull-back (`SkillCinematic.forLook` with `camAt`, `camHold`, `camFocus`, `camLookUp`); at `second` a wider ring at
  `radius` studs (`outerHeight` tall), show only; from `fall` the columns fall back as rain and mist. `cancelled(hooks)`
  on every beat (Review Focus 4); the light version for others, no camera or shake (Review Focus 5).
- [ ] Sounds: the slam, a splash, the torrents surging (Water Surge 3, `rbxassetid://9120607089`, is already licensed
  in AttackFx), rain falling back; measured, cues on the skill.
- [ ] GREEN; Studio: `/skillfx trident skill` at C and S, a real fight vs the Frost Tyrant (`/boss 4 fight`, in the
  Frontier window) or the Ember Colossus with the Trident; a dodge between 0.55 and 0.75; screenshots of each beat;
  Output clean. Commit "Torrent Strike: effects, camera and sounds".

### Task 5: Balance, docs

- [ ] `WEAPON="magmaHalberd:10:S" lune run tools/balance/bosses 60 1 3` and `magmaHalberd:0:C`;
  `WEAPON="tidalTrident:10:S" lune run tools/balance/bosses 60 1 4` and `tidalTrident:0:C`: inside the limits (0.8x
  well at most 85%); add both rows to DESIGN.md's balance table.
- [ ] DESIGN.md 5.11 (both skills, the `arc` shape, the checklist line for round 2.5 part 2), CLAUDE.md (the two
  anim files, `--sword magma_halberd` / `tidal_trident`, folders in `assets/animations`), `docs/animations.md`,
  `docs/weapons.md`; memory and the vault. Full suite green; commit.
