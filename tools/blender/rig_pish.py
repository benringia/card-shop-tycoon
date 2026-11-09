"""Rigs Pish, the tutorial's guide puppy (the owner's Shih Tzu), prepared by prep_pish.py (object "Pish_Dog" in
assets/blender/Pish/Pish_meshy.blend: 1 m tall, facing -Y, ~10,000 triangles, the light brown patch on its back).
Run in a background Blender:

  blender -b assets/blender/Pish/Pish_meshy.blend --python tools/blender/rig_pish.py

A chibi dog: a big round head (y -0.6..0, z 0.5..1.0) over a small body (y -0.3..0.35, z 0.2..0.58) on four short
legs (z 0..0.25; front feet at y -0.25, hind at 0.25, x +-0.16), floppy ears down the sides of its head and a
curled puff of a tail on its rump. Bones named for src/shared/Util/PetRig.luau, positions read off the mesh. The
lower jaw opens for his barks (owner 2026-11-09: barking among his animations): the underbite's chin with its two
teeth and the tongue, under the mouth line, split from the head with a dark mouth behind it (rig_kit.mouth_cut).
Saves assets/blender/Pish/Pish.blend (Pish_meshy.blend stays the unrigged prep) and writes
assets/blender/Pish/Pish.fbx (EXPORT=0 skips it). POSE=1 renders a test pose (a stride, head turned, ears and tail
swung, the mouth open) to assets/blender/Pish/Pish_pose_<view>.png to check the skin.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

FRONT_Y, HIND_Y = -0.25, 0.25
LEFT_X, RIGHT_X = 0.16, -0.165

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.15)),
    ("Pelvis", "Root", (0, 0.25, 0.4), (0, 0.08, 0.42)),
    ("Spine_0", "Pelvis", (0, 0.08, 0.42), (0, -0.08, 0.42)),
    ("Spine_1", "Spine_0", (0, -0.08, 0.42), (0, -0.2, 0.45)),
    ("Neck", "Spine_1", (0, -0.2, 0.45), (0, -0.24, 0.6)),
    ("Head_0", "Neck", (0, -0.24, 0.6), (0, -0.52, 0.74)),
    # Floppy ears hanging down the sides of the head, from the crown
    ("Ear_Left_0", "Head_0", (0.2, -0.3, 0.88), (0.27, -0.3, 0.56)),
    ("Ear_Right_0", "Head_0", (-0.2, -0.3, 0.88), (-0.27, -0.3, 0.56)),
    # Front legs: shoulder, wrist, paw
    ("0_Left_Limb_0", "Spine_1", (LEFT_X, FRONT_Y, 0.36), (LEFT_X, FRONT_Y, 0.15)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (LEFT_X, FRONT_Y, 0.15), (LEFT_X, FRONT_Y - 0.01, 0.04)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (LEFT_X, FRONT_Y - 0.01, 0.04), (LEFT_X, FRONT_Y - 0.08, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (RIGHT_X, FRONT_Y, 0.36), (RIGHT_X, FRONT_Y, 0.15)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (RIGHT_X, FRONT_Y, 0.15), (RIGHT_X, FRONT_Y - 0.01, 0.04)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (RIGHT_X, FRONT_Y - 0.01, 0.04), (RIGHT_X, FRONT_Y - 0.08, 0.01)),
    # Hind legs: hip, hock, paw
    ("1_Left_Limb_0", "Pelvis", (LEFT_X, HIND_Y, 0.36), (LEFT_X, HIND_Y + 0.01, 0.15)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (LEFT_X, HIND_Y + 0.01, 0.15), (LEFT_X, HIND_Y, 0.04)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (LEFT_X, HIND_Y, 0.04), (LEFT_X, HIND_Y - 0.07, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (RIGHT_X, HIND_Y, 0.36), (RIGHT_X, HIND_Y + 0.01, 0.15)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (RIGHT_X, HIND_Y + 0.01, 0.15), (RIGHT_X, HIND_Y, 0.04)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (RIGHT_X, HIND_Y, 0.04), (RIGHT_X, HIND_Y - 0.07, 0.01)),
    # The curled tail: up off the rump, over and round
    ("Tail_0", "Pelvis", (0, 0.3, 0.5), (0, 0.4, 0.62)),
    ("Tail_1", "Tail_0", (0, 0.4, 0.62), (0, 0.46, 0.74)),
    ("Tail_2", "Tail_1", (0, 0.46, 0.74), (0, 0.38, 0.8)),
]

# The mouth (read off a slice through the muzzle): open a little, 13 cm wide (x -0.08..0.05), its line 0.635 up at the
# corner rising to 0.647 at the front so the two bottom teeth (up to 0.645) go with the jaw and the upper lip (from
# 0.65) stays; the chin juts forward to y -0.6 and runs down to 0.53
MOUTH = dict(hinge_y=-0.51, tip_y=-0.6, top_hinge=0.635, top_tip=0.647)
BONES.append(("Jaw_0", "Head_0", (-0.015, -0.51, 0.625), (-0.015, -0.59, 0.585)))
JAW = rig_kit.jaw_share(bottom=0.53, half_width=0.1, mid_x=-0.015, top_blend=0.003, **MOUTH)

params = rig_kit.Params()
params.leg_top = 0.3  # the body's underside is about 0.2 up
params.leg_full = 0.14
params.leg_core = 0.09  # his paws are about 20 cm wide: a narrower reach left their inner edges on the body,
params.leg_radius = 0.15  # stretching whenever a leg moved
params.belly_mid = 0.03
params.tail_from = 0.28
params.head_from = -0.15

# Moving in one piece without stretching (owner 2026-11-09: "sniff is stretching its head... check all animations make
# sure nothing is stretching"; tools/blender/check_stretch.py measures it). skin()'s nearest-bone weights left the back
# of his big head (behind y -0.15) on the spine and pelvis, so the head stretched whenever it moved, and its smoothing
# spread the ears' and the tail's bones onto the chest, the cheeks and the rump. After skin():
# - the head (above the neck line: 0.48 up at the front, rising to 0.6 behind y 0, nothing behind y 0.12) goes to the
#   head's bones (rig_kit.confine);
# - each ear (its beige and grey-brown, and the white fur within EAR_REACH of it) follows its ear bone by height: none
#   at the crown where it hangs from (EAR_TOP), all of it from EAR_FREE down, blurred EAR_BLUR rings along the ear so
#   its edge against the cheek fades instead of tearing; no other vertex follows the ear;
# - the tail (above the rump, which tops out at 0.58, behind y 0.22) goes to the tail's bones, which fade out over the
#   rump's top (rig_kit.restrict).
HEAD_BONES = ("Head_0", "Ear_Left_0", "Ear_Right_0", "Jaw_0")
TAIL_BONES = ("Tail_0", "Tail_1", "Tail_2")
EAR_REACH = 0.035
EAR_TOP, EAR_FREE = 0.86, 0.62
EAR_BLUR = 4


def _smooth(value, zero, one):
    t = min(1.0, max(0.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


def head_share(p):
    behind = _smooth(p.y, -0.15, 0.0)
    floor = 0.48 * (1 - behind) + 0.6 * behind
    return _smooth(p.z, floor, floor + 0.07) * (1 - _smooth(p.y, 0.05, 0.12))


def tail_share(p):
    return _smooth(p.z, 0.58, 0.63) * _smooth(p.y, 0.2, 0.26)


def ears(mesh):
    """(left ear's vertex indices, right ear's), by the ears' colour"""
    from mathutils import kdtree

    colours = rig_kit.vertex_colours(mesh)
    world = [mesh.matrix_world @ v.co for v in mesh.data.vertices]

    def near(p):
        return abs(p.x) > 0.1 and p.z > 0.33 and p.y < -0.13  # the ears' back edges stop at y -0.15

    coloured = []
    for i, p in enumerate(world):
        rgb = colours.get(i)
        if rgb and near(p) and (max(rgb) < 0.7 or (max(rgb) - min(rgb)) / max(max(rgb), 1e-6) > 0.12):
            coloured.append(i)
    tree = kdtree.KDTree(max(1, len(coloured)))
    for k, i in enumerate(coloured):
        tree.insert(world[i], k)
    tree.balance()
    left, right = set(), set()
    for i, p in enumerate(world):
        if coloured and near(p) and tree.find(p)[2] < EAR_REACH:
            (left if p.x > 0 else right).add(i)
    return left, right


def stiffen(mesh):
    world = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    rig_kit.confine(mesh, HEAD_BONES, head_share, "Head_0")
    left, right = ears(mesh)
    for bone, members in (("Ear_Left_0", left), ("Ear_Right_0", right)):
        field = [_smooth(-world[i].z, -EAR_TOP, -EAR_FREE) if i in members else 0.0 for i in range(len(world))]
        # blurred inside the ear only: blurred onto the chest fur by its tip, the chest followed the ear
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
        "Jaw_0": (25, 0, 0),
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
    folder = os.path.join(rig_kit.REPO, "assets", "blender", "Pish")
    for view, direction in (("front", Vector((0, -1, 0.15))), ("side", Vector((1, 0, 0.1))),
                            ("three_quarter", Vector((0.75, -0.7, 0.45)))):
        cam.location = middle + direction.normalized() * 3.2
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"Pish_pose_{view}.png")
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.save_as_mainfile(filepath=os.path.join(rig_kit.REPO, "assets", "blender", "Pish", "Pish.blend"))
mesh = bpy.data.objects["Pish_Dog"]
rig_kit.optimize(mesh, "Pish")
rig_kit.mouth_cut(mesh, JAW, cavity_color=(0.12, 0.05, 0.06), **MOUTH)
rig = rig_kit.build_rig("PishRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
stiffen(mesh)
rig_kit.reweight_jaw(mesh, JAW)
if os.environ.get("POSE", "0") == "1":
    test_pose(rig)
elif os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Pish", rig, mesh)
