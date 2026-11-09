# Character animations (swords)

The player's sword moves are keyed in Blender on a copy of the game's standard R15 body and exported to Roblox
KeyframeSequences. Spec: `docs/superpowers/specs/2026-11-02-you-in-the-fight-design.md`.

## Files

| What | Where |
|---|---|
| Rig, keying helpers, preview renders, per-frame export | `tools/blender/anim_kit.py` |
| The starter sword's 12 moves (one function each, timed to `Config/Swords`) | `tools/blender/anim_starter_sword.py` |
| Background export and 60 fps MP4 previews of the sword moves | `tools/blender/run_sword_moves.py` |
| Exported moves (JSON, not synced) | `assets/blender/Animations/<Sword>/<move>.json` |
| JSON → KeyframeSequence `.rbxm` | `tools/anim/build_kfs.luau` |
| KeyframeSequences (synced to `ReplicatedStorage.SwordAnimations`) | `assets/animations/<Sword>/<move>.rbxm` |
| Published ids | `Config/Swords` → `SWORDS[id].animations` |
| Playing them | `src/client/Util/SwordAnims.luau` |

Moves: `draw, sheath, cut1, cut2, cut3, skill, dodge, flinch, down, getUp, ready, run`. `ready` and `run` loop and
are upper body only, so Roblox's own idle, walk and run keep the legs. Markers: `Hit` (a cut's or the skill's strike
frame, matching `hitAt`), `Grab` (the hand reaches the sword on the back: weld it to the hand), `Release` (back on the
back), `Hold` (the knocked-down pose: freeze until getting up).

## The rig

- Blender is Z up; the character faces -Y and its left is +X. 1 unit = 1 stud. Roblox ↔ Blender axes:
  x_r = -x_b, y_r = z_b, z_r = y_b (matrix `M = ((-1,0,0),(0,0,1),(0,1,0))`, its own inverse).
- The armature object is the HumanoidRootPart (centre 3 studs up). R15 rest joints are axis-aligned with identity
  attachment rotations, so a joint's Transform is just its rotation (and the Root joint's offset).
- Upper-body joints are keyed in Roblox `CFrame.Angles(x, y, z)` degrees (`key_pose`; x raises an arm forward, z swings
  it out to its side, y turns it about the vertical once it's out sideways). Arms trail the body by 1-2 frames.
- Legs are IK with planted ankle targets (`key_foot`, `plant_feet`). A dead-straight leg never bends: each knee has a
  0.06-stud forward pre-bend. Feet don't inherit rotation, so they stay flat.
- Keys go in time order; each joint's quaternion stays on the side of its last key (`make_compatible`), so a full spin
  doesn't flip.
- Roblox animations can't move the HumanoidRootPart: root motion (`key_root`) is baked into the Root joint, and every
  move ends where it started. The dodge's dash is real movement on the client.

## Export

`export_move` samples every other frame (30 a second): each joint's Transform in Roblox axes as a quaternion, the Root
joint's offset too: `T_r = M · (Fp⁻¹ · Fc) · M` with `F = pose_bone.matrix @ rest_rot⁻¹`. `build_kfs` writes one
Keyframe per sample (linear easing) with a Pose per moved joint; a joint's parents are added at weight 0 when the move
leaves them alone.

## Natural motion (the sword moves, spec 2026-11-04-sword-moves-design)

Moves that feel anime / hack-and-slash rather than stiff use three helpers in `anim_kit`:

- **Per-key easing:** `key_pose(..., ease=SOFT|SNAP|HOLD)`, `key_root(..., ease=...)`, `key_foot(..., ease=...)` record how
  each curve leaves that key; `apply_eases(rig)` writes them once the move is keyed. SOFT (sine in-out) for wind-ups and
  recoveries, SNAP (exponential ease-out) into and out of a strike (a 3-frame swing that settles), HOLD (linear) through
  a spin. Keys without an ease keep Blender's default curve, so the older moves export exactly as before.
- **Overlap:** `key_pose(..., lag=LAG_SWORD)`: the hips lead, then the chest (1 frame), head (2), shoulder (1), elbow (2),
  wrist (3), the free arm 2-4: a whip instead of every joint moving together.
- **Two hands:** `two_hands(rig, F, on, full, release, off)`: the left forearm's IK reaches the sword's handle under the
  right hand (an empty on the RightHand bone), its influence keyed in and out.

Export these at every frame (`export_move(..., step=1)`, 60 a second) and **in place** (`in_place=True`): the root's
travel stays keyed (it drives the preview and `Config/Swords` lunges) but is left out of the animation, because the
game moves the character for real. `render_video(path, first, last, cam, target)` writes a 60 fps MP4 preview.

Blender runs these in the **background** (`blender.exe -b --factory-startup --python <script>`), never in the owner's
open file: `build()` empties the scene.

The four moves made this way (`anim_starter_sword.NATURAL`; the game's side is in DESIGN.md "Sword moves round"):

| Move | Length | `Hit` | Cancel point | Lunge (the game's) |
|---|---|---|---|---|
| `cut1` forehand, a snapped diagonal cut down across | 0.60 s | 0.217 s | 0.34 s | 1.1 studs, 0.167-0.25 s |
| `cut2` backhand, a rising sweep from low left | 0.58 s | 0.183 s | 0.32 s | 0.8 studs, 0.133-0.22 s |
| `cut3` finisher, both hands: crouch, a 5-stud spinning leap, a slow-motion hang (0.31-0.56 s), a slam stabbing the sword into the ground, kneeling head bowed | 1.25 s | 0.70 s | (its end) | 3.0 studs, 0.17-0.66 s |
| `skill` the dash slash: draw stance, dash, frozen follow-through | 1.0 s | 0.62 s (the cut lines) | (its end) | the dash: 9 studs, 0.30-0.42 s |

Export them (and previews) with
`"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- [--preview <dir>] [move ...]`,
then `lune run tools/anim/build_kfs`. In these angles a positive x tips the waist or the head **back** (a head
"facing the sky"); lean forward and bow with negative x. The cancel points and lunges live only in `Config/Swords` (the next cut may start
at the cancel point; `SwordController` moves the character); keep them in step with the keys' follow-through and root
travel.

## The round 1 swords' skills (sword skills round, spec 2026-11-06-sword-skills-design)

Each round 1 sword swings the starter sword's cuts (shared ids) and its own skill, keyed on `anim_kit` in its own file
and exported in place at 60 fps. In a background Blender:
`"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword <name> [--preview <dir>]`
(`<name>` is the file's: `forge_sword`, `verdant_blade`, `sunforged_blade`, `prism_blade`; previews are
`<name>-skill-<front|side>.mp4`), then `lune run tools/anim/build_kfs assets/blender/Animations/<Folder> assets/animations/<Folder>`.
The file's `FOLDER` is the moveset's `model` in `Config/Swords` (where `SwordAnims` finds the move in Studio).

| Sword (file) | Skill | Length | Markers (`Config/Swords` skill) |
|---|---|---|---|
| Forge Sword (`anim_forge_sword.py`) | Elemental Spin: wound back, two turns with the blade out at waist height, a crouched finish | 1.1 s | `Hit` 0.8 (`hitAt`) |
| Verdant Blade (`anim_verdant_blade.py`) | Thornline: a hop with the blade hanging vertical, plunged into the ground, held, a shove as the vines snap, wrenched free | 0.95 s + the hold | `Hit` 0.45 (`hitAt`: the vines leave), `Hold` 0.5 (`hold.at`; the next key at 0.58 is `hold.snap`) |
| Sunforged Blade (`anim_sunforged_blade.py`) | Sunfall Cleave: crouch, a 5-stud jump arched back, a 1.2 s charge at the top, a cleave in the air, a low landing | 2.45 s | `Hit` 1.78 (`hitAt`) |
| Prism Blade (`anim_prism_blade.py`) | Prism Judgment: crouch, the blade swept to the sky, snapped down pointing at the boss, a punch per strike, swept up for the pillar | 1.75 s | `Hit` 0.6 (`hitAt`: the first strike; the rest `shape.gap` apart) |

- **Held moves**: Thornline's length doesn't include its hold. The game freezes the track at `hold.at` for
  `SwordRules.holdFor(hitAt, travel, hold.snap)` seconds so its snap key plays as the vines reach the foe
  (`SwordController`'s `holdPose`; the preview the same through `SwordController.HoldSkill`). Its preview video keys a
  typical 0.5 s hold in (`PREVIEW_HOLD_SHOWN`); the export never does.
- **Blade vertical**: with the sword's grip, a blade hanging point-down needs the wrist bent well down, more the higher
  the hands (Thornline: -135 at the chest, -195 overhead), keyed without the overlap lag (a trailing wrist tips it).
- **Whole-body turns** (Elemental Spin): a key every quarter turn on the hips' yaw (quaternions stay on their side),
  the feet turned with it round the spot (`_feet_turned`).
- Studio plays these from their KeyframeSequences until the owner publishes them (Save to Roblox under
  `ReplicatedStorage.SwordAnimations.<Folder>`; the id goes in that moveset's `animations.skill`).

## The spear moves (weapons round 2, spec 2026-11-07-weapons-round2-design)

`tools/blender/anim_spear.py` (`PROP = "spear"`, `FOLDER = "Spear"`) keys the spear moveset on `anim_kit.build("spear")`:
a spear prop (8.5 studs, held 31% up from the butt) at `hand_grip("spear")`, angleX -90, so a hanging arm holds it
straight ahead. A pose names the spear's pitch, not the wrist: `arm(shoulder, elbow, pitch)` sets the wrist so the
pitch is about the sum of the three x angles; its yaw comes from turning the hips and waist. The right arm is keyed
without the sword's overlap lag (`LAG_SPEAR`: only the waist, the neck and the free left arm trail; a lagging wrist
pointed the spear up on every snap). Two-handed moves bring the left hand 1.5 studs up the shaft (`two_hands(...,
family="spear")`). Moves: ready (upright at the right side), draw, sheath, run, Thrust (a deep 2-stud lunge), Sweep (a
full spin, the hit on its first pass across the front), Sky Pierce (a 6-stud spinning leap, a plunge) and Piercing Rush
(a 12-stud rush, the Hit as it arrives); dodge, flinch, down and get up reuse the Steel Sword's. Export and previews:
`run_sword_moves.py -- --sword spear [--preview <dir>]`, then `lune run tools/anim/build_kfs assets/blender/Animations/Spear
assets/animations/Spear`; `Config/Swords spear` timings follow the markers (tests/SwordsConfig).

**Titan's Wrath** (weapons round 2.5, the Titan's Lance's own skill): `tools/blender/anim_titans_lance.py`
(`FOLDER = "TitansLance"`, skill only) keys it on anim_spear's helpers: into both hands and a low wide stance, the
lance drawn far back, a trembling charge (alternating keys every 0.07 s, growing) that sinks and coils further to the
deepest coil at 1.22 s, the thrust's "Hit" at 1.35 s, held while the fissure tears, back to the guard by 2.2 s; no
root travel. `run_sword_moves.py -- --sword titans_lance [--preview <dir>]`, then `lune run tools/anim/build_kfs
assets/blender/Animations/TitansLance assets/animations/TitansLance`; `Config/Swords titansLance` (moveset `model`
"TitansLance": the skill's published id 108621386304529, 2026-11-08; the cuts use the spear's ids).

**Magma Cleave and Torrent Strike** (weapons round 2.5 part 2, the Halberd's and the Trident's own skills):
`tools/blender/anim_magma_halberd.py` (`FOLDER = "MagmaHalberd"`) and `anim_tidal_trident.py` (`FOLDER =
"TidalTrident"`), skill only, on anim_spear's helpers. The Halberd: into both hands, pulled back over the right shoulder
(the torso wound right), one huge swing right to left ("Hit" at 0.6), carried round low on the left, back up by 1.2.
The Trident: up into both hands and high overhead (Sky Pierce's raised poses, no leap), whipped down tip-first into
the ground ahead ("Slam" at 0.55), crouched leaning on the stuck shaft ("Hit" at 0.75) and held to 1.5, pulled free by
1.9. The stuck shaft leans about 37 degrees (the waist's bend adds to the arm's pitch: Sky Pierce's -62 sank it straight
down 4 studs into the ground). `run_sword_moves.py -- --sword magma_halberd` / `tidal_trident`, then `build_kfs` into
`assets/animations/<FOLDER>`. Published 2026-11-09: `SwordAnimations.MagmaHalberd.skill` 139376815690800 and
`SwordAnimations.TidalTrident.skill` 97640469455794 (`Config/Swords` `ownSkill`'s skill animation; the cuts use the
spear's ids). Without ffmpeg, preview stills come from the module's own `make(name, json_dir, render_dir)` in a
background Blender (PNG frames every other frame).

## The scythe moves (weapons round 3, spec 2026-11-09-weapons-round3-scythes-design)

`tools/blender/anim_scythe.py` (`PROP = "scythe"`, `FOLDER = "Scythe"`) keys the scythe moveset on
`anim_kit.build("scythe")`: a blocky scythe prop shaped like the Storm Reaper (`SCYTHE_LENGTH` 8.6 studs, held a third
up from the butt, the socket at the top and the blade 3.2 studs out to +X with its tip hanging to 3.4 over the grip),
at `hand_grip("scythe")`: the spear's tilt (-90) and a half turn round the shaft (twist 180; the imported models carry
their blade along +X), so the blade sits to the left of the right hand: over the head when upright. It uses the
spear's helpers (`arm(shoulder, elbow, pitch)`, two hands 1.5 studs up the shaft, the waist and neck trailing). Body
yaw: + turns to the left. Moves: ready (upright at the right side; the wrist turns the scythe a quarter round its shaft, `HOLD_TURN`, so the blade faces forward: owner 2026-11-09), draw, sheath, run (the same turn), Reap
(wound back over the right shoulder, one flat sweep right to left, the tip leading, "Hit" 0.34 of 0.85, a 1.1-stud
step), Back Sweep (crouched, a full spin to the left: the blade across the front, behind you and through the front
again, "Hit" 0.42 of 0.9), Whirlwind (two spins with the scythe held out at shoulder height, "Hit" 0.98 of 1.7) and
Reaping Cyclone (three spins with it raised high, rising onto the toes, "Hit" on the third, 0.94 of 1.6).
`run_sword_moves.py -- --sword scythe [--preview <dir>]`, then `lune run tools/anim/build_kfs
assets/blender/Animations/Scythe assets/animations/Scythe`; `Config/Swords scythe` timings follow the markers
(tests/SwordsConfig). Published by the owner 2026-11-09 (`SwordAnimations.Scythe.<move>`: cut1 84614363717630, cut2
101503127287374, cut3 112263670560674, skill 133282199201010, draw 120963161842619, sheath 87007060779059, ready
107381698123347, run 93344115404944); dodge, flinch, down and get up stay the Steel Sword's.

## Making or changing moves

1. In a background Blender (`run_sword_moves.py`, above; the older moves the same way with their names), or through
   the Blender MCP in a scratch file, never the owner's open one:
   `import anim_starter_sword as moves; moves.make("cut2", json_dir, render_dir)` (`make_all` for every move).
2. Show the front and side previews (GIFs at real speed) and get the look approved.
3. `lune run tools/anim/build_kfs` → `assets/animations/StarterSword/*.rbxm` (Rojo syncs them).
4. Studio plays them right away (`SwordAnims` registers a move that has no id yet).
5. Publish: in Studio select each KeyframeSequence under `ReplicatedStorage.SwordAnimations.<Sword>`, right-click →
   Save to Roblox, owned by whoever owns the published game (or it won't play there). Put the ids in
   `Config/Swords` (`"rbxassetid://<id>"`). The sword moves round's `cut1`, `cut2`, `cut3` and `skill` are still `""`
   (Studio only) until the owner does this; the branch merges after.

Timing: a cut's `Hit` marker and `Config/Swords` `hitAt` must agree (the server lands damage at `hitAt`). If a move's
timing changes, change both, and keep `tests/SwordRules.spec`'s combo power check and `tests/SwordsConfig.spec`'s
damage-a-second check (the chained cycle within 2 % of before) green; re-run both balance sims.

## Bone rigs (monster and boss attacks)

Monsters and bosses are skinned meshes with bones (`tools/blender/rig_kit.py`, one `rig_<model>.py` each), not R15
bodies. Their attack clips (spec `docs/superpowers/specs/2026-11-02-attack-animations-design.md`) use their own
pipeline:

| What | Where |
|---|---|
| Keying helpers and export | `tools/blender/anim_bone_kit.py` |
| A model's clips (one script per model) | `tools/blender/anim_<model>.py` |
| Exported clips (JSON, not synced) | `assets/blender/Animations/<model>/<clip>.json` |
| JSON → KeyframeSequence `.rbxm` | `lune run tools/anim/build_bone_clips <model>` |
| KeyframeSequences (synced to `ReplicatedStorage.MonsterAnimations/<model>`) | `assets/monster-animations/<model>/<clip>.rbxm` |
| Playing them | `src/client/Util/ClipPlayer.luau` |

- **Model space, not bone space.** `rig_kit` builds bones from head/tail points, so every bone has its own axes, and
  Roblox's FBX importer turns them again. So clips store each deform bone's rotation in MODEL space (Roblox axes) per
  frame, plus the top bone's offset; `ClipPlayer` turns that into `Bone.Transform` from the bone's rest pose in Roblox:
  `T = R0⁻¹ · Dparent⁻¹ · Dbone · R0`. The KeyframeSequence's attribute `Space = "Model"` marks it.
- Axes: Blender x/y/z → Roblox -x/z/y (`M`, as the sword kit), checked on the Meadow Warden's bones in Studio. Offsets
  are in model-file units; `ClipPlayer` scales them with the model.
- Keying: `key_turn(rig, bone, frame, (x, y, z))` turns a bone about its head by Euler degrees in ARMATURE axes (X the
  model's left, Y its back, Z up) after its parent's pose: an arm hanging down swings forward with a negative X turn.
  Key parents before children and in time order.
- Clips per model: `windup`, `strike` (all), `specialWindup`, `specialRelease` (bosses), marker `Hit` on the strike.
- They play on the client with no upload and no animation ownership (bones are set every frame), blended over the
  procedural motion (`Util/PetAnimator`) for `Party.KEYFRAME_ANIM.ONE_SHOT_BLEND` in and out
  (`KeyframeTiming.oneShotWeight`). A wind-up holds its last pose a moment for its hit, and the strike that follows
  starts at the wind-up's weight, so they chain with no dip: key the strike's first frame as the wind-up's last pose.
- `Util/MonsterMoves` picks the clip for each fight event (charge or quick-hit warning: `windup` over the warning;
  a hit: `strike`; a ring: `specialWindup` timed to its warning; the ring's hit: `specialRelease`); `Util/FightFx`
  plays it through `MonsterController.PlayClip` and draws the boss's effects (`Config/AttackFx` BOSS).
- Bosses keyed so far: `meadowWarden`, `caveBroodQueen`, `emberColossus` (`tools/blender/anim_<boss>.py`). The Prism
  Hydra waits for its remodel. The six valley species' `windup` and `strike` are all in `tools/blender/anim_wild.py`
  (exported under the game's species name, "Ash Wolf"; `lune run tools/anim/build_bone_clips "Ash Wolf"`).
  `anim_bone_kit.key_pose` keys a whole pose parents first, straight from the rig.
- Adding the `MonsterAnimations` mapping needs a `rojo serve` restart (all three project files have it).

## The sword model

The starter sword is built in Blender by `tools/blender/build_starter_sword.py` (sources in
`assets/blender/StarterSword/`): Blade, Guard, Grip and Pommel around the grip's centre (the origin), the blade up.

1. Import `StarterSword.fbx` in Studio (3D Importer, Rig Type None). The model's pivot lands on the grip's centre.
2. Right-click the model → Save to File → `assets/weapons/StarterSword.rbxm`.
3. `lune run tools/weapons/finish_sword`: the importer drops the Blender colours and turns each mesh's PivotOffset, so
   this sets the colours by part name, straightens the pivots and
   makes Grip the PrimaryPart (`tests/CreatureAssets.spec` checks it, and that no script is inside).
4. Rojo syncs `assets/weapons` to `ReplicatedStorage.WeaponModels` (restart `rojo serve` after adding the mapping).

The game (`SwordController`) welds the model by its grip: in the right hand at `Swords.HAND_GRIP` (tilted, then a
quarter turn about the blade so its flat faces the palm; Blender's `anim_kit.hand_grip()` matches), on the back at
`Swords.BACK_GRIP`, `Swords.BACK_SCALE` times bigger there. Until a model exists it draws a code-built stand-in.
