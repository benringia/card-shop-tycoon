"""Builds the Sprouthop creature (a little tree sprite: twisted bark body, big blocky face, leafy cap with twig
antlers, card art assets/ui/card-art/Sprouthop.jpg) in Blender.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: Pelvis, Spine_0/1, Neck, Head_0 (the big head with its leaves), arms
(Arm_Left_0..2, twig fingers on the hand), legs (0_Left_Limb_0..2, root feet) and the two twig antlers as ears
(Ear_Left_0, Ear_Right_0), so it walks on two legs, swings its arms and its antlers wiggle. No tail: the game sways
its hips instead, like a sapling in the wind.

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Sprouthop/{Sprouthop.blend,.fbx,palette png}.
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Sprouthop"

COLORS = {
    "bark": (150, 96, 52),
    "bark_dark": (108, 66, 34),
    "bark_light": (188, 130, 74),
    "face": (198, 140, 84),
    "eye": (34, 24, 20),
    "shine": (250, 246, 236),
    "blush": (232, 132, 120),
    "leaf": (112, 180, 52),
    "leaf_light": (164, 212, 72),
    "leaf_dark": (70, 136, 40),
    "moss": (124, 162, 62),
    "cap": (206, 152, 102),
    "stem": (236, 222, 192),
    "twig": (122, 80, 44),
}
LEAVES = ("leaf", "leaf_light", "leaf_dark")

HIP, KNEE, ANKLE = 1.0, 0.56, 0.16
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, HAND_X = 1.84, 0.4, 0.8, 1.16, 1.44
NECK_Z, HEAD_Z = 1.96, 2.1


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", (0, 0, HIP), (0, 0, 1.25)),
        ("Spine_0", "Pelvis", (0, 0, 1.25), (0, 0, 1.6)),
        ("Spine_1", "Spine_0", (0, 0, 1.6), (0, 0, NECK_Z)),
        ("Neck", "Spine_1", (0, 0, NECK_Z), (0, 0, HEAD_Z)),
        ("Head_0", "Neck", (0, 0, HEAD_Z), (0, 0, 3.0)),
    ]
    for sx in (1, -1):
        side = side_name(sx)
        bones += [
            (f"Ear_{side}_0", "Head_0", (sx * 0.32, 0.05, 3.22), (sx * 0.5, 0.08, 3.7)),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, 0, SHOULDER_Z), (sx * ELBOW_X, 0, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, 0, SHOULDER_Z), (sx * WRIST_X, 0, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, 0, SHOULDER_Z), (sx * HAND_X, 0, SHOULDER_Z)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.24, 0, HIP), (sx * 0.24, 0, KNEE)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.24, 0, KNEE), (sx * 0.24, 0, ANKLE)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.24, 0, ANKLE), (sx * 0.24, -0.32, 0.05)),
        ]
    return bones


def strands(b, a, c, width, bone, count, twist, colors=("bark_light", "bark_dark")):
    """Raised bark strands running from a to c around a limb, turning `twist` radians along it."""
    a, c = Vector(a), Vector(c)
    along = (c - a).normalized()
    side = along.cross(Vector((0, 1, 0)))
    if side.length < 0.1:
        side = along.cross(Vector((1, 0, 0)))
    side.normalize()
    up = along.cross(side).normalized()
    for i in range(count):
        angle = i / count * math.tau
        start = a + (side * math.cos(angle) + up * math.sin(angle)) * width * 0.5
        end = c + (side * math.cos(angle + twist) + up * math.sin(angle + twist)) * width * 0.5
        b.span(start, end, width * 0.22, colors[i % len(colors)], bone)


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        thigh, shin, foot = (f"0_{side}_Limb_{i}" for i in range(3))
        x = sx * 0.24
        b.span((x, 0, HIP + 0.04), (x, 0, KNEE), 0.32, "bark", thigh, 0.04)
        strands(b, (x, 0, HIP), (x, 0, KNEE), 0.32, thigh, 4, 0.8 * sx)
        b.span((x, 0, KNEE), (x, 0, ANKLE), 0.3, "bark_dark", shin, 0.04)
        strands(b, (x, 0, KNEE), (x, 0, ANKLE), 0.3, shin, 4, -0.8 * sx)
        # Root feet: a wide base with root toes spreading forward and to the sides
        b.box((x, -0.08, 0.08), (0.38, 0.48, 0.16), "bark", foot)
        for dx, dy, color in ((0.0, -1, "bark_dark"), (0.6, -0.8, "bark"), (-0.6, -0.8, "bark"), (sx * 1, 0.2, "bark_dark")):
            b.spike((x, -0.2, 0.06), (dx, dy, -0.25), 0.12, 0.26, color, foot)
    # Little mushrooms growing on the left shin and right thigh
    for base, out, bone, size in (((0.42, -0.02, 0.4), (1, -0.2, 0.4), "0_Left_Limb_1", 1.0),
                                  ((0.4, 0.06, 0.32), (1, 0.3, 0.2), "0_Left_Limb_1", 0.7),
                                  ((-0.4, -0.04, 0.82), (-1, -0.2, 0.3), "0_Right_Limb_0", 0.8)):
        base, out = Vector(base), Vector(out).normalized()
        b.span(base - out * 0.04, base + out * 0.08 * size, 0.05 * size, "stem", bone)
        b.box(base + out * 0.1 * size + Vector((0, 0, 0.03)), (0.16 * size, 0.16 * size, 0.06 * size), "cap", bone)


def build_body(b):
    b.box((0, 0, 1.12), (0.64, 0.44, 0.32), "bark", "Pelvis")
    # A twisted trunk: slabs turned alternately, with strands winding round
    for z, w, d, h, turn, bone in ((1.42, 0.58, 0.42, 0.36, 8, "Spine_0"), (1.78, 0.68, 0.46, 0.38, -8, "Spine_1")):
        b.box((0, 0, z), (w, d, h), "bark", bone, Matrix.Rotation(math.radians(turn), 3, "Z"))
    strands(b, (0, 0, 1.2), (0, 0, 1.62), 0.56, "Spine_0", 6, 1.0)
    strands(b, (0, 0, 1.58), (0, 0, 1.98), 0.66, "Spine_1", 6, -1.0)
    b.box((0, 0, 2.02), (0.3, 0.3, 0.16), "bark_dark", "Neck")
    # Moss and a leafy shoot on the shoulders
    b.box((0.18, -0.24, 1.66), (0.14, 0.04, 0.1), "moss", "Spine_1")
    b.box((-0.12, -0.23, 1.34), (0.1, 0.04, 0.08), "moss", "Spine_0")
    b.span((0.34, 0, 1.98), (0.4, -0.02, 2.14), 0.04, "twig", "Spine_1")
    b.box((0.42, -0.02, 2.17), (0.1, 0.04, 0.07), "leaf_light", "Spine_1", Matrix.Rotation(math.radians(30), 3, "Y"))


def build_head(b):
    h = "Head_0"
    centre_z = 2.54
    b.box((0, 0, centre_z), (0.92, 0.8, 0.86), "bark", h)
    b.box((0, -0.405, centre_z - 0.04), (0.8, 0.02, 0.7), "face", h)
    # Bark lines down the sides, back and chin
    for x in (-0.36, -0.12, 0.14, 0.34):
        b.box((x, 0.41, centre_z), (0.06, 0.02, 0.8), "bark_dark", h)
    for sx in (1, -1):
        for y in (-0.22, 0.12):
            b.box((sx * 0.465, y, centre_z), (0.02, 0.06, 0.8), "bark_dark", h)
        b.box((sx * 0.26, -0.42, 2.2), (0.05, 0.02, 0.14), "bark_dark", h)
    b.box((0, -0.42, 2.18), (0.05, 0.02, 0.1), "bark_dark", h)
    b.box((0, -0.43, 2.86), (0.82, 0.06, 0.08), "bark_light", h)  # brow ridge under the leaves
    # Big glossy eyes, blush and a little smile
    for sx in (1, -1):
        b.box((sx * 0.19, -0.42, 2.6), (0.26, 0.03, 0.28), "eye", h)
        b.box((sx * 0.14, -0.435, 2.67), (0.08, 0.02, 0.08), "shine", h)
        b.box((sx * 0.23, -0.435, 2.54), (0.04, 0.02, 0.04), "shine", h)
        b.box((sx * 0.34, -0.42, 2.42), (0.12, 0.02, 0.06), "blush", h)
    b.box((0, -0.42, 2.38), (0.14, 0.02, 0.035), "eye", h)
    for sx in (1, -1):
        b.box((sx * 0.09, -0.42, 2.405), (0.05, 0.02, 0.035), "eye", h)
    build_canopy(b, h)
    build_antlers(b)


def build_canopy(b, h):
    """The leafy cap: a solid crown, then many small leaf cubes over its top and hanging over the edges."""
    rng = random.Random(7)
    b.box((0, 0.02, 3.04), (1.16, 1.04, 0.34), "leaf", h)
    b.box((0, 0.02, 3.26), (0.94, 0.84, 0.16), "leaf_dark", h)
    for _ in range(110):
        angle = rng.uniform(0, math.tau)
        radius = rng.uniform(0.1, 0.66)
        x, y = math.cos(angle) * radius, math.sin(angle) * radius * 0.88 + 0.02
        edge = radius > 0.52
        z = rng.uniform(2.78, 3.0) if edge else rng.uniform(3.22, 3.42) - radius * 0.25
        s = rng.uniform(0.12, 0.2)
        b.box((x, y, z), (s, s, s * 0.7), rng.choice(LEAVES), h, Matrix.Rotation(rng.uniform(-0.5, 0.5), 3, "Z"))
    # Leaves drooping over the brow
    for x in (-0.3, -0.1, 0.12, 0.32):
        b.box((x, -0.46, 2.92), (0.16, 0.08, 0.12), rng.choice(LEAVES), h)


def build_antlers(b):
    """Two twig antlers on their own bones, each with a side branch and a couple of leaves."""
    for sx in (1, -1):
        ear = f"Ear_{side_name(sx)}_0"
        base, tip = Vector((sx * 0.32, 0.05, 3.22)), Vector((sx * 0.5, 0.08, 3.7))
        b.span(base, tip, 0.07, "twig", ear, 0.02)
        fork = base.lerp(tip, 0.55)
        b.span(fork, fork + Vector((sx * 0.16, 0.02, 0.1)), 0.05, "twig", ear)
        b.span(base.lerp(tip, 0.3), base.lerp(tip, 0.3) + Vector((-sx * 0.1, 0.0, 0.12)), 0.045, "twig", ear)
        b.box(tip + Vector((sx * 0.03, 0, 0.03)), (0.1, 0.04, 0.08), "leaf_light", ear, Matrix.Rotation(math.radians(sx * -30), 3, "Y"))
        b.box(fork + Vector((sx * 0.19, 0.02, 0.13)), (0.08, 0.04, 0.07), "leaf", ear)


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = (f"Arm_{side}_{i}" for i in range(3))
        b.span((sx * (SHOULDER_X - 0.06), 0, z), (sx * ELBOW_X, 0, z), 0.22, "bark", upper, 0.03)
        strands(b, (sx * SHOULDER_X, 0, z), (sx * ELBOW_X, 0, z), 0.22, upper, 3, 0.9)
        b.span((sx * ELBOW_X, 0, z), (sx * WRIST_X, 0, z), 0.2, "bark_dark", fore, 0.03)
        strands(b, (sx * ELBOW_X, 0, z), (sx * WRIST_X, 0, z), 0.2, fore, 3, -0.9)
        b.box((sx * 0.98, -0.11, z + 0.06), (0.08, 0.03, 0.06), "moss", fore)
        # Hand: a knotty palm with three twig fingers and a thumb
        b.box((sx * 1.24, 0, z), (0.18, 0.24, 0.24), "bark", hand)
        for dy in (-0.08, 0, 0.08):
            b.span((sx * 1.3, dy, z - 0.02), (sx * HAND_X, dy * 1.3, z - 0.06), 0.06, "bark_light", hand)
        b.span((sx * 1.22, -0.12, z), (sx * 1.3, -0.24, z + 0.04), 0.06, "bark_light", hand)
    # The right hand holds a little sprout with two leaves
    stem_base = Vector((-1.3, -0.16, SHOULDER_Z + 0.02))
    stem_tip = stem_base + Vector((0, -0.04, 0.22))
    b.span(stem_base, stem_tip, 0.035, "leaf_dark", "Arm_Right_2")
    for sx in (1, -1):
        b.box(stem_tip + Vector((sx * 0.06, 0, 0.02)), (0.1, 0.03, 0.06), "leaf_light", "Arm_Right_2",
              Matrix.Rotation(math.radians(sx * 25), 3, "Y"))


def parts(b):
    build_legs(b)
    build_body(b)
    build_head(b)
    build_arms(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
