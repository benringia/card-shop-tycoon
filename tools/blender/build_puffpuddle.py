"""Builds the Puffpuddle creature (a sea otter on all fours: a long low body, short legs, big webbed hind feet, a
round pale face and a flat tail) in Blender. A Common card, so as cute as can be: big shiny eyes, blush, whiskers and
a smile. Less blocky than the early models: a rounded-box body and legs, a smooth head, muzzle, ears and paws.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), a long body (Pelvis,
Spine_0/1), Neck, Head_0, round ears (Ear_Left_0, Ear_Right_0) and a flat tail (Tail_0..2), so it trots and runs on its
four feet, and sits up on its hind legs to groom its face or crack a shell with its front paws (Party.CREATURE_STYLE,
Party.SIGNATURE).

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Puffpuddle/{Puffpuddle.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Puffpuddle"

COLORS = {
    "fur": (92, 62, 44),
    "fur_light": (122, 86, 62),
    "pale": (214, 200, 180),
    "muzzle": (234, 224, 208),
    "nose": (30, 24, 24),
    "eye": (20, 16, 16),
    "shine": (250, 250, 250),
    "blush": (236, 160, 160),
    "pad": (60, 42, 32),
}

HIPS = Vector((0, 0.44, 0.46))
WAIST = Vector((0, 0.08, 0.48))
CHEST = Vector((0, -0.26, 0.5))
CHEST_FRONT = Vector((0, -0.52, 0.55))
NECK_TOP = Vector((0, -0.68, 0.72))
HEAD_TIP = Vector((0, -1.06, 0.76))
FRONT_LEG = [(0.22, -0.44, 0.42), (0.24, -0.44, 0.25), (0.24, -0.47, 0.08), (0.24, -0.6, 0.03)]
HIND_LEG = [(0.24, 0.42, 0.42), (0.26, 0.4, 0.25), (0.26, 0.44, 0.08), (0.26, 0.28, 0.03)]
TAIL = [(0, 0.72, 0.46), (0, 1.0, 0.38), (0, 1.28, 0.32), (0, 1.52, 0.3)]


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
        ("Pelvis", "Root", tuple(HIPS), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(CHEST_FRONT)),
        ("Neck", "Spine_1", tuple(CHEST_FRONT), tuple(NECK_TOP)),
        ("Head_0", "Neck", tuple(NECK_TOP), tuple(HEAD_TIP)),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones.append((f"Ear_{side}_0", "Head_0", (sx * 0.2, -0.78, 0.94), (sx * 0.24, -0.78, 1.06)))
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    return bones


def limb(b, a, c, width, color, bone):
    """A rounded square-section limb from a to c."""
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.round_box((a + c) / 2, (width, width, along.length + width * 0.4), color, bone, rot, bevel=0.6)


def build_body(b):
    # A long, low body of rounded boxes (they overlap, so it stays smooth when it bends), a pale chest
    b.round_box((0, 0.4, 0.46), (0.5, 0.5, 0.42), "fur", "Pelvis", bevel=0.7)
    b.round_box((0, 0.06, 0.48), (0.54, 0.5, 0.44), "fur", "Spine_0", bevel=0.7)
    b.round_box((0, -0.3, 0.52), (0.52, 0.46, 0.44), "fur", "Spine_1", bevel=0.7)
    b.round_box((0, 0.06, 0.28), (0.4, 0.62, 0.06), "fur_light", "Spine_0", bevel=0.8)  # lighter tummy
    b.blob((0, -0.5, 0.5), (0.22, 0.12, 0.2), "pale", "Spine_1")  # pale chest
    b.blob((0, -0.62, 0.66), (0.21, 0.17, 0.19), "pale", "Neck")


def build_head(b):
    h = "Head_0"
    b.blob((0, -0.84, 0.78), (0.27, 0.24, 0.23), "pale", h)
    b.blob((0, -1.02, 0.72), (0.15, 0.11, 0.11), "muzzle", h)
    b.blob((0, -1.12, 0.77), (0.055, 0.035, 0.04), "nose", h)
    b.round_box((0, -1.115, 0.67), (0.08, 0.02, 0.022), "nose", h, bevel=0.8)  # little smile
    for sx in (1, -1):
        b.blob((sx * 0.12, -1.02, 0.86), (0.05, 0.035, 0.055), "eye", h)
        b.blob((sx * 0.105, -1.05, 0.88), (0.018, 0.012, 0.018), "shine", h, segments=6, rings=4)
        b.blob((sx * 0.18, -1.0, 0.72), (0.045, 0.02, 0.028), "blush", h, segments=6, rings=4)
        for dz in (-0.03, 0.0, 0.03):
            b.span((sx * 0.1, -1.08, 0.72 + dz), (sx * 0.33, -1.04, 0.74 + dz * 2), 0.012, "nose", h)  # whiskers
        ear = f"Ear_{side_name(sx)}_0"
        b.blob((sx * 0.21, -0.78, 0.98), (0.06, 0.04, 0.055), "fur_light", ear, segments=8, rings=5)


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            limb(b, p[0], p[1], 0.18, "fur", upper)
            limb(b, p[1], p[2], 0.15, "fur", lower)
            # Small front paws; big flat webbed hind feet
            if pair == 0:
                b.blob(p[2] + Vector((0, -0.05, -0.04)), (0.08, 0.1, 0.045), "pad", foot)
            else:
                b.blob(p[2] + Vector((0, -0.1, -0.04)), (0.1, 0.17, 0.04), "pad", foot)


def build_tail(b):
    # A flat tail, wide and thin, trailing behind
    for i in range(len(TAIL) - 1):
        a, c = Vector(TAIL[i]), Vector(TAIL[i + 1])
        along = c - a
        rot = along.to_track_quat("Y", "Z").to_matrix()
        width = (0.2, 0.18, 0.15)[i]
        b.round_box((a + c) / 2, (width, along.length + 0.08, 0.09), "fur" if i < 2 else "fur_light", f"Tail_{i}", rot, bevel=0.9)


def parts(b):
    build_body(b)
    build_head(b)
    build_legs(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
