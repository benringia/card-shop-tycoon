"""Rigs Voltkit, a storm pangolin (a Very Rare, so slightly fierce and medium-sized; a full redesign on the user's call,
replacing the older scripted voxel caped fox hero, tools/blender/build_voltkit.py, with a four-legged creature that rigs
cleanly and isn't another fox, lynx or rodent among the Volt cards): generated with Meshy through the Blender MCP from
this firm prompt (object "Voltkit_Src", already 1 m tall):

  chunky mythical storm pangolin, very rare lightning creature, slightly fierce. Standing on all four legs like a dog,
  exactly four short thick legs straight down under its plump round body, all four feet planted square with sturdy
  claws, head and body facing straight forward, not sitting, not turned, not curled up. Smooth simple solid body.
  Overlapping dark steel-blue armour scales on its back, cream belly and face, fierce glowing yellow eyes. Main
  feature: bright glowing yellow lightning lines between its armour scales, two tall glowing yellow lightning-bolt
  crests on its head, and one thick tail ending in a glowing electric orb. Flat clean colors, low poly, toy-like.
  Perfectly symmetrical. Isolated single character only: no base, no ground, no props. One shape.

Right first time for the body (four square clawed feet, overlapping steel-blue armour, a cream face and belly, yellow
eyes), but the lightning came out dark: steel-blue crests, no glowing lines and a tiny tail orb. So the electric parts
are added here: the crests painted yellow (paint_patch), a big glowing orb on the tail tip (rig_kit.orb) and a yellow
bolt lying on each armoured flank (rig_kit.bolt). rig_kit.remesh_bake (voxel 4 mm, 10,000 triangles, colours baked) into
"Voltkit_Pangolin" in assets/blender/Voltkit/Voltkit_meshy.blend.

It waddles on four legs, its crests (Ear_ bones) flicking and its thin tail swaying; for its signature it curls its tail
up over its back like a scorpion and lightning strikes down from the orb (tailstrike). Bone positions are read off that
mesh. Writes assets/blender/Voltkit/Voltkit.fbx.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BOLT_YELLOW = (1.0, 0.86, 0.15)
ORB_YELLOW = (1.0, 0.95, 0.55)
# The crests: faces above CREST_LOW, out past CREST_SIDE, ahead of CREST_BACK
CREST_LOW, CREST_SIDE, CREST_BACK = 0.895, 0.09, -0.22
TAIL_TIP, ORB_RADIUS = (-0.07, 0.84, 0.43), 0.07

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.25, 0.5), (0, 0.05, 0.52)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.52), (0, -0.15, 0.54)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.54), (0, -0.35, 0.52)),
    ("Neck", "Spine_1", (0, -0.35, 0.52), (0, -0.5, 0.5)),
    ("Head_0", "Neck", (0, -0.5, 0.5), (0, -0.82, 0.42)),
    # The thin tail runs back low, then curls up (a little to its right) to the orb
    ("Tail_0", "Pelvis", (0, 0.38, 0.4), (-0.03, 0.5, 0.2)),
    ("Tail_1", "Tail_0", (-0.03, 0.5, 0.2), (-0.06, 0.62, 0.18)),
    ("Tail_2", "Tail_1", (-0.06, 0.62, 0.18), (-0.09, 0.74, 0.36)),
    ("Tail_3", "Tail_2", (-0.09, 0.74, 0.36), TAIL_TIP),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # The lightning crests on its head, flicking like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.1, -0.33, 0.86), (sx * 0.22, -0.3, 0.98)),
    ]
BONES += [
    # Front legs: shoulder, knee, wrist, claws (its left forefoot stands a little ahead)
    ("0_Left_Limb_0", "Spine_1", (0.12, -0.4, 0.35), (0.14, -0.42, 0.18)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.14, -0.42, 0.18), (0.14, -0.45, 0.05)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.14, -0.45, 0.05), (0.14, -0.55, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.12, -0.35, 0.35), (-0.13, -0.35, 0.18)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.13, -0.35, 0.18), (-0.13, -0.37, 0.05)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.13, -0.37, 0.05), (-0.13, -0.46, 0.01)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Hind legs: hip, knee, ankle, claws
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.12, 0.15, 0.38), (sx * 0.15, 0.15, 0.18)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.15, 0.15, 0.18), (sx * 0.15, 0.17, 0.05)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.15, 0.17, 0.05), (sx * 0.15, 0.08, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.32
params.leg_full = 0.22
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.04
params.tail_from = 0.35
params.head_from = -0.42


def is_crest(p):
    return p.z > CREST_LOW and abs(p.x) > CREST_SIDE and p.y < CREST_BACK


mesh = bpy.data.objects["Voltkit_Pangolin"]
if "electric" not in mesh:
    yellow = rig_kit.paint_patch(mesh, BOLT_YELLOW)
    glow = rig_kit.paint_patch(mesh, ORB_YELLOW)
    uvs = mesh.data.uv_layers.active.data
    for face in mesh.data.polygons:
        if is_crest(face.center):
            for loop in face.loop_indices:
                uvs[loop].uv = yellow
    rig_kit.orb(mesh, TAIL_TIP, ORB_RADIUS, glow)
    points = np.array([tuple(v.co) for v in mesh.data.vertices])
    for sign in (1, -1):
        # On the armour's widest point at the flank, lying flat against it
        near = points[(np.abs(points[:, 1] + 0.05) < 0.03) & (np.abs(points[:, 2] - 0.5) < 0.03) & (points[:, 0] * sign > 0)]
        out = (near[:, 0] * sign).max()
        rig_kit.bolt(mesh, base=(sign * (out - 0.005), 0.05, 0.36), up=(0, -0.25, 1), side=(0, 1, 0), size=0.22,
                     thick=0.03, uv=yellow)
    mesh["electric"] = True
rig = rig_kit.build_rig("VoltkitRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
for side, sign in (("Left", 1), ("Right", -1)):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, sign=sign: 1.0 if is_crest(p) and p.x * sign > 0 else 0.0)
# The orb rides the tail tip whole
rig_kit.reweight(mesh, "Tail_3", lambda p: 1.0 if (p - Vector(TAIL_TIP)).length < ORB_RADIUS * 1.2 else 0.0)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Voltkit", rig, mesh)
