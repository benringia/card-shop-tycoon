# Wild Bosses and Arenas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three Wild bosses (Meadow Warden, Cave Brood Queen, Ember Colossus) get real rigged models at the user's
size B, and each of their arena copies becomes an enclosed place of its own with its own sky, sound and way home.

**Architecture:** Sizes, fight spacing and boss moments are config plus small pure helpers (`Util/MonsterLooks`, a new
`Util/BossMoments`, new functions in `Util/WildValley`), Lune-tested; MonsterController, DayCycleController,
BattleService and WildService wire them in. Boss models follow the Wild monsters' pipeline (picture, Meshy image to
3D, `rig_<boss>.py` on `rig_kit.py`, glow masks); new arena props are Blender-scripted; Studio imports are the user's
hand-off.

**Tech Stack:** Luau (Rojo, `--!strict`), Lune tests, Blender 5.2 + MCP (Meshy), Figma image generation, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-01-wild-bosses-arenas-design.md`

## Global Constraints

- Sizes (studs): Meadow Warden 17 tall; Cave Brood Queen 12 tall (about 24 wide); Ember Colossus 17 tall (about 28
  long). The Prism Hydra stays the biggest (24.5).
- No change to fights: HP, ATK, SPD, levels, drops, keys, mechanics, groups. Bosses keep ids, names, titles, trophies.
- Never animate a SurfaceAppearance (no per-frame `EmissiveStrength`/`EmissiveTint` writes): effects are particles,
  lights and poses.
- New terrain stays within `WildValley.MAX_CELLS` 90k and `Scenery.MAX_CELLS` 230k; walls, roof and rocks are meshes.
- Meshy: about 1,420 credits; ask the user before any regeneration; character-only pictures, neutral poses, bulky,
  smooth. Never print the Meshy key. Before committing a .blend: add-on key fields empty (read with
  `scene.bl_system_properties_get()`, print lengths only), `*_Src` deleted, orphans purged.
- The user approves each boss picture and each Meshy model (turnaround render) before it is rigged, and the arena prop
  renders before they're imported.
- All tunables in `src/shared/Config`; pure modules don't require siblings; UI text plain ASCII plus `·` and emoji.
- 60 fps at graphics levels 1 and 10 in each arena with a fight running.

## Review Focus

1. A boss with no model (missing or over the part cap) still fights as its placeholder at its new height, with no
   moment effects and no errors (Task 1 tests the height; Task 2 tests that moments need their `Fx_` bones).
2. A player who streams into an arena copy mid-fight sees the current state (vents already smoking if enraged) but
   no replayed roar or heal flare (Task 2 tests `BossMoments.roarIn` and `BossMoments.flares` on first sight).
3. Leaving an arena by any way (the home portal, a fight's end, a fall rescue, a teleport) puts the normal sky back,
   and the valley and town never show an arena look (Task 3 tests `arenaZoneAt` returns nil outside the copies).
4. A group fight (several leaders on the ring, `GROUP_SPACING` 7) keeps every fighter inside the fence with the bigger
   ring radii (Task 1 tests `ringRadius <= ARENA_RADIUS - 8`).
5. The Prism Hydra and the Frontier bosses look and behave exactly as before (Task 1 tests their heights; Task 2 tests
   that bosses without `moments` get none).

---

### Task 1: Boss sizes and fight spacing

**Files:**
- Modify: `src/shared/Util/MonsterLooks.luau` (`height`), `src/shared/Config/Bosses.luau` (three boss entries and the
  `Boss` type), `src/client/Controllers/MonsterController.luau` (the `height` call)
- Test: `tests/MonsterLooks.spec.luau`

**Interfaces:**
- Produces: `MonsterLooks.height(world: any, species: string, elite: boolean, bossScale: number?, bossHeight: number?): number`
  — `bossHeight` wins when given; else `world.MONSTER_HEIGHT * bossScale` as today; else the species rules as today.
- Produces: `Boss.height: number?` (studs) on `meadowWarden` 17, `caveBroodQueen` 12, `emberColossus` 17;
  `ringRadius` 15 / 16 / 18; `introShot` `{ back = 34, up = 16 }` / `{ back = 34, up = 16 }` / `{ back = 40, up = 18 }`
  (starting values, retuned in Task 9 with the models; keep them in step with the tests).

- [ ] **Step 1: Write the failing tests** in `tests/MonsterLooks.spec.luau`:

```lua
["the Wild bosses are huge (size B), the final boss still the biggest"] = function()
	local bosses = require("../src/shared/Config/Bosses").BOSSES
	local expected = { meadowWarden = 17, caveBroodQueen = 12, emberColossus = 17 }
	for id, height in expected do
		local boss = bosses[id] :: any
		expect.near(MonsterLooks.height(wild, boss.name, false, boss.scale, boss.height), height, 1e-9, id)
	end
	local hydra = bosses.prismHydra :: any
	local hydraHeight = MonsterLooks.height(frontier, hydra.name, false, hydra.scale, hydra.height)
	expect.near(hydraHeight, frontier.MONSTER_HEIGHT * 7, 1e-9, "the Hydra as before")
	for id, height in expected do
		assert(height < hydraHeight, id .. " outgrows the final boss")
	end
end,

["bosses without a height keep their scale (Frontier bosses unchanged)"] = function()
	local bosses = require("../src/shared/Config/Bosses").BOSSES
	for _, id in { "frostTyrant", "stormSovereign", "riftDevourer" } do
		local boss = bosses[id] :: any
		expect.equal(boss.height, nil, id)
		expect.near(MonsterLooks.height(frontier, boss.name, false, boss.scale, nil), frontier.MONSTER_HEIGHT * boss.scale, 1e-9, id)
	end
end,

["fighters stand clear of the big bosses and inside the fence"] = function()
	local Bosses = require("../src/shared/Config/Bosses")
	for _, id in { "meadowWarden", "caveBroodQueen", "emberColossus" } do
		local boss = Bosses.BOSSES[id] :: any
		assert(boss.ringRadius and boss.ringRadius > Bosses.RING_RADIUS, id .. " needs more room than the default ring")
		assert(boss.ringRadius <= Bosses.ARENA_RADIUS - 8, id .. "'s fighters would stand at the fence")
		assert(boss.introShot and boss.introShot.back > Bosses.INTRO_SHOT.back, id .. " needs a wider intro shot")
	end
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: the three new tests FAIL (height ignores `bossHeight`, no
  `height`/`ringRadius` on the Wild bosses).
- [ ] **Step 3: Implement** the `height` parameter, the config values above (document `height` in the `Boss` type:
  "studs tall; wins over scale"), and pass `if boss then boss.height else nil` in MonsterController.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `Wild bosses: size B heights and room to fight them`.

### Task 2: Boss moments (roar, heal flare, enrage vents, root slam)

**Files:**
- Create: `src/shared/Util/BossMoments.luau`, `tests/BossMoments.spec.luau` (register in `tests/run.luau`)
- Modify: `src/shared/Config/Bosses.luau` (`moments` on the three bosses, `MOMENT_FX`, `ROAR_VOLUME`, the `Boss` type),
  `src/shared/Config/Party.luau` (`CREATURE_STYLE` and `SIGNATURE` for the three, `FIDGET_SECONDS.rootslam`),
  `src/shared/Util/PetRig.luau` (`rootslam`), `src/client/Util/PetAnimator.luau` (`play`),
  `src/client/Util/CreatureVisuals.luau` and `src/client/Util/SignatureFx.luau` (the `rootslam` cue),
  `src/client/Controllers/MonsterController.luau`, `src/server/Services/BattleService.luau`,
  `src/server/Services/WildService.luau` (`SpawnedAt`)
- Test: `tests/BossMoments.spec.luau`, `tests/PetRig.spec.luau`, `tests/MonsterLooks.spec.luau`

**Interfaces:**
- Produces: `BossMoments.roarIn(spawnedAt: number?, now: number, roarAt: number): number?` — seconds until the intro
  roar, or nil when it has passed or the spawn time is unknown.
- Produces: `BossMoments.flares(seen: number?, current: number?): boolean` — true only when `current` rose above a
  count already seen (a first sight never flares).
- Produces: `BossMoments.anchors(moment: any?, boneNames: { [string]: boolean }): { string }?` — the moment's `Fx_`
  bones if the model has all of them, else nil (no model, no effect).
- Produces: marker attributes set by the server: `SpawnedAt` (number, `workspace:GetServerTimeNow()` when a boss
  marker spawns), `Heals` (number, +1 per `heal` event), `Enraged` (true on the `enrage` event).
- Produces: `PetAnimator.play(rig, kind: string, now: number)` — starts that fidget now (cued afresh).
- Produces config: `moments = { roar: string, heal: { bones: { string }, fx: string }?, enrage: { bones: { string },
  burst: string, lasting: string }? }`: Warden `{ roar }`; Brood Queen `{ roar, heal = { bones = { "Fx_Sac" },
  fx = "broodFlare" } }`; Colossus `{ roar, enrage = { bones = { "Fx_Vent_0", "Fx_Vent_1", "Fx_Vent_2" },
  burst = "ventBurst", lasting = "ventSmoke" } }`. `MOMENT_FX` holds emitter numbers in `Wild.FX`'s shape for
  `broodFlare` (violet, a one-off burst), `ventBurst` (embers and smoke, one-off), `ventSmoke` (a slow plume).
  Roar ids are chosen in Step 6 from Roblox's free audio (Creator Store sound effects, `search_asset`).

- [ ] **Step 1: Write the failing tests.** `tests/BossMoments.spec.luau`:

```lua
["the intro roar comes once, at its moment"] = function()
	expect.near(BossMoments.roarIn(100, 100, 1) :: number, 1, 1e-9, "just spawned")
	expect.near(BossMoments.roarIn(100, 100.4, 1) :: number, 0.6, 1e-9, "streamed in early")
	expect.equal(BossMoments.roarIn(100, 103, 1), nil, "joined after the roar")
	expect.equal(BossMoments.roarIn(nil, 100, 1), nil, "no spawn time")
end,
["a heal flares when the count rises, never on first sight"] = function()
	expect.equal(BossMoments.flares(nil, 2), false, "first sight mid-fight")
	expect.equal(BossMoments.flares(2, 2), false, "no change")
	expect.equal(BossMoments.flares(2, 3), true, "healed")
	expect.equal(BossMoments.flares(0, nil), false, "attribute cleared")
end,
["moment effects need their bones"] = function()
	local moment = { bones = { "Fx_Vent_0", "Fx_Vent_1" } }
	expect.equal(BossMoments.anchors(moment, { Fx_Vent_0 = true }), nil, "a bone missing")
	expect.equal(#(BossMoments.anchors(moment, { Fx_Vent_0 = true, Fx_Vent_1 = true }) :: { string }), 2, "all there")
	expect.equal(BossMoments.anchors(nil, {}), nil, "no moment")
end,
["only the three Wild bosses have moments, each with a roar and known effects"] = function()
	local Bosses = require("../src/shared/Config/Bosses")
	for id, boss in Bosses.BOSSES do
		local moments = (boss :: any).moments
		local wildBoss = id == "meadowWarden" or id == "caveBroodQueen" or id == "emberColossus"
		expect.equal(moments ~= nil, wildBoss, id)
		if moments then
			assert(string.match(moments.roar, "^rbxassetid://%d+$"), id .. " has no roar sound")
			for _, kind in { moments.heal and moments.heal.fx, moments.enrage and moments.enrage.burst, moments.enrage and moments.enrage.lasting } do
				assert(Bosses.MOMENT_FX[kind] or kind == nil, id .. ": unknown effect " .. tostring(kind))
			end
		end
	end
end,
```

In `tests/PetRig.spec.luau`: `rootslam` cues at 0.95 (not at 0.5) and its body pose equals `stomp`'s at the same
progress. In `tests/MonsterLooks.spec.luau`: the three boss ids have a `Party.CREATURE_STYLE` with known fidgets (as
the species test), `Party.SIGNATURE.meadowWarden.fidget == "rootslam"`, and the Brood Queen and Colossus have no
random signature (their moments come from the fight).

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (no BossMoments module, no `rootslam`, no moments).
- [ ] **Step 3: Implement the pure parts and config:** `BossMoments` (Roblox-free), `rootslam` in PetRig (the stomp's
  pose and cue), `FIDGET_SECONDS.rootslam = 1.6`, styles: Warden `{ fidgets = { "look", "shake", "stomp" }, bounce =
  0.15, stride = 1.4, legSwing = 0.6, sway = 1.6 }` (two heavy legs, long arms), Brood Queen `{ fidgets = { "look",
  "tilt", "shake" }, bounce = 0.1 }`, Colossus `{ fidgets = { "look", "sniff", "shake", "stomp" }, bounce = 0.2,
  stride = 1.3 }`; `SIGNATURE.meadowWarden = { fidget = "rootslam", chance = 0.3 }`; `moments` with placeholder
  roar ids filled in Step 6.
- [ ] **Step 4: Wire the server:** WildService sets `SpawnedAt` when a boss marker is set up; BattleService's event
  loop (beside the `phase` → `Phase` line) sets `Heals` and `Enraged` on `fight.monster.marker`.
- [ ] **Step 5: Wire the client:** `PetAnimator.play`; the `rootslam` cue draws the stomp's ground ring plus a leaf and
  petal burst (`SignatureFx`); MonsterController, for a boss with `moments`: reads its bone names once, gets anchors
  per moment, and (a) at `roarIn` plays `wildroar` on its rig and a `Sound` (`moments.roar`, `ROAR_VOLUME`) at the
  root, (b) on a `Heals` change that `flares`, a burst on the sac bone, (c) on `Enraged` becoming true a burst and the
  lasting plume on the vents (already true on add: the plume only). Effects follow the `Extras` rule; emitters are
  children of the bones and go with the model.
- [ ] **Step 6: Pick the three roar sounds** with the Studio MCP's `search_asset` (deep, monstrous roars from the free
  library; tree-groan for the Warden, a hiss-shriek for the Brood Queen, a bellow for the Colossus), put the ids in
  config with a comment naming each sound, and play each once in Studio to hear it.
- [ ] **Step 7: Run** `lune run tests/run` and the compile check on the changed files. Expected: all pass.
- [ ] **Step 8: Commit** `Wild bosses: roar, heal flare, enrage vents and the Warden's root slam`.

### Task 3: Each arena's own sky

**Files:**
- Modify: `src/shared/Util/WildValley.luau` (`arenaZoneAt`), `src/shared/Config/DayCycle.luau` (`ARENA_LOOKS`),
  `src/client/Controllers/DayCycleController.luau`
- Test: `tests/WildValley.spec.luau`, `tests/DayCycle.spec.luau`

**Interfaces:**
- Produces: `WildValley.arenaZoneAt(valley: any, copies: number, x: number, z: number): number?` — the zone whose arena
  copy (any of `copies`) holds the point (within `valley.ARENA_HOLD` of its centre on both axes), else nil.
- Produces: `DayCycle.ARENA_LOOKS: { Look }` (by zone): 1 the grove (sunny afternoon, warm sun rays, light haze),
  2 the hollow (dim: low brightness and ambient, cold violet tint, dense haze), 3 the lava field (red-orange tint and
  atmosphere colour, ash-grey decay, dense haze). Every look has every field of the FIXED phase's look.

- [ ] **Step 1: Write the failing tests:** every copy centre of every zone maps to its zone (copies 1..4); points 100
  studs past a centre, the valley's arrival and the town's plaza map to nil; each `ARENA_LOOKS[z]` has the same keys
  as the FIXED look (recursively for `atmosphere`, `bloom`, `sunRays`) and `atmosphere.density >= 0.35` (the haze
  hides what lies past the walls).
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** `arenaZoneAt` and the looks; DayCycleController (main place only) applies
  `ARENA_LOOKS[zone]` at once while the character is in a copy, and otherwise does what it does today.
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `Wild bosses: each arena has its own sky`.

### Task 4: The arena layouts, the way home and the ambient sound

**Files:**
- Modify: `src/shared/Util/WildValley.luau` (`arenaDressing`), `src/shared/Config/WildValley.luau`
  (`ARENA_DRESSING`, `ARENA_HOME`), `src/server/Services/WildService.luau` (replaces `ringProps`; the home portal)
- Test: `tests/WildValley.spec.luau`

**Interfaces:**
- Produces: `WildValley.arenaDressing(valley: any, ringRadius: number, zone: number, seed: number): { { model: string,
  x: number, z: number, height: number, yaw: number, y: number? } }` — offsets from the copy's centre.
- Produces config `ARENA_HOME = { distance = 46, { model = "PortalWild", look = "Wild" }, { model = "PortalFrontier",
  look = "Frontier" }, { model = "PortalArena", look = "Arena" } }` (the way home 46 studs out on -X, inside the walls)
  and `ARENA_DRESSING[zone] = { walls = { models, rows = { { radius, count } }, height = { min, max } }, inner = {
  models, count, radius = { min, max }, height = { min, max } }, roof = { model, height }?, backdrop = { model,
  distance, height }?, effects = { string }, sound = { id, volume, range } }`. Starting content:
  - zone 1 grove: walls `StandingStone`, `TreeA`, `TreeB`, `TreeC` in rows at radius 54 and 59 (24 and 28 pieces),
    30-44 tall; inner `FlowerPink`, `FlowerWhite`, `FlowerYellow`, `Bush`, `RootsLarge`; the meadow's fireflies and
    leaves; birdsong and wind in leaves.
  - zone 2 hollow: walls `Stalagmite`, `RockA`, `RockB`, 18-30 tall; inner `Web`, `Cocoon` (hung: `y` near the roof),
    `Bones`, the gorge's crystals; roof `CaveDome`; dripping, a low hum, skittering.
  - zone 3 lava field: walls `LavaCliff` in one row at radius 57, 32-40 tall; inner `CharredTree`, `ObsidianShards`;
    backdrop `Volcano` 150 studs out on +X, 130 tall; embers and ash; rumbling and crackling lava.
  New model names (`StandingStone`, `Stalagmite`, `Web`, `Cocoon`, `Bones`, `CaveDome`, `LavaCliff`) come from Task 5;
  until saved, ScenePieces warns and skips them.

- [ ] **Step 1: Write the failing tests:** for each zone and a few seeds: wall rows go all the way round (each row's
  spacing `2 * pi * radius / count <= 14` studs) at radii inside the clearing (`radius + 4 <= ARENA_CLEARING.size / 2`);
  every inner piece stands outside the fight ring (`distance > ringRadius + 4` for the zone's boss and
  `> Bosses.ARENA_RADIUS + 2`), off the path (not `x < -Bosses.ARENA_RADIUS and |z| < 8`) and at least 8 studs from
  the way home (`(-ARENA_HOME.distance, 0)`); the same seed gives the same layout; only zone 2 has a roof and only
  zone 3 a backdrop; each zone has an ambient sound id `rbxassetid://<digits>` and a positive range under
  `ARENA_FIELD.spacing / 2`; `ARENA_HOME` lists three portal models that exist in `assets/props` and looks that exist
  in `Town.PORTAL_LOOKS`, at a distance between `ARENA_RADIUS + 6` and the inner walls.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3: Implement** `arenaDressing` (walls at even angles with a small seeded jitter, inner pieces by seeded
  rejection sampling under the rules above) and the config; pick the three ambient sounds with `search_asset`.
- [ ] **Step 4: Wire WildService:** each copy places its dressing (anchored, `CastShadow` off on pieces under 4 studs),
  the roof and backdrop, its zone's area effects, a looping positional ambient `Sound` at the centre, and its way home
  from `ARENA_HOME[zone]` (scaled to its slot height, dressed with `Town.PORTAL_LOOKS[look]`) instead of the root arch.
  The Return prompt stays on the portal.
- [ ] **Step 5: Run** `lune run tests/run`, `rojo build -o "$TEMP/test.rbxl"`. Expected: all pass, it builds.
- [ ] **Step 6: Commit** `Wild bosses: arena layouts, the way home and their sound`.

### Task 5: The arena props (Blender)

**Files:**
- Create: `tools/blender/build_arena_props.py`, `assets/blender/ArenaProps/` (`ArenaProps.blend`, one `<Name>.fbx` per
  prop, renders)

**Interfaces:**
- Produces seven props, each one object exported as `assets/blender/ArenaProps/<Name>.fbx` (1 m = 1 stud scale noted in
  the script; the game scales them by height): `StandingStone` (a tall rough menhir with moss on top and a few carved
  rune lines), `Stalagmite` (a tapering cave spike with drips), `Web` (a flat round web, a few strands, white-grey),
  `Cocoon` (a hanging wrapped shape on a strand), `Bones` (a ribcage half sunk with a skull and scattered bones),
  `CaveDome` (one closed shell about 132 wide and 46 high: rough rock walls curving into a roof, faces facing inward,
  its rim below floor level so no gap shows), `LavaCliff` (a basalt cliff segment about 16 wide with glowing cracks).
  Smooth stylized shapes and flat colours like the caldera's props (`build_volcano.py`, `build_charred_tree.py`), few
  triangles (under 3,000 each; the dome under 6,000).

- [ ] **Step 1: Write `build_arena_props.py`** (one function per prop, shared materials, an export per prop).
- [ ] **Step 2: Run it in Blender** through the MCP. Expected: seven FBX files and their triangle counts printed.
- [ ] **Step 3: Render** each prop (and the dome from inside) with `look`, put the renders on a companion page and
  **ask the user to approve them**; adjust what they ask.
- [ ] **Step 4: Save the .blend clean** and commit (`Wild bosses: arena props in Blender`).

### Task 6: The Meadow Warden's model

**Files:**
- Create: `assets/blender/MeadowWarden/` (`MeadowWarden_concept.png` copied from `boss-w1.png`, `MeadowWarden_sheet.png`,
  `.blend`, `.fbx`, `_color.png`, `_glow.png`), `tools/blender/rig_meadowwarden.py`

**Interfaces:**
- Consumes: `rig_kit.optimize`, `remesh_bake`, `build_rig`, `skin`, `export`, `glow_mask` (as in the monster rigs).
- Produces: `MeadowWarden.fbx` with a biped rig like `rig_magmagolem.py`: `Root`, `Pelvis`, `Spine_0`, `Spine_1`,
  `Neck`, `Head_0` (the antler boughs ride the head), long arms `Arm_<Side>_0..2` reaching the ground, legs
  `0_<Side>_Limb_0..2`; no jaw (a stone mask). Glow: the green eyes only. Up to 8,000 triangles.

- [ ] **Step 1: The sheet picture.** Generate a clean character picture of the picked design (Figma,
  `gemini-3.1-flash-image`): the Elder Warden from the spec, standing square, arms slightly out, front three-quarter
  view, plain white background, nothing else in the picture; cut it out (`MeadowWarden_sheet.png`); show it with the
  concept and **ask the user to approve it**.
- [ ] **Step 2: Meshy image to 3D** through the Blender MCP from the sheet. Render a turnaround (front, side, back,
  three-quarter) on a companion page and **ask the user to approve the model** (a redo only with their OK).
- [ ] **Step 3: Write and run `rig_meadowwarden.py`** (scale to 1 m like the golem, bones read off the mesh, glow
  rules). Expected printout: the FBX path, the glow path, triangles ≤ 8,000.
- [ ] **Step 4: Check it** as the monster rigs were checked: bone names, at most 4 influences, no unweighted vertices,
  a posed arm and head follow without tearing, the glow mask white on the eyes only.
- [ ] **Step 5: Save the .blend clean and commit** (`Wild bosses: the Meadow Warden's model and rig`).

### Task 7: The Cave Brood Queen's model

**Files:** Create `assets/blender/CaveBroodQueen/` (concept from `boss-q2.png`, sheet, `.blend`, `.fbx`, color, glow),
`tools/blender/rig_cavebroodqueen.py`

**Interfaces:** Consumes Task 6's recipe. Produces a rig with legs in four pairs `0..3_<Side>_Limb_0..1` (the tested
eight-leg wave), wings `Wing_<Side>_0..1` (folded on the back), `Head_0`, `Jaw_0` (the fangs), the body on
`Pelvis`/`Spine_0`, and a zero-influence `Fx_Sac` at the egg sac's centre (left out of skinning). Glow: the violet eyes
and the egg sac. Up to 8,000 triangles.

- [ ] **Steps 1-5 as Task 6**, the sheet showing her legs spread wide and symmetric, wings half open, top-front
  three-quarter view. **Fallback (spec call 2):** if Meshy fuses or loses legs or wings, build those parts by script in
  the rig file and join them to the generated body, then show the user the result before rigging. Commit
  `Wild bosses: the Cave Brood Queen's model and rig`.

### Task 8: The Ember Colossus's model

**Files:** Create `assets/blender/EmberColossus/` (concept from `boss-c3.png`, sheet, `.blend`, `.fbx`, color, glow),
`tools/blender/rig_embercolossus.py`

**Interfaces:** Consumes Task 6's recipe. Produces a quadruped rig: `Root`, `Pelvis`, `Spine_0`, `Spine_1`, `Neck`,
`Head_0`, `Jaw_0`, legs `0_`/`1_<Side>_Limb_0..2`, and zero-influence `Fx_Vent_0..2` at the three vents on its back.
Glow: the lava between the plates, the eyes and the mouth. Up to 8,000 triangles.

- [ ] **Steps 1-5 as Task 6**, the sheet showing it square on all four legs, facing forward, three-quarter view, built
  like an armoured rhino (horned head, domed basalt back, no turtle shell rim). Commit
  `Wild bosses: the Ember Colossus's model and rig`.

### Task 9: Into Studio, and tuning

**Files:**
- Create (the user saves): `assets/monsters/meadowWarden.rbxm`, `caveBroodQueen.rbxm`, `emberColossus.rbxm`;
  `assets/props/StandingStone.rbxm`, `Stalagmite.rbxm`, `Web.rbxm`, `Cocoon.rbxm`, `Bones.rbxm`, `CaveDome.rbxm`,
  `LavaCliff.rbxm`
- Modify: config numbers found while tuning
- Test: `tests/WildValley.spec.luau`

- [ ] **Step 1: Hand-off.** Ask the user to import the three boss FBX files (Rig Type Custom, Keep Zero Influence
  Bones) and the seven prop FBX files, and to upload the three glow masks. Then (Studio MCP, after asking): reset each
  MeshPart's `PivotOffset` rotation, give each boss MeshPart a SurfaceAppearance (`ColorMapContent` = its TextureID,
  `EmissiveMaskContent` = its glow id), anchor the props, and ask the user to save each into the paths above.
- [ ] **Step 2: Write the failing test:** every model named in `ARENA_DRESSING` (walls, inner, roof, backdrop) exists
  as `assets/props/<name>.rbxm`. Run it before the saves (FAIL), after (PASS). The existing model script gate covers
  the new files.
- [ ] **Step 3: Play-check each arena** (Studio MCP): each copy's look, its sky, the way home, the sound; screenshots
  from the fight camera and at full zoom out (no empty sky past the walls); the cave dark but readable.
- [ ] **Step 4: Fight each boss** (fire the Summon remote from the client, then `/boss <1-3> fight`): the intro roar
  (pose and sound), the size and the ring, the Brood Queen's flare on a heal and the Colossus's vents on its enrage (a
  strong party from `/maxcard` gets them below half), the Warden's root slam while it idles. Tune `height`,
  `ringRadius`, `introShot`, moment effects and sound volumes; keep Task 1's tests in step.
- [ ] **Step 5: Run** `lune run tests/run`; commit the rbxm files and tuning (`Wild bosses: the models and props in game`).

### Task 10: Measure, and docs

**Files:** Modify `DESIGN.md`, `docs/creatures.md`, `docs/props.md`, `CLAUDE.md`; the Obsidian vault.

- [ ] **Step 1: Measure** in Play from fixed cameras: render CPU and fps at graphics levels 1 and 10 in each arena with
  a fight running, plus the valley's arrival and the town street as controls. Expected: 60 fps everywhere. If not,
  find the cost by taking pieces away one kind at a time (as the monster round did) and fix it.
- [ ] **Step 2: Docs.** DESIGN: section 5.10 (the bosses' looks, sizes, moments), the Wild valley's arena paragraph
  (layouts, skies, ways home, sound), the file tree (`Util/BossMoments`, new props, rig scripts), 10.5 numbers;
  docs/creatures.md (the three boss models: pictures, Meshy, rigs, `Fx_` bones, moments); docs/props.md (the arena
  props and `build_arena_props.py`); CLAUDE.md (`BossMoments` in the test list); Obsidian: boss roster, decisions,
  lessons.
- [ ] **Step 3: Full suite, build, commit** (`lune run tests/run`; `rojo build -o "$TEMP/test.rbxl"`;
  `Wild bosses: measured, docs`).
