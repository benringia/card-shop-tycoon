"""Rigs Solarion, the eclipse sun phoenix (a Legendary, so godlike and big; owner 2026-11-14: "change solarion model into
a legendary phoenix", concept C of three, assets/blender/Solarion/phoenix_concept_C.png; it replaces the sun god titan,
which replaced the voxel cerberus). Meshy image-to-3D through the Blender MCP from the concept redrawn in a neutral
pose (assets/blender/Solarion/phoenix_neutral_C.png: standing upright, wings straight out to the sides, legs apart),
saved raw as assets/blender/Solarion/Phoenix_raw.glb (gitignored). Right first time: symmetrical (mirror error about
2 mm), facing -Y, 1 m tall, two taloned feet, the sun ring halo with its star behind the head, golden helm and scale
armour, feather blades at the shoulders, three flame-ribbon tails hanging behind the legs to the ground.

Run in a background Blender:  blender -b --factory-startup --python tools/blender/rig_solarion.py
It imports the raw model, marks the halo's pieces, reduces it to about 18,000 triangles (rig_kit.optimize: a collapse decimation keeps the thin
flame feathers, which a voxel remesh would melt), rigs it with bones named for src/shared/Util/PetRig.luau and skins
it (rig_kit.skin), gives everything out past the torso to the wing bones, locks the halo to the head (it moves with the head, never bends with a wing), saves
assets/blender/Solarion/Solarion.blend and exports Solarion.fbx. POSES=1 also renders test poses (wings beating,
raised for the sunburst, swept forward for a strike, legs tucked for flight) to assets/blender/Solarion/poses/.

It flies (Party.CREATURE_MODELS flies = true): Wing_<Side>_0..2 run from the shoulder out along the wing to its raised
tip; the legs (0_<Side>_Limb_0..2: thigh, shin, the foot reaching forward to the talons) tuck up in flight; the flame
tail hangs straight down behind them (Tail_0..2). Bone positions are read off the mesh (metres, Blender space: Z up,
facing -Y, its left is +X).
"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Solarion"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Phoenix_raw.glb")
TARGET_TRIS = 18000  # a Legendary's feathers: at 12,000 the wings' backs turned to flat sheets (Roblox allows 20,000)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.03, 0.4), (0, 0.02, 0.5)),
    ("Spine_0", "Pelvis", (0, 0.02, 0.5), (0, 0.01, 0.58)),
    ("Spine_1", "Spine_0", (0, 0.01, 0.58), (0, 0.0, 0.66)),
    ("Neck", "Spine_1", (0, 0.0, 0.66), (0, -0.02, 0.73)),
    ("Head_0", "Neck", (0, -0.02, 0.73), (0, -0.07, 0.86)),
    # The three flame ribbons hang together, straight down behind the legs
    ("Tail_0", "Pelvis", (0, 0.08, 0.45), (0, 0.125, 0.33)),
    ("Tail_1", "Tail_0", (0, 0.125, 0.33), (0, 0.135, 0.2)),
    ("Tail_2", "Tail_1", (0, 0.135, 0.2), (0, 0.14, 0.08)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # The wings from the shoulder out to their raised tips, a little behind the body
        (f"Wing_{side}_0", "Spine_1", (sx * 0.08, 0.05, 0.6), (sx * 0.24, 0.08, 0.66)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.24, 0.08, 0.66), (sx * 0.39, 0.1, 0.71)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.39, 0.1, 0.71), (sx * 0.54, 0.11, 0.8)),
        # The legs: thigh to knee, shin to ankle, the foot reaching forward to the talons
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.09, 0.02, 0.42), (sx * 0.13, 0.02, 0.22)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.13, 0.02, 0.22), (sx * 0.18, 0.0, 0.08)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.18, 0.0, 0.08), (sx * 0.19, -0.12, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.45
params.leg_full = 0.3
params.leg_core = 0.06
params.leg_radius = 0.12
params.tail_from = 0.09
params.head_from = 0.14  # the halo behind the head belongs to it too
params.smooth_radius = 0.035

# The halo: in the raw model the gold ring, its rays and the star are their own pieces behind the head (the wing roots
# beside them are separate red pieces): a piece at least HALO_GOLD gold, its middle behind HALO_BEHIND, above HALO_LOW
# and within HALO_REACH across. Marked before the reduction welds everything into one piece.
HALO_GOLD = 0.6
HALO_BEHIND = 0.09
HALO_REACH = 0.32
HALO_LOW = 0.62


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
    mesh.name = mesh.data.name = "Solarion_Phoenix"
    return mesh


def is_halo(centre, colours):
    gold = sum(1 for rgb in colours if rig_kit.is_gold(rgb)) / len(colours)
    return gold >= HALO_GOLD and centre.y > HALO_BEHIND and centre.z > HALO_LOW and abs(centre.x) < HALO_REACH


def lock_halo(mesh, halo):
    rig_kit.confine(mesh, ["Head_0"], lambda _p: 0.0, "Head_0", whole=lambda i: i in halo)
    print("halo vertices locked to the head:", len(halo))


# The wings: everything further out than the torso (WING_FROM, all wing by WING_FULL) above the thighs belongs to that
# side's wing bones, so a flap never drags the body's feathers down with it or stretches the wing onto the legs
WING_FROM, WING_FULL, WING_LOW = 0.12, 0.18, 0.4


def ramp(value, zero, one):
    t = max(0.0, min(1.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


def lock_wings(mesh):
    for side, sign in (("Left", 1), ("Right", -1)):
        bones = [f"Wing_{side}_{i}" for i in range(3)]
        rig_kit.confine(mesh, bones, lambda p, sign=sign: ramp(sign * p.x, WING_FROM, WING_FULL) * ramp(p.z, WING_LOW, WING_LOW + 0.04), bones[0])


def pose_tests(rig):
    """Renders the poses the game puts it in, to catch tearing: flapping, the sunburst's raised wings, a strike's wings
    swept forward, legs tucked in flight"""
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
    cam.location = (1.4, -2.2, 1.0)
    cam.rotation_euler = (Vector((0, 0, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    # each bone turned about a world axis (degrees): wings about Y (forward), legs and head about X (across)
    poses = {
        "rest": {},
        "flap_up": {f"Wing_{s}_{i}": ("Y", -sx * 35) for s, sx in (("Left", 1), ("Right", -1)) for i in range(3)},
        "flap_down": {f"Wing_{s}_{i}": ("Y", sx * 35) for s, sx in (("Left", 1), ("Right", -1)) for i in range(3)},
        "tucked": {f"0_{s}_Limb_0": ("X", 55) for s in ("Left", "Right")} | {f"0_{s}_Limb_1": ("X", -70) for s in ("Left", "Right")},
        "head_lunge": {"Spine_1": ("X", 10), "Neck": ("X", 25), "Head_0": ("X", 20)},
    }
    for label, turns in poses.items():
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            if pb.name in turns:
                axis, degrees = turns[pb.name]
                world = Vector((1, 0, 0)) if axis == "X" else Vector((0, 1, 0))
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
print("halo pieces marked:", rig_kit.mark_pieces(mesh, "HaloMark", is_halo), "vertices")
rig_kit.optimize(mesh, NAME, TARGET_TRIS)
halo = rig_kit.marked(mesh, "HaloMark")  # read before skin() clears the vertex groups
rig = rig_kit.build_rig(NAME + "Rig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
lock_wings(mesh)
lock_halo(mesh, halo)
dims = mesh.dimensions
print(f"mesh: {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles, {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")
if os.environ.get("POSES") == "1":
    pose_tests(rig)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
