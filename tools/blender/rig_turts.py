"""Rigs Turts, the plaza shopkeeper (the owner's dog; spec 2026-11-13-turts-shop-design), prepared by prep_turts.py
(object "Turts_Dog" in assets/blender/Turts/Turts_meshy.blend: 1 m tall, facing -Y, ~16,000 triangles with his face
kept dense). Run in a background Blender:

  blender -b assets/blender/Turts/Turts_meshy.blend --python tools/blender/rig_turts.py

Chikin's rig (rig_chikin.py, Pish's bone names) on Turts' measured shape, so Pish's clips (anim_pish.py, DOG=Turts)
play on him: feet at y -0.253 / 0.244, x +-0.129 front and +-0.19 hind; the belly 0.17 up, the back 0.72; a big shaggy
head (y -0.61..-0.05, z 0.55..1.0); long ears down its sides; a plumed tail up off his rump swept to his left (y
0.35..0.68, up to 0.89, about 0.2 to his left). His head's constant shake is added by the game on Head_0
(TurtsController). Saves assets/blender/Turts/Turts.blend and writes Turts.fbx (EXPORT=0 skips it); POSE=1 renders a
test pose to assets/blender/Turts/Turts_pose_<view>.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Turts"
FRONT_Y, HIND_Y = -0.253, 0.244
FRONT_X, HIND_X = 0.129, 0.19  # his left; the right is the mirror (measured from his four feet)
HEAD_X = 0.0  # his head sits square

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.15)),
    ("Pelvis", "Root", (0, 0.26, 0.45), (0, 0.08, 0.46)),
    ("Spine_0", "Pelvis", (0, 0.08, 0.46), (0, -0.08, 0.47)),
    ("Spine_1", "Spine_0", (0, -0.08, 0.47), (0, -0.2, 0.5)),
    ("Neck", "Spine_1", (0, -0.2, 0.5), (0, -0.26, 0.64)),
    ("Head_0", "Neck", (0, -0.26, 0.64), (0, -0.55, 0.78)),
    # Long shaggy ears hanging down the sides of his big head, from the crown
    ("Ear_Left_0", "Head_0", (0.27, -0.32, 0.88), (0.31, -0.32, 0.55)),
    ("Ear_Right_0", "Head_0", (-0.27, -0.32, 0.88), (-0.31, -0.32, 0.55)),
    # Front legs: shoulder, wrist, paw
    ("0_Left_Limb_0", "Spine_1", (FRONT_X, FRONT_Y, 0.36), (FRONT_X, FRONT_Y, 0.15)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (FRONT_X, FRONT_Y, 0.15), (FRONT_X, FRONT_Y - 0.01, 0.04)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (FRONT_X, FRONT_Y - 0.01, 0.04), (FRONT_X, FRONT_Y - 0.08, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-FRONT_X, FRONT_Y, 0.36), (-FRONT_X, FRONT_Y, 0.15)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-FRONT_X, FRONT_Y, 0.15), (-FRONT_X, FRONT_Y - 0.01, 0.04)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-FRONT_X, FRONT_Y - 0.01, 0.04), (-FRONT_X, FRONT_Y - 0.08, 0.01)),
    # Hind legs: hip, hock, paw
    ("1_Left_Limb_0", "Pelvis", (HIND_X, HIND_Y, 0.36), (HIND_X, HIND_Y + 0.01, 0.15)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (HIND_X, HIND_Y + 0.01, 0.15), (HIND_X, HIND_Y, 0.04)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (HIND_X, HIND_Y, 0.04), (HIND_X, HIND_Y - 0.07, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-HIND_X, HIND_Y, 0.36), (-HIND_X, HIND_Y + 0.01, 0.15)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-HIND_X, HIND_Y + 0.01, 0.15), (-HIND_X, HIND_Y, 0.04)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-HIND_X, HIND_Y, 0.04), (-HIND_X, HIND_Y - 0.07, 0.01)),
    # The plumed tail: up off the rump and swept over to his left
    ("Tail_0", "Pelvis", (0.03, 0.34, 0.6), (0.11, 0.46, 0.74)),
    ("Tail_1", "Tail_0", (0.11, 0.46, 0.74), (0.19, 0.57, 0.84)),
    ("Tail_2", "Tail_1", (0.19, 0.57, 0.84), (0.25, 0.66, 0.8)),
]

params = rig_kit.Params()
params.leg_top = float(os.environ.get("LEG_TOP", "0.28"))  # the belly is about 0.16 up between the legs
params.leg_full = 0.14
# His legs are thick fluffy columns (paws about 20 cm across): the skin at the back of a front leg, 12 cm behind its
# bone, must go with the leg, or it tears when the leg swings (tools/blender/check_stretch.py)
params.leg_core = float(os.environ.get("LEG_CORE", "0.14"))
params.leg_radius = float(os.environ.get("LEG_RADIUS", "0.2"))
params.belly_mid = 0.03
params.tail_from = 0.33
params.head_from = -0.12

# Moving in one piece without stretching (as rig_pish.py): the head above the neck line goes to the head's bones, each
# ear follows its bone by height (none at the crown, all of it from EAR_FREE down, blurred along the ear), and the tail
# above the rump goes to the tail's bones
HEAD_BONES = ("Head_0", "Ear_Left_0", "Ear_Right_0")
TAIL_BONES = ("Tail_0", "Tail_1", "Tail_2")
EAR_TOP, EAR_FREE = 0.88, 0.62
EAR_BLUR = 4


def _smooth(value, zero, one):
    t = min(1.0, max(0.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


def head_share(p):
    # his head is a big shaggy mop down to 0.55 in front; behind it the back rises to 0.72
    behind = _smooth(p.y, -0.35, -0.05)
    floor = 0.52 * (1 - behind) + 0.66 * behind
    return _smooth(p.z, floor, floor + 0.07) * (1 - _smooth(p.y, -0.06, 0.02))


TAIL_TIP_FLOOR = float(os.environ.get("TAIL_TIP_FLOOR", "0.58"))


def tail_share(p):
    # The tail curls up off the rump and its tip comes back down behind it (to 0.62 up at y 0.66): there the whole
    # curl goes with the tail, down to TAIL_TIP_FLOOR
    behind = _smooth(p.y, 0.5, 0.6)
    floor = 0.62 * (1 - behind) + TAIL_TIP_FLOOR * behind
    return _smooth(p.z, floor, floor + 0.05) * _smooth(p.y, 0.32, 0.38)


def ears(mesh):
    """(left ear's vertex indices, right ear's): the curls hanging past the head's sides, by place"""
    left, right = set(), set()
    for i, v in enumerate(mesh.data.vertices):
        p = mesh.matrix_world @ v.co
        if 0.42 < p.z < EAR_TOP and -0.55 < p.y < -0.12:
            if p.x - HEAD_X > 0.22:
                left.add(i)
            elif p.x - HEAD_X < -0.22:
                right.add(i)
    return left, right


def stiffen(mesh):
    world = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    rig_kit.confine(mesh, HEAD_BONES, head_share, "Head_0")
    left, right = ears(mesh)
    for bone, members in (("Ear_Left_0", left), ("Ear_Right_0", right)):
        field = [_smooth(-world[i].z, -EAR_TOP, -EAR_FREE) if i in members else 0.0 for i in range(len(world))]
        field = rig_kit.smooth_field(mesh, field, EAR_BLUR, where=lambda i, members=members: i in members)
        rig_kit.set_bone(mesh, bone, field)
    rig_kit.confine(mesh, TAIL_BONES, tail_share, "Tail_0")
    rig_kit.restrict(mesh, TAIL_BONES, lambda i: tail_share(world[i]))
    print("stiffened: ears", len(left), len(right))


def test_pose(rig):
    """A stride with the head turned, the ears and the tail swung: renders front, side and three-quarter views"""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    turns = {
        "0_Left_Limb_0": (25, 0, 0), "1_Right_Limb_0": (25, 0, 0),
        "0_Right_Limb_0": (-25, 0, 0), "1_Left_Limb_0": (-25, 0, 0),
        "Head_0": (0, 0, 20), "Neck": (10, 0, 0),
        "Ear_Left_0": (0, 25, 0), "Ear_Right_0": (0, -25, 0),
        "Tail_0": (0, 0, 30), "Tail_1": (0, 0, 20),
    }
    for name, (x, y, z) in turns.items():
        bone = rig.pose.bones[name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
    bpy.ops.object.mode_set(mode="OBJECT")
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 560, 560
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.32, 0.4, 0.5, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(40), 0, math.radians(25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("PoseCam", bpy.data.cameras.new("PoseCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    middle = Vector((0, 0, 0.45))
    folder = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
    for view, direction in (("front", Vector((0, -1, 0.15))), ("side", Vector((1, 0, 0.1))),
                            ("three_quarter", Vector((0.75, -0.7, 0.45)))):
        cam.location = middle + direction.normalized() * 3.2
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"{NAME}_pose_{view}.png")
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.save_as_mainfile(filepath=os.path.join(rig_kit.REPO, "assets", "blender", NAME, f"{NAME}.blend"))
mesh = bpy.data.objects["Turts_Dog"]
rig_kit.optimize(mesh, NAME, target_tris=16000)  # prep_turts kept his face dense: never cut him back to 10,000
rig = rig_kit.build_rig("TurtsRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
stiffen(mesh)
if os.environ.get("POSE", "0") == "1":
    test_pose(rig)
elif os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
