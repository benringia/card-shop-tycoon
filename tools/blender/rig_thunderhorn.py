"""Rigs Thunderhorn, a massive thunder stag (an Epic, so very dangerous and big): generated with Meshy through the
Blender MCP from this prompt (object "Thunderhorn_Stag" in assets/blender/Thunderhorn/Thunderhorn.blend, scaled x0.5 to
1 m tall), then optimized by rig_kit.optimize to about 8,700 triangles:

  massive powerful mythical thunder stag, very dangerous, huge heavy bulky muscular body, thick strong legs with gold
  hooves, broad chest, cream-white coat, a simple smooth short cream mane on its neck, fierce glowing yellow eyes, gold
  armor plates on its forehead, chest and shoulders, huge thick chunky golden antlers with few wide branches and
  glowing yellow lightning tips, short tail. Standing proudly on four legs. Stylized cartoon game model, smooth simple
  rounded shapes, big simple forms, flat clean colors, low poly, no fur detail, no realistic textures. Perfectly
  symmetrical. Isolated single character only, nothing else: no base, no ground, no rocks, no props. Legs clearly
  separate. One solid closed shape.

(Gold armour and gold antlers asked for by the user, the mane kept simple to keep it light.) Right first time. Its
grey-white coat was warmed to the card's cream (pale colourless pixels times 1.04, 0.99, 0.86). Vertices within 1 mm
merged and small holes filled. Bone positions are read off that mesh. Writes assets/blender/Thunderhorn/Thunderhorn.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.45), (0, 0.05, 0.47)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.47), (0, -0.15, 0.52)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.52), (0, -0.25, 0.58)),
    ("Neck", "Spine_1", (0, -0.25, 0.58), (0, -0.33, 0.7)),
    ("Head_0", "Neck", (0, -0.33, 0.7), (0, -0.52, 0.62)),
    ("Tail_0", "Pelvis", (0, 0.4, 0.45), (0, 0.46, 0.36)),
    ("Tail_1", "Tail_0", (0, 0.46, 0.36), (0, 0.5, 0.26)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # The golden antlers flick like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.06, -0.33, 0.76), (sx * 0.24, -0.25, 0.98)),
        # Front legs: shoulder, knee, fetlock, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.12, -0.2, 0.45), (sx * 0.11, -0.22, 0.25)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.22, 0.25), (sx * 0.1, -0.22, 0.07)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.1, -0.22, 0.07), (sx * 0.1, -0.28, 0.01)),
        # Hind legs from mid-haunch: knee, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.25, 0.42), (sx * 0.18, 0.3, 0.24)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.18, 0.3, 0.24), (sx * 0.21, 0.27, 0.07)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.21, 0.27, 0.07), (sx * 0.22, 0.2, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.38
params.leg_full = 0.24
params.leg_core = 0.06
params.leg_radius = 0.12
params.belly_mid = 0.04
params.tail_from = 0.36
params.head_from = -0.24

rig_kit.run("Thunderhorn", "Thunderhorn_Stag", BONES, params, target_tris=9000)
