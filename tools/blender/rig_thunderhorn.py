"""Rigs Thunderhorn, a fierce thunder stag (an Epic, so very dangerous and big). Remade 2026-11-16 (owner: "its still
sideways. remodel thunderhorn"; picked concept B of two): Meshy image-to-3D through the Blender MCP from the concept
cut out of its grey background (assets/blender/Thunderhorn/Thunderhorn_concept.png; drawn in a strict neutral pose, the
head in line with the body), saved raw as assets/blender/Thunderhorn/Thunderhorn_raw.glb (gitignored): a heavy-set
cream stag with a storm-grey cloud mane on its neck and chest marked with yellow lightning, gold shoulder armour and a
gold crown on its forehead, gold hooves and enormous golden antlers with lightning tips.

Meshy built it facing -Y and square on its legs; only its head came out turned 7.5 degrees to its left and leaning 3
(found by how mirror-symmetric the face is at each turn, scratch head_symmetry.py: 15.5 mm off at 0, 3.8 mm at -7.5).
Run in a background Blender:  blender -b --factory-startup --python tools/blender/rig_thunderhorn.py
It imports the raw model, stands it on its feet's middle at 1 m tall, turns the head back in line (HEAD_TURN about
the top of the neck and HEAD_LEAN about its forward axis, blended down the neck; the golden antlers and crown turn
whole), reduces it to about TARGET_TRIS triangles (rig_kit.optimize), opens its closed mouth along the painted line
(rig_kit.mouth_cut, a jaw on Jaw_0 for bites and roars), rigs it with bones named for src/shared/Util/PetRig.luau,
skins it (rig_kit.skin) and locks the antlers and crown to the head (they move with it, never bend). Saves
assets/blender/Thunderhorn/Thunderhorn.blend and exports Thunderhorn.fbx. POSES=1 also renders test poses.

Bone positions are read off the mesh (metres at 1 m tall, Blender space: Z up, facing -Y, its left is +X).
"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Thunderhorn"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Thunderhorn_raw.glb")
TARGET_TRIS = 14000
# The head (at 1 m tall): turned back HEAD_TURN degrees about a vertical axis through HEAD_PIVOT (x, y), then leaned
# back HEAD_LEAN about the forward axis at LEAN_Z; each vertex by its share: none below HEAD_LOW, all above HEAD_HIGH,
# fading out behind the neck (NECK_BACK); the golden antlers and crown take all of it
HEAD_TURN = -7.5
HEAD_LEAN = -3.0
HEAD_PIVOT = (0.0, -0.27)
LEAN_Z = 0.68
HEAD_LOW, HEAD_HIGH = 0.56, 0.62
NECK_BACK = (-0.24, -0.18)
# The closed mouth's painted line, from its corner (hinge) to the nose (tip), and the chin's underside
MOUTH = dict(hinge_y=-0.40, tip_y=-0.47, top_hinge=0.643, top_tip=0.648)
JAW = rig_kit.jaw_share(bottom=0.62, half_width=0.035, top_blend=0.003, **MOUTH)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.32, 0.43), (0, 0.12, 0.45)),
    ("Spine_0", "Pelvis", (0, 0.12, 0.45), (0, -0.06, 0.47)),
    ("Spine_1", "Spine_0", (0, -0.06, 0.47), (0, -0.22, 0.5)),
    # The neck rises under the cloud mane to the back of the skull; the head reaches forward to the nose
    ("Neck", "Spine_1", (0, -0.22, 0.5), (0, -0.28, 0.66)),
    ("Head_0", "Neck", (0, -0.28, 0.66), (0, -0.46, 0.65)),
    ("Jaw_0", "Head_0", (0, -0.39, 0.643), (0, -0.465, 0.636)),
    ("Tail_0", "Pelvis", (0, 0.40, 0.47), (0, 0.44, 0.43)),
    ("Tail_1", "Tail_0", (0, 0.44, 0.43), (0, 0.46, 0.36)),
    # Front legs: shoulder, knee, fetlock, hoof
    ("0_Left_Limb_0", "Spine_1", (0.09, -0.21, 0.40), (0.115, -0.205, 0.2)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.115, -0.205, 0.2), (0.121, -0.2, 0.08)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.121, -0.2, 0.08), (0.127, -0.25, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.09, -0.21, 0.40), (-0.115, -0.205, 0.2)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.115, -0.205, 0.2), (-0.121, -0.2, 0.08)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.121, -0.2, 0.08), (-0.126, -0.25, 0.01)),
    # Hind legs: hip, hock, fetlock, hoof
    ("1_Left_Limb_0", "Pelvis", (0.075, 0.17, 0.43), (0.09, 0.262, 0.24)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.09, 0.262, 0.24), (0.1, 0.282, 0.08)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.1, 0.282, 0.08), (0.106, 0.243, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.075, 0.17, 0.43), (-0.09, 0.262, 0.24)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.09, 0.262, 0.24), (-0.1, 0.282, 0.08)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.1, 0.282, 0.08), (-0.107, 0.243, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.40
params.leg_full = 0.27
params.leg_core = 0.035
params.leg_radius = 0.07
params.belly_mid = 0.03
params.tail_from = 0.40
params.head_from = -0.15  # the cloud mane on the chest stays with the body; in front of this it follows the neck
params.smooth_radius = 0.03


def ramp(value, zero, one):
    t = max(0.0, min(1.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


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
    mesh.name = mesh.data.name = "Thunderhorn_Stag"
    return mesh


def feet_centre(co):
    """The middle of the four feet: the ground vertices split front and back, then left and right at the widest gap"""
    import numpy as np

    low = co[co[:, 2] < co[:, 2].min() + 0.06]
    mid_y = (low[:, 1].min() + low[:, 1].max()) / 2
    centres = []
    for part in (low[low[:, 1] < mid_y], low[low[:, 1] >= mid_y]):
        xs = np.sort(part[:, 0])
        gap = int(np.argmax(np.diff(xs)))
        split = (xs[gap] + xs[gap + 1]) / 2
        centres += [part[part[:, 0] < split].mean(0), part[part[:, 0] >= split].mean(0)]
    return np.mean(centres, axis=0)


def is_head_gold(index, p, colours):
    """The golden antlers (above the ears) and the crown on the forehead; not the shoulder armour or the hooves"""
    rgb = colours.get(index)
    if not rgb or not rig_kit.is_gold(rgb):
        return False
    return (p[2] > 0.74 and p[1] < -0.1) or (p[2] > 0.64 and p[1] < -0.3)


def straighten(mesh):
    """On its feet's middle at 1 m tall, the head turned back in line and leaned upright"""
    import numpy as np

    me = mesh.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centre = feet_centre(co)
    co -= (centre[0], centre[1], co[:, 2].min())
    co /= co[:, 2].max()
    colours = rig_kit.vertex_colours(mesh)
    share = np.array([ramp(z, HEAD_LOW, HEAD_HIGH) for z in co[:, 2]]) * (1 - np.array([ramp(y, *NECK_BACK) for y in co[:, 1]]))
    for index in range(len(co)):
        if is_head_gold(index, co[index], colours):
            share[index] = 1.0
    turn = np.radians(HEAD_TURN) * share
    dx, dy = co[:, 0] - HEAD_PIVOT[0], co[:, 1] - HEAD_PIVOT[1]
    co[:, 0] = HEAD_PIVOT[0] + dx * np.cos(turn) - dy * np.sin(turn)
    co[:, 1] = HEAD_PIVOT[1] + dx * np.sin(turn) + dy * np.cos(turn)
    lean = np.radians(HEAD_LEAN) * share
    dz, dx = co[:, 2] - LEAN_Z, co[:, 0].copy()
    co[:, 0] = dx * np.cos(lean) - dz * np.sin(lean)
    co[:, 2] = LEAN_Z + dx * np.sin(lean) + dz * np.cos(lean)
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def pose_tests(rig):
    """Renders the poses the game puts it in, to catch tearing: a walk's stride, rearing for its thunder call, a bite's
    lunge with the jaw open, the tail swishing"""
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
    cam.location = (2.0, -1.8, 0.9)
    cam.rotation_euler = (Vector((0, 0.0, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    poses = {
        "rest": {},
        "stride": {"0_Left_Limb_0": ("X", -25), "1_Right_Limb_0": ("X", -25), "0_Right_Limb_0": ("X", 25),
                   "1_Left_Limb_0": ("X", 25), "0_Left_Limb_1": ("X", 30), "1_Right_Limb_1": ("X", 25)},
        "rear": {"Pelvis": ("X", -20), "0_Left_Limb_0": ("X", -35), "0_Right_Limb_0": ("X", -35),
                 "1_Left_Limb_0": ("X", 20), "1_Right_Limb_0": ("X", 20), "Neck": ("X", -10)},
        "bite": {"Neck": ("X", 25), "Head_0": ("X", 15), "Jaw_0": ("X", 25)},
        "tail_swish": {"Tail_0": ("Z", 20), "Tail_1": ("Z", 20)},
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
straighten(mesh)
rig_kit.optimize(mesh, NAME, TARGET_TRIS)
rig_kit.mouth_cut(mesh, JAW, cavity_color=(0.16, 0.05, 0.06), **MOUTH)
rig = rig_kit.build_rig(NAME + "Rig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
colours = rig_kit.vertex_colours(mesh)
head_gold = {v.index for v in mesh.data.vertices if is_head_gold(v.index, v.co, colours)}
rig_kit.confine(mesh, ["Head_0"], lambda _p: 0.0, "Head_0", whole=lambda i: i in head_gold)
print("antler and crown vertices locked to the head:", len(head_gold))
rig_kit.reweight_jaw(mesh, JAW)
dims = mesh.dimensions
print(f"mesh: {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")
if os.environ.get("POSES") == "1":
    pose_tests(rig)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
