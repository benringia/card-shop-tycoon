"""Rigs Pish, the tutorial's guide puppy (the owner's Shih Tzu), prepared by prep_pish.py (object "Pish_Dog" in
assets/blender/Pish/Pish_meshy.blend: 1 m tall, facing -Y, ~10,000 triangles, the light brown patch on its back).
Run in a background Blender:

  blender -b assets/blender/Pish/Pish_meshy.blend --python tools/blender/rig_pish.py

A chibi dog: a big round head (y -0.6..0, z 0.5..1.0) over a small body (y -0.3..0.35, z 0.2..0.58) on four short
legs (z 0..0.25; front feet at y -0.25, hind at 0.25, x +-0.16), floppy ears down the sides of its head and a
curled puff of a tail on its rump. Bones named for src/shared/Util/PetRig.luau, positions read off the mesh. Writes
assets/blender/Pish/Pish.fbx (EXPORT=0 skips it). POSE=1 renders a test pose (a stride, head turned, ears and tail
swung) to assets/blender/Pish/Pish_pose_<view>.png to check the skin.
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

params = rig_kit.Params()
params.leg_top = 0.3  # the body's underside is about 0.2 up
params.leg_full = 0.14
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.03
params.tail_from = 0.28
params.head_from = -0.15


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
    folder = os.path.join(rig_kit.REPO, "assets", "blender", "Pish")
    for view, direction in (("front", Vector((0, -1, 0.15))), ("side", Vector((1, 0, 0.1))),
                            ("three_quarter", Vector((0.75, -0.7, 0.45)))):
        cam.location = middle + direction.normalized() * 3.2
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"Pish_pose_{view}.png")
        bpy.ops.render.render(write_still=True)


rig, mesh = rig_kit.run("Pish", "Pish_Dog", BONES, params, export_now=os.environ.get("POSE", "0") != "1")
if os.environ.get("POSE", "0") == "1":
    test_pose(rig)
