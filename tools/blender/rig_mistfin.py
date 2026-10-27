"""Rigs Mistfin, a proud mist seal pup (a Rare, slightly fierce; a full redesign replacing the bought IceShark, since
Abyssal Koi is already a shark; the user's pick): generated with Meshy through the Blender MCP from this prompt
(object "Mistfin_Src", scaled x0.667 to 1 m tall):

  chunky cartoon mist seal pup, mythical tide creature, slightly fierce and proud, plump heavy round body, sitting
  upright on its belly propped on two thick front flippers, two rear flippers lying flat behind it, head and body
  facing straight forward. Soft grey-blue body with a pale belly, big shiny dark eyes, small black nose, whiskers, a
  fluffy frosty white mane around its neck, glowing aqua swirl markings on its back and flippers. Toy-like collectible,
  smooth simple rounded shapes, flat clean colors, low poly, no fur detail. Perfectly symmetrical. Isolated single
  character only, nothing else: no base, no ground, no ice, no water, no props. One solid closed shape.

Meshy made it standing upright on two little feet (kept, the user's call) with flipper arms, a frosty tuft on its head,
a long flat tail fin on the ground and no glowing markings: those are painted into its texture here by hand (three
wavy aqua mist lines across its back, glowing dots down its tail fin). 756k triangles, so rig_kit.remesh_bake (voxel
4.5 mm, 10,000 triangles, colours baked) into "Mistfin_Seal" in assets/blender/Mistfin/Mistfin.blend.

It waddles upright, flippers swinging a little and its tail fin swishing. Bone positions are read off that mesh. Writes
assets/blender/Mistfin/Mistfin.fbx.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

GLOW = (0.35, 0.95, 0.95)


def marked(p):
    """Whether a point on the skin is part of the glowing marks."""
    x, y, z = p
    # Wavy mist lines across the back (the back faces +Y)
    if y > -0.2 and abs(x) < 0.17 and 0.25 < z < 0.8:
        for zc in (0.36, 0.51, 0.66):
            if abs(z - (zc + 0.022 * math.sin(x * 28))) < 0.011:
                return True
    # Dots down the tail fin, on top
    if y > 0.05 and z > 0.03:
        for yc, xc in ((0.14, 0.0), (0.27, -0.01), (0.39, -0.03), (0.5, -0.055)):
            if math.hypot(y - yc, x - xc) < 0.03 - yc * 0.02:
                return True
    return False


def paint_marks(mesh):
    """Paints the marks into the colour map: every texel of the back and tail faces whose point on the skin is marked."""
    me = mesh.data
    me.calc_loop_triangles()
    img = next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    uvl = me.uv_layers.active.data
    for tri in me.loop_triangles:
        corners = [me.vertices[i].co for i in tri.vertices]
        centre = (corners[0] + corners[1] + corners[2]) / 3
        if not ((centre.y > -0.2 and centre.z > 0.25 and tri.normal.y > 0.25) or (centre.y > 0.05 and tri.normal.z > 0.3)):
            continue
        a, b, c = [np.array(uvl[li].uv) * (w, h) for li in tri.loops]
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        for py in range(int(max(0, min(a[1], b[1], c[1]))), int(min(h - 1, max(a[1], b[1], c[1]))) + 1):
            for pxx in range(int(max(0, min(a[0], b[0], c[0]))), int(min(w - 1, max(a[0], b[0], c[0]))) + 1):
                qx, qy = pxx + 0.5, py + 0.5
                l1 = ((b[1] - c[1]) * (qx - c[0]) + (c[0] - b[0]) * (qy - c[1])) / den
                l2 = ((c[1] - a[1]) * (qx - c[0]) + (a[0] - c[0]) * (qy - c[1])) / den
                l3 = 1 - l1 - l2
                if min(l1, l2, l3) < -0.02:
                    continue
                if marked(corners[0] * l1 + corners[1] * l2 + corners[2] * l3):
                    px[py, pxx, :3] = GLOW
    img.pixels[:] = px.ravel()
    img.update()
    img.save()


BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.3, 0.18), (0, -0.3, 0.35)),
    ("Spine_0", "Pelvis", (0, -0.3, 0.35), (0, -0.31, 0.5)),
    ("Neck", "Spine_0", (0, -0.31, 0.5), (0, -0.32, 0.6)),
    # The big round head with its frosty tuft
    ("Head_0", "Neck", (0, -0.32, 0.6), (0, -0.45, 0.95)),
    # The long flat tail fin along the ground
    ("Tail_0", "Pelvis", (0, -0.1, 0.12), (0, 0.15, 0.08)),
    ("Tail_1", "Tail_0", (0, 0.15, 0.08), (0, 0.35, 0.06)),
    ("Tail_2", "Tail_1", (0, 0.35, 0.06), (-0.04, 0.56, 0.05)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Flipper arms hanging at its sides
        (f"Arm_{side}_0", "Spine_0", (sx * 0.17, -0.33, 0.58), (sx * 0.2, -0.34, 0.45)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.2, -0.34, 0.45), (sx * 0.23, -0.34, 0.34)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.23, -0.34, 0.34), (sx * 0.26, -0.34, 0.27)),
        # Stubby legs: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.29, 0.15), (sx * 0.1, -0.3, 0.09)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.1, -0.3, 0.09), (sx * 0.1, -0.3, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.1, -0.3, 0.04), (sx * 0.11, -0.41, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.15
params.leg_full = 0.1
params.leg_core = 0.04
params.leg_radius = 0.08
params.belly_mid = 0.03
params.arm_core = 0.035
params.arm_radius = 0.065
params.tail_from = -0.12
params.head_from = -0.05  # everything but the tail fin; the head is split from the body by height

mesh = bpy.data.objects["Mistfin_Seal"]
if "marks" not in mesh:
    paint_marks(mesh)
    mesh["marks"] = True
rig = rig_kit.build_rig("MistfinRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Flipper arms hug its sides: every vertex close to an arm (within ARM_FULL wholly, fading out by ARM_REACH) goes to
# its nearest arm bone, so the whole flipper moves (as for Puffpuddle and Sparkrat)
ARM_FULL, ARM_REACH = 0.05, 0.075
arm_segments = {n: (Vector(h), Vector(t)) for n, _, h, t in BONES if n.startswith("Arm_")}


def arm_share(p, name):
    side = name.split("_")[1]
    if (p.x > 0) != (side == "Left"):
        return 0.0
    mine = rig_kit._segment_distance(p, *arm_segments[name])
    nearest = min(rig_kit._segment_distance(p, *seg) for n, seg in arm_segments.items() if n.split("_")[1] == side)
    if mine > nearest + 1e-9:
        return 0.0
    return rig_kit._ramp(mine, ARM_REACH, ARM_FULL)


for name in arm_segments:
    rig_kit.reweight(mesh, name, lambda p, name=name: arm_share(p, name))
# Toes reach past the legs' radius and some fell to the pelvis: near the ground, in front of the tail fin, every vertex
# within FOOT_REACH of a foot goes wholly to that foot
FOOT_TOP, FOOT_FULL, FOOT_REACH = 0.08, 0.04, 0.15
LEGS = ("0_Left_", "0_Right_")
SEGMENTS = {leg: [(Vector(h), Vector(t)) for n, _, h, t in BONES if n in (leg + "Limb_1", leg + "Limb_2")] for leg in LEGS}


def nearest_leg(p):
    if p.y > -0.12:
        return None
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
    rig_kit.export("Mistfin", rig, mesh)
