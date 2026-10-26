"""Rigs Cindercub, a very cute fire bear cub (a Common): generated with Meshy through the Blender MCP from this prompt
(object "Cindercub_Bear" in assets/blender/Cindercub/Cindercub.blend, scaled x0.7 to about 1 m tall), then optimized by
rig_kit.optimize to about 10,000 triangles and one 1024-pixel colour map:

  very cute chubby cartoon fire bear cub, quadruped standing on all four short thick stubby legs with its round body
  horizontal, side view game model, toy-like collectible creature, round plump body, big round head, small round
  ears, big shiny dark eyes, pink blushing cheeks, tiny happy smile, red-orange body, a little flame-shaped tuft of
  fire on top of its head with yellow tips, glowing warm yellow-orange belly patch and paw pads, short stubby tail
  with a tiny flame. Smooth simple rounded shapes, flat clean colors, low poly, no fur detail, no realistic textures,
  mythical creature, one solid closed shape

Meshy stood it upright like a teddy bear instead of on four legs; kept, as it walks on two short legs with its paws
resting on its tummy. Before rigging, vertices within 4 mm were merged and small holes filled (the reduced mesh had
hairline cracks). Bone positions are read off that mesh. Writes assets/blender/Cindercub/Cindercub.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.22), (0, 0.0, 0.36)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.36), (0, -0.02, 0.45)),
    ("Spine_1", "Spine_0", (0, -0.02, 0.45), (0, -0.04, 0.55)),
    ("Neck", "Spine_1", (0, -0.04, 0.55), (0, -0.06, 0.62)),
    ("Head_0", "Neck", (0, -0.06, 0.62), (0, -0.12, 0.9)),
    # A short flame tail, a little off centre
    ("Tail_0", "Pelvis", (0.03, 0.24, 0.2), (0.06, 0.3, 0.19)),
    ("Tail_1", "Tail_0", (0.06, 0.3, 0.19), (0.09, 0.37, 0.2)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.17, -0.12, 0.82), (sx * 0.23, -0.13, 0.93)),
        # Arms hang from the shoulders with the paws resting on the tummy
        (f"Arm_{side}_0", "Spine_1", (sx * 0.19, -0.06, 0.48), (sx * 0.24, -0.12, 0.39)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.24, -0.12, 0.39), (sx * 0.24, -0.2, 0.31)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.24, -0.2, 0.31), (sx * 0.22, -0.25, 0.28)),
        # Short legs: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.12, -0.05, 0.24), (sx * 0.13, -0.06, 0.13)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.13, -0.06, 0.13), (sx * 0.13, -0.06, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.13, -0.06, 0.05), (sx * 0.13, -0.15, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.24
params.leg_full = 0.14
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.22
params.head_from = 0.2  # the head sits right over the body, so it's split from the body by height alone (Neck/Head
# bones are nearest up there)
params.arm_core = 0.035
params.arm_radius = 0.07

rig_kit.run("Cindercub", "Cindercub_Bear", BONES, params)
