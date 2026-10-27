"""Rigs Infernox, a massive fire tyrannosaurus (an Epic, so very dangerous and big; replaces the older scripted voxel
build, tools/blender/build_infernox.py, keeping its card's look): generated with Meshy through the Blender MCP from
this prompt (object "Infernox_Src", scaled x0.25 to 1 m tall):

  massive fierce fire tyrannosaurus rex, epic mythical ember creature, very dangerous, huge heavy bulky muscular body,
  very thick powerful legs with big clawed feet, small clawed arms, big head with a wide jaw slightly open showing rows
  of sharp white teeth, fierce glowing amber eyes, bright red body with bold black tiger stripes, cream belly, throat
  and lower jaw, a big crest of orange and yellow flames on its head, a thick heavy tail. Standing still in a neutral
  pose on two legs, feet planted, body and head facing straight forward, tail straight back. Stylized cartoon game
  model, smooth simple rounded shapes, flat clean colors, low poly, no realistic textures. Perfectly symmetrical.
  Isolated single character only, nothing else: no base, no ground, no rocks, no props. One solid closed shape

Meshy made it with the flame crest running down its neck. It went through rig_kit.remesh_bake (voxel 5 mm, 10,000
triangles, colours baked) into "Infernox_Rex". By hand: its head was turned 22.8 degrees, so the head (y < -0.5, the
neck blending in from y -0.38) was turned back about a vertical axis at (0, -0.42); its tail curved to its right, so
each slice behind y 0.3 was moved back onto the middle line (offsets in the script history: -0.007 at y 0.35 to -0.194
at y 0.75). Saved in assets/blender/Infernox/Infernox_meshy.blend.

It walks on two heavy legs with its tail swinging behind, small arms held up in front (Party.ARM_POSE), the lower jaw
on Jaw_0 for its fire breath. Bone positions are read off that mesh. Writes assets/blender/Infernox/Infernox.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.1, 0.5), (0, -0.1, 0.55)),
    ("Spine_0", "Pelvis", (0, -0.1, 0.55), (0, -0.28, 0.62)),
    ("Spine_1", "Spine_0", (0, -0.28, 0.62), (0, -0.4, 0.68)),
    ("Neck", "Spine_1", (0, -0.4, 0.68), (0.01, -0.5, 0.72)),
    ("Head_0", "Neck", (0.01, -0.5, 0.72), (0.03, -0.78, 0.72)),
    # The thick tail runs straight back
    ("Tail_0", "Pelvis", (0, 0.2, 0.5), (0, 0.35, 0.46)),
    ("Tail_1", "Tail_0", (0, 0.35, 0.46), (0, 0.5, 0.43)),
    ("Tail_2", "Tail_1", (0, 0.5, 0.43), (0, 0.63, 0.41)),
    ("Tail_3", "Tail_2", (0, 0.63, 0.41), (0, 0.77, 0.4)),
    # Legs: hip, knee forward, hock back, clawed toes (the right foot stands a little ahead)
    ("0_Left_Limb_0", "Pelvis", (0.11, -0.06, 0.45), (0.15, -0.15, 0.26)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.15, -0.15, 0.26), (0.12, -0.06, 0.1)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.12, -0.06, 0.1), (0.14, -0.2, 0.01)),
    ("0_Right_Limb_0", "Pelvis", (-0.11, -0.1, 0.45), (-0.13, -0.19, 0.26)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.13, -0.19, 0.26), (-0.11, -0.12, 0.1)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.11, -0.12, 0.1), (-0.14, -0.26, 0.01)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Small arms hanging in front of the chest: shoulder, elbow, claws
        (f"Arm_{side}_0", "Spine_1", (sx * 0.12, -0.32, 0.58), (sx * 0.14, -0.37, 0.47)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.14, -0.37, 0.47), (sx * 0.135, -0.41, 0.39)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.135, -0.41, 0.39), (sx * 0.13, -0.46, 0.36)),
    ]

params = rig_kit.Params()
params.leg_top = 0.4
params.leg_full = 0.3
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.arm_core = 0.03
params.arm_radius = 0.07
params.tail_from = 0.25
params.head_from = -0.38

# The lower jaw hinges under the back of the head and drops for its fire breath. Its vertices (the open mouth's bottom
# half: in front of y -0.57, under z 0.615) go to Jaw_0, blending over 3 cm into the head's weights
BONES.append(("Jaw_0", "Head_0", (0.02, -0.55, 0.6), (0.02, -0.74, 0.53)))
JAW_FRONT, JAW_TOP, JAW_BLEND = -0.57, 0.615, 0.03


def jaw_share(p):
    if p.y > JAW_FRONT + JAW_BLEND or p.z > JAW_TOP + JAW_BLEND:
        return 0.0
    along = min(1.0, (JAW_FRONT + JAW_BLEND - p.y) / JAW_BLEND)
    below = min(1.0, (JAW_TOP + JAW_BLEND - p.z) / JAW_BLEND)
    return along * below


mesh = bpy.data.objects["Infernox_Rex"]
rig = rig_kit.build_rig("InfernoxRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
rig_kit.reweight(mesh, "Jaw_0", jaw_share)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Infernox", rig, mesh)
