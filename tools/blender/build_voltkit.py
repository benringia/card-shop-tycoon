"""Builds the Voltkit creature (a fox hero standing on two legs: golden-yellow fur, a cream chest with magenta chevrons,
magenta ear tips and tail bands, amber eyes under magenta brows, a pink gem on its brow and another on a necklace,
a magenta cape, dark brown boots, card art assets/ui/card-art/Voltkit.jpg) in Blender. A Very Rare card, so cool and
confident: a determined look, no fangs. Sturdy: a big head, thick limbs, a bushy tail. Blocky voxel style.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: Pelvis, Spine_0/1, Neck, Head_0, tall ears (Ear_Left_0, Ear_Right_0), arms
(Arm_Left_0..2), legs (0_Left_Limb_0..2), a bushy tail (Tail_0..3) and a three-bone cape hanging from the shoulders
(Cape_0..2, it billows back when running and flutters standing), so it walks on two legs with its arms swinging and
charges lightning between its fists (Party.SIGNATURE).

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Voltkit/{Voltkit.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Voltkit"

COLORS = {
    "fur": (236, 190, 50),
    "fur_dark": (206, 154, 34),
    "cream": (250, 222, 180),
    "magenta": (196, 40, 120),
    "magenta_dark": (150, 26, 92),
    "gem": (255, 90, 200),
    "gem_light": (255, 170, 230),
    "eye": (232, 150, 40),
    "pupil": (40, 20, 10),
    "nose": (40, 26, 20),
    "boot": (84, 52, 36),
    "boot_dark": (60, 36, 26),
}

HIP, KNEE, ANKLE = 0.96, 0.56, 0.16
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, HAND_X = 1.74, 0.46, 0.88, 1.26, 1.5
NECK_Z, HEAD_Z = 1.96, 2.06
HEAD_BASE = Vector((0, -0.02, HEAD_Z))
HEAD_SCALE = 1.45
HEAD_XFORM = Matrix.Translation(HEAD_BASE) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-HEAD_BASE)
TAIL = [(0, 0.3, 1.0), (0.1, 0.72, 0.84), (0.2, 1.06, 1.0), (0.24, 1.26, 1.34), (0.2, 1.3, 1.66)]
CAPE = [(0, 0.36, 1.98), (0, 0.42, 1.6), (0, 0.48, 1.2), (0, 0.54, 0.8)]


def head_point(p):
    return tuple(HEAD_XFORM @ Vector(p))


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
        ("Pelvis", "Root", (0, 0, HIP), (0, 0, 1.22)),
        ("Spine_0", "Pelvis", (0, 0, 1.22), (0, -0.02, 1.52)),
        ("Spine_1", "Spine_0", (0, -0.02, 1.52), (0, -0.02, NECK_Z)),
        ("Neck", "Spine_1", (0, -0.02, NECK_Z), (0, -0.02, HEAD_Z)),
        ("Head_0", "Neck", (0, -0.02, HEAD_Z), head_point((0, -0.02, 2.62))),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for i in range(len(CAPE) - 1):
        bones.append((f"Cape_{i}", "Spine_1" if i == 0 else f"Cape_{i - 1}", CAPE[i], CAPE[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones += [
            (f"Ear_{side}_0", "Head_0", head_point((sx * 0.18, 0.0, 2.36)), head_point((sx * 0.24, 0.0, 2.62))),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, -0.02, SHOULDER_Z), (sx * ELBOW_X, -0.02, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, -0.02, SHOULDER_Z), (sx * WRIST_X, -0.02, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, -0.02, SHOULDER_Z), (sx * HAND_X, -0.02, SHOULDER_Z)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.26, 0, HIP), (sx * 0.27, -0.03, KNEE)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.27, -0.03, KNEE), (sx * 0.27, 0.02, ANKLE)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.27, 0.02, ANKLE), (sx * 0.27, -0.3, 0.04)),
        ]
    return bones


def limb(b, a, c, width, color, bone):
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.box((a + c) / 2, (width, width, along.length + width * 0.4), color, bone, rot)


def build_body(b):
    b.box((0, 0, 1.08), (0.7, 0.5, 0.36), "fur", "Pelvis")
    b.box((0, -0.01, 1.4), (0.76, 0.54, 0.4), "fur", "Spine_0")
    b.box((0, -0.02, 1.76), (0.86, 0.56, 0.44), "fur", "Spine_1")
    # Cream chest with magenta chevrons
    b.box((0, -0.29, 1.5), (0.46, 0.04, 0.6), "cream", "Spine_0")
    b.box((0, -0.3, 1.82), (0.5, 0.04, 0.26), "cream", "Spine_1")
    for i, z in enumerate((1.62, 1.46, 1.3)):
        width = 0.36 - i * 0.08
        for sx in (1, -1):
            b.box((sx * width / 4, -0.315, z), (width / 2, 0.02, 0.05), "magenta", "Spine_0",
                  Matrix.Rotation(sx * 0.5, 3, "Y"))
    # The necklace: a magenta band round the neck and a big pink gem at the front
    b.box((0, -0.02, 1.98), (0.5, 0.48, 0.08), "magenta", "Neck")
    b.box((0, -0.33, 1.9), (0.16, 0.06, 0.18), "gem", "Spine_1")
    b.box((0, -0.365, 1.93), (0.07, 0.02, 0.07), "gem_light", "Spine_1")
    # The cape's collar sits on the shoulders
    b.box((0, 0.1, 2.0), (0.9, 0.4, 0.1), "magenta_dark", "Spine_1")


def build_head(b):
    h = "Head_0"
    b.xform = HEAD_XFORM
    b.box((0, -0.02, 2.28), (0.5, 0.46, 0.42), "fur", h)
    b.box((0, -0.28, 2.2), (0.24, 0.16, 0.16), "fur", h)  # snout
    b.box((0, -0.28, 2.14), (0.22, 0.14, 0.05), "cream", h)  # cream under the snout
    b.box((0, -0.37, 2.24), (0.08, 0.03, 0.06), "nose", h)
    b.box((0, -0.256, 2.42), (0.09, 0.02, 0.1), "gem", h)  # brow gem
    for sx in (1, -1):
        b.box((sx * 0.14, -0.255, 2.32), (0.1, 0.02, 0.06), "eye", h)
        b.box((sx * 0.13, -0.265, 2.32), (0.04, 0.02, 0.05), "pupil", h)
        b.box((sx * 0.14, -0.26, 2.37), (0.13, 0.03, 0.03), "magenta", h, Matrix.Rotation(sx * -0.25, 3, "Y"))  # determined brows
        b.box((sx * 0.22, -0.2, 2.16), (0.08, 0.1, 0.1), "cream", h)  # cream cheeks
        ear = f"Ear_{side_name(sx)}_0"
        b.box((sx * 0.2, 0.0, 2.52), (0.16, 0.1, 0.2), "fur", ear)
        b.box((sx * 0.21, 0.0, 2.66), (0.12, 0.08, 0.1), "magenta", ear)  # magenta tips
        b.box((sx * 0.2, -0.055, 2.5), (0.08, 0.02, 0.12), "cream", ear)
    b.xform = None


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = (f"Arm_{side}_{i}" for i in range(3))
        limb(b, (sx * (SHOULDER_X - 0.04), -0.02, z), (sx * ELBOW_X, -0.02, z), 0.24, "fur", upper)
        limb(b, (sx * ELBOW_X, -0.02, z), (sx * WRIST_X, -0.02, z), 0.22, "fur", fore)
        b.box((sx * 1.18, -0.02, z), (0.08, 0.26, 0.26), "magenta", fore)  # magenta cuffs
        b.box((sx * 1.4, -0.02, z), (0.22, 0.24, 0.24), "boot", hand)  # dark fists, like gloves


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        thigh, shin, foot = (f"0_{side}_Limb_{i}" for i in range(3))
        limb(b, (sx * 0.26, 0, HIP), (sx * 0.27, -0.03, KNEE), 0.28, "fur", thigh)
        limb(b, (sx * 0.27, -0.03, KNEE), (sx * 0.27, 0.02, ANKLE), 0.25, "boot", shin)  # dark boots
        b.box((sx * 0.27, 0.0, 0.5), (0.3, 0.3, 0.06), "boot_dark", shin)  # boot cuffs
        b.box((sx * 0.27, -0.12, 0.08), (0.28, 0.4, 0.14), "boot", foot)


def build_tail(b):
    widths = (0.2, 0.28, 0.32, 0.26)
    colors = ("fur", "fur", "magenta", "cream")  # a magenta band, a cream tip
    for i in range(len(TAIL) - 1):
        limb(b, TAIL[i], TAIL[i + 1], widths[i], colors[i], f"Tail_{i}")


def build_cape(b):
    widths = (0.86, 0.9, 0.94)
    for i in range(len(CAPE) - 1):
        a, c = Vector(CAPE[i]), Vector(CAPE[i + 1])
        along = c - a
        rot = along.to_track_quat("Z", "Y").to_matrix()
        b.box((a + c) / 2, (widths[i], 0.06, along.length + 0.05), "magenta" if i < 2 else "magenta_dark", f"Cape_{i}", rot)


def parts(b):
    build_body(b)
    build_head(b)
    build_arms(b)
    build_legs(b)
    build_tail(b)
    build_cape(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
