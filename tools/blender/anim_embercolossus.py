"""The Ember Colossus's attack clips (spec 2026-11-02-attack-animations-design; pipeline docs/animations.md "Bone
rigs"), keyed with anim_bone_kit on assets/blender/EmberColossus/EmberColossus.blend:

  windup          0.6 s  (Combat.CHARGE_LEAD) sits back on its haunches and lowers its head, horn aimed: a gore coming
  strike          0.5 s  lunges and tosses its head up, the horn sweeping through; Hit at 0.07 s
  specialWindup   1.2 s  (its ring's warning) rears up on its hind legs, front legs tucked, roaring: the lava slam coming
  specialRelease  0.8 s  crashes its front feet down, head low, jaw open; Hit at 0.1 s

Armature axes: X the model's left, Y its back, Z up. A positive X turn pitches a bone forward and down (a negative one
up and back); a leg hanging down swings back with a positive X turn and forward with a negative one. Pelvis is the
hindquarters, from the hips forward: turning it turns the whole body about the hips, so the hind legs turn back the
other way to stay standing.
Usage (Blender MCP): import anim_embercolossus as clips; clips.make_all(json_dir)
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402

importlib.reload(kit)

BLEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "blender", "EmberColossus",
                     "EmberColossus.blend")

ORDER = ["Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Jaw_0"] + [
    f"{pair}_{side}_Limb_{segment}" for pair in range(2) for side in ("Left", "Right") for segment in range(3)]


def _pose(rig, frame, pose):
    """Keys every bone in `pose` (bone -> degrees, or (degrees, offset)) at `frame`, parents first."""
    for name in ORDER:
        value = pose.get(name, (0, 0, 0))
        if isinstance(value, tuple) and len(value) == 2 and isinstance(value[0], tuple):
            kit.key_turn(rig, name, frame, value[0], value[1])
        else:
            kit.key_turn(rig, name, frame, value)


def _legs(pair, upper, lower=0, foot=0):
    """Both legs of a pair turned the same (X degrees): the upper leg, the lower leg, the foot."""
    pose = {}
    for side in ("Left", "Right"):
        pose[f"{pair}_{side}_Limb_0"] = (upper, 0, 0)
        pose[f"{pair}_{side}_Limb_1"] = (lower, 0, 0)
        pose[f"{pair}_{side}_Limb_2"] = (foot, 0, 0)
    return pose


REST = {}
GORE_READY = {
    "Pelvis": ((0, 0, 0), (0, 0.06, -0.02)),
    "Spine_1": (6, 0, 0),
    "Neck": (14, 0, 0),
    "Head_0": (18, 0, 0),
    **_legs(0, 12, -6),
}
GORE_DONE = {
    "Pelvis": ((0, 0, 0), (0, -0.12, 0.02)),
    "Spine_1": (-4, 0, 0),
    "Neck": (-14, 0, 0),
    "Head_0": (-26, 0, 0),
    "Jaw_0": (12, 0, 0),
    **_legs(0, -22, 8),
    **_legs(1, 10),
}
SLAM_READY = {
    "Pelvis": ((-28, 0, 0), (0, 0.04, 0)),
    "Spine_1": (-4, 0, 0),
    "Neck": (-8, 0, 0),
    "Head_0": (-14, 0, 0),
    "Jaw_0": (28, 0, 0),
    **_legs(0, -35, 55, -10),
    **_legs(1, 28),
}
SLAM_DOWN = {
    "Pelvis": ((6, 0, 0), (0, -0.05, -0.04)),
    "Spine_1": (4, 0, 0),
    "Neck": (10, 0, 0),
    "Head_0": (18, 0, 0),
    "Jaw_0": (30, 0, 0),
    **_legs(0, -10),
    **_legs(1, -6),
}


def _windup(rig):  # 0.6 s = frames 1-19
    _pose(rig, 1, REST)
    _pose(rig, 19, GORE_READY)


def _strike(rig):  # from ready, the gore, back to rest; 0.5 s = frames 1-16, the hit at frame 3
    _pose(rig, 1, GORE_READY)
    _pose(rig, 4, GORE_DONE)
    _pose(rig, 16, REST)


def _special_windup(rig):  # 1.2 s = frames 1-37, up then held, shaking
    _pose(rig, 1, REST)
    _pose(rig, 15, SLAM_READY)
    shake = dict(SLAM_READY)
    shake["Spine_1"] = (-7, 0, 2)
    shake["Head_0"] = (-18, 0, -3)
    _pose(rig, 24, shake)
    _pose(rig, 31, SLAM_READY)
    _pose(rig, 37, shake)


def _special_release(rig):  # 0.8 s = frames 1-25, the slam lands at frame 4
    _pose(rig, 1, SLAM_READY)
    _pose(rig, 4, SLAM_DOWN)
    _pose(rig, 12, SLAM_DOWN)
    _pose(rig, 25, REST)


# name -> (keying, last frame, markers)
CLIPS = {
    "windup": (_windup, 19, {}),
    "strike": (_strike, 16, {"Hit": 0.07}),
    "specialWindup": (_special_windup, 37, {}),
    "specialRelease": (_special_release, 25, {"Hit": 0.1}),
}


def key(name):
    """Keys one clip on the rig (for previews), opening the .blend first if needed; returns (rig, last frame)."""
    import bpy
    if not bpy.data.filepath.endswith("EmberColossus.blend"):
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
