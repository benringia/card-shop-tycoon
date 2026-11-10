"""The Frontier's monster and boss clips (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md; pipeline
docs/animations.md "Bone rigs"), keyed with anim_bone_kit on assets/blender/<Name>/<Name>.blend (rig_frontier_monsters.py,
rig_frontier_bosses.py).

The six monsters share their Wild counterparts' attacks (anim_wild.py `ready` and `done` poses, the bones a rig lacks
left out): the Shade Lynx the Ash Wolf's lunging bite, the Storm Hawk the Cave Bat's dive, the Lava Brute the Magma
Golem's ground punch, the Rift Horror the Spark Beetle's horn charge, the Prism Crab the Puddle Crab's pincer snap, the
Frost Wisp the Mossling's headbutt (as a body slam). Clips `windup` (0.6 s) and `strike` (0.5 s, Hit at 0.07 s).

The three bosses also have `specialWindup` (1.4 s, its ring's warning) and `specialRelease` (0.8 s, Hit at 0.1 s):
  frostTyrant     the Meadow Warden's branch swipe and two-fisted ground slam (the same biped bones)
  stormSovereign  rears back with wings high and jaws open, lunges and bites; rears up with its wings spread wide (the
                  thunderclap coming), then beats them down and roars
  riftDevourer    backs up with mandibles spread, lunges with them snapping shut; rears its front up, then crashes down

Run in a background Blender (it opens each .blend in turn; writes assets/blender/Animations/<game name>/<clip>.json):
  blender -b --factory-startup --python tools/blender/anim_frontier.py
then `lune run tools/anim/build_bone_clips "<game name>"` for each (MODELS=A,B to make only those).
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402
import anim_meadowwarden as warden  # noqa: E402
import anim_wild as wild  # noqa: E402

importlib.reload(kit)

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "blender")
JSON_DIR = os.path.join(ASSETS, "Animations")


def _pair(name, degrees, mirror="YZ"):
    x, y, z = degrees
    return {
        name.format(side="Left"): (x, y, z),
        name.format(side="Right"): (x, -y if "Y" in mirror else y, -z if "Z" in mirror else z),
    }


# .blend folder -> (the game's model name, the Wild species whose attack it shares)
MONSTERS = {
    "FrostWisp": ("Frost Wisp", "Mossling"),
    "ShadeLynx": ("Shade Lynx", "AshWolf"),
    "StormHawk": ("Storm Hawk", "CaveBat"),
    "LavaBrute": ("Lava Brute", "MagmaGolem"),
    "RiftHorror": ("Rift Horror", "SparkBeetle"),
    "PrismCrab": ("Prism Crab", "PuddleCrab"),
}

SOVEREIGN = {
    "rest": {},
    "ready": {
        "Pelvis": ((-6, 0, 0), (0, 0.04, 0.0)),
        "Spine_0": (-8, 0, 0),
        "Spine_1": (-10, 0, 0),
        "Neck": (-12, 0, 0),
        "Head_0": (-8, 0, 0),
        "Jaw_0": (26, 0, 0),
        **_pair("Wing_{side}_0", (0, -30, 0)),
        **_pair("Wing_{side}_1", (0, -15, 0)),
        **_pair("Arm_{side}_0", (-40, 0, 0)),
        "Tail_0": (-12, 0, 0),
    },
    "bite": {
        "Pelvis": ((12, 0, 0), (0, -0.12, -0.02)),
        "Spine_0": (12, 0, 0),
        "Spine_1": (14, 0, 0),
        "Neck": (16, 0, 0),
        "Head_0": (10, 0, 0),
        "Jaw_0": (-4, 0, 0),
        **_pair("Wing_{side}_0", (0, 20, 20)),
        **_pair("Arm_{side}_0", (-70, 0, 0)),
        "Tail_0": (14, 0, 0),
    },
    "rear": {
        "Pelvis": ((-14, 0, 0), (0, 0.06, 0.04)),
        "Spine_0": (-12, 0, 0),
        "Spine_1": (-12, 0, 0),
        "Neck": (-16, 0, 0),
        "Head_0": (-14, 0, 0),
        "Jaw_0": (30, 0, 0),
        **_pair("Wing_{side}_0", (0, -45, -10)),
        **_pair("Wing_{side}_1", (0, -25, 0)),
        **_pair("Wing_{side}_2", (0, -15, 0)),
        **_pair("Arm_{side}_0", (-60, 20, 0)),
    },
    "clap": {
        "Pelvis": ((10, 0, 0), (0, -0.04, -0.04)),
        "Spine_0": (10, 0, 0),
        "Spine_1": (10, 0, 0),
        "Neck": (8, 0, 0),
        "Head_0": (-6, 0, 0),
        "Jaw_0": (32, 0, 0),
        **_pair("Wing_{side}_0", (0, 35, 30)),
        **_pair("Wing_{side}_1", (0, 20, 0)),
        **_pair("Arm_{side}_0", (-20, 0, 0)),
    },
}

DEVOURER = {
    "rest": {},
    "ready": {
        "Pelvis": ((-6, 0, 0), (0, 0.06, 0.0)),
        "Spine_0": (-6, 0, 0),
        "Head_0": (-10, 0, 0),
        "Jaw_0": (24, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, -24), mirror="Z"),
        **_pair("0_{side}_Limb_0", (-12, 0, 0)),
    },
    "snap": {
        "Pelvis": ((8, 0, 0), (0, -0.12, -0.02)),
        "Spine_0": (8, 0, 0),
        "Head_0": (12, 0, 0),
        "Jaw_0": (-2, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, 18), mirror="Z"),
        **_pair("0_{side}_Limb_0", (20, 0, 0)),
    },
    "rear": {
        "Pelvis": ((-22, 0, 0), (0, 0.1, 0.06)),
        "Spine_0": (-10, 0, 0),
        "Head_0": (-14, 0, 0),
        "Jaw_0": (30, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, -30), mirror="Z"),
        **_pair("0_{side}_Limb_0", (-50, 0, 0)),
        **_pair("0_{side}_Limb_1", (30, 0, 0)),
        **_pair("1_{side}_Limb_0", (-20, 0, 0)),
    },
    "crash": {
        "Pelvis": ((12, 0, 0), (0, -0.06, -0.06)),
        "Spine_0": (8, 0, 0),
        "Head_0": (10, 0, 0),
        "Jaw_0": (10, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, 10), mirror="Z"),
        **_pair("0_{side}_Limb_0", (24, 0, 0)),
        **_pair("1_{side}_Limb_0", (10, 0, 0)),
    },
}


def _boss_clips(poses, attack_ready, attack_done, special_ready, special_done):
    """The four boss clips from four poses: windup, strike (the hit at frame 4), specialWindup (up fast, held with a
    tremble), specialRelease (the hit at frame 4, held, back to rest)."""
    def windup(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 19, poses[attack_ready])

    def strike(rig):
        kit.key_pose(rig, 1, poses[attack_ready])
        kit.key_pose(rig, 4, poses[attack_done])
        kit.key_pose(rig, 16, poses["rest"])

    def special_windup(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 16, poses[special_ready])
        tremble = dict(poses[special_ready])
        x, y, z = tremble.get("Spine_0", (0, 0, 0))
        tremble["Spine_0"] = (x - 3, y, z + 2)
        kit.key_pose(rig, 30, tremble)
        kit.key_pose(rig, 43, poses[special_ready])

    def special_release(rig):
        kit.key_pose(rig, 1, poses[special_ready])
        kit.key_pose(rig, 4, poses[special_done])
        kit.key_pose(rig, 12, poses[special_done])
        kit.key_pose(rig, 25, poses["rest"])

    return {
        "windup": (windup, 19, {}),
        "strike": (strike, 16, {"Hit": 0.07}),
        "specialWindup": (special_windup, 43, {}),
        "specialRelease": (special_release, 25, {"Hit": 0.1}),
    }


WARDEN = {"rest": warden.REST, "ready": warden.SWIPE_READY, "done": warden.SWIPE_DONE, "up": warden.SLAM_READY,
          "down": warden.SLAM_DOWN}
BOSSES = {
    "FrostTyrant": ("frostTyrant", _boss_clips(WARDEN, "ready", "done", "up", "down")),
    "StormSovereign": ("stormSovereign", _boss_clips(SOVEREIGN, "ready", "bite", "rear", "clap")),
    "RiftDevourer": ("riftDevourer", _boss_clips(DEVOURER, "ready", "snap", "rear", "crash")),
}


def _open(folder):
    import bpy
    blend = os.path.abspath(os.path.join(ASSETS, folder, folder + ".blend"))
    if os.path.normcase(bpy.data.filepath) != os.path.normcase(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
    rig = kit.armature()
    kit.reset(rig)
    return rig


def monster_clips(folder):
    """Its Wild counterpart's windup and strike, keyed on its own rig."""
    _, donor = MONSTERS[folder]
    poses = wild.SPECIES[donor]

    def windup(rig):
        kit.key_pose(rig, 1, {})
        kit.key_pose(rig, 19, poses["ready"])

    def strike(rig):
        kit.key_pose(rig, 1, poses["ready"])
        kit.key_pose(rig, 4, poses["done"])
        kit.key_pose(rig, 16, {})

    return {"windup": (windup, 19, {}), "strike": (strike, 16, {"Hit": 0.07})}


def make(folder):
    if folder in MONSTERS:
        game, clips = MONSTERS[folder][0], monster_clips(folder)
    else:
        game, clips = BOSSES[folder]
    paths = []
    for clip, (keying, last, markers) in clips.items():
        rig = _open(folder)
        keying(rig)
        paths.append(kit.export_clip(rig, clip, 1, last, os.path.join(JSON_DIR, game), markers))
    return paths


if __name__ == "__main__":
    wanted = [m for m in os.environ.get("MODELS", ",".join(list(MONSTERS) + list(BOSSES))).split(",") if m]
    for folder in wanted:
        for path in make(folder):
            print("clip", path)
