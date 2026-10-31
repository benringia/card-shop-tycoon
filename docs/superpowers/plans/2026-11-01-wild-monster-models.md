# Wild Monster Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The six Wild monsters draw their approved Meshy models, sized by species, rigged and moving like creatures, with
glowing eyes and growths and two small effects.

**Architecture:** A pure `Util/MonsterLooks` decides a monster's height, its animation style key and its glow strength;
`MonsterController` uses it, so rigged monster models animate through the existing `PetAnimator` (today only bosses do).
`PetRig` learns an eight-leg wave and one plain roar kind. Each model is cut down and rigged in Blender by its own
`tools/blender/rig_<folder>.py` on `rig_kit.py`, which also writes an emissive glow mask; the user imports the FBX
files and saves `assets/monsters/<Species>.rbxm`, with the mask set on a SurfaceAppearance in Studio.

**Tech Stack:** Luau (Rojo, Lune tests), Blender 5.2 Python through the Blender MCP, Roblox Studio MCP.

**Spec:** docs/superpowers/specs/2026-11-01-wild-monster-models-design.md

## Global Constraints

- Heights in studs: Mossling 2.5, Puddle Crab 2, Cave Bat 3, Spark Beetle 2.5, Ash Wolf 4, Magma Golem 6.5; elites
  `ELITE_SIZE` (1.35) times that.
- Style B, wild-touched, not card-like; the cut-down mesh keeps the approved silhouette, face and colours (the Mossling's
  and the golem's dark pupils stay; their eyes glow around them).
- Triangle budget: about 5,000 per model, the golem up to about 8,000.
- No new Meshy generations without asking the user (1420 credits on 2026-11-01).
- Sources in `assets/blender/<Folder>/` (`Mossling`, `PuddleCrab`, `CaveBat`, `SparkBeetle`, `MagmaGolem`, `AshWolf`);
  raw meshes in `.superpowers/monsters-raw/monsters_raw.blend` (`<Folder>_Src`). Delete `*_Src` and purge orphans before
  saving a .blend; before committing one, print the lengths of the scene's `blendermcp_*key*` / `*secret*` fields and
  check they are 0.
- Models saved as `assets/monsters/<Species>.rbxm` with the species name exactly as in `Config/Wild` (`Puddle Crab.rbxm`).
- Numbers in Config; pure rules Lune-tested (`lune run tests/run`, 626 passing at the start); `--!strict`.
- Studio MCP: reading is fine; ask before changing the place (Task 9's import edits are asked for once at the hand-off).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A species with no model (the Frontier's six, or a model over `MAX_MODEL_PARTS`) still draws its placeholder at
   `MONSTER_HEIGHT` with no error and no bone animation (Task 1 tests the height fallback and `styleKey` with no model).
2. An elite of a rigged species is 1.35x and its bones move at that size, not the species size (Task 1 tests the elite
   height; Task 9 checks one with `/elite` in Studio).
3. A model whose SurfaceAppearance has no emissive mask, or no SurfaceAppearance at all, draws normally with no error
   (Task 1: `glowStrength` returns nil with no glow config, and the controller only touches SurfaceAppearances that
   have a mask).
4. Bosses keep exactly today's behaviour: the style key stays the boss id, and plain `roar` (the Prism Hydra's
   signature) still neither cues nor poses the head (Task 1 and Task 2 tests).
5. The golem's lava pulse never goes outside its configured low/high and never stops (Task 1 tests the pulse bounds
   over a full cycle).

---

### Task 1: Monster size, style key and glow strength

**Files:**
- Create: `src/shared/Util/MonsterLooks.luau`
- Modify: `src/shared/Config/Wild.luau` (the six `SPECIES` entries)
- Modify: `src/client/Controllers/MonsterController.luau` (`add`, the RenderStepped loop)
- Test: `tests/MonsterLooks.spec.luau` (new; register it in `tests/run.luau`)

**Interfaces:**
- Produces:
  - `export type Glow = { strength: number, pulse: { low: number, high: number, seconds: number }? }`
  - `MonsterLooks.height(world: any, species: string, elite: boolean, bossScale: number?): number`: a boss is
    `world.MONSTER_HEIGHT * bossScale` (today's rule, elite ignored); otherwise the species' `height` (or
    `world.MONSTER_HEIGHT` when it has none) times `world.ELITE_SIZE` for an elite.
  - `MonsterLooks.styleKey(species: string, bossId: string?, hasModel: boolean): string?`: nil without a model, else
    the boss id for a boss, else the species name.
  - `MonsterLooks.glowStrength(glow: Glow?, now: number): number?`: nil with no glow; `strength` with no pulse; with a
    pulse, `low + (high - low) * (0.5 - 0.5 * cos(2π * now / seconds))` (low at 0, high at half a cycle).
  - `Wild.SPECIES[name].height: number?` and `.glow: MonsterLooks.Glow?`.

- [ ] **Step 1: Write the failing tests** in `tests/MonsterLooks.spec.luau` (requires `../src/shared/Config/Wild`,
  `../src/shared/Config/Frontier`, `../src/shared/Util/MonsterLooks`):

```lua
["each wild species has its own height, elites 1.35x"] = function()
	local heights = { Mossling = 2.5, ["Puddle Crab"] = 2, ["Cave Bat"] = 3, ["Spark Beetle"] = 2.5, ["Ash Wolf"] = 4, ["Magma Golem"] = 6.5 }
	for species, height in heights do
		expect.near(MonsterLooks.height(wild, species, false), height, 1e-9, species)
		expect.near(MonsterLooks.height(wild, species, true), height * wild.ELITE_SIZE, 1e-9, species .. " elite")
	end
end,
["a species without a height keeps the world's monster height"] = function()
	expect.near(MonsterLooks.height(frontier, "Frost Wisp", false), frontier.MONSTER_HEIGHT, 1e-9, "Frontier species")
end,
["a boss is sized by its scale as before"] = function()
	expect.near(MonsterLooks.height(wild, "Mossling", false, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "boss")
	expect.near(MonsterLooks.height(wild, "Mossling", true, 2.5), wild.MONSTER_HEIGHT * 2.5, 1e-9, "elite flag ignored")
end,
["bones move by species, bosses by their id, nothing without a model"] = function()
	expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, true), "Ash Wolf", "monster")
	expect.equal(MonsterLooks.styleKey("Ash Wolf", nil, false), nil, "placeholder")
	expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", true), "meadowWarden", "boss")
	expect.equal(MonsterLooks.styleKey("Mossling", "meadowWarden", false), nil, "boss placeholder")
end,
["glow: none, steady, or a pulse that stays in its range"] = function()
	expect.equal(MonsterLooks.glowStrength(nil, 3), nil, "no glow")
	expect.equal(MonsterLooks.glowStrength({ strength = 2 }, 3), 2, "steady")
	local pulse = { strength = 2, pulse = { low = 1.2, high = 3, seconds = 2.5 } }
	expect.near(MonsterLooks.glowStrength(pulse, 0) :: number, 1.2, 1e-9, "low at the start")
	expect.near(MonsterLooks.glowStrength(pulse, 1.25) :: number, 3, 1e-9, "high halfway")
	for step = 0, 50 do
		local value = MonsterLooks.glowStrength(pulse, step * 0.1) :: number
		assert(value >= 1.2 - 1e-9 and value <= 3 + 1e-9, "pulse out of range")
	end
end,
["every wild species has a height and the golem's lava pulses"] = function()
	for species, info in wild.SPECIES do
		assert(type(info.height) == "number" and info.height > 0, species .. " has no height")
		assert(info.glow and info.glow.strength > 0, species .. " has no glow")
	end
	assert(wild.SPECIES["Magma Golem"].glow.pulse, "the golem's lava doesn't pulse")
end,
```

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run MonsterLooks`
Expected: FAIL (module `MonsterLooks` not found).

- [ ] **Step 3: Implement `Util/MonsterLooks.luau` and the config.** Pure, no requires. In `Config/Wild.luau` give each
  `SPECIES` entry `height` (the Global Constraints values) and `glow`: `{ strength = 2 }` for five species,
  `{ strength = 2.5, pulse = { low = 1.2, high = 3, seconds = 2.5 } }` for the Magma Golem.

- [ ] **Step 4: Run the tests to see them pass**

Run: `lune run tests/run MonsterLooks`
Expected: PASS (6 tests).

- [ ] **Step 5: Wire `MonsterController`.** In `add`: height from `MonsterLooks.height(Wild, species, elite, boss and
  boss.scale)`; the last argument to `CreatureVisuals.build` becomes `MonsterLooks.styleKey(species, boss and bossId,
  template ~= nil)`; set `body.fxColor` to the element colour (roar sparks); collect the model's SurfaceAppearances whose
  `EmissiveMaskContent.SourceType ~= Enum.ContentSourceType.None` and set their `EmissiveStrength` from
  `MonsterLooks.glowStrength(info.glow, os.clock())` (skip when nil). In the RenderStepped loop, update the strength
  only for monsters whose glow has a pulse. Bosses: `info.glow` is nil for them, so they are untouched.

- [ ] **Step 6: Full suite and compile check**

Run: `lune run tests/run` then `lune run "$TEMP/lc/check2.luau" src/client/Controllers/MonsterController.luau src/shared/Util/MonsterLooks.luau src/shared/Config/Wild.luau`
Expected: all pass (632); `checked 3`.

- [ ] **Step 7: Commit** (`Wild monsters: sizes by species, bones for rigged models, glow strength`).

### Task 2: Many-legged gait, a plain roar for monsters, and the monster styles

**Files:**
- Modify: `src/shared/Util/PetRig.luau` (`legOffset`, `ROARS`)
- Modify: `src/client/Util/CreatureVisuals.luau` (the rigged cue branch)
- Modify: `src/shared/Config/Party.luau` (`CREATURE_STYLE`, `SIGNATURE`)
- Test: `tests/PetRig.spec.luau`, `tests/MonsterLooks.spec.luau`

**Interfaces:**
- Produces: signature kind `"wildroar"` (rears, lunges, jaw opens, cues at `ROAR_BURST`, plain shockwave and sparks in
  `body.fxColor`); `Party.CREATURE_STYLE` and `Party.SIGNATURE` entries keyed by the six species names.

- [ ] **Step 1: Write the failing tests** in `tests/PetRig.spec.luau` (use the file's `CFG`, `poseAt`, `rolesOf`; add
  `local fs = require("@lune/fs")` at the top):

```lua
["eight legs walk in a wave: odd pairs step opposite the even ones"] = function()
	local state = { phase = 0, moving = 1, flying = false } :: any
	local function lift(name: string): number
		return PetRig.footLift(CFG, PetRig.role(name) :: PetRig.Role, false, state)
	end
	assert(lift("0_Left_Limb_0") > 0 and lift("2_Left_Limb_0") > 0, "even left pairs step together")
	expect.equal(lift("1_Left_Limb_0"), 0, "pair 1 opposite")
	expect.equal(lift("3_Left_Limb_0"), 0, "pair 3 opposite")
	assert(lift("3_Right_Limb_0") > 0, "the right side mirrors")
end,
["six legs keep the insect tripod"] = function()
	local state = { phase = 0, moving = 1, flying = false } :: any
	local function lift(name: string): number
		return PetRig.footLift(CFG, PetRig.role(name) :: PetRig.Role, false, state)
	end
	assert(lift("0_Left_Limb_0") > 0 and lift("1_Right_Limb_0") > 0 and lift("2_Left_Limb_0") > 0, "tripod A")
	expect.equal(lift("0_Right_Limb_0") + lift("1_Left_Limb_0") + lift("2_Right_Limb_0"), 0, "tripod B waits")
end,
["a wild roar rears, lunges and opens the jaw; plain roar stays as it was"] = function()
	assert(PetRig.cue(CFG, "wildroar", CFG.ROAR_BURST) and not PetRig.cue(CFG, "wildroar", 0.1), "cues with the lunge")
	assert(PetRig.body(CFG, "wildroar", CFG.ROAR_BURST * 0.9, 1, true).pitch > 0, "rears back first")
	local WOLF = { "Pelvis", "Spine_0", "Neck", "Head_0", "Jaw_0", "0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0", "Tail_0" }
	assert(poseAt(WOLF, { time = 0, phase = 0, moving = 0, fidget = "wildroar", fidgetProgress = 0.5 } :: any)["jaw:0"].x < -math.rad(10), "jaw opens")
	expect.equal(PetRig.cue(CFG, "roar", 0.9), false, "plain roar still never cues (the Prism Hydra)")
	local source = fs.readFile("src/client/Util/CreatureVisuals.luau")
	assert(string.find(source, '"wildroar"', 1, true), "CreatureVisuals plays the shockwave for a wild roar")
end,
```

  and in `tests/MonsterLooks.spec.luau` (requires `../src/shared/Config/Party`):

```lua
["every wild species moves in its own style with known fidgets"] = function()
	local known = {}
	for _, list in { party.PET_ANIM.FIDGETS, party.PET_ANIM.BODY_FIDGETS, party.PET_ANIM.TITAN_FIDGETS } do
		for _, kind in list do known[kind] = true end
	end
	for species in wild.SPECIES do
		local style = party.CREATURE_STYLE[species]
		assert(style and style.fidgets, species .. " has no style")
		for _, kind in style.fidgets do assert(known[kind], species .. ": unknown fidget " .. kind) end
	end
	expect.equal(party.SIGNATURE["Ash Wolf"].fidget, "wildroar", "the wolf roars")
	expect.equal(party.SIGNATURE["Magma Golem"].fidget, "stomp", "the golem stomps")
end,
```

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run PetRig` and `lune run tests/run MonsterLooks`
Expected: FAIL on the eight-leg wave (pair 3 lifts with pair 0), on the wild roar and on the missing styles; the
six-leg tripod test already passes (it pins existing behaviour).

- [ ] **Step 3: Implement.** `legOffset`: add π for odd pairs (`role.pair % 2 == 1`) instead of pair 1 only (`isBiped`
  is unchanged). Add `wildroar = true` to `ROARS` (the existing branches then pose, cue and tip the body for it, since
  it isn't `"roar"`). In `CreatureVisuals`' rigged cue branch, add `"wildroar"` to the kinds that call `roarFx(body)`
  (`SignatureFx.play` ignores unknown kinds). In `Config/Party`:
  - `CREATURE_STYLE`: `Mossling = { fidgets = { "look", "sniff", "shake", "yawn" }, tailSpeed = 0.5, tailAmount = 0.5,
    bounce = 0.3, stride = 1.1 }`, `["Puddle Crab"] = { fidgets = { "look", "shake" }, bounce = 0.2 }`,
    `["Cave Bat"] = { fidgets = { "look", "tilt", "spin" } }`, `["Spark Beetle"] = { fidgets = { "look", "shake" },
    bounce = 0.2 }`, `["Magma Golem"] = { fidgets = { "look", "shake", "stomp" }, bounce = 0.15, stride = 1.3,
    legSwing = 0.6, sway = 1.4 }`, `["Ash Wolf"] = { fidgets = { "look", "sniff", "stretch", "shake", "yawn" },
    tailSpeed = 0.5, tailAmount = 0.8, bounce = 0.4 }` (starting values; Task 9 tunes them in Studio).
  - `SIGNATURE`: `["Ash Wolf"] = { fidget = "wildroar", chance = 0.3 }`, `["Magma Golem"] = { fidget = "stomp",
    chance = 0.3 }`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `lune run tests/run`
Expected: all pass (636).

- [ ] **Step 5: Commit** (`PetRig: eight-leg wave and a plain wild roar; Wild monster styles`).

### Task 3: Glow masks, and the Mossling's rig

**Files:**
- Modify: `tools/blender/rig_kit.py` (new `glow_mask`)
- Create: `tools/blender/rig_mossling.py`
- Create: `assets/blender/Mossling/Mossling.blend`, `Mossling.fbx`, `Mossling_glow.png`

**Interfaces:**
- Produces: `rig_kit.glow_mask(mesh, name, rules, grow=1) -> str`: reads the colour image of `mesh`'s material, writes
  `assets/blender/<name>/<name>_glow.png` at the same size, white where a texel matches any rule, black elsewhere,
  grown by `grow` texels so the glow covers the edge; returns the path. A rule is a dict
  `{"hue": (lo, hi) in degrees, "sat": (lo, hi), "val": (lo, hi)}`.
- Produces the per-monster recipe the next five tasks follow: a new .blend in `assets/blender/<Folder>/` with
  `<Folder>_Src` appended from the raw file and copied to `<Folder>_Body` (the Src deleted), mesh fixes, `BONES`,
  `rig_kit.Params`, `rig_kit.run(name, "<Folder>_Body", BONES, params, target_tris=5000)`, then `glow_mask`, then the
  checks below. Effect anchor bones are zero-influence leaves named `Fx_<Name>` (kept by the importer's Keep Zero
  Influence Bones).

- [ ] **Step 1: Make the .blend.** Open the raw file, append `Mossling_Src` into a new file saved as
  `assets/blender/Mossling/Mossling.blend`, copy it to `Mossling_Body`, delete the Src, purge orphans.
- [ ] **Step 2: Write `rig_mossling.py`**: a squat quadruped (`Root`, `Pelvis`, `Spine_0`, `Spine_1`, `Neck`, `Head_0`,
  `Jaw_0`, `Tail_0`, `Tail_1`, legs `0_`/`1_<Side>_Limb_0..2`), bone positions read off the mesh (feet from the ground
  clusters, about x ±0.2, front y -0.1 to -0.17, hind y 0.16 to 0.27 at 0.6 m tall), glow rules for the eyes and the
  mushroom caps only (sample the texture; the tusks are cream too and must stay unlit).
- [ ] **Step 3: Run it in Blender** (exec the file through the MCP with `sys.argv` unset).
  Expected printout: `exported ...\Mossling\Mossling.fbx`, the glow path, triangles ≤ 5,000.
- [ ] **Step 4: Check it.** Print: the triangle count, every bone name, the largest number of bone influences on a
  vertex (≤ 4), the count of vertices with no weight (0). Look at the glow mask image (white on eyes and caps only). Pose
  a front leg and the head 30° and `look` from the side: the mesh follows without tearing; reset the pose. Compare a
  material render with the approved model render: same silhouette, face and colours.
  Expected: all as stated.
- [ ] **Step 5: Save the .blend clean** (no `_Src`, orphans purged, key fields length 0) and commit
  `rig_kit.py`, `rig_mossling.py` and `assets/blender/Mossling/*` (`Wild monsters: glow masks and the Mossling's rig`).

### Task 4: The Puddle Crab's rig

**Files:** Create `tools/blender/rig_puddlecrab.py`, `assets/blender/PuddleCrab/PuddleCrab.blend`, `.fbx`, `_glow.png`

**Interfaces:** Consumes Task 3's recipe and `glow_mask`.

- [ ] **Step 1: Make the .blend** as in Task 3, then **remove the extra leg** in the script: delete the vertices of the
  leg standing at the back middle (its foot cluster near x 0, y +0.16 at 0.3 m tall) and close the hole if one opens.
  Expected: the foot clusters show four a side and none in the middle.
- [ ] **Step 2: Write `rig_puddlecrab.py`**: legs as four pairs `0_..3_<Side>_Limb_0..1` (front to back), the two
  hammer claws as their own chains (the builder picks names: arms if `PetRig` poses arms sensibly on a four-legged
  rig, otherwise child bones of `Head_0` that stay put), glow rules for the barnacle insides and the eyes.
- [ ] **Step 3: Run and check it** exactly as Task 3 Steps 3-4, plus: walking the legs in `look(mode="frames")` is not
  needed; the Lune wave test covers the gait.
- [ ] **Step 4: Save clean and commit** (`Wild monsters: the Puddle Crab's rig (extra leg removed)`).

### Task 5: The Cave Bat's rig

**Files:** Create `tools/blender/rig_cavebat.py`, `assets/blender/CaveBat/CaveBat.blend`, `.fbx`, `_glow.png`

- [ ] **Step 1: Make the .blend** as in Task 3.
- [ ] **Step 2: Write `rig_cavebat.py`**: a flyer (`Wild.FLYING` already lists it): `Root`, `Pelvis`, `Spine_0`, `Neck`,
  `Head_0`, `Jaw_0`, wings `Wing_Left_0..2` and `Wing_Right_0..2` along the stone wing bones, legs as pair 0 only
  (`0_<Side>_Limb_0..1`, tucked while flying), glow rules for the violet cracks and the eyes.
- [ ] **Step 3: Run and check it** as Task 3 Steps 3-4, posing a wing 30° up instead of a leg.
- [ ] **Step 4: Save clean and commit** (`Wild monsters: the Cave Bat's rig`).

### Task 6: The Spark Beetle's rig

**Files:** Create `tools/blender/rig_sparkbeetle.py`, `assets/blender/SparkBeetle/SparkBeetle.blend`, `.fbx`, `_glow.png`

- [ ] **Step 1: Make the .blend** as in Task 3 (the mesh is 0.06 m tall as imported: scale it to about 0.6 m first so
  `Params`' metre defaults fit, and apply the scale).
- [ ] **Step 2: Write `rig_sparkbeetle.py`**: six legs as pairs `0_..2_<Side>_Limb_0..1`, the pincers skinned to
  `Head_0`, two zero-influence effect bones `Fx_PincerLeft` and `Fx_PincerRight` at the pincer tips (children of
  `Head_0`), glow rules for the back crystals, the pincer cracks and the eyes.
- [ ] **Step 3: Run and check it** as Task 3 Steps 3-4; also print the two `Fx_` bones' positions (at the tips).
- [ ] **Step 4: Save clean and commit** (`Wild monsters: the Spark Beetle's rig`).

### Task 7: The Magma Golem's rig

**Files:** Create `tools/blender/rig_magmagolem.py`, `assets/blender/MagmaGolem/MagmaGolem.blend`, `.fbx`, `_glow.png`

- [ ] **Step 1: Make the .blend** as in Task 3 (2 m tall as imported; `Params` for a biped as in the existing two-legged
  rigs, e.g. `rig_cindertitan.py`).
- [ ] **Step 2: Write `rig_magmagolem.py`**: a heavy biped: `Root`, `Pelvis`, `Spine_0`, `Spine_1`, `Neck`, `Head_0`,
  arms `Arm_Left_0..2` and `Arm_Right_0..2`, legs as pair 0 only (`0_<Side>_Limb_0..2`) so `isBiped` holds,
  `target_tris=8000`, glow rules for the lava drips and the iris around the dark pupil.
- [ ] **Step 3: Run and check it** as Task 3 Steps 3-4, posing an arm 40° forward.
- [ ] **Step 4: Save clean and commit** (`Wild monsters: the Magma Golem's rig`).

### Task 8: The Ash Wolf's rig (bulked up)

**Files:** Create `tools/blender/rig_ashwolf.py`, `assets/blender/AshWolf/AshWolf.blend`, `.fbx`, `_glow.png`

- [ ] **Step 1: Make the .blend** as in Task 3, then **bulk it up by about 15%** in the script: scale the body and legs
  out from the midline (x) and the body's centre line (z) by 1.15, leaving the head, mane silhouette and length alone
  (a smooth falloff so there is no step at the neck). Expected: torso width 0.44 m → about 0.50 m; a side-by-side render
  with the raw model reads heavier, not distorted.
- [ ] **Step 2: Write `rig_ashwolf.py`**: a quadruped with `Jaw_0`, ears `Ear_<Side>_0`, tail `Tail_0..3` and a
  zero-influence `Fx_Tail` at the tail tip (child of `Tail_3`); glow rules for the ember cracks, the eye marks and the
  tail tip.
- [ ] **Step 3: Run and check it** as Task 3 Steps 3-4, plus the `Fx_Tail` position (at the tip).
- [ ] **Step 4: Save clean and commit** (`Wild monsters: the Ash Wolf's rig, bulked up`).

### Task 9: Into Studio: glow on the models, effects, tuning

**Files:**
- Create: `assets/monsters/Mossling.rbxm`, `Puddle Crab.rbxm`, `Cave Bat.rbxm`, `Spark Beetle.rbxm`, `Magma Golem.rbxm`,
  `Ash Wolf.rbxm` (saved by the user)
- Modify: `src/shared/Config/Wild.luau` (`SPECIES` `fx`, `FX_RANGE`), `src/client/Controllers/MonsterController.luau`
- Test: `tests/MonsterLooks.spec.luau`

**Interfaces:**
- Consumes: the six FBX and glow PNGs; `Fx_PincerLeft`, `Fx_PincerRight`, `Fx_Tail`.
- Produces: `Wild.SPECIES[name].fx: { kind: "sparks" | "smoke", bones: { string } }?` (Spark Beetle
  `{ kind = "sparks", bones = { "Fx_PincerLeft", "Fx_PincerRight" } }`, Ash Wolf `{ kind = "smoke", bones =
  { "Fx_Tail" } }`) and `Wild.FX_RANGE = 60` studs.

- [ ] **Step 1: Hand-off to the user** (one message): import the six FBX into Studio (Rig Type Custom, Keep Zero
  Influence Bones) and upload the six `*_glow.png` (Creator Hub, Images), then send the six image ids. Ask once to edit
  the imported copies in the place.
- [ ] **Step 2: Prepare each model through the Studio MCP** (Edit mode): reset the MeshPart's `PivotOffset` rotation;
  name the model by species; add a SurfaceAppearance under the MeshPart with `ColorMapContent` from the MeshPart's
  `TextureID` and `EmissiveMaskContent` from the species' uploaded mask (both are plugin-only properties, so they are set
  here and saved in the .rbxm); count PetRig roles on its bones (require `Shared.Util.PetRig`, count distinct leg chains
  by pair and side). Expected leg chains: Mossling 4, Puddle Crab 8, Cave Bat 2, Spark Beetle 6, Magma Golem 2, Ash
  Wolf 4; wing bones on the bat, arm bones on the golem.
- [ ] **Step 3: The user saves each model** as `assets/monsters/<Species>.rbxm`; Claude checks each appears in the
  synced `ReplicatedStorage.MonsterModels` before deleting the workspace copy (asked).
- [ ] **Step 4: Write the failing test** for the effect config:

```lua
["the beetle sparks at its pincers and the wolf smokes at its tail"] = function()
	expect.equal(wild.SPECIES["Spark Beetle"].fx.kind, "sparks", "beetle")
	expect.equal(#wild.SPECIES["Spark Beetle"].fx.bones, 2, "both pincers")
	expect.equal(wild.SPECIES["Ash Wolf"].fx.kind, "smoke", "wolf")
	assert(wild.FX_RANGE > 0, "effects have a range")
end,
```

  Run `lune run tests/run MonsterLooks`. Expected: FAIL (no `fx`).
- [ ] **Step 5: Implement the effects** in `MonsterController`: for a species with `fx`, parent a ParticleEmitter
  (sparks: small bright yellow flicks; smoke: soft grey wisps; their numbers in `Config/Wild` next to `fx`) to each named
  bone (a Bone is an Attachment); enable them only while the camera is within `Wild.FX_RANGE` and `Extras.enabled()`.
  Run the tests. Expected: all pass.
- [ ] **Step 6: Look at it in Studio** (stop → Play, `/wild`): each species walks the valley at its height; the bat flies
  with beating wings; the beetle uses its six legs, the crab its eight; the golem lumbers and stomps; the wolf roars
  with a shockwave; the glow shows day and night (`/time night`), the golem's lava pulses; sparks and smoke near the
  camera; `/elite` next to you is 1.35x and animates; Output clean. Tune `CREATURE_STYLE`, glow strengths and effect
  numbers in Config, Lune after each change. Screenshot each species for the user.
- [ ] **Step 7: Commit** the six .rbxm files, the config and the controller (`Wild monsters: the six models in game,
  glow and effects`).

### Task 10: Measure the valley, and docs

**Files:** Modify `DESIGN.md`, `docs/creatures.md`, `CLAUDE.md`; the Obsidian vault.

- [ ] **Step 1: Measure** as round 2 did (DESIGN 10.5): render CPU and fps at graphics levels 1 and 10 at the meadow
  with `/crowd 11` (24 monsters), the gorge and the ridge. Expected: 60 fps everywhere. If not, only the nearest monsters
  animate their bones (a cap in `Config/Wild`, picked like `CreatureCull`), with a Lune test, then measure again.
- [ ] **Step 2: Docs.** DESIGN: the Wild monsters paragraph (models, sizes by species, glow, effects), the file tree
  (`Util/MonsterLooks`, `assets/monsters`), 10.5 numbers. `docs/creatures.md` "Wild monsters": the image-to-3D way the
  models were made, the rig scripts, glow masks on a SurfaceAppearance, `Fx_` bones, heights in `Config/Wild`.
  CLAUDE.md: `MonsterLooks` in the test list. Obsidian: a monster roster note (the six, their designs and Meshy jobs),
  the decisions log, lessons learned.
- [ ] **Step 3: Full suite, build, commit** (`lune run tests/run`; `rojo build -o "$TEMP/test.rbxl"`; commit
  `Wild monsters: measured, docs`).
