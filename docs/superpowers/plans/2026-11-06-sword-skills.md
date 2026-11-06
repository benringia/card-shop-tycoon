# Sword Skills and Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each round 1 sword (Forge Sword, Verdant Blade, Sunforged Blade, Prism Blade) keeps the basic cut animations but gets its own slash and finisher effects and its own skill (animation, hit shape, effect, sounds).

**Architecture:** One pure rule (`SwordRules.skillHits`) decides who a skill hits, when and with what share, for the server (damage) and the client (predicted bursts). `Config/Swords` gains one moveset per sword sharing the starter's combo and cut animations; `Config/SwordSkillFx` holds the effects' numbers and client `Util/SwordSkillFx` draws them, for your own swings and (through a new broadcast) other players'. Skill animations come from Blender like the sword-moves round.

**Tech Stack:** Roblox Luau (Rojo), Lune tests (`lune run tests/run`), Blender 5.2 background builds (`tools/blender/anim_kit.py`), `lune run tools/anim/build_kfs`, Studio MCP checks.

**Spec:** `docs/superpowers/specs/2026-11-06-sword-skills-design.md`

## Global Constraints

- Basic attacks: the three combo cuts keep today's animations, damage and timing (`Swords.SWORDS.starterSword.combo`).
- Every new skill deals today's skill damage in total (power 0.9 x the weapon's Power) on today's cooldown (8 s).
- Shapes: Elemental Spin every foe within 9 studs of you; Thornline a line toward your aim 18 long, 4 wide; Sunfall
  Cleave a line toward your aim 24 long, 6 wide, each foe hit when the wave (40 studs a second) reaches it; Prism
  Judgment your aimed foe within 24 studs (in front, else around you), five strikes 0.15 s apart, each 1/5.
- The server checks the shape from its own record of where you stood; never the client's word for what was hit.
- The Steel Sword keeps its dash slash and pale steel; the Prism Blade's trail keeps taking the colour strong against
  the foe.
- Effects grow with the trail's scale from +7 (`trailScale` 1.2 / 1.35 / 1.5); no other ladder change.
- Everyone sees each other's slash, finisher and skill effects; others' effects drop particles first if a crowded fight
  runs slow.
- Effects never hide the boss's attack rings or telegraphs: no full-screen flashes, short-lived, low on screen.
- Licensed sounds only (Pro Sound Effects / APM), quiet (the owner's level for the Forge and drop sounds), each measured
  into `Config/SoundLevels`.
- Each sword is shown as a storyboard (visual companion) and its skill animation as front/side GIF previews before it's
  built; order Sunforged, Verdant, Prism, Forge Sword.
- The owner publishes the skill animations (Save to Roblox); their ids go in `Config/Swords`; Studio plays them before.
- Project rules (CLAUDE.md): `--!strict`, numbers in `src/shared/Config`, every remote in `Remotes.luau`, pure rules in
  `src/shared/Util` with Lune tests, never edit synced scripts in Studio, update DESIGN.md with the code.

## Review Focus

1. A skill used with no foe in its shape (Judgment with none within 24 studs, a wave toward nothing): the animation and
   effect still play, no damage, no error (Task 1 test: `skillHits` returns an empty list).
2. A foe that dies or leaves between the skill's start and a delayed hit (Sunfall's wave, Judgment's later strikes):
   that hit is skipped, the others land, no error (Task 1 test: hits carry the target id; Task 2 filters by id).
3. Swapping weapons around a skill: the skill used is the moveset equipped when the server receives it, its cooldown
   kept (Task 2 Studio check: equip another sword during the cooldown, the next skill is the new sword's).
4. Another player's effects far away or many at once: drawn only within range, at most a few full ones (Task 4 test:
   `SwordSkillFxRules.drawsOthers`).
5. A Forge Sword of each element: the same skill, coloured by its element, no missing colour (Task 3 test: every element
   has its look colours; Task 8 Studio check of all five).

---

### Task 1: The skill shapes rule

**Files:**
- Modify: `src/shared/Util/SwordRules.luau` (add `SkillShape`, `SkillHit`, `skillHits`)
- Test: `tests/SwordRules.spec.luau`

**Interfaces:**
- Produces:
  - `export type SkillShape = { kind: "dash" | "spin" | "line" | "wave" | "judgment", radius: number?, length: number?, width: number?, speed: number?, range: number?, angle: number?, strikes: number?, gap: number?, maxStuds: number?, slack: number? }`
  - `export type SkillHit = { id: string, after: number, share: number }`
  - `function SwordRules.skillHits(shape: SkillShape, sx: number, sz: number, px: number, pz: number, lookX: number, lookZ: number, targets: { Target }): { SkillHit }`
    (`sx, sz`: where the skill started; `px, pz, lookX, lookZ`: where you are and face at the hit moment; `after`:
    seconds after the hit moment; shares of one cast sum to 1 for each foe hit, judgment's single foe gets 5 x 0.2)

- [ ] **Step 1: Write the failing tests** in `tests/SwordRules.spec.luau`:

```lua
["skill shapes: dash is today's path, spin hits all around, a line ahead, the wave arrives by distance"] = function()
	local t = function(id, x, z) return { id = id, x = x, z = z, radius = 1 } end
	local targets = { t("ahead", 0, -10), t("behind", 0, 6), t("far", 0, -30), t("side", 8, 0) }
	-- dash: the same foes as SwordRules.anyInDashPath along the path from start to now (clamped to maxStuds + slack)
	local dash = SwordRules.skillHits({ kind = "dash", width = 4, maxStuds = 20, slack = 3 }, 0, 0, 0, -12, 0, -1, targets)
	expect.equal(#dash, 1); expect.equal(dash[1].id, "ahead"); expect.equal(dash[1].share, 1); expect.equal(dash[1].after, 0)
	-- spin: within 9 (+ the foe's radius) of where you are, all at once
	local spin = SwordRules.skillHits({ kind = "spin", radius = 9 }, 0, 0, 0, 0, 0, -1, targets)
	local ids = {}
	for _, hit in spin do ids[hit.id] = hit.after end
	expect.equal(ids.behind, 0); expect.equal(ids.side, 0); expect.equal(ids.ahead, nil); expect.equal(ids.far, nil)
	-- line: 18 long, 4 wide ahead of you
	local line = SwordRules.skillHits({ kind = "line", length = 18, width = 4 }, 0, 0, 0, 0, 0, -1, targets)
	expect.equal(#line, 1); expect.equal(line[1].id, "ahead")
	-- wave: 24 long, 6 wide, each foe when the 40 stud-a-second wave reaches it
	local wave = SwordRules.skillHits({ kind = "wave", length = 24, width = 6, speed = 40 }, 0, 0, 0, 0, 0, -1, targets)
	expect.equal(#wave, 1); expect.near(wave[1].after, 10 / 40, 1e-6)
end,

["judgment: five strikes a fifth each on the aimed foe within 24 (in front first), none in range: nothing"] = function()
	local t = function(id, x, z) return { id = id, x = x, z = z, radius = 1 } end
	local shape = { kind = "judgment", range = 24, angle = 60, strikes = 5, gap = 0.15 }
	local hits = SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("front", 0, -20), t("back", 0, 5) })
	expect.equal(#hits, 5)
	local total = 0
	for index, hit in hits do
		expect.equal(hit.id, "front"); expect.near(hit.after, (index - 1) * 0.15, 1e-9); total += hit.share
	end
	expect.near(total, 1, 1e-9)
	local around = SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("back", 0, 5) })
	expect.equal(around[1].id, "back", "none in front: the nearest around")
	expect.equal(#SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("away", 0, 40) }), 0, "out of range")
	expect.equal(#SwordRules.skillHits({ kind = "spin", radius = 9 }, 0, 0, 0, 0, 0, -1, {}), 0, "no foes")
end,
```

- [ ] **Step 2: Run** `lune run tests/run SwordRules` — Expected: FAIL (`skillHits` is nil).
- [ ] **Step 3: Implement `SwordRules.skillHits`** reusing `clampPath`, `inDashPath`, `aimTarget` (judgment: `aimTarget` with `range`/`angle`, else the nearest target within `range`); a line/wave's end is `px + lookX * length`; a wave hit's `after` is the foe's distance along the line / `speed`.
- [ ] **Step 4: Run** `lune run tests/run SwordRules` — Expected: PASS; then `lune run tests/run` — all pass.
- [ ] **Step 5: Commit** `git commit -m "Sword skills: one rule for every skill's shape"`

### Task 2: One moveset per sword, the server's new skills

**Files:**
- Modify: `src/shared/Config/Swords.luau` (Skill type: `dash` becomes optional, gains `shape: SwordRules.SkillShape`;
  Sword type gains `fx: { slash: string, finisher: string, skill: string }?`; four new movesets)
- Modify: `src/shared/Config/Weapons.luau` (each round 1 sword's `moveset`)
- Modify: `src/server/Services/BattleService.luau` (`onSwordSkill` uses `skillHits`)
- Modify: `src/client/Controllers/SwordController.luau` (`Skill`: dash only when the skill has `dash`; predicted bursts
  from `skillHits`)
- Test: `tests/SwordsConfig.spec.luau`

**Interfaces:**
- Consumes: Task 1 `SwordRules.skillHits`.
- Produces: `Swords.SWORDS.forgeSword | verdantBlade | sunforgedBlade | prismBlade` (fields as the starter's; `combo`
  and every animation but `skill` are the starter's own tables; `skill` = `{ power = 0.9, cooldown = 8, hitAt, length,
  shape }`; `fx = { slash, finisher, skill }` naming `Config/SwordSkillFx` looks; `model` = the folder its skill
  animation lives in: `ForgeSword`, `VerdantBlade`, `SunforgedBlade`, `PrismBlade`). Skill timings until the
  animations exist (Tasks 5-8 match them to the Hit markers): Elemental Spin hitAt 0.45 / length 0.9; Thornline 0.55 /
  1.1; Sunfall Cleave 0.8 / 1.3; Prism Judgment 0.6 / 1.4.
  Shapes: spin `{ kind = "spin", radius = 9 }`, line `{ kind = "line", length = 18, width = 4 }`, wave `{ kind = "wave",
  length = 24, width = 6, speed = 40 }`, judgment `{ kind = "judgment", range = 24, angle = 60, strikes = 5, gap = 0.15 }`;
  the starter's skill gets `shape = { kind = "dash", width = 4, maxStuds = 20, slack = 3 }` (from its `dash`).
  fx names: forgeSword `{ slash = "elementTrail", finisher = "elementBurst", skill = "elementalSpin" }`, verdantBlade
  `{ "leafShed", "rootBurst", "thornline" }`, sunforgedBlade `{ "fireTrail", "lavaCrack", "sunfallCleave" }`,
  prismBlade `{ "rainbowArc", "prismShatter", "prismJudgment" }` (as slash / finisher / skill).

- [ ] **Step 1: Write the failing tests** in `tests/SwordsConfig.spec.luau`: each round 1 weapon's `moveset` is its own
  (`Weapons.ById.sunforgedBlade.moveset == "sunforgedBlade"`, the five Forge Swords' `"forgeSword"`); every moveset's
  `combo` is `Swords.SWORDS.starterSword.combo` (same table) and its `animations.cut1/cut2/cut3` the starter's; every
  skill's `power` is 0.9 and `cooldown` 8; every skill has a `shape` with a known `kind`; the starter's shape is
  `"dash"`; every non-starter moveset has `fx` with the three names above.
- [ ] **Step 2: Run** `lune run tests/run SwordsConfig` — Expected: FAIL.
- [ ] **Step 3: Implement the movesets** in `Config/Swords` (a local `withSkill(name, model, skill, fx, cues)` copying the
  starter's fields by reference and replacing `skill`, `animations.skill`, `fx` and the skill's `cues`), point
  `Config/Weapons` at them.
- [ ] **Step 4: Server**: `onSwordSkill` records `sx, sz` at use; at `skill.hitAt` gets the root, `swordTargets(fight)`
  and `SwordRules.skillHits(skill.shape, ...)`; for each hit `task.delay(hit.after, strike, fight, member, skill.power *
  WeaponService.Power(player) * hit.share, "Skill", function(_, _, _, _, target) return target.id == hit.id end)`. The
  starter's dash keeps today's result (its test in Task 1).
- [ ] **Step 5: Client**: `SwordController.Skill` dashes only when `skill.dash` exists; its `predictHit` asks
  `#SwordRules.skillHits(...) > 0`.
- [ ] **Step 6: Run** `lune run tests/run` — Expected: all pass. Studio (Play, a boss via `/boss 1 fight`, Review Focus
  3): each sword's skill lands damage on the Warden (Output clean); equipping another sword during the cooldown, the next
  skill is the new sword's.
- [ ] **Step 7: Commit** `git commit -m "Sword skills: each round 1 sword its own moveset and skill shape"`

### Task 3: The effects toolkit and its preview

**Files:**
- Create: `src/shared/Config/SwordSkillFx.luau` (plain data), `src/shared/Util/SwordSkillFxRules.luau` (pure),
  `src/client/Util/SwordSkillFx.luau`
- Modify: `src/client/Controllers/MovePreviewController.luau` (payload `{ skillFx = moveset, move = "cut3" | "skill",
  grade, level }`), `src/server/Services/DevService.luau` (`/skillfx <sword> [cut1|cut2|cut3|skill] [level]`),
  `src/shared/Config/AdminPanel.luau` (a "Sword skills" section: four swords x finisher / skill buttons)
- Test: `tests/SwordSkillFx.spec.luau` (new), `tests/AdminPanel.spec.luau`

**Interfaces:**
- Produces:
  - `Config/SwordSkillFx.LOOKS: { [string]: { kind: "slash" | "finisher" | "skill", textures: { string }, ... } }`
    (keys exactly the twelve fx names of Task 2; `textures` are keys of `AttackFx.TEXTURES`, `MoveFx.TEXTURES`,
    `SuperFx.TEXTURES` or `SwordFx.TEXTURES`), `Config/SwordSkillFx.OTHERS = { range = 90, full = 3 }`
  - `SwordSkillFxRules.scale(trailScale: number): number` (1 below +7, then the trail's scale) and
    `SwordSkillFxRules.drawsOthers(distance: number, fullDrawn: number, others: { range: number, full: number }): "full" | "light" | "none"`
  - `SwordSkillFx.slash(character: Model, look: string, cut: number, colors: { deep: Color3, glow: Color3 }, scale: number)`,
    `SwordSkillFx.finisher(at: Vector3, look: string, colors, scale)`,
    `SwordSkillFx.skill(character: Model, look: string, colors, scale, aim: Vector3?)` (each returns nothing, cleans up after itself)
- Consumes: Task 2's `fx` names; `WeaponLooks.WEAPONS[*].glow/deep` and `BY_ELEMENT` for colours.

- [ ] **Step 1: Write the failing tests**: every look named by a moveset's `fx` exists with the right `kind`; every
  texture key exists in one of the four TEXTURES tables; every element has `glow` and `deep` (Review Focus 5);
  `scale(1) == 1`, `scale(1.5) == 1.5`; `drawsOthers(30, 0, OTHERS) == "full"`, `drawsOthers(30, 3, OTHERS) ==
  "light"`, `drawsOthers(200, 0, OTHERS) == "none"`; the AdminPanel has a "Sword skills" section whose commands start
  with `/skillfx`.
- [ ] **Step 2: Run** `lune run tests/run SwordSkillFx` — Expected: FAIL.
- [ ] **Step 3: Implement** the config (placeholder numbers per look, tuned in Tasks 5-8), the rules, the client util
  (each builder a stub that draws its look's basic shape so the preview works) and the preview path (the dummy of
  `/superfx`, the player's character casting).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass. Studio: `/skillfx sunforged skill` plays the stub on a
  dummy, Output clean.
- [ ] **Step 5: Commit** `git commit -m "Sword skills: the effects toolkit and /skillfx"`

### Task 4: Everyone sees each other's sword effects

**Files:**
- Modify: `src/shared/Remotes.luau` (`"SwordCast"`, server → all clients: `(userId, move, x, z)`, move `"cut1" | "cut2" |
  "cut3" | "skill"`), `src/server/Services/BattleService.luau` (fire it when a cut or skill is accepted),
  `src/client/Controllers/SwordController.luau` (own swings: `SwordSkillFx` calls from `Attack`/`Skill`; others' from
  `SwordCast`, gated by `drawsOthers`)
- Test: covered by Task 3's `drawsOthers` test; Studio check here.

**Interfaces:**
- Consumes: Task 3 `SwordSkillFx.*`, `SwordSkillFxRules.drawsOthers`, `Config/SwordSkillFx.OTHERS`.

- [ ] **Step 1: Implement**: your own cuts call `SwordSkillFx.slash` at each arc and `finisher` at cut 3's hit, your
  skill calls `skill` at its start; `SwordCast` (not your own userId) draws the same on that character when
  `drawsOthers` says so ("light": the slash only, no finisher/skill particles beyond its core).
- [ ] **Step 2: Run** `lune run tests/run` — Expected: all pass. Studio (Test → Local Server, 2 players): player 2 sees
  player 1's slashes and skill; Output clean.
- [ ] **Step 3: Commit** `git commit -m "Sword skills: others see your sword's effects"`

### Task 5: Sunforged Blade (fire trail, lava crack, Sunfall Cleave)

**Files:**
- Create: `tools/blender/anim_sunforged_blade.py` (on `anim_kit.py`), `assets/animations/SunforgedBlade/skill.rbxm`
  (by `build_kfs`)
- Modify: `src/shared/Config/SwordSkillFx.luau` (`fireTrail`, `lavaCrack`, `sunfallCleave`), `src/client/Util/SwordSkillFx.luau`,
  `src/shared/Config/Swords.luau` (sunforgedBlade skill `hitAt`/`length` to the Hit marker, sounds, cues),
  `src/shared/Config/SoundLevels.luau`

- [ ] **Step 1: Storyboard** in the visual companion: the fire trail on cuts 1-3, the lava crack under the finisher, the
  Sunfall Cleave beats (raise, sunlight gathering, the swing, the crescent wave, the explosion). Owner OK.
- [ ] **Step 2: The skill animation** in a background Blender (`anim_sunforged_blade.py`, `anim_kit` helpers): blade
  raised overhead, a held charge, a huge forward swing following through low (about 1.3 s), a Hit marker at the swing's
  strike. Front and side GIF previews to the owner. Owner OK.
- [ ] **Step 3:** `lune run tools/anim/build_kfs` → `assets/animations/SunforgedBlade/skill.rbxm`; set the skill's
  `hitAt` to the Hit marker; `lune run tests/run SwordsConfig` passes.
- [ ] **Step 4: The effects**: the three looks in `SwordSkillFx` (reusing `SuperFx.TEXTURES.crack`, `AttackFx.TEXTURES.flame`
  and `SwordFx.TEXTURES.crescent`), under the boss's rings, scaled by `SwordSkillFxRules.scale`.
- [ ] **Step 5: Sounds**: licensed picks (a fire whoosh layer on the slashes, a lava rumble on the finisher, the skill's
  charge, swing and explosion), measured with `tools/audio/measure_loudness.luau` into `Config/SoundLevels`, at the
  owner's quiet level.
- [ ] **Step 6: Studio check**: `/skillfx sunforged cut3`, `/skillfx sunforged skill`, then a real boss fight (the
  Sunforged equipped): damage lands, Output clean, screenshots of each beat to the owner.
- [ ] **Step 7: Commit** `git commit -m "Sword skills: the Sunforged Blade's fire, lava and Sunfall Cleave"`

### Task 6: Verdant Blade (leaves, roots, Thornline)

Same steps as Task 5 for `VerdantBlade`: `tools/blender/anim_verdant_blade.py` (a short hop, both hands driving the
blade into the ground in front, a beat holding it; about 1.1 s); looks `leafShed`, `rootBurst`, `thornline` (reusing
`MoveFx.TEXTURES.vine` and `bark`, `AttackFx.TEXTURES.glow`); sounds a leafy rustle layer, roots cracking, the vines
erupting and snapping shut. Commit `"Sword skills: the Verdant Blade's leaves, roots and Thornline"`.

### Task 7: Prism Blade (rainbow arcs, prism shatter, Prism Judgment)

Same steps for `PrismBlade`: `tools/blender/anim_prism_blade.py` (the blade swept up, then pointed at the boss and held
while the strikes land; about 1.4 s; five Hit markers 0.15 s apart, or one marker with the gap from config); looks
`rainbowArc`, `prismShatter`, `prismJudgment` (the five ghost blades are clones of the Forge Sword models, one per
element, tinted and see-through, striking down in order Ember, Tide, Bloom, Volt, Shade; then a rainbow pillar);
sounds a crystal chime layer, a prism shatter, the blades' strikes and the pillar. Commit `"Sword skills: the Prism
Blade's rainbow arcs and Prism Judgment"`.

### Task 8: Forge Sword (element trail, element burst, Elemental Spin)

Same steps for `ForgeSword` (one skill animation shared by the five elements): `tools/blender/anim_forge_sword.py` (a
planted full turn with the blade held out at waist height; about 0.9 s); looks `elementTrail`, `elementBurst`,
`elementalSpin` coloured by the weapon's element (flame puff / splash / leaves / sparks / shadow for the burst, the
ring wave in the element's look); sounds per element layer. Studio check all five elements (Review Focus 5). Commit
`"Sword skills: the Forge Sword's element trail, burst and Elemental Spin"`.

### Task 9: Balance, sounds and docs

**Files:**
- Modify: `tests/SoundLevel.spec.luau` (also every `Swords.SWORDS[*].sounds` id measured), `tools/audio/sound_ids.luau`
  (lists the sword sounds), `DESIGN.md` (5.11 and the combat section: each sword's effects and skill, the shapes, the
  broadcast; 10.2 files; 13 backlog), `docs/animations.md` (the four skill animations), `CLAUDE.md` (`/skillfx`, the
  new files, tests list: `SwordSkillFx`)

- [ ] **Step 1: Write the failing test**: `tests/SoundLevel.spec.luau` "every sword sound has its loudness measured"
  (as the super and Pet move sounds). Run `lune run tests/run SoundLevel` — Expected: FAIL for any unmeasured id;
  measure them (`tools/audio/measure_loudness.luau` in Studio) into `Config/SoundLevels`; PASS.
- [ ] **Step 2: Balance**: `lune run tools/balance/bosses 300` before (main) and after — Expected: every row's win rate
  within noise (the skills' damage and cooldown didn't change). Report the numbers.
- [ ] **Step 3: Docs** as listed; `rojo sourcemap default.project.json -o sourcemap.json`; `rojo build -o <scratch>/test.rbxl`.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "Sword skills: sound levels, balance check and docs"`
- [ ] **Step 6: The owner publishes** the four skill animations (Save to Roblox under `ReplicatedStorage.SwordAnimations.<Sword>`);
  the ids go in `Config/Swords` (`animations.skill`); commit `"Sword skills: published animation ids"`.
