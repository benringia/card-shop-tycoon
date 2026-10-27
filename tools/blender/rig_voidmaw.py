"""Rigs Voidmaw, a cosmic void dragon (a Legendary, so godlike and big; replaces the older scripted voxel seven-headed
hydra, tools/blender/build_voidmaw.py, with one head that Meshy can make cleanly): generated with Meshy through the
Blender MCP from this firm prompt (object "Voidmaw_Src", scaled x0.333 to 1 m tall):

  colossal mythical cosmic void dragon, legendary creature, godlike and terrifying. Standing on all four legs like a
  dog, exactly four thick powerful legs straight down under its huge heavy body, all four feet planted square, head and
  body facing straight forward, not sitting, not turned. No wings. Long thick tail straight out behind. Smooth simple
  solid body. Midnight blue-black skin speckled with small glowing stars, pale violet belly plates. Main feature: a
  huge wide jaw slightly open with glowing violet crystal fangs, a crown of tall glowing violet crystal horns, violet
  crystal spikes along its back and tail, a glowing black hole orb in its chest. Flat clean colors, low poly, toy-like.
  Perfectly symmetrical. Isolated single character only: no base, no ground, no props. One shape.

A midnight dragon with faint stars, a pale violet belly, violet crystal horns and spikes and an open fanged jaw, on
four planted legs; it came with small folded wings anyway (kept, the user's call) and a second tail lying along its
left side from hip to head, which was deleted by hand (vertices with x < -0.25, z < 0.37 and y < 0.42, then the
crystal islands of it left by its hip). rig_kit.remesh_bake (voxel 3.5 mm for the thin wings, 14,000 triangles,
colours baked) into "Voidmaw_Dragon" in assets/blender/Voidmaw/Voidmaw_meshy.blend, moved 5 cm to the middle.

It prowls on four legs, wings folded on Wing_ bones, its long tail swaying; its lower jaw (Jaw_0) drops for its roar.
Bone positions are read off that mesh. Writes assets/blender/Voidmaw/Voidmaw.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.2, 0.38), (0, 0.0, 0.4)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.4), (0, -0.25, 0.42)),
    ("Spine_1", "Spine_0", (0, -0.25, 0.42), (0, -0.45, 0.5)),
    ("Neck", "Spine_1", (0, -0.45, 0.5), (0, -0.6, 0.72)),
    ("Head_0", "Neck", (0, -0.6, 0.72), (0, -1.0, 0.68)),
    # The lower jaw hinges under the eyes
    ("Jaw_0", "Head_0", (0, -0.72, 0.6), (0, -0.88, 0.48)),
    # The long tail runs back low and rests its tip on the ground
    ("Tail_0", "Pelvis", (0, 0.25, 0.4), (0, 0.45, 0.28)),
    ("Tail_1", "Tail_0", (0, 0.45, 0.28), (0, 0.65, 0.15)),
    ("Tail_2", "Tail_1", (0, 0.65, 0.15), (0, 0.82, 0.12)),
    ("Tail_3", "Tail_2", (0, 0.82, 0.12), (-0.03, 0.98, 0.18)),
    # Folded wings, from the shoulders back along its sides (its right wing hangs lower)
    ("Wing_Left_0", "Spine_0", (0.12, -0.2, 0.55), (0.3, 0.05, 0.7)),
    ("Wing_Left_1", "Wing_Left_0", (0.3, 0.05, 0.7), (0.42, 0.5, 0.73)),
    ("Wing_Right_0", "Spine_0", (-0.12, -0.2, 0.55), (-0.3, 0.05, 0.62)),
    ("Wing_Right_1", "Wing_Right_0", (-0.3, 0.05, 0.62), (-0.43, 0.5, 0.52)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: shoulder, elbow, wrist, claws
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.13, -0.5, 0.4), (sx * 0.17, -0.52, 0.2)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.17, -0.52, 0.2), (sx * 0.16, -0.56, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.16, -0.56, 0.06), (sx * 0.16, -0.66, 0.01)),
        # Hind legs: hip, knee, hock, claws
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.13, 0.12, 0.4), (sx * 0.18, 0.05, 0.22)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.18, 0.05, 0.22), (sx * 0.17, 0.18, 0.07)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.17, 0.18, 0.07), (sx * 0.17, 0.04, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.36
params.leg_full = 0.22
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.04
params.tail_from = 0.25
params.head_from = -0.55

# The lower jaw: in front of JAW_BACK and under JAW_TOP, blending over JAW_BLEND into the head
JAW_BACK, JAW_TOP, JAW_BLEND = -0.74, 0.6, 0.03
# The wings: out past WING_SIDE above WING_LOW, between the shoulders and the tail; the outer half from WING_FOLD back
WING_SIDE, WING_LOW, WING_FOLD = 0.2, 0.5, 0.15


def jaw_share(p):
    return rig_kit._ramp(p.y, JAW_BACK, JAW_BACK - JAW_BLEND) * rig_kit._ramp(p.z, JAW_TOP + JAW_BLEND, JAW_TOP)


def wing_share(p, sign):
    if p.z < WING_LOW or not -0.35 < p.y < 0.62 or p.x * sign <= 0:
        return 0.0
    return rig_kit._ramp(p.x * sign, WING_SIDE, WING_SIDE + 0.05)


mesh = bpy.data.objects["Voidmaw_Dragon"]
rig = rig_kit.build_rig("VoidmawRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
rig_kit.reweight(mesh, "Jaw_0", jaw_share)
for side, sign in (("Left", 1), ("Right", -1)):
    rig_kit.reweight(mesh, f"Wing_{side}_0", lambda p, sign=sign: wing_share(p, sign))
    rig_kit.reweight(mesh, f"Wing_{side}_1",
                     lambda p, sign=sign: wing_share(p, sign) * rig_kit._ramp(p.y, WING_FOLD, WING_FOLD + 0.1))
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Voidmaw", rig, mesh)
