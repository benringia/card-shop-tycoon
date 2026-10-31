"""Rigs the Magma Golem, the ember ridge's heavy brute (spec 2026-11-01-wild-monster-models-design, style B
"wild-touched"). The user picked the "cairn cyclops" concept; Meshy made it from that picture (image to 3D, asked for a
T-pose, job meshy:i2m:01a19304-b98e-71ae-bd07-26929e9d175f, cut-out assets/blender/MagmaGolem/MagmaGolem_concept.png): a
hulking stack of grey and red-brown boulders with one orange cyclops eye (a dark slit pupil), lava dripping over its
head, chest and shoulders, long arms held slightly out with boulder fists near the ground and short stacked legs,
facing -Y.

"MagmaGolem_Src" in assets/blender/MagmaGolem/MagmaGolem.blend is that mesh, scaled x0.5 (Meshy made it 2 m tall) to
1 m like rig_cindertitan.py, whose layout it follows. It lumbers on two legs (pair 0 only, so PetRig treats it as
two-legged) swinging its arms (Arm_<Side>_0..2: shoulder x 0.3 at z 0.55, fists at x 0.43 down to z 0.08). Up to 8,000
triangles. The glow mask lights the lava and the iris round the dark pupil. Writes MagmaGolem.fbx and
MagmaGolem_glow.png next to the .blend.
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
    ("Pelvis", "Root", (0, 0.03, 0.22), (0, 0.02, 0.38)),
    ("Spine_0", "Pelvis", (0, 0.02, 0.38), (0, 0.0, 0.52)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.52), (0, -0.02, 0.64)),
    ("Neck", "Spine_1", (0, -0.02, 0.64), (0, -0.05, 0.68)),
    # The cyclops face at the front of the upper body, with the boulders stacked on top
    ("Head_0", "Neck", (0, -0.05, 0.68), (0, -0.12, 0.96)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Long arms: shoulder, elbow, wrist, the boulder fist hanging near the ground
        (f"Arm_{side}_0", "Spine_1", (sx * 0.3, 0.02, 0.55), (sx * 0.42, 0.03, 0.4)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.42, 0.03, 0.4), (sx * 0.43, 0.02, 0.24)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.43, 0.02, 0.24), (sx * 0.43, -0.01, 0.08)),
        # Short stacked legs: hip, knee, ankle, foot forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.04, 0.24), (sx * 0.2, 0.03, 0.13)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.2, 0.03, 0.13), (sx * 0.21, 0.03, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, 0.03, 0.04), (sx * 0.21, -0.05, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.22
params.leg_full = 0.14
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.04
params.head_from = 0.4  # the face sits on the upper body; neck and head bones may reach everything
params.arm_core = 0.07
params.arm_radius = 0.12
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (15, 48), "sat": (0.55, 1.0), "val": (0.72, 1.0)}]  # the lava and the orange iris (not the dark pupil)

source = bpy.data.objects.get("MagmaGolem_Src")
if source:
    source.name = "MagmaGolem_Body"
    source.data.name = "MagmaGolem_Body"
rig, mesh = rig_kit.run("MagmaGolem", "MagmaGolem_Body", BONES, params, target_tris=8000)
rig_kit.glow_mask(mesh, "MagmaGolem", GLOW, grow=1)
bpy.ops.wm.save_mainfile()
