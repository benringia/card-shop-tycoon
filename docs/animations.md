# Character animations (swords)

The player's sword moves are keyed in Blender on a copy of the game's standard R15 body and exported to Roblox
KeyframeSequences. Spec: `docs/superpowers/specs/2026-11-02-you-in-the-fight-design.md`.

## Files

| What | Where |
|---|---|
| Rig, keying helpers, preview renders, per-frame export | `tools/blender/anim_kit.py` |
| The starter sword's 12 moves (one function each, timed to `Config/Swords`) | `tools/blender/anim_starter_sword.py` |
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

## Making or changing moves

1. In Blender (through the Blender MCP), with `tools/blender` on `sys.path`:
   `import anim_starter_sword as moves; moves.make("cut2", json_dir, render_dir)` (`make_all` for every move).
2. Show the front and side previews (GIFs at real speed) and get the look approved.
3. `lune run tools/anim/build_kfs` → `assets/animations/StarterSword/*.rbxm` (Rojo syncs them).
4. Studio plays them right away (`SwordAnims` registers a move that has no id yet).
5. Publish: in Studio select each KeyframeSequence under `ReplicatedStorage.SwordAnimations.<Sword>`, right-click →
   Save to Roblox, owned by whoever owns the published game (or it won't play there). Put the ids in
   `Config/Swords` (`"rbxassetid://<id>"`).

Timing: a cut's `Hit` marker and `Config/Swords` `hitAt` must agree (the server lands damage at `hitAt`). If a move's
timing changes, change both, and keep `tests/SwordRules.spec`'s combo power check green.

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

The game (`SwordController`) welds the model by its grip: in the right hand at `Swords.HAND_GRIP`, on the back at
`Swords.BACK_GRIP`, `Swords.BACK_SCALE` times bigger there. Until a model exists it draws a code-built stand-in.
