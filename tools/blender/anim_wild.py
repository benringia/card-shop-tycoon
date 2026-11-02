"""The wild monsters' attack clips (spec 2026-11-02-attack-animations-design; pipeline docs/animations.md "Bone rigs"):
each species has a `windup` (0.6 s, Combat.CHARGE_LEAD) and a `strike` (0.5 s, the hit at 0.07 s), keyed with
anim_bone_kit on assets/blender/<Species>/<Species>.blend:

  AshWolf      crouches, head low and jaws open; lunges and snaps (a lunging bite)
  CaveBat      rises and leans back, wings high, talons up; dives forward, wings swept back (a dive)
  MagmaGolem   leans back, right fist raised overhead; bends and punches the ground (a ground punch)
  Mossling     sinks back with its head down; rams forward, tossing its brow up (a headbutt)
  PuddleCrab   leans back, both claws raised and open; snaps them shut down in front (a pincer snap)
  SparkBeetle  backs up with its head down and pincers spread; charges and tosses them up shut (a horn charge)

Armature axes: X the model's left, Y its back, Z up. A positive X turn pitches a bone forward and down (a negative one
up and back); a leg or arm hanging down swings forward with a negative X turn. Bones pointing out to the left turn up
with a negative Y turn and forward with a negative Z turn (the right side the other way round). The top bone (Pelvis)
can move too: (degrees, offset).
Clips are saved under the game's species name (Config/Wild SPECIES, "Ash Wolf"), the .blend folders without the space.
Usage (Blender MCP): import anim_wild as clips; clips.make_all(animations_dir)  (writes <dir>/<species>/<clip>.json)
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402

importlib.reload(kit)

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "blender")


def _pair(name, degrees, mirror="YZ"):
    """The same turn on a bone's Left and Right copies (`name` has {side}), mirrored on the axes in `mirror`."""
    x, y, z = degrees
    return {
        name.format(side="Left"): (x, y, z),
        name.format(side="Right"): (x, -y if "Y" in mirror else y, -z if "Z" in mirror else z),
    }


SPECIES = {
    "AshWolf": {
        "ready": {
            "Pelvis": ((0, 0, 0), (0, 0.05, -0.05)),
            "Spine_1": (6, 0, 0),
            "Neck": (12, 0, 0),
            "Head_0": (-10, 0, 0),
            "Jaw_0": (24, 0, 0),
            "Tail_0": (-20, 0, 0),
            **_pair("0_{side}_Limb_0", (16, 0, 0)),
            **_pair("1_{side}_Limb_0", (-16, 0, 0)),
            **_pair("1_{side}_Limb_1", (22, 0, 0)),
        },
        "done": {
            "Pelvis": ((0, 0, 0), (0, -0.18, 0.03)),
            "Spine_1": (-4, 0, 0),
            "Neck": (-10, 0, 0),
            "Head_0": (10, 0, 0),
            "Jaw_0": (-4, 0, 0),
            "Tail_0": (10, 0, 0),
            **_pair("0_{side}_Limb_0", (-36, 0, 0)),
            **_pair("1_{side}_Limb_0", (26, 0, 0)),
        },
    },
    "CaveBat": {
        "ready": {
            "Pelvis": ((-8, 0, 0), (0, 0.06, 0.08)),
            "Spine_0": (-8, 0, 0),
            "Head_0": (-6, 0, 0),
            "Jaw_0": (22, 0, 0),
            **_pair("Wing_{side}_0", (0, -40, 0)),
            **_pair("Wing_{side}_1", (0, -20, 0)),
            **_pair("0_{side}_Limb_0", (-35, 0, 0)),
            **_pair("0_{side}_Limb_1", (30, 0, 0)),
        },
        "done": {
            "Pelvis": ((22, 0, 0), (0, -0.2, -0.06)),
            "Spine_0": (12, 0, 0),
            "Head_0": (8, 0, 0),
            "Jaw_0": (-4, 0, 0),
            **_pair("Wing_{side}_0", (0, 25, 30)),
            **_pair("Wing_{side}_1", (0, 10, 0)),
            **_pair("0_{side}_Limb_0", (-50, 0, 0)),
            **_pair("0_{side}_Limb_1", (10, 0, 0)),
        },
    },
    "MagmaGolem": {
        "ready": {
            "Spine_0": (-10, 0, -10),
            "Spine_1": (-8, 0, -10),
            "Head_0": (6, 0, 10),
            "Arm_Right_0": (-150, 20, 0),
            "Arm_Right_1": (-30, 0, 0),
            "Arm_Left_0": (20, -10, 0),
        },
        "done": {
            "Pelvis": ((0, 0, 0), (0, -0.03, -0.06)),
            "Spine_0": (18, 0, 8),
            "Spine_1": (20, 0, 8),
            "Head_0": (8, 0, -6),
            "Arm_Right_0": (-50, 0, 0),
            "Arm_Right_1": (-10, 0, 0),
            "Arm_Left_0": (-20, 10, 0),
            **_pair("0_{side}_Limb_0", (-12, 0, 0)),
            **_pair("0_{side}_Limb_1", (18, 0, 0)),
        },
    },
    "Mossling": {
        "ready": {
            "Pelvis": ((0, 0, 0), (0, 0.06, -0.02)),
            "Spine_1": (5, 0, 0),
            "Neck": (20, 0, 0),
            "Head_0": (15, 0, 0),
            "Tail_0": (-25, 0, 0),
            **_pair("0_{side}_Limb_0", (15, 0, 0)),
        },
        "done": {
            "Pelvis": ((0, 0, 0), (0, -0.15, 0.02)),
            "Neck": (-10, 0, 0),
            "Head_0": (-22, 0, 0),
            "Jaw_0": (10, 0, 0),
            "Tail_0": (15, 0, 0),
            **_pair("0_{side}_Limb_0", (-25, 0, 0)),
            **_pair("1_{side}_Limb_0", (20, 0, 0)),
        },
    },
    "PuddleCrab": {
        "ready": {
            "Pelvis": ((-8, 0, 0), (0, 0.04, 0.02)),
            **_pair("Claw_{side}_0", (-45, 0, -10)),
            **_pair("Claw_{side}_1", (-35, 0, 0)),
        },
        "done": {
            "Pelvis": ((6, 0, 0), (0, -0.08, -0.01)),
            **_pair("Claw_{side}_0", (15, 0, 8)),
            **_pair("Claw_{side}_1", (25, 0, 0)),
        },
    },
    "SparkBeetle": {
        "ready": {
            "Pelvis": ((0, 0, 0), (0, 0.05, -0.01)),
            "Neck": (10, 0, 0),
            "Head_0": (18, 0, 0),
            **_pair("Pincer_{side}_0", (0, 22, 0)),
        },
        "done": {
            "Pelvis": ((0, 0, 0), (0, -0.16, 0.01)),
            "Neck": (-8, 0, 0),
            "Head_0": (-18, 0, 0),
            **_pair("Pincer_{side}_0", (0, -10, 0)),
        },
    },
}

# .blend folder -> the game's species name
GAME_NAME = {"AshWolf": "Ash Wolf", "CaveBat": "Cave Bat", "MagmaGolem": "Magma Golem", "Mossling": "Mossling",
             "PuddleCrab": "Puddle Crab", "SparkBeetle": "Spark Beetle"}

# clip -> (last frame, markers)
CLIPS = {"windup": (19, {}), "strike": (16, {"Hit": 0.07})}


def key(species, clip):
    """Keys one clip on the species' rig (for previews), opening its .blend first if needed; returns (rig, last)."""
    import bpy
    blend = os.path.abspath(os.path.join(ASSETS, species, species + ".blend"))
    if os.path.normcase(bpy.data.filepath) != os.path.normcase(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
    rig = kit.armature()
    kit.reset(rig)
    poses = SPECIES[species]
    if clip == "windup":  # 0.6 s = frames 1-19
        kit.key_pose(rig, 1, {})
        kit.key_pose(rig, 19, poses["ready"])
    else:  # from ready, the hit by frame 4 (0.1 s), back to rest; 0.5 s = frames 1-16
        kit.key_pose(rig, 1, poses["ready"])
        kit.key_pose(rig, 4, poses["done"])
        kit.key_pose(rig, 16, {})
    return rig, CLIPS[clip][0]


def make(species, animations_dir):
    """Exports the species' clips to <animations_dir>/<its game name>/."""
    paths = []
    for clip, (last, markers) in CLIPS.items():
        rig, _ = key(species, clip)
        paths.append(kit.export_clip(rig, clip, 1, last, os.path.join(animations_dir, GAME_NAME[species]), markers))
    return paths


def make_all(animations_dir):
    return [path for species in SPECIES for path in make(species, animations_dir)]
