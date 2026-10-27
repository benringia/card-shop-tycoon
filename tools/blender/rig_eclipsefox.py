"""Rigs Eclipse Fox, a shadow kitsune (an Epic, so very dangerous and big; replaces the older scripted voxel build,
tools/blender/build_eclipsefox.py): generated with Meshy through the Blender MCP from this firm prompt (object
"EclipseFox_Src", scaled x1.67 to 1 m tall):

  chunky muscular mythical shadow kitsune fox, epic creature, fierce and menacing. Standing on all four legs like a dog,
  exactly four thick powerful legs straight down under its heavy body, all four feet planted square, head and body
  facing straight forward, not sitting, not turned. Smooth simple solid body, no fur spikes, no fur strands. Deep violet
  body, big smooth white chest ruff, narrow glowing golden eyes, tall pointed ears, sharp fangs. Main feature: nine
  thick fluffy violet tails with white tips fanned out wide behind it, clearly separate; glowing violet crescent moon
  marks on its flanks; black eclipse disc with glowing golden ring on its forehead. Flat clean colors, low poly,
  toy-like. Perfectly symmetrical. Isolated single character only: no base, no ground, no props. One shape.

Four planted feet, a white ruff, violet rings on its flanks and a golden eclipse ring on its brow, but its rear half
was swung 28 degrees to its left and its tails came out bunched and stuck together. rig_kit.remesh_bake (voxel 4 mm,
10,000 triangles, colours baked), then fixed by hand:
- straightened: every vertex turned about a vertical axis at (0.07, -0.28) by 28 degrees x smoothstep(y, -0.32,
  -0.16), so the body behind the shoulders swings back in line with the head, then moved 7 cm to the middle;
- every generated tail deleted (the user wanted two or three that animate cleanly, none sticking to another):
  vertices with y > 0.16 and z > 0.1, or y > 0.22, except within 8 cm of a hind leg below z 0.42; the hole in its rump
  filled and coloured violet (paint_patch).
Saved as "EclipseFox_Kitsune" in assets/blender/EclipseFox/EclipseFox_meshy.blend. This script then adds three smooth
bushy tails (rig_kit.tail, violet with white tips): one rising behind, two fanned out to the sides with clear gaps.

It stalks on four legs, ears flicking, each tail swaying on its own beat (Tails_<tail>_0..2, one chain per tail; each
tail's own vertices follow only its own chain). Bone positions are read off that mesh. Writes
assets/blender/EclipseFox/EclipseFox.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

VIOLET = (0.145, 0.032, 0.361)
WHITE = (0.871, 0.875, 0.961)
TAIL_WIDEST = 0.09
# Each tail's Bezier curve: root (sunk in the rump), two handles, tip
TAILS = [
    ((0, 0.12, 0.46), (0, 0.3, 0.5), (0, 0.44, 0.7), (0, 0.42, 0.94)),
    ((0.08, 0.12, 0.42), (0.2, 0.28, 0.44), (0.32, 0.4, 0.58), (0.4, 0.42, 0.8)),
    ((-0.08, 0.12, 0.42), (-0.2, 0.28, 0.44), (-0.32, 0.4, 0.58), (-0.4, 0.42, 0.8)),
]


def bezier(points, t):
    p0, p1, p2, p3 = (Vector(p) for p in points)
    s = 1 - t
    return p0 * s ** 3 + p1 * 3 * s * s * t + p2 * 3 * s * t * t + p3 * t ** 3


BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.12, 0.4), (0, -0.05, 0.42)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.42), (0, -0.2, 0.45)),
    ("Spine_1", "Spine_0", (0, -0.2, 0.45), (0, -0.3, 0.5)),
    ("Neck", "Spine_1", (0, -0.3, 0.5), (0.02, -0.36, 0.68)),
    ("Head_0", "Neck", (0.02, -0.36, 0.68), (0.02, -0.56, 0.64)),
    ("Ear_Left_0", "Head_0", (0.08, -0.35, 0.84), (0.2, -0.32, 0.99)),
    ("Ear_Right_0", "Head_0", (-0.05, -0.35, 0.84), (-0.14, -0.31, 1.0)),
    # Front legs: shoulder, knee, paw (its right forepaw stands a little wide)
    ("0_Left_Limb_0", "Spine_1", (0.09, -0.38, 0.4), (0.12, -0.38, 0.24)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.12, -0.38, 0.24), (0.1, -0.41, 0.07)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.1, -0.41, 0.07), (0.11, -0.49, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.11, -0.36, 0.4), (-0.13, -0.34, 0.24)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.13, -0.34, 0.24), (-0.17, -0.37, 0.07)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.17, -0.37, 0.07), (-0.2, -0.45, 0.01)),
    # Hind legs: hip, hock, paw (its left hind paw stands a little back)
    ("1_Left_Limb_0", "Pelvis", (0.1, 0.1, 0.4), (0.12, 0.13, 0.24)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.12, 0.13, 0.24), (0.13, 0.14, 0.07)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.13, 0.14, 0.07), (0.15, 0.06, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.1, 0.03, 0.4), (-0.1, 0.02, 0.24)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.1, 0.02, 0.24), (-0.12, 0.03, 0.07)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.12, 0.03, 0.07), (-0.13, -0.05, 0.01)),
]
# One chain of three bones per tail along its curve
for tail, curve in enumerate(TAILS):
    points = [bezier(curve, f) for f in (0, 1 / 3, 2 / 3, 1)]
    for i in range(3):
        parent = "Pelvis" if i == 0 else f"Tails_{tail}_{i - 1}"
        BONES.append((f"Tails_{tail}_{i}", parent, tuple(points[i]), tuple(points[i + 1])))

params = rig_kit.Params()
params.leg_top = 0.34
params.leg_full = 0.24
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.head_from = -0.26

mesh = bpy.data.objects["EclipseFox_Kitsune"]
if "tails" not in mesh:
    mesh["body_verts"] = len(mesh.data.vertices)
    violet = rig_kit.paint_patch(mesh, VIOLET)
    white = rig_kit.paint_patch(mesh, WHITE)
    for curve in TAILS:
        rig_kit.tail(mesh, curve, TAIL_WIDEST, violet, white)
    mesh["tails"] = True
rig = rig_kit.build_rig("EclipseFoxRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Each tail is its own shell (rig_kit.tail adds them one after another): its vertices follow only its own chain, by the
# nearest of its bones, so a swaying tail never drags its neighbour
deform = {n: (Vector(h), Vector(t)) for n, _, h, t in BONES}
shell = (len(mesh.data.vertices) - mesh["body_verts"]) // len(TAILS)
for v in mesh.data.vertices[mesh["body_verts"]:]:
    tail = (v.index - mesh["body_verts"]) // shell
    own = [f"Tails_{tail}_{i}" for i in range(3)]
    for g in list(v.groups):
        mesh.vertex_groups[g.group].remove([v.index])
    scores = {n: 1 / (rig_kit._segment_distance(v.co, *deform[n]) ** 2 + 1e-6) for n in own}
    total = sum(scores.values())
    for n, w in scores.items():
        mesh.vertex_groups[n].add([v.index], w / total, "REPLACE")
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("EclipseFox", rig, mesh)
