"""Animation kit: the game's standard R15 body as a Blender rig, keyed in Roblox joint angles, exported per frame.

Docs: docs/animations.md. Run inside Blender (through the Blender MCP): `import anim_kit` with tools/blender on sys.path,
then `rig = anim_kit.build()` and key moves with key_pose / key_foot / key_root (see anim_starter_sword.py).

Upper body keyed in Roblox joint angles (degrees, Roblox CFrame.Angles order: X then Y then Z, as Rx*Ry*Rz), legs on
IK with planted foot targets (a 0.06 forward pre-bend at each knee tells the IK which way to fold), root motion on the
armature object. Blender: Z up, the character faces -Y, its left is +X. Roblox <-> Blender axes: x_r = -x_b,
y_r = z_b, z_r = y_b (M below, its own inverse). 1 Blender unit = 1 stud.

Roblox animations can't move the HumanoidRootPart, so a move's root motion is baked into the Root joint (the
LowerTorso pose) and every move ends where it started (a lunge steps in and back).
"""
import json
import math
import os

import bpy
from mathutils import Matrix, Vector

FPS = 60
EXPORT_STEP = 2  # export every other frame: 30 keyframes a second
HRP_Z = 3.0  # HumanoidRootPart centre above the ground (HipHeight 2 + half its 2-stud height)
M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))

# The standard R15 body, from the game (pivot = the joint's position, Roblox coords from the HumanoidRootPart centre)
PARTS = {
    "LowerTorso": {"parent": "HumanoidRootPart", "joint": "Root", "pivot": (0, -1, 0), "tail": (0, -0.6, 0), "center": (0, -0.8, 0), "size": (2, 0.4, 1)},
    "UpperTorso": {"parent": "LowerTorso", "joint": "Waist", "pivot": (0, -0.6, 0), "tail": (0, 1, 0), "center": (0, 0.2, 0), "size": (2, 1.6, 1)},
    "Head": {"parent": "UpperTorso", "joint": "Neck", "pivot": (0, 1, 0), "tail": (0, 2.2, 0), "center": (0, 1.6, 0), "size": (1.2, 1.2, 1.2)},
    "RightUpperArm": {"parent": "UpperTorso", "joint": "RightShoulder", "pivot": (1, 0.763, 0), "tail": (1.5, 0.0345, 0), "center": (1.5, 0.3687, 0), "size": (1, 1.1687, 1)},
    "RightLowerArm": {"parent": "RightUpperArm", "joint": "RightElbow", "pivot": (1.5, 0.0345, 0), "tail": (1.5, -0.725, 0), "center": (1.5, -0.2241, 0), "size": (1, 1.0519, 1)},
    "RightHand": {"parent": "RightLowerArm", "joint": "RightWrist", "pivot": (1.5, -0.725, 0), "tail": (1.5, -1.0, 0), "center": (1.5, -0.85, 0), "size": (1, 0.3, 1)},
    "LeftUpperArm": {"parent": "UpperTorso", "joint": "LeftShoulder", "pivot": (-1, 0.763, 0), "tail": (-1.5, 0.0345, 0), "center": (-1.5, 0.3687, 0), "size": (1, 1.1687, 1)},
    "LeftLowerArm": {"parent": "LeftUpperArm", "joint": "LeftElbow", "pivot": (-1.5, 0.0345, 0), "tail": (-1.5, -0.725, 0), "center": (-1.5, -0.2241, 0), "size": (1, 1.0519, 1)},
    "LeftHand": {"parent": "LeftLowerArm", "joint": "LeftWrist", "pivot": (-1.5, -0.725, 0), "tail": (-1.5, -1.0, 0), "center": (-1.5, -0.85, 0), "size": (1, 0.3, 1)},
    "RightUpperLeg": {"parent": "LowerTorso", "joint": "RightHip", "pivot": (0.5, -1, 0), "tail": (0.5, -1.8217, 0), "center": (0.5, -1.4208, 0), "size": (1, 1.2166, 1)},
    "RightLowerLeg": {"parent": "RightUpperLeg", "joint": "RightKnee", "pivot": (0.5, -1.8217, 0), "tail": (0.5, -2.748, 0), "center": (0.5, -2.2009, 0), "size": (1, 1.1931, 1)},
    "RightFoot": {"parent": "RightLowerLeg", "joint": "RightAnkle", "pivot": (0.5, -2.748, 0), "tail": (0.5, -2.9, -0.5), "center": (0.5, -2.85, 0), "size": (1, 0.3, 1)},
    "LeftUpperLeg": {"parent": "LowerTorso", "joint": "LeftHip", "pivot": (-0.5, -1, 0), "tail": (-0.5, -1.8217, 0), "center": (-0.5, -1.4208, 0), "size": (1, 1.2166, 1)},
    "LeftLowerLeg": {"parent": "LeftUpperLeg", "joint": "LeftKnee", "pivot": (-0.5, -1.8217, 0), "tail": (-0.5, -2.748, 0), "center": (-0.5, -2.2009, 0), "size": (1, 1.1931, 1)},
    "LeftFoot": {"parent": "LeftLowerLeg", "joint": "LeftAnkle", "pivot": (-0.5, -2.748, 0), "tail": (-0.5, -2.9, -0.5), "center": (-0.5, -2.85, 0), "size": (1, 0.3, 1)},
}
ORDER = ["LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm",
         "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
# Moves that leave the legs (and hips) to Roblox's own walk and idle animations
UPPER_BODY = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
COLORS = {"Head": (0.85, 0.68, 0.5, 1), "UpperTorso": (0.95, 0.5, 0.12, 1), "LowerTorso": (0.25, 0.25, 0.3, 1)}
SKIN = (0.85, 0.68, 0.5, 1)
PANTS = (0.25, 0.25, 0.3, 1)
FOOT_Z = 0.252  # an ankle target's height when the foot is flat on the ground

# Short joint names for poses: R root (hips), W waist, N neck, RS/RE/RW right shoulder/elbow/wrist, LS/LE/LW left
SHORT = {"R": "LowerTorso", "W": "UpperTorso", "N": "Head", "RS": "RightUpperArm", "RE": "RightLowerArm", "RW": "RightHand",
         "LS": "LeftUpperArm", "LE": "LeftLowerArm", "LW": "LeftHand"}
# Arms trail the body by this many frames (overlap: the shoulder leads, the wrist whips last)
LAG = {"RE": 1, "RW": 2, "LE": 1, "LW": 2}
# The sword-ready stance: the blade held up in front, the right elbow bent
READY = {"RS": (20, 0, 10), "RE": (55, 0, 0)}


def r2b(v):
    """A Roblox point (relative to the HumanoidRootPart) to Blender world coordinates."""
    return Vector((-v[0], v[2], v[1] + HRP_Z))


def angles(x, y, z):
    """Roblox CFrame.Angles(x, y, z) in degrees as a 3x3 rotation (Rx * Ry * Rz), in Roblox axes."""
    return (Matrix.Rotation(math.radians(x), 3, "X") @ Matrix.Rotation(math.radians(y), 3, "Y")
            @ Matrix.Rotation(math.radians(z), 3, "Z"))


def material(name, rgba):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    return mat


def box(name, center, size, rgba):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(name + "_m", rgba))
    return obj


def build():
    """An empty scene with the rig (armature "Rig" = the HumanoidRootPart), block body parts, a sword in the right hand
    (the game's grip), IK legs with planted foot targets, a ground, a sun and a camera."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm_data = bpy.data.armatures.new("RigData")
    rig = bpy.data.objects.new("Rig", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_data.edit_bones.new("HumanoidRootPart")
    root.head, root.tail = r2b((0, 0, 0)), r2b((0, 0.8, 0))
    for name in ORDER:
        p = PARTS[name]
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = r2b(p["pivot"]), r2b(p["tail"])
        b.parent = arm_data.edit_bones[p["parent"]]
        if name.endswith("Foot"):
            b.use_inherit_rotation = False  # feet stay flat on the ground whatever the legs do
    for side in ("Right", "Left"):
        knee = Vector((0, -0.06, 0))
        arm_data.edit_bones[f"{side}UpperLeg"].tail += knee
        arm_data.edit_bones[f"{side}LowerLeg"].head += knee
    bpy.ops.object.mode_set(mode="OBJECT")
    for name in ORDER:
        p = PARTS[name]
        rgba = COLORS.get(name, PANTS if "Leg" in name or "Foot" in name else SKIN)
        part = box("Part_" + name, r2b(p["center"]), (p["size"][0], p["size"][2], p["size"][1]), rgba)
        bpy.context.view_layer.update()
        keep = part.matrix_world.copy()
        part.parent = rig
        part.parent_type = "BONE"
        part.parent_bone = name
        part.matrix_world = keep
    # The sword in the right hand: the game's grip (hand frame: 0.18 down, turned -140 degrees about X), blade along +Y
    hand_cf = Matrix.Translation(Vector(PARTS["RightHand"]["center"]))
    grip = Matrix.Translation(Vector((0, -0.18, 0))) @ Matrix.Rotation(math.radians(-140), 4, "X")
    sword_parts = [("Handle", (0, 0, 0), (0.26, 1.1, 0.26), (0.27, 0.17, 0.12, 1)), ("Guard", (0, 0.62, 0), (1.15, 0.2, 0.34), (0.84, 0.69, 0.32, 1)),
                   ("Blade", (0, 2.55, 0), (0.24, 3.7, 0.07), (0.88, 0.92, 0.96, 1))]
    M4 = M.to_4x4()
    for pname, off, size, rgba in sword_parts:
        world_r = hand_cf @ grip @ Matrix.Translation(Vector(off))
        world_b = Matrix.Translation(Vector((0, 0, HRP_Z))) @ M4 @ world_r @ M4
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.active_object
        obj.name = "Sword_" + pname
        obj.matrix_world = world_b @ Matrix.Diagonal((size[0], size[2], size[1], 1))
        obj.data.materials.append(material("Sword_" + pname + "_m", rgba))
        bpy.context.view_layer.update()
        keep = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = "RightHand"
        obj.matrix_world = keep
    for side, sx in (("Right", 0.5), ("Left", -0.5)):
        target = bpy.data.objects.new(f"{side}FootTarget", None)
        target.empty_display_type = "SPHERE"
        target.empty_display_size = 0.25
        target.location = r2b((sx, -2.748, 0))
        scene.collection.objects.link(target)
        pole = bpy.data.objects.new(f"{side}KneePole", None)
        pole.location = r2b((sx, -1.8, -4))
        pole.parent = rig
        scene.collection.objects.link(pole)
        ik = rig.pose.bones[f"{side}LowerLeg"].constraints.new("IK")
        ik.target, ik.pole_target, ik.chain_count = target, pole, 2
        ik.pole_angle = math.radians(-90)
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, -4, 0))
    bpy.context.active_object.data.materials.append(material("Ground_m", (0.35, 0.55, 0.3, 1)))
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return rig


def frame_at(f0, t):
    """The frame `t` seconds after frame f0."""
    return f0 + round(t * FPS)


def set_joint(rig, part, ang, frame, lift=None):
    """Keys a joint at Roblox angles (degrees) on a frame: pose basis = rest^-1 * T_blender * rest. `lift` (studs, the
    hips only) raises or lowers the body (the IK legs bend to keep the feet planted)."""
    pb = rig.pose.bones[part]
    rest = pb.bone.matrix_local.to_3x3()
    t_b = M @ angles(*ang) @ M
    q = (rest.inverted() @ t_b @ rest).to_quaternion()
    q.make_compatible(pb.rotation_quaternion)  # keys go in time order: stay on the last key's side (a full spin)
    pb.rotation_quaternion = q
    pb.keyframe_insert("rotation_quaternion", frame=frame)
    if lift is not None:
        pb.location = rest.inverted() @ Vector((0, 0, lift))
        pb.keyframe_insert("location", frame=frame)


def key_pose(rig, frame, pose, lift=0.0):
    """Keys every upper-body joint (unlisted ones at rest) on a frame, arms trailing by LAG frames."""
    for short, part in SHORT.items():
        set_joint(rig, part, pose.get(short, (0, 0, 0)), frame + LAG.get(short, 0), lift if short == "R" else None)


def key_foot(side, frame, pos):
    """Keys an ankle target at a Blender position (x: + is the character's left, y: - is forward, z: up)."""
    t = bpy.data.objects[f"{side}FootTarget"]
    t.location = Vector(pos)
    t.keyframe_insert("location", frame=frame)


def plant_feet(frame, forward_right=0.0, forward_left=0.0):
    """Both feet flat at their rest spots (optionally stepped forward by these studs)."""
    key_foot("Right", frame, (-0.5, -forward_right, FOOT_Z))
    key_foot("Left", frame, (0.5, -forward_left, FOOT_Z))


def key_root(rig, frame, forward, sideways=0.0):
    """Keys root motion: studs forward (and to the character's right), baked into the Root joint on export."""
    rig.location = Vector((-sideways, -forward, 0))
    rig.keyframe_insert("location", frame=frame)


def look(cam_pos, target):
    cam = bpy.data.objects["Cam"]
    cam.location = Vector(cam_pos)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def render_frames(folder, frames, cam_pos, target, size=(480, 360)):
    """Renders these frames (Workbench, material colours) as numbered PNGs into `folder`."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Sky")
    scene.world.color = (0.62, 0.72, 0.82)  # a light sky behind the previews
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.image_settings.file_format = "PNG"
    look(cam_pos, target)
    os.makedirs(folder, exist_ok=True)
    paths = []
    for i, f in enumerate(frames):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(folder, f"{i:03d}.png")
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths


def export_move(rig, path, name, first, last, loop=False, parts=None, markers=None, priority="Action"):
    """Every EXPORT_STEP frames from `first` to `last`: each joint's Transform in Roblox axes (quaternion x, y, z, w; the
    Root joint's offset too, with the root motion baked in) for the parts given (default every part). Writes JSON for
    tools/anim/build_kfs.luau: { name, loop, priority, markers = { { name, t } }, frames = { { t, poses } } }."""
    scene = bpy.context.scene
    parts = parts or ORDER
    K = {pb.name: pb.bone.matrix_local.to_3x3().inverted() for pb in rig.pose.bones}
    out = {"name": name, "loop": loop, "priority": priority, "markers": markers or [], "frames": []}
    scene.frame_set(first)
    start = rig.location.copy()
    samples = list(range(first, last + 1, EXPORT_STEP))
    if samples[-1] != last:
        samples.append(last)  # always end on the move's last frame, so its length is exact
    for f in samples:
        scene.frame_set(f)
        poses = {}
        moved = rig.location - start
        for part in parts:
            pb = rig.pose.bones[part]
            parent = rig.pose.bones[PARTS[part]["parent"]]
            fc = pb.matrix.to_3x3() @ K[part]
            fp = parent.matrix.to_3x3() @ K[parent.name]
            q = (M @ (fp.inverted() @ fc) @ M).to_quaternion()
            entry = {"q": [q.x, q.y, q.z, q.w]}
            if part == "LowerTorso":
                d = pb.head - pb.bone.head_local + moved
                entry["p"] = [-d.x, d.z, d.y]
            poses[part] = entry
        out["frames"].append({"t": round((f - first) / FPS, 4), "poses": poses})
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(out, fh)
    return len(out["frames"])
