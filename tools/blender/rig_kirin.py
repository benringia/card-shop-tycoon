"""Rigs the Tideborne Kirin, a celestial sea kirin (a Legendary, so godlike and big; owner 2026-11-14: "also kirin",
concept A of three, assets/blender/Kirin/kirin_concept_A.png: today's Kirin made big and heavy-set). Meshy image-to-3D
through the Blender MCP from the concept redrawn in a neutral pose (assets/blender/Kirin/kirin_neutral_A.png: square on
all fours), saved raw as assets/blender/Kirin/Kirin_raw.glb (gitignored): a heavy pearl-white kirin with aqua scales,
a big seafoam wave mane, golden antlers and halo, golden chest armour and water flames round its hooves, its wave tail
curling up on its left side.

Meshy copied the concept's three-quarter view: the body stood turned about 47 degrees and the head looked a further 35
degrees to its left. Run in a background Blender:  blender -b --factory-startup --python tools/blender/rig_kirin.py
It imports the raw model, turns it to face -Y (TURN), stands it on its feet's middle, turns the head back in line
(HEAD_TURN about the top of the neck, blended down the neck so the mane doesn't tear), scales it to 1 m tall, marks the
golden antlers and halo, reduces it to about 18,000 triangles (rig_kit.optimize), rigs it with bones named for
src/shared/Util/PetRig.luau, skins it (rig_kit.skin), gives the water flames round each hoof to that leg, and locks the antlers and halo to the head (they move with it,
never bend). Saves assets/blender/Kirin/Kirin.blend and exports Kirin.fbx. POSES=1 also renders test poses.

It walks on four legs at an unhurried stride; each left leg stands a little behind its right (Meshy's stance), so each
leg's bones are placed on their own. Bone positions are read off the mesh (metres at 1 m tall, Blender space: Z up,
facing -Y, its left is +X).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Kirin"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Kirin_raw.glb")
TARGET_TRIS = 18000
TURN = 47.5  # degrees about the vertical: the body stood turned this far (43 left its white coat 4.5 degrees to its right:
# owner 2026-11-14 "a little sideways"; measured by the coat's mirror symmetry)
# The head, in the raw model's metres (1.8 m tall): turned back HEAD_TURN degrees about a vertical axis through
# HEAD_PIVOT (x, y); each vertex by its share: none below HEAD_LOW, all above HEAD_HIGH, fading out behind the neck
HEAD_TURN = -39.5  # applied after TURN: -35 with TURN 43 (the same head line)
HEAD_PIVOT = (0.0, -0.3)
HEAD_LOW, HEAD_HIGH = 1.05, 1.25
NECK_BACK = (0.05, 0.2)
# The water flames round each hoof reach further out than a leg's skin (they stayed behind as smears when a leg moved):
# everything below HOOF_HIGH (all of it below HOOF_LOW) within HOOF_REACH of a hoof across goes to that leg's lower bones
HOOF_LOW, HOOF_HIGH, HOOF_REACH = 0.12, 0.17, 0.15
# The wave tail is one solid curl bending back over the rump: skinned along its chain it smeared when it swished
# (owner 2026-11-14 "kirin tail is stretching"), so it swings whole on Tail_0 from the rump. Its aqua vertices behind
# TAIL_ROOT (all of it past the second number) above TAIL_LOW (a hind leg's hoof flames); the white rump stays
TAIL_ROOT = (0.37, 0.42)
TAIL_LOW = 0.28
# The golden antlers and halo: pieces at least half gold with their middle above HEAD_PIECES_LOW (1 m tall)
HEAD_PIECES_LOW = 0.74

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.32, 0.5), (0, 0.14, 0.52)),
    ("Spine_0", "Pelvis", (0, 0.14, 0.52), (0, -0.04, 0.52)),
    ("Spine_1", "Spine_0", (0, -0.04, 0.52), (0, -0.24, 0.5)),
    ("Neck", "Spine_1", (0, -0.24, 0.5), (0, -0.17, 0.72)),
    ("Head_0", "Neck", (0, -0.17, 0.72), (0, -0.33, 0.68)),
    # The wave tail curls up on its left side
    ("Tail_0", "Pelvis", (0, 0.42, 0.5), (0.041, 0.505, 0.45)),
    ("Tail_1", "Tail_0", (0.041, 0.505, 0.45), (0.148, 0.543, 0.5)),
    ("Tail_2", "Tail_1", (0.148, 0.543, 0.5), (0.2, 0.517, 0.63)),
    ("Tail_3", "Tail_2", (0.2, 0.517, 0.63), (0.155, 0.454, 0.77)),
    # Legs: shoulder or hip, knee or hock, the hoof. Each left leg stands a little behind its right (Meshy copied
    # the three-quarter drawing). Tail and leg positions measured at TURN 43, turned 4.5 degrees with the body.
    ("0_Left_Limb_0", "Spine_1", (0.129, -0.11, 0.42), (0.095, -0.127, 0.22)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.095, -0.127, 0.22), (0.095, -0.168, 0.08)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.095, -0.168, 0.08), (0.122, -0.211, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.125, -0.19, 0.42), (-0.134, -0.211, 0.22)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.134, -0.211, 0.22), (-0.157, -0.252, 0.08)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.157, -0.252, 0.08), (-0.133, -0.291, 0.01)),
    ("1_Left_Limb_0", "Pelvis", (0.076, 0.307, 0.44), (0.086, 0.308, 0.24)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.086, 0.308, 0.24), (0.095, 0.318, 0.14)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.095, 0.318, 0.14), (0.123, 0.26, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.109, 0.242, 0.44), (-0.112, 0.242, 0.24)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.112, 0.242, 0.24), (-0.115, 0.255, 0.14)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.115, 0.255, 0.14), (-0.122, 0.181, 0.01)),
]

params = rig_kit.Params()
params.leg_top = 0.38
params.leg_full = 0.24
params.leg_core = 0.04
params.leg_radius = 0.08
params.belly_mid = 0.03
params.tail_from = 0.38
params.head_from = 0.05  # the mane down the neck follows the neck and head
params.smooth_radius = 0.035


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
    mesh.name = mesh.data.name = "Kirin_Body"
    return mesh


def feet_centre(co):
    """The middle of the four feet: the ground vertices split front and back, then left and right at the widest gap"""
    import numpy as np

    low = co[co[:, 2] < co[:, 2].min() + 0.03]
    mid_y = (low[:, 1].min() + low[:, 1].max()) / 2
    centres = []
    for part in (low[low[:, 1] < mid_y], low[low[:, 1] >= mid_y]):
        xs = np.sort(part[:, 0])
        gap = int(np.argmax(np.diff(xs)))
        split = (xs[gap] + xs[gap + 1]) / 2
        centres += [part[part[:, 0] < split].mean(0), part[part[:, 0] >= split].mean(0)]
    return np.mean(centres, axis=0)


def straighten(mesh):
    """Facing -Y on its feet's middle, the head turned back in line, then 1 m tall"""
    import numpy as np

    me = mesh.data
    me.transform(Matrix.Rotation(math.radians(TURN), 4, "Z"))
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centre = feet_centre(co)
    co -= (centre[0], centre[1], co[:, 2].min())
    share = np.array([ramp(z, HEAD_LOW, HEAD_HIGH) for z in co[:, 2]]) * (1 - np.array([ramp(y, *NECK_BACK) for y in co[:, 1]]))
    angle = np.radians(HEAD_TURN) * share
    dx, dy = co[:, 0] - HEAD_PIVOT[0], co[:, 1] - HEAD_PIVOT[1]
    co[:, 0] = HEAD_PIVOT[0] + dx * np.cos(angle) - dy * np.sin(angle)
    co[:, 1] = HEAD_PIVOT[1] + dx * np.sin(angle) + dy * np.cos(angle)
    co /= co[:, 2].max()
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def lock_hooves(mesh):
    for pair in ("0", "1"):
        for side in ("Left", "Right"):
            prefix = f"{pair}_{side}_Limb_"
            hoof = Vector(next(t for n, _p, _h, t in BONES if n == prefix + "2"))
            bones = [prefix + "1", prefix + "2"]

            def share(p, hoof=hoof):
                near = (Vector((p.x, p.y, 0)) - Vector((hoof.x, hoof.y, 0))).length < HOOF_REACH
                same_side = (p.x > 0) == (hoof.x > 0) or abs(p.x) < 0.02
                return ramp(p.z, HOOF_HIGH, HOOF_LOW) if near and same_side else 0.0

            rig_kit.confine(mesh, bones, share, bones[1])


def lock_tail(mesh):
    colours = rig_kit.vertex_colours(mesh)

    def is_tail(index):
        rgb = colours.get(index, (1, 1, 1))
        return max(rgb) - min(rgb) > 0.12  # aqua, not the white coat

    def share(p):
        return ramp(p.y, *TAIL_ROOT) * ramp(p.z, TAIL_LOW, TAIL_LOW + 0.04)

    # the rest of the chain folded into Tail_0 first, everywhere (the curl's tip comes back near the rump, so even the
    # root's blend held some Tail_3; the wave's white foam isn't aqua), then the tail claimed whole past its root
    chain = {mesh.vertex_groups[f"Tail_{i}"].index for i in range(1, 4)}
    base = mesh.vertex_groups["Tail_0"]
    for v in mesh.data.vertices:
        moved = sum(g.weight for g in v.groups if g.group in chain)
        if moved <= 0:
            continue
        own = next((g.weight for g in v.groups if g.group == base.index), 0.0)
        for index in chain:
            mesh.vertex_groups[index].remove([v.index])
        base.add([v.index], own + moved, "REPLACE")
    rig_kit.confine(mesh, ["Tail_0"], share, "Tail_0", only=is_tail)


def is_head_piece(centre, colours):
    return centre.z > HEAD_PIECES_LOW and sum(1 for rgb in colours if rig_kit.is_gold(rgb)) / len(colours) >= 0.5


def pose_tests(rig):
    """Renders the poses the game puts it in, to catch tearing: a walk's stride, rearing for its blessing, a strike's
    lunge with the head low, the tail swishing"""
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
    cam.rotation_euler = (Vector((0, 0.05, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    # each bone turned about a world axis (degrees): legs, neck and head about X (across), the tail about Z (up)
    poses = {
        "rest": {},
        "stride": {"0_Left_Limb_0": ("X", -25), "1_Right_Limb_0": ("X", -25), "0_Right_Limb_0": ("X", 25),
                   "1_Left_Limb_0": ("X", 25), "0_Left_Limb_1": ("X", 30), "1_Right_Limb_1": ("X", 25)},
        "rear": {"Pelvis": ("X", -20), "0_Left_Limb_0": ("X", -35), "0_Right_Limb_0": ("X", -35),
                 "1_Left_Limb_0": ("X", 20), "1_Right_Limb_0": ("X", 20), "Neck": ("X", -10)},
        "strike": {"Spine_1": ("X", 8), "Neck": ("X", 30), "Head_0": ("X", 20)},
        "tail_swish": {f"Tail_{i}": ("Z", 18) for i in range(4)},
    }
    for label, turns in poses.items():
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            if pb.name in turns:
                axis, degrees = turns[pb.name]
                world = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
                local = (pb.bone.matrix_local.to_3x3().inverted() @ world).normalized()
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
print("antler and halo pieces marked:", rig_kit.mark_pieces(mesh, "HeadMark", is_head_piece), "vertices")
rig_kit.optimize(mesh, NAME, TARGET_TRIS)
head = rig_kit.marked(mesh, "HeadMark")  # read before skin() clears the vertex groups
rig = rig_kit.build_rig(NAME + "Rig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
lock_hooves(mesh)
lock_tail(mesh)
rig_kit.confine(mesh, ["Head_0"], lambda _p: 0.0, "Head_0", whole=lambda i: i in head)
print("antler and halo vertices locked to the head:", len(head))
dims = mesh.dimensions
print(f"mesh: {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")
if os.environ.get("POSES") == "1":
    pose_tests(rig)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
