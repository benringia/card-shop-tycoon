"""Builds the Solarion creature (a massive three-headed cerberus of black obsidian and jagged glowing ruby crystals,
card art assets/ui/card-art/Solarion.jpg) in Blender. A Legendary card, so terrifying: snarling wolf heads with
glowing red eyes and white crystal fangs, tall red crystal spikes along its back, crystal talons. Less blocky: a
rounded-box body and legs; the crystals stay sharp.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), its body level (Pelvis,
Spine_0/1), a four-bone tail (Tail_0..3) and three necks (Hydra_<head>_0..2, Hydra_<head>_3 the head) each with a
snarling jaw (Jaw_<head>), so it prowls on four legs, every head moves on its own and its jaws open for its solar
roar.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Solarion/{Solarion.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Solarion"

COLORS = {
    "obsidian": (34, 26, 30),
    "obsidian_mid": (58, 40, 44),
    "ruby": (200, 18, 30),
    "ruby_light": (255, 64, 54),
    "ruby_dark": (130, 8, 22),
    "ember": (255, 150, 60),
    "eye": (255, 60, 40),
    "fang": (250, 236, 236),
    "mouth": (255, 120, 50),
}
RUBIES = ("ruby", "ruby_light", "ruby_dark")

HIPS = Vector((0, 0.66, 1.2))
WAIST = Vector((0, 0.16, 1.24))
CHEST = Vector((0, -0.32, 1.32))
CHEST_FRONT = Vector((0, -0.66, 1.46))
NECK_ROOT_Z = 1.62
HIND_LEG = [(0.5, 0.64, 1.1), (0.58, 0.4, 0.66), (0.58, 0.7, 0.26), (0.58, 0.4, 0.05)]
FRONT_LEG = [(0.52, -0.48, 1.18), (0.6, -0.36, 0.7), (0.6, -0.56, 0.26), (0.6, -0.9, 0.05)]
TAIL = [(0, 0.96, 1.26), (0, 1.38, 1.18), (0.1, 1.76, 1.3), (0.24, 2.02, 1.6), (0.3, 2.06, 1.92)]
FAN = [0, 42, -42]
NECK_BONES = 3
HEAD_SCALE = 1.45
HEAD_LENGTH = 0.66 * HEAD_SCALE


def neck_points(head):
    """Short thick necks: the middle head forward and highest, the side heads out and a little lower."""
    a = math.radians(FAN[head])
    base = Vector((math.sin(a) * 0.36, CHEST_FRONT.y + 0.08, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 1.2, -1.1 - (0.15 if head == 0 else 0), NECK_ROOT_Z + 0.45 + 0.3 * math.cos(a) ** 3))
    control = Vector((math.sin(a) * 0.7, -0.6, (base.z + top.z) / 2 + 0.15))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.5, -1.0, -0.12)).normalized()
    return points, forward


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", tuple(HIPS), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(CHEST_FRONT)),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            parent = "Spine_1" if i == 0 else f"Hydra_{head}_{i - 1}"
            bones.append((f"Hydra_{head}_{i}", parent, tuple(points[i]), tuple(points[i + 1])))
        top = points[-1]
        bones.append((f"Hydra_{head}_3", f"Hydra_{head}_{NECK_BONES - 1}", tuple(top), tuple(top + forward * HEAD_LENGTH)))
        hinge = top + (forward * 0.1 + Vector((0, 0, -0.08))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.45 + Vector((0, 0, -0.06))) * HEAD_SCALE)))
    return bones


def limb(b, a, c, width, color, bone):
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.round_box((a + c) / 2, (width, width, along.length + width * 0.4), color, bone, rot, bevel=0.5)


def crystals(b, base, up, bone, count, size, spread, seed=0):
    """A cluster of jagged ruby crystals growing from base, pointing roughly `up`."""
    base, up = Vector(base), Vector(up).normalized()
    side = up.cross(Vector((0, 1, 0)))
    if side.length < 0.1:
        side = up.cross(Vector((1, 0, 0)))
    side.normalize()
    for i in range(count):
        angle = (i + seed) * 2.4
        offset = side * math.cos(angle) * spread + up.cross(side) * math.sin(angle) * spread
        tilt = up + offset * 1.2
        grow = 1.0 - 0.18 * (i % 3)
        b.spike(base + offset, tilt, size * 0.45 * grow, size * grow, RUBIES[(i + seed) % 3], bone)


def build_body(b):
    for bone, centre, size in (("Pelvis", (0, 0.62, 1.2), (0.96, 0.74, 0.66)),
                               ("Spine_0", (0, 0.14, 1.24), (1.0, 0.62, 0.66)),
                               ("Spine_1", (0, -0.42, 1.34), (1.14, 0.7, 0.8))):
        b.round_box(centre, size, "obsidian", bone, bevel=0.45)
        b.round_box(Vector(centre) + Vector((0, 0, -size[2] / 2 + 0.02)), (size[0] * 0.7, size[1] * 0.8, 0.06), "ruby_dark", bone, bevel=0.5)
    # Tall jagged crystal spikes all along its back, and crystal clusters on its shoulders and hips
    crystals(b, (0, -0.5, 1.72), (0, 0.15, 1), "Spine_1", 4, 0.7, 0.16)
    crystals(b, (0, 0.12, 1.56), (0, 0.15, 1), "Spine_0", 4, 0.62, 0.16, 1)
    crystals(b, (0, 0.62, 1.52), (0, 0.3, 1), "Pelvis", 3, 0.55, 0.14, 2)
    for sx in (1, -1):
        crystals(b, (sx * 0.5, -0.4, 1.52), (sx * 0.8, 0.1, 0.8), "Spine_1", 3, 0.38, 0.08, 3)
        crystals(b, (sx * 0.46, 0.66, 1.4), (sx * 0.8, 0.3, 0.6), "Pelvis", 2, 0.32, 0.06, 4)


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg, widths in ((0, FRONT_LEG, (0.42, 0.34, 0.34)), (1, HIND_LEG, (0.5, 0.38, 0.36))):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            limb(b, p[0], p[1], widths[0], "obsidian", upper)
            limb(b, p[1], p[2], widths[1], "obsidian_mid", lower)
            b.round_box(p[2] + Vector((0, -0.12, -0.17)), (widths[2] + 0.1, 0.46, 0.18), "obsidian", foot, bevel=0.5)
            crystals(b, p[0].lerp(p[1], 0.4) + Vector((sx * widths[0] * 0.45, 0.05, 0)), (sx * 1, 0.3, 0.4), upper, 2, 0.3, 0.05, pair)
            # Ruby crystal talons
            for toe in (-0.12, 0, 0.12):
                b.spike(p[2] + Vector((toe, -0.36, -0.2)), (toe * 1.5, -1, -0.35), 0.1, 0.26, "ruby_light", foot)


def build_tail(b):
    for i in range(len(TAIL) - 1):
        limb(b, TAIL[i], TAIL[i + 1], (0.32, 0.26, 0.21, 0.17)[i], "obsidian", f"Tail_{i}")
        crystals(b, Vector(TAIL[i]).lerp(Vector(TAIL[i + 1]), 0.5) + Vector((0, 0, 0.12)), (0, 0.2, 1), f"Tail_{i}", 2, 0.34 - i * 0.05, 0.05, i)
    crystals(b, TAIL[-1], (0.2, 0.2, 1), "Tail_3", 3, 0.32, 0.06, 5)


def build_necks(b):
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            bone = f"Hydra_{head}_{i}"
            limb(b, points[i], points[i + 1], 0.5 - 0.04 * i, "obsidian", bone)
            along = (points[i + 1] - points[i]).normalized()
            back = along.cross(Vector((1, 0, 0))).normalized()
            if back.y < 0:
                back = -back
            crystals(b, points[i].lerp(points[i + 1], 0.5) + back * 0.2, back + along * 0.3, bone, 2, 0.32, 0.05, head + i)
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A snarling wolf head: a long muzzle, red eyes under a heavy brow, crystal fangs, crystal ears."""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    b.round_box(at(0, 0.08, 0.08), (0.42, 0.38, 0.32), "obsidian", skull, m, bevel=0.45)
    b.round_box(at(0, 0.4, 0.03), (0.28, 0.36, 0.18), "obsidian_mid", skull, m, bevel=0.4)  # long muzzle
    b.round_box(at(0, 0.58, 0.07), (0.12, 0.04, 0.07), "obsidian", skull, m, bevel=0.5)  # nose
    b.round_box(at(0, 0.38, -0.07), (0.24, 0.36, 0.03), "mouth", skull, m, bevel=0.5)  # glowing mouth
    for sx in (1, -1):
        b.round_box(at(sx * 0.12, 0.25, 0.18), (0.1, 0.03, 0.05), "eye", skull, m, bevel=0.5)  # narrow glowing eyes
        b.round_box(at(sx * 0.12, 0.24, 0.235), (0.16, 0.08, 0.05), "obsidian_mid", skull, m, bevel=0.4)  # heavy brow
        for y in (0.3, 0.46):
            b.spike(at(sx * 0.11, y, -0.06), m @ Vector((0, 0.1, -1)), 0.05, 0.13, "fang", skull)
        b.spike(at(sx * 0.13, 0.54, -0.04), m @ Vector((0, 0.1, -1)), 0.06, 0.18, "fang", skull)  # big fangs
        # Crystal ears sweeping back
        b.spike(at(sx * 0.15, -0.02, 0.22), m @ Vector((sx * 0.4, -0.8, 1)), 0.14, 0.34, "ruby", skull)
    crystals(b, at(0, -0.06, 0.24), m @ Vector((0, -0.6, 1)), skull, 2, 0.3, 0.05, head)
    b.round_box(at(0, 0.34, -0.15), (0.26, 0.38, 0.09), "obsidian", jaw, m, bevel=0.45)
    b.round_box(at(0, 0.34, -0.1), (0.2, 0.32, 0.02), "mouth", jaw, m, bevel=0.5)
    for sx in (1, -1):
        for y in (0.34, 0.48):
            b.spike(at(sx * 0.1, y, -0.09), m @ Vector((0, 0.1, 1)), 0.05, 0.12, "fang", jaw)
    b.xform = None


def parts(b):
    build_body(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
