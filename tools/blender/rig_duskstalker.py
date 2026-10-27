"""Rigs Duskstalker, a shadow wolf (a Very Rare, so slightly fierce and medium-sized; replaces the older scripted voxel
monkey king, tools/blender/build_duskstalker.py): generated with Meshy through the Blender MCP from this firm prompt
(object "Duskstalker_Src", scaled x1.25 to 1 m tall):

  chunky mythical shadow wolf, very rare dark creature, slightly fierce. Standing on all four legs like a dog, exactly
  four short thick legs straight down under its sturdy plump body, all four feet planted square, head and body facing
  straight forward, not sitting, not turned. Smooth simple solid body, no fur spikes, no fur strands. Dark indigo body
  with a lavender chest, a simple smooth rounded dark purple mane on its neck, pointed ears, fierce glowing violet
  eyes. Main feature: two short curved glowing violet horns on its head, glowing violet crescent moon marks on its
  shoulders, and one thick bushy tail with a glowing violet tip. Flat clean colors, low poly, toy-like. Perfectly
  symmetrical. Isolated single character only: no base, no ground, no props. One shape.

(Two monkey kings came first: a shaggy one that broke into fur crumbs and holes, then a smooth one the user found
ugly; for the last try the user asked for a light, easy-to-animate creature, so a four-legged one like Frostfang.)
Right first time: a sleek dark indigo wolf with a tufted violet mane, violet-tipped ears and horns, glowing eyes and a
bushy violet-tipped tail, its left forefoot a stride ahead. rig_kit.optimize took it to 9,000 triangles. Saved as
"Duskstalker_Wolf" in assets/blender/Duskstalker/Duskstalker_meshy.blend.

It stalks on four legs, ears flicking, tail swaying; its signature is the backflip. Bone positions are read off that
mesh. Writes assets/blender/Duskstalker/Duskstalker.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.55), (0, 0.05, 0.58)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.58), (0, -0.15, 0.6)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.6), (0, -0.32, 0.62)),
    ("Neck", "Spine_1", (0, -0.32, 0.62), (0, -0.48, 0.75)),
    ("Head_0", "Neck", (0, -0.48, 0.75), (0, -0.81, 0.58)),
    # The bushy tail hangs back low
    ("Tail_0", "Pelvis", (0, 0.38, 0.55), (0, 0.5, 0.4)),
    ("Tail_1", "Tail_0", (0, 0.5, 0.4), (0, 0.62, 0.32)),
    ("Tail_2", "Tail_1", (0, 0.62, 0.32), (0, 0.81, 0.3)),
    # Ears and their violet horn tips
    ("Ear_Left_0", "Head_0", (0.11, -0.5, 0.87), (0.2, -0.62, 0.98)),
    ("Ear_Right_0", "Head_0", (-0.11, -0.51, 0.87), (-0.15, -0.68, 0.98)),
    # Front legs: shoulder, knee, paw (its left forefoot a stride ahead)
    ("0_Left_Limb_0", "Spine_1", (0.13, -0.3, 0.42), (0.14, -0.39, 0.2)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.14, -0.39, 0.2), (0.16, -0.45, 0.06)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.16, -0.45, 0.06), (0.16, -0.54, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.13, -0.25, 0.42), (-0.16, -0.22, 0.2)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.16, -0.22, 0.2), (-0.15, -0.22, 0.06)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.15, -0.22, 0.06), (-0.15, -0.31, 0.01)),
    # Hind legs: hip, hock, paw
    ("1_Left_Limb_0", "Pelvis", (0.12, 0.25, 0.45), (0.13, 0.36, 0.2)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.13, 0.36, 0.2), (0.15, 0.3, 0.06)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.15, 0.3, 0.06), (0.16, 0.22, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.13, 0.15, 0.45), (-0.11, 0.25, 0.2)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.11, 0.25, 0.2), (-0.14, 0.16, 0.06)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.14, 0.16, 0.06), (-0.14, 0.08, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.4
params.leg_full = 0.3
params.leg_core = 0.04
params.leg_radius = 0.08
params.belly_mid = 0.03
params.tail_from = 0.35
params.head_from = -0.4

mesh = bpy.data.objects["Duskstalker_Wolf"]
rig = rig_kit.build_rig("DuskstalkerRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Ears: above EAR_BASE, off the middle and ahead of the mane (which starts behind EAR_BACK) stay on the Ear_ bones
EAR_BASE, EAR_SIDE, EAR_BACK = 0.86, 0.04, -0.45
for side, sign in (("Left", 1), ("Right", -1)):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, sign=sign: rig_kit._ramp(p.z, EAR_BASE, EAR_BASE + 0.03)
                     if p.x * sign > EAR_SIDE and p.y < EAR_BACK else 0.0)
# Paws reach past the legs' radius: near the ground every vertex within FOOT_REACH of a foot goes to it
FOOT_TOP, FOOT_FULL, FOOT_REACH = 0.08, 0.04, 0.12
LEGS = ("0_Left_", "0_Right_", "1_Left_", "1_Right_")
SEGMENTS = {leg: [(Vector(h), Vector(t)) for n, _, h, t in BONES if n in (leg + "Limb_1", leg + "Limb_2")] for leg in LEGS}


def nearest_leg(p):
    best, best_distance = None, FOOT_REACH
    for leg, segments in SEGMENTS.items():
        distance = min(rig_kit._segment_distance(p, a, b) for a, b in segments)
        if distance < best_distance:
            best, best_distance = leg, distance
    return best


for leg in LEGS:
    rig_kit.reweight(mesh, leg + "Limb_2",
                     lambda p, leg=leg: rig_kit._ramp(p.z, FOOT_TOP, FOOT_FULL) if nearest_leg(p) == leg else 0.0)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Duskstalker", rig, mesh)
