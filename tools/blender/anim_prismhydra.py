"""The Prism Hydra's clips (owner 2026-11-12: "add the attack/skill animation/particles for its skill", then "we need an
animation and visual effects on all of those skills"; pipeline docs/animations.md "Bone rigs"), keyed with
anim_bone_kit on assets/blender/PrismHydraGuardian/PrismHydraGuardian.blend (the game's model: the Meshy temple guardian,
rig_prismHydraGuardian.py: five necks Hydra_<n>_0..2, heads Hydra_<n>_3, jaws Jaw_<n>, n 0-4; Spine_0/1, Pelvis).

Turns are in armature axes (X the model's left): +X leans an upright neck forward (toward -Y, its front), -X rears it
back; +Z turns it to the side; +X opens a jaw.
  windup          every neck rears back, heads up, jaws open wide (0.6 s)
  strike          the necks lunge forward together and the jaws snap shut (the hit at 0.07 s)
  specialWindup   all five necks rise high and arch back, jaws gaping, the body leaning back, trembling (1.4 s: the
                  ring's warning)
  specialRelease  the five heads slam down together over the ring (the hit at 0.1 s), held, back to rest
  shield          its Tide shield going up (1.6 s): the necks pull in and back, the heads tucked low and close, jaws shut,
                  braced, a shiver as the ice forms
  heal            its Bloom heal (2 s): the heads lift to the sky, jaws open, swaying slowly as the light comes down
  enrage          its Ember enrage (1.8 s): it rears up, the heads thrash side to side, then all five roar forward
  clapWindup      its Volt thunderclap's warning (2 s): heads high, jaws gaping, shuddering as it charges
  clapRelease     the clap (1.2 s, hit at 0.1 s): the five heads whip down to the ground
  summon          its Shade summoning (1.6 s, Bosses adds.cast): up high screeching, trembling, then the heads plunge
                  to the ground as the rifts open

Run in a background Blender (writes assets/blender/Animations/prismHydra/<clip>.json):
  blender -b --factory-startup --python tools/blender/anim_prismhydra.py
then `lune run tools/anim/build_bone_clips prismHydra`.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_frontier as fr  # noqa: E402  (its boss clip builder, .blend opener and export)
import anim_bone_kit as kit  # noqa: E402

HEADS = range(5)


def _necks(base, head, jaw, spine0=0, spine1=0, yaw=None):
    """A pose: every neck's three segments turned `base` (degrees of X, the middle head a little more), the heads
    `head`, the jaws `jaw`, the spine leaning with them; `yaw` (a function of the head's number) turns each neck to the
    side."""
    pose = {"Spine_0": (spine0, 0, 0), "Spine_1": (spine1, 0, 0)}
    for n in HEADS:
        boost = 1.15 if n == 0 else 1.0
        turn = yaw(n) if yaw else 0
        for i, share in enumerate((0.9, 1.0, 0.7)):
            pose[f"Hydra_{n}_{i}"] = (base * share * boost, 0, turn * share)
        pose[f"Hydra_{n}_3"] = (head * boost, 0, turn * 0.5)
        pose[f"Jaw_{n}"] = (jaw, 0, 0)
    return pose


def _shake(pose, amount, sign):
    """The pose with every neck turned `amount` degrees to the side, alternating by head, flipped by `sign`."""
    shaken = dict(pose)
    for n in HEADS:
        side = sign if n % 2 == 0 else -sign
        for i in range(4):
            x, y, z = shaken[f"Hydra_{n}_{i}"]
            shaken[f"Hydra_{n}_{i}"] = (x, y, z + amount * side * (0.5 if i == 3 else 1))
    return shaken


HYDRA = {
    "rest": {},
    "ready": _necks(-10, -14, 34, spine1=-6),
    "bite": _necks(15, 10, 5, spine1=8),
    "rear": _necks(-18, -22, 44, spine0=-8, spine1=-10),
    "slam": _necks(24, 14, 10, spine0=10, spine1=12),
    "guard": _necks(-12, 16, 0, spine0=4, spine1=-4),
    "sky": _necks(-20, -32, 30, spine1=-8),
    "roarUp": _necks(-22, -28, 50, spine0=-10, spine1=-12),
    "roarForward": _necks(16, 8, 50, spine0=6, spine1=8),
    "thunderUp": _necks(-24, -30, 46, spine0=-10, spine1=-12),
    "thunderClap": _necks(28, 18, 16, spine0=12, spine1=14),
    "plunge": _necks(30, 22, 40, spine0=10, spine1=14),
}


def _skill_clips(poses):
    def shield(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 10, poses["guard"])
        for index, frame in enumerate((16, 22, 28, 34)):
            kit.key_pose(rig, frame, _shake(poses["guard"], 3, 1 if index % 2 == 0 else -1))
        kit.key_pose(rig, 38, poses["guard"])
        kit.key_pose(rig, 48, poses["rest"])

    def heal(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 14, poses["sky"])
        kit.key_pose(rig, 26, _shake(poses["sky"], 6, 1))
        kit.key_pose(rig, 38, _shake(poses["sky"], 6, -1))
        kit.key_pose(rig, 46, poses["sky"])
        kit.key_pose(rig, 60, poses["rest"])

    def enrage(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 9, poses["roarUp"])
        for index, frame in enumerate((13, 17, 21, 25, 29)):
            kit.key_pose(rig, frame, _shake(poses["roarUp"], 14, 1 if index % 2 == 0 else -1))
        kit.key_pose(rig, 33, poses["roarForward"])
        kit.key_pose(rig, 44, poses["roarForward"])
        kit.key_pose(rig, 54, poses["rest"])

    def clap_windup(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 20, poses["thunderUp"])
        for index, frame in enumerate((28, 36, 44, 52)):
            kit.key_pose(rig, frame, _shake(poses["thunderUp"], 5, 1 if index % 2 == 0 else -1))
        kit.key_pose(rig, 61, poses["thunderUp"])

    def clap_release(rig):
        kit.key_pose(rig, 1, poses["thunderUp"])
        kit.key_pose(rig, 4, poses["thunderClap"])
        kit.key_pose(rig, 14, poses["thunderClap"])
        kit.key_pose(rig, 37, poses["rest"])

    def summon(rig):
        kit.key_pose(rig, 1, poses["rest"])
        kit.key_pose(rig, 12, poses["roarUp"])
        for index, frame in enumerate((17, 22, 27)):
            kit.key_pose(rig, frame, _shake(poses["roarUp"], 8, 1 if index % 2 == 0 else -1))
        kit.key_pose(rig, 29, poses["roarUp"])
        kit.key_pose(rig, 32, poses["plunge"])
        kit.key_pose(rig, 38, poses["plunge"])
        kit.key_pose(rig, 49, poses["rest"])

    return {
        "shield": (shield, 48, {}),
        "heal": (heal, 60, {}),
        "enrage": (enrage, 54, {}),
        "clapWindup": (clap_windup, 61, {}),
        "clapRelease": (clap_release, 37, {"Hit": 0.1}),
        "summon": (summon, 49, {}),
    }


fr.BOSSES["PrismHydraGuardian"] = ("prismHydra", {**fr._boss_clips(HYDRA, "ready", "bite", "rear", "slam"), **_skill_clips(HYDRA)})

if __name__ == "__main__":
    for path in fr.make("PrismHydraGuardian"):
        print("clip", path)
