"""Builds the Boltlynx creature (blocky lion warrior, card art assets/ui/card-art/Boltlynx.jpg) in Blender.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads (Pelvis, Spine_0, Neck, Head_0, Arm_Left_0, 0_Left_Limb_0, Tail_0, Ear_Left_0...),
so the game's code walk, arm swing, tail wag and fidgets drive it without Util/RigGuess or config.

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Boltlynx/{Boltlynx.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Boltlynx"

# Palette: one flat colour per cell of an 8x8 grid
COLORS = {
    "fur": (232, 176, 42),
    "fur_light": (248, 216, 128),
    "fur_shade": (204, 146, 30),
    "mane": (246, 196, 36),
    "mane_dark": (214, 148, 22),
    "nose": (92, 52, 40),
    "eye_white": (240, 240, 235),
    "eye": (28, 26, 30),
    "brow": (150, 96, 20),
    "tunic": (142, 146, 152),
    "tunic_dark": (112, 114, 120),
    "hem": (150, 140, 92),
    "bolt": (255, 222, 40),
    "gold": (234, 184, 34),
    "gold_dark": (178, 126, 22),
    "black": (30, 30, 36),
    "white": (236, 236, 236),
    "belt": (112, 66, 30),
    "pouch": (134, 84, 42),
    "silver": (192, 194, 204),
    "trousers": (82, 56, 36),
    "trousers_dark": (64, 42, 28),
}

# Rig: (bone, parent, head, tail). Heights in metres, about 4 tall with the mane.
HIP, KNEE, ANKLE = 1.32, 0.82, 0.3
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, FIST_X = 2.42, 0.62, 1.16, 1.64, 2.04
# The head and mane are drawn big, like the card art: scaled up about the neck and lifted clear of the chest
NECK = Vector((0, 0, 2.7))
HEAD_SCALE = 1.3
HEAD_LIFT = Vector((0, 0.04, 0.14))
HEAD_XFORM = Matrix.Translation(NECK + HEAD_LIFT) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-NECK)


def head_point(p):
    return tuple(HEAD_XFORM @ Vector(p))


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", (0, 0, HIP), (0, 0, 1.6)),
        ("Spine_0", "Pelvis", (0, 0, 1.6), (0, 0, 2.02)),
        ("Spine_1", "Spine_0", (0, 0, 2.02), (0, 0, 2.5)),
        ("Neck", "Spine_1", (0, 0, 2.5), (0, 0, 2.7)),
        ("Head_0", "Neck", (0, 0, 2.7), head_point((0, 0, 3.45))),
        ("Tail_0", "Pelvis", (0, 0.27, 1.3), (0, 0.58, 1.06)),
        ("Tail_1", "Tail_0", (0, 0.58, 1.06), (0, 0.92, 0.9)),
        ("Tail_2", "Tail_1", (0, 0.92, 0.9), (0, 1.22, 0.96)),
        ("Tail_3", "Tail_2", (0, 1.22, 0.96), (0, 1.42, 1.2)),
    ]
    for side, sx in (("Left", 1), ("Right", -1)):
        bones += [
            (f"Ear_{side}_0", "Head_0", head_point((sx * 0.3, -0.05, 3.36)), head_point((sx * 0.32, -0.05, 3.62))),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, 0, SHOULDER_Z), (sx * ELBOW_X, 0, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, 0, SHOULDER_Z), (sx * WRIST_X, 0, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, 0, SHOULDER_Z), (sx * FIST_X, 0, SHOULDER_Z)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.32, 0, HIP), (sx * 0.32, 0, KNEE)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.32, 0, KNEE), (sx * 0.32, 0, ANKLE)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.32, 0, ANKLE), (sx * 0.32, -0.36, 0.1)),
        ]
    return bones


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        x = sx * 0.32
        thigh, shin, foot = f"0_{side}_Limb_0", f"0_{side}_Limb_1", f"0_{side}_Limb_2"
        b.box((x, 0, 1.08), (0.44, 0.44, 0.56), "trousers", thigh)
        b.box((x, -0.005, 0.96), (0.46, 0.45, 0.08), "trousers_dark", thigh)  # fold above the knee
        b.box((x, 0, 0.68), (0.4, 0.4, 0.4), "trousers", shin)
        # Boot: black and gold bands, the upper on the shin, the sole and toe on the foot
        b.box((x, -0.02, 0.56), (0.48, 0.5, 0.1), "gold", shin)
        b.box((x, -0.02, 0.46), (0.45, 0.47, 0.1), "black", shin)
        b.box((x, -0.02, 0.36), (0.45, 0.47, 0.1), "gold", shin)
        b.box((x, -0.02, 0.27), (0.45, 0.47, 0.08), "black", shin)
        b.box((x, -0.1, 0.17), (0.46, 0.66, 0.12), "gold", foot)
        b.box((x, -0.1, 0.05), (0.48, 0.7, 0.1), "black", foot)
        b.box((x, -0.43, 0.13), (0.42, 0.04, 0.12), "black", foot)  # toe cap stripe


def build_body(b):
    # Hips and tunic hem
    b.box((0, 0, 1.3), (0.96, 0.52, 0.3), "trousers", "Pelvis")
    b.box((0, -0.02, 1.28), (0.94, 0.58, 0.22), "hem", "Pelvis")
    # Belt with buckle and pouches
    b.box((0, 0, 1.47), (1.0, 0.6, 0.15), "belt", "Pelvis")
    b.box((0, -0.31, 1.47), (0.22, 0.04, 0.13), "silver", "Pelvis")
    b.box((0, -0.33, 1.47), (0.12, 0.02, 0.07), "belt", "Pelvis")
    for sx in (1, -1):
        b.box((sx * 0.3, -0.33, 1.4), (0.2, 0.1, 0.22), "pouch", "Pelvis")
        b.box((sx * 0.3, -0.385, 1.47), (0.21, 0.03, 0.07), "belt", "Pelvis")
        b.box((sx * 0.52, 0.0, 1.4), (0.1, 0.22, 0.22), "pouch", "Pelvis")
    # Tunic
    b.box((0, 0, 1.79), (0.9, 0.52, 0.5), "tunic", "Spine_0")
    b.box((0, 0, 2.26), (1.12, 0.64, 0.52), "tunic", "Spine_1")
    b.box((0, 0, 2.54), (0.58, 0.5, 0.06), "tunic_dark", "Spine_1")  # collar
    for sx in (1, -1):
        b.box((sx * 0.48, 0, 2.02), (0.06, 0.58, 0.5), "tunic_dark", "Spine_1")  # side seams
    # Lightning bolt emblem on the chest
    for (x, z, w, h) in ((0.06, 2.4, 0.14, 0.12), (0.0, 2.3, 0.24, 0.08), (-0.05, 2.2, 0.14, 0.12), (-0.09, 2.11, 0.08, 0.08)):
        b.box((x, -0.335, z), (w, 0.04, h), "bolt", "Spine_1")
    # Fur showing at the neck
    b.box((0, -0.02, 2.68), (0.44, 0.44, 0.36), "fur", "Neck")


def build_head(b):
    h = "Head_0"
    b.xform = HEAD_XFORM
    b.box((0, -0.05, 3.03), (0.72, 0.66, 0.64), "fur", h)
    b.box((0, -0.43, 2.88), (0.42, 0.2, 0.28), "fur_light", h)  # muzzle
    b.box((0, -0.38, 2.75), (0.3, 0.14, 0.08), "fur_light", h)  # chin
    b.box((0, -0.54, 2.98), (0.16, 0.06, 0.1), "nose", h)
    b.box((0, -0.535, 2.88), (0.04, 0.04, 0.1), "nose", h)
    b.box((0, -0.535, 2.82), (0.16, 0.04, 0.03), "nose", h)  # mouth
    for sx in (1, -1):
        b.box((sx * 0.17, -0.385, 3.09), (0.13, 0.03, 0.1), "eye_white", h)
        b.box((sx * 0.15, -0.4, 3.08), (0.06, 0.02, 0.08), "eye", h)
        brow = Matrix.Rotation(math.radians(-sx * 14), 3, "Y")
        b.box((sx * 0.17, -0.395, 3.18), (0.2, 0.04, 0.05), "brow", h, brow)  # frowning brows
        b.box((sx * 0.37, -0.12, 2.92), (0.06, 0.3, 0.2), "fur_shade", h)  # cheek fluff
        ear = f"Ear_{side_name(sx)}_0"
        b.box((sx * 0.3, -0.05, 3.46), (0.2, 0.1, 0.22), "fur", ear)
        b.box((sx * 0.3, -0.105, 3.45), (0.1, 0.02, 0.12), "fur_light", ear)
    build_mane(b, h)
    b.xform = None


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def build_mane(b, h):
    # Solid mane around the head
    b.box((0, 0.26, 3.0), (1.12, 0.36, 1.0), "mane", h)
    b.box((0, 0.02, 3.4), (0.92, 0.74, 0.18), "mane", h)
    b.box((0, -0.28, 2.7), (0.6, 0.3, 0.18), "mane", h)  # beard
    for sx in (1, -1):
        b.box((sx * 0.46, 0.02, 2.96), (0.24, 0.66, 0.86), "mane", h)
    # Spikes radiating out in the face's plane, two rings, skipping straight below the chin
    centre = Vector((0, 0.1, 3.02))
    for ring, (radius, y, width, length, step, offset) in enumerate(((0.5, 0.0, 0.26, 0.42, 24, 0), (0.56, 0.3, 0.32, 0.55, 24, 12))):
        for i, angle_deg in enumerate(range(offset, 360 + offset, step)):
            angle = math.radians(angle_deg)
            if 235 < (angle_deg % 360) < 305:
                continue
            out = Vector((math.cos(angle), 0, math.sin(angle)))
            base = centre + out * radius + Vector((0, y, 0))
            direction = out + Vector((0, 0.35 if ring else 0.1, 0.15))
            color = "mane" if (i + ring) % 2 == 0 else "mane_dark"
            b.spike(base, direction, width, length * (1.1 if math.sin(angle) > 0.3 else 1.0), color, h)
    # Spikes sweeping back off the top and back of the mane
    for x, z, color in ((0, 3.4, "mane"), (0.3, 3.3, "mane_dark"), (-0.3, 3.3, "mane_dark"), (0.2, 2.85, "mane"), (-0.2, 2.85, "mane")):
        b.spike((x, 0.42, z), (x * 0.6, 1.0, 0.25), 0.3, 0.45, color, h)
    # Beard spikes pointing down
    for x in (-0.18, 0.0, 0.18):
        b.spike((x, -0.3, 2.62), (x * 0.8, -0.3, -1.0), 0.16, 0.16, "mane_dark" if x == 0 else "mane", h)


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = f"Arm_{side}_0", f"Arm_{side}_1", f"Arm_{side}_2"
        # Shoulder armour: gold shell, black and white plates on top. On the chest bone, so it stays on the
        # shoulder when the arm hangs instead of turning out sideways with it
        armour = "Spine_1"
        b.box((sx * 0.72, 0, z + 0.12), (0.6, 0.76, 0.38), "gold", armour)
        b.box((sx * 0.76, 0, z + 0.34), (0.5, 0.66, 0.08), "black", armour)
        b.box((sx * 0.76, 0, z + 0.41), (0.36, 0.54, 0.06), "white", armour)
        b.box((sx * 1.03, 0, z + 0.1), (0.06, 0.78, 0.36), "gold_dark", armour)
        b.span((sx * SHOULDER_X, 0, z), (sx * ELBOW_X, 0, z), 0.46, "fur", upper, 0.04)
        b.span((sx * ELBOW_X, 0, z), (sx * WRIST_X, 0, z), 0.42, "fur", fore, 0.03)
        # Gold arm guard with a brown strap
        b.box((sx * 1.44, 0, z), (0.38, 0.54, 0.54), "gold", fore)
        b.box((sx * 1.62, 0, z), (0.05, 0.56, 0.56), "gold_dark", fore)
        b.box((sx * 1.26, 0, z), (0.08, 0.5, 0.5), "belt", fore)
        # Fist: knuckles forward, thumb on top
        b.box((sx * 1.86, 0, z), (0.4, 0.52, 0.52), "fur", hand)
        b.box((sx * 1.9, -0.24, z - 0.02), (0.32, 0.06, 0.42), "fur_light", hand)
        b.box((sx * 1.76, -0.14, z + 0.28), (0.18, 0.16, 0.06), "fur_shade", hand)


def build_tail(b):
    points = [Vector((0, 0.27, 1.3)), Vector((0, 0.58, 1.06)), Vector((0, 0.92, 0.9)), Vector((0, 1.22, 0.96)), Vector((0, 1.42, 1.2))]
    for i in range(4):
        b.span(points[i], points[i + 1], 0.13 - i * 0.01, "fur", f"Tail_{i}", 0.03)
    # Golden tuft at the tip
    tip = points[4]
    b.box(tip + Vector((0, 0.04, 0.08)), (0.26, 0.26, 0.26), "mane", "Tail_3")
    for direction, color in (((0, 0.4, 1), "mane"), ((0.7, 0.3, 0.6), "mane_dark"), ((-0.7, 0.3, 0.6), "mane_dark"), ((0, 1, 0.2), "mane"), ((0, 0.2, 1.4), "mane_dark")):
        b.spike(tip + Vector((0, 0.04, 0.1)), direction, 0.2, 0.3, color, "Tail_3")


def parts(b):
    build_legs(b)
    build_body(b)
    build_head(b)
    build_arms(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
