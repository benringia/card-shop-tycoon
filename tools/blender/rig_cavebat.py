"""Rigs the Cave Bat, the caves' wild flyer (spec 2026-11-01-wild-monster-models-design, style B "wild-touched"). The
user picked the "gargoyle bat" concept; Meshy made it from that picture (image to 3D, job
meshy:i2m:01a192f6-d16a-7497-82cc-f1b99b361adf, cut-out assets/blender/CaveBat/CaveBat_concept.png): a stone-skinned
gargoyle standing upright with glowing violet cracks, curved horns, pointed ears, a fanged face, solid stone wings
spread wide and two clawed feet, 1 m tall with the horns, 1.2 m across the wings, facing -Y.

"CaveBat_Src" in assets/blender/CaveBat/CaveBat.blend is that mesh (appended from the raw file). It flies
(Config/Wild FLYING): the Wing_<Side>_0..2 chains run from the shoulders (x 0.18, z 0.68) out along the wing to the tips
(x 0.6, z 0.42) and beat; its legs tuck. Built like Gloomlet (rig_gloomlet.py). The glow mask lights the violet cracks
and eyes. Writes CaveBat.fbx and CaveBat_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.26), (0, 0.02, 0.4)),
    ("Spine_0", "Pelvis", (0, 0.02, 0.4), (0, 0.0, 0.52)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.52), (0, 0.0, 0.6)),
    ("Neck", "Spine_1", (0, 0.0, 0.6), (0, -0.02, 0.66)),
    ("Head_0", "Neck", (0, -0.02, 0.66), (0, -0.06, 0.9)),
    # The fanged lower jaw under the snout
    ("Jaw_0", "Head_0", (0, -0.08, 0.67), (0, -0.18, 0.63)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Stone wings from the shoulders out to the tips, a little behind the body
        (f"Wing_{side}_0", "Spine_1", (sx * 0.18, 0.05, 0.68), (sx * 0.32, 0.06, 0.72)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.32, 0.06, 0.72), (sx * 0.46, 0.05, 0.62)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.46, 0.05, 0.62), (sx * 0.6, 0.02, 0.42)),
        # Clawed feet, tucked when flying
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.09, 0.02, 0.27), (sx * 0.11, -0.02, 0.15)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.02, 0.15), (sx * 0.12, 0.0, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.12, 0.0, 0.05), (sx * 0.14, -0.08, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.26
params.leg_full = 0.15
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.head_from = 0.3  # upright: the head sits on the body, so neck and head bones may reach everything in front
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (255, 320), "sat": (0.35, 1.0), "val": (0.6, 1.0)}]  # the violet cracks and eyes

source = bpy.data.objects.get("CaveBat_Src")
if source:
    source.name = "CaveBat_Body"
    source.data.name = "CaveBat_Body"
rig, mesh = rig_kit.run("CaveBat", "CaveBat_Body", BONES, params, target_tris=5000)
rig_kit.glow_mask(mesh, "CaveBat", GLOW, grow=1)
bpy.ops.wm.save_mainfile()
