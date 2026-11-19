"""Rigs Leonbloom, the Bloom Legendary (owner 2026-11-19: "Bramblequake and Leonbloom", concept C of three): a colossal
lion god with a sage-green body, an enormous mane of big pink, white and gold flowers and broad leaves, golden branch
antlers, a glowing golden sun-seed gem on its forehead, golden leaf armour on its shoulders and chest, golden claws and
a long tail ending in a big pink flower bud. Godlike and big, like every Legendary.

The owner's pick looked at the viewer, so it was redrawn neutral first (assets/blender/Leonbloom/concept_C_neutral.png,
gitignored: body and head facing the same way), cut out of its grey background (Leonbloom_concept.png) and made with
Meshy image-to-3D through the Blender MCP, saved raw as Leonbloom_raw.glb (gitignored). Meshy built it facing -Y,
square on its legs and symmetric; only its tail curled off to its right (the bud about 0.19 m out at 1 m tall), so the
tail is bent back straight behind it (TAIL_SHIFT, the neutral rule: tail relaxed straight back).
Run in a background Blender:  blender -b --factory-startup --python tools/blender/rig_leonbloom.py
It imports the raw model, stands it on its feet's middle at 1 m tall, straightens the tail, reduces it to about
TARGET_TRIS triangles (rig_kit.optimize), rigs it with bones named for src/shared/Util/PetRig.luau, skins it
(rig_kit.skin) and locks the antlers and forehead gem to the head and the bud to the last tail bone (they move whole,
never bend). Saves assets/blender/Leonbloom/Leonbloom.blend and exports Leonbloom.fbx. POSES=1 also renders test poses.

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

NAME = "Leonbloom"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, f"{NAME}_raw.glb")
TARGET_TRIS = 16000
# The tail (behind TAIL_FROM_Y and over TAIL_OVER_Z) curls to its right: each vertex moves TAIL_SHIFT across (+X, to
# its left) by how far back it is, none at TAIL_FROM_Y, all of it from TAIL_FULL_Y (the bud)
TAIL_FROM_Y, TAIL_FULL_Y, TAIL_OVER_Z = 0.33, 0.58, 0.40
TAIL_SHIFT = 0.19
BUD_FROM = 0.55  # the flower bud: everything behind this (Y) swings whole on Tail_3

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.24, 0.46), (0, 0.06, 0.46)),
    ("Spine_0", "Pelvis", (0, 0.06, 0.46), (0, -0.10, 0.47)),
    ("Spine_1", "Spine_0", (0, -0.10, 0.47), (0, -0.24, 0.50)),
    # The neck rises inside the mane to the back of the skull; the head reaches forward to the nose
    ("Neck", "Spine_1", (0, -0.24, 0.50), (0, -0.36, 0.62)),
    ("Head_0", "Neck", (0, -0.36, 0.62), (0, -0.50, 0.62)),
    # The tail (once straightened) runs back from the rump and lifts to the bud
    ("Tail_0", "Pelvis", (0, 0.30, 0.50), (0, 0.40, 0.505)),
    ("Tail_1", "Tail_0", (0, 0.40, 0.505), (0, 0.48, 0.51)),
    ("Tail_2", "Tail_1", (0, 0.48, 0.51), (0, 0.55, 0.55)),
    ("Tail_3", "Tail_2", (0, 0.55, 0.55), (0, 0.68, 0.62)),
    # Front legs: shoulder, elbow, wrist, paw
    ("0_Left_Limb_0", "Spine_1", (0.15, -0.25, 0.40), (0.17, -0.26, 0.20)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.17, -0.26, 0.20), (0.17, -0.27, 0.07)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.17, -0.27, 0.07), (0.17, -0.33, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.15, -0.25, 0.40), (-0.17, -0.26, 0.20)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.17, -0.26, 0.20), (-0.17, -0.27, 0.07)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.17, -0.27, 0.07), (-0.17, -0.33, 0.01)),
    # Hind legs: hip, hock, ankle, paw
    ("1_Left_Limb_0", "Pelvis", (0.15, 0.20, 0.42), (0.19, 0.30, 0.20)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.19, 0.30, 0.20), (0.21, 0.30, 0.07)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.21, 0.30, 0.07), (0.21, 0.24, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.15, 0.20, 0.42), (-0.19, 0.30, 0.20)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.19, 0.30, 0.20), (-0.21, 0.30, 0.07)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.21, 0.30, 0.07), (-0.21, 0.24, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.38  # the golden shoulder armour and the mane above stay with the body
params.leg_full = 0.24
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.04
params.tail_from = 0.30
params.head_from = -0.22  # the mane on the shoulders stays with the body; in front of this it follows the neck
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
    mesh.name = mesh.data.name = "Leonbloom_Body"
    return mesh


def ramp(value, zero, one):
    t = max(0.0, min(1.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


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
    """On its feet's middle at 1 m tall, the tail bent back straight behind it"""
    import numpy as np

    me = mesh.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centre = feet_centre(co)
    co -= (centre[0], centre[1], co[:, 2].min())
    co /= co[:, 2].max()
    tail = (co[:, 1] > TAIL_FROM_Y) & (co[:, 2] > TAIL_OVER_Z)
    shift = np.array([ramp(y, TAIL_FROM_Y, TAIL_FULL_Y) for y in co[:, 1]]) * TAIL_SHIFT
    co[:, 0] += np.where(tail, shift, 0.0)
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    print("tail vertices straightened:", int(tail.sum()))


def is_head_gold(index, p, colours):
    """The golden antlers over the mane and the sun-seed gem on the forehead; not the shoulder and chest armour"""
    rgb = colours.get(index)
    if not rgb or not rig_kit.is_gold(rgb):
        return False
    return p[2] > 0.74 and p[1] < -0.12


def pose_tests(rig):
    """Renders the poses the game puts it in, to catch tearing: a walk's stride, rearing to roar, a pounce's lunge, the
    tail swishing its bud"""
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
    cam.location = (2.0, -1.9, 1.0)
    cam.rotation_euler = (Vector((0, 0.05, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    poses = {
        "rest": {},
        "stride": {"0_Left_Limb_0": ("X", -25), "1_Right_Limb_0": ("X", -25), "0_Right_Limb_0": ("X", 25),
                   "1_Left_Limb_0": ("X", 25), "0_Left_Limb_1": ("X", 30), "1_Right_Limb_1": ("X", 25)},
        "rear": {"Pelvis": ("X", -20), "0_Left_Limb_0": ("X", -35), "0_Right_Limb_0": ("X", -35),
                 "1_Left_Limb_0": ("X", 20), "1_Right_Limb_0": ("X", 20), "Neck": ("X", -12)},
        "lunge": {"Neck": ("X", 25), "Head_0": ("X", 15)},
        "tail_swish": {"Tail_0": ("Z", 20), "Tail_1": ("Z", 20), "Tail_2": ("Z", 15)},
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
colours = rig_kit.vertex_colours(mesh)
head_gold = {v.index for v in mesh.data.vertices if is_head_gold(v.index, v.co, colours)}
rig_kit.confine(mesh, ["Head_0"], lambda _p: 0.0, "Head_0", whole=lambda i: i in head_gold)
print("antler and gem vertices locked to the head:", len(head_gold))
bud = {v.index for v in mesh.data.vertices if v.co.y > BUD_FROM and v.co.z > TAIL_OVER_Z}
rig_kit.confine(mesh, ["Tail_3"], lambda _p: 0.0, "Tail_3", whole=lambda i: i in bud)
print("bud vertices locked to Tail_3:", len(bud))
dims = mesh.dimensions
print(f"mesh: {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")
if os.environ.get("POSES") == "1":
    pose_tests(rig)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
