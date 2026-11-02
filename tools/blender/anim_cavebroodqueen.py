"""The Cave Brood Queen's attack clips (spec 2026-11-02-attack-animations-design; pipeline docs/animations.md "Bone
rigs"), keyed with anim_bone_kit on assets/blender/CaveBroodQueen/CaveBroodQueen.blend:

  windup          0.6 s  (Combat.CHARGE_LEAD) rears its front up, front legs raised and fangs spread: a stab coming
  strike          0.5 s  drives the thorax, fangs and front legs down and forward; Hit at 0.07 s
  specialWindup   1.3 s  (its ring's warning) rears high, wings raised and fluttering, fangs wide: the web spit coming
  specialRelease  0.8 s  lunges, thrusting its head forward and sweeping its wings down as it spits; Hit at 0.1 s

Armature axes: X the model's left, Y its back, Z up. A positive X turn pitches a bone forward and down (a negative one
up and back), for the body and for hanging legs alike. The left legs point out along +X: a negative Y turn lifts one,
a negative Z turn swings it forward (the right legs the other way round). Pelvis is the egg sac, from the waist back;
turning it turns the whole body about the waist.
Usage (Blender MCP): import anim_cavebroodqueen as clips; clips.make_all(json_dir)
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402

importlib.reload(kit)

BLEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "blender", "CaveBroodQueen",
                     "CaveBroodQueen.blend")

ORDER = ["Pelvis", "Spine_0", "Head_0", "Jaw_0", "Wing_Left_0", "Wing_Left_1", "Wing_Right_0", "Wing_Right_1"] + [
    f"{pair}_{side}_Limb_{segment}" for pair in range(4) for side in ("Left", "Right") for segment in (0, 1)]


def _pose(rig, frame, pose):
    """Keys every bone in `pose` (bone -> degrees, or (degrees, offset)) at `frame`, parents first."""
    for name in ORDER:
        value = pose.get(name, (0, 0, 0))
        if isinstance(value, tuple) and len(value) == 2 and isinstance(value[0], tuple):
            kit.key_turn(rig, name, frame, value[0], value[1])
        else:
            kit.key_turn(rig, name, frame, value)


def _legs(pair, lift, forward, knee):
    """Both legs of a pair: lifted `lift` degrees, swung `forward` degrees, the lower leg turned `knee` (X)."""
    return {
        f"{pair}_Left_Limb_0": (0, -lift, -forward),
        f"{pair}_Right_Limb_0": (0, lift, forward),
        f"{pair}_Left_Limb_1": (knee, 0, 0),
        f"{pair}_Right_Limb_1": (knee, 0, 0),
    }


def _wings(spread, tip, sweep=0):
    """Both wings: raised `spread` degrees, their tips `tip` more, swept `sweep` degrees forward."""
    return {
        "Wing_Left_0": (0, -spread, -sweep),
        "Wing_Right_0": (0, spread, sweep),
        "Wing_Left_1": (0, -tip, 0),
        "Wing_Right_1": (0, tip, 0),
    }


REST = {}
STAB_READY = {
    "Pelvis": ((-10, 0, 0), (0, 0.06, 0.02)),
    "Spine_0": (-12, 0, 0),
    "Head_0": (-10, 0, 0),
    "Jaw_0": (-25, 0, 0),
    **_legs(0, 45, 30, -40),
    **_wings(15, 5),
}
STAB_DONE = {
    "Pelvis": ((8, 0, 0), (0, -0.12, -0.03)),
    "Spine_0": (20, 0, 0),
    "Head_0": (14, 0, 0),
    "Jaw_0": (20, 0, 0),
    **_legs(0, -10, 40, -25),
    **_wings(5, 0),
}
SPIT_READY = {
    "Pelvis": ((-22, 0, 0), (0, 0.08, 0.04)),
    "Spine_0": (-16, 0, 0),
    "Head_0": (-14, 0, 0),
    "Jaw_0": (-35, 0, 0),
    **_legs(0, 40, 25, -35),
    **_legs(1, 25, 15, -20),
    **_wings(40, 20),
}
SPIT_DONE = {
    "Pelvis": ((10, 0, 0), (0, -0.15, -0.02)),
    "Spine_0": (16, 0, 0),
    "Head_0": (22, 0, 0),
    "Jaw_0": (-20, 0, 0),
    **_legs(0, -10, 25, -10),
    **_legs(1, -5, 5, 0),
    **_wings(-10, -5, 30),
}


def _windup(rig):  # 0.6 s = frames 1-19
    _pose(rig, 1, REST)
    _pose(rig, 19, STAB_READY)


def _strike(rig):  # from ready, the stab, back to rest; 0.5 s = frames 1-16, the hit at frame 3
    _pose(rig, 1, STAB_READY)
    _pose(rig, 4, STAB_DONE)
    _pose(rig, 16, REST)


def _special_windup(rig):  # 1.3 s = frames 1-40, up fast then held, the wings fluttering
    _pose(rig, 1, REST)
    _pose(rig, 14, SPIT_READY)
    flutter = dict(SPIT_READY, **_wings(30, 10))
    _pose(rig, 22, flutter)
    _pose(rig, 30, SPIT_READY)
    _pose(rig, 36, flutter)
    _pose(rig, 40, SPIT_READY)


def _special_release(rig):  # 0.8 s = frames 1-25, the spit at frame 4
    _pose(rig, 1, SPIT_READY)
    _pose(rig, 4, SPIT_DONE)
    _pose(rig, 12, SPIT_DONE)
    _pose(rig, 25, REST)


# name -> (keying, last frame, markers)
CLIPS = {
    "windup": (_windup, 19, {}),
    "strike": (_strike, 16, {"Hit": 0.07}),
    "specialWindup": (_special_windup, 40, {}),
    "specialRelease": (_special_release, 25, {"Hit": 0.1}),
}


def key(name):
    """Keys one clip on the rig (for previews), opening the .blend first if needed; returns (rig, last frame)."""
    import bpy
    if not bpy.data.filepath.endswith("CaveBroodQueen.blend"):
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
