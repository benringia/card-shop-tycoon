# Weapons Round 3 Part 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four playable scythes (Forge Scythe in five elements, Widow's Reaper, Storm Reaper, Rift Reaper) with their
own models, grip, wide sweeping moves, the Reaping Cyclone skill, perks, looks and sounds. Part 2 (a later plan) gives
the three boss scythes their own skills.

**Architecture:** Scythes are a third `Config/Swords` moveset (`scythe`, shared by all four) built like round 2's spear
moveset, plus four `Config/Weapons` kinds that turn `ready`; grips get a `scythe` entry. Every cut is an existing
reach/arc cut (180 degrees ahead, or 360 for the finisher), checked by `SwordRules` on the server as today. Two new
perk kinds (`chain`, `execute`) live in `BattleSim.swordPerk`; Venom reuses `burn`.

**Tech Stack:** Luau (Rojo, `--!strict`), Lune tests (`lune run tests/run`), Blender 5.2 background scripts
(`weapon_kit.py`, `anim_kit.py`), Meshy through the Blender MCP, Roblox Studio MCP for checks and uploads.

**Spec:** `docs/superpowers/specs/2026-11-09-weapons-round3-scythes-design.md` (approved 2026-11-09). Round 2's spec and
plan (`2026-11-07-weapons-round2-design.md`, `docs/superpowers/plans/2026-11-07-weapons-round2.md`) are the pattern every
task below follows; where this plan says "as the spear", do what round 2 did for the spear.

## Global Constraints

- Branch `weapons-round3` (the spec is commit `9ee2936`).
- Server authoritative: hits, equips and skills validated on the server; remotes rate-limited; no client numbers trusted.
- Tunable numbers in `src/shared/Config`; shared rules in `src/shared/Util` (Roblox-free, Lune-tested; no sibling
  requires in pure modules).
- UI text plain ASCII; tap targets at least 48 px.
- Sounds: Pro Sound Effects (Roblox-licensed) only, measured into `Config/SoundLevels`, kept quiet.
- Effects exaggerated (memory fx-exaggerate) but the boss's ring warnings stay readable; others see the lite version.
- Blender background only, except the MCP Blender for Meshy and the `_raw.glb` export; `.blend` saved without `_Src`,
  orphans purged, key fields empty (print lengths only). Never print the Meshy API key.
- Meshy: about 30 credits a model, four models; read the balance (number only) before the first and tell the owner.
- Studio MCP: inspect freely; ask before changing the place; scripts only in the repo.
- Scythe lengths (studs): forgeScythe 8, widowsReaper 8.3, stormReaper 8.6, riftReaper 9. Grip a third of the length up
  from the butt. On the back at scale 1.
- Scythe moves: Reap reach 10, arc 180; Back Sweep reach 10, arc 180 (ahead: its look wraps behind you); Whirlwind reach
  10, arc 360; each cut about a third slower than the sword's; the combo's damage a second equals the Steel Sword's
  (`SwordRules.comboPowerPerSecond`). No cut reaches past 12 studs.
- Reaping Cyclone: `shape = { kind = "spin", radius = 9 }`, power 0.9, `cooldown = SKILL_COOLDOWN` (12), free after the
  hit, no movement.
- Perks: widowsReaper `{ kind = "burn", share = 0.025, seconds = 3 }`; stormReaper `{ kind = "chain", every = 4, share =
  0.4, spread = 0.3 }`; riftReaper `{ kind = "execute", below = 0.3, share = 0.3 }`; Forge Scythe none.
- `TIER_BOSS`: forgeScythe meadowWarden, widowsReaper emberColossus, stormReaper frostTyrant, riftReaper prismHydra.

## Review Focus

1. Reap on a foe exactly at the threshold: `execute` adds its 30% only while the foe's HP share is under `below`, never
   on a fainted foe, and counts against bosses' phase gates like any hit. Test: Task 2 step 1.
2. Chain Lightning with one foe: the target's +40% still lands every 4th hit; arcs never reach a fainted foe or your own
   side. Test: Task 2 step 1.
3. Venom from many quick hits: refreshed, not stacked (the `burn` rules), scaled x1.2 at Grade S. Test: Task 2 step 1.
4. The finisher must hit a foe straight behind you; Reap and Back Sweep must not. Test: Task 1 step 1.
5. Five Forge Scythes owned at once: one Forge Scythe row with the element picker in the Forge window, five ordered
   entries in the quick switch. Test: Task 2 step 1 (order) and Task 5 Studio check.

---

### Task 1: The scythe moveset data and grip

**Files:**
- Modify: `src/shared/Config/Swords.luau` (`SWORDS.scythe`; `GRIPS.scythe`)
- Modify: `tools/blender/anim_kit.py` (`hand_grip("scythe")` reads the same numbers as `GRIPS.scythe.hand`)
- Test: `tests/SwordsConfig.spec.luau`, `tests/SwordRules.spec.luau`

**Interfaces:**
- Produces: `Swords.SWORDS.scythe` (`name = "Scythe"`, `model = "Scythe"`: its animation folder
  `ReplicatedStorage.SwordAnimations.Scythe`; `combo` = Reap, Back Sweep, Whirlwind as in Global Constraints;
  `skill` = Reaping Cyclone; `animations` = the starter's table cloned with every move `""` until published; `sounds` /
  `cues` = the spear's until Task 6; `fx = { slash = "scytheSweep", finisher = "scytheWhirl", skill = "reapingCyclone" }`).
- Produces: `Swords.GRIPS.scythe = { hand = { y = -0.18, angleX = -90, twist = 0 }, back = { x = 0, y = -0.4, z = 0.7,
  angleZ = -40 }, backScale = 1 }` (the spear's, calibrated in Task 5).

- [ ] **Step 1: Write the failing tests**

In `tests/SwordsConfig.spec.luau`:
```lua
["the scythe moveset: reap, back sweep, whirlwind and Reaping Cyclone at the sword's damage a second"] = function()
	local scythe = Swords.SWORDS.scythe
	expect.equal(#scythe.combo, 3)
	expect.equal(scythe.combo[1].reach, 10); expect.equal(scythe.combo[1].arc, 180)
	expect.equal(scythe.combo[2].reach, 10); expect.equal(scythe.combo[2].arc, 180)
	expect.equal(scythe.combo[3].reach, 10); expect.equal(scythe.combo[3].arc, 360)
	expect.near(SwordRules.comboPowerPerSecond(scythe.combo), SwordRules.comboPowerPerSecond(Swords.SWORDS.starterSword.combo), 1e-3)
	for index, cut in scythe.combo do
		local sword = Swords.SWORDS.starterSword.combo[index]
		expect.equal(cut.length >= sword.length * 1.25, true, `cut {index} a third slower than the sword's`)
	end
	expect.equal(scythe.skill.power, 0.9); expect.equal(scythe.skill.cooldown, Swords.SKILL_COOLDOWN)
	expect.equal(scythe.skill.shape.kind, "spin"); expect.equal(scythe.skill.shape.radius, 9)
	expect.equal(scythe.model, "Scythe")
	expect.equal(Swords.GRIPS.scythe.backScale, 1)
end,
["a scythe's reach never makes a spot a boss's swipe can't reach"] = function()
	-- the spear's test, over SWORDS.scythe.combo (longest reach 10)
end,
```
In `tests/SwordRules.spec.luau`:
```lua
["the scythe's sweeps hit in front, its whirlwind all round"] = function()
	local scythe = Swords.SWORDS.scythe -- require Config/Swords in this spec if it doesn't yet
	local behind = { id = "b", x = 0, z = 6, radius = 1 }
	local ahead = { id = "a", x = 0, z = -9, radius = 1 }
	expect.equal(SwordRules.cutReaches(scythe.combo[1], 0, 0, 0, -1, ahead), true)
	expect.equal(SwordRules.cutReaches(scythe.combo[1], 0, 0, 0, -1, behind), false, "Reap: not behind")
	expect.equal(SwordRules.cutReaches(scythe.combo[2], 0, 0, 0, -1, behind), false, "Back Sweep's damage lands in front")
	expect.equal(SwordRules.cutReaches(scythe.combo[3], 0, 0, 0, -1, behind), true, "Whirlwind: all round")
end,
```

- [ ] **Step 2: Run** `lune run tests/run` → Expected: FAIL on the new tests only (`scythe` nil).

- [ ] **Step 3: Implement** `SWORDS.scythe` after `SWORDS.spear`: starting timings `hitAt` 0.30 / 0.28 / 0.95,
  `cancelAt` 0.46 / 0.43, `length` 0.80 / 0.78 / 1.65 (Task 4 replaces them with the animations' markers), powers scaled
  so the DPS test holds, small lunges like the sword's; the skill `hitAt` 0.9, `length` 1.5, `free = { at = 0.9 }`.
  `GRIPS.scythe` and `anim_kit.hand_grip("scythe")` per Interfaces (a comment pointing each at the other).

- [ ] **Step 4: Run** `lune run tests/run` → all pass.

- [ ] **Step 5: Commit** `git commit -m "Scythes: the scythe moveset and grip"`

### Task 2: Scythe perks and catalogue entries

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`swordPerk`: kinds `chain`, `execute`)
- Modify: `src/shared/Config/Weapons.luau` (`forgeScythe` becomes `forgeScythe_<Element>` x5 like the spear; the three
  boss scythes gain `moveset = "scythe"`, `model`, `perk`; all stay `ready = false`; `TIER_BOSS`)
- Modify: `src/shared/Util/WeaponRules.luau` (`Perk` type doc), `src/shared/Util/WeaponText.luau` (`perkWords`)
- Modify: `src/client/Controllers/BattleController.luau` (event `swordChain`: a Volt bolt from the target to each foe it
  arcs to, via `Util/HitFx`; event `swordExecute`: a Shade burst on the target)
- Test: `tests/BattleSim.spec.luau`, `tests/WeaponText.spec.luau`, `tests/WeaponRules.spec.luau`,
  `tests/WeaponsConfig.spec.luau`, `tests/WeaponSwitch.spec.luau`

**Interfaces:**
- Produces: perk kind `"chain"` (every `every`-th hit by this owner: an extra hit on the target of `share` x that hit,
  and one of `spread` x that hit on every other live foe on the target's side; event `{ type = "swordChain", from, to,
  arcs = { id } }`); `"execute"` (a hit on a foe whose HP share is under `below` deals `1 + share` times; event
  `{ type = "swordExecute", from, to }`).
- Produces: `Weapons.ById["forgeScythe_<Element>"]` (`family = "scythe"`, `moveset = "scythe"`, `model =
  "ForgeScythe_<Element>"`); `widowsReaper` (`model = "WidowsReaper"`), `stormReaper` (`"StormReaper"`), `riftReaper`
  (`"RiftReaper"`), each `moveset = "scythe"` and its Global Constraints perk; all `ready = false` until Task 5.

- [ ] **Step 1: Write the failing tests** (`tests/BattleSim.spec.luau`, with the existing perk tests' helpers):
```lua
["Storm Reaper's every 4th hit strikes the target for 40% more, and arcs to the other foes for 30%"] = function()
	-- a boss with one add: hits 1-3 plain; hit 4 gives one swordChain event, the target an extra 40% of the hit,
	-- the add 30%; a fainted add gets nothing; with no add the 40% still lands
end,
["Rift Reaper's hits deal 30% more to a foe under 30% of its HP, and only then"] = function()
	-- target at 31% HP: plain damage; at 29%: 1.3x and a swordExecute event; a fainted target: no damage, no event
end,
["Widow's Reaper's venom is the burn: refreshed, never stacked"] = function()
	-- two hits 0.5 s apart: one burn on the target, its end refreshed to the second hit + 3 s, its share 0.025
end,
```
`tests/WeaponText.spec.luau`: `perkWords` gives `"Every 4th hit strikes for 40% more and arcs to other foes for 30%"`,
`"Hits deal 30% more to foes under 30% HP"`, and the burn's wording for Venom with 2.5%.
`tests/WeaponRules.spec.luau`: Grade S scales `chain.share` and `spread`, `execute.share` and `burn.share` by `PERK_S`.
`tests/WeaponsConfig.spec.luau`: five `forgeScythe_<Element>` entries (family scythe, moveset scythe) and no
`forgeScythe`; the three boss scythes' models, perks and `TIER_BOSS` entries per Global Constraints.
`tests/WeaponSwitch.spec.luau`: with every scythe owned, the switch lists the five Forge Scythes together after the
spears, then the boss scythes by rarity.

- [ ] **Step 2: Run** `lune run tests/run` → Expected: FAIL on the new tests only.

- [ ] **Step 3: Implement** the two kinds in `swordPerk` (the extra hits through `hit(...)` with meter share 0, like
  `erupt`), the catalogue entries, `perkWords` cases, the two client events.

- [ ] **Step 4: Run** `lune run tests/run` → all pass.

- [ ] **Step 5: Commit** `git commit -m "Scythes: perks (Venom, Chain Lightning, Reap) and catalogue entries"`

### Task 3: The scythe models

**Files:**
- Modify: `tools/blender/weapon_kit.py` (`build_scythe(name, length, grip_share=1/3)` → parts `Head`, `Shaft`; the
  head found as the spear's: the lowest z in the top 45% where the smoothed width passes 1.6x the shaft's median width)
- Create: `tools/blender/build_weapon_forgeScythe.py`, `build_weapon_widowsReaper.py`, `build_weapon_stormReaper.py`,
  `build_weapon_riftReaper.py`
- Modify: `src/shared/Config/WeaponLooks.luau` (`FORGE_COLOR_MAPS.ForgeScythe`)
- Create (owner step): `assets/weapons/WidowsReaper.rbxm`, `StormReaper.rbxm`, `RiftReaper.rbxm`,
  `assets/weapons-source/ForgeScythe.rbxm`; then `assets/weapons/ForgeScythe_<Element>.rbxm` x5
- Test: `tests/CreatureAssets.spec.luau` (weapon models: no scripts, a `Shaft` or `Grip` PrimaryPart; ready scythes'
  models exist)

**Interfaces:**
- Consumes: `assets/blender/<Name>/concept_B.png`.
- Produces: models in `ReplicatedStorage.WeaponModels` named per Task 2's `model` fields, origin at the grip, head along
  +Y, the blade curving out to one side, parts `Head` and `Shaft`.

- [ ] **Step 1: Meshy** (MCP Blender): read the credit balance (number only) and tell the owner; then
  `generate_3d(image=<concept_B.png>, provider="meshy", name="<Name>_Src")` for each of the four, export
  `assets/blender/<Name>/<Name>_raw.glb` (out of git). Character-only prompt, right first time; ask before any retry.
- [ ] **Step 2: Write the failing test** (`CreatureAssets`: every ready scythe's model present, `Shaft` PrimaryPart),
  run → passes today (no scythe ready yet); it gates Task 5.
- [ ] **Step 3: Implement** `build_scythe` (as `build_spear`: optimize to about 4,000 triangles and one 1024 colour map,
  scale to the length, origin at the grip, split into `Head` / `Shaft`); the Forge Scythe's socket gems and butt
  recoloured five ways (`weapon_kit.recolor`, never the blade).
- [ ] **Step 4: Run** each build in a background Blender; look at the previews; key fields empty.
- [ ] **Step 5: Owner step**: show the four previews; upload the five colour maps into `FORGE_COLOR_MAPS.ForgeScythe`;
  the owner imports each FBX (Rig Type None) and saves to the paths above; then `lune run tools/weapons/finish_sword
  <path>` for each and `lune run tools/weapons/forge_variants ForgeScythe`.
- [ ] **Step 6: Run** `lune run tests/run` → all pass. **Commit** scripts, tools, configs and `.rbxm` files (not the raw
  GLBs or concepts): `git commit -m "Scythes: models (weapon_kit scythe cleanup, Forge Scythe in five elements)"`

### Task 4: The scythe animations

**Files:**
- Modify: `tools/blender/anim_kit.py` (a scythe prop: `build(prop="scythe", length=8.6)`, Shaft + Head at
  `hand_grip("scythe")`)
- Create: `tools/blender/anim_scythe.py` (moves `ready`, `draw`, `sheath`, `run`, `cut1` Reap, `cut2` Back Sweep,
  `cut3` Whirlwind, `skill` Reaping Cyclone; `Hit` marker on every attack, the skill's on its third spin)
- Modify: `tools/blender/run_sword_moves.py` (`--sword scythe` → `assets/animations/Scythe`)
- Create: `assets/animations/Scythe/<move>.rbxm` (via `lune run tools/anim/build_kfs`)
- Modify: `src/shared/Config/Swords.luau` (`SWORDS.scythe` timings from the markers; ids once published)
- Test: `tests/SwordsConfig.spec.luau` (the scythe's timings are its animations' markers, as the spear's)

- [ ] **Step 1: Key the moves** per the storyboard (spec 5.2 and the page's "The scythe moves"): ready = upright at the
  right side, blade over the head curving back; every attack brings both hands on with a heavy wind-up; Reap sweeps
  right to left across the front; Back Sweep turns you round so the blade carves behind and comes through the front at
  its `Hit`; Whirlwind spins twice with the scythe held out; Reaping Cyclone spins three times on the spot. Export
  previews (`run_sword_moves.py -- --sword scythe --preview <scratch dir>`; stills without ffmpeg: the module's
  `make(name, json_dir, render_dir)` and a PIL tile) and show them to the owner.
- [ ] **Step 2: Owner step**: the owner approves the previews (fix and re-show anything flagged).
- [ ] **Step 3: Build** the KFS; note each move's marker times and lengths.
- [ ] **Step 4: Write the failing test** `["the scythe's timings are its animations' markers"]` with step 3's numbers.
- [ ] **Step 5: Run** → FAIL; set the timings, re-scale the powers so the DPS test holds; run → all pass.
- [ ] **Step 6: Owner step**: the owner publishes each KFS (name the exact `SwordAnimations.Scythe.<move>` paths) and
  sends the ids; they go into `SWORDS.scythe.animations`. **Commit** `git commit -m "Scythes: the scythe moves"`

### Task 5: Scythes in the game: ready, looks, glow, portraits, grips

**Files:**
- Modify: `src/shared/Config/Weapons.luau` (`ready = true` for the four kinds)
- Modify: `src/shared/Config/WeaponLooks.luau` (`forgeScythe_<Element>` via `element(...)` with portraits;
  `widowsReaper = element("Shade", ...)`, `stormReaper = element("Volt", ...)`, `riftReaper` own colours or
  `element("Shade", ...)`; `GLOW_MAPS.ForgeScythe/WidowsReaper/StormReaper/RiftReaper`)
- Modify: `tools/textures/make_glow_maps.py` (glowing regions: the Forge Scythe's gems; the Widow's eyes and lilac edge;
  the Storm's lightning crack, edge and gem; the Rift's violet cracks, eye and runes)
- Modify: `src/shared/Config/Swords.luau` (`GRIPS.scythe` calibrated)
- Create: `assets/ui/weapon-portraits/<Name>.png` (not synced)
- Test: `tests/WeaponsConfig.spec.luau` (the existing "every ready weapon has a portrait and a glow map" test now covers
  the scythes)

- [ ] **Step 1: Set** the four kinds `ready`; run `lune run tests/run` → FAIL (no looks yet).
- [ ] **Step 2: Glow maps** (`make_glow_maps.py` → upload → ids → `lune run tools/weapons/add_glow_maps`); **portraits**
  (rendered on magenta in Studio, cut with `tools/ui-art/cut_product_picture.py`, uploaded, ids in `WeaponLooks`).
- [ ] **Step 3: Grips in Studio** (`/weapon <id>`): in hand, the butt by the right foot and the blade over the head; on
  the back, the lowest point above the ground (> 0.2 studs on the R15 test avatar) and the highest at most 3 studs over
  the head, for the 9-stud Rift Reaper; screenshots of each scythe in hand and on the back.
- [ ] **Step 4: Run** `lune run tests/run` → all pass. Studio: the Forge window's Forge Scythe row with its element
  picker, the Armory's scythe cards, the quick switch through all scythes. **Commit** `git commit -m "Scythes: ready,
  looks, glow maps, portraits, grips"`

### Task 6: Scythe effects, sounds and the skill button

**Files:**
- Modify: `src/shared/Config/SwordSkillFx.luau` (looks `scytheSweep` kind slash, `scytheWhirl` kind finisher,
  `reapingCyclone` kind skill with beats; `PREVIEW` names `scythe`, `widow`, `storm`, `rift` → `forgeScythe_Shade`,
  `widowsReaper`, `stormReaper`, `riftReaper`)
- Modify: `src/client/Util/SwordSkillFx.luau` (the three looks: each sweep a huge crescent trail in the scythe's colours
  with pack streaks, Back Sweep's wrapping round behind; the Whirlwind's double ring and shake; Reaping Cyclone's three
  rings of element crescents flying outward, the third the hit)
- Modify: `src/shared/Config/Swords.luau` (`SWORDS.scythe.sounds` own keys and `cues`; `SOUND_VOLUMES`)
- Modify: `src/shared/Config/SoundLevels.luau` (measured)
- Modify: `src/shared/Config/CombatHud.luau` (`SKILLS.scythe = { icon = <spare glyph>, name = "Reaping Cyclone", tip =
  "Spin three times, throwing rings of blades that hit every foe round you." }`), `src/shared/Config/UIIcons.luau` if a
  spare needs an id
- Modify: `src/shared/Config/AdminPanel.luau` (Sword skills: "Reaping Cyclone" → `/skillfx scythe skill`)
- Test: `tests/SwordSkillFx.spec.luau`, `tests/SoundLevel.spec.luau`, `tests/SwordsConfig.spec.luau`, `tests/SkillText.spec.luau`

- [ ] **Step 1: Write the failing tests**: the three looks exist with their kinds and textures from the existing sets
  (`reapingCyclone.beats.radius == SWORDS.scythe.skill.shape.radius`, its hit beat equals the skill's `hitAt`); `PREVIEW`
  has the four names; every scythe cue key has a sound; `SkillText.swordSkill(CombatHud, "scythe")` gives "Reaping
  Cyclone"; the admin panel has the button.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** the looks, sounds (toolbox API, category 3, creator 7462895450; measured with
  `tools/audio/measure_loudness.luau`), the skill button (a spare glyph from the existing sheets, my pick, shown to the
  owner with its alternatives), the admin button.
- [ ] **Step 4: Run** `lune run tests/run` → all pass. **Studio check**: `/skillfx scythe|widow|storm|rift
  cut1|cut2|cut3|skill`, held-camera stills of each moment (live effect, not frozen), a real boss fight with a scythe
  (summon a creature first), frame time with four casting at once, the lite version from a second player.
- [ ] **Step 5: Commit** `git commit -m "Scythes: effects, sounds and the Reaping Cyclone button"`

### Task 7: Balance, docs and the final pass

**Files:**
- Modify: `src/shared/Config/Weapons.luau` (perk numbers, and a `power` override only if a row needs it)
- Modify: `DESIGN.md` (5.11 weapons: scythes, the moves, perks, files; balance rows), `CLAUDE.md` (scythe build scripts,
  `anim_scythe.py`, `--sword scythe`, `forge_variants ForgeScythe`), `docs/weapons.md`, `docs/animations.md`, the
  Obsidian vault, memory `weapon-families.md`

- [ ] **Step 1: Balance**: `WEAPON="<id>:10:S" lune run tools/balance/bosses 400 1 <tier boss>` and `:0:C` for each
  scythe and its `TIER_BOSS`, plus the Rift Devourer for the Storm Reaper's arcs; every row inside round 1's limits
  (0.8x party fighting well at most 85%; +10 Grade S at most halves a 1x fight). Adjust perk numbers (and the Rift
  Reaper's base Power only if needed); record the rows in DESIGN.md.
- [ ] **Step 2: Docs** as listed; `rojo build` builds; `rojo sourcemap default.project.json -o sourcemap.json`.
- [ ] **Step 3: Run** `lune run tests/run` → all pass. **Commit** `git commit -m "Weapons round 3 part 1: balance and docs"`
- [ ] **Step 4: Final Studio pass** and tell the owner exactly what to judge.
