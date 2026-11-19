"""Rigs Bramblequake, the Bloom Epic (owner 2026-11-19: "Bramblequake and Leonbloom", concept A of three): a massive
armoured thorn ankylosaur, dark bark plates with big green thorns and pink-blossomed vines over its back, mossy
shoulders, a beaked head with two curved wooden horns, thick dark-green legs with bark-brown claws and a spiked seed-pod
club at the end of its tail. Very dangerous and big, like every Epic.

Meshy image-to-3D through the Blender MCP from the concept cut out of its grey background
(assets/blender/Bramblequake/Bramblequake_concept.png), saved raw as Bramblequake_raw.glb (gitignored). Meshy built it
facing -Y, square on its legs and symmetric (front and top renders checked), so no turn is needed; its left front foot
stands a little ahead of its right, so each leg's bones are placed on their own.
Run in a background Blender:  blender -b --factory-startup --python tools/blender/rig_bramblequake.py
It imports the raw model, stands it on its feet's middle at 1 m tall, reduces it to about TARGET_TRIS triangles
(rig_kit.optimize), rigs it with bones named for src/shared/Util/PetRig.luau, skins it (rig_kit.skin) and locks the
tail's club to its last tail bone (it swings whole, never bends). Saves assets/blender/Bramblequake/Bramblequake.blend
and exports Bramblequake.fbx. POSES=1 also renders test poses.

Bone positions are read off orthographic renders with a 0.1 m grid (metres at 1 m tall, Blender space: Z up, facing
-Y, its left is +X).
"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Bramblequake"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, f"{NAME}_raw.glb")
TARGET_TRIS = 14000
CLUB_FROM = 0.86  # the tail's spiked club: everything behind this (Y) swings whole on Tail_3

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.30, 0.56), (0, 0.08, 0.58)),
    ("Spine_0", "Pelvis", (0, 0.08, 0.58), (0, -0.14, 0.60)),
    ("Spine_1", "Spine_0", (0, -0.14, 0.60), (0, -0.36, 0.58)),
    # A short thick neck under the shell's front edge; the head reaches forward to the beak
    ("Neck", "Spine_1", (0, -0.36, 0.58), (0, -0.56, 0.55)),
    ("Head_0", "Neck", (0, -0.56, 0.55), (0, -0.86, 0.50)),
    # The tail runs straight back at the shell's middle height to the club
    ("Tail_0", "Pelvis", (0, 0.38, 0.60), (0, 0.56, 0.61)),
    ("Tail_1", "Tail_0", (0, 0.56, 0.61), (0, 0.74, 0.61)),
    ("Tail_2", "Tail_1", (0, 0.74, 0.61), (0, 0.90, 0.62)),
    ("Tail_3", "Tail_2", (0, 0.90, 0.62), (0, 1.12, 0.62)),
    # Front legs (its left foot a little ahead of its right): shoulder, knee, ankle, claws
    ("0_Left_Limb_0", "Spine_1", (0.20, -0.34, 0.47), (0.22, -0.34, 0.24)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.22, -0.34, 0.24), (0.22, -0.34, 0.08)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.22, -0.34, 0.08), (0.22, -0.40, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.20, -0.26, 0.47), (-0.22, -0.26, 0.24)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.22, -0.26, 0.24), (-0.22, -0.26, 0.08)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.22, -0.26, 0.08), (-0.22, -0.32, 0.01)),
    # Hind legs: hip, knee, ankle, claws
    ("1_Left_Limb_0", "Pelvis", (0.20, 0.30, 0.48), (0.24, 0.30, 0.25)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.24, 0.30, 0.25), (0.25, 0.30, 0.08)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.25, 0.30, 0.08), (0.25, 0.24, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.20, 0.30, 0.48), (-0.24, 0.30, 0.25)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.24, 0.30, 0.25), (-0.25, 0.30, 0.08)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.25, 0.30, 0.08), (-0.25, 0.24, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.48  # the mossy shoulder pads and the shell's spikes above stay with the body
params.leg_full = 0.30
params.leg_core = 0.08
params.leg_radius = 0.15
params.belly_mid = 0.06
params.tail_from = 0.38
params.head_from = -0.38
params.smooth_radius = 0.03


def import_raw():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=RAW)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    assert len(meshes) == 1, f"expected one mesh in {RAW}, got {[o.name for o in meshes]}"
    mesh = meshes[0]
    mesh.data.transform(mesh.matrix_world)
    mesh.parent = None
    mesh.matrix_world.identity()
    for other in [o for o in bpy.data.objects if o is not mesh]:
        bpy.data.objects.remove(other, do_unlink=True)
    mesh.name = mesh.data.name = "Bramblequake_Body"
    return mesh


def feet_centre(co):
    """The middle of the four feet: the ground vertices split front and back, then left and right at the widest gap"""
    import numpy as np

    low = co[co[:, 2] < co[:, 2].min() + 0.06 * (co[:, 2].max() - co[:, 2].min())]
    mid_y = (low[:, 1].min() + low[:, 1].max()) / 2
    centres = []
    for part in (low[low[:, 1] < mid_y], low[low[:, 1] >= mid_y]):
        xs = np.sort(part[:, 0])
        gap = int(np.argmax(np.diff(xs)))
        split = (xs[gap] + xs[gap + 1]) / 2
        centres += [part[part[:, 0] < split].mean(0), part[part[:, 0] >= split].mean(0)]
    return np.mean(centres, axis=0)


def stand(mesh):
    """On its feet's middle at 1 m tall"""
    import numpy as np

    me = mesh.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centre = feet_centre(co)
    co -= (centre[0], centre[1], co[:, 2].min())
    co /= co[:, 2].max()
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def pose_tests(rig):
    """Renders the poses the game puts it in, to catch tearing: a walk's stride, a heavy stomp (rearing a little), a
    head-down charge, the tail's club swinging"""
    out = os.path.join(FOLDER, "poses")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = 500
    world = bpy.data.worlds.new("w")
    world.color = (0.35, 0.35, 0.4)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (math.radians(45), 0, math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (2.6, -2.2, 1.1)
    cam.rotation_euler = (Vector((0, 0.15, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    poses = {
        "rest": {},
        "stride": {"0_Left_Limb_0": ("X", -22), "1_Right_Limb_0": ("X", -22), "0_Right_Limb_0": ("X", 22),
                   "1_Left_Limb_0": ("X", 22), "0_Left_Limb_1": ("X", 25), "1_Right_Limb_1": ("X", 20)},
        "rear": {"Pelvis": ("X", -12), "0_Left_Limb_0": ("X", -25), "0_Right_Limb_0": ("X", -25), "Neck": ("X", -10)},
        "charge": {"Neck": ("X", 20), "Head_0": ("X", 10)},
        "tail_swing": {"Tail_0": ("Z", 18), "Tail_1": ("Z", 18), "Tail_2": ("Z", 15), "Tail_3": ("Z", 10)},
    }
    for label, turns in poses.items():
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            if pb.name in turns:
                axis, degrees = turns[pb.name]
                world_axis = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
                local = (pb.bone.matrix_local.to_3x3().inverted() @ world_axis).normalized()
                pb.rotation_quaternion = Quaternion(local, math.radians(degrees))
        bpy.context.view_layer.update()
        scene.render.filepath = os.path.join(out, f"{label}.png")
        bpy.ops.render.render(write_still=True)
        print("posed", label)
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)


mesh = import_raw()
os.makedirs(FOLDER, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FOLDER, f"{NAME}.blend"))
stand(mesh)
rig_kit.optimize(mesh, NAME, TARGET_TRIS)
rig = rig_kit.build_rig(NAME + "Rig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
club = {v.index for v in mesh.data.vertices if v.co.y > CLUB_FROM}
rig_kit.confine(mesh, ["Tail_3"], lambda _p: 0.0, "Tail_3", whole=lambda i: i in club)
print("club vertices locked to Tail_3:", len(club))
dims = mesh.dimensions
print(f"mesh: {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")
if os.environ.get("POSES") == "1":
    pose_tests(rig)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
