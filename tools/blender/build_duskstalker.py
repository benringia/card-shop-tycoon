"""Builds the Duskstalker creature (a shadow Monkey King: a stocky fighter monkey with dark plum fur, a tan face and
chest, glowing amber eyes, a golden circlet with a violet gem, gold shoulder armour, a red cape, purple trousers
with a gold belt and a golden staff with red bands in its right hand) in Blender. A Very Rare card, so cool and
confident rather than cute or scary: a sly smile, no fangs. Sturdy, not skinny: broad shoulders, a barrel chest,
thick arms and legs, big fists and feet, a big head. Blocky voxel style (boxes, spikes and cubes).

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: Pelvis, Spine_0/1, Neck, Head_0, long arms (Arm_Left_0..2; the staff rides the right
hand), legs (0_Left_Limb_0..2), round ears (Ear_Left_0, Ear_Right_0) and a long tail curling up (Tail_0..3), so it
walks on two legs with a big arm swing, its tail swishes behind and it backflips (Party.SIGNATURE).

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Duskstalker/{Duskstalker.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Duskstalker"

COLORS = {
    "fur": (104, 42, 70),
    "fur_dark": (76, 28, 52),
    "tan": (214, 168, 110),
    "tan_dark": (184, 134, 84),
    "eye": (255, 170, 40),
    "pupil": (60, 20, 10),
    "gold": (236, 190, 60),
    "gold_dark": (190, 140, 30),
    "gem": (190, 90, 255),
    "cape": (190, 40, 50),
    "cape_dark": (140, 24, 36),
    "trousers": (96, 52, 140),
    "staff": (230, 180, 60),
    "staff_band": (200, 40, 40),
    "mouth": (90, 40, 40),
}

HIP, KNEE, ANKLE = 0.98, 0.56, 0.16
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, HAND_X = 1.8, 0.5, 0.98, 1.4, 1.68
NECK_Z, HEAD_Z = 2.0, 2.1
HEAD_BASE = Vector((0, -0.04, HEAD_Z))
HEAD_SCALE = 1.5
HEAD_XFORM = Matrix.Translation(HEAD_BASE) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-HEAD_BASE)
TAIL = [(0, 0.3, 1.0), (0, 0.74, 0.86), (0, 1.08, 1.06), (0, 1.2, 1.44), (0, 1.02, 1.7)]


def head_point(p):
    return tuple(HEAD_XFORM @ Vector(p))


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
        ("Pelvis", "Root", (0, 0, HIP), (0, 0, 1.26)),
        ("Spine_0", "Pelvis", (0, 0, 1.26), (0, -0.02, 1.58)),
        ("Spine_1", "Spine_0", (0, -0.02, 1.58), (0, -0.04, NECK_Z)),
        ("Neck", "Spine_1", (0, -0.04, NECK_Z), (0, -0.04, HEAD_Z)),
        ("Head_0", "Neck", (0, -0.04, HEAD_Z), head_point((0, -0.04, 2.7))),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones += [
            (f"Ear_{side}_0", "Head_0", head_point((sx * 0.32, -0.02, 2.36)), head_point((sx * 0.42, -0.02, 2.44))),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, -0.04, SHOULDER_Z), (sx * ELBOW_X, -0.04, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, -0.04, SHOULDER_Z), (sx * WRIST_X, -0.04, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, -0.04, SHOULDER_Z), (sx * HAND_X, -0.04, SHOULDER_Z)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.3, 0, HIP), (sx * 0.32, -0.04, KNEE)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.32, -0.04, KNEE), (sx * 0.32, 0.02, ANKLE)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.32, 0.02, ANKLE), (sx * 0.32, -0.34, 0.04)),
        ]
    return bones


def limb(b, a, c, width, color, bone):
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.box((a + c) / 2, (width, width, along.length + width * 0.4), color, bone, rot)


def build_body(b):
    # Stocky: broad hips, a barrel chest and wide shoulders under gold pauldrons
    b.box((0, 0, 1.1), (0.84, 0.56, 0.4), "trousers", "Pelvis")
    b.box((0, -0.02, 1.3), (0.88, 0.6, 0.12), "gold", "Pelvis")  # gold belt
    b.box((0, -0.33, 1.3), (0.2, 0.05, 0.11), "gem", "Pelvis")
    b.box((0, -0.01, 1.5), (0.9, 0.62, 0.42), "fur", "Spine_0")
    b.box((0, -0.03, 1.84), (1.08, 0.66, 0.48), "fur", "Spine_1")
    b.cube((0, -0.32, 1.62), (0.32, 0.08, 0.3), "tan", "Spine_0")  # chest
    for sx in (1, -1):
        b.cube((sx * 0.56, -0.04, 1.98), (0.22, 0.26, 0.16), "gold", "Spine_1")  # pauldrons
        b.cube((sx * 0.56, -0.04, 2.06), (0.1, 0.14, 0.06), "gold_dark", "Spine_1")
    # A red cape hanging from the shoulders down the back
    b.box((0, 0.4, 1.5), (0.9, 0.08, 0.9), "cape", "Spine_1")
    b.box((0, 0.44, 1.12), (0.82, 0.06, 0.3), "cape_dark", "Pelvis")
    b.box((0, -0.04, 2.04), (0.4, 0.34, 0.16), "fur_dark", "Neck")


def build_head(b):
    h = "Head_0"
    b.xform = HEAD_XFORM
    b.cube((0, -0.04, 2.3), (0.3, 0.27, 0.27), "fur", h)
    b.cube((0, -0.24, 2.26), (0.22, 0.1, 0.19), "tan", h)  # face
    b.cube((0, -0.32, 2.14), (0.15, 0.1, 0.09), "tan_dark", h)  # muzzle
    b.box((0, -0.41, 2.18), (0.09, 0.02, 0.025), "fur_dark", h)  # nostrils
    b.box((0.03, -0.41, 2.09), (0.13, 0.02, 0.02), "mouth", h)  # sly half smile
    for sx in (1, -1):
        b.cube((sx * 0.1, -0.31, 2.33), (0.055, 0.025, 0.035), "eye", h, segments=8, rings=5)
        b.cube((sx * 0.1, -0.33, 2.33), (0.02, 0.01, 0.025), "pupil", h, segments=6, rings=4)
        b.box((sx * 0.11, -0.32, 2.39), (0.13, 0.03, 0.035), "fur_dark", h)  # low brows
        ear = f"Ear_{side_name(sx)}_0"
        b.cube((sx * 0.33, -0.02, 2.3), (0.06, 0.08, 0.09), "tan_dark", ear, segments=8, rings=5)
    # The golden circlet, a gem at the front, two little curls at the temples
    b.cube((0, -0.04, 2.44), (0.31, 0.29, 0.045), "gold", h, segments=18, rings=6)
    b.cube((0, -0.33, 2.45), (0.05, 0.03, 0.06), "gem", h, segments=8, rings=5)
    for sx in (1, -1):
        b.cube((sx * 0.3, -0.12, 2.5), (0.04, 0.04, 0.07), "gold_dark", h, segments=6, rings=4)
    b.xform = None


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = (f"Arm_{side}_{i}" for i in range(3))
        limb(b, (sx * (SHOULDER_X - 0.04), -0.04, z), (sx * ELBOW_X, -0.04, z), 0.3, "fur", upper)
        limb(b, (sx * ELBOW_X, -0.04, z), (sx * WRIST_X, -0.04, z), 0.27, "fur", fore)
        b.box((sx * 1.3, -0.04, z), (0.1, 0.3, 0.3), "gold", fore)  # gold wrist bands
        b.cube((sx * 1.56, -0.04, z), (0.16, 0.15, 0.15), "tan", hand)  # big fists
    build_staff(b)


def build_staff(b):
    """The golden staff, a weapon gripped through the right fist, not lined up with the arm, and taller than the
    monkey. In the T-pose it crosses the fist pointing forward and a little in towards the body; once the arm hangs at
    its side in game that turns into the staff held nearly level, pointing forward past its feet, gripped at its
    middle."""
    staff = "Arm_Right_2"
    grip = Vector((-1.56, -0.04, SHOULDER_Z))
    along = Vector((0.26, -0.97, 0)).normalized()  # forward and a little inward now; forward, tipped up, once the arm hangs
    top, bottom = grip + along * 1.6, grip - along * 1.6  # 3.2 long, held at the middle; the monkey is about 2.8 tall
    b.span(bottom, top, 0.09, "staff", staff)
    for end, inward in ((top, -1), (bottom, 1)):
        band = end + along * inward * 0.12
        b.span(band - along * 0.06, band + along * 0.06, 0.11, "staff_band", staff)
        b.span(end - along * 0.03 * inward, end, 0.1, "gold_dark", staff)  # golden caps


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        thigh, shin, foot = (f"0_{side}_Limb_{i}" for i in range(3))
        limb(b, (sx * 0.3, 0, HIP), (sx * 0.32, -0.04, KNEE), 0.34, "trousers", thigh)
        limb(b, (sx * 0.32, -0.04, KNEE), (sx * 0.32, 0.02, ANKLE), 0.28, "fur", shin)
        b.box((sx * 0.32, 0.02, 0.26), (0.3, 0.3, 0.1), "gold", shin)  # gold anklets
        b.cube((sx * 0.32, -0.14, 0.08), (0.17, 0.24, 0.08), "tan", foot)


def build_tail(b):
    for i in range(len(TAIL) - 1):
        limb(b, TAIL[i], TAIL[i + 1], (0.15, 0.13, 0.12, 0.1)[i], "fur", f"Tail_{i}")
    b.cube(TAIL[-1], (0.11, 0.11, 0.11), "fur_dark", "Tail_3")


def parts(b):
    build_body(b)
    build_head(b)
    build_arms(b)
    build_legs(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
