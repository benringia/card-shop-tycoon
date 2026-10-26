"""Builds the Eclipse Fox creature (a nine-tailed shadow kitsune on four legs: deep violet fur, a white chest, muzzle
and tail tips, glowing violet crescent markings, a violet gem on its brow, sharp golden eyes and nine big fluffy
tails fanned out behind it) in Blender. An Epic card, so fierce and mystic: narrow golden eyes, sharp ears, but no
fangs on show. Sturdy, not skinny: a deep chest, thick legs, big paws, a huge neck ruff. Blocky voxel style
(boxes, spikes and cubes).

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), a body (Pelvis,
Spine_0/1), Neck, Head_0, tall ears (Ear_Left_0, Ear_Right_0) and nine tails (Tails_<tail>_0..2, each sways on its
own beat and fans out), so it trots and lopes on four feet, and sits up to summon an eclipse (Party.SIGNATURE).

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
The card is called "Eclipse Fox"; the model and files are EclipseFox.
Writes assets/blender/EclipseFox/{EclipseFox.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "EclipseFox"

COLORS = {
    "fur": (86, 54, 140),
    "fur_dark": (54, 32, 92),
    "fur_light": (122, 88, 180),
    "white": (236, 230, 246),
    "glow": (196, 120, 255),
    "gem": (230, 120, 255),
    "eye": (255, 214, 70),
    "pupil": (30, 14, 30),
    "nose": (26, 18, 30),
    "paw": (40, 24, 66),
}

HIPS = Vector((0, 0.5, 0.86))
WAIST = Vector((0, 0.1, 0.9))
CHEST = Vector((0, -0.3, 0.96))
CHEST_FRONT = Vector((0, -0.6, 1.04))
NECK_TOP = Vector((0, -0.8, 1.34))
HEAD_TIP = Vector((0, -1.42, 1.34))
FRONT_LEG = [(0.3, -0.5, 0.82), (0.32, -0.5, 0.46), (0.32, -0.54, 0.14), (0.32, -0.72, 0.04)]
HIND_LEG = [(0.32, 0.5, 0.84), (0.34, 0.34, 0.48), (0.34, 0.56, 0.16), (0.34, 0.4, 0.04)]
TAIL_COUNT = 9
TAIL_BONES = 3


def tail_points(index):
    """Nine tails fanned out behind, the middle ones highest, the outer ones low and wide, all curling up."""
    spread = (index - (TAIL_COUNT - 1) / 2) / ((TAIL_COUNT - 1) / 2)  # -1 .. 1
    a = spread * math.radians(70)
    base = Vector((math.sin(a) * 0.22, 0.78 + abs(spread) * 0.05, 0.9 + (1 - abs(spread)) * 0.08))
    tip = Vector((math.sin(a) * 1.5, 1.35 + math.cos(a) * 0.45, 1.5 + (1 - abs(spread)) * 0.95 - abs(spread) * 0.15))
    control = Vector((math.sin(a) * 0.9, 1.3, 0.9 + (1 - abs(spread)) * 0.4))
    points = []
    for i in range(TAIL_BONES + 1):
        t = i / TAIL_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + tip * t * t)
    return points


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
    for tail in range(TAIL_COUNT):
        points = tail_points(tail)
        for i in range(TAIL_BONES):
            parent = "Pelvis" if i == 0 else f"Tails_{tail}_{i - 1}"
            bones.append((f"Tails_{tail}_{i}", parent, tuple(points[i]), tuple(points[i + 1])))
    for sx in (1, -1):
        side = side_name(sx)
        bones.append((f"Ear_{side}_0", "Head_0", (sx * 0.18, -0.9, 1.58), (sx * 0.26, -0.88, 1.92)))
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    return bones


def limb(b, a, c, width, color, bone):
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.box((a + c) / 2, (width, width, along.length + width * 0.4), color, bone, rot)


def build_body(b):
    # A sturdy body: broad hips, a deep chest, a huge white ruff round the neck
    b.box((0, 0.46, 0.88), (0.64, 0.56, 0.54), "fur", "Pelvis")
    b.box((0, 0.08, 0.9), (0.62, 0.5, 0.52), "fur", "Spine_0")
    b.box((0, -0.34, 0.98), (0.7, 0.52, 0.62), "fur", "Spine_1")
    b.cube((0, -0.56, 0.92), (0.28, 0.14, 0.32), "white", "Spine_1")  # white chest
    b.box((0, -0.74, 1.18), (0.42, 0.36, 0.44), "fur", "Neck")
    b.cube((0, -0.78, 1.18), (0.4, 0.26, 0.34), "white", "Neck")  # big ruff
    for sx in (1, -1):
        b.cube((sx * 0.3, -0.72, 1.3), (0.14, 0.14, 0.18), "white", "Neck")  # ruff tufts
        # A crescent of glowing marks on each flank
        for i in range(10):
            t = i / 9
            y = 0.4 - 0.46 * t
            z = 0.88 + 0.2 * (1 - (2 * t - 1) ** 2)
            b.box((sx * 0.315, y, z), (0.03, 0.08, 0.06), "glow", "Spine_0" if y < 0.24 else "Pelvis")


def build_head(b):
    h = "Head_0"
    b.cube((0, -1.0, 1.4), (0.3, 0.3, 0.27), "fur", h)
    b.cube((0, -1.28, 1.3), (0.14, 0.2, 0.11), "fur", h)  # snout
    b.cube((0, -1.3, 1.25), (0.13, 0.18, 0.08), "white", h)  # white under the snout
    b.cube((0, -1.47, 1.33), (0.05, 0.035, 0.04), "nose", h, segments=8, rings=5)
    b.cube((0, -1.2, 1.52), (0.05, 0.035, 0.045), "gem", h, segments=6, rings=4)  # brow gem
    for sx in (1, -1):
        b.cube((sx * 0.13, -1.22, 1.44), (0.075, 0.025, 0.032), "eye", h, segments=8, rings=5)
        b.cube((sx * 0.13, -1.238, 1.44), (0.02, 0.012, 0.028), "pupil", h, segments=6, rings=4)
        b.box((sx * 0.13, -1.22, 1.49), (0.16, 0.035, 0.03), "fur_dark", h)  # low brow
        b.cube((sx * 0.24, -1.12, 1.28), (0.09, 0.1, 0.07), "white", h)  # cheek tufts
        ear = f"Ear_{side_name(sx)}_0"
        b.box((sx * 0.2, -0.9, 1.64), (0.18, 0.08, 0.2), "fur", ear)
        b.spike((sx * 0.2, -0.9, 1.72), (sx * 0.25, 0.05, 1), 0.17, 0.24, "fur_dark", ear)


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            limb(b, p[0], p[1], 0.26, "fur", upper)
            limb(b, p[1], p[2], 0.19, "fur_dark", lower)
            b.cube(p[2] + Vector((0, -0.08, -0.06)), (0.12, 0.16, 0.07), "paw", foot)


def build_tails(b):
    radii = (0.13, 0.17, 0.16)
    for tail in range(TAIL_COUNT):
        points = tail_points(tail)
        for i in range(TAIL_BONES):
            a, c = points[i], points[i + 1]
            along = c - a
            rot = along.to_track_quat("Z", "Y").to_matrix()
            color = "white" if i == TAIL_BONES - 1 else "fur"
            b.cube((a + c) / 2, (radii[i], radii[i], along.length / 2 + radii[i] * 0.9), color, f"Tails_{tail}_{i}", rot, segments=8, rings=6)
        if tail % 2 == 0:
            mid = points[1].lerp(points[2], 0.5)
            b.box(mid + Vector((0, 0.1, 0.1)), (0.05, 0.04, 0.16), "glow", f"Tails_{tail}_1")


def parts(b):
    build_body(b)
    build_head(b)
    build_legs(b)
    build_tails(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
