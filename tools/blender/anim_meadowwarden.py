"""The Meadow Warden's attack clips (spec 2026-11-02-attack-animations-design; pipeline docs/animations.md "Bone
rigs"), keyed with anim_bone_kit on assets/blender/MeadowWarden/MeadowWarden.blend:

  windup          0.6 s  (Combat.CHARGE_LEAD) rears back, twists right, right arm up and back: a branch swipe coming
  strike          0.5 s  swings the right arm across the front; Hit at 0.07 s (the hit lands as it starts)
  specialWindup   1.4 s  (its ring's warning) rears up, both arms raised high: the root slam coming
  specialRelease  0.8 s  slams both fists into the ground, crouching; Hit at 0.1 s

Armature axes: X the model's left, Y its back, Z up. Arms hang down: a negative X turn swings one forward, a positive Y
turn swings the right arm out (a negative Y the left). The spine leans back with a negative X turn; a negative Z turn
twists the chest to the right.
Usage (Blender MCP): import anim_meadowwarden as clips; clips.make_all(json_dir)
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402

importlib.reload(kit)

BLEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "blender", "MeadowWarden",
                     "MeadowWarden.blend")


def _pose(rig, frame, pose):
    """Keys every bone in `pose` (bone -> degrees, or (degrees, offset)) at `frame`, parents first."""
    order = ["Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Arm_Left_0", "Arm_Left_1", "Arm_Left_2",
             "Arm_Right_0", "Arm_Right_1", "Arm_Right_2"]
    for name in order:
        value = pose.get(name, (0, 0, 0))
        if isinstance(value, tuple) and len(value) == 2 and isinstance(value[0], tuple):
            kit.key_turn(rig, name, frame, value[0], value[1])
        else:
            kit.key_turn(rig, name, frame, value)


REST = {}
SWIPE_READY = {
    "Spine_0": (-8, 0, -16),
    "Spine_1": (-10, 0, -22),
    "Head_0": (8, 0, 14),
    "Arm_Right_0": (40, 100, 0),
    "Arm_Right_1": (-40, 0, 0),
    "Arm_Left_0": (-20, -15, 0),
}
SWIPE_DONE = {
    "Spine_0": (12, 0, 20),
    "Spine_1": (14, 0, 26),
    "Head_0": (-6, 0, -10),
    "Arm_Right_0": (-95, -55, 0),
    "Arm_Right_1": (-10, 0, 0),
    "Arm_Left_0": (25, 15, 0),
}
SLAM_READY = {
    "Pelvis": ((-4, 0, 0), (0, 0, 0.02)),
    "Spine_0": (-12, 0, 0),
    "Spine_1": (-14, 0, 0),
    "Head_0": (-10, 0, 0),
    "Arm_Right_0": (-150, 20, 0),
    "Arm_Right_1": (-20, 0, 0),
    "Arm_Left_0": (-150, -20, 0),
    "Arm_Left_1": (-20, 0, 0),
}
SLAM_DOWN = {
    "Pelvis": ((10, 0, 0), (0, 0, -0.06)),
    "Spine_0": (16, 0, 0),
    "Spine_1": (20, 0, 0),
    "Head_0": (8, 0, 0),
    "Arm_Right_0": (-35, -10, 0),
    "Arm_Right_1": (-10, 0, 0),
    "Arm_Left_0": (-35, 10, 0),
    "Arm_Left_1": (-10, 0, 0),
}


def _windup(rig):  # 0.6 s = frames 1-19
    _pose(rig, 1, REST)
    _pose(rig, 19, SWIPE_READY)


def _strike(rig):  # from ready, across, back to rest; 0.5 s = frames 1-16, the hit at frame 3
    _pose(rig, 1, SWIPE_READY)
    _pose(rig, 4, SWIPE_DONE)
    _pose(rig, 16, REST)


def _special_windup(rig):  # 1.4 s = frames 1-43, up fast then held, trembling a little
    _pose(rig, 1, REST)
    _pose(rig, 16, SLAM_READY)
    shake = dict(SLAM_READY)
    shake["Spine_1"] = (-17, 0, 2)
    _pose(rig, 30, shake)
    _pose(rig, 43, SLAM_READY)


def _special_release(rig):  # 0.8 s = frames 1-25, the slam lands at frame 4
    _pose(rig, 1, SLAM_READY)
    _pose(rig, 4, SLAM_DOWN)
    _pose(rig, 12, SLAM_DOWN)
    _pose(rig, 25, REST)


# name -> (keying, last frame, markers)
CLIPS = {
    "windup": (_windup, 19, {}),
    "strike": (_strike, 16, {"Hit": 0.07}),
    "specialWindup": (_special_windup, 43, {}),
    "specialRelease": (_special_release, 25, {"Hit": 0.1}),
}


def key(name):
    """Keys one clip on the rig (for previews), opening the .blend first if needed; returns (rig, last frame)."""
    import bpy
    if not bpy.data.filepath.endswith("MeadowWarden.blend"):
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(BLEND))
    rig = kit.armature()
    kit.reset(rig)
    keying, last, _ = CLIPS[name]
    keying(rig)
    return rig, last


def make_all(json_dir):
    paths = []
    for name, (_, last, markers) in CLIPS.items():
        rig, _ = key(name)
        paths.append(kit.export_clip(rig, name, 1, last, json_dir, markers))
    return paths
