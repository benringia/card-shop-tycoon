"""Rigs Gale Sprite, a mythical storm swift (a Rare, slightly fierce; a full redesign replacing the bought NeonSwallow,
the last bought model): generated with Meshy through the Blender MCP from this firm prompt (object "GaleSprite_Src",
scaled x1.43 to 1 m tall):

  chunky cartoon mythical storm swift bird, rare lightning creature, slightly fierce. Standing upright on two short
  thick legs with small talons, plump round body, big round head facing straight forward, not turned. Both wings
  spread straight out to the sides, wide open, level and symmetric. Smooth simple solid body, no feather strands. Deep
  blue body with a white belly, fierce glowing yellow eyes, a small sharp yellow beak, a swirling wind-shaped crest on
  its head. Main feature: bright glowing yellow lightning bolt shapes on both wings, and a fluffy grey storm-cloud
  tail crackling with small yellow lightning. Flat clean colors, low poly, toy-like collectible. Perfectly
  symmetrical. Isolated single character only: no base, no ground, no props. One solid shape.

Right first time: wings spread wide and level, yellow lightning sparks off both wings (thin strands, kept by the fine
remesh), a silver wind crest, a fluffy grey cloud puff on a long tail. 1.8M triangles, so rig_kit.remesh_bake (voxel
3.5 mm, 10,000 triangles, colours baked) into "GaleSprite_Swift" in assets/blender/GaleSprite/GaleSprite.blend.

It flies, wings beating on Wing_ bones; legs tucked; tail trailing. Bone positions are read off that mesh. Writes
assets/blender/GaleSprite/GaleSprite.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.42, 0.24), (0, -0.44, 0.38)),
    ("Spine_0", "Pelvis", (0, -0.44, 0.38), (0, -0.45, 0.52)),
    ("Neck", "Spine_0", (0, -0.45, 0.52), (0, -0.46, 0.66)),
    ("Head_0", "Neck", (0, -0.46, 0.66), (0, -0.62, 0.82)),
    # The long tail out behind with its cloud puff
    ("Tail_0", "Pelvis", (0, -0.3, 0.32), (0, -0.05, 0.3)),
    ("Tail_1", "Tail_0", (0, -0.05, 0.3), (0, 0.25, 0.32)),
    ("Tail_2", "Tail_1", (0, 0.25, 0.32), (0, 0.5, 0.4)),
    ("Tail_3", "Tail_2", (0, 0.5, 0.4), (0, 0.75, 0.5)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Wings spread out to the sides, root to tip
        (f"Wing_{side}_0", "Spine_0", (sx * 0.14, -0.44, 0.55), (sx * 0.33, -0.45, 0.6)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.33, -0.45, 0.6), (sx * 0.52, -0.44, 0.66)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.52, -0.44, 0.66), (sx * 0.74, -0.44, 0.82)),
        # Thin legs to taloned feet
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.08, -0.38, 0.24), (sx * 0.11, -0.36, 0.15)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.36, 0.15), (sx * 0.12, -0.44, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.12, -0.44, 0.05), (sx * 0.11, -0.54, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.24
params.leg_full = 0.16
params.leg_core = 0.03
params.leg_radius = 0.06
params.belly_mid = 0.02
params.tail_from = -0.32
params.head_from = 0.4  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["GaleSprite_Swift"]
rig = rig_kit.build_rig("GaleSpriteRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Wings and their lightning sparks out past the body: wholly to the wing bones by how far out they reach
for side, sign in (("Left", 1), ("Right", -1)):
    for segment, start, full in ((0, 0.13, 0.17), (1, 0.33, 0.37), (2, 0.52, 0.56)):
        rig_kit.reweight(mesh, f"Wing_{side}_{segment}",
                         lambda p, sign=sign, start=start, full=full: rig_kit._ramp(p.x * sign, start, full)
                         if p.z > 0.06 and p.y < -0.2 else 0.0)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("GaleSprite", rig, mesh)
