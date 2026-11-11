"""The Frontier's monster and boss clips (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md; pipeline
docs/animations.md "Bone rigs"), keyed with anim_bone_kit on assets/blender/<Name>/<Name>.blend (rig_frontier_monsters.py,
rig_frontier_bosses.py).

The six monsters share their Wild counterparts' attacks (anim_wild.py `ready` and `done` poses, the bones a rig lacks
left out): the Shade Lynx the Ash Wolf's lunging bite, the Storm Hawk the Cave Bat's dive, the Lava Brute the Magma
Golem's ground punch, the Rift Horror the Spark Beetle's horn charge, the Prism Crab the Puddle Crab's pincer snap, the
Frost Wisp the Mossling's headbutt (as a body slam). Clips `windup` (0.6 s) and `strike` (0.5 s, Hit at 0.07 s).

The three bosses also have `specialWindup` (1.4 s, its ring's warning) and `specialRelease` (0.8 s, Hit at 0.1 s):
  frostTyrant     his own (the owner 2026-11-10): a twisting claw swipe, jaw open; for his ice spikes he throws his head
                  back roaring with his arms out, calling the ice down, then crouches and slams his fists down as it falls
  stormSovereign  rears back with wings high and jaws open, lunges and bites; rears up with its wings spread wide, then
                  beats them down and roars. Its thunderclap (the owner 2026-11-11) has its own two: `clapWindup`
                  (2 s: wings raised high in a wide V, head thrown back roaring at the sky, shuddering as the storm
                  charges) and `clapRelease` (1.2 s, Hit at 0.1 s: its wings swing forward and clap together in front
                  of its chest, head down roaring, then back to rest)
  riftDevourer    rears back with its jaws wide and mandibles spread, then lunges far forward, head down, snapping them
                  shut (bigger since the owner 2026-11-11: "doesnt have a basic attack animation yet"); rears its front
                  up, then crashes down. Its summoning (2026-11-11) has its own `summon` (1.6 s): it rears up high
                  screeching, front legs reaching up, trembles, then slams its front down as the rifts open

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
    # the thunderclap's own (2026-11-11; stretch checked against "rear" and "clap": no worse)
    "thunderUp": {
        "Pelvis": ((-6, 0, 0), (0, 0.03, 0.04)),
        "Spine_0": (-8, 0, 0),
        "Spine_1": (-10, 0, 0),
        "Neck": (-16, 0, 0),
        "Head_0": (-22, 0, 0),
        "Jaw_0": (34, 0, 0),
        "Tail_0": (-12, 0, 0),
        **_pair("Wing_{side}_0", (0, -42, -12)),
        **_pair("Wing_{side}_1", (0, -22, 0)),
        **_pair("Wing_{side}_2", (0, -12, 0)),
        **_pair("Arm_{side}_0", (-55, 20, 0)),
    },
    "thunderClap": {
        "Pelvis": ((8, 0, 0), (0, -0.03, -0.03)),
        "Spine_0": (8, 0, 0),
        "Spine_1": (8, 0, 0),
        "Neck": (6, 0, 0),
        "Head_0": (-4, 0, 0),
        "Jaw_0": (34, 0, 0),
        "Tail_0": (-10, 0, 0),
        **_pair("Wing_{side}_0", (0, 5, -75)),
        **_pair("Wing_{side}_1", (0, 0, -30)),
        **_pair("Wing_{side}_2", (0, 0, -20)),
        **_pair("Arm_{side}_0", (-30, 0, 0)),
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

# His own (2026-11-10). His rig tears on big arm swings (its arm bones sit inside the body, so its arms are skinned
# with a wide radius: arms raised past about 30 degrees stretch into slabs, checked in renders), so the drama is in his
# spine, head and jaw and his arms move a little: a twisting claw swipe; for his ice spikes he throws his head back
# roaring with his arms out (the spikes forming high over the rings), then crouches and slams his fists down
FROST = {
    "rest": {},
    "ready": {
        "Spine_0": (-6, 0, -20), "Spine_1": (-8, 0, -26), "Head_0": (6, 0, 16), "Jaw_0": (20, 0, 0),
        "Arm_Right_0": (-25, 20, 0), "Arm_Right_1": (-25, 0, 0), "Arm_Left_0": (-10, -8, 0),
    },
    "swipe": {
        "Spine_0": (12, 0, 22), "Spine_1": (14, 0, 28), "Head_0": (-6, 0, -12), "Jaw_0": (12, 0, 0),
        "Arm_Right_0": (-30, -25, 0), "Arm_Left_0": (12, 8, 0),
    },
    "summon": {
        "Pelvis": ((-6, 0, 0), (0, 0, 0.03)), "Spine_0": (-16, 0, 0), "Spine_1": (-18, 0, 0), "Neck": (-12, 0, 0),
        "Head_0": (-26, 0, 0), "Jaw_0": (36, 0, 0),
        **_pair("Arm_{side}_0", (-20, 25, 0)), **_pair("Arm_{side}_1", (-25, 0, 0)), **_pair("Arm_{side}_2", (15, 0, 0)),
    },
    "command": {
        "Pelvis": ((12, 0, 0), (0, 0, -0.07)), "Spine_0": (18, 0, 0), "Spine_1": (22, 0, 0), "Neck": (6, 0, 0),
        "Head_0": (2, 0, 0), "Jaw_0": (28, 0, 0),
        **_pair("Arm_{side}_0", (-30, 8, 0)), **_pair("Arm_{side}_1", (-15, 0, 0)), **_pair("Arm_{side}_2", (-10, 0, 0)),
    },
}

# Its bite read as a nod at boss size (the owner 2026-11-11: "doesnt have a basic attack animation yet"), so it rears
# well back and lunges a third of its length (its Pelvis pivots at its back end: +X tips its head down)
DEVOURER = {
    "rest": {},
    "ready": {
        "Pelvis": ((-12, 0, 0), (0, 0.16, 0.05)),
        "Spine_0": (-6, 0, 0),
        "Head_0": (-16, 0, 0),
        "Jaw_0": (38, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, -36), mirror="Z"),
        **_pair("0_{side}_Limb_0", (-30, 0, 0)),
        **_pair("0_{side}_Limb_1", (20, 0, 0)),
    },
    "snap": {
        "Pelvis": ((14, 0, 0), (0, -0.32, -0.04)),
        "Spine_0": (8, 0, 0),
        "Head_0": (16, 0, 0),
        "Jaw_0": (-4, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, 26), mirror="Z"),
        **_pair("0_{side}_Limb_0", (26, 0, 0)),
        **_pair("2_{side}_Limb_0", (-14, 0, 0)),
    },
    # its summoning (2026-11-11): reared up high screeching, front legs reaching up; then its front slammed down
    "summonUp": {
        "Pelvis": ((-30, 0, 0), (0, 0.04, 0.1)),
        "Spine_0": (-10, 0, 0),
        "Head_0": (-24, 0, 0),
        "Jaw_0": (42, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, -40), mirror="Z"),
        **_pair("0_{side}_Limb_0", (-55, 0, 0)),
        **_pair("0_{side}_Limb_1", (35, 0, 0)),
        **_pair("1_{side}_Limb_0", (-25, 0, 0)),
    },
    "summonSlam": {
        "Pelvis": ((12, 0, 0), (0, -0.08, -0.05)),
        "Spine_0": (6, 0, 0),
        "Head_0": (10, 0, 0),
        "Jaw_0": (34, 0, 0),
        **_pair("Pincer_{side}_0", (0, 0, -20), mirror="Z"),
        **_pair("0_{side}_Limb_0", (30, 0, 0)),
        **_pair("1_{side}_Limb_0", (12, 0, 0)),
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


def _thunderclap_clips(poses):
    """The Storm Sovereign's thunderclap (2026-11-11): clapWindup (up over 20 frames, then shuddering as it charges, its
    wings quivering, held to the clap) and clapRelease (the clap at frame 4, held, back to rest)."""
    def clap_windup(rig):
        up = poses["thunderUp"]
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 20, up)
        for index, frame in enumerate((28, 36, 44, 52)):
            shiver = dict(up)
            sign = 1 if index % 2 == 0 else -1
            for name in ("Wing_Left_1", "Wing_Right_1"):
                x, y, z = shiver[name]
                shiver[name] = (x, y - 4 * sign, z)
            x, y, z = shiver.get("Spine_0", (0, 0, 0))
            shiver["Spine_0"] = (x - 2 * sign, y, z + 1.5 * sign)
            kit.key_pose(rig, frame, shiver)
        kit.key_pose(rig, 61, up)

    def clap_release(rig):
        kit.key_pose(rig, 1, poses["thunderUp"])
        kit.key_pose(rig, 4, poses["thunderClap"])
        kit.key_pose(rig, 14, poses["thunderClap"])
        kit.key_pose(rig, 37, poses["rest"])

    return {
        "clapWindup": (clap_windup, 61, {}),
        "clapRelease": (clap_release, 37, {"Hit": 0.1}),
    }


def _summon_clip(poses):
    """The Rift Devourer's summoning (2026-11-11): `summon`, 1.6 s (its Bosses adds.cast): up over 12 frames, trembling
    as it screeches, its front slammed down at frame 32 as the rifts open, held, back to rest."""
    def summon(rig):
        up = poses["summonUp"]
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 12, up)
        for index, frame in enumerate((17, 22, 27)):
            shiver = dict(up)
            sign = 1 if index % 2 == 0 else -1
            x, y, z = shiver["Head_0"]
            shiver["Head_0"] = (x - 4 * sign, y, z + 3 * sign)
            x, y, z = shiver["Spine_0"]
            shiver["Spine_0"] = (x, y, z - 2 * sign)
            kit.key_pose(rig, frame, shiver)
        kit.key_pose(rig, 29, up)
        kit.key_pose(rig, 32, poses["summonSlam"])
        kit.key_pose(rig, 38, poses["summonSlam"])
        kit.key_pose(rig, 49, poses["rest"])

    return {"summon": (summon, 49, {})}


WARDEN = {"rest": warden.REST, "ready": warden.SWIPE_READY, "done": warden.SWIPE_DONE, "up": warden.SLAM_READY,
          "down": warden.SLAM_DOWN}
BOSSES = {
    "FrostTyrant": ("frostTyrant", _boss_clips(FROST, "ready", "swipe", "summon", "command")),
    "StormSovereign": ("stormSovereign", {**_boss_clips(SOVEREIGN, "ready", "bite", "rear", "clap"), **_thunderclap_clips(SOVEREIGN)}),
    "RiftDevourer": ("riftDevourer", {**_boss_clips(DEVOURER, "ready", "snap", "rear", "crash"), **_summon_clip(DEVOURER)}),
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
