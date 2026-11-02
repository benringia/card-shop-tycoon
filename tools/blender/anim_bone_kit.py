"""Keys attack clips on a rigged monster or boss and exports them for Roblox (docs/animations.md "Bone rigs", spec
2026-11-02-attack-animations-design). The models' bones come from rig_kit.py (head/tail points, so each bone's axes
follow its own direction) and Roblox's FBX importer turns them again, so clips don't store per-bone local turns:
each frame stores every deform bone's rotation in MODEL space (Roblox axes), plus the top bone's offset, and the
game's Util/ClipPlayer turns that into Bone.Transform from the bone's rest pose in Roblox.

Axes: Blender is Z up, the model faces -Y, its left is +X; Roblox x_r = -x_b, y_r = z_b, z_r = y_b (M below, its own
inverse), checked on the Meadow Warden's bones in Studio. 1 Blender unit = 1 unit of the model file (the game scales
the model; ClipPlayer scales offsets with it).

Keying: key_turn(rig, bone, frame, (x, y, z)) turns a bone about its head by Euler degrees in ARMATURE axes (X the
model's left, Y its back, Z up), after its parent's pose: an arm hanging down swings forward with a negative X turn.
Keys go in time order and parents before children (each key reads the parent's pose at that frame).
Usage (Blender MCP): sys.path has tools/blender; import anim_bone_kit as kit; rig = kit.armature();
kit.key_turn(...); kit.export_clip(rig, "strike", 1, 21, json_dir, {"Hit": 0.4}).
"""
import json
import math
import os

import bpy
from mathutils import Euler, Matrix

M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
FPS = 30


def armature():
    """The scene's (first) armature."""
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def reset(rig):
    """Clears every pose and the action, back to the rest pose."""
    rig.animation_data_clear()
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def _parent_delta(pb):
    """The parent's posed armature matrix times its rest inverse (identity for a root)."""
    if not pb.parent:
        return Matrix.Identity(4)
    return pb.parent.matrix @ pb.parent.bone.matrix_local.inverted()


def key_turn(rig, name, frame, degrees=(0, 0, 0), offset=None):
    """Turns `name` about its head by Euler `degrees` in armature axes after its parent's pose, at `frame`; `offset`
    (armature units) moves it too (the top bone only). Inserts rotation and location keys."""
    scene = bpy.context.scene
    scene.frame_set(frame)
    pb = rig.pose.bones[name]
    pb.rotation_mode = "QUATERNION"
    rest = pb.bone.matrix_local
    head = rest.translation
    turn = Euler([math.radians(v) for v in degrees], "XYZ").to_matrix().to_4x4()
    pivot = Matrix.Translation(head) @ turn @ Matrix.Translation(-head)
    move = Matrix.Translation(offset) if offset else Matrix.Identity(4)
    pb.matrix = _parent_delta(pb) @ move @ pivot @ rest
    bpy.context.view_layer.update()
    pb.keyframe_insert("rotation_quaternion", frame=frame)
    pb.keyframe_insert("location", frame=frame)


def key_pose(rig, frame, pose):
    """Keys every deform bone at `frame`, parents first: `pose` maps a bone to Euler degrees, or (degrees, offset) for
    the top bone; bones it leaves out go back to rest."""
    def depth(bone):
        return 0 if not bone.parent else 1 + depth(bone.parent)
    for bone in sorted((b for b in rig.data.bones if b.use_deform), key=depth):
        value = pose.get(bone.name, (0, 0, 0))
        if isinstance(value, tuple) and len(value) == 2 and isinstance(value[0], tuple):
            key_turn(rig, bone.name, frame, value[0], value[1])
        else:
            key_turn(rig, bone.name, frame, value)


def export_clip(rig, name, frame_start, frame_end, json_dir, markers=None):
    """Writes <json_dir>/<name>.json: each frame (30 a second) every deform bone's model-space rotation (Roblox axes,
    quaternion x y z w) and the top deform bone's offset from rest (Roblox axes, model units); markers by time."""
    scene = bpy.context.scene
    deform = [b for b in rig.data.bones if b.use_deform]
    top = next((b for b in deform if not b.parent or not b.parent.use_deform), None)
    frames = []
    for frame in range(frame_start, frame_end + 1):
        scene.frame_set(frame)
        rotations, offsets = {}, {}
        for bone in deform:
            pb = rig.pose.bones[bone.name]
            delta = pb.matrix.to_3x3() @ bone.matrix_local.to_3x3().inverted()
            q = (M @ delta @ M).to_quaternion()
            rotations[bone.name] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)]
        if top:
            pb = rig.pose.bones[top.name]
            moved = M @ (pb.matrix.translation - top.matrix_local.translation)
            offsets[top.name] = [round(moved.x, 6), round(moved.y, 6), round(moved.z, 6)]
        frames.append({"t": round((frame - frame_start) / FPS, 4), "r": rotations, "p": offsets})
    os.makedirs(json_dir, exist_ok=True)
    data = {
        "name": name,
        "fps": FPS,
        "length": round((frame_end - frame_start) / FPS, 4),
        "markers": markers or {},
        "frames": frames,
    }
    path = os.path.join(json_dir, name + ".json")
    with open(path, "w") as f:
        json.dump(data, f)
    return path
