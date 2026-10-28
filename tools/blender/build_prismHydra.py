"""Builds the Prism Hydra, the final boss (Config/Bosses prismHydra, spec 2026-10-29-dungeon-final-boss-design.md),
in the chunky "simulator pet" style: big rounded simple shapes, oversized heads on short thick necks, stubby legs,
flat bright colours and almost no small detail. A remodel of the bought Crystal Titans Rainbow Hydra kept clearly ours
and unlike the famous five-headed dragon: one shared colour for all five heads (in game only the active phase's head
glows its element colour, MonsterController), a round violet body with a cream belly, and a crown of chunky crystals
on its back. Big eyes with an angry brow so it still reads as the final boss.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_<side>_Limb_0..2, hind 1_<side>_Limb_0..2), Pelvis and
Spine_0/1 level, Tail_0..3, five necks Hydra_<head>_0..2 with the head Hydra_<head>_3 and a jaw Jaw_<head>.
Heads: 0 in the middle, then 1/2 and 3/4 outwards (left, right); their elements are Config/Bosses prismHydra.heads.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/PrismHydra/{PrismHydra.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "PrismHydra"

COLORS = {
    "violet": (148, 96, 255),
    "violet_dark": (104, 62, 214),
    "cream": (255, 238, 214),
    "aqua": (104, 228, 255),
    "aqua_dark": (54, 172, 232),
    "pink": (255, 112, 214),
    "gold": (255, 206, 64),
    "eye": (255, 255, 255),
    "pupil": (34, 22, 56),
    "mouth": (96, 28, 92),
}

# A round, low body: hips at the back (+Y), chest at the front (-Y); the necks leave the top of the chest
HIPS = Vector((0, 0.7, 1.0))
WAIST = Vector((0, 0.1, 1.05))
CHEST = Vector((0, -0.45, 1.1))
CHEST_FRONT = Vector((0, -0.95, 1.2))
NECK_ROOT_Z = 1.55
# Stubby legs (one side, +X): hip/shoulder, knee/elbow, ankle, toes
FRONT_LEG = [(0.72, -0.55, 0.78), (0.76, -0.55, 0.45), (0.76, -0.58, 0.18), (0.76, -0.8, 0.05)]
HIND_LEG = [(0.72, 0.72, 0.76), (0.76, 0.76, 0.45), (0.76, 0.72, 0.18), (0.76, 0.5, 0.05)]
TAIL = [(0, 1.2, 0.95), (0, 1.62, 0.78), (0, 1.95, 0.64), (0, 2.18, 0.56), (0, 2.34, 0.52)]
# Heads: 0 in the middle and tallest, then outwards alternating sides (fan angle in degrees, + is the left)
FAN = [0, 34, -34, 64, -64]
NECK_BONES = 3
HEAD_SCALE = 1.3  # heads are built at size 1 and scaled up about the top of their neck: oversized, simulator style
HEAD_LENGTH = 0.9 * HEAD_SCALE


def neck_points(head):
    """Points along one short, thick neck, base to head: up out of the chest and out to its own place in the fan."""
    a = math.radians(FAN[head])
    reach = 0.25 if head % 2 == 1 else 0.0
    base = Vector((math.sin(a) * 0.45, CHEST_FRONT.y + 0.25, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 3.0, -1.45 - reach, NECK_ROOT_Z + 0.85 + 1.05 * math.cos(a) ** 2))
    control = Vector((math.sin(a) * 1.5, -0.75, (base.z + top.z) / 2 + 0.25))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.3, -1.0, -0.05)).normalized()
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
        hinge = top + (forward * 0.15 + Vector((0, 0, -0.2))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.5 + Vector((0, 0, -0.06))) * HEAD_SCALE)))
    return bones


def soft(b, center, size, color, bone, rot=None, bevel=0.42, segments=1):
    """The simulator look: a box with well-rounded edges (one bevel segment keeps it low-poly; heads get two)"""
    b.round_box(center, size, color, bone, rot, bevel=bevel, segments=segments)


def build_body(b):
    # One big round body in three soft chunks, a cream belly underneath and on the chest
    soft(b, (0, 0.68, 1.02), (1.9, 1.05, 1.3), "violet", "Pelvis")
    soft(b, (0, 0.08, 1.08), (2.1, 0.95, 1.42), "violet", "Spine_0")
    soft(b, (0, -0.52, 1.14), (1.95, 0.9, 1.36), "violet", "Spine_1")
    soft(b, (0, 0.1, 0.48), (1.5, 1.9, 0.34), "cream", "Spine_0")
    soft(b, (0, -0.98, 1.08), (1.2, 0.18, 0.95), "cream", "Spine_1", bevel=0.6)


def build_crown(b):
    """A crown of chunky crystals on its back: one big pink one, two aqua beside it, gold tips at the front"""
    b.spike((0, 0.15, 1.72), (0, 0.15, 1), 0.7, 1.15, "pink", "Spine_0")
    for sx in (1, -1):
        b.spike((sx * 0.5, 0.25, 1.68), (sx * 0.45, 0.2, 1), 0.5, 0.75, "aqua", "Spine_0")
        b.spike((sx * 0.45, -0.45, 1.75), (sx * 0.35, -0.1, 1), 0.4, 0.5, "gold", "Spine_1")
        b.spike((sx * 0.4, 0.82, 1.6), (sx * 0.3, 0.4, 1), 0.38, 0.5, "pink", "Pelvis")


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            soft(b, p[0].lerp(p[1], 0.5), (0.72, 0.72, 0.62), "violet_dark", upper)
            soft(b, p[1].lerp(p[2], 0.5), (0.66, 0.66, 0.42), "violet_dark", lower)
            soft(b, p[2] + Vector((0, (p[3] - p[2]).y * 0.35, -0.08)), (0.78, 0.8, 0.26), "cream", foot, bevel=0.6)


def build_tail(b):
    sizes = (0.7, 0.56, 0.44, 0.34)
    for i in range(len(TAIL) - 1):
        a, c = Vector(TAIL[i]), Vector(TAIL[i + 1])
        soft(b, a.lerp(c, 0.5), (sizes[i], (c - a).length + 0.12, sizes[i]), "violet" if i % 2 == 0 else "violet_dark", f"Tail_{i}")
    b.spike(Vector(TAIL[-1]), (0, 1, 0.15), 0.42, 0.55, "pink", "Tail_3")


def build_necks(b):
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            a, c = points[i], points[i + 1]
            along = (c - a)
            rot = along.to_track_quat("Z", "Y").to_matrix()
            width = 0.66 - 0.05 * i
            soft(b, a.lerp(c, 0.5), (width, width, along.length + 0.2), "violet", f"Hydra_{head}_{i}", rot)
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A big, round crystal head: a soft block with huge eyes and an angry brow, a gem horn, the lower jaw on its own bone"""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    soft(b, at(0, 0.3, 0.1), (1.0, 0.95, 0.82), "aqua", skull, m, bevel=0.5, segments=2)
    soft(b, at(0, 0.74, -0.02), (0.72, 0.36, 0.42), "aqua_dark", skull, m, bevel=0.55)  # snout
    for sx in (1, -1):
        soft(b, at(sx * 0.27, 0.72, 0.27), (0.36, 0.1, 0.36), "eye", skull, m, bevel=0.5)
        b.box(at(sx * 0.24, 0.78, 0.24), (0.16, 0.04, 0.2), "pupil", skull, m)
        # The angry brow slants down toward the middle
        tilt = m @ Matrix.Rotation(math.radians(-22 * sx), 3, "Y")
        b.box(at(sx * 0.27, 0.76, 0.5), (0.4, 0.08, 0.1), "violet_dark", skull, tilt)
    b.spike(at(0, 0.2, 0.5), m @ Vector((0, -0.35, 1)), 0.32, 0.5, "pink", skull)  # gem horn
    soft(b, at(0, 0.62, -0.32), (0.66, 0.5, 0.2), "aqua_dark", jaw, m, bevel=0.5)
    b.box(at(0, 0.68, -0.2), (0.5, 0.36, 0.05), "mouth", jaw, m)
    b.xform = None


def parts(b):
    build_body(b)
    build_crown(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
