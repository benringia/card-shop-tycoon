"""Builds the Infernox creature (a blocky red T-rex with black tiger stripes, cream belly and jaw, a flame crest on
its head, card art assets/ui/card-art/Infernox.jpg) in Blender.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: two big legs (0_Left_Limb_0..2), Pelvis, Spine_0/1 leaning forward, Neck, a big
Head_0 with its lower jaw on Jaw_0 (for its fire breath), tiny arms (Arm_Left_0..2, held up in front by
Party.ARM_POSE), a four-bone tail (Tail_0..3) and two flame-crest bones on the ear roles (Ear_Left_0, Ear_Right_0),
so it walks on two legs with its tail swinging behind and its crest flames flicker.

Blender: Z up, the creature faces -Y, its left is +X. Arms in a T-pose (PetAnimator lowers them).
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Infernox/{Infernox.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Infernox"

COLORS = {
    "red": (212, 72, 50),
    "red_dark": (168, 48, 38),
    "cream": (246, 232, 200),
    "stripe": (32, 26, 26),
    "flame": (255, 150, 30),
    "flame_light": (255, 222, 80),
    "flame_red": (240, 88, 30),
    "eye": (255, 200, 60),
    "pupil": (30, 20, 15),
    "mouth": (150, 40, 50),
    "teeth": (246, 242, 232),
    "claw": (52, 40, 40),
}

HIP = Vector((0, 0.3, 1.5))
WAIST = Vector((0, -0.05, 1.7))
CHEST = Vector((0, -0.38, 1.94))
NECK_BASE = Vector((0, -0.58, 2.2))
NECK_TOP = Vector((0, -0.74, 2.56))
HEAD_TIP = Vector((0, -1.62, 2.62))
JAW_HINGE = Vector((0, -0.92, 2.42))
LEG = [(0.38, 0.32, 1.42), (0.42, 0.02, 0.86), (0.42, 0.4, 0.3), (0.42, 0.02, 0.06)]
SHOULDER_Z, SHOULDER_X, ELBOW_X, WRIST_X, HAND_X = 1.98, 0.42, 0.68, 0.92, 1.08
ARM_Y = -0.62
TAIL = [(0, 0.66, 1.52), (0, 1.16, 1.4), (0, 1.66, 1.2), (0, 2.12, 1.0), (0, 2.5, 0.84)]
# The head (with its jaw and crest) is drawn big, like the card art: built at size 1, scaled up about the top of the neck
HEAD_SCALE = 1.35
HEAD_XFORM = Matrix.Translation(NECK_TOP) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-NECK_TOP)


def head_point(p):
    return tuple(HEAD_XFORM @ Vector(p))


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", tuple(HIP), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(NECK_BASE)),
        ("Neck", "Spine_1", tuple(NECK_BASE), tuple(NECK_TOP)),
        ("Head_0", "Neck", tuple(NECK_TOP), head_point(HEAD_TIP)),
        ("Jaw_0", "Head_0", head_point(JAW_HINGE), head_point((0, -1.56, 2.34))),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones += [
            (f"Ear_{side}_0", "Head_0", head_point((sx * 0.14, -0.86, 2.96)), head_point((sx * 0.2, -0.82, 3.34))),
            (f"Arm_{side}_0", "Spine_1", (sx * SHOULDER_X, ARM_Y, SHOULDER_Z), (sx * ELBOW_X, ARM_Y, SHOULDER_Z)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * ELBOW_X, ARM_Y, SHOULDER_Z), (sx * WRIST_X, ARM_Y, SHOULDER_Z)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * WRIST_X, ARM_Y, SHOULDER_Z), (sx * HAND_X, ARM_Y, SHOULDER_Z)),
        ]
        for i in range(3):
            parent = "Pelvis" if i == 0 else f"0_{side}_Limb_{i - 1}"
            bones.append((f"0_{side}_Limb_{i}", parent, mirror(LEG[i], sx), mirror(LEG[i + 1], sx)))
    return bones


def stripes_across(b, centre, size, bone, count, axis="y"):
    """Black tiger stripes wrapped over the top and down the sides of a box."""
    c = Vector(centre)
    for i in range(count):
        t = (i + 0.5) / count - 0.5
        offset = Vector((0, t * size[1] * 0.8, 0)) if axis == "y" else Vector((0, 0, t * size[2] * 0.8))
        b.box(c + offset + Vector((0, 0, size[2] / 2 + 0.01)), (size[0] * 0.5, 0.06, 0.03), "stripe", bone)
        for sx in (1, -1):
            b.box(c + offset + Vector((sx * (size[0] / 2 + 0.01), 0, size[2] * 0.15)), (0.03, 0.06, size[2] * 0.45), "stripe", bone)


def build_body(b):
    b.box((0, 0.3, 1.52), (0.86, 0.8, 0.72), "red", "Pelvis")
    stripes_across(b, (0, 0.3, 1.52), (0.86, 0.8, 0.72), "Pelvis", 3)
    b.box((0, -0.18, 1.8), (0.92, 0.72, 0.8), "red", "Spine_0")
    b.box((0, -0.55, 1.72), (0.6, 0.06, 0.66), "cream", "Spine_0")  # belly
    stripes_across(b, (0, -0.18, 1.8), (0.92, 0.72, 0.8), "Spine_0", 3)
    b.box((0, -0.46, 2.1), (0.74, 0.56, 0.52), "red", "Spine_1")
    b.box((0, -0.75, 2.06), (0.5, 0.04, 0.44), "cream", "Spine_1")
    b.box((0, -0.66, 2.4), (0.52, 0.44, 0.5), "red", "Neck")
    b.box((0, -0.89, 2.36), (0.36, 0.04, 0.4), "cream", "Neck")


def build_head(b):
    h, jaw = "Head_0", "Jaw_0"
    b.xform = HEAD_XFORM
    b.box((0, -1.02, 2.74), (0.72, 0.7, 0.52), "red", h)  # skull
    b.box((0, -1.46, 2.68), (0.6, 0.4, 0.34), "red", h)  # snout
    b.box((0, -1.6, 2.86), (0.4, 0.14, 0.06), "red_dark", h)  # nostril ridge
    for sx in (1, -1):
        b.box((sx * 0.1, -1.67, 2.8), (0.06, 0.02, 0.05), "pupil", h)  # nostrils
        b.box((sx * 0.3, -1.14, 2.88), (0.12, 0.12, 0.1), "eye", h)
        b.box((sx * 0.33, -1.17, 2.88), (0.06, 0.08, 0.08), "pupil", h)
        b.box((sx * 0.28, -1.14, 2.97), (0.18, 0.16, 0.05), "red_dark", h)  # angry brow
        for y in (-1.26, -1.4, -1.54):
            b.spike((sx * 0.24, y, 2.5), (0, 0, -1), 0.07, 0.12, "teeth", h)
        for y in (-0.98, -1.12):
            b.box((sx * 0.37, y, 2.74), (0.02, 0.06, 0.3), "stripe", h)  # head stripes
    b.box((0, -1.32, 2.52), (0.44, 0.6, 0.04), "mouth", h)  # roof of the mouth
    # Big cream lower jaw on its own bone
    b.box((0, -1.24, 2.36), (0.62, 0.72, 0.2), "cream", jaw)
    b.box((0, -1.24, 2.465), (0.46, 0.62, 0.02), "mouth", jaw)
    for sx in (1, -1):
        for y in (-1.3, -1.46):
            b.spike((sx * 0.22, y, 2.47), (0, 0, 1), 0.06, 0.1, "teeth", jaw)
    # Flame crest: a centre flame on the head, a flickering flame on each crest bone
    b.box((0, -0.92, 3.04), (0.24, 0.3, 0.12), "flame_red", h)
    b.spike((0, -0.92, 3.08), (0, 0.15, 1), 0.26, 0.56, "flame", h)
    for sx in (1, -1):
        ear = f"Ear_{side_name(sx)}_0"
        base = Vector((sx * 0.14, -0.86, 2.96))
        b.spike(base, (sx * 0.25, 0.1, 1), 0.24, 0.62, "flame", ear)
        b.spike(base + Vector((0, -0.02, 0.06)), (sx * 0.15, 0.05, 1), 0.12, 0.34, "flame_light", ear)
        b.spike(base + Vector((sx * 0.08, 0.06, 0)), (sx * 0.6, 0.2, 0.8), 0.12, 0.26, "flame_red", ear)
    b.xform = None


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        thigh, shin, foot = (f"0_{side}_Limb_{i}" for i in range(3))
        p = [Vector(mirror(q, sx)) for q in LEG]
        b.span(p[0], p[1], 0.5, "red", thigh, 0.1)
        b.span(p[1], p[2], 0.32, "red_dark", shin, 0.05)
        b.box(p[0].lerp(p[1], 0.5) + Vector((sx * 0.26, 0, 0)), (0.03, 0.08, 0.3), "stripe", thigh)
        b.box(p[2] + Vector((0, -0.14, -0.18)), (0.4, 0.5, 0.16), "red", foot)
        for toe in (-0.12, 0, 0.12):
            b.spike(p[2] + Vector((toe, -0.38, -0.2)), (toe, -1, -0.3), 0.1, 0.18, "claw", foot)


def build_arms(b):
    z = SHOULDER_Z
    for sx in (1, -1):
        side = side_name(sx)
        upper, fore, hand = (f"Arm_{side}_{i}" for i in range(3))
        b.span((sx * (SHOULDER_X - 0.04), ARM_Y, z), (sx * ELBOW_X, ARM_Y, z), 0.18, "red", upper, 0.03)
        b.span((sx * ELBOW_X, ARM_Y, z), (sx * WRIST_X, ARM_Y, z), 0.15, "red_dark", fore, 0.02)
        b.box((sx * 1.0, ARM_Y, z), (0.14, 0.18, 0.16), "red", hand)
        for dy in (-0.05, 0.05):
            b.spike((sx * 1.06, ARM_Y + dy, z), (sx * 0.6, -0.6, -0.5), 0.05, 0.14, "claw", hand)


def build_tail(b):
    widths = (0.5, 0.4, 0.3, 0.2)
    for i in range(len(TAIL) - 1):
        bone = f"Tail_{i}"
        b.span(TAIL[i], TAIL[i + 1], widths[i], "red", bone, 0.05)
        mid = Vector(TAIL[i]).lerp(Vector(TAIL[i + 1]), 0.5)
        b.box(mid + Vector((0, 0, widths[i] / 2 + 0.01)), (widths[i] * 0.6, 0.07, 0.03), "stripe", bone)
        for sx in (1, -1):
            b.box(mid + Vector((sx * (widths[i] / 2 + 0.01), 0, widths[i] * 0.1)), (0.03, 0.07, widths[i] * 0.5), "stripe", bone)


def parts(b):
    build_body(b)
    build_head(b)
    build_legs(b)
    build_arms(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
