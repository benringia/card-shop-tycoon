"""Builds the Thornback creature (a kung-fu praying mantis, lime green with orange armour plates, card art
assets/ui/card-art/Thornback.jpg) in Blender. A Rare card, so friendly rather than scary: big round green eyes with
shine, blunt rounded scythes, soft orange plates instead of thorns.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four walking legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2) from the waist,
an upright body (Pelvis at the waist, Spine_0/1 rising to the chest), Neck, Head_0, scythe arms (Arm_Left_0..2,
folded in front by Party.ARM_POSE), antennae on the ear roles (Ear_Left_0, Ear_Right_0, which twitch) and its
abdomen trailing behind as a three-bone tail (Tail_0..2), so it walks on four legs with its scythes folded and its
antennae and abdomen sway.

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Thornback/{Thornback.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Thornback"

COLORS = {
    "lime": (170, 206, 62),
    "lime_dark": (124, 164, 40),
    "lime_light": (206, 232, 104),
    "armor": (236, 122, 50),
    "armor_dark": (196, 86, 36),
    "eye": (120, 222, 92),
    "pupil": (22, 42, 22),
    "shine": (250, 250, 245),
    "mouth": (90, 110, 30),
}

WAIST = Vector((0, 0.1, 0.95))
BELLY = Vector((0, -0.04, 1.32))
CHEST = Vector((0, -0.14, 1.7))
NECK_TOP = Vector((0, -0.18, 1.94))
HEAD_TIP = Vector((0, -0.56, 2.08))
FRONT_LEG = [(0.18, -0.02, 0.92), (0.56, -0.28, 0.86), (0.64, -0.44, 0.12), (0.64, -0.58, 0.04)]
HIND_LEG = [(0.18, 0.24, 0.92), (0.6, 0.44, 0.86), (0.7, 0.7, 0.12), (0.7, 0.82, 0.04)]
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, HAND_X = 1.66, 0.2, 0.56, 0.9, 1.16
ARM_Y = -0.2
TAIL = [(0, 0.24, 0.96), (0, 0.66, 0.86), (0, 1.06, 0.72), (0, 1.38, 0.56)]


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
        ("Pelvis", "Root", tuple(WAIST), tuple(BELLY)),
        ("Spine_0", "Pelvis", tuple(BELLY), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), (0, -0.16, 1.84)),
        ("Neck", "Spine_1", (0, -0.16, 1.84), tuple(NECK_TOP)),
        ("Head_0", "Neck", tuple(NECK_TOP), tuple(HEAD_TIP)),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones += [
            (f"Ear_{side}_0", "Head_0", (sx * 0.08, -0.3, 2.22), (sx * 0.26, -0.46, 2.62)),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, ARM_Y, SHOULDER_Z), (sx * ELBOW_X, ARM_Y, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, ARM_Y, SHOULDER_Z), (sx * WRIST_X, ARM_Y, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, ARM_Y, SHOULDER_Z), (sx * HAND_X, ARM_Y, SHOULDER_Z)),
        ]
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            for i in range(3):
                bone_parent = "Pelvis" if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    return bones


def build_body(b):
    b.box(WAIST + Vector((0, 0.06, 0)), (0.42, 0.42, 0.3), "lime", "Pelvis")
    b.box((0, -0.06, 1.3), (0.4, 0.34, 0.5), "lime", "Spine_0")
    b.box((0, -0.24, 1.3), (0.3, 0.04, 0.4), "lime_light", "Spine_0")  # pale belly
    b.box((0, -0.14, 1.66), (0.5, 0.38, 0.36), "lime", "Spine_1")
    # Orange chest armour and shoulder plates, rounded
    b.box((0, -0.34, 1.64), (0.38, 0.06, 0.3), "armor", "Spine_1")
    b.box((0, -0.36, 1.64), (0.2, 0.04, 0.2), "armor_dark", "Spine_1")
    for sx in (1, -1):
        b.box((sx * 0.26, -0.16, 1.78), (0.18, 0.34, 0.12), "armor", "Spine_1")
    b.box((0, -0.17, 1.88), (0.18, 0.18, 0.12), "lime_dark", "Neck")


def build_head(b):
    h = "Head_0"
    b.box((0, -0.32, 2.06), (0.42, 0.32, 0.3), "lime", h)
    b.box((0, -0.52, 1.98), (0.22, 0.14, 0.16), "lime", h)  # little mouthparts
    b.box((0, -0.6, 1.96), (0.1, 0.04, 0.04), "mouth", h)  # a small smile
    b.box((0, -0.3, 2.24), (0.2, 0.2, 0.08), "armor", h)  # orange crest
    for sx in (1, -1):
        # Big round friendly eyes on the sides
        b.box((sx * 0.25, -0.38, 2.1), (0.16, 0.22, 0.22), "eye", h)
        b.box((sx * 0.32, -0.42, 2.1), (0.04, 0.12, 0.12), "pupil", h)
        b.box((sx * 0.34, -0.46, 2.15), (0.02, 0.05, 0.05), "shine", h)
        ear = f"Ear_{side_name(sx)}_0"
        b.span((sx * 0.08, -0.3, 2.2), (sx * 0.26, -0.46, 2.62), 0.035, "lime_dark", ear)
        b.box((sx * 0.27, -0.47, 2.64), (0.06, 0.06, 0.06), "lime_light", ear)


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], 0.14, "lime", upper, 0.03)
            b.box(p[1], (0.18, 0.18, 0.16), "armor", upper)  # orange knee
            b.span(p[1], p[2], 0.12, "lime_dark", lower, 0.02)
            b.box(p[2] + Vector((0, -0.04, -0.04)), (0.16, 0.22, 0.08), "lime_dark", foot)


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = (f"Arm_{side}_{i}" for i in range(3))
        b.span((sx * SHOULDER_X, ARM_Y, z), (sx * ELBOW_X, ARM_Y, z), 0.14, "lime", upper, 0.03)
        b.box((sx * 0.4, ARM_Y, z + 0.06), (0.18, 0.16, 0.06), "armor", upper)
        b.span((sx * ELBOW_X, ARM_Y, z), (sx * WRIST_X, ARM_Y, z), 0.16, "lime", fore, 0.03)
        # A blunt, rounded scythe blade along the forearm and hand, with soft bumps instead of spikes
        b.box((sx * 0.74, ARM_Y - 0.1, z - 0.02), (0.32, 0.06, 0.14), "lime_light", fore)
        for dx in (0.64, 0.76, 0.86):
            b.box((sx * dx, ARM_Y - 0.14, z - 0.02), (0.04, 0.03, 0.05), "lime_dark", fore)
        b.span((sx * WRIST_X, ARM_Y, z), (sx * HAND_X, ARM_Y, z), 0.13, "lime", hand, 0.02)
        b.box((sx * 1.12, ARM_Y - 0.06, z - 0.06), (0.12, 0.1, 0.12), "lime_light", hand)


def build_tail(b):
    # The abdomen: long, segmented, orange plates on top
    widths = (0.4, 0.36, 0.26)
    for i in range(len(TAIL) - 1):
        a, c = Vector(TAIL[i]), Vector(TAIL[i + 1])
        bone = f"Tail_{i}"
        b.span(a, c, widths[i], "lime", bone, 0.04)
        mid = a.lerp(c, 0.5)
        b.box(mid + Vector((0, 0, widths[i] / 2 + 0.01)), (widths[i] * 0.7, (c - a).length * 0.7, 0.04), "armor", bone)
        b.box(mid + Vector((0, 0, -widths[i] / 2 - 0.01)), (widths[i] * 0.6, (c - a).length * 0.8, 0.03), "lime_light", bone)


def parts(b):
    build_body(b)
    build_head(b)
    build_legs(b)
    build_arms(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
