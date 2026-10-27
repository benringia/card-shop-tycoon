"""Rigs Hushmoth, a cute fluffy moth (a Common, so cute and small; replaces the bought FairyMoth, keeping its card's
look): generated with Meshy through the Blender MCP from this prompt (object "Hushmoth_Src", scaled x5 to 1 m tall:
Meshy made it 20 cm):

  very cute chubby cartoon fluffy moth, mythical shade creature, round plump fuzzy white body, big round head, big
  shiny glowing blue eyes, two feathery golden yellow antennae, four short stubby legs tucked under its body, two big
  wide wings spread straight out flat to the sides like a butterfly, pastel wings with pink, lilac and aqua glowing
  spots and swirls. Facing straight forward, wings level and symmetric. Toy-like collectible, smooth simple rounded
  shapes, flat clean colors, low poly. Perfectly symmetrical. Isolated single character only, nothing else: no base,
  no ground, no flowers, no props. One solid closed shape.

Meshy made a fluffy white moth with big glowing blue eyes, pink cheeks, golden feathery antennae, little arms at its
sides, two thin legs and smaller pastel wings standing up behind its head (a thin sheet at y about 0.1): kept. 1.4M
triangles of fur, so rig_kit.remesh_bake (voxel 4 mm, fine enough to keep the wings; 10,000 triangles, colours
baked) into "Hushmoth_Moth" in assets/blender/Hushmoth/Hushmoth.blend.

It flies (legs tucked), the wings beating on Wing_ bones; the antennae flick on Ear_ bones. Wings and antennae are
given to their bones by position (skin() alone shares the round head between them). Bone positions are read
off that mesh. Writes assets/blender/Hushmoth/Hushmoth.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.0, 0.14), (0, -0.01, 0.32)),
    ("Spine_0", "Pelvis", (0, -0.01, 0.32), (0, -0.02, 0.48)),
    # The round head makes up the top half of the fluffy body
    ("Head_0", "Spine_0", (0, -0.02, 0.48), (0, -0.08, 0.86)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Feathery antennae on top of its head
        (f"Ear_{side}_0", "Head_0", (sx * 0.05, -0.05, 0.86), (sx * 0.18, -0.08, 0.97)),
        # Wings standing up behind the head, root out to tip
        (f"Wing_{side}_0", "Spine_0", (sx * 0.14, 0.1, 0.66), (sx * 0.25, 0.1, 0.8)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.25, 0.1, 0.8), (sx * 0.35, 0.11, 0.95)),
        # Little arms hanging at its sides
        (f"Arm_{side}_0", "Spine_0", (sx * 0.22, 0.0, 0.52), (sx * 0.26, 0.01, 0.4)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.26, 0.01, 0.4), (sx * 0.27, 0.02, 0.28)),
    ]
BONES += [
    # Thin legs: hip under the body, knee, ankle, toes
    ("0_Left_Limb_0", "Pelvis", (0.07, 0.0, 0.14), (0.1, -0.02, 0.07)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.1, -0.02, 0.07), (0.125, -0.05, 0.03)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.125, -0.05, 0.03), (0.16, -0.13, 0.01)),
    ("0_Right_Limb_0", "Pelvis", (-0.07, 0.01, 0.14), (-0.1, 0.01, 0.07)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.1, 0.01, 0.07), (-0.122, 0.01, 0.03)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.122, 0.01, 0.03), (-0.17, -0.06, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.1
params.leg_full = 0.06
params.leg_core = 0.02
params.leg_radius = 0.06
params.belly_mid = 0.03
params.arm_core = 0.04
params.arm_radius = 0.07
params.tail_from = 9  # no tail
params.head_from = 0.3  # the head sits right on the body: split by height alone

# What belongs to each part, by position: the wing sheets stand behind the head (y past WING_Y), fading in from their
# root at |x| WING_ROOT to wholly wing past WING_X (a hard edge creased the wing where it met the head); the antennae
# rise above the top of the head
WING_Y, WING_ROOT, WING_X, WING_Z = 0.07, 0.12, 0.2, 0.5
ANTENNA_Z, ANTENNA_X = 0.87, 0.03


def wing_share(p, side):
    if p.y <= WING_Y or p.z <= WING_Z or (p.x > 0) != (side == "Left"):
        return 0.0
    return rig_kit._ramp(abs(p.x), WING_ROOT, WING_X)


def antenna_side(p):
    if p.z > ANTENNA_Z and abs(p.x) > ANTENNA_X and p.y < WING_Y:
        return "Left" if p.x > 0 else "Right"
    return None


mesh = bpy.data.objects["Hushmoth_Moth"]
rig = rig_kit.build_rig("HushmothRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
for side in ("Left", "Right"):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, side=side: 1.0 if antenna_side(p) == side else 0.0)
    # The wing's inner half to its root bone, the outer half to its tip bone
    rig_kit.reweight(mesh, f"Wing_{side}_0", lambda p, side=side: wing_share(p, side) * rig_kit._ramp(p.z, 0.84, 0.76))
    rig_kit.reweight(mesh, f"Wing_{side}_1", lambda p, side=side: wing_share(p, side) * rig_kit._ramp(p.z, 0.76, 0.84))
# Nothing else stays on the wing and antenna bones: those weights go back to the head
parts = {mesh.vertex_groups[n].index: n for n in
         ("Ear_Left_0", "Ear_Right_0", "Wing_Left_0", "Wing_Right_0", "Wing_Left_1", "Wing_Right_1")}
head = mesh.vertex_groups["Head_0"]
for v in mesh.data.vertices:
    if wing_share(v.co, "Left") > 0 or wing_share(v.co, "Right") > 0 or antenna_side(v.co):
        continue
    moved = sum(g.weight for g in v.groups if g.group in parts)
    if moved <= 0:
        continue
    for index in parts:
        mesh.vertex_groups[index].remove([v.index])
    own = next((g.weight for g in v.groups if g.group == head.index), 0.0)
    head.add([v.index], own + moved, "REPLACE")
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Hushmoth", rig, mesh)
