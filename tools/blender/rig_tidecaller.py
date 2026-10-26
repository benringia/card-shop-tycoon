"""Rigs Tidecaller, a sea dragon (a Very Rare, so confident and slightly fierce): generated with Meshy through the
Blender MCP from this prompt (object "Tidecaller_Dragon" in assets/blender/Tidecaller/Tidecaller.blend, 1 m tall as
generated), then optimized by rig_kit.optimize to about 9,900 triangles:

  stylized cartoon sea dragon, mythical tide creature, confident and slightly fierce, standing on four sturdy legs
  with its body level, a long graceful neck, a dragon head with sharp glowing aqua eyes and two swept-back crystal
  horns, pale aqua-white scales with a teal belly, a row of glowing translucent aqua crystal fins along its back,
  crystal fin frills on its cheeks, a long tail ending in a big rounded fish-like fin, webbed clawed feet. Toy-like
  collectible creature, smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no scale detail,
  no realistic textures. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no
  water, no rocks, no props. Legs clearly separate. One solid closed shape.

Right first time, with a pair of crystal fin-wings on its back as well (it walks: they ride on Wing_ bones that sway
gently). Vertices within 1 mm merged and small holes filled. Bone positions are read off that mesh. Writes
assets/blender/Tidecaller/Tidecaller.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.05, 0.3), (0, -0.15, 0.3)),
    ("Spine_0", "Pelvis", (0, -0.15, 0.3), (0, -0.35, 0.33)),
    ("Spine_1", "Spine_0", (0, -0.35, 0.33), (0, -0.45, 0.42)),
    ("Neck", "Spine_1", (0, -0.45, 0.42), (0, -0.55, 0.6)),
    ("Head_0", "Neck", (0, -0.55, 0.6), (0, -0.8, 0.6)),
    # The long tail, low, rising to the fish fin
    ("Tail_0", "Pelvis", (0, 0.1, 0.3), (0, 0.3, 0.2)),
    ("Tail_1", "Tail_0", (0, 0.3, 0.2), (0, 0.5, 0.17)),
    ("Tail_2", "Tail_1", (0, 0.5, 0.17), (0, 0.68, 0.25)),
    ("Tail_3", "Tail_2", (0, 0.68, 0.25), (0, 0.84, 0.45)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # The crystal horns flick like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.06, -0.52, 0.76), (sx * 0.2, -0.48, 1.0)),
        # Crystal fin-wings on its back
        (f"Wing_{side}_0", "Spine_0", (sx * 0.08, -0.05, 0.5), (sx * 0.15, -0.05, 0.68)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.15, -0.05, 0.68), (sx * 0.22, 0.0, 0.84)),
        # Front legs: shoulder, elbow, wrist, toes
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.12, -0.45, 0.3), (sx * 0.15, -0.48, 0.15)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.15, -0.48, 0.15), (sx * 0.17, -0.5, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.17, -0.5, 0.05), (sx * 0.19, -0.6, 0.01)),
        # Hind legs from mid-haunch: knee, hock, toes
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.12, 0.05, 0.3), (sx * 0.13, 0.1, 0.15)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.13, 0.1, 0.15), (sx * 0.12, 0.05, 0.04)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.12, 0.05, 0.04), (sx * 0.12, -0.1, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.28
params.leg_full = 0.15
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.08
params.head_from = -0.45

rig_kit.run("Tidecaller", "Tidecaller_Dragon", BONES, params, target_tris=10000)
