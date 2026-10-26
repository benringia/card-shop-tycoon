"""Builds the Boltlynx creature (a blocky golden lion with a huge spiky mane and lightning-bolt markings) in Blender.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), its body level
(Pelvis at the hips, Spine_0/1 forward to the chest), Neck, Head_0 (the head and mane), Jaw_0 (the lower jaw, for
its thunder roar), the ears (Ear_Left_0, Ear_Right_0) and a four-bone tail with a spiky tuft (Tail_0..3), so it
trots, wags, flicks its ears and roars with its mouth wide open.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Boltlynx/{Boltlynx.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Boltlynx"

COLORS = {
    "fur": (226, 170, 70),
    "fur_dark": (190, 130, 50),
    "cream": (250, 232, 190),
    "mane": (232, 160, 40),
    "mane_dark": (196, 110, 28),
    "mane_tip": (255, 226, 90),
    "bolt": (255, 252, 214),
    "nose": (70, 40, 35),
    "eye": (255, 196, 60),
    "pupil": (30, 20, 15),
    "mouth": (150, 50, 50),
    "teeth": (245, 240, 230),
    "claw": (60, 45, 35),
}
MANES = ("mane", "mane_dark", "mane_tip")

# Body: level, hips at the back (+Y), chest at the front (-Y)
HIPS = Vector((0, 0.6, 1.1))
WAIST = Vector((0, 0.1, 1.14))
CHEST = Vector((0, -0.38, 1.2))
CHEST_FRONT = Vector((0, -0.72, 1.28))
NECK_TOP = Vector((0, -0.95, 1.62))
HEAD_TIP = Vector((0, -1.58, 1.6))
JAW_HINGE = Vector((0, -1.08, 1.48))
# Legs (one side, +X): shoulder/hip, elbow/knee, wrist/hock, toes
FRONT_LEG = [(0.32, -0.55, 1.05), (0.34, -0.48, 0.6), (0.34, -0.56, 0.18), (0.34, -0.8, 0.05)]
HIND_LEG = [(0.32, 0.55, 1.05), (0.36, 0.34, 0.62), (0.36, 0.6, 0.24), (0.36, 0.36, 0.05)]
TAIL = [(0, 0.88, 1.16), (0, 1.26, 1.0), (0, 1.62, 0.86), (0, 1.92, 0.92), (0, 2.12, 1.16)]
MANE_CENTRE = Vector((0, -0.98, 1.74))


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", tuple(HIPS), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(CHEST_FRONT)),
        ("Neck", "Spine_1", tuple(CHEST_FRONT), tuple(NECK_TOP)),
        ("Head_0", "Neck", tuple(NECK_TOP), tuple(HEAD_TIP)),
        ("Jaw_0", "Head_0", tuple(JAW_HINGE), (0, -1.52, 1.42)),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        bones.append((f"Ear_{side}_0", "Head_0", (sx * 0.24, -1.0, 1.94), (sx * 0.28, -1.0, 2.18)))
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    return bones


def build_body(b):
    for bone, centre, size in (("Pelvis", (0, 0.55, 1.1), (0.72, 0.72, 0.6)),
                               ("Spine_0", (0, 0.06, 1.13), (0.68, 0.56, 0.58)),
                               ("Spine_1", (0, -0.5, 1.2), (0.82, 0.62, 0.72))):
        c = Vector(centre)
        b.box(c, size, "fur", bone)
        b.box(c + Vector((0, 0, -size[2] / 2 - 0.02)), (size[0] * 0.62, size[1] * 0.9, 0.04), "cream", bone)
        b.box(c + Vector((0, 0, size[2] / 2 + 0.01)), (size[0] * 0.3, size[1] * 0.95, 0.03), "fur_dark", bone)
    # Lightning-bolt markings down each flank
    for sx in (1, -1):
        x = sx * 0.415
        for y, z, h in ((-0.66, 1.42, 0.2), (-0.54, 1.28, 0.12), (-0.44, 1.15, 0.2), (-0.34, 1.0, 0.12)):
            b.box((x, y, z), (0.03, 0.16, h), "bolt", "Spine_1")
        x = sx * 0.355
        for y, z, h in ((-0.04, 1.32, 0.18), (0.08, 1.2, 0.12), (0.18, 1.08, 0.18)):
            b.box((x, y, z), (0.03, 0.16, h), "bolt", "Spine_0")
    b.box((0, -0.86, 1.42), (0.5, 0.36, 0.5), "fur", "Neck")


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        for pair, leg, widths in ((0, FRONT_LEG, (0.32, 0.26, 0.3)), (1, HIND_LEG, (0.38, 0.28, 0.3))):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], widths[0], "fur", upper, 0.08)
            b.span(p[1], p[2], widths[1], "fur_dark" if pair else "fur", lower, 0.05)
            # A big paw with toe pads and little claws
            paw = p[2] + Vector((0, -0.1, -0.1))
            b.box(paw, (widths[2] + 0.06, 0.38, 0.16), "fur", foot)
            b.box(paw + Vector((0, -0.19, -0.03)), (widths[2], 0.04, 0.08), "cream", foot)
            for toe in (-0.09, 0, 0.09):
                b.spike(paw + Vector((toe, -0.2, -0.05)), (0, -1, -0.3), 0.05, 0.08, "claw", foot)


def build_head(b):
    h, jaw = "Head_0", "Jaw_0"
    b.box((0, -1.12, 1.72), (0.62, 0.56, 0.52), "fur", h)
    b.box((0, -1.46, 1.6), (0.38, 0.32, 0.24), "cream", h)  # muzzle
    b.box((0, -1.47, 1.73), (0.24, 0.3, 0.06), "fur_dark", h)  # bridge of the nose
    b.box((0, -1.63, 1.68), (0.18, 0.04, 0.1), "nose", h)
    b.box((0, -1.4, 1.5), (0.3, 0.3, 0.04), "mouth", h)  # roof of the mouth
    for sx in (1, -1):
        b.box((sx * 0.17, -1.405, 1.82), (0.14, 0.03, 0.09), "eye", h)
        b.box((sx * 0.15, -1.42, 1.82), (0.05, 0.02, 0.08), "pupil", h)
        b.box((sx * 0.17, -1.405, 1.9), (0.18, 0.04, 0.05), "fur_dark", h)  # brow
        b.spike((sx * 0.1, -1.56, 1.5), (0, -0.1, -1), 0.05, 0.1, "teeth", h)  # fangs
        b.box((sx * 0.21, -1.58, 1.58), (0.03, 0.03, 0.03), "nose", h)  # whisker dots
        b.box((sx * 0.2, -1.6, 1.62), (0.03, 0.03, 0.03), "nose", h)
    # Lower jaw, hinged at the back of the mouth
    b.box((0, -1.36, 1.42), (0.3, 0.36, 0.1), "cream", jaw)
    b.box((0, -1.36, 1.475), (0.24, 0.3, 0.02), "mouth", jaw)
    for sx in (1, -1):
        b.spike((sx * 0.09, -1.5, 1.48), (0, -0.1, 1), 0.045, 0.08, "teeth", jaw)
    build_mane(b, h)
    build_ears(b)


def build_mane(b, h):
    """A huge spiky mane: a solid ruff round the face and two rings of spikes radiating out, tipped in yellow."""
    c = MANE_CENTRE
    b.box(c + Vector((0, 0.22, 0)), (1.0, 0.36, 0.95), "mane", h)
    b.box(c + Vector((0, 0.06, 0.38)), (0.8, 0.5, 0.2), "mane", h)
    b.box(c + Vector((0, -0.02, -0.42)), (0.6, 0.42, 0.2), "mane_dark", h)  # under the chin
    for sx in (1, -1):
        b.box(c + Vector((sx * 0.42, 0.04, -0.02)), (0.2, 0.5, 0.8), "mane", h)
    for ring, (radius, depth, width, length, step, offset) in enumerate(((0.44, 0.1, 0.24, 0.4, 24, 0), (0.5, 0.34, 0.3, 0.52, 24, 12))):
        for i, angle_deg in enumerate(range(offset, 360 + offset, step)):
            angle = math.radians(angle_deg)
            out = Vector((math.cos(angle), 0, math.sin(angle)))
            base = c + out * radius + Vector((0, depth, 0))
            direction = out + Vector((0, 0.35 if ring else 0.12, 0.1))
            longer = 1.15 if math.sin(angle) > 0.3 else 1.0
            b.spike(base, direction, width, length * longer, MANES[(i + ring) % 2], h)
            if i % 3 == ring:
                # A yellow tip on some spikes, like static in the fur
                b.spike(base + direction.normalized() * length * longer * 0.6, direction, width * 0.35, length * 0.3, "mane_tip", h)
    for x, z in ((0, 0.4), (0.28, 0.3), (-0.28, 0.3), (0.2, -0.2), (-0.2, -0.2)):
        b.spike(c + Vector((x, 0.42, z)), (x * 0.6, 1, 0.2), 0.28, 0.42, "mane_dark", h)
    # Chest ruff hanging down from the neck
    for x in (-0.16, 0, 0.16):
        b.spike(Vector((x, -0.95, 1.3)), (x * 0.5, -0.3, -1), 0.2, 0.3, "mane" if x else "mane_dark", "Neck")


def build_ears(b):
    for sx in (1, -1):
        ear = f"Ear_{side_name(sx)}_0"
        b.box((sx * 0.25, -1.0, 2.04), (0.18, 0.08, 0.2), "fur", ear)
        b.box((sx * 0.25, -1.045, 2.03), (0.1, 0.02, 0.12), "fur_dark", ear)


def build_tail(b):
    widths = (0.16, 0.14, 0.12, 0.11)
    for i in range(len(TAIL) - 1):
        b.span(TAIL[i], TAIL[i + 1], widths[i], "fur", f"Tail_{i}", 0.03)
    # Spiky tuft at the tip, crackling yellow
    tip = Vector(TAIL[-1])
    b.box(tip + Vector((0, 0.04, 0.06)), (0.26, 0.26, 0.26), "mane", "Tail_3")
    for direction, color in (((0, 0.4, 1), "mane"), ((0.8, 0.3, 0.5), "mane_dark"), ((-0.8, 0.3, 0.5), "mane_dark"),
                             ((0, 1, 0.3), "mane_tip"), ((0.3, 0.2, 1.3), "mane_tip")):
        b.spike(tip + Vector((0, 0.04, 0.08)), direction, 0.18, 0.3, color, "Tail_3")


def parts(b):
    build_body(b)
    build_legs(b)
    build_head(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
