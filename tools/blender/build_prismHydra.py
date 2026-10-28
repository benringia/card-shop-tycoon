"""Builds the Prism Hydra, the final boss (Config/Bosses prismHydra, spec 2026-10-29-dungeon-final-boss-design.md):
a blocky remodel of the bought Crystal Titans Rainbow Hydra, kept clearly ours and unlike the famous five-headed
dragon: a fat, low body of lavender stone on short elephant legs, a crown of prism crystals on its back, a short thick
tail, and five short thick necks with faceted crystal heads, all in one pale prism palette (in game only the active
phase's head glows its element colour, MonsterController). Unlike Voidmaw (seven obsidian dragon heads) its heads are
gems, not dragon skulls.

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
    "stone": (118, 112, 150),
    "stone_dark": (84, 78, 114),
    "stone_light": (156, 150, 192),
    "pearl": (228, 224, 242),
    "crystal": (206, 232, 255),
    "crystal_pink": (240, 214, 255),
    "crystal_mint": (204, 255, 236),
    "crystal_mid": (172, 192, 232),
    "eye": (255, 255, 255),
    "mouth": (62, 42, 92),
    "claw": (54, 50, 72),
}
CRYSTALS = ("crystal", "crystal_pink", "crystal_mint")

# A fat, low body: hips at the back (+Y), chest at the front (-Y); the necks leave the top of the chest
HIPS = Vector((0, 0.75, 1.15))
WAIST = Vector((0, 0.1, 1.2))
CHEST = Vector((0, -0.45, 1.25))
CHEST_FRONT = Vector((0, -0.92, 1.36))
NECK_ROOT_Z = 1.62
# Short, thick elephant legs (one side, +X): hip/shoulder, knee/elbow, ankle/wrist, toes
FRONT_LEG = [(0.74, -0.55, 1.0), (0.8, -0.55, 0.56), (0.8, -0.6, 0.22), (0.8, -0.82, 0.05)]
HIND_LEG = [(0.74, 0.76, 0.96), (0.82, 0.86, 0.56), (0.82, 0.76, 0.22), (0.82, 0.54, 0.05)]
TAIL = [(0, 1.14, 1.05), (0, 1.56, 0.86), (0, 1.9, 0.66), (0, 2.15, 0.52), (0, 2.32, 0.46)]
# Heads: 0 in the middle and tallest, then outwards alternating sides (fan angle in degrees, + is the left)
FAN = [0, 34, -34, 64, -64]
NECK_BONES = 3
HEAD_SCALE = 1.2  # heads are built at size 1 and scaled about the top of their neck
HEAD_LENGTH = 0.6 * HEAD_SCALE


def neck_points(head):
    """Points along one neck, base to head: up out of the chest and forward, short and thick."""
    a = math.radians(FAN[head])
    reach = 0.2 if head % 2 == 1 else 0.0
    base = Vector((math.sin(a) * 0.5, CHEST_FRONT.y + 0.18, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 2.0, -1.55 - reach, NECK_ROOT_Z + 0.85 + 1.05 * math.cos(a) ** 2))
    control = Vector((math.sin(a) * 1.4, -0.7, (base.z + top.z) / 2 + 0.35))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.35, -1.0, -0.1)).normalized()
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
        hinge = top + (forward * 0.08 + Vector((0, 0, -0.08))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.42 + Vector((0, 0, -0.08))) * HEAD_SCALE)))
    return bones


def build_body(b):
    # A wide, deep, low body with a hanging pearl belly and stone plates across the back
    for bone, centre, size in (("Pelvis", (0, 0.72, 1.15), (1.72, 0.92, 1.02)),
                               ("Spine_0", (0, 0.1, 1.2), (1.96, 0.84, 1.14)),
                               ("Spine_1", (0, -0.5, 1.26), (1.8, 0.8, 1.08))):
        c = Vector(centre)
        b.box(c, size, "stone", bone)
        b.box(c + Vector((0, 0, size[2] / 2 + 0.03)), (size[0] * 0.8, size[1] * 0.7, 0.06), "stone_light", bone)
    b.box((0, 0.1, 0.62), (1.44, 1.7, 0.3), "pearl", "Spine_0")  # the hanging belly
    b.box((0, -0.96, 1.4), (1.3, 0.22, 0.7), "stone_dark", "Spine_1")  # breast, where the necks join
    b.box((0, -1.06, 1.32), (0.8, 0.06, 0.46), "pearl", "Spine_1")


def build_crown(b):
    """The crown of prism crystals on its back: a tall one in the middle, a ring of six leaning out."""
    top = Vector((0, 0.1, 1.8))
    b.spike(top, (0, 0.1, 1), 0.56, 1.35, "crystal", "Spine_0")
    for i in range(6):
        a = i / 6 * math.pi * 2
        out = Vector((math.cos(a), math.sin(a) * 0.8, 0))
        base = top + out * 0.42 + Vector((0, 0, -0.05))
        b.spike(base, out * 0.55 + Vector((0, 0, 1)), 0.3, 0.75 + 0.15 * (i % 2), CRYSTALS[i % 3], "Spine_0")
    for sx in (1, -1):  # smaller ones over the shoulders and hips
        b.spike((sx * 0.6, -0.6, 1.8), (sx * 0.6, 0.1, 1), 0.24, 0.44, "crystal_pink", "Spine_1")
        b.spike((sx * 0.62, 0.78, 1.66), (sx * 0.6, 0.3, 1), 0.24, 0.42, "crystal_mint", "Pelvis")


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], 0.62, "stone", upper, 0.1)
            b.span(p[1], p[2], 0.56, "stone_dark", lower, 0.06)
            b.box(p[2] + Vector((0, (p[3] - p[2]).y * 0.4, -0.12)), (0.66, 0.64, 0.22), "stone", foot)
            # Three broad pearl toenails at the front
            for toe in (-0.2, 0, 0.2):
                b.box(p[2] + Vector((toe, (p[3] - p[2]).y * 0.4 - 0.33, -0.15)), (0.14, 0.06, 0.14), "pearl", foot)


def build_tail(b):
    widths = (0.56, 0.46, 0.36, 0.28)
    for i in range(len(TAIL) - 1):
        bone = f"Tail_{i}"
        b.span(TAIL[i], TAIL[i + 1], widths[i], "stone" if i % 2 == 0 else "stone_dark", bone, 0.05)
        b.spike(Vector(TAIL[i]).lerp(Vector(TAIL[i + 1]), 0.5) + Vector((0, 0, widths[i] / 2)), (0, 0.4, 1), widths[i] * 0.5, 0.3, CRYSTALS[i % 3], bone)
    b.spike(Vector(TAIL[-1]), (0, 1, -0.2), 0.3, 0.5, "crystal", "Tail_3")


def build_necks(b):
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            bone = f"Hydra_{head}_{i}"
            width = 0.5 - 0.04 * i
            b.span(points[i], points[i + 1], width, "stone" if i % 2 == 0 else "stone_dark", bone, 0.06)
            along = (points[i + 1] - points[i]).normalized()
            back = along.cross(Vector((1, 0, 0))).normalized()
            if back.y < 0:
                back = -back
            # Pearl scales down the front of the neck, a small crystal down its back
            b.span(points[i] - back * width * 0.44, points[i + 1] - back * width * 0.44, width * 0.42, "pearl", bone)
            b.spike(points[i].lerp(points[i + 1], 0.5) + back * width * 0.42, back + along * 0.3, width * 0.45, 0.24, CRYSTALS[(head + i) % 3], bone)
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A faceted crystal head along `forward`: a gem with a pyramid snout and a crest, the lower jaw on its own bone."""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    b.box(at(0, 0.12, 0.08), (0.46, 0.4, 0.34), "crystal_mid", skull, m)
    b.spike(at(0, 0.32, 0.06), m @ Vector((0, 1, -0.05)), 0.34, 0.34, "crystal", skull)  # the gem snout
    b.box(at(0, 0.36, -0.08), (0.28, 0.3, 0.04), "mouth", skull, m)
    b.spike(at(0, 0.02, 0.25), m @ Vector((0, -0.7, 1)), 0.26, 0.42, "crystal_pink", skull)  # crest
    for sx in (1, -1):
        b.box(at(sx * 0.235, 0.24, 0.14), (0.03, 0.12, 0.07), "eye", skull, m)
        b.spike(at(sx * 0.2, 0.0, 0.18), m @ Vector((sx * 0.8, -0.8, 0.5)), 0.12, 0.26, "crystal_mint", skull)  # side facets
        for y in (0.3, 0.42):
            b.spike(at(sx * 0.1, y, -0.09), m @ Vector((0, 0.1, -1)), 0.05, 0.09, "pearl", skull)
    b.box(at(0, 0.3, -0.17), (0.3, 0.38, 0.1), "crystal_mid", jaw, m)
    b.box(at(0, 0.3, -0.115), (0.24, 0.32, 0.02), "mouth", jaw, m)
    b.xform = None


def parts(b):
    build_body(b)
    build_crown(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
