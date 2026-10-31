"""Rigs the Mossling, the meadow's small wild monster (spec 2026-11-01-wild-monster-models-design, style B "wild-touched":
feral, not card-like). The user picked the "boulder beast" concept; Meshy made it from that picture (image to 3D, job
meshy:i2m:01a192e8-5762-73f5-a1b3-5e7ac6e35e16, the cut-out is assets/blender/Mossling/Mossling_concept.png): a squat
grey stone brute on four stubby legs, heavy brow, pale green eyes, tusks, a moss beard and moss patches, cream mushrooms
along its back and a short stubby tail, 0.6 m tall, facing -Y.

"Mossling_Body" in assets/blender/Mossling/Mossling.blend is that mesh (appended from the raw file). It plods on four
stubby legs; the jaw moves the tusks and beard. Bone positions are read off the mesh: feet at x 0.18, front y -0.15,
hind y 0.19; face front at y -0.42; back up to 0.6 at y 0; the tail at y 0.33 to 0.42. The glow mask lights the mint
eyes and the cream mushrooms on its back (not the tusks, which are the same cream). Writes Mossling.fbx and
Mossling_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.15)),
    ("Pelvis", "Root", (0, 0.15, 0.3), (0, 0.0, 0.32)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.32), (0, -0.12, 0.33)),
    ("Spine_1", "Spine_0", (0, -0.12, 0.33), (0, -0.2, 0.33)),
    ("Neck", "Spine_1", (0, -0.2, 0.33), (0, -0.27, 0.32)),
    ("Head_0", "Neck", (0, -0.27, 0.32), (0, -0.42, 0.32)),
    # The lower jaw: tusks and beard
    ("Jaw_0", "Head_0", (0, -0.3, 0.22), (0, -0.41, 0.16)),
    # The stubby tail
    ("Tail_0", "Pelvis", (0, 0.33, 0.24), (0, 0.39, 0.22)),
    ("Tail_1", "Tail_0", (0, 0.39, 0.22), (0, 0.43, 0.2)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: shoulder inside the body, elbow, wrist to the toes
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.18, -0.15, 0.3), (sx * 0.18, -0.15, 0.16)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.18, -0.15, 0.16), (sx * 0.18, -0.15, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.18, -0.15, 0.05), (sx * 0.18, -0.19, 0.01)),
        # Hind legs: hip, knee, ankle to the toes
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.186, 0.19, 0.3), (sx * 0.186, 0.19, 0.16)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.186, 0.19, 0.16), (sx * 0.186, 0.19, 0.05)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.186, 0.19, 0.05), (sx * 0.186, 0.15, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.24
params.leg_full = 0.12
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.05
params.tail_from = 0.32
params.head_from = -0.24

GLOW = [
    {"hue": (120, 175), "sat": (0.2, 1.0), "val": (0.6, 1.0)},  # the mint eyes
    {"hue": (40, 68), "sat": (0.12, 0.6), "val": (0.72, 1.0)},  # the cream mushrooms (on the back, see region)
]


def glows_here(centre):
    """The back's mushrooms and the face above the tusks."""
    return centre.z > 0.48 or (centre.y < -0.3 and centre.z > 0.28)


rig, mesh = rig_kit.run("Mossling", "Mossling_Body", BONES, params, target_tris=5000)
rig_kit.glow_mask(mesh, "Mossling", GLOW, grow=1, region=glows_here)
bpy.ops.wm.save_mainfile()
