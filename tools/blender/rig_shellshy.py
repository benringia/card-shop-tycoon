"""Rigs Shellshy, a very cute shy baby sea turtle (a Common): generated with Meshy through the Blender MCP from this
prompt (object "Shellshy_Turtle" in assets/blender/Shellshy/Shellshy.blend, scaled x5 to 0.75 m tall), then optimized
by rig_kit.optimize to about 6,700 triangles:

  very cute chubby cartoon baby sea turtle, mythical tide creature, standing on all four short stubby legs with its
  body horizontal, toy-like collectible creature, big round head poking out shyly, big shiny dark eyes set close
  together, small centred shy smile, soft pink blush, soft mint-green skin, a smooth rounded dome shell of deep teal
  with glowing aqua swirl wave patterns, a small round glowing pearl on top of its head. Perfectly symmetrical face.
  Smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no realistic textures. Isolated single
  character only, nothing else: no base, no ground, no sand, no water, no rocks, no props. Legs clearly separate from
  each other. One solid closed shape.

Came out right first time (one closed piece, four separate flippers). Vertices within 1 mm merged and small holes
filled. It plods on four stubby flippers; the shell rides on the spine. Bone positions are read off that mesh.
Writes assets/blender/Shellshy/Shellshy.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.25), (0, 0.05, 0.27)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.27), (0, -0.2, 0.28)),
    ("Spine_1", "Spine_0", (0, -0.2, 0.28), (0, -0.36, 0.3)),
    ("Neck", "Spine_1", (0, -0.36, 0.3), (0, -0.44, 0.32)),
    ("Head_0", "Neck", (0, -0.44, 0.32), (0, -0.62, 0.36)),
    ("Tail_0", "Pelvis", (0, 0.42, 0.15), (0, 0.52, 0.13)),
    ("Tail_1", "Tail_0", (0, 0.52, 0.13), (0, 0.63, 0.12)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front flippers: shoulder under the shell, elbow, flipper tip
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.18, -0.28, 0.2), (sx * 0.23, -0.31, 0.11)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.23, -0.31, 0.11), (sx * 0.25, -0.32, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.25, -0.32, 0.04), (sx * 0.28, -0.4, 0.02)),
        # Hind flippers
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.16, 0.22, 0.2), (sx * 0.21, 0.25, 0.11)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.21, 0.25, 0.11), (sx * 0.23, 0.26, 0.04)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.23, 0.26, 0.04), (sx * 0.25, 0.33, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.15
params.leg_full = 0.09
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.04
params.tail_from = 0.42
params.head_from = -0.36

rig_kit.run("Shellshy", "Shellshy_Turtle", BONES, params, target_tris=7000)
