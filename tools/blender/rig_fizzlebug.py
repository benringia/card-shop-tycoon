"""Rigs Fizzlebug, a very cute electric bumblebee (a Common) that flies: generated with Meshy through the Blender MCP
from this prompt (object "Fizzlebug_Bee" in assets/blender/Fizzlebug/Fizzlebug.blend; Meshy made it 1.3 cm tall,
scaled x77 to 1 m), then optimized by rig_kit.optimize to about 7,700 triangles:

  very cute chubby cartoon bumblebee, mythical electric creature, round plump fuzzy-free ball-shaped body with soft
  yellow and dark navy stripes, big round head, big shiny dark eyes set close together, small centred smile, soft pink
  blush, two short antennae each tipped with a small glowing cyan lightning bolt, two pairs of thick rounded
  translucent lilac wings spread out to the sides, a small rounded glowing cyan stinger, tiny stubby legs tucked
  under. Perfectly symmetrical face. Smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no
  fur detail, no realistic textures. Isolated single character only, nothing else: no base, no ground, no flowers, no
  rocks, no props. One solid closed shape.

Meshy stood it upright with little arms, one pair of wings, ball-tipped antennae, and the stinger as a loose crystal
floating behind it. By hand (no second generation): the loose crystal deleted (vertices with y > 0.26, z < 0.26,
x > 0.09); a glowing cyan cone stinger added on its rear (radius 0.055, 0.14 long, at 0, 0.19, 0.32) and a small
cyan lightning bolt on each antenna tip (rig_kit.bolt), coloured 0.45, 0.95, 1.0 from rig_kit.paint_patch. Vertices
within 1 mm merged and small holes filled.

It flies (Party.CREATURE_MODELS flies = true): one Wing_<Side>_0 bone per wing buzzes, arms and legs dangle. Bone
positions are read off that mesh. Writes assets/blender/Fizzlebug/Fizzlebug.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.0, 0.2), (0, 0.0, 0.36)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.36), (0, -0.02, 0.46)),
    ("Spine_1", "Spine_0", (0, -0.02, 0.46), (0, -0.04, 0.54)),
    ("Neck", "Spine_1", (0, -0.04, 0.54), (0, -0.06, 0.6)),
    ("Head_0", "Neck", (0, -0.06, 0.6), (0, -0.16, 0.86)),
    # The stinger
    ("Tail_0", "Pelvis", (0, 0.08, 0.32), (0, 0.26, 0.32)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Antennae, bolts on their tips
        (f"Ear_{side}_0", "Head_0", (sx * 0.08, -0.3, 0.84), (sx * 0.2, -0.41, 0.98)),
        # One wing on each side, from its root on the back out to the tip
        (f"Wing_{side}_0", "Spine_1", (sx * 0.18, -0.05, 0.67), (sx * 0.35, -0.12, 0.7)),
        # Little arms at its sides
        (f"Arm_{side}_0", "Spine_0", (sx * 0.22, -0.12, 0.46), (sx * 0.28, -0.14, 0.36)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.28, -0.14, 0.36), (sx * 0.3, -0.16, 0.25)),
        # Stubby legs, feet forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.08, 0.2), (sx * 0.11, -0.12, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.12, 0.08), (sx * 0.11, -0.25, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.18
params.leg_full = 0.1
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.1
params.head_from = 0.2
params.arm_core = 0.04
params.arm_radius = 0.07

rig_kit.run("Fizzlebug", "Fizzlebug_Bee", BONES, params, target_tris=8000)
