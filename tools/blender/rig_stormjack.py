"""Rigs Stormjack, a chunky storm ram (a Rare, slightly fierce; replaces the older scripted voxel build,
tools/blender/build_stormjack.py, with a creature that is light, cheap and easy to animate, the user's ask): generated
with Meshy through the Blender MCP from this firm prompt (object "Stormjack_Src", scaled x1.11 to 1 m tall):

  chunky cartoon mythical storm ram, rare lightning creature, slightly fierce. Standing on all four legs like a dog,
  exactly four short thick legs straight down under its plump round body, all four feet planted square with dark
  hooves, head and body facing straight forward, not sitting, not turned. Smooth simple solid body, no fur strands. A
  fluffy round grey storm-cloud fleece covering its back, a dark slate blue face and legs, fierce glowing yellow eyes.
  Main feature: two big thick curled golden horns with glowing yellow lightning bolt marks, and small yellow lightning
  bolts crackling out of its cloud fleece. Short tail. Flat clean colors, low poly, toy-like collectible. Perfectly
  symmetrical. Isolated single character only: no base, no ground, no props. One solid shape.

Right first time: four square hooves, curled golden horns, a grey cloud fleece, but the lightning came out as tiny
marks on its legs, so the mythical part is added by hand (rig_kit.bolt, coloured by paint_patch): one big yellow bolt
lying on each flank, flat to the side so it shows side-on. (Two more rising from its back looked random to the user
and were removed.) 3.9M
triangles of fleece, so rig_kit.remesh_bake (voxel 5 mm, 9,000 triangles, colours baked) into "Stormjack_Ram" in
assets/blender/Stormjack/Stormjack_meshy.blend.

It trots on four short legs, its horns (Ear_ bones) and stubby tail flicking; for its signature it charges horn first
as lightning rains round it (the hornstorm, shared with Stormking). Bone positions are read off that mesh. Writes
assets/blender/Stormjack/Stormjack.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BOLT_YELLOW = (1.0, 0.86, 0.15)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.42), (0, 0.08, 0.44)),
    ("Spine_0", "Pelvis", (0, 0.08, 0.44), (0, -0.12, 0.46)),
    ("Spine_1", "Spine_0", (0, -0.12, 0.46), (0, -0.25, 0.52)),
    ("Neck", "Spine_1", (0, -0.25, 0.52), (0, -0.3, 0.66)),
    ("Head_0", "Neck", (0, -0.3, 0.66), (0, -0.55, 0.7)),
    # The stubby tail
    ("Tail_0", "Pelvis", (0, 0.44, 0.46), (0, 0.52, 0.5)),
    ("Tail_1", "Tail_0", (0, 0.52, 0.5), (0, 0.57, 0.56)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Curled horns, flicking like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.14, -0.25, 0.86), (sx * 0.27, -0.24, 0.82)),
        # Front legs: shoulder, knee, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.13, -0.12, 0.34), (sx * 0.14, -0.12, 0.18)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.14, -0.12, 0.18), (sx * 0.15, -0.12, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.15, -0.12, 0.06), (sx * 0.16, -0.2, 0.01)),
        # Hind legs: hip, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.27, 0.34), (sx * 0.16, 0.27, 0.18)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.16, 0.27, 0.18), (sx * 0.17, 0.28, 0.06)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.17, 0.28, 0.06), (sx * 0.18, 0.2, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.28
params.leg_full = 0.2
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.05
params.tail_from = 0.42
params.head_from = -0.22

mesh = bpy.data.objects["Stormjack_Ram"]
if "bolts" not in mesh:
    import numpy as np
    points = np.array([tuple(v.co) for v in mesh.data.vertices])

    def flank(y, z, sign):
        near = points[(np.abs(points[:, 1] - y) < 0.03) & (np.abs(points[:, 2] - z) < 0.03) & (points[:, 0] * sign > 0)]
        return (near[:, 0] * sign).max()

    yellow = rig_kit.paint_patch(mesh, BOLT_YELLOW)
    for sign in (1, -1):
        rig_kit.bolt(mesh, base=(sign * (flank(0.1, 0.42, sign) - 0.005), 0.12, 0.32), up=(0, -0.2, 1), side=(0, 1, 0),
                     size=0.2, thick=0.03, uv=yellow)
    mesh["bolts"] = True
rig = rig_kit.build_rig("StormjackRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Horns: wholly to the Ear_ bones, out past the head's sides
for side, sign in (("Left", 1), ("Right", -1)):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, sign=sign: rig_kit._ramp(p.x * sign, 0.14, 0.18)
                     if p.z > 0.6 and p.y < -0.08 else 0.0)
# Hooves: near the ground, every vertex within FOOT_REACH of a foot goes wholly to it
FOOT_TOP, FOOT_FULL, FOOT_REACH = 0.08, 0.04, 0.16
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
    rig_kit.export("Stormjack", rig, mesh)
